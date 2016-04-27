#FASE1-PREREQUISITOS
#Identificar tipo de replica

#Comprobar Backup

#Backup binarios BBDD
cd $ORACLE_HOME
tar cvf – .|gzip -c > /XXXXXXX/ora_db_soft_`hostname`_`date +%Y%m%d`.tar.gz
#Backup Grid
cd $GRID_HOME
tar cvf – .|gzip -c > /XXXXXXX/ora_grid_soft_`hostname`_`date +%Y%m%d`.tar.gz
#Backup Inventario
#	- Revisar ubicación
cat /etc/oraInst.loc
inventory_loc=/opt/oraInventory
inst_group=oinstall
#	- Realizat copia de seguridad
cd /opt/oraInventory
tar cvf – .|gzip -c > /XXXXXXX/ora_invetory_`hostname`_`date +%Y%m%d`.tar.gz
#Backup OCR
#	- Revisar los backups disponibles
$GRID_HOME/bin/ocrconfig –showbackup
#	- Realizar backup
$GRID_HOME/bin/ocrconfig -export /XXXXXXX/backup_file_name

#FASE2-PREPARACION ENTORNO
#Creacion directorio trabajo
cd /opt/oracle/admin/work/
mkdir Patch_PSU
chmod 777 Patch_PSU/
#Copiar software al directorio de trabajo
cd /opt/oracle/admin/work/Patch_PSU
mkdir REPOSITORIO
mount cosysdbt02:/mnt/REPOSITORIO /opt/oracle/admin/work/Patch_PSU/REPOSITORIO root:/opt/oracle/admin/work/Patch_PSU > cp REPOSITORIO/PSU_11.2.0.4.5/p19955028_112040_Linux-x86-64.zip

[SIM] [bkoradbzs02].root:/opt/oracle/admin/work/Patch_PSU > ll *.zip
-rwx------ 1 root root 592113372 Apr 14 09:41 p19955028_112040_Linux-x86-64.zip

#Descomprimir software
cd /opt/oracle/admin/work/Patch_PSU/
unzip p19955028_112040_Linux-x86-64.zip

#Adecuacion de permisos
cd /opt/oracle/admin/work/Patch_PSU/
/opt/oracle/admin/work/Patch_PSU/ > chmod 777 -R *
/opt/oracle/admin/work/Patch_PSU/ > ll

#Revision version Opatch
export ORACLE_BASE=/opt/oragrid/base
export ORACLE_HOME=/opt/oragrid/11.2.0.4
sudo -u oragrid $ORACLE_HOME/OPatch/opatch version
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/11.2.0.4/db_1
sudo -u oracle $ORACLE_HOME/OPatch/opatch versio
#Revision orainventory
export ORACLE_BASE=/opt/oragrid/base
export ORACLE_HOME=/opt/oragrid/11.2.0.4
sudo -u oragrid $ORACLE_HOME/OPatch/opatch lsinventory -detail -oh $ORACLE_HOME
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/11.2.0.4/db_1
sudo -u oracle $ORACLE_HOME/OPatch/opatch lsinventory -detail -oh $ORACLE_HOME
#Creacion response file
export ORACLE_BASE=/opt/oragrid/base
export ORACLE_HOME=/opt/oragrid/11.2.0.4
sudo –u oragrid $ORACLE_HOME/OPatch/ocm/bin/emocmrsp -no_banner -output /opt/oracle/admin/work/Patch_PSU/file.rsp
chmod 777 /opt/oracle/admin/work/Patch_PSU/file.rsp
#Chequeo de conflictos
export ORACLE_BASE=/opt/oragrid/base
export ORACLE_HOME=/opt/oragrid/11.2.0.4
#	- Chequeos conflictos entre parches (usar propietario de los binarios - oragrid)
cd /opt/oracle/admin/work/Patch_PSU/
sudo -u oragrid $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -phBaseDir 19955028/19769469
sudo -u oragrid $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir 19955028/19769469
sudo -u oragrid $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -phBaseDir 19955028/19769476
sudo -u oragrid $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir 19955028/19769476
sudo -u oragrid $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -phBaseDir 19955028/19769489
sudo -u oragrid $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir 19955028/19769489
#	- Chequeos de binarios activos (usar propietario de los binarios - oragrid)
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -phBaseDir 19955028/19769469
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -phBaseDir 19955028/19769476
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -phBaseDir 19955028/19769489
#	- Chequeos de espacio (usar propietario de los binarios - oragrid)
cd /opt/oracle/admin/work/Patch_PSU/
sudo -u oragrid $ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseDir 19955028

export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/11.2.0.4/db_1
#	- Chequeos conflictos entre parches (usar propietario de los binarios - oracle)
cd /opt/oracle/admin/work/Patch_PSU/
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -phBaseDir
19955028/19769469
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir
19955028/19769469
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -phBaseDir
19955028/19769476
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir
19955028/19769476
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -phBaseDir
19955028/19769489
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -phBaseDir
19955028/19769489
#	- Chequeos de binarios activos (usar propietario de los binarios - oracle)
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -phBaseDir
19955028/19769469
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -phBaseDir
19955028/19769476
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -phBaseDir
19955028/19769489
#	- Chequeos de espacio (usar propietario de los binarios - oracle)
cd /opt/oracle/admin/work/Patch_PSU/
sudo -u oracle $ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -phBaseDir 19955028
#FASE3-APLICACION PSU
#Parar agente de grid control
emctl stop agent
#Parar replica

#Aplicar PSU
#	- Carga de variables:
export ORACLE_BASE=/opt/oragrid/base
export ORACLE_HOME=/opt/oragrid/11.2.0.4
#	- Aplicación del parche al GI Home
cd /opt/oracle/admin/work/Patch_PSU/
$ORACLE_HOME/OPatch/opatch auto /opt/oracle/admin/work/Patch_PSU/19955028 -oh $ORACLE_HOME -ocmrf
/opt/oracle/admin/work/Patch_PSU/file.rsp
#	- Revisión de la aplicación parche del GI Home
/opt/oracle/admin/work/Patch_PSU > sudo –u oragrid $ORACLE_HOME/OPatch/opatch lsinventory
#	- Aplicacion del parche al DB Home
#	- Carga de variables:
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/11.2.0.4/db_1
unset ORACLE_SID
cd /opt/oracle/admin/work/Patch_PSU/
$ORACLE_HOME/OPatch/opatch auto /opt/oracle/admin/work/Patch_PSU/19955028 -oh $ORACLE_HOME -ocmrf /opt/oracle/admin/work/Patch_PSU/file.rsp
#	- Revisión de la aplicación parche del DB Home
sudo -u oracle /opt/oracle/product/11.2.0.4/db_1/OPatch/opatch lsinventory
#FASE4-POSTINSTALACION
#Aplicacion catbundle
#	- Carga de variables:
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/11.2.0.4/db_1
#	- Ejecucion catbundle.sql
cd $ORACLE_HOME/rdbms/admin
sqlplus / as sysdba
SQL> @catbundle.sql psu apply
#Revision diccionario
set lines 400
col ACTION_TIME for a30
col ACTION for a10
col NAMESPACE for a20
col VERSION for a20
col BUNDLE_SERIES for a20
col COMMENTS for a20
select * from dba_registry_history;
#Activacion de la replica (cuando todos los nodos han sido parcheados)

#FASE5-ROLLBACK
#Roll back patch
$ORACLE_HOME/OPatch/opatch auto -rollback /opt/oracle/admin/work/Patch_PSU/19955028 -oh $ORACLE_HOME -ocmrf /opt/oracle/admin/work/Patch_PSU/file.rsp
#Rollback catbundle
cd $ORACLE_HOME/rdbms/admin
sqlplus /nolog
SQL> CONNECT / AS SYSDBA
SQL> STARTUP
SQL> @bundle_PSU_<database SID PREFIX>_ROLLBACK.sql
SQL> QUIT

#FASE6-TAREAS ADICIONALES
#Arrancar Grid Agent
emctl start agent
#Backup de archivers
#Desmontaje fs repositorio
umount /opt/oracle/admin/work/Patch_PSU/REPOSITORIO




