#!/usr/bin/perl -w

##########################################################################################
# Specific file for the hp3400cl 
# author       : Jérémie TISSERAND
# date         : 29/08/2006
# note         : 
##########################################################################################
# version      :
# modified     : 
# author       :
# modification :
##########################################################################################



package KaVLAN::hp3400cl;
use KaVLAN::Switch;
@ISA = ("KaVLAN::Switch");

#For a better syntaxe
use strict;
#Include SNMP functions
use SNMP;

use const;



my $HP3400CL_VLAN_NAME_FOR_MODIF=".1.3.6.1.2.1.17.7.1.4.3.1.1";
my $HP3400CL_VLAN_NAME=".1.3.6.1.2.1.31.1.1.1.1";
my $HP3400CL_TAG=".1.3.6.1.2.1.16.22.1.1.1.1.4.1.3.6.1.2.1.16.22.1.4.1"; # VLAN_EXTERNAL_TO_INTERNAL_IDS
my $HP3400CL_IP=".1.3.6.1.4.1.11.2.14.11.1.4.8.1.1.1";
my $HP3400CL_MASK=".1.3.6.1.4.1.11.2.14.11.1.4.8.1.1.2";
my $HP3400CL_LIST_TAG=".1.3.6.1.2.1.17.7.1.4.3.1.2";
my $HP3400CL_LIST_UNTAG=".1.3.6.1.2.1.17.7.1.4.3.1.4";
my $HP3400CL_NB_PORT=49;
my $HP3400CL_AFFECTED_VALUE="1";
my $HP3400CL_REMOVE_VALUE="0";


##########################################################################################
# Constructor of the object 
# arg : 
# ret : 
# rmq :
##########################################################################################
sub new(){
    my ($pkg)= @_;
    my $self = bless KaVLAN::Switch->new("hp3400cl",$HP3400CL_VLAN_NAME, $HP3400CL_IP, $HP3400CL_MASK, $HP3400CL_TAG),$pkg;
    return $self;
}

##########################################################################################
# Modify a vlan name 
# arg : String -> the old name of the vlan
#     String -> the new name of the vlan 
#       Session -> the session on which we want to change the vlan name
# ret : 
# rmq : The number have to be retrieved by using the 'getVlanNumber' function
##########################################################################################
sub modifyVlanName(){
    my $self = shift;
#Check arguement
    my ($oldVlanName,$newVlanName,$session)=@_;
    if(not defined $oldVlanName or not defined $newVlanName or not defined $session){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

#Retreive the vlan number
    my @vlanNumber = $self->getVlanNumber($oldVlanName,$session);
    if($#vlanNumber==-1){
        die "ERROR : Can't modify the vlan name because there is vlan available";
    }
    
    $vlanNumber[0] = $self->getTagConfiguration($vlanNumber[0],$session);

#Create the snmp variable to apply changes in the vlan $vlanNumber
    my $var=new SNMP::Varbind([$HP3400CL_VLAN_NAME_FOR_MODIF,$vlanNumber[0],$newVlanName,"OCTETSTR"]);

#Send the snmp information
    &const::verbose("Applying modification");

    $session->set($var) or die "ERROR : Can't modify vlan (there is probably another vlan with the same name)\n";
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

#Check arguement
    my $self=shift;
    my ($vlanName,$switchSession)=@_;
    if(not defined $vlanName or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }


#Get port informations
    &const::verbose("Getting ports affected");

    #Retreive the vlan number
    my $realVlanName = ($vlanName eq $const::DEFAULT_NAME) ? $const::VLAN_DEFAULT_NAME : $const::MODIFY_NAME_KAVLAN.$vlanName;
    my @vlanNumber= $self->getVlanNumber($realVlanName,$switchSession);
    if($#vlanNumber == -1){
        die "ERROR : There is no vlan under this name";
    }

    $vlanNumber[0] = $self->getTagConfiguration($vlanNumber[0],$switchSession);

#Get the information
    my $untag =new SNMP::Varbind([$HP3400CL_LIST_UNTAG,$vlanNumber[0]]);
    my $tag = new SNMP::Varbind([$HP3400CL_LIST_TAG,$vlanNumber[0]]);

        $switchSession->get($untag);
        $switchSession->get($tag);

    my $untagInfo = unpack("B*",$untag->val);
    my $tagInfo = unpack("B*",$tag->val);


#Look if there are any ports affected in the tag or untag mode
        my $i;
        for($i=0;$i<($HP3400CL_NB_PORT+1);$i++){
#Retreive the oid sometimes, the oid is not in the good field and is in the name of the object that's why we try two way to get this number
               my $valUntag =  substr($untagInfo,$i,1); 
               my $valTag =  substr($tagInfo,$i,1); 

        if($valTag eq $HP3400CL_AFFECTED_VALUE && $valUntag eq $HP3400CL_AFFECTED_VALUE){
            push @{$res{"UNTAGGED"}}, ($i+1);
        }
        elsif($valTag eq $HP3400CL_AFFECTED_VALUE){
            push @{$res{"TAGGED"}}, ($i+1);
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
    my $realVlanName = ($vlanName eq $const::DEFAULT_NAME) ? $const::VLAN_DEFAULT_NAME : $const::MODIFY_NAME_KAVLAN.$vlanName;
    @vlanNumber= $self->getVlanNumber($realVlanName,$switchSession);
    if($#vlanNumber==-1){
        die "ERROR : There is no vlan available";
    }

    $vlanNumber[0] = $self->getTagConfiguration($vlanNumber[0],$switchSession);
#Change the port information

    &const::verbose("Put the port in tagged mode ",$port," to the vlan ",$vlanNumber[0]);
    my $tag = new SNMP::Varbind([$HP3400CL_LIST_TAG,$vlanNumber[0]]);
    my $untag = new SNMP::Varbind([$HP3400CL_LIST_UNTAG,$vlanNumber[0]]);

    $switchSession->get($tag);
    $switchSession->get($untag);

    my $depTag = $tag->val;
    my $depUntag = $untag->val;

#    print unpack("H*",$untag->val);
#    print "\n";
#    print unpack("H*",$tag->val);
#    print "\n";

    my $untagInfo = unpack("B*",$untag->val);
    my $tagInfo = unpack("B*",$tag->val);

    substr($untagInfo,($port-1),1)="0";
    substr($tagInfo,($port-1),1)="1";

#    print $untagInfo;
#    print "\n";
#    print $tagInfo;
#    print "\n";

    $untagInfo = pack("B*",$untagInfo);
    $tagInfo = pack("B*",$tagInfo);    

#    print unpack("H*",$untagInfo);
#    print "\n";
#    print unpack("H*",$tagInfo);
#    print "\n";

#    if($depTag ne $tagInfo && $depUntag eq $untagInfo){print "OK\n";}
#    else{print "KO\n";}

    my $newTag = new SNMP::Varbind([$HP3400CL_LIST_TAG,$vlanNumber[0],$tagInfo,"OCTETSTR"]);
    my $newUntag = new SNMP::Varbind([$HP3400CL_LIST_UNTAG,$vlanNumber[0],$untagInfo,"OCTETSTR"]);

    $switchSession->set($newTag) or die "ERROR : Can't affect the port to the vlan";
    $switchSession->set($newUntag) or die "ERROR : Can't affect the port to the vlan";

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

    $vlanNumber[0] = $self->getTagConfiguration($vlanNumber[0],$switchSession);
#Change the port information

    &const::verbose("Put the port in untag mode ",$port," to the vlan ",$vlanNumber[0]);    
    my $tag = new SNMP::Varbind([$HP3400CL_LIST_TAG,$vlanNumber[0]]);
    my $untag = new SNMP::Varbind([$HP3400CL_LIST_UNTAG,$vlanNumber[0]]);

    $switchSession->get($tag);
    $switchSession->get($untag);    

    my $depTag = $tag->val;
    my $depUntag = $untag->val;

    my $untagInfo = unpack("B*",$untag->val);
    my $tagInfo = unpack("B*",$tag->val);
    
    substr($untagInfo,($port-1),1)="1";
    substr($tagInfo,($port-1),1)="1";

    $untagInfo = pack("B*",$untagInfo);
    $tagInfo = pack("B*",$tagInfo);    

        my $newTag = new SNMP::Varbind([$HP3400CL_LIST_TAG,$vlanNumber[0],$tagInfo,"OCTETSTR"]);
    my $newUntag = new SNMP::Varbind([$HP3400CL_LIST_UNTAG,$vlanNumber[0],$untagInfo,"OCTETSTR"]);

    $switchSession->set($newUntag) or die "ERROR : Can't affect the port to the vlan";
    $switchSession->set($newTag) or die "ERROR : Can't affect the port to the vlan";
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

    $vlanNumber[0] = $self->getTagConfiguration($vlanNumber[0],$switchSession);
#Change the port information

    &const::verbose("Remove the port ",$port," from the vlan ",$vlanNumber[0]);    
    my $tag = new SNMP::Varbind([$HP3400CL_LIST_TAG,$vlanNumber[0]]);
    my $untag = new SNMP::Varbind([$HP3400CL_LIST_UNTAG,$vlanNumber[0]]);

    $switchSession->get($tag);
    $switchSession->get($untag);

    my $depTag = $tag->val;
    my $depUntag = $untag->val;

    my $untagInfo = unpack("B*",$untag->val);
    my $tagInfo = unpack("B*",$tag->val);
    
    substr($untagInfo,($port-1),1)="0";
    substr($tagInfo,($port-1),1)="0";

    $untagInfo = pack("B*",$untagInfo);
    $tagInfo = pack("B*",$tagInfo);    

        my $newTag = new SNMP::Varbind([$HP3400CL_LIST_TAG,$vlanNumber[0],$tagInfo,"OCTETSTR"]);
    my $newUntag = new SNMP::Varbind([$HP3400CL_LIST_UNTAG,$vlanNumber[0],$untagInfo,"OCTETSTR"]);

    $switchSession->set($newUntag) or die "ERROR : Can't remove the port from the vlan";
    $switchSession->set($newTag) or die "ERROR : Can't remove the port from the vlan";
}

1;

