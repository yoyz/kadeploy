use SUBSTmydeploydbSUBST;

alter table disk modify device varchar(255) not null;
alter table partition modify pnumber varchar(10) not null default "3";
