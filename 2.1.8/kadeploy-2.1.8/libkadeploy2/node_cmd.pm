###
# Node extension for command line
#
package libkadeploy2::NodeCmd;
use libkadeploy2::node;
use base ("Node");   # declare superclasses

use strict;
use warnings;



sub new {
    my ($self, $name) = @_;
    my ($addr) = (gethostbyname($name))[4];
    if (!$addr) { die "Node $name has no IP address"} 
    my $IP = join(".",unpack("C4", $addr));
    $self->SUPER::new($name);
}


sub set_values {
    my $self = shift;
    my $name = $self->get_name();
    my ($addr) = (gethostbyname($name))[4];
    if (!$addr) { die "Node $name has no IP address"} 
    my $IP = join(".",unpack("C4", $addr));
    $self->set_IP($IP);
}


#
# Exemple de surcharge de fonction, pour reagir au changement d'etat d'un noeud
#
sub set_state {
    my $self = shift;
    my $nextState = shift;
    my $nodeName;
    my $currentState = $self->get_state();
    my $error = "nothing to report";

    if ($currentState == $nextState) {
	print "[set_state] state doen\'t change so why call set_state!!!\n";
	return 1;
    }
    
    if ($currentState == 0) { # node never appeared before
	if ($nextState == -1) { # node is not yet there
	    $error = $self->get_error();
	} elsif ($nextState == 1) { # node appeared during first check
	    $error = "node appears";
	}
    } elsif ($currentState == -1) { # node appears during check, and only there
	$error = "node appears";
    } else { # node is there (current state == 1)
	$error = $self->get_error();
    }

    print $error . "\n";

    $self->SUPER::set_state($nextState);
}




1;
