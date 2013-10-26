package libkadeploy2::checknodes;

use libkadeploy2::remotecommand;
use libkadeploy2::message;
use libkadeploy2::node;
use libkadeploy2::nmap;

use warnings;
use strict;

my $message=libkadeploy2::message::new();

sub new($$)
{
    my $node=shift;
    my $db=shift;
    my $self;
    $self=
    {
	db   => $db,
	node => $node,
	verbose => 0,
    };
    bless $self;
    return $self;
}

sub set_verbose()  { my $self=shift; $self->{verbose}=1; }

sub exec($)
{
    my $self=shift;
    my $checktype=shift;
    my $node=$self->{node};
    my $db=$self->{db};
    my $correctcheck=0;
    my $ok=0;
    if ($checktype eq "ICMP")     { $correctcheck=1; $self->check_node_icmp(); }
    if ($checktype eq "SSH")      { $correctcheck=1; $self->check_node_ssh();  }
    if ($checktype eq "MCAT")     { $correctcheck=1; $self->check_node_mcat(); }
    if ($correctcheck)
    {
	$ok=1;
    }
    else
    {
	$message->message(2,"checktype : $checktype doesn't exist");
	$ok=0;
    }
    return $ok;
}

sub check_node_icmp()
{
    my $self=shift;
    my $node=$self->{node};
    my $db=$self->{db};
    
    my $nmap=libkadeploy2::nmap::new();
    if ($nmap->check_icmp($node->get_ip()))
    {
	$db->update_nodestate($node->get_name(),"ICMP","UP");
    }
    else
    {
	$db->update_nodestate($node->get_name(),"ICMP","DOWN");
    }    
}

sub check_node_ssh()
{
    my $self=shift;
    my $node=$self->{node};
    my $db=$self->{db};

    my $nmap=libkadeploy2::nmap::new();
    if ($nmap->check_tcp($node->get_ip(),22))
    {
	$db->update_nodestate($node->get_name(),"SSH","UP");
    }
    else
    {
	$db->update_nodestate($node->get_name(),"SSH","DOWN");
    }   

}


sub check_node_mcat()
{
    my $self=shift;
    my $node=$self->{node};
    my $db=$self->{db};
    my $ok=0;
    my $remotecommand=libkadeploy2::remotecommand::new("ssh",
						       "root",
						       $node,
						       "which mcatseg",
						       60,
						       $self->{verbose},
						       );
    $remotecommand->exec();
    if ($remotecommand->get_status())     
    {  	
	$ok=1;    
	$db->update_nodestate($node->get_name(),"MCAT","UP");
	$remotecommand=libkadeploy2::remotecommand::new("ssh",
							"root",
							$node,
							"pkill mcatseg",
							60,
							$self->{verbose},
							);
	$remotecommand->exec();
    }
    else
    {
	$db->update_nodestate($node->get_name(),"MCAT","DOWN");
    }
    return $ok;
}
    
