package libkadeploy2::kaenv;

use strict;
use warnings;

use Getopt::Long;
use libkadeploy2::conflib;
use libkadeploy2::deploy_iolib;
use libkadeploy2::hexlib;
use libkadeploy2::message;
use libkadeploy2::environment;
use libkadeploy2::environments;
use libkadeploy2::sudo;

sub listenv();
sub check_options();
sub check_rights();

my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }

my $add;
my $del;
my $help;
my $list;
my $envfile;
my $login;
my $envname;
my $retcode;
my $sudo_user=libkadeploy2::sudo::get_sudo_user();
my $message=libkadeploy2::message::new();
my $ok=1;

if (! $sudo_user) { $sudo_user=libkadeploy2::sudo::get_user(); }



sub run()
{
    if ($help) { $message->kaenv_help(); return 0; }
    
    if ($add)
    {
	if ($envfile && $login && $envname)
	{
	    my $env=libkadeploy2::environment::new();
	    $env->set_name($envname);
	    $env->set_user($login);
	    $env->set_descriptionfile($envfile);
	    if ($envfile =~ /^\//)
	    {
		if (! $env->addtodb()) { $ok=0; }
		if ($ok)   { $message->message(0,"add environment $envname to db"); }
		if (! $ok) { $message->message(2,"Fail to add environment $envname to db"); exit 1; }
		if ($ok) { return 0; } else { return 1; }
	    }
	    else
	    {
		$message->message(2,"you must specify an absolute path");
		return 1;
	    }
	}
    }

    if ($del)
    {
	if ($envfile && $login && $envname)
	{
	    my $env=libkadeploy2::environment::new();
	    $env->set_name($envname);
	    $env->set_user($login);
	    $env->set_descriptionfile($envfile);
	    if (! $env->delfromdb()) { $ok=0; }
	    if ($ok)   { $message->message(0,"del environment $envname from db"); }
	    if (! $ok) { $message->message(2,"Fail to del environment $envname from db"); exit 1; }
	    return 0;
	}
    }
    
    if ($list)
    {
	$retcode=0;
	listenv();
	return $retcode;	
    }

    $message->kaenv_help();
    return 0;    
}


sub check_options()
{
    if ($help) { $message->kaenv_help(); exit 0; }
    if ($add || $del) 
    {
	if (! $login)               { $message->missing_cmdline(2,"user name needed"); exit 1; }
	if (! $envname)             { $message->missing_cmdline(2,"environment name needed"); exit 1; }
    }
    if (! check_rights()) { $message->message(2,"$sudo_user not allowed to kaenv"); exit 1; }
}


sub get_options_cmdline()
{
    GetOptions(
	       'a!'             => \$add,
	       'add!'           => \$add,
	       
	       'd!'             => \$del,
	       'del!'           => \$del,
	       
	       'list!'          => \$list,

	       'h!'             => \$help,
	       'help!'          => \$help,
	       
	       'f=s'            => \$envfile,
	       'envfile=s'      => \$envfile,	  
	       
	       'login=s'        => \$login,
	       'l=s'            => \$login,
	       
	       'environment=s'  => \$envname,
	       'e=s'            => \$envname,
	       );

    foreach my $arg (@ARGV) { if ($arg =~ /([a-zA-Z0-9]+)@([a-zA-Z0-9\.]+)/) { $login=$1; $envname=$2; } }
}


sub check_rights()
{
    my $ok=1;
    if ($del)
    {
	$ok=0;
	if ($sudo_user eq "root" ||
	    $sudo_user eq $conf->get("deploy_user"))
	{
	    $ok=1;
	}
    }
    return $ok;
}


sub listenv()
{
    my @nodelist;
    my $node;
    my $environments = libkadeploy2::environments::new();
    $environments->get();
    $environments->print();
}



1;
