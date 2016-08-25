# docker-mongo

**Example on local machine:**
```sh
# Get the host published IP (internal network)
HOST_PUB_IP=`ifconfig | grep en0 -A 5 | grep "inet " | cut -d' ' -f2`
REP_KEY=someprivatekey
PORT_NODE_1=33001
PORT_NODE_2=33002
PORT_NODE_3=33003
PEER=$HOST_PUB_IP:$PORT_NODE_1

# Launch master
docker run -d -p $PORT_NODE_1:27017 \
  -e SELF_HOST=$HOST_PUB_IP \
  -e SELF_PORT=$PORT_NODE_1 \
  -e MONGO_REP_KEY=$REP_KEY \
  maestrano/mongo

# Launch first replica
docker run -d -p $PORT_NODE_2:27017 \
  -e MONGO_REP_PEERS=$PEER \
  -e SELF_HOST=$HOST_PUB_IP \
  -e SELF_PORT=$PORT_NODE_2 \
  -e MONGO_REP_KEY=$REP_KEY \
  maestrano/mongo

# Launch second replica
docker run -d -p $PORT_NODE_3:27017 \
  -e MONGO_REP_PEERS=$HOST_PUB_IP:$PORT_NODE_2,$PEER \
  -e SELF_HOST=$HOST_PUB_IP \
  -e SELF_PORT=$PORT_NODE_3 \
  -e MONGO_REP_KEY=$REP_KEY \
  maestrano/mongo
```
