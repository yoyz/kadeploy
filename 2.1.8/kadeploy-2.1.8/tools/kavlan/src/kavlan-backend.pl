#!/usr/bin/perl -w -I./src/ -I/usr/local/bin/kavlan

##########################################################################################
# KAVLAN 
# author       : Nicolas Niclausse
# date         : 02/10/2008
# note         :
##########################################################################################

package kavlan;

use strict;
use lib "/usr/local/kavlan/perl5";

use Getopt::Long;
use SNMP;
use const;
use vlan;
use KaVLAN::Config;
use KaVLAN::summit;
use KaVLAN::hp3400cl;
use KaVLAN::Cisco3750;
use KaVLAN::Foundry;

my $VLAN_PROPERTY_NAME="vlan"; # OAR property name of the VLAN ressource
my $VLAN_RANGE_NAME="NetVlan"; # config name of network range (site section)
my $VLAN_GATEWAY_NAME="IPVlan"; # config name of network gateway (router section)

# Verify that there is at least one argument
if($#ARGV < 0){
    &usage();
    exit(0);
}
&Getopt::Long::Configure("no_ignore_case");

my %options;
GetOptions(\%options,
        "i|vlan-id=s",
        "f|filenode=s",
        "m|machine=s@",
        "s|set",
        "q|quiet",
        "h|help",
        "v|verbose");

&usage(0) if( $options{"h"});

#------------------------------
# PARSE THE CONFIGURATION FILE
#------------------------------
$const::CONFIGURATION_FILE = $options{"F"} if ($options{"F"});
$const::VERBOSE=1 if $options{"v"};

my ($site,$router,$switch) = KaVLAN::Config::parseConfigurationFile();

$const::VLAN_DEFAULT_NAME=$site->{"VlanDefaultName"};

#-----------------------------
# GET APPLIANCE CONFIGURATION
#-----------------------------

#Get the configurations informations of the appliances
my $routerConfig;
my @switchConfig;

#Verifying if the -s option is activated to avoid loading router configuration
if(not defined $options{"s"}){
    if($router->{"Type"} eq "summit"){$routerConfig = KaVLAN::summit->new();}
    elsif($router->{"Type"} eq "hp3400cl"){$routerConfig =  KaVLAN::hp3400cl->new();}
    elsif($router->{"Type"} eq "Cisco3750"){$routerConfig = KaVLAN::Cisco3750->new();}
    elsif($router->{"Type"} eq "Foundry"){$routerConfig = KaVLAN::Foundry->new();}
    else{&mydie("ERROR : The router type doesn't exist");}
}

#We are loading all the switch information
foreach my $i (0 .. $#{$switch}){
    if($switch->[$i]{"Type"} eq "summit"){
        $switchConfig[$i] = KaVLAN::summit->new();
    }
    elsif($switch->[$i]{"Type"} eq "hp3400cl"){
        $switchConfig[$i] =  KaVLAN::hp3400cl->new();
    }
    elsif($switch->[$i]{"Type"} eq "Cisco3750"){
        $switchConfig[$i] = KaVLAN::Cisco3750->new();
    }
    elsif($switch->[$i]{"Type"} eq "Foundry"){
        $switchConfig[$i] = KaVLAN::Foundry->new();
    }
    else{
        &mydie("ERROR : The switch type doesn't exist");
    }
}

#---------------------------------------
# INITIALIZATION OF SNMP COMMUNICATIONS
#---------------------------------------

#SNMP informations
my $COMMUNITY = (defined $site->{"SNMPCommunity"}) ? $site->{"SNMPCommunity"} : "private";
my $routerSession;
my @switchSession;

#Create the SNMP sessions
if(not defined $options{"s"}){
    $routerSession= new SNMP::Session(DestHost => $router->{"IP"},
            Community => $COMMUNITY,
            Version => "2c",
            Timeout => 300000);
}
foreach my $i (0 .. $#{$switch}){
    print "establish session to remote SNMP server $switch->[$i]{IP}\n" if ($const::VERBOSE);
    $switchSession[$i]= new SNMP::Session(DestHost => $switch->[$i]{"IP"},
            Community => $COMMUNITY,
            Version => "2c",
            Timeout => 300000);
}

#--------------------------
# MANAGE ARGUMENTS
#--------------------------

my $USER;
if ($ENV{KAUSER}) {
    $USER=$ENV{KAUSER};
} else {
    $USER=$ENV{USER};
}

if ($options{"s"} ){ # set vlan for given nodes
    my @nodes = &KaVLAN::Config::get_nodes($options{"f"}, $options{"m"});
    my $VLAN  = $options{'i'};
    if (defined $VLAN) {
        &KaVLAN::Config::check_nodes_configuration(\@nodes,$site,$switch);
        foreach my $node (@nodes) {
            &set_vlan($node,$VLAN);
        }
    } else {
        &mydie("No VLAN found, abort!");
    }
    print "all nodes are configured in the vlan $VLAN\n" unless $options{"q"};
} else {
    &mydie("no action specified, abort");
}


## -----------------------------------------------------------------------
## End of main script here -----------------------------------------------
## -----------------------------------------------------------------------

sub set_vlan {
    my $node = shift;
    my $VLAN = shift;
    my ($port,$switchName) = KaVLAN::Config::getPortNumber($node,$site->{"Name"});
    my $indiceSwitch = &KaVLAN::Config::getSwitchIdByName($switchName,$switch);

    # we have already checked before (in check_nodes_configuration
    # )that the indice is defined and we have rights to modify the
    # port, therefore, we can skip checks here
    my $otherMode;
    $otherMode=1 if($switch->[$indiceSwitch]{"Type"} eq "hp3400cl");
    &vlan::addUntaggedPort($VLAN,$port,$switchSession[$indiceSwitch],$switchConfig[$indiceSwitch],$otherMode);
    print " ... node $node changed to vlan KAVLAN-$VLAN\n"  unless $options{"q"};
}

sub mydie {
    my $msg  = shift;
    print STDERR "$msg\n" unless $options{"q"};
    exit 1;
}

sub usage(){
    my $status= shift;
    $status=1 unless defined $status;
print "Version $const::VERSION
USAGE : $0 [options]
       -i|--vlan_id <VLANID>
       -s                            set vlan for given node(s)
       -f|--filenode <NODEFILE>
       -m|--machine <nodename>
       -q|--quiet                    quiet mode
       -h|--help                     print this help
       -v|--verbose                  verbose mode\n";
    exit $status;
}
