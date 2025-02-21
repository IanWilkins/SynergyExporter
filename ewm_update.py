# Wrapper script to update attachments and links using
# the WCL (workitem command line)
# https://github.com/jazz-community/work-item-command-line

# General Process. Run a query to get a list of ids and oldids
# Use that to update the WIs with attachments and links

# Required Inputs
# - Path to WCL script
# - Path to Synergy Export Directory
# - Path to working directory (default ./work)
# - Project Ar

###############################################################################
# Define Imports
import argparse
import os
from re import I
import sys
import csv
import collections
import subprocess

###############################################################################
# Define Globals

###############################################################################
# Define methods/functions
def initialize():
    print("Initializing System")
    global startDir
    startDir = os.getcwd()
    global workingDir

    if not os.path.exists(args.workingDir):
        os.makedirs(args.workingDir)

    workingDir = os.path.abspath(args.workingDir)


def parseCommandLine():
    print("Parsing Command Line")
    parser = argparse.ArgumentParser(prog='ewm_update',
                                     description='Update Workitems after import')
    parser.add_argument('--wcl', action='store',  nargs='?',
                        dest='wclCommand',
                        default='/WCL/wcl.sh',
                        help='Path to the WCL directory')
    parser.add_argument('-d', '--dir', action='store',  nargs='?',
                        dest='sourceDir',
                        default='/synergy/exports',
                        help='Path to the Synergy Export directory')
    parser.add_argument('--url', action='store',  nargs='?',
                        dest='ewmURL',
                        default='https://elm.example.com/ccm',
                        help='URL of EWM instance')
    parser.add_argument('--projectArea', action='store',  nargs='?',
                        dest='projectArea',
                        default='EWM Project Area',
                        help='Project Area Name')
    parser.add_argument('-u', '--user', action='store',  nargs='?',
                        dest='user',
                        default='ewm-admin',
                        help='User id to connect to EWM with')
    parser.add_argument('-p', '--pass', action='store',  nargs='?',
                        dest='password',
                        default='password',
                        help='Password to connect to EWM with')
    parser.add_argument('--query', action='store',  nargs='?',
                        dest='queryName',
                        default='All-Imported Objects',
                        help='Query to use to lookup imported objects')
    parser.add_argument('--work', action='store',  nargs='?',
                        dest='workingDir',
                        default='./work',
                        help='Directory for working and temp files')
    parser.add_argument('--skipAttachments', action='store_true',
                        help='Skip Processing Attachments')
    parser.add_argument('--skipLinks', action='store_true',
                        help='Skip Processing Links')
    parser.add_argument('--debug', action='store_true',
                        help='Turn on debug messages')

    global args
    args = parser.parse_args()

    debugPrint(args)

def validateArguments():
    # Verify that the files/directories needed exist
    print ("Validating Command Line")
    if not os.path.isfile(args.wclCommand):
       sys.exit("WCL option is incorrect")

    if not os.path.isdir(args.sourceDir):
       sys.exit("Source dir not valid")

def fetchCrossReference():
    # Run the query to get the cross reference info
    print(f"Running query {args.queryName} to lookup ID <-> OldId Values")

    wclPath = os.path.dirname(args.wclCommand)
    os.chdir(wclPath)

    global crossRefFile

    crossRefFile = os.path.join(workingDir, "crossRef.csv")
    #crossRefFile = "crossRef.csv"

    cmdOptions =  " -exportworkitems repository=\"" + args.ewmURL + "\" "
    cmdOptions += "user=\"" + args.user + "\" "
    cmdOptions += "password=\"" + args.password + "\" "
    cmdOptions += "projectArea=\"" + args.projectArea + "\" "
    cmdOptions += "exportFile=\"" + crossRefFile + "\" "
    cmdOptions += "query=\"" + args.queryName + "\" "
    cmdOptions += "columns=\"Old ID,Id,Type\" "
    cmdOptions += " /asrtceclipse"

    try:
        results = subprocess.check_output(args.wclCommand + cmdOptions, shell=True, text=True, stderr=subprocess.STDOUT)
        debugPrint(">>>" + results)

    except subprocess.CalledProcessError as e:
        print(f"ERROR -- Command failed with return code {e.returncode}")


def loadCrossReference():
    # Load the CSV file
    print ("Parsing the result of the Query")
    global crossReference
    crossReference = {}

    csvFile = open(crossRefFile, 'r')
    csv_reader = csv.DictReader((line.replace('\0','') for line in csvFile), delimiter=";")

    for line in csv_reader:
        debugPrint(line)
        crossReference[line["Old ID"]] = [line["Id"], line["Type"]]

    csvFile.close()

    debugPrint(crossReference)

def readAttachments():
    # Read the attachments directory
    attachmentDir = os.path.join(args.sourceDir, 'attachments')
    print (f"Finding Attachments in {attachmentDir}")
    attachments = pathToDict(attachmentDir)

    debugPrint(attachments)

    return attachments

def loadAttachments(attachments):

    debugPrint("Starting loadAttachments")

    # Setup command path
    wclPath = os.path.dirname(args.wclCommand)
    os.chdir(wclPath)

    # Sample Update command to add attachments
    # ./wcl.sh -update
    # repository="https://expert-labs-elm.fyre.ibm.com/ccm"
    # user='iwilkins'
    # password='iwilkins'
    # id="289"
    # @attachFile_1:add="/Users/ian/tmp/exports/attachments/trn#203/atextfile.txt,atextfile.txt,text/plain,UTF-8"
    # @attachFile_2:add="/Users/ian/tmp/exports/attachments/trn#203/TigersLogo.jpeg,TigersLogo.jpeg,application/unknown,UTF-8"

    # Loop through the attachments
    for oldId in attachments:
        if not oldId in crossReference:
            print("WARNING -- Unable to find EWM Id for Attachment Owner: " + oldId + " -- Skipping this record")
            continue

        ewmId = crossReference[oldId][0]

        print(f"Processing Attachments for {oldId} ({ewmId})")
        files = attachments[oldId]

        # Create the run the attachments commands

        cmdOptions =  " -update repository=\"" + args.ewmURL + "\" "
        cmdOptions += "user=\"" + args.user + "\" "
        cmdOptions += "password=\"" + args.password + "\" "
        cmdOptions += "id=\"" + ewmId + "\" "
        # Build the attachment bit
        for i in range(len(files)):
            cmdOptions += "@attachFile_" + str(i+1) + ":set=\"" + os.path.join(args.sourceDir, 'attachments', oldId, files[i]) + ","
            cmdOptions += files[i] + ",application/unknown,UTF-8\" "

        cmdOptions += " /enableDeleteAttachment"

        debugPrint(cmdOptions)

        try:
            results = subprocess.check_output(args.wclCommand + cmdOptions, shell=True, text=True, stderr=subprocess.STDOUT)
            debugPrint(">>>" + results)

        except subprocess.CalledProcessError as e:
            print(f"ERROR -- Command failed with return code {e.returncode}")



def loadLinks():

    csvFilePath = os.path.join(args.sourceDir, "relationships.csv")
    print (f"Processing Link file: {csvFilePath}")
    links = collections.defaultdict(set)

    csvFile = open(csvFilePath, 'r')
    csv_reader = csv.DictReader(csvFile, delimiter=",")

    # Load the links cross reference
    for line in csv_reader:
        links[line["parent"]].add(line["child"])

    csvFile.close()

    debugPrint(links)

    return links

def createLinks(links):
    debugPrint("Starting createLinks")

    # Setup command path
    wclPath = os.path.dirname(args.wclCommand)
    os.chdir(wclPath)

    # Sample Update command to add attachments
    # ./wcl.sh -update
    # repository="https://expert-labs-elm.fyre.ibm.com/ccm"
    # user='iwilkins'
    # password='iwilkins'
    # id="289"
    # @link_child=id1|id2|id3

    # Loop through the attachments
    for oldId in links:
        if not oldId in crossReference:
            print("WARNING -- Unable to find EWM Id for Parent: " + oldId + " -- Skipping this record")
            continue

        ewmId = crossReference[oldId][0]

        print (f"Creating Child Links for {oldId} ({ewmId})")
        children = links[oldId]

        # Create the run the attachments commands

        cmdOptions =  " -update repository=\"" + args.ewmURL + "\" "
        cmdOptions += "user=\"" + args.user + "\" "
        cmdOptions += "password=\"" + args.password + "\" "
        cmdOptions += "id=\"" + ewmId + "\" "
        cmdOptions += "@link_child=\""
        # Build the attachment bit
        for childId in children:
            if not childId in crossReference:
                print("WARNING -- Unable to find EWM Id for Child: " + childId + " -- Skipping this record")
                continue
            cmdOptions += crossReference[childId][0] + "|"

        cmdOptions = cmdOptions[:-1]
        cmdOptions += "\""

        debugPrint(cmdOptions)

        try:
            results = subprocess.check_output(args.wclCommand + cmdOptions, shell=True, text=True, stderr=subprocess.STDOUT)
            debugPrint(">>>" + results)

        except subprocess.CalledProcessError as e:
            print(f"ERROR -- Command failed with return code {e.returncode}")

def pathToDict(path):

    dirContents = {}
    for dir in os.listdir(path):
        if not os.path.isdir(os.path.join(path, dir)):
            continue
        dirContents[dir] = os.listdir(os.path.join(path, dir))

    return dirContents

def debugPrint(msg):
    if args.debug:
        print("-------- Start DEBUG INFO ----------")
        print(msg)
        print("-------- End DEBUG INFO ----------")

def main():

    parseCommandLine()

    initialize()
    validateArguments()

    fetchCrossReference()
    loadCrossReference()

    if (not args.skipAttachments):
        attachments = readAttachments()
        loadAttachments(attachments)

    if (not args.skipLinks):
        links = loadLinks()
        createLinks(links)



if __name__ == '__main__':
    main()
