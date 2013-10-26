package libkadeploy2::ntldr;

use strict;
use warnings;
use libkadeploy2::message;

my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }
my $kadeploydir=$conf->get("kadeploy2_directory");
my $message=libkadeploy2::message::new();
my $tftproot=$conf->get("tftp_repository");
my $ntbootdisk="ntldr.img";
my $bootiniref="$kadeploydir/lib/floppy/windows/boot.ini";
my $ntldrfactory=$conf->getpath_cmd("factory_windows");
my $sourcewindowsfloppy="$kadeploydir/lib/floppy/windows/ntldr.img";

sub new()
{
    my $self;
    $self=
    {
	nodelist         => 0,
	windowsdirectory => "WINDOWS",
	partnumber       => 0,
	disknumber       => 0,	
    };
    bless $self;
    return $self;
}

sub set_nodelist($)            { my $self=shift; $self->{nodelist}=shift; }
sub set_disknumber($)          { my $self=shift; $self->{disknumber}=shift; }
sub set_partnumber($)          { my $self=shift; $self->{partnumber}=shift;  }
sub set_windowsdirectory($)    { my $self=shift; $self->{windowsdirectory}=shift;  }

sub readbootinicfg()
{
    my $self=shift;
    my $nodelist=$self->{nodelist};
    my $node;
    my $ref_node_list;
    my @node_list;
    my $node_name;
    my $node_hexip;
    my $line;
    my $bootinipath;
    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;

    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	$message->message(-1,"show boot.ini of $node_name");
	$bootinipath="$tftproot/$node_name/boot.ini";
	open(BOOTINI,$bootinipath) or die "can't open $bootinipath";
	while ($line=<BOOTINI>) { print $line; }
	close(BOOTINI);
    }
}

sub writepxewindowsfloppy()
{
    my $self=shift;
    my $nodelist=$self->{nodelist};
    my $node;
    my $ref_node_list;
    my @node_list;
    my $dest;
    my $node_name;
    my $line;
    my $menudest;
    my $destfloppy;
    my $bootini;

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;
    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	$destfloppy="$tftproot/$node_name/$ntbootdisk";
	$bootini="$tftproot/$node_name/boot.ini";

	$message->message(0,"tftp boot modified for $node_name");

	system("cp $bootiniref $bootini");
	system("sed -i -e 's/WINNT/".uc($self->{windowsdirectory})."/g' $bootini");
	system("sed -i -e 's/partition(0)/partition(".$self->{partnumber}.")/g' $bootini");

	system("$ntldrfactory -s $sourcewindowsfloppy -d $destfloppy -m $bootini");
    }
}




1;
