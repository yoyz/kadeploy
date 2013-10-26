package libkadeploy2::kachecknodes;

use strict;
use warnings;
use Getopt::Long;
use libkadeploy2::message;
use libkadeploy2::environment;
use libkadeploy2::deploy_iolib;
use libkadeploy2::deployconf;
use libkadeploy2::nodelist;
use libkadeploy2::command;
use libkadeploy2::checknodes;

sub check_options();
sub check_nodes_services();
sub check_result();

sub set_check();
sub set_verbose();
sub set_type($);
sub set_retry($);
sub set_node_list($);

my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }
my $kadeploydir=$conf->get("kadeploy2_directory");

my @service_list=("ICMP","SSH","MCAT");
my $sleeptime=5;
my $blockcheckingtime=10;

################################################################################

sub run()
{
    my $self=shift;
    my $nodelist=$self->{nodelist};
    my $ok=0;      
    my $db;
    my $ref;

    if (! $self->check_options())  
    { 
	$message->message(2,"Something wrong while checking option kachecknodes");
	return 1;
    }


    if ($self->{check})
    {
	$db=libkadeploy2::deploy_iolib::new();
	$db->connect();
	if ($self->{retry})
	{
	    while ($self->{retry}>0)
	    {
		$self->check_nodes_services();
		if ($self->check_result()) { $self->{retry}=0; $ok=1; }
		if (! $ok) { sleep($self->{sleeptime}); }
		$self->{retry}--;
	    }
	}
	else
	{
	    $self->check_nodes_services();
	    if ($self->check_result()) { $ok=1; }
	}	
	$db->disconnect();
    }
    
    if ($self->{list})
    {
	$db=libkadeploy2::deploy_iolib::new();
	$db->connect();
	if ($self->check_result()) { $ok=1; }
	$db->disconnect();
    }

    if (! $ok)  { return 1; }
    return 0;
}

sub new()
{
    my $self;

    my $check;
    my $list;
    my $verbose;
    my $type;
    my $retry;
    my $sleeptime;

    $self=
    {
	check     => $check,
	list      => $list,
	verbose   => $verbose,
	type      => $type,
	retry     => $blockcheckingtime,
	sleeptime => $sleeptime,
	nodelist  => 0,
    };
    bless $self;
    return $self;
}

sub set_check()       { my $self=shift; $self->{check}=1; $self->{list}=0;  }
sub set_list()        { my $self=shift; $self->{list}=1; $self->{check}=0; }
sub set_verbose()     { my $self=shift; $self->{verbose}=1; }
sub set_type_list($)  { my $self=shift; $self->{type_list}=shift; }
sub set_retry($)      { my $self=shift; $self->{retry}=shift; }
sub set_sleeptime($)  { my $self=shift; $self->{sleeptime}=shift; }
sub set_nodelist($)   { my $self=shift; $self->{nodelist}=shift; }


sub get_options_cmdline()
{
    my $self=shift;
    my @node_list;
    my @type_list;
    my $refnode_list;
    my $reftype_list;
    my $check;
    my $list;
    my $retry;
    my $verbose=0;
    my $help=0;

    GetOptions(
	       'check!'               => \$check,
	       'list!'                => \$list,
	       
	       't=s'                  => \@type_list,
	       'type=s'               => \@type_list,
	       
	       'retry=s'              => \$retry,
	       
	       'm=s'                  => \@node_list,
	       'machine=s'            => \@node_list,
	       
	       'h!'                   => \$help,
	       'help!'                => \$help,
	       
	       'v!'                   => \$verbose,
	       'verbose!'             => \$verbose,
	       );
    $refnode_list=\@node_list;
    $self->{node_list}=$refnode_list;

    $self->{nodelist}=libkadeploy2::nodelist::new();
    $self->{nodelist}->loadlist($self->{node_list});


    $reftype_list=\@type_list;
    $self->{type_list}=$reftype_list;
    
    if ($check) { $self->{check}=1; }
    if ($list)  { $self->{list}=1;  }
    
}


sub check_options()
{
    my $self=shift;
    my $ok;

    if ($self->{help}) { $message->kachecknodes_help(); exit 0; }

    if (! $self->{retry}) { $self->set_retry(10); }

    if ($self->{nodelist})
    { }
    elsif($self->{node_list})
    {
	$self->{nodelist}=libkadeploy2::nodelist::new();
	$self->{nodelist}->loadlist($self->{node_list});
    }
    else
    {
	$message->missing_node_cmdline(2);
	return 0;
    }
    return 1;
}


sub check_nodes_services()
{
    my $self=shift;
    my $refnodelist;
    my $nodelist=$self->{nodelist};
    my $reftypelist=$self->{type_list};
    my $ok;
    my $node;
    my $type;
    my $db=libkadeploy2::deploy_iolib::new;

    $refnodelist=$nodelist->get_nodes();

    my @node_list=@$refnodelist;
    my @type_list=@$reftypelist;

    $db->connect();
    foreach $node (@node_list)
    {
	if (@type_list)
	{
	    foreach $type (@type_list)
	    {
		if ($self->{verbose})
		{ $message->message(-1,"checking $type on node ".$node->get_name()); }
		my $check=libkadeploy2::checknodes::new($node,$db);
		if ($self->{verbose}) { $check->set_verbose(); }
		$check->exec($type);
	    }
	}
	else
	{
	    foreach $type (@service_list)
	    {
		if ($self->{verbose})
		{ $message->message(-1,"checking $type on node ".$node->get_name()); }
		my $check=libkadeploy2::checknodes::new($node,$db);
		if ($self->{verbose}) { $check->set_verbose(); }
		$check->exec($type);		
	    }
	}
    }    
    $db->disconnect();
}

sub check_result()
{
    my $self=shift;
    my $service;
    my $ok=1;
    my $node;
    my @node_list;
    my @type_list;
    my $nodelist=$self->{nodelist};
    my $refnodelist;    
    my $reftypelist;
    my $db=libkadeploy2::deploy_iolib::new;

    $reftypelist=$self->{type_list};
    @type_list=@$reftypelist;

    $refnodelist=$nodelist->get_nodes();
    @node_list=@$refnodelist;

    $db->connect();
    foreach $node (@node_list)
    {
	if (@type_list)
	{
	    foreach $service (@type_list)
	    {
		$message->message(-1,$node->get_name()." ".$service." ".$db->get_nodestate($node->get_name(),$service));
		if (! ( $db->get_nodestate($node->get_name(),$service) eq "UP")) { $ok=0; }
	    }
	}
	else
	{
	    foreach $service (@service_list)
	    {
		$message->message(-1,$node->get_name()." ".$service." ".$db->get_nodestate($node->get_name(),$service));
		if (! ( $db->get_nodestate($node->get_name(),$service) eq "UP")) { $ok=0; }
	    }
	}
    }
    $db->disconnect();
    return $ok;
}


1;
