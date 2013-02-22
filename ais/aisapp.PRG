* AisApp.prg

#INCLUDE L7.H
#INCLUDE AIS.H

#DEFINE THISAPP_DATABASE_REVISION 0
#DEFINE THISAPP_CREATE_DBC_IF_MISSING .T. 

*** ======================================================== ***
define class AisApp AS KtbApp

  cConfigClass              = "AisConfig"  
  cTransactionClass         = "AisTransaction"
  
  * Update as structures change - see CheckRevision() method:
  nDatabaseRevision         = THISAPP_DATABASE_REVISION
  
  PROTECTED nNextRevision  && used internally
  nNextRevision             = NULL

  cApplication              = THISAPP_APPLICATION
  cClassPrefix              = "ais_"
  cPageAlias                = null

  cUserClass                = "KtbUser"
  cSessionClass             = "L7Session"  

  cTitle                    = THISAPP_ORG_NAME + " Artwork Information System"
  cDataBase                 = THISAPP_DATABASE

  cDefaultPage              = "Home"
  
  oLookup = NULL

  * --------------------------------------------------------- *
  function SetAppProcedures
    do (THISAPP_APPLICATION + "Classes") && [[ promote to L7! 
  endfunc   
  * --------------------------------------------------------- *
  function OnFirstPostMaintenanceHit
    * Good place to open database for performance reasons.
    if !this.CheckRevision() or this.lError
      return .F.
    endif 
    if !dbused(this.cDatabase )
      open database (this.cDataPath + this.cDatabase )
    endif 
    set database to (this.cDatabase )
    * Open tables for performance:
    OpenIfNot( "Artist", "Artist_Perform_")
    OpenIfNot( "Piece",  "Piece_Perform_")
    OpenIfNot( "Panel",  "Panel_Perform_")
    * Force lookups to get created now (so they stay open):
    *!* = this.cRegionAlias
    return .T.
  endfunc  && OnFirstPostMaintenanceHit
  * --------------------------------------------------------- *
  function CheckRevision()
    * Check if database revision in the System table matches
    * the "nRevision" property of this class. Attempt to apply 
    * the revision if not.
    if !dbused( this.cDataBase)
      #IF THISAPP_CREATE_DBC_IF_MISSING
        if !file(forceext(this.cDataPath + this.cDataBase, "DBC"))
          CreateEmptyDatabase(this.cDataPath)  && see below
        endif 
      #ENDIF
      open database (this.cDataPath + this.cDataBase)
    endif 
    set database to (this.cDataBase)
    if !this.LockSystemRecord()
      * Can't be sure another instance isn't doing the same thing.
      use 
      error "Maintenance is required to migrate database to Revision " + ;
        transform(this.nDatabaseRevision) + ;
        ", but a database lock is not available. Please try again!"
      return .F.
    else 
      if System_CheckRevision.Sys_Revision < this.nDatabaseRevision
        * Revisions need to be applied.
        local ii
        private pnStartingRevision
        pnStartingRevision = System_CheckRevision.Sys_Revision
        for ii = System_CheckRevision.Sys_Revision + 1 to this.nDatabaseRevision
          * The database could be more than one revision behind, so 
          * iterate through all necessary revisions:
          this.nNextRevision = m.ii
          if this.ApplyRevision() AND !this.lError
            * Revision applied successfully. Mark the database:
            replace ;
                Sys_Revision WITH m.ii ;
                Sys_Notes WITH Sys_Notes + ;
                  'Revision ' + TRANS( m.ii) + ' successfully applied at ' + ;
                  TRANS( DATETIME()) + "." + CHR(13) + CHR(10) ;
                Sys_Rev_Time WITH DATETIME() ;
              IN System_CheckRevision
          endif 
        endfor 
        if !this.lError
          * Update all of the views:
          do CreateViews WITH .F., THIS.cDataPath, THIS.cDataBase
        endif 
      endif 
      this.UnlockSystemRecord()
    endif 
    return !This.lError
  endfunc && CheckRevision
  * --------------------------------------------------------- *
  FUNCTION LockSystemRecord( )
    LOCAL llRet
    SELECT 0
    USE System ALIAS System_CheckRevision
    llRet = RLOCK()
    IF NOT m.llRet
      USE
    ENDIF
    RETURN m.llRet
  ENDFUNC && LockSystemRecord
  * --------------------------------------------------------- *
  FUNCTION UnlockSystemRecord( )
    IF USED( "System_CheckRevision")
      UNLOCK IN System_CheckRevision
      USE IN SELECT( "System_CheckRevision")
    ENDIF
  ENDFUNC && UnlockSystemRecord

  * --------------------------------------------------------- *
  FUNCTION ApplyRevision( )
    * One CASE for each revision incremental structure change.
    * Any change can optionally call the BackupDatabase method
    * to back up the database first.
    local lnRev, lnKey, lcStr, lnTally, ltNow, loExc, loRE, ii, lcWord
    lnRev = THIS.nNextRevision
    ltNow = DATETIME()

    do case 
    * CASE m.lnRev = 1
** CAUTION: Need to add any above changes to Create*() functions below!!

    otherwise 
      error "Unknown Database Revision " + TRANSFORM(m.lnRev)
    
    endcase 
  endfunc && ApplyRevision
enddefine && AisApp

*** ===================================================== ***
function CreateEmptyDatabase( lcPath)
  *
  #IF .F.
    * Table Prefixes:

    ART = Artist
    ASM = Assembly
    FAC = Facility
    FIL = Files
    LOC = Location
    PCE = Piece
    PNL = Panel
    RCP = Recipient
     
    SYS = System
  #ENDIF

  private poEnv
  poEnv = GetEnvObject(lcPath)

  create database ( THISAPP_DATABASE )

  * System Table:
  do CreateSystemTable

  * Primary Tables:
  do CreateArtistTable
  *!* do CreateAssemblyTable
  *!* do CreateFacilityTable
  *!* do CreateLocationTable
  do CreatePieceTable
  do CreatePanelTable
  *!* do CreateRecipientTable

  * Miscellaneous:
  do CreateFilesTable

  * Create records, stored procs, etc:
  do InsertSeedRecords
  do CreateStoredProcedures
  do CreateViews
  *!* -- do AddComments

  close databases 

  return 
endfunc  && CreateEmptyDatabase

* ---------------------------------------------------------- *
FUNCTION CreateSystemTable
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  CREATE TABLE ( "System" ) NAME System ;
    ( ;
      Sys_PK C(32) PRIMARY KEY DEFAULT GetGuid32(), ;
      Sys_Inactive L, ;
      Sys_Title C(72), ;
      Sys_Menu_Title C(40), ;
      Sys_Notes M, ;
      Sys_More_Data M, ;
      Sys_Orig_Art_FK C(32), ;
      Sys_Orig_Time T, ;
      Sys_Rev_Art_FK C(32), ;
      Sys_Rev_Time T, ;
      Sys_Revision I ;
    )
  * Standard 2 Indexes:
  INDEX ON DELETED() TAG Deleted
  INDEX ON Sys_Inactive TAG Inactive
  * Foreign Keys:
  * Other Keys:
  * Comment:
  DBSETPROP( "System", "Table", "Comment", ;
    [One record table to identify current DB revision. ])
ENDFUNC  && CreateSystemTable

* --------------------------------------------------------- *
function CreateArtistTable
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  create table ("Artist") name Artist ;
    ( ;
      Art_PK C(32) primary key default GetGuid32(), ;
      Art_Inactive L default .F., ;
      Art_ID C(8), ;
      Art_Approved L default .T., ;
      Art_Admin L default .f., ;
      Art_Core L default .f., ;
      Art_Artist L default .t., ;
      Art_Anonymous L, ;
      Art_Unknown L, ;
      Art_Full_Name C(60), ;
      Art_Last_Name C(20), ;
      Art_First_Name C(24), ;
      Art_Name_Orig M, ; 
      Art_Email C(80), ;
      Art_Phone C(24), ;
      Art_Contact_Orig M, ; 
      Art_Address M, ;
      Art_Neighborhood C(50), ;
      Art_Age_Range C(THISAPP_LENGTH_AGE_RANGE) default "n/a", ;
      Art_Participation M, ;
      Art_Partial_Panel L, ;
      Art_Bit_Info M, ;
      Art_Panel_Info M, ;
      Art_Panel_Count I, ;
      Art_Received L, ;
      Art_Storage_Location M, ;
      Art_Towers L, ; 
      Art_Help_Install L, ;
      Art_Help_Materials L, ;
      Art_Help_Meet_Up L, ;
      Art_Help_Outreach L, ;
      Art_Help_Other M, ;
      Art_Comments M, ;
      Art_Register_Time T, ;
      Art_KTB_Response M, ;
      Art_Access_Token C(32), ;
      Art_User_ID C(20), ;
      Art_Password_Hash C(16), ;      
      Art_Previous_Passwords C(80), ; 
      Art_Password_Count I, ;         
      Art_Password_Time T, ;          
      Art_Password_Expiry_Time T, ;   
      Art_Account_Lockout L, ;        
      Art_Account_Revoked L, ;        
      Art_Notes M, ;
      Art_Orig_Art_FK C(32), ;
      Art_Orig_Time T, ;
      Art_Rev_Art_FK C(32), ;
      Art_Rev_Time T, ;
      Art_Revision I NOT NULL DEFAULT 0 ;
    )

#if .f. 
"  checked participation choices (from blog form)
"  (possible) privacy preferences (e.g., "do not release", "first name only", "full name", "full name and email address")
#endif

  * Standard 2 Indexes:
  index on deleted() tag Deleted
  index on Art_Inactive tag Inactive
  * Foreign Keys:
  * Other Keys:
  index on Art_Approved tag Approved
  index on upper(Art_User_ID) tag User_ID
  index on Art_ID tag Art_ID
  index on Art_Access_Token tag token 
  index on upper(Art_Last_Name) tag U_last
  index on Art_Artist tag artist 
   
  * Comment:
  dbsetprop("Artist", "Table", "Comment", ;
    [One record per Artist or other user.] )
endfunc  && CreateArtistTable

* --------------------------------------------------------- *
function CreatePieceTable
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  create table ("Piece") name Piece ;
    ( ;
      Pce_PK C(32) primary key default GetGuid32(), ;
      Pce_Inactive L default .F., ;
      Pce_ID C(8), ;
      Pce_Art_FK C(32), ;
      Pce_Pnl_FK C(32), ;
      Pce_Whole_Panel L, ;  
      Pce_Dim_1 C(12), ;
      Pce_Dim_2 C(12), ;
      Pce_Type C(THISAPP_LENGTH_PIECE_TYPE), ;
      Pce_Shipped L, ;
      Pce_Ship_Date D, ;
      Pce_Received L, ;
      Pce_Comments M, ;
      Pce_Notes M, ;
      Pce_Orig_Art_FK C(32), ;
      Pce_Orig_Time T, ;
      Pce_Rev_Art_FK C(32), ;
      Pce_Rev_Time T, ;
      Pce_Revision I NOT NULL DEFAULT 0 ;
    )

  * Standard 2 Indexes:
  index on deleted() tag Deleted
  index on Pce_Inactive tag Inactive
  * Foreign Keys:
  index on Pce_Art_FK tag Art_FK
  index on Pce_Pnl_FK tag Pnl_FK
  * Other Keys:
  index on Pce_ID tag Pce_ID
  index on Pce_Shipped tag shipped
  index on Pce_Received tag received
  index on Pce_Whole_Panel tag wholePanel
     
  * Comment:
  dbsetprop("Piece", "Table", "Comment", ;
    [One record per Piece.] )
endfunc  && CreatePieceTable

* --------------------------------------------------------- *
function CreatePanelTable
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  create table ("Panel") name Panel ;
    ( ;
      Pnl_PK C(32) primary key default GetGuid32(), ;
      Pnl_Inactive L default .F., ;
      Pnl_ID C(8), ;
      Pnl_Stitcher_Art_FK C(32), ;
      Pnl_Asm_FK C(32), ;
      Pnl_Single_Piece L, ;  
      Pnl_Dim_1 C(12), ;
      Pnl_Dim_2 C(12), ;
      Pnl_Type C(THISAPP_LENGTH_PIECE_TYPE), ;
      Pnl_Comments M, ;
      Pnl_Notes M, ;
      Pnl_Orig_Art_FK C(32), ;
      Pnl_Orig_Time T, ;
      Pnl_Rev_Art_FK C(32), ;
      Pnl_Rev_Time T, ;
      Pnl_Revision I NOT NULL DEFAULT 0 ;
    )

  * Standard 2 Indexes:
  index on deleted() tag Deleted
  index on Pnl_Inactive tag Inactive
  * Foreign Keys:
  index on Pnl_Stitcher_Art_FK tag Stitcher
  index on Pnl_Asm_FK tag Asm_FK
  * Other Keys:
  index on Pnl_ID tag Pnl_ID
  index on Pnl_Single_Piece tag Single
     
  * Comment:
  dbsetprop("Panel", "Table", "Comment", ;
    [One record per Panel.] )
endfunc  && CreatePanelTable

* ---------------------------------------------------------- *
function CreateFilesTable
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  CREATE TABLE ( "Files" ) NAME Files ;
    ( ;
      Fil_PK C(32) PRIMARY KEY DEFAULT GetGuid32(), ;
      Fil_Inactive L DEFAULT .F., ;
      Fil_Art_FK C(32), ;
      Fil_Pce_FK C(32), ;  
      Fil_Pnl_FK C(32), ;  
      Fil_Type C(9) DEFAULT "File     ", ; 
      Fil_Ref_Fil_FK C(32), ; 
      Fil_Superseded L, ;  
      Fil_Superseded_Date D, ;  
      Fil_Download_Only L, ; 
      Fil_Unlisted L, ;  
      Fil_Core L DEFAULT .T., ;
      Fil_Artist L DEFAULT .T., ;
      Fil_Public L DEFAULT .F., ;
      Fil_Name C(160), ;  
      Fil_URL M, ;
      Fil_Size I, ;
      Fil_Date D, ;
      Fil_Time T, ;
      Fil_Upload_Art_FK C(32), ;  
      Fil_Upload_Time T, ;
      Fil_Scanned L, ;
      Fil_Summary M, ;
      Fil_Details M, ;
      Fil_Notes M, ;
      Fil_Orig_Art_FK C(32), ;
      Fil_Orig_Time T, ;
      Fil_Rev_Art_FK C(32), ;
      Fil_Rev_Time T, ;
      Fil_Revision I NOT NULL DEFAULT 0 ;
    )
  * Standard 2 Indexes:
  INDEX ON DELETED() TAG Deleted
  INDEX ON Fil_Inactive TAG Inactive
  * Foreign Keys:
  index on Fil_Art_FK tag Art_FK
  index on Fil_Pce_FK tag Pce_FK
  index on Fil_Pnl_FK tag Pnl_FK
  * Other Keys:
  * Comment:
  dbsetprop( "Files", "Table", "Comment", ;
    [One record per file. ])
endfunc  && CreateFilesTable

* ---------------------------------------------------------- *
FUNCTION InsertSeedRecords
  * INSERT SOME REQUIRED DATA RECORDS
  * Performed before stored procedures are created.
  * Create default People and Unique entries:

  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  PRIVATE pnAsgRecs
  pnAsgRecs = 0

  ** DEFAULT USERS:
  * "System Administrator"
  insert into Artist ( ;
      Art_PK, Art_Inactive, Art_Admin, Art_Artist, Art_Anonymous, ;
      Art_Full_Name, Art_First_Name, Art_Last_Name, ;
      Art_Orig_Art_FK, Art_Orig_Time, Art_Rev_Art_FK, Art_Rev_Time ;
    ) VALUES ( ;
      THISAPP_ADMIN_PK, .T., .t., .f., .f., ;
      "SYSTEM ADMINISTRATOR", "SYSTEM", "ADMINISTRATOR", ;
      THISAPP_ADMIN_PK, m.poEnv.tTime, THISAPP_ADMIN_PK, m.poEnv.tTime )

  * "Developer"
  insert into Artist ( ;
      Art_PK, Art_Inactive, Art_Admin, Art_Artist, Art_Anonymous, ;
      Art_Full_Name, Art_First_Name, Art_Last_Name, ;
      Art_User_ID, ;
      Art_Orig_Art_FK, Art_Orig_Time, Art_Rev_Art_FK, Art_Rev_Time ;
    ) VALUES ( ;
      THISAPP_DEV_PK, .f., .t., .f., .f., ;
      "SYSTEM DEVELOPER", "SYSTEM", "DEVELOPER", ;
      THISAPP_USER_DEV, ;
      THISAPP_ADMIN_PK, m.poEnv.tTime, THISAPP_ADMIN_PK, m.poEnv.tTime )

  * "Anonymous User"
  insert into Artist ( ;
      Art_PK, Art_Inactive, Art_Admin, Art_Artist, Art_Anonymous, ;
      Art_Full_Name, Art_First_Name, Art_Last_Name, ;
      Art_Orig_Art_FK, Art_Orig_Time, Art_Rev_Art_FK, Art_Rev_Time ;
    ) VALUES ( ;
      THISAPP_ANON_PK, .T., .f., .f., .t., ;
      "ANONYMOUS USER", "ANONYMOUS", "USER", ;
      THISAPP_ADMIN_PK, m.poEnv.tTime, THISAPP_ADMIN_PK, m.poEnv.tTime )

  * System:
  INSERT INTO System ( ;
      Sys_PK, Sys_Inactive, Sys_Revision, ;
      Sys_Orig_Art_FK, Sys_Orig_Time, Sys_Rev_Art_FK, Sys_Rev_Time ;
    ) VALUES ( ;
      replicate("1", 32), .F., THISAPP_DATABASE_REVISION, ;
      THISAPP_ADMIN_PK, m.poEnv.tTime, THISAPP_ADMIN_PK, m.poEnv.tTime )

  return 
endfunc  && InsertSeedRecords

* --------------------------------------------------------- *
function CreateStoredProcedures
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  close tables 

  local lcAllProcs, lcProcTmp
  lcAllProcs = []
  text to m.lcAllProcs additive 
    function StampRec(lvUser, ltTime)
      * Stamps current record with user ID and time. Always stamps revision fields. 
      * If origination fields are empty, assumes it should stamp those too. 
      local lcUserKey, lcPrefix, llRetVal, lcField, lcTypes, lcType, lnType 
       
      * If a time isn't passed, set it to current time: 
      if vartype(m.ltTime) <> "T" 
        ltTime = datetime() 
      endif  
       
      * Determine the user key: 
      do case 
      case vartype(m.lvUser) = "O" AND vartype(m.lvUser.oData) = 'O' AND vartype(m.lvUser.oData.Art_PK) = 'C' 
        * A valid user object was passed in. 
        lcUserKey = m.lvUser.oData.Art_PK 
      case vartype(m.lvUser) = 'C' 
        * A direct ID was passed in. Probably a maintenance function or engine routine. 
        lcUserKey = m.lvUser 
      otherwise 
        * Use the original admin account: 
        lcUserKey = "11111111111111111111111111111111" && no #define constants in stored procs
      endcase  
       
      llRetVal = .T. 
      lcPrefix = trim(left(field(1), 3)) && all fields have 3-letter alias prefixes
      if empty(m.lcPrefix) 
        llRetVal = .F. 
      else  
        lcTypes = "Orig,Rev"
        for lnType = 1 to getwordcount(m.lcTypes, ",")
          lcType = getwordnum(m.lcTypes, m.lnType, ",")
          * Artist: 
          lcField = alias() + "." + m.lcPrefix + "_" + m.lcType + "_Art_FK" && e.g., Panel.Pnl_Orig_Art_FK
          if type(m.lcField) = "C" and empty(eval(m.lcField)) 
            replace (m.lcField) with m.lcUserKey 
          endif  
          * Timestamp: 
          lcField = alias() + "." + m.lcPrefix + "_" + m.lcType + "_Time" && e.g., Panel.Pnl_Orig_Time
          if type(m.lcField) = "T" and empty(eval(m.lcField)) 
            replace (m.lcField) with m.ltTime 
          endif  
        next && lnType
      endif  
      return m.llRetVal 
    endfunc  
    * End: StampRec()

  endtext 
  text to m.lcAllProcs additive 
    function GetGUID32() && collapsing of 3 UDFs for use in stored procs
      local lcStruc_GUID, lcGUID, lnSize, lcRet
      declare integer CoCreateGuid ;
        in Ole32.dll ;
        string @lcGUIDStruc
      declare integer StringFromGUID2 ;
        in Ole32.dll ;
        string cGUIDStruc, ;
        string @cGUID, ;
        long nSize
      * Simulate GUID strcuture with a string:
      lcStruc_GUID = SPACE(16) 
      if CoCreateGuid(@lcStruc_GUID) # 0
        return ""
      endif 
      if empty(m.lcStruc_GUID)
        return ""
      endif 
      lcGUID = space(80)
      lnSize = len(m.lcGUID) / 2
      if StringFromGUID2(m.lcStruc_GUID, @lcGuid, m.lnSize) = 0
        return ""
      endif 
      * String is UNICODE so we must convert to ANSI:
      lcRet = strconv(left(m.lcGUID, 76), 6)
      * String is 38-chars with {-} chars, remove:
      lcRet = chrtran(m.lcRet, "{-}", "")
      return m.lcRet
    endfunc && GetGUID32

  endtext 
  lcProcTmp = "SP" + SYS(3) + ".TMP"
  strtofile(m.lcAllProcs, m.lcProcTmp) && append procedure needs disk presence
  append procedures from (m.lcProcTmp) overwrite 
  compile database THISAPP_DATABASE
  erase ( m.lcProcTmp )
  return 
endfunc  && CreateStoredProcedures
    
* --------------------------------------------------------- *
function CreateTable(lcTable, lcDataPath, lcDataBase)
  if pcount() < 3
    lcDataBase = THISAPP_DATABASE
  endif 

  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject( m.lcDataPath)

  if !dbused(m.lcDataBase)
    open database (m.lcDataPath + m.lcDataBase)
  endif 
  set database to (m.lcDataBase)
  local lcCommand
  lcCommand = "Create" + m.lcTable + "Table"
  do &lcCommand
  * Note: Assume whatever called this will call 
  *    CreateViews() also.
  return 
endfunc  && CreateTable
* --------------------------------------------------------- *
FUNCTION CreateViews(lcOneTable, lcDataPath, lcDataBase)
  * Optional parameter to drop single basic view and re-create. 
  * Caution: Assumes no extra dependent views based on that table.

  IF PCOUNT() < 2
    * Don't declare this PRIVATE. This command allows this procedure
    * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
    CLOSE DATA ALL
    poEnv = GetEnvObject()
    ** lcDataPath = THISAPP_DATAPATH 
    lcDataPath = ".\" && assume we're already there?
    lcDataBase = THISAPP_DATABASE
  ENDIF

  OPEN DATABASE ( m.lcDataPath + m.lcDataBase )
  LOCAL ARRAY laTables[1]
  LOCAL lcTbl, lcView, lcStub, lcPkFld, lcFkFld
  ADBOBJECTS( laTables, "Table" )

  * Add a primary view for each table:
  for each lcTbl in laTables
    IF VARTYPE( m.lcOneTable) = "C" AND NOT UPPER( m.lcOneTable ) == m.lcTbl
      * We asked for just a single view and this is not it.
      LOOP
    ENDIF
    
    lcView = "V_" + m.lcTbl
    if indbc(m.lcView, "View" )
      * Drop the previous view, so we can reinsert one with
      * a structure consistent with the new scema.
      drop view ( m.lcView )
    endif
    * NOTE: This is simplified over apps that used Integer PKs, which needed a UNIQUE table.
    lcPkFld = DBGETPROP( m.lcTbl, 'Table', 'PrimaryKey' )  && eg, Art_PK
    lcStub = LEFT( m.lcPkFld, 3)  && eg, "PER"
    lcExpr = m.lcPkFld + " = ?vp_c" + m.lcPkFld
    * e.g., Art_PK = ?vp_cArt_PK
    CREATE SQL VIEW &lcView AS SELECT * FROM &lcTbl WHERE &lcExpr
    DBSETPROP( m.lcView + "." + m.lcPkFld, "Field", "Updatable", .T. )
    DBSETPROP( m.lcView + "." + m.lcPkFld, "Field", "DefaultValue", [GetGUID32()] )
    DBSETPROP( m.lcView, "View", "SendUpdates", .T. )
    DBSETPROP( m.lcView, "View", "WhereType", 1)  && key field only in WHERE clause
    *[[ Do we need to transfer other default values to views??
  next && table

  * Add app-specific child record views:
  if empty( m.lcOneTable)

    do CreateChildView WITH "V_Artist_Piece_Set", "Piece", "Pce_Art_FK", "Artist", [Pce_Inactive=.F.]

    * All-record views (for master "browse" forms):
    do CreateAllRecordsView WITH "V_All_Users", "Artist", "Art_PK", [!empty(Art_User_ID)]

  endif 
  return 
endfunc  && CreateViews
* --------------------------------------------------------- *
function CreateChildView(lcViewName, lcChildTable, lcFkField, lcForeignTable, lcExtraWhere, lcOrder, lcJoin)
  local lcForeignStub, lcPkField, lcStub, lcExpr, lcFields
  lcForeignStub = left( dbgetprop( m.lcForeignTable, 'Table', 'PrimaryKey'), 3)
  lcPkField = dbgetprop( m.lcChildTable, 'Table', 'PrimaryKey' )  && eg, Art_PK
  lcStub = left( m.lcPkField, 3)  && eg, "PER"
  lcExpr = m.lcFkField + " = ?vp_c" + m.lcForeignStub + "_PK"
  lcFields = [*]
  lcJoin = evl(m.lcJoin, "")
  if !empty(m.lcExtraWhere)
    lcExpr = m.lcExpr + [ AND ] + m.lcExtraWhere
  endif 
  lcOrder = [order by ] + iif(empty(m.lcOrder), m.lcPkField, m.lcOrder)
  if indbc( m.lcViewName, "View" )
    drop view ( m.lcViewName )
  endif 
  create sql view &lcViewName as select &lcFields from &lcChildTable &lcJoin where &lcExpr &lcOrder
  dbsetprop( m.lcViewName + "." + m.lcPkField, "Field", "Updatable", .T. )
  dbsetprop( m.lcViewName + "." + m.lcPkField, "Field", "DefaultValue", [GetGUID32()] )
  dbsetprop( m.lcViewName, "View", "SendUpdates", .T. )
  return  
endfunc  && CreateChildView
* --------------------------------------------------------- *
function CreateAllRecordsView(lcView, lcTbl, lcPkFld, lcExtraWhere, lcOrder)
  local lcExpr
  if indbc( m.lcView, "View" )
    drop view ( m.lcView )
  endif 
  if !empty(m.lcExtraWhere )
    lcExpr = [WHERE ] + m.lcExtraWhere
  else 
    lcExpr = []
  endif 
  if !empty(m.lcOrder)
    lcExpr = LTRIM(m.lcExpr + [ ORDER BY ] + m.lcOrder)
  endif 
  create sql view &lcView as select * from &lcTbl &lcExpr
  dbsetprop( m.lcView + "." + m.lcPkFld, "Field", "Updatable", .T. )
  dbsetprop( m.lcView + "." + m.lcPkFld, "Field", "DefaultValue", [GetGUID32()] )
  dbsetprop( m.lcView, "View", "SendUpdates", .T. )
  return  
endfunc  &&  CreateAllRecordsView

* --------------------------------------------------------- *
FUNCTION GetEnvObject( lcPath)
  IF PCOUNT() = 0 AND VARTYPE( poEnv) = "O"
    RETURN poEnv
  ENDIF
  LOCAL loObj
  loObj = CREATEOBJECT( "CreateDataEnvironment" )
  IF EMPTY( m.lcPath)
    ** CD THISAPP_DATAPATH
  ELSE
    CD ( m.lcPath)
  ENDIF
  RETURN loObj
ENDFUNC  && GetObject
* --------------------------------------------------------- *
DEFINE CLASS CreateDataEnvironment AS RELATION
  cOrigDir = ""
  tTime = {}
  lDbcOpen = .F.

  FUNCTION INIT
    THIS.cOrigDir = SET( "DIRECTORY")
    THIS.tTime = DATETIME()
    THIS.lDbcOpen = DBUSED( THISAPP_DATABASE)
    IF NOT THIS.lDbcOpen
      IF FILE( THISAPP_DATABASE + ".DBC")
        OPEN DATABASE THISAPP_DATABASE
      ENDIF
    ENDIF
  ENDFUNC && INIT

  FUNCTION DESTROY
    IF NOT THIS.lDbcOpen
      IF DBUSED( THISAPP_DATABASE)
        SET DATABASE TO THISAPP_DATABASE
        CLOSE DATABASE
      ENDIF
    ENDIF
    CD ( THIS.cOrigDir )
  ENDFUNC  && DESTROY

ENDDEFINE  && CLASS CreateDataEnvironment 

*** ===================================================== ***
define class KtbApp AS L7App

  nErrorEmailInfo    = L7_ERRORINFO_TYPICAL            && additive (see L7.H for values) 
  nErrorPageInfo     = L7_NONE
  
  lAllowStateless    = .T. 
  * --------------------------------------------------------- *
  function SetupSessionObject  && overrides L7
    with this
      .oSession = createobject(.cSessionClass)
      .oSession.setDataPath(.oConfig.cLogPath) && place session with logs, both daily and intertwined
      .oSession.SetTableName(NVL(.cSessionTableName, .cApplication + "Session"))
      .oSession.SetTimeout(.nSessionTimeout)
    endwith 
    return   
  endfunc 
  * ---------------------------------------------------------- *
  FUNCTION CreateTransaction(lcType)
    LOCAL loTrans, lcID, loExc, llCreated
    TRY
      IF THIS.oConfig.lReadOnly
        ERROR "Database is currently in read-only state. Please try again later. We are sorry for the inconvenience."
      ENDIF 
      loTrans = CREATEOBJECT(THIS.cTransactionClass)
      loTrans.lWriteXmlupdategram = .T.
      loTrans.lLogTransactions = .T.
      loTrans.SetLogPath(THIS.oConfig.cTransactionPath)
      IF VARTYPE(TrueUser) = "O"
        lcId = TrueUser.GetUserID()
      ELSE
        lcId = "_APP"
      ENDIF
      lcId = m.lcId + "_" + EVL(m.lcType, "Transaction")
      lcId = m.lcId + "_" + GetGUIDString(36)
      loTrans.SetId(m.lcId)
      llCreated = .T.
    CATCH TO loExc
      THROW loExc.Message
    ENDTRY
    RETURN loTrans
  ENDFUNC
  * --------------------------------------------------------- *
  function Custom_GetLoginHelp()
    local lcRet
    lcRet = ""
    if vartype(this.oLookup) = "O" and pemstatus(this.olookup,'getSnippet',5)
      lcRet = m.lcRet + THIS.oLookup.GetSnippet("Login Help", .F., "")
    endif
    return m.lcRet
  endfunc   
  * --------------------------------------------------------- *
  function SetError(lcMessage, lcTitle, loException)
    * Pre-process error to add user name, then call framework default.
    local loExc, lcTmp, lcTmp2
    lcTitle = EVL(m.lcTitle, THIS.cApplication + " Application Error")
    try 
      if vartype(CurrentUser) = "O"
        lcTmp = CurrentUser.GetUserName()
        lcTitle = m.lcTitle + ", User: " + m.lcTmp
        if vartype(TrueUser) = "O"
          lcTmp2 = TrueUser.GetUserName()
          if !m.lcTmp == m.lcTmp2
            lcTitle = m.lcTitle + " (True User: " + m.lcTmp2 + ")"
          endif 
        endif   
      endif 
    catch to loExc
      lcTitle = m.lcTitle + " (2nd Error: " + loExc.Message + ")"
    endtry  
    dodefault(m.lcMessage, m.lcTitle, m.loException)
    return   
  endfunc  && SetError 
  * --------------------------------------------------------- *
  FUNCTION NotifyAdmin(lcSubject, lcMessage, lcCcTo)
    
    if empty(m.lcCcTo) && no special CC's--just delegate to app_log() instead of custom email
      this.app_log(L7_SEVERITY_NOTICE, m.lcSubject, ;
        iif(vartype(m.lcMessage) = "C", HTWrap(m.lcMessage, 'pre'), .f.))
      return && avoid redundant msg below
    endif
    
    local lcFrom, lcTo
    lcFrom = THIS.oConfig.cAdminEmail
    if empty(m.lcFrom)
      lcFrom = goL7AppManager.oConnector.cAdminEmail
    endif 
    lcTo = ConcatenateEmail(m.lcFrom, THIS.oConfig.cAdminCC)
    if !empty(m.lcCcTo)
      lcTo = ConcatenateEmail(m.lcTo, m.lcCcTo)
    endif 
    lcSubject = '[' + THIS.cApplication + '] ' + ;
      evl(m.lcSubject, "Untitled Event")
    if empty(m.lcMessage)
      lcMessage = "No details provided."
    endif 
    this.QueueMessage(lcTo, lcSubject, lcMessage, ;
      THIS.cApplication + ' Application', lcFrom, ;
      "", "", ;
      "", "text/plain", .F.)
    return   
  endfunc 
  * --------------------------------------------------------- *
enddefine  && KtbApp
