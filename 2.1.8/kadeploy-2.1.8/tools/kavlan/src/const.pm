#!/usr/bin/perl -w

##########################################################################################
# Const file of kavlan 
# author       : Jérémie TISSERAND
# date         : 29/08/2006
# note         : 
##########################################################################################
# version      :
# modified     : 
# author       :
# modification :
##########################################################################################



package const;
@ISA = ("Exporter");


#For a better syntaxe
use strict;

#Version of kavlan
our $VERSION="1.0";

#Location of the configuration file
our $CONFIGURATION_FILE="/etc/kavlan/kavlan.conf";

#Location of the configuration file
our $PATH_TABLE_CORES="/etc/kavlan/";

#Default name of VLAN that kavlan can modify
our $DEFAULT_NAME_KAVLAN="KAVLAN_";

#Name reserved to define the default name
our $DEFAULT_NAME="DEFAULT";

#Default name of the vlan on the site
our $VLAN_DEFAULT_NAME;

# VLAN NAME use an id starting from 1 to $VLAN_MAX_ID
our $VLAN_MAX_ID=8;

#Name of vlan when kavlan have modify them we are using the USER env variable to put it in the name of the vlan
#in order to know which vlan this user have modified and allow other people not to change configuration of our vlan
our $MODIFY_NAME_KAVLAN="KAVLAN-";

#Maximum of vlan allowed by ieee on network appliances
our $IEEE_MAX_VLAN=4095;

#Activate the verbose mode
our $VERBOSE=0;

#Activate the debug mode
our $DEBUG=0;
#Uses during the verbose mode to show the name of the function this variable have to be redefined in each function in order to override the variable of the caller function
our $FUNC_NAME="main";

# Cache SNMP results for all sessions (VLAN name, ports index, and so on ...)
our %CACHE ;


##########################################################################################
# Verbose function 
# arg : ...
# ret : 
# rmq : print all the arguments and a '\n' if the verbose mode is activated
##########################################################################################
sub verbose(){
    my @args=@_;

    if($const::VERBOSE!=0){
        my $function = (caller(1))[3];
        print $function."::";
        foreach my $item (@args){
            print $item;
    }

        print "\n";
    }
}

sub debug(){
    my $string= shift;
    if($const::DEBUG){
        print "DEBUG: $string\n";
    }
}

1;
