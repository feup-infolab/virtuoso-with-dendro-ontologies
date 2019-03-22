#!/usr/bin/env bash

docker stop $(docker ps -a -q -f ancestor=feupinfolab/virtuoso-with-dendro-ontologies)
docker build . -t feupinfolab/virtuoso-with-dendro-ontologies
docker run -p 8890:8890 feupinfolab/virtuoso-with-dendro-ontologies
