package libkadeploy2::nmap;
use strict;
use warnings;
use libkadeploy2::deployconf;

my $conf=libkadeploy2::deployconf::new();
if (! $conf->load()) { exit 1; }
my $nmappath=$conf->get("nmap_cmd");

sub new()
{
    my $self;
    $self=
    {
    };
    bless $self;
    return $self;
}

sub check_tcp($$)
{
    my $self = shift;

    my $hostip=shift;
    my $port=shift;
    
    my $line;
    my $nmapcmd;
    my $ok=0;

    $nmapcmd="$nmappath --system-dns -p $port -oG - $hostip";

    open(NMAPCMD, "$nmapcmd |");
    while ($line=<NMAPCMD>)
    {
	if ($line=~ /^Host: $hostip \(.*\)[\s\t]+Ports: $port\/open\//)
	{
	    $ok=1;
	}
    }
    close(NMAPCMD);
    return $ok;
}

sub check_icmp($)
{
    my $self = shift;

    my $hostip=shift;

    my $line;
    my $ok=0;
    my $nmapcmd;

    $nmapcmd="$nmappath --system-dns -sP -oG - $hostip";
    open(NMAPCMD, "$nmapcmd|");
    while ($line=<NMAPCMD>)
    {
	if ($line=~ /^Host: $hostip \(.*\)[\s\t]+Status:[\s]Up/)
	{
	    $ok=1;

	}
    }
    close(NMAPCMD);
    return $ok;
}


1;
