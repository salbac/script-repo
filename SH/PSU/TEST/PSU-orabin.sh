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
	local ORA_INV=`cat /etc/oraInst.loc | grep inventory | awk -F "=" '{print $2}'`
	#Seleccion tipo de backup
	case "$BINARY_TYPE" in
		DB)
		tar zcvf /opt/oracle_2/admin/work/Patch_PSU/ora_db_`hostname`_`date +%Y%m%d`.tar.gz $ORACLE_HOME
		;;
		GI)
		tar zcf /opt/oracle_2/admin/work/Patch_PSU/ora_grid_soft_`hostname`_`date +%Y%m%d`.tar.gz $GRID_HOME
		;;
		OI)
		tar zcvf /opt/oracle_2/admin/work/Patch_PSU/ora_inventory_`hostname`_`date +%Y%m%d`.tar.gz $ORA_INV
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
#cp /media/sf_TEMP/PSU/* /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO
#cp /media/sf_TEMP/Opatch/* /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO
if [ $PTYPE = DB ];
	then
		case $PATCH in #Parches DB
			linux_11.2.0.4_64)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/PSU/p19769489_112040_Linux-x86-64.zip /opt/oracle_2/admin/work/Patch_PSU/ 
			cd /opt/oracle_2/admin/work/Patch_PSU
			unzip /opt/oracle_2/admin/work/Patch_PSU/p19769489_112040_Linux-x86-64.zip
			;;
			linux_11.2.0.4)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/PSU/p19769489_112040_LINUX.zip /opt/oracle_2/admin/work/Patch_PSU/
			cd /opt/oracle_2/admin/work/Patch_PSU
			unzip /opt/oracle_2/admin/work/Patch_PSU/p19769489_112040_LINUX.zip
			;;
			linux_11.2.0.3_64)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/PSU/p19769496_112030_Linux-x86-64.zip /opt/oracle_2/admin/work/Patch_PSU/
			cd /opt/oracle_2/admin/work/Patch_PSU
			unzip /opt/oracle_2/admin/work/Patch_PSU/p19769496_112030_Linux-x86-64.zip
			;;
			linux_11.2.0.3)
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/PSU/p19769496_112030_LINUX.zip /opt/oracle_2/admin/work/Patch_PSU/
			cd /opt/oracle_2/admin/work/Patch_PSU
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
#Clonado binarios ORACLE
function clone(){
#Variables
local ORACLE_HOME=$1
local NEW_ORACLE_BASE=$2
local NEW_ORACLE_HOME=$3
local DBVERSION=$4
local OSDBA_GROUP=`cat $ORACLE_HOME/rdbms/lib/config.c | grep 'define SS_DBA_GRP' | awk -F '"' '{print $2}'`
local OSOPER_GROUP=`cat $ORACLE_HOME/rdbms/lib/config.c | grep 'define SS_OPER_GRP' | awk -F '"' '{print $2}'`
#Copiado
cd /opt/oracle_2/product/$DBVERSION/db_1/
tar cf - -C $ORACLE_HOME . | tar xf - #REVISAR::::::
#Clonado
if [ -s $OSOPER_GROUP ];
	then 
		runuser -l $VUSER -c "perl $ORACLE_HOME/clone/bin/clone.pl ORACLE_HOME=$NEW_ORACLE_HOME ORACLE_HOME_NAME=MyOraHome_db_2 ORACLE_BASE=$NEW_ORACLE_BASE OSDBA_GROUP=$OSDBA_GROUP OSOPER_GROUP=$OSOPER_GROUP"
	else
		OSOPER_GROUP=$OSDBA_GROUP
		runuser -l $VUSER -c "perl $ORACLE_HOME/clone/bin/clone.pl ORACLE_HOME=$NEW_ORACLE_HOME ORACLE_HOME_NAME=MyOraHome_db_2 ORACLE_BASE=$NEW_ORACLE_BASE OSDBA_GROUP=$OSDBA_GROUP OSOPER_GROUP=$OSOPER_GROUP"
	fi
}
#Aplicacion PSU via Opatch
function fopatch(){
#Variables
local PSUPATCH=$1
local ORACLE_HOME=$2
local RESP=$3
local ARCH=$4
local USER=`ls -la /opt/oracle_2/product/11.2.0.3/db_1/ | grep OPatch | awk '{print $3}' | sort -u`
local GROUP=`ls -la /opt/oracle_2/product/11.2.0.3/db_1/ | grep OPatch | awk '{print $4}' | sort -u`
#Version OPATCH
		case $ARCH in
		32)
			mv $ORACLE_HOME/OPatch OPatch-BCK #Plantear eliminar este backup
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/Opatch/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			cd $ORACLE_HOME
			unzip p6880880_112000_LINUX.zip
			chown -R $USER:$GROUP OPatch
		;;
		64)
			mv $ORACLE_HOME/OPatch OPatch-BCK
			cp /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/Opatch/p6880880_112000_Linux-x86-64.zip $ORACLE_HOME
			mkdir OPatch
			cd $ORACLE_HOME
			unzip p6880880_112000_Linux-x86-64.zip
			chown -R $USER:$GROUP OPatch
		;;
		esac
#Aplicacion PSU
	if [ $RAC = 'TRUE' ];
		then
		runuser -l $VUSER -c "$ORACLE_HOME/OPatch/opatch auto $PSUPATCH -oh $ORACLE_HOME -silent -ocmrf $RESP"
		else
		runuser -l $VUSER -c "$ORACLE_HOME/OPatch/opatch apply $PSUPATCH -oh $ORACLE_HOME -silent -ocmrf $RESP"
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
	VORACLE_BASE=`cat /etc/oraInst.loc | grep inventory | awk -F "=" '{print $2}' | sed 's/\/oraInventory//g'`
#	VORACLE_BASE=`df -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $6}'`
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
		if [ $OSARCH = x86_64 ];
		then
		echo "Start:" | date >> $RDIR/time.log
		directory 11.2.0.3 $VORACLE_BASE
		bckora OI
		repo linux_11.2.0.3_64 DB
		clone $VORACLE_HOME /opt/oracle_2 /opt/oracle_2/product/11.2.0.3/db_1 11.2.0.3
		fopatch /opt/oracle_2/admin/work/Patch_PSU/19769496 /opt/oracle_2/product/11.2.0.3/db_1 /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/resp.rsp 64
		echo "Finish:" | date >> $RDIR/time.log
		else
		echo "Start:" | date >> $RDIR/time.log
		directory 11.2.0.3 $VORACLE_BASE
		bckora OI
		repo linux_11.2.0.3 DB
		clone $VORACLE_HOME /opt/oracle_2 /opt/oracle_2/product/11.2.0.3/db_1 11.2.0.3
		fopatch /opt/oracle_2/admin/work/Patch_PSU/19769496 /opt/oracle_2/product/11.2.0.3/db_1 /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/resp.rsp 32
		echo "Finish:" | date >> $RDIR/time.log
		fi
		;;
		" 11.2.0.4.0 ")
		if [ $OSARCH = "x86_64" ];
		then 
		echo "Start:" | date >> $RDIR/time.log
		directory 11.2.0.4 $VORACLE_BASE
		bckora OI
		repo linux_11.2.0.4_64 DB
		clone $VORACLE_HOME /opt/oracle_2 /opt/oracle_2/product/11.2.0.4/db_1 11.2.0.4
		fopatch /opt/oracle_2/admin/work/Patch_PSU/19769496 /opt/oracle_2/product/11.2.0.4/db_1 /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/resp.rsp 64
		echo "Finish:" | date >> $RDIR/time.log
		else
		echo "Start:" | date >> $RDIR/time.log
		directory 11.2.0.4 $VORACLE_BASE
		bckora OI
		repo linux_11.2.0.4 DB
		clone $VORACLE_HOME /opt/oracle_2 /opt/oracle_2/product/11.2.0.4/db_1 11.2.0.4
		fopatch /opt/oracle_2/admin/work/Patch_PSU/19769496 /opt/oracle_2/product/11.2.0.4/db_1 /opt/oracle_2/admin/work/Patch_PSU/REPOSITORIO/PSU_REPO/resp.rsp 32
		echo "Finish:" | date >> $RDIR/time.log
		fi
		;;
	esac
	let CONTADOR=CONTADOR+1 
	let LIN=LIN+1
done

