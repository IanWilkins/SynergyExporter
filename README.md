# README for Synergy Exporter/Importer Scripts

## export.pl

## ewm_update.pl

usage: ewm_update [-h] [--wcl [WCLCOMMAND]] [-d [SOURCEDIR]] [--url [EWMURL]] [--projectArea [PROJECTAREA]] [-u [USER]] [-p [PASSWORD]] [--query [QUERYNAME]]
                  [--work [WORKINGDIR]] [--skipAttachments] [--skipLinks] [--debug] [--rmiServer] [--server [SERVER]]

Update Workitems after import

options:
  -h, --help            show this help message and exit
  --wcl [WCLCOMMAND]    Path to the WCL directory
  -d [SOURCEDIR], --dir [SOURCEDIR]
                        Path to the Synergy Export directory
  --url [EWMURL]        URL of EWM instance
  --projectArea [PROJECTAREA]
                        Project Area Name
  -u [USER], --user [USER]
                        User id to connect to EWM with
  -p [PASSWORD], --pass [PASSWORD]
                        Password to connect to EWM with
  --query [QUERYNAME]   Query to use to lookup imported objects
  --work [WORKINGDIR]   Directory for working and temp files
  --skipAttachments     Skip Processing Attachments
  --skipLinks           Skip Processing Links
  --debug               Turn on debug messages
  --rmiServer           Experimental - Use RMI Server
  --server [SERVER]     Experimental - Connect to RMI server