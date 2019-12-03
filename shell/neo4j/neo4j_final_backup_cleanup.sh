#!/bin/bash
# Name       : backup_final.sh
# Usage Info :
#        Final backup script delete files older than 7 days from s3,
#				 delete files older than 3 days from local drive,
#				 gzip what is not gzipped and delete bkp folders once gzip successful,
#				 check if the gzip exists in the s3 if not put it in s3.
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/24 : Vamsi P   : created
# ============================================================================

. $HOME/.bash_profile

. $NS/pkg_neo4j_param.sh

. $NB/pkg_common.sh

cd $NB

set_env()
{
	NEO4J_ENV=DEV
	eval BACKUP_S3='$'NEO4J_"${NEO4J_ENV}"_BACKUP_S3; export BACKUP_S3
	BACKUP_LOCATION=$NB/$NEO4J_ENV
	eval BACKUP_RETENTION_S3='$'NEO4J_"${NEO4J_ENV}"_BACKUP_RET_S3; export BACKUP_RETENTION_S3
    eval BACKUP_RETENTION_LOCAL='$'NEO4J_"${NEO4J_ENV}"_BACKUP_RET_LOCAL; export BACKUP_RETENTION_LOCAL
}

get_env()
{
	echo "BACKUP_S3              : $BACKUP_S3"
	echo "BACKUP_RETENTION_S3    : $BACKUP_RETENTION_S3"
    echo "BACKUP_RETENTION_LOCAL : $BACKUP_RETENTION_LOCAL"
}

delete_s3_old_backup()
{
    ###  This is to delete backup tar.gz from s3 older than 7 days

    S3_FILES=`aws s3 ls "${BACKP_S3}" --recursive | awk '{print $4}'`

    for S3_FILE in ${S3_FILES[@]}; do
		    DATE_EXTRACT_S3=${S3_FILE:13:10}
		    echo $DATE_EXTRACT_S3
		    S3_HOW_OLD=$(date_diff $DATE_EXTRACT_S3 `date +%F`)

		    if [[ $S3_HOW_OLD > $BACKUP_RETENTION_S3 ]]; then
		      aws s3 rm "${BACUP_S3}"/${S3_FILE}
		    fi
    done
}

local_backups_to_s3()
{
    ###  This is backup local files to S3 after tar.gz and delete from local if local file > 3 days old

    cd $BACKUP_LOCATION
    BACKUPS=`ls | grep neo | grep -v "export"`

    for BACKUP_NAME in ${BACKUPS[@]}; do
        DATE_EXTRACT_LOCAL=${BACKUP_NAME:13:10}
        echo $DATE_EXTRACT_LOCAL
        HOW_OLD_LOCAL=$(date_diff $DATE_EXTRACT_LOCAL `date +%F`)
		echo $HOW_OLD_LOCAL

		    if [[ $HOW_OLD_LOCAL> $BACKUP_RETENTION_LOCAL ]]; then
                echo $BACKUP_NAME : old file date is $DATE_EXTRACT_LOCAL and today date is `date +%F`
                echo "delete the backup"
			    rm ${BACKUP_NAME}
            else
                echo $BACKUP_NAME : new file date is $DATE_EXTRACT_LOCAL and today date is `date +%F`

	###  Check if tar.gz already exists in s3 if not copy to S3

		    if [[ $BACKUP_NAME == *tar.gz* ]]; then
                echo "check in aws s3 if exists nothing else copy there"
				aws s3 ls "${BACKP_S3}"/"${BACKUP_NAME}"
            if [[ $? -ne 0 ]] ; then
				aws s3 cp "${BACKUP_NAME}"  "${BACKP_S3}"
	        fi
                echo "check s3 vs ebs cost"
            else
                if [[ ! -f "${BACKUP_NAME}.tar.gz" ]]; then
                    tar cvfz "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
                    aws s3 cp "${BACKUP_NAME}.tar.gz" "${BACUP_S3}"
                    echo "deleting ${BACKUP_NAME}"
					rm  "${BACKUP_NAME}"
                fi
            fi
        fi
    done
}

set_env
get_env
delete_s3_old_backup
local_backups_to_s3

