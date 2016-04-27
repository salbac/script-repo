#!/bin/bash

#Variables principales para establecer el directorio de ejecucion e informacion basica del servidor.
OSARCHITECTURE=`uname -i`
OS=`uname -o`
OSVERSION=`cat /etc/redhat-release`
RDIR=/tmp/test
ENVFILE=$RDIR/env
VHOSTNAME=`hostname`
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
                ora_psu                 varchar2(20);
                ora_version             varchar2(10);
                ora_rac                 varchar2(10);
                ora_dg                  varchar2(10);
                ora_dg_type             varchar2(10);
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
	
cat <<-EOF > $RDIR/status.sql
	        set serveroutput on;
        set verify on
        set termout on
        set feedback on
        set linesize 130

        DECLARE
                ora_status              varchar2(20);
        BEGIN
        ---
        --- STATUS
        ---
        select status INTO ora_status from v\$instance;
        ---
        --- PRINT
        ---
        dbms_output.put_line('DBSTATUS='||ora_status);
        ---
        END;
        /
        exit;
	EOF
	
		
#Permisos ficheros sql
chmod 777 $RDIR/procedure.sql
chmod 777 $RDIR/status.sql
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
        VMP=`df -h -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $6}'`
        VSAIZ=`df -h -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $2}'`
#Creacion de fichero de variables
        touch $ENVFILE
        chmod 777 $ENVFILE
        echo export ORACLE_SID=$DB >>$ENVFILE
        echo export ORACLE_HOME=$VORACLE_HOME >>$ENVFILE
        echo export PATH=$VPATH >>$ENVFILE
        echo export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib >>$ENVFILE
        echo export RDIR=$RDIR >>$ENVFILE
#Ejecucion status.sql
        runuser -l $VUSER -c ". ${ENVFILE} ; sqlplus -s / as sysdba @$RDIR/status.sql" > $RDIR/status.log
        DBSTATUS=`cat $RDIR/status.log | grep DBSTATUS | cut -d "=" -f 2`
#Comprobacion status BBDD
        if [[ $DBSTATUS == OPEN || $DBSTATUS == MOUNTED ]];
        then
        #Ejecucion procedure.sql
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
                chmod 777 $HOSTNAME.log
                echo " $VHOSTNAME | $OS | $OSARCHITECTURE | $OSVERSION | $VORACLE_BASE | $VORACLE_HOME | $VMP | $VSIZE | $DB | $DBVERSION | $DBPSU | $RAC | $DATAGUARD | $DATAGUARDTYPE | $OPATCHVERSION "  >> $RDIR/$HOSTNAME.log
                rm -rf $ENVFILE $RDIR/spool.log $RDIR/status.log 
        fi
done
#Eliminacion ficheros temporales
        rm -rf $RDIR/status.log $RDIR/spool.log $RDIR/status.sql $RDIR/procedure.sql

