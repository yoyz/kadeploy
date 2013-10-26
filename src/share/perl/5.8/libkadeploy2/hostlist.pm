package libkadeploy2::hostlist;

use strict;
use warnings;

sub new()
{
    my $self;
    my @hostlist=();
    my $refToHostlist=\@hostlist;
    $self=
    {
	hostlist => $refToHostlist,
    }
    bless $self;
    return $self;
}

sub add($)
{
    my $self=shift;
    my $host=shift;
    my $refHostList;
    $self->{hostlist}=$
}
