#!/usr/bin/perl -w

##########################################################################################
# Specific file for the Cisco3750
# author       : Nicolas Niclausse
# date         : 29/07/2008
# note         :
##########################################################################################
# version      :
# modified     :
# author       :
# modification :
##########################################################################################

package KaVLAN::Cisco3750;
use KaVLAN::Switch;
@ISA = ("KaVLAN::Switch");

use strict;
use warnings;
use Data::Dumper;

# Documentation: 
# How To Add, Modify, and Remove VLANs on a Catalyst Using SNMP:
# http://www.cisco.com/en/US/tech/tk648/tk362/technologies_tech_note09186a00801c6035.shtml
#
# see also:
# http://mediatools.cs.ucl.ac.uk/nets/hen/browser/hen_scripts/trunk/lib/hardware/switches/cisco.py?rev=638

my $CISCO_VLAN_NAME = ".1.3.6.1.4.1.9.9.46.1.3.1.1.4.1";
my $CISCO_TAG       = "";
my $CISCO_IP        = ".1.3.6.1.2.1.3.1.1.3"; # RFC1213-MIB::atNetAddress
my $CISCO_MASK      = ".1.3.6.1.2.1.4.20.1.3"; #IP-MIB::ipAdEntNetMask IpAddress
my $CISCO_LIST_PORT = ".1.3.6.1.2.1.31.1.2.1.3";
my $CISCO_LIST_UNTAG= ".1.3.6.1.4.1.9.5.1.9.3.1.3";
my $CISCO_PORT_IFINDEX = ".1.3.6.1.2.1.47.1.1.1.1.14";

my $CISCO_VMVLAN = ".1.3.6.1.4.1.9.9.68.1.2.2.1.2"; # access vlan for every port (if defined)
# vlans list :      .1.3.6.1.4.1.9.9.46.1.3.1.1.2 (vtpVlanState)
# .1.3.6.1.4.1.9.9.68.1.2.2.1.4 #vmvlans
# .1.3.6.1.4.1.9.9.46           #ciscoVtpMIB
# .1.3.6.1.4.1.9.9.46.1.6.1.1.5 # native vlan

sub new {
    my ($pkg)= @_;
    my $self = bless KaVLAN::Switch->new("Cisco3750",$CISCO_VLAN_NAME, $CISCO_IP, $CISCO_MASK, $CISCO_TAG),$pkg;
    return $self;
}

##########################################################################################
# Get the IP Configuration of a vlan
# arg : Integer -> the number of the vlan on the routeur session
#       Session -> a session on which we can get the IP address
# ret : String -> the IP configuration 'IP/MASK'
# rmq :
##########################################################################################
sub getIPConfiguration {
# -> no direct way with foundry; must get the vlan index first
    warn "getIPConfiguration not implemented";
    return;
}

##########################################################################################
# Get the ports affected to a vlan 
# arg : String -> the vlan name
#       Session -> a switch session
# ret : hash table reference : -> "TAGGED" array containing the tagged ports
#                              -> "UNTAGGED" array containing the untagged ports
# rmq : The vlan have to be present on the switch
##########################################################################################
sub getPortsAffectedToVlan(){
    my %res;
    my $self = shift;
    #Check arguments
    my ($vlanName,$switchSession)=@_;
    if(not defined $vlanName or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

    #Get port informations
    &const::verbose("Getting ports affected");

    #Retrieve the vlan number
    my @vlanNumber;
    my $realVlanName = ($vlanName eq $const::DEFAULT_NAME) ? $const::VLAN_DEFAULT_NAME : $const::MODIFY_NAME_KAVLAN.$vlanName;
    @vlanNumber= $self->getVlanNumber($realVlanName,$switchSession);
    if($#vlanNumber == -1){
        die "ERROR : There is no vlan under this name";
    }
    my $untag =new SNMP::VarList([$CISCO_LIST_UNTAG]);
    foreach my $i ($switchSession->bulkwalk(0,$const::IEEE_MAX_VLAN,$untag)) {
        foreach my $j (@ {$i}) {
            if ($j->[2] == $vlanNumber[0] and  $j->[0] =~ /(\d+)\.(\d+)$/) {
                my $port = "$1/0/$2";
                push @{$res{"UNTAGGED"}}, $port;
            }
        }
    }
    ## FIXME: handle tagged port
    &const::verbose("TAGGED vlan not implemented");
    return \%res;
}

##########################################################################################
# Set a port as untag 
# arg : String -> the vlan name
#       Integer -> the port
#    Session -> a switch session
# ret : 
# rmq :
##########################################################################################
sub setUntag(){
    # Check arguments
    my $self = shift;
    my ($vlanName,$port,$switchSession)=@_;
    if(not defined $vlanName or not defined $port or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

    # Retrieve the vlan number of $vlanName
    &const::verbose("Verifying that the vlan is available");
    my $realVlanName = ($vlanName eq $const::DEFAULT_NAME) ? $const::VLAN_DEFAULT_NAME : $const::MODIFY_NAME_KAVLAN.$vlanName;
    my @vlanNumber = $self->getVlanNumber($realVlanName,$switchSession);
    if ($#vlanNumber==-1){
        die "ERROR : There is no vlan available";
    }

    # Change the port information
    &const::verbose("Put the port ",$port," in untag mode to the vlan ",$vlanNumber[0]);
    my $ifIndex = &getPortIfIndex($port,$switchSession);

    my $var = new SNMP::Varbind([ $CISCO_VMVLAN, $ifIndex, $vlanNumber[0],"INTEGER"]);
    $switchSession->set($var) or die "ERROR : Can't affect the port to the vlan";
}

sub getPortIfIndex {
    my ($port,$switchSession) = @_;
    # On 3750, 2/0/23 port number is 2028
    # FIXME: why +5 ?
    if ($port =~ m@(\d+/\d+)/(\d+)@) {
        my ($sw,$p) = ($1,$2);
        $sw =~ s@/@@;
        $p +=5;
        my $portnumber=sprintf("%d%02d",$sw,$p);
        my $var = new SNMP::Varbind([$CISCO_PORT_IFINDEX,$portnumber]);
        my $ifIndex = $switchSession->get($var);
        &const::verbose("ifindex of port $port ($portnumber) is $ifIndex");
        return $ifIndex;
    } else {
        die "bad port format: $port";
    }
}

1;
