#!/bin/bash
#Constantes
ORAINV=`cat /etc/oraInst.loc | grep inventory_loc | cut -d "=" -f 2`
TIMESTAMP=$(date "+%d.%m.%Y-%H.%M.%S")
#Variables
BCKDIR=/tmp/test/bck

###########
#FUNCIONES#
###########

#Backup Binarios Oracle 
function bckora(){
	#Variables funcion
	local BINARY_TYPE=$1
	#Seleccion tipo de backup
	case "$BINARY_TYPE" in
		DB)
		echo "$TIMESTAMP : Iniciando backup de los binarios de BBDD."
		cd $ORACLE_HOME
		tar -c ./ | gzip -c > $BCKDIR/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.tar.gz
			if [ $? = 0 ];
			then
				echo "$TIMESTAMP : Backup de los binarios de BBDD finalizado."
			else
				echo "$TIMESTAMP : ERROR Fallo en el backup de los binarios de BBDD."
			fi
		;;
		GI)
		echo "$TIMESTAMP : Iniciando backup de los binarios de Grid Infraestructure."
		cd $GRID_HOME
		tar -c ./ | gzip -c > $BCKDIR/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.tar.gz
			if [ $? = 0 ];
			then
				echo "$TIMESTAMP : Backup de los binarios de Grid Infraestructure finalizado"
			else
				echo "$TIMESTAMP : ERROR Fallo en el backup de los binarios de Grid Infraestructure."
			fi
		;;
		OI)
		echo "$TIMESTAMP : Iniciando backup de Oracle Inventory."
		cd $ORAINV
		tar -c ./ | gzip -c > $BCKDIR/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.tar.gz
			#echo $?
			if [ $? = 0 ];
			then
				echo "$TIMESTAMP : Backup de los binarios de Oracle Inventory finalizado";
			else
				echo "$TIMESTAMP : ERROR Fallo en el backup de Oracle Inventory.";
			fi
		;;
		OCR)
		echo "$TIMESTAMP : Iniciando backup de la configuracion del Oracle Cluster Registry."
		$GRID_HOME/bin/ocrconfig -export $BCKDIR/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.ocr
			if [ $? = 0 ];
			then
				echo "$TIMESTAMP : Backup de la configuracion Oracle Cluster Registry finalizado"
			else
				echo "$TIMESTAMP: ERROR Fallo en el backup de la configuracion Oracle Cluster Registry."
			fi
		;;
	esac
}

#Check prerequisitos oracle
function prereq(){

}

bckora OI >> /tmp/test/bck/log.log

