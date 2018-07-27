#!/usr/bin/perl -w

##########################################################################################
# Switch Class
# author       : Nicolas Niclausse
# date         : 24/07/2008
##########################################################################################

package KaVLAN::Switch;
# use vars qw(@ISA @EXPORT);
# use Exporter;
# @ISA = qw(Exporter);

@EXPORT = qw(new getVlanNumber getVlanName modifyVlanName getIPConfiguration getTagConfiguration listVlanOnRouteur listVlanOnSwitch getPortInformation);

use warnings;
use strict;
use SNMP;
use List::Util qw[min max];

use const;


##########################################################################################
# Constructor of the object 
# arg : name
# ret : 
# rmq :
##########################################################################################
sub new {
    my ($class,$name,$vlan_name_oid,$ip,$mask,$tag)= @_;
    my $self = {};
    $self->{name} = $name;
    $self->{VLAN_NAME} = $vlan_name_oid;
    $self->{IP} = $ip;
    $self->{MASK} = $mask;
    $self->{TAG} = $tag;
    bless ($self,$class);
    return $self;
}

##########################################################################################
# Get the vlan number
# arg : String -> the name of the vlan
#       Session -> the session on which we want to get the number of the vlan
# ret : Integer[] -> the numbers of vlan matches the string passed in argument 
# rmq :
##########################################################################################
sub getVlanNumber {
    my ($self,$vlanName,$session)=@_;
    # Check arguments
    if(not defined $vlanName or not defined $session){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    # default vlan, get the real name of the vlan
    $vlanName = $const::VLAN_DEFAULT_NAME if $vlanName eq $const::DEFAULT_NAME;

    &const::verbose("Get vlan number of ",$vlanName);
    my @res;
    my @resp;

    if ( defined $const::CACHE{\$session}{'VLANS'}) {
        &const::verbose("reuse VLAN list of switch from CACHE");
        @resp = @{$const::CACHE{\$session}{'VLANS'}} ;
    } else {
        #Retrieve the number and the name of each vlan
        my $var = new SNMP::VarList([$self->{VLAN_NAME}]);
        @resp = $session->bulkwalk(0,$const::IEEE_MAX_VLAN,$var);
        $const::CACHE{\$session}{'VLANS'} = \@resp;
    }

    # Loop until we have a name which correspond to $vlanName
    my $max = min($const::IEEE_MAX_VLAN-1, $#{ @{ $resp[0] } });
    foreach my $i (0..$max){
#        &const::verbose("Seeing ", ${ @{ $resp[0] } }[$i]->val);
        if( ${ @{ $resp[0] } }[$i]->val =~ /$vlanName/){
            &const::verbose("Adding vlan ", ${ @{ $resp[0] } }[$i]->val ," because he matches the given name");
#Getting the end of the oid as vlanNumber
                        my $number = ${@{$resp[0]}}[$i]->iid;
                        if(not defined $number or $number eq ""){
                                $number = ${@{${@{$resp[0]}}[$i]}}[0];
                        }

            $number =~ s/\w+\.//g;
            $number =~ s/\D+//g;

            push @res, $number;
        }
    }

#Return the value which correspond to the vlan name
    &const::verbose("Vlan's availables ",@res);

    return @res;
}

##########################################################################################
# Get the vlan name 
# arg : Integer -> the vlan number
#       Session -> the session on which we want to get the number of the vlan
# ret : String -> the name of the vlan
# rmq :
##########################################################################################
sub getVlanName(){
    my ($self,$vlanNumber,$session)=@_;
    if(not defined $vlanNumber or not defined $session){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
#Retrieve the number and the name of each vlan
    my $var = new SNMP::Varbind([$self->{VLAN_NAME},$vlanNumber]);
    my $resp = $session->get($var);

    return $resp;

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
    my ($self,$oldVlanName,$newVlanName,$session)=@_;
    if(not defined $oldVlanName or not defined $newVlanName or not defined $session){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

#Retreive the vlan number
    my @vlanNumber = $self->getVlanNumber($oldVlanName,$session);
    if($#vlanNumber==-1){
        die "ERROR : Can't modify the vlan name because there is vlan available";
    }

#Create the snmp variable to apply changes in the vlan $vlanNumber
    my $var=new SNMP::Varbind([$self->{VLAN_NAME},$vlanNumber[0],$newVlanName,"OCTETSTR"]);

#Send the snmp information
    &const::verbose("Applying modification");
    $session->set($var) or die "ERROR : Can't modify vlan (there is probably another vlan with the same name)\n";

}
##########################################################################################
# Get the IP Configuration of a vlan 
# arg : Integer -> the number of the vlan on the routeur session 
#       Session -> a session on which we can get the IP address
# ret : String -> the IP configuration 'IP/MASK'
# rmq :
##########################################################################################
sub getIPConfiguration(){
    my $self = shift;
#Check arguement
    my ($vlanNumber,$session)=@_;
    if(not defined $vlanNumber or not defined $session){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

#Retreive the informations about ip configuration
    &const::verbose("Retreive ip configuration of the vlan");
    my $ip=new SNMP::Varbind([$self->{IP},$vlanNumber,"","NETADDR"]);
    my $mask=new SNMP::Varbind([$self->{MASK},$vlanNumber,"","NETADDR"]);
    $session->get($ip) or die "ERROR : Can't retreive information about ip adress of the vlan";
    $session->get($mask) or die "ERROR : Can't retreive information about mask format of the vlan ";

    return $ip->val."/".$mask->val;

}


##########################################################################################
# Get the tag of a vlan
# arg : Integer -> the number of the vlan on the routeur session 
#       Session -> a session on which we can get the tag information
# ret : String -> the tag
# rmq :
##########################################################################################
sub getTagConfiguration(){
    my $self = shift;
#Check arguement
    my ($vlanNumber,$session)=@_;
    if(not defined $vlanNumber or not defined $session){
        die "ERROR : Not enough argument for $const::FUNC_NAME=";
    }

#Retreive the informations about ip configuration    
    &const::verbose("Retreive tag configuration of the vlan for ".$vlanNumber);
    my $res = 0;

#Retrieve the number and the name of each vlan
    my $var = new SNMP::VarList([$self->{TAG}]);
    my @resp = $session->bulkwalk(0,$const::IEEE_MAX_VLAN,$var);

#Loop until we have a name which correspond to $vlanName
    my $i;
    for($i=0; ( $i<$const::IEEE_MAX_VLAN ) && ( $i<($#{ @{ $resp[0] } } +1) ) && ($res == 0) ;$i++){
        my $tag;
        my $number;
#If the it is the normal mode, the tag is the value and number is in the oid
        $tag = ${ @{ $resp[0] } }[$i]->val;
        $number = ${@{${@{$resp[0]}}[$i]}}[0];
        $number =~ s/\w+\.//g;
        $number =~ s/\D+//g;

        if($number == $vlanNumber){
            $res = $tag;
        }

    }
    return $res;
}


##########################################################################################
# List vlan that matches a name 
# arg : String -> the vlan name
#       Session -> the routeur session
# ret : 
# rmq :
##########################################################################################
sub listVlanOnRouteur(){
    my $self = shift;
    my ($vlanName,$routeurSession)=@_;
    # Check arguement
    if(not defined $vlanName or not defined $routeurSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

#Retrieve the number and the name of each vlan
    my $var = new SNMP::VarList([$self->{VLAN_NAME}]);
    my @resp = $routeurSession->bulkwalk(0,$const::IEEE_MAX_VLAN,$var);

#Loop until we have a name which correspond to $vlanName
    my $max = min($const::IEEE_MAX_VLAN-1, $#{ @{ $resp[0] } });
    foreach my $i (0..$max){
        if(${ @{ $resp[0] } }[$i]->val =~ /$const::MODIFY_NAME_KAVLAN$vlanName/){
            &const::verbose("Vlan founded:",${ @{ $resp[0] } }[$i]->val);

            print "-------------------------------\n";
            my $val = ${ @{ $resp[0] } }[$i]->val;
            $val =~ s/$const::MODIFY_NAME_KAVLAN//;
            print "VLAN NAME : $val\n";
#Get the vlan number in order to retreive informations
            my @vlanNumber = $self->getVlanNumber($val,$routeurSession);
            my $ip =  $self->getIPConfiguration($vlanNumber[0],$routeurSession);
            print "ATTRIBUTED IP : $ip\n";
            my $tag = $self->getTagConfiguration($vlanNumber[0],$routeurSession);
            print "VLAN TAG : $tag\n";

        }
        if($vlanName =~ /$const::DEFAULT_NAME/ && ${ @{ $resp[0] } }[$i]->val =~ /$const::VLAN_DEFAULT_NAME/){
            print "-------------------------------\n";
            my $val = $const::DEFAULT_NAME;
            print "VLAN NAME : $val\n";
            $val =  $const::VLAN_DEFAULT_NAME;
            my @vlanNumber = $self->getVlanNumber($val,$routeurSession);
            my $ip =  $self->getIPConfiguration($vlanNumber[0],$routeurSession);
            print "ATTRIBUTED IP : $ip\n";
            my $tag = $self->getTagConfiguration($vlanNumber[0],$routeurSession);
            print "VLAN TAG : $tag\n";
        }
    }
}


##########################################################################################
# List vlan that matches a name 
# arg : String -> the vlan name
#    Session -> the switch session
# ret : 
# rmq :
##########################################################################################
sub listVlanOnSwitch(){
    #Check arguement
    my $self = shift;
    my ($vlanName,$switchSession,$switchConfig)=@_;
    if(not defined $vlanName or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

#Retrieve the number and the name of each vlan
    my $var = new SNMP::VarList([$self->{VLAN_NAME}]);
    my @resp = $switchSession->bulkwalk(0,$const::IEEE_MAX_VLAN,$var);

    use Data::Dumper;
    &const::verbose("Dumper(@resp)");
#Loop until we have a name which correspond to $vlanName
    my $max = min($const::IEEE_MAX_VLAN-1, $#{ @{ $resp[0] } });
    print "vlanName is $vlanName (default is $const::VLAN_DEFAULT_NAME), max is $max\n" if ($const::VERBOSE);
    foreach my $i (0..$max){
        if(${ @{ $resp[0] } }[$i]->val =~ /$const::MODIFY_NAME_KAVLAN$vlanName/){
            &const::verbose("Vlan founded:",${ @{ $resp[0] } }[$i]->val);

            print "-------------------------------\n";
            my $val = ${ @{ $resp[0] } }[$i]->val;
            $val =~ s/$const::MODIFY_NAME_KAVLAN//;
            print "VLAN NAME : $val\n";

        }
#The case of the default vlan
        if($vlanName =~ /$const::DEFAULT_NAME/ && ${ @{ $resp[0] } }[$i]->val =~ /$const::VLAN_DEFAULT_NAME/){
            print "-------------------------------\n";
            my $val = $const::DEFAULT_NAME;
            print "VLAN NAME : $val\n";
        }
    }
}


##########################################################################################
# Get port information 
# arg : Integer -> the port number
#    Session -> the switch session
# ret : a tab containing on the first element the untag vlan and on the others the tagged vlan
#       on which the port is affected
# rmq :
##########################################################################################
sub getPortInformation(){
    my $self = shift;
    my ($port,$switchSession)=@_;
    if(not defined $port or not defined $switchSession){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

    my @ret;
    my $val;

    my @resp;


    if ( defined $const::CACHE{\$switchSession}{'VLANS'}) {
        &const::verbose("reuse VLAN list of switch from CACHE");
        @resp = @{$const::CACHE{\$switchSession}{'VLANS'}} ;
    } else {
        #Retrieve the number and the name of each vlan
        my $var = new SNMP::VarList([$self->{VLAN_NAME}]);
        @resp = $switchSession->bulkwalk(0,$const::IEEE_MAX_VLAN,$var);
        $const::CACHE{\$switchSession}{'VLANS'} = \@resp;
    }

    my $indiceTagPort = 1;
#Loop until we have a name which correspond to $vlanName
    my $max = min($const::IEEE_MAX_VLAN-1, $#{ @{ $resp[0] } });
    foreach my $i (0..$max){
        my $name = ${ @{ $resp[0] } }[$i]->val;

        if($name =~ /$const::MODIFY_NAME_KAVLAN/ or $name =~ /$const::VLAN_DEFAULT_NAME/){
#Getting the right name of the vlan (without the prefix MODIFY_NAME_VLAN)
            if($name =~ /$const::MODIFY_NAME_KAVLAN/){
                &const::verbose("Vlan found:",$name);
                $val = $name;
                $val =~ s/$const::MODIFY_NAME_KAVLAN//;

            }
            if($name =~ /$const::VLAN_DEFAULT_NAME/){
                &const::verbose("Vlan found:",$name);
                $val = $const::DEFAULT_NAME;
            }
            my %res;
            if ( defined $const::CACHE{\$switchSession}{'port'}{$val}) {
                &const::verbose("reuse VLAN list of port from CACHE");
                %res = %{$const::CACHE{\$switchSession}{'port'}{$val}} ;
            } else {
                &const::verbose("will run getPortsAffectedToVlan with ",$val);
                my $tmp = $self->getPortsAffectedToVlan($val,$switchSession);
                %res = %{$tmp};
                $const::CACHE{\$switchSession}{'port'}{$val} = \%res;
            }

#Add informations about this vlan if we find the port in the vlan
            if(defined  @{$res{"TAGGED"}}){
                foreach my $j (0..$#{ @{ $res{"TAGGED"} } }){
                    if( ${@{$res{"TAGGED"}}}[$j] eq $port){
                        $ret[$indiceTagPort] = $val;
                        $indiceTagPort++;
                    }
                }
            }
            if(defined  @{$res{"UNTAGGED"}}){
                foreach my $j (0..$#{ @{ $res{"UNTAGGED"} } }){
                    if(${@{$res{"UNTAGGED"}}}[$j] eq $port){
                        $ret[0] = $val;
                    }
                }
            }

        }

    }
    return @ret;
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
    my $class = shift;
    die "setTag not implemented for class $class\n";
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
    my $class = shift;
    die "setUntag not implemented for class $class\n";
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
    my $class = shift;
    die "setRemove not implemented for class $class\n";
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
    my $class = shift;
    die "getPortsAffectedToVlan not implemented for class $class\n";
}

1;
