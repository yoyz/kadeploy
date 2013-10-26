package libkadeploy2::remoteparallelcommand;

use libkadeploy2::command;
use libkadeploy2::remotecommand;
use libkadeploy2::message;
use strict;
use warnings;

my $message=libkadeploy2::message::new();

sub new($$$$$$$)
{
    my $connector=shift;
    my $parallellauncher=shift;
    my $login=shift;
    my $nodelist=shift;
    my $cmd=shift;
    my $timeout=shift;
    my $verbose=shift;
    my $self=
    {
	connector        => $connector,
	parallellauncher => $parallellauncher,
	login            => $login,
	nodelist         => $nodelist,
	cmd              => $cmd,
	timeout          => $timeout,
	verbose          => $verbose,
	status           => -1,
    };
    bless $self;
    $self->check();
    return $self;
}

sub check()
{
    my $self=shift;
    if ( !($self->{parallellauncher} eq "dsh") &&
	 !($self->{parallellauncher} eq "DKsentinelle") &&
	 !($self->{parallellauncher} eq "internal"))
    { $message->message(2,"(INTERNAL parallellauncher must be : dsh | DKsentinelle | internal"); exit 1; }
    if ( !($self->{connector} eq "rsh" ) &&
	 !($self->{connector} eq "ssh" ) )
    { $message->message(2,"INTERNAL connector must be : rsh | ssh"); exit 1; }
    if (!($self->{timeout}>=0)) { $message->message(2,"INTERNAL timeout :".$self->{timeout}."(must be >= 0)"); exit 1; }
}

sub exec()
{
    my $self=shift;

    if ($self->{parallellauncher} eq "dsh")               
    { $self->{status}=$self->exec_dsh(); }

    if ($self->{parallellauncher} eq "DKsentinelle")      
    { $self->{status}=$self->exec_DKsentinelle(); }

    if ($self->{parallellauncher} eq "internal")  
    { $self->{status}=$self->exec_internal(); }

    return $self->{status};
}

sub exec_dsh()
{
    my $self=shift;
    my $command;
    my $prefixcmd="dsh -c -r ".$self->{connector};
    my $nodelist=$self->{nodelist};
    my $ref_ip_list=$nodelist->get_ip_list();
    my @ip_list=@$ref_ip_list;
    my $ip;
    foreach $ip (@ip_list)
    {device
	$prefixcmd.=" -m ".$self->{login}."@".$ip;
    }
    $prefixcmd.=" -- ".$self->{cmd};
    $command=libkadeploy2::command::new($prefixcmd,
					$self->{timeout},
					$self->{verbose});
    return $command->exec();
}

sub exec_DKsentinelle()
{
    my $self=shift;
    my $command;
    my $prefixcmd="DKsentinelle  -c ".$self->{connector}." -l ".$self->{login};
    my $nodelist=$self->{nodelist};
    my $ref_ip_list=$nodelist->get_ip_list();
    my @ip_list=@$ref_ip_list;
    my $ip;
    foreach $ip (@ip_list)
    {
	$prefixcmd.=" -m ".$ip;
    }
    $prefixcmd.=" -- ".$self->{cmd};
    $command=libkadeploy2::command::new($prefixcmd,
					$self->{timeout},
					$self->{verbose});
    return $command->exec();
}

sub exec_internal()
{
    my $self=shift;
    my $remotecommand;
    my $ok=0;
    my $nodelist=$self->{nodelist};
    my $node;
    my $i;
    my $pid;
    my $exit_value;
    my $signal_num;
    my $dumped_core;
    my %pid2cmd;
    my %pid2node;

    #create childs
    for ($i=0;$i<$nodelist->get_numberofnode()+1;$i++)
    {
	$pid=fork();
	$node=$nodelist->get_node($i);
	if ($pid==0)
	{
	    $remotecommand=libkadeploy2::remotecommand::new($self->{connector},
							    $self->{login},
							    $node,
							    $self->{cmd},
							    $self->{timeout},
							    $self->{verbose}
							    );
	    if ($remotecommand->exec()==0) { $ok=1; }
	    exit $ok;
	}
	else
	{
	    $pid2cmd{$pid}=$self->{cmd};
	    $pid2node{$pid}=$node->get_name();
	}

    }
    $ok=1;
    #remove zombie
    for ($i=0;$i<$nodelist->get_numberofnode()+1;$i++)
    {
	$pid=wait();
	$exit_value  = $? >> 8;
	$signal_num  = $? & 127;
	$dumped_core = $? & 128;
	if ($exit_value!=0 ||
	    $signal_num!=0 ||
	    $dumped_core!=0)
	{
	    $message->message(-1,"[".$pid2node{$pid}.":".$pid2cmd{$pid}."] exit_value:$exit_value signal_num:$signal_num dumped_core:$dumped_core");
	    $ok=0;
	}
    }
    return $ok;
}

sub get_status()
{
    my $self=shift;
    return $self->{status};
}

sub return_command()
{
    my $self=shift;
    return $self->{cmd};
}

1;
