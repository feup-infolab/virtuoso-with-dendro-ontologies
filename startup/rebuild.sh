#!/usr/bin/env bash

docker stop $(docker ps -a -q -f ancestor=virtuoso-loaded) &&  docker build . -t virtuoso-loaded && docker run -p 8890:8890 virtuoso-loaded
