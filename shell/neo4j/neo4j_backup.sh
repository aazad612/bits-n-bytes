#!/bin/bash
# Name       : neo4j_backup.sh
# Usage Info : Master script for creating neo4j backups.
#
#        The script is designed to be scheduled from a remote server
#        Script requries Java 1.2 to execute successfully.
#
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/06 : Johney A   : created
# 2018/12/10 : Johney A   : Addition of node lists
# 2019/01/16 : Mike H     : Removed export, Added backup tar, cp to s3, amd delete
# ============================================================================
. $HOME/.bash_profile
. $NS/pkg_neo4j_param.sh
. $NS/pkg_common.sh

my_help()
{
 echo "
    NAME   : Neo4j Backup script
    USAGE  : neo4j_backup.sh <neo4j_env> <backup_retention_period>
    "
}

set_env()
{
    #-- File Locations
    WORK_DIR="/opt/workdir/neo4j"; export WORK_DIR 
    BACKUP_DIR="${WORK_DIR}/backups/${NEO4J_ENV}"; export BACKUP_DIR
    [ ! -d ${BACKUP_DIR} ] && mkdir -p $BACKUP_DIR
    
    #-- Setup file_names
    eval BACKUP_S3='$'NEO4J_"${NEO4J_ENV}"_BACKUP_S3; export BACKUP_S3
    BACKUP_NAME="neo4j_backup_${CURRENT_DATE}.bkp"; export BACKUP_NAME
    BACKUP_LOG_FILE="${BACKUP_DIR}/neo4j_backup_${CURRENT_DATE}.log"; export BACKUP_LOG_FILE
    eval RET_TIME='$'NEO4J_"${NEO4J_ENV}"_BACKUP_RET_TIME; export RET_TIME
}

get_env()
{
    echo "Adminstrator Email  : $ADMIN_EMAIL"
    echo "Backup Directory    : $BACKUP_DIR"
    echo "Backup Log File     : $BACKUP_LOG_FILE"
    echo "Backup Name is      : ${BACKUP_NAME}"
    echo "Backup S3 bucket    : $BACKUP_S3"
    echo "Retention Time Is   : $RET_TIME"
}

neo_backup()
{
    neo4j-admin backup --from=${BACKUP_EXEC_NODE}:${NEO4J_BACKUP_PORT} --backup-dir=$BACKUP_DIR --check-consistency=true --fallback-to-full=true --cc-report-dir=$LOG_DIR --name=$BACKUP_NAME >> $BACKUP_LOG_FILE
    send_email $NEO4J_ENV "Neo4j backup completed" $BACKUP_LOG_FILE
    cd $BACKUP_DIR
    tar -czf ${BACKUP_NAME}.tar.gz ${BACKUP_NAME}				##Grants full access to dev account for the objects prod uploads to dev's s3 buckets
    aws s3 cp ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz  $BACKUP_S3 --grants full=id=3cf2c4d8156b3567dcb0a6686b6a4712335423f7f3df4b0bd1dc544f49c78ab7
}

backup_delete()
{
    find ${BACKUP_DIR} -type d -name "*.bkp" -mtime +${RET_TIME} -print -exec rm -rf {} \;
    find ${BACKUP_DIR} -type f -name "*.log" -mtime +${RET_TIME} -print -exec rm -rf {} \;
    find ${BACKUP_DIR} -type f -name "*.bkp.tar.gz" -mtime +${RET_TIME} -print -exec rm -rf {} \;
}




# ============================================================================
# Main
# ============================================================================

NEO4J_ENV=$1; export NEO4J_ENV
[ -f $NEO4J_ENV ] && exit_script "Cannot execute without a valid NEO4J_ENV as first parameter"

set_env
get_env | tee -a $BACKUP_LOG_FILE
get_slave_node >> $BACKUP_LOG_FILE
echo $BACKUP_EXEC_NODE
neo_backup
backup_delete
