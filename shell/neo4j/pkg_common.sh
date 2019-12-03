#!/bin/bash
# Name       : commonpkg.sh
# Usage Info :
#        This script contains functions that are useful for most shell scripts.
#        1. Data manipulation is not offered natively in bash
#        2. Functions for logging
#        3. Easy access to email function
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/19 : Johney A   : created
# 2018/12/20 : Johney A   : update variable names in logging section
# =============================================================================

# =============================================================================
#  Date Functions
# Usage Info :
# convert a date into a UNIX timestamp
#    stamp=$(date2stamp "2006-10-01 15:00")
#    echo $stamp
#
# from timestamp to date
#    stamp2date $stamp
#
# calculate the number of days between 2 dates
#    # -s in sec. | -m in min. | -h in hours  | -d in days (default)
#    dateDiff -s "2006-10-01" "2006-10-32"
#    dateDiff -m "2006-10-01" "2006-10-32"
#    dateDiff -h "2006-10-01" "2006-10-32"
#    dateDiff -d "2006-10-01" "2006-10-32"
#    dateDiff  "2006-10-01" "2006-10-32"
#
# number of seconds between two times
#    dateDiff -s "17:55" "23:15:07"
#    dateDiff -m "17:55" "23:15:07"
#    dateDiff -h "17:55" "23:15:07"
#
# number of minutes from now until the end of the year
#    dateDiff -m "now" "2006-12-31 24:00:00 CEST"
#
# Other standard goodies from GNU date not too well documented in the man pages
#    assign a value to the variable dte for the examples below
#    dte="2006-10-01 06:55:55"
#    echo $dte
#
# add 2 days, one hour and 5 sec to any date
#    date --date "$dte  2 days 1 hour 5 sec"
#
# substract from any date
#    date --date "$dte 3 days 5 hours 10 sec ago"
#    date --date "$dte -3 days -5 hours -10 sec"
#
# or any mix of +/-. What will be the date in 3 months less 5 days
#    date --date "now +3 months -5 days"
#
# time conversions into ISO-8601 format (RFC-3339 internet recommended format)
#    date --date "sun oct 1 5:45:02PM" +%FT%T%z
#    date --iso-8601=seconds --date "sun oct 1 5:45:02PM"
#    date --iso-8601=minutes
#
#    # time conversions into RFC-822 format
#    date --rfc-822 --date "sun oct 1 5:45:02PM"
#
# =============================================================================

date2stamp () {
    date --utc --date "$1" +%s
}

stamp2date (){
    date --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}

date_diff (){
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    dte1=$(date2stamp $1)
    dte2=$(date2stamp $2)
    diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    echo $((diffSec/sec*abs))
}

# =============================================================================
# logging and reporting functions
# =============================================================================

exit_script()
{
    LOG_DATA=$1
    log_data "ERROR: $LOG_DATA"
    exit 0
}

# Standard logging
log_data()
{
    LOG_DATA=$1
    date "+%Y-%b-%d %T: $LOG_DATA"
}


send_email()
{
    ENV=$1          #Prod/Dev/Qa/Int
    SUBJECT=$2
    LOG_FILE=$3
    FROM_ADMIN_EMAIL="DL-MediaEngineering@discovery.com"; export FROM_ADMIN_EMAIL
    TO_ADMIN_EMAIL="aazad_johney@discovery.com"; export TO_ADMIN_EMAIL
    tr -d ’\015’ < $LOG_FILE | mailx -s "$ENV - ${SUBJECT}" -r $ADMIN_EMAIL $ADMIN_EMAIL 
}

# =============================================================================

