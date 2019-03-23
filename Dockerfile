FROM tenforce/virtuoso:1.3.2-virtuoso7.2.5.1

RUN apt-get update; apt-get -y install curl netcat

ENV SCRIPTS_LOCATION="/startup"
COPY ./startup "$SCRIPTS_LOCATION"

# Environment variables

ENV ORIGINAL_VIRTUOSO_STARTUP_SCRIPT="/virtuoso.sh"
ENV VIRTUOSO_DBA_USER="dba"
ENV SETUP_COMPLETED_PREVIOUSLY="/data/virtuoso_already_loaded_ontologies.dat"

CMD ["/bin/bash", "/startup/scripts/virtuoso.sh"]
