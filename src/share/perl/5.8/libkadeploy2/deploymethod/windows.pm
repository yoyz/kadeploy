package libkadeploy2::deploymethod::windows;
use strict;
use warnings;

use Getopt::Long;
use libkadeploy2::deployconf;
use libkadeploy2::script;
use libkadeploy2::command;
use libkadeploy2::nodelist;
use libkadeploy2::device;
use libkadeploy2::remoteparallelcommand;
use libkadeploy2::disk;
use libkadeploy2::disks;
use libkadeploy2::environment;

sub execcmd($$);

my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }

my $kadeploydir=$conf->get("kadeploy2_directory");
my $kamcat=$conf->getpath_cmd("kamcat");
my $kapart=$conf->getpath_cmd("kapart");
my $kapxe=$conf->getpath_cmd("kapxe");
my $kareboot=$conf->getpath_cmd("kareboot");

my $device;
my $linuxdev;
my $remoteparallelcommand;
my $timeout=10;
my $defaultconnector="ssh";
my $connector="";
my $parallellauncher="internal";


my @node_list;
my $partitionfile;
my $disknumber;
my $partnumber;
my $disktype;
my $help=0;
my $nodelist;
my $command;
my $basefile;
my $cmd;
my $ref_node_list;
my $node;
my $nodename;
my $disk;
my $i;
my $taropts;
my $envfile;
my $environment;
my $disks;

################################################################################

sub new()
{
    my $self={};
    bless $self;
    $self->{verbose}=0;
    return $self;
}

sub get_options_cmdline()
{
    my $self=shift;
    my $verbose=0;
    GetOptions(
	       'm=s'                  => \@node_list,
	       'machine=s'            => \@node_list,
	       
	       'envfile=s'            => \$envfile,
	       
	       'disknumber=s'         => \$disknumber,
	       'partnumber=s'         => \$partnumber,
	       
	       'timeout=s'            => \$timeout,
	       
	       'connector=s'          => \$connector,	   
	       
	       'h!'                   => \$help,
	       'help!'                => \$help,
	       'v!'                   => \$verbose,
	       'verbose!'             => \$verbose,
	       );

    $self->{envfile}=$envfile;
    $self->{disknumber}=$disknumber;
    $self->{partnumber}=$partnumber;
    $self->{timeout}=$timeout;
    $self->{connector}=$connector;
    if ($verbose) { $self->{verbose}=$verbose; } else { $self->{verbose}=0; }
    if (@node_list)     { $self->{nodelist}=libkadeploy2::nodelist::new(); $self->{nodelist}->loadlist(\@node_list);  }
    else { $message->missing_node_cmdline(2); exit 1; }
    return 1;
}

sub check_options()
{
    my $self=shift;

    if (! $self->{envfile})  { $message->missing_cmdline(2,"envfile");   exit 1; }
    
    if (! $self->{nodelist})
    {
	if (@node_list)     { $self->{nodelist}=libkadeploy2::nodelist::new(); $self->{nodelist}->loadlist(\@node_list);  }
	else { $message->missing_node_cmdline(2); exit 1; }
    }
    
    $environment=libkadeploy2::environment::new();
    $environment->set_descriptionfile($self->{envfile});
    $environment->load();
    $self->{basefile}=$environment->get("basefile");

    if (! $connector) { $self->{connector}=$defaultconnector; }
    
    if (! $self->{disknumber})    { $message->missing_cmdline(2,"disknumber"); return 0; }
    if (! $self->{partnumber})    { $message->missing_cmdline(2,"partnumber"); return 0; }
    if (! $self->{basefile})      { $message->missing_cmdline(2,"basefile"); return 0; }
    if (! -f $self->{basefile})   { $message->filenotfound(2,$self->{basefile}); return 0; }

    $disks=libkadeploy2::disks::new($self->{nodelist});


    if (! $disks->check_disk_type($self->{disknumber})) { exit 1; }



    $self->{disktype}=$disks->get_disk_type($self->{disknumber});

    $self->{device}=libkadeploy2::device::new($self->{disktype},
					      $self->{disknumber},
					      $self->{partnumber});
    $self->{linuxdev}=$self->{device}->get_linux();
    return 1;
}

sub run()
{
    my $self=shift;
   
    if (! $self->check_options()) { exit 1; }

    $message->message(0,"Deploying windows on disk : ".
		      "disk=".$self->{disknumber}." ".
		      "partition=".$self->{partnumber}." ".
		      "interface=".$self->{disktype}." ".
		      $self->{nodelist}->get_str().		 
		      "");

    $cmd="umount /dev/".$self->{linuxdev};
    $self->execcmd($cmd,30);
    
    $cmd="umount /mnt/dest";
    $self->execcmd($cmd,30);
    
    $cmd="mkdir -p /mnt/dest";
    if (! $self->execcmd($cmd,10)) { exit 1; }
    
    $cmd="mkfs.vfat -F 32 /dev/".$self->{linuxdev};
    if (! $self->execcmd($cmd,30)) { exit 1; }
    
    $cmd="mount /dev/".$self->{linuxdev}." /mnt/dest";
    if (! $self->execcmd($cmd,10)) { exit 1; }
    
    

    if     ($self->{basefile} =~ /tgz$/)      { $taropts = "xzf"; }
    elsif  ($self->{basefile} =~ /tar$/)      { $taropts = "xf"; }
    elsif  ($self->{basefile} =~ /tar\.gz$/)  { $taropts = "xzf"; }
    elsif  ($self->{basefile} =~ /tar\.bz2$/) { $taropts = "xjf"; }
    else   { exit 1; }
    
    $kamcat=libkadeploy2::kamcat::new();
    $kamcat->set_nodelist($self->{nodelist});
    $kamcat->set_user("root");
    $kamcat->set_srvcmd("cat ".$self->{basefile});
    $kamcat->set_cltcmd("cd /mnt/dest ; tar $taropts -");

    $message->message(0,"Transfert image");
    if (! $kamcat->run())
    { 	$message->message(-1,"Transfert finished");     }
    else
    { 	$message->message(-1,"Transfert failed");     }
    
#$cmd="$kamcat -v -l root --servercommand \"cat $basefile\" --clientcommand \"cd /mnt/dest ; tar $taropts -\" ".$nodelist->get_cmdline;
    
    $cmd="umount /mnt/dest";
    $self->execcmd($cmd,200);
    $message->message(-1,"Finished");
}

################################################################################

sub set_nodelist($)   { my $self=shift; $self->{nodelist}=shift;;  }
sub set_envfile($)    { my $self=shift; $self->{envfile}=shift; }
sub set_disknumber($) { my $self=shift; $self->{disknumber}=shift; }
sub set_partnumber($) { my $self=shift; $self->{partnumber}=shift; }
sub set_timeout($)    { my $self=shift; $self->{timeout}=shift; }
sub set_verbose()     { my $self=shift; $self->{verbose}=1; }

								
sub execcmd($$)
{
    my $self=shift;
    my $cmd=shift;
    my $timeout=shift;
    $remoteparallelcommand=libkadeploy2::remoteparallelcommand::new(
								    $self->{connector},
								    $parallellauncher,
								    "root",
								    $self->{nodelist},
								    $cmd,
								    $timeout,
								    $self->{verbose},
								    );

if (! $remoteparallelcommand->exec()) { return 0; } else { return 1;}
}

1;
