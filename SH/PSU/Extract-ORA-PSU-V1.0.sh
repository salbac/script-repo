#!/bin/bash
#----------------------------------------------------------------------------
#--     Id: Extract-ORA-PSU-V1.0 2015-08-17 
#----------------------------------------------------------------------------
#--     IT Now
#--     
#----------------------------------------------------------------------------
#--     File-Name........:  Extract-ORA-PSU-V1.0.sh
#--     Author...........:  Sergio Alba 
#--     Editor...........:  Sergio Alba
#--     Date.............:  2015-08-17
#--     Revision.........:  0
#--     Purpose..........:  Recojer la informacion necesaria par determinar si el sistema cumple con los requerimientos del PSU a aplicar.		 
#--     Usage............:  ./Extract-ORA-PSU-V1.0.sh
#--     Group/Privileges.:  root
#--     Input parameters.:  ninguno
#--     Called by........:  -
#--     Restrictions.....:  -
#--     Notes............:
#----------------------------------------------------------------------------
#--		 Revision history: 
#----------------------------------------------------------------------------

#Variables principales para establecer el directorio de ejecucion e informacion basica del servidor.
OSHOSTNAME=`hostname`
OSARCHITECTURE=`uname -i`
OS=`uname -o`
RDIR=`pwd`
ENVFILE=$RDIR/env
ALL_DATABASES=`ps -ef |grep ora_pmon |grep -v grep | awk '{print $8}' |cut -c 10-`
#Limpieza log antiguo en el servidor
rm -rf $RDIR/$HOSTNAME.log
#Procedure PL/SQL
cat <<-EOF > $RDIR/procedure.sql
		set serveroutput on;
	set verify on
	set termout on
	set feedback on
	set linesize 130

	DECLARE
		ora_psu			varchar2(20);
		ora_version		varchar2(10);
		ora_rac			varchar2(10);
		ora_dg			varchar2(10);
		ora_dg_type		varchar2(10);
	BEGIN
	---
	--- PSU
	---
	SELECT * INTO ora_psu FROM (SELECT comments FROM sys.registry\$history WHERE bundle_series = 'PSU' ORDER BY action_time) psu WHERE ROWNUM <= 1 ORDER BY rownum;
	---
	--- VERSION
	---
	SELECT version INTO ora_version FROM v\$instance;
	---
	---RAC
	---
	SELECT value INTO ora_rac FROM v\$parameter WHERE name='cluster_database';
	---
	---Data Guard
	---
	SELECT value INTO ora_dg FROM v\$parameter WHERE name='dg_broker_start';
	---
	---Data Guard TYPE
	---
	SELECT database_role INTO ora_dg_type FROM v\$database;
	---
	--- PRINT 
	---
	dbms_output.put_line('DBPSU='||ora_psu);
	dbms_output.put_line('DBVERSION='||ora_version);
	dbms_output.put_line('DBRAC='||ora_rac);
	dbms_output.put_line('DBDG='||ora_dg);
	dbms_output.put_line('DBDGT='||ora_dg_type);
	
	---
	END;
	/
	exit;
	EOF
#Permisos procedure
chmod 777 $RDIR/procedure.sql
#Bucle por cada base de datos arrancada
for DB in $ALL_DATABASES
do
#Variables necesarias para el bucle
	VUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
	VPID=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $2}'`
	VORACLE_HOME=`pwdx "$VPID"| sed 's/\/dbs//g' | cut -d ":" -f 2 | cut -c 2-`
	UPATH=`runuser -l "$VUSER" -c "echo "$PATH""` 
	VPATH=$VORACLE_HOME/bin:$UPATH
	VORACLE_BASE=`df -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $6}'`
#Creacion de fichero de variables 
	touch $ENVFILE
	chmod 777 $ENVFILE
	echo export ORACLE_SID=$DB >>$ENVFILE
	echo export ORACLE_HOME=$VORACLE_HOME >>$ENVFILE
	echo export PATH=$VPATH >>$ENVFILE
	echo export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib >>$ENVFILE
	echo export RDIR=$RDIR >>$ENVFILE
#Ejecucion scripts sql
	runuser -l $VUSER -c ". ${ENVFILE} ; sqlplus -s / as sysdba @$RDIR/procedure.sql" > $RDIR/spool.log
	DBVERSION=`cat $RDIR/spool.log | grep DBVERSION | cut -d "=" -f 2`
	DBPSU=`cat $RDIR/spool.log | grep DBPSU | cut -d "=" -f 2`
	RAC=`cat $RDIR/spool.log | grep DBRAC | cut -d "=" -f 2`
	DATAGUARD=`cat $RDIR/spool.log | grep DBDG | cut -d "=" -f 2`
	DATAGUARDTYPE=`cat $RDIR/spool.log | grep DBDGT | cut -d "=" -f 2`
#Version OPATCH
	OPATCHVERSION=`runuser -l $VUSER -c "$VORACLE_HOME/OPatch/opatch version | cut -d ":" -f 2| sed 's/OPatch succeeded.//g' | awk 'NF > 0'"`
#Insercion resultados en log
	touch $RDIR/$HOSTNAME.log
	chmod 650 $HOSTNAME.log
	echo " $HOSTNAME : $OS : $OSARCHITECTURE : $VORACLE_HOME : $VORACLE_BASE : $DB : $DBVERSION : $OPATCHVERSION : $DBPSU : $RAC : $DATAGUARD : $DATAGUARDTYPE" >> $RDIR/$HOSTNAME.log	
#	echo "INSERT INTO table (HOSTNAME,OS,OSARCHITECTURE,ORACLE_HOME,ORACLE_BASE,DB,DBVERSION,OPATCHVERSION,DBPSU,RAC,DATAGUARD,DATAGUARDTYPE) 
#	VALUES ('$HOSTNAME','$OS','$OSARCHITECTURE','$VORACLE_HOME','$VORACLE_BASE','$DB,$DBVERSION','$OPATCHVERSION','$DBPSU','$RAC','$DATAGUARD','$DATAGUARDTYPE')">> $RDIR/$HOSTNAME-insert.sql
	#Eliminacion ficheros temporales
	rm -rf $ENVFILE $RDIR/spool.log $RDIR/procedure.sql
done
