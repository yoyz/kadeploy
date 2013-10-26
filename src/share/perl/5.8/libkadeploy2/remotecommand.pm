package libkadeploy2::remotecommand;

use libkadeploy2::deployconf;
use libkadeploy2::message;
use strict;
use warnings;

my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
$conf->load();

sub new($$$$$$)
{
    my $connector=shift;
    my $login=shift;
    my $node=shift;
    my $cmd=shift;
    my $timeout=shift;
    my $verbose=shift;
    my $self=
    {
	connector        => $connector,
	login            => $login,
	node             => $node,
	cmd              => $cmd,
	timeout          => $timeout,
	verbose          => $verbose,
	status           => -1,
	};
    bless $self;
    return $self;
}

sub exec()
{
    my $self=shift;
    my $findconnector=0;
    if ($self->{connector} eq "rsh")
    {
	return $self->exec_rsh();
	$findconnector=1;
    }
    if ($self->{connector} eq "ssh")
    {
	return $self->exec_ssh();
	$findconnector=1;
    }
    if ($findconnector==0)
    {
	$message->message(2,"INTERNAL connector not found : ".$self->{connector});
	exit 1;
    }	
}

sub exec_rsh()
{
    my $self=shift;
    my $cmd;
    my $command;
    $cmd="rsh -l ".$self->{login}." ".$self->{node}->get_ip()." ".$self->{cmd};

    $command=libkadeploy2::command::new($cmd,
					$self->{timeout},
					$self->{verbose}
					);

    $self->{status}=$command->exec();
    return($self->{status});
}

sub exec_ssh()
{
    my $self=shift;
    my $cmd;
    my $command;
    my $ssh_default_args;

    $ssh_default_args=$conf->get("ssh_default_args");
    if (! $ssh_default_args) { $ssh_default_args=""; }
    $cmd="ssh ".$ssh_default_args." -l ".$self->{login}." ".$self->{node}->get_ip()." ".$self->{cmd};

    $command=libkadeploy2::command::new($cmd,
					$self->{timeout},
					$self->{verbose}
					);
    $self->{status}=$command->exec();
    return($self->{status});
}

sub get_status()
{
    my $self=shift;
    return $self->{status};
}

1;
