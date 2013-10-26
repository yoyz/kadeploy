package libkadeploy2::partition;

use strict;
use warnings;
use libkadeploy2::message;
use libkadeploy2::deploy_iolib;
use libkadeploy2::tools;
my $message=libkadeploy2::message::new();

sub new()
{
    my $self;
    $self=
    {
	number    => 0,   # 1-99
	size      => 0,   #2000
	type      => "",  #primary, logical, extended, slice
	label     => "",  #/usr
	fdisktype => "",  #83,82,a6...
	fs        => "",  #ext2, ext3, ffs, ufs...
	mkfs      => "no",
	ostype    => "",
    };
    bless $self;
    return $self;
}

sub get_number()      { my $self=shift; return $self->{number}; }
sub get_type()        { my $self=shift; return $self->{type}; }
sub get_size()        { my $self=shift; return $self->{size}; }
sub get_label()       { my $self=shift; return $self->{label}; }
sub get_fdisktype()   { my $self=shift; return $self->{fdisktype}; }
sub get_fs()          { my $self=shift; return $self->{fs}; }
sub get_mkfs()        { my $self=shift; return $self->{mkfs}; }
sub get_ostype()      { my $self=shift; return $self->{ostype}; }



sub set_number($)        { my $self=shift; $self->{number}=shift; }

sub set_mkfs($)          
{ 
    my $self=shift; 
    my $mkfs=shift; 
    my $ok=0;
    if ($mkfs =~ /(\d+)/) 
    { 	if ($mkfs) { $self->{mkfs}="yes"; }
	else       { $self->{mkfs}="no"; }
	$ok=1;
    }
    elsif ($mkfs eq "no")
    {
	$self->{mkfs}="no";
	$ok=1;
    }
    elsif ($mkfs eq "yes")
    {
	$self->{mkfs}="yes";
	$ok=1;
    }
    return $ok;
}

sub set_fs($)            
{ 
    my $self=shift; 
    my $fs=shift;
    my $ok=0;
    if ($fs =~ /ext2|ext3|vfat|swap|ufs|ffs/)
    {
	$self->{fs}=$fs;	
	$ok=1;
    }
    return $ok;
}

sub set_ostype($)
{
    my $self=shift;
    my $ostype=shift;
    my $ok=0;
    if ($ostype =~ /linux|windows|netbsd|freebsd|openbsd|dos/i) 
    { 
	$ok=1; 
	$self->{ostype}=lc($ostype);
    }
    if ( ! $self->get_fdisktype())
    {
	if ($ostype =~ /linux/  )
	{ $self->set_fdisktype("83"); }
	elsif ($ostype =~ /netbsd/)
	{ $self->set_fdisktype("a9"); }
	elsif ($ostype =~ /freebsd/)
	{ $self->set_fdisktype("a5"); }
	elsif ($ostype =~ /openbsd/)
	{ $self->set_fdisktype("a6"); }
	elsif ($ostype =~ /windows/)
	{ $self->set_fdisktype("c"); }	
    }
    return $ok;
}


sub set_size($)
{ 
    my $self=shift; 
    my $size=shift;
    my $Msize=0;
    my $ok=1;

    $Msize=libkadeploy2::tools::translate_to_megabyte($size);
    if ($Msize) { $self->{size}=$Msize; }
    else { $ok=0; }
    return $ok;
}

sub set_type($)       
{ 
    my $self=shift; 
    my $type=shift;
    my $ok=0;


	
    if ($type &&
	(
	 $type eq "primary"  ||
	 $type eq "extended" ||
	 $type eq "logical"  ||
	 $type eq "slice"    
	 )
	)
    {
	$self->{type}=$type;
	$ok=1;
    }
    return $ok;
}


sub set_fdisktype($)     
{ 
    my $self=shift; 
    my $fdisktype=shift;
    my $ok=0;
    if ($fdisktype =~ /^[a-fA-F0-9]$/ ||
	$fdisktype =~ /^[a-fA-F0-9][a-fA-F0-9]$/
	)
    {
	$self->{fdisktype}=uc($fdisktype);
	$ok=1;
    }
    return $ok;
}

sub set_label($)         
{ 
    my $self=shift; 
    my $label=shift; 
    my $ok=0;

    if ($label =~ /\//     ||
	$label eq "swap" 
	)
    {
	$self->{label}=$label;
	$ok=1;
    }
    elsif ($label =~ // ||
	   $label eq "unknow" ||
	   $label eq "empty")
    {
	$self->{label}="unknow";
	$ok=1;
    }

    return $ok;
}


sub message_checkfailed($)
{
    my $self=shift;
    my $msg=shift;
    $message->message(2,$msg." =>".
		      " part=".$self->get_number().
		      " type == extended ".
		      " fs=".$self->get_fs().
		      " fdisktype=".$self->get_fdisktype().
		      " label=".$self->get_label().
		      " mkfs=".$self->get_mkfs().
		      " ostype=".$self->get_ostype().
		      " (partition::check)");    
}

sub check()
{
    my $self=shift;
    my $ok=1;

    if ($self->get_number()==0) 
    { $message->message(2,"number == 0 (partition::check)"); $ok=0; }

    if ($self->get_size()==0) 
    { $message->message(2,"size == 0 (partition::check)"); $ok=0; }   


    if ($self->get_type() eq "")
    {
	$self->message_checkfailed("type == \"\" !!! ");
	$ok=0;
    }	
    elsif ($self->get_type() eq "extended")
    {
	
	if (
	    $self->get_fs()        || 
	    $self->get_fdisktype() ||
	    $self->get_ostype()   
	    )
	{ $self->message_checkfailed("fs|fdisktype|ostype && extended"); $ok=0; }	
    }
    elsif ($self->get_type() eq "primary" ||
	   $self->get_type() eq "logical")
    {
	if ( ! $self->get_label())
	{ $self->set_label("unknow"); }
    }
    else
    { $self->message_checkfailed("type=primary|extended|logical"); $ok=0;  }

    if (
	(
	 $self->get_fdisktype() eq "83" ||
	 $self->get_fdisktype() eq "82"
	 ) &&
	! $self->get_ostype()
	)
    {
	$self->set_ostype("linux");
    }
#    print STDERR $self->get_number()." ".$self->get_ostype()."\n";

	

    
    #LINUX
    if ($self->get_ostype() eq "linux")
    {

	if ($self->get_label()  eq "swap" &&
	    !($self->get_fs() eq "swap")
	    )
	{ $self->message_checkfailed("label=swap fs!=swap"); $ok=0; }


	#Help user
	if (! $self->get_fdisktype())
	{ $self->set_fdisktype("83"); }

	if ($self->get_label() eq "swap")
	{ 
	    $self->set_fs("swap"); 
	}

	if ($self->get_fs() eq "swap")
	{
	    $self->set_mkfs("yes");
	    $self->set_label("swap");
	}
	
	if ($self->get_fs() eq "swap" &&
	    $self->get_fdisktype != 82)
	{ $self->message_checkfailed("fs=swap && fdisktype!=82"); $ok=0; }
	
	
	#check
	if (!( $self->get_fdisktype eq "83" || 
	       $self->get_fdisktype eq "82" 
	       ))	    
	{ $message->message(0,"ostype=linux && fdisktype=".$self->get_fdisktype); $ok=0; }


	if (!($self->get_fs() =~ /ext2|ext3|swap/))
	{ $message->message(0,"part=".$self->get_number()." fs!=(ext2|ext3) : [".$self->get_fs()."]"); $ok=0; }

    }
    if ($self->get_fdisktype eq "83")
    {
	if (! $self->get_fs()) { $self->set_fs("ext2"); }
	if (! $self->get_ostype()) { $self->set_ostype("linux"); }
    }
    if ($self->get_fdisktype eq "82")
    {
	if (! $self->get_ostype()) { $self->set_ostype("linux"); }
	if (! $self->get_fs())     { $self->set_fs("swap"); }
	
    }
    if ($self->get_fs =~ /ext2|ext3/)
    {
	if (! $self->get_ostype()) { $self->set_ostype("linux"); }
    }


    #OPENBSD
    if ($self->get_ostype() eq "openbsd" &&
	! ( $self->get_fdisktype eq "A6"))
    { $message->message(0,"ostype=openbsd && fdisktype=".$self->get_fdisktype); $ok=0; }  

    return $ok;
}


sub get_line()
{
    my $self=shift;
    my $partline;
    my $ok=$self->check();
    
    if ($ok)
    {
	$partline="part=".$self->get_number()." ";
	$partline.="mkfs=".$self->get_mkfs()." "; 

	if ($self->get_size())        { $partline.="size=".$self->get_size()." "; }
	if ($self->get_type())        { $partline.="type=".$self->get_type()." "; }
	if ($self->get_ostype())      { $partline.="ostype=".$self->get_ostype()." "; }
	if ($self->get_fdisktype())   { $partline.="fdisktype=".$self->get_fdisktype()." "; }
	if ($self->get_label())       { $partline.="label=".$self->get_label()." "; }
	if ($self->get_fs())          { $partline.="fs=".$self->get_fs()." "; }

	return $partline;
    }
    else
    {
	$message->message(2,"check failed (partition::get_line)");
    }
    return $ok; 

}

sub print()
{
    my $self=shift;
    my $partline;
    my $ok=0;

    $partline=$self->get_line();

    if ($partline 
	)
    {
	print "$partline\n";
	$ok=1;
    }
    return $ok; 
}

sub load_line($)
{
    my $self=shift;
    my $line=shift;
    my $ok=1;

    my $partnumber;
    my $size;

    if ($line =~ /^part=([0-9]+)[\t\s]+/)
    {
	$partnumber=$1;
	$self->set_number($partnumber);

	if ($line =~ /size=([0-9]+)/ ||
	    $line =~ /size=([0-9]+)([kKmMgG])/)
	{  if ($2) { $self->set_size("$1"."$2"); } else { $self->set_size($1); } }
	
	if ($line =~ /[\s\t]fdisktype=([0-9a-zA-Z]+)/)
	{ $self->set_fdisktype($1); }
	
	if ($line =~ /[\s\t]label=([\/a-zA-Z]+)/)
	{ $self->set_label($1); }
	
	if ($line =~ /[\s\t]type=([a-zA-Z]+)/)
	{ $self->set_type($1); }

	if ($line =~ /[\s\t]ostype=([a-zA-Z0-9]+)/)
	{ $self->set_ostype($1); }

	if ($line =~ /[\s\t]fs=([a-zA-Z0-9]+)/)
	{ $self->set_fs($1);  }
	
	if ($line =~ /[\s\t]mkfs=([01]|yes|no)/)
	{ $self->set_mkfs($1);  }
	
    }
    else
    {
	$ok=0;
    }
    if ($ok)
    {
	$ok=$self->check();
    }
    return $ok;
}
	
sub addtodb($$)
{
    my $self=shift;
    my $nodename = shift;
    my $disknumber = shift;
    my $key1;
    my $key2;
    my $key3;
    my $key4;
    my $tmphash1;
    my $tmphash2;
    my $tmphash3;
    my $nodeid;
    my $db;
    my $diskid;
    my @info;
    my $size;
    my $part_id;
    
    my $fdisktype;
    my $label;
    my $number;
    my $type;
    my $ok;
    my $hashpart;
    if ($self->check())
    {
	$db = libkadeploy2::deploy_iolib::new();
	$db->connect();
	$nodeid=$db->node_name_to_id($nodename);
	$diskid=$db->nodename_disknumber_to_diskid($nodename,$disknumber);
	$part_id = $db->add_partition($diskid,$self);
	if ($part_id) { $message->message(0,"Registring partition ".$self->get_number." for disk $disknumber of node $nodename"); }
	else          { $message->message(2,"Fail to register partition $number for disk $disknumber of node $nodename"); }
	if ($part_id) {$ok=1; } else { $ok=0; }
	$db->disconnect();
    }
    return $ok;
}

sub getfromdb($$$)
{
    my $self=shift;
    my $nodename=shift;
    my $disknumber=shift;
    my $partnumber=shift;
    my $partinfo;
    my ($nodeid,$diskid,$partid);

    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();

	
    $nodeid=$db->node_name_to_id($nodename);
    $diskid=$db->nodename_disknumber_to_diskid($nodename,$disknumber);
    $partid=$db->diskidpartnumber_to_partitionid($diskid,$partnumber);
    $partinfo=$db->get_partitioninfo_from_partitionid($partid);
    if ($partinfo)
    {
	$self->set_number($partinfo->{pnumber});
	$self->set_size($partinfo->{size});
	$self->set_type($partinfo->{parttype});
	$self->set_fdisktype($partinfo->{fdisktype});
	$self->set_ostype($partinfo->{ostype});
	$self->set_label($partinfo->{label});
	$self->set_fs($partinfo->{fs});
	$self->set_mkfs($partinfo->{mkfs});
    }
    $db->disconnect();
}


1;
