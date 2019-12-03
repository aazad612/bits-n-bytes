#!/bin/bash
# Name       : Neo4j Health Check Script
# Usage Info :
#
#        This script checks the availability of the neo4j instance for
#        normal operation on port 7474, if there are issues it will mark
#        the instance in unhealthy state in the autoscaling group which
#        in turn would reinitialize the current instance.
#
# If you stop this script from running you must run the following command before it will work again    rm -r /tmp/neo4j_health_check_test.lock/
#
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/13 : Johney A   : created
# 2019/03/04 : Mike H     : added function to email after every failed attempt, added lock function to prevent multiple instances of this script running, fxied mail not sending
# 2019/04/10 : Mike H     : added env name and node name
# ============================================================================
. $HOME/.bash_profile
set_env()
{
    NEO4J_CONNECT_PORT=7474                               export NEO4J_CONNECT_PORT
    CONNECT_RETRIES=5                                     export CONNECT_RETRIES
    RETRY_DELAY=30                                        export RETRY_DELAY
    ADMIN_EMAIL=dl-mediaengineering@discovery.com         export ADMIN_EMAIL
    WORK_DIR=/home/neo4j/scripts/healthcheck              export WORK_DIR
    LOCKFILE=/tmp/neo4j_health_check.lock                 export LOCKFILE
    LOG_DIR=${WORK_DIR}/logs                              export LOG_DIR
    [ ! -d ${LOG_DIR} ] && mkdir -p ${LOG_DIR}
    LOG_FILE=neo4jhealth.log                              export LOG_FILE
    if [ -f "${HOME}/FULL_HOST_NAME" ]; then
        NEO4J_INSTANCE_NAME=`cat ${HOME}/FULL_HOST_NAME`  export NEO4J_INSTANCE_NAME
    else
        NEO4J_INSTANCE_NAME=`hostname`                    export NEO4J_INSTANCE_NAME
    fi
}

healthcheck()
{
LOOP_CNT=${CONNECT_RETRIES}
while [ "${LOOP_CNT}" -ne "0" ]; do
    #--check response from Neo4j HTTP NEO4J_PORT
    curl -I -s -o /dev/null localhost:${NEO4J_CONNECT_PORT}
    if [ $? == 0 ]; then
    #--If the request was successful on the connection port, no further action necessary.
        rm -rf ${LOCKFILE}
        exit 0
    else
        echo `date` "Health check failed, retrying ${LOOP_CNT} more times. Sleeping ${RETRY_DELAY} seconds..."
        sleep ${RETRY_DELAY}
        echo "Connection retry failed retrying ${LOOP_CNT} more times for Neo4j instance ${NICKNAME} ${NEO4J_INSTANCE_NAME} `date "+%FT%T"`" | mail -s "NEO4J INSTANCE ${NICKNAME} HEALTH CHECK FAILED" ${ADMIN_EMAIL}
        sleep ${RETRY_DELAY}
    fi
      ((LOOP_CNT--))
done

echo `date` "max attempts to check for :${NEO4J_CONNECT_PORT}, instance Unhealthy" | tee -a ${LOG_DIR}/${LOG_FILE}
INSTANCE_ID=$( wget -q -O - http://169.254.169.254/latest/meta-data/instance-id )
aws --region us-east-1 autoscaling set-instance-health --instance-id "$INSTANCE_ID" --health-status Unhealthy
echo "Neo4j instance ${NICKNAME} ${NEO4J_INSTANCE_NAME} is marked unhealthy in autoscaling group `date "+%FT%T"`" | mail -s "NEO4J INSTANCE UNHEALTHY" -a ${LOG_DIR}/${LOG_FILE} ${ADMIN_EMAIL}
rm -rf ${LOCKFILE}
}


# ============================================================================
# Main
# ============================================================================
#set -x
set_env

#--This locks the script to prevent multiple instances of it running at the same time
if mkdir "${LOCKFILE}"; then
    echo >&2 "successfully acquired lock"
    healthcheck
    #--remove lockdir when script is done
        rm -rf ${LOCKFILE}
else
    echo >&2 "Script already running"
    echo "`date "+%FT%T"` ${NICKNAME} ${NEO4J_INSTANCE_NAME} health check script problem. one instance of script is running. Another is trying to start." | mail -s "health check script problem" ${ADMIN_EMAIL}
    exit 0
fi
