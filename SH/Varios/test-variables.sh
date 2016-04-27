#!/bin/bash
#Variables Principales
OSHOSTNAME=`hostname`
OSARCHITECTURE=`uname -i`
OS=`uname -o`
RDIR=`pwd`
VPATH=$PATH
ALL_DATABASES=`ps -ef |grep ora_pmon |grep -v grep | awk '{print $8}' |cut -c 10-`
#Bucle por cada base de datos arrancada
for DB in $ALL_DATABASES
do
#Variables Bucle
	VUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
	VPID=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $2}'`
	VORACLE_HOME=`pwdx "$VPID"| sed 's/\/dbs//g' | cut -d ":" -f 2`
	ORACLE_HOME=$VORACLE_HOME
	PATH=$ORACLE_HOME/bin:$PATH
	ORACLE_SID=$DB
	ORACLE_TERM=xterm
	LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
#Export variables de entorno para Oracle	
	export ORACLE_SID=$ORACLE_SID
	export ORACLE_HOME=$ORACLE_HOME
	export PATH=$PATH
#Ejecucion codigo PL/SQL
	su -m $VUSER -c sqlplus / as sysdba @<<-EOF
	set serveroutput on;
	set verify on
	set termout on
	set feedback on
	set linesize 130

	DECLARE
		PSU			varchar2(20);
		VERSION		varchar2(10);
	BEGIN
	---
	--- PSU
	---
	SELECT * into PSU FROM (select comments from sys.registry$history WHERE bundle_series = 'PSU' ORDER BY action_time) psu WHERE rownum <= 1 ORDER BY rownum;
	---
	--- VERSION
	---
	SELECT version into VERSION FROM v$instance;
	--- PRINT 
	dbms_output.put_line('DBPSU='PSU);
	dbms_output.put_line('DBVERSION='VERSION);
	---
	END;
	/
	exit;
	EOF
#Insercion resultados en log
	echo " $OHOSTNAME : $OS : $OSARCHITECTURE : $ORACLE_HOME : $ORACLE_BASE : $DB : $DBVERSION : $OPATCHVERSION : $DBPSU : $RAC : $DATAGUARD" >> $RDIR/log.log	
#Eliminacion variables de entorno
	unset ORACLE_SID
	unset ORACLE_HOME
	unset LD_LIBRARY_PATH
	unset ORACLE_TERM
	export PATH=$VPATH
done
