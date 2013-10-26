package libkadeploy2::deploymethod::linux;

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
use libkadeploy2::sudo;
use libkadeploy2::user;

sub execcmd($$);

my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }

my $kadeploydir=$conf->get("kadeploy2_directory");
my $kamcat=$conf->getpath_cmd("kamcat");
my $kapart=$conf->getpath_cmd("kapart");
my $kapxe=$conf->getpath_cmd("kapxe");
my $kareboot=$conf->getpath_cmd("kareboot");
my $postinstallscript=$conf->get("post_install_script");


my $device;
my $linuxdev;
my $remoteparallelcommand;
my $timeout=30;
my $defaultconnector="ssh";
my $connector="";
my $parallellauncher="internal";


my @node_list;
my $disknumber;
my $partnumber;
my $disktype;
my $help=0;
my $verbose=0;
my $nodelist;
my $command;
my $basefile;
my $postinstall;
my $cmd;
my $ref_node_list;
my $node;
my $nodename;
my $i;
my $taropts;
my $environment;
my $envfile;
my $disks;

my $partitionfile;
my $disk;
my $subdevice;
my $mntdest="/mnt/dest";
my $fstab="";
my $username;
my $sudo=libkadeploy2::sudo::new();
my $deployusername=$conf->get("deploy_user");

$username=$sudo->get_sudo_user();
if (! $username) { $username=$sudo->get_user(); }

my $user=libkadeploy2::user::new($username);
my $deployuser=libkadeploy2::user::new($deployusername);

my $suffixpubkey=".ssh/id_rsa.pub";
my $userpubkey=            $user->get("dir")."/$suffixpubkey";
my $deployuserpubkey=$deployuser->get("dir")."/$suffixpubkey";
my $tmpfilepubkey="/tmp/kadeploy-".$username."-pubkey";
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
    GetOptions(
	       'm=s'                  => \@node_list,
	       'machine=s'            => \@node_list,
	       
	       'partitionfile=s'      => \$partitionfile,
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
    $self->{partitionfile}=$partitionfile;
    if ($verbose) { $self->{verbose}=$verbose; } else { $self->{verbose}=0; }
    if (@node_list)     { $self->{nodelist}=libkadeploy2::nodelist::new(); $self->{nodelist}->loadlist(\@node_list);  }
    else { $message->missing_node_cmdline(2); exit 1; }
    return 1;
}

sub check_options()
{
    my $self=shift;
    my $ok=1;
    if (! $self->{envfile})          { $message->missing_cmdline(2,"envfile");   $ok=0; }

    if (! $self->{nodelist})
    {
	if (@node_list)     { $self->{nodelist}=libkadeploy2::nodelist::new(); $self->{nodelist}->loadlist(\@node_list);  }
	else { $message->missing_node_cmdline(2); $ok=0; }
    }
    $node=$self->{nodelist}->get_node(0);
    $self->{node}=$node;

    $environment=libkadeploy2::environment::new();
    $environment->set_descriptionfile($self->{envfile});
    $environment->load();
    $self->{basefile}=$environment->get("basefile");
    $self->{postinstall}=$environment->get("postinstall");

    if (! $connector) { $self->{connector}=$defaultconnector; }

    if (! $self->{partitionfile})    { $message->missing_cmdline(2,"partitionfile");   $ok=0; }
    if (! $self->{disknumber})       { $message->missing_cmdline(2,"disknumber");      $ok=0; }
    if (! $self->{partnumber})       { $message->missing_cmdline(2,"partnumber");      $ok=0; }
    if (! $self->{basefile})         { $message->missing_cmdline(2,"basefile");        $ok=0; }
    if (! $self->{postinstall})      { $message->missing_cmdline(2,"postinstall");     $ok=0; }
    if (! -f $self->{basefile})      { $message->filenotfound(2,$self->{basefile});    $ok=0; }
    if (! -f $self->{postinstall})   { $message->filenotfound(2,$self->{postinstall}); $ok=0; }



    $disks=libkadeploy2::disks::new($self->{nodelist});
    if (! $disks->check_disk_type($self->{disknumber})) { exit 1; }

    if ($self->{partitionfile})
    {
	$disk=libkadeploy2::disk::new();
	if (! $disk->loadpartitionfile($self->{partitionfile}))
	{ $message->message("Can't load ".$self->{partitionfile}); }
    }

    $self->{disktype}=$disks->get_disk_type($self->{disknumber});

    $device=libkadeploy2::device::new($self->{disktype},
				      $self->{disknumber},
				      $self->{partnumber});
    $self->{linuxdev}=$device->get_linux();

    $message->message(-1,"Collecting pubkey");
    open(PUBKEYFILE,"$deployuserpubkey") or die "can't read $deployuserpubkey";
    while (my $line=<PUBKEYFILE>) {$self->{pubkey}.=$line; }
    close(PUBKEYFILE);

    open(PUBKEYFILE,"$userpubkey")       or die "can't read $userpubkey";
    while (my $line=<PUBKEYFILE>) {$self->{pubkey}.=$line; }
    close(PUBKEYFILE);
    
    open(PUBKEYFILE,">$tmpfilepubkey")   or die "can't write $tmpfilepubkey";
    print PUBKEYFILE $self->{pubkey};
    close(PUBKEYFILE);
    chmod(0600,$tmpfilepubkey);

    return 1;
}

sub run()
{
    my $self=shift;

    if (! $self->check_options()) { exit 1; }

    $kamcat=libkadeploy2::kamcat::new();
    $kamcat->set_nodelist($self->{nodelist});
    $kamcat->set_user("root");


    $message->message(0,"Deploying linux on disk : ".
		      "disk=".$self->{disknumber}.
		      " partition: ".$self->{partnumber}.
		      " interface: ".$self->{disktype}.
		      " ".$self->{nodelist}->get_str());



    $cmd="umount $mntdest/*";
    $self->execcmd($cmd,30);

    $cmd="umount /dev/".$self->{linuxdev};
    $self->execcmd($cmd,30);   

    $cmd="umount $mntdest";
    $self->execcmd($cmd,30);
    
    $message->message(-1,"Mounting /dev/".$self->{linuxdev}." on $mntdest");
    
    $cmd="mkdir -p $mntdest";
    if (! $self->execcmd($cmd,10)) { $message->message(2,"Failed on $cmd"); exit 1; }   

    $cmd="mkfs /dev/".$self->{linuxdev};
    if (! $self->execcmd($cmd,30)) { $message->message(2,"Failed on $cmd"); exit 1; }
    
    $cmd="mount /dev/".$self->{linuxdev}." $mntdest";
    if (! $self->execcmd($cmd,10)) { $message->message(2,"Failed on $cmd"); exit 1; }

    if ($disk)
    {
	for ( my $i=1 ; $i< $disk->get_numberofpartition(); $i++)
	{
	    my $cmd1="";
	    my $cmd2="";
	    my $cmd3="";
	    $subdevice=libkadeploy2::device::new($self->{disktype},
						 $self->{disknumber},
						 $i);
	    my $src="/dev/".$subdevice->get_linux();
	    my $dst="$mntdest/".$disk->get_frompartition($i,"label");
	    
	    if ($i == $self->{partnumber})
	    {
		
	    }	    
	    elsif (!($disk->get_frompartition($i,"label") eq "unknow")  &&
		   !($disk->get_frompartition($i,"type") eq "extended") &&
		   ($disk->get_frompartition($i,"fs") =~ /ext2|ext3/) &&
		   !($disk->get_frompartition($i,"fs") eq "swap")
		   )		
	    {
		
		$cmd1="mkfs.".$disk->get_frompartition($i,"fs")." $src ";	       
		$cmd2="mkdir -p $dst";
		$cmd3="mount $src $dst";
		$message->message(-1,"$cmd1 ; $cmd2 ; $cmd3");
		if ( ! $self->execcmd($cmd1,10)) { $message->message(2,"Failed on $cmd1"); exit 1; }
		if ( ! $self->execcmd($cmd2,10)) { $message->message(2,"Failed on $cmd2"); exit 1; }
		if ( ! $self->execcmd($cmd3,10)) { $message->message(2,"Failed on $cmd3"); exit 1; }
	    }
	    elsif ($disk->get_frompartition($i,"fs") eq "swap")
	    {		
		$cmd1="mkswap $src";
		$message->message(-1,"$cmd1");
		if ( ! $self->execcmd($cmd1,10)) { $message->message(2,"Failed on $cmd1"); exit 1; }
	    }
	}
    }    


    if     ($self->{basefile} =~ /tgz$/)      { $taropts = "xzf"; }
    elsif  ($self->{basefile} =~ /tar$/)      { $taropts = "xf"; }
    elsif  ($self->{basefile} =~ /tar\.gz$/)  { $taropts = "xzf"; }
    elsif  ($self->{basefile} =~ /tar\.bz2$/) { $taropts = "xjf"; }
    else   { exit 1; }
    
    $kamcat->set_srvcmd("cat ".$self->{basefile});
    $kamcat->set_cltcmd("cd $mntdest ; tar $taropts -");
#    $cmd="$kamcat -v -l root --servercommand \"cat $basefile\" --clientcommand \"cd /mnt/dest ; tar $taropts -\" ".$nodelist->get_cmdline;
    $message->message(-1,"Transfering image"); 
    if (! $kamcat->run())
    { 	$message->message(-1,"Transfert finished");     }
    else
    { 	$message->message(-1,"Transfert failed");     }

    

    if     ($self->{postinstall} =~ /tgz$/)      { $taropts = "xzf"; }
    elsif  ($self->{postinstall} =~ /tar$/)      { $taropts = "xf"; }
    elsif  ($self->{postinstall} =~ /tar\.gz$/)  { $taropts = "xzf"; }
    elsif  ($self->{postinstall} =~ /tar\.bz2$/) { $taropts = "xjf"; }
    else   { exit 1; }

    #FSTAB
    $kamcat->set_srvcmd("$kapart --printfstab --partitionfile ".
			$self->{partitionfile}." ".
			" -d ".$self->{disknumber}." ".
			" -p ".$self->{partnumber}." ".
			" -m ".$node->get_name());
    $kamcat->set_cltcmd("cat > $mntdest/etc/fstab");

    if (! $kamcat->run())
    { 	$message->message(-1,"configuring fstab finished");     }
    else
    { 	$message->message(-1,"configuring fstab failed");     }



    #SSH KEY
    $kamcat->set_srvcmd("cat $tmpfilepubkey");
    $kamcat->set_cltcmd("cat >> $mntdest/root/.ssh/authorized_keys");
    $kamcat->set_nodelist($self->{nodelist});
    if (! $kamcat->run())
    { 	$message->message(-1,"configuring root ssh user finished");     }
    else
    { 	$message->message(-1,"configuring root ssh user failed");     }
    $cmd="rm $tmpfilepubkey";
    $self->execcmd($cmd,10);


    $message->message(-1,"Transfering postinstall");    
    $kamcat->set_srvcmd("cat ".$self->{postinstall});
    $kamcat->set_cltcmd("cd /tmp ; tar $taropts -");
#    $cmd="$kamcat -v -l root --servercommand \"cat $postinstall\" --clientcommand \"cd /tmp ; tar $taropts -\" ".$nodelist->get_cmdline;
    if (! $kamcat->run())
    { 	$message->message(-1,"Transfert finished");     }
    else
    { 	$message->message(-1,"Transfert failed");     }



    $message->message(-1,"launching postinstall");
    $cmd="/tmp/$postinstallscript";
    if (! $self->execcmd($cmd,10)) { $message->message(2,"Failed on $cmd"); exit 1; }
    
    $message->message(-1,"Unmounting all dev "); #/dev/".$self->{linuxdev}." on $mntdest");
    $cmd="umount -a "; #/dev/".$self->{linuxdev};
    if (! $self->execcmd($cmd,200)) { $message->message(2,"Failed on $cmd"); exit 1; }
    $message->message(-1,"Finished");
    print $fstab;
    return 0;
}


sub set_nodelist($)       { my $self=shift; $self->{nodelist}=shift;;  }
sub set_envfile($)        { my $self=shift; $self->{envfile}=shift; }
sub set_partitionfile($)  { my $self=shift; $self->{partitionfile}=shift; }
sub set_disknumber($)     { my $self=shift; $self->{disknumber}=shift; }
sub set_partnumber($)     { my $self=shift; $self->{partnumber}=shift; }
sub set_timeout($)        { my $self=shift; $self->{timeout}=shift; }
sub set_verbose()         { my $self=shift; $self->{verbose}=1; }


################################################################################
								
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
								    $self->{verbose}								    
								    );

if (! $remoteparallelcommand->exec()) { return 0; } else { return 1;}
}

1;
