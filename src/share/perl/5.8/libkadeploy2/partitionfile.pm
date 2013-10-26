package libkadeploy2::partitionfile;
use libkadeploy2::deploy_iolib;
use strict;
use warnings;

#sub loadpartitionfile($)




sub checkcorrectness($)
{
    my $diskref=shift;
    my %disk=%$diskref;    
    my $key1;
    my $key2;
    my $key3;
    my $key4;
    my $tmphash1;
    my $tmphash2;
    my $tmphash3;
    
    my $numberofprimarypart=0;
    my $numberofextendedpart=0;
    my $numberoflogicalpart=0;
    my $sizeoflogical=0;
    my $sizeofprimary=0;
    my $sizeofdisk=0;
    my $actualpartnumber=0;
    #disk 
    foreach $key1 (sort keys %disk)
    {
	$tmphash1 = $disk{$key1};
	if (ref($tmphash1) eq 'HASH')
	{
	    #partition
	    foreach $key2 (sort keys %$tmphash1)
	    {
		$tmphash2 = $$tmphash1{$key2};		
		$actualpartnumber=$key2;
		if (ref($tmphash2) eq 'HASH')
		{
		    #attribute of partition
		    foreach $key3 (sort keys %$tmphash2) 
		    {
			if ($$tmphash2{$key3} eq "primary")
			{
			    $numberofprimarypart++;			    
			}
			if ($$tmphash2{$key3} eq "extended")
			{
			    $numberofextendedpart++;
			}
			if ($$tmphash2{$key3} eq "logical")
			{
			    $numberoflogicalpart++;
			}
			if ($actualpartnumber<5 &&
			    ($key3 eq "size")
			    )
			    
			{
			    $sizeofprimary+=$$tmphash2{$key3};
			}
			if ($actualpartnumber>=5 &&
			    ($key3 eq "size")			    
			    )
			{
			    $sizeoflogical+=$$tmphash2{$key3};
			}			
		    }
		}
	    }
	}
	else
	{
	    if ($key1 eq "size")
	    {
		$sizeofdisk=$disk{$key1};
	    }
	}
    }
    if ($numberofprimarypart + $numberofextendedpart > 4)
    {
	print STDERR "Error too much primary or extended partition.\n";
	exit 1;
    }
    if ($sizeofdisk<$sizeofprimary ||
	$sizeofdisk<$sizeoflogical)
    {
	print STDERR "Error size of disk < size of partition\n";
	exit 1;
    }

print STDERR "primary part                  : $numberofprimarypart\n";
print STDERR "extended part                 : $numberofextendedpart\n";
print STDERR "logical part                  : $numberoflogicalpart\n";
print STDERR "size of disk                  : $sizeofdisk\n";    
print STDERR "size of primary and extended  : $sizeofprimary\n";    
print STDERR "size of logical               : $sizeoflogical\n";    

}




1;
