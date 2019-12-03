#!/bin/bash
# Name       : Neo4j Health Check Script
# Usage Info :
#
#        This script checks the availability of the new4j instance for
#        normal operation on port 7474, if there are issues it will mark
#        the instance in unhealthy state in the autoscaling group which
#        in turn would reinitiate the current instance.
#
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/13 : Johney A   : created
# ============================================================================
. $HOME/.bash_profile

set_env()
{
    NEO4J_CONNECT_PORT=7474
    CONNECT_RETRIES=6
    RETRY_DELAY=30
    ADMIN_EMAIL=dl-mediaengineering@discovery.com

    WORK_DIR=/opt/software/neo4j/scripts/healthcheck
    LOG_DIR=$WORK_DIR/logs
    [ ! -d $LOG_DIR ] && mkdir -p $LOG_DIR
    LOG_FILE=neo4jhealth.log
    if [ -f "$HOME/FULL_HOST_NAME" ]; then
        NEO4J_INSTANCE_NAME=`cat $HOME/FULL_HOST_NAME`
    else
        NEO4J_INSTANCE_NAME=`hostname`
    fi
}

# ============================================================================
# Main
# ============================================================================
set_env

LOOP_CNT=$CONNECT_RETRIES
while [ "$LOOP_CNT" -ne "0" ]; do
    # check response from Neo4j HTTP NEO4J_PORT
    curl -I -s -o /dev/null localhost:$NEO4J_CONNECT_PORT

    if [ $? == 0 ]; then
        #If the request was serverd on the connection port, no further action necessary.
        exit 0
    else
        echo `date` " Health check failed, retrying $LOOP_CNT more times. Sleeping $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
    fi
    ((LOOP_CNT--))
done

echo `date` "max attempts to check for : $NEO4J_CONNECT_PORT completed, instance found Unhealthy" | tee -a ${LOG_DIR}/${LOG_FILE}

INSTANCE_ID=$( wget -q -O - http://169.254.169.254/latest/meta-data/instance-id )

mailx -s "Neo4j instance $NEO4J_INSTANCE_NAME is marked unhealthy in autoscaling group ${CURRENT_DATE}" $ADMIN_EMAIL -r $ADMIN_EMAIL < ${LOG_DIR}/${LOG_FILE}

aws --region us-east-1 autoscaling set-instance-health --instance-id "$INSTANCE_ID" --health-status Unhealthy
