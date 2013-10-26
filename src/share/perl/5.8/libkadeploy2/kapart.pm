package libkadeploy2::kapart;

use strict;
use warnings;
use POSIX;
use libkadeploy2::cmdline;
use libkadeploy2::message;
use libkadeploy2::command;
use libkadeploy2::nodelist;
use libkadeploy2::remoteparallelcommand;
use libkadeploy2::disk;
use libkadeploy2::device;
use libkadeploy2::disks;

use Getopt::Long;

use libkadeploy2::fdiskscript;
use libkadeploy2::fstab;

    

sub get_options();
sub check_options();
sub kapart($);

my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }

my $message=libkadeploy2::message::new();


my @node_list;
my $partitionfile;
my $disknumber;
my $partnumber;
my $disktype;
my $ostype;
my $help;
my $command;
my $cmd;
my $hostfile;
my $nodelist;
my $nodeshell;
my $verbose=0;
my $printfdisk;
my $printfstab;
my $dofdisk;

my $kadeploydir=$conf->get("kadeploy2_directory");
my $kamcat=$conf->getpath_cmd("kamcat");
my $kapart=$conf->getpath_cmd("kapart");
my $kanodes=$conf->getpath_cmd("kanodes");

################################################################################

sub new()
{
    my $self;
    $self=
    {
	node_list       => 0,
	nodelist        => 0,
	partitionfile   => "",
	
	disknumber      => 0,
	partnumber      => 0,
	
	ostype          => "linux",
	
	fdisk           => 0,
	printfdisk      => 0,
	printfstab      => 0,
    };
    bless $self;
    return $self;
}

sub run()
{
    my $self=shift;
    my $ok=1;
    if (! $self->check_options()) { return 1; }
    if ($self->{dofdisk})
    {
	$ok=$self->kapart();
    }
    elsif ($self->{printfdisk})
    {
	$ok=$self->printfdisk();
    }
    elsif ($self->{printfstab})
    {
	$ok=$self->printfstab();
    }
    return $ok;
}

sub set_nodelist($)    { my $self=shift; my $arg=shift; $self->{nodelist}=$arg;    }
sub set_dofdisk()       { my $self=shift; $self->{dofdisk}=1;    $self->{printfdisk}=0; $self->{printfstab}=0; }
sub set_printfdisk()    { my $self=shift; $self->{printfdisk}=1; $self->{dofdisk}=0;    $self->{printfstab}=0; }
sub set_printfstab()    { my $self=shift; $self->{printfstab}=1; $self->{printfdisk}=0; $self->{dofdisk}=0;    }
sub set_disknumber($)   { my $self=shift; my $arg=shift; $self->{disknumber}=$arg;  }
sub set_partnumber($)   { my $self=shift; my $arg=shift; $self->{partnumber}=$arg;  }
sub set_ostype($)       { my $self=shift; my $arg=shift; $self->{ostype}=$arg;  }
sub set_partitionfile($){ my $self=shift; my $arg=shift; $self->{partitionfile}=$arg;  }

sub get_options_cmdline()
{
    my $self=shift;
    my $nodelist;
    my @node_list;
    my $partitionfile;
    my $disknumbercmdline;
    my $partnumbercmdline;
    my $ostype;
    my $dofdisk;
    my $printfdisk;
    my $printfstab;
    my $verbose=0;
    my $help;
    
    GetOptions(
	       'm=s'                  => \@node_list,
	       'machine=s'            => \@node_list,
	       #'connector=s'          => \$connector,
	       
	       'partitionfile=s'      => \$partitionfile,
	       
	       'disknumber=s'         => \$disknumbercmdline,
	       'd=s'                  => \$disknumbercmdline,

	       'partnumber=s'         => \$partnumbercmdline,	      
	       'p=s'                  => \$partnumbercmdline,	      
	       
	       'ostype=s'             => \$ostype,
	       
	       'fdisk!'               => \$dofdisk,
	       'printfdisk!'          => \$printfdisk,
	       'printfstab!'          => \$printfstab,
	       
	       'v!'                   => \$verbose,
	       'verbose!'             => \$verbose,
	       
	       'h!'                   => \$help,
	       'help!'                => \$help,
	       );
    
    if ((! $help) && (! $printfdisk)) 
    {	if (@node_list)     
	{ $nodelist=libkadeploy2::nodelist::new(); $nodelist->loadlist(\@node_list);  }
	else { $message->missing_node_cmdline(2); return 0; }
	$self->set_nodelist($nodelist);
    }
    
    if (! $ostype) { $self->set_ostype("linux"); }
		   

    $self->set_disknumber($disknumbercmdline);    
    $self->set_partnumber($partnumbercmdline);
    $self->set_partitionfile($partitionfile);
    if ($dofdisk)      { $self->set_dofdisk(); }
    if ($printfdisk)   { $self->set_printfdisk(); }
    if ($printfstab)   { $self->set_printfstab(); }

    $self->{help}=$help;
    $self->{verbose}=$verbose;

    return 1;
}

sub check_options()
{
    my $self=shift;
    my $nodelist;
    my $partitionfile;
    if ($self->{help}) { $message->kapart_help(); exit 0;     }
    
    $nodelist=$self->{nodelist};
    $partitionfile=$self->{partitionfile};

    if (! $self->{disknumber} && $self->{dofdisk})
                                      { $message->missing_cmdline(2,"disknumber"); $message->kapart_help(); return 0; }
    if (! $nodelist && $self->{dofdisk})
                                      { $message->missing_node_cmdline(2); return 0; }

    if (! $self->{ostype})            { $message->missing_cmdline(2,"ostype"); return 0; }
    if (! $partitionfile)             { $message->missing_cmdline(2,"partitionfile"); return 0; }
 
    if (! -f $partitionfile)          { $message->filenotfound(2,$partitionfile); return 0; }    
    if ((!$self->{dofdisk}) && (!$self->{printfdisk}) && (!$self->{printfstab}))
    {
	$message->message(2,"choose a flags");
	return 0;
    }
    return 1;
}

sub kapart($)
{
    my $self=shift;
    my $ok=1;
    my $ref_node_list;
    my @node_list;
    my $node;
    my $remoteparallelcommand;
    my $nodename;
    my $i;
    my $device;
    my $linuxdev;
    my $disk;
    my $disks;
    my $partitionfile;
    my $disknumber;


    $partitionfile=$self->{partitionfile};
    $nodelist=$self->{nodelist};
    $disknumber=$self->{disknumber};

    $disk=libkadeploy2::disk::new();	
    if (! $disk->loadpartitionfile($partitionfile))
    { $message->message(2,"in partition file $partitionfile"); return 0; }

    $disks=libkadeploy2::disks::new($nodelist);
    if (! $disks->check_disk_type($disknumber)) { return 0; }

    $disktype=$disks->get_disk_type($disknumber);


    $cmd="$kamcat --login root --servercommand \"$kapart --printfdisk --partitionfile $partitionfile\" --clientcommand \" cat > /tmp/fdisk.txt\" ";
    $cmd.=libkadeploy2::cmdline::get_nodes_cmdline($nodelist);  
    
    $command=libkadeploy2::command::new(
					$cmd,
					30,
					$self->{verbose}
					);
    
    
    if (! $command->exec()) { $ok=0; }
    else 
    { 
	$cmd="$kanodes --add --partitionfile";
    


	$device=libkadeploy2::device::new("$disktype",$disknumber,0);
	$linuxdev=$device->get_linux();


	$cmd="\"umount /mnt/dest/*\"";
	$remoteparallelcommand=libkadeploy2::remoteparallelcommand::new(
								    "ssh",
								    "internal",
								    "root",
								    $nodelist,
								    $cmd,
								    30,
								    1
								    );								   
	$remoteparallelcommand->exec();
	$cmd="\"umount /mnt/dest\"";
	$remoteparallelcommand=libkadeploy2::remoteparallelcommand::new(
								    "ssh",
								    "internal",
								    "root",
								    $nodelist,
								    $cmd,
								    30,
								    1
								    );								   
	$remoteparallelcommand->exec();



	$cmd="\"cat /tmp/fdisk.txt \| fdisk /dev/$linuxdev\"";
	$remoteparallelcommand=libkadeploy2::remoteparallelcommand::new(
								    "ssh",
								    "internal",
								    "root",
								    $nodelist,
								    $cmd,
								    30,
								    1
								    );
	if (! $remoteparallelcommand->exec()) { $ok=0;   }
    }						    

    
    
    if ($ok)
    {
	$message->message(0,"Partition done for node ".$nodelist->get_str());
	return 1;
    }
    else
    {
	$message->message(2,"Partition failed for node ".$nodelist->get_str());
	return 0;
    }
}

sub printfdisk()
{
    my $self=shift;
    my $partitionfile=$self->{partitionfile};
    my $disk;	
    my $fdiskscript;
    my $ok=1;
    $disk=libkadeploy2::disk::new();
    $fdiskscript=libkadeploy2::fdiskscript::new();
    if ($disk->loadpartitionfile($partitionfile))
    {
	$fdiskscript->set_disk($disk);
	$ok=$fdiskscript->print();
    }
    else
    {
	$ok=0;
    }
    return $ok;
}

sub printfstab()
{
    my $self=shift;
    my $partitionfile=$self->{partitionfile};
    my $nodelist=$self->{nodelist};
    my $disknumber=$self->{disknumber};
    my $partnumber=$self->{partnumber};
    my $diskinterface;
    my $disk;
    my $disks;
    my $fstab;
    my $fstabbuffer="";
    my $ok=1;
    
    $disks=libkadeploy2::disks::new($nodelist);
    if (! $disks->check_disk_type($disknumber)) { $ok=0; }
    $disktype=$disks->get_disk_type($disknumber);

    $disk=libkadeploy2::disk::new();
    if (!$disk->loadpartitionfile($partitionfile))
    {
	$message->message(2,"in partitionfile");
	return $ok;
    }
    $disk->set_interface($disktype); 
    $fstab=libkadeploy2::fstab::new();
    $fstab->add_disk(1,$disk);
    $fstab->set_bootdisknumber($disknumber);
    $fstab->set_bootpartnumber($partnumber);
    $fstabbuffer=$fstab->get($self->{ostype});
    if ($fstabbuffer)
    { 	print $fstabbuffer;  }
    else { $ok=0; }
    return $ok;
}




1;
