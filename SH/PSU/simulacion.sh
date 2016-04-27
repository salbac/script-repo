#!/bin/bash
#----------------------------------------------------------------------------
#--     Id: 
#----------------------------------------------------------------------------
#--     IT Now
#--     
#----------------------------------------------------------------------------
#--     File-Name........:  
#--     Author...........:  Sergio Alba 
#--     Editor...........:  Sergio Alba
#--     Date.............:  
#--     Revision.........:  
#--     Purpose..........:  	 
#--     Usage............:  
#--     Group/Privileges.:  
#--     Input parameters.:  
#--     Called by........:  
#--     Restrictions.....:  
#--     Notes............:
#----------------------------------------------------------------------------
#--		 Revision history: 
#----------------------------------------------------------------------------

#FUNCIONES
#Backup Binarios Oracle 
function bckora(){
	#Variables funcion
	local BINARY_TYPE=$1
	#Seleccion tipo de backup
	case "$BINARY_TYPE" in
		DB)
		tar zcvf /opt/oracle_2/admin/work/Patch_PSU/ora_db_`hostname`_`date +%Y%m%d`.tar.gz $ORACLE_HOME
		;;
		GI)
		tar zcf /opt/oracle_2/admin/work/Patch_PSU/ora_grid_soft_`hostname`_`date +%Y%m%d`.tar.gz $GRID_HOME
		;;
		OI)
		tar zcvf /opt/oracle_2/admin/work/Patch_PSU/ora_inventory_`hostname`_`date +%Y%m%d`.tar.gz $ORACLE_BASE/oraInventory
		;;
		OCR)
		$GRID_HOME/bin/ocrconfig -local -export /opt/oracle_2/admin/work/Patch_PSU/ocr_`hostname`_`date +%Y%m%d`.bak
		;;
	esac
}
#Creacion de directorios pre clonado
function directory (){
#Variables
local DBVERSION=$1
local ORACLE_BASE=$2
#Creacion estructura de directorios
cd /opt/oracle_2
mkdir product
mkdir product/$DBVERSION
mkdir product/$DBVERSION/db_1
mkdir admin
mkdir admin/work
mkdir admin/work/Patch_PSU
mkdir admin/work/Patch_PSU/REPOSITORIO
chown $VUSER:oinstall -R /opt/oracle_2
chmod 775 /opt/oracle_2
chmod 775 /opt/oracle_2/product/
chmod 775 /opt/oracle_2/product/$DBVERSION/
chmod 750 /opt/oracle_2/product/$DBVERSION/db_1
cd $ORACLE_BASE
ln -s /opt/oracle_2/admin
ln -s /opt/oracle_2/product
}
#Funcion que conecta con el repositorio de software y copia el parche correspondiente segun los parametros de entrada
function repo(){
local PATCH=$1
local PTYPE=$2 
mount 10.241.216.24:/mnt/REPOSITORIO /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO
if [ $PTYPE = DB ];
	then
		case $PATCH in #Parches DB
			linux_11.2.0.4_64)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/p19769489_112040_Linux-x86-64.zip /opt/oracle_2/admin/work/Patch_PSU/ 
			unzip /opt/oracle_2/admin/work/Patch_PSU/p19769489_112040_Linux-x86-64.zip
			;;
			linux_11.2.0.4)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/p19769489_112040_LINUX.zip /opt/oracle_2/admin/work/Patch_PSU/
			unzip /opt/oracle_2/admin/work/Patch_PSU/p19769489_112040_LINUX.zip
			;;
			linux_11.2.0.3_64)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/p19769496_112030_Linux-x86-64.zip /opt/oracle_2/admin/work/Patch_PSU/
			unzip /opt/oracle_2/admin/work/Patch_PSU/p19769496_112030_Linux-x86-64.zip
			;;
			linux_11.2.0.3)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/p19769496_112030_LINUX.zip /opt/oracle_2/admin/work/Patch_PSU/
			unzip /opt/oracle_2/admin/work/Patch_PSU/p19769496_112030_LINUX.zip
			;;
		esac
	else
		case $PATCH in #Parches Grid Infraestructure
			linux_11.2.0.4_64)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/p19955028_112040_Linux-x86-64.zip /opt/oracle_2/admin/work/Patch_PSU/
			;;
			linux_11.2.0.4)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/p19955028_112040_LINUX.zip /opt/oracle_2/admin/work/Patch_PSU/
			;;
			linux_11.2.0.3_64)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/p19971343_112030_Linux-x86-64.zip /opt/oracle_2/admin/work/Patch_PSU/
			;;
			linux_11.2.0.3)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/p19971343_112030_LINUX.zip /opt/oracle_2/admin/work/Patch_PSU/
			;;
		esac
	fi
}
#Prerequisitos oracle PSU
function prereq(){
#Variables
local USER=$1
local ORACLE_HOME=$2
local PATCH=$3
local RESULT=`cat prereq.log | grep fail | grep -v grep` 
#Prerequisitos
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -oh $ORACLE_HOME -phBaseDir $PATCH >> prereq.log
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -oh $ORACLE_HOME -phBaseDir $PATCH >> prereq.log
#sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -oh $ORACLE_HOME -phBaseDir $PATCH >> prereq.log
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -oh $ORACLE_HOME -phBaseDir $PATCH >> prereq.log
if [ -s $RESULT ];
then
echo "Fallo en prerequisitos"
exit 1
fi
}
#Fichero respuesta Oracle PSU
function resp_file(){
#Variables
local ORACLE_HOME=$1
local PATHRF=$2
#Response file
$ORACLE_HOME/OPatch/ocm/bin/emocmrsp -no_banner -output $PATHRF/file.rsp
}
#Clonado binarios ORACLE
function clone(){
#Variables
local ORACLE_HOME=$1
local ORACLE_BASE=$2
local OSDBA_GROUP=`cat $ORACLE_HOME/rdbms/lib/config.c | grep 'define SS_DBA_GRP' | awk -F '"' '{print $2}'`
local OSOPER_GROUP=`cat $ORACLE_HOME/rdbms/lib/config.c | grep 'define SS_OPER_GRP' | awk -F '"' '{print $2}'`
#Copiado
tar cf - -C $ORACLE_HOME /opt/oracle_2/product/$DBVERSION/db_1 | tar xf - #REVISAR::::::
#Clonado
if [ -s $OSOPER_GROUP ];
	then 
		perl $ORACLE_HOME/clone/bin/clone.pl ORACLE_HOME=$ORACLE_HOME ORACLE_HOME_NAME=MyOraHome_db_2 ORACLE_BASE=$ORACLE_BASE OSDBA_GROUP=$OSDBA_GROUP OSOPER_GROUP=$OSOPER_GROUP
	else
		OSOPER_GROUP=$OSDBA_GROUP
		perl $ORACLE_HOME/clone/bin/clone.pl ORACLE_HOME=$ORACLE_HOME ORACLE_HOME_NAME=MyOraHome_db_2 ORACLE_BASE=$ORACLE_BASE OSDBA_GROUP=$OSDBA_GROUP OSOPER_GROUP=$OSOPER_GROUP
	fi
}
#Aplicacion PSU via Opatch
function fopatch(){
#Variables
local PSUPATCH=$1
local ORACLE_HOME=$2
local RESP=$3
local DBVERSION=$4
local OSARCH=$5
local VOPATCH=`$ORACLE_HOME/OPatch/opatch version | grep 'OPatch Version' | awk -F ":" '{print $2}'`
local OP3=`echo $VOPATCH | awk -F "." '{print $4}'`
local OP4=`echo $VOPATCH | awk -F "." '{print $5}'`
#Version OPATCH
if [ $OSARCH = x86_64 ];
	then
		case $DBVERSION in
		11.2.0.3)
			if [[ $OP3 -ge 3 ]] && [[ $OP4 -ge 0 ]];
			then
			echo "Opatch ok"
			else 
			#Actualizar OPATCH
			mv $ORACLE_HOME/OPatch OPatch-BCK #Plantear eliminar este backup
			cp $ORACLE_BASE/admin/work/APAR/REPO/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			unzip p6880880_112000_LINUX-x86-64.zip
			fi
		;;
		11.2.0.4)
			if [[ $OP3 -ge 3 ]] && [[ $OP4 -ge 6 ]];
			then
			echo "Opatch ok"
			else 
			#Actualizar OPATCH
			mv $ORACLE_HOME/OPatch OPatch-BCK
			cp $ORACLE_BASE/admin/work/APAR/REPO/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			unzip p6880880_112000_LINUX-x86-64.zip
			fi
		;;
		esac
	else
		case $DBVERSION in
		11.2.0.3)
			if [[ $OP3 -ge 3 ]] && [[ $OP4 -ge 0 ]];
			then
			echo "Opatch ok"
			else 
			#Actualizar OPATCH
			mv $ORACLE_HOME/OPatch OPatch-BCK
			cp $ORACLE_BASE/admin/work/APAR/REPO/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			unzip p6880880_112000_LINUX.zip
			fi
		;;
		11.2.0.4)
			if [[ $OP3 -ge 3 ]] && [[ $OP4 -ge 6 ]];
			then
			echo "Opatch ok"
			else 
			#Actualizar OPATCH
			mv $ORACLE_HOME/OPatch OPatch-BCK
			cp $ORACLE_BASE/admin/work/APAR/REPO/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			unzip p6880880_112000_LINUX.zip
			fi
		;;
		esac
	fi
#Aplicacion PSU
	if [ $RAC = 'TRUE' ];
		then
		$ORACLE_HOME/OPatch/opatch auto $PSUPATCH -oh $ORACLE_HOME -ocmrf $RESP
		else
		$ORACLE_HOME/OPatch/opatch apply $PSUPATCH -oh $ORACLE_HOME -ocmrf $RESP
	fi
}
#Funcion de pausa
function pause(){
   read -p "$*"
}
#Variables
RDIR=`pwd`
ENVFILE=$RDIR/env
ALL_DATABASES=`ps -ef |grep ora_pmon |grep -v grep | awk '{print $8}' |cut -c 10-`
OSARCH=`uname -i`
#Catalogo PSU
cat <<-EOF > $RDIR/catalogo.log
11.2.0.3.0 | 11.2.0.3.13
11.2.0.4.0 | 11.2.0.4.5
	EOF
#Script SQL version DB
cat <<-EOF > $RDIR/dbversion.sql
	set serveroutput on;
        set verify on
        set termout on
        set feedback on
        set linesize 130

        DECLARE
                ora_version                 varchar2(20);
		BEGIN
		---
		--- DB Version
		---
		SELECT version INTO ora_version FROM v\$instance;
		---
		--- Print 
		---
		dbms_output.put_line('DBVERSION='||ora_version);
		---
		END;
        /
        exit;
		
	EOF
#
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
chmod 777 $RDIR/dbversion.sql
chmod 777 $RDIR/status.sql
touch $RDIR/home.log
chmod 777 $RDIR/home.log
#Bucle para extraer la version de las BBDD y su Oracle_Home
for DB in $ALL_DATABASES
do
#Variables internas del bucle
	VUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
    VPID=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $2}'`
    VORACLE_HOME=`pwdx "$VPID"| sed 's/\/dbs//g' | cut -d ":" -f 2 | cut -c 2-`
    UPATH=`runuser -l "$VUSER" -c "echo "$PATH""`
    VPATH=$VORACLE_HOME/bin:$UPATH
    VORACLE_BASE=`df -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $6}'`
#Creacion de fichero de variables
    touch $ENVFILE
    chmod 777 $ENVFILE
    >$ENVFILE
	echo export ORACLE_SID=$DB >>$ENVFILE
    echo export ORACLE_HOME=$VORACLE_HOME >>$ENVFILE
    echo export PATH=$VPATH >>$ENVFILE
    echo export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib >>$ENVFILE
    echo export RDIR=$RDIR >>$ENVFILE
#Ejecucion status.sql
        runuser -l $VUSER -c ". ${ENVFILE} ; sqlplus -s / as sysdba @$RDIR/status.sql" > $RDIR/status.log
        DBSTATUS=`cat $RDIR/status.log | grep DBSTATUS | cut -d "=" -f 2`
#Comprobacion status BBDD
		if [ "$DBSTATUS" = OPEN ] || [ "$DBSTATUS" = MOUNTED ];
       then
        #Ejecucion dbversion.sql
                runuser -l $VUSER -c ". ${ENVFILE} ; sqlplus -s / as sysdba @$RDIR/dbversion.sql" > $RDIR/spool.log
                DBVERSION=`cat $RDIR/spool.log | grep DBVERSION | cut -d "=" -f 2`
        #Insercion resultados en log
		echo "$VORACLE_HOME | $DBVERSION " >> $RDIR/home.log       
		fi
done	
#Extraccion de los Oracle_Home a parchear con su version de DB
cat $RDIR/home.log | sort -u > lineas.log   	
LINEAS=`cat lineas.log | wc -l`
CONTADOR=0
LIN=1
while [  $CONTADOR -lt $LINEAS ]; 
	do
    VERSION=`awk -v lin="$LIN" ' NR == lin ' lineas.log | awk -F "|" '{print $2}'`
	VORACLE_HOME=`awk -v lin="$LIN" ' NR == lin ' lineas.log | awk -F "|" '{print $1}'`
	PSU=`cat $RDIR/catalogo.log | grep $VERSION | awk -F "|" '{print $2}'`
		case "$VERSION" in
		" 11.2.0.3.0 ")
		if [ OSARCH = x86_64 ];
		then
		directory 11.2.0.3 $VORACLE_BASE
		pause 'Pulsar [Enter] para continuar...'
		echo "bckora OI"
		pause 'Pulsar [Enter] para continuar...'
		echo "repo linux_11.2.0.3_64 DB"
		pause 'Pulsar [Enter] para continuar...'
		echo "clone $VORACLE_HOME $VORACLE_BASE"
		pause 'Pulsar [Enter] para continuar...'
		echo "resp_file $VORACLE_HOME /opt/oracle_2/admin/work/Patch_PSU/file.rsp"
		pause 'Pulsar [Enter] para continuar...'
		echo "fopatch p19769496 $VORACLE_HOME /opt/oracle_2/admin/work/Patch_PSU/file.rsp $DBVERSION $OSARCH"
		pause 'Pulsar [Enter] para continuar...'
		else
		directory 11.2.0.3 $VORACLE_BASE
		pause 'Pulsar [Enter] para continuar...'
		echo "bckora OI"
		pause 'Pulsar [Enter] para continuar...'
		echo "repo linux_11.2.0.3 DB"
		pause 'Pulsar [Enter] para continuar...'
		echo "clone $VORACLE_HOME $VORACLE_BASE"
		pause 'Pulsar [Enter] para continuar...'
		echo "resp_file $VORACLE_HOME /opt/oracle_2/admin/work/Patch_PSU/file.rsp"
		pause 'Pulsar [Enter] para continuar...'
		echo "fopatch p19769496 $VORACLE_HOME /opt/oracle_2/admin/work/Patch_PSU/file.rsp $DBVERSION $OSARCH"
		pause 'Pulsar [Enter] para continuar...'
		fi
		;;
		" 11.2.0.4.0 ")
		if [ OSARCH = "x86_64" ];
		then 
		directory 11.2.0.4 $VORACLE_BASE
		pause 'Pulsar [Enter] para continuar...'
		echo "bckora OI"
		pause 'Pulsar [Enter] para continuar...'
		echo "repo linux_11.2.0.4_64 DB"
		pause 'Pulsar [Enter] para continuar...'
		echo "clone $VORACLE_HOME $VORACLE_BASE"
		pause 'Pulsar [Enter] para continuar...'
		echo "resp_file $VORACLE_HOME /opt/oracle_2/admin/work/Patch_PSU/file.rsp"
		pause 'Pulsar [Enter] para continuar...'
		echo "fopatch p19769489 $VORACLE_HOME /opt/oracle_2/admin/work/Patch_PSU/file.rsp $DBVERSION $OSARCH"
		pause 'Pulsar [Enter] para continuar...'
		else
		directory 11.2.0.4 $VORACLE_BASE
		pause 'Pulsar [Enter] para continuar...'
		echo "bckora OI"
		pause 'Pulsar [Enter] para continuar...'
		echo "repo linux_11.2.0.4 DB"
		pause 'Pulsar [Enter] para continuar...'
		echo "clone $VORACLE_HOME $VORACLE_BASE"
		pause 'Pulsar [Enter] para continuar...'
		echo "resp_file $VORACLE_HOME /opt/oracle_2/admin/work/Patch_PSU/file.rsp"
		pause 'Pulsar [Enter] para continuar...'
		echo "fopatch p19769489 $VORACLE_HOME /opt/oracle_2/admin/work/Patch_PSU/file.rsp $DBVERSION $OSARCH"
		pause 'Pulsar [Enter] para continuar...'		
		fi
		;;
	esac
	let CONTADOR=CONTADOR+1 
	let LIN=LIN+1
done
