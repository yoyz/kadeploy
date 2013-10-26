package libkadeploy2::kadeploy;
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
my $kachecknodes=$conf->getpath_cmd("kachecknodes");
my $deployenv_name=$conf->get("deployenv_name");
my $deployenv_login=$conf->get("deployenv_login");
my @node_list;
my $disknumber=$conf->get("default_disk_number");
my $partnumber=$conf->get("default_partition_number");
my $login;
my $help;
my $verbose=0;
my $envname;
my $environment;
my $nodelist;
my $basefile;
my $partitionfile;
my $cmd;
my $ok=1;
my $noreboot=0;
my $command;
my $envfile;
my $timetosleep=60;
my $sudo_user=libkadeploy2::sudo::get_sudo_user();

sub get_options_cmdline()
{
    GetOptions(
	       'm=s'                  => \@node_list,
	       'machine=s'            => \@node_list,
	       
	       'disknumber=i'         => \$disknumber,
	       'd=i'                  => \$disknumber,
	       'partnumber=i'         => \$partnumber,
	       'p=i'                  => \$partnumber,
	       
	       'login=s'              => \$login,
	       'l=s'                  => \$login,
	       
	       'environment=s'        => \$envname,
	       'e=s'                  => \$envname,
	       
	       'h!'                   => \$help,
	       'help!'                => \$help,
	       'v!'                   => \$verbose,
	       'verbose!'             => \$verbose,
	       
	       'noreboot!'            => \$noreboot,
	       'n!'                   => \$noreboot,
	       );
    foreach my $arg (@ARGV) { if ($arg =~ /([a-zA-Z0-9_]+)\@([a-zA-Z0-9\._]+)/) { $login=$1; $envname=$2; } }
}


sub check_options()
{
    if ($help)            { $message->kadeploy_help(); exit 0; }
    if (@node_list)
    {
	$nodelist=libkadeploy2::nodelist::new();
	$nodelist->loadlist(\@node_list);
    }
    else
    {
	$message->missing_node_cmdline(2);
	$message->kadeploy_help(); 
	return 0;
    }
    

    if (! $disknumber)    { $message->missing_cmdline(2,"disknumber needed"); return 0; }
    if (! $partnumber)    { $message->missing_cmdline(2,"partnumber needed"); return 0; }
    if (! ($disknumber =~ /^\d+$/)) { $message->missing_cmdline(2,"partnumber is a number begining at 1"); return 0; }
    if (! ($partnumber =~ /^\d+$/)) { $message->missing_cmdline(2,"partnumber is a number begining at 1"); return 0; }
    if (! $login)         { $message->missing_cmdline(2,"user name needed"); return 0; }
    if (! $envname)       { $message->missing_cmdline(2,"environment name needed"); return 0; }
    return 1;
}

sub run()
{
    if (! check_options()) { $message->message(2,"Something wrong while checking option"); return 1; }
    $environment=libkadeploy2::environment::new();
    $environment->set_name($envname);
    $environment->set_user($login);    
    
    if (! $environment->get_descriptionfile_fromdb()) { $message->message(2,"Environment not registred in db...");    exit 1; }
    if (! $environment->load())                       { $message->erroropeningfile(2,$environment->get_descriptionfile()); exit 1; 	}
    if (! $environment->get("deploytype"))       { $message->message(2,"Your configuration file doesn't contain deploytype"); exit 1; 	}
    $envfile=$environment->get_descriptionfile();	
    $ok=1;
    
#IF PXE
    if ($environment->get("deploytype") eq "pxelinux")
    { 
	$cmd="$kadeployenv ".$nodelist->get_cmdline()." -e $envname -l $login";
	if ($partnumber) { $cmd.=" -p $partnumber"; }
	if ($verbose) { $cmd.=" -v"; }
	if (! execcmd($cmd)) { $message->message(2,"Fail with pxe for node ".$nodelist->get_str()); return 1; }
	else { $message->message(-1,"$sudo_user setting up pxe for node ".$nodelist->get_str()); return 0; }
    }
    
    $message->message(-1,"Using $deployenv_login\@$deployenv_name");
    $cmd=$kadeployenv." ".$nodelist->get_cmdline()." -l $deployenv_login -e $deployenv_name";
    if (! execcmd($cmd)) { $message->message(2,"$sudo_user Fail with pxe for node ".$nodelist->get_str()); exit 1; }
    
    $cmd="$kachecknodes --check --type MCAT ".$nodelist->get_cmdline();
    if (! execcmd($cmd))
    {
	$cmd=$kareboot." ".$nodelist->get_cmdline();
	if (! execcmd($cmd)) { $message->message(2,"Fail with reboot"); exit 1; }
	
	$message->message(-1,"Sleeping $timetosleep");
	sleep($timetosleep);
    }
    
    $cmd=$kadeployenv." ".$nodelist->get_cmdline()." -e ".$envname." -l ".$login." -p ".$partnumber." -d ".$disknumber;
    if (! execcmd($cmd)) { $message->message(2,"Fail to deploy"); exit 1; }
    else { $ok=0; }
    
    if ($noreboot==0)
    {
	$cmd=$kareboot." ".$nodelist->get_cmdline();
	if (! execcmd($cmd)) { $message->message(2,"Fail whith reboot"); exit 1; }
	
	$message->message(-1,"Sleeping $timetosleep");
	sleep($timetosleep);
	
	$cmd=$kachecknodes." --check --retry 40 --type ICMP ".$nodelist->get_cmdline();
	if (! execcmd($cmd)) { $message->message(2,"Fail waiting for node"); $ok=0; }
    }
    
    if (! $ok) { exit 1; }
    else { $message->message(0,"Deployment success"); exit 0; }
}


################################################################################

sub execcmd($)
{
    my $cmd=shift;
    $command=libkadeploy2::command::new($cmd,
					1000,
					$verbose
					);
    $command->exec();
    return $command->get_status();
}
