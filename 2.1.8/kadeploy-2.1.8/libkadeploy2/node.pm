## manage node relative content
package libkadeploy2::node;

use strict;
use warnings;

my $default_state = 0;
my $default_command_status = 0;

## Class constructor
# 
# check all the relevant data available for the node
#
# args: name
#
# must call set_IP to set the node IP after that!
sub new {
    my ($class, $name) = @_;
    my $self = {};
    $self->{name} = $name;
    $self->{state} = $default_state;
    $self->{command_status} = $default_command_status;
    $self->{error} = ""; # error to report on set_state
    bless ($self, $class);
    return $self;
}

##  error
# allows to report dedicated errors on nodes
sub set_error {
    my $node = shift;
    $node->{error} = shift;
}

sub get_error {
    my $node = shift;
    return $node->{error};
}

## state
# 0: initial state, know nothing about the node
# 1: node is available for deployment
# -1: node is not available for deployment
sub get_state {
    my $node = shift;
    return $node->{state};
}

sub set_state {
    my $node = shift;
    $node->{state} = shift;
}

## last command status
# 0: initial state before any command is issued
# 1: command was successfull
# -1: command failed
sub get_command_status {
    my $node = shift;
    return $node->{command_status};
}

sub set_command_status {
    my $node = shift;
    $node->{command_status} = shift;
}

## name
# get name of the node
sub get_name {
    my $node = shift;
    return $node->{name};
}

## IP
# IP of the node
sub set_IP {
    my $node = shift;
    $node->{IP} = shift;
}

sub get_IP {
    my $node = shift;
    return $node->{IP};
}



1;
