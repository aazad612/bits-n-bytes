#!/bin/bash
# Name       : neo4j-cf-launch.sh
# Usage Info : This launch script improvises over the current cloud formation
#            launch shell script by Eliminating all pull files using a prebaked
#            AMI. This will also maintain consistency across all environments.
#
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/16 : Vamsi P     : created
# 2018/12/16 : Johney A    : Changed usage info
# ============================================================================
sudo su -

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

#===============================================================================
# Hostname and Network Setup
#===============================================================================
FULL_HOST_NAME=$1

# Changing the shell prompt to reflect correct DNS_NAME
echo "export NICKNAME=${FULL_HOST_NAME}" > /etc/profile.d/prompt.sh
sed -i 's|u@\\h|u@\\$NICKNAME|g' /etc/bashrc

HOST_NAME=`echo $FULL_HOST_NAME | awk -F"." '{print $1 }'`
NODE_ID=`echo $HOST_NAME | tail -c 2`
ENV=`echo $FULL_HOST_NAME | tail -c 4` # dev/qa/int/prod
ZONE=`echo $FULL_HOST_NAME | awk -F"." '{ print $2"."$3 }'` # mcd.snidev
LOCAL_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' |cut -d/ -f1)
TTL=60
export RECRD="${HOST_NAME} ${TTL} A ${LOCAL_IP}"
/usr/local/bin/cli53 rrcreate -d --replace $ZONE "$RECRD"
echo "$LOCAL_IP                $FULL_HOST_NAME"      >> /etc/hosts

#===============================================================================
#Volume Mount and Neo4j
#===============================================================================
mkdir /opt/software
/bin/mount /dev/xvdp /opt/software
echo '/dev/xvdp /opt/software auto defaults 0 0' >> /etc/fstab
usermod -md /opt/software/neo4j neo4j


#Copy bash profile from S3 bucket to /opt/software/neo4j
aws s3 cp s3://sni.mcde.config/neo4j-main/bash_profile /opt/software/neo4j/.bash_profile
chmod 700 /opt/software/neo4j/.bash_profile
chown neo4j:neo4j /opt/software/neo4j/.bash_profile
echo "sudo su - neo4j" >> /home/ec2-user/.bash_profile

#===============================================================================
# Newrelic License
#===============================================================================

[[ $ENV=="dev" ]] && NR_LICENSE="593e9297d7d8400976d534757b870c62b23be1fa"
[[ $ENV=="int" ]] && NR_LICENSE="591bd152a72c092627467366bfa4d7089c1ea5e7"
[[ $ENV=="qa" ]] && NR_LICENSE="511e03fb2edb03fe11feff15651449e4ebc4abf1"
[[ $ENV=="prod" ]] && NR_LICENSE="99da8ae7ed4c3671d04c4bcbb442a784fcde99db"

echo "license_key: $NR_LICENSE"   >> /etc/newrelic_infra.yml
echo "display_name: $HOST_NAME"   >> /etc/newrelic_infra.yml
echo "custom_attributes:"         >> /etc/newrelic_infra.yml
echo " Environment: $ENV"         >> /etc/newrelic_infra.yml
echo " BusinessUnit: media"       >> /etc/newrelic_infra.yml
echo " Project: neo4j"            >> /etc/newrelic_infra.yml
echo " Platform: neo4j"           >> /etc/newrelic_infra.yml
echo " Location: cloud"           >> /etc/newrelic_infra.yml

#===============================================================================
# 	neo4j_health_check.sh download and set crontab
#===============================================================================

aws s3 cp s3://sni.mcde.config/neo4j-main/neo4j_health_check.sh /opt/software/neo4j/scripts/neo4j_health_check.sh
chmod 700 /opt/software/neo4j/scripts/neo4j_health_check.sh
aws s3 cp s3://sni.mcde.config/neo4j-main/cronentry.txt /opt/software/neo4j/cronentry.txt

sudo -u neo4j crontab /opt/software/neo4j/cronentry.txt
sudo -u neo4j neo4j start 

