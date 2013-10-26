package libkadeploy2::rights;
use strict;
use warnings;
use libkadeploy2::deploy_iolib;
use libkadeploy2::message;

my $message=libkadeploy2::message::new();
my $user="";
my $node="";
my $rights="";


sub new()
{
    my $self;
    $self=
    {
	ACL => 0,
	index => 0,
    };
    bless $self;
    return $self;
}

sub get()
{
    my $self=shift;
    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    $self->{ACL}=$db->get_rights();
    $db->disconnect();    
}


sub get_next()
{
    my $self=shift;
    my $ref_array;
    my $right=libkadeploy2::right::new();
    my $refline;

    $ref_array=$self->{ACL};
    $refline=$$ref_array[$self->{index}];
    $self->{index}=$self->{index}+1;
    if ($refline)
    {
	$user=$$refline[0];
	$node=$$refline[1];
	$rights=$$refline[2];
	$right->set_user($user);
	$right->set_node($node);
	$right->set_right($rights);
	return $right;
    }
    else
    {
	return 0;
    }
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
    my $right;
    $ref_array=$self->{ACL};
    if (! $ref_array) { $message->missing_rights_db(0); return 1; }
    foreach $refline (@$ref_array)
    {
	$user=$$refline[0];
	$node=$$refline[1];
	$rights=$$refline[2];
	$right=libkadeploy2::right::new();
	$right->set_user($user);
	$right->set_node($node);
	$right->set_right($rights);

	if ($i==0)
	{
	    $right->print_header($oldstyle);
	    $i++;
	}
	$right->print_line($oldstyle);
     }    
    $right->print_footer($oldstyle);
}

sub print_user($)
{
    my $self=shift;
    my $usertotest=shift;
    my $ref_array;
    my @array;
    my $line;
    my $refline;
    my $user;
    my $node;
    my $rights;
    my $right;
    my $i=0;
    $ref_array=$self->{ACL};
    foreach $refline (@$ref_array)
    {
	$user=$$refline[0];
	$node=$$refline[1];
	$rights=$$refline[2];

	$right=libkadeploy2::right::new();
	$right->set_user($user);
	$right->set_node($node);
	$right->set_right($rights);

	if ($i==0)
	{
	    $right->print_header();
	    $i++;
	}
        if ($$refline[0] eq $usertotest)
        {  
	    $right->print_line();
        }
     }    
    $right->print_footer();
}

sub print_node($)
{
    my $self=shift;
    my $nodetotest=shift;
    my $ref_array;
    my @array;
    my $line;
    my $refline;
    my $user;
    my $node;
    my $rights;
    my $right;
    my $i=0;
    $ref_array=$self->{ACL};
    foreach $refline (@$ref_array)
    {
	$user=$$refline[0];
	$node=$$refline[1];
	$rights=$$refline[2];

	$right=libkadeploy2::right::new();
	$right->set_user($user);
	$right->set_node($node);
	$right->set_right($rights);

	if ($i==0)
	{
	    $right->print_header();
	    $i++;
	}
        if ($$refline[1] eq $nodetotest)
        {  
	    $right->print_line();
        }
     }    
    $right->print_footer();
}

sub print_rights($)
{
    my $self=shift;
    my $righttotest=shift;
    my $ref_array;
    my @array;
    my $line;
    my $refline;
    my $user;
    my $node;
    my $rights;
    my $right;
    my $i=0;
    $ref_array=$self->{ACL};
    foreach $refline (@$ref_array)
    {
	$right=libkadeploy2::right::new();
	$user=$$refline[0];
	$node=$$refline[1];
	$rights=$$refline[2];
	if ($i==0)
	{
	    $right->print_header();
	    $i++;
	}
	$right->set_user($user);
	$right->set_node($node);
	$right->set_right($rights);
        if ($$refline[2] eq $righttotest)
        {  
	    $right->print_line();
        }
     }    
    $right->print_footer();
}


1;
