#!/bin/bash
#VARIABLES

VHOSTNAME=`hostname`
OSARCH=`uname -i`
OSVERSION=`cat /etc/redhat-release`
ALL_DATABASES=`ps -ef |grep ora_pmon |grep -v grep | awk '{print $8}' |cut -c 10-`

#FUNCTIONS

#Creacion directorio base de ejecucion
function create_exec_dir(){
BASEDIR=/tmp
TMPDIR=`mktemp -p "$BASEDIR" -d`
chmod 777 $TMPDIR
mkdir $TMPDIR/ENV
mkdir $TMPDIR/OUT
mkdir $TMPDIR/SQL
chmod -R 777 $TMPDIR
OUTDIR=$TMPDIR/OUT
ENVDIR=$TMPDIR/ENV
SQLDIR=$TMPDIR/SQL
}
#Eliminacion directorio base de ejecucion
function remove_exec_dir(){
rm -rf $TMPDIR
}
#Fichero de Output
function output_generation(){
echo "
HOSTNAME=		$VHOSTNAME
OS_VERSION=		$OSVERSION
ARCHITECTURE=	$OSARCH
SID=			$DB
ORACLE_BASE=	$VORACLE_BASE
ORACLE_HOME=	$VORACLE_HOME
USER=			$VUSER
DB_VERSION=		$DBVERSION
PSU_VERSION=	$PSU
OPATCH_VERSION=	$OPATCHVERSION
" > $OUTDIR/$VHOSTNAME_$DB.log
}
#Fichero env
function env_generation(){
touch $ENVDIR/$DB.env
cat <<-EOF > $ENVDIR/$DB.env
export ORACLE_SID=$DB 
export ORACLE_HOME=$VORACLE_HOME 
export PATH=$VPATH 
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib 
EOF
chmod 777 $ENVDIR/$DB.env
}
#Ejecucion PL/SQL (Parametro $1 path script sql $2 path spool sql)
function exec_sql(){
local SQL_SCRIPT=$1
local LOG=$2
runuser -l $VUSER -c ". $ENVDIR/$DB.env ; sqlplus -s / as sysdba @$SQL_SCRIPT" > $LOG
}

#MAIN

create_exec_dir

#Procedure PL/SQL
cat <<-EOF > $SQLDIR/procedure.sql
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
	
cat <<-EOF > $SQLDIR/status.sql
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

chmod 777 $SQLDIR/*.sql
	
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

env_generation

#Ejecucion status.sql

exec_sql $SQLDIR/status.sql $SQLDIR/status.log
DBSTATUS=`cat $SQLDIR/status.log | grep DBSTATUS | cut -d "=" -f 2`

#Comprobacion status BBDD
if [[ $DBSTATUS == OPEN || $DBSTATUS == MOUNTED ]];
    then
#Ejecucion procedure.sql

exec_sql $SQLDIR/procedure.sql $SQLDIR/procedure.log
DBVERSION=`cat $SQLDIR/procedure.log | grep DBVERSION | cut -d "=" -f 2`

#Version OPATCH y PSU

OPATCHVERSION=`runuser -l $VUSER -c "$VORACLE_HOME/OPatch/opatch version | cut -d ":" -f 2| sed 's/OPatch succeeded.//g' | awk 'NF > 0'"`
PSU=`runuser -l $VUSER -c "$VORACLE_HOME/OPatch/opatch lsinventory | grep 'Database Patch Set Update'| awk ' NR == 1 ' | awk -F ": " '{print $3}' | awk -F "(" '{print $1}'"`

#Insercion resultados en log

output_generation

    fi
done
