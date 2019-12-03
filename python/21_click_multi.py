#!/usr/bin/env python3

import click
import pprint
import boto3
import botocore

####################################################################################################

session = boto3.Session(profile_name='PRODQA')
ec2 = session.resource('ec2')        

####################################################################################################

# Top function group for click 
@click.group()
def click_commands():
    """Commands for EC2"""

####################################################################################################

# Sub function group for volumes 
@click_commands.group('click_volumes')  # This and the def below dont need to have same name
def click_volumes():                    # But do keep them same
    """Commands for EC2 volumes"""

##################################################

# List volumes for given instance
@click_volumes.command('list_volumes')
@click.option('--instance_id',
                default=None,
                help="Please specify the instance to list volumes for")
def list_volumes(instance_id):
    for ec2instance in ec2.instances.filter(InstanceIds=[instance_id]):
        for vol in ec2instance.volumes.all():
            print(vol)
            print(', '.join((vol.state, str(vol.size) + "Gb",
                vol.encrypted and "Encrypted" or "Not Encrypted")))

##################################################

# List volume snapshots for given instance
@click_volumes.command('list_vol_snapshots')
@click.option('--instance_id',
                default=None,
                help="Please specify the instance to list snapshots for")
def list_vol_snapshots(instance_id):
    for ec2instance in ec2.instances.filter(InstanceIds=[instance_id]):
        for vol in ec2instance.volumes.all():
            print(vol)
            for snap in vol.snapshots.all():
                print(', '.join((snap.id, snap.state, snap.progress)))
                break
            else:
                print('No Snapshots Found')

##################################################

# Create volume snapshots for given instance
@click_volumes.command('create_vol_snapshot')
@click.option('--instance_id',
                default=None,
                help="Please specify the instance to list volumes for")
def create_vol_snapshot(instance_id):
    for ec2instance in ec2.instances.filter(InstanceIds=[instance_id]):
        for vol in ec2instance.volumes.all():
            print(vol)
            vol.create_snapshot (Description="CreatedByAJ")

####################################################################################################
####################################################################################################

# Sub function Header group for instances
@click_commands.group('click_instances')
def click_instances():
    """Commands for EC2 Instances"""

##################################################

# List instances with a given project name (not implemented)
# "list_instances" below would be the command line option
@click_instances.command('list_instances')          
@click.option('--project_name','project_name_tag'
                default='Catchers Mitt',
                help="Please specify the project you need the instances for")
def list_instances(project_name_tag):
    "List EC2 Instances"                        # Message displayed by Click
    # to get all 
    inst_list = ec2.instances.all()

    # get the filtered instances list in a varialble 
    # the filter to be used for listing specific instances 
    filters = [{
                    'Name'   : 'tag:Project',
                    'Values' : [project_name_tag]
                }]
    fasp_inst_list = ec2.instances.filter(Filters=filters)

    # print the instance list 
    for inst in fasp_inst_list:
        for inst_tag in inst.tags or []:
            tags_dict = {inst_tag['Key']: inst_tag['Value']}

        inst_name_tag   = tags_dict.get('Name', 'NameTagMissing')
        inst_id         = inst.id
        inst_type       = inst.instance_type
        
        #pp = (', '.join((print(inst_name_tag, inst_id, inst_type))))
        pp = (', '.join((inst_name_tag, inst_id, inst_type)))
        px = pprint.PrettyPrinter(indent=30)
        px.pprint(pp)

##################################################

# start instance
@click_instances.command('start_instance')
@click.option('--instance_name','inst_id',      # changing parameter name
                default=None,
                help="Please specify the instance to be started")
@click.option('--wait_till_up','wait',          # changing parameter name
                default='no',
                help="Please specify the instance to be started")
def start_instace(inst_id, wait):
    "Start EC2 Instance"                         
    print ( "starter is" + starter )
    inst_id.start()
    if wait == 'yes':
        inst_id.wait_until_running()

##################################################

# stop instance 
@click_instances.command('stop_instance')
@click.option('--instance_name',
                default=None,
                help="Please specify the instance to be stopped")
def stop_instace(instance_name):
    "Stop EC2 Instance"                          
    while True:
        try:
            instance_name.stop()
        except botocore.exceptions.Clienterror as botoerror:
            print("its not down yet")
        continue
#def stop_instace2(instance_name):
#    "Stop EC2 Instance"                         
#    instance_name.stop()
#    instance_name.wait_until_stopped()

####################################################################################################
####################################################################################################

if __name__ == '__main__':
    click_commands()

