package libkadeploy2::kaconsole;

use File::Copy;
use Getopt::Long;
use libkadeploy2::deployconf;
use libkadeploy2::deploy_iolib;
use libkadeploy2::rights_iolib;
use libkadeploy2::command;
use libkadeploy2::message;
use libkadeploy2::karights;
use libkadeploy2::sudo;
use libkadeploy2::nodelist;
use strict;
use warnings;

sub check_options();
sub check_rights();

my $sudo_user;
my $exitcode;
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }

my $message=libkadeploy2::message::new();



my $node;
my $nodelist;
my @node_list;
my $command;
my $cmd;
my $help;
my $kadeploydir=$conf->get("kadeploy2_directory");

sub run()
{
    if (! check_options()) { return 1; }
    if (! check_rights()) { $message->message(2,"$sudo_user not allowed to kaconsole  ".$nodelist->get_str()); exit 1; }
    
    $node=$nodelist->get_node(0);
    $cmd="/etc/kadeploy/nodes/".$node->get_name()."/command/console";
    
    $exitcode=system($cmd);
    $exitcode=$exitcode/256;
    return $exitcode;
}

################################################################################

sub get_options_cmdline()
{
    GetOptions(
	       'help!'         => \$help,
	       'h!'            => \$help,

	       'm=s'           => \$node,
	       'machine=s'     => \$node,
	       );	

}


sub check_rights()
{
    $sudo_user=libkadeploy2::sudo::get_sudo_user();
    if (! $sudo_user) { $sudo_user=libkadeploy2::sudo::get_user(); }
    my $ok=0;
    if ( $sudo_user eq "root" ||
	 $sudo_user eq $conf->get("deploy_user")
	 )
    {
	$ok=1;
    }
    if (libkadeploy2::karights::check_rights(
				      $nodelist,
				      "CONSOLE"))
    {
	$ok=1;
    }	
    return $ok;
}

sub check_options()
{
    

    if (!$node)
    {
	$message->kaconsole_help();
	return 0;
    }
    else
    {
	@node_list=($node);
	$nodelist=libkadeploy2::nodelist::new();
	$nodelist->loadlist(\@node_list);
    }
    return 1;
}

