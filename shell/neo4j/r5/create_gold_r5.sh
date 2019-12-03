#!/bin/bash
# Name       : Gold Image Creation Script for Neo4j R5 servers
# Usage Info : Master script for creating neo4j gold image.
#       Using a well formed AMI reduces the need for adhoc system updates
#       this image will also maintain the environments consistent. 
#
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/13 : Johney A   : created
# ============================================================================

# set -x
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi
CURVERSION=neo4j311

#===============================================================================
# OS + Neo4j User Setup
#===============================================================================

#=== create user neo4j ===
useradd neo4j
echo "neo4j   ALL=(ALL)   NOPASSWD:    ALL"      >> /etc/sudoers
echo "sudo su - neo4j"                           >> /home/ec2-user/.bash_profile

#=== create conf files ===
echo "neo4j   soft    nofile  40000"             >> /etc/security/limits.conf
echo "neo4j   hard    nofile  40000"             >> /etc/security/limits.conf
echo "session    required   pam_limits.so"       >> /etc/pam.d/su

#===============================================================================
# File Download
#===============================================================================
cd /opt/backup/install
aws s3 sync s3://sni.mcde.config/neo4jv3 .

#===============================================================================
# Software Install as Root
#===============================================================================
yum update -y
yum install -y mailx
#-- Java
#curl -v -O -L -b oraclelicense=accept-securebackup-cookie http://download.oracle.com/otn-pub/java/jdk/8u191-b12/2787e4a523244c269598db4e85c51e0c/jdk-8u191-linux-x64.rpm
#curl -v -O -L -b oraclelicense=accept-securebackup-cookie http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/jdk-8u121-linux-x64.rpm
aws s3 cp https://s3.amazonaws.com/sni.mcde.config/neo4j/software/jdk-8u121-linux-x64.rpm .
rpm -ivh jdk-8u121-linux-x64.rpm

#-- Newrelic
curl -v -O http://download.newrelic.com/pub/newrelic/el5/i386/newrelic-repo-5-3.noarch.rpm
sudo curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/6/x86_64/newrelic-infra.repo
rpm -ivh newrelic-repo-5-3.noarch.rpm
yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
yum install newrelic-infra -y

#-- Pip
sudo yum install python34
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py --user

#-- awscli
echo "pip install awscli --upgrade --user" | sudo su - neo4j
echo "pip install awscli --upgrade --user" | sudo su - ec2user

#-- cli53
wget -c https://github.com/barnybug/cli53/releases/download/0.8.12/cli53-linux-amd64
mv cli53-my-platform /usr/local/bin/cli53
chmod +x /usr/local/bin/cli53

#================================================================================
# Create and Mount FS
#================================================================================
/sbin/mkfs.ext4 /dev/sdb
/sbin/mkfs.ext4 /dev/sdc
/sbin/mkfs.ext4 /dev/sdd

mkdir -p /opt/software
mkdir -p /opt/database
mkdir -p /opt/backup

/bin/mount /dev/sdb /opt/software
/bin/mount /dev/sdc /opt/database
/bin/mount /dev/sdd /opt/backup

echo '/dev/sdb /opt/software auto defaults 1 1' >> /etc/fstab
echo '/dev/sdc /opt/database auto defaults 1 1' >> /etc/fstab
echo '/dev/sdd /opt/backup auto defaults 1 1'   >> /etc/fstab


mkdir -p /home/neo4j/scripts
mkdir -p /opt/software/$CURVERSION
mkdir -p /opt/database/$CURVERSION/data/databases
mkdir -p /opt/database/$CURVERSION/data/dbms
mkdir -p /opt/backup/$CURVERSION/cbackup       # location for canonical backups
mkdir -p /opt/backup/$CURVERSION/export        # location for user readable backups
mkdir -p /opt/backup/$CURVERSION/import        # location for data files to import
mkdir -p /opt/backup/$CURVERSION/install       # location for intabllables
