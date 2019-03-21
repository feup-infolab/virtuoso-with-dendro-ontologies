#!/usr/bin/env bash

# register exit handler to shut down virtuoso cleanly on Ctrl+C
exit_func() {
    echo "SIGTERM detected. Shutting down virtuoso"
    if [[ "$DBA_PASSWORD" != "" ]]
    then
      echo "checkpoint(); shutdown()" | isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" -P "$DBA_PASSWORD" || (echo "Error logging into Virtuoso with authentication ON during shutdown." && exit 1)
    else
      echo "checkpoint(); shutdown()" | isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER"  || (echo "Error logging into Virtuoso with authentication OFF during shutdown." && exit 1)
    fi
}

trap exit_func SIGTERM SIGINT

# starts containers with the volumes mounted
function wait_for_server_to_boot_on_port()
{
    local ip=$1

    if [[ $ip == "" ]]; then
      ip="127.0.0.1"
    fi
    local port=$2
    local attempts=0
    local max_attempts=60

    echo "Waiting for server on $ip:$port to boot up..."

    response=$(curl -s $ip:$port)
    echo $response

  	until curl --output /dev/null --silent --head --fail http://$ip:$port || [[ $attempts > $max_attempts ]]; do
        attempts=$((attempts+1))
        echo "waiting... (${attempts}/${max_attempts})"
        sleep 1;
  	done

    if (( $attempts == $max_attempts ));
    then
        echo "Server on $ip:$port failed to start after $max_attempts"
    elif (( $attempts < $max_attempts ));
    then
        echo "Server on $ip:$port started successfully at attempt (${attempts}/${max_attempts})"
    fi
}

function start_virtuoso()
{
  source "$ORIGINAL_VIRTUOSO_STARTUP_SCRIPT"
}

if [[ -f "$SETUP_COMPLETED_PREVIOUSLY" || "$FORCE_ONTOLOGIES_RELOAD" != "" ]]
then
  start_virtuoso
else

  if [[ "$DBA_PASSWORD" == "" ]];
  then
    DBA_PASSWORD="dba"
  fi

  echo "This is the first startup of this container. Ontologies need to be loaded..."

  #
  # Wait for virtuoso server to boot up
  #
  /bin/bash "$ORIGINAL_VIRTUOSO_STARTUP_SCRIPT" &
  VIRTUOSO_PID=$!

  wait_for_server_to_boot_on_port "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT"
  wait_for_server_to_boot_on_port "$VIRTUOSO_HOST" "$VIRTUOSO_CONDUCTOR_PORT"

  #
  # Test Authentication
  #
  if [[ "$DBA_PASSWORD" != "" ]]
  then
    echo "checkpoint(); exit()" | isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" -P "$DBA_PASSWORD" || (echo "Error logging into Virtuoso with authentication on." && exit 1)
  fi

  #
  # Load ontologies and set up namespaces
  #

  if [[ "$DBA_PASSWORD" != "" ]]
  then
    echo "Logging into virtuoso with credentials $VIRTUOSO_DBA_USER: $DBA_PASSWORD..."
    isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" -P "$DBA_PASSWORD" < "$SCRIPTS_LOCATION/isql_commands/load_ontologies.rq" || ( echo "Unable to load ontologies into Virtuoso." && exit 1 )
    isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" -P "$DBA_PASSWORD" < "$SCRIPTS_LOCATION/isql_commands/declare_namespaces.rq" || ( echo "Unable to setup namespaces" && exit 1 )
  else
    isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" < "$SCRIPTS_LOCATION/isql_commands/load_ontologies.rq" || ( echo "Unable to load ontologies into Virtuoso." && exit 1 )
    isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" < "$SCRIPTS_LOCATION/isql_commands/declare_namespaces.rq" || ( echo "Unable to setup namespaces" && exit 1 )
  fi

  touch "$SETUP_COMPLETED_PREVIOUSLY"

  if [[ -f $SETUP_COMPLETED_PREVIOUSLY ]]; then
    echo "Installed base ontologies in virtuoso."
  else
    echo "Unable to touch file $SETUP_COMPLETED_PREVIOUSLY after loading ontologies"
    exit 1
  fi


  #
  # Enable job control for this shell
  #

  set -m

  #
  # kill virtuoso and wait for its shutdown
  #
  echo "Shutting down virtuoso..."
  while kill $VIRTUOSO_PID; do
    echo "Virtuoso shutting down..."
    sleep 1
  done

  echo "Virtuoso shut down successful. Starting up again for normal operation..."

  #start_virtuoso_again
  start_virtuoso
fi
