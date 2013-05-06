* L7Data.PRG
*
* CAUTION: These classes do not refelct current thinking. These are
*    used in some early L7 apps. (TRAD, IMDB, etc)
*
#DEFINE L7DATA_PRIVATE_DATASESSION .F.
#UNDEF THIS_DEBUG 
#DEFINE THIS_DEBUG .F.

#IF .F.
***** BEGIN LICENSE BLOCK *****
Version: MPL 1.1

The contents of this file are subject to the Mozilla Public License Version 
1.1 (the "License"); you may not use this file except in compliance with 
the License. You may obtain a copy of the License at 
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is "Level 7 Framework for Web Connection" and 
"Level 7 Toolkit" (collectively referred to as "L7").

The Initial Developer of the Original Code is Randy Pearson of 
Cycla Corporation.

Portions created by the Initial Developer are Copyright (C) 2004 by
the Initial Developer. All Rights Reserved.

***** END LICENSE BLOCK *****
#ENDIF


* This is old. Need to move to app-specific location for any apps that need it still!
* This or something like it could go in DBC after debugging.
* Developers using L7Data should subclass and provide their own
* NewId() method that calls someting else.
FUNCTION NextId
  LPARAMETER lcTable
  LOCAL lnNextId, lnSelect, vp_cName, ii, llOK
  lnSelect = SELECT()
  lnNextId = -1
  SELECT 0
  vp_cName = PADR( UPPER( m.lcTable), 30 )
  USE V_Unique
  llOk = .F.

  FOR ii = 1 TO 30
  	IF _TALLY = 0
  		* No record yet for this table!
  		lnNextId = 1
  		APPEND BLANK
  		REPLACE Unq_Name WITH vp_cName Unq_Last_Num WITH 1
  	ELSE
  		lnNextId = Unq_Last_Num + 1
  		REPLACE Unq_Last_Num WITH m.lnNextId
  	ENDIF
  	llOK = TABLEUPDATE( 1 )
  	IF m.llOk 
  		EXIT
  	ELSE
  		* Simultaneous requests--try again.
  		= TABLEREVERT()
  		= REQUERY( "v_Unique" )
  	ENDIF
  ENDFOR
  SELECT ( m.lnSelect )
  RETURN m.lnNextId
ENDFUNC  && NextId

*** ============================================== ***
DEFINE CLASS L7ViewData AS L7Data
  * Sub-class of L7Data for Local Views with v_ prefixes.
  nRecordId        = -1   && when integer keys used
  cRecordId        = space(32) && when GUID/char keys used
  lObjectMessaging = .T.
  lIntegerKeys     = .T. && set .F, for GUID/char keys
  * -------------------------------------------------- *
  function _isNewRecord()
    return iif(this.lIntegerKeys, this.nRecordId = -1, empty(this.cRecordId))
  endfunc 
  * -------------------------------------------------- *
  FUNCTION GetRecord
    THIS.SelectAlias()
    LOCAL loRecord
    SCATTER MEMO NAME loRecord
    * Transfer defaults *if* it's a new record.
    IF this._isNewRecord() && THIS.nRecordId = -1
    	THIS.LoadDefaults()
    	LOCAL ii
    	FOR ii = 1 TO THIS.nDefaults
    		STORE THIS.aDefaults[ m.ii, 2] TO ;
    			( "loRecord." + THIS.aDefaults[ m.ii, 1] )
    	ENDFOR
    ENDIF
    RETURN loRecord
  ENDFUNC  && GetRecord
  * -------------------------------------------------- *
  FUNCTION InsertFromRecord(loRecord)

error "This method appears never have been valid."

*!*      LOCAL llRetVal
*!*      THIS.SelectAlias()
*!*      llRetVal = THIS.AddRecord()
*!*      IF m.llRetVal
*!*      	llRetVal = THIS.UpdateFromRecord( m.loRecord )
*!*      ENDIF	
*!*      RETURN m.llRetVal
  ENDFUNC  && InsertFromRecord
  * -------------------------------------------------- *
  FUNCTION UpdateFromRecord(loRecord)

error "This method appears never have been valid."

*!*      THIS.SelectAlias()
*!*      * Modify timestamp and user properties:
*!*      STORE THIS.tTimestamp      TO ( "loRecord." + THIS.cPrefix + "_Rev_T" )
*!*      STORE THIS.oUser.nPersonId TO ( "loRecord." + THIS.cPrefix + "_Rev_Per_FK" )

*!*      * Create list of fields *not* to update:
*!*      LOCAL lcExcept
*!*      lcExcept = THIS.cPrefix + "_PK," + ;
*!*      	THIS.cPrefix + "_Orig_Per_FK," + ;
*!*      	THIS.cPrefix + "_Orig_T"
*!*      	
*!*      GATHER MEMO NAME loRecord FIELDS EXCEPT &lcExcept
*!*      IF NOT THIS.lError
*!*      	IF NOT TABLEUPDATE()
*!*      		TABLEREVERT()
*!*      		THIS.SetError( "Error commiting database changes.")
*!*      	ENDIF
*!*      ENDIF

*!*      RETURN NOT THIS.lError
  ENDFUNC  && UpdateFromRecord
  * -------------------------------------------------- *
  FUNCTION AddRecord

error "This method appears never to be called and itself calls an invalid method."

*!*      LOCAL lnNewId, llRetVal, lcCmd
*!*      lnNewId = THIS.NewId()
*!*      IF m.lnNewId > 0
*!*      	THIS.SelectAlias()
*!*      	llRetVal = .T.
*!*      	lcCmd = [INSERT INTO ] + THIS.cAlias + ;
*!*      		[ (] + THIS.cKeyField + [, ] + ;
*!*      		THIS.cPrefix + [_Orig_Per_FK, ] + ;
*!*      		THIS.cPrefix + [_Orig_T) VALUES (] + ;
*!*      		LTRIM( STR( m.lnNewId)) + ;
*!*      		[, THIS.oUser.nPersonId, THIS.tTimestamp)]
*!*      	&lcCmd
*!*      	THIS.nRecordId = m.lnNewId
*!*      *!*		IF NOT TABLEUPDATE()
*!*      *!*			= TABLEREVERT()
*!*      *!*			THIS.SetError( "Error adding record to database." )
*!*      *!*			llRetVal = .F.
*!*      *!*		ELSE	
*!*      *!*			= THIS.FindRecord( m.lnNewId )
*!*      	IF NOT THIS.lObjectMessaging
*!*      		llRetVal = THIS.SaveFieldChanges( .T.)
*!*      	ENDIF
*!*      *!*		ENDIF
*!*      ENDIF
*!*      RETURN m.llRetVal

  ENDFUNC  && AddRecord
  * -------------------------------------------------- *
  FUNCTION SelectAlias
    * Called by: AddRecord(), SaveRecord()
    * Up to you to save SELECT() status, if necessary, first.
    IF THIS.lTableIsOpen = .F. 
    	THIS.FindRecord()
    ENDIF
    SELECT ( THIS.cAlias )
  ENDFUNC  && SelectAlias
  * -------------------------------------------------- *
  function FindRecord( tvKey )
    if empty(m.tvKey)
    	tnKey = iif(this.lIntegerKeys, this.nRecordId, this.cRecordId)
    endif 

    local ii, lcViewParm, lnSelect
    if this.lIntegerKeys     
      lcViewParm = "vp_n" + THIS.cPrefix + "_PK"
    else
      lcViewParm = "vp_c" + THIS.cPrefix + "_PK"
    endif 
    local ( m.lcViewParm )
    STORE m.tvKey TO ( m.lcViewParm )
    lnSelect = SELECT()
    SELECT 0
    FOR ii = 1 TO 100
    	THIS.cAlias = "V_" + THIS.cTable + "_" + LTRIM( STR( m.ii))
    	IF USED( THIS.cAlias )
    		LOOP
    	ENDIF
    	IF m.ii > 100
    		RETURN .F.
    	ENDIF
    	USE ( "V_" + THIS.cTable ) ;
    		ALIAS ( THIS.cAlias ) ;
    		IN 0
      * AGAIN [[ caused BUG when view in use elsewhere!
    	THIS.lTableIsOpen = .T.
    	IF this.lIntegerKeys and m.tvKey < 0
    		** THIS.lRecordFound = .T.  && [[ Why .T. ???
        THIS.lRecordFound = .F.  && 10/27/2009: .T. was playing into URL hacks with - (neg) numbers in URL
    	ELSE
    		IF RECCOUNT( THIS.cAlias) = 1
    			THIS.lRecordFound = .T.
    		ELSE
    			IF RECCOUNT( THIS.cAlias) >= 2
    				ERROR TRANS( RECCOUNT( THIS.cAlias)) + " records in alias for view of " + THIS.cTable + ;
    					" with Key = " + TRANS( m.tvKey) + ". [L7Data]"
    			ELSE
    				THIS.lRecordFound = .F.
    			ENDIF
    		ENDIF
    	endif
      if this.lIntegerKeys
        this.nRecordId = IIF( THIS.lRecordFound, m.tvKey, -1)
      else
        this.cRecordId = IIF( THIS.lRecordFound, m.tvKey, space(32))
      endif 
    	this.lTableIsOpen = .T.
    	exit 
    endfor 
    if !this.lTableIsOpen
      error "Could not open alias for view of " + THIS.cTable + ". [L7Data]"
    endif 
    select ( m.lnSelect )
    return this.lRecordFound
  endfunc  && FindRecord
  * -------------------------------------------------- *
  FUNCTION SaveRecord

error "This method appears never to be called and itself calls an invalid method."

*!*      * Only called following FindRecord().
*!*      LOCAL lnSelect, llRetVal, ii
*!*      lnSelect = SELECT()
*!*      llRetVal = .T.
*!*      IF THIS.SelectAlias()
*!*      	IF THIS.lRecordFound
*!*      		IF THIS.SaveFieldChanges( .F.)
*!*      			llRetVal = .T.
*!*      		ENDIF
*!*      	ELSE
*!*      		THIS.SetError( "Record not found or selected--changes not saved.")
*!*      		llRetVal = .F.
*!*      	ENDIF
*!*      ENDIF
*!*      SELECT ( m.lnSelect )
*!*      RETURN m.llRetVal
  ENDFUNC  && SaveRecord
  * -------------------------------------------------- *
  FUNCTION SaveFieldChanges( tlAddMode )

error "This method appears never have been valid."

*!*      * Called by: AddRecord and SaveRecord.
*!*      * (Never call directly.)
*!*      LOCAL ii, lcFields, lcCmd
*!*      STORE "" TO lcFields
*!*      IF m.tlAddMode
*!*      	IF NOT THIS.lDefaultsLoaded
*!*      		THIS.LoadDefaults()
*!*      		THIS.lDefaultsLoaded = .T.
*!*      	ENDIF
*!*      	FOR ii = 1 TO THIS.nDefaults
*!*      		IF NOT THIS.aDefaults[ m.ii, 3]  && not disabled
*!*      			* Queue change only if needed, using 3rd parameter flag:
*!*      			THIS.QueueFieldChange( THIS.aDefaults[ m.ii, 1], ;
*!*      				THIS.aDefaults[ m.ii, 2], .T. )
*!*      		ENDIF
*!*      	ENDFOR
*!*      ENDIF
*!*      FOR ii = 1 TO THIS.nChanges
*!*      	IF NOT THIS.aChanges[ m.ii, 3]  && cleared, or already saved
*!*      		lcFields = m.lcFields + ", " + THIS.aChanges[ m.ii, 1] + ;
*!*      			" WITH THIS.aChanges[" + LTRIM( STR( m.ii)) + ",2]"
*!*      	ENDIF
*!*      ENDFOR
*!*      lcFields = m.lcFields + ", " + THIS.cPrefix + "_Rev_T WITH THIS.tTimeStamp"
*!*      lcFields = m.lcFields + ", " + THIS.cPrefix + "_Rev_Per_FK WITH THIS.oUser.nPersonId"

*!*      IF NOT EMPTY( m.lcFields )
*!*      	lcCmd = [REPLACE ] + SUBSTR( m.lcFields, 2)
*!*      	IF NOT THIS.lError
*!*      		THIS.SelectAlias()
*!*      		&lcCmd
*!*      		IF NOT THIS.lError
*!*      			IF NOT TABLEUPDATE()
*!*      				= TABLEREVERT()
*!*      				THIS.SetError( "Error commiting database changes.")
*!*      			ENDIF
*!*      		ENDIF
*!*      	ENDIF
*!*      ENDIF
*!*      RETURN NOT THIS.lError
  ENDFUNC  && SaveFieldChanges
  * -------------------------------------------------- *
ENDDEFINE  && L7ViewData

*** ============================================== ***
#IF L7DATA_PRIVATE_DATASESSION
DEFINE CLASS L7Data AS SESSION
#ELSE
DEFINE CLASS L7Data AS RELATION
#ENDIF
  cDataPath = ""
  cDatabase = ""
  cTable    = "x"  && override this
  cAlias    = "x"
  cPrefix   = "xxx"  && override this
  lIntegerKeys = .T. && set .F, for GUID/char keys
  nRecordId    = 0
  cRecordId    = space(32)
  cKeyField = ""
  lRecordFound = .F.
  lTableIsOpen = .F.

  oUser = NULL

  tTimeStamp = NULL

  * These track field-level changes:
  DIMENSION aChanges[ 1, 3]
  nChanges = 0

  * These are for default values:
  DIMENSION aDefaults[ 1, 3]
  nDefaults = 0
  lDefaultsLoaded = .F.

  * Error handling:
  lError = .F.
  cErrorMessage = ""
  nError = 0
  * -------------------------------------------------- *
  FUNCTION GetData(lcProp)
    IF THIS.lTableIsOpen AND ;
    	THIS.lRecordFound
    	*
    	RETURN EVAL( THIS.cAlias + "." + m.lcProp )
    ELSE
    	RETURN NULL
    ENDIF
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION cKeyField_ACCESS
    RETURN THIS.cPrefix + "_PK"
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION INIT(loUser)

    #IF L7DATA_PRIVATE_DATASESSION
    DO StandardVfpSettings  && SET EXACT, DELETED, etc.
    #ENDIF
    
    IF VARTYPE( goL7App) = "O"
    	THIS.cDataPath = goL7App.cDataPath
    	THIS.cDataBase = goL7App.cDataBase
    ENDIF

    IF VARTYPE( loUser) = "O"
    	THIS.oUser = m.loUser
    ELSE
    	IF VARTYPE( m.CurrentUser) = "O"
    		THIS.oUser = m.CurrentUser
    	ENDIF
    ENDIF

    IF NOT DBUSED( THIS.cDatabase)
    	OPEN DATABASE (THIS.cDataPath + THIS.cDatabase)
    ENDIF
    SET DATABASE TO ( THIS.cDatabase )

    THIS.tTimeStamp = DATETIME()
    THIS.cAlias = THIS.cTable + "_1" 
  ENDFUNC  && INIT
  * -------------------------------------------------- *
  FUNCTION Destroy
    THIS.CloseTable()
    THIS.oUser = NULL  && needed for GC
  ENDFUNC
  * -------------------------------------------- *
  FUNCTION CloseTable
    * Called by: Destroy()
    IF THIS.lTableIsOpen
    	IF USED( THIS.cAlias )
    		USE IN ( THIS.cAlias)
    	ENDIF
    	THIS.lTableIsOpen = .F.
    ENDIF
  ENDFUNC  && CloseTable
  *!*    * -------------------------------------------------- *
  *!*    #IF THIS_DEBUG = .F.
  *!*    FUNCTION Error( tnError, tcMethod, tnLine )
  *!*      * VFP error handler.
  *!*      THIS.lError = .T.
  *!*      THIS.nError = m.tnError
  *!*      THIS.cErrorMessage = MESSAGE()
  *!*      WAIT WINDOW MESSAGE() TIME 1
  *!*    ENDFUNC  && ERROR
  *!*    #ENDIF
  * -------------------------------------------------- *
  FUNCTION SetError( tcMessage )
    ERROR m.tcMessage
    *!*      * Simulate error condition by setting flag and
    *!*      * message programatically.
    *!*      THIS.lError = .T.
    *!*      THIS.nError = 1098
    *!*      THIS.cErrorMessage = IIF( EMPTY( m.tcMessage), ;
    *!*      	"User-initiated error.", m.tcMessage )
  ENDFUNC  && SetError
  * -------------------------------------------------- *
  FUNCTION OpenTable
    * Called by: SelectAlias()
    LOCAL ii
    FOR ii = 1 TO 100
    	THIS.cAlias = THIS.cTable + "_" + LTRIM( STR( m.ii))
    	IF USED( THIS.cAlias )
    		LOOP
    	ENDIF
    	IF m.ii > 100
    		RETURN .F.
    	ENDIF
      TRY
      	USE ( THIS.cDatabase + "!" + THIS.cTable ) ;
      		AGAIN ;
      		ALIAS ( THIS.cAlias ) ;
      		IN 0
      CATCH TO loExc
        ERROR [Error "] + loExc.Message + [" occurred in class ] + THIS.Class + ;
          [ when trying to open table.]
      ENDTRY
    	THIS.lTableIsOpen = .T.
    	THIS.lRecordFound = .F.
    	THIS.nRecordId = -1
    	EXIT
    ENDFOR
  ENDFUNC  && OpenTable
  * -------------------------------------------------- *
  FUNCTION NewId
    if this.lIntegerKeys     
      RETURN NextID( THIS.cTable )
    else
      return getGuidString(32) 
    endif
  ENDFUNC  && NewId
  * -------------------------------------------------- *
  FUNCTION AddRecord

    if !this.lIntegerKeys     
      error "This method only works with integer keys so far."
    endif

    LOCAL lnNewId, llRetVal, lcCmd
    lnNewId = THIS.NewId()
    IF m.lnNewId > 0
    	llRetVal = .T.
    	lcCmd = [INSERT INTO ] + THIS.cTable + ;
    		[(] + THIS.cKeyField + [) VALUES (] + ;
    		LTRIM( STR( m.lnNewId)) + [)]
    	&lcCmd
    	THIS.FindRecord( m.lnNewId )
    	THIS.SaveFieldChanges( .T.)
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && AddRecord
  * -------------------------------------------------- *
  FUNCTION SelectAlias
    * Called by: FindRecord(), AddRecord(), SaveRecord()
    * Up to you to save SELECT() status, if necessary, first.
    IF THIS.lTableIsOpen = .F. OR NOT USED( THIS.cAlias )
    	IF NOT THIS.OpenTable()
    		RETURN .F.
    	ENDIF
    ENDIF
    SELECT ( THIS.cAlias )
  ENDFUNC  && SelectAlias
  * -------------------------------------------------- *
  FUNCTION LocateFor( tcExpr )

    if !this.lIntegerKeys     
      error "This method only works with integer keys so far."
    endif

    LOCAL lnSelect
    lnSelect = SELECT()
    THIS.lRecordFound = .F.
    IF THIS.SelectAlias()
    	LOCAL lcKeyField
    	LOCATE FOR &tcExpr
    	THIS.lRecordFound = FOUND()
    	THIS.nRecordId = IIF( THIS.lRecordFound, EVAL( THIS.cKeyField), -1)
    ENDIF
    SELECT ( m.lnSelect )
    RETURN THIS.lRecordFound
  ENDFUNC  && FindRecord
  * -------------------------------------------------- *
  FUNCTION FindRecord( tnKey )

    if !this.lIntegerKeys     
      error "This method only works with integer keys so far."
    endif

    LOCAL lnSelect
    lnSelect = SELECT()
    THIS.lRecordFound = .F.
    IF THIS.SelectAlias()
    	LOCAL lcKeyField
    	lcKeyField = THIS.cKeyField
    	LOCATE FOR &lcKeyField = m.tnKey
    	THIS.lRecordFound = FOUND()
    	THIS.nRecordId = IIF( THIS.lRecordFound, m.tnKey, -1)
    ENDIF
    SELECT ( m.lnSelect )
    RETURN THIS.lRecordFound
  ENDFUNC  && FindRecord
  * -------------------------------------------------- *
  FUNCTION GetRecord
    THIS.SelectAlias()
    LOCAL loRecord
    SCATTER MEMO NAME loRecord
    RETURN loRecord
  ENDFUNC  && GetRecord
  * -------------------------------------------------- *
  FUNCTION SaveRecord
    LOCAL lnSelect, llRetVal, ii
    lnSelect = SELECT()
    llRetVal = .T.
    IF THIS.SelectAlias()
    	IF THIS.lRecordFound
    		IF THIS.SaveFieldChanges( .F.)
    			llRetVal = .T.
    		ENDIF
    	ELSE
    		THIS.SetError( "Record not found or selected--changes not saved.")
    		llRetVal = .F.
    	ENDIF
    ENDIF
    SELECT ( m.lnSelect )
    RETURN m.llRetVal
  ENDFUNC  && SaveRecord
  * -------------------------------------------------- *
  FUNCTION SaveFieldChanges( tlAddMode )
    * Called by: AddRecord and SaveRecord.
    * (Never call directly.)
    LOCAL ii, lcFields, lcCmd
    STORE "" TO lcFields
    IF m.tlAddMode
    	IF NOT THIS.lDefaultsLoaded
    		THIS.LoadDefaults()
    		THIS.lDefaultsLoaded = .T.
    	ENDIF
    	FOR ii = 1 TO THIS.nDefaults
    		IF NOT THIS.aDefaults[ m.ii, 3]  && not disabled
    			* Queue change only if needed, using 3rd parameter flag:
    			THIS.QueueFieldChange( THIS.aDefaults[ m.ii, 1], ;
    				THIS.aDefaults[ m.ii, 2], .T. )
    		ENDIF
    	ENDFOR
    ENDIF
    FOR ii = 1 TO THIS.nChanges
    	IF NOT THIS.aChanges[ m.ii, 3]  && cleared, or already saved
    		lcFields = m.lcFields + ", " + THIS.aChanges[ m.ii, 1] + ;
    			"=THIS.aChanges[" + LTRIM( STR( m.ii)) + ",2]"
    	ENDIF
    ENDFOR
    IF NOT EMPTY( m.lcFields )
    		
    	lcCmd = [UPDATE ] + THIS.cTable + ;
    		[ SET ] + SUBSTR( m.lcFields, 2) + ;
    		[ WHERE ] + THIS.cKeyField + [=] + LTRIM( STR( THIS.nRecordId ))

    	IF NOT THIS.lError
    		&lcCmd
    	ENDIF
    ENDIF
    RETURN NOT THIS.lError
  ENDFUNC  && SaveFieldChanges
  * -------------------------------------------------- *
  FUNCTION LoadDefaults()
    * Override this method in Sub-class, and make calls
    * to AddDefault, like this:
    *
    * = THIS.AddDefault( 'status', 'OPEN' )
    * more...
  ENDFUNC  && LoadDefaults
  * -------------------------------------------------- *
  FUNCTION AddDefault( tcField, tuValue )
    * Store a default value to be added with a new record.

    LOCAL ii 
    FOR ii = 1 TO THIS.nDefaults
    	IF UPPER( THIS.aDefaults[ m.ii, 1]) == UPPER( m.tcField)
    		* Already queued!
    		THIS.aDefaults[ m.ii, 2] = m.tuValue
    		THIS.aDefaults[ m.ii, 3] = .F.
    		RETURN
    		* EXIT
    	ENDIF
    ENDFOR
    IF m.ii > THIS.nDefaults
    	THIS.nDefaults = THIS.nDefaults + 1
    	DIMENSION THIS.aDefaults[ THIS.nDefaults, 3]
    	THIS.aDefaults[ THIS.nDefaults, 1] = UPPER( m.tcField)
    	THIS.aDefaults[ THIS.nDefaults, 2] = m.tuValue
    	THIS.aDefaults[ THIS.nDefaults, 3] = .F.
    ENDIF
  ENDFUNC  && AddDefault
  * -------------------------------------------------- *
  FUNCTION QueueFieldChange( tcField, tuValue, tlDefaultValue )
    *
    * Queues a field change. DOES NOT SAVE the change.
    * Call SaveRecord() when ready to save all changes.
    * 3rd Parameter, if set to TRUE does NOT queue the change
    *   if the same field is already queued with a value. This
    *   allows AddDefaultValues to queue defaults without
    *   clashing with any code that is trying to set those fields.
    *
    LOCAL ii 
    FOR ii = 1 TO THIS.nChanges
    	IF UPPER( THIS.aChanges[ m.ii, 1]) == UPPER( m.tcField)
    		* Already queued!
    		IF NOT m.tlDefaultValue
    			THIS.aChanges[ m.ii, 2] = m.tuValue
    			THIS.aChanges[ m.ii, 3] = .F.
    		ENDIF
    		RETURN
    		* EXIT
    	ENDIF
    ENDFOR
    IF m.ii > THIS.nChanges
    	THIS.nChanges = THIS.nChanges + 1
    	DIMENSION THIS.aChanges[ THIS.nChanges, 3]
    	THIS.aChanges[ THIS.nChanges, 1] = UPPER( m.tcField)
    	THIS.aChanges[ THIS.nChanges, 2] = m.tuValue
    	THIS.aChanges[ THIS.nChanges, 3] = .F.
    ENDIF
  ENDFUNC  && QueueFieldChange
  * -------------------------------------------------- *
ENDDEFINE  && L7Data
*** ============================================== ***

#if .f.
01/28/2004 - updated Destroy() to release oUser (GC).
#endif
