#!/usr/bin/perl -w

##########################################################################################
# VLAN modification function file 
# author       : Jérémie TISSERAND
# date         : 29/08/2006
# note         : 
##########################################################################################
# version      :
# modified     :
# author       : Nicolas Niclausse
# modification : 21/11/2008
##########################################################################################


package vlan;

use strict;
use SNMP;
use const;

##########################################################################################
# Add a vlan
# arg : String -> the name of the vlan
#       Session -> a router session
#    Config -> a router configuration
# ret : 
# rmq :
##########################################################################################
sub addVlanOnRouter(){
    my ($vlanName,$routerSession,$routerConfig)=@_;
    # Check arguments
    if(not defined $vlanName or not defined $routerSession or not defined $routerConfig){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    if($vlanName eq $const::DEFAULT_NAME){
        die "ERROR : this name can not be used";
    }
    &const::verbose();

    &addVlanOnSwitch($vlanName,$routerSession,$routerConfig);
}

##########################################################################################
# Add a vlan
# arg : String -> the name of the vlan
#       Session -> a switch session
#       Config -> a switch configuraiton
# ret :
# rmq :
##########################################################################################
sub addVlanOnSwitch(){
    my ($vlanName,$switchSession,$switchConfig)=@_;
    # Check argument
    if(not defined $vlanName or not defined $switchSession or not defined $switchConfig){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    &const::verbose();
    if($vlanName eq $const::DEFAULT_NAME){
        die "ERROR : this name can not be used";
    }

    # Retrieve the vlan number of $vlanName
    &const::verbose("Verifying that there is enough vlan available");
    my @vlanNumber= $switchConfig->getVlanNumber($const::DEFAULT_NAME_KAVLAN,$switchSession);
    if($#vlanNumber==-1){
        die "ERROR : There is no vlan available for modification";
    }
    # Change the name of the vlan on the switch
    &const::verbose("Modifying vlan name on the switch");
    $switchConfig->modifyVlanName($const::DEFAULT_NAME_KAVLAN,$const::MODIFY_NAME_KAVLAN.$vlanName,$switchSession);
}

##########################################################################################
# Delete a vlan
# arg : String -> the name of the vlan
#       Session -> a switch session
#    Config -> a router configuration
# ret : 
# rmq :
##########################################################################################
sub delVlanOnRouter(){
    my ($vlanName,$routerSession,$routerConfig)=@_;
    # Check argument
    if(not defined $vlanName or not defined $routerSession or not defined $routerConfig ){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    &const::verbose();

    if($vlanName eq $const::DEFAULT_NAME){
        die "ERROR : this name can not be used";
    }
    # Retrieve the vlan number of $vlanName
    &const::verbose("Verifying if this vlan is set");
    my @vlanNumber= $routerConfig->getVlanNumber($const::MODIFY_NAME_KAVLAN.$vlanName,$routerSession);
    if($#vlanNumber==-1){
        die "ERROR : There is no vlan under this name";
    }

    # Change the name of the vlan
    &const::verbose("Modifying vlan name on the router");
    $routerConfig->modifyVlanName($const::MODIFY_NAME_KAVLAN.$vlanName,$const::DEFAULT_NAME_KAVLAN.$vlanNumber[0],$routerSession);
}

##########################################################################################
# Delete a vlan
# arg : String -> the name of the vlan
#       Session -> a switch session
#    Config -> a switch configuration
#    Var -> specify the cleaner mode to delete vlan
# ret : 
# rmq :
##########################################################################################
sub delVlanOnSwitch(){
    my ($vlanName,$switchSession,$switchConfig,$otherMode)=@_;
    # Check argument
    if(not defined $vlanName or not defined $switchSession or not defined $switchConfig){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    &const::verbose();

    if($vlanName eq $const::DEFAULT_NAME){
        die "ERROR : this name can not be used";
    }
    # Retrieve the vlan number of $vlanName
    &const::verbose("Verifying if this vlan is set");
    my @vlanNumber= $switchConfig->getVlanNumber($const::MODIFY_NAME_KAVLAN.$vlanName,$switchSession);
    if($#vlanNumber==-1){
        die "ERROR : There is no vlan under this name";
    }

    # Remove all the ports affected to this vlan
    &const::verbose("Removing ports from the vlan");
    my $port = $switchConfig->getPortsAffectedToVlan($vlanName,$switchSession);
    my %res = %{$port};
    if(defined  @{$res{"TAGGED"}}){
        foreach my $i (0..$#{ @{ $res{"TAGGED"} } }){
            &removePort($vlanName,${@{$res{"TAGGED"}}}[$i],$switchSession,$switchConfig,$otherMode);
        }
    }
    if(defined  @{$res{"UNTAGGED"}}){
        foreach my $i (0..$#{ @{ $res{"UNTAGGED"} } }){
            &removePort($vlanName,${@{$res{"UNTAGGED"}}}[$i],$switchSession,$switchConfig,$otherMode);
        }
    }

    # Change the name of the vlan
    &const::verbose("Modifying vlan name on the switch");
    $switchConfig->modifyVlanName($const::MODIFY_NAME_KAVLAN.$vlanName,$const::DEFAULT_NAME_KAVLAN.$vlanNumber[0],$switchSession);
}


##########################################################################################
# Add a machine in the tagged mode for a vlan 
# arg : String -> the vlan name
#       Integer -> the port
#    Session -> a switch session
#    Config -> a switch configuration
#    Var -> specify the cleaner mode to delete the port 
# ret : 
# rmq :
##########################################################################################
sub addTaggedPort(){
    my ($vlanName,$port,$switchSession,$switchConfig,$otherMode)=@_;

    # Check argument
    if(not defined $vlanName or not defined $port or not defined $switchSession or not defined $switchConfig){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    &const::verbose();
#    &removePort($vlanName,$port,$switchSession,$switchConfig,$otherMode);

    $switchConfig->setTag($vlanName,$port,$switchSession);
}


##########################################################################################
# Add a machine in the untagged mode for a vlan 
# arg : String -> the vlan name
#       Integer -> the port
#    Session -> a switch session
#    Config -> a switch configuration
#    Var -> specify the cleaner mode to delete the port 
# ret : 
# rmq :
##########################################################################################
sub addUntaggedPort(){
    my ($vlanName,$port,$switchSession,$switchConfig,$otherMode)=@_;

    # Check argument
    if(not defined $vlanName or not defined $port or not defined $switchSession or not defined $switchConfig){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    &const::verbose();

    my @res = $switchConfig->getPortInformation($port,$switchSession);
    # If we are trying to put the port in the vlan but he is already here
    return if(defined $res[0] and $res[0] eq $vlanName);

    if(defined $otherMode){
        &const::verbose("clear mode activated");
        # If we are with hp switch, we can't affect as untag before removing the older untag vlan and we can't let a port unaffect, that's why we are using the tag mode
        if(defined $res[0]){
            $switchConfig->setTag($res[0],$port,$switchSession);
        }
        $switchConfig->setTag($vlanName,$port,$switchSession);
        $switchConfig->setUntag($vlanName,$port,$switchSession);
        if(defined $res[0]){
            $switchConfig->setRemove($res[0],$port,$switchSession);
        }
    }
    else{
        # If the port is tagged, we remove it
        my $trouve=0;
        foreach my $i (1..$#res) {
            if(defined $res[$i] and $res[$i] eq $vlanName){
                $trouve=1;
                last;
            }
        }
        if($trouve==1){ $switchConfig->setRemove($vlanName,$port,$switchSession);}
        $switchConfig->setUntag($vlanName,$port,$switchSession);
    }
}

##########################################################################################
# Remove a port from a vlan
# arg : String -> the vlan name
#       Integer -> the port
#    Session -> a switch session
#    Config -> a switch configuration
#    Var -> specify the cleaner mode to delete the port 
# ret : 
# rmq :
##########################################################################################
sub removePort(){
    my ($vlanName,$port,$switchSession,$switchConfig,$otherMode)=@_;
    &const::verbose();
    # Check argument
    if(not defined $vlanName or not defined $port or not defined $switchSession or not defined $switchConfig){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    # Retrieve port informations
    my $res=$switchConfig->getPortsAffectedToVlan($vlanName,$switchSession);
    my %infoPort = %{$res};

    # If we are in the untag mode, we remove the port from the vlan
    # and affect him to the default vlan
    if(defined  @{$infoPort{"UNTAGGED"}}){
        foreach my $i (0..$#{ @{ $infoPort{"UNTAGGED"} } }){
            if(${@{$infoPort{"UNTAGGED"}}}[$i] == $port){
                if(defined $otherMode){
                    # We are doing this because hp switch doesn't
                    # allow to remove a port from a vlan before
                    # affecting him to another
                    &const::verbose("clear mode activated");
                                        $switchConfig->setTag($vlanName,$port,$switchSession);
                    $switchConfig->setTag($const::DEFAULT_NAME,$port,$switchSession);
                                        $switchConfig->setUntag($const::DEFAULT_NAME,$port,$switchSession);
                    $switchConfig->setRemove($vlanName,$port,$switchSession);
                                }
                                else{
                    $switchConfig->setRemove($vlanName,$port,$switchSession);
                                        $switchConfig->setUntag($const::DEFAULT_NAME,$port,$switchSession);
                                }

            }
        }
    }
#If we are in tag mode, we remove the port
    if(defined @{$infoPort{"TAGGED"}}){
        foreach my $i (0..$#{ @{ $infoPort{"TAGGED"} } }){
            if(${@{$infoPort{"TAGGED"}}}[$i] == $port){
                my @vlanOfPort = $switchConfig->getPortInformation($port,$switchSession);
                # We are putting the port in the default vlan in untag
                # mode before removing it if it was the last vlan in
                # which it belong
                if($#vlanOfPort == 1 and not defined $vlanOfPort[0]){
                    &const::verbose("We are putting the $port in the default vlan");
                    if(defined $otherMode){
                        $switchConfig->setTag($const::DEFAULT_NAME,$port,$switchSession);
                        $switchConfig->setUntag($const::DEFAULT_NAME,$port,$switchSession);
                    } else{
                        $switchConfig->setUntag($const::DEFAULT_NAME,$port,$switchSession);
                    }
                }
                $switchConfig->setRemove($vlanName,$port,$switchSession);
            }
        }
    }
}

##########################################################################################
# Set the initial configuration for a port
# arg : Integer -> the port
#       Session -> a switch session
#       Config -> a switch configuration
# ret :
# rmq :
##########################################################################################
sub portInitialConfiguration(){
    &const::verbose();

    # Check argument
    my ($port,$switchSession,$switchConfig,$otherMode)=@_;
    if(not defined $port or not defined $switchSession or not defined $switchConfig){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

    #Retrieve the vlan number of default VLAN
    &const::verbose("Verifying that the vlan is available");
    my @vlanNumberDefault= $switchConfig->getVlanNumber($const::VLAN_DEFAULT_NAME,$switchSession);
    if($#vlanNumberDefault==-1){
        die "ERROR : Vlan default name is not correctly set on the configuration file";
    }

    # Change the port information

    &const::verbose("Put the port ",$port," to the default vlan ");    
    &addUntaggedPort($const::DEFAULT_NAME,$port,$switchSession,$switchConfig,$otherMode);

    # Remove the port of all vlan for the tag mode
    &const::verbose("Retreiving all the vlan created");
    my @vlanNumber=$switchConfig->getVlanNumber($const::MODIFY_NAME_KAVLAN,$switchSession);
    my $i;
    for($i=0;$i<($#vlanNumber+1);$i++){
        my $vlanName = $switchConfig->getVlanName($vlanNumber[$i],$switchSession);
        $vlanName =~ s/$const::MODIFY_NAME_KAVLAN//;
        &removePort($vlanName,$port,$switchSession,$switchConfig,$otherMode);
    }
}

1;

