#!/usr/bin/env python3

import os.path
from os import path
import click

def process_parfile(mode, parfilename):
    # parfilename = "scrids.par"
    if not path.exists(parfilename):
        print ("Parfile \"" + parfilename + "\"does not exist")
        exit()

    with open(parfilename, "r") as parfile:
        for scridline in parfile:
            scriddet = scridline.strip()
            scriddet = scriddet.split(",")
            if mode == "validate":
                if len(scriddet) >= 2:
                    scrid = scriddet[0]
                    ingesttype = scriddet[1]
                    if ingesttype in ["longs", "specials", "episodes", "intermediate",
                                      "broadcast", "source", "shorts", "blacks", "promos"]:
                        continue
                    else:
                        print("Invalid ingest type \"" + ingesttype + "\" specified for scrid: " + scrid)
                        exit()
                else:
                    print("Incomplete entry detected : >>>   " + scridline )
                    exit()
            elif mode == "execute":
                scrid = scriddet[0]
                ingesttype = scriddet[1]
                print("run_ingest(" + scrid + "," +  ingesttype + ")")
            else:
                scrid = scridline.strip()
                print("run_ingest(" + scrid + "," +  mode + ")")


        print()
        if mode == "validate":
            print("Scrid file validation for " + parfilename + " successful!\n")
        else:
            print("Scrid ingest for file " + parfilename + " successful!\n")

@click.command()
@click.option('--env',
              help="Environment to ingest into (dev/qa/int)")
@click.option('--parfile',
              help="Please specify the name of the parameter file")
@click.option('--scridlist',
              help="Please specify the name of the parameter file")
def accept_user_input(env, parfile, scridlist):
    """
        Welcome to the mcd engineering fancy ingest script.

        Ingest types supported are:

        LONGS : long, special, episode, intermediate, broadcast, source
        SHORTS : short, black, promo, social

        Ingest can be done using 2 methods

        1. scridlist - one scrid per line and no other parameters, other inputs would be
        provided using the menu, please use this mode the first few times.

            default file name - scridlist.txt

        2. parfile - Parameter file based ingest: faster approach, this also allows
        to execute multiple ingest types in the same run.
        each line in the parameter file will have 2 mandatory inputs scrid and
        ingesttype, and a third optional parameter to specify reingest.

            12345,longs,r

            default filename - scrids.par

        Values in round brackets are default
    """

    # if the environment was not specified as a cmd line argument
    if not env:
        env = input ('Environment to ingest into (dev/qa/int): \n')
        print()
        if not env in ["dev","int","qa"]:
            print ("Please specify only dev, int or qa\n")
            exit()

    # if the parfile was not specified as a cmd line argument
    if parfile and scridlist:
        print ("you can specify parfile or scridlist and not both!")
        exit()
    elif parfile:
        parfiletype = "parfile"
    elif scridlist:
        parfiletype = "scridlist"
    else:
        parfiletype = input ('Scrid input file format parfile or (scridlist): \n') or "scridlist"

        if parfiletype == "parfile":
            parfile = input ('Please specify the name of the parameter file (scrids.par): \n') or "scrids.par"

        elif parfiletype == "scridlist":

            parfile = input ('Please specify the name of the scrid list file (scridlist.txt): \n') or "scridlist.txt"

            ingesttype = input ('Please specify the ingest type: \n') or "parfileingest"

            if not ingesttype in ["long", "special", "episode", "intermediate", "broadcast", "source",
                              "short", "black", "promo", "social"]:
                print ("Invalid ingest type received!\n" )
                exit()
        else:
            print("Invalid parameter file specification!\n")
            exit()

    if parfiletype == "parfile":
        print("Now validating the parfile.")
        process_parfile("validate", parfile)
        process_parfile("execute", parfile)
    elif parfiletype == "scridlist":
        print ("Ingest type specified is: " + ingesttype + "\n")
        process_parfile(ingesttype, parfile)

if __name__ == '__main__':
    accept_user_input()
