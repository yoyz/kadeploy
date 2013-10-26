package libkadeploy2::kareset;

use strict;
use warnings;
use Getopt::Long;
use libkadeploy2::message;
use libkadeploy2::environment;
use libkadeploy2::deploy_iolib;
use libkadeploy2::deployconf;
use libkadeploy2::nodelist;
use libkadeploy2::command;
use libkadeploy2::sudo;
use libkadeploy2::environment;

sub execcmd($);

my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }
my $kadeploydir=$conf->get("kadeploy2_directory");
my $kadeployenv=$conf->getpath_cmd("kadeployenv");
my $kareboot=$conf->getpath_cmd("kareboot");
my $deployenv_name=$conf->get("deployenv_name");
my $deployenv_login=$conf->get("deployenv_login");
my $cmd;
my @node_list;
my $nodelist;
my $command;
my $help;

sub run()
{
    $message->message(-1,"Trying to reset nodes in deployment system");
    $cmd="$kadeployenv -e $deployenv_name -l $deployenv_login ".$nodelist->get_cmdline();
    if (! execcmd($cmd)) { $message->message(2,"Fail to ".$nodelist->get_str()); return 1; }
    
    $cmd="$kareboot ".$nodelist->get_cmdline();
    if (! execcmd($cmd)) { $message->message(2,"Fail to ".$nodelist->get_str()); return 1; }    
}

sub get_options_cmdline()
{
    GetOptions(
	       'm=s'                  => \@node_list,
	       'machine=s'            => \@node_list,
	       
	       'h!'                   => \$help,
	       'help!'                => \$help,
	       );
}

sub check_options()
{
    if ($help) { $message->kareset_help(); exit 0; }
    
    if (@node_list)
    {
	$nodelist=libkadeploy2::nodelist::new();
	$nodelist->loadlist(\@node_list);
    }
    else
    {
	$message->missing_node_cmdline(2);
	$message->kadeploy_help(); 
	exit 1;
    }    
}

sub execcmd($)
{
    my $cmd=shift;
    $command=libkadeploy2::command::new($cmd,
					1000,
					0
					);
    $command->exec();
    return $command->get_status();
}


1;
