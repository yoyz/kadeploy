#!/usr/bin/perl

use Getopt::Long;

use lib::conflib;
use libkadeploy2::confroot;

my $conf_root_dir;
my $error;
my @hexnetworks;
my @ranges1;
my @ranges2;
my @kernels;
my @initrds;

$PROMPT = 1;
$DISPLAY = "messages";
$TIMEOUT = 50;
$BAUDRATE = 38400;

if (!@ARGV) {
  print "Usage : setup_pxe.pl \
range1:kernel1:initrd1 [range2:kernel2:initrd2 ...]\n\
[-C|--configuration <configuration root directory>]\n\
\twhere range can be a single IP adress e.g. \
'192.168.10.19' or an interval e.g. '192.168.10.5-17'\n";
	exit 0;
}

(@args) = @ARGV;

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

## gets appropriate parameters from configuration file
$network = conflib::get_conf("network");
$tftp_repository = conflib::get_conf("tftp_repository");
$pxe_rep = $tftp_repository . conflib::get_conf("pxe_rep");
$tftp_relative_path = conflib::get_conf("tftp_relative_path");

$images_repository = $tftp_repository . $tftp_relative_path;

# debug print
#print "1. $network ; 2. $tftp_repository ; 3. $pxe_rep ; 4. $tftp_relative_path ; 5. $images_repository\n";

###
# Let's GO!
###

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
	if ((0<$1) and ($1<255) and (0<$2) and ($2<255) and (0<$3) and ($3<255)) {
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

# copy grub_file to grub repositories
#-f $grub_file or die "grub image file does not exist!";

$template_default_content="PROMPT $PROMPT\nDEFAULT bootlabel\nDISPLAY $DISPLAY\nTIMEOUT $TIMEOUT\n\nlabel bootlabel\n";

# compute network hex address
#if ($network=~/(\d+)\.(\d+)\.(\d+)\.(\d+)/) {
#    @t=($1, $2, $3, $4);
#    $IP_hex="";
#    for ($i=0; $i<3; $i++) {
#	$network_hex.=hexalize($t[$i]);
#    }
#}
#else {
#    die "wrong network adress format";
#}


# perform tests on arguments and fill arrays
ARG: foreach $argument (@args) {
    if ($argument =~ /^(.*)\:(.*)\:(.*)$/) {
	$range = $1;
	$kernel = $2;
	$initrd = $3;
	test($range, $kernel, $initrd) and print "OK\n" and next ARG;
# failure in range or label
	die "error: $error";
    }
    elsif ($argument =~ /^(.*)\:(.*)$/) { # we use a shortcut here
	    $range = $1;
	    $label = $2; # label to get from configuration
	    $label =~ /^label/ or die "wrong label syntax: should begin with the prefix \'label\'";
	    if (conflib::is_conf($label)) {
		    $argument = conflib::get_conf($label);
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
	open(DEST, "> $destination")
	    or die "Couldn't open $destination for writing: $!\n";
	print DEST "$template_default_content\tKERNEL $kernel\n\tAPPEND $append";
	close(DEST);
    }
}
