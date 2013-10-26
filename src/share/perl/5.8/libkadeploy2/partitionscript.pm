package partitionscript;

sub new()
{
    
}

sub printfdiskdeleteprimary();
sub printfdiskformat();
sub printfdiskwrite();


sub printfdiskdeleteprimary()
{
    print "d
1
d
2
d
3
d
4
";
}



sub printfdiskwrite()
{
    print "p
w
";
}


sub printfdiskformat($)
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
    
    my $type;
    my $partnumber;
    my $size;
    my $fdisktype;
        
    my $fdiskversion="2.12";
    
    print STDERR "WARNING this script work only with fdisk 2.12\n";

    foreach $key1 (sort keys %disk)
    {
	$tmphash1 = $disk{$key1};
	if (ref($tmphash1) eq 'HASH')
	{
	    foreach $key2 (sort sort_par_num keys %$tmphash1)
	    {
#		print "\t$key1=$key2\n";
		$partnumber=$key2;
		$tmphash2 = $$tmphash1{$key2};
		if (ref($tmphash2) eq 'HASH')
		{
		    foreach $key3 (sort keys %$tmphash2) 
		    {
			if ($key3 eq "number")
			{
			    $partnumber=$$tmphash2{$key3};
			}
			if ($key3 eq "fdisktype")
			{
			    $fdisktype=$$tmphash2{$key3}
			}
			if ($key3 eq "size")
			{			    
			    $size=$$tmphash2{$key3};
			    $size=int($size/1.1); #Stupid hack for fdisk because of this fucking 1000 and 1024 ...
			    $size="+".$size."M";
			}
			if ($key3 eq "type")
			{
			    if ($$tmphash2{$key3} eq "primary")
			    {
				$type="p";
			    }
			    if ($$tmphash2{$key3} eq "extended")
			    {
				$type="e";
			    }
			    if ($$tmphash2{$key3} eq "logical")
			    {
				$type="l";
			    }


			}
#			print "\t\t$key3=".$$tmphash2{$key3}."\n";			
		    }
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
	}
	else
	{
#	    print "$key1=$disk{$key1}\n";
	}
    }
    
}


1;
