#!/usr/bin/perl
# Usage: $file 
#       -proj <project spec> -tasks -objects -IRS
#    
#    where:
#
#       -new <project spec>    	-- project spec. of the project
#       [-old <project spec>]	-- project spec. of the project to compare to
#       [-tasks|-notasks]       -- Include tasks in the report
#       [-IRS|-noIRS]		-- Include IRs in the report
#       [-format [HTML|ASCII]]	-- Output Format for report



# Initial Setup
#


#use strict;
use File::Basename;
use File::Path;
use File::Copy;
use Getopt::Long;
use Env qw(CCM_HOME CCM_ADDR CCM_UILOG);
use XML::Simple;


#-------------------------------------------------------------------------------
# Define function stubs
sub error_cleanup;
sub sig_cleanup;
sub dbprint;
sub usage;
sub loadcrs;
sub loadtasks; 
sub loadtasksSingle; 
sub getObjects;
sub processProjects;
sub processProject;
sub getProjectObjects;
sub print_report;
sub print_report_ascii;
sub print_report_html;
sub print_report_xml;
#-------------------------------------------------------------------------------
my $file=basename($0);
my $script_dir=dirname($0);


use vars qw($debug $old $new $incltasks $format $inclcrs);


$debug=0;


#
# catch signals SIGINT(2) SIGQUIT(3) SIGKILL(9) SIGTERM(15) 
# not catching SIGTRAP(5) since it is not on Win32
#
$SIG{'INT'}=$SIG{'QUIT'}=$SIG{'KILL'}=$SIG{'TERM'}=\&sig_cleanup; 


# Define global variables
#
my ($rc, $del, $dbid, @tasks, @report, $newproj, $oldproj, $no_compare);

# Get the input options
GetOptions(     "old=s", \$old, 
                "new=s", \$new, 
                "tasks!", \$incltasks,
                "IRs!", \$inclcrs,
                "debug!", \$debug,
                "format=s", \$format);



# Process options
#
if (not (defined $new)) {
    usage();
}

if (not (defined $old)) {
	$no_compare = 1;
} else {
	$no_compare = 0;
}

if (not(defined $incltasks)) {
    $incltasks = 1;
}

if (not(defined $inclcrs)) {
    $inclcrs = 1;
}

if (not(defined $format)) {
    $format = "HTML";
}


dbprint "Options:\n\told: $old\n\tnew: $new\n\ttasks $incltasks\n\tIRs $inclcrs\n\tdebug: $debug\n";

# Main line


# Validate session running
dbprint "Determining database delimiter \n";
$del=`ccm delim` || error_cleanup "Unable to talk with ccm session, have you started one?\n    Is 'ccm' in your PATH?";
$del =~ s/\s*$//;


dbprint "Determining dcm id \n";
$dbid=`ccm dcm -show -dbid` || error_cleanup "Unable to determine the DCM id\n";
$dbid =~ s/\s*$//;
if ($dbid eq "") {
           $dbid = "probtrac";
}


if ($no_compare == 0) {
	# Validate projects exist
	#
	my ($name, $version) = split /$del/, $old;
	
	
	dbprint "Get old project objectname\n";
	my ($oldstatus,$oldrelease);
	my ($oldobj) = `ccm query -t project -v \"$version\" -n \"$name\" -ns -u -f \"%objectname####%status####%release\"` || error_cleanup "Project $old does not exist in the database\n";
	$oldobj =~ s/\s*$//; 
	($oldobj, $oldstatus) = split /####/, $oldobj;
	dbprint "Old project objectname: $oldobj\n";
	
	$oldproj = {"name" => $name};
	$oldproj->{"version"} = $version;
	$oldproj->{"objectname"} = $oldobj;
	$oldproj->{"proj_spec"} = $old;
	$oldproj->{"status"} = $oldstatus;
	$oldproj->{'release'} = $oldrelease;

}

($name, $version) = split /$del/, $new;

dbprint "Get new project objectname\n";
my ($newstatus, $newrelease);
my ($newobj) = `ccm query -t project -v \"$version\" -n \"$name\" -ns -u -f \"%objectname####%status####%release\"` || error_cleanup "Project $new does not exist in the database\n";
$newobj =~ s/\s*$//; 
($newobj, $newstatus) = split /####/, $newobj;
dbprint "New project objectname: $newobj\n";

$newproj = {"name" => $name};
$newproj->{"version"} = $version;
$newproj->{"objectname"} = $newobj;
$newproj->{"proj_spec"} = $new;
$newproj->{"status"} = $newstatus;
$newproj->{'release'} = $newrelease;

dbprint "Newproject $newproj->{'name'}\nVersion: $newproj->{'version'}\nObjectname: $newproj->{'objectname'}\n\n";
if ($no_compare == 0) {
	dbprint "Oldproject $oldproj->{'name'}\nVersion: $oldproj->{'version'}\nObjectname: $oldproj->{'objectname'}\n\n";
	process_projects($newproj, $oldproj);
} else {
	process_project($newproj);
}



exit 0;


###############################################################################
###############################################################################
# Sub routines
###############################################################################
###############################################################################


#-------------------------------------------------------------------------------
# process_projects
#
# Process a directory level
#
# Incoming:
#       $newproj - Original Project
#       $oldproj - New Project
#
# Returns:
#       0 - Success
#       1 - Error
#
#-------------------------------------------------------------------------------
sub process_projects {

    my ($newproj, $oldproj) = @_;

    my $report = {};
    
    # load the new project object hash
    getProjectObjects($newproj);
    getProjectObjects($oldproj);
    
    $report->{'project'}->{'name'} = $newproj->{'name'};
    $report->{'project'}->{'version'} = $newproj->{"version"};
    $report->{'project'}->{'objectname'} = $newproj->{"objectname"};
    $report->{'project'}->{'proj_spec'} = $newproj->{"proj_spec"};
    $report->{'project'}->{'status'} = $newproj->{"status"};
    $report->{'project'}->{'release'} = $newproj->{"release"};
        
    # Compare the two projects using the new as the source
    foreach $key (keys (%{$newproj->{'objects'}})) {
        
        # if this is just a directory skip it
        if ($newproj->{'objects'}->{$key}->{'type'} eq 'dir') {
            next;
        }
        
        # check to see if the object is in the old project
        if (exists($oldproj->{'objects'}->{$key})) {
            
            # is the version the same
            if ($oldproj->{'objects'}->{$key}->{'version'} eq $newproj->{'objects'}->{$key}->{'version'}) {
                
                # is it in the same location
                if ($oldproj->{'objects'}->{$key}->{'path'} ne $newproj->{'objects'}->{$key}->{'path'}) {
                    
                    $report->{'moved'}->{$key} = $newproj->{'objects'}->{$key};
                    
                }
            } else {
                $report->{'updated'}->{$key} = $newproj->{'objects'}->{$key};
            }
            
        } else { # It doesn't exist
            
            $report->{'new'}->{$key} = $newproj->{'objects'}->{$key};
        }
    }
    
    # Compare the two projects using the old as the source
    # We're looking for deleted files
    foreach $key (keys (%{$oldproj->{'objects'}})) {
        
        # if this is just a directory skip it
        if ($oldproj->{'objects'}->{$key}->{'type'} eq 'dir') {
            next;
        }
        
        # check to see if the object is in the new project
        if (exists($newproj->{'objects'}->{$key})) {
            
            next;
            
        } else { # It doesn't exist
            
            $report->{'deleted'}->{$key} = $oldproj->{'objects'}->{$key};
        }
    }

    if ($incltasks || $inclcrs) {
        loadtasks($newproj, $oldproj, $report);
    }
    
    if ($inclcrs) {
        loadcrs ($report);
    }
    
    print_report($report, $format);
    
    return 1;

}

#-------------------------------------------------------------------------------
# process_project
#
# Process a directory level
#
# Incoming:
#       $newproj - Original Project
#
# Returns:
#       0 - Success
#       1 - Error
#
#-------------------------------------------------------------------------------
sub process_project {

    my ($newproj) = @_;

    my $report = {};
    
    # load the new project object hash
    getProjectObjects($newproj);
    
    $report->{'project'}->{'name'} = $newproj->{'name'};
    $report->{'project'}->{'version'} = $newproj->{"version"};
    $report->{'project'}->{'objectname'} = $newproj->{"objectname"};
    $report->{'project'}->{'proj_spec'} = $newproj->{"proj_spec"};
    $report->{'project'}->{'status'} = $newproj->{"status"};
    $report->{'project'}->{'release'} = $newproj->{"release"};
        
    # Compare the two projects using the new as the source
    foreach $key (keys (%{$newproj->{'objects'}})) {
        
        # if this is just a directory skip it
        if ($newproj->{'objects'}->{$key}->{'type'} eq 'dir') {
            next;
        }
                    
        $report->{'new'}->{$key} = $newproj->{'objects'}->{$key};

    }
    

    if ($incltasks || $inclcrs) {
        loadtasksSingle($newproj, $report);
    }
    
    if ($inclcrs) {
        loadcrs ($report);
    }
    
    print_report($report, $format);
    
    return 1;

}

#-------------------------------------------------------------------------------
# loadcrs
#
# Load the objects in the project into the hash passed in 
#-------------------------------------------------------------------------------
sub loadcrs {
    
    my ($report) = @_;
    
    foreach $key (keys %{$report->{'tasks'}} ) {
        
        # get all IRS associated with the task
        my $querycmd = "ccm query -ns -u -t problem \"has_associated_task(\'" . $report->{'tasks'}->{$key}->{'objectname'} . "\')\" ";
        $querycmd .= "-f \"%objectname@@@@%problem_number@@@@%problem_synopsis@@@@%release@@@@%crstatus\"";
        dbprint $querycmd;
        
        my (@crs) = `$querycmd`;
        
        foreach $cr (@crs) {
            
            $cr =~ s/\s*$//;
            
            my ($objectname, $problem_number, $synopsis, $release, $status) = split /\@\@\@\@/, $cr;
            
            # fetch the description
            $description = `ccm attr -s problem_description $objectname`;
            
            # load the report
            $report->{'crs'}->{$objectname}->{'objectname'} = $objectname;
            $report->{'crs'}->{$objectname}->{'number'} = $problem_number;
            $report->{'crs'}->{$objectname}->{'release'} = $release;
            $report->{'crs'}->{$objectname}->{'synopsis'} = $synopsis;
            $report->{'crs'}->{$objectname}->{'status'} = $status;
            $report->{'crs'}->{$objectname}->{'description'} = $description;
            $report->{'crs'}->{$objectname}->{'tasks'}->{$key} = $report->{'tasks'}->{$key};
            $report->{'tasks'}->{$key}->{'problems'} .= "$problem_number ";
            
        }
        
    }
    
    return 1;
    
}

#-------------------------------------------------------------------------------
# loadtasks
#
# Load the objects in the project into the hash passed in 
#-------------------------------------------------------------------------------
sub loadtasks {
    
    my ($newproj, $oldproj, $report) = @_;
    
    # get all tasks in the project
    my $querycmd = "ccm task -query -ns -u -in_release " . $oldproj->{'objectname'} . " " . $newproj->{'objectname'} . " -f \"%objectname@@@@%task_number@@@@%release@@@@%resolver@@@@%task_synopsis\"";
    dbprint $querycmd;
    
    my (@tasks) = `$querycmd`;
    
    foreach $task (@tasks) {
        
        $task =~ s/\s*$//;
        
        my($objectname, $task_number, $release, $resolver, $synopsis) = split /\@\@\@\@/, $task;
        
        $report->{'tasks'}->{$objectname}->{'objectname'} = $objectname;
        $report->{'tasks'}->{$objectname}->{'release'} = $release;
        $report->{'tasks'}->{$objectname}->{'resolver'} = $resolver;
        $report->{'tasks'}->{$objectname}->{'task_number'} = $task_number;
        $report->{'tasks'}->{$objectname}->{'synopsis'} = $synopsis;
        
    }
    
    return 1;
    
}


#-------------------------------------------------------------------------------
# loadtasksSingle
#
# Load the objects in the project into the hash passed in 
#-------------------------------------------------------------------------------
sub loadtasksSingle {
    
    my ($newproj, $report) = @_;
    
    # get all tasks in the project
    my $querycmd = "ccm task -query -ns -u -in_release " . $newproj->{'objectname'} . " -f \"%objectname@@@@%task_number@@@@%release@@@@%resolver@@@@%task_synopsis\"";
    dbprint $querycmd;
    
    my (@tasks) = `$querycmd`;
    
    foreach $task (@tasks) {
        
        $task =~ s/\s*$//;
        
        my($objectname, $task_number, $release, $resolver, $synopsis) = split /\@\@\@\@/, $task;
        
        $report->{'tasks'}->{$objectname}->{'objectname'} = $objectname;
        $report->{'tasks'}->{$objectname}->{'release'} = $release;
        $report->{'tasks'}->{$objectname}->{'resolver'} = $resolver;
        $report->{'tasks'}->{$objectname}->{'task_number'} = $task_number;
        $report->{'tasks'}->{$objectname}->{'synopsis'} = $synopsis;
        
    }
    
    return 1;
    
}


#-------------------------------------------------------------------------------
# print_report
#
# Load the objects in the project into the hash passed in 
#-------------------------------------------------------------------------------
sub print_report {
    
    my ($report, $format) = @_;
    
    if ($format eq "ascii") {
        print_report_ascii($report);
    } elsif ($format eq 'HTML'){
        print_report_html($report);
    } elsif ($format eq "XML") {
        print_report_xml($report);
    } else {
        print_report_ascii($report);
    }
    
}


#-------------------------------------------------------------------------------
# print_report_xml
#
# Load the objects in the project into the hash passed in 
#-------------------------------------------------------------------------------
sub print_report_xml {
    
    my ($report) = @_;
    
    my $xsimple = XML::Simple->new();

    print $xsimple->XMLout($report, noattr => 1);
    #print $xsimple->XMLout($report);
    
    return 1;
}
#-------------------------------------------------------------------------------
# print_report_html
#
# Load the objects in the project into the hash passed in 
#-------------------------------------------------------------------------------
sub print_report_html {
    
    my ($report) = @_;
    
    my (@output, @sortedOutput);
    
    print "<HTML>\n";
    print "<H1>Audit Report for $newproj->{'proj_spec'}</H1>\n";

    # Display the IRs if required
    if ($inclcrs) {
        
        print "<h3>The following IRs are included in the project</h3>\n";
        
        print "<table width=\"75%\">\n";
        print "<TR><TD><h4>#</h4></TD><TD><h4>Synopsis</h4></TD><TD><h4>Release</h4></TD><TD><h4>Status</h4></TD></TR>\n";
        # For each IR
        foreach $key (sort (keys (%{$report->{'crs'}}))) {
            
            print "<TR>\n";
            print "<TD>$report->{'crs'}->{$key}->{'number'}</td>\n";
            print "<TD>$report->{'crs'}->{$key}->{'synopsis'}</td>\n";
            print "<TD>$report->{'crs'}->{$key}->{'release'}</td>\n";
            print "<TD>$report->{'crs'}->{$key}->{'status'}</td>\n";
            
            print "</tr>\n";
            print "<tr><td colspan=\"4\"><table width=\"99%\"><tr><td><h4>Description</h4></td><td>$report->{'crs'}->{$key}->{'description'}</td></tr></table></td></tr>\n";
            
            # Now print the Tasks for this IR
            print "<tr><td colspan=\"4\"><table width=\"99%\"><tr><td><h4>Tasks included in this IR</h4></td></tr></table></td></tr>\n";
            
            print "<tr><td colspan=\"4\"><table>\n";
            print "<TR><TD><h4>#</h4></TD><TD><h4>Synopsis</h4></TD><TD><h4>Release</h4></TD><TD><h4>Resolver</h4></TD></TR>\n";
            foreach $taskkey (sort (keys (%{$report->{'crs'}->{$key}->{'tasks'}}))) {
                
                # print the task
                print "<TR>\n";
                print "<TD>$report->{'tasks'}->{$taskkey}->{'task_number'}</td>\n";
                print "<TD>$report->{'tasks'}->{$taskkey}->{'synopsis'}</td>\n";
                print "<TD>$report->{'tasks'}->{$taskkey}->{'release'}</td>\n";
                print "<TD>$report->{'tasks'}->{$taskkey}->{'resolver'}</td>\n";
                
                print "</tr>\n";
              
            }
            print "</table></td></tr>\n";
        }
        print "</table>\n";
        
    } elsif ($incltasks) {
        
        print "<h3>The following Tasks are included in the project</h3>\n";
         
        print "<table width=\"75%\">\n";
        print "<TR><TD><h4>#</h4></TD><TD><h4>Synopsis</h4></TD><TD><h4>Release</h4></TD><TD><h4>Resolver</h4></TD></TR>\n";
            
        foreach $taskkey (sort (keys (%{$report->{'tasks'}}))) {
            
            # print the task
            print "<TR>\n";
            print "<TD>$report->{'tasks'}->{$taskkey}->{'task_number'}</td>\n";
            print "<TD>$report->{'tasks'}->{$taskkey}->{'synopsis'}</td>\n";
            print "<TD>$report->{'tasks'}->{$taskkey}->{'release'}</td>\n";
            print "<TD>$report->{'tasks'}->{$taskkey}->{'resolver'}</td>\n";
            
                print "</tr>\n";
        }
        print "</table>\n";
        
    }
      
    
    # Display the new objects
    if (exists ($report->{'new'})){
        
        print "<h3>The following objects where added to the project</h3>\n";
        print "<table width=\"75%\">\n";
        print "<COLGROUP span=\"1\" width=\"60%\"><COLGROUP span=\"1\" width=\"10%\">\n";
        print "<TR><TD><h4>Path</h4></TD><TD><h4>Assoc. Task(s)</h4></TD><TD><h4>Type</h4></TD><TD><h4>Instance</h4></TD></TR>\n";
        @output=();
        foreach $key (keys(%{$report->{'new'}})) {
            
            push @output, "<tr><td>$report->{'new'}->{$key}->{'path'}</td><td>$report->{'new'}->{$key}->{'tasks'}</td><td>$report->{'new'}->{$key}->{'type'}</td><td>$report->{'new'}->{$key}->{'instance'}</td></tr>\n";
            
        }
        @sortedOutput = sort @output;
        foreach $line (@sortedOutput) {
            
            print "$line";
            
        }
        print "</table>";
        
    }
  
    # Display the updated objects
    if (exists ($report->{'updated'})){
        
        print "<h3>The following objects where updated in the project</h3>\n";
        print "<table width=\"75%\">\n";
        print "<COLGROUP span=\"1\" width=\"60%\"><COLGROUP span=\"1\" width=\"10%\">\n";
        print "<TR><TD><h4>Path</h4></TD><TD><h4>Assoc. Task(s)</h4></TD><TD><h4>Type</h4></TD><TD><h4>Instance</h4></TD></TR>\n";
        @output=();
        foreach $key (keys(%{$report->{'updated'}})) {
            
            push @output, "<tr><td>$report->{'updated'}->{$key}->{'path'}</td><td>$report->{'updated'}->{$key}->{'tasks'}</td><td>$report->{'updated'}->{$key}->{'type'}</td><td>$report->{'updated'}->{$key}->{'instance'}</td></tr>\n";
            
        }
        @sortedOutput = sort @output;
        foreach $line (@sortedOutput) {
            
            print "$line";
            
        }
        print "</table>";
        
    }
    
    # Display the moved objects
    if (exists ($report->{'moved'})){
        
        print "<h3>The following objects where moved in the project</h3>\n";
        print "<table width=\"75%\">\n";
        print "<COLGROUP span=\"1\" width=\"60%\"><COLGROUP span=\"1\" width=\"10%\">\n";
		print "<TR><TD><h4>Path</h4></TD><TD><h4>Assoc. Task(s)</h4></TD><TD><h4>Type</h4></TD><TD><h4>Instance</h4></TD></TR>\n";
        @output=();
        foreach $key (keys(%{$report->{'moved'}})) {
            
            push @output, "<tr><td>$report->{'moved'}->{$key}->{'path'}</td><td>$report->{'moved'}->{$key}->{'tasks'}</td><td>$report->{'moved'}->{$key}->{'type'}</td><td>$report->{'moved'}->{$key}->{'instance'}</td></tr>\n";
            
        }
        @sortedOutput = sort @output;
        foreach $line (@sortedOutput) {
            
            print "$line";
            
        }
        print "</table>";
        
    }
    
        # Display the deleted objects
    if (exists ($report->{'deleted'})){
        
        print "<h3>The following objects where deleted from the project</h3>\n";
        print "<table width=\"75%\">\n";
        print "<COLGROUP span=\"1\" width=\"60%\"><COLGROUP span=\"1\" width=\"10%\">\n";
        print "<TR><TD><h4>Path</h4></TD><TD><h4>Assoc. Task(s)</h4></TD><TD><h4>Type</h4></TD><TD><h4>Instance</h4></TD></TR>\n";
        @output=();
        foreach $key (keys(%{$report->{'deleted'}})) {
            
            push @output, "<tr><td>$report->{'deleted'}->{$key}->{'path'}</td><td>$report->{'deleted'}->{$key}->{'tasks'}</td><td>$report->{'deleted'}->{$key}->{'type'}</td><td>$report->{'deleted'}->{$key}->{'instance'}</td></tr>\n";
            
        }
        @sortedOutput = sort @output;
        foreach $line (@sortedOutput) {
            
            print "$line";
            
        }
        print "</table>";
        
    }
     
    print "\n\n</html>";
    
}

#-------------------------------------------------------------------------------
# print_report_ascii
#
# Load the objects in the project into the hash passed in 
#-------------------------------------------------------------------------------
sub print_report_ascii {
    
    my ($report) = @_;
    
    my (@output, @sortedOutput);
    

    # Display the IRs if required
    if ($inclcrs) {
        
        print "\n\n";
        print "The following IRs are included in the project\n\n";
        
        # For each IR
        foreach $key (sort (keys (%{$report->{'crs'}}))) {
            
            my $crout = $report->{'crs'}->{$key}->{'number'} . " - " . $report->{'crs'}->{$key}->{'synopsis'};
            $crout .= "\nRelease: " . $report->{'crs'}->{$key}->{'release'};
            $crout .= "\nStatus: " . $report->{'crs'}->{$key}->{'status'};
            $crout .= "\nDescription:\n"  . $report->{'crs'}->{$key}->{'description'} . "\n";
            
            print "$crout";
            
            # Now print the Tasks for this IR
            print "Tasks included in IR\n";
            
            foreach $taskkey (sort (keys (%{$report->{'crs'}->{$key}->{'tasks'}}))) {
                
                # print the task
                my $taskout = $report->{'tasks'}->{$taskkey}->{'task_number'} . " - " . $report->{'tasks'}->{$taskkey}->{'synopsis'};
                $taskout .= "\nRelease: " . $report->{'tasks'}->{$taskkey}->{'release'};
                $taskout .= "\nResolver: " . $report->{'tasks'}->{$taskkey}->{'resolver'} . "\n";
                
                print "$taskout\n";
            }
            
            print "\n";
        }
    } elsif ($incltasks) {
        
        print "\n\n";
        print "The following Tasks are included in the project\n\n";
        foreach $taskkey (sort (keys (%{$report->{'tasks'}}))) {
            
            # print the task
            my $taskout = $report->{'tasks'}->{$taskkey}->{'task_number'} . " - " . $report->{'tasks'}->{$taskkey}->{'synopsis'};
            $taskout .= "\nRelease: " . $report->{'tasks'}->{$taskkey}->{'release'};
            $taskout .= "\nResolver: " . $report->{'tasks'}->{$taskkey}->{'resolver'} . "\n";
            
            print "$taskout\n";
        }
    }
      
    print "\n";
    
    # Display the new objects
    if (exists ($report->{'new'})){
        print "The following objects where added to the project\n\n";
        @output=();
        foreach $key (keys(%{$report->{'new'}})) {
            
            push @output, " $report->{'new'}->{$key}->{'path'}\tAssoc. Task(s) $report->{'new'}->{$key}->{'tasks'}\n";
            
        }
        @sortedOutput = sort @output;
        foreach $line (@sortedOutput) {
            
            print "$line";
            
        }
        print "\n\n";
        
    }
  
    # Display the updated objects
    print "The following objects where updated in the project\n\n";
    @output=();
    foreach $key (keys(%{$report->{'updated'}})) {
        
        push @output, " $report->{'updated'}->{$key}->{'path'}\tAssoc. Task(s) $report->{'updated'}->{$key}->{'tasks'}\n";
        
    }
    @sortedOutput = sort @output;
    foreach $line (@sortedOutput) {
        
        print "$line";
        
    }
    print "\n\n";
    
    # Display the moved objects
    print "The following objects where updated in the project\n\n";
    @output=();
    foreach $key (keys(%{$report->{'moved'}})) {
        
        push @output, " $report->{'moved'}->{$key}->{'path'}\tAssoc. Task(s) $report->{'moved'}->{$key}->{'tasks'}\n";
        
    }
    @sortedOutput = sort @output;
    foreach $line (@sortedOutput) {
        
        print "$line";
        
    }
    print "\n\n";
    
        # Display the deleted objects
    print "The following objects where deleted from the project\n\n";
    @output=();
    foreach $key (keys(%{$report->{'deleted'}})) {
        
        push @output, " $report->{'deleted'}->{$key}->{'path'}\n";
        
    }
    @sortedOutput = sort @output;
    foreach $line (@sortedOutput) {
        
        print "$line";
        
    }
    print "\n\n";
    
}
#-------------------------------------------------------------------------------
# getProjectObjects
#
# Load the objects in the project into the hash passed in 
#-------------------------------------------------------------------------------
sub getProjectObjects {
	
    my ($project) = @_;

    # first we have to get the object names only so we can account for blanks 
    # in filenames and versions
    
    my $qrycmd = "ccm query -ns -u \"is_member_of(\'" . $project->{'objectname'} . "\')\" -f \"%objectname###%status###%owner###%task\"";
    my @objects = `$qrycmd`;
    
    # load data into our hash
    foreach $obj (@objects) {
     
        my ($name, $version, $type, $rest, $instance, $status, $owner, $displayname, $objectname, $obj_spec, $tasks);
        $obj =~ s/\s*$//;
        ($objectname, $rest) = split /###/, $obj;
        ($name, $rest) = split /$del/, $obj;
        ($version, $type, $rest) = split /:/, $rest;
        ($instance, $status, $owner, $tasks) = split /###/, $rest;
        $displayname="$name$del$version";
        $obj_spec="$name:$type:$instance";
        $project->{'objects'}->{$obj_spec} = {'objectname' => $objectname};
        $project->{'objects'}->{$obj_spec}->{'name'} = $name;
        $project->{'objects'}->{$obj_spec}->{'type'} = $type;
        $project->{'objects'}->{$obj_spec}->{'version'} = $version;
        $project->{'objects'}->{$obj_spec}->{'instance'} = $instance;
        $project->{'objects'}->{$obj_spec}->{'status'} = $status;
        $project->{'objects'}->{$obj_spec}->{'owner'} = $owner;
        $project->{'objects'}->{$obj_spec}->{'tasks'} = $tasks;
        $project->{'objects'}->{$obj_spec}->{'displayname'} = $displayname;
        
    }
    
    my $scope = "-all_proj";
    if ($project->{'status'} eq "prep") {
        $scope = "-prep_proj";
    } elsif ($project->{'status'} eq "released") {
        $scope = "-released_proj";
    } elsif ($project->{'status'} eq "working") {
        $scope = "-working_proj";
    }
    
    my @results = grep {s/(^[^\s].*)\n/$1/ || s/^\t(.*)\@$project->{'proj_spec'}\s*\n/$1/ } `ccm finduse -query \"is_member_of('$project->{'objectname'}')\" $scope `;

    foreach $key (keys (%{$project->{'objects'}})) {
        
        my ($currentObject) = $project->{'objects'}->{$key};
        
        $currentObject->{'path'} = "";
        
        # look for the object in the results
        my $searchstr = "^" . "$currentObject->{'displayname'} $currentObject->{'status'} $currentObject->{'owner'} $currentObject->{'type'}";
        $searchstr .= " .* ";
        $searchstr .= "$currentObject->{'instance'}";
        $searchstr .= " .*";
        $searchstr =~ s/([\+])/\\$1/g;
            
        for ($i=0; $i < scalar @results; $i+=2)  {
            

            
            if ($results[$i] =~ m/$searchstr/) {
         
                $currentObject->{'path'} = $results[$i+1];
            
            }
        }
    }

    return 1;
}



#-------------------------------------------------------------------------------
# Signal handler function
#
# Incoming parameters:
#   $_[0] - the caught signal
#
# Returns:
#   does not return!
#-------------------------------------------------------------------------------
sub sig_cleanup
{
        $SIG{'INT'}=$SIG{'QUIT'}=$SIG{'TRAP'}=$SIG{'KILL'}=$SIG{'TERM'}=\&sig_cleanup; 
        die "$file: Caught signal $_[0], exiting..\n";
}


#-------------------------------------------------------------------------------
# Error caught cleanup function
#
# Incoming parameters:
#   $_[0] - the caught signal
#
# Returns:
#   does not return!
#-------------------------------------------------------------------------------
sub error_cleanup
{
        print "$file: $_[0] \n";
        exit 1;
}



#-------------------------------------------------------------------------------
# Debug Print
#
# Incoming parameters:
#   $_[0] - the message to print
#
# Returns:
#   always returns 1 
#
#-------------------------------------------------------------------------------
sub dbprint
{
        if ($debug) {
                print "$file: $_[0] \n";
        }
        return 1;
}




#-------------------------------------------------------------------------------
# usage
#
# Print the usage 
#-------------------------------------------------------------------------------
sub usage {


print <<EOF;

Usage: $file -new <project spec> [-old <project spec>] [-tasks] [-objects] [-IRS]
    
    where:

       -new <project spec>        -- project spec. of the project
       [-old <project spec>]      -- project spec. of the project to compare to
       [-format [ascii|XML|HTML]] -- output format for the report  
       [-tasks|-notasks]       	  -- Include tasks in the report
       [-IRS|-noIRS]		      -- Include IRs in the report
       
Description:
    This script will generate a report listing the objects that have changed*
between two versions of a project. It will also list the IRs and tasks that are 
associated with those changes.

Example 1: Generating a report that lists the changes between the current qa project
and the current production installation and outputing the report in HTML. Checking
indicates that production contains ver. 3.7.01

$file -new GCMS2~GCMS_QA -old GCMS2~3.7.01 -format HTML

or optionally if you have a production* project whose baseline/properties properly
reflects what is in the production environment then you could use that project as
the 'old' like

$file -new GCMS2~GCMS_QA -old GCMS2~Prod -format HTML

Example 2: Generate a report that lists the changes between two released baselines
and output the report in XML. Examine the two baselines to determine what versions
of the project they contain and use those values for the 'new' and 'old'

$file -new exp~1.1a -old exp~1.0 -format XML

EOF


exit 1;
}

