#!/bin/bash
# Name       : neo4j_config.sh
# Usage Info :
#        Master script containing all variables required for all Neo4j Envs
#        Script also contains a fucntion to select a slave node for maintenance
#        acitivity.
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/19 : Johney A   : created
# 2018/12/20 : Johney A   : documentation and comments update
# 2019/01/16 : Mike H     : added retention for prod, int, and qa
# ============================================================================
NEO4J_PROD_NODE_LIST="neo4j-1.mcd.sniprod,neo4j-2.mcd.sniprod,neo4j-3.mcd.sniprod"; export NEO4J_PROD_NODE_LIST
NEO4J_INT_NODE_LIST="neo4j-1.mcd.sniint,neo4j-2.mcd.sniint,neo4j-3.mcd.sniint"; export NEO4J_INT_NODE_LIST
NEO4J_QA_NODE_LIST="neo4j-1.mcd.sniqa,neo4j-2.mcd.sniqa,neo4j-3.mcd.sniqa"; export NEO4J_QA_NODE_LIST
NEO4J_DEV_NODE_LIST="neo4j-1.mcd.snidev,neo4j-2.mcd.snidev,neo4j-3.mcd.snidev"; export NEO4J_DEV_NODE_LIST
# =============================================================================
NEO4J_BACKUP_PORT=6362; export NEO4j_BACKUP_PORT
NEO4J_CONNECT_PORT=7474; export NEO4J_CONNECT_PORT
NEO4J_BOLT_PORT=7687; export NEO4J_BOLT_PORT
CONNECT_RETRIES=6; export CONNECT_RETRIES
RETRY_DELAY=30; export RETRY_DELAY
# =============================================================================
CURRENT_DATE=$( date +%Y-%m-%dT%H%M%S); export CURRENT_DATE
ADMIN_EMAIL="DL-MediaEngineering@discovery.com"; export ADMIN_EMAIL
# =============================================================================
NEO4J_PROD_BACKUP_S3="s3://prod.sni.backups/neo4j/"
NEO4J_INT_BACKUP_S3="s3://int.sni.backups/neo4j/"
NEO4J_QA_BACKUP_S3="s3://qa.sni.backups/neo4j/"
NEO4J_DEV_BACKUP_S3="s3://dev.sni.backups/neo4j/"
# =============================================================================
NEO4J_PROD_BACKUP_RET_TIME="7"
NEO4J_INT_BACKUP_RET_TIME="3"
NEO4J_QA_BACKUP_RET_TIME="3"
NEO4J_DEV_BACKUP_RET_TIME="3"
# =============================================================================
NEO4J_EXP_PATH=/opt/software/neo4j/db_backup/neo4j/export
NEO4J_PROD_EXPORT_S3="s3://prod.sni.exports/neo4j"
NEO4J_INT_EXPORT_S3="s3://int.sni.exports/neo4j"
NEO4J_QA_EXPORT_S3="s3://qa.sni.exports/neo4j"
NEO4J_DEV_EXPORT_S3="s3://dev.sni.exports/neo4j"
# =============================================================================
REFRESH_TRANSFER_S3="s3://sni.mcd.refresh.transfer"
# =============================================================================

# this scripts finds out a slave node for maintenance acitivity
# the node for maintenance would be referred by BACKUP_EXEC_NODE
get_slave_node()
{
    eval NODE_LIST='$'NEO4J_"${NEO4J_ENV}"_NODE_LIST; export NODE_LIST
    SHUFFLED_NODE_LIST=`echo $NODE_LIST | tr "," "\n" | shuf`
    for NODE in $SHUFFLED_NODE_LIST; do
        echo "checking $NODE to be slave"
        if [ "$(curl -s http://${NODE}:7474/db/manage/server/ha/slave)" = true ]
        then
            export BACKUP_EXEC_NODE=$NODE
            break
        fi
    done
    echo "Backup Node is $BACKUP_EXEC_NODE"
    export BACKUP_EXEC_NODE
}
# =============================================================================

