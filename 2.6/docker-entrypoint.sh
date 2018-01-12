#!/bin/bash
#set -e

# Set default variables
export MONGO_USER=${MONGO_USER:-root}
export MONGO_PASSWORD=${MONGO_PASSWORD:-changeme}
export SELF_HOST=${SELF_HOST:-localhost}
export SELF_PORT=${SELF_PORT:-27017}
export SELF_ADDRESS="${SELF_HOST}:${SELF_PORT}"
export MONGO_OPTS="--smallfiles --oplogSize 100"

function shutdownServer {
  echo "GRACEFULLY SHUTDOWN SERVER"
  mongo -u $MONGO_USER -p $MONGO_PASSWORD --eval "db.getSiblingDB('admin').shutdownServer()" admin
  mongo -u $MONGO_USER -p $MONGO_PASSWORD --eval "rs.remove('$SELF_ADDRESS')" admin
}

# Gracefully shutdown replica set when stopping container
trap shutdownServer SIGTERM

# Generate keyfile
if [ -n "$MONGO_REP_KEY" ]; then
  echo $MONGO_REP_KEY > /etc/mongodb-keyfile
else
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 > /etc/mongodb-keyfile
fi
chmod 600 /etc/mongodb-keyfile
chown mongodb /etc/mongodb-keyfile

# Master mode
# Initiate new replicaSet
if [ -z "$MONGO_REP_PEERS" ] || [ "$MONGO_REP_PEERS" = "$SELF_ADDRESS" ]; then
  echo "Starting as replicaSet PRIMARY..."

  # Start Mongo without options
  echo "Starting mongo for auth configuration..."
  mongod --fork --logpath /var/log/mongodb.log $MONGO_OPTS

  # Create root user
  if [ -n "$MONGO_USER" ] && [ -n "$MONGO_PASSWORD" ]; then
    echo "Creating root user: ${MONGO_USER}"
    mongo --eval "db.createUser({ user: '${MONGO_USER}', pwd: '${MONGO_PASSWORD}', roles: [ { role: 'root', db: 'admin' } ] })" admin
  fi

  # Shutdown
  echo "Shutting down mongo..."
  mongod --shutdown

  # Start Mongo with replicaSet configuration
  echo "Starting mongo for replicaSet configuration..."
  mongod --fork --logpath /var/log/mongodb.log --replSet rs0 --keyFile /etc/mongodb-keyfile $MONGO_OPTS

  # Initiate replicaSet
  echo "Initiating replicaSet rs0 with member ${SELF_ADDRESS}"
  mongo -u $MONGO_USER -p $MONGO_PASSWORD --eval "rs.initiate({_id: 'rs0',version: 1,members: [{ _id: 0, host : '${SELF_ADDRESS}' }]})" admin
  sleep 5

  # Shutdown
  echo "Shutting down mongo..."
  mongod --shutdown

  # Echo initialization logs
  echo "---------------- Initialization logs ------------------------"
  cat /var/log/mongodb.log
  echo "-------------------------------------------------------------"
else
  # Slave mode
  # Auto-register slave to master
  echo "Starting as replicaSet SECONDARY..."

  # Transform comma separated list of peers into an array
  arr_peers=(${MONGO_REP_PEERS//,/ })

  # Get master
  echo "Retrieving replicaSet master..."
  for trycount in 1 2 3 4; do
    retval=
    master_address=

    # Try each peer
    for peer in "${arr_peers[@]}"; do
      [ "$peer" == "$SELF_ADDRESS" ] && continue # do not query self for master
      master_address=`mongo --quiet -u $MONGO_USER -p $MONGO_PASSWORD --eval "rs.isMaster().primary" $peer/admin`
      retval=$?
      [ "$retval" == "0" ] && break # break immediately on success
    done

    # Break or retry
    if [ -n "$master_address" ] && [ "$retval" == "0" ]; then
      break
    else
      [ $trycount -gt 4 ] && exit 1
      echo "Unable to retrieve master. Retrying in 10s (try ${trycount}/4)"
      sleep 10
    fi
  done
  echo "ReplicaSet master is: ${master_address}"

  # Start Mongo with replicaSet configuration
  echo "Starting mongo for replicaSet configuration..."
  mongod --fork --logpath /var/log/mongodb.log --replSet rs0 --keyFile /etc/mongodb-keyfile $MONGO_OPTS

  # Add self to replicaSet via master
  echo "Register replicaSet member: ${SELF_ADDRESS}"
  for trycount in 1 2 3 4; do
    mongo -u $MONGO_USER -p $MONGO_PASSWORD --eval "rs.add('${SELF_ADDRESS}')" $master_address/admin
    [ "$?" == "0" ] && break # break immediately on success
    [ $trycount -gt 4 ] && exit 1
  done

  # Shutdown
  echo "Shutting down mongo..."
  mongod --shutdown
fi

# Execute options directly
if [ "${1:0:1}" = '-' ]; then
  set -- mongod "$@"
fi

if [ "$1" = 'mongod' ]; then
  numa='numactl --interleave=all'
  if $numa true &> /dev/null; then
    set -- $numa "$@"
  fi
fi

# allow the container to be started with `--user`
if [ "$1" = 'mongod' -a "$(id -u)" = '0' ]; then
  echo "Executing CMD as mongodb user"
  chown -R mongodb /data/configdb /data/db
  exec gosu mongodb "$@"
else
  exec "$@"
fi
