#!/usr/bin/env bash

# Set constants
VIRTUOSO_HOST=$(hostname -i | awk '{print $1}')
VIRTUOSO_ISQL_PORT="1111"
VIRTUOSO_CONDUCTOR_PORT="8890"

# register exit handler to shut down virtuoso cleanly on Ctrl+C
exit_func() {
    echo "SIGTERM detected. Shutting down virtuoso"
    if [[ "$DBA_PASSWORD" != "" ]]
    then
      echo "checkpoint(); shutdown()" | isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" -P "$DBA_PASSWORD" \
      || (echo "Error logging into Virtuoso with authentication ON during shutdown." && exit 1)
    else
      echo "checkpoint(); shutdown()" | isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER"  \
      || (echo "Error logging into Virtuoso with authentication OFF during shutdown." && exit 1)
    fi
}

trap exit_func SIGTERM SIGINT

function server_is_online()
{
  local ip=$1
  local port=$2
  local text_to_find="$3"
  local response

  if [[ "$text_to_find" == "" ]];
  then
    echo "Waiting for server at $ip:$port to boot up..."
    response=$(curl --silent --verbose "$ip:$port")
    if [[ "$?" != "0" ]]; then
      nc -z "$ip" "$port"
      if [[ "$?" == "0" ]]; then
        echo "Server IS ONLINE (checked via netcat)!"
        return 0
      else
        echo "Server is not online. Response was $response"
        return 1
      fi
    else
      echo "Server IS ONLINE! Response was $response"
      return 0
    fi
  else
    echo "Waiting for server at $ip:$port to boot up and respond with something like $text_to_find"
    response=$(curl --silent --verbose --fail "$ip:$port")

    if [[ "$?" != "0" ]]; then
      if [[ "$response" == *$text_to_find* ]];
      then
        echo "Server IS ONLINE! Response was $response, which includes $text_to_find"
        return 0
      else
        echo "Server is not online. Response was $response"
        return 1
      fi
    else
      echo "Server IS ONLINE! Response was $response"
      return 0
    fi
  fi
}

# starts containers with the volumes mounted
function wait_for_server_to_boot_on_port()
{
    local ip=$1
    local port=$2
    local text_to_find=$3

    if [[ $ip == "" ]]; then
      ip="127.0.0.1"
    fi

    local attempts
    local max_attempts=60

    echo "Waiting for server on $ip:$port to boot up..."

    attempts=0

	  until \
      server_is_online $ip $port "$text_to_find" || (( $attempts > $max_attempts )) \
    ; do
        ((attempts=attempts+1))
        echo "Waiting... ${attempts}/${max_attempts}"
        sleep 1;
        response=$(curl -s $ip:$port)
	  done

    if (( $attempts >= $max_attempts ));
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
  echo "This is the first startup of this container. Ontologies need to be loaded..."

  #
  # Wait for virtuoso server to boot up
  #
  /bin/bash "$ORIGINAL_VIRTUOSO_STARTUP_SCRIPT" &
  VIRTUOSO_PID=$!

  wait_for_server_to_boot_on_port "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT"
  wait_for_server_to_boot_on_port "$VIRTUOSO_HOST" "$VIRTUOSO_CONDUCTOR_PORT" "HTTP/1.1 200 OK"

  #
  # Test Authentication
  #
  if [[ "$DBA_PASSWORD" != "" ]]
  then
    echo "checkpoint();" | isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" -P "$DBA_PASSWORD" || (echo "Error logging into Virtuoso with authentication on." && exit 1)
  fi

  #
  # Load ontologies and set up namespaces
  #

  if [[ "$DBA_PASSWORD" != "" ]]
  then
    echo "Logging into virtuoso with credentials $VIRTUOSO_DBA_USER: $DBA_PASSWORD..."
    isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" -P "$DBA_PASSWORD" < "$SCRIPTS_LOCATION/isql_commands/load_ontologies.rq" \
    && \
    isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" -P "$DBA_PASSWORD" < "$SCRIPTS_LOCATION/isql_commands/declare_namespaces.rq" \
    && \
    touch $SETUP_COMPLETED_PREVIOUSLY \
      || ( echo "Unable to setup namespaces" && exit 1 )
  else
    isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" < "$SCRIPTS_LOCATION/isql_commands/load_ontologies.rq" \
    && \
    isql-v "$VIRTUOSO_HOST" "$VIRTUOSO_ISQL_PORT" -U "$VIRTUOSO_DBA_USER" < "$SCRIPTS_LOCATION/isql_commands/declare_namespaces.rq" \
    && \
    touch $SETUP_COMPLETED_PREVIOUSLY \
      || ( echo "Unable to setup namespaces" && exit 1 )
  fi

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
