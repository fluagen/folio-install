#Prerequisites JDK
FROM maven:3.6.1-jdk-8-alpine

#Mvn
RUN apk add --no-cache curl git

#Okapi git clone and MVN Build
RUN mkdir -p /usr/local/bin/folio/
WORKDIR /usr/local/bin/folio
RUN git clone  -b "v2.29.3" --recursive https://github.com/folio-org/okapi.git
RUN cd okapi && mvn clean install -DskipTests

#Expose ports
EXPOSE 9130
EXPOSE 9150
EXPOSE 5701
EXPOSE 5702
EXPOSE 5703
EXPOSE 5704
EXPOSE 5705
EXPOSE 5706
EXPOSE 54327

#Set environment variables for script
ENV INITDB='false'
ENV PG_HOST='pghost'
ENV PG_PORT='5432'
ENV PG_USERNAME='okapi'
ENV PG_PASSWORD='okapi25'
ENV PG_DATABASE='okapi'
ENV OKAPI_COMMAND='dev'
ENV OKAPI_PORT='9130'
ENV OKAPI_URL='http://okapi:9130'
ENV OKAPI_HOST='okapi'
ENV OKAPI_CLUSTERHOST='okapi'
ENV OKAPI_NODENAME='okapi1'
ENV OKAPI_LOGLEVEL='INFO'
ENV OKAPI_STORAGE='postgres'
ENV HAZELCAST_FILE='/usr/local/bin/folio/okapi/hazelcast.xml'
ENV HAZELCAST_PORT='5701'
ENV HAZELCAST_VERTX_PORT='5702'
ENV HAZELCAST_IP='localhost'

#Copy in scripts and files
COPY hazelcast.xml /usr/local/bin/folio/okapi/
COPY startup.sh /usr/local/bin/folio/

#Execute the script on container runtime
CMD ["/usr/local/bin/folio/startup.sh"]
