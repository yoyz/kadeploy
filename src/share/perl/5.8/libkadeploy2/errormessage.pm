package libkadeploy2::message;

sub new()
{
    my $self;
    $self ={};
    bless $self;
    return $self;
}

sub missing_node_cmdline()
{
    print STDERR "ERROR : you have to specify nodes\n";
}

1;
