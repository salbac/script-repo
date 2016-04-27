#!/bin/bash

#Variables
DB=$1
DBPID=`ps -ef | grep pmon_"$DB" | grep -v grep | awk '{print $2}'`
DBUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
OB=`cat /etc/oraInst.loc | grep inventory_loc | awk -F "=" '{print $2}' | sed 's/\/oraInventory//g'`
OH=`pwdx "$DBPID" | cut -d ":" -f 2 | sed 's/ \//\//g' | sed 's/\/dbs//g'`
RDIR=`pwd`
UPATH=`runuser -l "$VUSER" -c "echo "$PATH""`
VPATH=$OH/bin:$UPATH
ENVF=$RDIR/$DB.env
SQL=@?/rdbms/admin/catbundle.sql psu apply
#SQL=@$RDIR/test.sql


#Creacion fichero env`
chmod 777 $RDIR
touch $ENVF
chmod 777 $ENVF
cat <<-EOF >$ENVF
export ORACLE_SID=$DB
export ORACLE_BASE=$OB
export ORACLE_HOME=$OH
export PATH=$VPATH
export LD_LIBRARY_PATH=$OH/lib:/lib:/usr/lib
EOF

#Ejecucion sql
runuser -l $DBUSER -c ". ${ENVF} ; sqlplus -s / as sysdba $SQL"

