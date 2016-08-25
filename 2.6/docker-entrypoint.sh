#!/bin/bash
#set -e

# Set default variables
export MONGO_USER=${MONGO_USER:-root}
export MONGO_PASSWORD=${MONGO_PASSWORD:-changeme}
export SELF_HOST=${SELF_HOST:-localhost}
export SELF_PORT=${SELF_PORT:-27017}
export SELF_ADDRESS="${SELF_HOST}:${SELF_PORT}"

if [ "${1:0:1}" = '-' ]; then
  set -- mongod "$@"
fi

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
if [ -z "$MONGO_REP_PEER" ]; then
  echo "Starting as replicaSet PRIMARY..."

  # Start Mongo without options
  echo "Starting mongo for auth configuration..."
  mongod --fork --logpath /var/log/mongodb.log

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
  mongod --fork --logpath /var/log/mongodb.log --replSet rs0 --keyFile /etc/mongodb-keyfile

  # Initiate replicaSet
  echo "Initiating replicaSet rs0 with member ${SELF_ADDRESS}"
  mongo -u $MONGO_USER -p $MONGO_PASSWORD --eval "rs.initiate({_id: 'rs0',version: 1,members: [{ _id: 0, host : '${SELF_ADDRESS}' }]})" admin

  # Shutdown
  echo "Shutting down mongo..."
  mongod --shutdown

  # Echo initialization logs
  cat /var/log/mongodb.log
fi

# Slave mode
# Auto-register slave to master
if [ -n "$MONGO_REP_PEER" ]; then
  echo "Starting as replicaSet SECONDARY..."

  # Get master
  echo "Retrieving replicaSet master..."
  master_address=`mongo --quiet -u root -p changeme --eval "rs.isMaster().primary" $MONGO_REP_PEER/admin`
  echo "ReplicaSet master is: ${master_address}"

  # Start Mongo with replicaSet configuration
  echo "Starting mongo for replicaSet configuration..."
  mongod --fork --logpath /var/log/mongodb.log --replSet rs0 --keyFile /etc/mongodb-keyfile

  # Add self to replicaSet via master
  echo "Register replicaSet member: ${SELF_ADDRESS}"
  mongo -u $MONGO_USER -p $MONGO_PASSWORD --eval "rs.add('${SELF_ADDRESS}')" $master_address/admin

  # Shutdown
  echo "Shutting down mongo..."
  mongod --shutdown
fi

# allow the container to be started with `--user`
if [ "$1" = 'mongod' -a "$(id -u)" = '0' ]; then
  chown -R mongodb /data/configdb /data/db
  exec gosu mongodb "$BASH_SOURCE" "$@"
fi

if [ "$1" = 'mongod' ]; then
  numa='numactl --interleave=all'
  if $numa true &> /dev/null; then
    set -- $numa "$@"
  fi
fi

exec "$@"
