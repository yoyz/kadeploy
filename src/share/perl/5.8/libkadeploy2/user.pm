package libkadeploy2::user;
use strict;
use warnings;
use libkadeploy2::message;

sub new($)
{
    my $name=shift;
    if (! $name) { die "name not found [$name]"; }
    my $self=
    {
	name    => $name,
	fetched => 0,
    };
    bless $self;
    return $self;
}
sub fetch()
{
    my $self=shift;
    my $pwname;
    my $pwpass;
    my $pwuid;
    my $pwgid;
    my $pwquota;
    my $pwcomment;
    my $pwgcos;
    my $pwdir;
    my $pwshell;
    ($pwname, $pwpass, $pwuid, $pwgid, $pwquota, $pwcomment, $pwgcos, $pwdir, $pwshell) = getpwnam($self->{name});
    $self->{pwname}=$pwname;
    $self->{pwpass}=$pwpass;
    $self->{pwuid}=$pwuid;
    $self->{pwgid}=$pwgid;
    $self->{pwcomment}=$pwcomment;
    $self->{pwgcos}=$pwgcos;
    $self->{pwdir}=$pwdir;
    $self->{pwshell}=$pwshell;
    $self->{fetched}=1;
}

sub print()
{
    my $self=shift;
    print $self->{pwname}.
	":".$self->{pwpass}.
	":".$self->{pwuid}.
	":".$self->{pwgid}.
	":".$self->{pwgcos}.
	":".$self->{pwdir}.
	":".$self->{pwshell};
}

sub get($)
{
    my $self=shift;
    my $opt=shift;
    if (! $self->{fetched}) { $self->fetch(); }

    if ($opt    eq "name")   { return $self->get_name(); }
    elsif ($opt eq "pass")   { return $self->get_pass(); }
    elsif ($opt eq "uid")    { return $self->get_uid(); }
    elsif ($opt eq "gid")    { return $self->get_gid(); }
    elsif ($opt eq "gcos")   { return $self->get_gcos(); }
    elsif ($opt eq "dir")    { return $self->get_dir(); }
    elsif ($opt eq "shell")  { return $self->get_shell(); }
    else  { die "opt=$opt error"; }
}

sub get_name()  { my $self=shift; return $self->{pwname}; }
sub get_pass()  { my $self=shift; return $self->{pwpass}; }
sub get_uid()   { my $self=shift; return $self->{pwuid}; }
sub get_gid()   { my $self=shift; return $self->{pwgid}; }
sub get_gcos()  { my $self=shift; return $self->{pwgcos}; }
sub get_dir()   { my $self=shift; return $self->{pwdir}; }
sub get_shell() { my $self=shift; return $self->{pwshell}; }

1;


