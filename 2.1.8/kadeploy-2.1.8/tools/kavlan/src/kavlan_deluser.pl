#!/usr/bin/perl

use Getopt::Long;
use KaVLAN::RightsMgt;
use KaVLAN::Config;

use strict;

my $conf_root_dir;

&usage() if (!@ARGV) ;

## declares the options
my @user_list = ();
my @host_list = ();
my @vlan_list = ();
my $help;

## gets the options
GetOptions(
           'l|login=s'         => \@user_list,
           'm|machine=s'       => \@host_list,
           'v|vlan=s'          => \@vlan_list,
           'h|help'            => \$help,
           'C|configuration=s' => \$conf_root_dir
          );
&usage if $help;

my ($site,$routeur,$switch) = KaVLAN::Config::parseConfigurationFile();

## checks if needed options are defined
if (!@user_list){
    print "WARNING : no user specified, rights revoked to all users\n";
    @user_list = ("*");
}
if (!@host_list){
    print "WARNING : no host specified, rights revoked for all nodes\n";
    @host_list = ("*");
}

if (!@vlan_list){
    print "WARNING : no vlan specified, rights revoked for all vlans\n";
    @vlan_list = ("*");
}


## time to revoke rights
my $dbuser   = $site->{DbUser};
my $dbpasswd = $site->{DbPasswd};
my $dbhost   = $site->{DbHost};
my $dbname   = $site->{DbName};

my $base = &KaVLAN::RightsMgt::connect($dbhost,$dbname,$dbuser,$dbpasswd);

foreach my $user (@user_list){
    foreach my $host (@host_list){
        foreach my $vlan (@vlan_list){
            KaVLAN::RightsMgt::del_user($base,$user,$host,$vlan);
        }
    }
}

&KaVLAN::RightsMgt::disconnect($base);

print "Done.\n";

sub usage {
    print "Usage : kavlan_deluser [-l|--login login]
    [-m|--machine hostname]
    [-v|--vlan vlan_id]\n";
  exit 0;
}
