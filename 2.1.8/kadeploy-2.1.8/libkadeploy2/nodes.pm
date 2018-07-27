package libkadeploy2::nodes;
## operations on sets of nodes

use libkadeploy2::conflib;
use libkadeploy2::debug;

use strict;
use warnings;

# needed here
use IPC::Open3;

use Data::Dumper;
use POSIX qw(:signal_h :errno_h :sys_wait_h);

# Try to load high precision time module
my $useTime = 1;
my $timeStart;
my $timeEnd;
unless (eval "use Time::HiRes qw(gettimeofday tv_interval);1"){
    $useTime = 0;
}

# be verbose?
my $verbose = 0;


##
# Configuration Variables
##
my $configuration;

# my $launcherWindowSize = 40; # default window_size
my $launcherWindowSize = 200; # default window_size
my $nmapCmd;
my $useNmapByDefault;
my $nmapArgs; # can add parameters to customize ping request to the site
my $kadeploy2Directory; # should be like /home/deploy/kadeploy2
my %nodes_commands;

sub register_conf {
    $configuration = shift;
   
    if ($configuration->get_conf("window_size")) {
	$launcherWindowSize = $configuration->get_conf("launcher_window_size");
    }
    $nmapCmd = $configuration->get_conf("nmap_cmd");
    $useNmapByDefault = $configuration->get_conf("enable_nmap");
    $nmapArgs = $configuration->get_conf("nmap_arguments");
    $kadeploy2Directory = $configuration->get_conf("kadeploy2_directory");

    %nodes_commands = (
	deployment => {
		remote_command => $configuration->get_conf("deploy_rcmd"),
	},
	production => {
		remote_command => $configuration->get_conf("prod_rcmd"),
	},
    );
    return 1;
}


##
# WARNING!!!
# sentinelle command must remain global variables, because you can't run commands
# on mixes of Nodes environment!!!
# should be done into separate calls!!
##

##
# Class Variables
##
my $environment; # used to check previous environment value when multiple set of nodes are created (cf new)

##
# Others Variables
##
my $errorMessageOnCheck = "Not there on Check"; # error message for nodes that are reported dead after check

## PID of sentinelle
my $userKilled = 0; # to determine wether sentinelle was killed on user demand or on alarm timeout

## Nodes constructor
sub new {
    my ($class, $env, $debug) = @_; # environment is production or deployment 
    my $self = {};

    my $errorMessage = "";
    if($debug) { $verbose=1; }

    if(!$environment) { # environment is not defined
	$environment = $env;
    } elsif ($environment ne $env) {
	libkadeploy2::debug::debugl(0, "environments should not be mixed in the same deployment!\n");
	return 0;
    }

    ## want the help of nmap ?
    $self->{useNmap} = $useNmapByDefault;
    libkadeploy2::debug::debugl(3, "nmapCmd: $nmapCmd\n"); 
    if (!defined($nmapCmd) || (! -x $nmapCmd)){
	libkadeploy2::debug::debugl(3, "WARNING: nmap won't be used there\n");
	$self->{useNmap} = 0;
    }
    $self->{nodesByIPs} = {}; # hash of 'node' instances, key is IP
    $self->{nodesByNames} = {}; # hash of 'node' instances, key is hostname
    $self->{nodesNumber} = 0;
    $self->{nodesAll} = []; # set containing all the nodes (discarded ones are included) CONSTANT SET
    $self->{nodesToPing} = []; # all nodes to be checked in an array (suspected/already failed nodes removed)
    $self->{nodesPinged} = []; # nodes after nmap
    $self->{nodesReady} = {}; # nodes ready (after check, or runCommand)
    $self->{nodesNotReached} = []; # nodes not reached by a parallel command (after check, or runCommand)
    $self->{commandSummary} = ""; # STDOUT summary of the last parallel command
    bless ($self, $class);
    return $self;
}


##  error
# allows to report dedicated errors on nodes
sub set_error {
    my $self = shift;
    $self->{errorMessage} = shift;
}

sub get_error {
    my $self = shift;
    return $self->{errorMessage};
}


#
## discards a set of nodes, it is not a destructor
## it allows to verify that nodes subsets are under the same environment
## and when a set is discarded, that you can build a new one in another environment
#
sub discard {
  my $self = shift;
  my $nodeIP;
  my $nodeName;
  my $nodesRemaining = 0;

  $environment = "";   # empties environment name
  # reset structures
  $self->{nodesToPing} = [];
  $self->{nodesPinged} = [];
  foreach $nodeIP (@{$self->{nodesAll}}) {
    if($self->{nodesByIPs}->{$nodeIP}->get_state() == 1) {
      push(@{$self->{nodesToPing}}, $nodeIP);
      push(@{$self->{nodesPinged}}, $nodeIP);
      $nodesRemaining += 1;
    } else {
      $nodeName = $self->{nodesByIPs}->{$nodeIP}->get_name();
      libkadeploy2::debug::debugl(2, "Node $nodeName discarded from deployment\n");
    }
  }
  return $nodesRemaining;
}

#
## add a node in hash, no duplicate entry allowed 
#
sub add {
    my $self = shift;
    my $node = shift;
    my $nodeIP = $node->get_IP();
    my $nodeName = $node->get_name();

    if (!$nodeIP) {
	print "[Nodes::add] node $nodeName has no IP, not added to Nodes instance\n";
	return ;
    }
    if (exists $self->{nodesByIPs}->{$nodeIP}) {
    	print "[Nodes::add] node $nodeName was already inserted, not added twice\n";
	return ;
    }
    $self->{nodesByIPs}->{$nodeIP}=$node; # perl uses references to instances, every hash refers to the same node instance
    $self->{nodesByNames}->{$nodeName}=$node;
    # should be added to the constant set containing all the nodes
    push(@{$self->{nodesAll}}, $nodeIP);
    # if we use nmap, nodesPinged is discarted anyway
    push(@{$self->{nodesToPing}}, $nodeIP);
    push(@{$self->{nodesPinged}}, $nodeIP);

    $self->{nodesNumber} += 1;
}



#
# update the nodesReady hash, and the nodesNotReached array depending on Nodes' states
#
# Use it before manipulating these structures, because different sets of nodes can update their state!
#
# return the number of ready nodes
#
sub syncNodesReadyOrNot {
    my $self = shift;
    my $nodeIP;
    my $nodesReadyNumber = 0;

    # update the nodesReady hash, and the nodesNotReached array
    $self->{nodesReady} = {};
    $self->{nodesNotReached} = [];
    foreach $nodeIP (@{$self->{nodesToPing}}) {
	if($self->{nodesByIPs}->{$nodeIP}->get_state() == 1) {
 	    $self->{nodesReady}->{$nodeIP} = $self->{nodesByIPs}->{$nodeIP};
	    $nodesReadyNumber += 1;
	} else {
	    $self->{nodesByIPs}->{$nodeIP}->set_state(-1);
	    push(@{$self->{nodesNotReached}}, $nodeIP);
	}
    }
    return $nodesReadyNumber;
}



sub ready {
    my $self = shift;
    my $nodeIP;
    foreach $nodeIP (@{$self->{nodesToPing}}) {
	if($self->{nodesByIPs}->{$nodeIP}->get_state() != 1) {
	    return 0;
	}
    }
    return 1;
}



sub getReadyNodes {
    my $self = shift;
    my $nodeName;
    my @result;
    my $nodeIP;
    foreach $nodeIP (@{$self->{nodesToPing}}) {
	if($self->{nodesByIPs}->{$nodeIP}->get_state() == 1) {
 	    $nodeName = $self->{nodesByIPs}->{$nodeIP}->get_name();
	    push(@result, $nodeName);
	}
    }
    return (@result);
}


sub getFailedNodes {
    my $self = shift;
    my $nodeName;
    my @result;
    my $nodeIP;
    foreach $nodeIP (@{$self->{nodesToPing}}) {
	if($self->{nodesByIPs}->{$nodeIP}->get_state() != 1) {
 	    $nodeName = $self->{nodesByIPs}->{$nodeIP}->get_name();
	    push(@result, $nodeName);
	}
    }
    return (@result);
}



# get_node_by_name
#
#
sub get_node_by_name {
    my $self = shift;
    my $nodeName = shift;
    libkadeploy2::debug::debugl(2, "You want this node: $nodeName \n");
    if (exists($self->{nodesByNames}->{$nodeName})) {
	return ($self->{nodesByNames}->{$nodeName});
    }
    return 0;
}


# get_node_by_IP
#
#
sub get_node_by_IP {
    my $self = shift;
    my $nodeIP = shift;
    libkadeploy2::debug::debugl(2, "You want this node: $nodeIP \n");
    if (exists($self->{nodesByIPs}->{$nodeIP})) {
	return ($self->{nodesByIPs}->{$nodeIP});
    }
    return 0;
}



# getCommandSummary
#
# return the summary of the last parallel command
sub getCommandSummary {
    my $self = shift;
    return ($self->{commandSummary});
}

# reset commandSummary (should be used after a parallel command)
sub resetCommandSummary {
    my $self = shift;
    $self->{commandSummary} = "";
}



# checkNmap
#
# fills $self->{nodesPinged} with hosts'IPs
sub checkNmap {
    my $self = shift;
    my $command = $nmapCmd . " -n -sP ";
    my $commandArgs = join(" ",@{$self->{nodesToPing}});
    my $pingedIP;
    my $line;
    $self->{nodesPinged} = []; # should be reset when using nmap or multiple node's occurrences appear
 
    if (!defined($nmapArgs)) { $nmapArgs=" "; }
 
    open(PINGSCAN, $command. " ". $nmapArgs . " " . $commandArgs." |") or die ("[checkNmap] can't reach nmap output");
    while($line=<PINGSCAN>) 
    {
	if ($line =~ /(\d+\.\d+\.\d+\.\d+)/)
	{
	    push(@{$self->{nodesPinged}}, $1);
	}
    }
    close(PINGSCAN);    
    return scalar(@{$self->{nodesPinged}});
}



# checkPortsWithNmap
#
# use nmap to check the nodes
# check port for nmap should be added to environment description
sub checkPortswithNmap {
    my $self = shift;
    my %portsToCheck; # ports that should be scanned with nmap with the desired state
    my $nmapPortsList = "";
    my %seenNodes;
    my $nodeIP;
    my $nodesReadyNumber;
    my $portsToTest = 0; # number of ports to test
    my $displayReadyNodesNumber = 0; # display the number of ready nodes?

    if ($environment eq "deployment") {
      $portsToCheck{"22"} = 1; # ssh should be opened
      $portsToCheck{"25300"} = 1; # 25000 port should also be opened (tag)
    }
    else {
      $portsToCheck{"22"} = 1; # ssh should be opened
      $portsToCheck{"25300"} = 0; # 25000 port should be closed (tag)
    }
    foreach my $port (sort (keys(%portsToCheck))) {
      $nmapPortsList = $nmapPortsList . "," . $port;
      $portsToTest++;
    }
    $nmapPortsList =~ s/^,//; # remove first coma

    if (!defined($nmapArgs)) { $nmapArgs=" "; } 
    my $nmapCommand = $nmapCmd . " -T5 -n -p " .  $nmapPortsList. " " . join(" ", @{$self->{nodesPinged}});

    my $pid = open3(\*WRITER, \*READER, \*ERROR, $nmapCommand );
    my $testedPorts; # tested ports number for node
    while(<READER>){
        chomp($_);
        if ($_ =~ m/(\d+\.\d+\.\d+\.\d+)/m) {
	  $nodeIP = $1;
	  $testedPorts = 0; # reinitialize number of scanned ports for host
        }
	if ($_ =~ /^(\d+)\/.*open/) {
	  if ($portsToCheck{$1} == 1) { # check open ports
	    $testedPorts++;
	    if ($testedPorts == $portsToTest) {
	      $seenNodes{$nodeIP} = 1;
	    }
	  }
	}
	if ($_ =~ /^(\d+)\/.*closed/) { # check the closed ports
	  if ($portsToCheck{$1} == 0) {
	    $testedPorts++;
	    if ($testedPorts == $portsToTest) {
	      $seenNodes{$nodeIP} = 1;
	    }
	  }
	}
      }
    waitpid($pid, 0);
    close(WRITER);
    close(READER);
    close(ERROR);
    # change state of seen nodes
    foreach $nodeIP (sort (keys(%seenNodes))) {
      if(exists($self->{nodesByIPs}->{$nodeIP})) {
	if($self->{nodesByIPs}->{$nodeIP}->get_state() != 1) {
	  libkadeploy2::debug::debugl(3, "there on check:  $nodeIP \n");
	  $self->{nodesByIPs}->{$nodeIP}->set_state(1);
	  $displayReadyNodesNumber = 1;
	}
      }
      else { # this should be a big trouble!!
	halt("oups, here comes an unregistered node $nodeIP\n");
      }
    }
    # change state of unseen nodes
    for $nodeIP (@{$self->{nodesToPing}}) {
	if (!exists($seenNodes{$nodeIP})) { #unseen node
	    if ($self->{nodesByIPs}->{$nodeIP}->get_state() == 1) { # node disappeared
		libkadeploy2::debug::debugl(3, "node should have rebooted: $nodeIP\n") if ($environment ne "production");
		$displayReadyNodesNumber = 1;
	    }
	    $self->{nodesByIPs}->{$nodeIP}->set_error($self->get_error());
	    $self->{nodesByIPs}->{$nodeIP}->set_state(-1);
	}
    }
    $nodesReadyNumber = keys %seenNodes;
    if ($displayReadyNodesNumber) {
	if ($environment eq "deployment") {
	    libkadeploy2::debug::debugl(3, "<BootInit ".$nodesReadyNumber.">\n");
	} elsif ($environment eq "production") {
	    libkadeploy2::debug::debugl(3, "<BootEnv ".$nodesReadyNumber.">\n");
	}
    }
    return 1;
}



#
# Check nodes that are there and then change the state of the nodes that did not respond
#
sub check {
    my $self = shift;
    my $nodeIP;
    my $nodeState;
    my $nodesNumber = scalar(@{$self->{nodesToPing}});
    my $timedout;

    # reset the nodesReady hash
    $self->{nodesReady} = {};


    if($nodesNumber == 0) { # nothing to do, so why get any further?	
	return 1;
    }

    if($self->{useNmap}) { # let's perform a first check
	# check thanks to nmap and not sentinelle
	$self->checkPortswithNmap();
	return 1;
    }

    return(1);
}


sub initCheck {
    my $self = shift;

    $self->set_error("not there on first check");
    return $self->check();
}


sub lastCheck {
    my $self = shift;
    
    $self->set_error("not there on last check");
    return $self->check();
}


###                                                   ###
# Parallel command launchers with different subtilities #
###                                                   ###

#
# runs an array of timedout commands
#
# %commandToRun: hash of already built commands to run  (host => command)
# timeout: timeout for the commands
# window_size: max number of simultaneous processes
# $errorString: error to register for the nodes on failure (not reported yet)
#
sub runThose {
    my $self = shift;
    my $ref_to_commands = shift;
    my $timeout = shift;
    my $window_size = shift;
    my $errorString = shift; # useless $self->get_error() instead
    my $report_failed = shift;

# for tests reduce window_size
# $window_size=4;

    my %commandsToRun = %{$ref_to_commands};

    my @nodes = keys(%commandsToRun);

    # local variables
    my $nbcommands = $#nodes + 1;
    my $index = 0;
    my %running_processes;
    my $nb_running_processes = 0;
    my %finished_processes;
    my %processDuration;

    # reset node command_status
    foreach my $nodeIP (keys(%commandsToRun)){
	$self->{nodesByIPs}->{$nodeIP}->set_command_status(0); # initial status before command
    }

    if ($window_size <= 0) {
        $window_size = $nbcommands;
    }

    # Treate finished processes
    # Clean declaration for a sub function in Perl
    local *register_wait_results = sub ($$){
      my $pid = shift;
      my $returnCode = shift;

      my $exit_value = $returnCode >> 8;
      my $signal_num  = $returnCode & 127;
      my $dumped_core = $returnCode & 128;
      if ($pid > 0){
         if (defined($running_processes{$pid})){
            $processDuration{$running_processes{$pid}}{"end"} = [gettimeofday()] if ($useTime == 1);
	    libkadeploy2::debug::debugl(4, "[VERBOSE] Child process $pid ended : exit_value = $exit_value, signal_num = $signal_num, dumped_core = $dumped_core \n");
            $finished_processes{$running_processes{$pid}} = [$exit_value,$signal_num,$dumped_core];
            delete($running_processes{$pid});
            $nb_running_processes--;
         }
      }
    };


    $timeStart = [gettimeofday()] if ($useTime == 1);

    # Start to launch subprocesses with the window limitation
    my @timeout;
    my $pid;
    while (($index < $nbcommands) or ($#timeout >= 0)){
      # Check if window is full or not
      while((($nb_running_processes) < $window_size) and ($index < $nbcommands)){
	libkadeploy2::debug::debugl(4, "[VERBOSE] fork process for $index command\n");
        $processDuration{$index}{"start"} = [gettimeofday()] if ($useTime == 1);

        $pid = fork();
        if (defined($pid)){
            $running_processes{$pid} = $index;
            $nb_running_processes++;
            push(@timeout, [$pid,time()+$timeout]);
            if ($pid == 0){
                #In the child
                my $cmd = $commandsToRun{$nodes[$index]};
		libkadeploy2::debug::debugl(4, "[VERBOSE] Execute command : $cmd\n");
		libkadeploy2::debug::exec_wrapper($cmd);
            }
        }else{
            warn("/!\\ fork system call failed for command $index.\n");
        }
        $index++;
      }
      while(($pid = waitpid(-1, WNOHANG)) > 0) {
        register_wait_results($pid, $?);
      }

      my $t = 0;
      while(defined($timeout[$t]) and (($timeout[$t]->[1] <= time() or (!defined($running_processes{$timeout[$t]->[0]}))))){
        if (!defined($running_processes{$timeout[$t]->[0]})){
            shift(@timeout);
        }else{
            if ($timeout[$t]->[1] <= time()){
	     	# kills all the processes whose parent pid is the positive value of the pid and the parent
		# WARNING reported to fail in some cases where pids change their grouppid
		# cf sentinelle2 if happens with rsh
		kill(9,-$timeout[$t]->[0]);
            }
        }
        $t++;
      }
      select(undef,undef,undef,0.1) if ($t == 0);
    }

    my $exit_code = 0;
    # Print summary for each nodes
    foreach my $i (keys(%finished_processes)){
      my $verdict = "BAD";
      my $report_failed_node = $report_failed;
      if (($finished_processes{$i}->[0] == 0) && ($finished_processes{$i}->[1] == 0) && ($finished_processes{$i}->[2] == 0)){
        $verdict = "GOOD";
	$self->{nodesByIPs}->{$nodes[$i]}->set_command_status(1); # report execution OK
	$report_failed_node = 0;
      }else{
        $self->{nodesByIPs}->{$nodes[$i]}->set_command_status(-1); # report execution KO
	$self->{nodesByIPs}->{$nodes[$i]}->set_error($errorString); # set error to errorString
        $exit_code = 1;
      }
      libkadeploy2::debug::debugl(4, "$nodes[$i] : $verdict ($finished_processes{$i}->[0],$finished_processes{$i}->[1],$finished_processes{$i}->[2]) ");

      if ($useTime == 1){
        my $duration = tv_interval($processDuration{$i}{"start"}, $processDuration{$i}{"end"});
	my $msg = sprintf("%.3f s",$duration);
	libkadeploy2::debug::debugl(4, $msg);
      }
      libkadeploy2::debug::debugl(4, "\n");
      if ($report_failed_node == 1) {
        $self->{nodesByIPs}->{$nodes[$i]}->set_error($self->get_error());
        $self->{nodesByIPs}->{$nodes[$i]}->set_state(-1);
	libkadeploy2::debug::debugl(3, "node " . $nodes[$i] . " marked as failed\n");
      }
     
      } 

    foreach my $i (keys(%running_processes)){
      libkadeploy2::debug::debugl(3, "$nodes[$running_processes{$i}] : BAD (-1,-1,-1) -1 s process disappeared\n");
      $exit_code = 1;
      if ($report_failed == 1) {
        $self->{nodesByIPs}->{$nodes[$running_processes{$i}]}->set_error($self->get_error());
        $self->{nodesByIPs}->{$nodes[$running_processes{$i}]}->set_state(-1);
	libkadeploy2::debug::debugl(3, "node " . $nodes[$running_processes{$i}] . " marked as failed\n");
      }
    }

    # Print global duration
    if ($useTime == 1){
      $timeEnd = [gettimeofday()];
      my $msg = sprintf("Total duration : %.3f s (%d nodes)\n", tv_interval($timeStart, $timeEnd), $nbcommands);
      libkadeploy2::debug::debugl(4, $msg);
    }

    # sync nodes structures
    if ($report_failed == 1) {
      $self->syncNodesReadyOrNot();
    }

    return ($exit_code);
}



sub getThoseCommandSummary {
    my $self = shift;
    my $status;
    my $test = 0;
    my $result = 1;
   
    libkadeploy2::debug::debugl(3, "\nCommand execution summary:\n");
    foreach my $nodeIP (sort @{$self->{nodesToPing}}) {
	$test=1; # at least one node
        if ( $self->{nodesByIPs}{$nodeIP}->get_command_status() == 1 ) {
            $status = "OK";
	} else {
	    $status = "ERROR";
	    $result=0;
	}
	libkadeploy2::debug::debugl(3, "\t" . $self->{nodesByIPs}{$nodeIP}->get_name() . "\t" . $status . "\n");
    }
    libkadeploy2::debug::debugl(3, "Finished\n\n");
    
    return ($test && $result);
}


	
sub runCommandMcat {
    my $self = shift;
    my $server_command = shift;
    my $node_pipe = shift;
    my $nodes="";
    my $kadeploy2_directory=$configuration->get_conf("kadeploy2_directory");
    my $internal_parallel_command = $configuration->get_conf("use_internal_parallel_command");
    if (!$internal_parallel_command) { $internal_parallel_command = "no"; }
    my $pid;
    my $timeout=400;
    my $firstnode="";
    my $timetosleep=1.0;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();
    my $connector = $nodes_commands{$environment}{remote_command};
    
    my @nodesIP;
    my %num;
    # build sorted nodesfile
    foreach my $key (sort keys %{$self->{nodesReady}}) {
	push (@nodesIP, $key);
    }
    for (@nodesIP) {
	$num{$_} = sprintf("%d%03d%03d%03d", split(/\./));
    }
    my @sortedIP = sort { $num{$a} <=> $num{$b}; } @nodesIP;
    #for (@sortedIP) { print $_ . "\n";}

    # create echo command
    my $echo_string="";
    foreach my $nodeIP (@sortedIP) {
	$echo_string .= $nodeIP . " ";
    }
    
    # distribute nodesfile across the nodes
    # distributing files with cat should be avoided because of TIME_WAIT
    $self->runRemoteCommand (" /usr/local/bin/filenode.sh /nodes.txt " . $echo_string);
    # build chain
    $self->runRemoteCommand ("/usr/local/bin/launch_transfert.sh " . $node_pipe);
    # launch local command and pass data to the first node
    my $command = $server_command . " | " . $connector . " " . $sortedIP[0] . " \" cat > /entry_pipe \" ";
    libkadeploy2::debug::debugl(4, "mcat local: $command\n");
    libkadeploy2::debug::system_wrapper($command);
    libkadeploy2::debug::debugl(4, "mcat done\n");
    $self->runRemoteCommandBackground ("sync", "transfert");
}





#
# runs the remote command only!
#
sub runRemoteCommand($$)
{
    my $self = shift;
    my $remoteCommand = shift;

    return $self->runLocalRemote ("", $remoteCommand, 0);		    
}


#
# runs the remote command only and report failed nodes
#
sub runRemoteCommandReportFailed($$$)
{
    my $self = shift;
    my $remoteCommand = shift;
    my $errorString = shift;
    $self->set_error($errorString);

    return $self->runLocalRemote ("", $remoteCommand, 1);
}



#
# runs the remote command in background
# 
sub runRemoteCommandBackground($$$) {
    my $self = shift;
    my $remoteCommand = shift;
    my $lock = shift;
    
    my $CommandToLaunch = "\" /usr/local/bin/launch_background.sh /var/lock/" . $lock . " " . $remoteCommand . " \"";
    $self->runLocalRemote ("", $CommandToLaunch, 0);

    $CommandToLaunch = "\" /usr/local/bin/wait_background.sh /var/lock/" . $lock . " \"";
    # don't report failed nodes on background commands
    return $self->runLocalRemote ("", $CommandToLaunch, 0);
}



# 
# runs the remote command in background and report failed nodes (usefull for preinstall)
# 
sub runRemoteCommandBackgroundReportFailed($$$$) {
    my $self = shift;
    my $remoteCommand = shift;
    my $lock = shift;
    my $errorString = shift;
    $self->set_error($errorString);

    my $CommandToLaunch = "\" /usr/local/bin/launch_background.sh /var/lock/" . $lock . " " . $remoteCommand . " \"";
    $self->runLocalRemote ("", $CommandToLaunch, 1);

    $CommandToLaunch = "\" /usr/local/bin/wait_background.sh /var/lock/" . $lock . " \"";
    # don't report failed nodes on background commands
    return $self->runLocalRemote ("", $CommandToLaunch, 1);
}




#
# runs a bunch of commands
#
sub runLocalRemote($$$$) {
    my $self = shift;
    my $localCommand = shift;
    my $remoteCommand = shift;
    my $report_failed = shift;
    my $connector = $nodes_commands{$environment}{remote_command};
    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    libkadeploy2::debug::debugl(4, "LocalRemote called with " . $localCommand . " " . $connector . " nodeIP " . $remoteCommand . "\n");

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) {
            $executedCommands{$nodeIP} = $localCommand . $connector . " " . $nodeIP . " " . $remoteCommand;
    }
    # return $self->runThose(\%executedCommands, 50, $launcherWindowSize, "failed on node", $report_failed);
    return $self->runThose(\%executedCommands, 250, $launcherWindowSize, "failed on node", $report_failed);

}


sub runDetachedCommand {
    my $self = shift;
    my $command = shift;
    my $connector = $nodes_commands{$environment}{remote_command};
    my $remoteCommand = "\"$command\" 2>/dev/null &";
    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) {
        $executedCommands{$nodeIP} = $connector . " " . $nodeIP . " " . $remoteCommand;
    }

    # return $self->runThose(\%executedCommands, 2, $launcherWindowSize, "Detached command failed on node", 0);
    return $self->runThose(\%executedCommands, 15, $launcherWindowSize, "Detached command failed on node", 0);
}


sub runDetachedKexec {
    my $self = shift;
    my $useprodenvtodeploy = shift;
    my $kernelPath = shift;
    my $initrdPath = shift;
    my $destPart = shift;
    my $kernelParam = shift;
    my $connector = $nodes_commands{$environment}{remote_command};
    my $remoteCommand = "\"/usr/local/bin/kexec_detach $kernelPath $initrdPath $destPart $kernelParam\" &";
    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) {
        $executedCommands{$nodeIP} = $connector . " " . $nodeIP . " " . $remoteCommand;
    }
    # return $self->runThose(\%executedCommands, 2, $launcherWindowSize, "Kexec failed on node", 0);
    return $self->runThose(\%executedCommands, 15, $launcherWindowSize, "Kexec failed on node", 0);
}


sub runSimpleReboot {
    my $self = shift;
    my $connector = $nodes_commands{$environment}{remote_command};
    my $remoteCommand = "\"/sbin/reboot\"&";

    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) {
        $executedCommands{$nodeIP} = $connector . " " . $nodeIP . " " . $remoteCommand; 
    }

    # return $self->runThose(\%executedCommands, 2, $launcherWindowSize, "reboot failed on node", 0);
    return $self->runThose(\%executedCommands, 15, $launcherWindowSize, "reboot failed on node", 0);
}


sub rebootThoseNodes 
{
    my $self = shift;
    my $connector = $nodes_commands{$environment}{remote_command};
    my $remoteCommand = "/usr/local/bin/reboot_detach";

    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) {
        $executedCommands{$nodeIP} = $connector . " " . $nodeIP . " " . $remoteCommand; 
    }

    # return $self->runThose(\%executedCommands, 2, $launcherWindowSize, "reboot failed on node", 0);
    return $self->runThose(\%executedCommands, 15, $launcherWindowSize, "reboot failed on node", 0);
}



sub rebootMyNodes {
    my $self = shift;
    my $method = shift; # method can be "deployboot" "softboot" "hardboot" "deployreboot" "failednodes"
    my $connector = $nodes_commands{$environment}{remote_command};

    my $use_next_method = 1;
    my $next_method = "hardboot"; # can be "deployreboot" if a reboot from deploy environment should be tryied before the hard one

    my $get_failed_nodes = 0; # should only reboot failed nodes

    my %executedCommands;
    my %nextExecutedCommands;
    my %tmpExecutedCommands;
   
    my $nbsoftboot_nodes = 0; # number of nodes rebooted softly
    my $nbdeployreboot_nodes = 0; # number of nodes deployrebooted
    my $nbhardboot_nodes = 0; # number of nodes hardrebooted
    my $nbmethod_nodes;

    my $result;

    # get commands for all the nodes
    my %cmd = $configuration->check_cmd();

    my $hostname;

    if ($method eq "failednodes") {
        $get_failed_nodes = 1;
	$method = "hardboot"; # reboot failed node the hard way
    }
    if ($method ne "deployreboot") { # no need for a connector, nodes to reboot: @nodesToPing
        foreach my $nodeIP (@{$self->{nodesToPing}}) {
            $hostname = $self->{nodesByIPs}{$nodeIP}->get_name();
            if (!$cmd{$hostname}{$method}){
		libkadeploy2::debug::debugl(3, "WARNING : no $method command found for $hostname !\n");
            } else {
	        if (!$get_failed_nodes) {
		    $executedCommands{$nodeIP} = $cmd{$hostname}{$method};
		} else {
		    if ($self->{nodesByIPs}{$nodeIP}->get_state() == -1) {
			libkadeploy2::debug::debugl(3, "Rebooting node $hostname hard\n");
                        $executedCommands{$nodeIP} = $cmd{$hostname}{$method};
		    }
		}
            }
        }
        # $self->runThose(\%executedCommands, 6, $launcherWindowSize, "$method failed on node", 0);
        $self->runThose(\%executedCommands, 50, $launcherWindowSize, "$method failed on node", 0);
    } else {
        # deployreboot
        return $self->rebootThoseNodes();
    }

    while ($use_next_method) {
        # verify if all commands ended successfully
	$nbmethod_nodes = 0;
	%nextExecutedCommands = (); # empty next commands to be run
        foreach my $nodeIP (keys(%executedCommands)) {
	    if ( $self->{nodesByIPs}{$nodeIP}->get_command_status() != 1 ) {
		libkadeploy2::debug::debugl(4, "$executedCommands{$nodeIP} went wrong \n ");
	        $hostname = $self->{nodesByIPs}{$nodeIP}->get_name();
		libkadeploy2::debug::debugl(3, "Problem occured rebooting node :" . $hostname . " trying " . $next_method . " \n");
		if ($next_method eq "hardboot") {
		    $use_next_method = 0;
	            if(!$cmd{$hostname}{"hardboot"}){
			libkadeploy2::debug::debugl(3,"WARNING : no hardboot command found for $hostname !\n");
	            } else {
		        $nbmethod_nodes++;
			libkadeploy2::debug::debugl(4, "rebooting node $hostname hard \n");
	                $nextExecutedCommands{$nodeIP} = $cmd{$hostname}{"hardboot"};
	            }
		} else {
		    if ($method eq "softboot") {
		        $nbsoftboot_nodes++;
		    }
		}
	        if ($next_method eq "deployreboot") {
		    $nbmethod_nodes++;
		    $nextExecutedCommands{$nodeIP} = $connector . " " . $nodeIP . " /usr/local/bin/reboot_detach";
		} 
	    }
        }
	%executedCommands = %nextExecutedCommands;
        if ( $nbmethod_nodes != 0 ) {
	    libkadeploy2::debug::debugl(4, "Launching parrallel commands \n");
	    # $self->runThose(\%nextExecutedCommands, 6, $launcherWindowSize, "hardboot failed on node", 0);
	    $self->runThose(\%nextExecutedCommands, 50, $launcherWindowSize, "hardboot failed on node", 0);
	} else {
            $use_next_method = 0;
	}
	if ($next_method eq "deployreboot") {
	    $method = "deployreboot";
	    $next_method = "hardboot";
	    $nbdeployreboot_nodes = $nbmethod_nodes;
	} elsif ($next_method eq "hardreboot") {
	    $method = "hardreboot";
            $nbhardboot_nodes = $nbmethod_nodes;
	    $use_next_method = 0;
	}
    }

    if ( (($nbsoftboot_nodes == 0) or ($nbdeployreboot_nodes > 0)) and ($method eq "softboot" )) {
        # if a single node is rebooted from softboot it is enough to ensure good detection
        return 0;
    }
    return 1;
}




1;
