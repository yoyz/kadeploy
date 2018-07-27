#!/usr/bin/perl -w

##########################################################################################
# Config Class
# author       : Nicolas Niclausse
# date         : 02/10/2008
##########################################################################################

package KaVLAN::Config;

@EXPORT = qw(parseConfigurationFile getPortNumber getPortName canModifyPort check_nodes_configuration get_nodes);

use warnings;
use strict;

use const;


##########################################################################################
# Parse the configuration file
# arg :
# ret : two hash tables references : 1-site, 2-routeur
#       an array reference containing hash tables : 3-switch
# rmq :
##########################################################################################
sub parseConfigurationFile{
    my $key;
    my $value;
    my %site;
    my @switch;
    my %routeur;
    my $typeLine="";

    my $nbSwitch = -1;

    open(CONF,"<",$const::CONFIGURATION_FILE) or die "ERROR : Can't open configuration file";

    while(<CONF>){
        #Verify if a line is not a comment (begin with #) and is a good line (contain a '=' or a '@')
        if( $_ !~ /#\w*/ and ($_ =~ m/=/ or $_ =~ m/@/) ){
#Verify if it is a global information line
            if($_ =~ /@\w*/){
#remove @
                $_ =~ s/@//;
#Inform that the following lines will be for the block name we have just read
                $typeLine=$_;

                if($typeLine =~m/Switch/){
                    $nbSwitch++;
                }
            } else {
#Remove spaces from the line
                $_ =~ s/^\s+//g;
                $_ =~ s/\s+$//g;
#Remove the \n and the \t
                $_ =~ s/\n//;
                $_ =~ s/\t//g;
#Split the informations around the '='
                ($key,$value) = split(/\s*=\s*/,$_);
#Do the association between the line and the upper block which is the information for
                if($typeLine =~ m/Switch/){
                    $switch[$nbSwitch]{$key}=$value;
                } elsif($typeLine =~ m/Routeur/) {
                    $routeur{$key} = $value;
                } elsif($typeLine =~ m/Site/) {
                    $site{$key} = $value;
                } else {
                    print "Configuration line not associated with an upper block (Switch, Routeur or Information):\n";
                }
            }
        }
    }
    close(CONF);

    if(not defined $routeur{"Name"} or not defined $routeur{"IP"} or not defined $routeur{"Type"}){
        die "ERROR : You have to enter value for the routeur in the configuration file : Name, IP, Type";
    }

    foreach my $i (0..$nbSwitch) {
        if(not defined $switch[$i]{"Name"} or not defined $switch[$i]{"IP"} or not defined $switch[$i]{"Type"} or not defined $switch[$i]{"Ports"}){
            die "ERROR : You have to enter value for the switch in the configuration file : Name, IP, Type";
        }
    }
    if(not defined $site{"VlanDefaultName"} or not defined $site{"Name"}){
        die "ERROR : You have to enter value for the site in the configuration file : VlanDefaultName, Name. You can also enter a value for the SNMPCommunity";
    }

#Return references of the three hash
    return \%site,\%routeur,\@switch;
}


##########################################################################################
# Get the port number via a name
# arg : String -> the name of the computer
#    String -> the site name
# ret : two variable : the number or -1 / the switch name
# rmq :
##########################################################################################
sub getPortNumber {
    my ($portName,$name)=@_;
    # Check arguement
    if(not defined $portName or not defined $name){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    my $trouve = 0;
    my $lineName;
    my $linePort;
    my $lineSwitch;
    my $line;

    if(open(CONF,"<".$const::PATH_TABLE_CORES."/".$name.".conf")){
        while( (defined ($line = <CONF>)) && ($trouve==0)){
            $line =~ s/\n//;
            ($lineName,$linePort,$lineSwitch) = split(/ /,$line);
            if(defined $lineName and $lineName eq $portName){
                $trouve = 1;
                &const::verbose("Port found in the configuration file");
            }

        }
    }
    close(CONF);
    return (-1,-1) unless ($trouve);
    return ($linePort,$lineSwitch);
}


##########################################################################################
# Get the port name via a number
# arg : Integer -> the port number
#     String -> the switch name
#     String -> the site name
# ret : the port name or ""
# rmq :
##########################################################################################
sub getPortName{
    my ($portNumber,$switchName,$siteName)=@_;
    my $trouve = 0;
    my $lineName;
    my $linePort;
    my $lineSwitch;
    my $line;
#Check arguement
    if(not defined $portNumber or not defined $switchName or not defined $siteName){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }


    if(open(CONF,"<",$const::PATH_TABLE_CORES.$siteName.".conf")){
        while( (defined ($line = <CONF>)) && ($trouve==0)){
            $line =~ s/\n//;
            ($lineName,$linePort,$lineSwitch) = split(/ /,$line);
            if(defined $lineSwitch and defined $linePort and $lineSwitch eq $switchName and $linePort eq $portNumber){
                $trouve = 1;
                &const::verbose("Port founded in the configuration file");
            }

        }
    }
    close(CONF);
    return "" unless ($trouve);
    return $lineName;
}

##########################################################################################
# Search the id of the switch in the switch table
# arg : String -> the name of the switch
# ret : the number or -1
# rmq : 
##########################################################################################
sub getSwitchIdByName(){
    my ($name,$switch)=@_;

#Check argument
    if(not defined $name){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }
    my $indice=-1;
    foreach my $i (0..$#{$switch}) {
        &const::verbose("name : ".$switch->[$i]{"Name"});
        if ($switch->[$i]{"Name"} eq  $name) {
            &const::verbose("found switch $name !");
            $indice = $i;
            last;
        }
    }
    return $indice;
}

##########################################################################################
# Know if we can modify this port
# arg : Integer -> the port
#       Integer -> the switch indice
#       Switch -> a switch tab of reference
# ret : 0 if it's ok OR -1
# rmq :
##########################################################################################
sub canModifyPort(){
    my ($port,$indice,$switch)=@_;
    # Check argument
    if(not defined $port or not defined $indice or not defined $switch){
        die "ERROR : Not enough argument for $const::FUNC_NAME";
    }

    my $portAllowed=$switch->[$indice]{"Ports"};
    return 0 if($portAllowed eq "all");

    my @portArray = split(/,/,$portAllowed);

    my $trouve=-1;
    foreach my $i (0..$#portArray){
        # If the string matches the format xx-yy that means that it is a range of port
        if ($portArray[$i] =~ /-/){
            my $min=$portArray[$i];
            $min =~ s/\-\d+//;
            my $max=$portArray[$i];
            $max =~ s/\d+\-//;
            if($port>=$min && $port<=$max){
                $trouve=0;
                last;
            }
        } else {
            if($port==$portArray[$i]){
                $trouve=0;
                last;
            }
        }

    }
    return $trouve;
}


# check if all nodes are configured
sub check_nodes_configuration {
    my $nodes   = shift;
    my $site    = shift;
    my $switch  = shift;
    if ($#{@{$nodes}} < 0) {
        die "node list empty, abort !";
    }
    foreach my $node (@{$nodes}) {
        my ($port,$switchName) = &getPortNumber($node,$site->{"Name"});
        if ($port eq -1) { die "ERROR : Node $node not present in the configuration"; };
        my $indiceSwitch = &getSwitchIdByName($switchName,$switch);
        if($indiceSwitch==-1) {die "ERROR : There is no switch under this name";};
        if(&KaVLAN::Config::canModifyPort($node,$indiceSwitch,$switch) != 0) {
            die "ERROR : you can't modify this port";
        }
    }
}

# return: list of nodes, or die if empty nodelist
sub get_nodes {
    my $nodefile = shift;  # filename
    my $nodes    = shift;  # arrayref

    my @nodelist;
    if ($nodefile) {
        # open file, uniquify nodes
        open(NODEFILE, "uniq $nodefile|") or die "can't open nodefile ($nodefile), abort ! $!";
        while (<NODEFILE>) {
            chomp;
            if (&check_node_name($_)) {
                push @nodelist, $_;
            } else {
                warn "skip node $_";
            }
        }
        close(NODEFILE);
    }

    if ($nodes) {
        &const::verbose("read node list (-m )");
        my %seen = ();
        foreach my $elem ( @$nodes )
            {
                next unless &check_node_name($elem);
                next if $seen{ $elem }++;
                push @nodelist, $elem;
            }
    }
    return @nodelist;
}

# check if node name is valid (with or without domain)
# => node-XX.site.grid5000.fr or node-xx-ethXX.site.grid5000.fr
sub check_node_name {
    my $nodename = shift;
    return $nodename =~ m/^\w+-\d+(-\w+)?(\.\w+\.\w+\.\w+)?$/;
}

1;
