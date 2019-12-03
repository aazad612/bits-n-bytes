//Export Main
CALL apoc.export.csv.query("MATCH (a:Asset)-[r1:INSTANCE]->(i:Instance)-[r2:LOCATION]->(l:Location) WHERE a.type <> 'still-image' RETURN l.url as URL, l.name as NAME, l.updatedTime as TIMESTAMP, a.state as STATE, a.scrid as SCRID, i.guid as GUID, a.type as ASSET_TYPE, i.type as INST_TYPE, a.id_house_number as HOUSE_NUM", "/opt/software/neo4j/db_backup/neo4j/export/sar-export.csv", {});

//Export Assets
CALL apoc.export.csv.query("MATCH (a:Asset) RETURN a.assetClass as asset_class, a.state as asset_state, a.type as asset_type, a.authoritativeSystem as authoritative_system, a.createdTime as create_time, a.createdBy as created_by, a.format as format, a.id_abstract_show_code, a.id_brand_abbreviation, a.id_container_id, a.id_dci_paid, a.id_edam_asset_id, a.id_episode_extension, a.id_episode_number, a.id_film_track_id, a.id_guid, a.id_house_number, a.id_isci_code, a.id_media_number, a.id_media_number_bugged, a.id_music_video_id, a.id_promo_house_number, a.id_segment_number, a.id_sequence_id, a.id_series_number, a.id_show_abbreviation, a.id_show_code, a.id_slate_asset_deliverable_id, a.id_tms_id, a.id_umid, id(a) as node_id, a.id_non_linear_id, a.scrid, a.subType as subtype, a.updatedBy, a.updatedTime, a.id_image_id, a.id_image_container_id, a.id_dci_property_id, a.id_hive_show_id, a.id_hive_season_id, a.id_hive_episode_id, a.id_series_sequence, a.id_episode_sequence, a.id_cut_id", "/opt/software/neo4j/db_backup/neo4j/export/assets.csv", {});

//Export Instances 
CALL apoc.export.csv.query("MATCH (i:Instance) RETURN i.type as type,i.createdTime as create_time, i.createdBy as created_by,i.guid,i.id_edam_instance_id,i.id_umid_instance_number, i.md5, i.mediaAspectRatio, i.mediaBitRate, i.mediaCodec, i.mediaDefinition, i.mediaEncoding, i.mediaFileSize, i.mediaFormat, i.mediaFrameRate, i.mediaHorizontalResolution, i.mediaType, i.mediaVerticalResolution, id(i) as node_id, i.scrid, i.updatedBy, i.updatedTime, i.id_movie_id, i.id_gcr_object_id", "/opt/software/neo4j/db_backup/neo4j/export/instances.csv", {});

//Export Locations
CALL apoc.export.csv.query("MATCH (l:Location) RETURN l.md5, l.name, l.url, id(l) as node_id, l.updatedBy, l.updatedTime", "/opt/software/neo4j/db_backup/neo4j/export/locations.csv", {});

//Export Relatinships
CALL apoc.export.csv.query("MATCH ()-[r]->() RETURN id(r) as relation_id, type(r), id(startnode(r)) as start_id, id(endnode(r)) as end_id, r.guid", "/opt/software/neo4j/db_backup/neo4j/export/relationships.csv", {});
