package libkadeploy2::kadeployenv;
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
use libkadeploy2::karights;
use libkadeploy2::kachecknodes;
use libkadeploy2::time;
use libkadeploy2::kapart;

use libkadeploy2::deploymethod::dd;
use libkadeploy2::deploymethod::linux;
use libkadeploy2::deploymethod::windows;

sub get_options_cmdline();
sub check_options();
sub partitionlinuxnodes();
sub deploylinux();
sub deploypxelinux();
sub deploydd();
sub deploywindows();
sub setuppxelinux();
sub setuppxewindows();
sub setupgrubchainload();
sub check_necessary_right_or_exit($);
sub check_disk_partnumber();

my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }
my $kadeploydir=$conf->get("kadeploy2_directory");
my $db=libkadeploy2::deploy_iolib::new();

my $ddpath=$conf->getpath_cmd("environment_dd");
my $linuxpath=$conf->getpath_cmd("environment_linux");
my $windowspath=$conf->getpath_cmd("environment_windows");

my $kapxe=$conf->getpath_cmd("kapxe");
#my $kapart=$conf->getpath_cmd("kapart");

my $defaultdisknumber=$conf->get("default_disk_number");
my $defaultpartnumber=$conf->get("default_partition_number");

my $defaultpartitioning="/etc/kadeploy/clusterpartition.conf";

sub run()
{
    my $self=shift;
    my $ok=1;
    my $retcode=0;
    my $timedeploy;
    my $partitionfile;

    if (! $self->check_options()) { return 1; }

    my $disknumber=$self->{disknumber};
    my $partnumber=$self->{partnumber};
    my $envname=$self->{envname};
    my $login=$self->{login};
    my $environment=$self->{environment};

    
    $timedeploy=libkadeploy2::time::new();
    $timedeploy->start();

    
#    $envfile=$environment->get_descriptionfile();

    if (!$self->check_necessary_right("PXE")) { return 1; }
    if (!$self->check_envfile())              { return 1; }

    
    #Check nodes if deploytype != PXE
    if (! ($environment->get("deploytype") =~/^pxe.+/))
    {

	if (( ! $self->{partnumbercmdline}) && (! $environment->is_set("partnumber")))
	{
	    $message->message(2,"no partnumber defined");
	    return 1;
	}
	if (! $environment->is_set("pxetype"))
	{
	    $message->message(2,"pxetype not set in your envfile... can't setup pxe");
	    return 1;
	}

	my $partitionrightcheck=1;
	if ($environment->is_set("partitionfile"))
	{ if (!
	      (
	       $self->check_necessary_right("DISK$disknumber") &&
	       $self->check_necessary_right("DISK".$disknumber."_PART".$partnumber) &&
	       $self->check_disk_partnumber()
	       )
	      )
	    { $partitionrightcheck=0; }
	}
	else
	{ if (!
	      (
	       check_necessary_right("DISK".$disknumber."_PART".$partnumber) &&
	       check_disk_partnumber()
	       )
	      )
	  { $partitionrightcheck=0; }	  
	}
	if (! $partitionrightcheck) 
	{ $message->message(2,"Missing right on disk $disknumber part $partnumber"); return 1; }


	my $missingnode=1;
	for (my $i=0; $i<5 && $missingnode;$i++)
	{	    
	    $missingnode=0;
	    if (!$self->checknodes_icmp_ssh_mcat())
	    { $message->message(1,"All node are not there"); $missingnode=1; }
	    if (!$self->checknodes_db())
	    { $message->message(-1,"Removing missing nodes"); $missingnode=1; }
	}
	if ($self->{nodelist}->get_numberofnode() == -1)
	{
	    $message->message(2,"There isn't any node...");
	    return 1;
	}

	#PARTITIONING
	$partitionfile=$environment->get("partitionfile");
	if (! $partitionfile)    
	{
	    $message->message(0,"Trying with default parititioning schema for node ".$self->{nodelist}->get_str());
	    $partitionfile=$defaultpartitioning;
	}
	$self->{partitionfile}=$partitionfile;

	$message->message(0,"Partitioning nodes ".$self->{nodelist}->get_str()." whith file $partitionfile");
	$ok=$self->partitionlinuxnodes();
	if (! $ok) 
	{ 
	    $message->message(2,"fail to partition some nodes....");
	    return 1; 
	}
	$ok=$self->deploy($environment->get("deploytype"));
	if ($ok) 
	{ 
	    $message->message(0,"Setup pxe for ".$self->{nodelist}->get_str());
	    if (!$self->confsetuppxe($environment->get("deploytype"))) { $message->message(2,"Something wrong in your environment file"); $ok=0; }
	    $ok=$self->setuppxe();
	}	
    }  
    elsif ($environment->get("deploytype") =~ /^pxe.+/)
    { 	    
	if (!$self->confsetuppxe($environment->get("deploytype"))) 
	{ $message->message(2,"Something wrong in your environment file"); $ok=0; }
	if ($ok) { $ok=$self->setuppxe(); }
    }
       
    if ($ok)
    { 
	$message->message(0, "Deployment success with ".$self->{nodelist}->get_str()); 
	$message->message(-1,"Deployment time ".int($timedeploy->stop())."s");
	$retcode=0; 
    }
    else
    { 
	$message->message(2, "Deployment failed with ".$self->{nodelist}->get_str());  
	$message->message(-1,"Deployment time ".int($timedeploy->stop())."s");
	$retcode=1;
    }

    return $retcode;
}

################################################################################

sub set_login($)        { my $self=shift; my $arg=shift; $self->{login}=$arg;       }
sub set_envname($)      { my $self=shift; my $arg=shift; $self->{envname}=$arg;     }

sub set_disknumber($)   { my $self=shift; my $arg=shift; $self->{disknumber}=$arg;  }
sub set_partnumber($)   { my $self=shift; my $arg=shift; $self->{partnumber}=$arg;  }

sub set_nodelist($)    { my $self=shift; my $arg=shift; $self->{nodelist}=$arg;    }

sub set_deploytype($)   { my $self=shift; my $deploytype=shift; $self->{deploytype}=$deploytype; }
sub set_pxetype($)      { my $self=shift; my $pxetype=shift;    $self->{pxetype}=$pxetype; } 
sub set_bootfromnetwork { my $self=shift; $self->{bootfromnetwork}=1; $self->{bootfromdisk}=0; }
sub set_bootfromdisk    { my $self=shift; $self->{bootfromdisk}=1; $self->{bootfromnetwork}=0; }


sub new()
{
    my $self;
    $self=
    {
	login       => "",
	envname     => "",
	nodelist    => "",
	environment => "",
	help        => 0,

	verbose     => 0,
    };
    bless $self;
    return $self;
}



sub get_options_cmdline()
{
    my $self=shift;
    
    my @node_list;
    my $nodelist;
    my $login="";
    my $help;
    my $verbose=0;
    my $envname="";
    my $disknumbercmdline;
    my $partnumbercmdline;

    GetOptions(
	       'm=s'                  => \@node_list,
	       'machine=s'            => \@node_list,
	       
	       'disknumber=s'         => \$disknumbercmdline,
	       'd=s'                  => \$disknumbercmdline,
	       'partnumber=s'         => \$partnumbercmdline,
	       'p=s'                  => \$partnumbercmdline,
	       
	       'login=s'              => \$login,
	       'l=s'                  => \$login,
	       
	       'environment=s'        => \$envname,
	       'e=s'                  => \$envname,
	       
	       'h!'                   => \$help,
	       'help!'                => \$help,
	       'v!'                   => \$verbose,
	       'verbose!'             => \$verbose,
	       );

    if (! $help) 
    {	if (@node_list)     
	{ $nodelist=libkadeploy2::nodelist::new(); $nodelist->loadlist(\@node_list);  }
	else { $message->missing_node_cmdline(2); return 0; }
	$self->{nodelist}=$nodelist;
    }


    $self->{disknumbercmdline}=$disknumbercmdline;
    $self->{partnumbercmdline}=$partnumbercmdline;
    $self->{login}=$login;
    $self->{envname}=$envname;
    $self->{help}=$help;
    $self->{verbose}=$verbose;
}

sub check_options()
{
    my $self=shift;
    my $login;
    my $envname;
    my $environment;
    my $ok=1;

    if ($self->{help}) { $message->kadeployenv_help(); exit 0; }

    foreach my $arg (@ARGV) { if ($arg =~ /([a-zA-Z0-9_]+)@([a-zA-Z0-9\._]+)/) 
			      { $login=$1; $envname=$2; } }
    if (! $login)                   
    { $message->missing_cmdline(2,"User name needed"); return 0; }

    if (! $envname)                 
    { $message->missing_cmdline(2,"Environment name needed"); return 0; }    

    $self->{login}=$login;
    $self->{envname}=$envname;

    $environment=libkadeploy2::environment::new();
    $environment->set_name($envname);
    $environment->set_user($login);    
    if (! $environment->get_descriptionfile_fromdb()) { $message->message(2,"Environment not registred in db..."); $ok=0; }
    if (! $environment->load())                       { $message->erroropeningfile(2,$environment->get_descriptionfile()); $ok=0; }
    if (! $environment->is_set("deploytype"))         { $message->message(2,"Your configuration file doesn't contain deploytype"); $ok=0; }
    $self->{envfile}=$environment->get_descriptionfile();

    if ($environment->is_set("partnumber")) 
    { $self->{partnumber}=$environment->get("partnumber"); }
    elsif ($self->{partnumbercmdline})
    { $self->{partnumber}=$self->{partnumbercmdline}; }
    else
    { $self->{partnumber}=$defaultpartnumber; }

    if ($environment->is_set("disknumber"))
    { $self->{disknumber}=$environment->get("disknumber"); }
    elsif ($self->{disknumbercmdline})
    { $self->{disknumber}=$self->{disknumbercmdline}; }
    else
    { $self->{disknumber}=$defaultdisknumber; }	

    $self->{environment}=$environment;

    return $ok;
}



sub checknodes_icmp_ssh_mcat()
{
    my $self=shift;
    my $kachecknodes;
    my @icmptype=("ICMP");
    my @sshtype=("SSH");
    my @mcattype=("MCAT");
    
    $kachecknodes=libkadeploy2::kachecknodes::new();
    $kachecknodes->set_check();
    $kachecknodes->set_type_list(\@icmptype);
    $kachecknodes->set_retry(10);
    $kachecknodes->set_sleeptime(10);
    $kachecknodes->set_nodelist($self->{nodelist});
    if ($kachecknodes->run()!=0) 
    { 
	$message->message(2,"check @icmptype, node not found... (".$self->{nodelist}->get_str().")"); 
	return 0; 
    }
    
    $kachecknodes=libkadeploy2::kachecknodes::new();
    $kachecknodes->set_check();
    $kachecknodes->set_type_list(\@sshtype);
    $kachecknodes->set_retry(3);
    $kachecknodes->set_sleeptime(10);
    $kachecknodes->set_nodelist($self->{nodelist});
    if ($kachecknodes->run()!=0) 
    { 
	$message->message(2,"check @sshtype, node not found... (".$self->{nodelist}->get_str().")"); 
	return 0; 
    }
    
    $kachecknodes->set_check();
    $kachecknodes->set_type_list(\@mcattype);
    $kachecknodes->set_retry(3);
    $kachecknodes->set_sleeptime(10);
    $kachecknodes->set_nodelist($self->{nodelist});
    if ($kachecknodes->run()!=0) 
    { 
	$message->message(2,"check @mcattype node not found... (".$self->{nodelist}->get_str().")"); 
	return 0; 
    }
    return 1;
}

sub checknodes_db()
{
    my $self=shift;
    my $ok=1;
    my $nodelist=$self->{nodelist};
    my $refnodelist=$nodelist->get_nodes();
    my @node_list=@$refnodelist;

    $db->connect();	
    foreach my $node (@node_list)
    {
	if (! ($db->get_nodestate($node->get_name(),"MCAT") eq "UP"))
	{
	    $message->message(1,"mcat service for node ".$node->get_name()." is not up"); 
	    $nodelist->del($node->get_ip());
	    $ok=0;
	}
    }
    $self->{nodelist}=$nodelist;
    $db->disconnect();
    return $ok;
}

sub check_envfile()
{
    my $self=shift;
    my $environment=$self->{environment};
    my $ok=1;

    if (($environment->get("deploytype") eq "windows") &&
	(! $environment->is_set("windowsdirectory")))
    { $message->message(2,"Your environment file doesn't contain windowsdirectory"); $ok=0;    }
    
    if ($environment->get("deploytype") eq "linux" &&
	(! $environment->is_set("postinstall") ) )
	{ $message->message(2,"Your environment file doesn't contain postinstall"); $ok=0;    }
    
    if (! $ok) { $message->message(2,"envfile error : ".$environment->get_name()); }
    return $ok;
}


sub check_disk_partnumber()
{
    my $self=shift;
    my $ok=1;
    if (! $self->{disknumber})   { $message->missing_cmdline(2,"disknumber needed"); $ok=0; }
    if (! $self->{partnumber})   { $message->missing_cmdline(2,"partnumber needed"); $ok=0; }
    if (! ($self->{disknumber} =~ /^\d+$/)) { $message->missing_cmdline(2,"partnumber is a number begining at 1"); $ok=0; }
    if (! ($self->{partnumber} =~ /^\d+$/)) { $message->missing_cmdline(2,"partnumber is a number begining at 1"); $ok=0; }    
    return $ok;
}

sub check_necessary_right($)
{
    my $self=shift;
    my $righttocheck=shift;
    my $ok=1;
    if (!$self->check_rights($righttocheck)) 
    { $message->notenough_right(2,"user:".$self->{sudo_user}." right:".$righttocheck." node:".$self->{nodelist}->get_str()); $ok=0; }
    return $ok;
}

sub check_rights($)
{
    my $self=shift;
    my $righttocheck=shift;
    my $ok=0;

    $self->{sudo_user}=libkadeploy2::sudo::get_sudo_user();
    if (! $self->{sudo_user}) { $self->{sudo_user}=libkadeploy2::sudo::get_user(); }

    if ( $self->{sudo_user} eq "root" ||
	 $self->{sudo_user} eq $conf->get("deploy_user")
	 )
    {
	$ok=1;
    }
    if (libkadeploy2::karights::check_rights(
				      $self->{nodelist},
				      "$righttocheck"))
    {
	$ok=1;
    }	
    return $ok;
}


sub partitionlinuxnodes()
{
    my $self=shift;
    my $cmd;
    my $command;
    
    my $kapart=libkadeploy2::kapart::new();
    $kapart->set_nodelist($self->{nodelist});
    $kapart->set_dofdisk();
    $kapart->set_ostype("linux");
    $kapart->set_partitionfile($self->{partitionfile});
    $kapart->set_disknumber($self->{disknumber});
    if ($kapart->run())
    { return 1; }
    else
    { return 0; }
#    $cmd=$kapart." ".
#	$self->{nodelist}->get_cmdline()." ".
#	" --fdisk ".
#	" --disknumber ".$self->{disknumber}.
#	" --ostype linux ".
#	" --partitionfile ".$self->{partitionfile}
#	;
    
#    $command=libkadeploy2::command::new($cmd,
#					60,
#					$self->{verbose}
#					);
#    $command->exec();
#    return $command->get_status();
#    return 1;
}


sub deploy($)
{
    my $self=shift;
    my $deploytype=shift;
    my $deploy;
    my @node_list;
    @node_list=$self->{nodelist}->get_nodes();


    if    ($deploytype eq "linux")
    { 	$deploy=libkadeploy2::deploymethod::linux::new();       }
    elsif ($deploytype eq "dd")
    {   $deploy=libkadeploy2::deploymethod::dd::new();          }
    elsif ($deploytype eq "windows")  
    {   $deploy=libkadeploy2::deploymethod::windows::new();     }
    else
    {   $message->message(2,"deploymethod not found... kadeployenv::deploy($)"); exit 1;    }

    $deploy->set_nodelist($self->{nodelist});
    $deploy->set_partnumber($self->{partnumber});
    $deploy->set_disknumber($self->{disknumber});
    $deploy->set_envfile($self->{envfile});
    $deploy->set_partitionfile($self->{partitionfile});
    if ($self->{verbose}) { $deploy->set_verbose(); }

    $message->message(0,"Begin deployment ".$deploytype." with ".$self->{nodelist}->get_str());
    if ($deploy->run()==0) { return 1; }
}


sub confsetuppxe($)
{
    my $self=shift;
    my $deploytype=shift;
    
    my $ok=1;

    my $environment=$self->{environment};

    my $pxetype;

    if ($environment->is_set("bootfromdisk") &&
	$environment->is_set("bootfromtftp"))
    {
	$message->message(2,"bootfromdisk & bootfromtftp mutualy exclusive !!!");
	return 0;
    }    

    if ($environment->is_set("pxetype"))
    {
	$pxetype=$environment->get("pxetype");
	$self->set_pxetype($pxetype);
	$deploytype=$pxetype;
    }


    if ($deploytype =~ /^pxelinux$/   ||	
	$deploytype =~ /^pxegrub$/    ||
	$deploytype =~ /^pxeopenbsd$/
	) 
    { 
	$self->set_bootfromnetwork();
	$self->set_deploytype($deploytype);
	$self->set_pxetype($deploytype);
    }
    elsif ($deploytype =~ /^pxe.+/)
    {
	$self->bootfromdisk();
	$self->set_deploytype($deploytype);
	$self->set_pxetype($deploytype);
    }
    else
    {       
	$message->message(2,"deploytype = $deploytype pxetype = $pxetype (kadeployenv::confsetuppxe)");
	$ok=0;
    }
    return $ok;
}


sub setuppxe()
{
    my $self=shift;
    my $command;
    my $deploytype=$self->{environment}->get("deploytype");
    my $nodelist=$self->{nodelist};
    my $pxetype=$self->{pxetype};
    my $disknumbercmdline=$self->{disknumbercmdline};
    my $partnumbercmdline=$self->{partnumbercmdline};
    my $environment=$self->{environment};
    my $verbose=$self->{verbose};
    my $bootfrom="";
    my $cmd;

    if ($self->{bootfromnetwork})
    { $bootfrom=" --fromtftp"; }
    elsif ($self->{bootfromdisk})
    { $bootfrom=" --fromdisk"; }
    else { $message->message(2,"Internal error bootfrom unknow ??"); return 0; }
    
    $cmd="$kapxe ".$nodelist->get_cmdline().
	" --type ".$pxetype;


    if ($disknumbercmdline)
    { 	$cmd.=" --disknumber $disknumbercmdline"; }
    if ($partnumbercmdline)
    { 	$cmd.=" --partnumber $partnumbercmdline"; }
    elsif ($environment->is_set("partnumber"))
    {   $cmd.=" --partnumber ".$environment->get("partnumber"); }


    if ($environment->is_set("kernel"))
    { $cmd.=" --kernel ".$environment->get("kernel"); }
      
    if ($environment->is_set("initrd"))
    { $cmd.=" --initrd ".$environment->get("initrd"); }

    if ($environment->is_set("module"))
    { $cmd.=" --module ".$environment->get("module"); }

    if ($environment->is_set("kernelparams"))
    { $cmd.=" --kernelparams ".$environment->get("kernelparams"); }

    if ($environment->is_set("windowsdirectory"))
    { $cmd.=" --windowsdirectory ".$environment->get("windowsdirectory");     }
    
    $cmd.=" $bootfrom";
	
    if ($verbose) { $cmd.=" -v"; }

    $command=libkadeploy2::command::new($cmd,
					50,
					$verbose);
    $command->exec();
    return $command->get_status();

}

    1;
