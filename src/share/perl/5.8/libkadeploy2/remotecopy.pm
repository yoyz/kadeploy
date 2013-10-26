package libkadeploy2::remotecopy;
use libkadeploy2::message;
use libkadeploy2::parallelcommand;
use strict;
use warnings;

my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
$conf->load();

sub new($$$$$$$)
{
    my $connector=shift;
    my $login=shift;
    my $nodelist=shift;
    my $source=shift;
    my $dest=shift;
    my $timeout=shift;
    my $verbose=shift;
    my $self=
    {
	connector        => $connector,
	login            => $login,
	nodelist         => $nodelist,
	source           => $source,
	dest             => $dest,
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
    if ($self->{connector} eq "ssh")
    { $self->exec_scp(); }
    else
    { $message->message("connector not supported\n"); exit 1; }
}

sub exec_scp()
{
    my $self=shift;
    my $nodelist=$self->{nodelist};
    my $ref_node_list;
    my @node_list;
    my $node;
    my $nodeip;
    my @cmdlist;
    my $refcmdlist;
    my $cmd;
    my $ok=0;
    my $parallelcommand;
    my $ssh_default_args;

    $ssh_default_args=$conf->get("ssh_default_args");
    if (! $ssh_default_args) { $ssh_default_args=""; }

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;
    foreach $node (@node_list)
    {	
	$nodeip=$node->get_ip();
	$cmd="scp $ssh_default_args ".$self->{source}." ".$self->{login}."@".$nodeip.":".$self->{dest};
	@cmdlist=(@cmdlist,$cmd);
    }
    $refcmdlist=\@cmdlist;
    $parallelcommand=libkadeploy2::parallelcommand::new($self->{timeout},
							$self->{verbose});
    $ok=$parallelcommand->execparallel($refcmdlist);
    $self->{status}=$ok;
    return $ok;
}

sub get_status()
{
    my $self=shift;
    return $self->{status};
}
1;
