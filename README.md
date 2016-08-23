# docker-mongo

**Example on local machine:**
```sh
# Get the host published IP (internal network)
HOST_PUB_IP=`ifconfig | grep en0 -A 5 | grep "inet " | cut -d' ' -f2`
REP_KEY=someprivatekey
PORT_NODE_1=33001
PORT_NODE_2=33002
PORT_NODE_3=33003

# Launch master
docker run -d -p $PORT_NODE_1:27017 -e SELF_ADDRESS=$HOST_PUB_IP:$PORT_NODE_1 -e REP_KEY=$REP_KEY maestrano/mongo

# Launch first slave
docker run -d -p $PORT_NODE_2:27017 -e REPLICA_PEER=$HOST_PUB_IP:$PORT_NODE_1 -e SELF_ADDRESS=$HOST_PUB_IP:$PORT_NODE_2 -e REP_KEY=$REP_KEY alachaum/mongo

# Launch second slave
docker run -d -p $PORT_NODE_3:27017 -e REPLICA_PEER=$HOST_PUB_IP:$PORT_NODE_1 -e SELF_ADDRESS=$HOST_PUB_IP:$PORT_NODE_3 -e REP_KEY=$REP_KEY alachaum/mongo
```
