#!/bin/bash
# Name       : aws_rds_refresh.sh
# Usage Info : Master script for mam refresh on rds databases
#
#        The script is designed to be ran from the admin server
#         it will refresh a database from higher environments to lowers
#
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/06 : Johney A   : created
# 2019/01/28 : Mike H     : addition of refreshing a instance within the same account
# 2019/02/08 : Mike H     : Addition of snapshot & point of time instance cleanup
# 2019/02/25 : Mike H     : Addition of option groups, Security groups
# 2019/04/15 : Mike H	  : Addition of Parameter groups, Tags, Instance class
#=============================================================================
#!/bin/bash
. $HOME/.profile
. $HOME/.bashrc
function sleep_until_inst()
{
  #-- Wait until instance creation is complete
  while true; do
    IS_UP=`aws --profile $1 rds describe-db-instances --db-instance-identifier "$2" 2>&1`
    OUTPUT=`echo "$IS_UP" | grep '"DBInstanceStatus": "available"'`
    [ ! -z "$OUTPUT" ] && break
    echo waiting for 90 seconds for instance $2 creation to complete; sleep 90
  done
}

function sleep_until_snap()
{
  #-- Wait until Snapshot creation is complete
  while true; do
    IS_UP=`aws --profile $1 rds describe-db-snapshots --db-snapshot-identifier "$2" 2>&1`
    OUTPUT=`echo "$IS_UP" | grep '"Status": "creating"'`
    [ -z "$OUTPUT" ] && break
    echo waiting for 90 seconds for snapshot $2 creation to complete; sleep 90
  done
}

function aws_set_env()
{
  #-- First param (SOURCE or TARGET) Second ( DEV/INT/QA/PROD )
  [ "$2" = "DEV" ] && SUBNET_GROUP="create-mediacd-dev-vpc-rdsprivatevpcsubnets-qnkng6b3vq4b" && MULTI_AZ="no-multi-az"
  [ "$2" = "INT" ] && SUBNET_GROUP="create-mediacd-int-vpc-rdsprivatevpcsubnets-mn4unjsv6qn6" && MULTI_AZ="no-multi-az"
  [ "$2" = "QA" ] && SUBNET_GROUP="mcd-qa-vpc-rdsprivatevpcsubnets-tqawwy7yey3b" && MULTI_AZ="no-multi-az"
  [ "$2" = "PROD" ] && SUBNET_GROUP="mcd-prod-vpc-rdsprivatevpcsubnets-r8fmiecilgeq" && MULTI_AZ="multi-az"
echo ${MULTI_AZ}
  #-- Profiles as configured by the "AWS CONFIGURE COMMAND"
  if [[ "$2" = "DEV" || "$2" = "INT" ]]; then
    PROFILE=DEVINT;
    ACCOUNT_NO=447434275168
  fi
  if [[ "$2" = "PROD" || "$2" = "QA" ]]; then
    PROFILE=PRODQA;
    ACCOUNT_NO=250312325083
  fi

  if [ "$1" = "SOURCE" ]; then
    SOURCE_SUBNET_GROUP=${SUBNET_GROUP}; export SOURCE_SUBNET_GROUP
    SOURCE_PROFILE=${PROFILE}; export SOURCE_PROFILE
    SOURCE_ACCOUNT_NO=${ACCOUNT_NO}; export SOURCE_ACCOUNT_NO
    SOURCE_MULTI_AZ=${MULTI_AZ}; export SOURCE_MULTI_AZ
    SOURCE_OPTION_GROUP=`aws --profile ${SOURCE_PROFILE} rds describe-db-instances --db-instance-identifier ${SOURCE_INSTANCE} | grep OptionGroupName | awk ' { print $2}' | tr -d '"'`; export SOURCE_OPTION_GROUP

  elif [ "$1" = "TARGET" ]; then
    TARGET_SUBNET_GROUP=${SUBNET_GROUP}; export TARGET_SUBNET_GROUP
    TARGET_PROFILE=${PROFILE}; export TARGET_PROFILE
    TARGET_ACCOUNT_NO=${ACCOUNT_NO}; export TARGET_ACCOUNT_NO
    TARGET_MULTI_AZ=${MULTI_AZ}; export TARGET_MULTI_AZ
    TARGET_OPTION_GROUP=`aws --profile ${TARGET_PROFILE} rds describe-db-instances --db-instance-identifier ${TARGET_INSTANCE} | grep OptionGroupName | awk ' { print $2}' | tr -d '"'`; export TARGET_OPTION_GROUP
    TARGET_SIZE=`aws --profile ${TARGET_PROFILE} rds describe-db-instances --db-instance-identifier ${TARGET_INSTANCE} | grep AllocatedStorage | awk ' { print $2 }' | tr -d ','`; export TARGET_SIZE
    TARGET_PG=`aws rds --profile ${TARGET_PROFILE} describe-db-instances --db-instance-identifier ${TARGET_INSTANCE} | grep DBParameterGroupName | awk ' { print $2} ' | tr -d '",'`; export TARGET_PG
    TARGET_INSTANCE_CLASS=`aws rds --profile ${TARGET_PROFILE} describe-db-instances --db-instance-identifier ${TARGET_INSTANCE} | grep "DBInstanceClass" | tr -d ',"' | awk ' { print $2}'`; export TARGET_INSTANCE_CLASS
    TARGET_ENV=`aws rds --profile ${TARGET_PROFILE} describe-db-instances --db-instance-identifier ${TARGET_INSTANCE} | grep "DBInstanceIdentifier" | awk ' {print $2}' | tr -d '"'| grep -o 'dev\|int\|qa\|prod'`; export TARGET_ENV
fi
  RESTORED_INSTANCE="${SOURCE_INSTANCE}-refresh-${SUFFIX}"; export RESTORED_INSTANCE
  SNAP_ID="${RESTORED_INSTANCE}-snap"; export SNAP_ID
  ENCR_SNAP_ID="${SNAP_ID}-encr"; export ENCR_SNAP_ID
  TARGET_TEMP_INSTANCE="${TARGET_ENV}-${SOURCE_INSTANCE}-refresh-${SUFFIX}"; export TARGET_TEMP_INSTANCE
  SOURCE_TEMP_INSTANCE="${SOURCE_ENV}-${SOURCE_INSTANCE}-refresh-${SUFFIX}-s"; export SOURCE_TEMP_INSTANCE
  TARGET_SNAP_ARN="arn:aws:rds:${REGION}:${SOURCE_ACCOUNT_NO}:snapshot:"; export TARGET_SNAP_ARN
  TARGET_ENCR_SNAPSHOT="${TARGET_INSTANCE}-refresh-${SUFFIX}-snap-encr"; export TARGET_ENCR_SNAPSHOT
  BACKUP_INST_NAME="${TARGET_INSTANCE}-${SUFFIX}-backup"; export BACKUP_INST_NAME
  IS_ENCR=`aws --profile $SOURCE_PROFILE rds describe-db-instances --db-instance-identifier $SOURCE_INSTANCE | grep key`; export IS_ENCR
}


function echo_variables()
{
  echo SOURCE
  echo "    $SOURCE_INSTANCE"
  echo "    $SOURCE_PROFILE"
  echo "    $SOURCE_SUBNET_GROUP"
  echo "    $SOURCE_ACCOUNT_NO"
  echo "    $SOURCE_OPTION_GROUP"
  echo TARGET
  echo "    $TARGET_INSTANCE"
  echo "    $TARGET_PROFILE"
  echo "    $TARGET_SUBNET_GROUP"
  echo "    $TARGET_ACCOUNT_NO"
  echo "    $TARGET_OPTION_GROUP"
  echo "    $TARGET_MULTI_AZ"
  echo "    $TARGET_INSTANCE_CLASS"
  echo "    $TARGET_ENV"
  if [ "${SOURCE_PROFILE}" = "${TARGET_PROFILE}" ]; then
    RESTORE_SUBNET_GROUP=$SOURCE_SUBNET_GROUP
  else
    RESTORE_SUBNET_GROUP=$TARGET_SUBNET_GROUP
  fi
  export RESTORE_SUBNET_GROUP

  echo NAMES USED
  echo "    Point in time Restore instance              : ${RESTORED_INSTANCE}"
  echo "    Snap take from PITR instance                : ${SNAP_ID}"
  echo "    Encrypted instance at source                : ${ENCR_SNAP_ID}"
  echo "    Snapshot used for restore in target         : ${TARGET_ENCR_SNAPSHOT}"
  echo "    Temp instance created by this script        : ${TARGET_TEMP_INSTANCE}"
  echo "    Backup Instance name created by this script : ${BACKUP_INST_NAME}"
}

function restore_target_instance_same_account()
{
  #-- Point in time recovery

  aws --profile $SOURCE_PROFILE rds restore-db-instance-to-point-in-time --source-db-instance-identifier $SOURCE_INSTANCE --target-db-instance-identifier ${SOURCE_TEMP_INSTANCE} --restore-time $RESTORE_TIME --db-subnet-group-name ${TARGET_SUBNET_GROUP} --no-multi-az --option-group-name ${TARGET_OPTION_GROUP}
  echo Point in time recovery in progress
  sleep_until_inst $SOURCE_PROFILE ${SOURCE_TEMP_INSTANCE}

  echo Recovery complete

  #-- Create Snapshot from restored instance
  aws --profile $TARGET_PROFILE rds create-db-snapshot --db-instance-identifier $SOURCE_TEMP_INSTANCE --db-snapshot-identifier ${SNAP_ID}
  #-- Wait until the snapshot creation is complete
  sleep_until_snap $SOURCE_PROFILE ${SNAP_ID}

  #-- restore a temporary instance from the snapshot shared from source
  aws --profile $TARGET_PROFILE rds restore-db-instance-from-db-snapshot --db-instance-identifier $TARGET_TEMP_INSTANCE --db-snapshot-identifier "${TARGET_SNAP_ARN}${SNAP_ID}" --${TARGET_MULTI_AZ} --db-subnet-group-name ${TARGET_SUBNET_GROUP} --tags Key=Name,Value=${TARGET_INSTANCE}
  sleep_until_inst ${TARGET_PROFILE} ${TARGET_TEMP_INSTANCE}
}



function restore_target_instance()
{

#-- Point in time recovery
  aws --profile $SOURCE_PROFILE rds restore-db-instance-to-point-in-time --source-db-instance-identifier $SOURCE_INSTANCE --target-db-instance-identifier $RESTORED_INSTANCE --restore-time $RESTORE_TIME --db-subnet-group-name ${SOURCE_SUBNET_GROUP} --no-multi-az
  echo Point in time recovery in progress
  sleep_until_inst $SOURCE_PROFILE ${RESTORED_INSTANCE}

  #-- Create Snapshot from restored instance
  aws --profile $SOURCE_PROFILE rds create-db-snapshot --db-instance-identifier $RESTORED_INSTANCE --db-snapshot-identifier ${SNAP_ID}
  #-- Wait until the snapshot creation is complete
  sleep_until_snap $SOURCE_PROFILE ${SNAP_ID}

  #-- Share the snapshot with the target account
  aws --profile $SOURCE_PROFILE rds modify-db-snapshot-attribute --db-snapshot-identifier ${SNAP_ID} --attribute-name restore --values-to-add $TARGET_ACCOUNT_NO

  #-- restore a temporary instance from the snapshot shared from source
  aws --profile $TARGET_PROFILE rds restore-db-instance-from-db-snapshot --db-instance-identifier $TARGET_TEMP_INSTANCE --db-snapshot-identifier "${TARGET_SNAP_ARN}${SNAP_ID}" --${TARGET_MULTI_AZ} --db-subnet-group-name ${TARGET_SUBNET_GROUP} --tags Key=Name,Value=${TARGET_INSTANCE} Key=Environment,Value=${TARGET_ENV}

  #-- wait until temporary target instance is up
  sleep_until_inst $TARGET_PROFILE $TARGET_TEMP_INSTANCE
}

function restore_encr_target_instance()
{
  #-- SHARED-KEY is available in both accounts
  SHARED_KEY=0804ce99-309e-451b-aa3e-8d8d04767d5e
  #-- DEVQA_KEY is only available in DEVQA account
  DEVQA_KEY=14ae959d-a307-4521-b0f1-591e100298bc
  #-- ESEARCH_KEY
  ESRCH_KEY=af61a836-7991-494f-90a3-46246a087796
  #-- Point in time recovery

  aws --profile $SOURCE_PROFILE rds restore-db-instance-to-point-in-time --source-db-instance-identifier $SOURCE_INSTANCE --target-db-instance-identifier $RESTORED_INSTANCE --restore-time $RESTORE_TIME --db-subnet-group-name ${SOURCE_SUBNET_GROUP} --no-multi-az
  echo Point in time recovery in progress
  sleep_until_inst $SOURCE_PROFILE ${RESTORED_INSTANCE}

  #-- Create a snapshot from restore instance ( this is encrypted with default encryption )
  aws --profile $SOURCE_PROFILE rds create-db-snapshot --db-instance-identifier $RESTORED_INSTANCE --db-snapshot-identifier ${SNAP_ID}
  echo Creation of snapshot with default enryption in progress
  sleep_until_snap $SOURCE_PROFILE ${SNAP_ID}
  date

  if [ "${SOURCE_INSTANCE}" = "2prod-mcd-esearch" ]; then
        KEY=${ESRCH_KEY}
        echo Share the snapshot with shared key with the target account
  	    aws --profile $SOURCE_PROFILE rds modify-db-snapshot-attribute --db-snapshot-identifier ${ENCR_SNAP_ID} --attribute-name restore --values-to-add $TARGET_ACCOUNT_NO
        #-- Encrypted Snapshots must be copied into a local snapshot to be recovered, use a key shared with the target account
        aws --profile $TARGET_PROFILE rds copy-db-snapshot --source-db-snapshot-identifier ${TARGET_SNAP_ARN}${ENCR_SNAP_ID} --target-db-snapshot-identifier ${TARGET_ENCR_SNAPSHOT} --kms-key-id ${KEY}
        echo Create copy of the shared snapshot for recovery
        sleep_until_snap $TARGET_PROFILE ${TARGET_ENCR_SNAPSHOT}
        date
    else
        KEY=${DEVQA_KEY}
        echo "Create Snapshot ecnrypted with non-default encryption key to share to target Dev/qa account"
  	    aws --profile $SOURCE_PROFILE rds copy-db-snapshot --source-db-snapshot-identifier ${SNAP_ID} --target-db-snapshot-identifier ${ENCR_SNAP_ID} --kms-key-id $SHARED_KEY
  	    sleep_until_snap $SOURCE_PROFILE ${ENCR_SNAP_ID}
  	    date
  	    echo Share the snapshot with shared key with the target account
  	    aws --profile $SOURCE_PROFILE rds modify-db-snapshot-attribute --db-snapshot-identifier ${ENCR_SNAP_ID} --attribute-name restore --values-to-add $TARGET_ACCOUNT_NO
        #-- Encrypted Snapshots must be copied into a local snapshot to be recovered, use a key shared with the target account
        aws --profile $TARGET_PROFILE rds copy-db-snapshot --source-db-snapshot-identifier ${TARGET_SNAP_ARN}${ENCR_SNAP_ID} --target-db-snapshot-identifier ${TARGET_ENCR_SNAPSHOT} --kms-key-id ${KEY}
        echo Create copy of the shared snapshot for recovery
        sleep_until_snap $TARGET_PROFILE ${TARGET_ENCR_SNAPSHOT}

  fi

  #-- Restore a temporary instance from the snapshot shared from source
  aws --profile $TARGET_PROFILE rds restore-db-instance-from-db-snapshot --db-snapshot-identifier ${TARGET_ENCR_SNAPSHOT} --db-instance-identifier ${TARGET_TEMP_INSTANCE}  --${TARGET_MULTI_AZ} --db-subnet-group-name ${TARGET_SUBNET_GROUP}
  echo restore of final temporary instance in progress.
  sleep_until_inst ${TARGET_PROFILE} ${TARGET_TEMP_INSTANCE}
}

function name_change_vpc()
{
  TARGET_VPC_GROUP_ID=`aws --profile ${TARGET_PROFILE} rds describe-db-instances --db-instance-identifier "${TARGET_INSTANCE}" | grep VpcSecurityGroupId | awk ' { print $2 $3 }' | tr -d '",'`; export TARGET_VPC_GROUP_ID
  #-- changing new instance vpc to target vpc amd renaming old instance to backup
  aws --profile $TARGET_PROFILE rds modify-db-instance --db-instance-identifier ${TARGET_INSTANCE} --new-db-instance-identifier $BACKUP_INST_NAME --apply-immediately
  sleep_until_inst ${TARGET_PROFILE} ${BACKUP_INST_NAME}
  #-- changing new instance vpc to target vpc and renaming to target instance
  aws --profile $TARGET_PROFILE rds modify-db-instance --db-instance-identifier ${TARGET_TEMP_INSTANCE} --new-db-instance-identifier ${TARGET_INSTANCE} --vpc-security-group-ids "${TARGET_VPC_GROUP_ID}" --db-parameter-group-name ${TARGET_PG} --db-instance-class ${TARGET_INSTANCE_CLASS} --apply-immediately #--allocated-storage ${TARGET_SIZE} --apply-immediately
  sleep_until_inst ${TARGET_PROFILE} "${TARGET_INSTANCE}"
}

function clean_up()
{
  #-- deleting snapshots and temp instances used to refresh a instance
  if [ "${SOURCE_PROFILE}" != "${TARGET_PROFILE}" ] && [ -n "${IS_ENCR}" ]; then
    echo "deleting restored instance and encryted snapshots from ${SOURCE_PROFILE}"
    aws --profile ${SOURCE_PROFILE} rds delete-db-snapshot --db-snapshot-identifier ${SNAP_ID}
    aws --profile ${SOURCE_PROFILE} rds delete-db-instance --db-instance-identifier ${RESTORED_INSTANCE} --skip-final-snapshot
    aws --profile ${SOURCE_PROFILE} rds delete-db-snapshot --db-snapshot-identifier ${ENCR_SNAP_ID}
    aws --profile ${TARGET_PROFILE} rds delete-db-snapshot --db-snapshot-identifier ${TARGET_ENCR_SNAPSHOT}
  elif [ "${SOURCE_PROFILE}" != "${TARGET_PROFILE}" ] && [ ! -n "${IS_ENCR}" ]; then
    echo "Deleting restored instance and snapshot from ${SOURCE_PROFILE}"
    aws --profile ${SOURCE_PROFILE} rds delete-db-snapshot --db-snapshot-identifier ${SNAP_ID}
    aws --profile ${SOURCE_PROFILE} rds delete-db-instance --db-instance-identifier ${RESTORED_INSTANCE} --skip-final-snapshot
  else
    aws --profile ${SOURCE_PROFILE} rds delete-db-snapshot --db-snapshot-identifier ${SNAP_ID}
    aws --profile ${SOURCE_PROFILE} rds delete-db-instance --db-instance-identifier ${SOURCE_TEMP_INSTANCE} --skip-final-snapshot
fi
    echo "Cleanup is complete. Only backup instances left"
}
#---------------------------------------------------------------
#      Main
#---------------------------------------------------------------
#set -x

aws_set_env SOURCE ${SOURCE_ENV}
aws_set_env TARGET ${TARGET_ENV}

echo_variables
date


  if [ "${SOURCE_PROFILE}" = "${TARGET_PROFILE}" ]; then
    TARGET_TEMP_INSTANCE="${RESTORED_INSTANCE}"; export TARGET_TEMP_INSTANCE
    echo "same account"
    restore_target_instance_same_account
#----checking if instance is encrypted
  elif  [ ! -n "$IS_ENCR" ]; then
    echo not encrypted
    restore_target_instance;
    else
    echo encrypted
    restore_encr_target_instance;
  fi

name_change_vpc
clean_up
  echo "refresh complete"
  echo "${BACKUP_INST_NAME}" >> /home/mikehawkins/media-engineering/mam-refresh/database/mam_run_dir/instance_delete_list.txt
#---------------------------------------------------------------
#      End of Main script
#---------------------------------------------------------------

