----------------------------------------------------------------------------
--     $Id: reg.sql 21 2009-09-16 09:11:28Z soe $
----------------------------------------------------------------------------
--     Trivadis AG, Infrastructure Managed Services
--     Europa-Strasse 5, 8152 Glattbrugg, Switzerland
----------------------------------------------------------------------------
--     File-Name........:  cpui.sql
--     Author...........:  Stefan Oehrli (oes) stefan.oehrli@trivadis.com
--     Editor...........:  $LastChangedBy: soe $
--     Date.............:  $LastChangedDate: 2009-09-16 11:11:28 +0200 (Mi, 16 Sep 2009) $
--     Revision.........:  $LastChangedRevision: 21 $
--     Purpose..........:  List installed PSU / CPU		 
--     Usage............:  @cpui
--     Group/Privileges.:  select catalog
--     Input parameters.:  none
--     Called by........:  as DBA or user with access to registry$history
--     Restrictions.....:  unknown
--     Notes............:--
----------------------------------------------------------------------------
--		 Revision history.:      see svn log
----------------------------------------------------------------------------
col action_time for a28
col version for a10
col comments for a35
col action for a25
col namespace for a12
select * from registry$history;
