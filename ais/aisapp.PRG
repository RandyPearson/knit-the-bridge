* AisApp.prg

#INCLUDE L7.H
#INCLUDE AIS.H

#DEFINE THISAPP_DATABASE_REVISION     18
#DEFINE THISAPP_CREATE_DBC_IF_MISSING .T. 

*** ======================================================== ***
define class AisApp AS KtbApp

  * Lookup table aliases:
  cFacAlias                 = NULL  && see cFacAlias_ACCESS method

  cConfigClass              = "AisConfig"  
  
  nErrorPageInfo            = L7_ERRORINFO_TYPICAL
  nErrorEmailInfo           = L7_ERRORINFO_TYPICAL

  * Update as structures change - see CheckRevision() method:
  nDatabaseRevision         = THISAPP_DATABASE_REVISION
  
  PROTECTED nNextRevision  && used internally
  nNextRevision             = NULL

  cApplication              = THISAPP_APPLICATION
  cClassPrefix              = "ais_"
  cPageAlias                = null

  cUserClass                = "AisUser"
  cSessionClass             = "L7Session"  

  cLogRequestClass          = "aisLogRequest"  && see aisClasses

  cTitle                    = THISAPP_ORG_NAME + " Artwork Information System"
  cDataBase                 = THISAPP_DATABASE

  cDefaultPage              = "Home"
  
  oLookup = NULL

  * --------------------------------------------------------- *
  function cFacAlias_ACCESS
    this.OpenLookupTable("Facility")
    return "Facility_LOOKUP_"
  endfunc 
  * -------------------------------------------------- *
  function OpenLookupTable(lcCode)
    local lcAlias, lcSql, lcIndexCommands, lnSelect
    lcAlias = m.lcCode + "_LOOKUP_"
    lcIndexCommands = ""
    if used(m.lcAlias)
      return 
    endif 
    do case 
    case lcCode == "Facility"  && Rev. 12
      lcSql = ;
        [SELECT Fac_PK, Fac_Name, Fac_ID, Fac_Order, Fac_Dropoff, Fac_Storage] + ;
        [ FROM ] + THISAPP_DATABASE + [!Facility] + ;
        [ WHERE Fac_Inactive = .F.] + ;
        [ ORDER BY Fac_Order]
      lcIndexCommands = ;
        [INDEX ON Fac_PK TAG Fac_PK] + CRLF + ;
        [INDEX ON Fac_Name TAG Fac_Name] + CRLF + ;
        [INDEX ON Fac_Order TAG Fac_Order] 

    otherwise 
      error "Unknown lookup request: " + m.lcCode
      return 
    endcase 
    * Change this to SQLEXEC for remote data:
    lcSql = m.lcSql + [ INTO CURSOR ] + m.lcAlias + [ READWRITE]
    lnSelect = SELECT()
    &lcSql
    if !empty(m.lcIndexCommands)
      local laIndexCommands[1], lcXbase
      alines(laIndexCommands, m.lcIndexCommands, .T.)
      for each lcXbase in laIndexCommands
        &lcXbase
      endfor 
    endif 
    select (m.lnSelect)
    return 
  endfunc  && OpenLookupTable
  * --------------------------------------------------------- *
  function determineBrowser()

    local loDevice
    loDevice = createobject("aisBrowserDevice")
    Environ.Set('app.client_device', m.loDevice)

    dodefault()  && does: THIS.cBrowserName = Request.cBrowser
    return 
  endfunc  && determineBrowser
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
    * Deploy physical files needed in http space:
    this.DeployContent()
    set nulldisplay to "--"
    return .T.
  endfunc  && OnFirstPostMaintenanceHit
  * --------------------------------------------------------- *
  function DeployContent()
    * CAUTION: New files added here must be explicitly added to PJX (built into EXE)! 
    *          Otherwise, they will appear to work in development, but not in production.  
  
    this._deployContentFile("ktb-ais.css",     ".\css\")
    this._deployContentFile("ktb-aisForm.css", ".\css\")
    
    this._deployContentFile("prototype-1.7.0.js", ".\js\") && prototype-1.5.1.js
    this._deployContentFile("jquery-1.7.1.js",    ".\js\") && jquery-1.3.1.js
    this._deployContentFile("sortTable.js",       ".\js\")
    this._deployContentFile("l7CoreP.js",         ".\js\")
    this._deployContentFile("l7CoreJQ.js",        ".\js\")

    *!* this._deployContentFile("Server_Override_Trapezoid.png", ".\icons\")

    return .T.
  endfunc  && DeployContent
  * --------------------------------------------------------- *
  function _DeployContentFile(tcFile, tcRelPath, tcBasePath)
    if !file(m.tcFile) && should be built into project/EXE
      this.app_log(L7_SEVERITY_WARNING, "Deployable file missing from project: " + m.tcFile)
      return
    endif
    local lcContNew, lcContOld, lcPath, lcOldFile, llOld, lnBytes, loFso as scripting.filesystemobject, loFil, loTxt
    lcContNew = filetostr(m.tcFile)
    lcPath = fullpath(m.tcRelPath, evl(m.tcBasePath, this.oConfig.cHtmlPagePath))
    if !directory(m.lcPath)
      mkdir (m.lcPath)
      this.app_log(L7_SEVERITY_NOTICE, "Created deployment folder: " + m.lcPath)
    endif 
    loFso = createobject('scripting.filesystemobject')
    lcOldFile = addbs(m.lcPath) + m.tcFile
    llOld = loFso.FileExists(m.lcOldFile)  && file(m.lcOldFile)--didn't work from EXE
    if m.llOld
      * lcContOld = filetostr(m.lcOldFile)
      loFil = loFso.GetFile(m.lcOldFile)
      loTxt = loFil.OpenAsTextStream()
      lcContOld = loTxt.ReadAll() 
      store null to loFil, loTxt
      this.app_log(L7_SEVERITY_DEBUG, "File present: " + m.lcOldFile)
      if !m.lcContNew == m.lcContOld 
        this.app_log(L7_SEVERITY_DEBUG, textmerge([Content file sizes: <<len(m.lcContOld)>>, <<len(m.lcContNew)>> bytes.]))
        do case
        case m.lcContNew = m.lcContOld 
          this.app_log(L7_SEVERITY_DEBUG, textmerge([m.lcContNew = m.lcContOld]))
        case m.lcContOld = m.lcContNew 
          this.app_log(L7_SEVERITY_DEBUG, textmerge([m.lcContOld = m.lcContNew]))
        otherwise
          this.app_log(L7_SEVERITY_DEBUG, textmerge([m.lcContOld <> m.lcContNew, even without exact matching]))
        endcase
      endif 
    else
      this.app_log(L7_SEVERITY_NOTICE, "File NOT present: " + m.lcOldFile)
    endif 

    if !m.llOld or !m.lcContNew == m.lcContOld 
      loTxt = loFso.CreateTextFile(m.lcOldFile, .t.)
      loTxt.Write(m.lcContNew)
      loTxt.Close()
      loTxt = null
      this.app_log(L7_SEVERITY_NOTICE, textmerge([Content file deployed: <<m.lcOldFile>>, <<len(m.lcContNew)>> bytes.]))
    else
      *!* this.app_log(L7_SEVERITY_DEBUG, "File matched: " + m.lcOldFile)
    endif 
   
    return .T.
  endfunc  && DeployContent
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
    case m.lnRev = 1
      do CreateTable ;
        with "Unique", this.cDataPath, this.cDataBase

    case m.lnRev = 2
      alter table Panel add column Pnl_Completed L
      select Panel
      index on Pnl_Completed tag Completed
      use in select("Panel")

    case m.lnRev = 3
      this.removeColumn("Panel", "Pnl_Type") && no error if d.n.e. 

      alter table Artist add column Art_Railing_1_Count I
      alter table Artist add column Art_Railing_2_Count I
      alter table Artist add column Art_Railing_3_Count I
      use in select("Artist")

    case m.lnRev = 4
      alter table Artist add column Art_Hidden L
      alter table Artist add column Art_Organizer L
      select Artist
      index on Art_Hidden tag Hidden
      replace all Art_Organizer with Art_Help_Meet_Up
      this.removeColumn("Artist", "Art_Help_Meet_Up") && no error if d.n.e. 

    case m.lnRev = 5
      * no changes--force view creation 

    case m.lnRev = 6
      alter table Artist add column Art_Title C(60)
      select Artist
      index on Art_Neighborhood tag Neighbor
      use in select("Artist")

    case m.lnRev = 7
      * also force view creation 
      use Artist exclusive in select("Artist")
      select Artist
      index on Art_Last_Name tag Last_Name
      if indbc('artist.user_id',"INDEX")
        delete tag User_Id
      endif 
      use in select("Artist")

    case m.lnRev = 8
      * also force view creation 
      use Artist exclusive in select("Artist")
      select Artist
      index on Art_Register_Time tag reg_time 
      use in select("Artist")

    case m.lnRev = 9
      alter table Artist add column Art_Developer L 
      select Artist
      replace Art_Developer with .t. for Art_PK = THISAPP_DEV_PK           
      use in select("Artist")

    case m.lnRev = 10
      alter table Artist add column Art_Help_Money L 
      alter table Artist add column Art_Starred L 
      select Artist
      index on Art_Starred tag Starred
      replace Art_Help_Money with .t. for [money] $ lower(art_participation)
      replace Art_Help_Materials with .t. for [materials] $ lower(art_participation)
      use in select("Artist")
      
    case m.lnRev = 11
      * Create Facility table:
      do CreateTable ;
        with "Facility", this.cDataPath, this.cDataBase
      use in select("Facility")
      
      alter table Panel add column Pnl_Fac_FK c(32) 
      select Panel
      index on Pnl_Fac_FK tag Fac_FK
      use in select("Panel")

    case m.lnRev = 12
      alter table Piece add column Pce_Fac_FK c(32) 
      select Piece
      index on Pce_Fac_FK tag Fac_FK
      use in select("Piece")

      use Facility exclusive in select("Facility")
      select Facility
      index on fac_Name tag Fac_Name
      use in select("Facility")

    case m.lnRev = 13
      alter table Facility add column Fac_Order N(6, 1)
      select Facility
      index on Fac_Order tag order 
      use in select("Facility")

    case m.lnRev = 14
      use Facility exclusive in select("Facility")
      select Facility
      replace all Fac_Order with recno() 
      use in select("Facility")

    case m.lnRev = 15
      use Panel in select("Panel")
      use Piece in select("Piece")
      select Panel
      scan for Pnl_Single_Piece and empty(Pnl_Stitcher_Art_FK)
        select Piece
        locate for Pce_Pnl_FK = Panel.Pnl_PK
        select Panel
        if found("Piece")
          replace Pnl_Stitcher_Art_FK with Piece.Pce_Art_FK ;
            Pnl_Completed with .t. 
          this.app_log(L7_SEVERITY_NOTICE, "Updated stitcher and completion of Panel: " + Panel.Pnl_ID)
        endif
      endscan 
        
      use in select("Panel")
      use in select("Piece")

    case m.lnRev = 16
      this.removeColumn("Artist", "Art_User_ID") && no error if d.n.e. 
      alter table Artist add column Art_Release_Name L
      use in select("Artist")

      alter table Piece add column Pce_Acknowledged L
      select Piece 
      index on Pce_Acknowledged tag ack 
      use in select("Piece")

    case m.lnRev = 17
      * Create Location table:
      do CreateTable ;
        with "Location", this.cDataPath, this.cDataBase
      use in select("Location")

    case m.lnRev = 18
      * Create PanelLocation table:
      do CreateTable ;
        with "PanelLocation", this.cDataPath, this.cDataBase
      use in select("PanelLocation")

** CAUTION: Need to add any above changes to Create*() functions below!!

    otherwise 
      error "Unknown Database Revision " + transform(m.lnRev)
    
    endcase 
  endfunc && ApplyRevision
  * --------------------------------------------------------- *
  function RemoveColumn(tcTable, tcCol)
    local loExc, laTags[1], lnTag
    if indbc(m.tcTable + "." + m.tcCol, "FIELD")
      try 
        * gain EXCLUSIVE use: 
        use (m.tcTable) exclusive in select(m.tcTable)
        select (m.tcTable)
        * see if any index tags need to be dropped (avoid error 1531):
        ataginfo(laTags)
        for lnTag = 1 to alen(laTags, 1)
          if laTags[m.lnTag, 3] == upper(m.tcCol) && expression matches field (more complex indexes must be explicitly deleted)
            delete tag (laTags[m.lnTag, 1])
            goL7App.App_Log(L7_SEVERITY_NOTICE, textmerge('Deleted Index Tag <<laTags[m.lnTag, 1]>> of <<m.tcTable>> Table'))
            
          endif
        next 
        * Drop the column:
        alter table (m.tcTable) drop column (m.tcCol)
        goL7App.App_Log(L7_SEVERITY_NOTICE, textmerge('Dropped column <<m.tcCol>> of <<m.tcTable>> Table'))
      catch to loExc
        goL7App.App_Log(L7_SEVERITY_WARNING, textmerge('DROP COLUMN failed for <<m.tcTable>>.<<m.tcCol>>: <<loExc.Message>>'))
      finally
        use in select(m.tcTable)
      endtry 
    endif
    return 
  endfunc && RemoveColumn
  * --------------------------------------------------------- *
enddefine && AisApp

*** ===================================================== ***
function CreateEmptyDatabase( lcPath)
  *
  #IF .F.
    * Table Prefixes:

    ART = Artist
    ASM = Assembly
    FAC = Facility (storage)
    FIL = Files
    LOC = Location (installation point)
    PCE = Piece
    PLC = PanelLocation
    PNL = Panel
    RCP = Recipient
    
    RLG = [Reserved for Railing sub-type of Piece table]
     
    SYS = System
  #ENDIF

  private poEnv
  poEnv = GetEnvObject(lcPath)

  create database ( THISAPP_DATABASE )

  * Unique ID Table:
  DO CreateUniqueTable

  * System Table:
  do CreateSystemTable

  * Primary Tables:
  do CreateArtistTable
  *!* do CreateAssemblyTable
  do CreateFacilityTable
  do CreateLocationTable
  do CreatePieceTable
  do CreatePanelTable
  do CreatePanelLocationTable

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
FUNCTION CreateUniqueTable
  * Unique ID Table

  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  CREATE TABLE ( "Unique" ) NAME Unique ;
    ( ;
      Unq_Name C( THISAPP_LENGTH_UNIQUE_NAME) PRIMARY KEY, ;
      Unq_Last_Num I, ;
      Unq_Rev_Time T ;
    )
  INDEX ON DELETED() TAG Deleted
  INDEX ON UPPER( Unq_Name) TAG Name_U
  * Comment:
  DBSETPROP( "Unique", "Table", "Comment", ;
    [One record per "counter" of unique ID assignments. ])
  return  
endfunc   && CreateUniqueTable

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
      Art_Approved L default .f., ;
      Art_Developer L default .f., ;
      Art_Admin L default .f., ;
      Art_Core L default .f., ;
      Art_Hidden L default .f., ; && Rev 4
      Art_Artist L default .t., ;
      Art_Starred L, ;  && Rev 10
      Art_Release_Name L, ;  && Rev 16
      Art_Anonymous L, ;
      Art_Unknown L, ;
      Art_Full_Name C(60), ;
      Art_Last_Name C(20), ;
      Art_First_Name C(24), ;
      Art_Title C(60), ;  && Rev 6
      Art_Name_Orig M, ; 
      Art_Email C(THISAPP_USER_EMAIL_LEN), ;  && 80
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
      Art_Railing_1_Count I, ; && Rev 3
      Art_Railing_2_Count I, ; && Rev 3
      Art_Railing_3_Count I, ; && Rev 3
      Art_Received L, ;
      Art_Storage_Location M, ;
      Art_Towers L, ; 
      Art_Help_Install L, ;
      Art_Help_Materials L, ;
      Art_Help_Money L, ;  && Rev 10
      Art_Organizer L, ; && Rev 4 renamed from Art_Help_Meet_Up
      Art_Help_Outreach L, ;
      Art_Help_Other M, ;
      Art_Comments M, ;
      Art_Register_Time T, ;
      Art_KTB_Response M, ;
      Art_Access_Token C(32), ;
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
  index on Art_Starred tag Starred  && Rev 10
  index on Art_Approved tag Approved
  index on Art_Hidden tag Hidden
  ** index on upper(Art_User_ID) tag User_ID
  index on Art_ID tag Art_ID
  index on Art_Access_Token tag token 
  index on Art_Last_Name tag Last_Name
  index on upper(Art_Last_Name) tag U_last
  index on Art_Artist tag artist 
  index on Art_Neighborhood tag Neighbor  && Rev 6
  index on Art_Register_Time tag reg_time && Rev 8
   
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
      Pce_Fac_FK C(32), ; && Rev 12
      Pce_Whole_Panel L, ;  
      Pce_Dim_1 C(12), ;
      Pce_Dim_2 C(12), ;
      Pce_Type C(THISAPP_LENGTH_PIECE_TYPE), ;
      Pce_Shipped L, ;
      Pce_Ship_Date D, ;
      Pce_Received L, ;
      Pce_Acknowledged L, ;  && Rev 16
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
  index on Pce_Fac_FK tag Fac_FK  && Rev 12
  * Other Keys:
  index on Pce_ID tag Pce_ID
  index on Pce_Shipped tag shipped
  index on Pce_Received tag received
  index on Pce_Acknowledged tag ack 
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
      Pnl_Completed L, ;
      Pnl_Stitcher_Art_FK C(32), ;
      Pnl_Asm_FK C(32), ;
      Pnl_Fac_FK C(32), ; && Rev 11
      Pnl_Single_Piece L, ;  
      Pnl_Dim_1 C(12), ;
      Pnl_Dim_2 C(12), ;
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
  index on Pnl_Fac_FK tag Fac_FK  && Rev 11
  * Other Keys:
  index on Pnl_Completed tag Completed
  index on Pnl_ID tag Pnl_ID
  index on Pnl_Single_Piece tag Single
     
  * Comment:
  dbsetprop("Panel", "Table", "Comment", ;
    [One record per Panel.] )
endfunc  && CreatePanelTable

* --------------------------------------------------------- *
function CreatePanelLocationTable  && TABLE added in Rev 18
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  create table ("PanelLocation") name PanelLocation ;
    ( ;
      Plc_PK C(32) primary key default GetGuid32(), ;
      Plc_Inactive L default .F., ;
      Plc_Pnl_FK C(32), ;
      Plc_Loc_FK C(32), ;
      Plc_Orientation C(5), ;
      Plc_Orig_Art_FK C(32), ;
      Plc_Orig_Time T, ;
      Plc_Rev_Art_FK C(32), ;
      Plc_Rev_Time T, ;
      Plc_Revision I NOT NULL DEFAULT 0 ;
    )

  * Standard 2 Indexes:
  index on deleted() tag Deleted
  index on Plc_Inactive tag Inactive
  * Foreign Keys:
  index on Plc_Pnl_FK tag pnl for !Plc_Inactive candidate 
  index on Plc_Loc_FK tag loc
  * Other Keys:
  index on Plc_Orientation tag Orient 
  * Comment:
  dbsetprop("PanelLocation", "Table", "Comment", ;
    [One record per Panel Location.] )
endfunc  && CreatePanelLocationTable

* --------------------------------------------------------- *
function CreateLocationTable  && TABLE added in Rev 17
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  create table ("Location") name Location ;
    ( ;
      Loc_PK C(32) primary key default GetGuid32(), ;
      Loc_Inactive L default .F., ;
      Loc_ID C(8), ;
      Loc_Side C(4), ;
      Loc_No N(3,0), ;
      Loc_Old_ID C(4), ;
      Loc_H1 N(6,2), ;
      Loc_W1 N(6,2), ;
      Loc_H2 N(6,2), ;
      Loc_Skip L, ;
      Loc_Marker C(20), ;
      Loc_Comments M, ;
      Loc_Notes M, ;
      Loc_Orig_Art_FK C(32), ;
      Loc_Orig_Time T, ;
      Loc_Rev_Art_FK C(32), ;
      Loc_Rev_Time T, ;
      Loc_Revision I NOT NULL DEFAULT 0 ;
    )

  * Standard 2 Indexes:
  index on deleted() tag Deleted
  index on Loc_Inactive tag Inactive
  * Foreign Keys:
  * Other Keys:
  index on Loc_ID tag Loc_ID
  index on Loc_Side tag Loc_Side
  index on Loc_No tag Loc_No
  index on Loc_Old_ID tag Loc_Old_ID
  index on Loc_W1 tag Loc_W1
     
  * Comment:
  dbsetprop("Location", "Table", "Comment", ;
    [One record per Location.] )
endfunc  && CreateLocationTable

* --------------------------------------------------------- *
function CreateFacilityTable  && TABLE added in Rev 11
  * Don't declare this PRIVATE. This command allows this procedure
  * to be run by itself, as in DO <thisproc> IN <thisfile>.PRG:
  poEnv = GetEnvObject()

  create table ("Facility") name Facility ;
    ( ;
      Fac_PK C(32) primary key default GetGuid32(), ;
      Fac_Inactive L default .F., ;
      Fac_ID C(8), ;
      Fac_Order N(6, 1), ;  && Rev 13
      Fac_Name C(60), ;
      Fac_Address M, ;
      Fac_Contact M, ;
      Fac_Email C(THISAPP_USER_EMAIL_LEN), ;  && 80
      Fac_Phone C(24), ;
      Fac_Comments M, ;
      Fac_Storage L, ;
      Fac_DropOff L, ;  
      Fac_Notes M, ;
      Fac_Orig_Art_FK C(32), ;
      Fac_Orig_Time T, ;
      Fac_Rev_Art_FK C(32), ;
      Fac_Rev_Time T, ;
      Fac_Revision I NOT NULL DEFAULT 0 ;
    )

  * Standard 2 Indexes:
  index on deleted() tag Deleted
  index on Fac_Inactive tag Inactive
  * Foreign Keys:
  * Other Keys:
  index on Fac_ID tag Fac_ID
  index on Fac_Name tag Fac_Name  && Rev 12
  index on Fac_Storage tag Storage
  index on Fac_DropOff tag DropOff
  index on Fac_Order tag order && Rev 13
     
  * Comment:
  dbsetprop("Facility", "Table", "Comment", ;
    [One record per Facility.] )
endfunc  && CreateFacilityTable

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
      Art_PK, Art_Inactive, Art_Admin, Art_Hidden, Art_Artist, Art_Anonymous, ;
      Art_Full_Name, Art_First_Name, Art_Last_Name, ;
      Art_Orig_Art_FK, Art_Orig_Time, Art_Rev_Art_FK, Art_Rev_Time ;
    ) VALUES ( ;
      THISAPP_ADMIN_PK, .T., .t., .t., .f., .f., ;
      "SYSTEM ADMINISTRATOR", "SYSTEM", "ADMINISTRATOR", ;
      THISAPP_ADMIN_PK, m.poEnv.tTime, THISAPP_ADMIN_PK, m.poEnv.tTime )

  * "Developer"
  insert into Artist ( ;
      Art_PK, Art_Inactive, Art_Admin, Art_Hidden, Art_Approved, Art_Artist, Art_Anonymous, ;
      Art_Full_Name, Art_First_Name, Art_Last_Name, ;
      Art_ID, Art_Password_Hash, ;
      Art_Orig_Art_FK, Art_Orig_Time, Art_Rev_Art_FK, Art_Rev_Time ;
    ) VALUES ( ;
      THISAPP_DEV_PK, .f., .t., .t., .t., .f., .f., ;
      "SYSTEM DEVELOPER", "SYSTEM", "DEVELOPER", ;
      THISAPP_USER_DEV, AisPasswordHash(THISAPP_USER_DEV, THISAPP_USER_DEV), ;
      THISAPP_ADMIN_PK, m.poEnv.tTime, THISAPP_ADMIN_PK, m.poEnv.tTime )

  * "Anonymous User"
  insert into Artist ( ;
      Art_PK, Art_Inactive, Art_Admin, Art_Hidden, Art_Artist, Art_Anonymous, ;
      Art_Full_Name, Art_First_Name, Art_Last_Name, ;
      Art_Orig_Art_FK, Art_Orig_Time, Art_Rev_Art_FK, Art_Rev_Time ;
    ) VALUES ( ;
      THISAPP_ANON_PK, .T., .f., .t., .f., .t., ;
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
    do CreateChildView WITH "V_Panel_Piece_Set", "Piece", "Pce_Pnl_FK", "Panel", [Pce_Inactive=.F.]

    * All-record views (for master "browse" forms):
    do CreateAllRecordsView WITH "V_Unapproved_Artists",  "Artist", "Art_PK", [!Art_Inactive and !Art_Approved]
    do CreateAllRecordsView WITH "V_Artists_by_Name",     "Artist", "Art_PK", [!Art_Inactive and !empty(Art_ID) and !Art_Hidden], [Art_Last_Name, Art_First_Name]
    do CreateAllRecordsView WITH "V_Artists_by_Location", "Artist", "Art_PK", [!Art_Inactive and !empty(Art_ID) and !Art_Hidden], [Art_Neighborhood]
    do CreateAllRecordsView WITH "V_Artists_by_Reg_Time", "Artist", "Art_PK", [!Art_Inactive and !empty(Art_ID) and !Art_Hidden], [Art_Register_Time]

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
