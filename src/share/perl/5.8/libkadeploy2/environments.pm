package libkadeploy2::environments;

use strict;
use warnings;
use libkadeploy2::deploy_iolib;
use libkadeploy2::message;

my $message=libkadeploy2::message::new();

sub new()
{
    my $self=
    {
	ENV => 0,
    };
    bless $self;
    return $self;
}

sub get()
{
    my $self=shift;
    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    $self->{ENV}=$db->get_environments();
    $db->disconnect();    
}

sub print($)
{
    my $self=shift;
    my $oldstyle=shift;
    my $ref_array;
    my @array;
    my $line;
    my $refline;
    my $i=0;
    my $environment;
    my $name;
    my $user;
    my $descriptionfile;
    $ref_array=$self->{ENV};
    if (! $ref_array) { $message->missing_env_db(0); return 1; }
    foreach $refline (@$ref_array)
    {
	$name=$$refline[0];
	$user=$$refline[1];
	$descriptionfile=$$refline[2];
	$environment=libkadeploy2::environment::new();
	$environment->set_name($name);
	$environment->set_user($user);
	$environment->set_descriptionfile($descriptionfile);

	if ($i==0)
	{
	    $environment->print_header($oldstyle);
	    $i++;
	}
	$environment->print_line($oldstyle);
    }    
    if ($i)
    {
	$environment->print_footer($oldstyle);
    }
}



