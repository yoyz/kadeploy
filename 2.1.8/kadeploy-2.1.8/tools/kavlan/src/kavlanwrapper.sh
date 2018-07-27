#!/bin/bash

USERNAME=`id -u -n`
KAVLANUSER=kavlan
export KAUSER=$USERNAME
export PERL5LIB=/usr/local/kavlan/perl5
export KAVLANDIR=/usr/local/kavlan
exec sudo -u $KAVLANUSER $KAVLANDIR/cmd/`basename $0` "$@"
