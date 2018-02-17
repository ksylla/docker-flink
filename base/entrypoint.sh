#!/bin/bash

if [ ! -z "$SERVICE_PRECONDITION" ] ;then
    function wait_for_it()
    {
        local serviceport=$1
        local service=${serviceport%%:*}
        local port=${serviceport#*:}
        local retry_seconds=5
        local max_try=${MAX_TRY_PRECONDITION:-100}
        let i=1

        nc -z $service $port
        result=$?

        until [ $result -eq 0 ]; do
        echo "[$i/$max_try] check for ${service}:${port}..."
        echo "[$i/$max_try] ${service}:${port} is not available yet"
        if (( $i == $max_try )); then
            echo "[$i/$max_try] ${service}:${port} is still not available; giving up after ${max_try} tries. :/"
            exit 1
        fi

        echo "[$i/$max_try] try in ${retry_seconds}s once again ..."
        let "i++"
        sleep $retry_seconds

        nc -z $service $port
        result=$?
        done
        echo "[$i/$max_try] $service:${port} is available."
    }

    for i in ${SERVICE_PRECONDITION[@]}
    do
        wait_for_it ${i}
    done
else
    echo $0: no SERVICE_PRECONDITION specified
fi

if [ ! -z "$REQUEST_SLOTS" ] ;then
    echo REQUEST_SLOTS=$REQUEST_SLOTS at FLINK_MASTER=$FLINK_MASTER
    if [[ ! -z "$FLINK_MASTER" ]] && [[ $REQUEST_SLOTS =~ ^[0-9]+$ ]] ;then
        request-slots () {
            RC=-1
            FLINK_REQUEST=$FLINK_MASTER:8081/overview
            FLINK_OVERVIEW=$(curl -XGET -s $FLINK_REQUEST)
            RC=$?
            if [ $RC -eq 0 ] ;then
                SLOTS=$(echo $FLINK_OVERVIEW | sed 's/^.*"slots-available":\([0123456789]*\),.*$/\1/')
                echo RC=$RC : SLOTS=$SLOTS : $FLINK_OVERVIEW
            else
                SLOTS=0
                echo RC=$RC : SLOTS=$SLOTS : cannot request $FLINK_REQUEST for slots-available >&2
            fi
        } 

        SLOTS=0
        while [ $SLOTS -lt $REQUEST_SLOTS ] ;do
            request-slots
            if [ $SLOTS -lt $REQUEST_SLOTS ]; then
                echo await requested number: REQUEST_SLOTS=$REQUEST_SLOTS
                sleep 5
            fi
        done
    else
        echo ERROR: REQUEST_SLOTS not a number or FLINK_MASTER not specified >&2
        exit 1
    fi

exec $@
