package libkadeploy2::deployconf;

use strict;
use warnings;
use libkadeploy2::message;
use libkadeploy2::conflib;
use libkadeploy2::command;
use libkadeploy2::sudo;

$ENV{PATH}="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin";

my $kadeployconfdir="/etc/kadeploy";
my $deployconf=$kadeployconfdir."/deploy.conf";
my $partitionfile=$kadeployconfdir."/clusterpartition.conf";
my $nodesfile=$kadeployconfdir."/clusternodes.conf";

my $kasudowrapper_path="/bin/kasudowrapper.sh";
my $kareboot_path="/bin/kareboot";
my $kapart_path="/sbin/kapart";
my $kapxe_path="/bin/kapxe";
my $kaexec_path="/bin/kaexec";
my $kamcat_path="/bin/kamcat";
my $kasetup_path="/sbin/kasetup";
my $kanodes_path="/sbin/kanodes";
my $kadeployenv_path="/bin/kadeployenv";
my $karights_path="/sbin/karights";
my $kachecknodes_path="/sbin/kachecknodes";
my $mcatseg_path="/bin/mcatseg";

my $factory_grub_path="/lib/floppy/grub/grub-factory.pl";
my $factory_windows_path="/lib/floppy/windows/ntldr-factory.pl";

my $environment_dd_path="/lib/environment/dd";
my $environment_linux_path  ="/lib/environment/linux";
my $environment_windows_path="/lib/environment/windows";





my %critic = 
	    (
	     #######                   legende                    ########
	     #   nb  type de donnee                     - action a realisee
	     # -----------------------------------------------------------
	     #   1 = nombre ou options ou simple chaine - 1 pas de check
	     #   2 = /path/                             - 2 check "/" debut & "/" fin
	     #   3 = /path/cmd ou /path/archive.tgz     - 3 check "/" debut & ! "/" fin
	     #   4 = chemin/                            - 4 check ! "/" debut & "/" fin
	     #   5 = machinchose                        - 5 check ! "/" debut et fin
	     #   6 = /truc                              - 6 check "/" debut 
	     #   7 = yes                                - 7 check "yes" | "no"
	     ##############################################################


             # ce ne sont pas des variables critiques	     
	     #"use_internal_parallel_command" => 7,
	     #"do_fdisk_on_deploy" => 7,
	     
	     "kadeploy2_directory" => 6,
	     
	     "deploy_db_host" => 1,
	     "deploy_db_name" => 1,
	     "deploy_db_login" => 1,
	     "deploy_db_psswd" => 1,
	     
	     "pre_install_archive" => 3,
	     "pre_install_script" => 5,
	     "post_install_script" => 5,
	     "tftp_repository" => 2,

	     "deployenv_name" => 5,
	     "deployenv_login"   => 5,
	     
	     "deploy_user"  => 5,

	     "default_partition_number" => 1,
	     "default_disk_number"      => 1,
	     #############################
	     );



my $message=libkadeploy2::message::new();


sub new()
{
    my $self;
    $self=
    {
	conffile => $deployconf,
	conf     => "NOTLOADED",
	loaded   => 0,
	critic   => \%critic,
    };
    bless $self;
    return $self;
}

sub load()
{
    my $self=shift;
    my $ok=1;
    my $conf=libkadeploy2::conflib::new($self->{conffile},
					$self->{critic});
    if (! $conf->load())  { $ok=0; }
    $self->{conf}=$conf;
    $self->{loaded}=1;
    return $ok;
}

sub loadcheck()
{
    my $self=shift;
    if (! $self->load())  { return 0; }
    if (! $self->check()) { return 0; }
    return 1;
}

sub check_conf_directory_structure()
{
    my $self=shift;
    my $ok=1;
    if ( ! -d $kadeployconfdir)
    {  	$message->dirnotfound(2,$kadeployconfdir); $ok=0;   }
    
    if ( ! -e $self->{conf})
    { $message->filenotfound(2,$self->{conf}); $ok=0; }
    return $ok;
}

sub get($)
{
    my $self=shift;
    my $key=shift;;
    my $conf;
    my $val;
    if ($self->{loaded})
    {
	$conf=$self->{conf};
	$val=$conf->get($key);
    }
    else
    {
	$message->message(2,"deployconf get($) error conf not loaded\n");
	exit 1;
    }
    return $val;
}


sub is_conf($)
{
    my $self=shift;
    my $key=shift;
    my $conf;
    my $val;    
    if ($self->{loaded})
    {
	$conf=$self->{conf};
	$val=$conf->is_set($key);
    }
    return $val;
}


sub check()
{
    my $self=shift;
    my $conf;
    my $retval=1;
    if ($self->{loaded})
    {
	$conf=$self->{conf};
	$retval=$conf->check();
    }
    else
    {
	$retval=0;
    }
    return $retval;
}

#check /etc/kadeploy/deploy.conf
sub checkdeployconf()
{
    my $self=shift;   
    my $kadeploy2_directory;
    my $tftpdir;
    my $pxe_rep;
    my $deploy_user;
    my $userok=0;
    my $ok=1;
    my $getenterror=0;
    my $line;
    my $remotesentinelle;
    my $remotemcat;
    my $deploy_sentinelle_cmd;
    my $prod_sentinelle_cmd;
    my $pre_install_archive;
    my $post_install_archive;
    my $tftp_relative_path;
    my $command;
    my $cmd;
    my $timeout=2;
    my $user;
    my $bin;

        if ($self->{loaded}==0) 
    {
	$message->loadingfileyoumust(2);
	exit 1;
    }


    $kadeploy2_directory=$self->get("kadeploy2_directory");
    $deploy_user=$self->get("deploy_user");
    $tftpdir=$self->get("tftp_repository");
    $pxe_rep=$self->get("pxe_rep");
    $deploy_sentinelle_cmd=$self->get("deploy_sentinelle_cmd");
    $pre_install_archive=$self->get("pre_install_archive");
    $post_install_archive=$self->get("post_install_archive");
    $user=libkadeploy2::sudo::get_sudo_user();

    #CHECK KADEPLOY DIR
    if (! -d $kadeploy2_directory)
    {
	print "* kadeploy directory $kadeploy2_directory not found.\n";
	$ok=0;	
    }
    else
    {
	print "* kadeploy directory $kadeploy2_directory exist.\n";
    }

    #CHECK USER
    open(FH,"getent passwd | grep $deploy_user |") or $getenterror=1;
    if (! $getenterror)
    {
	while ($line=<FH>)
	{
	    if ($line=~/^$deploy_user/)
	    {
		$userok=1;
	    }
	}
	close(FH);
	if ($userok) { 	print "* $deploy_user user exist.\n"; }
	else { print "* deploy user doesn't exit.\n"; $ok=0; }
    }
    else
    {
	print "* $deploy_user user don't exist.\n";	
	$ok=0;
	return $ok;
    }

    #CHECK TFTP
    if (! -d  $tftpdir)
    {
	print "* tftp directory $tftpdir NOT found\n";
	$ok=0;
    }
    else
    {
	print "* tftp directory $tftpdir exist.\n";       
    }

    #CHECK TFTP PXE
    if (! -d $tftpdir.$pxe_rep)
    {
	print "* pxe directory ".$tftpdir.$pxe_rep." NOT found.\n";
	$ok=0;
    }
    else
    {
	print "* pxe directory ".$tftpdir.$pxe_rep. " exist.\n";
    }

    #CHECK TFTP PXE WRITE ACCESS
    if (! -w $tftpdir.$pxe_rep)
    {
	print "* pxe directory ".$tftpdir.$pxe_rep." NOT writable.\n";
	$ok=0;
    }
    else
    {
	print "* pxe directory ".$tftpdir.$pxe_rep. " writable.\n";
    }


    
    #CHECK PREINSTALL
    if (-e $pre_install_archive)
    {
	print "* pre_install_archive exist.\n";
    }
    else
    {
	print "* You have to correct your pre_install_archive path.\n";
	$ok=0;
	return $ok;
    }

    #CHECK POSTINSTALL
    if (-e $post_install_archive)
    {
	print "* post_install_archive exist.\n";
    }
    else
    {
	print "* You have to correct your post_install_archive path.\n";
	$ok=0;	
	return $ok;
    }

    print "\n";
    return $ok;       
}


sub check_etc_deploy()
{
    my $ok=1;
    if (! -d $kadeployconfdir) { $message->message(0,"kadeploy configuration directory $kadeployconfdir is not created"); $ok=0; }
    if (! -e $deployconf)      { $message->filenotfound(2,"$deployconf"); $ok=0; }
    return($ok);
}

sub getpath_cmd($)
{
    my $self=shift;
    my $cmd=shift;
    
    my $cmdpath;
    my $scriptpath;
    my $kadeploydir=$self->get("kadeploy2_directory");

    if    ($cmd eq "kareboot")       { $cmdpath=$kareboot_path; }
    elsif ($cmd eq "kapart")         { $cmdpath=$kapart_path; }
    elsif ($cmd eq "kapxe")          { $cmdpath=$kapxe_path; }
    elsif ($cmd eq "kaexec")         { $cmdpath=$kaexec_path; }
    elsif ($cmd eq "kamcat")         { $cmdpath=$kamcat_path; }
    elsif ($cmd eq "kasetup")        { $cmdpath=$kasetup_path; }
    elsif ($cmd eq "kadeployenv")    { $cmdpath=$kadeployenv_path; }
    elsif ($cmd eq "karights")       { $cmdpath=$karights_path; }
    elsif ($cmd eq "kachecknodes")   { $cmdpath=$kachecknodes_path; }
    elsif ($cmd eq "kanodes")        { $cmdpath=$kanodes_path; }

    elsif ($cmd eq "mcatseg")        { $cmdpath=$mcatseg_path; }
    elsif ($cmd eq "kasudowrapper")  { $cmdpath=$kasudowrapper_path; }

    elsif ($cmd eq "environment_dd")        { $cmdpath=$environment_dd_path; }
    elsif ($cmd eq "environment_linux")     { $cmdpath=$environment_linux_path; }
    elsif ($cmd eq "environment_windows")   { $cmdpath=$environment_windows_path; }

    elsif ($cmd eq "factory_grub")          { $cmdpath=$factory_grub_path; }
    elsif ($cmd eq "factory_windows")       { $cmdpath=$factory_windows_path; }



    if (! $cmdpath) { $message->message(2,"deployconf.pm error cmd=$cmd"); exit 255;  }
    $scriptpath=$kadeploydir.$cmdpath;
    return $scriptpath;
}

sub chmodconf()
{
    my $self=shift;

    my $kadeployuser=$self->get("deploy_user");
    my $kadeploydir=$self->get("kadeploy2_directory");
    my $sudouser=libkadeploy2::sudo::get_sudo_user();
    my $tftpdir=$self->get("tftp_repository");
    if (! $sudouser) { $sudouser=libkadeploy2::sudo::get_user(); }

    my $kasudowrapperfile="$kadeploydir/bin/kasudowrapper.sh";
    if ($sudouser eq "root" ||
	$sudouser eq $kadeployuser
	)
    {
# la conf appartient a deploy	
	$message->message(-1,"chmoding $kadeployconfdir");
	chmod(0755,"$kadeployconfdir");
	system("chown $kadeployuser:root $kadeployconfdir");
	system("chown -R $kadeployuser:root $kadeployconfdir/*");
	chmod(0440,"$deployconf");
	chmod(0440,"$partitionfile");
	chmod(0440,"$nodesfile");

	$message->message(-1,"chmoding $kasudowrapperfile");
# le wrapper doit pouvoir etre ecris par deploy	
	system("chmod 755 $kasudowrapperfile");           
	system("chown $kadeployuser:root $kasudowrapperfile"); 
	
	$message->message(-1,"chmoding $tftpdir");
	system("chmod -R 755 $tftpdir");
	system("chown -R $kadeployuser $tftpdir");

	$message->message(-1,"chmoding plugin");
	system("chmod 755 ".$self->getpath_cmd("environment_linux"));
	system("chmod 755 ".$self->getpath_cmd("environment_dd"));
	system("chmod 755 ".$self->getpath_cmd("environment_windows"));

	$message->message(0,"chmod configuration file done");
    }
    else
    {
	$message->message(2,"You have not enough right : ".libkadeploy2::sudo::get_sudo_user());
	exit 1;
    }
}


1;
