package libkadeploy2::disk;
use strict;
use warnings;
use libkadeploy2::deploy_iolib;
use libkadeploy2::message;
use libkadeploy2::partition;
use libkadeploy2::conflib;
use libkadeploy2::tools;

my $message=libkadeploy2::message::new();

sub get_fromdb($$);
sub get_frompartition($$);

sub new()
{
    my $self;
    my %partitionhash=();
    $self=
    {
	partition => \%partitionhash,
	interface => "unknow",
	size      => 0,
	numberofpartition => 0,
    };
    bless $self;
    return $self;
}

sub loaddisksettingfile($)
{
    my $self=shift;
    my $disksettingfilename=shift;
    my $ok=1;
    my $disksetting=libkadeploy2::conflib::new($disksettingfilename,0);
    $disksetting->load();
    if (
	$disksetting->is_set("interface") &&
	$disksetting->is_set("size")
	)
    {
	$self->set_interface($disksetting->get("interface"));
	$self->set_size(libkadeploy2::tools::translate_to_megabyte($disksetting->get("size")));
    }
    else
    {
	$message->message(2,"$disksettingfilename doesn't contain interface(ide|sata|scsi) or size(200M|30G)");
	$ok=0;
    }
    return $ok
}

sub check()
{
    my $self=shift;
    my $ref_partitionhash=$self->{partition};
    my %partitionhash=%$ref_partitionhash;
    my $ok=1;

    my @listnumber;
    my $linecorrect;
    my $sizeofextended=0;
    my $sizeoflogical=0;
    my $sizeofprimary=0;
    my $numberofprimary=0;
    my $numberofextended=0;
    my $numberoflogical=0;


    foreach my $partnumber ( sort sort_par_num keys %partitionhash)
    { 
	my ($number,$size,$fdisktype,$label,$type)=("","","","","");
	my $part="";
	
	$part=$partitionhash{$partnumber};

	$number=$part->get_number();
	$size=$part->get_size();
	$fdisktype=$part->get_fdisktype();
	$type=$part->get_type();
	$label=$part->get_label();


	if ($numberofextended > 1)   { $message->message(2,"you can only have one extended part"); exit 1; }
	if ($numberofprimary > 4   ) { $message->message(2,"you can only have four primary part"); exit 1; }
	if ($numberofprimary + $numberofextended > 4   ) { $message->message(2,"you can only have four part (primary + extended)"); exit 1; }
	if ($numberofextended == 0 && $numberoflogical > 0 ) 
	{ $message->message(2,"extended partition must be defined before logical"); exit 1; }

	if ($type eq "logical" && $number < 4) { $message->message(2,"logical part begin at 5"); $linecorrect=0;}
	if ($type eq "primary" && $number > 4) { $message->message(2,"primary part must be [1..4]"); $linecorrect=0;}
	if ($type eq "primary") { $numberofprimary++; $sizeofprimary+=$size; }
	if ($type eq "logical") { $sizeoflogical+=$size; $numberoflogical++; }
	if ($type eq "extended") 
	{ 
	    $numberofextended++; $sizeofextended=$size; 
	    if ($number > 4) 
	    { 
		$message->message(2,"extended partition must be in [1..4]"); 
		$linecorrect=0; 
	    }
	}
	foreach my $tmpnumber (@listnumber)
	{
	    if ($tmpnumber==$number) 
	    { $message->message(2,"part=$number alreayd defined"); $linecorrect=0; }
	}
	@listnumber=(@listnumber,$number);
	if ($ok) { $ok=$part->check(); }
    }

    if ($sizeoflogical >= $sizeofextended &&
	$numberofextended > 0 &&
	$numberoflogical  > 0	
	) 
    { 
	$message->message(2,"size of extended part <= size of logical part\nsizeofextended $sizeofextended\nsizeoflogical $sizeoflogical"); 
	$ok=0; 
    }

    return $ok;
}


sub loadpartitionfile($)
{
    my $self=shift;
    my $partitionfile=shift;
    my $line;
    my %disk;
    my %partitions;
    my $ok=1;
    my $linecorrect=0;
    $self->{partition}=\%partitions; 
    
    $message->loadingfile(0,$partitionfile);
    if (open(FH,$partitionfile))
    {
	foreach $line (<FH>)
	{
	    $linecorrect=0;
	    my $part=libkadeploy2::partition::new();
	    if ($line =~ /^part=([0-9]+).+$/)
	    {
		if ($part->load_line($line)) 
		{
		    $self->add_partition($part);
		    $linecorrect=1;
		}
	    }
	    elsif ($line =~ /^$/ ||
		   $line =~ /^\#/)
	    { $linecorrect=1; }

	    if ($linecorrect==0)
	    {
		chomp($line);
		$message->message(2,"line => ".$line."]");
		$ok=0;
	    }
	}
	close(FH);
    }
    else
    {
	$message->loadingfilefailed(2,$partitionfile);
	$ok=0;
    }
    return $ok;
}

sub sort_par_num { return $a <=> $b }

sub print()
{
    my $self=shift;
    my $ok=1;
    my $ref_partitionhash=$self->{partition};
    my %partitionhash=%$ref_partitionhash;
    
    foreach my $partnumber ( sort sort_par_num keys %partitionhash)
    { 
	my $parthash=$partitionhash{$partnumber};
	if (!$parthash->print()) { $ok=0; }
    }
    return $ok;
}

sub set_interface($)
{
    my $self=shift;
    my $interface=shift;
    $self->{interface}=$interface;
}

sub set_size($)
{
    my $self=shift;
    my $size=shift;
    $self->{size}=$size;
}

sub get_interface()
{
    my $self=shift;
    return $self->{interface};
}

sub get_size()
{
    my $self=shift;
    return $self->{size};
}


sub get_fromdb($$)
{
    my $self=shift;
    my $nodename=shift;
    my $disknumber=shift;
    my $nodeid;
    my $db;
    my $diskid;
    my %info;
    my $refinfo;
    my $reflistpartitionid;
    my @listpartitionid;
    my $partitionid;
    my $ok=0;
    my $firstpass=1;

    $db = libkadeploy2::deploy_iolib::new();
    $db->connect();
    $nodeid=$db->node_name_to_id($nodename);
    if ($nodeid)
    {
	$diskid=$db->get_diskid_from_nodeid_disknumber($nodeid,$disknumber);
	if ($diskid)
	{
	    $refinfo=$db->get_diskinfo_from_diskid($diskid);
	    %info=%$refinfo;
	    $self->set_interface($info{interface});
	    $self->set_size($info{size});
			   

	    $reflistpartitionid=$db->get_listpartitionid_from_diskid($diskid);
	    @listpartitionid=@$reflistpartitionid;
	    foreach $partitionid    (@listpartitionid)
	    {
		$refinfo=$db->get_partitioninfo_from_partitionid($partitionid);
		%info=%$refinfo;

		my $part=libkadeploy2::partition::new();

		$part->set_type($info{parttype});	
		$part->set_number($info{pnumber});
		$part->set_size($info{size});
		$part->set_label($info{label});
		$part->set_fdisktype($info{fdisktype});
		$part->set_ostype($info{ostype});
		$part->set_mkfs($info{mkfs});
		$part->set_fs($info{fs});

		if ($firstpass && $ok==0) { $ok=1; }
		if ($self->add_partition($part) && $ok)  { $ok=1; }
		else { $ok=0; }
	    }
	}   
	else
	{
	    $message->message(-1,"Disk $disknumber not found in db");
	    $ok=0;
	}
    }
    else
    {
	$message->message(2,"Node $nodename not found in db");
	$ok=0;
    }
    return $ok;
}

sub add_partition($)
{
    my $self=shift;
    my $partition=shift;
    my $ok=1;

    my %partitionhash;
    my $ref_partitionhash;
    $ref_partitionhash=$self->{partition};
    %partitionhash=%$ref_partitionhash;
    $partitionhash{$partition->get_number()}=$partition;
    $ref_partitionhash=\%partitionhash;
    $self->{partition}=$ref_partitionhash;

    if ($partition->get_number() > $self->{numberofpartition})
    { $self->{numberofpartition}= $partition->get_number(); }

    return $ok;
}

sub get_numberofpartition()
{
    my $self=shift;
    return $self->{numberofpartition};
}

sub addtodb($$)
{
    my $self=shift;
    my $nodename=shift;
    my $disknumber=shift;
    my $ok=0;
    if ($self->adddisktodb($nodename,$disknumber) &&
	$self->addpartitiontodb($nodename,$disknumber)
	)
    { $ok=1; 	}

    return $ok;
}

sub adddisktodb($$)
{
    my $self=shift;
    my $nodename = shift;
    my $disknumber = shift;
    my $tmphash1;
    my $size;
    my $interface;
    my $key1;
    my $db;
    my $nodeid;
    my @info;
    my $ok;
    my $disk_id;

    $ok=0;

    $size=$self->{size};
    $interface=$self->{interface};

    if ($size && $interface)
    {
	$db=libkadeploy2::deploy_iolib::new();
	$db->connect();
	$nodeid=$db->node_name_to_id($nodename);
	if (! $nodeid) { $ok=0; }
	else
	{
	    @info = ($disknumber,$interface,$size,$nodeid);
	    $disk_id = $db->add_disk(\@info);
	    if ($disk_id) { $ok=1; }
	}
	$db->disconnect();    
    }

    if ($ok)
    { 	$message->message(0,"Register $interface harddisk $disknumber for node $nodename");     }
    else
    {  	$message->message(0,"Fail to register $interface harddisk $disknumber for node $nodename");     }

    return $ok;
}


sub addpartitiontodb($$)
{
    my $self=shift;
    my $nodename = shift;
    my $disknumber = shift;
    my $ok=0;

    my $ref_partitionhash=$self->{partition};
    my %partitionhash=%$ref_partitionhash;
    foreach my $partnumber ( keys %partitionhash)
    { 
	my $parthash=$partitionhash{$partnumber};
	$ok=$parthash->addtodb($nodename,$disknumber);
    }
    return $ok;
}

sub get_frompartition($$)
{
    my $self=shift;
    my $partnumber=shift;
    my $info=shift;
    my $ret=0;

    my $ref_partitionhash;
    my %partitionhash;
    my $parthash;

    if ($partnumber)
    {
	$ref_partitionhash=$self->{partition};
	%partitionhash=%$ref_partitionhash;
	$parthash=$partitionhash{$partnumber};
	$ret=$parthash->{$info};
    }
    else
    {
	$ret=0;
    }
    return $ret;
}



1;
