#!/usr/bin/perl -w
#
=head1 NAME

    CRExport.pl

=head1 SYNOPSIS

    perl CRExport.pl

    Options:

        [exportDir <export directory]
        [user <user id to connect to Synergy>]
        [password <password to connect to Synergy>]
        [db <database path to export from>]



=head1 OPTIONS

=over 8

=item B<exportDir E<lt>export directoryE<gt>>

The filename to load the CR data into. This will override hardcoded setting for the variable $attachDir in the USER CONFIG SECTION

=item B<user E<lt>user id to connect to Change and SynergyE<gt>>

The user to connect to Change and Synergy with. This will override hardcoded setting for the variable $username in the USER CONFIG SECTION

=item B<password E<lt>password to connect to Change and SynergyE<gt>>

The password to connect to Change and Synergy with. This will override hardcoded setting for the variable $password in the USER CONFIG SECTION

=item B<db E<lt>database path to export fromE<gt>>

The database path to connect to Change and Synergy with. This will override hardcoded setting for the variable $db in the USER CONFIG SECTION

=back

=head1 DESCRIPTION

B<export.pl> will export all the CRs/IRs and Tasks from Synergy to a CS file. Also exports attachments to a directory

=cut

##############################################################################
# Include required perl modules
#
use Text::CSV_XS qw(csv);
use Pod::Usage;
use Getopt::Long;
use FileHandle;
use strict;
use Env qw(CCM_HOME CCM_ADDR CCM_UILOG);
use File::Basename;
use Config;
use Time::Local;
use Data::Dumper;
use Cwd qw(cwd);
use File::Basename qw(fileparse);
use File::Path qw(make_path);
use File::Spec;

my $file=basename($0);

###################################### BEGIN USER CONFIG SECTION ##########################################

# Environment Information
# Login information

my $username= "ccm_root";
my $password= "ccm_root";
my $db      = "/ccmdb/training";
my $role    = "ccm_admin";

my $exportDir           = "./export/";              # Default export directory

# The following are my OUTPUT data files
my $statusFile          = "import.log";             # The name of the import log file

# Misc fields
my $del = '';
my $dcm_del = '';
my $dir_del = '/';

# Field Mappings
my %CRFields = 	(change_impact => 'changeimpact',
                 creator => 'com.ibm.team.workitem.attribute.creator',
                 create_time => 'com.ibm.team.workitem.attribute.creationdate',
                 custom_1 => 'custom1',
                 custom_2 => 'custom2',
                 custom_3 => 'custom_3',
                 custom_4 => 'custom_4',
                 defer_date	 => 'defer_date',
                 problem_description => 'com.ibm.team.workitem.attribute.description',
                 est_duration => 'com.ibm.team.workitem.attribute.duration',
                 project_name => 'com.ibm.team.workitem.attribute.category',
                 investigator => 'investigator',
                 problem_number => 'oldid',
                 part_number => 'part_number',
                 priority => 'com.ibm.team.workitem.attribute.priority',
                 program => 'program',
                 reason_for_request => 'reason-for-investigation',
                 request_origin => 'request_origin',
                 request_type => 'requesttype',
                 resolver => 'com.crane.cr_process.resolver',
                 severity => 'com.ibm.team.workitem.attribute.severity',
                 crstatus => 'com.ibm.team.workitem.attribute.state',
                 submitter => 'submitter',
                 problem_synopsys => 'com.ibm.team.workitem.attribute.summary',
                 sw_load => 'com.crane.attribute.sw_load',
                 transition_log => 'transitionlog',
                 object_type => 'com.ibm.team.workitem.attribute.workitemtype');

my %IRFields = (actual_duration => 'actual_duration',
                actual_verification_duration => 'actual_verification_duration',
                change_impact => 'changeimpact',
                check_list_working => 'checklist',
                check_list => 'checklist1_history',
                check_list_completed => 'checklist1_status2',
                creator => 'com.ibm.team.workitem.attribute.creator',
                create_time => 'com.ibm.team.workitem.attribute.creationdate',
                defect_list => 'defect.history',
                defect_list_completed => 'defect.status',
                defect_list_working => 'defects_list',
                defer_date => 'defer_date',
                problem_description => 'com.ibm.team.workitem.attribute.description',
                est_duration => 'com.ibm.team.workitem.attribute.duration',
                est_completion_date => 'estimated_completion_date',
                est_duration => 'estimated_duration',
                est_verification_date => 'estimated_verification_date',
                est_verification_duration => 'estimated_verification_duration',
                project_name => 'com.ibm.team.workitem.attribute.category',
                functional_group => 'functional_group',
                keyword => 'keyword',
                minutes_working => 'meeting_minutes',
                minutes => 'meeting.minutes.history',
                minutes_completed => 'meeting.minutes.status',
                problem_number => 'oldid',
                part_number => 'part_number',
                priority => 'com.ibm.team.workitem.attribute.priority',
                product_name => 'product_name',
                product_version => 'product_version',
                program => 'program',
                request_origin => 'request_origin',
                request_type => 'requesttype',
                resolver => 'com.crane.cr_process.resolver',
                severity => 'com.ibm.team.workitem.attribute.severity',
                crstatus => 'com.ibm.team.workitem.attribute.state',
                problem_synopsys => 'com.ibm.team.workitem.attribute.summary',
                sw_load => 'com.crane.attribute.sw_load',
                transition_log => 'transitionlog',
                object_type => 'com.ibm.team.workitem.attribute.workitemtype',
                verif_engr => 'verification_engineer',
                verif_priority => 'verificationPriority');

my %TaskFields = (change_impact => 'changeimpact',
                  creator => 'com.ibm.team.workitem.attribute.creator',
                  resolver => 'com.ibm.team.workitem.attribute.owner',
                  create_time => 'com.ibm.team.workitem.attribute.creationdate',
                  task_description => 'com.ibm.team.workitem.attribute.description',
                  est_duration => 'com.ibm.team.workitem.attribute.duration',
                  release => 'com.ibm.team.workitem.attribute.category',
                  task_number => 'oldid',
                  priority => 'com.ibm.team.workitem.attribute.priority',
                  status => 'com.ibm.team.workitem.attribute.state',
                  task_synopsis => 'com.ibm.team.workitem.attribute.summary',
                  transition_log => 'transitionlog',
                  cvtype => 'com.ibm.team.workitem.attribute.workitemtype');

###################################### END USER CONFIG SECTION ##########################################
# Define System Globals
my $startTime;                                      # Value in seconds when we first started procesing data
my $startDir;

#########################################################################################################
#                                           BEGIN MAIN EXECUTION                                        #
#########################################################################################################

# Predefine some needed functions
#
sub error_cleanup;
sub dbprint;
sub sig_cleanup;

#
# catch signals SIGINT(2) SIGQUIT(3) SIGKILL(9) SIGTERM(15)
# not catching SIGTRAP(5) since it is not on Win32
#
$SIG{'INT'}=$SIG{'QUIT'}=$SIG{'KILL'}=$SIG{'TERM'}=\&sig_cleanup;

# Add the config stuff to determine what OS we're running on

use vars qw($subdir $os $null $Registry $debug $man $help);

if ($Config{'osname'} eq 'MSWin32') {
   # Hey we're running on windows -- need more information
   $os = "MSWin32";
   $subdir = "\\";
   $null = "> NUL 2>&1";
   # Fetch CCM_HOME from the registry. Need this for E-MAIL
   # We use require and import instead of use so UNIX doesn't complain
   require Win32::TieRegistry;
   import Win32::TieRegistry;
   $CCM_HOME = $Registry->{"HKEY_LOCAL_MACHINE\\SOFTWARE\\Telelogic\\CM Synergy\\6.5\\Install\\ccm_home"};

} else {
   # it's UNIX (I hope)
   $os = "UNIX";
   $subdir = "\/";
   $null = "> /dev/null 2>&1";

}

# Parse command line options
parseCmdLine();

# Ensure files are present to match our options
validateFiles();

initialize();

#------------------------------------------------------------------------------------------------------
# Start up Synergy
startSynergySession();

#------------------------------------------------------------------------------------------------------
# Export Problmes
exportProblems();

#------------------------------------------------------------------------------------------------------
# Export Tasks
exportTasks();

#------------------------------------------------------------------------------------------------------
# Export Relationships
exportRelationships();


#------------------------------------------------------------------------------------------------------
# Cleanup
closeSynergySession();

closeLogFile();

cd $startDir;

exit;
############### END MAIN BLOCK #############

##########################################################################################################

##########################################################################################################
#
# Export the CRs to the CSV file
sub exportProblems {
    exportObjects("CR", %CRFields);
    exportObjects("IR", %IRFields);
}

##########################################################################################################
#
# Export the CRs/IRs to the CSV file
sub exportObjects {
    my ($objectType, %fields) = @_;

    my @outputRecords = ();

    my $query = "ccm query -t problem -ns -u \"object_type=\'$objectType\'\"";
    # Build the output statement
    my $format = "-f \"";
    my @headers = ();

    for my $key (sort keys(%fields)) {
        if ($key eq "problem_number") {
            $format .= "%created_in" . $dcm_del . "%" . $key . "@@@";
        } else {
            $format .= "%" . $key . "@@@";
        }
        push @headers, $fields{$key};
    }

    # Push the headers record into the output array.
    push @outputRecords, [@headers];

    # Strip off the last @@@
    $format = substr($format, 0, -3) . "@@@@@@\"";

    my $qryResults = `$query $format`;

    my @results = split /@@@@@@\n/, $qryResults;

    my $arraySize = @results;

    for my $record (@results) {

        my @attrs = split /@@@/, $record;

        # Convert the <void>'s to empty strings
        for my $attrib (@attrs) {
            if ($attrib eq "<void>") {
                $attrib = "";
            }
        }

        # Push the record into the output array.
        push @outputRecords, [@attrs];

    }
    my $newCSV = csv ({ binary => 1, in => \@outputRecords, out => $objectType . ".csv", sep_char => "," });

    exportAttachments($objectType);

}
##########################################################################################################
#
# Export the relationships to the CSV file
sub exportRelationships {
    my @outputRecords = ();


    # Push the headers record into the output array.
    my @headers = ('parent', 'child', 'relationship');
    push @outputRecords, [@headers];

    # Query for CRs that have child IRs
    my $query = "ccm query -t problem -ns -u \"object_type=\'CR\' and has_associated_ir(cvtype=\'problem\' and object_type=\'IR\')\"";

    # Build the output statement
    my $format = "-f \"%cvid@@@%created_in" . $dcm_del. "%problem_number\"";


    my @results = `$query $format`;

    for my $record (@results) {

        chomp $record;

        my ($cvid, $parentId) = split /@@@/, $record;

        my $relateQry = "ccm query -ns -u -t problem \"is_associated_ir_of(cvid=" . $cvid . ")\" -f \"%created_in" . $dcm_del . "%problem_number\"";

        my @children = `$relateQry`;

        for my $child (@children) {
            chomp $child;

            push @outputRecords, [($parentId, $child, 'associated_ir')];

        }

    }

    # Query for IRs that have child Tasks
    my $query2 = "ccm query -t problem -ns -u \"object_type=\'IR\' and has_associated_task(cvtype=\'task\')\"";

    my @results2 = `$query2 $format`;

    for my $record (@results2) {

        chomp $record;

        my ($cvid, $parentId) = split /@@@/, $record;

        my $relateQry = "ccm query -ns -u -t task \"is_associated_task_of(cvid=" . $cvid . ")\" -f \"%created_in" . $dcm_del . "%task_number\"";

        my @children = `$relateQry`;

        for my $child (@children) {
            chomp $child;

            push @outputRecords, [($parentId, $child, 'associated_task')];

        }

    }

    my $newCSV = csv ({ binary => 1, in => \@outputRecords, out => "relationships.csv", sep_char => "," });

}

##########################################################################################################
#
# Export the attachments
sub exportAttachments {

    my ($objectType) = @_;

    my $current_dir = cwd;

    mkdir "attachments";

    chdir $current_dir . $dir_del . "attachments";

    my $query = "ccm query -t problem -ns -u \"object_type=\'$objectType\' and has_attachment(has_attr(\'attachment_name\'))\"";
    # Build the output statement
    my $format = "-f \"%cvid@@@%created_in" . $dcm_del . "%problem_number\"";

    my @results = `$query $format`;

    for my $record (@results) {

        chomp $record;
        my ($cvid, $id) = split /@@@/, $record;
        mkdir $id;
        chdir $id;

        my $attachQuery = "ccm query -ns -u \"is_attachment_of(cvid=" . $cvid . ")\" -f \"%objectname@@@%attachment_name\"";

        my @attachResults = `$attachQuery`;

        for my $attachment (@attachResults) {
            chomp $attachment;

            my ($objectId, $attachment_name) = split /@@@/, $attachment;
            my $catCmd = "ccm cat \"" . $objectId . "\" > \"" . $attachment_name . "\"";

            my $rc = `$catCmd`;

        }

        chdir $current_dir . $dir_del . "attachments";
    }


    chdir $current_dir;


}

##########################################################################################################
#
sub exportTasks {

    my @outputRecords = ();

    my $query = "ccm query -t task -ns -u \"status!=\'task_automatic\'\"";
    # Build the output statement
    my $format = "-f \"";
    my @headers = ();

    for my $key (sort keys(%TaskFields)) {
        if ($key eq "task_number") {
            $format .= "%created_in" . $dcm_del . "%" . $key . "@@@";
        } else {
            $format .= "%" . $key . "@@@";
        }
        push @headers, $TaskFields{$key};
    }

    # Push the headers record into the output array.
    push @outputRecords, [@headers];

    # Strip off the last @@@
    $format = substr($format, 0, -3) . "@@@@@@\"";

    my $qryResults = `$query $format`;

    my @results = split /@@@@@@\n/, $qryResults;

    my $arraySize = @results;

    for my $record (@results) {

        my @attrs = split /@@@/, $record;

        # Convert the <void>'s to empty strings
        for my $attrib (@attrs) {
            if ($attrib eq "<void>") {
                $attrib = "";
            }
        }

        # Push the record into the output array.
        push @outputRecords, [@attrs];

    }
    my $newCSV = csv ({ binary => 1, in => \@outputRecords, out => "Tasks.csv", sep_char => "," });


}

##########################################################################################################
#
# Basic script initialization to prepare for importing.  Open the log file, setup the connection parameters,
# login the user who is to perform the import operation.  This user must have the ccm_admin role.  And finally
# get the current list of source attributes.
#
sub initialize {

    $startDir = cwd;

    # Check if the export dir exists, if not create it and then cd into it.
    if (-e $exportDir and -d $exportDir) {
        chdir $exportDir;
    } else {

        make_path $exportDir
        chdir $exportDir;

    }

    eval
    {
        openLogFile($statusFile);

        if ($@) {
            printToLog($@, 1);
        }

    };

    if ($@) {
        printToLog($@, 1);
    }
}



##########################################################################################################
#  openLogFile
#  -----------
#  This routine opens the log file for status reporting.
#
sub openLogFile {
    my $logfile = shift;

    # Abort if we cannot open our log file
    unless (open ERROR, ">$logfile") {
    die("Cannot open the import log file: $logfile. $!.");
    }

    print ERROR localtime(time) . " ********** Export started **************\n";
    return 0;
}

##########################################################################################################
#  closeLogFile
#  -----------
#  This routine opens the log file for status reporting.
#
sub closeLogFile {
    print ERROR localtime(time) . " Export finished.\n";
    close ERROR;
}

##########################################################################################################
#  printToLog
#  ----------
#  This routine adds a timestamped message to the log.
#  And if its a fatal message, cleans up and exits.
#
sub printToLog {
    my $errorMessage = shift;
    my $exitStatus   = shift;

    print ERROR localtime(time) . " " . $errorMessage . "\n";

    if($exitStatus) {
        print $errorMessage . "\n";
        closeErrorLog();
        exit 1;
    }
}


##########################################################################################################
#  startSynergySession
#  -----------
#  This routine must be called to start a session on the synergy database
#

sub startSynergySession {

    my $start_cmd="";
    if ($os eq "MSWin32") {
        $start_cmd = "ccm start -r ccm_admin -n $username -pw $password -q -nogui -m -d $db 2> NUL";
        $dir_del = "\\";
    } else {
        $start_cmd = "ccm start -r ccm_admin -q -nogui -m -d $db 2>/dev/null";
        $dir_del = "/";
    }

    dbprint "Starting with cmd\n\t$start_cmd\n";
    $CCM_ADDR=`$start_cmd`;
    $CCM_ADDR=~s/\s*$//;

    if ($? != 0) { error_cleanup "Unable to start a session on $db"; }

    dbprint "The session address is $CCM_ADDR\n";

    # Validate session running
    dbprint "Determining database delimiter \n";
    $del=`ccm delim` || error_cleanup "Unable to talk with ccm session, have you started one?\n    Is 'ccm' in your PATH?";
    $del =~ s/\s*$//;

    # Determin DCM delimiter
    dbprint "Determining DCM delimiter \n";
    $dcm_del=`ccm dcm -s -delim` || error_cleanup "Unable to talk with ccm session, have you started one?\n    Is 'ccm' in your PATH?";
    $dcm_del =~ s/\s*$//;

}

##########################################################################################################
#  closeSynergySession
#  ------------
#  Close the open Synergy Session

sub closeSynergySession {

    system ("ccm stop $null");
}



##########################################################################################################
#  parseCmdLine
#  ------------
#  This routine parses the command line
#  and sets values or displays help text.
#
sub parseCmdLine {

    GetOptions("exportDir=s" => \$exportDir,
             "user=s"       => \$username,
             "password=s"   => \$password,
             "db=s"         => \$db,
             "role=s"       => \$role,
             "help|?"       => \$help,
             "man"          => \$man,
             "debug!"       => \$debug) or pod2usage(2);

    pod2usage(3) if $help;
    pod2usage(-exitstatus => 0, -verbose => 2) if $man;


    return 0;
}

##########################################################################################################
#  validateFiles
#  -------------
#  This routine verifies our import files
#  are present and sets options accordingly.
#
sub validateFiles {
    print "Checking import files:\n";

    print "\tFile Check Complete\n\n";
    return 0;
}

##########################################################################################################
#  reportStats
#  -----------
#  This routine reports the status of the import
#
sub reportStats {
    print "\n\t*****\n\tSuccessfully imported $numberSuccess out of $totalRecCount records.\n";
    my $elapsed = (time - $startTime);
    if ($elapsed != 0) {
    print "\tElapsed time: $elapsed seconds\n";
    print "\tAverage time/record: " . ($elapsed/$totalRecCount). " seconds\n";
    }
    print "\t*****\n\n";
}




##########################################################################################################
# Error caught cleanup function
#
# Incoming parameters:
#   $_[0] - the caught signal
#
# Returns:
#   does not return!
#
sub error_cleanup {

    system ("ccm stop $null");
    print "$file: $_[0] \n";
    exit 1;

}

##########################################################################################################
# Debug Print
#
# Incoming parameters:
#   $_[0] - the message to print
#
# Returns:
#   always returns 1
#

sub dbprint {
    if ($debug) {
        print Dumper($_[0]);
    }
    return 1;
}


##########################################################################################################
# Signal handler function
#
# Incoming parameters:
#   $_[0] - the caught signal
#
# Returns:
#   does not return!
#-------------------------------------------------------------------------------
sub sig_cleanup {
    $SIG{'INT'}=$SIG{'QUIT'}=$SIG{'TRAP'}=$SIG{'KILL'}=$SIG{'TERM'}=\&sig_cleanup;
    error_cleanup "Caught signal $_[0], exiting..\n";
}
