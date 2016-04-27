#!/bin/bash
#script check ISEC Oracle  FULL - parte Fundation=Y y Fundation=N  - Version 2.11 (para Techspecs Oracle V3.0) 
#
#       Raul Moreno Guirado 25/09/2013
#       Xavi Puig
#       Silvia Blazinschek (2013, 2014) 
#
#                       Uso:   ./isec_oracle.sh -t caixa          (chequea todas las techspecs con agreed values de Caixa) 
#                              ./isec_oracle.sh -t itnow          (chequea todas las techspecs con agreed values de Itnow)
#                              ./isec_oracle.sh -t caixa AG.1.1.1 (solo chequea una techspec)
#
#
#       Fase 1 GetToGreen Oracle for Linux (usado con BASH, no es util en CSH)
#
#       Este script debe ejecutarse con usuario root
######
######   este script requiere de permisos de lectura para los .sql porque los ejecuta ora11g , pero los genera root
######   y ora11g necesita tener permiso de escritura en el directorio actual para crear los informes/directorios donde se graban resultados

#  Modificaciones: (Silvia)   
#  15/10/2014 : Se modifica la forma de obtener las instancias que se chequean. Ahora no se busca un fichero environment, sino que se crea 
#               a partir de la informacion obtenida por el comando srvctl (extraemos las BDs registradas)
#  20/10/2014: Se cambia la programacion de la verificacion AG.1.1.8  (PASSWORD VERIFICATION FUNCTION) porque no daba resultados correctos
#              Se corrige, pero aun se debe tener en cuenta que solo los usuarios privilegiados (Section 5.0 techspec Oracle) deben tener una 
#              longitud de password de 14 y los usuarios generales deben tener 8. Esta diferencia, obliga a cambiar el codigo, basando la 
#              eleccion de la funcion de verificacion de passwords de un perfil al conjunto de usuarios que posee, y quizas requiera 
#              cambiar usuarios de perfil, a menos que el  perfil origen cumpla con los 14 caracteres.
#              Por este motivo, la salida debe vincularse a los usuarios y no a los perfiles como hasta ahora (para AG.1.1.8).
#  21/10/2014: Seagrega consultas individuales de las techspecs AG.1.1.1, AG.1.1.2, AG.1.1.4, AG.1.1.5, AG.1.1.6, AG.1.1.7
#              con los resultados acumulados en el subdirectorio  resultados_sql 
#              y las consultas se guardan en el subdirectorio  consultas_sql
#  22/10/2014: Se parametrizan las consultas con valores distintos para Caixa e ITNow, para que el script pueda usarse con unos o con otros
#              el script  para Caixa se invoca:  ./isec_oracle.sh
#              el script  para ITNow se invoca:  ./isec_oracle.sh itnow 
#  23/10/2014: Se modifica la consulta AG.1.1.8 de password verify function tieniendo en cuenta a los usuarios privilegiados (long-pass >=14)
#              Se modifican las funciones y procedures que se creaban, y se incorporan al texto de la consulta para no crear estos objetos en la BD
#  24/10/2014: Se modifica el script para que la salida sea parecida a la Fase2, y el informe queda por detras
#  25/10-03/11: Se corrigen techspecs con errores, se añade help y sintaxis al script, se mejoran la salida de resultados
#  11/11/2014: Se agrega el check para AG.1.7.7  (direct login access for oracle prohibited, must user login first and then sudo to oracle)
##################################################################################################################################
           
#  Parametrizacion
#  Valores agreed Caixa:
#  PASSWORD_LIFE_TIME=180            (PARAM111)
#  PASSWORD_GRACE_TIME=5             (PARAM112)
#  PASSWORD_REUSE_TIME=720           (PARAM114)
#  PASSWORD_REUSE_MAX=3              (PARAM115)
#  FAILED_LOGIN_ATTEMPTS=6           (PARAM116)
#  PASSWORD_LOCK_TIME=UNLIMITED      (PARAM117)
#  
#  Valores agreed ITNow: 
#  PASSWORD_LIFE_TIME=90             (PARAM111)
#  PASSWORD_GRACE_TIME=5             (PARAM112)
#  PASSWORD_REUSE_TIME=720           (PARAM114)
#  PASSWORD_REUSE_MAX=8              (PARAM115)
#  FAILED_LOGIN_ATTEMPTS=4           (PARAM116)
#  PASSWORD_LOCK_TIME=UNLIMITED      (PARAM117)

set -x 
trap  "eliminar_sqls; exit" 2 3

VERSION="V3.0"       #####  Version de Techspecs Oracle tratadas por este script

REDHATVERSION=`grep "Red Hat" /etc/redhat-release | awk '{print $6}'`
if [ -z "$REDHATVERSION" ] ; then
   echo "CANCEL:  Este servidor no es un Red Hat."
   exit
fi

if [ "$SHELL" = "/bin/csh" ] ; then
   echo "CANCEL:  Este script se debe usar con BASH"
   exit
fi

limpia_errorlog()
{
   if [ ! -s errorfile.log ]; then
       rm -f errorfile.log
   fi
}

usage_sintaxis()
{
    echo -e "\nSintaxis:   $0 [ -h | -t [ caixa | itnow ]] [ ALL | [ AG.1.1.1 AG.1.1.2 .....]]"
    echo -e "\nUso:(ejemplos)" 
    echo -e "   $0 -h                                   ..... help"
    echo -e "   $0 -t caixa                             ..... check  ISEC Oracle Caixa agreed values, ALL techspecs"
    echo -e "   $0 -t caixa AG.1.5.4                    ..... check  ISEC Oracle Caixa agreed values, solo 1 techspec"
    echo -e "   $0 -t itnow                             ..... check  ISEC Oracle Itnow agreed values, ALL techspecs"
    echo -e "   $0 -t itnow AG.1.1.1 AG.1.1.2           ..... check  ISEC Oracle Itnow agreed values, varias techspecs"
    echo -e "   $0 ALL                                  ..... por defecto de opciones, chequea ISEC Oracle Caixa agreed values"
    echo -e "   $0 AG.1.1.1 AG.1.1.2 AG.1.1.4           ..... por defecto de opciones, chequea ISEC Oracle Caixa agreed values"
    echo
}

if [ $# -eq 0 ]; then
    echo -e "\nERROR: Falta especificar opcion o techspecs a evaluar"
    usage_sintaxis 
    exit
fi

while getopts ":ht:" arg
do
    case "${arg}" in
     "h" ) echo 
           echo -e "Help:   Script Get2Green que extrae informacion de todas las techspecs ISEC Oracle FULL $VERSION"
           echo -e "        Se generan informes y fixes propuestos que podrian ser utilizados por un DBA para corregir los incumplimientos ISEC Oracle"
           echo -e "        Se recomienda evaluar los fixes propuestos antes de su aplicacion y documentar las excepciones para aquellos que no se puedan corregir." 
           echo         
           echo -e "        Se consultan todas las BDs Oracle en esta maquina cuyo estado es PRIMARY"
           echo -e "        Script util en maquinas Red Hat y SHELL=bash"
           echo -e "        El usuario de ejecucion del script: root"
           echo
           echo -e "Informes:"
           echo -e "        El informe unificado de todas las BDs queda en el subdirectorio      ./Reports/hostname_report"
           echo -e "        Los fixes propuestos quedan en el subdirectorio                      ./Reports/hostname_report/fixes"
           echo -e "        Los logs diferenciados por sistema y BDs queda en subdirectorio      ./Reports/hostname_report/logs"
           echo -e "        Ficheros temporales utiles quedan en subdirectorio                   ./Reports/hostname_report/temporales" 
           echo
           echo -e "Errores:"
           echo -e "        Los errores de este script quedan registrados en el fichero errorfile.log. Si no se genera el fichero, no hay errores."
           echo
           echo -e "Nota:   Este script no ejecuta ningun cambio, solo realiza consultas, genera informes y propone fixes que deben ser evaluados antes de su aplicacion"
           usage_sintaxis
           exit ;;
     "t" ) SETPARM=${OPTARG} ;;
    esac
done
shift $((OPTIND-1))

SETPARM=${SETPARM:-"caixa"}   

if [ $SETPARM = "caixa" ] ; then
  PARAM111=180
  PARAM112=5
  PARAM114=720
  PARAM115=3
  PARAM116=6
  PARAM117=UNLIMITED
else
  PARAM111=90
  PARAM112=5
  PARAM114=720
  PARAM115=8
  PARAM116=4
  PARAM117=UNLIMITED
fi

####Colores printado
export VERDE="\033[32m"
export ROJO="\033[31m"
export AMAR="\033[33m"
export RESET="\033[0m"
export BOLD=`tput smso`
export UNBOLD=`tput rmso`
export SUBR=`tput sgr 0 1`
export UNSUBR=`tput sgr 0 0`

export NOK=${BOLD}${ROJO}NOK${RESET}${UNBOLD}
export OK=${SUBR}${VERDE}OK${RESET}${UNSUBR}

AUTORIZA='ALTER DATABASE|ALTER PROFILE|ALTER SYSTEM|ALTER TABLESPACE|ALTER USER|AUDIT ANY|AUDIT SYSTEM|CREATE ANY JOB|CREATE PROFILE|CREATE ROLLBACK SEGMENT|CREATE TABLESPACE|CREATE USER|DROP PROFILE|DROP ROLLBACK SEGMENT|DROP TABLESPACE|DROP USER|GRANT ANY OBJECT PRIVILEGE|GRANT ANY PRIVILEGE|GRANT ANY ROLE|MANAGE TABLESPACE|RESTRICTED SESSION|DBA|IMP_FULL_DATABASE|EXP_FULL_DATABASE|EXECUTE_CATALOG_ROLE|DELETE_CATALOG_ROLE'
#AUTORIZA="-e 'ALTER DATABASE' -e 'ALTER PROFILE' -e 'ALTER SYSTEM' -e 'ALTER TABLESPACE' -e 'ALTER USER' -e 'AUDIT ANY' -e 'AUDIT SYSTEM' -e 'CREATE ANY JOB' -e 'CREATE PROFILE' -e 'CREATE ROLLBACK SEGMENT' -e 'CREATE TABLESPACE' -e 'CREATE USER' -e 'DROP PROFILE' -e 'DROP ROLLBACK SEGMENT' -e 'DROP TABLESPACE' -e 'DROP USER' -e 'GRANT ANY OBJECT PRIVILEGE' -e 'GRANT ANY PRIVILEGE' -e 'GRANT ANY ROLE' -e 'MANAGE TABLESPACE' -e 'RESTRICTED SESSION' -ew 'DBA' -e 'IMP_FULL_DATABASE' -e 'EXP_FULL_DATABASE' -e 'EXECUTE_CATALOG_ROLE' -e 'DELETE_CATALOG_ROLE'"

TODASLASTECHSPECS=0

######################################################################################
#####
#####   inicializacion de variables generales y ficheros de informes/fixes
#####
######################################################################################
HOST=`hostname | awk -F'.' '{print $1}' | tr "[:lower:]" "[:upper:]"`
#####################################################################33333333333333333333
umask 022 

DIA=`date +%d%m%y-%H%M%S`

DIR=`pwd`/Reports/`hostname | awk -F'.' '{print $1}'`_report  

[ ! -d $DIR ] && mkdir -p $DIR && chmod 777 $DIR

[ ! -d $DIR/fixes ] && mkdir -p $DIR/fixes

[ ! -d $DIR/logs ] && mkdir -p $DIR/logs

[ ! -d $DIR/temporales ] && mkdir -p $DIR/temporales

FIXES=${DIR}/fixes/fixes_sistema_$DIA

INFORME=$DIR/${HOST}_OracleISEC_FULL_${DIA}.log
INFORMESIS=$DIR/logs/${HOST}_OracleISEC_FULL_sistema_${DIA}.log
HOST=`hostname |awk -F'.' '{print $1}'`
ERRORFILE=errorfile.log

rm -f ficheros_encontrados

LISTACOMPLETATECHSPEC="AG.1.1.1 AG.1.1.2 AG.1.1.4 AG.1.1.5 AG.1.1.6 AG.1.1.7 AG.1.1.8 AG.1.1.10 AG.1.2.1 AG.1.2.3 AG.1.2.4 AG.1.2.8 AG.1.4.1 AG.1.4.3 AG.1.4.4 AG.1.4.5 AG.1.4.6 AG.1.4.7 AG.1.4.8 AG.1.7.1 AG.1.7.3 AG.1.7.4 AG.1.7.5 AG.1.7.6 AG.1.7.7 AG.1.7.9.1 AG.1.7.9.2 AG.1.7.14 AG.1.7.15 AG.1.7.16 AG.1.8.1 AG.1.8.5 AG.1.8.6 AG.1.5.1 AG.1.5.2 AG.1.5.3 AG.1.5.4 AG.1.7.8 AG.1.7.12 AG.1.8.11.1 AG.1.8.11.2 AG.1.8.11.3 AG.1.8.11.4 AG.1.8.14 AG.1.8.15 AG.1.8.17 AG.1.8.7 AG.1.8.12 AG.1.8.13 AG.1.8.16 AG.1.8.13.1 AG.1.9.1.1 AG.1.9.1.2 AG.5.0.1"

LIN="===================================================================================="

> $INFORME
> $INFORMESIS
exec 2> $ERRORFILE

echo -e "\n${LIN}\n${LIN}\nINFORME: ISEC_ORACLE_SISTEMA_FULL - $SETPARM agreed values - `date +%d/%m/%y-%H:%M:%S` \n\n$HOST \n${LIN}\n${LIN}" | tee -a  $INFORME | tee -a $INFORMESIS

> $FIXES

echo -e "#### FECHA: `date +%d/%m/%y-%H:%M:%S` \n\n$HOST" > $FIXES
echo -e "####\n####  Valore cuidadosamente la ejecucion de los comandos de cambios\n$LIN" >> $FIXES

####*****************************************************************************
####               seccion  funciones
###******************************************************************************

#Cambia valor de variables del tamaño de pantalla cuando recibe signal SIGWINCH
trap 'cambiar_dimensiones' WINCH                    # Coger signal cuando un usuario cambia la pantalla
function cambiar_dimensiones() {
  exec 2>&1		#Cambio la stderr a la salida normal, así el tput podrá pillar el tamaño de la pantalla correctamente
  COLUMNAS=$(tput cols)
  FILAS=$(tput lines)
  POSRESULTADO=$(($COLUMNAS-8))
  if [ -n "$ERRORFILE" ] 
  then
    exec 2>> $ERRORFILE  #Vuelvo a dejar la stderr como estaba
  fi
}


#vectorgrep: Pone en el vector de parámetros un "-e" delante de cada elemento y devuelve el vector en la variable $VECTOR_TEMP
function vectorgrep()
{
  VECTOR_TEMP=""
  VECTOR_TEMP1="$*"
  ELEMENTO=""
  if [ -n "$VECTOR_TEMP1" ]
  then
    for ELEMENTO in $VECTOR_TEMP1
    do
	if [ -z "$VECTOR_TEMP" ]
	then
	  VECTOR_TEMP="-e $ELEMENTO"
	else
	  VECTOR_TEMP="$VECTOR_TEMP -e $ELEMENTO"
	fi
    done
  else
    VECTOR_TEMP="-e ZZZZzzZZZZZZzzzzZZZZZZK"
  fi
}

#quitarelementos: Quita del vector del primer parámetro los elementos que aparezcan en el vector del segundo parámetro y devuelve el resultado en $LISTA_TEMP
function quitarelementos()
{
  LISTA_TEMP=""
  ELEMENTO=""
  vectorgrep $2
  for ELEMENTO in $1
  do
   echo -n "$ELEMENTO" | grep -q $VECTOR_TEMP 2>/dev/null
   RES=$?
   if [ $RES -ne 0 ]
   then
     if [ -z "$LISTA_TEMP" ]
     then
	LISTA_TEMP="$ELEMENTO"
     else
        LISTA_TEMP="$LISTA_TEMP $ELEMENTO"
     fi
   fi	
  done  

}


#OkNok: Imprime por pantalla el Ok o Nok con colores y el texto, ajustado al tamaño de la pantalla
function OkNok()
{
  LONGITUD_TEXTO=`echo -n $2|wc -c`
  if [ $LONGITUD_TEXTO -lt ${POSRESULTADO} ] #El texto no chafará el OK o NOK
  then
    echo -n -e "\033[${POSRESULTADO}C"
    if [ $1 -eq 0 ]
    then
          echo -e -n "[  ${VERDE}OK${RESET}  ]"
    else
          echo -e -n "[  ${ROJO}NOK${RESET} ]"
    fi

    echo -n -e "\033[${COLUMNAS}D" #Pone el cursor al principio de la línea
    echo -e $2

  else
    NUMLINEAS=`echo ${LONGITUD_TEXTO}/${POSRESULTADO}|bc -l|awk -v FS="." '{if ($2>0) {print $1+1} else {print $1}}'`
    for((i=0;i<$NUMLINEAS;i++))
    do
       if [ $i -eq $((${NUMLINEAS}-1)) ]
       then
         PARTE_TEXTO=`echo -n $2|cut -c $((${i}*${POSRESULTADO}+1))-`
 	 echo -n -e "\033[${POSRESULTADO}C"
         if [ $1 -eq 0 ]
         then
            echo -e -n "[  ${VERDE}OK${RESET}  ]" 
         else
            echo -e -n "[  ${ROJO}NOK${RESET} ]"
         fi
	 echo -n -e "\033[${COLUMNAS}D" #Pone el cursor al principio de la línea
         echo -e $PARTE_TEXTO

       else
         PARTE_TEXTO=`echo -n $2|cut -c $((${i}*${POSRESULTADO}+1))-$(((${i}+1)*${POSRESULTADO}))`
	 echo -e $PARTE_TEXTO
       fi
     done
  fi
}
function posi ()
{
LARGO=`echo "$CODIGOTECHSPEC" | wc -c`
POS=`expr 16 - $LARGO `
CODIGO=`echo -n -e "\033[${POS}C"`

}


function redraw ()
{
LINEAESPERE="$1"
LARGOESPERE=`echo "$LINEAESPERE" | wc -c`
#POS2=`expr $COLUMNAS - $LARGOESPERE`
#REDRAW=`echo -n -e "\033[1A\033[0K\033[${LARGOESPERE}D"`
REDRAW=`echo -n -e "\033[1A\033[M"`
}

#parsearparametroscomprobar: Parsear parámatros para la función de comprobación
function parsearparametroscomprobar() 
{
  counter=0
  LISTATECHSPECORACLE=""
  for param in $@
  do
    let counter=$counter+1
    if [ $param == "ALL" ] #Si se pasa este parámetro se comprobarán todas las techspec menos las que pasen por parámetro
    then
	if [ $counter -eq 1 ]
	then 
	  TODASLASTECHSPECS=1
	else #El parámetro ALL no está en la primera posición
	  echo -e "${ROJO}El parámetro ALL debe estar en primer lugar${RESET}"
	  exit 1
	fi
    else
	vectorgrep  $LISTACOMPLETATECHSPEC  
	echo -n "$param" |grep -w -q $VECTOR_TEMP
	if [ $? -ne 0 ]
	then
	  echo -e "${ROJO}El parámetro $param es incorrecto o no corresponde a ninguna techspec incluida en el script${RESET}"
	  echo -e "Las techspecs incluidas son:\n$LISTACOMPLETATECHSPEC"
	  exit 1
	fi
  
        if [ -z "$LISTATECHSPECORACLE" ]
        then
          LISTATECHSPECORACLE="$param"
        else
          LISTATECHSPECORACLE="$LISTATECHSPECORACLE $param"
        fi
    fi	
  done

  if [ -z "$LISTATECHSPECORACLE" ]
  then
    TODASLASTECHSPECS=1
  fi

  if [ $TODASLASTECHSPECS -eq 1 ]
  then
    if [ -z "$LISTATECHSPECORACLE" ]
    then
      echo -e "Se comprobarán TODAS las techspecs"
    else	
      echo -e "Se comprobarán TODAS las techspecs excepto estas: '$LISTATECHSPECORACLE'"
    fi
  else
    echo -e "Se comprobarán SOLAMENTE las siguientes techspecs: '$LISTATECHSPECORACLE'"
  fi
  
}

#testtechspeccomprobar: Devuelve 0 si la techspec pasada por parámetro se ha de comprobar o no para la función de comprobación
function testtechspeccomprobar()
{
  vectorgrep $LISTATECHSPECORACLE
  if [ $TODASLASTECHSPECS -eq 1 ] #En este caso la lista indica las techspec que no se han de hacer
  then
    echo -n $1 |grep -q -w $VECTOR_TEMP
    if [ $? -eq 0 ]  #El elemento está en la lista
    then
	return 1
    fi
  else #En este caso la lista indica las techspec que se han de hacer
    echo -n $1 |grep -q -w $VECTOR_TEMP 
    if [ $? -ne 0 ]  #El elemento no está en la lista, luego no se hace
    then
        return 1
    fi
  fi
}
eliminar_sqls ()
{
rm -f  $DIR/public.sql
rm -f  $DIR/ctxsys_priv.sql
rm -f  /tmp/cambios_isec_oracle_revoke.sql
rm -f  /tmp/cambios_ctxsys_revoke.sql
rm -f  $DIR/auditoria_oracle.sql
rm -f  $DIR/parameters.sql
rm -f  $DIR/database.sql
rm -f  $DIR/archivelog.sql
rm -f  $DIR/background_dest.sql
rm -f  $DIR/passdefault.sql
rm -f  $DIR/passdefault_product_service.sql
rm -f  $DIR/oracledemousers.sql
rm -f  $DIR/dbsnmpuser.sql
rm -f  $DIR/ctxsysuser.sql
rm -f cambios_ctxsys_revoke.sh    
rm -f  $DIR/privgeneral.sql
rm -f  $DIR/privdba.sql
rm -f  $DIR/privsysdbaoper.sql
rm -f  $DIR/privwithadmin.sql
rm -f $DIR/ag_1_1_1_password_life_time.sql
rm -f $DIR/ag_1_1_2_password_grace_time.sql
rm -f $DIR/ag_1_1_4_password_reuse_time.sql
rm -f $DIR/ag_1_1_5_password_reuse_max.sql
rm -f $DIR/ag_1_1_6_failed_login_attempts.sql
rm -f $DIR/ag_1_1_7_password_lock_time.sql
rm -f $DIR/ag_1_1_8_password_verify_function.sql
rm -f $DIR/bd_primaria.sql
rm -f $DIR/orausers.sql
rm -f $DIR/Orasystempriv.sql
rm -f $DIR/OraPRIVIsec.sql
rm -f $DIR/check_pwd.sql
rm -f $DIR/check_retries.sql
rm -f $DIR/single_rac_instance.sql
rm -f $DIR/rac_instance.sql
rm -f $DIR/userexternal.sql
#rm -f $DIR/*sql
}


#####***************************************************************************
infor()
{
texto=$2
tech=$1
echo -e "${tech} ${texto}" >> $INFORME
}
#####***************************************************************************
inforsis()
{
texto=$2
tech=$1
echo -e "${tech} ${texto}" >> $INFORMESIS
}
####*****************************************************************************
inforora()
{
texto=$2
tech=$1
echo -e "${tech} ${texto}" >>  $INFORMEORA
}
###******************************************************************************
fix()
{
tech=$1
comando=$2
printf "${tech};$comando\n" >> $FIXES
}
####****************************************************************************
fixora()
{
tech=$1
texto=$2
echo -e "${tech};$texto" >> $FIXORA
}

#********************************************************************************
######   funcion que extrae los directorios de HOMEs de software Oracle y setea variable PATH para que root pueda ejecutar comando srvctl
setear_bases ()
{
       ORAINSTLOC=`grep inventory_loc /etc/oraInst.loc | awk -F"=" '{print $2}'`
       ORAINSTGRP=`grep inst_group /etc/oraInst.loc | awk -F"=" '{print $2}'`

       CONTENTSXML=${ORAINSTLOC}/ContentsXML
       INVENTORYXML=${CONTENTSXML}/inventory.xml

######   en la variable PATH1  debemos setear como primer directorio de busqueda, el del GRID, despues pueden aparecer el resto de directorios ORACLE_HOME
######   de otro modo el comando 'svrctl' puede funcionar mal

       PATH2=`grep "HOME NAME" $INVENTORYXML | awk '{print $3}' | tr -d '"' | awk -F"=" '{printf("%s/bin:",$2);}'`
       
       PATH1=`echo "$PATH2" | awk -F":" '{ for(i=1;i<=NF;i++)
                              if (tolower($i) ~ "grid")
                                { guardo=$i;
                                 hay=1; }
                              else
                                 todo=todo$i":"; }
                           END { print guardo":"todo;}'`  

       export ORACLE_HOME=`grep "HOME NAME" $INVENTORYXML | awk '{print $3}' | tr -d '"' | awk -F"=" '{printf("%s:",$2);}' | awk -F":" '{for(i=1;i<=NF;i++) if(tolower($i) ~ "grid" ) {print $i; exit}}'` 
 
#       DIRECTORIOS_FIND=`grep "HOME NAME" $INVENTORYXML | grep -v "plugin" | awk '{print $3}' | tr -d '"' | awk -F"=" '{printf("%s ",$2);}'`
       DIRECTORIOS_FIND=`grep "HOME NAME" $INVENTORYXML | cut -d"=" -f2- | awk '{print $2" "}' | awk -F"=" '{printf("%s ",$2);}' | tr -d '\"'`
      
        
       PATH=$PATH:$PATH1:/sbin:/usr/sbin:/bin:/usr/bin
#       echo PATH=$PATH
       if [ -z $ORACLE_HOME  ] 
       then
             echo -e "ERROR: ORACLE_HOME no esta correctamente seteada para ejecutar 'srvctl'"
             echo -e "$ORACLE_HOME"
             echo -e "Operacion check ISEC Oracle Full abortada"
             limpiar_sqls
             exit
       fi     
       echo ORACLE_HOME=$ORACLE_HOME
       BASE_NAMES=`srvctl config | tr -s "\n" " "`
       NOSRVCTL=0
       if [ `echo "$BASE_NAMES" | grep -i -c Unable` -gt 0 ] 
       then
            NOSRVCTL=1
            USERORA=`ps -ef |grep ora_dbw0 | grep -v grep | awk '{print $1}'`
            BASE_NAMES=""
            for userora in $USERORA
            do
                BASE1=`su - $userora -c "env" | grep DB_SID | grep -v grep |awk -F"=" '{print $2}'`
                BASE_NAMES="${BASE_NAMES} $BASE1"
                
            done
       fi

       echo $BASE_NAMES | grep -q -e "PRCR-1119" -e "PRCR-1115" 
       if [ $? -eq 0 ] 
       then
              echo -e "ERROR: No es posible chequear las BDs de esta maquina en estos momentos por errores del comando 'srvctl config'"
              echo -e "       usado para extraer los nombres de las BDs registradas.\n"
              echo -e "Corrija los siguientes errores y luego reintente"
              echo -e "$BASE_NAMES"
              exit
       fi
#       echo BASE_NAMES=$BASE_NAMES

}

######################################################################################################
######   funcion que construye el fichero ENVFILE y lo deja en $DIR por cada base  
setear_entorno ()
{       
       base=$1
       ins=`srvctl config database -d $base | grep -i "database instance" |awk -F":" '{print $2}' | tr -d " "`
       SH1=bash
       if [ $NOSRVCTL -eq 0 ] 
       then
           ORACLE_HOME=`srvctl config database -d $base | grep -i "oracle home" | awk -F":" '{print $2}' | tr -d " "` 
           cant_instances=`srvctl config database -d $base |grep -i "database instance" | awk -F":" '{print $2}' | tr "," " " | wc -w | tr -d "\n"`
           cant_instances=${cant_instances:-0}
           if [ $cant_instances -gt 1 ]     ####   es un Oracle RAC
           then
              HOST1=`echo $HOST|awk -F "." '{print $1}'`	
              ORACLE_SID=`srvctl status database -d $base|grep -i instance |grep $HOST1 | awk '{print $2}' | tr -d "\n"`
           else  ####   es una single instance
              [ $cant_instances -eq 1 ] && ORACLE_SID=`srvctl config database -d $base | grep -i "Database instance" | awk -F":" '{print $2}' | tr -d " "`
              [ $cant_instances -eq 0 ] && ORACLE_SID=`ps -ef | grep ora_dbw0 | grep -i -v _asm | grep -i $base | awk -F"_" '{print $NF}' | tr -d "\n"`
           fi

           ORACLE_USER=`srvctl config database -d $base | grep -i "oracle user" |awk -F":" '{print $2}' |tr -d " "`
           ORACLE_GRID=`grep "HOME NAME" $INVENTORYXML | cut -d"=" -f2- | awk '$1~"grid" {print $2}' | awk -F"=" '{printf("%s ", $2);}' | tr -d '"'`
           ORACLE_AGENT=`grep "HOME NAME" $INVENTORYXML | cut -d"=" -f2- | awk '$1~"agent" {print $2}' | awk -F"=" '{printf("%s ", $2);}' | tr -d '"'`
           TNS_ADMIN=$ORACLE_HOME/network/admin
           HOME1=`su - $ORACLE_USER -c "pwd"`
           ENVFILE=$DIR/envfile_$base
           PATH=$ORACLE_HOME/bin:$PATH
           CRS_HOME=$(grep 'CRS="true"' $INVENTORYXML | sed -nr 's/^.*LOC="(.*)" TYPE.*$/\1/p')
           [ $SH1 == "bash" ] && SHEL="."
       else
           ORACLE_GRID=`grep "HOME NAME" $INVENTORYXML | cut -d"=" -f2- | awk '$1~"grid" {print $2}' | awk -F"=" '{printf("%s ", $2);}' | tr -d '"'`
           ORACLE_AGENT=`grep "HOME NAME" $INVENTORYXML | cut -d"=" -f2- | awk '$1~"agent" {print $2}' | awk -F"=" '{printf("%s ", $2);}' | tr -d '"'`
           CRS_HOME=$(grep 'CRS="true"' $INVENTORYXML | sed -nr 's/^.*LOC="(.*)" TYPE.*$/\1/p')
           us1=`ps -ef |grep ora_dbw0 |grep -v grep |grep $base | awk '{print $1}'`
           ORACLE_HOME=`su - $us1 -c "env" | grep ORACLE_HOME | grep -v grep | awk -F"=" '{print $2}'`
           ORACLE_SID=`su - $us1 -c "env" |grep ORACLE_SID | grep -v grep |awk -F"=" '{print $2}'`
           ORACLE_USER=$us1
           SH1=`su - $us1 -c "env" |grep SHELL |grep -v grep |awk -F"=" '{print $2}'`
           if [ `echo $SH1 | grep -v -c csh` -gt 1 ]
           then
                 SHEL="source"
           else
                 SHEL="."
           fi
           TNS_ADMIN=$ORACLE_HOME/network/admin
           ENVFILE=$DIR/envfile_$base
           PATH=$ORACLE_HOME/bin:$PATH
           
       fi       
echo export ORACLE_HOME=$ORACLE_HOME > $ENVFILE
echo export ORACLE_GRID=$ORACLE_GRID >> $ENVFILE
echo export ORACLE_AGENT=$ORACLE_AGENT >> $ENVFILE
echo export ORACLE_USER=$ORACLE_USER >> $ENVFILE
echo export ORACLE_SID=$ORACLE_SID >> $ENVFILE
echo export PATH=$ORACLE_HOME/bin:$PATH >> $ENVFILE
echo export TNS_ADMIN=$ORACLE_HOME/network/admin >> $ENVFILE >> $ENVFILE
echo export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH >> $ENVFILE
echo export CRS_HOME=$CRS_HOME >> $ENVFILE
echo export SHEL=$SHEL >> $ENVFILE
}
######################################################################################################
######   funcion que setea ORACLE_HOME (solo para BDs, elimina "agent" y "grid" )
setear_entorno_network ()
{
  ORACLE_GRID=`grep ORACLE_GRID $DIR/envfile* | sort -u | tail -1 | awk -F"=" '{print $2}'`
  export ORACLE_HOME=$ORACLE_GRID
  export PATH=$ORACLE_HOME/bin:$PATH

###  for dire in $DIRECTORIOS_FIND
###  do
###       if [[ `echo "$dire" | grep -c -i agent` -eq 0 ]] && [[ `echo "$dire" | grep -c -i grid` -eq 0 ]]
###       then
###             ORACLE_HOME="$dire"
###             break
###       fi
###   done
  if [ -z $ORACLE_HOME ]
  then
      echo "ORACLE_HOME no seteada, el comando srvctl no funciona correctamente"
  fi
###   export ORACLE_HOME
}

# ##################################################
# function: normalizeFile
# purpose: 
#   shared utility to concatenate "\" lines
#   remove comment and blank lines from a file
#   remove comments at end of lines
#  
# parameters:
#  $1 the file
# notes:
#  echo's the resulting file content 
# ###################################################
normalizeFile() {
  FILETOREAD="$1"
  if [ -f "$FILETOREAD" ] && [ -s "$FILETOREAD" ];
  then  
    sed ':a; /\\$/N; s/\\\n//; ta' "$FILETOREAD" | \
      awk '{\
       line=$0; \
       z=index(line,"#"); \
       if (z == 0){ gsub(/^[ \t]+|[ \t]+$/,"",line); if (length(line)>0){ print line; }} \
       else {x=substr(line,1,z-1); gsub(/^[ \t]+|[ \t]+$/,"",x); if (length(x)>0){ print x;} } \
      }' | awk '{x=index($0,":"); if (x != 1) {print $0;} }'   
  fi
}  


#
# ########################################
# source for these functions is _scripts/builtin

# ##################################################
# function: isCommandBuiltin
# purpose: checks if a command is a shell builtin
#  command
# parameters:
#  $1 the command
#  $2 the result variable 
# notes:
#  1. if the command is a full path, only the filename part
#    will be processed
#  2. this code does a best effort to determine if the
#    command is builtin. it does not account for translation
#    of the output of "type" or "command" on the client
#    operating system.  a command is builtin if either of
#    "type" or "command -v" includes the keyword "builtin" or "alias"
# ###################################################
isCommandBuiltin() {
  TEST_CMD=$1
  RESULT_BUILTIN=$2
  
  ITIS_BUILTIN=0
  #  if the command contains a full path, check just the filename portion
  if [ "${TEST_CMD:0:1}" == "/" ];
  then
  	 TEST_CMD=`echo $TEST_CMD 2>/dev/null | awk '{split($1,x,"/");z=0;for(k in x)z++; print x[z];}'`
  fi	
  BLTIN_TYPE_RETURNS=`LC_ALL=C type $TEST_CMD 2>/dev/null` 
  TYPE_IS_BUILTIN=`echo $BLTIN_TYPE_RETURNS | egrep -c -w 'builtin'`
  if [ $TYPE_IS_BUILTIN -gt 0 ];
  then
  	 ITIS_BUILTIN=1
  else
    TYPE_IS_ALIAS=`echo $BLTIN_TYPE_RETURNS | egrep -c 'alias'`
    if [ $TYPE_IS_ALIAS -gt 0 ];
    then
    	ITIS_BUILTIN=1
    else  
       COMMAND_IS_BUILTIN=`LC_ALL=C command -v $TEST_CMD 2>/dev/null | egrep -c -w '(builtin|alias)'`
       if [ $COMMAND_IS_BUILTIN -gt 0 ];
       then
       	  ITIS_BUILTIN=1
       fi
    fi
  fi
  eval $RESULT_BUILTIN="'$ITIS_BUILTIN'"	
}

# ########################################
# Source for these functions is  _scripts/isCommandExempt

# DEVELOPERS NOTE: always include builtin prior to this script in your detect scripts

isCommandExempt()
{
  CHECK_THIS=$1
  SKIP_THESE=$2
  CMD_IS_EXEMPT=$3
  
  if [ "x$SKIP_THESE" != "x" ] && [ "$SKIP_THESE" != "-" ] 
  then
    IS_AN_EXEMPTION=`echo "$CHECK_THIS" | awk -F"/" '{print $NF}' | egrep -w -c "$SKIP_THESE"`
  else
    IS_AN_EXEMPTION=0
  fi  
  if [ $IS_AN_EXEMPTION -eq 0 ]
  then	   
    isCommandBuiltin "$CHECK_THIS" ISBUILTIN
    if [ $ISBUILTIN -gt 0 ];
    then
  	  IS_AN_EXEMPTION=1
    fi
  fi  
  eval $CMD_IS_EXEMPT="'$IS_AN_EXEMPTION'"	
}

# ########################################
# source for these functions is _scripts/extractCronCmd

# ##################################################
# function: extractCronCmd
# purpose: 
#  From the given command, determines the actual executable command.
#   If command is su or a shell, it extracts correspnding executable command:
#    i.e su (su [options] -c command or su [options] --command=COMMAND or su --session-command=COMAND)
#    i.e /bin/sh [options] -c command
#        It will return:  command
#  If given command is Not su or a shell, it returns the given command.
#    i.e from /sbin/ping -c 1 192.168.0.1 > /dev/null
#         it will return: /sbin/ping
#     
# parameters:
#  $1 one line from the cronjob file that contains the cronjob command
#     i.e from a line 01 * * * * root /sbin/ping -c 1 192.168.0.1 > /dev/null
#         the $1 should only contain the command part /sbin/ping -c 1 192.168.0.1 > /dev/null
# notes:
#  - If given command is su or a shell and a command can not be extracted, an ERROR will be returned
# ###################################################

extractCronCmd()
{
  local CMD_ENTRY=$1
  local COMMAND=`printf "$CMD_ENTRY" | awk '{print $1}'`
  local SHELLS_LIST_FILE="/etc/shells"

  # Skip if COMMAND is empty or starts with a -. String with precedent - is normally a parameter and makes grep below to choke.
  if [ `printf "$COMMAND" | egrep -c "^-"` -eq 0 ] && [ "x$CMD_ENTRY" != "x" ]
  then

   # Check if it is a su command
    # -----------------------------

    if [ "$COMMAND" = "su" ] || [ "$COMMAND" = `which su` ]
    then
        # Look for the -c. The next element will be the command to analyse. No si el comando comienza con ". /comando" (solo significa que se ejecuta en el shell actual
        #  Puede haber lineas como:  su - ora11g -c ". ~/COMMAND1 && sh /COMMAND2"
        #  y esta linea deberia extraer como COMMAND="~/COMMAND1  /COMMAND2"   siendo la lista de comandos despues de -c y que pueden estar entre "" y tener sh 
        user=`printf "$CMD_ENTRY" | awk '{ if($2~"^-") print $3;
                                         else print $2;}'`
        userhome=`grep "^${user}:" /etc/passwd | awk -F":" '{print $6}'`

        COMMAND=`printf "$CMD_ENTRY" | awk  '{for(i=2;i<=NF;i++) 
                              {  
                                 if($i~"^-") {user=$(i+1);i=i+2;}
                                 if(i==2 && $i!~"^-"){i++;}
                                 if($i~"^-c") {i++;}
                                 printf("%s ",$i);
                              }
                            }' | 
         awk '{if($0~"'"|"'") {  
                          long1=split($0,a,"|"); 
                          for(i=1;i<=long1;i++)
                                  if(a[i]~"&" && a[i]!~"&>" && a[i]!~">&") 
                                        {  
                                          long2=split(a[i],b,"&");
                                          for (j=0;j<=long2;j++)  
                                                  if (b[j] != "") { 
                                                         split(b[j],c," ");
                                                         if (c[1] ~"\".") 
                                                                 print c[2];
                                                         else
                                                            if (c[1] ~ "/bin/csh" || c[1] ~ "/bin/sh" || c[1] ~ "/bin/ksh" || c[1] ~ "/bin/bash" )
                                                                 print c[2];
                                                            else
                                                                 print c[1];
                                                  };
                                        }
                                   else
                                        {
                                         long2=split(a[i],b," ");
                                         if (b[1] ~"\".") 
                                               print b[2];
                                         else
                                               if (b[1] ~ "/bin/csh" || b[1] ~ "/bin/sh" || b[1] ~ "/bin/ksh" || b[1] ~ "/bin/bash" )
                                                       print b[2];
                                               else
                                                       print b[1];
                                        };
                          exit;
                         }
       if($0~"'"&"'" && $0!~"'"&>"'" && $0!~"'">&"'") {  
                        long1=split($0,a,"&"); 
                        for (i=1;i<=long1;i++)
                          {     
                               if (a[i] != "") { 
                                     split(a[i],b," ");
                                     if (b[1] ~"\".")  
                                            print b[2];
                                     else
                                         if (b[1] ~ "/bin/csh" || b[1] ~ "/bin/sh" || b[1] ~ "/bin/ksh" || b[1] ~ "/bin/bash" )
                                            print b[2];
                                         else
                                            print b[1];
                                         };
                               }
                        exit;
                      }
       if ($1== "\".") 
            print $2 ; 
       else 
            print $1 ; }' |
 awk -v uh=$userhome '$1 ~ "~" {sub("~/","/",$1); print uh$1;next;} {print $1}'`
    
        if [  -z "$COMMAND" ];
        then
          # -c was not found or no command after -c was found.  Try searching --command or --session-command
          COMMAND=`printf "$CMD_ENTRY" | awk '{for(i=1;i<=NF;i++){ if((index($i,"--command=")==1) || (index($i,"--session-command=")==1)) {split($i,k,"="); v=k[2]; print v;}}}'`
          # If no command found for the su, mark it as violation
          if [ -z "$COMMAND" ]
          then
            #Command not found for su. Mark it as violation
            COMMAND="ERROR"
          fi
        fi
    else
        # Check if it is a shell command
        # -----------------------------
#        IS_SHELL=`cat $SHELLS_LIST_FILE | grep -w $COMMAND`
        IS_SHELL=0
        for sh1 in `cat $SHELLS_LIST_FILE`
        do
            printf "$CMD_ENTRY" | grep -q -w $sh1 
            if [ $? -eq 0 ]
            then
                 IS_SHELL=1
            fi
        done
        if [ $IS_SHELL -eq 1 ];
        then
            # Look for the -c. The next element will be the command to analyse.
#            COMMAND=`printf "$CMD_ENTRY" | awk '{for(i=1;i<NF;i++){ y=$i; if( match(y,"^-c$")) { print $(i+1);}}}'`
            COMMAND=`printf "$CMD_ENTRY" | awk  '{for(i=1;i<=NF;i++) 
                              {  
                                 if($i~"^-c") {i++;}
                                 printf("%s ",$i);
                              }
                            }' | 
         awk '{if($0~"'"|"'") {  
                          long1=split($0,a,"|"); 
                          for(i=1;i<=long1;i++)
                                  if(a[i]~"&" && a[i]!~"&>" && a[i]!~">&") 
                                        {  
                                          long2=split(a[i],b,"&");
                                          for (j=0;j<=long2;j++)  
                                                  if (b[j] != "") { 
                                                         split(b[j],c," ");
                                                         if (c[1] ~"\".") 
                                                                 print c[2];
                                                         else
                                                            if (c[1] ~ "/bin/csh" || c[1] ~ "/bin/sh" || c[1] ~ "/bin/ksh" || c[1] ~ "/bin/bash" )
                                                                 print c[2];
                                                            else
                                                                 print c[1];
                                                  };
                                        }
                                   else
                                        {
                                         long2=split(a[i],b," ");
                                         if (b[1] ~"\".") 
                                               print b[2];
                                         else
                                               if (b[1] ~ "/bin/csh" || b[1] ~ "/bin/sh" || b[1] ~ "/bin/ksh" || b[1] ~ "/bin/bash" )
                                                       print b[2];
                                               else
                                                       print b[1];
                                        };
                          exit;
                         }
       if($0~"'"&"'" && $0!~"'"&>"'" && $0!~"'">&"'") {  
                        long1=split($0,a,"&"); 
                        for (i=1;i<=long1;i++)
                          {     
                               if (a[i] != "") { 
                                     split(a[i],b," ");
                                     if (b[1] ~"\".")  
                                            print b[2];
                                     else
                                         if (b[1] ~ "/bin/csh" || b[1] ~ "/bin/sh" || b[1] ~ "/bin/ksh" || b[1] ~ "/bin/bash" )
                                            print b[2];
                                         else
                                            print b[1];
                                         };
                               }
                        exit;
                      }
       if ($1== "\".") 
            print $2 ; 
       else 
            print $1 ; }'` 
    
            # If no command found for the shell, mark it as violation
            if [ -z "$COMMAND" ]
            then
              #Command not found for su. Mark it as violation
              COMMAND="ERROR"
            fi
        else
          if [ "$COMMAND" == "sudo" ] || [ "$COMMAND"  == `which sudo` ]
          then
          # if it is sudo, skip over the sudo parameters and find the command
          # sudo parameters start with dash (-)
          # the following sudo parameters have the next parameter as input to them
          #  -p, -U, -g, -u, -C, -r, -t
          # additionally VAR=value to sudo is not the command
            COMMAND=`printf "$CMD_ENTRY" |awk '{for(i=2;i<=NF;i++){if ($i~"^-|^VAR="){ if ($i~"^-p$|^-u$|^-U$|^-g$|^-C$|^-t$|^-r$") ++i;}else{ print $i; break;}}}'`
          else    ##### no es comando "su", ni "shell" ni "sudo", pero puede haber "|" y "&"
            COMMAND=`printf "$CMD_ENTRY" | awk  '{for(i=1;i<=NF;i++) 
                              {  
                                 if($i~"^-c") {i++;}
                                 printf("%s ",$i);
                              }
                            }' | 
            awk '{if($0~"'"|"'") {  
                          long1=split($0,a,"|"); 
                          for(i=1;i<=long1;i++)
                                  if(a[i]~"&" && a[i]!~"&>" && a[i]!~">&") 
                                        {  
                                          long2=split(a[i],b,"&");
                                          for (j=0;j<=long2;j++)  
                                                  if (b[j] != "") { 
                                                         split(b[j],c," ");
                                                         if (c[1] ~"\".") 
                                                                 print c[2];
                                                         else
                                                            if (c[1] ~ "/bin/csh" || c[1] ~ "/bin/sh" || c[1] ~ "/bin/ksh" || c[1] ~ "/bin/bash" )
                                                                 print c[2];
                                                            else
                                                                 print c[1];
                                                  };
                                        }
                                   else
                                        {
                                         long2=split(a[i],b," ");
                                         if (b[1] ~"\".") 
                                               print b[2];
                                         else
                                               if (b[1] ~ "/bin/csh" || b[1] ~ "/bin/sh" || b[1] ~ "/bin/ksh" || b[1] ~ "/bin/bash" )
                                                       print b[2];
                                               else
                                                       print b[1];
                                        };
                          exit;
                         }
               if($0~"'"&"'" && $0!~"'"&>"'" && $0!~"'">&"'") {  
                        long1=split($0,a,"&"); 
                        for (i=1;i<=long1;i++)
                          {     
                               if (a[i] != "") { 
                                     split(a[i],b," ");
                                     if (b[1] ~"\".")  
                                            print b[2];
                                     else
                                         if (b[1] ~ "/bin/csh" || b[1] ~ "/bin/sh" || b[1] ~ "/bin/ksh" || b[1] ~ "/bin/bash" )
                                            print b[2];
                                         else
                                            print b[1];
                                         };
                               }
                        exit;
                      }
       if ($1== "\".") 
            print $2 ; 
       else 
            print $1 ; }'` 
    
          fi        
        fi
    fi

    # In unlikely event that there are two or more -c commnads due to an user error.Shell only executes the first one.
    # This fixlet will do the same and will analyse only the 1st one.
#    COMMAND=`echo $COMMAND | awk '{print $1}'`
    
  fi
  printf "$COMMAND"
}

#
# ########################################
# source for these functions is _scripts/cronCmdFullPath

# ##################################################
# function: isCronjobCmdFullPath
# purpose: 
#  Checks if a given command is has a full path. 
#  If non-compliant, it returns the word VIOLATION. Otherwise no string is returned. 
#  
# parameters:
#  $1 one line from the cronjob file that contains the cronjob command
#     i.e from a line 01 * * * * root /sbin/ping -c 1 192.168.0.1 > /dev/null
#         the $1 should only contain the command part /sbin/ping -c 1 192.168.0.1 > /dev/null
#  $2 Searchable pattern of the commands to be exempted
#  $3 File with local variables for sourcing and resolving paths.   
#  $4 A temp file necessary for processing
# notes:
#  - The given parameter may contain more than 1 command separated by ;. Analyse each command
#  - If command is su or a shell, it extracts corresponding command to analyse from the su parameters:
#    i.e su (su [options] -c command or su [options] --command=COMMAND or su --session-command=COMAND)
#    i.e /bin/sh [options] -c command
# ###################################################

isCronjobCmdFullPath() {
  CRONJOB_COMMAND=$1
  EXEMPTIONS_PARAMETER_SETTING=$2
  FILE_TO_SOURCE=$3
  A_TMPFILE=$4
  FICH_SALIDA=$5
 
  #Several commands can be in a single line separated by ; . Analyse each.
  echo $CRONJOB_COMMAND |  awk '{split($0,a,";");z=1;for(x in a) print a[z++];}' > $A_TMPFILE
  
  cat $A_TMPFILE |
  while read EACH_COMMAND
  do 
    if [ "x$EACH_COMMAND" != "x" ]
    then
        # get the first element/word of the command 
        EXTRACTED_CMD=`extractCronCmd "$EACH_COMMAND"`
         
        # Check if there was an error extracting command  
        if [ "$EXTRACTED_CMD" = "ERROR" ]
        then
            # Return non-compliant due to the extract error
            echo "VIOLATION"
            break;
        fi

        if [ -n "$EXTRACTED_CMD" ]
        then
            # Convert to extended path in case there are env variables on the path
            for EXTRACMD in $EXTRACTED_CMD
            do 
                 if [ `echo "$EXTRACMD" | grep -c "$"` -gt 0 ]
                 then
                     if [ -s $FILE_TO_SOURCE ]
                     then
                          RESOLVED_CMD=`. $FILE_TO_SOURCE; eval "echo $EXTRACMD"`
                     else
                          RESOLVED_CMD=`eval "echo $EXTRACMD"`
                     fi
                 else
                     RESOLVED_CMD="$EXTRACTED_CMD"
                 fi
            
            # The command to analyse has been established.
            # Check if it is a full path, a built in or an exception. If not it is a violation.
                FULLPATH=`echo "$RESOLVED_CMD" | grep "^/"`
                if [ -z "$FULLPATH" ]
                then
                # It is not a full path command
                # Check if command is one of the exceptions or a built in. If it is, skip it.
                    isCommandExempt "$RESOLVED_CMD" "$EXEMPTIONS_PARAMETER_SETTING" IS_EXEMPT
                    if [ $IS_EXEMPT -eq 0 ]
                    then
                    # command is not builtin nor an exception.Return non-compliant
                        echo "VIOLATION"
                        break;
                    fi
                else
                    echo $RESOLVED_CMD >> $FICH_SALIDA
                fi
             done
        fi
    fi
  done
}
# ###### END OF SHARED SCRIPT FUNCTIONS ##############

###****************   CRONTABS de usuarios 'dba'  **********************************************
####     Para AG.1.8.13.1  los comandos de los cron files de usuarios oracle, no pueden tener permiso 'w' for others
####     primero hay que obtener el full-path command name de los comandos que hay dentro del fichero cron de los usuarios oracle ('dba')
####     Este check dara NOK en caso que los comandos detectados en el cron del USER  no existan
####     o tengan permisos 'w' (others) prohibidos.
####     o los subdirectorios intermedios de dichos comandos tengan permisos 'w' (others)
function cron_comandos ()
{

# Setup tmpfiles
ERRORFILE=errorfile
CRONTAB=crontmp1
SOURCEFILE=cronsource
TMPFILE=tmpfile ; >$TMPFILE

# Crontab file for oracle users locations
# /var/spool/cron/user-oracle RHEL 4, 5, 6

FILETOREAD=$1   

> cronfullpath


#Check for existance of the file to analyse
if [ -s $FILETOREAD ]
then
	# File exist. Remove comments, empty lines and environment variables
    normalizeFile $FILETOREAD > $CRONTAB
   
	if [ -s $CRONTAB ];
	then		
    	# Create file that contains only local variables.
    	# This is done so when sourcing only the variables get processed/executed for path resolution
    	# so the other commands will not be executed.
		awk '{x=index($1,"="); if(x>0){y=substr($1,x+1); if( !(y~"^`")) print $1}}' $CRONTAB > $SOURCEFILE
        
	    cat $CRONTAB |
	    while read ENTRY
	    do
			# Get the command.
            IS_SHORT_FORMAT=`printf "$ENTRY" | grep "^@"`
   			CRON_COMMAND=`printf "$ENTRY" | awk -vShort="$IS_SHORT_FORMAT" '{if( length(Short)>0) {start=2;} else{ start=6;};{for(i=start;i<=NF;i++){ {printf $i " ";} }}}'`

	        # Check if a command exists on the line
      		if [ -n "$CRON_COMMAND" ]
      		then
				# Verify the command is full path compliant.
                # A value retunrn, means command is Not a full path	
				IS_FULLPATH=`isCronjobCmdFullPath "$CRON_COMMAND" "$EXEMPT_PATTERN" "$SOURCEFILE" "$TMPFILE" cronfullpath`
				rm -f $TMPFILE
				
	      		if [ $IS_FULLPATH ]
    			then
	    	   		# command in violation. Add it to the non-compliant list
    				printf "${ENTRY}\n" >> $ERRORFILE
    			fi
      		fi
      	done
	fi
	    	
	
# Check for the existance of fail results
        if [ -s $ERRORFILE ]
        then
	#  has non compliant entries
		RESULTADOCRON="Existen lineas activas en $FILETOREAD que no especifican full path para file/command/script y no es posible obtener los permisos"
                cat $ERRORFILE
        else
                RESULTADOCRON="$FILETOREAD: Los file/command/script son full-path"
        fi
        #  se deben revisar los permisos de los ficheros de cronfullpath        
           comandos=`cat cronfullpath | tr -s '\n' ' '`
else
	RESULTADOCRON="Fichero $FICHERO no existe. Nada que chequear."
fi	

rm -f $ERRORFILE
rm -f $CRONTAB
rm -f $SOURCEFILE
rm -f $TMPFILE
printf "$comandos"

}

#*******************************************************************************
####          generacion de  consultas SQL 
###*****************************************************************************
####
####  Consulta cuantas instancias oracle para 1 BD
####
cat << EOF > $DIR/single_rac_instance.sql

-- obtiene la cantidad de instancias, si es 1=single instance,  si son varias=RAC 

connect /as sysdba

 
set verify off
set pagesize 0
set feedback off 

select count(*) from gv\$instance;

quit
EOF

#####################################################################
####  Consulta si es una single instance o es un cluster RAC de varias intancias oracle para 1 BD
####
cat << EOF > $DIR/rac_instance.sql

-- obtiene los nombres de los hostname que son parte de la instancia RAC

connect /as sysdba

 
set verify off
set pagesize 0
set feedback off 
set colsep ";"

select instance_name, host_name from gv\$instance;

quit
EOF

#######################################################################################################
####
####  Consulta para saber si una instancia con pmon, tiene su BASE en estado PRIMARY o DATABASE_STANDY
####===================================================================================================
cat << EOF > $DIR/bd_primaria.sql

-- Verifica si una BD con 'pmon' activo  esta en estado 'PRIMARY' que implica que es candidata a chequearse si ademas esta abierta

connect /as sysdba

set verify off
set pagesize 0
set feedback off 

select database_role from v\$database ; 
quit
EOF

######################################################################################################
####  Consulta para AG.1.1.1  - PASSWORD LIFE TIME
####
cat << EOF > $DIR/ag_1_1_1_password_life_time.sql

connect /as sysdba

set verify off 
set linesize 132
set serveroutput on
set feedback off

spool $DIR/ag_1_1_1_password_life_time.log

Declare 
   techspec varchar(9) := 'AG.1.1.1';
   valordefault varchar(10);
   strbase varchar2(15);
   instance varchar2(15);
 
Begin

SELECT  sys_context('USERENV','DB_NAME') INTO strbase FROM dual;
select instance_name into instance from v\$instance;
dbms_output.put_line (chr(10) || 'Instance: ' || instance || ' : PASSWORD LIFE TIME - must be $PARAM111   (' || TO_CHAR(SYSDATE) || ')' ||  chr(10) || '-------------------------------------------' );
-- dbms_output.put_line ('La caducidad de passwords debe ser $PARAM111 dias. Este parametro se setea a nivel de PROFILE');
-- dbms_output.put_line ('Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE.');
-- dbms_output.put_line ('Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile' || chr(10));

dbms_output.put_line (chr(10) || 'Base de datos: ' || strbase );

For cadaprof1 in (Select distinct PROFILE  from dba_profiles)
Loop
    For ProfileParameter in (Select  LIMIT from dba_profiles where RESOURCE_NAME like 'PASSWORD_LIFE_TIME' AND PROFILE like cadaprof1.PROFILE  order by RESOURCE_TYPE ) 
    Loop
        IF  ProfileParameter.LIMIT <> '$PARAM111' THEN 
            IF ProfileParameter.LIMIT = 'DEFAULT' THEN  -- se debe extraer el LIMIT del profile DEFAULT
               select LIMIT into valordefault from dba_profiles where RESOURCE_NAME like 'PASSWORD_LIFE_TIME' and PROFILE = 'DEFAULT';
               IF valordefault <> '$PARAM111' THEN
                  dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_LIFE_TIME: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault || ')' );
                  for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
                  Loop
                     dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")    USER: "'|| user1.username || '" , password life time is ' || valordefault );
                  End Loop;
               ELSE
                  dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_LIFE_TIME: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault || ')' );
               END IF ;
            ELSE
                  dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_LIFE_TIME: "' || ProfileParameter.LIMIT || '"');
                  for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
                  Loop
                     dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")    USER: "'|| user1.username || '" , password life time is ' || ProfileParameter.LIMIT );
                  End Loop;
            END IF; 
        ELSE
            dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_LIFE_TIME: "' || ProfileParameter.LIMIT || '"');
        END IF;
    End Loop;
End Loop ;  

End;
/
spool off 

quit

EOF

#####################################################################################################3333
###   consulta SQL que obtiene el estado de todos los usuarios Oracle de todas las BDs abiertas
###
########################################################################################################
 
cat <<EOF > $DIR/check_pwd.sql

connect /as sysdba

column usr format a25
column prof format a20
column stat format a18
column last_pwd_chg format a16
column expdate format a16
column lockdate format a16
column caducidad_180_dias format a40
set linesize 180
set pages 70
set head off 
set feedback off

select 'Fecha      : ' || sysdate ||  '       HOSTNAME : ' || UTL_INADDR.get_host_name || '        BASE: ' ||  sys_context('USERENV','DB_NAME') 
from dual;

set head on 

select a.username usr, 
       a.profile prof, 
       a.account_status stat, 
       (case when (a.expiry_date is null) then 'no caduca'
        else to_char(a.expiry_date,'DD-MON-YY/HH24:MI') end ) expdate, 
       (case when (b.ptime is null ) then 'passwd never set'
         else to_char(b.ptime,'DD-MON-YY/HH24:MI')end )  last_pwd_chg, 
       to_char(a.lock_date,'DD-MON-YY/HH24:MI')  lockdate, 
--       (case when (a.expiry_date < sysdate)  then 'caducado' 
--             when ((a.expiry_date > sysdate or a.expiry_date = sysdate) and sysdate < (b.ptime + $PARAM111))  then 'vigente'
--             when (b.ptime is null) then 'password never set'
--             when (a.expiry_date is null and b.ptime is not null and (sysdate < (b.ptime + $PARAM111) or sysdate = (b.ptime + $PARAM111))) then 'caducaria el ' || to_char((b.ptime + $PARAM111),'DD-MON-YY/HH24:MI')
--             when (a.expiry_date is null and b.ptime is not null and sysdate > (b.ptime + $PARAM111)) then 'con $PARAM111 dias estaria caducada desde ' || to_char((b.ptime + $PARAM111),'DD-MON-YY') 
--            else  to_char((b.ptime + $PARAM111),'DD-MON-YY/HH24:MI') 
       (case 
             when (a.expiry_date is null and b.ptime is not null and (sysdate < (b.ptime + $PARAM111) or sysdate = (b.ptime + $PARAM111))) then 'caducaria el ' || to_char((b.ptime + $PARAM111),'DD-MON-YY/HH24:MI')
             when (a.expiry_date is null and b.ptime is not null and sysdate > (b.ptime + $PARAM111)) then 'estaria caducada desde ' || to_char((b.ptime + $PARAM111),'DD-MON-YY/HH24:MI') 
             when (a.expiry_date < sysdate and a.account_status = 'OPEN') then 'actualmente caducado'
             when ((a.expiry_date > sysdate or a.expiry_date = sysdate) and sysdate < (b.ptime + $PARAM111))  then 'vigente'
               else '            '
       end) caducidad_${PARAM111}_dias 
from dba_users a, user$ b 
where a.username = b.name 
order by profile; 

quit

EOF
######################################################################################################
####  Consulta para AG.1.1.2  - PASSWORD GRACE TIME
####
cat << EOF > $DIR/ag_1_1_2_password_grace_time.sql

connect /as sysdba

set verify off 
set linesize 132
set serveroutput on
set feedback off

spool $DIR/ag_1_1_2_password_grace_time.log

Declare 
   techspec varchar(9) := 'AG.1.1.2';
   valordefault varchar(10);
   strbase varchar2(15);
   instance varchar(15);

Begin

SELECT  sys_context('USERENV','DB_NAME') INTO strbase FROM dual;
select instance_name into instance from v\$instance;
dbms_output.put_line (chr(10) || 'Instance: ' || instance || ' : PASSWORD GRACE TIME - must be $PARAM112   (' || TO_CHAR(SYSDATE) || ')' || chr(10) || '-------------------------------------------' );
-- dbms_output.put_line ('Dias adicionales a la caducidad de password en la que es posible cambiar la password antes que expire la cuenta');
-- dbms_output.put_line ('Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE');
-- dbms_output.put_line ('Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile' || chr(10));

dbms_output.put_line (chr(10) || 'Base de datos: ' || strbase );

For cadaprof1 in (Select distinct PROFILE  from dba_profiles)
Loop
    For ProfileParameter in (Select  LIMIT from dba_profiles where RESOURCE_NAME like 'PASSWORD_GRACE_TIME' AND PROFILE like cadaprof1.PROFILE  order by RESOURCE_TYPE )
    Loop
        IF  ProfileParameter.LIMIT <> '$PARAM112' THEN 
            IF ProfileParameter.LIMIT = 'DEFAULT' THEN  -- se debe extraer el LIMIT del profile DEFAULT
               select LIMIT into valordefault from dba_profiles where RESOURCE_NAME like 'PASSWORD_GRACE_TIME' and PROFILE = 'DEFAULT';
               IF valordefault <> '$PARAM112' THEN
                     dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_GRACE_TIME: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
                     for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
                     Loop
                          dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")    USER: "'|| user1.username || '" , password grace time is ' || valordefault );
                     End Loop;
               ELSE
                     dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_GRACE_TIME: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
               END IF;
            ELSE
               dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_GRACE_TIME: "' || ProfileParameter.LIMIT || '"');
               for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
               Loop
                     dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")    USER: "'|| user1.username || '" , password grace time is ' || ProfileParameter.LIMIT );
               End Loop;
            END IF;
        ELSE
            dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_GRACE_TIME: "' || ProfileParameter.LIMIT ||'"' );
        END IF;
    End Loop;
End Loop ;  

End;
/
spool off 
quit

EOF

######################################################################################################
####  Consulta para AG.1.1.4  - PASSWORD REUSE TIME
####
cat << EOF > $DIR/ag_1_1_4_password_reuse_time.sql

connect /as sysdba

set verify off 
set linesize 132
set serveroutput on
set feedback off

spool $DIR/ag_1_1_4_password_reuse_time.log

Declare 
   techspec varchar(9) := 'AG.1.1.4';
   valordefault varchar(10);
   strbase varchar2(15);
   instance varchar(15);

Begin

SELECT  sys_context('USERENV','DB_NAME') INTO strbase FROM dual;
select instance_name into instance from v\$instance;
dbms_output.put_line (chr(10) || 'Instance: ' || instance || ' : PASSWORD REUSE TIME - must be $PARAM114   (' || TO_CHAR(SYSDATE) || ')' || chr(10) || '-------------------------------------------' );
-- dbms_output.put_line ('Cantidad de dias que deben pasar antes de reutilizar una password.');
-- dbms_output.put_line ('Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE');
-- dbms_output.put_line ('Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile' || chr(10));

dbms_output.put_line (chr(10) || 'Base de datos: ' || strbase );

For cadaprof1 in (Select distinct PROFILE  from dba_profiles)
Loop
    For ProfileParameter in (Select  LIMIT from dba_profiles where RESOURCE_NAME like 'PASSWORD_REUSE_TIME' AND PROFILE like cadaprof1.PROFILE  order by RESOURCE_TYPE )
    Loop
        IF  ProfileParameter.LIMIT <> '$PARAM114' THEN 
            IF ProfileParameter.LIMIT = 'DEFAULT' THEN  -- se debe extraer el LIMIT del profile DEFAULT
               select LIMIT into valordefault from dba_profiles where RESOURCE_NAME like 'PASSWORD_REUSE_TIME' and PROFILE = 'DEFAULT';
               IF valordefault <> '$PARAM114' THEN
                     dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_REUSE_TIME: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
                     for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
                     Loop
                          dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")   USER: "'|| user1.username || '" , password reuse time is ' || valordefault );
                     End Loop;
               ELSE
                     dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_REUSE_TIME: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
               END IF;
            ELSE
               dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_REUSE_TIME: "' || ProfileParameter.LIMIT || '"');
               for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
               Loop
                     dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")   USER: "'|| user1.username || '" , password reuse time is ' || ProfileParameter.LIMIT );
               End Loop;
            END IF;
        ELSE
            dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_REUSE_TIME: "' || ProfileParameter.LIMIT || '"');
        END IF;
    End Loop;
End Loop ;  

End;
/
spool off 
quit

EOF

######################################################################################################
####  Consulta para AG.1.1.5  - PASSWORD REUSE MAX 
####
cat << EOF > $DIR/ag_1_1_5_password_reuse_max.sql

connect /as sysdba

set verify off 
set linesize 132
set serveroutput on
set feedback off

spool $DIR/ag_1_1_5_password_reuse_max.log

Declare 
   techspec varchar(9) := 'AG.1.1.5';
   valordefault varchar(10);
   strbase varchar2(15);
   instance varchar(15);

Begin

SELECT  sys_context('USERENV','DB_NAME') INTO strbase FROM dual;
select instance_name into instance  from v\$instance;
dbms_output.put_line (chr(10) || 'Instance: ' || instance || ' : PASSWORD REUSE MAX - must be $PARAM115   (' || TO_CHAR(SYSDATE) || ')' || chr(10) || '-------------------------------------------' );
-- dbms_output.put_line ('Cantidad de password distintas que deben setearse antes de repetir una password.');
-- dbms_output.put_line ('Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE');
-- dbms_output.put_line ('Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile' || chr(10));

dbms_output.put_line (chr(10) || 'Base de datos: ' || strbase );

For cadaprof1 in (Select distinct PROFILE  from dba_profiles)
Loop
    For ProfileParameter in (Select  LIMIT from dba_profiles where RESOURCE_NAME like 'PASSWORD_REUSE_MAX' AND PROFILE like cadaprof1.PROFILE  order by RESOURCE_TYPE )
    Loop
        IF  ProfileParameter.LIMIT <> '$PARAM115' THEN 
            IF ProfileParameter.LIMIT = 'DEFAULT' THEN  -- se debe extraer el LIMIT del profile DEFAULT
               select LIMIT into valordefault from dba_profiles where RESOURCE_NAME like 'PASSWORD_REUSE_MAX' and PROFILE = 'DEFAULT';
               IF valordefault <> '$PARAM115' THEN
                     dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_REUSE_MAX: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
                     for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
                     Loop
                          dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")   USER: "'|| user1.username || '" , password reuse max is ' || valordefault );
                     End Loop;
               ELSE
                     dbms_output.put_line ('OK:  PROFILE: "' || cadaprof1.PROFILE || '"  ,PASSWORD_REUSE_MAX: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
               END IF;
            ELSE
               dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_REUSE_MAX: "' || ProfileParameter.LIMIT || '"');
               for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
               Loop
                     dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")   USER: "'|| user1.username || '" , password reuse max is ' || ProfileParameter.LIMIT );
               End Loop;
            END IF;
        ELSE
            dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_REUSE_MAX: "' || ProfileParameter.LIMIT || '"');
        END IF;
    End Loop;
End Loop ;  

End;
/
spool off 
quit

EOF

######################################################################################################
####  Consulta para AG.1.1.6  - FAILED_LOGIN_ATTEMPTS 
####
cat << EOF > $DIR/ag_1_1_6_failed_login_attempts.sql

connect /as sysdba

set verify off 
set linesize 132
set serveroutput on
set feedback off

spool $DIR/ag_1_1_6_failed_login_attempts.log

Declare 
   techspec varchar(9) := 'AG.1.1.6';
   valordefault varchar(10);
   strbase varchar2(15);
   instance  varchar(15);

Begin

SELECT  sys_context('USERENV','DB_NAME') INTO strbase FROM dual;
select instance_name into instance from v\$instance;
dbms_output.put_line (chr(10) || 'Instance: ' || instance || ' : FAILED LOGIN ATTEMPTS - must be $PARAM116   (' || TO_CHAR(SYSDATE) || ')' || chr(10) || '-------------------------------------------' );
-- dbms_output.put_line ('Cantidad de fallos permitidos durante el login usando la password.');
-- dbms_output.put_line ('Superada la cantidad de fallos, el usuario queda en estado LOCKED, y no podra logarse hasta que no se desbloquee expresamente');
-- dbms_output.put_line ('Si el usuario esta custodiado por SEGUR, esta herramienta desbloquea el usuario cuando le asigne una password');
-- dbms_output.put_line ('en cambio si NO esta custodiado por SEGUR, el usuario debera desbloquearse expresamente por un DBA'); 
-- dbms_output.put_line ('Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE');
-- dbms_output.put_line ('Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile' || chr(10));

dbms_output.put_line (chr(10) || 'Base de datos: ' || strbase );

For cadaprof1 in (Select distinct PROFILE  from dba_profiles)
Loop
    For ProfileParameter in (Select  LIMIT from dba_profiles where RESOURCE_NAME like 'FAILED_LOGIN_ATTEMPTS' AND PROFILE like cadaprof1.PROFILE  order by RESOURCE_TYPE )
    Loop
        IF  ProfileParameter.LIMIT <> '$PARAM116' THEN 
            IF ProfileParameter.LIMIT = 'DEFAULT' THEN  -- se debe extraer el LIMIT del profile DEFAULT
               select LIMIT into valordefault from dba_profiles where RESOURCE_NAME like 'FAILED_LOGIN_ATTEMPTS' and PROFILE = 'DEFAULT';
               IF valordefault <> '$PARAM116' THEN
                     dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,FAILED_LOGIN_ATTEMPTS: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
                     for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
                     Loop
                          dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")   USER: "'|| user1.username || '" , failed login attempts is ' || valordefault );
                     End Loop;
               ELSE
                     dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,FAILED_LOGIN_ATTEMPTS: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
               END IF;
            ELSE
               dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,FAILED_LOGIN_ATTEMPTS: "' || ProfileParameter.LIMIT || '"');
               for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
               Loop
                     dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")   USER: "'|| user1.username || '" , failed login attempts is ' || ProfileParameter.LIMIT );
               End Loop;
            END IF;
        ELSE
            dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,FAILED_LOGIN_ATTEMPTS: "' || ProfileParameter.LIMIT || '"');
        END IF;
    End Loop;
End Loop ;  

End;
/
spool off 
quit

EOF
########################################################################################################################
###   Consulta de la cantidad de retries de cada usuario de una BD
###
cat <<EOF > $DIR/check_retries.sql

connect /as sysdba

column usr format a25
column prof format a20
column stat format a18
column lockdate format a16
column retries_actuales format a18 
column fallos_permitidos format a17
column c.limit format a10
set linesize 150
set pages 70
set head off 
set feedback off 

select 'Fecha      : ' || sysdate ||  '       HOSTNAME : ' || UTL_INADDR.get_host_name || '        BASE: ' ||  sys_context('USERENV','DB_NAME') 
from dual;

set head on 

select a.username usr, 
       a.profile prof, 
       a.account_status stat, 
       to_char(a.lock_date,'DD-MON-YY/HH24:MI')  lockdate, 
       lpad(c.limit,16,' ') fallos_permitidos,
       (case 
             when (b.lcount > $PARAM116 and c.limit = 'UNLIMITED' ) then 'estaria lockeado con: ' || lpad(to_char(b.lcount,5),17,' ') || ' login retries'
             else lpad(to_char(b.lcount,5),17,' ') 
       end) retries_actuales 
from dba_users a, user$ b, dba_profiles c 
where a.username = b.name and a.profile = c.profile  and c.resource_name = 'FAILED_LOGIN_ATTEMPTS'
order by a.profile; 

quit

EOF

######################################################################################################
####  Consulta para AG.1.1.7  - PASSWORD LOCK TIME 
####
cat << EOF > $DIR/ag_1_1_7_password_lock_time.sql

connect /as sysdba

set verify off 
set linesize 132
set serveroutput on
set feedback off

spool $DIR/ag_1_1_7_password_lock_time.log

Declare 
   techspec varchar(9) := 'AG.1.1.7';
   valordefault varchar(10);
   strbase varchar2(15);
   instance varchar2(15);

Begin

SELECT  sys_context('USERENV','DB_NAME') INTO strbase FROM dual;
select instance_name into instance from v\$instance;
dbms_output.put_line (chr(10) || 'Instance: ' || instance || ' : PASSWORD LOCK TIME  - must be $PARAM117   (' || TO_CHAR(SYSDATE) || ')' || chr(10) || '-------------------------------------------' );
-- dbms_output.put_line ('Cantidad de dias que un usuario permanece en estado LOCKED despues de superar FAILED_LOGIN_ATTEMPTS.');
-- dbms_output.put_line ('Superada la cantidad de dias de PASSWORD_LOCK_TIME, Oracle desbloquea automaticamente al usuario para ahorrar tareas al DBA.');
-- dbms_output.put_line ('Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE');
-- dbms_output.put_line ('Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile' || chr(10));

dbms_output.put_line (chr(10) || 'Base de datos: ' || strbase );

For cadaprof1 in (Select distinct PROFILE  from dba_profiles)
Loop
    For ProfileParameter in (Select  LIMIT from dba_profiles where RESOURCE_NAME like 'PASSWORD_LOCK_TIME' AND PROFILE like cadaprof1.PROFILE  order by RESOURCE_TYPE )
    Loop
        IF  ProfileParameter.LIMIT <> '$PARAM117' THEN 
            IF ProfileParameter.LIMIT = 'DEFAULT' THEN  -- se debe extraer el LIMIT del profile DEFAULT
               select LIMIT into valordefault from dba_profiles where RESOURCE_NAME like 'PASSWORD_LOCK_TIME' and PROFILE = 'DEFAULT';
               IF valordefault <> '$PARAM117' THEN
                     dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_LOCK_TIME: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
                     for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
                     Loop
                          dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE || '")   USER: "'|| user1.username || '" , password lock time is ' || valordefault );
                     End Loop;
               ELSE
                     dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_LOCK_TIME: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
               END IF;
            ELSE
               dbms_output.put_line ('NOK: PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_LOCK_TIME: "' || ProfileParameter.LIMIT || '"');
               for user1 in (select username from dba_users where profile like cadaprof1.PROFILE and account_status not like '%LOCKED%')
               Loop
                     dbms_output.put_line (chr(3) ||'  ("' || cadaprof1.PROFILE ||'")   USER: "'|| user1.username || '" , password lock time  is ' || ProfileParameter.LIMIT );
               End Loop;
            END IF;
        ELSE
            dbms_output.put_line ('OK:  PROFILE: "'|| cadaprof1.PROFILE || '"  ,PASSWORD_LOCK_TIME: "' || ProfileParameter.LIMIT || '"');
        END IF;
    End Loop;
End Loop ;  

End;
/
spool off 
quit

EOF

######################################################################################################
####  Consulta para AG.1.1.8  - PASSWORD VERIFY FUNCTION 
####
cat << EOF > $DIR/ag_1_1_8_password_verify_function.sql

connect /as sysdba

set verify off 
set linesize 160
set serveroutput on
set feedback off

spool $DIR/ag_1_1_8_password_verify_function.log

Declare 
   techspec varchar(9) := 'AG.1.1.8';
   valordefault varchar(10);
   strbase varchar2(15);
   isdefault number;
   value varchar2(30);
   passlong varchar2(20); 
   passalpha varchar2(20); 
   passnum varchar2(20); 
   passigual varchar(20);
   ispriv boolean;
   instance varchar2(15);

-- Esta funcion se accede siempre que el user g2gpru ya existe, luego lo cambiamos al perfil que estamos chequeando e intentamos darle una password mala
FUNCTION CheckPVF_alphanum(usuario VARCHAR2, perfil VARCHAR2, pass VARCHAR2, value VARCHAR2, check1 VARCHAR2, ispriv BOOLEAN) RETURN boolean
IS
        err_msg varchar2(1000);
        err_num number;
        a exception; 
BEGIN
        execute immediate 'alter user g2gpru  profile "' || perfil || '"';
        execute immediate 'alter user g2gpru IDENTIFIED BY "' || pass || '"';
        raise a;

        EXCEPTION
        when a then
           IF ispriv THEN
             DBMS_OUTPUT.PUT_LINE ('NOK: USER: ' || rpad(usuario,20,' ') || ' PROFILE: "'|| perfil || '" ,PASSWORD_VERIFY_FUNCTION: "' || value || '"  no cumple ' || check1 || chr(10) );
           ELSE
             DBMS_OUTPUT.PUT_LINE ('NOK: USER: ' || rpad(usuario,20,' ') || ' PROFILE: "'|| perfil || '" ,PASSWORD_VERIFY_FUNCTION: "' || value || '"  no cumple ' || check1 );
           END IF;
             RETURN FALSE;
        when OTHERS then
                err_num := SQLCODE;
                err_msg := SUBSTR(SQLERRM, 1, 1000);
--        DBMS_OUTPUT.PUT_LINE(err_num || ':' ||err_msg);
                RETURN TRUE;

END CheckPVF_alphanum;

-- esta funcion solo entra cuando el user g2gpru no existe, luego lo crea con una longitud de password incorrecta 
FUNCTION CheckPVF(usuario VARCHAR2, perfil VARCHAR2, value VARCHAR2, isdefault NUMBER,  pass VARCHAR2, ispriv BOOLEAN) RETURN boolean 
IS
        err_msg varchar2(1000);
        err_num number;
        b exception;
        c varchar2(2);
BEGIN
        execute immediate 'create user g2gpru IDENTIFIED BY "' || pass || '" profile "' || perfil || '"';
        raise b;
 
        EXCEPTION
        when b then
           IF ispriv THEN
              c:=chr(10);
           ELSE
              c:='';
           END IF;

           IF isdefault = 1 THEN
             DBMS_OUTPUT.PUT_LINE ('NOK: USER: ' || rpad(usuario,20,' ') || ' PROFILE: "'|| perfil || '"  ,PASSWORD_VERIFY_FUNCTION: "' || value || '" no cumple longitud password (from PROFILE DEFAULT)' || c );
           ELSE
             DBMS_OUTPUT.PUT_LINE ('NOK: USER: ' || rpad(usuario,20,' ') || ' PROFILE: "'|| perfil || '"  ,PASSWORD_VERIFY_FUNCTION: "' || value || '" no cumple longitud password' || c);
           END IF; 
           RETURN FALSE;
        when OTHERS then   -- se cumple longitud de password y ahora debe probar la asignacion de password alfabeticas y numericas
                err_num := SQLCODE;
                err_msg := SUBSTR(SQLERRM, 1, 1000);
--        DBMS_OUTPUT.PUT_LINE(err_num || ':' ||err_msg);
                RETURN TRUE;        
END CheckPVF;
 
--  Funcion que chequea si el user g2gpru existe, para saber si hacemos un create user o un alter user cuando verificamos la funcion de password
FUNCTION existe_g2gpru return boolean
IS
     var varchar2(10);
     c exception;
Begin
      select username into var from dba_users where username = 'G2GPRU';
      raise c;
 EXCEPTION 
 WHEN c then
      IF VAR = 'G2GPRU' THEN
          RETURN TRUE;
      ELSE
          RETURN FALSE;
      END IF;
 WHEN OTHERS  THEN
      RETURN FALSE; 
END existe_g2gpru;

-- si el usuario que entra, tiene alguno de los privilegios significa que es un usuario privilegiado, por lo que devuelve TRUE, si no, devuelve FALSE
-- Los usuarios privilegiados deben cumplir con una longitud de password = 14, lo demas deben cumplir con longitud password = 8
FUNCTION user_privi(usuario varchar2) RETURN BOOLEAN
IS

BEGIN
For user1 in (select granted_role from
  (
  /* THE USERS */
    select 
      null     grantee, 
      username granted_role
    from 
      dba_users
    where
        username like upper(usuario)
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select 
      grantee ,
      granted_role 
    from
      dba_role_privs
      where granted_role not in ('CONNECT','RESOURCE')
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select
      grantee,
      privilege 
    from
      dba_sys_privs
     where privilege in ('ALTER DATABASE','ALTER PROFILE','ALTER SYSTEM','ALTER TABLESPACE','ALTER USER','AUDIT ANY','AUDIT SYSTEM','CREATE ANY JOB','CREATE PROFILE','CREATE ROLLBACK SEGMENT','CREATE TABLESPACE','CREATE USER','DROP RPOFILE','DROP ROLLBACK SEGMENT','DROP TABLESPACE','DROP USER','GRANT ANY OBJECT PRIVILEGE','GRANT ANY PRIVILEGE','GRANT ANY ROLE','MANAGE TABLESPACE','RESTRICTED SESSION') and grantee is not null and grantee not in ('CONNECT','RESOURCE') 
 )
start with grantee is null
connect by grantee = prior granted_role)

Loop
     if user1.granted_role in ('ALTER DATABASE','ALTER PROFILE','ALTER SYSTEM','ALTER TABLESPACE','ALTER USER','AUDIT ANY','AUDIT SYSTEM','CREATE ANY JOB','CREATE PROFILE','CREATE ROLLBACK SEGMENT','CREATE TABLESPACE','CREATE USER','DROP RPOFILE','DROP ROLLBACK SEGMENT','DROP TABLESPACE','DROP USER','GRANT ANY OBJECT PRIVILEGE','GRANT ANY PRIVILEGE','GRANT ANY ROLE','MANAGE TABLESPACE','RESTRICTED SESSION', 'DBA','IMP_FULL_DATABASE','EXECUTE_CATALOG_ROLE','DELETE_CATALOG_ROLE') THEN
  dbms_output.put_line(chr(10) || usuario || ' : usuario privilegiado');
       RETURN TRUE;   -- si tiene alguno de esos privilegios, entonces es privilegiado
     END IF;
End Loop;      -- si termina el loop sin ninguno de esos privilegios, entonces no es un usuario privilegiado
RETURN FALSE;
END user_privi;


BEGIN

SELECT  sys_context('USERENV','DB_NAME') INTO strbase FROM dual;
select instance_name into instance from v\$instance;
dbms_output.put_line (chr(10) || 'Instance: ' || instance || ' : PASSWORD VERIFY FUNCTION  -   (' || TO_CHAR(SYSDATE) || ')' || chr(10) || '-------------------------------------------' );
-- dbms_output.put_line ('La funcion de verificacion de password de un perfil, es utilizada durante el cambio de password.');
-- dbms_output.put_line ('No se aceptan PASSWORD_VERIFY_FUNCTION = NULL');
-- dbms_output.put_line ('Las funciones asociadas, deben cumplir con los requisitos:');
-- dbms_output.put_line ('  - Longitud de password usuarios privilegiados:  14 (caixa)');
-- dbms_output.put_line ('  - Longitud de password usuarios generales: 8 (caixa/itnow)');
-- dbms_output.put_line ('  - La password no debe conicidir con el nombre de usuario');
-- dbms_output.put_line ('  - La password debe contener al menos 1 caracter alfabetico');
-- dbms_output.put_line ('  - La password debe contener al menos 1 digito numerico');
-- dbms_output.put_line ('Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE');
-- dbms_output.put_line ('Solo revisamos los usuarios (NO LOCKED) que incumplen la normativa' || chr(10));

dbms_output.put_line (chr(10) || 'Base de datos: ' || strbase );
For uuu in (select username,profile from dba_users where account_status not like '%LOCKED%')
Loop
    For ProfileParameter in (Select  LIMIT from dba_profiles where RESOURCE_NAME like 'PASSWORD_VERIFY_FUNCTION' AND PROFILE like uuu.PROFILE  order by RESOURCE_TYPE )
    Loop
         IF ProfileParameter.LIMIT = 'NULL' THEN
                ispriv:=user_privi(uuu.username);
                IF ispriv THEN
                    dbms_output.put_line ('NOK: USER: ' || rpad(uuu.username,20,' ') || ' PROFILE: "'|| uuu.PROFILE || '" ,PASSWORD_VERIFY_FUNCTION: "' || ProfileParameter.LIMIT || '" no tiene funcion' || chr(10));
                ELSE
                    dbms_output.put_line ('NOK: USER: ' || rpad(uuu.username,20,' ') || ' PROFILE: "'|| uuu.PROFILE || '" ,PASSWORD_VERIFY_FUNCTION: "' || ProfileParameter.LIMIT || '" no tiene funcion' );
                END IF;
         ELSE  -- is not null 
            IF ProfileParameter.LIMIT = 'DEFAULT' THEN  -- is default, se verifica valor default en perfil default
               select LIMIT into valordefault from dba_profiles where profile='DEFAULT' and RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION';
               IF valordefault = 'NULL' THEN  -- is default, pero la funcion default es null
                     ispriv:=user_privi(uuu.username);
                     IF ispriv THEN
                         dbms_output.put_line ('NOK: USER: ' || rpad(uuu.username,20,' ') || ' PROFILE: "'|| uuu.PROFILE || '" ,PASSWORD_VERIFY_FUNCTION: "' || ProfileParameter.LIMIT || '" no tiene funcion (from PROFILE DEFAULT = ' || valordefault ||')' || chr(10));
                     ELSE
                         dbms_output.put_line ('NOK: USER: ' || rpad(uuu.username,20,' ') || ' PROFILE: "'|| uuu.PROFILE || '" ,PASSWORD_VERIFY_FUNCTION: "' || ProfileParameter.LIMIT || '" no tiene funcion (from PROFILE DEFAULT = ' || valordefault ||')' );
                     END IF;
               ELSE    -- es default not null
                     value:=ProfileParameter.LIMIT;
                     ispriv:=user_privi(uuu.username);
                     IF ispriv THEN       -- es un usuario privilegiado
                             passlong := '0987654321abc';       -- asigna password larga para perfil generic  (que pide 14)
                             passalpha := 'abcdefghijklmn';       -- asigna password alfabeticos perfil generic (falta 1 numerico)
                             passnum := '12345678901234';             -- asigna password numerico perfil generic (falta 1 alfabetico) 
                             passigual := 'g2gpru';             -- asigna password = username
                     ELSE
                             passlong := 'abCa1ai';             -- asigna password corta para perfil personal  (que pide 8)
                             passalpha := 'abCaiaix';             -- asigna password alfabeticos perfil personal (falta 1 numerico) 
                             passnum := '12345678';             -- asigna password numerico perfil personal (falta 1 alfabetico) 
                             passigual := 'g2gpru';             -- asigna password = username
                     END IF;
                     IF ( existe_g2gpru ) THEN
                         if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passlong,value,'longitud password (from PROFILE DEFAULT)',ispriv)) THEN
                               if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passalpha,value,'1 caracter numerico (from PROFILE DEFAULT)',ispriv)) THEN 
                                    if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passnum,value,'1 caracter alfabetico (from PROFILE DEFAULT)',ispriv)) THEN 
                                         if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passigual,value,'password not like username (from PROFILE DEFAULT)',ispriv)) THEN 
                                             dbms_output.put_line ('OK:  USER: '|| rpad(uuu.username,20,' ') || ' PROFILE: "'|| uuu.PROFILE || '" ,PASSWORD_VERIFY_FUNCTION: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
                                         END IF;
                                    END IF;
                                END IF;
                          END IF; 
                     ELSE
                          isdefault:=1;
                          if ( CheckPVF(uuu.USERNAME,uuu.PROFILE, value, isdefault, passlong,ispriv)) THEN
                               if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passalpha,value,'1 caracter numerico (from PROFILE DEFAULT)',ispriv)) THEN 
                                    if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passnum,value,'1 caracter alfabetico (from PROFILE DEFAULT)',ispriv)) THEN 
                                         if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passigual,value,'password not like username (from PROFILE DEFAULT)',ispriv)) THEN 
                                             dbms_output.put_line ('OK:  USER: ' || rpad(uuu.username,20,' ') || ' PROFILE: "'|| uuu.PROFILE || '" ,PASSWORD_VERIFY_FUNCTION: "' || ProfileParameter.LIMIT || '" (from PROFILE DEFAULT = ' || valordefault ||')');
                                         END IF;
                                    END IF; 
                               END IF;
                          END IF;
                     END IF;
               END IF;   -- if default not null 
            ELSE -- if not default not null
               value:=ProfileParameter.LIMIT;
               ispriv:=user_privi(uuu.username);
               IF ispriv THEN       -- es un usuario privilegiado
                      passlong := '0987654321abc';       -- asigna password larga para perfil generic  (que pide 14)
                      passalpha := 'abcdefghijklmn';       -- asigna password alfabeticos perfil generic (falta 1 numerico)
                      passnum := '12345678901234';             -- asigna password numerico perfil generic (falta 1 alfabetico) 
                      passigual := 'g2gpru';             -- asigna password = username
               ELSE
                      passlong := 'abCa1ai';             -- asigna password corta para perfil personal  (que pide 8)
                      passalpha := 'abCaiaix';             -- asigna password alfabeticos perfil personal (falta 1 numerico) 
                      passnum := '12345678';             -- asigna password numerico perfil personal (falta 1 alfabetico) 
                      passigual := 'g2gpru';             -- asigna password = username
               END IF;
               IF ( existe_g2gpru ) THEN
                      if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passlong,value,'longitud password',ispriv)) THEN
                           if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passalpha,value,'1 caracter numerico',ispriv)) THEN 
                                if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passnum,value,'1 caracter alfabetico',ispriv)) THEN 
                                     if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passigual,value,'password like username',ispriv)) THEN 
                                          dbms_output.put_line ('OK:  USER: ' || rpad(uuu.username,20,' ') ||' PROFILE: "'|| uuu.PROFILE || '" ,PASSWORD_VERIFY_FUNCTION: "' || ProfileParameter.LIMIT || '"' );
                                     END IF;
                                END IF;
                           END IF;
                       END IF;
               ELSE 
                     isdefault:=0;
                     if ( CheckPVF(uuu.USERNAME,uuu.PROFILE,value,isdefault,passlong,ispriv)) THEN 
                          if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passalpha,value,'1 caracter numerico',ispriv)) THEN  
                               if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passnum,value,'1 caracter alfabetico',ispriv)) THEN 
                                    if ( CheckPVF_alphanum(uuu.USERNAME,uuu.PROFILE,passigual,value,'password like username',ispriv)) THEN 
                                          dbms_output.put_line ('OK:  USER: ' || rpad(uuu.username,20,' ') || ' PROFILE: "'|| uuu.PROFILE || '" ,PASSWORD_VERIFY_FUNCTION: "' || ProfileParameter.LIMIT || '"' );
                                    END IF;
                               END IF;
                          END IF;
                     END IF;
               END IF;
            END IF; 
         END IF;
         IF existe_g2gpru THEN
              execute immediate 'drop user g2gpru';
         END IF;
    End Loop;
End Loop ;  

End;

/
spool off 
quit

EOF
#####################################################################################################
#####   query que obtiene los usuarios que se crearon con opcion 
cat <<EOF > $DIR/userexternal.sql

connect /as sysdba

set pagesize 0
set feedback off
set verify off
set colsep ";"

spool /tmp/userexternal

select username, authentication_type from dba_users
where authentication_type like '%EXTERNAL%' or username like '&1%';

spool off

quit
EOF


######################################################################################################
####   Query que obtiene todos los roles, users que posean el rol: DELETE_CATALOG_ROLE
 
cat <<EOF > $DIR/users_delete_catalog_role.sql

connect /as sysdba
set pagesize 0
set feedback off
set verify off

spool /tmp/users_delete_catalog_role
select 
   case when (grantee in (select role from dba_roles where role = 'DBA')) then 'OK:  ROL: ' || grantee
        when (grantee in (select role from dba_roles where role <> 'DBA')) then 'NOK: ROL: ' || grantee
        when (grantee in (select username from dba_users where username = 'SYS' )) then 'OK:  USER: ' || grantee
        when (grantee in (select username from dba_users where username <> 'SYS' or username <> 'SYSTEM')) then 'NOK: USER: ' || grantee
   end, 
   granted_role 
from dba_role_privs 
where granted_role = upper('DELETE_CATALOG_ROLE');

spool off

quit
EOF

####################################################################################################3
cat <<EOF > $DIR/orausers.sql

connect /as sysdba

set pagesize 0
set feedback off 

select distinct username from dba_users where  username not in ('SYS', 'SYSTEM', 'WMSYS', 'SYSMAN','MDSYS','ORDSYS','ORDDATA','XDB', 'WKSYS', 'EXFSYS', 'OLAPSYS', 'DBSNMP', 'DMSYS','CTXSYS','WK_TEST', 'ORDPLUGINS', 'OUTLN', 'APEX_030200', 'ANONYMOUS','DIP','MDDATA','OWBSYS', 'APEX_PUBLIC_USER','APPQOSSYS','FLOWS_FILES','HP_DBSPI','MGMT_VIEW','ORACLE_OCM','OWBSYS_AUDIT','SPATIAL_CSW_ADMIN_USR', 'SPATIAL_WFS_ADMIN_USR', 'MWADM','TIVADMDB','RMAN','WKPROXY','WKADMIN','OAS_PUBLIC','WEBSYS','TRACESVR','SI_INFORMTN_SCHEMA','AURORA$ORB$UNAUTHENTICATED', 'AURORA$JIS$UTILITY','LBACSYS','TSMSYS','OWBSYS_AUDIT','AWR_STAGE','TIVADMDB','RMAN');

quit

EOF

###select distinct username from dba_users where  username not in ('SYS', 'SYSTEM', 'WMSYS', 'SYSMAN','MDSYS','ORDSYS','ORDDATA','XDB', 'WKSYS', 'EXFSYS', 'OLAPSYS', 'DBSNMP', 'DMSYS','CTXSYS','WK_TEST', 'ORDPLUGINS', 'OUTLN', 'APEX_030200', 'ANONYMOUS','DIP','MDDATA','OWBSYS', 'APEX_PUBLIC_USER','APPQOSSYS','FLOWS_FILES','HP_DBSPI','MGMT_VIEW','ORACLE_OCM','OWBSYS_AUDIT','SPATIAL_CSW_ADMIN_USR', 'SPATIAL_WFS_ADMIN_USR', 'MWADM','TIVADMDB','RMAN','WKPROXY','WKADMIN','OAS_PUBLIC','WEBSYS','TRACESVR','SI_INFORMTN_SCHEMA','AURORA$ORB$UNAUTHENTICATED', 'AURORA$JIS$UTILITY','LBACSYS','TSMSYS','OWBSYS_AUDIT','AWR_STAGE','TIVADMDB','RMAN');
##########################################################################################
###  y no queremos los roles DBA, CONNECT, RESOURCE porque ya los miramos en otras techspecs

cat << EOF > $DIR/OraPRIVIsec.sql

connect /as sysdba


set linesize 132
set pages 0
set verify off 
set feedback off 
set termout off 

spool /tmp/userauth.txt

select
  case when (granted_role in (select role from dba_roles) and grantee in (select role from dba_roles)) then level || lpad(' ',2*level) || 'SUB-ROL: ' || granted_role 
       when (granted_role in (select role from dba_roles) and grantee not in (select role from dba_roles)) then level || lpad(' ',2*level) || 'ROL: ' || granted_role
       when (grantee is null ) then level || '  ' || 'USER: ' || granted_role
  else level || lpad(' ', 2*level) || 'PRIVILEGIO: ' || granted_role  
  end
from
  (
  /* THE USERS */
    select 
      null     grantee, 
      username granted_role
    from 
      dba_users
    where
        username like upper('&1')
--      username not in ('SYS', 'SYSTEM', 'WMSYS', 'SYSMAN','MDSYS','ORDSYS','ORDDATA','XDB', 'WKSYS', 'EXFSYS', 
--         'OLAPSYS', 'DBSNMP', 'DMSYS','CTXSYS','WK_TEST', 'ORDPLUGINS', 'OUTLN', 'APEX_030200', 'ANONYMOUS','DIP','MDDATA','OWBSYS',
--         'APEX_PUBLIC_USER','APPQOSSYS','FLOWS_FILES','HP_DBSPI','MGMT_VIEW','ORACLE_OCM','OWBSYS_AUDIT','SPATIAL_CSW_ADMIN_USR','LBACSYS',
--         'SPATIAL_WFS_ADMIN_USR','XS$NULL','MWADM','TIVADMDB','RMAN','WKPROXY','WKADMIN','OAS_PUBLIC','WEBSYS','TRACESVR','SI_INFORMTN_SCHEMA',
---        'AURORA$ORB$UNAUTHENTICATED', 'AURORA$JIS$UTILITY','TSMSYS','OWBSYS_AUDIT','AWR_STAGE','TIVADMDB','RMAN')
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select 
      grantee ,
      granted_role 
    from
      dba_role_privs
--      where granted_role not in ('CONNECT','RESOURCE','DBA','IMP_FULL_DATABASE','EXECUTE_CATALOG_ROLE','DELETE_CATALOG_ROLE')
      where granted_role not in ('CONNECT','RESOURCE') and grantee not in ('DBA','IMP_FULL_DATABASE','EXECUTE_CATALOG_ROLE','DELETE_CATALOG_ROLE')
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select
      grantee,
      privilege 
    from
      dba_sys_privs
    where privilege in ('ALTER DATABASE','ALTER PROFILE','ALTER SYSTEM','ALTER TABLESPACE','ALTER USER','AUDIT ANY','AUDIT SYSTEM','CREATE ANY JOB','CREATE PROFILE','CREATE ROLLBACK SEGMENT','CREATE TABLESPACE','CREATE USER','DROP RPOFILE','DROP ROLLBACK SEGMENT','DROP TABLESPACE','DROP USER','GRANT ANY OBJECT PRIVILEGE','GRANT ANY PRIVILEGE','GRANT ANY ROLE','MANAGE TABLESPACE','RESTRICTED SESSION') and grantee is not null and grantee not in ('CONNECT','RESOURCE','DBA','IMP_FULL_DATABASE','EXECUTE_CATALOG_ROLE','DELETE_CATALOG_ROLE') 
 )
start with grantee is null
connect by grantee = prior granted_role;

spool off 
quit

EOF

##########################################################################################

cat <<EOF > $DIR/Orasystempriv.sql

connect /as sysdba


spool $DIR/${uHOSTNAME}_OracleISEC2013.log APP

set linesize 132
set serveroutput on 
set feedback off

-- Inicio bloque principal

Declare 
        estad   varchar(3);

Begin

        estad := 'OK' ;
	dbms_output.put_line (chr(10) || 'USUARIOS con privilegios SYSDBA y SYSOPER  '||chr(10)||'----------------------------------------');
	dbms_output.put_line ('USUARIO               SYSDBA   SYSOPER    ESTADO'||chr(10)||'-------------------------------------------------');
        for user in (select USERNAME, SYSDBA , SYSOPER  from v\$pwfile_users order by USERNAME) 
        Loop
		Case user.USERNAME  
				WHEN 'SYS' THEN 
	    dbms_output.put_line ( rpad(user.USERNAME,20,' ') || chr(9) || rpad(user.SYSDBA,7,' ') || chr(9) || rpad(user.SYSOPER,7,' ')|| '    OK ');
                                ELSE
	    dbms_output.put_line ( rpad(user.USERNAME,20,' ') || chr(9) || rpad(user.SYSDBA,7,' ') || chr(9) || rpad(user.SYSOPER,7,' ')|| '    NOK ');
                End Case;

        End Loop;

	 dbms_output.put_line (chr(10) || 'PRIVILEGIOS/ROLES with ADMIN OPTION=YES '||chr(10)||'----------------------------------------');
        for useradmin in (select GRANTEE, PRIVILEGE, ADMIN_OPTION from dba_sys_privs where GRANTEE not in  ('SYS', 'SYSTEM', 'DBA','WMSYS', 'SYSMAN','MDSYS','ORDSYS','ORDDATA','XDB', 'WKSYS', 'EXFSYS', 'OLAPSYS', 'DBSNMP', 'DMSYS','CTXSYS','WK_TEST', 'APEX_030200','ORDPLUGINS', 'OUTLN', 'ANONYMOUS','DIP','MDDATA','OWBSYS', 'APEX_PUBLIC_USER','APPQOSSYS','FLOWS_FILES','HP_DBSPI','MGMT_VIEW','ORACLE_OCM','OWBSYS_AUDIT','SPATIAL_CSW_ADMIN_USR', 'SPATIAL_WFS_ADMIN_USR', 'MWADM','TIVADMDB','RMAN','WKPROXY','WKADMIN','OAS_PUBLIC','WEBSYS','TRACESVR','AQ_ADMINISTRATOR_ROLE','PERFSTAT','SCHEDULER_ADMIN','SI_INFORMTN_SCHEMA','AURORA$ORB$UNAUTHENTICATED', 'AURORA$JIS$UTILITY','LBACSYS','TSMSYS','OWBSYS_AUDIT','AWR_STAGE') and ADMIN_OPTION = 'YES' )
        Loop 
	    dbms_output.put_line (rpad(useradmin.GRANTEE,30,' ') || chr(9) || rpad(useradmin.PRIVILEGE,40,' ') || chr(9) || ' NOK ');
            estad := 'NOK';
        End Loop;
        IF estad = 'OK' THEN
--        dbms_output.put_line('PRIVILEGIOS/ROLES EXCLUIDOS:  ' || chr(10) || 'SYS, SYSTEM, DBA, WMSYS, SYSMAN, MDSYS, ORDSYS, ORDDATA, XDB, WKSYS, EXFSYS, OLAPSYS, DBSNMP, DMSYS,CTXSYS, WK_TEST, APEX_030200, ORDPLUGINS, OUTLN, ANONYMOUS, DIP, MDDATA, OWBSYS, APEX_PUBLIC_USER, APPQOSSYS, FLOWS_FILES, HP_DBSPI, MGMT_VIEW, ORACLE_OCM, OWBSYS_AUDIT, SPATIAL_CSW_ADMIN_USR, SPATIAL_WFS_ADMIN_USR, MWADM, TIVADMDB, RMAN, WKPROXY, WKADMIN, OAS_PUBLIC, WEBSYS, TRACESVR, SCHEDULER_ADMIN, AQ_ADMINISTRATOR_ROLE, PERFSTAT','SI_INFORMTN_SCHEMA','AURORA$ORB$UNAUTHENTICATED', 'AURORA$JIS$UTILITY','LBACSYS'); 
	     dbms_output.put_line (chr(10) || 'NO existen PRIVILEGIOS/ROLES (Not internal Oracle) with ADMIN OPTION=YES ===>  OK');
        END IF;
    
End;
/
quit

EOF

###################################################################################
###       CONSULTA SQL de PACKAGES/VIEW ALL USERS y privilegio EXECUTE from PUBLIC
###################################################################################
cat <<EOF > $DIR/public.sql

connect / as sysdba

set serveroutput on
set lines 132 
set feedback off

column grantee format a15
column tablename format a30
column privilege format a15  

Declare 

instancia varchar(20);

Begin

select sys_context('USERENV','INSTANCE_NAME') into instancia from dual;

dbms_output.put_line('--- Instancia: ' || instancia || ' --- PACKAGES/VIEW Revoke execute from PUBLIC' || CHR(10));

For cadaobjeto in ( SELECT grantee, table_name as tablename , privilege , object_type FROM all_tab_privs   JOIN all_objects  ON (table_name = object_name) WHERE (object_type = 'PACKAGE' and ( object_name = 'DBMS_SQL' or object_name = 'DBMS_LOB' or object_name = 'DBMS_XMLGEN' or object_name = 'DBMS_JOB' or object_name = 'DBMS_SCHEDULER' or object_name = 'UTL_TCP' or object_name = 'UTL_HTTP' or object_name = 'UTL_FILE' or object_name = 'UTL_SMTP' ) AND privilege = 'EXECUTE' AND grantee = 'PUBLIC')  or ( object_type = 'VIEW' and object_name = 'ALL_USERS' AND grantee = 'PUBLIC' and privilege = 'EXECUTE' ))
Loop
  IF  cadaobjeto.object_type LIKE '%PACKAGE%' THEN 
    dbms_output.put_line(rpad('PACKAGE',10,' ') || rpad(cadaobjeto.tablename,15,' ') || 'has privilege ' || rpad(cadaobjeto.privilege,10,' ') || 'from grantee  ' || cadaobjeto.grantee );
  else
    dbms_output.put_line(rpad('VIEW',10,' ') || rpad(cadaobjeto.tablename,15,' ') || 'has privilege ' || rpad(cadaobjeto.privilege,10,' ') || 'from grantee  ' || cadaobjeto.grantee );
  END IF;
End Loop; 
End ;
/

set term off
spool /tmp/cambios_isec_oracle_revoke.sql


Begin

dbms_output.put_line('SENTENCIAS ORACLE PARA CORREGIR (valorar individualmente su ejecucion):  ' || CHR(10));

For cadaobjeto in ( SELECT grantee, table_name as tablename , privilege , object_type FROM all_tab_privs   JOIN all_objects  ON (table_name = object_name) WHERE (object_type = 'PACKAGE' and ( object_name = 'DBMS_SQL' or object_name = 'DBMS_LOB' or object_name = 'DBMS_XMLGEN' or object_name = 'DBMS_JOB' or object_name = 'DBMS_SCHEDULER' or object_name = 'UTL_TCP' or object_name = 'UTL_HTTP' or object_name = 'UTL_FILE' or object_name = 'UTL_SMTP' ) AND privilege = 'EXECUTE' AND grantee = 'PUBLIC')  or ( object_type = 'VIEW' and object_name = 'ALL_USERS' AND grantee = 'PUBLIC' and privilege = 'EXECUTE' ))
Loop
  dbms_output.put_line('REVOKE EXECUTE ON ' || cadaobjeto.tablename || ' FROM PUBLIC;');
End Loop; 
End;
/
spool off
exit 

EOF


###       CONSULTA SQL de PACKAGES with OWNER=CTXSYS  y cualquier privilegio (ALL_ACCESS) from PUBLIC
###################################################################################
cat <<EOF > $DIR/ctxsys_priv.sql

connect / as sysdba

set serveroutput on
set lines 132 
set feedback off

Declare 

instancia varchar(20);
priv varchar(15);
tablename varchar(30);
gran varchar(15);

Begin

select sys_context('USERENV','INSTANCE_NAME') into instancia from dual;

dbms_output.put_line('AG.1.7.14.2  --- Instancia: ' || instancia || ' --- Revoke All Access to CTXSYS PACKAGES from PUBLIC' || CHR(10));
dbms_output.put_line('Nota informativa: if you revoke execute privileges of CTXSYS packages from PUBLIC you will break the Oracle Text feature');
dbms_output.put_line('                  check carefully if you have any Text indexes' || CHR(10));

For cadaobjeto in ( SELECT grantee, table_name , privilege , object_type FROM all_tab_privs   JOIN all_objects  ON (table_name = object_name) WHERE (object_type = 'PACKAGE'  AND grantee = 'PUBLIC' and owner = 'CTXSYS' ))
Loop
    tablename := cadaobjeto.table_name;
    priv := cadaobjeto.privilege;
    gran := cadaobjeto.grantee;
    dbms_output.put_line(rpad('CTXSYS PACKAGE',18,' ') || rpad(tablename,30,' ') || 'has privilege ' || rpad(priv,15,' ') || 'from grantee  ' || rpad(gran,15,' ') );
End Loop; 
End ;
/

set term off 

spool /tmp/cambios_ctxsys_revoke.sql

Declare 
priv varchar(15);

Begin

dbms_output.put_line('SENTENCIAS ORACLE PARA CORREGIR (valorar individualmente su ejecucion):  ' || CHR(10));

For cadaobjeto in ( SELECT grantee, table_name as tablename , privilege , object_type FROM all_tab_privs   JOIN all_objects  ON (table_name = object_name) WHERE (object_type = 'PACKAGE' AND grantee = 'PUBLIC' and owner = 'CTXSYS' ))
Loop
  priv := cadaobjeto.privilege;
  dbms_output.put_line('REVOKE ' || priv || ' ON CTXSYS.' || cadaobjeto.tablename || ' FROM PUBLIC;');
End Loop; 
End;
/
spool off
exit 

EOF




#*******************************************************************************
#####       CONSULTA SQL de valores de AUDITORIA
################################################################################
cat <<EOF > $DIR/auditoria_oracle.sql

connect /as sysdba

set serverout on
set lines 132 
set head off
set term off 
set feedback off

spool /tmp/isec_oracle_audit
 
Declare 
     techspech varchar(10);
     EstadoAudit varchar(20);
     destino varchar(60);

Begin

 -- Estado parametros Auditoria
        For AuditParameter in
                (Select NAME, VALUE from v\$parameter where NAME IN ('audit_trail', 'sec_protocol_error_trace_action', 'audit_sys_operations'  ))
                Loop
                destino := ' ';
                Case AuditParameter.NAME
                                WHEN 'audit_trail' THEN
                                        techspech := 'AG.1.2.1';
                                        IF AuditParameter.VALUE <> 'OS' and AuditParameter.VALUE <> 'DB' and AuditParameter.VALUE <> 'DB_EXTENDED' THEN
                                                EstadoAudit :=  'NOK';
                                        ELSE
                                                select value into destino from v\$parameter where name like  'audit_file_dest';
                                                EstadoAudit :=  'ok';
                                        END IF;
                                WHEN 'sec_protocol_error_trace_action' THEN
                                        techspech := 'AG.1.2.3';
                                        IF AuditParameter.VALUE <> 'LOG' THEN
                                                EstadoAudit := 'NOK';
                                        ELSE
                                                EstadoAudit := 'ok';
                                        END IF;
                                WHEN 'audit_sys_operations' THEN
                                        techspech := 'AG.1.2.4';
                                        IF AuditParameter.VALUE <> 'TRUE' THEN
                                                EstadoAudit := 'NOK';
                                        ELSE
                                                EstadoAudit := 'ok';
                                        END IF;
                                ELSE EstadoAudit := ' ';
                End case;
                        dbms_output.put_line ( techspech || ' | ' ||  AuditParameter.NAME || ' | ' || AuditParameter.VALUE || ' | ' || EstadoAudit || ' | ' || rtrim(destino));

                End loop;
End;
/
spool off 
exit
EOF

###*******************************************************************************
###  AUDIT ALL :  se queda fuera de G2G - 13/02/2014
###
###  cat <<EOF > $DIR/audit-stmt-priv.sql
###  connect /as sysdba
###  
###  set pages 0
###  set head off
###  set feedback off
###  set colsep ";"
###  
###  spool /tmp/audit-stmt-priv
###  
###  column username     format a15
###  column audit_option format a30
###  column privilege    format a30
###  column success      format a10
###  column failure      format a10
###  
###  select 
###     user_name, 
###     audit_option, 
###     success, 
###     failure
###  from 
###     dba_stmt_audit_opts
###  union
###  select 
###     user_name, 
###     privilege, 
###     success, 
###     failure
###  from 
###     dba_priv_audit_opts;
###  
###  spool off
###  exit
###  
###  EOF
#########################################################################################

####*************************************************************************************
#####      CONSULTA de parametros en la BD
#########################################################################################
cat <<EOF  > $DIR/parameters.sql
connect /as sysdba

set lines 132 
set head off
set term off
set feedback off

spool /tmp/show_parameter_oracle
show parameter O7_DICTIONARY_ACCESSIBILITY;
show parameter REMOTE_OS_AUTHENT;
show parameter SEC_MAX_FAILED_LOGIN_ATTEMPTS;
show parameter SEC_RETURN_SERVER_RELEASE_BANNER;
show parameter REMOTE_OS_ROLES;
show parameter DB_NAME;
show parameter UTL_FILE_DIR;
show parameter OS_AUTHENT_PREFIX;
spool off 
exit

EOF

############################################################################################

######         CONSULTA DE Datafile, Redolog, Tempfiles, Controlfiles  de BD 
###############################################################################################
cat <<EOF > $DIR/database.sql

connect / as sysdba

set serverout on
set lines 152 
set term off
set feedback off

column member format a100
column file_name  format a100
column name format a100

spool /tmp/oracle_datafiles 
Declare 

instancia varchar(20);
temp      varchar(20);

Begin

select sys_context('USERENV','INSTANCE_NAME') into instancia from dual;

select property_value into temp from database_properties where property_name = 'DEFAULT_TEMP_TABLESPACE';

-- dbms_output.put_line('AG.1.8.1  --- Instancia: ' || instancia || ' --- DATABASE Datafiles/TEMPfiles/LogFiles/ControlFiles ' || CHR(10));

For tablespace in (select TABLESPACE_NAME from DBA_TABLESPACES)
Loop
    For file in ( SELECT file_name FROM dba_data_files WHERE tablespace_name like tablespace.tablespace_name )
    Loop
        dbms_output.put_line('instancia: ' ||instancia || ';TABLESPACE: ' || rpad(tablespace.tablespace_name,30,' ') || ';DATA_FILE_NAME;' || rpad(file.file_name,100,' ') );
    End Loop; 

  if tablespace.tablespace_name = temp THEN
    For file in ( SELECT file_name FROM dba_temp_files WHERE tablespace_name like tablespace.tablespace_name )
    Loop
        dbms_output.put_line('instancia: ' ||instancia || ';TABLESPACE: ' || rpad(tablespace.tablespace_name,30,' ') || ';TEMP_FILE_NAME;' || rpad(file.file_name,100,' '));
    End Loop; 
  End If;
End Loop;

For logmembers in (select member from  v\$logfile)
Loop
    dbms_output.put_line('instancia: ' || instancia || ';LOGFILE:                                  ' || ';REDO_FILE_NAME;' || rpad(logmembers.member,100,' '));
End Loop; 

For controlfile in (SELECT name from v\$controlfile)
Loop
    dbms_output.put_line('instancia: ' || instancia || ';CONTROLFILE:                              ' || ';CTRL_FILE_NAME;' ||rpad(controlfile.name,100,' '));

End Loop;
   
End ;
/
spool off
exit 

EOF

###############################################################################

#####          CONSULTA de Archive Log status/directorio destino de files
###############################################################################
cat <<EOF > $DIR/archivelog.sql
connect / as sysdba

set serverout on
set term off
set feedback off

spool /tmp/oracle_archivelogfiles 

archive log list

spool off
exit

EOF

################################################################################333

######        CONSULTA del directorio repositorio del alert_SID.log
#################################################################################

cat <<EOF > $DIR/background_dest.sql
connect /as sysdba

set serverout on
set lines 152
set term off
set head off
set feedback off

column value format a120
column name format a30

spool /tmp/oracle_background_dest
select name, value from v\$parameter where name = 'background_dump_dest';
spool off
exit

EOF

################################################################################

cat <<EOF > $DIR/passdefault.sql
connect /as sysdba

set term off
set head off
set colsep ";"
set feedback off

spool /tmp/passdefault

select rtrim(d.username,' '), u.account_status  from dba_users_with_defpwd d, dba_users u where d.username in ('SYS', 'SYSTEM') and d.username = u.username; 

spool off
exit

EOF

################################################################################

cat <<EOF > $DIR/passdefault_product_service.sql
connect /as sysdba

set term off 
set head off
set colsep ";"
set line 120
set feedback off

column username format a25
column account_status a20
spool /tmp/passdefault_product_service

SELECT  rtrim(d.username,' '), u.account_status  FROM dba_users_with_defpwd d, dba_users u
where d.username not in ('SYS' , 'SYSTEM' )  and d.username = u.username 
order by 2,1; 

spool off
exit

EOF

################################################################################

cat <<EOF > $DIR/oracledemousers.sql
connect /as sysdba

set term off 
set head off
set colsep ";"
set feedback off

spool /tmp/oracledemousers

SELECT  rtrim(username,' '), account_status  FROM dba_users
where username  in ('SCOTT','ADAMS','JONES','CLARK','BLAKE','HR','OE','SH');

spool off
exit

EOF

################################################################################

cat <<EOF > $DIR/dbsnmpuser.sql
connect /as sysdba

set term off 
set head off
set colsep ";"
set feedback off

spool /tmp/dbsnmpuser

SELECT  rtrim(username,' '), account_status  FROM dba_users
where username like '%DBSNMP%';

spool off
exit

EOF

################################################################################

cat <<EOF > $DIR/ctxsysuser.sql
connect /as sysdba

set term off 
set head off
set feedback off

spool /tmp/ctxsysuser

SELECT  username, account_status  FROM dba_users
where username like 'CTXSYS';

spool off
exit

EOF

################################################################################
#
#          consulta sobre usuarios generales que solo pueden tener roles/provilegios 'CONNECT' 'RESOURCE'
#          (Excepcionados: usuarios DBAs 
#                          usuarios de Servicios Oracle o productos 
#                          usuarios con status  LOCKED 
#                          usuario de SEGUR OPS$ISYSAD1 )
################################################################################

cat <<EOF > $DIR/privgeneral.sql
connect /as sysdba

set term off
set line 100
set head off
set colsep ";"
set serverout on
set feedback off 

column username format a20
column granted_role format a30
column grantee format a20
column privilege format a30

spool /tmp/privgeneral

DECLARE 

    ispriv boolean;
    campo  varchar(10);
    instancia varchar(10);
    privil varchar(30);

-- si el usuario que entra, tiene alguno de los privilegios significa que es un usuario privilegiado, por lo que devuelve TRUE, si no, devuelve FALSE
FUNCTION user_privi(usuario varchar2) RETURN BOOLEAN
IS

BEGIN
For user1 in (select granted_role from
  (
  /* THE USERS */
    select 
      null     grantee, 
      username granted_role
    from 
      dba_users
    where
      username like upper(usuario)
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select 
      grantee,
      granted_role
    from
      dba_role_privs
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select
      grantee,
      privilege
    from
      dba_sys_privs
  )
start with grantee is null
connect by grantee = prior granted_role)

Loop
     if user1.granted_role in ('ALTER DATABASE','ALTER PROFILE','ALTER SYSTEM','ALTER TABLESPACE','ALTER USER','AUDIT ANY','AUDIT SYSTEM','CREATE ANY JOB','CREATE PROFILE','CREATE ROLLBACK SEGMENT','CREATE TABLESPACE','CREATE USER','DROP RPOFILE','DROP ROLLBACK SEGMENT','DROP TABLESPACE','DROP USER','GRANT ANY OBJECT PRIVILEGE','GRANT ANY PRIVILEGE','GRANT ANY ROLE','MANAGE TABLESPACE','RESTRICTED SESSION','DBA','IMP_FULL_DATABASE','EXECUTE_CATALOG_ROLE','DELETE_CATALOG_ROLE') THEN
       RETURN TRUE;   -- si tiene alguno de esos privilegios, entonces es privilegiado
     END IF;
End Loop;      -- si termina el loop sin ninguno de esos privilegios, entonces no es un usuario privilegiado
RETURN FALSE;
END user_privi;


BEGIN

select  value into instancia from v\$parameter where name = 'instance_name';

For cadauser in (select username from dba_users where username not in ('OUTLN','APPQOSSYS','DBSNMP','MDDATA','OLAPSYS','ORACLE_OCM','SQLTXADMIN','SI_INFORMTN_SCHEMA','XDB','SYSMAN','CTXSYS','ORDDATA','EXFSYS','ORDSYS','MDSYS','FLOWS_FILES','MGMT_VIEW','OWBSYS_AUDIT')) 
Loop
     ispriv := user_privi(cadauser.username);
     IF not ispriv THEN
        For cadapriv in (select null, granted_role, campo   from
  (
  /* THE USERS */
    select 
      null     grantee, 
      username granted_role,
      'username' campo 
    from 
      dba_users
    where
      username like upper(cadauser.username)
  /* THE ROLES TO ROLES RELATIONS */ 
  union
    select 
      grantee,
      granted_role,
      'rol' campo 
    from
      dba_role_privs
    where granted_role not in ('CONNECT','RESOURCE')
  /* THE ROLES TO PRIVILEGE RELATIONS */ 
  union
    select
      grantee,
      privilege,
      'privilege' campo 
    from
      dba_sys_privs  where privilege not in (select privilege from dba_sys_privs where grantee in ('CONNECT','RESOURCE') )
  )
start with grantee is null
connect by grantee = prior granted_role)

       Loop
          IF cadauser.username <> cadapriv.granted_role THEN
                dbms_output.put_line(cadauser.username || ';' || cadapriv.granted_role || ';' || cadapriv.campo );
          END IF;
       End Loop;
     END IF;
End Loop;

END;
/
spool off
exit

EOF
#########################################################
#### BEGIN

#### select  value into instancia from v\$parameter where name = 'instance_name';

#### For cadauser in (select username from dba_users) 
#### Loop
####      ispriv := user_privi(cadauser.username);
####      IF not ispriv THEN
####         For cadapriv in (
#### select  grantee, granted_role, 'role' campo 
#### from
####         dba_role_privs a
####         left outer join dba_users p on (a.grantee = cadauser.username)
#### where
####         (a.granted_role <> 'CONNECT' AND a.granted_role <> 'RESOURCE')
####         and (upper(a.grantee) <> 'ANONYMOUS' 
####              AND upper(a.grantee) <> 'XDB' 
####              AND upper(a.grantee) <> 'WKPROXY' 
####              AND upper(a.grantee) <> 'WKADMIN' 
####              AND upper(a.grantee) <> 'OAS_PUBLIC' 
####              AND upper(a.grantee) <> 'WEBSYS' 
####              AND upper(a.grantee) <> 'TRACESVR' 
####              AND upper(a.grantee) <> 'AURORA\$ORB\$UNAUTHENTICATED' 
####              AND upper(a.grantee) <> 'AURORA\$JIS\$UTILITY' 
####              AND upper(a.grantee) <> 'WKSYS' 
####              AND upper(a.grantee) <> 'MWADM' 
####              AND upper(a.grantee) <> 'TIVADMDB' 
####              AND upper(a.grantee) <> 'SYSMAN' 
####              AND upper(a.grantee) <> 'MGMT_VIEW' 
####              AND upper(a.grantee) <> 'OUTLN' 
####              AND upper(a.grantee) <> 'DBSNMP' 
####              AND upper(a.grantee) <> 'PERFSTAT' 
####              AND upper(a.grantee) <> 'MDSYS' 
####              AND upper(a.grantee) <> 'CTXSYS' 
####              AND upper(a.grantee) <> 'ORDPLUGINS' 
####              AND upper(a.grantee) <> 'ORDSYS' 
####              AND upper(a.grantee) <> 'EXFSYS' 
####              AND upper(a.grantee) <> 'DIP' 
####              AND upper(a.grantee) <> 'SYS' 
####              AND upper(a.grantee) <> 'SYSTEM' 
####              AND upper(a.grantee) <> 'WMSYS' 
####              AND upper(a.grantee) <> 'RMAN' 
####              AND upper(a.grantee) <> 'DBA')
####              and upper(a.grantee)  NOT IN (SELECT upper(x.value)|| 'ISYSAD1' from v\$parameter x where upper(x.name) = 'OS_AUTHENT_PREFIX')
####              and p.account_status not like '%LOCKED%'
#### union
#### 
#### select  a.grantee, a.privilege, 'privilege' campo 
#### from
####         dba_sys_privs a 
####         left outer join dba_users p on ( a.grantee = p.username )
#### where
####         a.privilege  NOT IN (SELECT x.privilege from dba_sys_privs x where (x.grantee = 'CONNECT' OR x.grantee = 'RESOURCE') )
####         AND a.grantee NOT IN (SELECT x.role from dba_roles x where a.grantee = 'DBA')
####         and (upper(a.grantee) <> 'ANONYMOUS' 
####         AND upper(a.grantee) <> 'XDB' 
####         AND upper(a.grantee) <> 'WKPROXY' 
####         AND upper(a.grantee) <> 'WKADMIN' 
####         AND upper(a.grantee) <> 'OAS_PUBLIC' 
####         AND upper(a.grantee) <> 'WEBSYS' 
####         AND upper(a.grantee) <> 'TRACESVR' 
####         AND upper(a.grantee) <> 'AURORA\$ORB\$UNAUTHENTICATED' 
####         AND upper(a.grantee) <> 'AURORA\$JIS\$UTILITY' 
####         AND upper(a.grantee) <> 'WKSYS' 
####         AND upper(a.grantee) <> 'MWADM' 
####         AND upper(a.grantee) <> 'TIVADMDB' 
####         AND upper(a.grantee) <> 'SYSMAN' 
####         AND upper(a.grantee) <> 'MGMT_VIEW' 
####         AND upper(a.grantee) <> 'OUTLN' 
####         AND upper(a.grantee) <> 'DBSNMP' 
####         AND upper(a.grantee) <> 'PERFSTAT' 
####         AND upper(a.grantee) <> 'MDSYS' 
####         AND upper(a.grantee) <> 'CTXSYS' 
####         AND upper(a.grantee) <> 'ORDPLUGINS' 
####         AND upper(a.grantee) <> 'ORDSYS' 
####         AND upper(a.grantee) <> 'EXFSYS' 
####         AND upper(a.grantee) <> 'DIP' 
####         AND upper(a.grantee) <> 'SYS' 
####         AND upper(a.grantee) <> 'SYSTEM' 
####         AND upper(a.grantee) <> 'WMSYS' 
####         AND upper(a.grantee) <> 'RMAN' 
####         AND upper(a.grantee) <> 'DBA')
####         and upper(a.grantee) NOT IN (SELECT upper(x.value)|| 'ISYSAD1' from v\$parameter x where upper(x.name) = 'OS_AUTHENT_PREFIX')
####         and p.account_status not like '%LOCKED%' )
####       Loop
####                 dbms_output.put_line(cadauser.username || ';' || cadapriv.granted_role || ';' || cadapriv.campo);
####       End Loop;
####      END IF;
#### End Loop;
#### 
#### END;
#### /
#### spool off
#### exit
#### --              dbms_output.put_line('instancia: ' || instancia || '; USER general: "' || cadauser.username || '" ROL:  ' || cadapriv.granted_role || ' adicional a ROL CONNECT/RESOURCE');
#### --          ELSE
#### --              IF campo = 'privilege' THEN
#### --                  dbms_output.put_line('instancia: ' || instancia || '; USER general: "' || cadauser.username || '" PRIV:  ' || cadapriv.privilege || 'adicional a PRIV de CONNECT/RESOURCE');
#### --              ELSE
#### --                  dbms_output.put_line('instancia: ' || instancia || '; USER general: "' || cadauser.username || '"  cumple ROL/PRIV CONNECT/RESOURCE');
#### --              END IF;
#### --          END IF; 
#### --        End Loop;
#### --     END IF;
#### --End Loop;
#### --
#### --END;
#### --/
#### --spool off
#### --exit

#### EOF

################################################################################
#
#          consulta sobre roles o usuarios DBAs con cualquier subrol DBA 
#          saca informeacion como esta:
#
#     USER:PROVAG2G:G2G:DBA (usuario con un rol cuyo subrol es 'DBA')
#
# no salen los usuarios 'SYS', 'SYSTEM' (DBAs por definicion) y los usuarios  de Oracle Services
################################################################################

cat <<EOF > $DIR/privdba.sql
connect /as sysdba

set line 150
set term off
set head off
set feedback off

column username format a20
column granted_role format a30
column grantee format a20

spool /tmp/privdba

select 
      case when (connect_by_root username  is null) then 'ROL'   
           else 'USER' 
      end || 
      sys_connect_by_path(grantee,':') || ':' || granted_role 
from 
 dba_role_privs
left join dba_users on (grantee = username)
where connect_by_root username not in ('SYS','SYSTEM','ANONYMOUS','XDB','WKPROXY','WKADMIN','OAS_PUBLIC','WEBSYS','TRACESVR','AURORA\$ORB\$UNAUTHENTICATED','AURORA\$JIS\$UTILITY','WKSYS','MWADM','TIVADMDB','SYSMAN','MGMT_VIEW','OUTLN','DBSNMP','PERFSTAT','MDSYS','CTXSYS','ORDPLUGINS','ORDSYS','EXFSYS','DIP','WMSYS','RMAN','OLAPSYS','SPATIAL_CSW_ADMIN_USR','SQLTXADMIN','OWBSYS','APEX_030200','MDDATA') and granted_role = 'DBA' 
connect by prior granted_role = grantee; 

spool off 
exit

EOF


######################################################################################
####### ORIGINAL - se cambia por la consulta de arriba porque esta consulta no es recursiva 
#######          consulta sobre usuarios DBAs con rol DBA 
#######                          usuarios de Servicios Oracle o productos 
#######                          usuarios con status  LOCKED 
#######                          usuario de SEGUR OPS$ISYSAD1 )
################################################################################
######
######cat <<EOF > $DIR/privdba.sql
######connect /as sysdba
######
######set line 100
######set term off
######set head off
######set colsep ";"
######column username format a20
######column granted_role format a30
######
######spool /tmp/privdba
######
######
######select  grantee, granted_role, 'with DBA role'
######from
######        dba_role_privs a
######        left outer join dba_users p on (a.grantee = p.username)
######where
######        ( a.granted_role  = 'DBA' 
######                 or 
######          a.granted_role in (select x.grantee from dba_role_privs x 
######                               left join dba_roles z on (x.grantee = z.role) 
######                             where x.granted_role = 'DBA')) 
######          and (upper(a.grantee) <> 'ANONYMOUS' 
######             AND upper(a.grantee) <> 'XDB' 
######             AND upper(a.grantee) <> 'WKPROXY' 
######             AND upper(a.grantee) <> 'WKADMIN' 
######             AND upper(a.grantee) <> 'OAS_PUBLIC' 
######             AND upper(a.grantee) <> 'WEBSYS' 
######             AND upper(a.grantee) <> 'TRACESVR' 
######             AND upper(a.grantee) <> 'AURORA\$ORB\$UNAUTHENTICATED' 
######             AND upper(a.grantee) <> 'AURORA\$JIS\$UTILITY' 
######             AND upper(a.grantee) <> 'WKSYS' 
######             AND upper(a.grantee) <> 'MWADM' 
######             AND upper(a.grantee) <> 'TIVADMDB' 
######             AND upper(a.grantee) <> 'SYSMAN' 
######             AND upper(a.grantee) <> 'MGMT_VIEW' 
######             AND upper(a.grantee) <> 'OUTLN' 
######             AND upper(a.grantee) <> 'DBSNMP' 
######             AND upper(a.grantee) <> 'PERFSTAT' 
######             AND upper(a.grantee) <> 'MDSYS' 
######             AND upper(a.grantee) <> 'CTXSYS' 
######             AND upper(a.grantee) <> 'ORDPLUGINS' 
######             AND upper(a.grantee) <> 'ORDSYS' 
######             AND upper(a.grantee) <> 'EXFSYS' 
######             AND upper(a.grantee) <> 'DIP' 
######             AND upper(a.grantee) <> 'SYS' 
######             AND upper(a.grantee) <> 'SYSTEM' 
######             AND upper(a.grantee) <> 'WMSYS' 
######             AND upper(a.grantee) <> 'RMAN') 
######             and upper(a.grantee)  NOT IN (SELECT upper(x.value)|| 'ISYSAD1' from v\$parameter x where upper(x.name) = 'OS_AUTHENT_PREFIX')
######             and p.account_status not like '%LOCKED%' ;
######
######spool off 
######exit
######
######EOF

#############################################################################################
####       consulta de los usuarios que tienen privilegio SYSDBA, SYSOPER
####
####       Se consulta la tabla   v$pwfile_users   donde aparecen los usuarios y "YES"/"NO" si tienen privilegio SYSDBA o SYSOPER
####
#############################################################################################


cat <<EOF > $DIR/privsysdbaoper.sql
connect /as sysdba

set line 60
set term off
set head off
set feed off
column username format a20

spool /tmp/privsysdbaoper

select username 
from  v\$pwfile_users
where (sysdba = 'TRUE' or sysoper = 'TRUE' ) and username not in ('SYS','SYSTEM','ANONYMOUS','XDB','WKPROXY','WKADMIN','OAS_PUBLIC','WEBSYS','TRACESVR','AURORA\$ORB\$UNAUTHENTICATED','AURORA\$JIS\$UTILITY','WKSYS','MWADM','TIVADMDB','SYSMAN','MGMT_VIEW','OUTLN','DBSNMP','PERFSTAT','MDSYS','CTXSYS','ORDPLUGINS','ORDSYS','EXFSYS','DIP','WMSYS','RMAN','OLAPSYS','SPATIAL_CSW_ADMIN_USR','SQLTXADMIN','OWBSYS','APEX_030200','MDDATA'); 

spool off 
exit

EOF

############################################################################################
####      consulta de usuarios que tienen privilegios "WITH ADMIN" yes 
####      y que no sean usuarios DBA o Oracle service accounts
####
####      consulta solo la tabla DBA_SYS_PRIVS  buscando la columna de ADMIN para los privilegios
####
############################################################################################

cat <<EOF > $DIR/privwithadmin.sql
connect /as sysdba

set line 100
set term off
set pages 0
set head off
set feed off
set colsep ";"

spool /tmp/privwithadmin

select grantee, privilege, admin_option, 'NO'
from
       dba_sys_privs
left join dba_users on (grantee = username)
where
        (username <> 'WKSYS' AND username <> 'MWADM' AND username  <> 'TIVADMDB' AND username <> 'SYSMAN' AND username <> 'MGMT_VIEW' AND username <> 'OUTLN' 
         AND username <> 'DBSNMP' AND username <> 'PERFSTAT' AND username <> 'MDSYS' AND username <> 'CTXSYS' AND username <> 'ORDPLUGINS' AND username <> 'ORDSYS' 
         AND username <> 'EXFSYS' AND username <> 'DIP' AND username <> 'SYS' AND username <> 'SYSTEM' AND username <> 'WMSYS' AND username <> 'RMAN' AND username <> 'DBA' 
         AND username <> 'ANONYMOUS' AND username <> 'XDB' AND username <> 'WKPROXY' AND username <> 'WKADMIN' AND username <> 'OAS_PUBLIC' AND username <> 'WEBSYS' 
         AND username <> 'TRACESVR' AND username <> 'AURORA\$ORB\$UNAUTHENTICATED' AND username <> 'AURORA\$JIS\$UTILITY' AND username <> 'OLAPSYS' 
         AND username <> 'SPATIAL_CSW_ADMIN_USR' AND username <> 'SQLTXADMIN' AND username <> 'OWBSYS' AND username <> 'MDDATA' AND username <> 'APEX_030200')
        and admin_option = 'YES' ;

spool off
exit

EOF

####       fin de consultas sql
#############################################################################################
###
#####            funciones para cada techspech
############################################################################################
###   *********    PASSWORD_LIFE_TIME  ************************************
ag_1_1_1_password_life_time ()
{
ins=$1
      if [ `grep -c "^NOK" $DIR/ag_1_1_1_password_life_time.log` -gt 0 ] ; then
            echo -e "$NOK: --- instancia: $ins ---  No cumple password_life_time = $PARAM111" | tee -a  $DIR/ag_1_1_1_password_life_time.log
            res=1
            fixora "AG.1.1.1" "PASSWORD_LIFE_TIME es un parametro de perfil que setea la caducidad de password, debe valer $PARAM111 dias"
            fixora "AG.1.1.1" "Si existen usuarios que incumplen, para corregirlos, debe o bien modificar el perfil donde residen o bien moverlo de perfil"
            fixora "AG.1.1.1" "Revise la consulta en ${ins}.caducidad para determinar que pasaria con los usuarios que no caducan"
            for cadaprof in `grep "^NOK:" $DIR/ag_1_1_1_password_life_time.log  | awk '{printf("%s ",$3);}'`             
            do
                    listausers=`grep "($cadaprof)" $DIR/ag_1_1_1_password_life_time.log | grep "USER" | awk '{printf("%s ",$4);}'`
                    if [ -n "$listausers" ] ; then
                        fixora "AG.1.1.1" "sql;alter profile $cadaprof PASSWORD_LIFE_TIME $PARAM111;"
                        fixora "AG.1.1.1" "o bien mueva los usuarios de profile $cadaprof a un profile compliance" 
                        fixora "AG.1.1.1" "profile=$cadaprof;usuarios=$listausers"
                    fixora "++++++++++++++++++++++++++++++++++" ""
                    fi
            done
            fixora "$LIN" ""
      else
            echo -e "$OK: --- instancia: $ins ---  password_life_time = $PARAM111  correcto" | tee -a  $DIR/ag_1_1_1_password_life_time.log
      fi
      mv $DIR/ag_1_1_1_password_life_time.log $DIR/temporales/ag_1_1_1_${ins}_password_life_time.log
}

###################################################################################################
###  ********   PASSWORD_GRACE_TIME   ***************************************
ag_1_1_2_password_grace_time ()
{
ins=$1
      if [ `grep -c "^NOK" $DIR/ag_1_1_2_password_grace_time.log` -gt 0 ]; then
            echo -e "$NOK: --- instancia: $ins ---  No cumple password_grace_time = $PARAM112" | tee -a  $DIR/ag_1_1_2_password_grace_time.log
            res=1
            fixora "AG.1.1.2" "PASSWORD_GRACE_TIME es un parametro de perfil que setea los dias adicionales para cambiar password despues de caducada, debe valer $PARAM112"
            fixora "AG.1.1.2" "Si existen usuarios que incumplen, para corregirlos, debe o bien modificar el perfil donde residen o bien moverlo de perfil"
            for cadaprof in `grep "^NOK:" $DIR/ag_1_1_2_password_grace_time.log  | awk '{printf("%s ",$3);}'`             
            do
                    listausers=`grep "($cadaprof)" $DIR/ag_1_1_2_password_grace_time.log | grep "USER" | awk '{printf("%s ",$4);}'`
                    if [ -n "$listausers" ] ; then
                        fixora "AG.1.1.2" "sql;alter profile $cadaprof PASSWORD_GRACE_TIME $PARAM112;"
                        fixora "AG.1.1.2" "o bien mueva los usuarios de profile $cadaprof a un profile compliance" 
                        fixora "AG.1.1.2" "profile=$cadaprof;usuarios=$listausers"
                    fixora "++++++++++++++++++++++++++++++++++" ""
                    fi

            done
            fixora "$LIN" ""
      else
            echo -e "$OK: --- instancia: $ins ---  password_grace_time = $PARAM112  correcto" | tee -a  $DIR/ag_1_1_2_password_grace_time.log
      fi
      mv $DIR/ag_1_1_2_password_grace_time.log $DIR/temporales/ag_1_1_2_${ins}_password_grace_time.log
}
####################################################################################################
###  ********   PASSWORD_REUSE_TIME    *******************************************
ag_1_1_4_password_reuse_time ()
{
ins=$1
      if [ `grep -c "^NOK" $DIR/ag_1_1_4_password_reuse_time.log` -gt 0 ]; then
            echo -e "$NOK: --- instancia: $ins ---  No cumple password_reuse_time = $PARAM114" | tee -a  $DIR/ag_1_1_4_password_reuse_time.log
            res=1
            fixora "AG.1.1.4" "PASSWORD_REUSE_TIME es un parametro de perfil que setea la cantidad de dias que deben pasar antes de reutilizar una password, debe valer $PARAM114"
            fixora "AG.1.1.4" "Si existen usuarios que incumplen, para corregirlos, debe o bien modificar el perfil donde residen o bien moverlo de perfil"
            for cadaprof in `grep "^NOK:" $DIR/ag_1_1_4_password_reuse_time.log  | awk '{printf("%s ",$3);}'`             
            do
                    listausers=`grep "($cadaprof)" $DIR/ag_1_1_4_password_reuse_time.log | grep "USER" | awk '{printf("%s ",$4);}'`
                    if [ -n "$listausers" ] ; then
                        fixora "AG.1.1.4" "sql;alter profile $cadaprof PASSWORD_REUSE_TIME $PARAM114;"
                        fixora "AG.1.1.4" "o bien mueva los usuarios de profile $cadaprof a un profile compliance" 
                        fixora "AG.1.1.4" "profile=$cadaprof;usuarios=$listausers"
                    fixora "++++++++++++++++++++++++++++++++++" ""
                    fi

            done
            fixora "$LIN" ""
      else
            echo -e "$OK: --- instancia: $ins ---  password_reuse_time = $PARAM114  correcto" | tee -a  $DIR/ag_1_1_4_password_reuse_time.log
      fi
      mv $DIR/ag_1_1_4_password_reuse_time.log $DIR/temporales/ag_1_1_4_${ins}_password_reuse_time.log
}
####################################################################################################
###  *******   PASSWORD_REUSE_MAX    *******************************************
ag_1_1_5_password_reuse_max ()
{
ins=$1
      if [ `grep -c "^NOK" $DIR/ag_1_1_5_password_reuse_max.log` -gt 0 ]; then
            echo -e "$NOK: --- instancia: $ins ---  No cumple password_reuse_max = $PARAM115" | tee -a  $DIR/ag_1_1_5_password_reuse_max.log
            res=1
            fixora "AG.1.1.5" "PASSWORD_REUSE_MAX es un parametro de perfil que setea cuantos cambios de password deben ocurrir antes de reutilizarla, debe valer $PARAM115"
            fixora "AG.1.1.5" "Si existen usuarios que incumplen, para corregirlos, debe o bien modificar el perfil donde residen o bien moverlo de perfil"
            for cadaprof in `grep "^NOK:" $DIR/ag_1_1_5_password_reuse_max.log  | awk '{printf("%s ",$3);}'`             
            do
                    listausers=`grep "($cadaprof)" $DIR/ag_1_1_5_password_reuse_max.log | grep "USER" | awk '{printf("%s ",$4);}'`
                    if [ -n "$listausers" ] ; then
                        fixora "AG.1.1.5" "sql;alter profile $cadaprof PASSWORD_REUSE_MAX $PARAM115;"
                        fixora "AG.1.1.5" "o bien mueva los usuarios de profile $cadaprof a un profile compliance" 
                        fixora "AG.1.1.5" "profile=$cadaprof;usuarios=$listausers"
                    fixora "----------------------------------------------------------------------------------------" ""
                    fi

            done
            fixora "$LIN" ""
      else
            echo -e "$OK: --- instancia: $ins ---  password_reuse_max = $PARAM115  correcto" | tee -a  $DIR/ag_1_1_5_password_reuse_max.log
      fi
      mv $DIR/ag_1_1_5_password_reuse_max.log $DIR/temporales/ag_1_1_5_${ins}_password_reuse_max.log
}
####################################################################################################
###  ******** FAILED_LOGIN_ATTEMPTS    ******************************************
ag_1_1_6_failed_login_attempts ()
{
ins=$1
      if [ `grep -c "^NOK" $DIR/ag_1_1_6_failed_login_attempts.log` -gt 0 ]; then
            echo -e "$NOK: --- instancia: $ins ---  No cumple failed_login_attempts = $PARAM116" | tee -a  $DIR/ag_1_1_6_failed_login_attempts.log
            res=1
            fixora "AG.1.1.6" "FAILED_LOGIN_ATTEMPTS es un parametro de perfil que setea los fallos de password permitidos durante el login, debe valer $PARAM116"
            fixora "AG.1.1.6" "Si existen usuarios que incumplen, para corregirlos, debe o bien modificar el perfil donde residen o bien moverlo de perfil"
            fixora "AG.1.1.6" "Revise la consulta en ${ins}.retries para determinar si algun usuario ha superado la cantidad de fallos permitidos (retries)"
            for cadaprof in `grep "^NOK:" $DIR/ag_1_1_6_failed_login_attempts.log  | awk '{printf("%s ",$3);}'`             
            do
                    listausers=`grep "($cadaprof)" $DIR/ag_1_1_6_failed_login_attempts.log | grep "USER" | awk '{printf("%s ",$4);}'`
                    if [ -n "$listausers" ] ; then
                        fixora "AG.1.1.6" "sql;alter profile $cadaprof FAILED_LOGIN_ATTEMPTS $PARAM116;"
                        fixora "AG.1.1.6" "o bien mueva los usuarios de profile $cadaprof a un profile compliance" 
                        fixora "AG.1.1.6" "profile=$cadaprof;usuarios=$listausers"
                    fixora "++++++++++++++++++++++++++++++++++" ""
                    fi

            done
            fixora "$LIN" ""
      else
            echo -e "$OK: --- instancia: $ins ---   failed_login_attempts = $PARAM116  correcto" | tee -a $DIR/ag_1_1_6_failed_login_attempts.log
      fi
      mv $DIR/ag_1_1_6_failed_login_attempts.log $DIR/temporales/ag_1_1_6_${ins}_failed_login_attempts.log
}
###################################################################################################
###  ********** PASSWORD_LOCK_TIME   ********************************************
ag_1_1_7_password_lock_time ()
{
ins=$1
      if [ `grep -c "^NOK" $DIR/ag_1_1_7_password_lock_time.log` -gt 0 ]; then
            echo -e "$NOK: --- instancia: $ins ---  No cumple password_lock_time = $PARAM117" | tee -a  $DIR/ag_1_1_7_password_lock_time.log
            res=1
            fixora "AG.1.1.7" "PASSWORD_LOCK_TIME es un parametro de perfil que setea la cantidad de dias que el usuario permanece lockeado por failed_login_attempts, debe valer $PARAM117"
            fixora "AG.1.1.7" "Si existen usuarios que incumplen, para corregirlos, debe o bien modificar el perfil donde residen o bien moverlo de perfil"
            for cadaprof in `grep "^NOK:" $DIR/ag_1_1_7_password_lock_time.log  | awk '{printf("%s ",$3);}'`             
            do
                    listausers=`grep "($cadaprof)" $DIR/ag_1_1_7_password_lock_time.log | grep "USER" | awk '{printf("%s ",$4);}'`
                    if [ -n "$listausers" ] ; then
                        fixora "AG.1.1.7" "sql;alter profile $cadaprof PASSWORD_LOCK_TIME $PARAM117;"
                        fixora "AG.1.1.7" "o bien mueva los usuarios de profile $cadaprof a un profile compliance" 
                        fixora "AG.1.1.7" "profile=$cadaprof;usuarios=$listausers"
                    fixora "++++++++++++++++++++++++++++++++++" ""
                    fi

            done
            fixora "$LIN" ""
      else
            echo -e "$OK: --- instancia: $ins ---   password_lock_time = $PARAM117  correcto" | tee -a  $DIR/ag_1_1_7_password_lock_time.log
      fi
      mv $DIR/ag_1_1_7_password_lock_time.log $DIR/temporales/ag_1_1_7_${ins}_password_lock_time.log
}
##################################################################################################
###   ************    PASSWORD_VERIFY_FUNCTION   **************************************
ag_1_1_8_password_verify_function ()
{
ins=$1
      if [ `grep -c "^NOK" $DIR/ag_1_1_8_password_verify_function.log` -gt 0 ]; then
            echo -e "$NOK: --- instancia: $ins ---  No cumple con PASSWORD_VERIFY_FUNCION adecuada para algunos usuarios" | tee -a  $DIR/ag_1_1_8_password_verify_function.log
            fixora "AG.1.1.8" "PASSWORD_VERIFY_FUNCTION es una funcion que debe cumplir los requisitos de calidad de password"
            fixora "AG.1.1.8" "Si existen usuarios que incumplen, para corregirlos, debe o bien modificar el perfil donde residen o bien moverlo de perfil"
            fixora "AG.1.1.8" "Si la funcion de PASWORD_VERIFY_FUNCTION es null, debe crear una funcion nueva o usar una funcion existente y asociarla al perfil" 
            fixora "AG.1.1.8" "Requisitos de calidad de password:"
            fixora "AG.1.1.8" "No se aceptan PASSWORD_VERIFY_FUNCTION = NULL"
            fixora "AG.1.1.8" "  - Longitud de password usuarios privilegiados:  14 (caixa)"
            fixora "AG.1.1.8" "  - Longitud de password usuarios generales: 8 (caixa/itnow)"
            fixora "AG.1.1.8" "  - La password no debe conicidir con el nombre de usuario"
            fixora "AG.1.1.8" "  - La password debe contener al menos 1 caracter alfabetico"

            res=1
            for cadauser in `grep "^NOK:" $DIR/ag_1_1_8_password_verify_function.log  | awk '{printf("%s ",$3);}'`             
            do
                    cadaprof=`grep "^NOK:" $DIR/ag_1_1_8_password_verify_function.log | grep -w $cadauser | awk '{printf("%s",$5);}'` 
                    privilegiado=`grep -w $cadauser $DIR/ag_1_1_8_password_verify_function.log | grep privilegiado`
                    motivo=`grep -w $cadauser $DIR/ag_1_1_8_password_verify_function.log | grep "^NOK" | awk '{for(i=8;i<=NF;i++){printf("%s ",$i);}}'`
                    if [ -n "$privilegiado" ] ; then
                        fixora "AG.1.1.8" "sql;alter profile $cadaprof PASSWORD_VERIFY_FUNCTION VERIFY_PWD_GENERIC;"
                        fixora "AG.1.1.8" "o bien mueva usuario $cadauser (privilegiado) de profile $cadaprof a un profile compliance ($motivo)" 
                    else
                        fixora "AG.1.1.8" "sql;alter profile $cadaprof PASSWORD_VERIFY_FUNCTION VERIFY_PWD_PERSONAL;"
                        fixora "AG.1.1.8" "o bien mueva usuario $cadauser de profile $cadaprof a un profile compliance ($motivo)" 
                    fi
                    fixora "++++++++++++++++++++++++++++++++++" ""
            done
            fixora "$LIN" ""
      else
            echo -e "$OK: --- instancia: $ins ---   PASSWORD_VERIFY_FUNCION adecuada para todos los usuarios (NO LOCKED)" | tee -a  $DIR/ag_1_1_8_password_verify_function.log
      fi
      mv $DIR/ag_1_1_8_password_verify_function.log $DIR/temporales/ag_1_1_8_${ins}_password_verify_function.log
}

####  **********   Externally Identified Accounts (typically OPS$ accounts) - The "identified externally" option may be used if remote_os_authent=false 
####  Esta es una opcion que debe usarse en la creacion/modificacion de los usuarios externos que usen el os_authent_prefix=OPS$ (podria ser otro)
####
####  AG.1.1.10 
ag_1_1_10_externaly_users()
{

ins=$1
USER=$2
authtype=$3

OS_PREFIX=`grep -i OS_AUTHENT_PREFIX /tmp/show_parameter_oracle.lst | awk '{print toupper($3);}'` 
REMOTE_OS_AUTHENT=`grep -i REMOTE_OS_AUTHENT /tmp/show_parameter_oracle.lst | awk '{print toupper($3);}'`
if [ -n "$USER" ]
then
    if [ "$REMOTE_OS_AUTHENT" = "FALSE" ] 
    then
         lg=`echo "$OS_PREFIX" | awk '{print length($1);}'`       #####  obtiene la longitud del OS_PREFIX
         valuser=`echo "$USER" | cut -c1-$lg`
         if [ "$authtype" = "EXTERNAL" ]
         then 
             if [ "$valuser" != "$OS_PREFIX" ]
             then
                  echo -e "$NOK --- instancia $ins --- El user externo $USER no tiene el OS_AUTHENT_PREFIX correcto ($valuser)" 
                  fixora "AG.1.1.10" "El user externo $USER no posee el $OS_PREFIX, elimine el user y vuelva a crearlo con el $OS_PREFIX al principio del username"
                  res=1
             else
                 echo -e "$OK  --- instancia $ins --- User: $USER , AUTHENTICATION_TYPE=EXTERNAL, OS_AUTHENT_PREFIX: $OS_PREFIX, REMOTE_OS_AUTHENT=$REMOTE_OS_AUTHENT"
             fi
         else
                 echo -e "$NOK --- instancia $ins --- User: $USER , AUTHENTICATION_TYPE=$authtype (not identified externally), OS_AUTHENT_PREFIX: $OS_PREFIX, REMOTE_OS_AUTHENT=$REMOTE_OS_AUTHENT"
                 fixora "AG.1.1.10" "El user externo $USER no tiene la opcion 'identified externally'."
                 fixora "AG.1.1.10" "sql;alter user $USER identified externally;"
                 res=1
         fi
    else
         echo -e "$NOK - --- instancia $ins ---: el parametro REMOTE_OS_AUTHENT=$REMOTE_OS_AUTHENT esta mal configurado para el user externo $USER"
         fixora "AG.1.1.10" "El user $USER externo bien seteado, pero el PARAMETRO REMOTE_OS_AUTHENT no es 'FALSE'"
         fixora "AG.1.1.10" "sql; alter system set REMOTE_OS_AUTHENT=false scope=spfile;"
         fixora "AG.1.1.10" "y reinicie la base de datos"
         res=1
    fi
fi
}

###****************   CRONTABS de usuarios 'dba'  **********************************************
####     AG.1.8.13.1  los comandos de los cron files de usuarios oracle, no pueden tener permiso 'w' for others
####
ag_1_8_13_1_crons() ####  busca los crones del usuario que entra como parametro, de este modo puede hacer la lista de usuarios 'DBA's
{

ERRORFILE=errorfile2

res=0
USER=$1

#infor "AG.1.8.13.1:" "Scripts detected from crontab files of the 'dba' OS users are not world writable"
#inforsis "AG.1.8.13.1:" "Scripts detected from crontab files of the 'dba' OS users are not world writable"
malo=0
if [ -f /var/spool/cron/$USER ] ; then 
#######################################################
####   obtener la lista de comandos (full path) de los cron de usuarios oracle
####   si se ponen en la variable 'comandos' ya se hace la comprobacion
####   se usara parte del codigo de la techspec de Linux: AD.1.8.14.1  (para cron de usuario 'root' en linux)
  > $ERRORFILE
#####    comandos=`awk '{print $5}' /var/spool/cron/$USER | tr '\n' ' '`   ### esta linea no extrae correctamente los comandos a revisar
  comandos=$(cron_comandos /var/spool/cron/$USER)
  if [ -s $ERRORFILE ]
  then
          infor "$NOK: CRON $USER :$RESULTADOCRON"
          inforsis "$NOK: CRON $USER :$RESULTADOCRON"
          fix "AG.1.8.13.1" "comandos en /var/spool/cron/$USER no existen o tienen path relativo. Asigne path absoluto."
          awk -v fil=/var/spool/cron/$USER '{print "NOK;fil;no existe;"$0}' $ERRORFILE >> $INFORSIS 
          awk -v fil=/var/spool/cron/$USER '{print "NOK;fil;no existe;"$0}' $ERRORFILE >> $INFORME 
          malo=1
  fi    
  if [ ! -z "$comandos" ]
  then
    for com in $comandos
    do
       perm=`ls -l $com | awk '{print $1 }' | cut -c9`
       perm2=`ls -l $com | awk '{print $1}'`
       if [[ $perm == 'w' ]] ; then
         infor "$NOK:  script cronjobs for $USER : $com  has 'w' permission for other" ""
         inforsis "$NOK:  script cronjobs for $USER : $com  has 'w' permission for other" ""
         fix "AG.1.8.13.1" "chmod o-w $com \n"
         malo=1
       else
         infor "$OK: $perm2;$com;script cronjobs for $USER : permisos correctos "
         inforsis "$OK: $perm2;$com;script cronjobs for $USER : permisos correctos "
       fi
    done
  fi
  if [ $malo -eq 0 ] ; then
   infor "$OK: No existen comandos de cronjobs del usuario $USER con permisos 'w' (other) \n" ""
   inforsis "$OK: No existen comandos de cronjobs del usuario $USER con permisos 'w' (other) \n" ""
   MASINFO="tiene scripts/file en su /var/spool/cron/$USER con permisos adecuados"
  else
      infor "$NOK: Existen comandos de cronjobs del usuario $USER que no existen o tienen permiso 'w' (other) prohibidos \n" "" 
      inforsis "$NOK: Existen comandos de cronjobs del usuario $USER que no existen o tienen permiso 'w' (other) prohibidos \n" "" 
      fix "$LIN" ""
      res=1
  fi
else
      infor "$OK: No existe /var/spool/cron/$USER . Nada que chequear. \n" ""
      inforsis "$OK: No existe /var/spool/cron/$USER . Nada que chequear. \n" ""
      MASINFO="no tiene /var/spool/cron/$USER, nada que chequear"
fi  ### fin de si existe fichero /var/spool/cron/$USER

if [ $res -eq 1 ]
then
    TEXTO_TECH="$NOK - 'DBA's CRONs - Usuario dba $USER ejecuta scripts/files en sus cronfile con permisos 'w' for others prohibidos"
else
    TEXTO_TECH="$OK - 'DBA's CRONs - Usuario dba $USER $MASINFO"
fi
echo -e $TEXTO_TECH
rm -f $ERRORFILE
}

#####************************************************************************************************

#####**************   umask usuarios oracle **********************************************************
#####    AG.1.9.1.1 - umask de usuarios oracle - para softowners de instalacion SW Oracle 
#####
ag_1_9_1_1_umasks_binaries()
{
#infor "AG.1.9.1.1:"  "Umask for Oracle user - x022 for installation and maintenance of Oracle binaries\n"
#inforsis "AG.1.9.1.1:"  "Umask for Oracle user - x022 for installation and maintenance of Oracle binaries\n"

res=0
ORACLE_HOME=`grep ORACLE_HOME $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
ORACLE_GRID=`grep ORACLE_GRID $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
ORACLE_AGENT=`grep ORACLE_AGENT $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`

ficheros_umask_install_settings=`find -L $ORACLE_HOME $ORACLE_GRID $ORACLE_AGENT  -name *param*.ini  -print` 

umask_malos=""

> umask_binarios_oracle

if [ -n "$ficheros_umask_install_settings" ]
then
    for fich in $ficheros_umask_install_settings 
    do
         umask_fich=`grep -i UMASK $fich | awk -F"=" '{printf("%s",$2)}'`
         umask_fich=${umask_fich:-007}
         if [ $umask_fich != "022" ]
         then
             res=1
             fix "AG.1.9.1.1" "$fich :  Modifique fichero y setee UMASK=022"
             echo -e "$NOK - umask $umask_fich in $fich  (for install/maintenance of Oracle binaries)" >> umask_binarios_oracle
             umask_malos="$umask_fich $umask_malos"
         else    
             echo -e "$OK - umask $umask_fich in $fich  (for install/maintenance of Oracle binaries)" >> umask_binarios_oracle
         fi
    done
else
    res=1
    fix "AG.1.9.1.1" "La instalacion Oracle Software no dispone de ficheros oraparam.ini o clusterparam.ini que seteen umask 022"
    fix "AG.1.9.1.1" "Revise la instalacion del producto"
    echo -e "$NOK - No existen ficheros de parametros de instalacion que seteen umask 022, por defecto 007" >> umask_binarios_oracle
    umask_malos="007"
fi

if [ $res -eq 1 ]
then
     fix "$LIN" "" 
     TEXTO_TECH="$NOK - umask $umask_malos for any installation and maintenance of Oracle binaries"
else
     TEXTO_TECH="$OK -  umask 022  for installation and maintenance of Oracle binaries"
fi

echo -e "$TEXTO_TECH"
}


#####**************   umask usuarios oracle **********************************************************
#####    AG.1.9.1.2 - umask de usuarios oracle 027 - para Daily operations
#####
ag_1_9_1_2_umasks_daily()
{
usuarios=`ps -ef | grep pmon_ |grep -v grep |grep -v asm |awk '{print $1}' | uniq | tr '\n' ' '`
#infor "AG.1.9.1.2:"  "Umask for Oracle user - x027 for Daily operations\n"
#inforsis "AG.1.9.1.2:"  "Umask for Oracle user - x027 for Daily operations\n"
res=0
umalos=""
for USER in $usuarios
do
      umaskusuario=`runuser -l $USER -c 'umask'`
      if [[ $umaskusuario == ?027 ]] ; then
          infor "$OK:  Umask user: $USER  = $umaskusuario \n"
          inforsis "$OK:  Umask user: $USER  = $umaskusuario \n"
      else
          HOME1=`grep "^$USER" /etc/passwd |  awk -F":" '{print $6}'`
          umalos="$USER $umalos"
          infor "$NOK:  Umask user: $USER  = $umaskusuario - resetear umask=027  en $HOME1/.bashrc\n" ""
          inforsis "$NOK:  Umask user: $USER  = $umaskusuario - resetear umask=027  en $HOME1/.bashrc\n" ""
          fix "AG.1.9.1.2" "Umask=$umaskusuario  for user $USER - Must be set to x027 for Daily operations"
          fix "AG.1.9.1.2" "runuser -l $USER -c 'echo umask 027 >> $HOME1/.bashrc' \n"
          res=1
      fi
done
if [ $res -eq 1 ]
then
    fix "$LIN" "" 
    TEXTO_TECH="$NOK - Protecting resources - User Resources : Umask de users "$umalos"  no es x027 - Daily operations"
else
    TEXTO_TECH="$OK - Protecting resources - User Resources : Umask de users "$usuarios" correctos (x027) - Daily operations"
fi
echo -e $TEXTO_TECH

}


###*************    AUDITORIAS   ********************************************************************
#####   AG.1.2.1

ag_1_2_1_check_audit_trail ()
{
USER=$1
ins=$2

AUDIT_FILE_DEST=`grep "AG.1.2.1" /tmp/isec_oracle_audit.lst | awk -F'|' '{print $5}' | tr -d ' '`
#
# AG.1.2.1:    AUDITORIA:  Parametro AUDIT_TRAIL must be 'OS' or 'DB' or 'DB_EXTENDED'
#                          si 'OS' : todos los ficheros de sistema *.aud del directorio destino  $AUDIT_FILE_DEST 
#                          deben tener owner=$USER y permisos=640 
#
inforora "AG.1.2.1:"  "AUDITORIA:  Parametro AUDIT_TRAIL must be 'OS' or 'DB' or 'DB_EXTENDED'"
inforora "         "  "            si 'OS' : todos los ficheros de sistema *.aud del directorio destino  $AUDIT_FILE_DEST" ""
inforora "         "  "            deben tener owner=$USER y permisos=640" ""
grep "AG.1.2.1" /tmp/isec_oracle_audit.lst | awk -F'|' -v OK=$OK -v NOK=$NOK -v ins=$ins '{if ($4~"NOK") print NOK": --- instancia: "ins" --- AUDIT_TRAIL = "$3;else print OK": --- instancia: "ins" --- AUDIT_TRAIL = "$3}' | tee -a $INFORMEORA | tee -a $INFORME 
grep "AG.1.2.1" /tmp/isec_oracle_audit.lst |grep "NOK" >/dev/null 2>&1
res1=$?   
VALOR=`grep "AG.1.2.1" /tmp/isec_oracle_audit.lst | awk -F'|' '{print $3}' | tr -d ' '`
if [[ $VALOR == 'OS' ]] ; then
        ls -l $AUDIT_FILE_DEST | sed '/^total/d' | awk -v user=$USER '{ if ($1!~"...-.-----" || $3!~user ) print $1";"$3";"$4";"$9" ==> owner(user)/permiso(640) incorrecto"}' | tee -a $INFORMEORA |tee -a $INFORME 
        unalista=`ls -l $AUDIT_DILE_DEST | sed '^total/d' | awk -v user=$USER '{ if ($1!~"...-.-----" || $3!~user ) print "chmod 640 "$9}'`
        if [ ! -z $unalista ]
        then
             fixes "AG.1.2.1" "$unalista"
             res1=0
        fi
fi
if [ $res1 = 0 ] ; then
       fixora "AG.1.2.1" "SENTENCIAS para activar AUDIT TRAIL: (valore cuidadosamente su activacion)"
###       inforora "        " "SENTENCIAS para activar AUDIT TRAIL: (valore cuidadosamente su activacion)"
       fixora "AG.1.2.1" "sql;alter system set AUDIT_TRAIL=[os|db|db_extended];"
###       inforora "        " "    alter system set AUDIT_TRAIL=[os|db|db_extended];"
       fixora "AG.1.2.1" "Y reinicie base de datos ....."
###       inforora "        " "Y reinicie base de datos ....."
       fixora "AG.1.2.1" "Si selecciona 'OS' recuerde setear:"
###       inforora "        " "Si selecciona 'OS' recuerde setear:"
       fixora "AG.1.2.1" "sql;alter system set AUDIT_FILE_DEST=directorio;"
###       inforora "        " "    alter system set AUDIT_FILE_DEST=directorio"
       fixora "AG.1.2.1" "y segurese de tener espacio suficiente en ese directorio"
###       inforora "        " "y segurese de tener espacio suficiente en ese directorio\n"
       fixora "AG.1.2.1" "Si selecciona 'DB' o 'DB_EXENDED' utilice un tablespace independiente para la tabla AUD$"
###       inforora "        " "Si selecciona 'DB' o 'DB_EXENDED' utilice un tablespace independiente para la tabla AUD$"
       fixora "AG.1.2.1" "y prepare un metodo de limpieza de la tabla AUD$ \n$LIN"
###       inforora "        " "y prepare un metodo de limpieza de la tabla AUD$ \n$LIN"
       res=1
else
       res=0
       inforora "$LIN" ""
fi  
}

#####################################################################################
######   AG.1.2.3

ag_1_2_3_check_audit_param ()
{
ins=$1
#
# AG.1.2.3: AUDITORIA:   Parametro SEC_PROTOCOL_ERROR_TRACE_ACTION must be 'LOG'
#

inforora "AG.1.2.3:" "AUDITORIA:   Parametro SEC_PROTOCOL_ERROR_TRACE_ACTION must be 'LOG'"

grep "AG.1.2.3" /tmp/isec_oracle_audit.lst | awk -F'|' -v OK=$OK -v NOK=$NOK -v ins=$ins '{if ($4~"NOK") print NOK": --- instancia: "ins" --- SEC_PROTOCOL_ERROR_TRACE_ACTION = "$3;else print OK": --- instancia: "ins" --- SEC_PROTOCOL_ERROR_TRACE_ACTION = "$3}' | tee -a $INFORMEORA |tee -a $INFORME
grep "AG.1.2.3" /tmp/isec_oracle_audit.lst | grep "NOK" >/dev/null 2>&1
if [ $? = 0 ] ; then
       fixora "AG.1.2.3" "SENTENCIAS para activar SEC_PROTOCOL_ERROR_TRACE_ACTION: (valore cuidadosamente su activacion)"
###       inforora "        " "SENTENCIAS para activar SEC_PROTOCOL_ERROR_TRACE_ACTION: (valore cuidadosamente su activacion)"
       fixora "AG.1.2.3" "sql;alter system set SEC_PROTOCOL_ERROR_TRACE_ACTION=LOG SCOPE=SPFILE;"
###       inforora "        " "    alter system set SEC_PROTOCOL_ERROR_TRACE_ACTION=LOG SCOPE=SPFILE"
       fixora "AG.1.2.3" "Y reinicie base de datos .....\n$LIN"
###       inforora "        " "Y reinicie base de datos .....\n$LIN"
       res=1
else
       res=0
       inforora "$LIN" ""
fi
}

#####################################################################################
####  AG.1.2.4

ag_1_2_4_check_audit_operacions ()
{
ins=$1
res=0

inforora "AG.1.2.4:"  "AUDITORIA:  Parametro AUDIT_SYS_OPERATIONS  must be 'TRUE'" 

grep "AG.1.2.4" /tmp/isec_oracle_audit.lst | awk -F'|' -v OK=$OK -v NOK=$NOK -v ins=$ins '{if ($4~"NOK") print NOK": --- instancia: "ins" --- AUDIT_SYS_OPERATIONS = "$3;else print OK": --- instancia: "ins" --- AUDIT_SYS_OPERATIONS = "$3}' | tee -a $INFORMEORA | tee -a $INFORME
grep "AG.1.2.4" /tmp/isec_oracle_audit.lst | grep "NOK" >/dev/null 2>&1
if [ $? = 0 ] ; then
       fixora "AG.1.2.4" "SENTENCIAS para activar AUDIT_SYS_OPERATIONS: (valore cuidadosamente su activacion)"
###       inforora "        " "SENTENCIAS para activar AUDIT_SYS_OPERATIONS: (valore cuidadosamente su activacion)"
       fixora "AG.1.2.4" "sql;alter system set AUDIT_SYS_OPERATIONS=TRUE SCOPE=SPFILE;"
###       inforora "        " "    alter system set AUDIT_SYS_OPERATIONS=TRUE SCOPE=SPFILE"
       fixora "AG.1.2.4" "Y reinicie base de datos .....\n$LIN"
###       inforora "        " "Y reinicie base de datos .....\n$LIN"
       res=1
else
       inforora "$LIN" ""
fi

}

#####################################################################################
####  AG.1.2.8    DELETE_CATALOG_ROLE restricted to DBAs

ag_1_2_8_users_delete_catalog_role ()
{
ins=$1

inforora "AG.1.2.8:"  "LOGGING: DELETE_CATALOG_ROLE restricted to DBAs" 
inforora "         "  "Solo los roles/usuarios DBAs pueden tener este privilegio"
inforora "\nInstance: $ins --- DELETE_CATALOG_ROLE restricted to DBAs\n-----------------------------------"
grep -q "^NOK" /tmp/users_delete_catalog_role.lst > $TMPOUT 
if [ $? = 0 ] ; then
   fixora "AG.1.2.8" "SENTENCIAS para quitar el privilegio DELETE_CATALOG_ROLE: (valore cuidadosamente su revocacion)"
   while read -e linea
   do 
       from1=`echo $linea | awk '{print $3}'`
       fixora "AG.1.2.8" "sql;revoke DELETE_CATALOG_ROLE from $from1;" 
   done < $TMPOUT
   res=1
fi

if [ $res -eq 1 ]
then
     TEXTO_TECH="$NOK --- instancia: $ins --- Existen roles/usuarios con privilegio DELETE_CATALOG_ROLE y no son DBAs"
else
     TEXTO_TECH="$OK  --- instancia: $ins --- Privilegio DELETE_CATALOG_ROLE restringidos a roles/usuarios DBAs"
fi

echo -e $TEXTO_TECH
}

############################################################################################
##### AG.1.2.6
#####   descomente la siguiente linea si desea generar un fichero .sql con las sentencias de auditoria a ejecutar desde SQLPLUS
#####   check_audit_all ()
#####   {
####    grep "AG.1.2." $FIXORA | grep ";sql;" |awk -F ';' '{print $3}' > $DIR/fixes/cambio_auditoria_$ins.sql

####    infor "AG.1.2.6: " "AUDITORIA: AUDIT ALL;  need to be enabled"
####    infor "          " "Implica auditar: "
####    infor "          " "     - connections and statements relating to user access,"
####    infor "          " "     - changes to database objects and to the structure of the database itself."
####    infor "" ""
####    infor "          " "TABLA de sentencias/privilegios del AUDIT ALL:"
####    infor "          " "   - ALTER SYSTEM      (ALTER SYSTEM)"
####    infor "          " "   - CLUSTER           (CREATE, ALTER, DROP, TRUNCATE CLUSTER)"
####    infor "          " "   - CONTEXT           (CREATE,        DROP           CONTEXT)"
####    infor "          " "   - DATABASE LINK     (CREATE, ALTER, DROP           DATABASE LINK)"
####    infor "          " "   - DIMENSION         (CREATE, ALTER, DROP           DIMENSION)"
####    infor "          " "   - DIRECTORY         (CREATE,        DROP           DIRECTORY)"
####    infor "          " "   - INDEX             (CREATE, ALTER, DROP, ANALIZE  INDEX)"
####    infor "          " "   - MATERIALIZED VIEW (CREATE, ALTER, DROP           MATERIALIZED VIEW)"
####    infor "          " "   - NOT EXISTS        (All SQL statments that fail because object does not exist)"
####    infor "          " "   - OUTLINE           (CREATE, ALTER, DROP           OUTLINE)"
####    infor "          " "   - PROCEDURE         (CREATE,        DROP           FUNCTION,LIBRARY,PACKAGE,PROCEDURE,JAVA SOURCES,CLASSES,RESOURCES)"
####    infor "          " "   - PROFILE           (CREATE, ALTER, DROP           PROFILE)"
####    infor "          " "   - PUBLIC DATABASE LINK (CREATE, ALTER, DROP        PUBLIC DATABASE LINK)" 
####    infor "          " "   - PUBLIC SYNONYM    (CREATE,       DROP            PUBLIC SYNONYM)"
####    infor "          " "   - ROLE              (CREATE, ALTER, DROP, SET      ROLE)"
####    infor "          " "   - ROLLBACK SEGMENT  (CREATE, ALTER, DROP           ROLLBACK SEGMENT)"
####    infor "          " "   - SEQUENCE          (CREATE,        DROP           SEQUENCE)"
####    infor "          " "   - SESSION           (                              LOGON)"
####    infor "          " "   - SYNONYM           (CREATE,        DROP           SYNONYM)"
####    infor "          " "   - SYSTEM AUDIT      (AUDIT, NOAUDIT                SQL statement)"
####    infor "          " "   - SYSTEM GRANT      (GRANT, REVOKE                 system-privileges-and-roles)"
####    infor "          " "   - TABLE             (CREATE,        DROP, TRUNCATE TABLE)"
####    infor "          " "   - TABLESPACE        (CREATE, ALTER, DROP           TABLESPACE)" 
####    infor "          " "   - TRIGGER           (CREATE, ALTER, DROP           TRIGGER with ENABLE/DISABLE clause)"
####    infor "          " "   - TYPE              (CREATE, ALTER, DROP           TYPE and TYPE BODY)"
####    infor "          " "   - USER              (CREATE, ALTER, DROP           USER)"
####    infor "          " "   - VIEW              (CREATE,        DROP           VIEW)"
####    runuser -l $USER -c ". $ENVFILE ; sqlplus -s /nolog @$DIR/audit-stmt-priv.sql"
####    echo | tee -a $INFORME
####    /tmp/audit-stmt-priv.lst tiene todos las statements/privilegios auditados, en el 2-do campo
####    cat /tmp/audit-stmt-priv.lst | awk -F';' '{gsub("  ","",$2);print $2}' 

####    }
###***********   FIN AUDITORIA   ********************************************************
###
####************  show PARAMETERS ********************************************************************
###  AG.1.4.1
###
ag_1_4_1_param_o7_dictionary_accessibility ()
{
ins=$1

inforora "AG.1.4.1"  "System Settings - Parameter O7_DICTIONARY_ACCESSIBILITY  must be FALSE"
inforora "        "  "Controls restrictions on SYSTEM privileges. "
inforora "        "  "If the parameter is set to true, access to objects in the SYS schema is allowed."
inforora "        "  "The default setting of false ensures that system privileges that allow access to objects in 'any schema'"
inforora "        "  "do not allow access to objects in the SYS schema."


grep O7_DICTIONARY_ACCESSIBILITY /tmp/show_parameter_oracle.lst | awk -v OK="$OK" -v NOK="$NOK" -v ins=$ins '{if ($3=="FALSE"||$3=="false") print OK": --- instancia: "ins" --- parameter O7_DICTIONARY_ACCESSIBILITY="$3 ;else print NOK": --- instancia: "ins" --- parameter O7_DICTIONARY_ACCESSIBILITY="$3}' | tee -a $INFORMEORA | tee -a $INFORME
grep O7_DICTIONARY_ACCESSIBILITY /tmp/show_parameter_oracle.lst | awk -v lin=$LIN '{if ($3!~"FALSE" && $3!~"false") print "AG.1.4.1;SENTENCIAS para corregir parameter O7_DICTIONARY_ACCESSIBILITY\nAG.1.4.1;sql;alter system set O7_DICTIONARY_ACCESSIBILITY=FALSE SCOPE=SPFILE;\nAG.1.4.1;y reinicie Base de datos...\n"lin}' >> $FIXORA 
res=`grep O7_DICTIONARY_ACCESSIBILITY /tmp/show_parameter_oracle.lst | awk '{if ($3!~"FALSE" && $3!~"false") print 1; else print 0; }'`  
}

########################################################################################
###  AG.1.4.3
###
ag_1_4_3_param_remote_os_authent ()
{
ins=$1

inforora "AG.1.4.3"  "System Settings - Parameter REMOTE_OS_AUTHENT  must be FALSE"
inforora "        "  "Specifies whether remote clients will be authenticated with the value of the OS_AUTHENT_PREFIX parameter."
inforora "        "  "REMOTE_OS_AUTHENT parameter is deprecated. It is retained for backward compatibility only"

grep remote_os_authent /tmp/show_parameter_oracle.lst | awk -v OK="$OK" -v NOK="$NOK" -v ins=$ins '{if ($3=="FALSE"||$3=="false") print OK": --- instancia: "ins" --- parameter REMOTE_OS_AUTHENT="$3;else print NOK": --- instancia: "ins" --- parameter REMOTE_OS_AUTHENT="$3}' |tee -a $INFORMEORA |tee -a $INFORME
grep remote_os_authent /tmp/show_parameter_oracle.lst | awk -v lin=$LIN '{if ($3!~"FALSE" && $3!~"false") print "AG.1.4.3;SENTENCIAS para corregir parameter remote_os_authent\nAG.1.4.3;sql;alter system set remote_os_authent=false SCOPE=SPFILE;\nAG.1.4.3;y reinicie Base de Datos...\n"lin}' >> $FIXORA 
res=`grep remote_os_authent /tmp/show_parameter_oracle.lst | awk '{if ($3!~"FALSE" && $3!~"false") print 1; else print 0;}'` 
}

###########################################################################################
###  AG.1.4.4
###
ag_1_4_4_param_sec_max_failed_login_attempts ()
{
ins=$1

inforora "AG.1.4.4"  "System Settings - Parameter SEC_MAX_FAILED_LOGIN_ATTEMPTS  must be $PARAM116"
inforora "        "  "Specifies the number of authentication attempts that can be made by a client on a connection to the server process"

grep sec_max_failed_login_attempts /tmp/show_parameter_oracle.lst | awk -v OK="$OK" -v NOK="$NOK" -v ins=$ins -v val=$PARAM116 '{if ($3==val) print OK": --- instancia: "ins" --- parameter SEC_MAX_FAILED_LOGIN_ATTEMPTS="$3;else print NOK": --- instancia: "ins" --- parameter SEC_MAX_FAILED_LOGIN_ATTEMPTS="$3}' |tee -a $INFORMEORA | tee -a $INFORME
grep sec_max_failed_login_attempts /tmp/show_parameter_oracle.lst | awk -v lin=$LIN -v val=$PARAM116 '{if ($3!=val) print "AG.1.4.4;SENTENCIAS para corregir parameter sec_max_failed_login_attempts\nAG.1.4.4;sql;alter system set SEC_MAX_FAILED_LOGIN_ATTEMPTS=" val " SCOPE=SPFILE;\nAG.1.4.4;y reinicie Base de Datos...\n"lin}' >> $FIXORA 
res=`grep sec_max_failed_login_attempts /tmp/show_parameter_oracle.lst | awk -v val=$PARAM116 '{if ($3!=val) print 1 ; else print 0}'`  
}

###########################################################################################
###  AG.1.4.5
###
ag_1_4_5_param_sec_return_server_release_banner ()
{
ins=$1

inforora "AG.1.4.5"  "System Settings - Parameter SEC_RETURN_SERVER_RELEASE_BANNER  must be FALSE"
inforora "        "  "Specifies the server does not return complete database software information to clients."
inforora "        "  "FALSE: Only returns a generic version string to the client."

grep sec_return_server_release_banner /tmp/show_parameter_oracle.lst | awk -v OK="$OK" -v NOK="$NOK" -v ins=$ins '{if ($3=="FALSE"||$3=="false") print OK": --- instancia: "ins" --- parameter SEC_RETURN_SERVER_RELEASE_BANNER="$3;else print NOK": --- instancia: "ins" --- parameter SEC_RETURN_SERVER_RELEASE_BANNER="$3}' |tee -a $INFORMEORA | tee -a $INFORME
grep sec_return_server_release_banner /tmp/show_parameter_oracle.lst | awk -v lin=$LIN '{if ($3!~"FALSE" && $3!~"false") print "AG.1.4.5;SENTENCIAS para corregir sec_return_server_release_banner\nAG.1.4.5;sql;alter system set SEC_SEC_RETURN_SERVER_RELEASE_BANNER=FALSE SCOPE=SPFILE;\nAG.1.4.5;y reinicie Base de Datos...\n"lin}' >> $FIXORA 
res=`grep sec_return_server_release_banner /tmp/show_parameter_oracle.lst | awk '{if ($3!~"FALSE" && $3!~"false") print 1; else print 0;}'` 
}

#########################################################################################
###  AG.1.4.6
###
ag_1_4_6_param_db_name ()
{
ins=$1

inforora "AG.1.4.6"  "System Settings - DB_NAME - Change the default ORCL database name"

grep db_name /tmp/show_parameter_oracle.lst | awk -v OK="$OK" -v NOK="$NOK" -v ins=$ins '{if ($3=="ORCL") print NOK": --- instancia: "ins" --- parameter DB_NAME="$3;else print OK": --- instancia: "ins" --- DB_NAME="$3" no es default ORCL database name"}' | tee -a $INFORMEORA | tee -a $INFORME
grep db_name /tmp/show_parameter_oracle.lst | awk -v lin=$LIN '{if ($3=="ORCL") print "AG.1.4.6;SENTENCIAS para corregir DB_NAME=ORCL\nAG.1.4.6;El procedimiento es complejo y debe consultarse en la Documentacion Oracle\n"lin}' >> $FIXORA
res=`grep db_name /tmp/show_parameter_oracle.lst | awk '{if ($3=="ORCL") print 1; else print 0;}'`
}

#########################################################################################
### AG.1.4.7
###
ag_1_4_7_remote_os_roles ()
{
ins=$1

inforora "AG.1.4.7"  "System Settings - Parameter REMOTE_OS_ROLES  must be FALSE"
inforora "        "  "The default value, false, causes Oracle to identify and manage roles for remote clients."

grep remote_os_roles /tmp/show_parameter_oracle.lst | awk -v OK="$OK" -v NOK="$NOK" -v ins=$ins  '{if ($3=="FALSE"||$3=="false") print OK": --- instancia: "ins" --- parameter REMOTE_OS_ROLES="$3;else print NOK": --- instancia: "ins" --- parameter REMOTE_OS_ROLES="$3}' |tee -a $INFORMEORA | tee -a $INFORME
grep remote_os_roles /tmp/show_parameter_oracle.lst | awk -v lin=$LIN '{if ($3!~"FALSE" && $3!~"false") print "AG.1.4.7;SENTENCIAS para corregir remote_os_roles\nAG.1.4.7;sql;alter system set REMOTE_OS_ROLES=FALSE SCOPE=SPFILE;\nAG.1.4.7;y reinicie Base de Datos...\n"lin}' >> $FIXORA 
res=`grep remote_os_roles /tmp/show_parameter_oracle.lst | awk '{if ($3!~"FALSE" && $3!~"false") print 1; else print 0;}'`
}
#########################################################################################

#########################################################################################
### AG.1.4.8
###
ag_1_4_8_utl_file_dir ()
{
ins=$1

inforora "AG.1.4.8"  "System Settings - Parameter UTL_FILE_DIR   must not be set to '*'"
inforora "        "  "Specifies one or more directories that Oracle should use for PL/SQL file I/O."
inforora "        "  "Each directory on separate contiguous lines" 

grep utl_file_dir /tmp/show_parameter_oracle.lst | awk -v OK="$OK" -v NOK="$NOK" -v ins=$ins  '{if ($3=="'"*"'") print NOK": --- instancia: "ins" --- parameter UTL_FILE_DIR=*";else print OK": --- instancia: "ins" --- parameter UTL_FILE_DIR="($3?$3:"null")}' |tee -a $INFORMEORA | tee -a $INFORME
grep utl_file_dir /tmp/show_parameter_oracle.lst | awk -v lin=$LIN '{if ($3=="'"*"'") print "AG.1.4.8;SENTENCIAS para corregir utl_file_dir\nAG.1.4.8;sql;alter system set UTL_FILE_DIR=path_directory SCOPE=SPFILE;\nAG.1.4.8;y reinicie Base de Datos...\n"lin}' >> $FIXORA 
res=`grep utl_file_dir /tmp/show_parameter_oracle.lst | awk '{if ($3=="'"*"'") print 1; else print 0;}'`
}
#########################################################################################
# get a property from stdin (listener.ora format) for a specific listener and 
# print it on stdout. this awk script will tokenize the listener file so that 
# it can find the property no matter what format the file is in. it will only 
# print the first match (for example an address).
#   param 1: top-level property filter (e.g. listener name)
#   param 2: leaf property to get (e.g. host, port, protocol)
# by Jeremy Schneider - ardentperf.com
getlistenerproperty() {
  sed -e 's/=/`=/g' -e 's/(/`(/g' -e 's/)/`)/g'|awk 'BEGIN{level=1} {
    wrote=0
    split($0,tokens,"`")
    i=1; while(i in tokens) {
      if(tokens[i]~"^[(]") level++
      if(tokens[i]~"^[)]") level--
      if(level==1&&i==1&&tokens[i]~"[A-Za-z]") TOP=tokens[i]
      if(toupper(TOP)~toupper("^[ t]*'"$1"'[ t]*$")) {
        if(propertylvl) {
          if(level>=propertylvl) {
            if(tokens[i]~"^="&&level==propertylvl) printf substr(tokens[i],2)
              else printf tokens[i]
            wrote=1
          } else propertylvl=0
          found=1
        }
        if(!found&&toupper(tokens[i])~toupper("^[(]?[ t]*'"$2"'[ t]*$")) propertylvl=level
      }
      i++
    }
    if(wrote) printf ";"
  }'
}

################   LISTENERS ##############################################################
####
#### AG.1.5.1
ag_1_5_1_listener_password ()
{
####***************PASSWORDS   en ficheros   listener.ora   ********************************************
inforsis "AG.1.5.1"  "Network Settings - Passwords of Listeners - Only required where LOCAL_OS_AUTHENTICATION_<LISTENER>=OFF"
inforsis "Nota:   "  "Remote listener authentication is enabled if  LOCAL_OS_AUTHENTICATION_<listener>=OFF, then you must set password for it"
inforsis "        "  "in your listener.ora file with PASSWORDS_<listener_name> = password \n"
inforsis "        "  "Refer base policy for password complexity requirements"

res=0

########  para que root pueda ejecutar comandos "svrctl o lsnrctl, debe tener el PATH seteado al principio con $ORACLE_GRID/bin
setear_entorno_network

########  obtenemos la lista de listener activos revisando los procesos "tnslsnr"
lista_listener=`ps -ef |  grep "tnslsnr" |grep -v grep | awk '{print $9}'`     ####  devuelve los nombres de los listener activos

for listener_name in $lista_listener
do
######    buscamos el listener_file que le corresponde a este listener, teniendo en cuenta que puede ser un Single Client Access Listener o un Cluster Ready Listener
    ERRCLUSTER=`srvctl config listener -l ${listener_name} | grep "PRCN-2066"`      #####  type Single Client Access Name Listener
    if [ -n "$ERRCLUSTER" ] ; then
          listener_file=`lsnrctl status ${listener_name} | grep -i "listener parameter file" | awk '{print $4}'`
    else
          ORAHOME=`srvctl config listener -l ${listener_name} | grep Home | awk '{print $2}'`       ####   es un listener cluster ready
          if [ -d "$ORAHOME" ] ; then
               listener_file="$ORAHOME/network/admin/listener.ora"    #####  aqui ORAHOME es directorio, pero en algun caso ORAHOME = <CRS home> , no un directorio
          else
               echo "$ORAHOME" | grep -q "CRS"         ####   caso ORAHOME= <CRS home>  que debe coincidir con CRS_HOME extraido de inventory.xml 'CRS="true"'
               if [ $? -eq 0 ] ; then
                   CRS_HOME=`grep CRS_HOME $DIR/envfile* |grep -v grep | awk -F"=" '{print $2}'`
                   listener_file="$CRS_HOME/network/admin/listener.ora"
               else
                   listener_file=""
               fi
          fi  
    fi
   
    if [ -z $listener_file ] ; then
       TEXTO_TECH="$NOK - no se encuentra listener.ora para listener $listener_name"
       echo -e $TEXTO_TECH
       res=1
       return
    fi 
    grep -q -i "LOCAL_OS_AUTHENTICATE_${listener_name}" $listener_file
    if [ $? -eq 0 ]
    then
         valor=`cat $listener_file | getlistenerproperty LOCAL_OS_AUTHENTICATE_${listener_name} LOCAL_OS_AUTHENTICATE_${listener_name}| tr -s ";" ""`
#####             valor=`grep -i "LOCAL_OS_AUTHENTICATE_${listener_name}" $listener_file | awk -F"=" '{print $2}'`
         if [[ "$valor" = "OFF" ]] || [[ "$valor" = "off" ]]
         then
             pass=`cat $listener_file | getlistenerproperty PASSWORDS_${listener_name} PASSWORDS_${listener_name} | tr -s ";" ""`
#####             pass=`grep -i "PASSWORDS_${listener_name}" $listener_file | awk -F"=" '{print $2}'` 
             if [ -z $pass ] ; then
                         infor "$NOK - Listener: $listener_name configurado en $listener_file  DEBE tener seteado:" ""
                         inforsis "$NOK - Listener: $listener_name configurado en $listener_file  DEBE tener seteado:" ""
                         infor "\t\tPASSWORDS_${listener_name}=(password-propia-listener)" ""
                         inforsis "\t\tPASSWORDS_${listener_name}=(password-propia-listener)" ""
                         infor "\t\t porque LOCAL_OS_AUTHENTICATE_${listener_name}=OFF" ""
                         inforsis "\t\t porque LOCAL_OS_AUTHENTICATE_$cadauno=OFF" ""
                         fix "AG.1.5.1" "Modifique fichero $listener_file"
                         fix "AG.1.5.1" "Setear PASSWORDS_${listener_name} si va a mantener" 
                         fix "AG.1.5.1" "LOCAL_OS_AUTHENTICATE_${listener_name}=OFF" 
                         res=1
             else
                         infor "$OK - Listener: $listener_name configurado en $listener_file  tiene PASSWORDS_${listener_name} con password" ""
                         inforsis "$OK - Listener: $listener_name configurado en $listener_file tiene PASSWORDS_${listener_name} con password" ""
             fi
         else
             infor "$OK - Listener: $listener_name configurado en $listener_file  tiene LOCAL_OS_AUTHENTICATE=ON" ""
             inforsis "$OK - Listener: $listener_name configurado en $listener_file  tiene LOCAL_OS_AUTHENTICATE=ON" ""
         fi          
    else
        infor "$OK - Listener: $listener_name configurado en $listener_file  tiene LOCAL_OS_AUTHENTICATE=ON por defecto" ""
        inforsis "$OK - Listener: $listener_name configurado en $listener_file  tiene LOCAL_OS_AUTHENTICATE=ON por defecto" ""
    fi
done   

if [ $res -eq 0 ]
then
    TEXTO_TECH="$OK  No existen Listeners con LOCAL_OS_AUTHENTICATE_<listener>=OFF" 
else
    TEXTO_TECH="$NOK Existe algun Listener con LOCAL_OS_ATHENTICATE_<listener>=OFF y no tiene PASSWORDS_<listener>" 
    fix "$LIN" ""
fi
   
echo -e $TEXTO_TECH

}
########################################################################################################
####   AG.1.5.2  
####
###************     ficheros   listener.ora   NO deben configurar el servicio LISTENER_*** en el puerto 1521 (puerto default) ********
###************     se busca los LISTENERS activos, y se revisan sus ficheros de configuracion listener.ora 
###************     para informar que deben cambiar el puerto si es 1521 

ag_1_5_2_port_1521 ()
{
inforsis "AG.1.5.2"  "Network Settings - Listeners ports <> default-port 1521"
inforsis "        "  "los ficheros listener.ora que usen el default port 1521 en algun LISTENER activo" 
inforsis "        "  "deben reconfigurarse a otro puerto, aunque varias BDs podrian usar el mismo puerto\n"

res=0

########  para que root pueda ejecutar comandos "svrctl o lsnrctl, debe tener el PATH seteado al principio con $ORACLE_GRID/bin
setear_entorno_network

########  obtenemos la lista de listener activos revisando los procesos "tnslsnr"
lista_listener=`ps -ef |  grep "tnslsnr" |grep -v grep | awk '{print $9}'`     ####  devuelve los nombres de los listener activos

for listener_name in $lista_listener
do
######    buscamos el listener_file que le corresponde a este listener, teniendo en cuenta que puede ser un Single Client Access Listener o un Cluster Ready Listener
          ERRCLUSTER=`srvctl config listener -l ${listener_name} | grep "PRCN-2066"`      #####  type Single Client Access Name Listener
          if [ -n "$ERRCLUSTER" ] ; then
                  listener_file=`lsnrctl status ${listener_name} | grep -i "listener parameter file" | awk '{print $4}'`
                  listener_port=`lsnrctl status ${listener_name} | grep "PORT=" | sed -nr 's/.*PORT=(.*)\)+\)+\)/\1/p'`
          else
               ORAHOME=`srvctl config listener -l ${listener_name} | grep Home | awk '{print $2}'`       ####   es un listener cluster ready
               listener_port=`srvctl config listener -l ${listener_name} | grep "End points" | awk -F":" '{print $3}'`
               if [ -d "$ORAHOME" ] ; then
                   listener_file="$ORAHOME/network/admin/listener.ora"    #####  aqui ORAHOME es directorio, pero en algun caso ORAHOME = <CRS home> , no un directorio
               else
                   echo "$ORAHOME" | grep -q "CRS"         ####   caso ORAHOME= <CRS home>  que debe coincidir con CRS_HOME extraido de inventory.xml 'CRS="true"'
                   if [ $? -eq 0 ] ; then
                        CRS_HOME=`grep CRS_HOME $DIR/envfile* |grep -v grep | awk -F"=" '{print $2}'`
                        listener_file="$CRS_HOME/network/admin/listener.ora"
                   else
                        listener_file=""
                   fi
               fi  
           fi
           if [ -z $listener_file ] ; then
                TEXTO_TECH="$NOK - no se encuentra listener.ora para listener $listener_name"
                echo -e $TEXTO_TECH
                res=1
                return
           fi 
           
           if [ "${listener_port}" = "1521" ]
           then
                infor "$NOK - listener: $listener_name, utiliza el PORT=1521" ""
                inforsis "$NOK - listener: $listener_name, utiliza el PORT=1521" ""
                infor  "      Modifique si es posible el Listener Parameter File: \n     $listener_file \n      y use otro puerto\n" ""
                inforsis  "      Modifique si es posible el Listener Parameter File: \n     $listener_file \n     y use otro puerto\n" ""
                fix "AG.1.5.2" "Listener $listener_name, usa puerto 1521 en su fichero de configuracion"
                fix "AG.1.5.2" "Modifique si es posible, fichero: $listener_file" 
                fix "AG.1.5.2" "y use otro puerto"
                fix "$LIN" ""
                res=1
           else
                infor "$OK - listener: $listener_name, utiliza el PORT=${listener_port}" ""
                inforsis "$OK - listener: $listener_name, utiliza el PORT=${listener_port}"
           fi
done
if [ $res -eq 0 ] ; then
     TEXTO_TECH="$OK - No existen listener activos que usen el puerto 1521"
     RES=0
else
     TEXTO_TECH="$NOK - Existe algun listener activo que usa el puerto 1521 prohibido"
     RES=1
fi
echo -e $TEXTO_TECH
}


####*******************************************************************************
####    AG.1.5.3  no puede haber listeners con el default NAME=LISTENER
###############################################################################33
ag_1_5_3_listener_name ()
{

inforsis "AG.1.5.3" "Network Settings - Default LISTENER name  - no permitido"
inforsis "        " "Si existe algun listener con nombre LISTENER, modifiquelo si es posible\n"

res=0
########  para que root pueda ejecutar comandos "svrctl o lsnrctl, debe tener el PATH seteado al principio con $ORACLE_GRID/bin
setear_entorno_network

########  obtenemos la lista de listener activos revisando los procesos "tnslsnr"
lista_listener=`ps -ef |  grep "tnslsnr" |grep -v grep | awk '{print $9}'`     ####  devuelve los nombres de los listener activos

for listener_name in $lista_listener
do
######    buscamos el listener_file que le corresponde a este listener, teniendo en cuenta que puede ser un Single Client Access Listener o un Cluster Ready Listener
          ERRCLUSTER=`srvctl config listener -l ${listener_name} | grep "PRCN-2066"`      #####  type Single Client Access Name Listener
          if [ -n "$ERRCLUSTER" ] ; then
                  listener_file=`lsnrctl status ${listener_name} | grep -i "listener parameter file" | awk '{print $4}'`
          else
               ORAHOME=`srvctl config listener -l ${listener_name} | grep Home | awk '{print $2}'`       ####   es un listener cluster ready
               if [ -d "$ORAHOME" ] ; then
                   listener_file="$ORAHOME/network/admin/listener.ora"    #####  aqui ORAHOME es directorio, pero en algun caso ORAHOME = <CRS home> , no un directorio
               else
                   echo "$ORAHOME" | grep -q "CRS"         ####   caso ORAHOME= <CRS home>  que debe coincidir con CRS_HOME extraido de inventory.xml 'CRS="true"'
                   if [ $? -eq 0 ] ; then
                        CRS_HOME=`grep CRS_HOME $DIR/envfile* |grep -v grep | awk -F"=" '{print $2}'`
                        listener_file="$CRS_HOME/network/admin/listener.ora"
                   else
                        listener_file=""
                   fi
               fi  
           fi
           
           if [ "${listener_name}" = "LISTENER" ] 
           then
                    infor "$NOK - listener: $listener_name  Usa Default name en fichero: \n     $listener_file \n" ""
                    inforsis "$NOK - listener: $listener_name  Usa Default name en fichero: \n     $listener_file \n" ""
                    fix "AG.1.5.3" "Listener $lismalo, usa default LISTENER name, en su fichero de configuracion"
                    fix "AG.1.5.3" "Modifique si es posible, fichero: $listener_file" 
                    fix "AG.1.5.3" "y cambie a otro nombre de listener"
                    fix "$LIN" ""
                    res=1
           else
                    infor "$OK - listener name: $listener_name  - no es default name" ""
                    inforsis "$OK - listener name: $listener_name  - no es default name" ""
           fi
done 
if [ $res -eq 0 ]
then
    TEXTO_TECH="$OK - No existe ningun listener con default name LISTENER"
    RES=0
else
    TEXTO_TECH="$NOK - Existen listeners que usan Default name LISTENER"
    RES=1
fi

echo -e $TEXTO_TECH
}
##################################################################################      
#### AG.1.5.4
# Oracle just released Security Alert CVE-2012-1675 to address the .TNS Listener Poison Attack in the Oracle Database.  
# With a CVSS Base Score of 7.5, this vulnerability is remotely exploitable without authentication, and if successfully exploited, 
# can result in a full compromise of the targeted Database. 
#
# Customers on single-node configurations (i.e., non Real Application Cluster (RAC) customers) should refer to the My Oracle Support Note titled: 
# Using Class of Secure Transport (COST) to Restrict Instance Registrationr: (Doc ID 1453883.1) 
# to limit registration to the local node and the IPC protocol through the COST (Class Of Secure Transport) feature in the listener.
#
# RAC and Exadata customers should refer to the My Oracle Support Note:
# Using Class of Secure Transport (COST) to Restrict Instance Registration in Oracle RAC. (Doc ID 1340831.1) 
# to implement similar COST restrictions.  
# Note that implementing COST restrictions in RAC environments require the use of SSL/TLS encryption.  
# Such network encryption features were previously only available to customers who were licensed for Oracle Advanced Security.  
# However, RAC customers who were previously not licensed for Oracle Advanced Security need not be concerned about a licensing restriction
# as Oracle has updated its licensing to allow these customers the use of these features (namely SSL and TLS) 
# to protect themselves against vulnerability CVE-2012-1675.  
# In other words, Oracle has added Oracle Advanced Security SSL/TLS to the Enterprise Edition Real Application Clusters (Oracle RAC) 
# and RAC One Node options, and added Oracle Advanced Security SSL/TLS to the Oracle Database Standard Edition license when used with the Real Application Clusters. 
#
# High sev security vulnerability identified this configuration as strongly advised and this has come out as a high sev APAR to all oracle registered accounts.

# no miramos los listeners de GRID y AGENT

ag_1_5_4_listener_secure_register ()
{
####***************PARAMETRO SECURE_REGISTER_<listener> must be set   en ficheros   listener.ora   ********************************************
inforsis "AG.1.5.4"  "Network Settings - Set parameter SECURE_REGISTER_<listenername> in listener.ora (Oracle 10.2.0.3 or higher)"
inforsis "        "  "Class of Secure Transport (COST) is used to restrict instance registration with listeners"
inforsis "        "  "to only local and authorized instances having appropriate credentials."
inforsis "        "  "See Oracle Support Notes 1340831.1(RAC) & 1453883.1(single instance), Addresses Oracle Security Alert CVE-2012-1675"
inforsis "        "  "Note that implementing COST restrictions in RAC environments require the use of SSL/TLS encryption"
inforsis "        "  "High sev security vulnerability identified this configuration as strongly advised and this has come out as a high sev APAR to all oracle registered accounts."
res=0

setear_entorno_network

########  obtenemos la lista de listener activos revisando los procesos "tnslsnr"
lista_listener=`ps -ef |  grep "tnslsnr" |grep -v grep | awk '{print $9}'`     ####  devuelve los nombres de los listener activos

for listener_name in $lista_listener
do
######    buscamos el listener_file que le corresponde a este listener, teniendo en cuenta que puede ser un Single Client Access Listener o un Cluster Ready Listener
     ERRCLUSTER=`srvctl config listener -l ${listener_name} | grep "PRCN-2066"`      #####  type Single Client Access Name Listener
     if [ -n "$ERRCLUSTER" ] ; then
            listener_file=`lsnrctl status ${listener_name} | grep -i "listener parameter file" | awk '{print $4}'`
     else
            ORAHOME=`srvctl config listener -l ${listener_name} | grep Home | awk '{print $2}'`       ####   es un listener cluster ready
            if [ -d "$ORAHOME" ] ; then
                   listener_file="$ORAHOME/network/admin/listener.ora"    #####  aqui ORAHOME es directorio, pero en algun caso ORAHOME = <CRS home> , no un directorio
            else
                   echo "$ORAHOME" | grep -q "CRS"         ####   caso ORAHOME= <CRS home>  que debe coincidir con CRS_HOME extraido de inventory.xml 'CRS="true"'
                   if [ $? -eq 0 ] ; then
                        CRS_HOME=`grep CRS_HOME $DIR/envfile* |grep -v grep | awk -F"=" '{print $2}'`
                        listener_file="$CRS_HOME/network/admin/listener.ora"
                   else
                        listener_file=""
                   fi
            fi  
    fi
    if [ -z $listener_file ] ; then
            TEXTO_TECH="$NOK - no se encuentra listener.ora para listener $listener_name"
            echo -e $TEXTO_TECH
            res=1
            return
    fi 
           
    grep -q -i "SECURE_REGISTER_${listener_name}" $listener_file
    if [ $? -eq 0 ]
    then
              valor=`cat $listener_file | getlistenerproperty SECURE_REGISTER_${listener_name} SECURE_REGISTER_${listener_name}| tr -s ";" ""`
              infor "$OK - listener name: $listener_name  - SECURE_REGISTER_${listener_name}=$valor" ""
              inforsis "$OK - listener name: $listener_name  - SECURE_REGISTER_${listener_name}=$valor" ""
    else
              res=1
              infor "$NOK - listener: $listener_name  - SECURE_REGISTER_${listener_name} must be set in \n    $listener_file \n" ""
              inforsis "$NOK - listener: $listener_name  - SECURE_REGISTER_${listener_name} must be set in \n    $listener_file \n" ""
              fix "AG.1.5.4" "SECURE_REGISTER_listener_name parameter is used to specify the transports on which registration requests are to be accepted."
              fix "AG.1.5.4" "Listener parameter: SECURE_REGISTER_${listener_name}=(transport1,transport2,...) must be set in ${listener_file}"
              fix "AG.1.5.4" "with apropiate COST (Class Of Secure Transport)  to restrict instance registration"
              fix "AG.1.5.4" "Example:  SECURE_LISTENER_${listener_name}=(tcp,ipc)"
              fix "AG.1.5.4" "For RAC environments require the use of SSL/TLS encryption"
              fix "AG.1.5.4" "See Oracle Support Notes 1340831.1 (RAC) & 1453883.1 (single instance)"
              fix "AG.1.5.4" "where instruct you to solve this concern"
              fix "AG.1.5.4" "++++++++++++++++++++++++++++++++++++++++++++++"
    fi
done
if [ $res -eq 0 ]
then
    TEXTO_TECH="$OK - Todos los listeners tienen seteado SECURE_REGISTER_<listener>"
else
    TEXTO_TECH="$NOK - Existen listeners que deben setear SECURE_REGISTER_<listener> con los transportes apropiados"
    RES=1
    fix "$LIN" ""
fi

echo -e $TEXTO_TECH
}

#######################################################################################
####   AG.1.7.1  USUARIOS 'SYS', 'SYSTEM'   no pueden tener DEFAULT PASSWORDS
####
ag_1_7_1_defpwd ()
{
ins=$1

inforora "AG.1.7.1" "Identify and Authenticate Users - Admin accounts 'SYS', 'SYSTEM' no pueden tener default passwords"
inforora "Note: Unless required by the Applications, only active users need to be checked."
inforora "Change the passwords for any active accounts that the DBA_USERS_WITH_DEFPWD view lists.\n"

res=0
CHECKFILE=/tmp/passdefault.lst
####grep -e "no rows" -e "ninguna fila seleccionada" $CHECKFILE >/dev/null 2>/dev/null
####if [ $? = 0 ] ; then
if [ ! -s $CHECKFILE ] ; then
    infor "$OK: --- instancia: $ins --- Los usuarios 'SYS' y 'SYSTEM' no tienen default passwords\n" ""
    inforora "$OK: --- instancia: $ins --- Los usuarios 'SYS' y 'SYSTEM' no tienen default passwords\n" ""
    TEXTO_TECH=`printf "$OK: --- instancia: $ins --- 'SYS', 'SYSTEM' Users no tienen default password.\n"`
else
    res=`awk -F";" 'BEGIN {resul=0;} 
                          {user=$1;
                           status=$2; 
                           if(status~"EXPIRED|LOCKED") next;
                           resul=1;
                          }
                    END {print resul;}' $CHECKFILE` 
    awk -F";" -v OK=$OK -v NOK=$NOK -v ins=$ins '{user=$1;
                                                  status=$2; 
                                                  if(status~"EXPIRED|LOCKED") 
                                                     printf("%s: --- instancia: %s --- %-35s Status: %-20s\n",OK,ins,user,status); 
                                                  else 
                                                     printf("%s: --- instancia: %s --- %-35s Status: %-20s\n",NOK,ins,user,status);
                                                 }' $CHECKFILE | tee -a $INFORME | tee -a $INFORMEORA >/dev/null  
    if [ $res -eq 1 ]
    then
        u1=`awk -F";" '{gsub(" ","",$1);user=$1;
                           status=$2; 
                           if(status~"EXPIRED|LOCKED") next;
                           umalos=user" "umalos;
                          }
                    END {print umalos;}' $CHECKFILE` 
         awk -F";" '{user=$1;
                     status=$2; 
                     if(status~"EXPIRED|LOCKED") next; 
                     else 
                        print "AG.1.7.1;SENTENCIA para asignar passwords a user "user;
                        print "AG.1.7.1;sql;alter user "user" identified by nueva-password;";
                        }}' $CHECKFILE >> $FIXORA 
    fi
    inforora "${LIN}\n" ""
    if [ $res -eq 1 ]
    then
          TEXTO_TECH=`printf "$NOK: --- instancia: $ins --- Users ' $u1' tienen default password.\n"`
          fixora "$LIN" ""
    else
          TEXTO_TECH=`printf "$OK: --- instancia: $ins --- 'SYS', 'SYSTEM' Users no tienen default password.\n"`
    fi
fi
echo -e  "$TEXTO_TECH"
rm -f /tmp/passdefault.lst 
}
#######################################################################################
####   AG.1.7.3  USUARIOS ORACLE PRODUCT(Service)   no pueden tener DEFAULT PASSWORDS
####
ag_1_7_3_defpwd ()
{
ins=$1

inforora "AG.1.7.3" "Identify and Authenticate Users - Users ORACLE PRODUCT (Service)  no pueden tener default passwords"
inforora "Note: Unless required by the Applications, only active users need to be checked."
inforora "Change the passwords for any active accounts that the DBA_USERS_WITH_DEFPWD view lists."
inforora "Oracle recommends that you do not assign these accounts passwords that they may have had in previous releases of Oracle Database."

### infor "Oracle Product (Service) users considerados:" ""
### 
### USUARIOS CREADOS POR DEFAULT EN LA CREACION DE LA BASE DE DATOS
###
### infor "ANONYMOUS : Account that allows HTTP access to Oracle XML DB. It is used in place of the APEX_PUBLIC_USER account when the Embedded PL/SQL Gateway (EPG) is installed in the database. EPG is a Web server that can be used with Oracle Database. It provides the necessary infrastructure to create dynamic applications. See also XDB."
### infor "APEX_030200: Oracle Application Express Suite. The account owns the Application Express schema and metadata to create web based applications."
### infor "APEX_PUBLIC_USER: Oracle Application Express Suite. The account owns the Application Express schema and metadata to create web based applications."
### infor "FLOW_FILES: Oracle Application Express Suite. The account owns the Application Express schema and metadata to create web based applications."
### infor "APPQOSSYS : Used for storing/managing all data and metadata required by Oracle Quality of Service Management"
### infor "CTXSYS : Oracle Text administrator user. Enables the building of text query applications and document classification applications."
### infor "DBSNMP : Oracle Enterprise Manager to monitor and manage the database. Password is created at installation or database creation time."
### infor "DIP : Oracle DIP provisioning service when connecting to the database. User to synchronize the changes in Oracle Internet Directory with the applications in the database."
### infor "EXFSSYS : The account used internally to access the EXFSYS schema, which is associated with the Rules Manager and Expression Filter feature."
### infor "MDDATA : The schema used by Oracle Spatial for storing Geocoder and router data. "
### infor "MDSYS : The Oracle Spatial and Oracle Multimedia Locator administrator account. "
### infor "MGMT_VIEW: An account used by Oracle Enterprise Manager Database Control. Password is randomly generated at installation or database creation time. Users do not need to know this password." 
### infor "OLAPSYS : Stored outlines for optimizer plan stability"
### infor "ORACLE_OCM : Owner of packages used by Oracle Configuration Manager"
### infor "ORDDATA : This account contains the Oracle Multimedia DICOM data model."
### infor "ORDPLUGINS : Oracle Multimedia (Object Relational Data ORD), Plug-ins supplied by Oracle and third-party. User used by Time Series, Multimedia and applications to store, manage, and retrieve images, audio, video,"
### infor "ORDSYS : The Oracle Multimedia administrator account. (Object Relational Data (ORD) User used by Time Series, etc.)"
### infor "OUTLN : The account that supports plan stability. Plan stability prevents certain database environment changes from affecting the performance characteristics of applications by preserving execution plans in stored outlines. OUTLN acts as a role to centrally manage metadata associated with stored outlines."
### infor "OWBSYS : The account for administrating the Oracle Warehouse Builder repository. Access this account during the installation process to define the base language of the repository and to define Warehouse Builder workspaces and users. A data warehouse is a relational or multidimensional database that is designed for query and analysis."
### infor "OWBSYS_AUDIT : This account is used by the Warehouse Builder Control Center Agent to access the heterogeneous execution audit tables in the OWBSYS schema."
### infor "SI_INFORMTN_SCHEMA : The account that stores the information views for the SQL/MM Still Image Standard. See also ORDPLUGINS and ORDSYS."
### infor "SPATIAL_CSW_ADMIN_USR : The Catalog Services for the Web (CSW) account. It is used by the Oracle Spatial CSW cache manager to load all record type metadata, and record instances from the database into the main memory for the record types that are cached. See also SPATIAL_WFS_ADMIN_USR, MDDATA and MDSYS."
### infor "SPATIAL_WFS_ADMIN_USR : The Web Feature Service (WFS) account. It is used by the Oracle Spatial WFS cache manager to load all feature type metadata, and feature instances from the database into main memory for the feature types that are cached. See also SPATIAL_CSW_ADMIN_USR , MDDATA and MDSYS."
### infor "SYSMAN : The account used to perform Oracle Enterprise Manager database administration tasks. The SYS and SYSTEM accounts can also perform these tasks. Password is created at installation or database creation time."
### infor "WMSYS : The account used to store the metadata information for Oracle Workspace Manager."
### infor "XDB : The account used for storing Oracle XML DB data and metadata. See also ANONYMOUS."
### infor "XS$NULL : An internal account that represents the absence of a user in a session. Because XS$NULL is not a user, this account can only be accessed by the Oracle Database instance. XS$NULL has no privileges and no one can authenticate as XS$NULL, nor can authentication credentials ever be assigned to XS$NULL."
###
### USUARIOS QUE NO ESTAN CREADOS POR DEFAULT EN LA CREACION DE LA BASE DE DATOS
###
### infor "AWR_STAGE : Used to load data into the AWR from a dump file"
### infor "CSMIG : User for Database Character Set Migration Utility"
### infor "LBACSYS : Label Based Access Control owner when Oracle Label Security (OLS) option is used"
### infor "WK_TEST : The instance administrator for the default instance, WK_INST. After unlocking this account and assigning this user a password, then the cached schema password must also be updated using the administration tool Edit Instance Page. Ultra Search provides uniform search-and-location capabilities over multiple repositories, such as Oracle databases, other ODBC compliant databases, IMAP mail servers, HTML documents managed by a Web server, files on disk, and more. See also WKSYS"
### infor "WKSYS : An Ultra Search database super-user. WKSYS can grant super-user privileges to other users, such as WK_TEST. All Oracle Ultra Search database objects are installed in the WKSYS schema. See also WK_TEST"
### infor "WKPROXY : An administrative account of Application Server Ultra Search."
### infor "DMSYS  : Oracle Data Mining" 
### infor "DSSYS : Oracle Dynamic Services and Syndication Server"
### infor "PERFSTAT : Oracle Statistics Package (STATSPACK) that supersedes UTLBSTAT/UTLESTAT"
### infor "TRACESVR : Oracle Trace server"
### infor "TSMSYS : User for Transparent Session Migration (TSM) a Grid feature"
### infor "AURORA$JIS$UTILITY$ : "
### infor "AURORA$ORB$UNAUTHENTICATED : Used for users who do not authenticate in Aurora/ORB "

CHECKFILE=/tmp/passdefault_product_service.lst
res=0
###grep -e "no rows" -e "ninguna fila seleccionada" $CHECKFILE >/dev/null 2>/dev/null
###if [ $? = 0 ] ; then
if [ ! -s $CHECKFILE ] ; then
    infor "$OK: --- instancia: $ins --- Los usuarios ORACLE PRODUCT (Service)  no tienen passwords por default\n" ""
    inforora "$OK: --- instancia: $ins --- Los usuarios ORACLE PRODUCT (Service)  no tienen passwords por default\n$LIN" ""
    TEXTO_TECH=`printf "$OK: --- instancia: $ins --- Usuarios ORACLE PRODUCT (Service)  no tienen default password.\n"`
else
    sed -i '/ rows /d' $CHECKFILE
    sed -i '/^$/d' $CHECKFILE
    res=`awk -F";" 'BEGIN {resul=0;} 
                          {user=$1;
                           status=$2; 
                           if(status~"EXPIRED|LOCKED") next;
                           resul=1;
                          }
                    END {print resul;}' $CHECKFILE` 
    awk -F";" -v OK=$OK -v NOK=$NOK -v ins=$ins '{gsub(" ","",$1);user=$1;
                                                  gsub("  ","",$2);status=$2; 
                                                  if(status~"EXPIRED|LOCKED") 
                                                     printf("%s: --- instancia: %s --- %-25s tiene default password y Status: %-21s\n",OK,ins,user,status); 
                                                  else 
                                                     printf("%s: --- instancia: %s --- %-25s tiene default password y Status: %-21s\n",NOK,ins,user,status);
                                                  }' $CHECKFILE | tee -a $INFORME | tee -a $INFORMEORA >/dev/null  
    if [ $res -eq 1 ]
    then
        u1=`awk -F";" '{gsub(" ","",$1);user=$1;
                           status=$2; 
                           if(status~"EXPIRED|LOCKED") next;
                           umalos=user" "umalos;
                          }
                    END {print umalos;}' $CHECKFILE` 
         awk -F";" '{user=$1;
                     status=$2; 
                     if(status~"EXPIRED|LOCKED") next; 
                     else 
                        print "AG.1.7.3;SENTENCIA para asignar passwords a user "user" (Atencion a recomendaciones Oracle):";
                        print "AG.1.7.3;sql;alter user "user" identified by nueva-password;";
                        print "AG.1.7.3;sql;alter user "user" account lock;";
                        }}' $CHECKFILE >> $FIXORA 
    fi
    inforora "${LIN}\n" ""
    if [ $res -eq 1 ]
    then
          TEXTO_TECH=`printf "$NOK: --- instancia: $ins --- ORACLE PRODUCT users ' $u1' tienen default password.\n"`
          fixora "$LIN" ""
    else
          TEXTO_TECH=`printf "$OK: --- instancia: $ins --- Usuarios ORACLE PRODUCT (Service)  no tienen default password.\n"`
    fi
fi
echo -e  "$TEXTO_TECH"
rm -f /tmp/passdefault_product_service.lst 
}

#######################################################################################
####   AG.1.7.4  USUARIOS 'SCOTT' , 'ADAMS', 'JONES', 'CLARK', 'BLAKE', 'HR', 'OE', 'SH' 
####   Removed or locked on production systems.  For Oracle ERP, the use of hr, oe, and sh are required to support the application
####   Note: Note: Unless required by the Applications, only active users need to be checked.

ag_1_7_4_oracledemousers ()
{
ins=$1

inforora "AG.1.7.4" "Identify and Authenticate Users - Remove or lock DEMO Users SCOTT, ADAMS, JONES, CLARK, BLAKE, HR, OE, SH in Production Databases"
inforora "Note: Unless required by the Applications, only active users need to be checked."
inforora "For Oracle ERP, the use of hr, oe, and sh are required to support the application."

CHECKFILE=/tmp/oracledemousers.lst
####grep -e "no rows" -e "ninguna fila seleccionada" $CHECKFILE >/dev/null 2>/dev/null
####if [ $? -eq 0 ] ; then
if [ ! -s $CHECKFILE ] ; then
    infor "$OK: --- instancia: $ins --- ALL DEMO Users (SCOTT, ADAMS, JONES, CLARK, BLAKE, HR, OE, SH) no existen o estan locked\n" ""
    inforora "$OK: --- instancia: $ins --- ALL DEMO Users (SCOTT, ADAMS, JONES, CLARK, BLAKE, HR, OE, SH) no existen o estan locked\n$LIN" ""
    TEXTO_TECH=`printf "$OK: --- instancia: $ins --- DEMO Users (SCOTT,ADAMS, JONES, CLARK, BLAKE, HR, OE, SH) no existen o estan locked"`
else
    sed -i '/ rows /d' $CHECKFILE
    sed -i '/^$/d' $CHECKFILE
    res=`awk -F";" 'BEGIN {resul=0;} 
                          {user=$1;
                           status=$2; 
                           if(user=="HR"||user=="OE"||user=="SH") next; 
                           if(status~"EXPIRED|LOCKED") next;
                           resul=1;
                          }
                    END {print resul;}' $CHECKFILE` 
    awk -F";" -v OK=$OK -v NOK=$NOK -v ins=$ins '{user=$1;
                                                  status=$2; 
                                                  if(user=="HR"||user=="OE"||user=="SH") 
                                                     {printf("%s: --- instancia: %s --- %-35s Status: %-20s\n",OK,ins,user,status); next;}
                                                  if(status~"EXPIRED|LOCKED") 
                                                     printf("%s: --- instancia: %s --- %-35s Status: %-20s\n",OK,ins,user,status); 
                                                  else 
                                                     printf("%s: --- instancia: %s --- %-35s Status: %-20s\n",NOK,ins,user,status);
                                                 }' $CHECKFILE | tee -a $INFORME | tee -a $INFORMEORA >/dev/null  
    if [ $res -eq 1 ]
    then
         u1=`awk -F";" '{gsub(" ","",$1); user=$1;
                         status=$2; 
                         if(status~"EXPIRED|LOCKED") next;
                         umalos=user" "umalos;
                          }
                    END {print umalos;}' $CHECKFILE` 
         awk -F";" '{user=$1;
                     status=$2; 
                     if(user=="HR"||user=="OE"||user=="SH") next; 
                     if(status~"EXPIRED|LOCKED") next; 
                     else 
                        { print "AG.1.7.4;SENTENCIA para eliminar o lockear user "user; 
                          print "AG.1.7.4;Recuerde que un usuario conectado a la base de datos, no puede eliminarse.";
                          print "AG.1.7.4;sql;alter user "user" account lock; o bien";
                          print "AG.1.7.4;sql;drop user "user" cascade;";
                        }}' $CHECKFILE >> $FIXORA 
    fi
    inforora "${LIN}\n" ""
    if [ $res -eq 1 ]
    then
          TEXTO_TECH=`printf "$NOK: --- instancia: $ins --- Algun DEMO Users ' $u1 ' existe o no esta locked"`
          fixora "$LIN" ""
    else
          TEXTO_TECH=`printf "$OK: --- instancia: $ins --- DEMO Users (SCOTT,ADAMS, JONES, CLARK, BLAKE, HR, OE, SH) no existen o estan locked"`
    fi
fi
echo -e  "$TEXTO_TECH"
rm -f /tmp/oracledemousers.lst 

}
#######################################################################################
####   AG.1.7.5  USUARIO 'DBSNMP'  
####   Removed or locked if no remote database maintenance
####   Note: Unless required by the Applications, only active users need to be checked.

ag_1_7_5_dbsnmpuser ()
{
ins=$1

inforora "AG.1.7.5" "Identify and Authenticate Users - Remove or lock User 'DBSNMP' if no remote database maintenance"
inforora "Note: Unless required by the Applications, only active users need to be checked."

res=0
CHECKFILE=/tmp/dbsnmpuser.lst
###grep -e "no rows" -e "ninguna fila seleccionada" $CHECKFILE >/dev/null 2>/dev/null
###if [ $? = 0 ] ; then
if [ ! -s $CHECKFILE ] ; then
    infor "$OK: --- instancia: $ins --- User DBSNMP no existe o esta locked\n" ""
    inforora "$OK: --- instancia: $ins --- User DBSNMP no existe o esta locked\n$LIN" ""
    TEXTO_TECH=`printf "$OK: --- instancia: $ins --- User DBSNMP no existe o esta locked"`
else
    sed -i '/ rows /d' $CHECKFILE
    sed -i '/^$/d' $CHECKFILE
    res=`awk -F";" 'BEGIN {resul=0;} 
                          {user=$1;
                           status=$2; 
                           if(status~"EXPIRED|LOCKED") next;
                           resul=1;
                          }
                    END {print resul;}' $CHECKFILE` 
    awk -F";" -v OK=$OK -v NOK=$NOK -v ins=$ins '{gsub(" ","",$1);user=$1;
                                                  status=$2; 
                                                  if(status~"EXPIRED|LOCKED") 
                                                     printf("%s: --- instancia: %s --- %-35s tiene default password y Status: %-20s\n",OK,ins,user,status); 
                                                  else 
                                                     printf("%s: --- instancia: %s --- %-35s tiene default password y Status: %-20s\n",NOK,ins,user,status);
                                                 }' $CHECKFILE | tee -a $INFORME | tee -a $INFORMEORA >/dev/null  
    if [ $res -eq 1 ]
    then
        u1=`awk -F";" '{gsub(" ","",$1);user=$1;
                           status=$2; 
                           if(status~"EXPIRED|LOCKED") next;
                           umalos=user" "umalos;
                          }
                    END {print umalos;}' $CHECKFILE` 
         awk -F";" '{user=$1;
                     status=$2; 
                     if(status~"EXPIRED|LOCKED") next; 
                     else 
                        print "AG.1.7.5;SENTENCIA para eliminar  user "user" o lockear";
                        print "AG.1.7.5;Recuerde que un usuario conectado a la base de datos, no puede eliminarse.";
                        print "AG.1.7.5;sql;alter user "user" account lock; o bien";
                        print "AG.1.7.5;sql;drop user "user" cascade;";
                        }}' $CHECKFILE >> $FIXORA 
    fi
    inforora "${LIN}\n" ""
    if [ $res -eq 1 ]
    then
          TEXTO_TECH=`printf "$NOK: --- instancia: $ins  User DBSNMP  no debe existir o estar locked."`
          fixora "$LIN" ""
    else
          TEXTO_TECH=`printf "$OK: --- instancia: $ins --- User DBSNMP no existe o esta locked"`
    fi
fi
echo -e  "$TEXTO_TECH"
rm -f /tmp/dbsnmpuser.lst 

}
###########################################################################################
### AG.1.7.6
###    General Users Roles/Privileges: CONNECT, RESOURCE (role or equivalent privilege grant)             
###    Excluding the Oracle service accounts and DBA userids, these are the only privileges and roles 
###    which may be granted to a non-DBA or non-Oracle service user
###    - se añaden a excluding users:   LOCKED accounts, y OPS$ISYSAD1  (usuario SEGUR)
ag_1_7_6_privgeneral ()
{
ins=$1

inforora "AG.1.7.6" "Identify and Authenticate Users - General Users Roles/Privileges:" 
inforora "        " "Only CONNECT, RESOURCE (role or equivalent privilege grant) may be granted" 
inforora "        " "Excluding Oracle service account and DBA userids, these are the only privileges and roles"
inforora "        " "which may be granted to a non-DBA or non-Oracle service users"
inforora "        " "Se excluyen adicionalmente LOCKED accounts y OPS$ISYSAD1 (SEGUR)"

res=0

CHECKFILE=/tmp/privgeneral.lst
###grep -e "no rows" -e "ninguna fila seleccionada" $CHECKFILE >/dev/null 2>/dev/null
###if [ $? = 0 ] ; then
if [ ! -s $CHECKFILE ] ; then
    infor "$OK: --- instancia: $ins --- General Users Roles/Privileges permited: CONNECT, RESOURCE" ""
    inforora "$OK: --- instancia: $ins --- General Users Roles/Privileges permited: CONNECT, RESOURCE" ""
    TEXTO_TECH="$OK: --- instancia: $ins --- General Users Roles/Privileges solo tiene privilegios CONNECT, RESOURCE"
else
       res=1
       infor "$NOK:  --- Instancia: $ins -- Existen General Users con mas privilegios que  CONNECT, RESOURCE\n" ""
       inforora "$NOK:  --- Instancia: $ins -- Existen General Users con mas privilegios que  CONNECT, RESOURCE\n" ""
       linea="----------------------------------------------------------------------------------"
       awk -F";" -v lin=$linea 'BEGIN {printf("%-20s %-30s %-10s\n%s\n","USER","GRANTED ROLE/PRIVILEGE","TIPO",lin)} {printf("%-20s %-30s %-10s\n",$1,$2,$3);} END {print "\n";}' $CHECKFILE | tee -a $INFORME | tee -a $INFORMEORA >/dev/null 
       fixora "AG.1.7.6" "SENTENCIAS para quitar privilegios a usuarios generales que no sean CONNECT, RESOURCE"  
       fixora "AG.1.7.6" "Evalue cuidadosamente la revocacion de privilegios"
       grep -v rows $CHECKFILE | awk -F";" '{print "AG.1.7.6;sql;REVOKE " $2 " FROM " $1 ";"$3;}' >> $FIXORA
       echo -e "$LIN\n" >> $FIXORA
       TEXTO_TECH="$NOK: --- instancia: $ins --- Existen General Users con mas privilegios que CONNECT, RESOURCE"
fi
echo -e $TEXTO_TECH
rm -f /tmp/privgeneral.lst
}
###########################################################################################
### AG.1.7.7 
### Direct login on this ID should not be enabled. Access should be via sudo.
### Note:  this restriction applies to the production databases only; 
### the restriction does not necessarily apply to other environments unless specified.  
### An individual must logon as themselves and .sudo. to Oracle ID for UNIX and Linux.
### Actualmente usamos el acceso a oracle a traves de la siguiente conf de /etc/sudoers
###
###    User_Alias SYSDMO_ADMDB=admdb01,admdb02
###    Cmnd_Alias SYSDMO_ADMDB_CMD=/bin/su [-] oracle,/bin/su oracle,/bin/su [-] ora*,/bin/su ora*
###    SYSDMO_ADMDB ALL=(root) NOPASSWD:SYSDMO_ADMDB_CMD
###
### Esto permite ejecutar a "admdb01" y "admdb02" (pedidos por SEGUR) ejecutar el comando: 
###    sudo -u root su - oracle
###
### Para que los usuarios "oracle" no puedan tener direct login, propondremos un :!!: en el segundo campo del /etc/shadow del user oracle
### Se hicieron pruebas, y esto evita el direct login, acepta el su - oracle desde root, pero no permite el ssh a este user a menos que existan claves cruzadas
### que el Oracle RAC necesita. Esta techspec tendra que estar excepcionada para los Oracle RAC porque hacen conexiones ssh entre las maquinas del cluster
### (sin ssh authorized_keys con las claves cruzadas indicando from=, el cluster dejaria de funcionar si "oracle" pasa a tener :!!:
### Para las maquinas con single instance, debe haber un :!!: en /etc/shadow, y el authorized_keys de los usuarios "oracle" no debe tener lineas validas.
### Para verificar si la maquina es un RAC, se usara la consulta oracle: "select count(*) from gv$instance;" 
### que marca cuantas maquinas hay dentro del cluster. Si este contador da 1, es una single instance, si > 1 entonces es un RAC.
### En caso de cumplir que no permite direct login en /etc/shadow, falta comprobar que no se hagan direct login mediante SSH a menos que 
### sean un Oracle RAC que lo requiere mediante claves SSH cruzadas, en cuyo caso es una "EXCEPCION"

#####  funcion que verifica que un auhtorized_keys file tiene claves SSH con from=hosts_RAC

function check_ssh_from_hosts 
{
   AUTHORIZEDFILE=$1
   softowner=$2
   host=$3

   TMPFILE=tmpfile
   > $TMPFILE 
   if [ -z "$host" ]
   then
#######   todas son single instances del softowner,  el authorized_keys no debe tener ninguna SSK key
      grep -v "^#" "$AUTHORIZEDFILE" | grep -v "^$" > $TMPFILE
      if [ -s $TMPFILE ]
      then
          RES1=1     #####   solo con single instances, esto es incorrecto
      else
          RES1=0     #####   solo con single instances, esto es correcto
      fi
   else 
#######   existe alguna instancia que es RAC, que obliga a tener un authorized_keys para softowner, esto permite direct login, pero solo para los hostnames del RAC
      if [ -e "$AUTHORIZEDFILE" ]  
      then
           grep -v "^$" "$AUTHORIZEDFILE" | grep -v "^#" | cat -n | while read -r entryline
           do
  echo $entryline | awk -v ok=$OK -v nok=$NOK -v listahh=$host -v owner=$softowner '{if($2 ~ "from=") 
                                                                                       { i=match($2,"from=.*[[:space:]]") ;
                                                                                         hh=substr($2,i+6);
                                                                                         c=split(hh,a,",");
                                                                                         for(i=1;i<=c;i++)
                                                                                            if (a[i] ~ listahh)
                                                                                                { print ok":   (" owner " admite conexiones SSH from="a[i] ; 
                                                                                                  exit; }}}' > $TMPFILE
         done  
#######  si TMPFILE  esta vacio, significa que autorized_keys de softowner, no tiene ninguna linea con from=host
         if [ !  -s $TMPFILE ]       
         then
               RES1=1     ######    en caso de RAC , esto es incorrecto
         else
               RES1=0     #####     en caso de RAC,  esto es correcto porque tiene un from=  para el host
         fi
      else
         RES1=2      #####   no existe authorized_keys (incorrecto=RAC)
      fi
   fi

rm -f $TMPFILE

return $RES1

}


ag_1_7_7_direct_login ()
{
softowner=$1

DIRECT_LOGIN=`awk -F":" -v ow="$softowner" '$1 ~ ow {if ( $2 ~ "!!" || $2 ~ "*" ){print 0} else {print 1}}' /etc/shadow`  ## da 1 si tiene password (nok), 0 si esta bloqueado (ok) 

####  si DIRECT_LOGIN=0   el user esta bloqueado para hacer direct login pero hay que comprobar mas cosas
####     hay que comprobar si es un ORACLE RAC o una single instance.
####     en caso de single instance ya es correcto
####     en caso de RAC, se debe comprobar que el user tiene SSH authorized_keys con los from=  de todos los miembros del cluster
####     y ademas se debe revisar que exista en el /etc/sudoers las lineas del su - oracle para root 
####  SI direct_login=1   el user no esta bloqueado, entonces debe dar NOK, aunque sea RAC y tenga todo lo demas bien.

if [ $DIRECT_LOGIN -eq  1 ] 
then
    res=1
    echo -e "$NOK - Usuario $softowner  tiene direct login acces habilitado mediante password en /etc/shadow" >> direct_login 
    fix "AG.1.7.7" "Modificar /etc/shadow  para user $softowner y cambiar el 2-do campo a :!!: para bloquear su direct login access"
    fix "$LIN" ""
    MODO="/etc/shadow"
else
    HOME_SOFTOWNER=`awk -F":" -v ow=$"softowner" '$1 ~ ow {print $6}' /etc/passwd`

################    buscamos fichero authorized_keys   del user softowner
    SSHCONFIG=/etc/ssh/sshd_config
    AUTHORIZEDFILE=`grep AuthorizedKeysFile $SSHCONFIG`
    if [ -z "$AUTHORIZEDFILE" ]
    then
          AUTHORIZEDFILE="AuthorizedKeysFile %h/.ssh/authorized_keys"
    fi
    AUTHORIZEDFILE=`echo $AUTHORIZEDFILE | awk 'NF==2 {printf("%s",$NF);exit;}
                                                     {for(i=2;i<=NF;i++) printf(" %s",$i);}'`
    HOMEROOT=`grep "^$softowner:" /etc/passwd | awk -F":" '{print $6}' | awk -F"/" '{printf("%s",$1);
                                                                              for(i=2;i<=NF;i++)
                                                                                   {printf("\\\/%s",$i);}}'`
    HOMEROOT2=`grep "^$softowner:" /etc/passwd | awk -F":" '{print $6}'`
    if [[ "$AUTHORIZEDFILE" == ".ssh/authorized_keys" ]] 
    then
           AUTHORIZEDFILE=$HOMEROOT2/.ssh/authorized_keys 
    else
           AUTHORIZEDFILE=`echo "$AUTHORIZEDFILE" | sed "s/\%h/$HOMEROOT/g" | sed "s/\%u/$softowner/g"`
    fi
#####################################################################    fin de buscar authorized_keys   de softowner

    FICHEROS_INSTANCIAS_SOFTOWNER=`grep -l -w "ORACLE_USER=$softowner" $DIR/envfile*`

#####################################################################
###  ahora debemos determinar si user softowner tiene alguna instancia que es parte de un RAC, solo entonces es admisible un "authorized_keys"
###  si no hay ninguna instancia de RAC, entonces authorized_keys no debe existir para evitar el direct login a traves de SSH, o si existe
###  no debe tener ninguna SSH public key valida
###  si existen instancias RAC, entonces solo los hostnames de las instancias RAC pueden estar presentes en el authorized_keys

    inst_RAC=""
    inst_single=""

    for ENVFILE in $FICHEROS_INSTANCIAS_SOFTOWNER
    do
        ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
        cant_instances=`runuser -l $softowner -c "$SHEL ${ENVFILE} ; sqlplus -s /nolog @$DIR/single_rac_instance.sql" | tr -d " "` 
        if [ $cant_instances -eq 1 ]      ######  es una single instance
        then
            inst_single="$ins $inst_single"
        else
            inst_RAC="$ins $inst_RAC"
        fi
    done            
   
################   si todas las instancias son single, la variable inst_RAC estara vacia 
    if [ -z $inst_RAC ]
    then
        if [ ! -e  "$AUTHORIZEDFILE" ]
        then
             echo -e "$OK : User $softowner has direct login access inhabilited via /etc/shadow and via SSH.(solo single instances) " >> direct_login 
        else
           if [ -s "$AUTHORIZEDFILE"  ]
           then
               check_ssh_from_hosts "$AUTHORIZEDFILE" $softowner ""
               res=$?
               if [ $res -eq 1 ]
               then
                 MODO="SSH"
                 echo -e "$NOK : User $softowner tiene inhabilitado  direct login  via /etc/shadow pero permite direct login via SSH" >> direct_login
                 fix "AG.1.7.7" "User $softowner tiene inhabilitado  direct login  via /etc/shadow pero permite direct login via SSH"
                 fix "AG.1.7.7" "Debe eliminarse a menos que use instancias de Cluster RAC"
                 fix "AG.1.7.7" "De momento no detectamos instancias de clusters RAC, de modo que elimine fichero $AUTHORIZEDFILE o comente sus lineas"
                 fix "$LIN" ""
                 res=1
               else
                 echo -e "$OK : User $softowner has direct login acces inhabilited via /etc/shadow and via SSH.(solo single instances)" >> direct_login
               fi
           else
              echo -e "$OK : User $softowner has direct login access inhabilited via /etc/shadow and via SSH.(solo single instances)" >> direct_login 
           fi 
        fi
    else
################   los hostnames de las instancias RAC, deben estar incluidos en el softowner authorized_keys con formato "from=hostname"
        for ins in $inst_RAC
        do
             ENVFILE=$DIR/envfile_$ins
             lista_hosts=`runuser -l $softowner -c "$SHEL ${ENVFILE} ; sqlplus -s /nolog @$DIR/rac_instance.sql" | awk -F";" '{printf("%s ",$2)}'` 
             for host1 in `echo $lista_hosts`
             do 
               HOST1=`echo $host1 | awk -F"." '{print $1}' | tr '[:lower:]' '[:upper:]'`
               echo $HOST | grep -q -i $HOST1     #####  el propio host no interesa porque no debe estar incluido en su propio authorized_keys
               if [ $? -eq 1 ]
               then

                  check_ssh_from_hosts $AUTHORIZEDFILE $softowner $host1     #####  verifica que el softowner en su auhtorized_keys tiene claves SSH con from=host1
                  res=$?
                  if [ $res -eq 0 ]
                  then
                      echo -e "$OK - EXCEPTION : User $softowner has SSH Public KEYS with from=$host1 specification for Cluster_RAC instance $ins " >> direct_login 
                  else
                      if [ $res -eq 1 ]
                      then
                          echo -e "$NOK : User $softowner must set SSH Public KEYS in $AUTHORIZEDFILE with from=$host1 specification for Cluster RAC instance $ins" >> direct_login
                          fix "AG.1.7.7" "User $softowner tiene inhabilitado direct login via /etc/shadow, y tiene instances de cluster RAC"
                          fix "AG.1.7.7" "pero el $AUTHORIZEDFILE no especifica from=$host1 en la SSH Key"  
                          fix "AG.1.7.7" "Modifique $AUTHORIZEDFILE e incluya las SSH Public Keys con 'from=$host1' para cluster RAC instance $ins"
                          MODO="SSH"
                      else
                          echo -e "$NOK : User $softowner no posee un $AUTORIZEDFILE que permita los accesos SSH entre los hostname de cluster RAC instance $ins" >> direct_login
                          fix "AG.1.7.7" "User $softowner tiene inhabilitado direct login via /etc/shadow, y tiene instances de cluster RAC"
                          fix "AG.1.7.7" "pero no existe $AUTHORIZEDFILE con las SSH Keys de los hostnames de la instancia $ins" 
                          fix "AG.1.7.7" "Crear $AUTHORIZEDFILE para user $softowner para los hostnames de la instancia $ins" 
                          res=1
                      fi
                      fix "$LIN" ""
                  fi
               fi
             done
         done
     fi
fi

if [ $res -eq 0 ] 
then
    TEXTO_TECH="$OK  - User $softowner : Direct login no habilitado o existe una excepcion para Cluster RAC"
else
    TEXTO_TECH="$NOK - User $softowner : Direct login habilitado via $MODO"
fi
echo -e $TEXTO_TECH

}

###########################################################################################
### AG.1.7.8 
###    Oracle software owner ID Oracle software owner OS group 
###    Restricted to  DBAs
###    Restrict users assigned to the oracle software owner ID group (typically dba/oinstall)
###    Note:  this restriction applies to the production databases only; 
###           the restriction does not necessarily apply to other environments unless specified.  
###           DBAs have discretion in further limiting privileges for non-DBA userids over those listed here 
###           if privileges can affect the availability and viability of the database (in any environment). 
###
###    Se pide que los DBAs sean los unicos usuarios que pertenecen al OSDBA group or oinstall
###    DBA groups solo deben contener oracle software owners
###########################################################################################
group_users ()
{
######   en Linux, el fichero /etc/group no tiene la lista completa de usuarios miembros de un grupo
######   los usuarios cuyo group primario esta en /etc/passwd, pueden no aparecer como miembros del grupo en /etc/group
######   y el grupo tiene una lista vacia de usuarios aunque el grupo tiene miembros.
######   Para ver la lista real de usuarios miembros de un grupo, se debe encontrar a todos los usuarios que tienen a ese grupo
######   como grupo primario en /etc/passwd  +  añadir la lista de usuarios adicionales que aparecen en /etc/group para ese grupo
grupo=$1     ####   nombre del grupo
usrgrupo=$2  ####   en esta variable guardamos el resultado
gid=`grep "^${grupo}:" /etc/group | awk -F":" '{print $3}'`     ### obtengo el gid del grup
gidusersprim=`awk -F":" -v gid=$gid '{if($4==gid) {printf("%s ",$1);}}' /etc/passwd`
gidusersgrp=`grep "^${grupo}:" /etc/group | awk -F":" '{print $4}' | awk -F"," '{for (i=1;i<=NF;i++){printf("%s ",$i)}}'`
usersgrupo=""
for user in $gidusersprim $gidusersgrp
do
    echo $usersgrupo | grep -q $user    ####   quitamos los duplicados
    if [ $? -eq 1 ]
    then
        if [ -z $usersgrupo ] ; then
            usersgrupo="$user"
        else
            usersgrupo="$usersgrupo $user"
        fi
    fi
done
eval $usrgrupo="'$usersgrupo'"
}


ag_1_7_8_software_owner_groups ()
{

listausuariosDBA=$1

ORACLEHOME=$1

unset softowner
unset osdbagroup
unset grupoinstallsoft

CONFIGC=$ORACLEHOME/rdbms/lib/config.c

if [ -e $CONFIGC ]
then
  if [ "$ORACLEHOME" != "$ORACLE_AGENT" ]
  then
     osdbagroup=`grep "#define" $CONFIGC | grep "SS_DBA_GRP" | tail -1 | awk '{print $3}' | tr -d '"'`
     softowner=`grep "^ORACLE_OWNER=" $ORACLEHOME/install/utl/rootmacro.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
     grupoinstallsoft=`grep "^OSDBA_GROUP=" $ORACLEHOME/install/utl/rootmacro.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
  fi
fi

if [ "$ORACLEHOME" = "$ORACLE_AGENT" ]
then
    if [ -e $ORACLE_AGENT/root.sh ]; then
        if [ `grep -c "^ORACLE_OWNER" $ORACLE_AGENT/root.sh` -gt 0 ] ; then
            softowner=`grep "^ORACLE_OWNER=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2); }'`
            osdbagroup=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
            grupoinstallsoft=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
        else
           if [ `grep -c "gcroot.sh" $ORACLE_AGENT/root.sh |  grep -v "^#"` -gt 0 ] ; then
                 buscafile=`grep "gcroot.sh" $ORACLE_AGENT/root.sh |tail -1`
                 if [ -f $buscafile ] ; then
                     softowner=`grep "^ORACLE_OWNER" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                     osdbagroup=`grep "^OSDBA_GROUP=" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                     grupoinstallsoft=`grep "^OSDBA_GROUP=" $buscafile |tail -1 | awk -F"=" '{printf("%s",$2);}'`
                 fi
           fi
        fi
    fi
fi

[ -z $softowner ] && [ -z $osdbagroup ] && [ -z $grupoinstallsoft ] && infor "$ORACLEHOME : no encuentra Software Owner, OSDBA_GROUP, OSDBA_INSTALL" && inforsis "$ORACLEHOME : no encuentra Software Owner, OSDBA_GROUP, OSDBA_INSTALL" && res=0 && return
 
unset listagrupo1
unset listagrupo2

group_users $osdbagroup listagrupo1
group_users $grupoinstallsoft listagrupo2

umalos1=""
umalos2=""

res=0
for u1 in $listagrupo1 
do
    if [[ $u1 != $softowner ]] 
    then           
        umalos1="$umalos1 $u1"
        res=1
    fi
done
for u1 in $listagrupo2
do
    if [[ $u1 != $softowner ]] 
    then           
        umalos2="$umalos2 $u1"
        res=1
    fi
done
if [ ! -z $umalos1 ]
then
 if [ "$ORACLEHOME" = "$ORACLE_HOME" ]
 then
    infor "$NOK: ORACLE_HOME=$ORACLE_HOME : Group '$osdbagroup' (OSDBA Group) tiene usuarios '$umalos1' que no son 'DBAs' (softowner=$softowner)" 
    inforsis "$NOK: ORACLE_HOME=$ORACLE_HOME : Group '$osdbagroup' (OSDBA Group) tiene usuarios '$umalos1' que no son 'DBAs' (softowner=$softowner)" 
 fi
 if [ "$ORACLEHOME" = "$ORACLE_GRID" ]
 then
    infor "$NOK: ORACLE_GRID=$ORACLE_GRID : Group '$osdbagroup' (OSDBA Group) tiene usuarios '$umalos1' que no son 'DBAs' (softowner=$softowner)" 
    inforsis "$NOK: ORACLE_GRID=$ORACLE_GRID : Group '$osdbagroup' (OSDBA Group) tiene usuarios '$umalos1' que no son 'DBAs' (softowner=$softowner)" 
 fi
 if [ "$ORACLEHOME" = "$ORACLE_AGENT" ]
 then
    infor "$NOK: ORACLE_AGENT=$ORACLE_AGENT : Group '$osdbagroup' (OSDBA Group) tiene usuarios '$umalos1' que no son 'DBAs' (softowner=$softowner)" 
    inforsis "$NOK: ORACLE_AGENT=$ORACLE_AGENT : Group '$osdbagroup' (OSDBA Group) tiene usuarios '$umalos1' que no son 'DBAs'" 
 fi
 fix "AG.1.7.8" "Los usuarios '$umalos1'  deben quitarse del grupo $osdbagroup"
 res=1
fi
if [ ! -z $umalos2 ]
then
 if [ "$ORACLEHOME" = "$ORACLE_HOME" ]
 then
    infor "$NOK: ORACLE_HOME=$ORACLE_HOME : Group '$grupoinstallsoft' (Oracle DB software) tiene usuarios '$umalos2' que no son 'DBAs' (softowner=$softowner)" 
    inforsis "$NOK: ORACLE_HOME=$ORACLE_HOME : Group '$grupoinstallsoft' (Oracle DB software) tiene usuarios '$umalos2' que no son 'DBAs' (softowner=$softowner)" 
 fi
 if [ "$ORACLEHOME" = "$ORACLE_GRID" ]
 then
    infor "$NOK: ORACLE_GRID=$ORACLE_GRID : Group '$grupoinstallsoft' (Oracle GRID software) tiene usuarios '$umalos2' que no son 'DBAs' (softowner=$softowner)" 
    inforsis "$NOK: ORACLE_GRID=$ORACLE_GRID : Group '$grupoinstallsoft' (Oracle GRID software) tiene usuarios '$umalos2' que no son 'DBAs' (softowner=$softowner)" 
 fi
 if [ "$ORACLEHOME" = "$ORACLE_AGENT" ]
 then
    infor "$NOK: ORACLE_AGENT=$ORACLE_AGENT : Group '$grupoinstallsoft' (Oracle Agent) tiene usuarios '$umalos2' que no son 'DBAs' (softowner=$softowner)" 
    inforsis "$NOK: ORACLE_AGENT=$ORACLE_AGENT : Group '$grupoinstallsoft' (Oracle Agent) tiene usuarios '$umalos2' que no son 'DBAs' (softowner=$softowner)" 
 fi
 fix "AG.1.7.8" "Los usuarios '$umalos2'  deben quitarse del grupo '$grupoinstallsoft'"
 res=1
 
fi
if [ $res -eq 0 ]
then
  if [ "$ORACLEHOME" = "$ORACLE_HOME" ]
  then
       infor "$OK: ORACLE_HOME=$ORACLE_HOME : Group '$osdbagroup' (OSDBA Group) solo contiene Oracle-DB-software owners: $listagrupo1"
       infor "$OK: ORACLE_HOME=$ORACLE_HOME : Group '$grupoinstallsoft' (Oracle DB software) solo contiene Oracle-DB-software owners:  $listagrupo2"
       inforsis "$OK: ORACLE_HOME=$ORACLE_HOME : Group '$osdbagroup' (OSDBA Group) solo contiene Oracle-DB-software owners: $listagrupo1"
       inforsis "$OK: ORACLE_HOME=$ORACLE_HOME : Group '$grupoinstallsoft' (Oracle DB software) solo contiene Oracle-DB-software owners:  $listagrupo2"
  fi
  if [ "$ORACLEHOME" = "$ORACLE_GRID" ]
  then
       infor "$OK: ORACLE_GRID=$ORACLE_GRID : Group '$osdbagroup' (OSDBA Group) solo contiene Oracle-DB-software owners: $listagrupo1"
       infor "$OK: ORACLE_GRID=$ORACLE_GRID : Group '$grupoinstallsoft' (Oracle GRID software) solo contiene Oracle-GRID-software owners: $listagrupo2"
       inforsis "$OK: ORACLE_GRID=$ORACLE_GRID : Group '$osdbagroup' (OSDBA Group) solo contiene Oracle-DB-software owners: $listagrupo1"
       inforsis "$OK: ORACLE_GRID=$ORACLE_GRID : Group '$grupoinstallsoft' (Oracle GRID software) solo contiene Oracle-GRID-software owners: $listagrupo2"
  fi
  if [ "$ORACLEHOME" = "$ORACLE_AGENT" ]
  then
       infor "$OK: ORACLE_AGENT=$ORACLE_AGENT : Group '$osdbagroup' (OSDBA Group) solo contiene Oracle-DB-software owners: $listagrupo1"
       infor "$OK: ORACLE_AGENT=$ORACLE_AGENT : Group '$grupoinstallsoft' (Oracle Agent) solo contiene Oracle-Agent-software owners: $listagrupo2"
       inforsis "$OK: ORACLE_AGENT=$ORACLE_AGENT : Group '$osdbagroup' (OSDBA Group) solo contiene Oracle-DB-software owners: $listagrupo1"
       inforsis "$OK: ORACLE_AGENT=$ORACLE_AGENT : Group '$grupoinstallsoft' (Oracle Agent) solo contiene Oracle-Agent-software owners: $listagrupo2"
  fi
fi
if [ $res -eq 1 ]
then
  if [ "$ORACLEHOME" = "$ORACLE_HOME" ]
  then
    TEXTO_TECH="$NOK: ORACLE_HOME: $ORACLE_HOME : Existen Users no DBAs que pertenecen a grupos de Oracle-software-owners restringidos"
  fi
  if [ "$ORACLEHOME" = "$ORACLE_GRID" ]
  then
    TEXTO_TECH="$NOK: ORACLE_GRID: $ORACLE_GRID : Existen Users no DBAs que pertenecen a grupos de Oracle-software-owners restringidos"
  fi
  if [ "$ORACLEHOME" = "$ORACLE_AGENT" ]
  then
    TEXTO_TECH="$NOK: ORACLE_AGENT: $ORACLE_AGENT : Existen Users no DBAs que pertenecen a grupos de Oracle-software-owners restringidos"
  fi
else
  if [ "$ORACLEHOME" = "$ORACLE_HOME" ]
  then
    TEXTO_TECH="$OK: ORACLE_HOME: $ORACLE_HOME: Los grupos relacionados con (OSDBA, Oracle DB software) solo tienen Users 'DBAs'"
  fi
  if [ "$ORACLEHOME" = "$ORACLE_GRID" ]
  then
    TEXTO_TECH="$OK: ORACLE_GRID: $ORACLE_GRID: Los grupos relacionados con (OSDBA, Oracle GRID software) solo tienen Users 'DBAs'"
  fi
  if [ "$ORACLEHOME" = "$ORACLE_AGENT" ]
  then
    TEXTO_TECH="$OK: ORACLE_AGENT: $ORACLE_AGENT: Los grupos relacionados con (OSDBA, Oracle AGENT) solo tienen Users 'DBAs'"
  fi
fi
echo -e $TEXTO_TECH
}


###########################################################################################

### AG.1.7.9.1
###    Rol DBA Granted only to DBAs and Oracle service accounts (where required) in all database environments             
ag_1_7_9_1_privdba ()
{
ins=$1

inforora "AG.1.7.9.1" "Identify and Authenticate Users - DBA Roles granted only to DBAs and Oracle service accounts:" 

res=0
sed -i "/^$/d" /tmp/privdba.lst
if [ ! -s /tmp/privdba.lst  ] ; then
    infor "$OK: --- instancia: $ins --- DBA Roles granted only to DBAs and Oracle service accounts\n" ""
    inforora "$OK: --- instancia: $ins --- DBA Roles granted only to DBAs and Oracle service accounts\n" ""
    TEXTO_TECH="$OK: --- instancia: $ins --- DBA Roles granted only to DBAs and Oracle service accounts"
else
       res=1
       infor "$NOK: --- instancia: $ins --- Existen usuarios con DBA Roles y no son DBAs o Oracle service accounts\n" ""
       inforora "$NOK: --- instancia: $ins --- Existen usuarios con DBA Roles y no son DBAs o Oracle service accounts\n" ""
       TEXTO_TECH="$NOK: --- instancia: $ins --- Existen usuarios con DBA Roles y no son DBAs o Oracle service accounts"
       infor "Para corregir, se debe quitar el rol DBA al usuario o al anteultimo subrol asociado a DBA" ""
       inforora "Para corregir, se debe quitar el rol DBA al usuario o al anteultimo subrol asociado a DBA" ""
       infor "Si existen mas usuarios vinculados a subroles asociados a DBA " ""
       infor "y desea conservar el rol DBA para algun usuario debera redefinir sus roles asociados" ""
       inforora "Si existen mas usuarios vinculados a subroles asociados a DBA " ""
       inforora "y desea conservar el rol DBA para algun usuario debera redefinir sus roles asociados" ""
       linea="----------------------------------------------------------------------------------"
       awk -F":" -v lin=$linea 'BEGIN {printf("%-20s %-30s\n%s\n","USER","GRANTED ROLEs",lin)} {for(i=2;i<=NF;i++){printf("%-20s ",$i)};printf("\n");} END {print "\n";}' /tmp/privdba.lst | tee -a $INFORME | tee -a $INFORMEORA >/dev/null 
       fixora "AG.1.7.9.1" "SENTENCIAS para quitar roles DBA a usuarios que no son 'SYS', 'SYSTEM' o Oracle Service"  
       fixora "AG.1.7.9.1" "Nota: Si rol DBA asociado a un usuario:"
       fixora "AG.1.7.9.1" "         -Se propone quitar rol DBA a usuario"
       fixora "AG.1.7.9.1" "      Si existen roles intermedios con privilegio DBA "
       fixora "AG.1.7.9.1" "         -Se propone quitar privilegio DBA al anteultimo rol previo al DBA"
       fixora "AG.1.7.9.1" "          pero si dicho rol previo esta asociado a mas usuarios debe evaluar "
       fixora "AG.1.7.9.1" "          cuidadosamente la revocacion de privilegios DBA a roles"
       grep -v rows /tmp/privdba.lst | awk -F":" '{ print "AG.1.7.9.1;"$0 ; 
                                                    print "AG.1.7.9.1;sql;REVOKE DBA FROM " $(NF-1) ";";}' >> $FIXORA
       echo -e "$LIN\n" >> $FIXORA
fi
echo -e $TEXTO_TECH
rm -f /tmp/privdba.lst
}
###########################################################################################
### AG.1.7.9.2
###    Privilege SYSDBA, SYSOPER Granted only to DBAs and Oracle service accounts (where required) in all database environments             
ag_1_7_9_2_privsysdbaoper ()
{
ins=$1
res=0

inforora "AG.1.7.9.2" "Identify and Authenticate Users - Privilege SYSDBA, SYSOPER granted only to DBAs and Oracle service accounts:" 

sed -i "/^$/d" /tmp/privsysdbaoper.lst
if [ ! -s /tmp/privsysdbaoper.lst  ] ; then
    infor "$OK: --- instancia: $ins --- Privilege SYSDBA, SYSOPER granted only to DBAs and Oracle service accounts\n" ""
    inforora "$OK: --- instancia: $ins --- Privilege SYSDBA, SYSOPER granted only to DBAs and Oracle service accounts\n" ""
    TEXTO_TECH="$OK: --- instancia: $ins --- Privileges SYSDBA, SYSOPER granted only to DBAs and Oracle service accounts"
    cat /tmp/privsysdbaoper.lst | tee -a $INFORME | tee -a $INFORMEORA >/dev/null
else
       res=1
       infor "$NOK: --- instancia: $ins --- Privileges SYSDBA, SYSOPER are granted to users other than DBAs and Oracle service accounts\n" ""
       inforora "$NOK: --- instancia: $ins --- Privileges SYSDBA, SYSOPER are granted to users other than DBAs and Oracle service accounts\n" ""
       TEXTO_TECH="$NOK: --- instancia: $ins --- Privileges SYSDBA, SYSOPER are granted to users other than DBAs and Oracle service accounts"
       linea="----------------------------------------------------------------------------------"
       grep -v rows /tmp/privsysdbaoper.lst | awk -F":" -v lin=$linea 'BEGIN {printf("%-20s %-5s %-5s\n%s\n","USER","SYSDBA","SYSOPER",lin)} {printf("%-20s %-6s %-6s\n",$1,$2,$3);printf("\n");} END {print "\n";}' | tee -a $INFORME | tee -a $INFORMEORA >/dev/null 
       fixora "AG.1.7.9.2" "SENTENCIAS para quitar privilegio SYSDBA/SYSOPER a usuarios que no son 'SYS', 'SYSTEM' o Oracle Service"  
       fixora "AG.1.7.9.2" "Evalue cuidadosamente la revocacion de privilegios"
       grep -v rows /tmp/privsysdbaoper.lst | awk -F":" '{ print "AG.1.7.9.2;"$0 ; 
                                                           if($2 != 'TRUE') print "AG.1.7.9.2;sql;REVOKE SYSDBA FROM "$1 ";";
                                                           if($3 != 'TRUE') print "AG.1.7.9.2;sql;REVOKE SYSOPER FROM " $1 ";"}' >> $FIXORA
       echo -e "$LIN\n" >> $FIXORA
fi
echo -e $TEXTO_TECH
rm -f /tmp/privsysdbaoper.lst
}
##########################################################################################
### AG.1.7.12 
###     Do not use 'dba' group name  for the OSDBA group
###     Changing this group from the generic name makes attacking the OS harder
###     Note. This is a requirement for new builds and should be discussed with the DBA prior to retrofitting this into existing environments.
###
###     El oracle software owner  debe pertenecer al OSDBA group  
###     el OSDBA group se determina durante la instalacion del producto, y se setea en el fichero:
###     $ORACLE_HOME/rdbms/lib/config.c
###     en la linea: 
###     #define SS_DBA_GRP "grupo"   (donde en la mayoria de los casos "grupo" es "dba"
###  
###     Los usuarios que existan dentro del OSDBA group, son los usuarios que tendran privilegio SYSDBA y se podran conectar 
###     a las BDs como connect / as sysdba
###
###     Si tuviera que cambiarse este grupo despues de la instalacion del producto 
###     podria afectar al funcionamiento de todas las BDs que se vinculan a un determinado ORACLE_HOME
###     de modo que esta muy desaconsejado realizar el siguiente procedimiento por la afectacion que puede producir.
###     Por este motivo la techspec permite mantener el 'dba' como OSDBA group si es una instalacion antigua.
###     Procedimiento:
###     1. Crear un grupo nuevo:  dbadmin
###           # groupadd dbadmin
###     2. Añadir al oracle software owner (por ej, "ora11g") al grupo "dbadmin" 
###           # usermod -a -G dbadmin ora11g
###     3. Parar la base de datos y su listener
###           # su - ora11g
###           $ sqlplus / as sysdba
###           SQL> shutdown immediate
###           SQL> quit
###           $ lsnrctl stop
###     4. Hacer una copia de backup para el fichero config.c
###           cp $ORACLE_HOME/rdbms/lib/config.c $ORACLE_HOME/rdbms/lib/config.c.bak
###     5. Modificar el fichero config.c y cambiar el grupo 'dba' por 'dbadmin'
###           vi $ORACLE_HOME/rdbms/lib/config.c
###                #define SS_DBA_GRP "dba"  ===>  #define SS_DBA_GRP "dbadmin"
###     6. Relink  Oracle
###           cd $ORACLE_HOME/rdbms/lib
###           mv config.o config.o.copia
###           make -f ins_rdbms.mk ioracle
###     7. Volver a arrancar la BD y el listener
###           # su - ora11g
###           $ lsnrctl start
###           $ sqlplus / as sysdba
###           SQL> startup
###           SQL> quit
### 
###
###################################################################################################################################
ag_1_7_12_osdba_group ()
{
#infor "AG.1.7.12" "Do not use dba name for the OSDBA group for new buildings" 
#inforsis "AG.1.7.12" "Identify and Authenticate Users - Do not use dba name for the OSDBA group for new buildings" 

unset osdbagroup

ORACLEHOME=$1
res=0
CONFIGC=$ORACLEHOME/rdbms/lib/config.c

ORACLE_AGENT=`grep ORACLE_AGENT $DIR/envfile* | awk -F"=" '{print $2}'`

CONFIGC=$ORACLEHOME/rdbms/lib/config.c

if [ -e $CONFIGC ]
then
  if [ "$ORACLEHOME" != "$ORACLE_AGENT" ]
  then
     osdbagroup=`grep "#define" $CONFIGC | grep "SS_DBA_GRP" | tail -1 | awk '{print $3}' | tr -d '"'`
  fi

else
    if [ "$ORACLEHOME" = "$ORACLE_AGENT" ]
    then
        if [ -e $ORACLE_AGENT/root.sh ]; then
          if [ `grep -c "^OSDBA_GROUP" $ORACLE_AGENT/root.sh` -gt 0 ] ; then
            osdbagroup=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
          else
             if [ `grep -c "gcroot.sh" $ORACLE_AGENT/root.sh |  grep -v "^#"` -gt 0 ] ; then
                 buscafile=`grep "gcroot.sh" $ORACLE_AGENT/root.sh |tail -1`
                 if [ -f $buscafile ] ; then
                     osdbagroup=`grep "^OSDBA_GROUP=" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                 fi
             fi
          fi
        fi
     else
        if [ -e $ORACLEHOME/oraInst.loc ] 
        then
             osdbagroup=`grep "inst_group" $ORACLEHOME/oraInst.loc | awk -F"=" '{print $2}'`
        else
             infor "Software Oracle desconocido, revise su configuracion para determinar su OSDBA group y que no sea 'dba'"
             inforsis "Software Oracle desconocido, revise su configuracion para determinar su OSDBA group y que no sea 'dba'"
        fi
    fi
fi

if [ "$osdbagroup" = "dba" ]
then
         infor "$NOK:  ORACLE_HOME: $ORACLEHOME -- 'dba' group es el OSDBA group "
         infor "Nota: Si esta instalacion es nueva, debe reconsiderar el uso de otro grupo distinto de 'dba' como OSDBA"
         infor "      Si es una instalacion antigua, el uso del OSDBA group 'dba' esta permitido" ""
         inforsis "$NOK:  ORACLE_HOME: $ORACLEHOME -- 'dba' group es el OSDBA group "
         inforsis "Nota: Si esta instalacion es nueva, debe reconsiderar el uso de otro grupo distinto de 'dba' como OSDBA"
         inforsis "      Si es una instalacion antigua, el uso del OSDBA group 'dba' esta permitido" ""
         fix "AG.1.7.12" "ORACLE_HOME: $ORACLEHOME -- 'dba' group es el OSDBA group "
         fix "AG.1.7.12" "Do not use OSDBA group 'dba' name for new buildings"
         fix "AG.1.7.12" "Si no es una instalacion nueva, 'dba' puede permanecer como OSDBA group"
         echo "$LIN" >> $FIXES
         res=1
         TEXTO_TECH="$NOK:  ORACLE_HOME: $ORACLEHOME -- 'dba' group es OSDBA group" 
else
     if [ -z $osdbagroup ] ; then
         infor "$NOK:  ORACLE_HOME=$ORACLEHOME -- Software desconocido - OSDBA group no seteado"
         inforsis "$NOK:  ORACLE_HOME=$ORACLEHOME -- Software desconocido - OSDBA group no seteado"
         TEXTO_TECH="$NOK:  ORACLE_HOME=$ORACLEHOME -- Software desconocido - OSDBA group no seteado"
     else 
         infor "$OK:  ORACLE_HOME=$ORACLEHOME -- OSDBA group '$osdbagroup' es correcto" ""
         inforsis "$OK:  ORACLE_HOME=$ORACLEHOME -- OSDBA group '$osdbagroup' es correcto" ""
         TEXTO_TECH="$OK:  ORACLE_HOME=$ORACLEHOME -- OSDBA group '$osdbagroup' es correcto"
     fi
fi
      
echo -e $TEXTO_TECH
}

##########################################################################################
###  AG.1.7.14
###                 CTXSYS User should not exist or must be locked
####                CTXSYS PACKAGES no deben dar  ningun privilegio from PUBLIC
ag_1_7_14_ctxsys_user ()
{                      
ins=$1

inforora "AG.1.7.14.1" "Identify Admin account CTXSYS for Oracle Text feature"
infor "AG.1.7.14.1" "Identify Admin account CTXSYS for Oracle Text feature"

res=0
user="CTXSYS"
accountstatus=`cat /tmp/ctxsysuser.lst | grep "CTXSYS" | awk '{for(i=2;i<=NF;i++){printf("%s ",$i);}}'`
echo "$accountstatus" | egrep -q -E "LOCKED" 
if [ $? -eq 0 ]
then
       TEXTO=`printf "$OK: --- instancia: $ins --- %-10s exists with Status: %-20s.\n" "$user" "$accountstatus"`
       infor "${TEXTO}\n" ""
       inforora "${TEXTO}\n" ""
       TEXTO_TECH=`printf "$OK: --- instancia: $ins --- CTXSYS User exists and is $accountstatus"`
else
       infor "$NOK:  --- Instancia: $ins -- CTXSYS User exists:  if context is not being used then drop CTXSYS user" ""
       infor "$NOK:  --- Instancia: $ins -- CTXSYS User exists:  if context is being used then lock CTXSYS user" ""
       inforora "$NOK:  --- Instancia: $ins -- CTXSYS User exists:  if context is not being used then drop CTXSYS user" ""
       inforora "$NOK:  --- Instancia: $ins -- CTXSYS User exists:  if context is being used then lock CTXSYS user" ""
       res=1
       fixora "AG.1.7.14.1" "SENTENCIA para eliminar o lockear  user $user "
       fixora "AG.1.7.14.1" "Recuerde que un usuario conectado a la base de datos, no puede eliminarse."
       fixora "AG.1.7.14.1" "CTXSYS is used for Oracle Text feature" 
       fixora "AG.1.7.14.1" "sql;alter user $user account lock; if context is being used"
       fixora "AG.1.7.14.1" "sql;drop user $user cascade; if context is not being used"
       TEXTO_TECH=`printf "$NOK: --- instancia: $ins --- CTXSYS User exists and is $accountstatus"`
fi
infor "++++++++++++++++++++++++++++++++++++++" ""
inforora "++++++++++++++++++++++++++++++++++++++" ""
echo -e $TEXTO_TECH
rm -f /tmp/ctxsysuser.lst
}
###########################################################################################
###
ag_1_7_14_ctxsys_priv ()
{
ins=$1
####inforora "AG.1.7.14.2" "Identify and Authenticate Users - Revoke all access to CTXSYS packages from PUBLIC"
####infor "AG.1.7.14.2" "Identify and Authenticate Users - Revoke all access to CTXSYS packages from PUBLIC"
res=0
grep -v SENTENCIAS /tmp/cambios_ctxsys_revoke.sql | grep -v "successfully" | sed '/^$/d' | sed '/^ .*$/d' > cambios_ctxsys_revoke.sh
cat $TMPOUT >> $INFORME
cat $TMPOUT >> $INFORMEORA
if [  -s cambios_ctxsys_revoke.sh ] 
then
       res=1
       infor "$NOK:  --- Instancia: $ins -- CTXSYS PACKAGES tienen privilegios  from PUBLIC\n" ""
       inforora "$NOK:  --- Instancia: $ins -- CTXSYS PACKAGES tienen privilegios  from PUBLIC\n" ""
       TEXTO_TECH="$NOK:  --- Instancia: $ins -- CTXSYS PACKAGES tienen privilegios  from PUBLIC"
       echo "AG.1.7.14.2;SENTENCIAS para quitar privilegios a paquetes de owner CTXSYS:" >> $FIXORA
       echo "AG.1.7.14.2;Check carefully if you do not have any Text indexes"  >> $FIXORA
       awk '{print "AG.1.7.14.2;sql;"$0;}' cambios_ctxsys_revoke.sh  >> $FIXORA
       echo $LIN >> $FIXORA
else
       infor "OK:  --- Instancia: $ins --- No existen CTXSYS PACKAGES con privilegios from PUBLIC\n" ""
       inforora "OK:  --- Instancia: $ins --- No existen CTXSYS PACKAGES con privilegios from PUBLIC\n" ""
       TEXTO_TECH="$OK:  --- Instancia: $ins -- No existen CTXSYS PACKAGES con privilegios from PUBLIC"
fi
echo -e $TEXTO_TECH
###  descomente esta linea si desea generar fichero de cambios .sql a ejecutar desde SQLPLUS
###    mv cambios_ctxsys_revoke.sh $DIR/fixes/cambios_ctxsys_revoke_$ins.sql
rm -f cambios_ctxsys_revoke.sh    
rm -f  /tmp/cambios_ctxsys_revoke.sql 

}
###########################################################################################
### AG.1.7.15
###    Privilege WITH ADMIN Granted only to DBAs and Oracle service accounts (where required) in all database environments             
ag_1_7_15_privwithadmin ()
{
ins=$1
res=0

inforora "AG.1.7.15" "Identify and Authenticate Users - Privilege WITH ADMIN  granted only to DBAs and Oracle service accounts:" 

sed -i "/^$/d" /tmp/privwithadmin.lst
if [ ! -s /tmp/privwithadmin.lst  ] ; then
    infor "$OK: --- instancia: $ins --- Privilege WITH ADMIN only to DBAs and Oracle service accounts\n" ""
    inforora "$OK: --- instancia: $ins --- Privilege WITH ADMIN only to DBAs and Oracle service accounts\n" ""
    TEXTO_TECH="$OK:  --- Instancia: $ins -- Privilegios WITH ADMIN solo asociados a DBAs or Oracle service accounts"
else
       res=1
       infor "$NOK: --- instancia: $ins --- Tiene Usuarios con privilegios WITH ADMIN OPTION y no son  DBAs o Oracle service accounts\n" ""
       inforora "$NOK: --- instancia: $ins --- Tiene Usuarios con privilegios WITH ADMIN OPTION y no son  DBAs o Oracle service accounts\n" ""
       TEXTO_TECH="$NOK:  --- Instancia: $ins -- Existen usuarios con privilegios WITH ADMIN y no son DBAs or Oracle service accounts"
       linea="----------------------------------------------------------------------------------"
       awk -F";" 'function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
                  {printf("User: %s  has privilege %s  WITH ADMIN OPTION\n",rtrim($1),rtrim($2));} 
                  END {print "\n";}' /tmp/privwithadmin.lst | tee -a $INFORME | tee -a $INFORMEORA 
       fixora "AG.1.7.15" "SENTENCIAS para quitar privilegio WITH ADMIN  a usuarios que no son DBAs o Oracle Service accounts"  
       fixora "AG.1.7.15" "Evalue cuidadosamente la revocacion de privilegios"
       fixora "AG.1.7.15" "Se debe revocar el privilegio y rehacer el grant sin la opcion WITH ADMIN OPTION"
       awk -F";" 'function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
                  {if($3 != 'NO') {print "AG.1.7.15;sql;REVOKE "rtrim($2)"  FROM " rtrim($1) ";";
                                   print "AG.1.7.15;sql;GRANT "rtrim($2)" TO " rtrim($1) ";";}}' /tmp/privwithadmin.lst >> $FIXORA
#####       echo -e "$LIN\n" >> $FIXORA
fi
echo -e $TEXTO_TECH
rm -f /tmp/privwithadmin.lst
}

##########################################################################################
###  AG.1.7.16
###
####                PACKAGES / VIEW ALL_USERS  no deben tener privilegio EXECUTE from PUBLIC
ag_1_7_16_packages_privilegios ()
{                      
ins=$1
res=0

grep -v SENTENCIAS /tmp/cambios_isec_oracle_revoke.sql | grep -v "successfully" | sed '/^$/d' | sed '/^ .*$/d' > cambios_isec_oracle_revoke.sh
if [  -s cambios_isec_oracle_revoke.sh ] ; then
         res=1
         infor "$NOK:  --- Instancia: $ins -- Algunos PACKAGES/VIEW tienen privilegio EXECUTE from PUBLIC\n" ""
         inforora "$NOK:  --- Instancia: $ins -- Algunos PACKAGES/VIEW tienen privilegio EXECUTE from PUBLIC\n" ""
         TEXTO_TECH="$NOK:  --- Instancia: $ins -- Algunos PACKAGES/VIEW tienen privilegio EXECUTE from PUBLIC"
         fixora "AG.1.7.16" "No deben existir PACKAGES/VIEW con privilegio EXECUTE from PUBLIC"
         awk '{print "AG.1.7.16;sql;"$0}' cambios_isec_oracle_revoke.sh  >> $FIXORA
         echo $LIN >> $FIXORA
else
         infor "OK:  --- Instancia: $ins --- No existen PACKAGES/VIEW con privilegio EXECUTE from PUBLIC\n" ""
         inforora "OK:  --- Instancia: $ins --- No existen PACKAGES/VIEW con privilegio EXECUTE from PUBLIC\n" ""
         TEXTO_TECH="$OK:  --- Instancia: $ins -- No existen PACKAGES/VIEW con privilegio EXECUTE from PUBLIC"
fi
echo -e $TEXTO_TECH
###  descomente esta linea si desea generar fichero de cambios .sql a ejecutar desde SQLPLUS
###    mv cambios_isec_oracle_revoke.sh $DIR/fixes/cambios_isec_oracle_revoke_$ins.sql
rm -f cambios_isec_oracle_revoke.sh    
rm -f  /tmp/cambios_isec_oracle_revoke.sql 
}

############################################################################################
####*********************************************************************************
###    AG.1.8.1   por instancia:  DataFiles/LogFiles/TempFiles/ControlFiles de la BDs - Protecting Resources OS - Unix permisos: 600
#####################################################################################
####   datos de data files en /tmp/oracle_datafiles.lst
ag_1_8_1_datafiles ()
{
ins=$1
res=0

inforsis "AG.1.8.1" "Protecting resources OSRs - Database Files (datafiles, controlfiles, redolog files, temporary files) Unix permission 600"
inforsis "        " "ASM Database Files have no Unix permission settings"

awk -F';' -v OK=$OK '{if($4~"^+") {print OK"- "$1" Fichero ASM: "$4}}' /tmp/oracle_datafiles.lst | tee -a $INFORME |tee -a $INFORMESIS >/dev/null

> directorios-bd-$ins   ####  usaremos este fichero para la techspech AG.1.8.12

sed -i '/successfully/d' /tmp/oracle_datafiles.lst   ####  quito la sentencia de successfully y las lineas en blanco
sed -i '/^$/d' /tmp/oracle_datafiles.lst

alguno=`awk -F';' 'BEGIN {alguno=0;}
                       {if($4!~"^+"){alguno=1;}}
                       END {print alguno;}' /tmp/oracle_datafiles.lst`
if [ $alguno -eq 0 ]  ####  todos los ficheros son ASM
then
    TEXTO_TECH="$OK --- instancia: $ins --- DataFiles/LogFiles/TempFiles/ControlFiles son ASM y tienen permisos propios"
else    #### algun fichero es de directorios Unix y debe cumplir los permisos 600
for unfile in `awk -F';' '{if($4!~"^+") print $4;}' /tmp/oracle_datafiles.lst | tr -s '\n' ' '` 
do
  [ -f $unfile ] && ls -l $unfile | awk '{print $1";"$9}' | awk -F';' -v ins=$ins -v OK=$OK -v NOK=$NOK '{if($1!~"-[-r][-w]-------") print NOK"-instancia: "ins" Fichero    : "$2" -permisos:"$1 ; else print OK"- "$2" -permisos: "$1}'
  if [[ -f $unfile ]] && [[ $res -eq 0 ]]
  then
      res=`ls -l $unfile | awk '{if($1!~"-[-r][-w]-------") print 1; else print 0;}'`
      if [ $res -eq 0 ]
      then
          TEXTO_TECH="$OK --- instancia: $ins --- DataFiles/LogFiles/TempFiles/ControlFiles con permisos Unix 600"
      else
          TEXTO_TECH="$NOK --- instancia: $ins --- DataFiles/LogFiles/TempFiles/ControlFiles con mas permisos Unix que 600"
      fi
  fi
  [ -f $unfile ] && dirname $unfile >> directorios-bd-$ins && sort -u directorios-bd-$ins > direc-temp
  [ -f direc-temp ] && mv direc-temp directorios-bd-$ins  
  [ -f $unfile ] && ls -l $unfile | awk '{print $1";"$9}' | awk -F';' -v LIN=$LIN '{ if($1!~"-[-r][-w]-------") {print "AG.1.8.1;chmod 600 "$9"\n";tiene=1;}} END {if(tiene==1) print LIN;}' >> $FIXES
done | tee -a $INFORME | tee -a $INFORMESIS >/dev/null
fi
echo -e $TEXTO_TECH

}

#############################################################################################
####**********************************************************************************
###   AG.1.8.12   por instancia: Los directorios que contienen ficheros de BD - owner= oracle software y permisos 750
####################################################################################
####    el fichero "directorios-db"  tiene los directorios de los DATAFILES de la BD de la instancia
####    si "directorios-db" esta vacio, es porque los ficheros/directorios de la BD estan en ASM
####    y en ese caso esta techspech esta OK
ag_1_8_12_directorios_bd ()
{
ins=$1
#infor "AG.1.8.12" "--- instancia: $ins --- Protecting resources OSRs - Directories containing the database files: oracle software owner, Unix permisos: 750" 
#inforsis "AG.1.8.12" "--- instancia: $ins --- Protecting resources OSRs - Directories containing the database files: oracle software owner, Unix permisos: 750" 
ENVFILE=`grep -l $ins $DIR/envfile*` 
owner=`grep "^ORACLE_OWNER=" $ENVFILE | awk -F"=" '{printf("%s",$2);}'`

awk -F";" '{n=split($4,a,"/");
            for(i=1;i<n;i++) 
                printf("%s/",a[i]);
            print "" ;}' /tmp/oracle_datafiles.lst |sort -u > directorios-bd-$ins

sed -i '/^$/d' directorios-bd-$ins
grep -v "^+" directorios-bd-$ins  > dirtemp 
[ ! -s dirtemp ] && res=0 && infor "$OK" "--- instancia: $ins --- No existen directorios Unix que contengan ficheros de BD, porque son ASM" && inforsis "$OK" "--- instancia: $ins --- No existen directorios Unix que contengan ficheros de BD, porque son ASM" && awk -v OK=$OK -v ins=$ins '{print OK": --- instancia: "ins"  Directorio ASM: "$1}' directorios-bd-$ins | tee -a $INFORME | tee -a $INFORMESIS >/dev/null
[ -s dirtemp ]  && cat dirtemp | while read dire
do
    ls -ld $dire | awk -v owner=$owner -v OK=$OK -v NOK=$NOK -v LIN=$LIN '{if($3!=owner || $1!~"d[-r][-w][-x][-r]-[-x]---") 
                                                                  print NOK"- "$1";"$3";"$9" - deberia tener: owner="owner" ; permiso: 750"; 
                                                               else 
                                                                  print OK"- "$1";"$3";"$9i;
                                                              } 
                                                              END {print LIN "\n"}'
    res=`ls -ld $dire | awk -v owner=$owner 'BEGIN {res1=0} 
                                            {if($3!=owner || $1!~"d[-r][-w][-x][-r]-[-x]---") 
                                                 res1=1; 
                                            } 
                                             END {print res1}'`
    if [ $res -eq 1 ]
    then
         ls -ld $dire | awk -v owner=$owner -v OK=$OK -v NOK=$NOK -v LIN=$LIN '{if($3!=owner)
                                                                              {print "AG.1.8.12;chown "owner" "$9; tiene=1}
                                                                           if($1!~"d[-r][-w][-x][-r]-[-x]---")
                                                                              {print "AG.1.8.12;chmod 750 "$9; tiene=1}
                                                                          }  
                                                                          END {if (tiene==1) 
                                                                                 print LIN "\n"}' >> $FIXES
    fi
done | tee -a $INFORME | tee -a $INFORMESIS >/dev/null 
[ -s directorios-bd-$ins ] && awk -v ins=$ins '{print "instancia: "ins" Directorio: "$1;}' directorios-bd-$ins > diretemp
[ -s diretemp ] && mv diretemp  $DIR/temporales/directorios-bd-$ins
if [ $res -eq 1 ]
then
     TEXTO_TECH="$NOK - Directories containing the database files,  have not oracle-software-owner or Unix permission 750"
else
     TEXTO_TECH="$OK - Directories containing the database files,  with oracle-software-owner and Unix permission 750"
fi
rm -f dirtemp directorios-bd-$ins
mv /tmp/oracle_datafiles.lst $DIR/temporales/oracle_datafiles_$ins
echo -e $TEXTO_TECH
}

##############################################################################################
#####********************************************************************************
###  AG.1.8.11  por sistema: Ficheros /etc/oratab, /etc/oraInst.loc*, tnsnames.ora, listener.ora 
###             deben tener como owner=oracle software owner y como grupo=dba o oinstall
#####################################################################################
####
rm -f fichora
ag_1_8_11_1_oratab ()
{
#infor "AG.1.8.11.1" "Protecting resources OSRs - oratab file, with oracle-software-owner, oracle-group" 
#inforsis "AG.1.8.11.1" "Protecting resources OSRs - oratab file, with oracle-software-owner, oracle-group"

###   /etc/oratab  se relaciona con las BDs y con el ORACLE_HOME

varopt=""
[ -d /var/opt/oracle ] && varopt=/var/opt/oracle


ORACLE_HOME=`grep ORACLE_HOME $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`

for ORACLEHOME in $ORACLE_HOME /etc $varopt 
do

     CONFIGC=$ORACLEHOME/rdbms/lib/config.c

     if [ -e $CONFIGC ]
     then
           if [ "$ORACLEHOME" != "$ORACLE_AGENT" ]
           then
                OSDBA_GROUP=`grep "#define" $CONFIGC | grep "SS_DBA_GRP" | tail -1 | awk '{print $3}' | tr -d '"'`
                owner=`grep "^ORACLE_OWNER=" $ORACLEHOME/install/utl/rootmacro.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                group=`grep "^OSDBA_GROUP=" $ORACLEHOME/install/utl/rootmacro.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
           fi
     fi

 find $ORACLEHOME  -name oratab -ls | awk '{print $5";"$6";"$11}' | awk -F';' -v owner=$owner -v group1=$group -v group2=$OSDBA_GROUP -v OK=$OK -v NOK=$NOK '{if($1!~owner || ($2!~group1 && $2!~group2)) print NOK": "$1";"$2";"$3";deberia tener owner="owner",group="group1",o bien group="group2 ; else print OK": "$1";"$2";"$3}' >> fichora

done

res=0
grep oratab fichora  | tee -a $INFORME | tee -a $INFORMESIS >/dev/null
if [ `grep oratab fichora | grep -c NOK` -gt 0 ]
then
    res=1
    grep oratab fichora | grep NOK | awk -F";"  '{ split($4,a,","); 
                                                   match(a[1],"=.*",owner);
                                                   print "AG.1.8.11.1;chown "substr(owner[0],2)" "$3;
                                                   match(a[2],"=.*",grupo1);
                                                   print "AG.1.8.11.1;chgrp "substr(grupo1[0],2)" "$3" o bien";
                                                   match(a[3],"=.*",grupo2);
                                                   print "AG.1.8.11.1;chgrp "substr(grupo2[0],2)" "$3;}' >> $FIXES
fi
if [ $res -eq 0 ]
then
    TEXTO_TECH="$OK - FICHEROS: oratab file, with oracle-software-owner, oracle group"
else
    TEXTO_TECH="$NOK - FICHEROS: oratab file, tiene owner/group diferente a oracle-software-owner/oracle-group"
fi

echo -e $TEXTO_TECH

} 
#######################################################################################
ag_1_8_11_2_oraInst ()
{
#infor "AG.1.8.11.2" "Protecting resources OSRs - oraInst.loc* file, with oracle software owner, oracle group" 
#inforsis "AG.1.8.11.2" "Protecting resources OSRs - oraInst file, with oracle software owner, oracle group"

varopt=""
[ -d /var/opt/oracle ] && varopt=/var/opt/oracle

ORACLE_HOME=`grep ORACLE_HOME $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
ORACLE_GRID=`grep ORACLE_GRID $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
ORACLE_AGENT=`grep ORACLE_AGENT $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`

for ORACLEHOME in $ORACLE_HOME $ORACLE_GRID $ORACLE_AGENT /etc $varopt 
do

  if [ $ORACLEHOME != $ORACLE_AGENT ] ; then

     CONFIGC=$ORACLEHOME/rdbms/lib/config.c

     if [ -e $CONFIGC ]
     then
           if [ "$ORACLEHOME" != "$ORACLE_AGENT" ]
           then
                OSDBA_GROUP=`grep "#define" $CONFIGC | grep "SS_DBA_GRP" | tail -1 | awk '{print $3}' | tr -d '"'`
                owner=`grep "^ORACLE_OWNER=" $ORACLEHOME/install/utl/rootmacro.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                group=`grep "^OSDBA_GROUP=" $ORACLEHOME/install/utl/rootmacro.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
           fi
     else
           OSDBA_GROUP=root   ####  el /etc/oraInst.loc  tiene owner/group=root/root   despues de ejecutar el orainstRoot.sh en la instalacion
           owner=root
           group=root 
     fi
  else
    if [ -e "$ORACLE_AGENT"/root.sh ] ; then
        if [ `grep -c "^ORACLE_OWNER" $ORACLE_AGENT/root.sh` -gt 0 ] ; then
            owner=`grep "^ORACLE_OWNER=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2); }'`
            OSDBA_GROUP=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
            group=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
        else
           if [ `grep -c "gcroot.sh" $ORACLE_AGENT/root.sh |  grep -v "^#"` -gt 0 ] ; then
                 buscafile=`grep "gcroot.sh" $ORACLE_AGENT/root.sh |tail -1`
                 if [ -f $buscafile ] ; then
                     owner=`grep "^ORACLE_OWNER" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                     OSDBA_GROUP=`grep "^OSDBA_GROUP=" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                     group=`grep "^OSDBA_GROUP=" $buscafile |tail -1 | awk -F"=" '{printf("%s",$2);}'`
                 fi
           fi
        fi
    fi

  fi
 
  find $ORACLEHOME  -name oraInst.loc -ls | awk '{print $5";"$6";"$11}' | awk -F';' -v owner=$owner -v group1=$group -v group2=$OSDBA_GROUP -v OK=$OK -v NOK=$NOK '{if($1!~owner || ($2!~group1 && $2!~group2)) print NOK": "$1";"$2";"$3";deberia tener owner= "owner",group= "group1",o group="group2 ; else print OK": "$1";"$2";"$3}' >> fichora

done

res=0
grep oraInst fichora | tee -a $INFORME | tee -a $INFORMESIS >/dev/null
if [ `grep oraInst fichora | grep -c NOK` -gt 0 ]
then
    res=1
    grep oraInst fichora | grep NOK | awk -F";"  '{ split($4,a,","); 
                                                   match(a[1],"=.*",owner);
                                                   print "AG.1.8.11.2;chown "substr(owner[0],2)" "$3;
                                                   match(a[2],"=.*",grupo1);
                                                   print "AG.1.8.11.2;chgrp "substr(grupo1[0],2)" "$3" o bien";
                                                   match(a[3],"=.*",grupo2);
                                                   print "AG.1.8.11.2;chgrp "substr(grupo2[0],2)" "$3;}' >> $FIXES
fi
if [ $res -eq 0 ]
then
    TEXTO_TECH="$OK - FICHEROS: oraInst.loc files, with oracle-software-owner, oracle group"
else
    TEXTO_TECH="$NOK - FICHEROS: oraInst.loc files, tiene owner/group diferente a oracle-software-owner/oracle-group"
fi

echo -e $TEXTO_TECH

} 

#######################################################################################
ag_1_8_11_3_listener ()
{
#infor "AG.1.8.11.3" "Protecting resources OSRs - listener.ora file, with oracle-software-owner/oracle-group" 
#inforsis "AG.1.8.11.3" "Protecting resources OSRs - listener.ora  file, with oracle-software-owner/oracle-group"

ORACLE_HOME=`grep ORACLE_HOME $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
ORACLE_GRID=`grep ORACLE_GRID $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
ORACLE_AGENT=`grep ORACLE_AGENT $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`

for ORACLEHOME in $ORACLE_HOME $ORACLE_GRID $ORACLE_AGENT
do

  if [ $ORACLEHOME != $ORACLE_AGENT ] ; then

     CONFIGC=$ORACLEHOME/rdbms/lib/config.c

     if [ -e $CONFIGC ]
     then
           if [ "$ORACLEHOME" != "$ORACLE_AGENT" ]
           then
                OSDBA_GROUP=`grep "#define" $CONFIGC | grep "SS_DBA_GRP" | tail -1 | awk '{print $3}' | tr -d '"'`
                owner=`grep "^ORACLE_OWNER=" $ORACLEHOME/install/utl/rootmacro.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                group=`grep "^OSDBA_GROUP=" $ORACLEHOME/install/utl/rootmacro.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
           fi
     fi
  else
    if [ -e "$ORACLE_AGENT"/root.sh ] ; then
        if [ `grep -c "^ORACLE_OWNER" $ORACLE_AGENT/root.sh` -gt 0 ] ; then
            owner=`grep "^ORACLE_OWNER=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2); }'`
            OSDBA_GROUP=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
            group=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
        else
           if [ `grep -c "gcroot.sh" $ORACLE_AGENT/root.sh |  grep -v "^#"` -gt 0 ] ; then
                 buscafile=`grep "gcroot.sh" $ORACLE_AGENT/root.sh |tail -1`
                 if [ -f $buscafile ] ; then
                     owner=`grep "^ORACLE_OWNER" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                     OSDBA_GROUP=`grep "^OSDBA_GROUP=" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                     group=`grep "^OSDBA_GROUP=" $buscafile |tail -1 | awk -F"=" '{printf("%s",$2);}'`
                 fi
           fi
        fi
    fi

  fi
 

find ${ORACLEHOME} -wholename "*/admin/listener.ora" -ls | awk '{print $5";"$6";"$11}' | awk -F';' -v owner=$owner -v group1=$group -v group2=$OSDBA_GROUP -v OK=$OK -v NOK=$NOK '{if($1!~owner || ($2!~group1 && $2!~group2)) print NOK": "$1";"$2";"$3";deberia tener owner= "owner",group= "group1",o group="group2 ; else print OK": "$1";"$2";"$3;}' >> fichora

done

res=0
grep listener.ora fichora | tee -a $INFORME | tee -a $INFORMESIS >/dev/null

if [ `grep listener.ora fichora | grep -c NOK` -gt 0 ]
then
    res=1
    grep listener.ora fichora | grep NOK | awk -F";"  '{ split($4,a,","); 
                                                   match(a[1],"=.*",owner);
                                                   print "AG.1.8.11.3;chown "substr(owner[0],2)" "$3;
                                                   match(a[2],"=.*",grupo1);
                                                   print "AG.1.8.11.3;chgrp "substr(grupo1[0],2)" "$3" o bien";
                                                   match(a[3],"=.*",grupo2);
                                                   print "AG.1.8.11.3;chgrp "substr(grupo2[0],2)" "$3;}' >> $FIXES
fi
if [ $res -eq 0 ]
then
    TEXTO_TECH="$OK - FICHEROS: listener.ora files, with oracle-software-owner, oracle group"
else
    TEXTO_TECH="$NOK - FICHEROS: listener.ora files, tiene owner/group diferente a oracle-software-owner/oracle-group"
fi
echo -e $TEXTO_TECH
} 

#######################################################################################
ag_1_8_11_4_tnsnames ()
{
#infor "AG.1.8.11.4" "Protecting resources OSRs - tnsnames.ora file, with oracle software owner, dba|oinstall group" 
#inforsis "AG.1.8.11.4" "Protecting resources OSRs - tnsnames.ora  file, with oracle software owner, dba|oinstall group"

ORACLE_HOME=`grep ORACLE_HOME $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
ORACLE_GRID=`grep ORACLE_GRID $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
ORACLE_AGENT=`grep ORACLE_AGENT $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`

for ORACLEHOME in $ORACLE_HOME $ORACLE_GRID $ORACLE_AGENT
do

  if [ $ORACLEHOME != $ORACLE_AGENT ] ; then

     CONFIGC=$ORACLEHOME/rdbms/lib/config.c

     if [ -e $CONFIGC ]
     then
           if [ "$ORACLEHOME" != "$ORACLE_AGENT" ]
           then
                OSDBA_GROUP=`grep "#define" $CONFIGC | grep "SS_DBA_GRP" | tail -1 | awk '{print $3}' | tr -d '"'`
                owner=`grep "^ORACLE_OWNER=" $ORACLEHOME/install/utl/rootmacro.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                group=`grep "^OSDBA_GROUP=" $ORACLEHOME/install/utl/rootmacro.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
           fi
     fi
  else
    if [ -e "$ORACLE_AGENT"/root.sh ] ; then
        if [ `grep -c "^ORACLE_OWNER" $ORACLE_AGENT/root.sh` -gt 0 ] ; then
            owner=`grep "^ORACLE_OWNER=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2); }'`
            OSDBA_GROUP=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
            group=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh |tail -1 | awk -F"=" '{printf("%s",$2);}'`
        else
           if [ `grep -c "gcroot.sh" $ORACLE_AGENT/root.sh |  grep -v "^#"` -gt 0 ] ; then
                 buscafile=`grep "gcroot.sh" $ORACLE_AGENT/root.sh |tail -1`
                 if [ -f $buscafile ] ; then
                     owner=`grep "^ORACLE_OWNER" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                     OSDBA_GROUP=`grep "^OSDBA_GROUP=" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                     group=`grep "^OSDBA_GROUP=" $buscafile |tail -1 | awk -F"=" '{printf("%s",$2);}'`
                 fi
           fi
        fi
    fi

  fi
 

  find $ORACLEHOME  -wholename "*/admin/tnsnames.ora" -ls | awk '{print $5";"$6";"$11}' | awk -F';' -v owner=$owner -v group1=$group -v group2=$OSDBA_GROUP -v OK=$OK -v NOK=$NOK '{if($1!~owner || ($2!~group1 && $2!~group2)) print NOK": "$1";"$2";"$3";deberia tener owner= "owner",group= "group1",o group="group2 ; else print OK": "$1";"$2";"$3}' >> fichora

done

res=0
grep tnsnames.ora fichora | tee -a $INFORME | tee -a $INFORMESIS >/dev/null
if [ `grep tnsnames.ora fichora | grep -c NOK` -gt 0 ]
then
    res=1
    grep tnsnames.ora fichora | grep NOK | awk -F";"  '{ split($4,a,","); 
                                                   match(a[1],"=.*",owner);
                                                   print "AG.1.8.11.3;chown "substr(owner[0],2)" "$3;
                                                   match(a[2],"=.*",grupo1);
                                                   print "AG.1.8.11.3;chgrp "substr(grupo1[0],2)" "$3" o bien";
                                                   match(a[3],"=.*",grupo2);
                                                   print "AG.1.8.11.3;chgrp "substr(grupo2[0],2)" "$3;}' >> $FIXES
fi
if [ $res -eq 0 ]
then
    TEXTO_TECH="$OK - FICHEROS: tnsnames.ora files, with oracle-software-owner, oracle group"
else
    TEXTO_TECH="$NOK - FICHEROS: tnsnames.ora files, tiene owner/group diferente a oracle-software-owner/oracle-group"
fi

echo -e $TEXTO_TECH
} 
####*********************************************************************************
###    AG.1.8.5   por instancia:  Archive Log de la BDs - Protecting Resources OS - Unix permisos: 640
#####################################################################################
####   datos de archive log files en /tmp/oracle_archivelogfiles.lst
ag_1_8_5_archivelog ()
{
ins=$1
res=0

awk -v OK=$OK -v ins=$ins '/Archive destination/||/Destino del archivo/ {for(i=3;i<=NF;i++){
                                                    if($i~"^+") {print OK"- instancia: "ins" Fichero ASM: "$i}
                                                 }}' /tmp/oracle_archivelogfiles.lst |tee -a $INFORME | tee -a $INFORMESIS >/dev/null

alguno=`awk -F';' 'BEGIN {alguno=0;}
                         { if ($0 !~ "Archive destination" || $0 !~ "Destino del archivo") {next;} 
                           if ($0 ~ "Archive destination" ) {j=3;} 
                           if ($0 ~ "Destino del archivo" ) {j=4;} 
                           {for(i=j;i<=NF;i++)
                               if($i!~"^+"){alguno=1;}}}
                   END {print alguno;}' /tmp/oracle_archivelogfiles.lst`
if [ $alguno -eq 0 ]  ####  todos los ficheros son ASM
then
    TEXTO_TECH="$OK --- instancia: $ins --- ArchiveLog Files son ASM y tienen permisos propios"
else    #### algun fichero es de directorios Unix y debe cumplir los permisos 640
for dir in `awk '/Archive destination/ {if($3!~"^+") print $3;}' /tmp/oracle_archivelogfiles.lst | tr -s '\n' ' '` 
do
  [ -d $dir ] && ls -l $dir | awk '{print $1";"$9}' | awk -F';' -v OK=$OK -v NOK=$NOK '{ if($1!~"-[-r][-w]-[-r]-----") print NOK"-instancia: "ins" Fichero    : "$2" -permisos:"$1 ; else print OK"- "$2" -permisos: "$1}'
  if [[ -d $dir ]] && [[ $res -eq 0 ]]
  then
      res=`ls -l $dir | awk '{if($1!~"-[-r][-w]-[-r]-----") print 1; else print 0;}'`
      if [ $res -eq 0 ]
      then
          TEXTO_TECH="$OK --- instancia: $ins --- ArchiveLog Files con permisos Unix 640"
      else
          TEXTO_TECH="$NOK --- instancia: $ins --- ArchiveLog Files con mas permisos Unix que 640"
      fi
  fi
  [ -d $dir ] && ls -l $dir | awk '{print $1";"$9}' | awk -F';' -v LIN=$LIN '{ if($1!~"-[-r][-w]-[-r]-----") {print "AG.1.8.5;chmod 640 "$9"\n";tiene=1;}} END {if(tiene == 1) print LIN;}' >> $FIXES
done | tee -a $INFORME | tee -a $INFORMESIS
fi
echo -e $TEXTO_TECH
mv /tmp/oracle_archivelogfiles.lst $DIR/temporales/oracle_archivelog_$ins
}

####*********************************************************************************
###    AG.1.8.6   por instancia:  Alert Log de la BDs - Protecting Resources OS - Unix permisos: 640
#####################################################################################
####   ficheros alert log files en directorio del Parameter: 'background_dump_dest' 
ag_1_8_6_alertlog ()
{
ins=$1

res=0
diralerts=`grep background_dump_dest /tmp/oracle_background_dest.lst | awk '{print $2}' | tr -d ' '`

ls -l ${diralerts}/*alert*log | awk '{print $1";"$9}' | awk -F';' -v OK=$OK -v NOK=$NOK '{if($1!~"-[r-][-w]-[-r]-----") print NOK": "$1";"$2 ; else print OK": "$1";"$2;}' | tee -a $INFORME | tee -a $INFORMESIS >/dev/null
res=`ls -l ${diralerts}/*alert*log | awk '{if($1!~"-[r-][-w]-[-r]-----") {print 1; exit;} {print 0}}'`
if [ $res -eq 1 ]
then
   TEXTO_TECH="$NOK --- instancia: $ins --- AlertLog Files tienen mas permisos que 640"
   ls -l ${diralerts}/*alert*log | awk '{print $1";"$9}' | awk -F';' -v LIN=$LIN '{if($1!~"-[r-][-w]-[-r]-----") {print "AG.1.8.6;chmod 640 "$9"\n";tiene=1;}} END {if(tiene==1)print LIN}' >> $FIXES 
else
   TEXTO_TECH="$OK --- instancia: $ins --- AlertLog Files tienen permisos  640"
fi
echo -e $TEXTO_TECH
}

#########################################################################################
###   AG.1.8.7   Permisos de ficheros init<SID>.ora, spfile<SID>.ora, config.ora  640
########################################################################################
ag_1_8_7_permisos_init_spfile ()
{
ins=$1
RES1=0
#infor  "AG.1.8.7:" "--- instancia: $ins --- Protecting resources OSRs - init<SID>.ora, spfile<SID>.ora, config.ora - permisos: 640 o mas restrictivos"
#inforsis  "AG.1.8.7:" "--- instancia: $ins --- Protecting resources OSRs - init<SID>.ora, spfile<SID>.ora, config.ora - permisos: 640 o mas restrictivos"

grep -e \/init"${ins}".ora -e \/init"${ORACLE_SID}".ora ficheros_encontrados |tee -a $INFORME | tee -a $INFORMESIS >/dev/null
res=0
for fich in `grep -e \/init"$ins".ora -e \/init"${ORACLE_SID}".ora  ficheros_encontrados | grep NOK | awk -F';' '{print $2}' | tr -s '\n' ' '` 
do
     fix "AG.1.8.7" "chmod 640 $fich" 
     res=1
     RES1=1
done && [[ $res == 1 ]] && fix "$LIN" "" 

grep -e \/spfile"${ins}".ora -e \/spfile"${ORACLE_SID}".ora  ficheros_encontrados |tee -a $INFORME | tee -a $INFORMESIS >/dev/null
res=0
for fich in `grep -e \/spfile"${ins}".ora -e \/spfile"${ORACLE_SID}".ora  ficheros_encontrados | grep NOK | awk -F';' '{print $2}' | tr -s '\n' ' '` 
do
     fix "AG.1.8.7" "chmod 640 $fich" 
     res=1
     RES1=1
done && [[ $res == 1 ]] && fix "$LIN" "" 
grep \/config.ora ficheros_encontrados |tee -a $INFORME | tee -a $INFORMESIS >/dev/null
res=0
for fich in `grep \/config.ora ficheros_encontrados | grep NOK | awk -F';' '{print $2}' | tr -s '\n' ' '` 
do
     fix "AG.1.8.7" "chmod 640 $fich" 
     res=1
     RES1=1
done && [[ $res == 1 ]] && fix "$LIN" ""  

if [ $RES1 -eq 0 ] 
then
     TEXTO_TECH="$OK --- instancia: $ins --- FICHEROS: init<SID>.ora, spfile<SID>.ora, config.ora - permisos 640 correctos"
else
     TEXTO_TECH="$NOK --- instancia: $ins --- FICHEROS: Existe algun init<SID>.ora, spfile<SID>.ora, config.ora - con mas permisos que 640"
fi
res=$RES1
echo -e $TEXTO_TECH
}


############################################################################################
####         permisos de ficheros listener.ora, tnsnames.ora, target.xml

####  AG.1.8.14
ag_1_8_14_listener_ora ()
{
# infor "AG.1.8.14:" "Protecting resources OSRs - listener.ora - permisos: 600"
# inforsis "AG.1.8.14:" "Protecting resources OSRs - listener.ora - permisos: 600"
    grep -q listener.ora ficheros_encontrados
if [ $? -eq 1 ]
then
find $DIRECTORIOS_FIND -wholename "*/admin/listener.ora" -ls | awk -v NOK=$NOK -v OK=$OK '{if ($3!~"-..-------") print NOK":  "$3";"$11";deberia tener permiso: -rw-------";else print OK":  "$3";"$11}'  >> ficheros_encontrados
fi
    grep listener.ora ficheros_encontrados | tee -a $INFORME | tee -a $INFORMESIS >/dev/null 
    res=0
    for fich in `grep listener.ora ficheros_encontrados | grep NOK |  awk -F';' '{print $2}' | tr -s '\n' ' '`
    do 
             fix "AG.1.8.14" "chmod 600 $fich" 
             res=1
    done && [[ $res == 1 ]] && fix "$LIN" ""  
    if [ $res -eq 1 ]
    then
         TEXTO_TECH="$NOK - FICHEROS: listener.ora - Existe algun fichero con mas permisos que 600"
    else
         TEXTO_TECH="$OK - FICHEROS: listener.ora - Todos los ficheros tienen permisos 600 o mas restrictivos"
    fi
echo -e $TEXTO_TECH

}

###############################################################################################
###
###   AG.1.8.15
ag_1_8_15_tnsnames_ora ()
{
#        infor  "AG.1.8.15:" "Protecting resources OSRs - tnsnames.ora - permisos: 644 o mas restrictivos"
#       inforsis  "AG.1.8.15:" "Protecting resources OSRs - tnsnames.ora - permisos: 644 o mas restrictivos"
        find $DIRECTORIOS_FIND -wholename "*/admin/tnsnames.ora" -ls | awk -v NOK=$NOK -v OK=$OK '{if ($3!~"-..-.--.--") print NOK":  "$3";"$11";deberia tener permiso: -rw-r--r-- o mas restrictivo";else print OK":  "$3";"$11}'  >> ficheros_encontrados
        grep tnsnames.ora ficheros_encontrados | tee -a $INFORME |tee -a $INFORMESIS >/dev/null
        res=0
        for fich in `grep tnsnames.ora ficheros_encontrados | grep NOK | awk -F';' '{print $3}' |tr -s '\n' ' '`
        do
             fix "AG.1.8.15" "chmod 644 $fich" 
             res=1
        done && [[ $res == 1 ]] &&  fix "$LIN" "" 
        if [ $res -eq 1 ]
        then
            TEXTO_TECH="$NOK - FICHEROS: tnsnames.ora - Existe algun fichero con mas permisos que 644"
        else
            TEXTO_TECH="$OK - FICHEROS: tnsnames.ora - Todos los ficheros tienen permisos 644 o mas restrictivos"
        fi
echo -e $TEXTO_TECH
        
}
##############################################################################################
###
###   ag.1.8.17
ag_1_8_17_targets_xml ()
{
#        infor  "AG.1.8.17:" "Protecting resources OSRs - targets.xml (Oracle EM Grid Agent configuration file) - permisos: 644 o mas restrictivos"
#        inforsis  "AG.1.8.17:" "Protecting resources OSRs - targets.xml (Oracle EM Grid Agent configuration file) - permisos: 644 o mas restrictivos"
        DIREGRID=`echo $DIRECTORIOS_FIND | grep -i grid`
        find $DIRECTORIOS_FIND -name targets.xml -ls | awk -v NOK=$NOK -v OK=$OK '{if($3!~"-rw-[-r]--[-r]--") print NOK":  "$3";"$11";deberia tener permiso: -rw-r--r-- o mas restrictivo";else print OK":  "$3";"$11}'  >> ficheros_encontrados
        grep targets.xml ficheros_encontrados |tee -a $INFORME | tee -a $INFORMESIS >/dev/null
        res=0
        for fich in `grep targets.xml ficheros_encontrados | grep NOK | awk -F';' '{print $2}' | tr -s '\n' ' '`
        do
             fix "AG.1.8.17" "chmod 644 $fich" 
             res=1
        done && [[ $res == 1 ]] && fix "$LIN" ""  
        if [ $res -eq 1 ]
        then
            TEXTO_TECH="$NOK - FICHEROS: targets.xml - Existe algun fichero con mas permisos que 644"
        else
            TEXTO_TECH="$OK - FICHEROS: targets.xml - Todos los ficheros tienen permisos 644 o mas restrictivos"
        fi
echo -e $TEXTO_TECH
}
##############################################################################################

#########################################################################################
####  AG.1.8.16       fichero de passwords orapw$ORACLE_SID  - permisos 640 o mas restrictivos
####  
ag_1_8_16_orapwdSID ()
{
    ins=$ins
#infor "AG.1.8.16:" "--- Instancia: $ins ---  Protecting resources OSRs - orapw$ORACLE_SID - permisos: 640 o mas restrictivos"
#inforsis "AG.1.8.16:" "--- Instancia: $ins ---  Protecting resources OSRs - orapw$ORACLE_SID - permisos: 640 o mas restrictivos"
    ENVFILE=`grep -l $ins $DIR/envfile*`
    ORACLE_HOME=`grep "^ORACLE_HOME" $ENVFILE | awk -F"=" '{print $2}'`
    find $ORACLE_HOME -name orapw${ins} -ls | awk -v NOK=$NOK -v OK=$OK '{if($3!~"-[-r][-w]-[-r]-----") print NOK":  "$3";"$11";deberia tener permiso: -rw-r----- o mas restrictivo"; else print OK":  "$3";"$11}' >> ficheros_encontrados
    res=0
    if [ `grep -c orapw${ins} ficheros_encontrados` -gt 0 ] 
    then
          grep orapw${ins} ficheros_encontrados | tee -a $INFORME | tee -a $INFORMESIS >/dev/null
    else
          infor "$OK" "--- instancia: $ins --- No existe fichero orapw${ins}"
          inforsis "$OK" "--- instancia: $ins --- No existe fichero orapw${ins}"
          res=2
    fi
    for fich in `grep orapw${ins} ficheros_encontrados | grep NOK | awk -F';' '{print $2}' | tr -s '\n' ' '`
    do
          fix "AG.1.8.16" "chmod 644 $fich" 
          res=1
    done && [[ $res == 1 ]] && fix "$LIN" ""  
    if [ $res -eq 1 ]
    then
            TEXTO_TECH="$NOK - FICHEROS: orapw<SID> - Existe algun fichero con mas permisos que 640"
    else
         if [ $res -eq 0 ]
         then
            TEXTO_TECH="$OK - FICHEROS: orapw<SID> - Todos los ficheros tienen permisos 640 o mas restrictivos"
         else
            res=0
            TEXTO_TECH="$OK - FICHEROS: orapw<SID> - No existe fichero para instancia $ins"
         fi
    fi
echo -e $TEXTO_TECH
}

######     funcion para determinar cuales usuarios tienen privilegios/roles solo autorizados a DBAs y Oracle Service Accounts
######     consideramos que el usuario de SEGUR  'OPS$ISYSAD1' necesita privilegios ALTER USER, GRANTS para gestionar passwords, por lo cual estara excepcionado
######     los demas usuarios que posean estos privilegios, deben justificarse (por ej. si son de aplicacion y los requieren)
ag_5_0_1_privileged_auth ()
{
  ins=$1
  shift
  users=$*
  TMPOUT=tmpout1
  > $TMPOUT
  res=0
  for user in $users 
  do
          rm -f /tmp/userauth.txt
          echo "$user" | grep -q  "\\$"        #####  para los usuarios OPS$ISYSAD1 u otros externos, se debe convertir a OPS\$ISYSAD1
          uu=$user
          if [ $? = 0 ] ; then
               user=$(echo $user | sed  's/\$/\\$/') 
          fi
          runuser -l $orauser -c "$SHEL ${ENVFILE} ; sqlplus -s /nolog @$DIR/OraPRIVIsec.sql $user" >/dev/null 2>&1
          egrep -q -E "$AUTORIZA" /tmp/userauth.txt 
          if [ $? = 0 ]; then
            echo $user | grep -q -e ISYSAD1 
            if [ $? = 0 ] ; then
              echo -e  "\n$OK:  Usuario: $uu , roles y autorizaciones ===EXCEPCION===" >> $TMPOUT
            else
                     echo -e "\n$NOK: Usuario: $uu , roles y autorizaciones" >> $TMPOUT
                     res=1
            fi
            cat /tmp/userauth.txt >> $TMPOUT
#            awk '{for(i=2;i<NF;i++) {printf("%s ",$i);} print $NF;}' /tmp/userauth.txt  >> $TMPOUT
            if [ "$uu" = "OPS\$ISYSAD1" ]
            then
                 continue
            else
                 awk '{if ($2 ~ "USER:") 
                    {user=$3 ; next} 
                  if ($2 ~ "SUB-ROL:") 
                    {print user "|" $1 "|SUBROL|" $3 "|NOK" ; next } 
                  if ($2 ~ "ROL:") 
                    {print user "|" $1 "|ROL|" $3 "|NOK" ; next} 
                  if ($2 ~ "PRIVILEGIO:") 
                    {print user "|" $1 "|PRIVILEGIO|" $3 " " $4 " " $5 " " $6 "|NOK"; next}}' /tmp/userauth.txt >> $DIR/ag_5_0_1_${ins}_privmalos
            fi
          fi 
 done

###  ejemplo de fichero ag_5_0_1_${ins}_privmalos  de donde se extraen las sentencias SQL para proponer revocar los privilegios no autorizados a usuarios generales
###PROVAG2G|2|PRIVILEGIO|ALTER USER  |NOK
###PROVAG2G|2|ROL|G2G|NOK
###PROVAG2G|3|SUBROL|DBA|NOK
###PROVAG2G|3|SUBROL|DELETE_CATALOG_ROLE|NOK
###PROVAG2G|3|SUBROL|PP|NOK
###PROVAG2G|4|SUBROL|G2G3|NOK
###PROVAG2G|4|PRIVILEGIO|ALTER USER  |NOK
###PROVAG2G|4|PRIVILEGIO|CREATE USER  |NOK
###PROVAG2G|4|PRIVILEGIO|DROP USER  |NOK
###PROVAG2G|2|ROL|IMP_FULL_DATABASE|NOK
###PROVAG2G|2|ROL|PP1|NOK
###PROVAG2G|3|PRIVILEGIO|ALTER USER  |NOK

if [ -f $DIR/ag_5_0_1_${ins}_privmalos ] && [ `grep -c "NOK" $DIR/ag_5_0_1_${ins}_privmalos` -gt 0 ] 
then
    fixora "AG.5.0.1" "Evalue cuidadosamente la revocacion de roles/privilegios de usuarios/roles"
    grep "NOK" $DIR/ag_5_0_1_${ins}_privmalos | awk -F"|" -v lin=$LIN 'BEGIN {level=1;esrol=0; essubrol=0;lant=0}
            {level=$2;
             if($3 == "ROL" )
               { lant=level;
                rolant[lant]=$4;
                rol1=$4;
                from1=$1;
                essubrol=0;
                if($4 == "DBA" || $4 == "IMP_FULL_DATABASE" || $4 == "EXECUTE_CATALOG_ROLE" || $4 == "DELETE_CATALOG_ROLE")
                   {print "AG.5.0.1;sql;revoke " rol1 " from " from1 ";";  }
                next}
             if ($3 == "SUBROL" && ( $4 == "DBA" || $4 == "IMP_FULL_DATABASE" || $4 == "EXECUTE_CATALOG_ROLE" || $4 == "DELETE_CATALOG_ROLE") && level == lant+1 )
               { rol1=$4;
                 print "AG.5.0.1;sql;revoke " rol1 " from " rolant[lant] ";";
                 essubrol=1;
                 next}
             if($3 == "SUBROL" && essubrol == 1 )
               { rolant[level]=$4;
                 lant=level;
                 next}
             if ($3 == "SUBROL" && $4 != "DBA" && $4 != "IMP_FULL_DATABASE" && $4 != "EXECUTE_CATALOG_ROLE" && $4 != "DELETE_CATALOG_ROLE" && level == lant+1 )
               { rolant[level]=$4;
                 lant=$2;
                 next}
             if($3 == "PRIVILEGIO" && level == lant+1 )
               {print "AG.5.0.1;sql;revoke " $4 " from " rolant[lant] ";"
                next }
             if($3 == "PRIVILEGIO" && level == lant )
               {print "AG.5.0.1;sql;revoke " $4 " from " rolant[lant-1] ";"
                next }
             if($3 == "PRIVILEGIO" && level == 2)
               {print "AG.5.0.1;sql;revoke " $4 " from " $1 ";"; 
                next}}
       END {print lin;}' >> $FIXORA
fi

if [ $res -eq 0 ]
then
      TEXTO_TECH="$OK: --- instancia $ins --- No existen usuarios con autorizaciones privilegiadas salvo los DBAs y Oracle Service Accounts"
else
      TEXTO_TECH="$NOK: --- instancia $ins --- Existen usuarios con autorizaciones privilegiadas y no son Oracle Service Accounts"
fi

 [ -f $DIR/ag_5_0_1_${ins}_privmalos ] && mv $DIR/ag_5_0_1_${ins}_privmalos $DIR/temporales
 rm -f /tmp/userauth.txt
 echo -e $TEXTO_TECH
}

###################################################################################
haybds ()
{

   if [ $NOBD = 1 ] 
   then
        TEXTO_TECH="$OK:  NO hay BDs que chequear .... "
        echo -e $TEXTO_TECH > $RESULT
        RES=0
   fi
   
}

###############################################################################################
###
###                fin funciones
###
###############################################################################################

###############################################################################################
###
###                 MAIN
###
################################################################################

#usuarios=`ps -ef | grep pmon_ |grep -v grep |grep -v asm |awk '{print $1}' | uniq | tr '\n' ' '`

#for USER in $usuarios
#do

cambiar_dimensiones

#instancias=`ps -ef |grep pmon |grep -v grep | grep -v asm | grep -w $USER | awk '{print $8}' | cut -d'_' -f3 | tr -s '\n' ' '`
instancias=`ps -ef |grep pmon |grep -v grep | grep -v asm | awk '{print $8}' | cut -c10-`

parsearparametroscomprobar $*   ####   revisa si las techspec puestas en los parametros aparecen entre la lista de techspechs posibles en LISTACOMPLETATECHSPEC
##### > $DIR/temporales/ficheros_encontrados_$DIA
setear_bases    #### setea variable BASE_NAMES con los nombres de las BDs de la maquina

if [ -z "$BASE_NAMES" ]
then
    echo -e "No existen BDs en esta maquina...."
    NOBD=1       ##### flag que marca que no hay BDs
else
    NOBD=0
fi

############################################################################
bases_levantadas=""

######echo $BASE_NAMES

echo "Solo se evaluan las BDs PRIMARY...."
for base in $BASE_NAMES     ####  revisamos todas las bases definidas y solo nos quedamos con las bases de instancias levantadas... 
do

 setear_entorno $base    ### revisa la configuracion de la Base y extrae el nombre de instancia en la variable "ins"
 ins=`grep ORACLE_SID $DIR/envfile_$base | awk -F"=" '{print $2}'`
 echo $instancias | grep -q $ins   ####  revisamos la instancia solo si esta arrancada 
 if [ $? -eq 1 ]
 then
        INFORMEORA=$DIR/logs/${HOST}_OracleISEC_FULL_${ins}_${DIA}.log
        infor "$LIN\nHOST: $HOST - BASE: $BASE  - Instancia NO levantada, No se chequea esta base de datos....$LIN\n"
        inforora "$LIN\nHOST: $HOST - BASE: $BASE  - Instancia NO levantada, No se chequea esta base de datos....$LIN\n"
 else
        orauser=`grep "ORACLE_USER" $DIR/envfile_$base | awk -F"=" '{print $2}'` 
        entor=$DIR/envfile_$base
        estado=`runuser -l $orauser -c "$SHEL ${entor} ; sqlplus -s /nolog @$DIR/bd_primaria.sql"`
        echo "$base : $estado" 
        echo "$estado" | grep -q -i primary
        if [ $? -eq 0 ] 
        then 
              bases_levantadas="$base $bases_levantadas"
        else
             echo -e "\nHOST: $HOST - BASE: $base - Instancia MONTADA, BD no es PRIMARY, No se chquea esta base de datos ....\n"
        fi
 fi
done


############################################################################

for base in $bases_levantadas    #####   seteamos los ficheros de informes y de fixes de oracle por cada base levantada 
do 
    ins=`grep ORACLE_SID $DIR/envfile_$base | awk -F"=" '{print $2}'`
    INFORMEORA=$DIR/logs/${HOST}_OracleISEC_FULL_${ins}_${DIA}.log
    echo -e "${LIN}\n${LIN}\nINFORME: ISEC_ORACLE_${ins}_FULL - `date +%d/%m/%y-%H:%M:%S` \n${LIN}\n${LIN}" > $INFORMEORA 

#    [ ! -d $DIR/${ins} ] &&  mkdir $DIR/${ins}

    FIXORA=$DIR/fixes/fixes_oracle_${ins}_$DIA
    echo "#### FECHA: `date +%d/%m/%y-%H:%M:%S`  $HOST - instancia: $ins" > $FIXORA
    echo -e "####\n####  Valore cuidadosamente la ejecucion de los comandos de cambios\n${LIN}" >> $FIXORA

done

> ficheros_encontrados

RESULT=resultado 
TMPOUT=tmpout1

fff=0
###########################################################################
#### CODIGOTECHSPEC=AG.1.1.1
CODIGOTECHSPEC="AG.1.1.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Passwords,...." && fff=1
     infor "AG.1.1.1" "Password Requirements - PASSWORD_LIFE_TIME - $PARAM111" 
     inforora "AG.1.1.1" "Password Requirements - PASSWORD_LIFE_TIME - $PARAM111"
     infor "La caducidad de passwords debe ser $PARAM111 dias. Este parametro se setea a nivel de PROFILE"
     infor "Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     infor "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     inforora "La caducidad de passwords debe ser $PARAM111 dias. Este parametro se setea a nivel de PROFILE"
     inforora "Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     inforora "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     RES=0
     >$RESULT
     >$TMPOUT
     
     for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
     do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         rm -f $DIR/ag_1_1_1_password_life_time.log
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ag_1_1_1_password_life_time.sql" >> $TMPOUT  
         res=0
         ag_1_1_1_password_life_time $ins >> $RESULT
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/check_pwd.sql " > $DIR/${ins}.caducidad
         let RES=$RES+$res
     done
     haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
     if [ $RES -gt 1 ] ; then RES=1 ; fi
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Password Requirements - PASSWORD_LIFE_TIME = $PARAM111 ...."
     cat $TMPOUT >> $INFORMEORA 
     cat $TMPOUT >> $INFORME
     cat $RESULT | tee -a $INFORME | tee -a $INFORMEORA
     infor "${LIN}\n" ""
     inforora "${LIN}\n" ""
rm -f $DIR/ag_1_1_1_password_life_time.sql
rm -f $DIR/check_pwd.sql
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.1.2
CODIGOTECHSPEC="AG.1.1.2"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Passwords,...." && fff=1
     infor "AG.1.1.2" "Password Requirements - PASSWORD_GRACE_TIME - $PARAM112" 
     inforora "AG.1.1.2" "Password Requirements - PASSWORD_GRACE_TIME - $PARAM112"
     infor "Dias adicionales a la caducidad de password en la que es posible cambiar la password antes que expire la cuenta"
     infor "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     infor "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     inforora "Dias adicionales a la caducidad de password en la que es posible cambiar la password antes que expire la cuenta"
     inforora "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     inforora "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     RES=0
     >$RESULT
     >$TMPOUT
     for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
     do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         rm -f $DIR/ag_1_1_2_password_grace_time.log
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ag_1_1_2_password_grace_time.sql" >> $TMPOUT 
         res=0
         ag_1_1_2_password_grace_time $ins >> $RESULT
         let RES=$RES+$res
     done
     haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
     if [ $RES -gt 1 ] ; then RES=1 ; fi
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Password Requirements - PASSWORD_GRACE_TIME = $PARAM112...."
     cat $TMPOUT >> $INFORMEORA 
     cat $TMPOUT >> $INFORME
     cat $RESULT |tee -a $INFORMEORA | tee -a $INFORME
     infor "${LIN}\n" ""
     inforora "${LIN}\n" ""
rm -f $DIR/ag_1_1_2_password_grace_time.sql
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.1.4
CODIGOTECHSPEC="AG.1.1.4"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Passwords,...." && fff=1
     infor "AG.1.1.4" "Password Requirements - PASSWORD_REUSE_TIME - $PARAM114" 
     inforora "AG.1.1.4" "Password Requirements - PASSWORD_REUSE_TIME - $PARAM114"
     infor "Cantidad de dias que deben pasar antes de reutilizar una password."
     infor "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     infor "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     inforora "Cantidad de dias que deben pasar antes de reutilizar una password."
     inforora "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     inforora "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     RES=0
     >$RESULT
     >$TMPOUT
     for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
     do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         rm -f $DIR/ag_1_1_4_password_reuse_time.log
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ag_1_1_4_password_reuse_time.sql" >> $TMPOUT 
         res=0
         ag_1_1_4_password_reuse_time $ins >> $RESULT
         let RES=$RES+$res
     done
     haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
     if [ $RES -gt 1 ] ; then RES=1 ; fi
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Password Requirements - PASSWORD_REUSE_TIME = $PARAM114 ...."
     cat $TMPOUT >> $INFORMEORA 
     cat $TMPOUT >> $INFORME
     cat $RESULT | tee -a $INFORMEORA | tee -a $INFORME
     infor "${LIN}\n" ""
     inforora "${LIN}\n" ""
rm -f $DIR/ag_1_1_4_password_reuse_time.sql
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.1.5
CODIGOTECHSPEC="AG.1.1.5"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Passwords,...." && fff=1
     infor "AG.1.1.5" "Password Requirements - PASSWORD_REUSE_MAX - $PARAM115" 
     inforora "AG.1.1.5" "Password Requirements - PASSWORD_REUSE_MAX - $PARAM115"
     infor "Cantidad de password distintas que deben setearse antes de repetir una password."
     infor "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     infor "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     inforora "Cantidad de password distintas que deben setearse antes de repetir una password."
     inforora "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     inforora "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     RES=0
     >$RESULT
     >$TMPOUT
     for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
     do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         rm -f $DIR/ag_1_1_5_password_reuse_max.log
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ag_1_1_5_password_reuse_max.sql" >> $TMPOUT  
         res=0
         ag_1_1_5_password_reuse_max $ins >> $RESULT
         let RES=$RES+$res
     done
     haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
     if [ $RES -gt 1 ] ; then RES=1 ; fi
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Password Requirements - PASSWORD_REUSE_MAX = $PARAM115 ...."
     cat $TMPOUT >> $INFORMEORA 
     cat $TMPOUT >> $INFORME
     cat $RESULT | tee -a $INFORMEORA | tee -a $INFORME
     infor "${LIN}\n" ""
     inforora "${LIN}\n" ""
rm -f $DIR/ag_1_1_5_password_reuse_max.sql
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.1.6
CODIGOTECHSPEC="AG.1.1.6"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Passwords,...." && fff=1
     infor "AG.1.1.6" "Password Requirements - FAILED_LOGIN_ATTEMPTS - $PARAM116" 
     inforora "AG.1.1.6" "Password Requirements - FAILED_LOGIN_ATTEMPTS - $PARAM116"
     infor "Cantidad de fallos permitidos durante el login usando la password."
     infor "Superada la cantidad de fallos, el usuario queda en estado LOCKED, y no podra logarse hasta que no se desbloquee expresamente"
     infor "Si el usuario esta custodiado por SEGUR, esta herramienta desbloquea el usuario cuando le asigne una password"
     infor "en cambio si NO esta custodiado por SEGUR, el usuario debera desbloquearse expresamente por un DBA" 
     infor "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     infor "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     inforora "Cantidad de fallos permitidos durante el login usando la password."
     inforora "Superada la cantidad de fallos, el usuario queda en estado LOCKED, y no podra logarse hasta que no se desbloquee expresamente"
     inforora "Si el usuario esta custodiado por SEGUR, esta herramienta desbloquea el usuario cuando le asigne una password"
     inforora "en cambio si NO esta custodiado por SEGUR, el usuario debera desbloquearse expresamente por un DBA" 
     inforora "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     inforora "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     RES=0
     >$RESULT
     >$TMPOUT
     for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
     do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         rm -f $DIR/ag_1_1_6_failed_login_attempts.log
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ag_1_1_6_failed_login_attempts.sql" >> $TMPOUT 
         res=0
         ag_1_1_6_failed_login_attempts $ins >> $RESULT
         let RES=$RES+$res
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/check_retries.sql" > $DIR/${ins}.retries
     done
     haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
     if [ $RES -gt 1 ] ; then RES=1 ; fi
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Password Requirements - FAILED_LOGIN_ATTEMPTS = $PARAM116 ...."
     cat $TMPOUT >> $INFORMEORA 
     cat $TMPOUT >> $INFORME
     cat $RESULT | tee -a $INFORMEORA | tee -a $INFORME
     infor "${LIN}\n" ""
     inforora "${LIN}\n" ""
rm -f $DIR/ag_1_1_6_failed_login_attempts.sql
rm -f $DIR/check_retries.sql
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.1.7
CODIGOTECHSPEC="AG.1.1.7"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Passwords,...." && fff=1
     infor "AG.1.1.7" "Password Requirements - PASSWORD_LOCK_TIME - $PARAM117" 
     inforora "AG.1.1.7" "Password Requirements - PASSWORD_LOCK_TIME - $PARAM117"
     infor "Cantidad de dias que un usuario permanece en estado LOCKED despues de superar FAILED_LOGIN_ATTEMPTS"
     infor "Superada la cantidad de dias de PASSWORD_LOCK_TIME, Oracle desbloquea automaticamente al usuario para ahorrar tareas al DBA"
     infor "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     infor "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     inforora "Cantidad de dias que un usuario permanece en estado LOCKED despues de superar FAILED_LOGIN_ATTEMPTS"
     inforora "Superada la cantidad de dias de PASSWORD_LOCK_TIME, Oracle desbloquea automaticamente al usuario para ahorrar tareas al DBA"
     inforora "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     inforora "Los usuarios (NO LOCKED) de un profile que incumple la normativa aparecen inmediatamente por debajo del profile"
     RES=0
     >$RESULT
     >$TMPOUT
     for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
     do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         rm -f $DIR/ag_1_1_7_password_lock_time.log
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ag_1_1_7_password_lock_time.sql" >> $TMPOUT  
         res=0
         ag_1_1_7_password_lock_time $ins >> $RESULT
         let RES=$RES+$res
     done
     haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
     if [ $RES -gt 1 ] ; then RES=1 ; fi
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Password Requirements - PASSWORD_LOCK_TIME = $PARAM117 ...."
     cat $TMPOUT >> $INFORMEORA 
     cat $TMPOUT >> $INFORME
     cat $RESULT | tee -a $INFORMEORA | tee -a $INFORME
     infor "${LIN}\n" ""
     inforora "${LIN}\n" ""
rm -f $DIR/ag_1_1_7_password_lock_time.sql
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.1.8
CODIGOTECHSPEC="AG.1.1.8"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Passwords,...." && fff=1
     infor "AG.1.1.8" "Password Requirements - PASSWORD_VERIFY_FUNCTION" 
     inforora "AG.1.1.8" "Password Requirements - PASSWORD_VERIFY_FUNCTION"
     infor "La funcion de verificacion de password de un perfil, es utilizada durante el cambio de password."
     infor "No se aceptan PASSWORD_VERIFY_FUNCTION = NULL"
     infor "Las funciones asociadas, deben cumplir con los requisitos:"
     infor "  - Longitud de password usuarios privilegiados:  14 (caixa)"
     infor "  - Longitud de password usuarios generales: 8 (caixa/itnow)"
     infor "  - La password no debe conicidir con el nombre de usuario"
     infor "  - La password debe contener al menos 1 caracter alfabetico"
     infor "  - La password debe contener al menos 1 digito numerico"
     infor "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     infor "Solo revisamos los usuarios (NO LOCKED) que incumplen la normativa"
     inforora "La funcion de verificacion de password de un perfil, es utilizada durante el cambio de password."
     inforora "No se aceptan PASSWORD_VERIFY_FUNCTION = NULL"
     inforora "Las funciones asociadas, deben cumplir con los requisitos:"
     inforora "  - Longitud de password usuarios privilegiados:  14 (caixa)"
     inforora "  - Longitud de password usuarios generales: 8 (caixa/itnow)"
     inforora "  - La password no debe conicidir con el nombre de usuario"
     inforora "  - La password debe contener al menos 1 caracter alfabetico"
     inforora "  - La password debe contener al menos 1 digito numerico"
     inforora "Este parametro se setea a nivel de PROFILE. Para corregir un usuario que incumple, debe moverlo de PROFILE o modificar el PROFILE"
     inforora "Solo revisamos los usuarios (NO LOCKED) que incumplen la normativa"

     RES=0
     >$RESULT
     >$TMPOUT
     for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
     do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         rm -f $DIR/ag_1_1_8_password_verify_function.log
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ag_1_1_8_password_verify_function.sql" >> $TMPOUT  
         res=0
         ag_1_1_8_password_verify_function $ins >> $RESULT
         let RES=$RES+$res
     done
     haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
     if [ $RES -gt 1 ] ; then RES=1 ; fi
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Password Requirements - PASSWORD_VERIFY_FUNCTION ...."
     cat $TMPOUT >> $INFORMEORA 
     cat $TMPOUT >> $INFORME
     cat $RESULT | tee -a $INFORMEORA | tee -a $INFORME
     infor "${LIN}\n" ""
     inforora "${LIN}\n" ""
rm -f $DIR/ag_1_1_8_password_verify-function.sql
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.1.10
CODIGOTECHSPEC="AG.1.1.10"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Passwords,...." && fff=1
     infor "AG.1.1.10" "Password Requirements - Externally Identified Accounts (typically OPS$ accounts)" 
     inforora "AG.1.1.10" "Password Requirements - Externally Identified Accounts (typically OPS$ accounts)" 
     infor "         " "The 'identified externally' option may be used if remote_os_authent=false" 
     inforora "         " "The 'identified externally' option may be used if remote_os_authent=false" 
     RES=0
     >$RESULT
     >$TMPOUT
     for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
     do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/parameters.sql"
         OS_PREFIX=`grep -i OS_AUTHENT_PREFIX /tmp/show_parameter_oracle.lst | awk '{printf toupper($3);}' | tr '$' '\$'`
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/userexternal.sql $OS_PREFIX " >/dev/null
         res=0
         userexternal=""
         if [ -s /tmp/userexternal.lst ] 
         then
                 userexternal=`awk -F";" '{printf("%s ",$1);}' /tmp/userexternal.lst`
                 if [ -n "$userexternal" ] 
                 then
                      for uex in $userexternal
                      do 
                         authtype=`grep $uex /tmp/userexternal.lst | awk -F";" '{print $2}'`
                         ag_1_1_10_externaly_users $ins $uex $authtype >> $TMPOUT
                      done     
                 fi
                 if [ $res -eq 1 ]
                 then
                   echo -e "$NOK : --- instancia $ins --- Externally Identified Accounts mal configurados" >> $RESULT
                   fixora "$LIN" ""
                 else
                   echo -e "$OK  : --- instancia $ins --- Externally Identified Accounts bien configurados" >> $RESULT
                 fi
         else
               echo -e "$OK  : --- instancia $ins --- No tiene Externally Identified Accounts" >> $RESULT
               echo -e "$OK  : --- instancia $ins --- No tiene Externally Identified Accounts" >> $TMPOUT
         fi
         let RES=$RES+$res
     done
     haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
     if [ $RES -gt 1 ] ; then RES=1 ; fi
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Password Requirements - Externally Identified Accounts (typically OPS$ accounts) ...."
     cat $TMPOUT >> $INFORMEORA 
     cat $TMPOUT >> $INFORME
     cat $RESULT 
     infor "${LIN}\n" ""
     inforora "${LIN}\n" ""
rm -f $DIR/userexternal.sql
rm -f /tmp/userexternal.lst
rm -f /tmp/show_parameter_oracle.lst
echo $LIN
fi

#############################################################################
#### CODIGOTECHSPEC=AG.1.2.1
####    AUDITORIAS
audi=0
CODIGOTECHSPEC="AG.1.2.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
         echo "Auditorias,...." && audi=1
         infor "AG.1.2.1:"  "AUDITORIA:  Parametro AUDIT_TRAIL must be 'OS' or 'DB' or 'DB_EXTENDED'"
         infor "         "  "            si 'OS' : todos los ficheros de sistema *.aud del directorio destino  $AUDIT_FILE_DEST" ""
         infor "         "  "            deben tener owner=$USER y permisos=640" ""
         RES=0
         > $RESULT
         for base in $bases_levantadas   #####  se ejecutara cada techspech por todas las bases levantadas
         do
               ENVFILE=$DIR/envfile_$base
               ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
               USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
               runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/auditoria_oracle.sql"
               res=0
               ag_1_2_1_check_audit_trail $USER $ins >> $RESULT
               let RES=$RES+$res
         done
         haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
         if [ $RES -gt 1 ] ; then RES=1 ; fi
         OkNok $RES "${CODIGOTECHSPEC}${CODIGO} : AUDITORIAS: Parametro AUDIT_TRAIL must be 'OS' or 'DB' or 'DB_EXTENDED' ...." 
        cat $RESULT
##        if [ $RES -eq 1 ]
##        then
##            infor "        " "SENTENCIAS para activar AUDIT TRAIL: (valore cuidadosamente su activacion)"
##            infor "        " "    alter system set AUDIT_TRAIL=[os|db|db_extended];"
##            infor "        " "Y reinicie base de datos ....."
##            infor "        " "Si selecciona 'OS' recuerde setear:"
##            infor "        " "    alter system set AUDIT_FILE_DEST=directorio"
##            infor "        " "y segurese de tener espacio suficiente en ese directorio\n"
##            infor "        " "Si selecciona 'DB' o 'DB_EXENDED' utilice un tablespace independiente para la tabla AUD$"
##            infor "        " "y prepare un metodo de limpieza de la tabla AUD$ \n"
##        fi
echo $LIN | tee -a $INFORME 
fi
rm -f $DIR/auditoria_oracle.sql
#############################################################################
#### CODIGOTECHSPEC=AG.1.2.3

CODIGOTECHSPEC="AG.1.2.3"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $audi == 0 ]] &&  echo "Auditorias,...." && audi=1
    infor "AG.1.2.3:" "AUDITORIA:   Parametro SEC_PROTOCOL_ERROR_TRACE_ACTION must be 'LOG'"
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         ag_1_2_3_check_audit_param $ins >> $RESULT
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : AUDITORIAS: Parametro SEC_PROTOCOL_ERROR_TRACE_ACTION must be 'LOG' ...."
    cat $RESULT
##    if [ $RES -eq 1 ]
##    then
##       infor "        " "SENTENCIAS para activar SEC_PROTOCOL_ERROR_TRACE_ACTION: (valore cuidadosamente su activacion)"
##       infor "        " "    alter system set SEC_PROTOCOL_ERROR_TRACE_ACTION=LOG SCOPE=SPFILE"
##       infor "        " "Y reinicie base de datos .....\n"
##    fi
echo $LIN | tee -a $INFORME  
fi

#############################################################################
#### CODIGOTECHSPEC=AG.1.2.4
CODIGOTECHSPEC="AG.1.2.4"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $audi == 0 ]] &&  echo "Auditorias,...." && audi=1
    infor "AG.1.2.4:"  "AUDITORIA:  Parametro AUDIT_SYS_OPERATIONS  must be 'TRUE'" 
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         ag_1_2_4_check_audit_operacions $ins >>$RESULT
         rm  -f /tmp/isec_oracle_audit.lst
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    rm -f $DIR/auditoria_oracle.sql 
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : AUDITORIAS: Parametro AUDIT_SYS_OPERATIONS  must be 'TRUE' ...."
    cat $RESULT
##    if [ $RES -eq 1 ]
##    then
##       infor "        " "SENTENCIAS para activar AUDIT_SYS_OPERATIONS: (valore cuidadosamente su activacion)"
##       infor "        " "    alter system set AUDIT_SYS_OPERATIONS=TRUE SCOPE=SPFILE"
##       infor "        " "Y reinicie base de datos .....\n$LIN"
##    fi
echo $LIN |  tee -a $INFORME 
fi
#############################################################################
#### CODIGOTECHSPEC=AG.1.2.8
CODIGOTECHSPEC="AG.1.2.8"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    infor "AG.1.2.8:"  "DELETE_CATALOG_ROLE restricted to DBAs" 
    infor "         "  "Solo los roles/usuarios DBAs pueden tener este privilegio"
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         infor "\nInstance: $ins --- DELETE_CATALOG_ROLE restricted to DBAs\n----------------------------------------"
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/users_delete_catalog_role " >/dev/null
         res=0
         ag_1_2_8_users_delete_catalog_role $ins >>$RESULT
         cat /tmp/users_delete_catalog_role.lst >> $INFORME 
         cat /tmp/users_delete_catalog_role.lst >> $INFORMEORA 
         echo -e "$TEXTO_TECH \n" >> $INFORME
         echo -e "$TEXTO_TECH \n$LIN" >> $INFORMEORA
         rm  -f /tmp/users_delete_catalog_role.lst
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    rm -f $DIR/users_delete_catalog_role.sql 
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : LOGGING: DELETE_CATALOG_ROLE restricted to DBAs ...."
    cat $RESULT
echo $LIN |  tee -a $INFORME 
fi
para=0
#############################################################################
#### CODIGOTECHSPEC=AG.1.4.1
CODIGOTECHSPEC="AG.1.4.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    echo "Parametros,...." && para=1
    infor "AG.1.4.1"  "System Settings - Parameter O7_DICTIONARY_ACCESSIBILITY  must be FALSE"
    infor "        "  "Controls restrictions on SYSTEM privileges. "
    infor "        "  "If the parameter is set to true, access to objects in the SYS schema is allowed."
    infor "        "  "The default setting of false ensures that system privileges that allow access to objects in 'any schema'"
    infor "        "  "do not allow access to objects in the SYS schema."
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/parameters.sql"
         ag_1_4_1_param_o7_dictionary_accessibility $ins >>$RESULT
         inforora "${LIN}\n" ""
         rm -f /tmp/show_parameter_oracle.lst
         let RES=$RES+$res
    done
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : System Settings -  Parameter O7_DICTIONARY_ACCESSIBILITY  must be 'FALSE' ...."
    cat $RESULT
echo $LIN |  tee -a $INFORME 
fi
#############################################################################
#### CODIGOTECHSPEC=AG.1.4.3
CODIGOTECHSPEC="AG.1.4.3"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $para == 0 ]] &&  echo "Parametros,...." && para=1
    infor "AG.1.4.3"  "System Settings - Parameter REMOTE_OS_AUTHENT  must be FALSE"
    infor "        "  "Specifies whether remote clients will be authenticated with the value of the OS_AUTHENT_PREFIX parameter."
    infor "        "  "REMOTE_OS_AUTHENT parameter is deprecated. It is retained for backward compatibility only"
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/parameters.sql"
         ag_1_4_3_param_remote_os_authent $ins >>$RESULT
         inforora "${LIN}\n" ""
         rm -f /tmp/show_parameter_oracle.lst
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : System Settings -  Parameter REMOTE_OS_AUTHENT  must be 'FALSE' ...."
    cat $RESULT
echo $LIN |  tee -a $INFORME 
fi
#############################################################################
#### CODIGOTECHSPEC=AG.1.4.4
CODIGOTECHSPEC="AG.1.4.4"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $para == 0 ]] &&  echo "Parametros,...." && para=1
    infor "AG.1.4.4"  "System Settings - Parameter SEC_MAX_FAILED_LOGIN_ATTEMPTS  must be $PARAM116"
    infor "        "  "Specifies the number of authentication attempts that can be made by a client on a connection to the server process"

    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/parameters.sql"
         ag_1_4_4_param_sec_max_failed_login_attempts $ins >>$RESULT
         inforora "${LIN}\n" ""
         rm -f /tmp/show_parameter_oracle.lst
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : System Settings -  Parameter SEC_MAX_FAILED_LOGIN must be $PARAM116 ...."
    cat $RESULT
echo $LIN |  tee -a $INFORME 
fi
#############################################################################
#### CODIGOTECHSPEC=AG.1.4.5
CODIGOTECHSPEC="AG.1.4.5"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $para == 0 ]] &&  echo "Parametros,...." && para=1
    infor "AG.1.4.5"  "System Settings - Parameter SEC_RETURN_SERVER_RELEASE_BANNER  must be FALSE"
    infor "        "  "Specifies the server does not return complete database software information to clients."
    infor "        "  "FALSE: Only returns a generic version string to the client."
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/parameters.sql"
         ag_1_4_5_param_sec_return_server_release_banner $ins >>$RESULT
         inforora "${LIN}\n" ""
         rm -f /tmp/show_parameter_oracle.lst
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : System Settings - Parameter SEC_RETURN_SERVER_RELEASE_BANNER  must be 'FALSE' ...."
    cat $RESULT
echo $LIN |  tee -a $INFORME 
fi
#############################################################################
#### CODIGOTECHSPEC=AG.1.4.6
CODIGOTECHSPEC="AG.1.4.6"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $para == 0 ]] &&  echo "Parametros,...." && para=1
    infor "AG.1.4.6"  "System Settings - DB_NAME - Change the default ORCL database name"
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/parameters.sql"
         ag_1_4_6_param_db_name $ins >>$RESULT
         inforora "${LIN}\n" ""
         rm -f /tmp/show_parameter_oracle.lst
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : System Settings - DB_NAME - Change the default ORCL database name ...."
    cat $RESULT
echo $LIN |  tee -a $INFORME 
fi
#############################################################################
#### CODIGOTECHSPEC=AG.1.4.7
CODIGOTECHSPEC="AG.1.4.7"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $para == 0 ]] &&  echo "Parametros,...." && para=1
    infor "AG.1.4.7"  "System Settings - Parameter REMOTE_OS_ROLES  must be FALSE"
    infor "        "  "The default value, false, causes Oracle to identify and manage roles for remote clients."
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/parameters.sql"
         ag_1_4_7_remote_os_roles $ins >> $RESULT
         inforora "${LIN}\n" ""
         rm -f /tmp/show_parameter_oracle.lst
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : System Settings - Parameter REMOTE_OS_ROLES  must be 'FALSE' ...."
    cat $RESULT
echo $LIN | tee -a $INFORME 
fi
#############################################################################
#### CODIGOTECHSPEC=AG.1.4.8
CODIGOTECHSPEC="AG.1.4.8"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $para == 0 ]] &&  echo "Parametros,...." && para=1
    infor "AG.1.4.8"  "System Settings - Parameter UTL_FILE_DIR  must not be '*'"
    infor "        "  "Specify one or more directories that Oracle should use for PL/SQL file I/O."
    infor "        "  "Each directory on separate contiguous lines" 
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/parameters.sql"
         ag_1_4_8_utl_file_dir $ins >> $RESULT
         inforora "${LIN}\n" ""
         rm -f /tmp/show_parameter_oracle.lst
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : System Settings - Parameter UTL_FILE_DIR  must not be '*' ...."
    cat $RESULT
echo $LIN | tee -a $INFORME 
fi
rm -f $DIR/parameters.sql
###***********   permisos ficheros listener.ora, tnsnames.ora,  targets.xml, orapw$ORACLE_SID   *****************
###***********   la variable DIRECTORIOS_FIND tiene los directorios HOME encontrados en inventory.xml de todos los productos instalados
ggg=0
###########################################################################
#### CODIGOTECHSPEC=AG.1.5.1
CODIGOTECHSPEC="AG.1.5.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ggg == 0 ]] &&  echo "Network settings,...." && ggg=1
    infor "AG.1.5.1"  "Network Settings: Passwords of Listeners - Only required where LOCAL_OS_AUTHENTICATION_<LISTENER>=OFF (Oracle 10g and above)"
    infor "Nota:   "  "Remote listener authentication is enabled if  LOCAL_OS_AUTHENTICATION_<listener>=OFF, then you must set password for it"
    infor "        "  "in your listener.ora file with PASSWORDS_<listener_name> = password \n"
    infor "        "  "Refer base policy for password complexity requirements"
    RES=0
    ag_1_5_1_listener_password > $RESULT
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Network Settings -  Passwords of Listener - required where LOCAL_OS_AUTHENTICATION_<LISTENER>=OFF ...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi
###########################################################################
#### CODIGOTECHSPEC=AG.1.5.2
CODIGOTECHSPEC="AG.1.5.2"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ggg == 0 ]] &&  echo "Network settings,...." && ggg=1
    infor "AG.1.5.2"  "Network Settings - Listeners ports <> default-port 1521"
    infor "        "  "los ficheros listener.ora que usen el default port 1521 en algun LISTENER activo" 
    infor "        "  "deben reconfigurarse a otro puerto, aunque varias BDs podrian usar el mismo puerto\n"
    RES=0
    ag_1_5_2_port_1521 >$RESULT
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Network Settings - Listener Ports <> default-port 1521 and LISTENER name prohibited...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.5.3
CODIGOTECHSPEC="AG.1.5.3"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ggg == 0 ]] &&  echo "Network settings,...." && ggg=1
    infor "AG.1.5.3"  "Network Settings - LISTENER default name prohibited"
    infor "        " "Change default name LISTENER if possible\n"
    RES=0
    ag_1_5_3_listener_name >$RESULT
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Network Settings: 'LISTENER' default name prohibited...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.5.4
CODIGOTECHSPEC="AG.1.5.4"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ggg == 0 ]] &&  echo "Network settings,...." && ggg=1
    infor "AG.1.5.4"  "Network Settings - Set parameter SECURE_REGISTER_<listenername> in listener.ora (Oracle 10.2.0.3 or higher)"
    infor "        "  "Class of Secure Transport (COST) is used to restrict instance registration with listeners"
    infor "        "  "to only local and authorized instances having appropriate credentials."
    infor "        "  "See Oracle Support Notes 1340831.1(RAC) & 1453883.1(single instance), Addresses Oracle Security Alert CVE-2012-1675"
    infor "        "  "Note that implementing COST restrictions in RAC environments require the use of SSL/TLS encryption"
    RES=0
    ag_1_5_4_listener_secure_register >$RESULT
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Network Settings: LISTENER parameter SECURE_REGISTER_<listener> must be set in listener.ora...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi
#############################################################################
pass1=0
#############################################################################
#### CODIGOTECHSPEC=AG.1.7.1
CODIGOTECHSPEC="AG.1.7.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $pass1 == 0 ]] &&  echo "Passwords,...." && pass1=1
    infor "AG.1.7.1" "Identify and Authenticate Users - Users 'SYS', 'SYSTEM' no pueden tener default passwords"
    infor "Note: Unless required by the Applications, only active users need to be checked."
    infor "Change the passwords for any active accounts that the DBA_USERS_WITH_DEFPWD view lists."
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/passdefault.sql $ins"
         ag_1_7_1_defpwd $ins >>$RESULT
         inforora "${LIN}\n" ""
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  Users 'SYS', 'SYSTEM' no pueden tener default passwords ...."
    cat $RESULT
echo $LIN | tee -a $INFORME 
fi
rm -f $DIR/passdefault.sql
###########################################################################
#### CODIGOTECHSPEC=AG.1.7.3
CODIGOTECHSPEC="AG.1.7.3"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $pass1 == 0 ]] &&  echo "Passwords,...." && pass1=1
    infor "AG.1.7.3" "Identify and Authenticate Users - Users ORACLE PRODUCT (Service)  no pueden tener default passwords"
    infor "Note: Unless required by the Applications, only active users need to be checked."
    infor "Change the passwords for any active accounts that the DBA_USERS_WITH_DEFPWD view lists."
    infor "Oracle recommends that you do not assign these accounts passwords that they may have had in previous releases of Oracle Database."
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/passdefault_product_service.sql"
         ag_1_7_3_defpwd $ins >>$RESULT
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  ORACLE PRODUCT (Service) no deben tener default passwords ...."
    cat $RESULT
echo $LIN |tee -a $INFORME
fi
rm -f $DIR/passdefault_product_service.sql

uuu=0
###########################################################################
#### CODIGOTECHSPEC=AG.1.7.4
CODIGOTECHSPEC="AG.1.7.4"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $uuu == 0 ]] &&  echo "Usuarios,...." && uuu=1
    infor "AG.1.7.4" "Identify and Authenticate Users - Remove or lock DEMO Users SCOTT, ADAMS, JONES, CLARK, BLAKE, HR, OE, SH in Production Databases"
    infor "Note: Unless required by the Applications, only active users need to be checked."
    infor "For Oracle ERP, the use of hr, oe, and sh are required to support the application."
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/oracledemousers.sql"
         ag_1_7_4_oracledemousers $ins >> $RESULT
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users - DEMO Users SCOTT, ADAMS, JONES, CLARK, BLAKE, HR, OE, SH removed or locked ...."
    cat $RESULT
echo $LIN |tee -a $INFORME
fi
rm -f $DIR/oracledemousers.sql
###########################################################################
#### CODIGOTECHSPEC=AG.1.7.5
CODIGOTECHSPEC="AG.1.7.5"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $uuu == 0 ]] &&  echo "Usuarios,...." && uuu=1
    infor "AG.1.7.5" "Identify and Authenticate Users - Remove or lock User 'DBSNMP' if no remote database maintenance"
    infor "Note: Unless required by the Applications, only active users need to be checked."
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/dbsnmpuser.sql"
         ag_1_7_5_dbsnmpuser $ins >>$RESULT
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  DBSNMP User removed or locked if no remote database maintenance...."
    cat $RESULT
echo $LIN | tee -a $INFORME
fi
rm -f $DIR/dbsnmpuser.sql

ppp=0
###########################################################################
#### CODIGOTECHSPEC=AG.1.7.6
CODIGOTECHSPEC="AG.1.7.6"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ppp == 0 ]] &&  echo "Privileges,...." && ppp=1
    infor "AG.1.7.6" "Identify and Authenticate Users - General Users Roles/Privileges:" 
    infor "        " "Only CONNECT, RESOURCE (role or equivalent privilege grant) may be granted" 
    infor "        " "Excluding Oracle service account and DBA userids, these are the only privileges and roles"
    infor "        " "which may be granted to a non-DBA or non-Oracle service users"
    infor "        " "Se excluyen adicionalmente LOCKED accounts y OPS\$ISYSAD1 (SEGUR)"
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/privgeneral.sql"
         ag_1_7_6_privgeneral $ins >>$RESULT
         inforora "${LIN}\n" ""
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  General Users Roles/Privileges only CONNECT/RESOURCE may be granted...."
    cat $RESULT
echo $LIN |tee -a $INFORME
fi

rm -f $DIR/privgeneral.sql

###########################################################################
#### CODIGOTECHSPEC=AG.1.7.7
CODIGOTECHSPEC="AG.1.7.7"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ppp == 0 ]] &&  echo "Privileges,...." && ppp=1
    infor "AG.1.7.7" "Identify and Authenticate Users - Direct login should not be enabled. Access should be via sudo."
    infor "        " "(for Operating system accounts used for managing Oracle software and databases)"
    infor "        " "Estos usuarios deben tener bloqueado el acceso en /etc/shadow y mediante SSH" 
    infor "        " "EXCEPCION: "
    infor "        " "Si existe alguna instancia Cluster RAC, debe permitirse el direct login via SSH entre los hostnames del cluster"
    inforsis "AG.1.7.7" "Identify and Authenticate Users - Direct login should not be enabled. Access should be via sudo."
    inforsis "        " "(for Operating system accounts used for managing Oracle software and databases)"
    inforsis "        " "Estos usuarios deben tener bloqueado el acceso en /etc/shadow y mediante SSH" 
    inforsis "        " "EXCEPCION: "
    inforsis "        " "Si existe alguna instancia Cluster RAC, debe permitirse el direct login via SSH entre los hostnames del cluster"
    RES=0
    > $RESULT
    lista_users=`grep ORACLE_USER $DIR/envfile* | awk -F"=" '{print $2}' | sort -u | tr -s '\n' ' '`
    > direct_login
    for softowner in $lista_users
    do
         res=0
         ag_1_7_7_direct_login $softowner >>$RESULT
         let RES=$RES+$res
    done
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  Direct login should not be enabled ...."
    cat $RESULT
    cat direct_login >>  $INFORME
    cat direct_login >>  $INFORMESIS

echo $LIN |tee -a $INFORME | tee -a $INFORMESIS
fi

rm -f direct_login
rm -f $DIR/single_rac_instance.sql
rm -f $DIR/rac_instance.sql

###########################################################################
#### CODIGOTECHSPEC=AG.1.7.8
CODIGOTECHSPEC="AG.1.7.8"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    echo "Oracle-software owners restricted to Oracle-software groups (typically dba/oinstall)...." 
    infor "AG.1.7.8" "Identify and Authenticate Users - Oracle-software owners restricted to Oracle-software groups (typically dba/oinstall)" 
    inforsis "AG.1.7.8" "Oracle-software owners restricted to Oracle-software groups (typically dba/oinstall)" 
    infor "        " "Oracle-software groups restricted to DBAs"
    inforsis "        " "Oracle-software groups restricted to DBAs"
    RES=0
    > $RESULT
    direc=""
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ORACLE_HOME=`grep "ORACLE_HOME" $ENVFILE | awk -F"=" '{print $2}'`
         ORACLE_GRID=`grep "ORACLE_GRID" $ENVFILE | awk -F"=" '{print $2}'`
         ORACLE_AGENT=`grep "ORACLE_AGENT" $ENVFILE |awk -F"=" '{print $2}'` 
         if [ `echo "$direc" | grep -c "$ORACLE_HOME"` -eq 0  ]
         then
              ag_1_7_8_software_owner_groups $ORACLE_HOME >> $RESULT 
              direc="$ORACLE_HOME $direc" 
              let RES=$RES+$res
         fi
    done
    ag_1_7_8_software_owner_groups $ORACLE_GRID >> $RESULT 
    let RES=$RES+$res
    ag_1_7_8_software_owner_groups $ORACLE_AGENT >> $RESULT 
    let RES=$RES+$res
    if [ $RES -gt 1 ] ; then RES=1 ; fix "$LIN" "" ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users - Oracle-software owners restricted to Oracle-software groups (typically dba/oinstall)...."
    cat $RESULT
echo $LIN | tee -a $INFORME | tee -a $INFORMESIS
fi
###########################################################################
#### CODIGOTECHSPEC=AG.1.7.9.1
CODIGOTECHSPEC="AG.1.7.9.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ppp == 0 ]] &&  echo "Privileges,...." && ppp=1
    infor "AG.1.7.9.1" "Identify and Authenticate Users - DBA Roles granted only to DBAs and Oracle service accounts:" 
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/privdba.sql"
         ag_1_7_9_1_privdba $ins >>$RESULT
         let RES=$RES+$res
         inforora "${LIN}\n" ""
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  Rol DBA only granted to DBAs or Oracle service accounts...."
    cat $RESULT
echo $LIN |tee -a $INFORME
fi
rm -f $DIR/privdba.sql

###########################################################################
#### CODIGOTECHSPEC=AG.1.7.9.2
CODIGOTECHSPEC="AG.1.7.9.2"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ppp == 0 ]] &&  echo "Privileges,...." && ppp=1
    infor "AG.1.7.9.2" "Identify and Authenticate Users - Privilege SYSDBA, SYSOPER granted only to DBAs and Oracle service accounts:" 
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/privsysdbaoper.sql"
         ag_1_7_9_2_privsysdbaoper $ins >> $RESULT
         inforora "${LIN}\n" ""
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  SYSDBA, SYSOPER only granted to DBAs or Oracle service accounts...."
    cat $RESULT
echo $LIN |tee -a $INFORME
fi
rm -f $DIR/privsysdbaoper.sql

lll=0
###########################################################################
#### CODIGOTECHSPEC=AG.1.7.12
CODIGOTECHSPEC="AG.1.7.12"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $lll == 0 ]] &&  echo "Config,...." && lll=1
    infor "AG.1.7.12" "Identify and Authenticate Users - Do not use 'dba' name for the OSDBA group for new buildings" 
    infor "         " "Changing this group from the generic name makes attacking the OS harder"
    infor "         " "Note. This is a requirement for new builds and should be discussed with the DBA prior to retrofitting this into existing environments."
    inforsis "AG.1.7.12" "Identify and Authenticate Users - Do not use 'dba' name for the OSDBA group for new buildings" 
    inforsis "         " "Changing this group from the generic name makes attacking the OS harder"
    inforsis "         " "Note. This is a requirement for new builds and should be discussed with the DBA prior to retrofitting this into existing environments."
    RES=0
    >$RESULT
    for dir in $DIRECTORIOS_FIND
    do
        res=0
        ag_1_7_12_osdba_group $dir >>$RESULT 
        let RES=$RES+$res
    done
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  Do not use 'dba' name for the OSDBA group...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.7.14
CODIGOTECHSPEC="AG.1.7.14"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ppp == 0 ]] &&  echo "Privileges,...." && ppp=1
    infor "AG.1.7.14" "Identify and Authenticate Users - Admin account CTXSYS for Oracle Text feature"
    infor "         " "if account CTXSYS does not exist: OK"
    infor "         " "if context is not being used drop CTXSYS user"
    infor "         " "if conext is being used lock CTXSYS user" 
    infor "         " "Revoke all access to CTXSYS packages from PUBLIC\n"
    RES=0
    > $RESULT
    TMPOUT=tmpout1
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ctxsysuser.sql"
         grep -q "CTXSYS" /tmp/ctxsysuser.lst
         if [ $? -eq 0 ]
         then
               ag_1_7_14_ctxsys_user $ins >>$RESULT
               let RES=$RES+$res
               runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/ctxsys_priv.sql" | grep -v "successfully completed" > $TMPOUT 
               ag_1_7_14_ctxsys_priv $ins >>$RESULT
               let RES=$RES+$res
               rm -f $DIR/ctxsys_priv.sql
         else
               infor "$OK: User CTXSYS does not exist."
               echo -e "$OK: --- instancia $ins --- User CTXSYS does not exist" >> $RESULT
         fi
         inforora "${LIN}\n" ""
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  CTXSYS User and Package Privileges...."
    cat $RESULT
    infor "${LIN}\n" ""
echo $LIN
fi
rm -f $DIR/ctxsys_priv.sql
rm -f $DIR/ctxsysuser.sql

###########################################################################
#### CODIGOTECHSPEC=AG.1.7.15
CODIGOTECHSPEC="AG.1.7.15"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ppp == 0 ]] &&  echo "Privileges,...." && ppp=1
    infor "AG.1.7.15" "Identify and Authenticate Users - Privilege WITH ADMIN  granted only to DBAs and Oracle service accounts:" 
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/privwithadmin.sql"
         ag_1_7_15_privwithadmin $ins >> $RESULT
         inforora "${LIN}\n" ""
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  'WITH ADMIN OPTION' granted only to DBAs or Oracle service accounts...."
    cat $RESULT
    infor "${LIN}\n" ""
echo $LIN
fi
rm -f $DIR/privwithadmin.sql
###########################################################################
#### CODIGOTECHSPEC=AG.1.7.16
CODIGOTECHSPEC="AG.1.7.16"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ppp == 0 ]] &&  echo "Privileges,...." && ppp=1
    infor "AG.1.7.16" "Identify and Authenticate Users - PACKAGES/VIEW con privilegio EXECUTE from PUBLIC" ""
    inforora "AG.1.7.16" "Identify and Authenticate Users - PACKAGES/VIEW con privilegio EXECUTE from PUBLIC" ""
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/public.sql" | grep -v "successfully completed" |  tee -a $INFORMEORA | tee -a $INFORME >/dev/null
         ag_1_7_16_packages_privilegios $ins >>$RESULT
         inforora "${LIN}\n" ""
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Identify and Authenticate Users -  'PACKAGES/VIEW with EXECUTE from PUBLIC privilege...."
    cat $RESULT
    infor "${LIN}\n" ""
echo $LIN
fi
rm -f $DIR/public.sql

fff=0
###########################################################################
#### CODIGOTECHSPEC=AG.1.8.1
CODIGOTECHSPEC="AG.1.8.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Ficheros de base de datos,...." && fff=1
    infor "AG.1.8.1" "Protecting resources OSRs - Database Files (datafiles, controlfiles, redolog files, temporary files) Unix permission 600"
    infor "        " "ASM Database Files have no Unix permission settings"
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/database.sql"
         ag_1_8_1_datafiles $ins >>$RESULT
         inforsis "${LIN}\n" ""
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} :  Protecting resources OSRs - DataFiles/RedologFiles/TempFiles/ControlFiles con permisos Unix 600...."
    cat $RESULT
    infor "${LIN}\n" ""
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.8.5
CODIGOTECHSPEC="AG.1.8.5"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Ficheros de base de datos,...." && fff=1
    infor "AG.1.8.5" "Protecting resources OSRs - Archivelog Files, Unix permission: 640"
    inforsis "AG.1.8.5" "Protecting resources OSRs - Archivelog Files, Unix permission: 640"
    infor "        " "ASM Archivelog Files have no UNIX permission settings"
    inforsis "        " "ASM Archivelog Files have no UNIX permission settings"
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/archivelog.sql"
         ag_1_8_5_archivelog $ins >>$RESULT
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} :  Protecting resources OSRs - 'ArchiveLog' Files con permisos Unix 640...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi
rm -f $DIR/archivelog.sql

###########################################################################
#### CODIGOTECHSPEC=AG.1.8.6
CODIGOTECHSPEC="AG.1.8.6"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Ficheros de base de datos,...." && fff=1
    infor "AG.1.8.6" "Protecting resources OSRs - Alert log Files, Unix permission: 640"
    inforsis "AG.1.8.6" "Protecting resources OSRs - Alert log Files, Unix permission: 640"

    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/background_dest.sql"
         ag_1_8_6_alertlog $ins >>$RESULT
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} :  Protecting resources OSRs - 'AlertLog' files con permisos Unix 640...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi
rm -f $DIR/background_dest.sql
rm -f /tmp/oracle_background_dest.lst

###########################################################################
#### CODIGOTECHSPEC=AG.1.8.7
CODIGOTECHSPEC="AG.1.8.7"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Ficheros,...." && fff=1
    infor  "AG.1.8.7:" "Protecting resources OSRs - init<SID>.ora, spfile<SID>.ora, config.ora - permisos: 640 o mas restrictivos"
    inforsis  "AG.1.8.7:" "Protecting resources OSRs - init<SID>.ora, spfile<SID>.ora, config.ora - permisos: 640 o mas restrictivos"

    [ -e ficheros_encontrados ] && grep -q "spfile*.ora" ficheros_encontrados
    if [ $? -eq 1 ]
    then
         find $DIRECTORIOS_FIND -name spfile*.ora -ls | awk -v NOK=$NOK -v OK=$OK '{if($3!~"-[-r][-w]-[-r]-----") print NOK":  "$3";"$11";deberia tener permiso: -rw-r----- o mas restrictivo";else print OK":  "$3";"$11}'  >> ficheros_encontrados
    fi
    [ -e ficheros_encontrados ] && grep -q "init*.ora" ficheros_encontrados
    if [ $? -eq 1 ]
    then
         find $DIRECTORIOS_FIND  -name init*.ora -a -name init"${ORACLE_SID}".ora  -ls | awk -v NOK=$NOK -v OK=$OK '{if($3!~"-[-r][-w]-[-r]-----") print NOK":  "$3";"$11";deberia tener permiso: -rw-r----- o mas restrictivo";else print OK":  "$3";"$11}'  >> ficheros_encontrados
    fi
    [ -e ficheros_encontrados ] && grep -q "init*.ora" ficheros_encontrados
    if [ $? -eq 1 ]
    then
         find $DIRECTORIOS_FIND -name config.ora -ls | awk -v NOK=$NOK -v OK=$OK '{if($3!~"-rw-[-r]-----") print NOK":  "$3";"$11";deberia tener permiso: -rw-r----- o mas restrictivo";else print OK":  "$3";"$11}'  >> ficheros_encontrados
    fi
    RES=0
    >$RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         res=0
         ag_1_8_7_permisos_init_spfile $ins >>$RESULT
         let RES=$RES+$res
    done
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Protecting resources OSRs - Database Initialization files init<SID>.ora,spfile<SID>.ora,config.ora Unix permission 640...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.8.11.1
CODIGOTECHSPEC="AG.1.8.11.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Ficheros,...." && fff=1
     infor "AG.1.8.11.1" "Protecting resources OSRs - oratab file, with oracle-software-owner, oracle-group" 
     inforsis "AG.1.8.11.1" "Protecting resources OSRs - oratab file, with oracle-software-owner, oracle-group"
     RES=0
     >$RESULT
     ag_1_8_11_1_oratab >> $RESULT
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Protecting resources OSRs - 'oratab' files, with oracle-software-onwe/oracle-group...."
     cat $RESULT
     infor "${LIN}\n" ""
     inforsis "${LIN}\n" ""
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.8.11.2
CODIGOTECHSPEC="AG.1.8.11.2"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Ficheros,...." && fff=1
     infor "AG.1.8.11.2" "Protecting resources OSRs - oraInst.loc files, with oracle-software-owner, oracle-group" 
     inforsis "AG.1.8.11.2" "Protecting resources OSRs - oraInst.loc files, with oracle-software-owner, oracle-group"
     RES=0
     >$RESULT
     ag_1_8_11_2_oraInst >> $RESULT
     let RES=$RES+$res
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Protecting resources OSRs - 'oraInst.loc' files, with oracle-software-onwe/oracle-group...."
     cat $RESULT
     infor "${LIN}\n" ""
     inforsis "${LIN}\n" ""
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.8.11.3
CODIGOTECHSPEC="AG.1.8.11.3"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Ficheros,...." && fff=1
     infor "AG.1.8.11.3" "Protecting resources OSRs - listener.ora files, with oracle-software-owner, oracle-group" 
     inforsis "AG.1.8.11.3" "Protecting resources OSRs - listener.ora files, with oracle-software-owner, oracle-group"
     RES=0
     > $RESULT
     ag_1_8_11_3_listener >>$RESULT 
     let RES=$RES+$res
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : protecting resources OSRs - 'listener.ora' files, with oracle-software-onwe/oracle-group...."
     cat $RESULT
     infor "${LIN}\n" ""
     inforsis "${LIN}\n" ""
echo $LIN
fi
###########################################################################
#### CODIGOTECHSPEC=AG.1.8.11.4
CODIGOTECHSPEC="AG.1.8.11.4"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $fff == 0 ]] &&  echo "Ficheros,...." && fff=1
     infor "AG.1.8.11.4" "Protecting resources OSRs - tnsnames.ora files, with oracle-software-owner, oracle-group" 
     inforsis "AG.1.8.11.4" "Protecting resources OSRs - tnsnames.ora files, with oracle-software-owner, oracle-group"
     RES=0
     >$RESULT
     ag_1_8_11_4_tnsnames >>$RESULT
     let RES=$RES+$res
     OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Protecting resources OSRs - 'tnsnames.ora' files, with oracle-software-onwe/oracle-group...."
     cat $RESULT
     infor "${LIN}\n" ""
     inforsis "${LIN}\n" ""
echo $LIN
fi
ddd=0
###########################################################################
#### CODIGOTECHSPEC=AG.1.8.12
CODIGOTECHSPEC="AG.1.8.12"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    [[ $ddd == 0 ]] &&  echo "Directorios de base de datos,...." && ddd=1
    infor "AG.1.8.12" "Protecting resources OSRs - Directories containing the database files: oracle software owner, Unix permisos: 750" 
    inforsis "AG.1.8.12" "Protecting resources OSRs - Directories containing the database files: oracle software owner, Unix permisos: 750" 
    RES=0
    > $RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         USER=`grep ORACLE_USER $ENVFILE |   awk -F"=" '{print $2}'`
         res=0
         if [ ! -e /tmp/oracle_datafiles.lst ]
         then
              runuser -l $USER -c "$SHEL $ENVFILE ; sqlplus -s /nolog @$DIR/database.sql"
         fi
         ag_1_8_12_directorios_bd $ins >>$RESULT
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Protecting resources OSRs -  Directories containing the database files: oracle-software-owner, Unix permisos 750...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi
rm -f $DIR/database.sql

###########################################################################
#### CODIGOTECHSPEC=AG.1.8.13
CODIGOTECHSPEC="AG.1.8.13"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    

    infor "AG.1.8.13.1:" "Protecting resources OSRs - Scripts detected from crontab files of the 'dba' OS users are not world writable"
    inforsis "AG.1.8.13.1:" "Protecting resources OSRs - Scripts detected from crontab files of the 'dba' OS users are not world writable"
    echo Crones,.....
    RES=0
    > $RESULT
    users_hechos=""

    ORACLE_HOME=`grep ORACLE_HOME $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
    ORACLE_GRID=`grep ORACLE_GRID $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`
    ORACLE_AGENT=`grep ORACLE_AGENT $DIR/envfile* | sort -u |  awk -F"=" '{printf("%s ",$2)}'`

    for ORACLEHOME in $ORACLE_HOME $ORACLE_GRID $ORACLE_AGENT
    do

         if [ $ORACLEHOME != $ORACLE_AGENT ] ; then

              CONFIGC=$ORACLEHOME/rdbms/lib/config.c

              if [ -e $CONFIGC ]
              then
                   if [ "$ORACLEHOME" != "$ORACLE_AGENT" ]
                   then
                       osdbagroup=`grep "#define" $CONFIGC | grep "SS_DBA_GRP" | awk '{print $3}' | tr -d '"'`
                       softowner=`grep "^ORACLE_OWNER=" $ORACLEHOME/install/utl/rootmacro.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                   fi
              fi
         else
              if [ -e "$ORACLE_AGENT"/root.sh ] ; then
                    if [ `grep -c "^ORACLE_OWNER" $ORACLE_AGENT/root.sh` -gt 0 ] ; then
                        osdbagroup=`grep "^OSDBA_GROUP=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                        softowner=`grep "^ORACLE_OWNER=" $ORACLE_AGENT/root.sh | tail -1 | awk -F"=" '{printf("%s",$2); }'`
                    else
                         if [ `grep -c "gcroot.sh" $ORACLE_AGENT/root.sh |  grep -v "^#"` -gt 0 ] ; then
                              buscafile=`grep "gcroot.sh" $ORACLE_AGENT/root.sh |tail -1`
                              if [ -f $buscafile ] ; then
                                  osdbagroup=`grep "^OSDBA_GROUP=" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                                  softowner=`grep "^ORACLE_OWNER" $buscafile | tail -1 | awk -F"=" '{printf("%s",$2);}'`
                              fi
                         fi
                    fi
              fi

         fi
 
         echo "$users_hechos" | grep -q $softowner
         if [ $? -eq 1 ]
         then
             ag_1_8_13_1_crons $softowner >>$RESULT
             users_hechos="$softowner $users_hechos"
             let RES=$RES+$res
         fi
         unset listagrupo
         group_users $osdbagroup listagrupo
         for u1 in $listagrupo
         do
            echo "$users_hechos" |grep -q $u1
            if [ $? -eq 1 ]
            then
                ag_1_8_13_1_crons $u1 >>$RESULT
                users_hechos="$softowner $users_hechos"
                let RES=$RES+$res
            fi
         done
    done
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Protecting resources OSRs -  Scripts detected from crontab files of 'dba' users are not world writable...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi
zzz=0
###########################################################################
#### CODIGOTECHSPEC=AG.1.8.14
CODIGOTECHSPEC="AG.1.8.14"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
        [ $zzz -eq 0 ] && echo "Ficheros, ...." && zzz=1
        infor "AG.1.8.14:" "Protecting resources OSRs - listener.ora - permisos: 600"
        inforsis "AG.1.8.14:" "Protecting resources OSRs - listener.ora - permisos: 600"
        RES=0
        >$RESULT
        ag_1_8_14_listener_ora >>$RESULT
        let RES=$RES+$res
        OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} :  Protecting resources OSRs - 'listener.ora' files deben tener permisos 600 o mas restrictivos...."
        cat $RESULT
        infor "${LIN}\n" ""
        inforsis "${LIN}\n" ""
echo $LIN
fi
        
###########################################################################
#### CODIGOTECHSPEC=AG.1.8.15
CODIGOTECHSPEC="AG.1.8.15"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
        [ $zzz -eq 0 ] && echo "Ficheros, ...." && zzz=1
        infor  "AG.1.8.15:" "Protecting resources OSRs - tnsnames.ora - permisos: 644 o mas restrictivos"
        inforsis  "AG.1.8.15:" "Protecting resources OSRs - tnsnames.ora - permisos: 644 o mas restrictivos"
        RES=0
        >$RESULT
        ag_1_8_15_tnsnames_ora >>$RESULT
        let RES=$RES+$res
        OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} :  Protecting resources OSRs - 'tnsnames.ora' files deben tener permisos 600 o mas restrictivos...."
        cat $RESULT
        infor "${LIN}\n" ""
        inforsis "${LIN}\n" ""
echo $LIN
fi
###########################################################################
#### CODIGOTECHSPEC=AG.1.8.16
CODIGOTECHSPEC="AG.1.8.16"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
        [ $zzz -eq 0 ] && echo "Ficheros, ...." && zzz=1
    infor "AG.1.8.16:" "Protecting resources OSRs - orapw<SID> - permisos: 640 o mas restrictivos"
    inforsis "AG.1.8.16:" "Protecting resources OSRs - orapw<SID> - permisos: 640 o mas restrictivos"
    RES=0
    >$RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         res=0
         ag_1_8_16_orapwdSID $ins >>$RESULT
         let RES=$RES+$res
    done
    if [ $RES -gt 1 ] ; then RES=1 ; fi
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Protecting resources OSRs - 'orapw<SID>' files deben tener permisos 640 o mas restrictivos...."
    cat $RESULT
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi
###########################################################################
#### CODIGOTECHSPEC=AG.1.8.17
CODIGOTECHSPEC="AG.1.8.17"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
        [ $zzz -eq 0 ] && echo "Ficheros, ...." && zzz=1
        infor  "AG.1.8.17:" "Protecting resources OSRs - targets.xml (Oracle EM Grid Agent configuration file) - permisos: 644 o mas restrictivos"
        inforsis  "AG.1.8.17:" "Protecting resources OSRs - targets.xml (Oracle EM Grid Agent configuration file) - permisos: 644 o mas restrictivos"
        RES=0
        >$RESULT
        ag_1_8_17_targets_xml >>$RESULT
        let RES=$RES+$res
        OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} : Protecting resources OSRs - 'targets.xml' files deben tener permisos 644 o mas restrictivos...."
        cat $RESULT
        infor "${LIN}\n" ""
        inforsis "${LIN}\n" ""
echo $LIN
fi

#####************************************************************************************************

###########################################################################
#### CODIGOTECHSPEC=AG.1.9.1.1
CODIGOTECHSPEC="AG.1.9.1.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    infor "AG.1.9.1.1:"  "Protecting resources - User Resources : Umask for Oracle user - x022 for installation and maintenance of Oracle binaries\n"
    inforsis "AG.1.9.1.1:"  "Protecting resources - User Resources : Umask for Oracle user - x022 for installation and maintenance of Oracle binaries\n"
    RES=0
    >$RESULT
    ag_1_9_1_1_umasks_binaries >> $RESULT
    let RES=$RES+$res
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} :  UMASK must be 022 for installation and maintenance of Oracle binaries ...."
    cat umask_binarios_oracle >> $INFORME
    cat umask_binarios_oracle >> $INFORMESIS
    infor "\n" "" 
    inforsis "\n" "" 
    cat $RESULT | tee -a $INFORME | tee -a $INFORMESIS
    rm -f umask_binarios_oracle
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi

###########################################################################
#### CODIGOTECHSPEC=AG.1.9.1.2
CODIGOTECHSPEC="AG.1.9.1.2"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    infor "AG.1.9.1.2:"  "Protecting resources - User Resources : Umask for Oracle user - x027 for Daily operations\n"
    inforsis "AG.1.9.1.2:"  "Protecting resources - User Resources : Umask for Oracle user - x027 for Daily operations\n"
    RES=0
    >$RESULT
    ag_1_9_1_2_umasks_daily >>$RESULT
    let RES=$RES+$res
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} :  UMASK de Oracle user must be 027 - Daily operations...."
    cat $RESULT | tee -a $INFORME | tee -a $INFORMESIS
    infor "${LIN}\n" ""
    inforsis "${LIN}\n" ""
echo $LIN
fi

###########################################################################
####  CODIGOTECHSPEC=AG.5.0.1
CODIGOTECHSPEC="AG.5.0.1"
testtechspeccomprobar $CODIGOTECHSPEC
if [ $? -eq 0 ]
then    
    infor "AG.5.0.1:"  "Privileged Authorizations/Userids\n"
    infor "The Database actions listed in 5.0.1.x are considered privileged. "
    infor "Access to these allows users to change security/compliance requirements "
    infor "and/or impact the stability of the supported environment\n"
    infor "('ALTER DATABASE','ALTER PROFILE','ALTER SYSTEM','ALTER TABLESPACE','ALTER USER')"
    infor "('AUDIT ANY','AUDIT SYSTEM')"
    infor "('CREATE ANY JOB','CREATE PROFILE','CREATE ROLLBACK SEGMENT','CREATE TABLESPACE','CREATE USER')"
    infor "('DROP RPOFILE','DROP ROLLBACK SEGMENT','DROP TABLESPACE','DROP USER')"
    infor "('GRANT ANY OBJECT PRIVILEGE','GRANT ANY PRIVILEGE','GRANT ANY ROLE')"
    infor "('MANAGE TABLESPACE','RESTRICTED SESSION')"
    infor "\nThe next list describe the UserIDs or groups that have Privileged authority (NO LOCKED UserIDs):"
    inforora "AG.5.0.1:"  "Privileged Authorizations/Userids\n"
    inforora "The Database actions listed in 5.0.1.x are considered privileged. "
    inforora "Access to these allows users to change security/compliance requirements "
    inforora "and/or impact the stability of the supported environment\n"
    inforora "('ALTER DATABASE','ALTER PROFILE','ALTER SYSTEM','ALTER TABLESPACE','ALTER USER')"
    inforora "('AUDIT ANY','AUDIT SYSTEM')"
    inforora "('CREATE ANY JOB','CREATE PROFILE','CREATE ROLLBACK SEGMENT','CREATE TABLESPACE','CREATE USER')"
    inforora "('DROP RPOFILE','DROP ROLLBACK SEGMENT','DROP TABLESPACE','DROP USER')"
    inforora "('GRANT ANY OBJECT PRIVILEGE','GRANT ANY PRIVILEGE','GRANT ANY ROLE')"
    inforora "('MANAGE TABLESPACE','RESTRICTED SESSION')"
    inforora "\nThe next list describe the UserIDs or groups that have Privileged authority (NO LOCKED UserIDs):"
    RES=0
    >$RESULT
    for base in $bases_levantadas
    do
         ENVFILE=$DIR/envfile_$base
         ins=`grep ORACLE_SID $ENVFILE | awk -F"=" '{print $2}'`
         res=0
         orauser=`grep ORACLE_USER $ENVFILE | awk -F"=" '{print $2}'`
         users=`runuser -l $orauser -c "$SHEL ${ENVFILE} ; sqlplus -s /nolog @$DIR/orausers.sql" | tr -s '\n' ' '`
         infor "\nAG.5.0.1 --- instancia $ins --- Privileged Authorizations/Userids"
         inforora "\nAG.5.0.1 --- instancia $ins --- Privileged Authorizations/Userids"
         ag_5_0_1_privileged_auth $ins $users  >>$RESULT
         cat $TMPOUT >> $INFORME 
         cat $TMPOUT >> $INFORMEORA
         if [ $res -eq 1 ]
         then 
             infor "$NOK: --- instancia $ins --- Existen usuarios con autorizaciones privilegiadas"
             inforora "$NOK: --- instancia $ins --- Existen usuarios con autorizaciones privilegiadas"
         else
             infor "$OK: --- instancia $ins --- No existen usuarios con  autorizaciones privilegiadas salvo los DBAs y Oracle Services Accounts"
             inforora "$OK: --- instancia $ins --- No existen usuarios con  autorizaciones privilegiadas salvo los DBAs y Oracle Services Accounts"
         fi
         inforora "${LIN}\n" ""
         let RES=$RES+$res
    done
    haybds     ####  funcion que mira si no hay BDs, en cuyo caso este check debe ser correcto y graba  en RESULT
    if [ $RES -gt 1 ]; then RES=1 ; fi 
    OkNok $RES  "${CODIGOTECHSPEC}${CODIGO} :  Privileged Authorizations/Userids  ...."
    cat $RESULT
    infor "${LIN}\n" ""
echo $LIN
fi


[ -s fichora ] && cat fichora >> $DIR/temporales/ficheros_encontrados_$DIA
[ -s ficheros_encontrados ] && cat ficheros_encontrados >> $DIR/temporales/ficheros_encontrados_$DIA

eliminar_sqls
rm -f ficheros_encontrados fichora resultado tmpout1

limpia_errorlog

