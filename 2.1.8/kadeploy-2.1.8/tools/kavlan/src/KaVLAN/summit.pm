#!/usr/bin/perl -w

##########################################################################################
# Specific functions for the summit 
# author       : Jérémie TISSERAND
# date         : 28/08/2006
# note         : 
##########################################################################################
# version      :
# modified     : 29/07/2008
# author       : Nicolas Niclausse
# modification : inherit from KaVLAN::Switch class
##########################################################################################



package KaVLAN::summit;

use KaVLAN::Switch;
@ISA = ("KaVLAN::Switch");

#For a better syntaxe
use strict;
#Include SNMP functions
use SNMP;

use const;



my $SUMMIT_VLAN_NAME=".1.3.6.1.4.1.1916.1.2.1.2.1.2";
my $SUMMIT_TAG      =".1.3.6.1.4.1.1916.1.2.1.2.1.10";
my $SUMMIT_IP       =".1.3.6.1.4.1.1916.1.2.4.1.1.1";
my $SUMMIT_MASK     =".1.3.6.1.4.1.1916.1.2.4.1.1.2";
my $SUMMIT_LIST_PORT=".1.3.6.1.2.1.31.1.2.1.3";
my $SUMMIT_NB_PORT=49;
my $SUMMIT_TAG_VALUE=4;
my $SUMMIT_UNTAG_VALUE=4;
my $SUMMIT_REMOVE_VALUE=6;
my $SUMMIT_AFFECTED_TAG_VALUE=1;
my $SUMMIT_AFFECTED_UNTAG_VALUE=1;
my $SUMMIT_OFFSET_UNTAG_TAG=1;

##########################################################################################
# Constructor of the object 
# arg : 
# ret : 
# rmq :
##########################################################################################
sub new(){
    my ($pkg)= @_;
    my $self = bless KaVLAN::Switch->new("summit",$SUMMIT_VLAN_NAME, $SUMMIT_IP, $SUMMIT_MASK, $SUMMIT_TAG),$pkg;
    return $self;
}

# sub getVlanNumber()      : inherited
# sub getVlanName()        : inherited
# sub modifyVlanName()     : inherited (but specific to hp)
# sub getIPConfiguration() : inherited
# sub getTagConfiguration(): inherited

# sub listVlanOnRouteur()  : inherited
# sub listVlanOnSwitch()   : inherited
# sub getPortInformation() : inherited

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
#Check arguement
    my ($vlanName,$switchSession)=@_;
    if(not defined $vlanName or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }


#Get port informations
    &const::verbose("Getting ports affected");

#Retreive the vlan number
        my @vlanNumber;
        if($vlanName eq $const::DEFAULT_NAME){
                @vlanNumber= $self->getVlanNumber($const::VLAN_DEFAULT_NAME,$switchSession);
        }
        else{
                @vlanNumber= $self->getVlanNumber($const::MODIFY_NAME_KAVLAN.$vlanName,$switchSession);
        }
    if($#vlanNumber == -1){
        die "ERROR : There is no vlan under this name";
    }

#Get the information
    my $var=new SNMP::VarList([$SUMMIT_LIST_PORT,$vlanNumber[0]],[$SUMMIT_LIST_PORT,$vlanNumber[0]+$SUMMIT_OFFSET_UNTAG_TAG]);

        my @info = $switchSession->bulkwalk(0,($SUMMIT_NB_PORT+1),$var);

#Look if there are any ports affected in the tag or untag mode
        my $i;
        for($i=0;$i<$#{@{$info[0]}}+1;$i++){
#Retreive the oid sometimes, the oid is not in the good field and is in the name of the object that's why we try two way to get this number
                my $val =  ${@{$info[0]}}[$i]->iid;
                if(not defined $val or $val eq ""){
                        $val = ${@{${@{$info[0]}}[$i]}}[0];
                }
        $val =~ s/\w+\.//g;
        $val =~ s/\D+//g;
        if($val < ($SUMMIT_NB_PORT+1)){
            if(${@{$info[0]}}[$i]->val eq $SUMMIT_AFFECTED_UNTAG_VALUE){
                push @{$res{"UNTAGGED"}}, $val;
            }
        }
        }
        for($i=0;$i<$#{@{$info[1]}}+1;$i++){
#Retreive the oid sometimes, the oid is not in the good field and is in the name of the object that's why we try two way to get this number
                my $val =  ${@{$info[1]}}[$i]->iid;
                if(not defined $val or $val eq ""){
                        $val = ${@{${@{$info[1]}}[$i]}}[0];
                }

        $val =~ s/\w+\.//g;
        $val =~ s/\D+//g;
        if(${@{$info[1]}}[$i]->val eq $SUMMIT_AFFECTED_UNTAG_VALUE){
                push @{$res{"TAGGED"}}, $val;
        }
    }
    return \%res;
}

##########################################################################################
# Set a port as tag 
# arg : String -> the vlan name
#       Integer -> the port
#    Session -> a switch session
# ret : 
# rmq :
##########################################################################################
sub setTag(){
#Check arguement
    my $self = shift;
    my ($vlanName,$port,$switchSession)=@_;
    if(not defined $vlanName or not defined $port or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

#Retreive the vlan number of $vlanName
    &const::verbose("Verifying that the vlan is available");
    my @vlanNumber;
    if($vlanName eq $const::DEFAULT_NAME){
        @vlanNumber= $self->getVlanNumber($const::VLAN_DEFAULT_NAME,$switchSession);
    }
    else{
        @vlanNumber= $self->getVlanNumber($const::MODIFY_NAME_KAVLAN.$vlanName,$switchSession);
    }
    if($#vlanNumber==-1){
        die "ERROR : There is no vlan available";
    }

#For tagged port there is a magic thing ;)
    $vlanNumber[0]+=$SUMMIT_OFFSET_UNTAG_TAG;

#Change the port information

    &const::verbose("Put the port in tag mode ",$port," to the vlan ",$vlanNumber[0]);    
    my $var = new SNMP::Varbind([$SUMMIT_LIST_PORT.".".$vlanNumber[0],$port,$SUMMIT_TAG_VALUE,"INTEGER"]);
    $switchSession->set($var) or die "ERROR : Can't affect the port to the vlan";
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
#Check arguement
    my $self = shift;
    my ($vlanName,$port,$switchSession)=@_;
    if(not defined $vlanName or not defined $port or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

#Retreive the vlan number of $vlanName
    &const::verbose("Verifying that the vlan is available");
        my @vlanNumber;
        if($vlanName eq $const::DEFAULT_NAME){
                @vlanNumber= $self->getVlanNumber($const::VLAN_DEFAULT_NAME,$switchSession);
        }
        else{
                @vlanNumber= $self->getVlanNumber($const::MODIFY_NAME_KAVLAN.$vlanName,$switchSession);
        }

    if($#vlanNumber==-1){
        die "ERROR : There is no vlan available";
    }


#Change the port information

    &const::verbose("Put the port in untag mode ",$port," to the vlan ",$vlanNumber[0]);    
    my $var = new SNMP::Varbind([$SUMMIT_LIST_PORT.".".$vlanNumber[0],$port,$SUMMIT_UNTAG_VALUE,"INTEGER"]);

    $switchSession->set($var) or die "ERROR : Can't affect the port to the vlan";

}

##########################################################################################
# Set a port as remove 
# arg : String -> the vlan name
#       Integer -> the port
#    Session -> a switch session
# ret : 
# rmq :
##########################################################################################
sub setRemove(){
#Check arguement
    my $self = shift;
    my ($vlanName,$port,$switchSession)=@_;
    if(not defined $vlanName or not defined $port or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

#Retreive the vlan number of $vlanName
    &const::verbose("Getting the vlan number");
        my @vlanNumber;
        if($vlanName eq $const::DEFAULT_NAME){
                @vlanNumber= $self->getVlanNumber($const::VLAN_DEFAULT_NAME,$switchSession);
        }
        else{
                @vlanNumber= $self->getVlanNumber($const::MODIFY_NAME_KAVLAN.$vlanName,$switchSession);
        }

    if($#vlanNumber==-1){
        die "ERROR : There is no vlan under this name";
    }

#Change the port information

    &const::verbose("Remove the port ",$port," from the vlan ",$vlanNumber[0]);    
    my $varTagged = new SNMP::Varbind([$SUMMIT_LIST_PORT.".".$vlanNumber[0],$port,$SUMMIT_REMOVE_VALUE,"INTEGER"]);
    my $varUntagged = new SNMP::Varbind([$SUMMIT_LIST_PORT.".".($vlanNumber[0]+$SUMMIT_OFFSET_UNTAG_TAG),$port,$SUMMIT_REMOVE_VALUE,"INTEGER"]);
#If the port was untagged we put him in the default vlan

    $switchSession->set($varUntagged) or $switchSession->set($varTagged) or die "ERROR : Can't remove port ".$port." from vlan ".$vlanName;

}

1;
