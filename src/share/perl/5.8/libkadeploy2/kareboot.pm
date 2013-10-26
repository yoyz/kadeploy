package libkadeploy2::kareboot;

use File::Copy;
use Getopt::Long;
use libkadeploy2::deployconf;
use libkadeploy2::deploy_iolib;
use libkadeploy2::command;
use libkadeploy2::message;
use libkadeploy2::nodelist;
use libkadeploy2::cmdline;
use libkadeploy2::karights;
use libkadeploy2::sudo;
use strict;
use warnings;

sub execcmd($$$);
sub check_options;
sub check_right($);


my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }

my $sudo_user=libkadeploy2::sudo::get_sudo_user();
if (! $sudo_user) { $sudo_user=libkadeploy2::sudo::get_user(); }

my $ref_node_list;
my @node_list;
my $node_file;
my $node;
my $env;
my $soft;
my $hard;
my $deploy;
my $noreboot;
my $device;
my $verbose=0;
my $refnodelist;
my $command;
my $cmd;
my $nodeshell;
my $nodelist;
my $help;
my $ok=1;
my $message=libkadeploy2::message::new();
my $kadeploydir=$conf->get("kadeploy2_directory");
my $righttocheck="REBOOT";

sub run()
{
    if (! check_options()) { return 1; }

    if (! check_right($righttocheck)) { $message->message(2,"$sudo_user not allowed to $righttocheck ".$nodelist->get_str()); exit 1; }
    
    
    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;
    
    foreach $node (@node_list)
    {
	if ($soft)
	{
	    if (! execcmd($node,"softboot",$verbose))
	    { $ok=0; }
	}    
	if ($hard)
	{
	    if (! execcmd($node,"hardboot",$verbose))
	    { $ok=0; }
	}
	if ((! $soft ) &&
	    (! $hard))
	{
	    if (! execcmd($node,"softboot",$verbose))
	    {
		if (! execcmd($node,"hardboot",$verbose))
		{		
		    $ok=0;
		}
	    }
	}
    }
    if (! $ok) { return 1; }
    else       { return 0; }
}

################################################################################

sub get_options_cmdline()
{
    GetOptions(
	       'm=s'           => \@node_list,
	       'machine=s'     => \@node_list,
	       'f=s'           => \$node_file,

	       'e=s'           => \$env,
	       'environment=s' => \$env,

	       's'             => \$soft,
	       'soft'          => \$soft,

	       'h'             => \$hard,
	       'hard'          => \$hard,

	       'd'             => \$deploy,
	       'deploy'        => \$deploy,

	       'n'             => \$noreboot,
	       'noreboot'      => \$noreboot,

	       'p=s'           => \$device,
	       'partition=s'   => \$device,

	       'verbose'       => \$verbose,
	       'v'             => \$verbose,

	       'help!'         => \$help,
	       'h!'            => \$help,
	       );

}

sub check_options()
{

    if ($help) { $message->kareboot_help(); exit 0; }

    if (@node_list)     { $nodelist=libkadeploy2::nodelist::new(); $nodelist->loadlist(\@node_list);  }
    else { $message->missing_node_cmdline(2); return 0; }


    if (!scalar($nodelist))
    {
	$message->kareboot_help();
	return 0;
    }
    
    if ($soft && $hard)
    {
	print "ERROR : soft and hard reboot options are exclusive\n";
	print "ERROR : please select only one of them at once\n";
	return 0;
    }
    
    if (($noreboot && $soft) || ($noreboot && $hard))
    {
	print "ERROR : no reboot and soft or hard reboot should be exclusive\n";
	print "ERROR : please select only one of them at once\n";
	return 0;
    }
    
    if (($deploy && $env) || ($deploy && $device) || ($env && $device))
    {
	print "ERROR : please select EITHER a deployment reboot OR a reboot on a partition OR a reboot on an environment\n";
	return 0;
    }

    return 1;
}



sub check_right($)
{
    my $righttocheck=shift;
    return libkadeploy2::karights::check_rights($nodelist,$righttocheck);
}



sub execcmd($$$)
{
    my $node=shift;
    my $cmdnode=shift;
    my $verbose=shift;
    my $refnodelist;
    my @node_list;
    my $ok=1;
    
    $refnodelist=$nodelist->get_nodes();
    @node_list=@$refnodelist;


    $cmd=$conf->getpath_cmd("kaexec")." --confcommand -m ".$node->get_name()." -c $cmdnode";
    $command=libkadeploy2::command::new($cmd,30,$verbose);
    $command->exec();
    if (! $command->get_status())
    { 
	$message->message(0,$sudo_user." ".$cmdnode." ".$node->get_name()." fail");
	$ok=0; 
    }
    else
    {
	$message->message(0,$sudo_user." ".$cmdnode." ".$node->get_name()." success");
    }    
    return $ok;
}



1;
