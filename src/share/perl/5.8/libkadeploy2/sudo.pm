package libkadeploy2::sudo;

use strict;
use warnings;

my $message=libkadeploy2::message::new(); 

sub new()
{
    my $self={};
    bless $self;
    return $self;
}

sub get_user()      { my $self=shift; return $ENV{USER}; }
sub get_sudo_user() { my $self=shift; return $ENV{SUDO_USER}; }

1;
