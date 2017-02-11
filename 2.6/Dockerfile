FROM mongo:2.6

# Point-in-time backup script with backup rotation
COPY backup.sh /usr/local/bin/

# Extend mountable directory
VOLUME ["/data"]

# Entrypoint command
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

EXPOSE 27017
CMD ["mongod","--auth","--replSet", "rs0","--keyFile", "/etc/mongodb-keyfile","--smallfiles","--oplogSize","100"]
