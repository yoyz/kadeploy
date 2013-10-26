package libkadeploy2::environment;

use strict;
use warnings;

sub new()
{
    my $self;
    $self=
    {
	name => "NOTSET",
	user => "NOTSET",
	descriptionfilepath => "NOTSET",
	descriptionfile => 0
	
    };
    bless $self;
    return $self;
}


sub set_name($)
{
    my $self=shift;
    my $name=shift;
    $self->{name}=$name;
}

sub get_name()
{
    my $self=shift;
    my $name=shift;
    return $self->{name};
}

sub set_user($)
{
    my $self=shift;
    my $user=shift;
    $self->{user}=$user;
}

sub get_user($)
{
    my $self=shift;
    my $user=shift;
    return $self->{user};
}

sub set_descriptionfile($)
{
    my $self=shift;
    my $descriptionfilepath=shift;
    $self->{descriptionfilepath}=$descriptionfilepath;
}

sub get_descriptionfile()
{
    my $self=shift;
    return $self->{descriptionfilepath};
}

sub get($)
{
    my $self=shift;
    my $key=shift;
    my $descriptionfile=$self->{descriptionfile};
    return $descriptionfile->get($key);
}

sub is_set($)
{
    my $self=shift;
    my $key=shift;
    my $descriptionfile=$self->{descriptionfile};
    return $descriptionfile->is_set($key);
}

sub set($$)
{
    my $self=shift;
    my $key=shift;
    my $descriptionfile=$self->{descriptionfile};
    return $descriptionfile->set($key);
}

sub get_descriptionfile_fromdb()
{
    my $self=shift;
    my $ok=0;
    my $descriptionfilepath;
    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    $descriptionfilepath=$db->get_environment_descriptionfile($self->{name},
							      $self->{user}							  );
    $db->disconnect();
    if ($descriptionfilepath)
    {
	$self->{descriptionfilepath}=$descriptionfilepath;
	$ok=1;
    }
    return $ok;
}


sub addtodb()
{
    my $self=shift;
    my $ok=0;
    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    if ($db->add_env(
		     $self->get_name(),
		     $self->get_user(),
		     $self->get_descriptionfile()
		     ))
    {
	$ok=1;
    }
    $db->disconnect();
    return $ok;
}

sub delfromdb()
{
    my $self=shift;
    my $ok=0;
    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    if ($db->del_env(
		     $self->get_name(),
		     $self->get_user(),
		     $self->get_descriptionfile()
		     ))
    {
	$ok=1;
    }
    $db->disconnect();
    return $ok;
}


sub load()
{
    my $self=shift;
    my $descriptionfile=libkadeploy2::conflib::new($self->{descriptionfilepath},0);
    $descriptionfile->load();    
    $self->{descriptionfile}=$descriptionfile;
}

sub print_descriptionfile()
{
    my $self=shift;
    my $descriptionfile=$self->{descriptionfile};
    $descriptionfile->print();
}



sub print()
{
    my $self=shift;
    $self->print_header();
    $self->print_line();
    $self->print_footer();
}

sub print_header()
{
    my $self=shift;
    print "
environment :
--------------
";
	
}

sub print_footer()
{
    my $self=shift;
    print "\n";
}

sub print_line()
{
    my $self=shift;
    print "$self->{user}"."@".$self->{name}." ".$self->{descriptionfilepath}."\n";
}




1;
