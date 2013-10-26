package libkadeploy2::hexlib;
use strict;
use warnings;

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

sub hexalizeip($)
{
    my $ip=shift;
    my $iphex=0;
    my $ip1;
    my $ip2;
    my $ip3;
    my $ip4;
    if ($ip =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/)
    {
	($ip1,$ip2,$ip3,$ip4)=($1,$2,$3,$4);
#	print $ip1;
	$ip1=libkadeploy2::hexlib::hexalize($ip1);
	$ip2=libkadeploy2::hexlib::hexalize($ip2);
	$ip3=libkadeploy2::hexlib::hexalize($ip3);
	$ip4=libkadeploy2::hexlib::hexalize($ip4);
	$iphex=$ip1.$ip2.$ip3.$ip4;	
    }
    return $iphex;
}
1;
