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
import sys
import csv

###############################################################################
# Define Globals

###############################################################################
# Define methods/functions
def initialize():
    global startDir
    startDir = os.getcwd()
    global workingDir

    if not os.path.exists(args.workingDir):
        os.makedirs(args.workingDir)

    workingDir = os.path.abspath(args.workingDir)


def parseCommandLine():
    parser = argparse.ArgumentParser(prog='ewm_update',
                                     description='Update Workitems after import')
    parser.add_argument('--wcl', action='store',  nargs='?',
                        dest='wclCommand',
                        default='/Users/ian/expert-labs/WCL/wcl.sh',
                        help='Path to the WCL directory')
    parser.add_argument('-d', '--dir', action='store',  nargs='?',
                        dest='sourceDir',
                        default='/Users/ian/tmp/exports',
                        help='Path to the Synergy Export directory')
    parser.add_argument('--url', action='store',  nargs='?',
                        dest='ewmURL',
                        default='https://expert-labs-elm.fyre.ibm.com/ccm',
                        help='URL of EWM instance')
    parser.add_argument('--projectArea', action='store',  nargs='?',
                        dest='projectArea',
                        default='Crane 01-10-2025 Drop',
                        help='Project Area Name')
    parser.add_argument('-u', '--user', action='store',  nargs='?',
                        dest='user',
                        default='iwilkins',
                        help='User id to connect to EWM with')
    parser.add_argument('-p', '--pass', action='store',  nargs='?',
                        dest='password',
                        default='iwilkins',
                        help='Password to connect to EWM with')
    parser.add_argument('--query', action='store',  nargs='?',
                        dest='queryName',
                        default='All-Imported Objects',
                        help='Query to use to lookup imported objects')
    parser.add_argument('--work', action='store',  nargs='?',
                        dest='workingDir',
                        default='./work',
                        help='Directory for working and temp files')
    parser.add_argument('--debug', action='store_true',
                        help='Turn on debug messages')

    global args
    args = parser.parse_args()

    print (args)

def validateArguments():
    # Verify that the files/directories needed exist
    if not os.path.isfile(args.wclCommand):
       sys.exit("WCL option is incorrect")

    if not os.path.isdir(args.sourceDir):
       sys.exit("Source dir not valid")

def fetchCrossReference():
    # Run the query to get the cross reference info

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

    rc = os.system(args.wclCommand + cmdOptions)

    debugPrint(rc)

    if rc:
        SystemExit("Unable to fetch cross references")


def loadCrossReference():
    # Load the CSV file
    global crossReference
    crossReference = {}

    csvFile = open(crossRefFile, 'r')
    csv_reader = csv.DictReader((line.replace('\0','') for line in csvFile), delimiter=";")

    for line in csv_reader:
        debugPrint(line)
        crossReference[line["Old ID"]] = [line["Id"], line["Type"]]

    csvFile.close()

    print(crossReference)

def readAttachments():
    # Read the attachments directory
    attachments = pathToDict(os.path.join(args.sourceDir, 'attachments'))

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
        debugPrint("Processing attachments for OldID: " + oldId)
        ewmId = crossReference[oldId][0]
        debugPrint("Found EWM Id: " + ewmId)

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

        rc = os.system(args.wclCommand + cmdOptions)

        debugPrint("RC from Attachment Update: " + str(rc))



def pathToDict(path):

    dirContents = {}
    for dir in os.listdir(path):
        if not os.path.isdir(os.path.join(path, dir)):
            continue
        dirContents[dir] = os.listdir(os.path.join(path, dir))

    return dirContents

def debugPrint(msg):
    if args.debug:
        print(msg)

def main():

    parseCommandLine()

    initialize()
    validateArguments()

    fetchCrossReference()
    loadCrossReference()

    attachments = readAttachments()
    loadAttachments(attachments)



if __name__ == '__main__':
    main()
