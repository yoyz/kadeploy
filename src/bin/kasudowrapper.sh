#!/bin/bash

MYNAME="kasudowrapper.sh"
DEPLOYDIR=/opt/kadeploy/
DEPLOYUSER=deploy
PERL5LIBDEPLOY=$DEPLOYDIR/share/perl/5.8

export PERL5LIB=${PERL5LIBDEPLOY}/:$PERL5LIB
export DEPLOYDIR


if [ -x $DEPLOYDIR/bin/`basename $0` ] ; then exec sudo -u $DEPLOYUSER $DEPLOYDIR/bin/`basename $0` "$@" ; $OK=1 ;  fi
if [ -x $DEPLOYDIR/sbin/`basename $0` ] ; then exec sudo -u $DEPLOYUSER $DEPLOYDIR/sbin/`basename $0` "$@" ; $OK=1 ;  fi
if [ ! $OK ] ; then echo "$MYNAME badly configured, use (prefix)/sbin/kasetup -exportenv" ; fi

