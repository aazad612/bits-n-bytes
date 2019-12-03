#!/bin/bash
# Name       : neo4j_infa_export.sh
# Usage Info : 
#        The script exports data from neo4j instances needed for informatica workflows. 
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/19 : Johney A   : created
# ============================================================================
. $HOME/.bash_profile
. $NS/pkg_neo4j_param.sh
. $NS/pkg_common.sh

my_help()
{
echo "
    NAME   : Neo4j Backup script
    USAGE  :
        neo4j_infa_export.sh <neo4j_env>
    "
}

set_env()
{
    eval EXPORT_S3='$'NEO4J_"${NEO4J_ENV}"_EXPORT_S3; export EXPORT_S3
    #-- File Locations
    export WORK_DIR=$NB/$NEO4J_ENV
    export LOG_FILE=$WORK_DIR/neo4j_infa_export_${CURRENT_DATE}.log
}

get_env()
{
    echo "Adminstrator Email  : $ADMIN_EMAIL"
    echo "Export S3 Bucket    ; $EXPORT_S3"
    echo "Log file is         : $LOG_FILE"
    echo "Export location is  : $NEO4J_EXP_PATH"
}

export_for_infa()
{
    # this will create files on the BACKUP_EXEC_NODE node and not on this server
    # copy the exports to the s3 bucket from the BACKUP_EXEC_NODE using a ssh command
    cd /opt/workdir/neo4j/scripts
    cat neo4j_infa_export.cql | cypher-shell -a bolt://${BACKUP_EXEC_NODE}:${NEO4J_BOLT_PORT} -u export_user -p exportuser 
    echo "aws s3 cp ${NEO4J_EXP_PATH} ${EXPORT_S3} --no-progress --recursive --exclude "'*.json' | ssh $BACKUP_EXEC_NODE 'bash -s ' 
}

# ============================================================================
# Main
# ============================================================================

NEO4J_ENV=$1; export NEO4J_ENV
[ -f $NEO4J_ENV ] && exit_script "Cannot execute without a valid NEO4J_ENV as first parameter"

set_env
get_env
get_env >> $LOG_FILE

get_slave_node  >> $LOG_FILE 

export_for_infa >> $LOG_FILE

send_export_email $NEO4J_ENV "Neo4j CSV Export completed for Informatica" $LOG_FILE

# ============================================================================

