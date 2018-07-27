#jpeyrard@imag.fr
#14/10/05
#
#hex patch
#
update environment set fdisktype = 130 where filesystem='swap';
update environment set fdisktype = 131 where filesystem='ext2';
update environment set fdisktype = 131 where filesystem='ext3';
alter table environment add `optsupport` int(10) unsigned NOT NULL default '0';
