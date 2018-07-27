#!/usr/bin/perl -w -I./src/ -I/usr/local/bin/kavlan

##########################################################################################
# KAVLAN 
# author       : Nicolas Niclausse
# date         : 02/10/2008
# note         :
##########################################################################################

package kavlan;

use strict;
use Getopt::Long;
use Data::Dumper;

use const;
# use vlan;
use KaVLAN::Config;
use KaVLAN::RightsMgt;

my $OAR_PROPERTIES=$ENV{'OAR_RESOURCE_PROPERTIES_FILE'};
my $OAR_NODEFILE=$ENV{'OAR_NODEFILE'};
my $OARSTAT="oarstat"; # oarstat command
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
        "r|get-network-range",
        "g|get-network-gateway",
        "d|disable-dhcp",
        "i|vlan-id=s",
        "l|get-nodelist",
        "V|get-vlan-id",
        "j|job-id=s",
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


#--------------------------
# MANAGE DATABASE
#--------------------------
my $dbuser   = $site->{DbUser};
my $dbpasswd = $site->{DbPasswd};
my $dbhost   = $site->{DbHost};
my $dbname   = $site->{DbName};

&mydie("Database not configured correctly, check your configuration file") unless ($dbuser and $dbpasswd and $dbhost and $dbname);
my $dbh = &KaVLAN::RightsMgt::connect($dbhost,$dbname,$dbuser,$dbpasswd);

#--------------------------
# MANAGE ARGUMENTS
#--------------------------

my $USER;
if ($ENV{KAUSER}) {
    $USER=$ENV{KAUSER};
} else {
    $USER=$ENV{USER};
}

if ($options{"r"}) {   # get-network-range
    my $VLAN  = &get_vlan();
    if ($site->{$VLAN_RANGE_NAME.$VLAN}) {
        print $site->{$VLAN_RANGE_NAME.$VLAN}."\n";
    } else {
        &mydie("ERROR : Unknown network range for vlan $VLAN\nERROR : please check your configuration file");
    }
} elsif ($options{"g"}) { # get-network-gateway
    my $VLAN  = &get_vlan();
    if ($router->{$VLAN_GATEWAY_NAME.$VLAN}) {
        print $router->{$VLAN_GATEWAY_NAME.$VLAN}."\n";
    } else {
        &mydie("ERROR : Unknown network gateway for vlan $VLAN\nERROR : please check your configuration file");
    }
} elsif ($options{"d"} ){ # disable dhcp server for the given vlan
    # TODO
    my $VLAN  = &get_vlan();
    die "disable dhcp server: not implemented";
} elsif ($options{"s"} ){ # set vlan for given nodes
    my @nodes;
    my $VLAN  = &get_vlan();
    if  ($options{'i'}) { # vlan id is set
        @nodes = &KaVLAN::Config::get_nodes($options{"f"}, $options{"m"});
    } elsif ($options{'j'}) {
        &mydie("Can't specify nodes with -f or -m when jobid is given, abort!") if ($options{"f"} or $options{"m"});
        # use OAR job id to get the nodes
        @nodes = &get_nodes_from_oarjob($options{"j"});
    } elsif ($OAR_NODEFILE) { # no job or vlan id specified, look for OAR env. variables
        # use OAR nodefile
        print "Take node list from OAR nodefile: $OAR_NODEFILE\n" unless $options{"q"};
        @nodes = &KaVLAN::Config::get_nodes($OAR_NODEFILE, "");
    } else {
        &mydie("No nodes specified: use -m, -f or -j");
    };
    if (defined $VLAN) {
        &KaVLAN::Config::check_nodes_configuration(\@nodes,$site,$switch);
        unless (&KaVLAN::RightsMgt::check_rights_nodelist($dbh, $USER,\@nodes,$VLAN)) {
            &mydie ("User does not have appropriate rights on VLAN, abort") ;
        }
        &const::verbose("User $USER has enough rights to change the VLAN of all nodes, continue");
        &set_vlan(\@nodes,$VLAN);
    } else {
        &mydie("No VLAN found, abort!");
    }
    print "all nodes are configured in the vlan $VLAN\n" unless $options{"q"};
} elsif ($options{"V"} ){ # get vlan id of job
    print &get_vlan_from_oar($options{'j'});
    print "\n";
} elsif ($options{"l"} ){ # get node list of job
    my @nodes;
    my @nodes_default; # node name in default vlan
    my $JOBID=$options{'j'};
    my $VLAN = &get_vlan_from_oar($JOBID);
    if ($JOBID) {
        @nodes_default = &get_nodes_from_oarjob($JOBID);
    } elsif ($OAR_NODEFILE) {
        @nodes_default = &KaVLAN::Config::get_nodes($OAR_NODEFILE, "");
    } else {
        die "get node list: no job specified, use -j";
    }
    die "no VLAN found" unless $VLAN;
    die "no nodes found" if ($#nodes_default < 0);
    # rewrite nodename: add -vlanX where X is the vlan ID
    @nodes = map { s/^(\w+-\d+)\./$1\-vlan-$VLAN\./; $_ } @nodes_default;
    foreach (@nodes) {print "$_\n";};
} else {
    &mydie("no action specified, abort");
}


&KaVLAN::RightsMgt::disconnect($dbh);


## -----------------------------------------------------------------------
## End of main script here -----------------------------------------------
## -----------------------------------------------------------------------

sub set_vlan {
    my $nodes = shift;
    my $VLAN = shift;
    my $backend_cmd =  $site->{"BackendCmd"};
    &KaVLAN::RightsMgt::disconnect($dbh);
    &mydie("Backend command not configured ! abort") unless ($backend_cmd);
    # we have already checked before (in check_nodes_configuration
    # )that the indice is defined and we have rights to modify the
    # port, therefore, we can skip checks here
    my $nodelist = join(" -m ",@{$nodes});
    exec("$backend_cmd -s -i $VLAN -m $nodelist" );
}

sub get_vlan {
    my $VLAN;
    if  (defined $options{'i'}) { # vlan id is set
        $VLAN  = &check_vlan($options{"i"});
    } elsif ($options{'j'}) {
        # use OAR job id to get the nodes
        $VLAN  = &get_vlan_from_oar($options{"j"});
    } elsif ($OAR_NODEFILE) { # no job or vlan id specified, look for OAR env. variables
        # use OAR nodefile
        $VLAN  = &get_vlan_from_oar();
    } else {
        return undef;
    }
}

# returns vlan id of job; if jobid is undef, check OAR env. variables.
sub get_vlan_from_oar {
    my $jobid = shift;
    if ($jobid) {
        &const::verbose("try to get VLAN id from job $jobid");
        return &get_vlan_property("",$jobid);
    } elsif ($OAR_PROPERTIES) {
        &const::verbose("try to get VLAN id from OAR_PROPERTIES file");
        return &get_vlan_property($OAR_PROPERTIES,"");
    } else {
        &mydie("no job specified, use -j");
    }
}


sub get_nodes_from_oarjob {
    my $JOBID = shift;

    my @nodes_default;

    if ($JOBID =~ m/^\d+$/) {
        &const::verbose("get nodes from oarstat: $OARSTAT -f -j $JOBID  ");
        open(OARSTAT, "$OARSTAT -f -j $JOBID |") or die "Error while running oarstat: $!";
        while (<OARSTAT>) {
            if  (/assigned_hostnames = (.*)$/) {
                @nodes_default= split(/\+/,$1);
            }
        };
        close(OARSTAT);
        return @nodes_default;
    } else {
        &mydie("Wrong jobid given ($JOBID), abort!");
    }
}


# check vlan_id parameter when given by the user
sub check_vlan {
    my $vlan_id = shift;

    &mydie("no vlan_id") unless defined $vlan_id;
    if ($vlan_id =~ m/default/i) {
        return $const::DEFAULT_NAME;
    } elsif ($vlan_id =~ m/^\d+$/)  {
        return $vlan_id if ($vlan_id >= 1 and $vlan_id <= $const::VLAN_MAX_ID);
    };
    &mydie("abort: bad VLAN id ($vlan_id)");
}

sub get_vlan_property {
    my $filename = shift;
    my $jobid    = shift;
    if ( $jobid ) {
        open(PROP, "$OARSTAT -p -j $jobid |") or die "can't start oarstat, abort ! $!";
    } elsif (-f $filename ) {
        open(PROP, "< $filename") or die "can't open $filename, abort ! $!";
    }
    while (<PROP>) {
        chomp;
        foreach my $prop (split /\s+\,\s+/) {
            if ($prop =~ m/$VLAN_PROPERTY_NAME\s+\=\s+\'(\w+)\'/) {
                &const::verbose("found vlan = $1");
                close(PROP);
                return $1;
            }
        }
    }
    close(PROP);
    &mydie("Can't find VLAN from OAR properties of job $jobid, abort");
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
USAGE : kavlan [options]
       -r|--get-network-range
       -g|--get-network-gateway
       -l|--get-nodelist
          --get-vlan-id              print VLAN ID of job (needs -j JOBID)
       -d|--disable-dhcp
       -i|--vlan_id <VLANID>
       -s                            set vlan for given node(s)
       -f|--filenode <NODEFILE>
       -j|--oar-jobid=XXXX
       -m|--machine <nodename>
       -q|--quiet                    quiet mode
       -h|--help                     print this help
       -v|--verbose                  verbose mode\n";
    exit $status;
}
