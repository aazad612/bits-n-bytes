#!/bin/bash
#
# Modified by   : Johney Aazad
# Modified Date : 2018/05/17
# Comments      : Created this file

# Get the script name including the full path
DATETIME=`date "+%Y%m%d_%H%M%S"`
vDir="$( cd "$( dirname "$0" )" && pwd )/"
vBase=`basename "$0"`
vScript="$vDir""$vBase"
mkdir "$vDir"output 2>/dev/null
vOut=$vDir"output/"`echo $vBase | gawk -F. -v sid=$1 '{ print $1 }'`"_${DBNAME}_${BKUPTY}_$DATETIME.log"

. $HOME/setenv/init.sh >/dev/null 2>/dev/null
setdb 112CLIENT >/dev/null 2>/dev/null
export PASS=`openssl enc -d -des-ecb -K  -in $PASSWORDFILE`


# Standard logging
LogData()
{
   date "+%Y-%b-%d %T: $1" >> $vOut
#  echo $1
}

# Error logging
ExitScript()
{
  echo $1
  LogData "ERROR: $1"
  LogData "******************** End of the script ********************"
  exit 0
}

# Check if the database is available to run rman commands. Error out if it's not available
CheckDB()
{
  DBSTATUS=""
  DBSTATUS=`sqlplus -s <<EOF
  sys/"${PASS}"@${DBNAME} as sysdba
  set pages 0
  set head off
  set feed off
  SELECT status from v\\$instance;
  exit;
EOF`
  if [[ $DBSTATUS != "OPEN" && $DBSTATUS != "MOUNTED" && $DBSTATUS != "READ ONLY WITH APPLY" ]]; then
    ExitScript "$DBNAME is not running in OPEN or MOUNTED or READ ONLY mode. Status is $DBSTATUS"
  fi
}

# According to Requested Encryption check wallet and generate RMAN Commands
CheckEncryption()
{
if [ ${ENCRYPT} = NO ]; then
  CMDENCR="SET ENCRYPTION OFF;"
else
  WALLET=""
  WALLET=`sqlplus -s <<EOF
  sys/"${PASS}"@${DBNAME} as sysdba
  set pages 0 head off feed off
  select status from v\\$encryption_wallet;
  exit;
EOF`

[[ ${WALLET} = "CLOSED" ]] && ExitScript "Encryption Requested but Wallet not available"
  CMDENCR="SET ENCRYPTION ON;"
fi
}

DISKBKP=YES
TAPEBKP=YES
ENCRYPT=NO
# The value of the variable COMPRESS below is directly used in the RMAN Command and hence left blank
COMPRESS=""

# Aceept Input Parameters

while [ ! -z ${1} ]
do
case $1 in
  -d | -db )
      [ -z ${2} ] && ExitScript "Please specify the database name"
      DBNAME=$2
      CheckDB "$DBNAME"
      shift 2
      ;;
  -b | -bkptype )
      if ! [[ $2 = "FULL" || $2 = "INC0" || $2 = "INC1" || $2 = "ARCH" ]]; then
      ExitScript "Invalid backup type $2. Backup type must be [FULL|INC0|INC1|ARCH]"
      fi
      BKUPTYP=$2
      shift 2
      ;;
  -c | -compress )
      COMPRESS="COMPRESSED "
      shift
      ;;
  -h )
      echo "
      NGS ORACLE DATABASE BACKUP SCRIPT
      SYNTAX
      Mandatory
        -d or -db        <ARG>      DATABASE NAME
        -b or -bkptype   <ARG>      BACKUP TYPE [FULL|INC0|INC1|ARCH]
      Optional
        -c or -compress             COMPRESSED BACKUP
        -h                          HELP MENU
        -nd                         WRITE THE BACKUP DIRECTLY TO TAPE
        -e                         NON ENCRYPTED BACKUP
        -nt                         DISK ONLY BACKUP, DO NOT WRITE TO TAPE
        -m | -mail                  SEND ERRORS to the RECIPIENT MAIL_NOTIFY
        -r or -retention <ARG>      ARCHIVELOG RETENTION IN HOURS
        "
      exit
      ;;
  -nd )
      DISKBKP=NO
      shift
      ;;
  -e )
      ENCRYPT=YES
      shift
      ;;
  -nt )
      TAPEBKP=NO
      shift
      ;;
  -m | -mail )
      [ -z ${2} ] && ExitScript "Please specify the Email Recipient List"
      EMAIL_NOTIFY=$2
      shift 2
      ;;
  -r | -retention )
#     ! [[ $BKUPTYP = "ARCH" ]] && ExitScript "Backup Type is not ARCH"
      [ -z ${2} ] && ExitScript "Please specify a value for Archive log retention"
      ! [[ $2  =~ ^[0-9]+$ ]] && ExitScript "Invalid Value Specified for Archive Log Retention"
      RETENTION=$2
      shift 2
      ;;
  *)
      ExitScript "Error: Unknown option: $1"
      ;;
esac
done

# Database and Backup Type are Mandatory
[ -z $DBNAME ] && ExitScript "Database Name not specified"
[ -z $BKUPTYP ] && ExitScript "Backup type not specified"
LogData "Commencing ${COMPRESS}${BKUPTYP} backup for $DBNAME"

# Determine Archive Log Retention
if [ -z $RETENTION ]; then
  RETENTION=48
  echo "Archivelog Retention not specified, default value of 48 hours would be used"
else
  echo "Archivelog Retention of $RETENTION hours specified"
fi

# Create output directoy in the script base
vOut=$vDir"output/"`echo $vBase | gawk -F. -v sid=$1 '{ print $1 }'`"_${DBNAME}_${BKUPTYP}_$DATETIME.log"
set -x
LogData "******************** Start of script ********************"
LogData "Directory    : $vDir"
LogData "Script       : $vScript"
LogData "Base         : $vBase"
LogData "Output File  : $vOut"

TAG="${DBNAME}_${BKUPTYP}_${DATETIME}"
TAG=${TAG:0:30}
LogData "Database Name: $DBNAME"
LogData "Backup Type  : $BKUPTYP"
LogData "Backup Tag   : $TAG"

# Check if the database is open or mounted
CheckDB "$DBNAME"

#Check for Encryption
if [ $ENCRYPT=YES ]; then
   CheckEncryption "$DBNAME"
fi

RMAN_CONNECT="connect target sys/\""${PASS}"\"@${DBNAME}\n"
# Database is up and input parameters are validated. Start RMAN backup commands

# Send backups to fast recovery area first
if [ $DISKBKP = "YES" ]; then
   if [ $BKUPTYP = "FULL" ]; then
      DISK_COMMAND="BACKUP AS ${COMPRESS}BACKUPSET DEVICE TYPE DISK DATABASE TAG '$TAG' INCLUDE CURRENT CONTROLFILE;"
   elif [ $BKUPTYP = "INC0" ]; then
      DISK_COMMAND="BACKUP AS ${COMPRESS}BACKUPSET DEVICE TYPE DISK INCREMENTAL LEVEL 0 DATABASE TAG '$TAG' INCLUDE CURRENT CONTROLFILE;"
   elif [ $BKUPTYP = "INC1" ]; then
      DISK_COMMAND="BACKUP AS ${COMPRESS}BACKUPSET DEVICE TYPE DISK INCREMENTAL LEVEL 1 DATABASE TAG '$TAG' INCLUDE CURRENT CONTROLFILE;"
   elif [ $BKUPTYP = "ARCH" ]; then
      DISK_COMMAND="BACKUP AS ${COMPRESS}BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES TAG '$TAG';"
   fi
   DISK_SCRIPT=${CMDENCR}${DISK_COMMAND}
   LogData "$DISK_SCRIPT"
   echo -e "$RMAN_CONNECT $DISK_SCRIPT" | rman | gawk '{print strftime("%Y-%b-%d %H:%M:%S: "), $0; fflush(); }' >> $vOut
fi

# Send backpsets/archivelogs to tape
if [ $TAPEBKP = "YES" ]; then
   TAPE_COMMAND="SET ENCRYPTION OFF; BACKUP DEVICE TYPE SBT_TAPE BACKUPSET ALL NOT BACKED UP 1 TIMES TAG '$TAG';"
   TAPE_SCRIPT=${TAPE_COMMAND}
   LogData "$TAPE_SCRIPT"
   echo -e "$RMAN_CONNECT $TAPE_SCRIPT" | rman | gawk '{print strftime("%Y-%b-%d %H:%M:%S: "), $0; fflush(); }' >> $vOut
   # Delete archivelogs backed up to tapes
   DELETE_ARCH="DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE SBT_TAPE COMPLETED BEFORE 'SYSDATE-$RETENTION/24';";
   LogData "$DELETE_ARCH"
   echo -e "$RMAN_CONNECT $DELETE_ARCH" | rman | gawk '{print strftime("%Y-%b-%d %H:%M:%S: "), $0; fflush(); }' >> $vOut
fi

# Delete backupsets backed up to tapes
# BACKED UP n TIMES TO DEVICE TYPE SBT_TAPE is not availalbe for backupsets
DELETE_LIST=$vDir"output/"`echo $vBase | gawk -F. -v sid=$1 '{ print $1 }'`"_${DBNAME}_${BKUPTYP}_$DATETIME.rcv"
rm -f $DELETE_LIST
echo
LogData "Delete List File: $DELETE_LIST"

if [ $DISKBKP = "YES" ]; then
   CROSSCHECK="CROSSCHECK BACKUP DEVICE TYPE DISK;"
   echo -e "$RMAN_CONNECT $CROSSCHECK" | rman | gawk '{print strftime("%Y-%b-%d %H:%M:%S: "), $0; fflush(); }' >> v$Out
   sqlplus -s << EOF >> $DELETE_LIST
   sys/"${PASS}"@${DBNAME} as sysdba
   set pages 0
   set head off
   set feed off
   SELECT DISTINCT 'DELETE NOPROMPT BACKUPSET ' || BS_KEY || ' DEVICE TYPE DISK;' DEL_BACKUP
     FROM V\$BACKUP_FILES
    WHERE BS_DEVICE_TYPE LIKE '%SBT_TAPE%'
      AND BS_COMPLETION_TIME < TRUNC(SYSDATE-1)
      AND DEVICE_TYPE = 'DISK'
      AND BS_COPIES >=2
    ORDER BY DEL_BACKUP;
EOF

   echo -e "$RMAN_CONNECT @$DELETE_LIST" | rman | gawk '{print strftime("%Y-%b-%d %H:%M:%S: "), $0; fflush(); }' >> $vOut
fi

#rm -f $DELETE_LIST
# Resync recovery catalog
# Need to create catalog first
#set -x
#if [[ "$EMAIL_NOTIFY" != "" ]]; then
#  SUBJECT="BACKUPREPORT FOR $DBNAME $BKUPTYP"
#  LogData "sending email to $EMAIL_NOTIFY"
#  # Below command is repeated in the sendmail call to preserve formatting.
#  MAILBODY=`cat ${vOut} | grep 'RMAN'`
#  if [[ $MAILBODY != "" ]]; then
#     # Email Report
#     (
#       echo "Subject: ${SUBJECT}"
#       echo "To: ${EMAIL_NOTIFY}"
#       echo "MIME-Version: 1.0"
#       echo "Content-Type: text/html"
#       echo "Content-Disposition: inline"
##       echo "<pre>"
#       cat ${vOut}
#       echo "</pre>"
#     ) | /usr/sbin/sendmail ${EMAIL_NOTIFY}
#  fi
#fi

LogData "******************** End of script ********************"
