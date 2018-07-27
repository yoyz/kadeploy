#!/bin/bash

SQLCMDS=fullrights.sql
DBNAME="deploy217test"
DBHOST="fgrelon1.nancy.grid5000.fr"

if [ ! -f ${SQLCMDS} ]; then
  touch ${SQLCMDS}
else
  echo '' > ${SQLCMDS}
fi


for a in $(seq 1 47); do
  echo "INSERT INTO rights(user,node,part) VALUES ('deploy', 'grillon-${a}.nancy.grid5000.fr', '*');" >> ${SQLCMDS}
done

for a in $(seq 1 120); do
  echo "INSERT INTO rights(user,node,part) VALUES ('deploy', 'grelon-${a}.nancy.grid5000.fr', '*');" >> ${SQLCMDS}
done

echo -en "\nPlease enter root Mysql passwd : "
read -s rpwd
echo -en "\nInserting rights into ${K217DB}..."
mysql -u root -p${rpwd} -h ${DBHOST} -D ${DBNAME} < ${SQLCMDS}
echo -en " done\n\n"