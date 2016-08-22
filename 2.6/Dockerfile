FROM mongo:2.6

# Entrypoint command
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

EXPOSE 27017
CMD ["mongod", "--auth", "--replSet", "rs0", "--keyFile", "/etc/mongodb-keyfile"]
