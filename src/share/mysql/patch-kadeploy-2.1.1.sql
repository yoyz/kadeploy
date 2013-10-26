#jpeyrard@imag.fr
#19/12/05
#
#Environment linked to a user
#
CONNECT SUBSTmydeploydbSUBST;
alter table `environment` add user varchar(255) default 'nobody';
update environment set user='deploy' where name='grid5000';
update environment set user='deploy' where name='debian4all';
