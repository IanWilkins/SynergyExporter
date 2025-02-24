# README for Synergy Exporter/Importer Scripts

---

## export.pl

### SYNOPSIS

perl CRExport.pl

**Options:**

- [-exportDir \<export directory\>]
- [-user \<user id to connect to Synergy\>]
- [-password \<password to connect to Synergy\>]
- [-db \<database path to export from\>]
- [-server \<Synergy server URL\>]

### OPTIONS

| Option   | Description |
| -------------------------------- | ---------------------------------------------------------------- |
| -exportDir \<export directory\> | The directory to load the CR/IR and Attachment data into. This will override hardcoded setting for the variable $exportDir in the USER CONFIG SECTION |
| -user \<user id to connect to Change and Synergy\> | The user to connect to Change and Synergy with. This will override hardcoded setting for the variable $username in the USER CONFIG SECTION |
| -password \<password to connect to Change and Synergy\> | The password to connect to Change and Synergy with. This will override hardcoded setting for the variable $password in the USER CONFIG SECTION |
| -db \<database path to export from\> | The database path to connect to Change and Synergy with. This will override hardcoded setting for the variable $db in the USER CONFIG SECTION |
| -server \<Synergy Server URL\> | The Synergy Server to connect with when running on Windows. This will override hardcoded setting for the variable $server in the USER CONFIG SECTION |

### DESCRIPTION

export.pl will export all the CRs/IRs and Tasks from Synergy to a CS file. Also exports attachments to a directory

---
---

## ewm_update.py

### SYNOPSIS

python ewm_update.py

- [-h]
- [--wcl [WCLCOMMAND]]
- [-d [SOURCEDIR]]
- [--url [EWMURL]]
- [--projectArea [PROJECTAREA]]
- [-u [USER]]
- [-p [PASSWORD]]
- [--query [QUERYNAME]]
- [--work [WORKINGDIR]]
- [--skipAttachments]
- [--skipLinks]
- [--debug]
- [--rmiServer]
- [--server [SERVER]]

Update Workitems after import

### OPTIONS

| Option   | Description |
| -------------------------------- | ---------------------------------------------------------------- |
| -h, --help | show this help message and exit |
| --wcl [WCLCOMMAND] | Path to the WCL directory |
| -d [SOURCEDIR], --dir [SOURCEDIR] | Path to the Synergy Export directory. This would be the "exports" directory created by the *export.pl* script |
| --url [EWMURL] | URL of EWM instance |
| --projectArea [PROJECTAREA] | Project Area Name |
| -u [USER], --user [USER] | User id to connect to EWM with |
| -p [PASSWORD], --pass [PASSWORD] | Password to connect to EWM with |
| --query [QUERYNAME] | Query to use to lookup imported objects |
| --work [WORKINGDIR] | Directory for working and temp files |
| --skipAttachments | Skip Processing Attachments. Do not attempt to update attachments |
| --skipLinks | Skip Processing Links. Do not attempt to update Parent->Child links |
| --debug | Turn on debug messages |
| --rmiServer | Experimental - Use RMI Server. This is experimental, but should improve overall performance. |
| --server [SERVER] | Experimental - Connect to RMI server at this address. To use this option start the WCL tool with the /rmiServer option |
