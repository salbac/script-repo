#!/bin/bash
#----------------------------------------------------------------------------
#--     Id: 
#----------------------------------------------------------------------------
#--     
#--     
#----------------------------------------------------------------------------
#--     File-Name........:  ORA_EXEC_SQL.sh
#--     Author...........:  Sergio Alba 
#--     Editor...........:  Sergio Alba
#--     Date.............:  1/2/2016
#--     Revision.........:  
#--     Purpose..........:  Lanzadera de scripts SQL en todas las BBDD Oracle activas 
#--     Usage............:  ORA_EXEC_SQL.sh script.sql
#--     Group/Privileges.:  root
#--     Input parameters.:  Nombre script SQL
#--     Called by........:  
#--     Restrictions.....:  Usar desde /tmp (Para evitar problemas con los permisos en directorios intermedios)
#--     Notes............:	
#----------------------------------------------------------------------------
#--		 Revision history: 
#--							SA: Se agrega control par a ver si hy BBDD levantadas
#----------------------------------------------------------------------------

###########
#Variables#
###########
SQL=$1
RDIR=/tmp
BASEDIR=$RDIR/ORA_EXEC_SQL
ENVFILE=$BASEDIR/env
OUTPUT=$RDIR/out
ALL_DATABASES=`ps -ef |grep ora_pmon |grep -v grep | awk '{print $8}' |cut -c 10-`
HOSTNAME=`hostname`
###########
#Funciones#
###########

######
#Main#
######
#Control parametro de entrada
if [ -z $1 ]
	then
		echo "Falta fichero SQL como parametro" > $OUTPUT/$HOSTNAME.log
		exit 1
fi
#Estructura de directorios
mkdir $RDIR/ORA_EXEC_SQL
chmod 777 $BASEDIR
mkdir $RDIR/out
chmod 777 $OUTPUT
#Permisos fichero OUTPUT
touch $OUTPUT
chmod 777 $OUTPUT
#Control instancias arrancadas en el servidor
if [ -z $ALL_DATABASES ]
	then 
		echo "No se encuentran instancias de BBDD Oracle" > $OUTPUT/$HOSTNAME.log
		cd $RDIR
		rm -rf $BASEDIR 
		exit 1
fi
#Bucle que recorre las DB levantadas 
for DB in $ALL_DATABASES
do
#Variables internas del bucle
	VUSER=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $1}'`
    VPID=`ps -ef |grep ora_pmon |grep -v grep |grep "$DB" | awk '{print $2}'`
    VORACLE_HOME=`pwdx "$VPID"| sed 's/\/dbs//g' | cut -d ":" -f 2 | cut -c 2-`
    UPATH=`/sbin/runuser -l "$VUSER" -c "echo "$PATH""`
    VPATH=$VORACLE_HOME/bin:$UPATH
    VORACLE_BASE=`df -P "$VORACLE_HOME" | sed '2,2!d' | awk '{print $6}'`
#Creacion de fichero de entorno
    touch $ENVFILE
    chmod 777 $ENVFILE
    >$ENVFILE
	echo export ORACLE_SID=$DB >>$ENVFILE
    echo export ORACLE_HOME=$VORACLE_HOME >>$ENVFILE
    echo export PATH=$VPATH >>$ENVFILE
    echo export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib >>$ENVFILE
    echo export RDIR=$RDIR >>$ENVFILE
#Ejecucion script sql
        /sbin/runuser -l $VUSER -c ". ${ENVFILE} ; sqlplus -s / as sysdba @$RDIR/$SQL" > $OUTPUT/$HOSTNAME-$DB.log
done

#Compresion de logs y eliminacion de directorios temporales
cd $RDIR
rm -rf $BASEDIR 
