package libkadeploy2::fdiskscript;
use strict;
use warnings;

sub new()
{
    my $self;
    $self=
    {
    };
    bless $self;
    return $self;    
}

sub loaddisk();
sub printfdiskdeleteprimary();
sub printfdiskformat();
sub printfdiskwrite();
sub print();

sub set_disk($)
{
    my $self=shift;
    my $disk=shift;
    $self->{disk}=$disk;
    return 1;
}

sub print()
{
    my $self=shift;
    $self->printfdiskdeleteprimary();
    $self->printfdiskformat();
    $self->printfdiskwrite();
}

sub printfdiskdeleteprimary()
{
    print "o
";
}



sub printfdiskwrite()
{
    print "p
w
";
}

sub sort_par_num { return $a <=> $b }

sub printfdiskformat()
{
    my $self=shift;
    my $diskref=$self->{disk};

    my $key1;
    my $key2;
    my $key3;
    my $key4;
    my $tmphash1;
    my $tmphash2;
    my $tmphash3;
    
    my $type;
    my $partnumber;
    my $size;
    my $fdisktype;
        
    
    my $ref_partitionhash=$diskref->{partition};
    my %partitionhash=%$ref_partitionhash;
    
    foreach my $partnumber ( sort sort_par_num keys %partitionhash)
    { 
	my $parthash=$partitionhash{$partnumber};
	my $size=$parthash->get_size();
	my $partnumber=$parthash->get_number();       
	my $fdisktype=$parthash->get_fdisktype();
	my $longtype=$parthash->get_type();
	my $type="";

	$size=int($size/1.1); #Stupid hack for fdisk because of this fucking 1000 and 1024 ...
	$size="+".$size."M";

	if    ($longtype eq "primary")  { $type="p"; }
	elsif ($longtype eq "extended") { $type="e"; }
	elsif ($longtype eq "logical")  { $type="l"; }
	
	if ($type eq "p" ||
	    $type eq "e")
	{
	    if ($partnumber!=4)
	    {		
		print "n
$type
$partnumber

$size
";
	    }
	    else
	    {			    
		print "n
$type

$size
";		    
	    }		    
	}		
	if ($type eq "l")
	{
	    print "n
$type

$size
";			
	}
	if (!($type eq "e"))
	{
	    if ($partnumber==1)
	    {
		print "t
$fdisktype
";
	    }
	    else
	    {
		print "t
$partnumber
$fdisktype
";
	    }
	    
	}
    }
}


####
#     foreach $key1 (sort keys %disk)
#     {
# 	$tmphash1 = $disk{$key1};
# 	if (ref($tmphash1) eq 'HASH')
# 	{
# 	    foreach $key2 (sort sort_par_num keys %$tmphash1)
# 	    {
# #		print "\t$key1=$key2\n";
# 		$partnumber=$key2;
# 		$tmphash2 = $$tmphash1{$key2};
# 		if (ref($tmphash2) eq 'HASH')
# 		{
# 		    foreach $key3 (sort keys %$tmphash2) 
# 		    {
# 			if ($key3 eq "number")
# 			{
# 			    $partnumber=$$tmphash2{$key3};
# 			}
# 			if ($key3 eq "fdisktype")
# 			{
# 			    $fdisktype=$$tmphash2{$key3}
# 			}
# 			if ($key3 eq "size")
# 			{			    
# 			    $size=$$tmphash2{$key3};
# 			    $size=int($size/1.1); #Stupid hack for fdisk because of this fucking 1000 and 1024 ...
# 			    $size="+".$size."M";
# 			}
# 			if ($key3 eq "type")
# 			{
# 			    if ($$tmphash2{$key3} eq "primary")
# 			    {
# 				$type="p";
# 			    }
# 			    if ($$tmphash2{$key3} eq "extended")
# 			    {
# 				$type="e";
# 			    }
# 			    if ($$tmphash2{$key3} eq "logical")
# 			    {
# 				$type="l";
# 			    }


# 			}
# #			print "\t\t$key3=".$$tmphash2{$key3}."\n";			
# 		    }
# 		    if ($type eq "p" ||
# 			$type eq "e")
# 		    {
# 			if ($partnumber!=4)
# 			{
			    
# 			    print "n
# $type
# $partnumber

# $size
# ";
# 			}
# 			else
# 			{			    
# 			    print "n
# $type

# $size
# ";		    
# 			}		    
# 		    }		
# 		    if ($type eq "l")
# 		    {
# 			print "n
# $type

# $size
# ";			
# 		    }
# 		    if (!($type eq "e"))
# 		    {
# 			if ($partnumber==1)
# 			{
# 			    print "t
# $fdisktype
# ";
# 			}
# 			else
# 			{
# 			    print "t
# $partnumber
# $fdisktype
# ";
# 			}
# 		    }
# 		}
# 	    }
# 	}
# 	else
# 	{
# #	    print "$key1=$disk{$key1}\n";
# 	}
#     }
#   
#}


1;
