*/5 * * * *  /opt/software/neo4j/scripts/neo4j_health_check.sh >> /opt/software/neo4j/neo4j-enterprise/logs/neo4j_health_check.log 2>&1
15 0 * * * /opt/software/neo4j/scripts/ebs_snapshot.py $(/opt/aws/bin/ec2-metadata | grep instance-id | awk '{print $2}') --queue https://sqs.us-east-1.amazonaws.com/447434275168/dev-mcd-replicatesnapshots-stack-ReplicateSnapshotsQueue-5V91PGDVOOU4 --target us-east-2 --retention 5 -v >> /tmp/ebs-snapshot.log 2>&1

