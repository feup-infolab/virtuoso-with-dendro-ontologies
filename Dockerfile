FROM tenforce/virtuoso:1.3.2-virtuoso7.2.5.1

RUN apt-get update; apt-get -y install curl

ENV SCRIPTS_LOCATION="/startup"
COPY ./startup "$SCRIPTS_LOCATION"

# Environment variables

ENV ORIGINAL_VIRTUOSO_STARTUP_SCRIPT="/virtuoso.sh"
ENV VIRTUOSO_HOST="127.0.0.1"
ENV VIRTUOSO_ISQL_PORT="1111"
ENV VIRTUOSO_CONDUCTOR_PORT="8890"
ENV VIRTUOSO_DBA_USER="dba"
ENV SETUP_COMPLETED_PREVIOUSLY="/data/virtuoso_already_loaded_ontologies.dat"

CMD ["/bin/bash", "/startup/scripts/virtuoso.sh"]
