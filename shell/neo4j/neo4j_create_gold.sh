#!/bin/bash
# Name       : neo4j-create-gold.sh
# Usage Info : This script improvises over the current cloud formation
#            launch shell script by Eliminating all pull files using a prebaked
#            AMI. This will also maintain consistency across all environments.
#
# ==================================
# Modification Log
# ==================================
# Date       : Author     : Comments
# ----------------------------------
# 2018/12/06 : Johney A    : created
# 2018/12/08 : Vamsi P     : validation and bug fixes
# ============================================================================
# set -x
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

#===============================================================================
# OS + Neo4j User Setup
#===============================================================================

#=== create user neo4j ===
useradd neo4j
echo "neo4j   ALL=(ALL)   NOPASSWD:    ALL"      >> /etc/sudoers

#=== create conf files ===
echo "neo4j   soft    nofile  40000"             >> /etc/security/limits.conf
echo "neo4j   hard    nofile  40000"             >> /etc/security/limits.conf
echo "session    required   pam_limits.so"       >> /etc/pam.d/su

#===============================================================================
# File Download
#===============================================================================
cd /root
curl -v -O -L -b oraclelicense=accept-securebackup-cookie http://download.oracle.com/otn-pub/java/jdk/8u121-b13/e9e7ea248e2c4826b92b3f075a80e441/jdk-8u121-linux-x64.rpm
curl -v -O http://download.newrelic.com/pub/newrelic/el5/i386/newrelic-repo-5-3.noarch.rpm
sudo curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/6/x86_64/newrelic-infra.repo

#===============================================================================
# Software Install as Root
#===============================================================================
yum update -y
yum install -y mailx

sudo yum install python34
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py --user
pip install boto3

echo "pip install awscli --upgrade --user" | sudo su - neo4j
echo "pip install awscli --upgrade --user" | sudo su - ec2-user

wget -c https://github.com/barnybug/cli53/releases/download/0.8.12/cli53-linux-amd64
mv cli53-linux-amd64 /usr/local/bin/cli53
chmod +x /usr/local/bin/cli53

#== Java Setup =================================================================
#=== LATEST RELEASE ===
#rpm -ivh jdk-8u191-linux-x64.rpm
#=== RELEASE INSTALLED WITH Neo4j 3.1.1 ===
rpm -ivh jdk-8u121-linux-x64.rpm
yum update -y

#unzip newrelic-java-3.37.0.zip -d $NH
rpm -ivh newrelic-repo-5-3.noarch.rpm
yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
yum install newrelic-infra -y
