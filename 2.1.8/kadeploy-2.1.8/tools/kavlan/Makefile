DEST=/usr/local/kavlan
CMDPATH=$(DEST)/cmd
CONFPATH=/etc/kavlan
BINDIR=/usr/local/bin
SBINDIR=/usr/local/sbin
KAVLANUSER=kavlan

install-frontend: install-perllibs
	install -m 0640 -d $(CONFPATH)
#	cp -r *.conf $(CONFPATH)
	install -m 0644 man/man1/kavlan.1 /usr/share/man/man1/
	install -d $(DEST)/bin
	install -o $(KAVLANUSER) -d $(DEST)/cmd
	install -o $(KAVLANUSER) -m 0750 src/kavlan-frontend.pl $(CMDPATH)/kavlan
	install -o $(KAVLANUSER) -m 0750 src/kavlan_adduser.pl $(CMDPATH)/kavlan_adduser
	install -o $(KAVLANUSER) -m 0750 src/kavlan_deluser.pl $(CMDPATH)/kavlan_deluser
	install -o $(KAVLANUSER) -m 0755 src/kavlanwrapper.sh $(DEST)/bin
	ln -s $(DEST)/bin/kavlanwrapper.sh $(BINDIR)/kavlan
	ln -s $(DEST)/bin/kavlanwrapper.sh $(SBINDIR)/kavlan_deluser
	ln -s $(DEST)/bin/kavlanwrapper.sh $(SBINDIR)/kavlan_adduser

install-backend : install-perllibs
	install -o $(KAVLANUSER) -d -m 0750 $(CONFPATH)
#	cp -r *.conf $(CONFPATH)
	install -m 0644 man/man1/kavlan.1 /usr/share/man/man1/
	install -o $(KAVLANUSER) -d  $(DEST)
	install -o $(KAVLANUSER) -m 0750 src/kavlan-backend.pl $(BINDIR)/kavlan-backend

install-perllibs:
	install -o $(KAVLANUSER) -d  $(DEST)/perl5
	install -o $(KAVLANUSER) -d  $(DEST)/perl5/KaVLAN
	install -o $(KAVLANUSER) -m 0644 src/KaVLAN/*.pm $(DEST)/perl5/KaVLAN
	install -o $(KAVLANUSER) -m 0644 src/vlan.pm $(DEST)/perl5
	install -o $(KAVLANUSER) -m 0644 src/const.pm $(DEST)/perl5

uninstall-frontend :
#	rm -r $(CONFPATH)
	rm -f /usr/share/man/man1/kavlan.1
	rm -fr $(DEST)
	rm $(BINDIR)/kavlan
	rm $(SBINDIR)/kavlan_adduser
	rm $(SBINDIR)/kavlan_deluser

uninstall-backend :
#	rm -r $(CONFPATH)
	rm -f /usr/share/man/man1/kavlan.1
	rm -fr $(DEST)
	rm $(BINDIR)/kavlan-backend

