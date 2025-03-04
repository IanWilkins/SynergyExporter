#!/usr/bin/perl -w
#
=head1 NAME

    CRExport.pl

=head1 SYNOPSIS

    perl CRExport.pl

    Options:

        [-exportDir <export directory>]
        [-user <user id to connect to Synergy>]
        [-password <password to connect to Synergy>]
        [-db <database path to export from>]
        [-server <Synergy server URL>]



=head1 OPTIONS

=over 8

=item B<exportDir E<lt>export directoryE<gt>>

The directory to load the CR/IR and Attachment data into. This will override hardcoded setting for the variable $exportDir in the USER CONFIG SECTION.

=item B<user E<lt>user id to connect to Change and SynergyE<gt>>

The user to connect to Change and Synergy with. This will override hardcoded setting for the variable $username in the USER CONFIG SECTION

=item B<password E<lt>password to connect to Change and SynergyE<gt>>

The password to connect to Change and Synergy with. This will override hardcoded setting for the variable $password in the USER CONFIG SECTION

=item B<db E<lt>database path to export fromE<gt>>

The database path to connect to Change and Synergy with. This will override hardcoded setting for the variable $db in the USER CONFIG SECTION

=item B<server E<lt>Synergy Server URLE<gt>>

The Synergy Server to connect with when running on Windows. This will override hardcoded setting for the variable $server in the USER CONFIG SECTION

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

my $maxStringLength = 32000;

my $username= "ccm_root";
my $password= "ccm_root";
my $db      = "/ccmdb/training";
my $role    = "ccm_admin";
my $server  = "https://server.example.com:8400";

my $exportDir           = "./exports/";              # Default export directory

# The following are my OUTPUT data files
my $statusFile          = "export.log";             # The name of the export log file

# Misc fields
my $del = '';
my $dcm_del = '';

# Field Mappings
my %CRFields = 	(change_impact => 'changeimpact',
                 submitter => 'com.ibm.team.workitem.attribute.creator',
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
                 problem_synopsis => 'com.ibm.team.workitem.attribute.summary',
                 sw_load => 'com.crane.attribute.sw_load',
                 transition_log => 'transitionlog',
                 object_type => 'com.ibm.team.workitem.attribute.workitemtype');

my %IRFields = (actual_duration => 'actual_duration',
                actual_verification_duration => 'actual_verification_duration',
                change_impact => 'changeimpact',
                check_list_working => 'checklist',
                check_list => 'checklist1_history',
                check_list_completed => 'checklist1_status2',
                submitter => 'com.ibm.team.workitem.attribute.creator',
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
                problem_synopsis => 'com.ibm.team.workitem.attribute.summary',
                sw_load => 'com.crane.attribute.sw_load',
                transition_log => 'transitionlog',
                object_type => 'com.ibm.team.workitem.attribute.workitemtype',
                verif_engr => 'verification_engineer',
                verif_priority => 'verificationPriority',
                IR_STATIC => 'old_change_type');

my %RCRFields = (actual_duration => 'actual_duration',
                actual_verification_duration => 'actual_verification_duration',
                check_list_working => 'checklist',
                check_list => 'checklist1_history',
                check_list_completed => 'checklist1_status2',
                submitter => 'com.ibm.team.workitem.attribute.creator',
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
                request_type => 'requesttype',
                resolver => 'com.crane.cr_process.resolver',
                crstatus => 'com.ibm.team.workitem.attribute.state',
                problem_synopsis => 'com.ibm.team.workitem.attribute.summary',
                sw_load => 'com.crane.attribute.sw_load',
                transition_log => 'transitionlog',
                IR_STATIC => 'com.ibm.team.workitem.attribute.workitemtype',
                verif_engr => 'verification_engineer',
                verif_priority => 'verificationPriority',
                RCR_STATIC => 'old_change_type');

my %cCRFields = (change_impact => 'changeimpact',
                 submitter => 'com.ibm.team.workitem.attribute.creator',
                 create_time => 'com.ibm.team.workitem.attribute.creationdate',
                 problem_description => 'com.ibm.team.workitem.attribute.description',
                 project_name => 'com.ibm.team.workitem.attribute.category',
                 investigator => 'com.ibm.team.workitem.attribute.owner',
                 problem_number => 'oldid',
                 crstatus => 'com.ibm.team.workitem.attribute.state',
                 problem_synopsis => 'com.ibm.team.workitem.attribute.summary',
                 transition_log => 'transitionlog',
                 Investigation_STATIC => 'task_type',
                 Task_STATIC => 'com.ibm.team.workitem.attribute.workitemtype');

my %TaskFields = (change_impact => 'changeimpact',
                  submitter => 'com.ibm.team.workitem.attribute.creator',
                  resolver => 'com.ibm.team.workitem.attribute.owner',
                  create_time => 'com.ibm.team.workitem.attribute.creationdate',
                  task_description => 'com.ibm.team.workitem.attribute.description',
                  est_duration => 'com.ibm.team.workitem.attribute.duration',
                  release => 'com.ibm.team.workitem.attribute.category',
                  task_number => 'oldid',
                  priority => 'com.ibm.team.workitem.attribute.priority',
                  status => 'com.ibm.team.workitem.attribute.state',
                  task_synopsis => 'com.ibm.team.workitem.attribute.summary',
                  status_log => 'transitionlog',
                  Regular_Task_STATIC => 'task_type',
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
   $CCM_HOME = $Registry->{"HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Telelogic\\CM Synergy\\7.2.2\\Install\\ccm_home"};
} else {
   # it's UNIX (I hope)
   $os = "UNIX";
   $subdir = "\/";
   $null = "> /dev/null 2>&1";

}

# Parse command line options
parseCmdLine();

# Ensure files are present to match our options
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

chdir $startDir;

exit;
############### END MAIN BLOCK #############

##########################################################################################################

##########################################################################################################
#
# Export the CRs to the CSV file
sub exportProblems {
    exportObjects("CR", %CRFields);
    exportObjects("cCR", %cCRFields);
    exportObjects("IR", %IRFields);
    exportRCRs("RCR", %RCRFields);
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
        } elsif ($key =~ /_STATIC$/) {
            # Not searching for the field just statically mapping
            $format .= substr($key, 0, -7) . "@@@"
        } else {
            $format .= "%" . $key . "@@@";
        }
        push @headers, $fields{$key};
    }

    # Push the headers record into the output array.
    push @outputRecords, [@headers];

    # Strip off the last @@@
    $format = substr($format, 0, -3) . "@@@@@@\"";

    dbprint("Query: " . $query . " " . $format);

    my $qryResults = `$query $format`;

    my @results = split /@@@@@@\n/, $qryResults;

    my $arraySize = @results;

    for my $record (@results) {

        my @attrs = split /@@@/, $record;

        my $attribIndex = 0;
        my $attribId = '';
        my @attribAttachments = ();
        for my $attrib (@attrs) {
            # Save the id incase we need it to create attachments
            if ($headers[$attribIndex] eq 'oldid') {
                $attribId = $attrib;
            }
            if (length($attrib) > $maxStringLength) {
                # Add the attribute to the attachments
                push @attribAttachments, [$headers[$attribIndex],$attrib];
                $attrib = substr($attrib, 0, $maxStringLength);
            }
            # Convert the <void>'s to empty strings
            if ($attrib eq "<void>") {
                $attrib = "";
            }
            $attribIndex++;
        }

        # Push the record into the output array.
        push @outputRecords, [@attrs];

	if (scalar(@attribAttachments) > 0) {
	    processAttachments($attribId, \@attribAttachments);
        }

    }
    my $newCSV = csv ({ binary => 1, in => \@outputRecords, out => $objectType . ".csv", sep_char => "," });

    exportAttachments($objectType);

}

##########################################################################################################
#
sub exportRCRs {
    my ($objectType, %fields) = @_;

    my @outputRecords = ();

    my $query = "ccm query -t problem -ns -u \"crstatus match \'rcr_*\'\"";
    # Build the output statement
    my $format = "-f \"";
    my @headers = ();

    for my $key (sort keys(%fields)) {
        if ($key eq "problem_number") {
            $format .= "%created_in" . $dcm_del . "%" . $key . "@@@";
        } elsif ($key =~ /_STATIC$/) {
            # Not searching for the field just statically mapping
            $format .= substr($key, 0, -7) . "@@@"
        } else {
            $format .= "%" . $key . "@@@";
        }
        push @headers, $fields{$key};
    }

    # Push the headers record into the output array.
    push @outputRecords, [@headers];

    # Strip off the last @@@
    $format = substr($format, 0, -3) . "@@@@@@\"";

    dbprint("Query: " . $query . " " . $format);

    my $qryResults = `$query $format`;

    my @results = split /@@@@@@\n/, $qryResults;

    my $arraySize = @results;

    for my $record (@results) {

        my @attrs = split /@@@/, $record;

        for my $attrib (@attrs) {
            if (length($attrib) > $maxStringLength) {
                $attrib = substr($attrib, 0, $maxStringLength);
            }
            # Convert the <void>'s to empty strings
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

    dbprint($query);

    my @results = `$query $format`;

    for my $record (@results) {

        chomp $record;

        my ($cvid, $parentId) = split /@@@/, $record;

        my $relateQry = "ccm query -ns -u -t problem \"is_associated_ir_of(cvid=" . $cvid . ")\" -f \"%created_in" . $dcm_del . "%problem_number\"";

        dbprint ($relateQry);

        my @children = `$relateQry`;

        for my $child (@children) {
            chomp $child;

            push @outputRecords, [($parentId, $child, 'associated_ir')];

        }

    }

    # Query for IRs that have child Tasks
    my $query2 = "ccm query -t problem -ns -u \"object_type=\'IR\' and has_associated_task(cvtype=\'task\')\"";

    dbprint($query2);

    my @results2 = `$query2 $format`;

    for my $record (@results2) {

        chomp $record;

        my ($cvid, $parentId) = split /@@@/, $record;

        my $relateQry = "ccm query -ns -u -t task \"is_associated_task_of(cvid=" . $cvid . ")\" -f \"%created_in" . $dcm_del . "%task_number\"";

        dbprint ($relateQry);

        my @children = `$relateQry`;

        for my $child (@children) {
            chomp $child;

            push @outputRecords, [($parentId, $child, 'associated_task')];

        }

    }

    # Query for CRs that have child cCRs
    my $query3 = "ccm query -t problem -ns -u \"object_type=\'CR\' and has_associated_cr(cvtype=\'problem\' and object_type=\'cCR\')\"";

    dbprint($query3);

    my @results3 = `$query3 $format`;

    for my $record (@results3) {

        chomp $record;

        my ($cvid, $parentId) = split /@@@/, $record;

        my $relateQry = "ccm query -ns -u -t problem \"is_associated_cr_of(cvid=" . $cvid . ")\" -f \"%created_in" . $dcm_del . "%problem_number\"";

        dbprint ($relateQry);

        my @children = `$relateQry`;

        for my $child (@children) {
            chomp $child;

            push @outputRecords, [($parentId, $child, 'associated_cr')];

        }

    }

    # Query for CRs that have child RCRs
    my $query4 = "ccm query -t problem -ns -u \"object_type=\'CR\' and has_associated_rcr(cvtype=\'problem\')\"";

    dbprint($query4);

    my @results4 = `$query4 $format`;

    for my $record (@results3) {

        chomp $record;

        my ($cvid, $parentId) = split /@@@/, $record;

        my $relateQry = "ccm query -ns -u -t problem \"is_associated_rcr_of(cvid=" . $cvid . ")\" -f \"%created_in" . $dcm_del . "%problem_number\"";

        dbprint ($relateQry);

        my @children = `$relateQry`;

        for my $child (@children) {
            chomp $child;

            push @outputRecords, [($parentId, $child, 'associated_rcr')];

        }

    }

    my $newCSV = csv ({ binary => 1, in => \@outputRecords, out => "relationships.csv", sep_char => "," });

}

##########################################################################################################
#
# Export the attachments
sub processAttachments {

    my ($attribId, $attribAttachments) = @_;

    my $current_dir = cwd;

    chdir "attachments";

    make_path ($attribId);

    chdir $attribId;

    for my $record (@$attribAttachments) {
        open(FH, '>', @$record[0] . ".txt") or die $!;
        print FH @$record[1];
        close(FH);
    }

    chdir $current_dir;
}

##########################################################################################################
#
# Export the attachments
sub exportAttachments {

    my ($objectType) = @_;

    my $current_dir = cwd;

    chdir $current_dir . $subdir . "attachments";

    my $query = "ccm query -t problem -ns -u \"object_type=\'$objectType\' and has_attachment(has_attr(\'attachment_name\'))\"";
    # Build the output statement
    my $format = "-f \"%cvid@@@%created_in" . $dcm_del . "%problem_number\"";

    my @results = `$query $format`;

    for my $record (@results) {

        chomp $record;
        my ($cvid, $id) = split /@@@/, $record;
        make_path($id);
        chdir $id;

        my $attachQuery = "ccm query -ns -u \"is_attachment_of(cvid=" . $cvid . ")\" -f \"%objectname@@@%attachment_name\"";

        my @attachResults = `$attachQuery`;

        for my $attachment (@attachResults) {
            chomp $attachment;

            my ($objectId, $attachment_name) = split /@@@/, $attachment;
            my $catCmd = "ccm cat \"" . $objectId . "\" > \"" . $attachment_name . "\"";

            my $rc = `$catCmd`;

        }

        chdir $current_dir . $subdir . "attachments";
    }


    chdir $current_dir;


}

##########################################################################################################
#
sub exportTasks {

    my @outputRecords = ();

    my $query = "ccm query -t task -ns -u \"status!=\'task_automatic\' and status!=\'component_task\'\"";
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
            if (length($attrib) > $maxStringLength) {
                $attrib = substr($attrib, 0, $maxStringLength);
            }
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
# Basic script initialization to prepare for exporting.  Open the log file, setup the connection parameters,
# login the user who is to perform the export operation.  This user must have the ccm_admin role.  And finally
# get the current list of source attributes.
#
sub initialize {

    $startDir = cwd;

    # Check if the export dir exists, if not create it and then cd into it.
    if (-e $exportDir and -d $exportDir) {
        chdir $exportDir;
    } else {
        make_path $exportDir;
        chdir $exportDir;
    }
    make_path("attachments");

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
    die("Cannot open the export log file: $logfile. $!.");
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
        $start_cmd = "ccm start -s $server -r ccm_admin -n $username -pw $password -q -nogui -m -d $db 2> NUL";
    } else {
        $start_cmd = "ccm start -r ccm_admin -q -nogui -m -d $db 2>/dev/null";
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
             "server=s"     => \$server,
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
