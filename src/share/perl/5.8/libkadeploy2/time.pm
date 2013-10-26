package libkadeploy2::time;

use Time::HiRes;
use strict;
use warnings;
require 'sys/syscall.ph';

my $TIMEVAL_T = "LL";

sub new()
{
    my $self=
    {
	start => 0,
	done  => 0,
    };
    bless $self;
    return $self;	
}

sub start()
{
    my $self=shift;
    $self->{done} = $self->{start} = pack($TIMEVAL_T, ());

    syscall(&SYS_gettimeofday, $self->{start}, 0) != -1
	or die "gettimeofday: $!";
    return 1;
}



sub stop()
{    
    my $self=shift;
    my $delta_time;
    my @startl;
    my @donel;
    syscall( &SYS_gettimeofday, $self->{done}, 0) != -1
	or die "gettimeofday: $!";

    @startl = unpack($TIMEVAL_T, $self->{start});
    @donel  = unpack($TIMEVAL_T, $self->{done});

# fix microseconds
    for ($donel[1], $startl[1]) { $_ /= 1_000_000 }

    $delta_time = sprintf "%.4f", ($donel[0]  + $donel[1]  )-($startl[0] + $startl[1] );
    return $delta_time;

}




##########################
# DO YOUR OPERATION HERE #
##########################



