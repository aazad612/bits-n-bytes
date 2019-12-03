#!/usr/bin/env python36

# def arg_parse_module():
#     """ Function to read arguments """
#
#     LOG.info("Getting Arguments")
#     parser = argparse.ArgumentParser(description="Data Copy Script")
#     parser.add_argument(
#         "-e", required=True, choices=["dev", "int", "qa"], help="environment"
#     )
#     parser.add_argument("-s", required=True, help="scrid")
#
#     args = parser.parse_args()
#     return args


def search_wfts(scrid, inst_type):
    # static variables
    template_ids = "569d336b-3de4-4892-a14a-fe30eeee305a"
    task_ids = "instance-available"
    instance_type = str(inst_type)
    #
    terms1 = {}
    terms1["templateIds"] = []
    terms1["templateIds"].append(template_ids)
    terms1["taskIds"] = []
    terms1["taskIds"].append(task_ids)
    terms1["context"] = {}
    terms1["context"]["instance-type"] = []
    terms1["context"]["instance-type"].append(instance_type)
    terms1["context"]["scrid"] = []
    terms1["context"]["scrid"].append(str(scrid))
    terms1["atts"] = {}
    #
    sort1 = {}
    sort1["atts"] = True
    sort1["type"] = "TASK"
    sort1["name"] = "priority"
    sort1["desc"] = False
    #
    data = {}
    data["requestingTasks"] = True
    data["sorts"] = []
    data["sorts"].append(sort1)
    data["terms"] = []
    data["terms"].append(terms1)
    data["page"] = 1
    data["pageSize"] = 10

    url = "http://workflowtrackingservice.mcd.sniqa/workflow-tracking/v1/workflows/searches"
    headers = {"Content-Type": "application/json"}
    response = requests.post(url=url, data=json.dumps(data), headers=headers)
    LOG.info("WFTS response is {}".format(response.content))
    try:
        search_id = json.loads(response.content)["results"][0]["workFlow"]["id"]
        return search_id
    except:
        return None


def create_search_payload(scrid, inst_type, search_id):
    payload = {}
    if search_id != None:
        payload["id"] = str(search_id)
    else:
        payload["id"] = None

    payload["templateID"] = "569d336b-3de4-4892-a14a-fe30eeee305a"
    payload["name"] = None
    payload["description"] = None
    payload["group"] = None
    payload["app"] = None
    payload["lastUpdate"] = None
    payload["createDate"] = None
    payload["caller"] = "NL_IngestScript"
    payload["comment"] = None
    payload["user"] = "NL_IngestScript"
    payload["userFirstName"] = None
    payload["userLastName"] = None
    payload["status"] = "created"
    payload["atts"] = {}
    payload["atts"]["priority"] = "2018-09-05T12:00:00.000Z"
    payload["context"] = {}
    payload["context"]["instance-type"] = str(inst_type)
    payload["context"]["language"] = "en_US"
    payload["context"]["speaker-configuration"] = "N/A"
    payload["context"]["scrid"] = scrid
    payload["tasks"] = []

    task1 = {}
    task1["id"] = "instance-available"
    task1["guid"] = None
    task1["name"] = None
    task1["description"] = None
    task1["group"] = None
    task1["lastUpdate"] = None
    task1["createDate"] = None
    task1["caller"] = None
    task1["comment"] = None
    task1["user"] = None
    task1["userFirstName"] = None
    task1["userLastName"] = None
    task1["value"] = "pending"
    task1["atts"] = {}

    payload["tasks"].append(task1)
    #    final_payload = json.dumps(payload)
    LOG.info("Final payload is: {}\n".format(payload))
    return payload


def send_wfts(payload, http_endpoint):
    print("Endpoint: {} \nPayload: {}".format(http_endpoint, payload))
    if payload["id"] is None:
        r = requests.post(http_endpoint, data=json.dumps(payload), headers=config.WFTS_HEADERS)
    else:
        r = requests.put(http_endpoint, data=json.dumps(payload), headers=config.WFTS_HEADERS)
    return r.text


def get_item_from_db(scrid_sql, scrid_sql_named_params):
    LOG.info("In get_item_from_db")
    try:
        connection = oracle.connect(config.DB_LOGIN_STRING)
        cursor = connection.cursor()
        cursor.execute(scrid_sql, scrid_sql_named_params)
        #cursor.execute("select id_value from DWUSER.ES_ASSET_IDENTIFIER where id_type='non-linear-id'
        # and scrid={}".format(scrid_sql_named_params['m_scrid']))
        for row in cursor.fetchall():
            my_item = row[0]

        if cursor.rowcount == 0:
            raise InternalException("No Rows returned from DB", scrid_sql_named_params)

        cursor.close()
        connection.close()
        return my_item
    except (Exception) as e:
        LOG.info("Problems: %s" % e)
        raise InternalException("DB Problems:", e)


def get_irs_data(scrid, type):
    LOG.info("In get_irs_data")
    headers = {"SMUSER": "CDE", "SN-AD-GROUPS": "SN_MAM_VIEW_SECURED_ASSETS"}
    url = (
            config.BASE_IRS_URL
            + scrid
            + config.TYPE_IRS_URL
            + str(type)
            + config.END_IRS_URL
    )
    LOG.info("URL is %s", url)
    try:

        response = requests.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()

    except requests.exceptions.HTTPError as errh:
        raise InternalException("Http Error:", errh)
    except requests.exceptions.ConnectionError as errc:
        raise InternalException("Error Connecting:", errc)
    except requests.exceptions.Timeout as errt:
        raise InternalException("Timeout Error:", errt)
    except requests.exceptions.RequestException as err:
        raise InternalException("Other Error:", err)

    return data


def get_info_from_db(db_data_info, sql_named_params):
    status_sql = config.MQ_DATA_SQL

    try:
        connection = oracle.connect(config.DB_LOGIN_STRING)
        cursor = connection.cursor()
        cursor.execute(status_sql, sql_named_params)

        for row in cursor.fetchall():
            db_data_info["m_format"] = row[0]
            db_data_info["m_type"] = row[1]
            db_data_info["m_file_size"] = row[2]
            db_data_info["m_encoding"] = row[3]
            db_data_info["m_codec"] = row[4]
            db_data_info["m_resolution_v"] = row[5]
            db_data_info["m_resolution_h"] = row[6]
            db_data_info["m_asp_ratio"] = row[7]
            db_data_info["m_bit_rate"] = row[8]
            db_data_info["m_frame_rate"] = row[9]
            db_data_info["m_def"] = row[10]

        if cursor.rowcount == 0:
            raise InternalException("No Rows returned from DB", scrid_sql_named_params)

        cursor.close()
        connection.close()

        db_data_info["m_instance_type"] = sql_named_params["m_instance_type"]
        db_data_info["m_scrid"] = sql_named_params["m_scrid"]

        print("\ndb_data_info is:\n", db_data_info, "\n")
        #        if "4k-master" not in db_data_info["m_instance_type"]:
        if (db_data_info["m_def"] is not None) and (len(db_data_info["m_def"]) > 1):
            m_def_parts = db_data_info["m_def"].split("|")
            db_data_info["m_cadence_errors"] = m_def_parts[0]
            db_data_info["m_start_time"] = m_def_parts[1]
        if len(m_def_parts) < 3:
            db_data_info["m_cadence_pattern"] = ""
        else:
            db_data_info["m_cadence_pattern"] = m_def_parts[2]

    except (Exception) as e:
        LOG.info("Problems: " % e)
        raise InternalException("DB Problems:", e)


def get_json_data(db_data_info, tagHouseNum, json_file_name):
    template = "file://json.queue"
    try:
        if template.startswith("file"):
            file_re = re.compile(r"file://(.*)", re.X)

        if file_re.match(template):
            template = file_re.match(template).groups()[0]

        data = json.load(open(template))

        data["media"]["format"] = db_data_info["m_format"]
        data["media"]["type"] = db_data_info["m_type"]
        data["media"]["fileSize"] = db_data_info["m_file_size"]
        data["media"]["encoding"] = db_data_info["m_encoding"]
        data["media"]["codec"] = db_data_info["m_codec"]
        data["media"]["verticalResolution"] = db_data_info["m_resolution_v"]
        data["media"]["horizontalResolution"] = db_data_info["m_resolution_h"]
        data["media"]["aspectRatio"] = db_data_info["m_asp_ratio"]
        data["media"]["bitRate"] = db_data_info["m_bit_rate"]
        data["media"]["frameRate"] = db_data_info["m_frame_rate"]
        data["media"]["startTime"] = db_data_info["m_start_time"]

        data["scrid"] = db_data_info["m_scrid"]
        data["instanceType"] = db_data_info["m_instance_type"]
        data["cadenceErrors"] = db_data_info["m_cadence_errors"]
        data["cadencePattern"] = db_data_info["m_cadence_pattern"]
        data["identifiers"][0]["type"] = "house-number"

        data["identifiers"][0]["value"] = tagHouseNum
        data["fileUrl"] = json_file_name
        print("JSON data is", data)  # Sean added
        return data

    except (Exception) as e:
        LOG.info("Problems: %s" % e)


def write_to_sqs(sqs_data, conn_sqs, tagEnv):
    LOG.info("In write_to_sqs")
    LOG.info("sqs full data : %s\n", sqs_data)
    if tagEnv == "dev":
        queue = conn_sqs.Queue(url=config.DEV_SQS_QUEUE)
    elif tagEnv == "int":
        queue = conn_sqs.Queue(url=config.INT_SQS_QUEUE)
    elif tagEnv == "qa":
        queue = conn_sqs.Queue(url=config.QA_SQS_QUEUE)

    response = queue.send_message(MessageBody=json.dumps(sqs_data))
    print("JSON uploaded to SQS", json.dumps(sqs_data))  # Sean added
    print("Upload to SQS response", response)  # Sean added
    LOG.info(response["MessageId"])


def copy_framegrab(nlvid, tagEnv):
    LOG.info("In copy_framegrab")

    mamRefreshDir = config.MAMREFRESH_DIR
    if (tagEnv == "dev") or (tagEnv == "int"):
        framegrabDir = config.NON_PROD_BASE_DIR + tagEnv + config.DEV_INT_FRAMEGRAB_DIR
    elif tagEnv == "qa":
        framegrabDir = config.NON_PROD_BASE_DIR + tagEnv + config.QA_FRAMEGRAB_DIR

    check_directory_exists(mamRefreshDir)
    check_directory_exists(framegrabDir)

    for fg_size in config.FRAMEGRAB_COPY_SIZES:
        LOG.info("fg_size is - %s", fg_size)
        source = mamRefreshDir + "/0134084" + fg_size
        destination = framegrabDir + "/" + nlvid + fg_size
        copy_a_file(source, destination)


def copy_intermediate_and_proxy(tagScrid, tagEnv):
    LOG.info("In copy_intermediate_and_proxy")

    intermediate_dest = (
            config.NON_PROD_BASE_DIR + tagEnv + "/ingest/video/intermediate/"
    )
    check_directory_exists(intermediate_dest)
    proxy_dest = (
            config.NON_PROD_BASE_DIR + tagEnv + "/ingest/video/frame-accurate-proxy/"
    )
    check_directory_exists(proxy_dest)

    type = "segment"
    data = get_irs_data(tagScrid, type)
    print("Intermediate and proxy data dict is", data)  # Sean added
    for k in data["items"]:
        LOG.info(k["scrid"])
        LOG.info(k["assetType"])
        LOG.info(k["instanceType"])
        if k["instanceType"] == "frame-accurate-proxy":
            destination = proxy_dest
        elif k["instanceType"] == "intermediate":
            destination = intermediate_dest
        else:
            raise InternalException("No path Error:", k["instanceType"])
        for l in k["locations"]:
            if l["name"] == "isilon-knox":
                source = config.PROD_BASE_DIR + l["nativePath"]
                LOG.info("Source is: %s : Destination is %s ", source, destination)
                copy_a_file(source, destination)


def copy_closedcaption(tagScrid, tagEnv, showcode):
    LOG.info("In copy_closedcaption")
    cc_dest = config.NON_PROD_BASE_DIR + tagEnv + "/ingest/cc/"
    check_directory_exists(cc_dest)

    type = "closed-captioning"
    data = get_irs_data(tagScrid, type)
    print("CC data dict is", data)  # Sean added
    for k in data["items"]:
        LOG.info(k["scrid"])
        LOG.info(k["assetType"])
        LOG.info(k["instanceType"])
        for l in k["locations"]:
            if l["name"] == "isilon-knox":
                source = config.PROD_BASE_DIR + l["nativePath"]
                dest_file = cc_dest + showcode + os.path.splitext(source)[1]
                LOG.info("Source is: %s : Destination is %s ", source, dest_file)
                copy_a_file(source, dest_file)


def copy_xdcam(tagScrid, tagEnv, housenum):
    LOG.info("In copy_xdcam")
    aws_data = {}
    aws_data["tagEnv"] = tagEnv
    LOG.info(aws_data["tagEnv"])
    connections = AwsBotoConnections(aws_data)
    conn_sqs = connections.connection_sqs()

    xdcam_dir = config.NON_PROD_BASE_DIR + tagEnv + "/ingest/mbr/"
    check_directory_exists(xdcam_dir)
    sql_named_params = {"m_scrid": tagScrid}
    type = "episode"
    data = get_irs_data(tagScrid, type)
    print("Copy xdcam data is", data)  # Sean added
    for k in data["items"]:
        LOG.info(k["scrid"])
        LOG.info(k["assetType"])
        LOG.info(k["instanceType"])
        for l in k["locations"]:
            if l["name"] == "isilon-knox":
                source = config.PROD_BASE_DIR + l["nativePath"]
                json_file_name = (
                        "file://" + tagEnv + "/ingest/mbr/" + os.path.basename(source)
                )
                LOG.info("Source is: %s : Destination is %s ", source, xdcam_dir)
                copy_a_file(source, xdcam_dir)
                db_data_info = {}
                sql_named_params["m_instance_type"] = k["instanceType"]
                get_info_from_db(db_data_info, sql_named_params)

                sqs_data = get_json_data(db_data_info, housenum, json_file_name)
                LOG.info("sqs_data : %s", sqs_data["media"]["startTime"])
                LOG.info("sqs_data : %s", sqs_data["scrid"])

                # LOG.info("sqs full data : %s",  sqs_data)
                write_to_sqs(sqs_data, conn_sqs, tagEnv)


def copy_xdcam_special(tagScrid, tagEnv, housenum):
    LOG.info("In copy_xdcam")
    aws_data = {}
    aws_data["tagEnv"] = tagEnv
    LOG.info(aws_data["tagEnv"])
    connections = AwsBotoConnections(aws_data)
    conn_sqs = connections.connection_sqs()

    xdcam_dir = config.NON_PROD_BASE_DIR + tagEnv + "/ingest/mbr/"
    check_directory_exists(xdcam_dir)
    sql_named_params = {"m_scrid": tagScrid}
    type = "special"
    data = get_irs_data(tagScrid, type)
    for k in data["items"]:
        LOG.info(k["scrid"])
        LOG.info(k["assetType"])
        LOG.info(k["instanceType"])
        for l in k["locations"]:
            if l["name"] == "isilon-knox":
                source = config.PROD_BASE_DIR + l["nativePath"]
                json_file_name = (
                        "file://" + tagEnv + "/ingest/mbr/" + os.path.basename(source)
                )
                LOG.info("Source is: %s : Destination is %s ", source, xdcam_dir)
                copy_a_file(source, xdcam_dir)
                db_data_info = {}
                sql_named_params["m_instance_type"] = k["instanceType"]
                get_info_from_db(db_data_info, sql_named_params)

                sqs_data = get_json_data(db_data_info, housenum, json_file_name)
                LOG.info("sqs_data : %s", sqs_data["media"]["startTime"])
                LOG.info("sqs_data : %s", sqs_data["scrid"])

                # LOG.info("sqs full data : %s",  sqs_data)
                write_to_sqs(sqs_data, conn_sqs, tagEnv)


def check_directory_exists(dir):
    LOG.info("Checking for directory %s", dir)
    if not os.path.isdir(dir):
        raise IOError("Directory does not exist", dir)


def copy_a_file(file, destination):
    LOG.info("Copying file - %s to %s", file, destination)
    try:
        shutil.copy(file, destination)
    except (Exception) as e:
        LOG.warning(
            "problems copying the source %s to %s: %s" % (source, destination, e)
        )
        raise IOError("Error copying files")


def main():

    LOG.info("Begin--")

    args = arg_parse_module()
    LOG.info("args are: %s %s ", args.e, args.s)

    tagScrid = args.s
    tagEnv = args.e

    bcast_search_id = search_wfts(tagScrid, "broadcast")
    scc_search_id = search_wfts(tagScrid, "scc")
    nlp_search_id = search_wfts(tagScrid, "nonlinear-progressive")
    #LOG.info("bcast_search_id is {}\n".format(bcast_search_id))
    #LOG.info("scc_search_id is {}\n".format(scc_search_id))
    #LOG.info("nlp_search_id is {}\n".format(nlp_search_id))
    bcast_scrid_payload = create_search_payload(tagScrid, "broadcast", bcast_search_id)
    scc_scrid_payload = create_search_payload(tagScrid, "scc", scc_search_id)
    nlp_scrid_payload = create_search_payload(tagScrid, "nonlinear-progressive", nlp_search_id)
    #LOG.info("bcast_scrid_payload is {}\n".format(bcast_scrid_payload))
    #LOG.info("scc_scrid_payload is {}\n".format(scc_scrid_payload))
    #LOG.info("nlp_scrid_payload is {}\n".format(nlp_scrid_payload))
    bcast_response = send_wfts(bcast_scrid_payload, config.QA_WFTS_ENDPOINT)
    scc_response = send_wfts(scc_scrid_payload, config.QA_WFTS_ENDPOINT)
    nlp_response = send_wfts(nlp_scrid_payload, config.QA_WFTS_ENDPOINT)
    #LOG.info("SCC response is {}\n".format(scc_response))
    #LOG.info("Broadcast response is {}\n".format(bcast_response))
    #LOG.info("NLP response is {}\n".format(nlp_response))
    scrid_sql_named_params = {"m_scrid": tagScrid}
    print("sql_named_params is:\n{}\n\nscrid_sql is:\n{}\n".format(scrid_sql_named_params, scrid_sql))

    scrid_sql = config.NLVID_DATA_SQL
    nlvid = get_item_from_db(scrid_sql, scrid_sql_named_params)
    #LOG.info("NLVID is %s", nlvid)

    scrid_sql = config.HOUSENUM_DATA_SQL
    housenum = get_item_from_db(scrid_sql, scrid_sql_named_params)
    #LOG.info("HOUSENUM is %s", housenum)

    scrid_sql = config.SHOWCODE_DATA_SQL
    showcode = get_item_from_db(scrid_sql, scrid_sql_named_params)
    #LOG.info("SHOWCODE is %s", showcode)

    copy_framegrab(nlvid, tagEnv)                       # if just images
    copy_intermediate_and_proxy(tagScrid, tagEnv)       # if asked for intermediate
    copy_closedcaption(tagScrid, tagEnv, showcode)      # if just cc
    copy_xdcam(tagScrid, tagEnv, housenum)              # if asked for broadcast, episodes, or 'source'
    copy_xdcam_special(tagScrid, tagEnv, housenum)      # they will say special, like HD resolution, etc.
    LOG.info("End--\n")


if __name__ == "__main__":
    main()


"""
if asset_request == long_form:
    parse arguments passed with file execution using argparse module. these parameters include:
        environment == args.e
        scrid == args.s
        recontribute == args.r #Proposed addition not currently available with y/n option if assets need recon
    if recontribute == y:
        bcast_search_id = search_wfts(scrid, "broadcast")
        scc_search_id = search_wfts(scrid, "scc")
        bcast_scrid_payload = create_search_payload(scrid, "broadcast", bcast_search_id)
        scc_scrid_payload = create_search_payload(scrid, "scc", scc_search_id)
        bcast_response = send_wfts(bcast_scrid_payload, QA_WFTS_ENDPOINT)
        scc_response = send_wfts(scc_scrid_payload, QA_WFTS_ENDPOINT)
    get_item_from_db(scrid, 
    
    short_ingestion = blacks, short-forms, brand promos
long_ingestion = specials, episodes, 
recontributions = must be done before the respective copy to the isilon (short or long ingestion). In general it consists of searching WFTS for a scrid with a predefined payload from the WFTS http endpoint for search, and doing different actions depending on the result. If no result is returned we need to do a POST (create) call of the separate pre-defined payload to the WFTS endpoint. If a search result was returned, we need to do a PUT (update) call of the separate pre-defined payload to the WFTS endpoint. Furthermore, it seems that the “task1["value"]” key in the payload needs to accurately reflect the state of the copy job and ingestion. Usually “pending” if ran before the job, and “complete” if ran after the asset is ingested.
will update as Chethan gets with Ramesh and updates specs


"""

please document the steps similar to you did in ME-1596