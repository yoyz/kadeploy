package libkadeploy2::hexlib;

sub hexalize($) 
{
    my $number = shift;
    if ($number<16) {
	return (sprintf "0%X", $number);
    } else {
	return (sprintf "%X", $number);
    }
}

sub unhexalize($)
{
    my $number = shift;
    return hex($number);
}

sub gethostipx($)
{
    my $ip = shift;
    
    if ($ip =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/)
      {
	 my $iphexalized=libkadeploy2::hexlib::hexalize($1) .
	    libkadeploy2::hexlib::hexalize($2) .
	    libkadeploy2::hexlib::hexalize($3) .
	    libkadeploy2::hexlib::hexalize($4);
    
	 return ($iphexalized);
      }
    else
      {
        libkadeploy2::debug::debugl(3, "$ip : wrong IP syntax.\n");
        return 0;	  
      }
    
}

1;
