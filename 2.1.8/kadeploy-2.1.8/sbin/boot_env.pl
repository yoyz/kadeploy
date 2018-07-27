#!/usr/bin/perl

#-----------------------------------------------------------
# Config file searched : <config directory>/deploy_cmd.conf
#-----------------------------------------------------------

use File::Copy;
use Getopt::Long;
use lib::conflib;
use lib::bootlib;
use lib::deploy_iolib;

use strict;

my $soft = 0;
my $hard = 0;
my @host_list = ();
my $env = "";
my $device="";
my $reboot = "";

if (!@ARGV){
    print "Usage : boot_env.pl [-s|--soft] [-h|--hard] -m|--machine hostname -e|--environment name -p|--partition partition\n";
    exit 0;
}

## gets the options
GetOptions('m=s'           => \@host_list,
	   'machine=s'     => \@host_list,
	   'e=s'           => \$env,
	   'environment=s' => \$env,
	   's'             => \$soft,
	   'soft'          => \$soft,
	   'h'             => \$hard,
	   'hard'          => \$hard,
	   'p=s'           => \$device,
	   'partition=s'   => \$device,
	   );

## checks if needed options are defined
if ((!@host_list)||((!$env)&&(!$device))){
    print "Usage : boot_env.pl [-s|--soft] [-h|--hard] -m|--machine hostname -e|--environment name -p|--partition partition\n";
    exit 0;
}
if ((!($soft)) && (!($hard))){
    print "ERROR : please define the type of reboot you want (either soft or hard)\n";
    exit 0;
}
if ($soft && $hard){
    print "ERROR : soft and hard reboot options should be exclusive\n";
    print "EROOR : please select only one of them at once\n";
    exit 0;
}
if ($env && $device){
    print "ERROR : you should specify EITHER a environment OR a partition to boot on\n";
    exit 0;    
}

# defines reboot type
if ($soft){
    $reboot = "softboot";
}elsif ($hard){
    $reboot = "hardboot";
}else{
    print "ERROR : this case should never happen... you are in big trouble...\n";
    exit 0;
}


## Available variables are :
## - @host_list - list of hosts to reboot
## - $env - environment name
##  OR
## - $device - device and partition number

my %cmd = conflib::check_cmd;

foreach my $host (@host_list){
    my $dev="";
    my $part="";
    my %node_info;
    my @env_info = ();

    if(!$cmd{$host}{$reboot}){
	print "WARNING : no $reboot command found for $host !\n";
    }else{
	# debug print
	# print "to be executed : $host -> $cmd{$host}{$reboot}\n";

	# searches for partition with requested environment
	my $base = deploy_iolib::connect();

	if ($env){
	    my @res = deploy_iolib::search_deployed_env($base,$env,$host);
	    if(scalar(@res)){
		# gets device and part number of the first partition by default for the moment
		$dev  = deploy_iolib::disk_id_to_dev($base,$res[0][0]);
		$part = deploy_iolib::part_id_to_nb($base,$res[0][1]);
		
		# debug print
		# print "DEV = $dev ; PART = $part ; That's it !\n";
		
		my $kernel_path = deploy_iolib::env_name_to_kernel($base,$env);

		@env_info = ($env,$kernel_path);
	    }
	}elsif($device){
	    # separates device and partition number from $device
	    $dev = substr($device, 0, 3);
	    my @nb = split(/$dev/, $device);
	    $part = $nb[1];

	    # gets the environment installed on
	    @env_info = deploy_iolib::get_installed_env($base,$host,$dev,$part);
	}else{
	    print "ERROR : this case should never happen neither...\n";
	    exit 0;
	}
	
	if ($dev && $part && scalar(@env_info)){
	    # grub and pxe
	    my $ip = deploy_iolib::node_name_to_ip($base,$host);
	    $node_info{$ip} = [$dev,$part];
	    bootlib::manage_grub_pxe(\%node_info,\@env_info);
	    # reboots
	    print "Rebooting...\n";
	    system("$cmd{$host}{$reboot}");
	  }else{
	      print "ERROR : parameters (env image ? kernel path ? device ? partition ?) are missing...";
	      exit 0;
	  }
	deploy_iolib::disconnect($base);
    }
}
