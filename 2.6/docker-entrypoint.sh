#!/bin/bash
#set -e

# Set default variables
export MONGO_USER=${MONGO_USER:-root}
export MONGO_PASSWORD=${MONGO_PASSWORD:-changeme}
export SELF_ADDRESS=${SELF_ADDRESS:-localhost:27017}

if [ "${1:0:1}" = '-' ]; then
  set -- mongod "$@"
fi

# Generate keyfile
if [ -n "$REP_KEY" ]; then
  echo $REP_KEY > /etc/mongodb-keyfile
else
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 > /etc/mongodb-keyfile
fi
chmod 600 /etc/mongodb-keyfile
chown mongodb /etc/mongodb-keyfile

if [ "$IS_MASTER" == "true" ]; then
  # Start Mongo without options
  mongod --fork --logpath /var/log/mongodb.log

  # Create root user
  if [ -n "$MONGO_USER" ] && [ -n "$MONGO_PASSWORD" ]; then
    mongo --eval "db.createUser({ user: '${MONGO_USER}', pwd: '${MONGO_PASSWORD}', roles: [ { role: 'root', db: 'admin' } ] })" admin
  fi

  # Shutdown
  mongod --shutdown

  # Start Mongo with replicaSet configuration
  mongod --fork --logpath /var/log/mongodb.log --replSet rs0 --keyFile /etc/mongodb-keyfile

  # Initiate replicaSet
  mongo -u $MONGO_USER -p $MONGO_PASSWORD --eval "rs.initiate({_id: 'rs0',version: 1,members: [{ _id: 0, host : '${SELF_ADDRESS}' }]})" admin

  # Shutdown
  mongod --shutdown

  # Echo initialization logs
  cat /var/log/mongodb.log
fi

# Auto-register slave to master
if [ "$IS_MASTER" != "true" ] && [ -n "$REPLICA_MASTER" ]; then
  mongo -u $MONGO_USER -p $MONGO_PASSWORD --eval "rs.add('${SELF_ADDRESS}')" $REPLICA_MASTER/admin
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
