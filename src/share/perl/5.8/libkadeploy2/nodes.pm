package libkadeploy2::Nodes;
## operations on sets of nodes

use strict;
use warnings;

# needed here
use IPC::Open3;

use Data::Dumper;
use POSIX qw(:signal_h :errno_h :sys_wait_h);

##
# Configuration Variables
##

my $nmapCmd = libkadeploy2::conflib::get_conf("nmap_cmd");
my $useNmapByDefault = libkadeploy2::conflib::get_conf("enable_nmap");
my $nmapArgs = libkadeploy2::conflib::get_conf("nmap_arguments"); # can add parameters to customize ping request to the site
my $kadeploy2Directory = libkadeploy2::conflib::get_conf("kadeploy2_directory"); # should be like /home/deploy/kadeploy2

# perl is shit....#

my %parallel_launcher = (
    deployment => {
	sentinelleCmd => libkadeploy2::conflib::get_conf("deploy_sentinelle_cmd"),
	sentinelleDefaultArgs => libkadeploy2::conflib::get_conf("deploy_sentinelle_default_args"),
	sentinellePipelineArgs => libkadeploy2::conflib::get_conf("deploy_sentinelle_pipelined_args"),
	sentinelleEndings => libkadeploy2::conflib::get_conf("deploy_sentinelle_endings"),
	sentinelleTimeout => libkadeploy2::conflib::get_conf("deploy_sentinelle_timeout"),
    },
    production => { # only used for testing purposes for the moment...
	sentinelleCmd => libkadeploy2::conflib::get_conf("prod_sentinelle_cmd"),
	sentinelleDefaultArgs => libkadeploy2::conflib::get_conf("prod_sentinelle_default_args"),
	sentinellePipelineArgs => libkadeploy2::conflib::get_conf("prod_sentinelle_pipelined_args"),
	sentinelleEndings => libkadeploy2::conflib::get_conf("prod_sentinelle_endings"),
     	sentinelleTimeout => libkadeploy2::conflib::get_conf("prod_sentinelle_timeout"),
    },
);

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
my $sentinelleCmd;
my $sentinelleDefaultArgs; # le timeout reporte les noeuds comme morts, si ,timeout=...
my $sentinellePipelineArgs; # sentinelle arguments for efficient data transmission
my $sentinelleEndings; # command at the end, should return host IP only on the target nodes!
my $sentinelleTimeout; # important because buggy sentinelle (return segfault...) should be timedout... after an answer! Another point is when you can ping a node and the rshd daemon is not yet launched.

##
# Others Variables
##
my $errorMessageOnCheck = "Not there on Check"; # error message for nodes that are reported dead after check

## PID of sentinelle
my $sentinellePID = 0; # pid of the current sentinelle process
my $userKilled = 0; # to determine wether sentinelle was killed on user demand or on alarm timeout

## Nodes constructor
sub new {
    my ($class, $env) = @_; # environment is production or deployment 
    my $self = {};

    if(!defined($parallel_launcher{$env})) {
	print "environment is not defined on Nodes creation, please refers configuration!\n";
	return 0;
    }
    if(!$environment) { # environment is not defined
	$environment = $env;
    } elsif ($environment ne $env) {
	print "environments should not be mixed in the same deployment!\n";
	return 0;
    }

    # initialize commands for the selected environment
    $sentinelleCmd = $parallel_launcher{$env}{sentinelleCmd};
    $sentinelleDefaultArgs = $parallel_launcher{$env}{sentinelleDefaultArgs};
    $sentinellePipelineArgs = $parallel_launcher{$env}{sentinellePipelineArgs};
    $sentinelleEndings = $parallel_launcher{$env}{sentinelleEndings};
    $sentinelleTimeout = $parallel_launcher{$env}{sentinelleTimeout};

    ###
    # TODO: checks should go into configuration checks!!
    ###
    ## sentinelle MUST be there
    #if (!defined($sentinelleCmd)){
 	#print "sentinelle not defined or not installed on your system\n";
	#return -1;
    #}
    ## want the help of nmap ?
    $self->{useNmap} = $useNmapByDefault;
    print "nmapCmd: $nmapCmd\n"; 
    if (!defined($nmapCmd) || (! -x $nmapCmd)){
	print "WARNING: nmap won't be used there\n";
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

## kills the current sentinelle process
sub kill_sentinelle {
    if ($sentinellePID != 0) {
	print "kill sentinelle!!\n";
	$userKilled = 1;
	if (kill 0 => $sentinellePID) {
	    print "I can kill sentinelle\n";
	    kill 9,  $sentinellePID;
	}
    }
    return;
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
      print "Node $nodeName discarded from deployment\n";
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
    print "You want this node: $nodeName \n";
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
    print "You want this node: $nodeIP \n";
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


#
# Allows to report error on events that occurs to nodes
#
sub setNodesErrorMessage {
    my $self = shift;
    my $errorMessage = shift; # error message to report after a set_state

    foreach my $nodeIP (@{$self->{nodesToPing}}) {
	$self->{nodesByIPs}{$nodeIP}->set_error($errorMessage);
    }    
}


# checkNmap
#
# fills $self->{nodesPinged} with hosts'IPs
sub checkNmap {
    my $self = shift;
    my $command = $nmapCmd . " -sP ";
    my $commandArgs = join(" ",@{$self->{nodesToPing}});
    my $pingedIP;
    my $line;
    $self->{nodesPinged} = []; # should be reset when using nmap or multiple node's occurrences appear
 
    open(PINGSCAN, $command.$commandArgs." |") or die ("[checkNmap] can't reach nmap output");
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

    $self->setNodesErrorMessage("Not there on last check!");
    if ($environment eq "deployment") {
      $portsToCheck{"22"} = 0; # ssh should be closed
      $portsToCheck{"514"} = 1; # login port should be opened
    }
    else {
      $portsToCheck{"22"} = 1; # ssh should be opened
    }
    foreach my $port (sort (keys(%portsToCheck))) {
      $nmapPortsList = $nmapPortsList . "," . $port;
      $portsToTest++;
    }
    $nmapPortsList =~ s/^,//; # remove first coma

    if (!defined($nmapArgs)) { $nmapArgs=" "; } 
    my $nmapCommand = $nmapCmd . " -n -p " .  $nmapPortsList. " " . $nmapArgs. " " . join(" ", @{$self->{nodesPinged}});

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
	  print "there on check:  $nodeIP \n";
	  $self->{nodesByIPs}->{$nodeIP}->set_state(1);
	  $displayReadyNodesNumber = 1;
	}
      }
      else { # this should be a big trouble!!
	print "oups, here comes an unregistered node $nodeIP\n";
      }
    }
    # change state of unseen nodes
    for $nodeIP (@{$self->{nodesToPing}}) {
	if (!exists($seenNodes{$nodeIP})) { #unseen node
	    $self->{nodesByIPs}->{$nodeIP}->set_state(-1);
	}
    }
    $nodesReadyNumber = keys %seenNodes;
    if ($displayReadyNodesNumber) {
	if ($environment eq "deployment") {
	    print "<BootInit ".$nodesReadyNumber.">\n";
	} elsif ($environment eq "production") {
	    print "<BootEnv ".$nodesReadyNumber.">\n";
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
    my $checkCommand = $sentinelleCmd;
    my $timedout;

    # set error message before check
    $self->setNodesErrorMessage("Not there on check!");
    # reset the nodesReady hash
    $self->{nodesReady} = {};


    if($nodesNumber == 0) { # nothing to do, so why get any further?	
	return 1;
    }

    if($self->{useNmap}) { # let's perform a first check
	$nodesNumber = $self->checkNmap();
	if($nodesNumber == 0) { # nothing to do after nmap, so why get any further?
	    # set the state of the disappeared nodes
	    foreach $nodeIP (@{$self->{nodesToPing}}) {
		$self->{nodesByIPs}{$nodeIP}->set_state(-1);
	    }
	    # Let's sync the structures 
	    $self->syncNodesReadyOrNot();
	    return 1;
	} else { # check thanks to nmap and not sentinelle
	    $self->checkPortswithNmap();
	    return 1;
	}
    }

    $checkCommand .= " " . $sentinelleDefaultArgs . " -m".join(" -m",@{$self->{nodesPinged}});
    if (defined($sentinelleEndings)) {
	$checkCommand .= " -- ".$sentinelleEndings;
    }
    #print $checkCommand . "\n";
    eval {
	$timedout = 0;
        $SIG{ALRM} = sub { $timedout = 1; die("alarm\n") };
        alarm($sentinelleTimeout);

        my $pid = open3(\*WRITER, \*READER, \*ERROR, $checkCommand );
	$sentinellePID = $pid; ## allows to kill sentinelle externally
        while(<READER>){
	    chomp($_);
            if ($_ =~ m/^\s*(\d+\.\d+\.\d+\.\d+)\s*$/m) {
		$nodeIP = $1;
		print "there on check:  $nodeIP \n";
		if(exists($self->{nodesByIPs}->{$nodeIP})) {
		    $self->{nodesByIPs}->{$nodeIP}->set_state(1);
		    $self->{nodesReady}->{$nodeIP} = $self->{nodesByIPs}->{$nodeIP};
		} else { # this should be a big trouble!!
		    print "oups, here comes an unregistered node $nodeIP\n";
		}
	    }
	}
	waitpid($pid, 0);
	close(WRITER);
	close(READER);
        close(ERROR);
        alarm(0);
    };
    if ($@){
	if ($timedout == 0) {
	    print "killed by user...exiting\n";
	    exit 0;   
	}
        print("[Check] sentinelle command times out : all nodes are rebooting now\n");
	# We discard the results...
	$self->{nodesReady} = {}; 
    }

    # set the state of the disappeared nodes
    foreach $nodeIP (@{$self->{nodesToPing}}) {
	if (!exists($self->{nodesReady}->{$nodeIP})) {
	    $self->{nodesByIPs}{$nodeIP}->set_state(-1);
	}
    }

    # Let's sync the structures 
    $self->syncNodesReadyOrNot();
    return(1);
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
# $errorString: error to register for the nodes on failure
#
sub runThoseExtern {
    my $self = shift;
    my $ref_to_commands = shift;
    my $timeout = shift;
    my $window_size = shift;
    my $errorString = shift;
    my $verbose=1;


    my %commandsToRun = %{$ref_to_commands};

    my @nodes=keys(%commandsToRun);

    my $index = 0;
    my %running_processes;
    my %finished_processes;


    if (!$window_size) {
	$window_size = scalar(@nodes)+1;
    }

    while (scalar(keys(%finished_processes)) <= $#nodes){
      while((scalar(keys(%running_processes)) < $window_size) && ($index <= $#nodes)){
        print("[VERBOSE] fork process for the node $nodes[$index]\n") if ($verbose);
        my $pid = fork();
        if (defined($pid)){
	  if ($pid == 0){
	    #In the child
	    # Initiate timeout
	    alarm($timeout);
	    my $cmd = $commandsToRun{$nodes[$index]};
	    print("[VERBOSE] Execute command : $cmd\n") if ($verbose);
	    exec($cmd);
	  }
	  $running_processes{$pid} = $index;
	  print ("[VERBOSE] job $pid forked\n") if ($verbose);
        }else{
	  warn("/!\\ fork system call failed for node $nodes[$index].\n");
        }
        $index++;
      }
      my $waited_pid = wait();
      my $exit_value = $? >> 8;
      my $signal_num  = $? & 127;
      my $dumped_core = $? & 128;

      if ($waited_pid == -1){
        die("/!\\ wait return -1 so there is no child process. It is a mistake\n");
      }else{
        if (defined($running_processes{$waited_pid})){
	  print("[VERBOSE] Child process $waited_pid ended : exit_value = $exit_value, signal_num = $signal_num, dumped_core = $dumped_core \n") if ($verbose);
	  $finished_processes{$running_processes{$waited_pid}} = [$exit_value,$signal_num,$dumped_core];
	  delete($running_processes{$waited_pid});
        }
      }
    }

    foreach my $i (keys(%finished_processes)){
      my $verdict = "BAD";
      if (($finished_processes{$i}->[0] == 0) && ($finished_processes{$i}->[1] == 0) && ($finished_processes{$i}->[2] == 0)){
        $verdict = "GOOD";
      }
      print("$nodes[$i] : $verdict ($finished_processes{$i}->[0],$finished_processes{$i}->[1],$finished_processes{$i}->[2])\n");
    }

    return 1;
}

sub runThose {
    my $self = shift;
    my $ref_to_commands = shift;
    my $timeout = shift;
    my $window_size = shift;
    my $errorString = shift;
    my $verbose=1;


    my %commandsToRun = %{$ref_to_commands};

    my @nodes=keys(%commandsToRun);

    my $index = 0;
    my %running_processes;
    my %finished_processes;


    if (!$window_size) {
        $window_size = scalar(@nodes)+1;
    }

    while (scalar(keys(%finished_processes)) <= $#nodes){
      while((scalar(keys(%running_processes)) < $window_size) && ($index <= $#nodes)){
        print("[VERBOSE] fork process for the node $nodes[$index]\n") if ($verbose);
        my $pid = fork();
        if (defined($pid)){
          if ($pid == 0){
            #In the child
            # Initiate timeout
            alarm($timeout);
            my $cmd = $commandsToRun{$nodes[$index]};
            print("[VERBOSE] Execute command : $cmd\n") if ($verbose);
            exec($cmd);
          }
          $running_processes{$pid} = $index;
          print ("[VERBOSE] job $pid forked\n") if ($verbose);
        }else{
          warn("/!\\ fork system call failed for node $nodes[$index].\n");
        }
        $index++;
      }
      my $waited_pid = wait();
      my $exit_value = $? >> 8;
      my $signal_num  = $? & 127;
      my $dumped_core = $? & 128;

      if ($waited_pid == -1){
        die("/!\\ wait return -1 so there is no child process. It is a mistake\n");
      }else{
        if (defined($running_processes{$waited_pid})){
          print("[VERBOSE] Child process $waited_pid ended : exit_value = $exit_value, signal_num = $signal_num, dumped_core = $dumped_core \n") if ($verbose);
          $finished_processes{$running_processes{$waited_pid}} = [$exit_value,$signal_num,$dumped_core];
          delete($running_processes{$waited_pid});
        }
      }
    }

    foreach my $i (keys(%finished_processes)){
      my $verdict = "BAD";
      if (($finished_processes{$i}->[0] == 0) && ($finished_processes{$i}->[1] == 0) && ($finished_processes{$i}->[2] == 0)){
        $verdict = "GOOD";
      }
      print("$nodes[$i] : $verdict ($finished_processes{$i}->[0],$finished_processes{$i}->[1],$finished_processes{$i}->[2])\n");
    }

    return 1;
}




#
# runs a command on a set of nodes, only the on the ones which are Ready.
# Initial state must be set through the check method on the set that contains all the nodes.
#
# Nodes that do not respond are reported in the nodesNotReached array
#
# returns values: 0 if a single node disappears
#
sub runIt {
    my $self = shift;
    my $executedCommand = shift; # parallel command launcher
    my $commandLocal = shift; # command run locally expl: tar -zxf image.tgz |
    my $commandRemote = shift; # command to execute on a set of nodes
    my $nodeIP;
    my $nodeState;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();
    my $return_value = 1;

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
	return 1;
    }
    
    foreach my $key (sort keys %{$self->{nodesReady}}) {
	$executedCommand .= " -m$key";
    }
     if ($executedCommand =~ "sentinelle.pl"  ){
     $executedCommand .= " -p " .  "\"" . "\\\"" . $commandRemote . "\&\\\"\&"  . "\"";
     print $executedCommand .  "\n";
     system($executedCommand);
     }
     else{
    $executedCommand .= " -- " . $commandRemote;#}



    print $executedCommand .  "\n";
    
    my $pid = open3(\*WRITER, \*READER, \*READER, $executedCommand );
    $sentinellePID=$pid;
    while(<READER>){
	chomp($_);
	if ($_ =~ m/^\s*(\d+\.\d+\.\d+\.\d+)\s*$/m) {
	    $nodeIP = $1;
	    if(exists($self->{nodesByIPs}->{$nodeIP})) {
		$nodeState = $self->{nodesByIPs}->{$nodeIP}->get_state();
		$self->{nodesByIPs}->{$nodeIP}->set_state(-1);
		if($nodeState == 1) { # node disappeared => update the structures
		    $return_value = 0;
		}
	    } else { # this should be a big trouble!!
		print "oups, node $nodeIP was not here while said to be ready!\n";
	    }
	}
	else  { # distinguished thanks to -v option in sentinelle
	    # collect STDOUT to $self->{commandSummary}
	    $self->{commandSummary} .= "$_\n";
	}
    }
    waitpid($pid, 0);
    close(WRITER);
    close(READER);}

    # Let's sync the Nodes' state
    $self->syncNodesReadyOrNot();

    return $return_value;
}


#
# runs local and then parallel commands
# for non optimal, but safe pipelines
#
sub runCommand {
    my $self = shift;
    my $commandLocal = shift; # command run locally expl: tar -zxf image.tgz |
    my $commandRemote = shift; # command to execute on a set of nodes
    my $parallelLauncher = $commandLocal . " " . $sentinelleCmd . " " . $sentinelleDefaultArgs . " -v ";

    return ($self->runIt($parallelLauncher, $commandLocal, $commandRemote));
}

#
# runs local command and use mput for copy
#
#sub runCommandMput {
#    my $self = shift;
#    my $remoteNamedPipe = "-p " . shift; # remote named pipe targetted with mput -p option
#    my $parallelLauncher = "/usr/local/bin/mput" . " " . $sentinelleDefaultArgs . " -v ";
#
#    return ($self->runIt($parallelLauncher, "", $remoteNamedPipe));
#}

# #
# added for optimisation methods support
# runs command with sentinelle.pl
#

sub runCommandSimplessh {
    my $self = shift;
    my $commandRemote = shift;
#    my $parallelLauncher = "/home/deploy/kadeploy2/tools/sentinelle/sentinelle.pl " . " -c ssh -l root -t 2 -w 50 ";
    
    my $parallelLauncher = libkadeploy2::conflib::get_conf("perl_sentinelle_cmd");
    my $launcherOpts = libkadeploy2::conflib::get_conf("perl_sentinelle_default_args");
    
    return ($self->runIt($parallelLauncher." ".$launcherOpts, "", $commandRemote));
}
	
sub runCommandMcat {
    my $self = shift;
    my $server_command = shift;
    my $nodes_command = shift;
    my $mcatPort = shift; # port to use for data transfert
    my $nodes="";
    my $kadeploy2_directory=libkadeploy2::conflib::get_conf("kadeploy2_directory");
    my $remote_mcat=libkadeploy2::conflib::get_conf("remote_mcat");
    my $internal_parallel_command = libkadeploy2::conflib::get_conf("use_internal_parallel_command");
    if (!$internal_parallel_command) { $internal_parallel_command = "no"; }
    my $pid;
    my $timeout=400;
    my $firstnode="";
    my $timetosleep=1.0;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if ($internal_parallel_command eq "yes")
    {

	foreach my $key (sort keys %{$self->{nodesReady}}) 
	{
	    if ( $firstnode eq "") { $firstnode=$key; }
	    $nodes .= " $key";
	    $timetosleep+=0.08;
	}
	
	$pid=fork();
	if ($pid==0)
	{
	    $self->runRemoteCommandTimeout("\" $remote_mcat 1 $mcatPort '".$server_command."' '".$nodes_command."' ".$nodes."  \" ",$timeout);
	    exit 0;
	}
	else
	{
	    my $command="$kadeploy2_directory/bin/mcatseg 4 $mcatPort '".$server_command."'  '".$nodes_command."' ".$firstnode;
	    sleep($timetosleep);
	    print "mcat local: $command\n";
	    system($command);
	    print "mcat local done\n";
	    waitpid($pid,0);
	}
    }
    else #use external mcat
    {
	$self->runCommandMcatExtern($server_command,$nodes_command,$mcatPort);
    }
}





sub runCommandMcatExtern 
{
    my $self = shift;
    my $server_command = shift;
    my $nodes_command = shift;
    my $mcatPort = shift; # port to use for data transfert
    my $test=0;
    my $kadeploydir = libkadeploy2::conflib::get_conf("kadeploy2_directory");
    my $parallelLauncher = $kadeploydir."/bin/";# . "mcat_rsh.pl";

    my $remoteCommand = libkadeploy2::conflib::get_conf("remote_mcat");
    

    if($nodes_command =~ m/tmp/)
    {
	$parallelLauncher = $parallelLauncher. "mcat_ssh.pl";
    }
    else
    {
	$parallelLauncher = $parallelLauncher.  "mcat_rsh.pl";
    }
 
    my $executedCommand = $parallelLauncher . " -p $mcatPort -sc \"" . $server_command . "\" -dc \"" . $nodes_command . "\"";
    
    print "Command Mcat: $executedCommand";
    
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();
    my $return_value = 1;

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $key (sort keys %{$self->{nodesReady}}) {
        $executedCommand .= " -m $key";
    }
    my $pid = open3(\*WRITER, \*READER, \*READER, $executedCommand );
    $sentinellePID=$pid;
    while(<READER>){
        chomp($_);
	$_=~/LAST_NODE_ENDED/ and $test=1;
    }
    waitpid($pid, 0);
    close(WRITER);
    close(READER);
    if($test) {
        print "tranfert OK\n";
    }
    return $test;
}



#
# runs the remote command only!
#
sub runRemoteCommand($$)
{
    my $self = shift;
    my $remoteCommand = shift;
    my $connector = "rsh -l root";
    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) 
    {
    	$executedCommands{$nodeIP} = $connector . " " . $nodeIP . " " . $remoteCommand; 
    }
    return $self->runThose(\%executedCommands, 20, 50, "failed on node");		    
}

sub runRemoteCommandTimeout($$$)
{
    my $self = shift;
    my $remoteCommand = shift;
    my $timeout = shift;
    my $connector = "rsh -l root";
    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) {
	$executedCommands{$nodeIP} = $connector . " " . $nodeIP . " " . $remoteCommand; 
    }
    return $self->runThose(\%executedCommands, $timeout, 50, "failed on node");		    
}





#
# runs the remote command only!
#
sub runRemoteCommandExtern {
    my $self = shift;
    my $command = shift;
    return ($self->runCommand("", $command));
}


#
# evident names...
#
sub runReportedCommand{
    my $self = shift;
    my $commandLocal = shift; # command run locally expl: tar -zxf image.tgz |
    my $commandRemote = shift; # command to execute on a set of nodes
    my $errorMessage = shift; # error message to report

    $self->setNodesErrorMessage($errorMessage);
    return ($self->runCommand($commandLocal, $commandRemote));
}


sub runReportedRemoteCommand {
    my $self = shift;
    my $command = shift;
    my $errorMessage = shift; # error message to report

    $self->setNodesErrorMessage($errorMessage);
    return ($self->runRemoteCommand($command));
}


#
# launches a pipelined transfert, checks are crucial here!
# because an error breaks the pipe!
#
# Should only be used on efficients transferts for the moment!!
#
sub runEfficientPipelinedCommand {
    my $self = shift;
    my $commandLocal = shift; # command run locally expl: tar -zxf image.tgz |
    my $commandRemote = shift; # command to execute on a set of nodes
    my $errorMessage = shift; # error message to report on failure

    if(!$sentinellePipelineArgs) { # here, use runReportedCommand instead, not crucial anymore...
	return ($self->runReportedRemoteCommand($commandLocal, $commandRemote, $errorMessage))
    }
    my $parallelLauncher = $commandLocal . " " . $sentinelleCmd . " " . $sentinellePipelineArgs . " -v ";

    # up to now, every error means dead of the deployment
    $self->setNodesErrorMessage($errorMessage);
  
    if($self->runIt($parallelLauncher, $commandLocal, $commandRemote)) {
	return 1;
    }

    # here, we should discard all the nodes...
    # I am not sure the program will reach this part in case of a problem
    # if sentinelle hangs-> nothing more can be done...
    # everything that follows seems to be useless...
    foreach my $nodeIP (@{$self->{nodesToPing}}) {
	    $self->{nodesByIPs}{$nodeIP}->set_state(-1);
    }
    # Let's sync the Nodes' state
    $self->syncNodesReadyOrNot();

    return 0;
}

sub tar {
my $self = shift;
    #my $launcherOpts = "-c ssh -l root -t 2 -w 50";
    #my $launcherDirectory = "/home/deploy/kadeploy2/tools/sentinelle/";
    #my $parallelLauncher = $launcherDirectory . "sentinelle.pl";
    my $parallelLauncher = libkadeploy2::conflib::get_conf("perl_sentinelle_cmd");
    my $launcherOpts = libkadeploy2::conflib::get_conf("perl_sentinelle_default_args");
    my $remoteCommand = "/root/tar";
		 
    my $executedCommand = $parallelLauncher . " " . $launcherOpts;
		      
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();
    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }
    foreach my $key (sort keys %{$self->{nodesReady}}) {
        $executedCommand .= " -m $key";
    }
    $executedCommand .= " -p " . "\"" . $remoteCommand . "\"";
#    print"$executedCommand \n";
   system ($executedCommand);
   return 1;		
}






sub rebootThoseNodes 
{
    my $self = shift;
    my $connector = "rsh -l root";
    my $remoteCommand = "reboot_detach";

    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) {
        $executedCommands{$nodeIP} = $connector . " " . $nodeIP . " " . $remoteCommand; 
    }

    return $self->runThose(\%executedCommands, 2, 50, "reboot failed on node");
}





sub rebootThoseNodesold {
    my $self = shift;
    my $connector = "rsh -l root";
    my $remoteCommand = "reboot_detach &";

    my %executedCommands;
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
        return 1;
    }

    foreach my $nodeIP (sort keys %{$self->{nodesReady}}) {
	$executedCommands{$nodeIP} = $connector . " " . $nodeIP . " " . $remoteCommand; 
    }

    return $self->runThose(\%executedCommands, 2, 50, "reboot failed on node");		    
}



#
# Runs a remote system command and kill it after sentinelleTimeout
#
sub runRemoteSystemCommand {
    my $self = shift;
    my $executedCommand = $sentinelleCmd . " " . $sentinelleDefaultArgs;
    my $commandRemote = shift; # command to execute on a set of nodes
    my $nodesReadyNumber = $self->syncNodesReadyOrNot();
    my $return_value = 1;
    my $timedout;
    my $pid;

    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
	return 1;
    }
    
    foreach my $key (sort keys %{$self->{nodesReady}}) {
	$executedCommand .= " -m$key";
    }
    $executedCommand .= " -- " . $commandRemote;

    #print $executedCommand;

    if (!defined($pid = fork())) {
	die "cannot fork: $!";
    } elsif ($pid) {
	# I'm the parent
	print "Forking child $pid\n";
    } else {
	exec ("$executedCommand") or die "Couldn't execute $executedCommand: $!\n";
    }
    # waits a little...
    sleep(2*$sentinelleTimeout);
    # kill the job!!!
    kill(9, $pid);

    #system($executedCommand);
    return 1;
}



#
# Reboot nodes from deployment system
#
#sub rebootNodes {
#    my $self = shift;
#    my $launcherOpts = "-c rsh -l root -t 2 -w 50";
#    my $launcherDirectory = $kadeploy2Directory . "/tools/sentinelle/";
#    my $parallelLauncher = $launcherDirectory . "sentinelle.pl";
#    my $remoteCommand = "shutdown  -r now";
#
#    my $executedCommand = $parallelLauncher . " " . $launcherOpts;
#
#    my $nodesReadyNumber = $self->syncNodesReadyOrNot();
#
#    if($nodesReadyNumber == 0) { # no node is ready, so why get any further?
#        return 1;
#    }
#
#    foreach my $key (sort keys %{$self->{nodesReady}}) {
#        $executedCommand .= " -m $key";
#    }
#    $executedCommand .=	" -p " . "\"" . $remoteCommand . "\"";
#    system ($executedCommand);
#    return 1;
#}


1;
