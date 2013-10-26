package libkadeploy2::right;
use strict;
use warnings;
use libkadeploy2::deploy_iolib;



     #
     #CORRECT RIGHTS
     #
     #PXE
     #REBOOT
     #CONSOLE
     #DISKN
     #DISKNPARTN



sub new()
{
    my $self;
    $self=
    {
	"user"   => "[NOTSET]",
	"node"   => "[NOTSET]",
	"right" => "[NOTSET]",
    };
    bless $self;
    return $self;
}

sub set_user($)
{
    my $self=shift;
    my $user=shift;
    $self->{user}=$user;
}

sub get_user()
{
    my $self=shift;
    if ($self->{user} eq "[NOTSET]")
    {
	return 0;
    }
    else
    {
	return $self->{user};
    }
}

sub get_node()
{
    my $self=shift;
    if ($self->{node} eq "[NOTSET]")
    {
	return 0;
    }
    else
    {
	return $self->{node};
    }
}

sub get_right()
{
    my $self=shift;
    if ($self->{right} eq "[NOTSET]")
    {
	return 0;
    }
    else
    {
	return $self->{right};
    }
}


sub set_node($)
{
    my $self=shift;
    my $node=shift;
    $self->{node}=$node;
}



sub set_right($)
{
    my $self=shift;
    my $right=shift;
    $self->{right}=$right;
}


sub addtodb()
{
    my $self=shift;
    my $ok=0;
    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    $ok=$db->add_rights_user_nodename_rights(
					     $self->{user},
					     $self->{node},
					     $self->{right}
					     );
    $db->disconnect();
    return $ok;
}

sub delfromdb($$$)
{
    my $self=shift;
    my $user=shift;
    my $node=shift;
    my $rights=shift;
    my $ok=0;
    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    $ok=$db->del_rights_user_nodename_rights(
					     $self->{user},
					     $self->{node},
					     $self->{right}
					     );
    $db->disconnect();
    return $ok;

}

sub print_header($)
{
    my $self=shift;
    my $oldstyle=shift;
    if ($oldstyle)
    {
	print "user"."@"."node\tright\n";
    }
    else
    {
	print "
+----------------+--------------------------+------------------+
| user           | node                     | rights           |
+----------------+--------------------------+------------------+
";
    }
}

sub print_footer($)
{
    my $self=shift;
    my $oldstyle=shift;
    if (! $oldstyle)
    {
	print "+----------------+--------------------------+------------------+\n";
    }
}

sub print_line($)
{
    my $self=shift;
    my $oldstyle=shift;
    if ($oldstyle)
    {
	print $self->{user}."@".$self->{node}."\t".$self->{right}."\n";
    }
    else
    {
	no warnings;
	format STDOUT =
| @<<<<<<<<<<<<< | @<<<<<<<<<<<<<<<<<<<<<<< | @<<<<<<<<<<<<<<<<|
$self->{user},         $self->{node},           $self->{right}
.
    write; 
use warnings;
}
}


1;
