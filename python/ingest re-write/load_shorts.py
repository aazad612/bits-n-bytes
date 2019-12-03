#!/usr/bin/env python3

import argparse
import sys
import os
import shutil
import logging
import json
import re
import requests
import boto3
import cx_Oracle as oracle
import copy_artifacts_new_config as config

from libs.log import module_logger, setup_logging
from exception.exceptions import InternalException
from connection.awsconnnects import AwsBotoConnections
from botocore.exceptions import BotoCoreError, ClientError

# Logging
LOG = module_logger(__name__)
setup_logging(logging.INFO)

def arg_parse_module():
    """ Function to read arguments """

    LOG.info('Getting Arguments')
    parser = argparse.ArgumentParser(description='Data Copy Script')
    parser.add_argument('-e',
                        required=True,
                        choices=['dev', 'int', 'qa'],
                        help='environment')
    parser.add_argument('-s',
                        required=True,
                        help='scrid')

    args = parser.parse_args()
    return args

def get_item_from_db(scrid_sql, scrid_sql_named_params):
    LOG.info("In get_item_from_db")
    try:
        connection = oracle.connect(config.DB_LOGIN_STRING)
        cursor = connection.cursor()
        cursor.execute(scrid_sql, scrid_sql_named_params)
        for row in cursor.fetchall():
            my_item = row[0]

        if cursor.rowcount == 0:
            raise InternalException("No Rows returned from DB" , scrid_sql_named_params)

        cursor.close()
        connection.close()
        return my_item
    except (Exception)as e:
        LOG.info("Problems: %s" %e)
        raise InternalException("DB Problems:", e)

def get_irs_data(scrid,type):
    LOG.info("In get_irs_data")
    headers = {"SMUSER": "CDE", "SN-AD-GROUPS": "SN_MAM_VIEW_SECURED_ASSETS"}
    url=config.BASE_IRS_URL+scrid+config.TYPE_IRS_URL+str(type)+config.END_IRS_URL
    LOG.info("URL is %s", url)
    try:

        response = requests.get(url,headers=headers)
        response.raise_for_status()
        data=response.json()

    except requests.exceptions.HTTPError as errh:
        raise InternalException("Http Error:", errh)
    except requests.exceptions.ConnectionError as errc:
        raise InternalException("Error Connecting:", errc)
    except requests.exceptions.Timeout as errt:
        raise InternalException("Timeout Error:", errt)
    except requests.exceptions.RequestException as err:
        raise InternalException("Other Error:", err)

    return data

def get_info_from_db(db_data_info,sql_named_params):
    """
    get the information about files
    """
    status_sql = config.MQ_DATA_SQL
    try:

        connection = oracle.connect(config.DB_LOGIN_STRING)
        cursor = connection.cursor()
        cursor.execute(status_sql, sql_named_params)
        for row in cursor.fetchall():
            db_data_info["m_format"]       = row[0]
            db_data_info["m_type"]         = row[1]
            db_data_info["m_file_size"]    = row[2]
            db_data_info["m_encoding"]     = row[3]
            db_data_info["m_codec"]        = row[4]
            db_data_info["m_resolution_v"] = row[5]
            db_data_info["m_resolution_h"] = row[6]
            db_data_info["m_asp_ratio"]    = row[7]
            db_data_info["m_bit_rate"]     = row[8]
            db_data_info["m_frame_rate"]   = row[9]
            db_data_info["m_def"]          = row[10]

        if cursor.rowcount == 0:
            raise InternalException("No Rows returned from DB" , scrid_sql_named_params)

        cursor.close()
        connection.close()

        db_data_info["m_instance_type"] = sql_named_params["m_instance_type"]
        db_data_info["m_scrid"] = sql_named_params["m_scrid"]
        m_def_parts=db_data_info["m_def"].split('|')
        db_data_info["m_cadence_errors"] = m_def_parts[0]
        db_data_info["m_start_time"] = m_def_parts[1]
        if len(m_def_parts)<3:
            db_data_info["m_cadence_pattern"] = ""
        else:
            db_data_info["m_cadence_pattern"] = m_def_parts[2]
    except (Exception)as e:
        LOG.info("Problems: " %e)
        raise InternalException("DB Problems:", e)

def get_json_data(db_data_info,tagHouseNum,json_file_name):
    LOG.info('In get_json_data')
    template = 'file://json.queue'
    try:
        if template.startswith('file'):
            file_re = re.compile(r'file://(.*)', re.X)

        if file_re.match(template):
            template = file_re.match(template).groups()[0]

        data = json.load(open(template))

        data["media"]["format"]=db_data_info["m_format"]
        data["media"]["type"]=db_data_info["m_type"]
        data["media"]["fileSize"]=db_data_info["m_file_size"]
        data["media"]["encoding"]=db_data_info["m_encoding"]
        data["media"]["codec"]=db_data_info["m_codec"]
        data["media"]["verticalResolution"]=db_data_info["m_resolution_v"]
        data["media"]["horizontalResolution"]=db_data_info["m_resolution_h"]
        data["media"]["aspectRatio"]=db_data_info["m_asp_ratio"]
        data["media"]["bitRate"]=db_data_info["m_bit_rate"]
        data["media"]["frameRate"]=db_data_info["m_frame_rate"]
        data["media"]["startTime"]=db_data_info["m_start_time"]

        data["scrid"]=db_data_info["m_scrid"]
        data["instanceType"]=db_data_info["m_instance_type"]
        data["cadenceErrors"]=db_data_info["m_cadence_errors"]
        data["cadencePattern"]=db_data_info["m_cadence_pattern"]
        data["identifiers"][0]["type"]="house-number"

        data["identifiers"][0]["value"]=tagHouseNum
        data["fileUrl"]=json_file_name

        return data

    except (Exception)as e:
        LOG.info("Problems: %s" %e)

def write_to_sqs(sqs_data,conn_sqs,tagEnv):
    LOG.info('In write_to_sqs')
    LOG.info("sqs full data : %s\n",  sqs_data)
    if(tagEnv=='dev'):
        queue = conn_sqs.Queue(url=config.DEV_SQS_QUEUE)
    elif (tagEnv=='int'):
        queue = conn_sqs.Queue(url=config.INT_SQS_QUEUE)
    elif (tagEnv=='qa'):
        queue = conn_sqs.Queue(url=config.QA_SQS_QUEUE)

    response = queue.send_message(MessageBody=json.dumps(sqs_data))

    LOG.info(response['MessageId'])

def copy_framegrab(nlvid,tagEnv):
    LOG.info('In copy_framegrab')

    mamRefreshDir = config.MAMREFRESH_DIR
    if((tagEnv=='dev') or (tagEnv=='int')):
        framegrabDir = config.NON_PROD_BASE_DIR + tagEnv + config.DEV_INT_FRAMEGRAB_DIR
    elif (tagEnv=='qa'):
        framegrabDir = config.NON_PROD_BASE_DIR + tagEnv + config.QA_FRAMEGRAB_DIR

    check_directory_exists(mamRefreshDir)
    check_directory_exists(framegrabDir)

    for fg_size in config.FRAMEGRAB_COPY_SIZES:
        LOG.info("fg_size is - %s", fg_size)
        source=mamRefreshDir+"/0134084"+fg_size
        destination=framegrabDir+"/"+nlvid+fg_size
        copy_a_file(source, destination)

def copy_closedcaption(tagScrid,tagEnv,housenum):
    LOG.info("In copy_closedcaption")
    cc_dest = config.NON_PROD_BASE_DIR+tagEnv+"/ingest/cc/"
    check_directory_exists(cc_dest)
    type='closed-captioning'
    data=get_irs_data(tagScrid,type)
    for k in data['items']:
        LOG.info(k['scrid'])
        LOG.info(k['assetType'])
        LOG.info(k['instanceType'])
        for l in k['locations']:
            if l['name']=='isilon-knox':
                source=config.PROD_BASE_DIR+l['nativePath']
                dest_file=cc_dest + housenum + os.path.splitext(source)[1]
                LOG.info("Source is: %s : Destination is %s ",source, dest_file)
                copy_a_file(source, dest_file)

def copy_non_linear_video(tagScrid,tagEnv,housenum):
    LOG.info("In copy_non_linear_video")
    aws_data = {}
    aws_data['tagEnv']=tagEnv
    LOG.info(aws_data['tagEnv'])
    connections = AwsBotoConnections(aws_data)
    conn_sqs = connections.connection_sqs()

    sql_named_params={'m_scrid':tagScrid}
    type='non-linear-video'
    intermediate_dest = config.NON_PROD_BASE_DIR+tagEnv+"/ingest/nlv/intermediate/"
    check_directory_exists(intermediate_dest)
    proxy_dest = config.NON_PROD_BASE_DIR+tagEnv+"/ingest/nlv/frame-accurate-proxy/"
    check_directory_exists(proxy_dest)
    verticaldistribution_dest = config.NON_PROD_BASE_DIR+tagEnv+"/ingest/nlv/vertical-distribution/"
    check_directory_exists(verticaldistribution_dest)
    verticalsource_dest = config.NON_PROD_BASE_DIR+tagEnv+"/ingest/nlv/vertical-source/"
    check_directory_exists(verticalsource_dest)
    squaredistribution_dest = config.NON_PROD_BASE_DIR+tagEnv+"/ingest/nlv/square-distribution/"
    check_directory_exists(squaredistribution_dest)
    squaresource_dest = config.NON_PROD_BASE_DIR+tagEnv+"/ingest/nlv/square-source/"
    check_directory_exists(squaresource_dest)
    xdcam_dest = config.NON_PROD_BASE_DIR+tagEnv+"/ingest/mbr/"
    check_directory_exists(xdcam_dest)

    type='non-linear-video'
    data=get_irs_data(tagScrid,type)
    for k in data['items']:
        LOG.info(k['scrid'])
        LOG.info(k['assetType'])
        LOG.info(k['instanceType'])
        if k['instanceType']=='frame-accurate-proxy':
            destination=proxy_dest
        elif k['instanceType']=='intermediate':
            destination=intermediate_dest
        elif k['instanceType']=='square-distribution':
            destination=squaredistribution_dest
        elif k['instanceType']=='square-source':
            destination=squaresource_dest
        elif k['instanceType']=='vertical-distribution':
            destination=verticaldistribution_dest
        elif k['instanceType']=='vertical-source':
            destination=verticalsource_dest
        elif k['instanceType']=='nonlinear-progressive' or 'broadcast':
            for l in k['locations']:
                if l['name']=='isilon-knox':
                    source=config.PROD_BASE_DIR+l['nativePath']
                    destination=xdcam_dest
                    json_file_name="file://"+tagEnv+"/ingest/mbr/"+os.path.basename(source)
                    db_data_info = {}
                    sql_named_params['m_instance_type']=k['instanceType']
                    get_info_from_db(db_data_info,sql_named_params)

                    sqs_data = get_json_data(db_data_info,housenum,json_file_name)
                    LOG.info("sqs_data : %s", sqs_data["media"]["startTime"])
                    LOG.info("sqs_data : %s", sqs_data["scrid"])

                    write_to_sqs(sqs_data,conn_sqs,tagEnv)
        else:
            raise InternalException("No path Error:", k['instanceType'])
        for l in k['locations']:
            if l['name']=='isilon-knox':
                source=config.PROD_BASE_DIR+l['nativePath']
                LOG.info("Source is: %s : Destination is %s ",source, destination)
                copy_a_file(source, destination)

def check_directory_exists(dir):
    LOG.info("Checking for directory %s", dir)
    if not os.path.isdir(dir):
        raise IOError("Directory does not exist", dir)

def copy_a_file(source,destination):
    LOG.info("Copying file - %s to %s", source, destination)
    try:
        shutil.copy(source, destination)
    except (Exception) as e:
        LOG.warning("problems copying the source %s to %s: %s" % (source, destination, e))
        raise IOError('Error copying files')

def main():

    LOG.info('Begin--')

    args = arg_parse_module()
    LOG.info("args are: %s %s ",args.e, args.s)

    tagScrid=args.s
    tagEnv=args.e

    scrid_sql_named_params={'m_scrid':tagScrid}
    scrid_sql = config.NLVID_DATA_SQL
    nlvid = get_item_from_db(scrid_sql,scrid_sql_named_params)
    LOG.info("NLVID is %s", nlvid)

    scrid_sql = config.HOUSENUM_DATA_SQL
    housenum = get_item_from_db(scrid_sql,scrid_sql_named_params)
    LOG.info("HOUSENUM is %s", housenum)
    copy_framegrab(nlvid,tagEnv)
    copy_closedcaption(tagScrid,tagEnv,housenum)
    copy_non_linear_video(tagScrid,tagEnv,housenum)
    LOG.info('End--\n')
if __name__ == '__main__':
    main()