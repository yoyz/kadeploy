package libkadeploy2::pathlib;

use strict;
use warnings;
use libkadeploy2::debug;

sub strip_leading_slash($)
{
    my $f=shift;
    
    $f =~ s/^\///;
    return($f);
}

sub strip_leading_dirs($)
{
    my $f=shift;
    if (!libkadeploy2::pathlib::is_valid($f)) {
	return ("");
    } else {
	$f =~ s/.*\/([^\/]*)$/$1/;
	return($f);
    }
}

sub strip_dotdot($)
{
    my $f=shift;
      
    $f =~ s/^[\.\/]*(.*)$/$1/;
    return($f);
}

sub get_leading_dirs($)
{
    my $f=shift;
    
    if ($f =~ m/[^\/]*\/.*/) {
	$f =~ s/(^[\/a-zA-Z0-9\-\._]*)\/[^\/]+/$1/;
	return($f);
    } else {
	return ("");
    }
}

sub get_subdir_root($)
{
    my $f=shift;
    
    $f =~ s/^([^\/]+)\/.*$/$1/;
    return($f);
}

sub check_multiboot($)
{
    my $k = shift;
    
    if ( $k =~ m/mboot\.c32/ ) {
	return 1;
    } else {
	return 0;
    }
}

sub is_valid($)
{
    my $f=shift;
    
    if (defined($f)) {
	if ( (!($f =~ m/^$/)) && (!($f =~ m/^[ ]+$/)) ) {
	    return 1;
	} else {
	    return 0;
	}
    } else {
	return 0;
    }	
}


1;
