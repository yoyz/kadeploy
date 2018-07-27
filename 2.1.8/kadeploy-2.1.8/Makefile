#!/usr/bin/make

#######################################
#
# Installation Makefile for Kadeploy
# Grid'5000 project 
#
#######################################


#===================================
# ADAPT TO your target distribution
#===================================
DISTRIB = debian4


#==============================================
# Kadeploy installation prefix
# YOU MAY ADAPT this to your local preferences
#==============================================
PREFIX=/usr/local


#=======================================
# Release - please DO NOT modify below
#=======================================
MAJOR = 2
MINOR = 1
SUBMINOR = 8
SUBRELEASE =


#============================
# Please DO NOT modify below
#============================
VERSION_BRIEF = $(MAJOR)$(MINOR)$(SUBMINOR)
ifneq ($(strip $(VERSION_BRIEF)),)
VERSION = $(MAJOR).$(MINOR).$(SUBMINOR)
endif
ifneq ($(strip $(SUBRELEASE)),)
KADEPLOY_VERSION = $(VERSION)-$(SUBRELEASE)
KADEPLOY_VERSION_BRIEF = $(VERSION_BRIEF)_$(SUBRELEASE)
else ifneq ($(VERSION),)
KADEPLOY_VERSION = $(VERSION)
KADEPLOY_VERSION_BRIEF = $(VERSION_BRIEF)
endif
ifneq ($(KADEPLOY_VERSION),)
KADIR = kadeploy-$(KADEPLOY_VERSION)
else
KADIR = kadeploy
endif


#============================
# Please DO NOT modify below 
#============================
SHELL=/bin/bash

# Installation directories
KADEPLOYHOMEDIR=$(PREFIX)/$(KADIR)
KABINDIR=$(KADEPLOYHOMEDIR)/bin
KASBINDIR=$(KADEPLOYHOMEDIR)/sbin
KAADDONSDIR=$(KADEPLOYHOMEDIR)/addons
KALIBDIR=$(KADEPLOYHOMEDIR)
KADBDIR=$(KADEPLOYHOMEDIR)/db

# Configuration directory
KADEPLOYCONFDIR_LEGACY=/etc/kadeploy
KADEPLOYCONFDIR=/etc/$(KADIR)

MANDIR=$(PREFIX)/man
INFODIR=$(PREFIX)/info

# Path to user reachable Ka*-commands
BINDIR=$(PREFIX)/bin/$(KADIR)
SBINDIR=$(PREFIX)/sbin/$(KADIR)


KADEPLOY_BINFILES=kaconsole kaenvironments karecordenv kadeploy kareboot karemote kaaddkeys kadatabase
KADEPLOY_SBINFILES=kaadduser kadeluser kanodes
KADEPLOY_MANPAGES=kaadduser.1 kaaddkeys.1 kaconsole.1 kadeluser.1 kaenvironments.1 karecordenv.1 kadeploy.1 kareboot.1 deploy.conf.1 karemote.1 deploy_cmd.conf.1

# Kadeploy user settings
GROUPS=/etc/group
USERS=/etc/passwd
DEPLOYUSER=deploy
DEPLOYGROUP=deploy


#=====================================================================
# To be adapted to the target distribution (developer's part of work)
# - Perl libs paths
# - docbook resources
#=====================================================================
ifeq ($(DISTRIB), debian4)
PERLDIR=/usr/share/perl/5.8
HTMLDOC=/usr/bin/htmldoc
XSLTPROC=/usr/bin/xsltproc
TLDPOPXSL=/usr/share/xml/docbook/stylesheet/ldp/html/tldp-one-page.xsl
else ifeq ($(DISTRIB), fedora4)
PERLDIR=/usr/lib/perl5/5.8.6
HTMLDOC=/usr/bin/htmldoc
XSLTPROC=/usr/bin/xsltproc
TLDPOPXSL=/usr/share/xml/docbook/stylesheet/ldp/html/tldp-one-page.xsl
else ifeq ($(DISTRIB), centos52)
PERLDIR=/usr/lib/perl5/5.8.8
HTMLDOC=/usr/bin/htmldoc
XSLTPROC=/usr/bin/xsltproc
TLDPOPXSL=/usr/share/xml/docbook/stylesheet/ldp/html/tldp-one-page.xsl
else
PERLDIR=/usr/share/perl/5.8
HTMLDOC=/usr/bin/htmldoc
XSLTPROC=/usr/bin/xsltproc
TLDPOPXSL=/usr/share/xml/docbook/stylesheet/ldp/html/tldp-one-page.xsl
endif

$(info Use settings for distribution : $(DISTRIB) )
$(info $(DISTRIB) : using Perl path : $(PERLDIR) )
$(info $(DISTRIB) : using htmldoc path : $(HTMLDOC) )
$(info $(DISTRIB) : using xsltproc path : $(XSLTPROC) )
$(info $(DISTRIB) : using LDP XSL stylesheet : $(TLDPOPXSL) )

#==================
# Archive creation
#==================

MANPAGES_SRC=docs/man/src/
MANPAGES=docs/man/man1/
DOCUMENTATION_SRC=docs/texi/
DOCUMENTATION=$(DOCUMENTATION_SRC)/documentation/
DOCBOOK=docs/docbook/
SCRIPTS=scripts/
ADDONS=addons/
TOOLS=tools/
PDF_DOCS=$(wildcard $(DOCBOOK)*.pdf)

EXCLUDED=--exclude='.svn' --exclude='*~' --exclude='old_method'
KADEPLOY_ARC=kadeploy-$(KADEPLOY_VERSION).tar



.PHONY: all usage installcheck root_check user_and_group_deploy_check \
links_install conflink_install installdirs files_install install sudo_install man_install \
uninstall files_uninstall \
dist scripts_arc addons_arc tools_arc manpages_arc manpages documentation documentation_arc 

	

#################
#
# Default action
#
#################

all: usage


########################################
# 
# Installation or uninstallation checks
# 
########################################

#Check if you execute installation with root privileges
installcheck: root_check user_and_group_deploy_check prefix_check

prefix_check:
	@echo "Installation directory check ..."
	@( ( test -d $(PREFIX) && echo "$(PREFIX) found." ) || ( echo "$(PREFIX) not found ; will be created." ) )
	
root_check:
	@echo "root check ..."
	@[ `whoami` = 'root' ] || ( echo "Warning: root-privileges are required to install some files !" ; exit 1 )

#Add the "proxy" user/group to /etc/passwd if needed.
user_and_group_deploy_check: 
	@echo "User and group check ..."
	@( ( grep -q "^deploy:" $(GROUPS) && echo "deploy group already created." ) || \
	addgroup --quiet --system $(DEPLOYGROUP) )
	@( ( grep -q "^deploy:" $(USERS) && echo "deploy user already created." ) || \
	adduser --quiet --system --ingroup $(DEPLOYGROUP) --no-create-home --home $(KADEPLOYHOMEDIR) $(DEPLOYUSER) 2>&1 >/dev/null )

links_install:
	@echo "Making links to sudowrapper ..."
	@ln -s $(KABINDIR)/kasudowrapper.sh $(BINDIR)/kaconsole
	@ln -s $(KABINDIR)/kasudowrapper.sh $(BINDIR)/kaenvironments
	@ln -s $(KABINDIR)/kasudowrapper.sh $(BINDIR)/karecordenv
	@ln -s $(KABINDIR)/kasudowrapper.sh $(BINDIR)/kadeploy
	@ln -s $(KABINDIR)/kasudowrapper.sh $(BINDIR)/kareboot
	@ln -s $(KABINDIR)/kasudowrapper.sh $(BINDIR)/karemote
	@ln -s $(KABINDIR)/kasudowrapper.sh $(BINDIR)/kadatabase
	@ln -s $(KABINDIR)/kasudowrapper.sh $(SBINDIR)/kaadduser
	@ln -s $(KABINDIR)/kasudowrapper.sh $(SBINDIR)/kadeluser
	@ln -s $(KABINDIR)/kasudowrapper.sh $(SBINDIR)/kanodes
	@( ( [ ! -e $(PERLDIR)/libkadeploy2 ] && ln -s $(PERLDIR)/$(KADIR)/libkadeploy2 $(PERLDIR)/libkadeploy2 ) || \
	( echo "$(PERLDIR)/libkadeploy2 already exists ; not linked over." ) )
	
installdirs:
	@echo "Making directories ..."
	@mkdir -p $(KADEPLOYHOMEDIR)/db
	@mkdir -p $(KADEPLOYHOMEDIR)/grub
	@mkdir -p $(KADEPLOYHOMEDIR)/.ssh
	@mkdir -p $(KABINDIR)	
	@mkdir -p $(KASBINDIR)
	@mkdir -p $(KALIBDIR)/libkadeploy2
	@mkdir -p $(PERLDIR)/$(KADIR)
	@mkdir -p -m 700 $(KADEPLOYCONFDIR)/.ssh
	@mkdir -p $(BINDIR)
	@mkdir -p $(SBINDIR)

files_install:
	@echo "Copying files ..."
	@install -m 600 conf/deploy.conf $(KADEPLOYCONFDIR)/
	@install -m 600 conf/deploy_cmd.conf $(KADEPLOYCONFDIR)/
	@install -m 600 conf/clusternodes.conf $(KADEPLOYCONFDIR)/
	@install -m 600 conf/clusterpartition.conf $(KADEPLOYCONFDIR)/
	@chown -R $(DEPLOYUSER):root $(KADEPLOYCONFDIR)

	@install -m 755 bin/kaconsole $(KABINDIR)/
	@install -m 755 bin/kaenvironments  $(KABINDIR)/
	@install -m 755 bin/karecordenv $(KABINDIR)/
	@install -m 755 bin/kadeploy $(KABINDIR)/
	@install -m 755 bin/kareboot $(KABINDIR)/
	@install -m 755 bin/karemote $(KABINDIR)/
	@install -m 755 bin/kadatabase $(KABINDIR)/
	@install -m 755 bin/kasudowrapper.sh $(KABINDIR)/	
	@install -m 755 bin/kaaddkeys $(BINDIR)/

	@install -m 755 sbin/kaadduser $(KASBINDIR)/
	@install -m 755 sbin/kadeluser $(KASBINDIR)/
	@install -m 755 sbin/kastats $(KASBINDIR)/	
	@install -m 755 sbin/kanodes $(KASBINDIR)/
	@install -m 755 sbin/setup_pxe.pl $(KASBINDIR)/

# Perl modules 
	@install -m 755 libkadeploy2/* $(KALIBDIR)/libkadeploy2/
	@ln -sf $(KALIBDIR)/libkadeploy2 $(PERLDIR)/$(KADIR)/libkadeploy2

# database scripts
	@install -m 755 scripts/install/kadeploy_conflib.pm $(KADBDIR)
	@install -m 755 scripts/sql/*.sql $(KADBDIR)
	
# GRUB files
	@install -m 755 addons/grub/* $(KADEPLOYHOMEDIR)/grub

# SSH key 
	@install -m 600 addons/deployment_kernel_generation/debootstrap/ssh/id_deploy $(KADEPLOYHOMEDIR)/.ssh/
	@install -m 644 addons/deployment_kernel_generation/debootstrap/ssh/id_deploy.pub $(KADEPLOYHOMEDIR)/.ssh/
	@install -m 600 addons/deployment_kernel_generation/debootstrap/ssh/id_deploy $(KADEPLOYCONFDIR)/.ssh/
	@install -m 644 addons/deployment_kernel_generation/debootstrap/ssh/id_deploy.pub $(KADEPLOYCONFDIR)/.ssh/

conflink_install:
	@( ( [ ! -e $(KADEPLOYCONFDIR_LEGACY) ] &&  ln -s $(KADEPLOYCONFDIR) $(KADEPLOYCONFDIR_LEGACY) ) || \
	( echo "$(KADEPLOYCONFDIR_LEGACY) already exists ; not linked over." ) )
	
#Sudo installation : modification of /etc/sudoers
sudo_install:
	@[ -e /etc/sudoers ] || ( echo "Error: No /etc/sudoers file. Is sudo installed ?" && exit 1 )
	@sed -i "s%DEPLOYCONFDIR=__SUBST__%DEPLOYCONFDIR=$(KADEPLOYCONFDIR)%" $(KABINDIR)/kasudowrapper.sh
	@sed -i "s%DEPLOYDIR=__SUBST__%DEPLOYDIR=$(KADEPLOYHOMEDIR)%" $(KABINDIR)/kasudowrapper.sh
	@sed -i "s%DEPLOYBINDIR=__SUBST__%DEPLOYBINDIR=$(BINDIR)%" $(KABINDIR)/kasudowrapper.sh
	@sed -i "s%DEPLOYUSER=__SUBST__%DEPLOYUSER=$(DEPLOYUSER)%" $(KABINDIR)/kasudowrapper.sh
	@sed -i "s%PERL5LIBDEPLOY=__SUBST__%PERL5LIBDEPLOY=$(KALIBDIR)%" $(KABINDIR)/kasudowrapper.sh
	@scripts/install/sudocheck -k $(KADEPLOY_VERSION_BRIEF) -u
	@scripts/install/sudocheck -k $(KADEPLOY_VERSION_BRIEF) -b $(KABINDIR) -i
	
# Manpages installation
man_install:
	@mkdir -p $(MANDIR)/man1
	@install -m 755 $(MANPAGES)/* $(MANDIR)/man1/

#Kadeploy installation in main directory
install: installcheck installdirs files_install links_install conflink_install sudo_install final_msg
	@( chown -R deploy:deploy $(KADEPLOYCONFDIR) )

final_msg:
	@echo -e "\n*** WARNING"
	@echo -e "- To select correct configuration (with Bash) : \n\texport KADEPLOY_CONFIG_DIR="$(KADEPLOYCONFDIR)
	@echo -e "- Otherwise use '-C "$(KADEPLOYCONFDIR)"' with ka* commands.\n"
	@echo -e "\n*** INFO"
	@echo -e "- To install man pages :\n\tmake man_install\n"

#Install info documentation
#info_install:
#	@mkdir -p $(INFODIR)
#	@install -m 755 docsDocumentation/info/*  $(INFODIR)/

###########################
#
# Kadeploy un-installation
# 
###########################

#Remove Installation of Kadeploy 
files_uninstall :
	@echo "Removing system-wide installed files ..."
	@cd $(BINDIR) && rm -f $(KADEPLOY_BINFILES)
	@cd $(SBINDIR) && rm -f $(KADEPLOY_SBINFILES)
	@rm -rf $(BINDIR)
	@rm -rf $(SBINDIR)
	@rm -rf $(PERLDIR)/$(KADIR)

kahomedir_uninstall :
	@echo "Deleting Kadeploy installation directory : $(KADEPLOYHOMEDIR)"
	@rm -rf $(KADEPLOYHOMEDIR)/
#@cd $(MANDIR) && rm -f $(KADEPLOY_MANPAGES)

sudoers_uninstall :
	@echo "Uninstalling sudowrapper ..."
	@scripts/install/sudocheck -k $(KADEPLOY_VERSION_BRIEF) -u
	
usergroup_uninstall :
	@echo "Removing deploy user and group ..."
	@( grep -q $(DEPLOYUSER) /etc/passwd && userdel $(DEPLOYUSER) ) \
	|| echo "user $(DEPLOYUSER) already removed."
	@( grep -q $(DEPLOYGROUP) /etc/group && groupdel $(DEPLOYGROUP) ) \
	|| echo "group $(DEPLOYGROUP) already removed."
	
conf_uninstall :
	@echo "Deleting Kadeploy configuration directory : $(KADEPLOYCONFDIR)"
	@rm -rf $(KADEPLOYCONFDIR)/
	@( [ -d $(KADEPLOYCONFDIR_LEGACY).old ] && ( mv $(KADEPLOYCONFDIR_LEGACY).old $(KADEPLOYCONFDIR_LEGACY) ) || echo No previously existing $(KADEPLOYCONFDIR_LEGACY).old found. )
#@( [ -L $(KADEPLOYCONFDIR_LEGACY) ] && ( rm -f $(KADEPLOYCONFDIR_LEGACY) ) || echo "No previously existing $(KADEPLOYCONFDIR_LEGACY) found." )

uninstall : root_check files_uninstall kahomedir_uninstall conf_uninstall sudoers_uninstall

purge : uninstall usergroup_uninstall

#############################
# 
# Archive creation (tarball)
# 
#############################

dist: dist_prepare dist_all

dist_prepare:
	@( cd .. && [ ! -L $(KADIR) ] && ln -s trunk $(KADIR) || echo Existing $(KADIR) found. )
	
dist_all: manpages_arc documentation_arc scripts_arc addons_arc tools_arc
	@echo "Archiving Kadeploy main files ..."
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/bin/
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/sbin/
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/libkadeploy2/
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/conf/
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/AUTHORS
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/COPYING
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/README
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/Makefile
	@echo "Compressing archive ..."
	@gzip $(KADEPLOY_ARC)
	@( cd .. && rm -f $(KADIR) )
	@echo "Done."

scripts_arc:
	@echo "Archiving scripts ..."
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/$(SCRIPTS)
	
addons_arc:
	@echo "Archiving addons ..."
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/$(ADDONS)
	
tools_arc:
	@echo "Archiving tools ..."
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/$(TOOLS)
	
manpages_arc: manpages
	@echo "Archiving Manpages ..."
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/$(MANPAGES)
	
manpages:
	@make -C $(MANPAGES_SRC) 2>&1 >/dev/null
	
documentation_arc: documentation
	@echo "Archiving documentation ..."
	@tar $(EXCLUDED) -C ../ -rf $(KADEPLOY_ARC) $(KADIR)/$(PDF_DOCS)
# @tar $(EXCLUDED) -C $(DOCUMENTATION_SRC) -rf $(KADEPLOY_ARC) INSTALL
# @tar $(EXCLUDED) -C $(DOCUMENTATION_SRC) -rf $(KADEPLOY_ARC) changelog.txt
# @tar $(EXCLUDED) -rf $(KADEPLOY_ARC) $(DOCUMENTATION)

check_htmldoc:
	@( test -f $(HTMLDOC) || ( echo "$(HTMLDOC) : command not found." && exit 1; ) )
	
check_xsltproc: 
	@( test -f $(XSLTPROC) || ( echo "$(XSLTPROC) : command not found." && exit 1; ) )

check_ldpxsl:
	@( test -f $(TLDPOPXSL) || ( echo "$(TLDPOPXSL) : command not found." && exit 1; ) )

documentation: check_htmldoc check_xsltproc check_ldpxsl
	@( cd $(DOCBOOK) && $(MAKE) 2>&1 >/dev/null )

################
#
# Usage of make
# 
################

usage:
	@echo -e "\n\t***************************************"
	@echo -e "\t*** Installation of Kadeploy-$(KADEPLOY_VERSION) ***"
	@echo -e "\t***************************************"
	@echo -e "\n\tUsage: make [ OPTIONS=<...> ] MODULE"
	@echo -e "\t\t==> OPTIONS := { PREFIX | DISTRIB } "
	@echo -e "\t\t==> MODULE := { install | uninstall | dist }\n"
