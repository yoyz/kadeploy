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

package KaVLAN::Foundry;
use KaVLAN::Switch;
@ISA = ("KaVLAN::Switch");

use strict;
use warnings;
use Data::Dumper;

# main OIDs
my $FOUNDRY_VLAN_NAME = ".1.3.6.1.2.1.17.7.1.4.3.1.1";
my $FOUNDRY_TAG       = "";
my $FOUNDRY_IP        = ".1.3.6.1.4.1.1991.1.2.2.18.1.2"; # only used for router ?
my $FOUNDRY_MASK      = ".1.3.6.1.4.1.1991.1.2.2.18.1.3"; # only used for router ?

my $MAX_PORTS=1000;

# Documentation: Foundry MIB Reference Guide

# see also (but does not apply in our case):
# http://www.notarus.net/networking/foundry_snmp.htmla

# specific OIDs
my $FOUNDRY_LIST_UNTAG= ".1.3.6.1.4.1.1991.1.1.3.3.5.1.24"; # snSwIfVlanId
my $FOUNDRY_PORT_IFINDEX = ".1.3.6.1.2.1.2.2.1.2"; # FIXME
my $FOUNDRY_MEMBER_STATUS = ".1.3.6.1.4.1.1991.1.1.3.2.6.1.3"; #.<VLAN>.<PORTINDEX> : snVLanByPortMemberRowStatus
my $FOUNDRY_DELETE_VLAN=3;
my $FOUNDRY_CREATE_VLAN=4;

sub new {
    my ($pkg)= @_;
    my $self = bless KaVLAN::Switch->new("Foundry",$FOUNDRY_VLAN_NAME, $FOUNDRY_IP, $FOUNDRY_MASK, $FOUNDRY_TAG),$pkg;
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
    # no direct way with foundry; must get the vlan index first
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
    my $self = shift;
    #Check arguments
    my ($vlanName,$switchSession)=@_;
    if(not defined $vlanName or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    my %res;

    #Get port informations
    &const::verbose("Getting ports affected");

    #Retrieve the vlan number
    my @vlanNumber;
    my $realVlanName = ($vlanName eq $const::DEFAULT_NAME) ? $const::VLAN_DEFAULT_NAME : $const::MODIFY_NAME_KAVLAN.$vlanName;
    @vlanNumber= $self->getVlanNumber($realVlanName,$switchSession);
    if($#vlanNumber == -1){
        die "ERROR : There is no vlan under this name";
    }
     my $untag =new SNMP::VarList([$FOUNDRY_LIST_UNTAG]);
     foreach my $i ($switchSession->bulkwalk(0,$MAX_PORTS,$untag)) {
         foreach my $j (@ {$i}) {
             if ($j->[2] == $vlanNumber[0] and  $j->[0] =~ /(\d+)$/) {
                 my $port = &getPortFromIndex($1,$switchSession);
                 &const::verbose("port $port is in vlan $vlanNumber[0]");
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
    # first, we must remove the port from its current VLAN
    my @OldVLAN = $self->getPortInformation($port,$switchSession);
    if ($#OldVLAN==-1){
        die "ERROR : Can't find current VLAN of port $port";
    }
    &const::verbose("The port is currently in the VLAN ",$OldVLAN[0]);
    my $ifIndex = &getPortIfIndex($port,$switchSession);
    # delete
    my ($old_vlan_number)= $self->getVlanNumber($OldVLAN[0],$switchSession);
    &const::verbose("old vlan number is $old_vlan_number");
    my $var = new SNMP::Varbind([ $FOUNDRY_MEMBER_STATUS, "$old_vlan_number.$ifIndex", $FOUNDRY_DELETE_VLAN,"INTEGER"]);
    $switchSession->set($var) or die "ERROR : Can't delete the port from the old vlan ($OldVLAN[0].$ifIndex)";
    # create
    $var = new SNMP::Varbind([ $FOUNDRY_MEMBER_STATUS, "$vlanNumber[0].$ifIndex", $FOUNDRY_CREATE_VLAN,"INTEGER"]);
    $switchSession->set($var) or die "ERROR : Can't add the port to the new vlan";
}

##########################################################################################
# arg : integer -> the vlan index
# ret : string -> the vlan name ( ex: 9/3 )
##########################################################################################
sub getPortFromIndex {
    my $ifIndex;
    my ($index,$switchSession) = @_;

   ## FIXME: compute index based on (X-1)*64+Y
    my $allports =new SNMP::VarList([$FOUNDRY_PORT_IFINDEX]);
    my $port;
    foreach my $i ($switchSession->bulkwalk(0,$MAX_PORTS,$allports)) {
        foreach my $j (@ {$i}) {
            if ($j->[1] =~ /$index$/) {
                $port = $j->[2];
                $port =~ s/\d*\D+(\d+\/\d+)/$1/;
            }
        }
    }
    return $port;
}

##########################################################################################
# arg : string -> the vlan name ( ex: 9/3 )
# ret : integer -> the vlan index
##########################################################################################
sub getPortIfIndex {
    my ($port,$switchSession) = @_;
    if ($port =~ m@(\d+)/(\d+)@) {
        # ifIndex of port X/Y is (X-1)*64+Y
        return ($1-1)*64+$2;
    } else {
        die "bad port format: $port";
    }
}

1;
