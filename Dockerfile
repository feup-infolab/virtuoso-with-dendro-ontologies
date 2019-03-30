FROM openlink/virtuoso-opensource-7:7.2.6-r1-g0a3336c

RUN apt-get update; apt-get -y install curl netcat

ARG DBA_PASSWORD="mysecret"

ENV SCRIPTS_LOCATION="/startup"
COPY ./startup "$SCRIPTS_LOCATION"

# Environment variables

ENV ORIGINAL_VIRTUOSO_STARTUP_SCRIPT "/virtuoso-entrypoint.sh"
ENV VIRTUOSO_DBA_USER "dba"
ENV DBA_PASSWORD "$DBA_PASSWORD"
ENV SETUP_COMPLETED_PREVIOUSLY "/database/virtuoso_already_loaded_ontologies.dat"

CMD ["/bin/bash", "/startup/scripts/virtuoso.sh"]
