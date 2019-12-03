#!/usr/bin/env python3
import boto3
import sys
import click
import csv

####################################################################################################

session = boto3.Session(profile_name='DEVINT')
sns = session.client('sns')

####################################################################################################

# Top function group for click
@click.group()
def cli():
    """Commands for SNS"""
    pass

####################################################################################################

# Function to list dead numbers
# Not complete
@cli.command('list_dead_numbers')
def list_dead_numbers():
    """List opted out phone numbers"""
    phones = sns.list_phone_numbers_opted_out()
    numbers = phones['phoneNumbers']
    for num in numbers:
        print(str(num))

# Topics and subscribers
@cli.command('list_topics_and_subs')
def list_topics_and_subs():
    """list_topics_and_subscriptions"""

    with open('sns_dev_new.csv','w') as csvfile:
        writer = csv.writer(csvfile)
        # write the header record for the CSV File
        writer.writerow(['topic', 'Subscription', 'Protocol', 'EndPoint' ])

        with open('topics_without_subs_devint.txt','w') as output_file:

            # Paginator to get all Topics
            paginator = sns.get_paginator('list_topics')
            pagedtopics=paginator.paginate(PaginationConfig={'MaxItems':800})

            # not entirely clear on next 2 statements but they work.
            for alltopics in pagedtopics:
                for topic in alltopics['Topics']:
                    subs = sns.list_subscriptions_by_topic(TopicArn=topic['TopicArn'])
                    # Topics without subscribers would be written to a flat file
                    if subs['Subscriptions'] == []:
                        # print('This topic has no subscribers : ' + topic[topical])
                        output_file.write('This topic has no subscribers : ' + topic['TopicArn'] +"\n")
                        pass
                    # Topics with subscribers are written to a CSV file
                    # cat sns_dev_new.csv | awk -F"," '{ print $4}' | sort | uniq | grep -v sqs | grep -v lambda
                    else:
                        allsubs=subs['Subscriptions']
                        for subrec in range(len(allsubs)):
                            #print(allsubs[subrec])
                            topicarn    = allsubs[subrec]['TopicArn']
                            subarn      = allsubs[subrec]['SubscriptionArn']
                            subprotocol = allsubs[subrec]['Protocol']
                            subendpoint = allsubs[subrec]['Endpoint']
                            # print ( ', '.join([topicarn, subarn, subprotocol,subendpoint]))
                            writer.writerow ([topicarn, subarn, subprotocol,subendpoint])

# Function to list S3 bucket/s
@cli.command('list_topics_and_subscriptions')
def list_topics_and_subscriptions():
    """list_topics_and_subscriptions"""
    topics = sns.list_topics()   # dictionary of arns
    with open('sns_dev.csv','w') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['topic', 'Subscription', 'Protocol', 'EndPoint' ])

        alltopics=topics['Topics']
        for counter1 in range(len(alltopics)):
            subs = sns.list_subscriptions_by_topic(TopicArn=alltopics[counter1]['TopicArn'])
            if subs['Subscriptions'] == []:
                #print('This topic has no subscribers : ' + topic[topical])
                pass
            else:
                allsubs=subs['Subscriptions']
                for subrec in range(len(allsubs)):
                    #print(allsubs[subrec])
                    topicarn    = allsubs[subrec]['TopicArn']
                    subarn      = allsubs[subrec]['SubscriptionArn']
                    subprotocol = allsubs[subrec]['Protocol']
                    subendpoint = allsubs[subrec]['Endpoint']
                    print ( ', '.join([topicarn, subarn, subprotocol,subendpoint]))
                    writer.writerow ([topicarn, subarn, subprotocol,subendpoint])

####################################################################################################

if __name__ == '__main__':
    cli()

####################################################################################################