package libkadeploy2::deploymethod::dd;
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
use libkadeploy2::kamcat;

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
my $connector="ssh";
my $parallellauncher="internal";


my @node_list;
my $partitionfile;
my $disknumber;
my $partnumber;
my $disktype;
my $help=0;
my $command;
my $basefile;
my $cmd;
my $ref_node_list;
my $node;
my $nodename;
my $disk;
my $i;
my $unzip;
my $environment;
my $disks;

################################################################################
sub new()
{
    my $self={};
    bless $self;
    return $self;
}

sub run()
{
    my $self=shift;
    $self->check_options();
    
    
    
    $disks=libkadeploy2::disks::new($self->{nodelist});
    if (! $disks->check_disk_type($self->{disknumber})) { exit 1; }
    
    $self->{disktype}=$disks->get_disk_type($self->{disknumber});
    
    $device=libkadeploy2::device::new($self->{disktype},
				      $self->{disknumber},
				      $self->{partnumber});
    $self->{linuxdev}=$device->get_linux();
    
    
    
    $message->message(0,"Deploying dd on".
		      " disk=".$self->{disknumber}.
		      " partition=".$self->{partnumber}.
		      " interface=".$self->{disktype}.
		      " ".$self->{nodelist}->get_str());
    
    
    $cmd="umount /dev/".$self->{linuxdev};
    $self->execcmd($cmd,30);
    
    $cmd="umount /mnt/dest";
    $self->execcmd($cmd,30);
    
    
    $message->message(-1,"Transfert image");
    
    if     ($self->{basefile} =~ /gz$/)       { $unzip = "| gzip -d"; }
    elsif  ($self->{basefile} =~ /bz2$/)      { $unzip = "| bzip2 -d"; }
    elsif  ($self->{basefile} =~ /dd$/)       { $unzip = ""; }
    else   { exit 1; }
    
#    my $srvcmd="cat ".$self->{basefile};
#    my $cltcmd="cat $unzip > /dev/".$self->{linuxdev};
#    $cmd="$kamcat -v -l root --servercommand \"$srvcmd\" --clientcommand \"$cltcmd\" ".$self->{nodelist}->get_cmdline;
#    $command=libkadeploy2::command::new($cmd,
#					600,
#					$self->{verbose}
#					);
#    if (! $command->exec()) { exit 1; }

    $kamcat=libkadeploy2::kamcat::new();
    $kamcat->set_nodelist($self->{nodelist});
    $kamcat->set_user("root");
    $kamcat->set_srvcmd("cat ".$self->{basefile});
    $kamcat->set_cltcmd("cat $unzip > /dev/".$self->{linuxdev});
    if ($self->{verbose}) { $kamcat->set_verbose(2); } else { $kamcat->set_verbose(1); }
    $kamcat->run();
    $message->message(-1,"Finished");
}   


sub get_options_cmdline()
{
    my $self=shift; 
    my $verbose;
    my $disknumber;
    my $partnumber;
    my $timeout;
    my $connector;
    my $envfile;

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
    $self->{verbose}=$verbose;
}




sub check_options()
{
    my $self=shift;
    $environment=libkadeploy2::environment::new();
    $environment->set_descriptionfile($self->{envfile});
    $environment->load();
    $self->{basefile}=$environment->get("basefile");

    if (! $self->{verbose})       { $self->{verbose}=0; }

    if (! $self->{disknumber})    { $message->missing_cmdline(2,"disknumber"); exit 1; }
    if (! $self->{partnumber})    { $message->missing_cmdline(2,"partnumber"); exit 1; }
    if (! $self->{envfile})       { $message->missing_cmdline(2,"basefile"); exit 1; }
    if (! $self->{basefile})      { $message->missing_cmdline(2,"basefile"); exit 1; }
    if (! -f $self->{basefile})   { $message->filenotfound(2,$basefile); exit 1; }

    if (! $self->{envfile})          { $message->missing_cmdline(2,"envfile");   exit 1; }

    if (! $self->{nodelist})
    {
	if (@node_list)     { $self->{nodelist}=libkadeploy2::nodelist::new(); $self->{nodelist}->loadlist(\@node_list);  }
	else { $message->missing_node_cmdline(2); exit 1; }
    }

    

}


sub set_nodelist($)   { my $self=shift; $self->{nodelist}=shift;;  }
sub set_envfile($)    { my $self=shift; $self->{envfile}=shift; }
sub set_partitionfile($)  { my $self=shift; $self->{partitionfile}=shift; }
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
								    $connector,
								    $parallellauncher,
								    "root",
								    $self->{nodelist},
								    $cmd,
								    $timeout,
								    $self->{verbose}
#								    1
								    );

if (! $remoteparallelcommand->exec()) { return 0; } else { return 1;}
}

1;
