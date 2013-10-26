package libkadeploy2::script;
use libkadeploy2::command;
use strict;
use warnings;

sub new($$$$)
{
    my $refcommandlist=shift;
    my $timeout=shift;
    my $verbose=shift;
    my $stoponerror=shift;
    my $currentcommand;
    my @commandlist=@$refcommandlist;
    my $self = 
    {
	timeout               => $timeout,
	commandlist           => $refcommandlist,
	verbose               => $verbose,
	stoponerror           => $stoponerror,    #stop exec if error
	hadfail               => 0,                #script hasn't failed
	currentcommandnumber  => 0,       
    };
    bless $self;
    return $self;
}

sub exec()
{
    my $self=shift;
    my $ok=1;
    my $notfinished=1;
    my $status;
    while ($notfinished)
    {
	$status=$self->exec_next();
	if ($status==0) { $ok=0; $self->{hadfail}=1; }
	if ($self->{stoponerror} && $ok==0) { $notfinished=0; }
	if ($self->finished()==1) { $notfinished=0; }
    }
    return $ok;
}

sub finished()
{
    my $self=shift;
    my @commandlist;
    my $refcommandlist;
    $refcommandlist=$self->{commandlist};
    @commandlist=@$refcommandlist;
	   
    if ($self->{currentcommandnumber}>=$#commandlist+1)
    {
	return 1;
    }
    else
    {
	return 0;
    }
}

sub exec_next()
{
    my $self=shift;
    my $refcommandlist=$self->{commandlist};
    my $cmd;
    my $ok=1;
    my $i;
    my @commandlist=@$refcommandlist;
    if ($self->{hadfail}) 
    { 
	$self->{hadfail}=0; 
	$self->{currentcommandnumber}+=1; 
    }

    $cmd=$commandlist[$self->return_currentcommandnumber()];
    
    my $command = libkadeploy2::command::new($cmd,
					     $self->{timeout},
					     $self->{verbose},
					     );
    $command->exec();
    if ($command->get_status()==0)
    {
	print STDERR "WARNING : ".$command->return_command()." Failed\n";
	if ($self->{stoponerror}) { $ok=0; }
	$self->{hadfail}=1;
    }
    else
    {
	$self->next_command();
    }
    return $ok;    
}

sub return_currentcommandnumber()
{
    my $self=shift;
    return $self->{currentcommandnumber};
}

sub return_currentcommand()
{
    my $self=shift;
    my $refcommandlist=$self->{commandlist};
    my @commandlist=@$refcommandlist;
    return @commandlist[$self->{currentcommandnumber}];
}


sub next_command()
{
    my $self=shift;
    return $self->{currentcommandnumber}=$self->{currentcommandnumber}+1;
}

1;

