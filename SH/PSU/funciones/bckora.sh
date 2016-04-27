#Backup Binarios Oracle 
function bckora(){
	#Variables funcion
	local BINARY_TYPE=$1
	#Seleccion tipo de backup
	case "$BINARY_TYPE" in
		DB)
		echolog "Iniciando backup de los binarios de BBDD."
		cd $ORACLE_HOME
		tar -c ./ | gzip -c > $BCKDIR/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.tar.gz
			if [ $? = 0 ];
			then
				echolog INFO "Backup de los binarios de BBDD finalizado."
			else
				echolog ERROR "Fallo en el backup de los binarios de BBDD."
			fi
		;;
		GI)
		echolog "Iniciando backup de los binarios de Grid Infraestructure."
		cd $GRID_HOME
		tar -c ./ | gzip -c > $BCKD/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.tar.gz
			if [ $? = 0 ];
			then
				echolog INFO "Backup de los binarios de Grid Infraestructure finalizado"
			else
				echolog "Fallo en el backup de los binarios de Grid Infraestructure."
			fi
		;;
		OI)
		echolog "Iniciando backup de Oracle Inventory."
		cd $ORAINV
		tar -c ./ | gzip -c > $BCKD/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.tar.gz
			#echo $?
			if [ $? = 0 ];
			then
				echolog INFO "Backup del Oracle Inventory finalizado";
			else
				echolog ERROR "Fallo en el backup del Oracle Inventory.";
			fi
		;;
		OCR)
		echolog INFO "Iniciando backup de la configuracion del Oracle Cluster Registry."
		$GRID_HOME/bin/ocrconfig -export $BCKD/ora_"$BINARY_TYPE"_soft_`hostname`_`date +%Y%m%d`.ocr
			if [ $? = 0 ];
			then
				echolog INFO "Backup de la configuracion Oracle Cluster Registry finalizado"
			else
				echolog ERROR "Fallo en el backup de la configuracion Oracle Cluster Registry."
			fi
		;;
	esac
}
