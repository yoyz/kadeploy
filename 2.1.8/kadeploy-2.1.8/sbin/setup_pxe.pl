#!/usr/bin/perl

use Getopt::Long;

use libkadeploy2::conflib;
use libkadeploy2::deploy_iolib;
use libkadeploy2::confroot;

my $conf_root_dir;
my @host_list; # machine name is prefered since it allows to change only the configuration directive to pass a node from one cluster to another, in the deploy_cmd.conf file otherwise 2 lines would have been required

my $usage = "Usage : setup_pxe.pl \
range1:kernel1:initrd1 [range2:kernel2:initrd2 ...]\n\
[-C|--configuration <configuration root directory>]\n\
\twhere range can be a hostname declared in kadeploy database \
(should be prefered for multi cluster sites with several databases), \
a single IP adress e.g. '192.168.10.19' or an interval e.g. '192.168.10.5-17'\n";

$PROMPT = 1;
$DISPLAY = "messages";
$TIMEOUT = 50;
$BAUDRATE = 38400;

if (!@ARGV) {
  print $usage;
  exit 0;
}

#------------
# Get option
#------------
GetOptions( 'C=s'   => \$conf_root_dir,
  'configuration=s' => \$conf_root_dir
);

if (!$conf_root_dir eq "") {
  libkadeploy2::confroot::set_conf_rootdir($conf_root_dir);
}
libkadeploy2::confroot::get_conf_rootdir();
libkadeploy2::confroot::info();

# Configuration
my $configuration = libkadeploy2::conflib->new();

if (!$configuration->check_conf()) {
    print "ERROR : problem occured loading configuration file\n";
    exit 1;
}

## gets appropriate parameters from configuration file
$network = $configuration->get_conf("network");
$tftp_repository = $configuration->get_conf("tftp_repository");
$pxe_rep = $tftp_repository . $configuration->get_conf("pxe_rep");
$tftp_relative_path = $configuration->get_conf("tftp_relative_path");

$images_repository = $tftp_repository . $tftp_relative_path;

# debug print
#print "1. $network ; 2. $tftp_repository ; 3. $pxe_rep ; 4. $tftp_relative_path ; 5. $images_repository\n";

###
# Let's GO!
###
my $error;
my @hexnetworks;
my @ranges1;
my @ranges2;
my @kernels;
my @initrds;
my $addr;

(@args) = @ARGV;

sub rangeify {
    my $thing = shift; # range, IP or hostname 

    if (($thing =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) || ($thing =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)-(\d+)$/)) {
        # $thing is a valid range
	return $thing;
    } else { # thing should be a name
	push (@host_list, $thing);
	if (!$configuration->check_nodes_conf(\@host_list) || !$configuration->check_conf()) {
		print "ERROR : problem occured loading configuration file\n";
		exit 1;
	}
	# update settings for the rest
	$network = $configuration->get_conf("network");
	$tftp_repository = $configuration->get_conf("tftp_repository");
	$pxe_rep = $tftp_repository . $configuration->get_conf("pxe_rep");
	$tftp_relative_path = $configuration->get_conf("tftp_relative_path");
	libkadeploy2::deploy_iolib::register_conf($configuration);
	my $base = libkadeploy2::deploy_iolib::connect();
	$addr = libkadeploy2::deploy_iolib::node_name_to_ip($base,$thing);
	libkadeploy2::deploy_iolib::disconnect($base);
	if(!$addr) {
		print STDERR "ERROR : cannot retrive ipadress for " . $thing . "\n";
		exit 1;
	}
	return $addr;
    }
}

sub hexalize {
    $number = shift;
    if ($number<16) {
	return (sprintf "0%X", $number);
    }
    else {
	return (sprintf "%X", $number);
    }
}


sub test_network {
    my $net = shift;
    if ($net =~ /^(\d+)\.(\d+)\.(\d+)$/) {
	if ((0<$1) and ($1<255) and (0<=$2) and ($2<=255) and (0<=$3) and ($3<=255)) {
	    $hexnet = hexalize($1) . hexalize($2) . hexalize($3);
	    push (@hexnetworks, $hexnet);
	    return 1;
	}
    }
    return 0;
}


sub test_me {
    my $net = shift;
    my $first = shift;
    my $last = shift;
    if (!test_network($net)) {
	$error = "wrong network: $net";
	return 0;
    }
    if (($first < 1) or ($first > 254)) {
	$error = "wrong IP range: $first";
	return 0;
    }
    if (($last < $first) or ($last > 254)) {
	$error = "wrong IP range or order in range: $first-$last";
	return 0;
    }
    push(@ranges1, $first);
    push(@ranges2, $last);
    return 1;
}


sub test_range {
    my $range = shift;

    $range =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ and return test_me("$1.$2.$3", $4, $4);
    $range =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)-(\d+)$/ and  return test_me("$1.$2.$3", $4, $5);
    $error = "invalid range syntax: $range";
    return 0;
}


sub test {
    my $range = shift;
    my $kernel = shift;
    my $initrd = shift;
    
    $test_range = test_range($range);    
    $test_range or return 0; # error on range

    push(@kernels, $kernel);
    push(@initrds, $initrd); 

    return 1;

}

$template_default_content="PROMPT $PROMPT\nSERIAL 0 $BAUDRATE\nDEFAULT bootlabel\nDISPLAY $DISPLAY\nTIMEOUT $TIMEOUT\n\nlabel bootlabel\n";

# perform tests on arguments and fill arrays
ARG: foreach $argument (@args) {
    if ($argument =~ /^(.*)\:(.*)\:(.*)$/) {
	$range = rangeify($1);
	$kernel = $2;
	$initrd = $3;
	test($range, $kernel, $initrd) and print "OK\n" and next ARG;
# failure in range or label
	die "error: $error";
    }
    elsif ($argument =~ /^(.*)\:(.*)$/) { # we use a shortcut here
	    $range = rangeify($1);
	    $label = $2; # label to get from configuration
	    $label =~ /^label/ or die "wrong label syntax: should begin with the prefix \'label\'";
	    if ($configuration->is_conf($label)) {
		    $argument = $configuration->get_conf($label);
		    if ($argument =~ /^(.*)\:(.*)$/) {
			     $kernel = $1;
			     $initrd = $2;
			     test($range, $kernel, $initrd) and print "OK\n" and next ARG;
			     die "error: $error";
		     }
		     else {
			     die "wrong label syntax: should be \'kernel:initrd\'";
		     }
	    }
	    else {
		die "error: label $label is undefined";
	    }
    
    }
    else {
	die "wrong syntax";
    }
}

# generate files in pxe directories and overwrite old ones
for ($i=0; $i<scalar(@kernels); $i++) {

    print "kernel $kernels[$i], initrd $intrds[$i] from ",hexalize($ranges1[$i])," to ", hexalize($ranges2[$i]) ,"\n";

    $kernel = $tftp_relative_path . "/" . $kernels[$i];
    $initrd = $initrds[$i];

    $append = "initrd=$tftp_relative_path/$initrd";
    for($j=$ranges1[$i]; $j<=$ranges2[$i]; $j++) {
	$destination=$pxe_rep.$hexnetworks[$i].hexalize($j);
	unlink $destination if (-l $destination); #prevent from overwriting the default PXE configuration
	open(DEST, "> $destination")
	    or die "Couldn't open $destination for writing: $!\n";
	print DEST "$template_default_content\tKERNEL $kernel\n\tAPPEND $append";
	close(DEST);
    }
}
