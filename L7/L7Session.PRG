#INCLUDE L7.H

* L7Session.PRG

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


**** ======================================================== ***
DEFINE CLASS L7Session AS SESSION
  lRecycleRecords = .F.   && recycle policy--if .f., must arrange for session pruning (or daily tables)
  lDailyTables = .T.      && .t. to support daily tables with rollover
  dToday = null
  lQuarterlyFolders = .T. && separates tables (if daily) into different subfolders by quarter, eg: ..\LogFiles\2006-Q1\
  cDatapath  = ""
  cTableName = "L7Session"  && usually overwritten by app.cSessionTable
  tLastCleanup = NULL
  nTimeout   = 3600  && seconds (3600 = 1 hour)
  nTimeout_Saved = NULL
  cUserToken = "x"
  nHits      = 0
  tNow       = NULL
  lLoggedIn  = NULL  && unused--see related access method
  lJustExpired = .F. && indicates if a logged-in user just expired
  lValidSession = .F.
  cIpAddress = ""
  cClientCRC = "          "
  cMagicXmlPrefix = 'L7Object__' && prefix object names
  * --------------------------------------------------------- *
  FUNCTION nHits_ACCESS
    IF this.IsValidSession()
      RETURN Hits
    ELSE
      RETURN 0
    ENDIF 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION lLoggedIn_ACCESS
    IF this.IsValidSession()
      RETURN LoggedIn
    ELSE
      RETURN .F.
    ENDIF 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION INIT
    DO StandardVfpSettings  && required for new private datasession
    SET MULTILOCKS OFF      && 03/13/2006, prevent stray lock from linking 2 records to 1 session
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION RELEASE
    ** THIS.oScript = NULL
    THIS.Cleanup()
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    THIS.RELEASE()
  ENDFUNC 
  * --------------------------------------------------------- *
  * same as L7RequestLog.getLogFilePath, so daily (related) files can be colocated
  function GetDataPath(ldDate)
    local lcPath
    ldDate = evl(m.ldDate, DATE())  && default to today
    lcPath = iif(empty(this.cDataPath), [.\], addbs(this.cDataPath))
    if this.lQuarterlyFolders 
      * See note in L7LogRequest.getLogFilePath
      lcPath = addbs(m.lcPath + ;
        str(year(m.ldDate), 4, 0) + "-Q" + str(ceiling(month(m.ldDate) / 3), 1, 0))
      * e.g., path.../2006-Q1/
    endif
    * create folder if not present: 
    if !directory(m.lcPath)
      L7MkDir (m.lcPath)
    endif 
    return m.lcPath
  endfunc
  * --------------------------------------------------------- *
  function SetDataPath(tcPath)
    this.cDataPath = m.tcPath
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION SetTableName(lcName)
    * note: where daily tables are used, the TableName is just a prefix 
    THIS.cTableName = m.lcName
  ENDFUNC
  * --------------------------------------------------------- *
  function GetTableName(tdDate)
    * note: where daily tables are used, the TableName is just a prefix 
    local lcName
    lcName = THIS.cTableName 
    if this.lDailyTables 
      lcName = m.lcName + "_" + dtos(evl(m.tdDate, date()))
    endif
    return m.lcName
  endfunc 
  * --------------------------------------------------------- *
  function Reset 
    * Clears session properties (between hits) so object can be persistent.
    * Possibly called quasi-redundantly at begin/end of processor work. 
    * CAUTION: Subclasses should extend reset() to cover add'l properties, if applicable.
    with this
      * NOTE: dToday does not require resetting
      .tNow = DATETIME()
      .cClientCRC = SPACE(10)
      .cIpAddress = ""
      if !isnull(.nTimeout_Saved) && previous hit used custom timeout, restore original
        .nTimeout = .nTimeout_Saved
        .nTimeout_Saved = NULL
      endif 
      .lJustExpired = .F.
      .lValidSession = .F.
      this.CheckCleanup() && hook to allow occasional maintenance, such as auto-expiry
    endwith 
    return 
  endfunc && Reset
  * --------------------------------------------------------- *
  function CheckCleanup
    if isnull(THIS.tLastCleanup)
      this.tLastCleanup = DATETIME()
    else 
      if DATETIME() - this.tLastCleanup > this.nTimeout
        this.Cleanup()
      endif 
    endif 
    return 
  endfunc  && CheckCleanup
  * --------------------------------------------------------- *
  function Cleanup && subclasses can add behavior
    this.tLastCleanup = DATETIME()
    return 
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION SetTimeout(lnSecs)
    THIS.nTimeout = m.lnSecs
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION OverrideTimeout(lnSecs)
    STORE THIS.nTimeout TO THIS.nTimeout_Saved
    THIS.nTimeout = m.lnSecs
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetAvailableRecord
    * Find and lock an unused or expired record, or create and
    * lock a new record.
    LOCAL llRetVal, ltTimeout, lnTries
    llRetVal = .T.
    llRetVal = m.llRetVal AND THIS.OpenTable()
    IF m.llRetVal
    	llRetVal = .F.
      if this.lRecycleRecords
      	ltTimeout = THIS.tNow - THIS.nTimeout
      	SCAN FOR LastHit < m.ltTimeout
      		* Look for a timed-out session.
      		IF NOT RLOCK()
      			LOOP
      		ENDIF
      		IF LastHit < m.ltTimeout
      			* 2nd check after lock applied.
      			llRetVal = .T.
      			THIS.ClearRecord()
      			EXIT
      		ENDIF
      	ENDSCAN
    	endif && recycle

      IF NOT m.llRetVal  && no un-used sessions or no recycle policy
    		FOR lnTries = 1 TO 25
    			APPEND BLANK
    			IF RLOCK()
    				llRetVal = .T.
    				EXIT
    			ENDIF
    		ENDFOR
    	ENDIF
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && GetAvailableRecord           
  * --------------------------------------------------------- *
  FUNCTION IsValidSession
    RETURN THIS.lValidSession
  ENDFUNC  && IsValidSession
  * --------------------------------------------------------- *
  FUNCTION UpdateSession(tcReason)
    * Change session timestamp and update hit count.
    * Assumes record pointer on desired record.
    * Called by high-level methods like FindLicensePlateSession().
    LOCAL llLock, llRetVal, lnTry, lnTries
    lnTries = 25
    FOR lnTry = 1 TO m.lnTries
    	IF RLOCK()
        llLock = .t.
        do case
        case this.wasExpired()
          tcReason = "Session timed out."
          llRetVal = .f.
        case this.tNow - LastHit > this.nTimeout
          tcReason = "Session timed out."
    			llRetVal = .F.
    			* Flag if we are forcing
    			* expiration of a logged-in user on this hit. This flag can
    			* be checked to decide between treating the hit as anonymous
    			* or requiring a new login:
    			IF THIS.lLoggedIn
    				THIS.lJustExpired = .T.
    			endif
          this.afterExpiration(@tcReason)
    		otherwise  && Current Session
    			* Set flag so IsValidSession can reference it.
    			llRetVal = .T.
    			THIS.lValidSession = .T.
    			REPLACE ;
    				Hits WITH Hits + 1 ;
    				LastHit WITH THIS.tNow
    		endcase 

    		UNLOCK
    		EXIT
    	ENDIF
    endfor
    if not m.llLock
      tcReason = "Could not lock record to update session status."
      llRetVal = .f.
    endif

    RETURN m.llRetVal
  ENDFUNC  && UpdateSession                
  * --------------------------------------------------------- *
  function wasExpired(tcReason) && record is locked at this point
    return Expired or !empty(LogoutTime) && Today.Expired?
  endfunc 
  * --------------------------------------------------------- *
  function afterExpiration(tcReason) && record is locked at this point
    replace Expired with .t. ;
      ExpiryTime with this.tNow 
  endfunc 
  * --------------------------------------------------------- *
  function LicensePlateIdentifiesUser
    * Check to see if a specific license plate
    * indetifies who the user is.
    return THIS.IsValidSession() and ;
      !empty(UserToken) and ;
      inlist(TokenType, "LP ", "TC+", "PC+") and ;
    	!empty(UserId) 
      
  endfunc  && LicensePlateIdentifiesUser   
  * --------------------------------------------------------- *
  function FindLicensePlateSession(tcId, tcReason)  && proposed license plate to check
    if vartype(m.tcId) <> "C" OR empty(m.tcId)
      tcReason = "Session ID not passed in."
      return .f.
    endif 
    if !ValidGuid(m.tcId)
      tcReason = "Session ID not a valid UUID"
      return .f.
    endif 
    local llRetVal, lcId
    llRetVal = this.OpenTable() 

    if !m.llRetVal
      tcReason = "Failed to open session table."
    else
    	lcId = padr(m.tcId, len(UserToken))
    	locate for UserToken = m.lcId   && prev: AND inlist(TokenType, "LP ", "TC+", "PC+")
      llRetVal = found()
      if !m.llRetVal and this.lDailyTables
        llRetval = this.checkYesterday(m.tcId)
      endif 
      if !m.llRetVal
        tcReason = "ID not found in session table."
      else
      	llRetVal = inlist(TokenType, "LP ", "TC+", "PC+")
        if !m.llRetVal
          tcReason = "Incompatible token type for session: " + TokenType
        else
          llRetVal = this.VerifyMatch(@tcReason)
        endif
      endif
    endif 
    if m.llRetVal  && all succeeded
    	llRetVal = THIS.UpdateSession(@tcReason)
    endif 
    return m.llRetVal 
  endfunc  && FindLicensePlateSession
  * --------------------------------------------------------- *
  * called from FindLicensePlateSession() and maybe FindTokenSession() 
  function checkYesterday(tcId)  
    local llRet, loXfer
    if used("Yesterday")
      select Yesterday
      locate for UserToken = m.tcId 
      if found()
        scatter memo name loXfer
        insert into Today from name m.loXfer
        llRet = .t.
        replace Continued with .t. in Yesterday 
        goL7App.app_log(L7_SEVERITY_INFO, "User session continued from Yesterday")
      endif
      select Today
    endif 
    return m.llRet
  endfunc && checkYesterday
  * --------------------------------------------------------- *
  FUNCTION FindTokenSession(tcId, tcType, tcReason) && token to check (cookie or auth ID)
    IF VARTYPE( m.tcId) <> "C" OR EMPTY( m.tcId)
      tcReason = "Session ID not passed in."
      RETURN .F.
    ENDIF
    LOCAL llRetVal, lcId
    llRetVal = THIS.OpenTable() 
    if !m.llRetVal
      tcReason = "Failed to open session table."
    else
      lcId = PADR( UPPER( m.tcId ), LEN( UserToken) )
      LOCATE FOR UPPER( UserToken) = m.lcId
      llRetVal = found()
      if !m.llRetVal and this.lDailyTables
        llRetval = this.checkYesterday(m.tcId)
      endif 
      if !m.llRetVal
        tcReason = "ID not found in session table."
      else
        llRetVal = (TokenType = m.tcType)

        if !m.llRetVal
          tcReason = "Incompatible token type for session: " + TokenType
        else
          llRetVal = this.VerifyMatch(@tcReason)
        endif
      endif 
    endif 
    if m.llRetVal  && all succeeded
      llRetVal = THIS.UpdateSession(@tcReason)
    endif 
    return m.llRetVal 
  endfunc  && FindTokenSession
  * --------------------------------------------------------- *
  function VerifyMatch(tcReason)  && can override, but take care of reason by ref.
    if !alltrim(this.cClientCRC) == alltrim(ClientCRC)
      tcReason = textmerge([Client CRC (<<this.cClientCRC>>) does not match value stored in session (<<ClientCRC>>).])
      return .f.
    endif
    return .t. 
    * Note: CRC can vary in length.
  endfunc 
  * --------------------------------------------------------- *
  function AddLicensePlate
    local llRetVal, lnTry, lnTries
    lnTries = 25
    llRetVal = .f.
    for lnTry = 1 to m.lnTries
      if rlock()
        if empty(TokenType) 
          replace TokenType with "LP"
        else
          if TokenType <> "LP"
            replace TokenType with left(TokenType, 2) + "+"
          endif
        endif
        unlock
        llRetVal = .t.
      endif
    endfor
    if !m.llRetVal
      error "Could not add license plate to session record."
    endif
    return m.llRetVal
  endfunc
  * --------------------------------------------------------- *
  FUNCTION NewLicensePlateSession(lcLP, lcType)  
    * lcType can be TC+ or PC+ if a cookie also is being sent
    LOCAL llRetVal, ltTimeout, lnTries
    llRetVal = .T. 
    IF THIS.GetAvailableRecord()  && We have a locked record.
    	REPLACE ;
    		UserToken WITH m.lcLP ;
        TokenType WITH EVL(m.lcType, "LP "), ;
        ClientCRC WITH THIS.cClientCRC ;
    		IpAddress WITH THIS.cIpAddress ;
    		Hits WITH 1 ;
    		FirstHit WITH THIS.tNow ;
    		LastHit WITH THIS.tNow
    	UNLOCK
    ELSE
    	llRetVal = .F.
      error "No available record to create license plate."
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && NewLicensePlateSession
  * --------------------------------------------------------- *
  FUNCTION NewTokenSession(lcId, lcType)  && new token
    LOCAL llRetVal, ltTimeout, lnTries
    llRetVal = .T. 
    IF THIS.GetAvailableRecord()  && We have a locked record.
    	REPLACE ;
    		UserToken WITH m.lcId ;
        TokenType WITH m.lcType ;
        ClientCRC WITH THIS.cClientCRC ;
    		IpAddress WITH THIS.cIpAddress ;
    		Hits WITH 1 ;
    		FirstHit WITH THIS.tNow ;
    		LastHit WITH THIS.tNow
    	UNLOCK
    ELSE
    	llRetVal = .F.
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && NewTokenSession
  * --------------------------------------------------------- *
  FUNCTION FindUserSession(lcId)  && User ID to check
    IF VARTYPE( m.lcId) <> "C" OR EMPTY( m.lcId)
    	RETURN .F.
    ENDIF
    LOCAL llRetVal
    llRetVal = THIS.OpenTable()
    IF m.llRetVal
    	lcId = PADR( UPPER( m.lcId ), LEN( UserId ) )
      llRetVal = .F.  && will be turned back on in DO loop if match found
    	LOCATE FOR UPPER( UserId ) = m.lcId 
      DO WHILE FOUND()
        IF THIS.VerifyMatch()
          llRetVal = .T.
          EXIT
        ENDIF
        * Need to keep looking so that a user with two or more clients 
        * gets handled properly. (One session record per UA.)
        CONTINUE
      ENDDO
    ENDIF
    IF m.llRetVal
    	llRetVal = THIS.UpdateSession()
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && FindUserSession
  * --------------------------------------------------------- *
  FUNCTION NewUserSession(lcId) 
    LOCAL llRetVal, ltTimeout, lnTries
    llRetVal = .T. 
    IF THIS.GetAvailableRecord()  && We have a locked record.
    	REPLACE ;
    		UserId WITH m.lcId ;
        ClientCRC WITH THIS.cClientCRC ;
    		IpAddress WITH THIS.cIpAddress ;
    		Hits WITH 1 ;
    		FirstHit WITH THIS.tNow ;
    		LastHit WITH THIS.tNow
    	UNLOCK
    ELSE
    	llRetVal = .F.
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && NewUserSession
  * --------------------------------------------------------- *
  FUNCTION IsLoggedIn
    RETURN THIS.IsValidSession() AND LoggedIn
  ENDFUNC  && IsLoggedIn
  * --------------------------------------------------------- *
  function openDailyTable() && called on every hit, in theory
    local llRetVal, lcTable, lcPath
    llRetVal = .t.
    with this
      if isnull(.dToday) or ttod(.tNow) <> .dToday
        use in select("Today")
        use in select("Yesterday")
        .dToday = ttod(.tNow)
      endif
      if !used("Today")
        lcPath = .getDataPath(.dToday)
        *!* lcTable = .cTableName + "_" + dtos(.dToday)
        lcTable = .getTableName(.dToday)
        if !file(forceext(m.lcPath + m.lcTable, "DBF"))
          llRetVal = this.CreateTable(m.lcTable)
        endif 
        use (m.lcPath + m.lcTable) again alias Today in select("Today")
        *
        lcPath = .getDataPath(.dToday - 1) && these can differ on M1/D1 of a quarter
        *!* lcTable = .cTableName + "_" + dtos(.dToday - 1)
        lcTable = .getTableName(.dToday - 1)
        if file(forceext(m.lcPath + m.lcTable, "DBF"))
          use (m.lcPath + m.lcTable) again alias Yesterday in select("Yesterday")
        endif 
      endif
      select Today 
    endwith
    return m.llRetVal
  endfunc && openDailyTable
  * --------------------------------------------------------- *
  FUNCTION OpenTable
    if this.lDailyTables
      return this.openDailyTable()
    endif 
    local llRetVal, lcTable, lcPath
    llRetVal = .T.

    lcPath = this.getDataPath() && no date passed--no daily tables
    lcTable = this.getTableName()
    if !file(forceext(m.lcPath + m.lcTable, "DBF"))
    	llRetVal = this.CreateTable(m.lcTable)
    endif 
    use (m.lcTable) again 
    return  m.llRetVal
  endfunc  && OpenTable
  * --------------------------------------------------------- *
  FUNCTION ClearRecord
    * Clear a current record of any residue from its
    * earlier use. 
    BLANK
  ENDFUNC  && ClearRecord                  
  * --------------------------------------------------------- *
  function SetLoginStatus(tlIn)
    if rlock()
      if m.tlIn
        replace LoggedIn with .t., LoginTime with this.tNow
      else
        replace LoggedIn with .f., LogoutTime with this.tNow
      endif 
      unlock 
    else  
      error "Could not lock record to set session login status!"
    endif
    return 
  endfunc  && SetLoginStatus               
  * --------------------------------------------------------- *
  FUNCTION SetUserId(lcId)
    * Sets User ID property.
    lcId = UPPER( PADR( m.lcId, LEN( UserId)))
    *!*      IF UserId <> m.lcId
    *!*      	IF RLOCK()
    *!*      		REPLACE UserId WITH m.lcId
    *!*      		UNLOCK
    *!*        ELSE 
    *!*          ERROR "Could not lock record to set session user ID!"
    *!*      	ENDIF
    *!*      ENDIF
    if rlock()
      if UserId <> m.lcId
        replace UserId with m.lcId
      endif
      unlock 
    else  
      error "Could not lock record to set session user ID!"
    endif 
    return 
  endfunc   
  * --------------------------------------------------------- *
  function SetUserInfo(toUser)
    if rlock()
      replace Admin with m.toUser.isAdministrator() 
      unlock 
    else  
      error "Could not lock record to set session user ID!"
    endif 
    return 
  endfunc 
  * --------------------------------------------------------- *
  function GetToken
    IF this.IsValidSession()
      return UserToken
    else  && example: request log routinely asking Session, but user may not be ID'd (or have a session) yet
      return ""  && null is probably better, but client code may not be ready?
    endif 
  endfunc 
  * --------------------------------------------------------- *
  function GetUserId
    if this.IsValidSession()
      return trim( UserId)
    else
      return ""  
    endif 
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION SetLicensePlate(lcId)
    * Sets License property for an existing session, such as when
    * you want to combine a cookie and a license plate.
    lcId = PADR( m.lcId, LEN( UserToken))
    IF RLOCK()
      IF UserToken <> m.lcId
    		REPLACE UserToken WITH m.lcId
      endif 
    	unlock 
    else
      error "Could not lock record to set session license plate!"
    endif
    return 
  endfunc   
  * --------------------------------------------------------- *
  FUNCTION PushFormVars(lcVars)
    IF RLOCK()
    	IF NOT m.lcVars == FormVars
    		REPLACE FormVars WITH m.lcVars
    	ENDIF
    	UNLOCK
    else
      error "Could not lock record to push formvars!"
    endif
    return 
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION PopFormVars
    LOCAL lcRet
    IF RLOCK()
    	lcRet = FormVars
    	REPLACE FormVars WITH ""
    	UNLOCK
    ELSE
    	lcRet = FormVars
    ENDIF
    RETURN m.lcRet
  ENDFUNC  
  * --------------------------------------------------------- *
  function CreateTable(tcName) 
    local lcPath, lcName
    lcPath = this.getDataPath()
    lcName = iif(empty(m.tcName), this.getTableName(), m.tcName)
    create table (m.lcPath + m.lcName) ;
    	free ;
    	( ;
    		UserToken C(32), ; && misnomer, is the Session ID, often license plate or cookie
        TokenType C(3), ;
    		UserId C(20), ;
    		IpAddress C(15), ;
        ClientCRC C(10), ;
    		Hits I, ;
    		LastHit T, ;
    		FirstHit T, ;
    		LoggedIn L, ;
        LoginTime T, ;
        LogoutTime T, ;
        Expired L, ;
        ExpiryTime T, ;
        Continued L, ;
        Admin L, ;
    		CookieFlag L, ;
    		AuthHitNo I, ;
    		AuthAs C(20), ;
        UserAgent M, ;  && added 6/29/2010
    		SessVars M, ;
    		FormVars M, ;
        ObjectVars M, ;
        FileNames M, ;
    		Prefs M ;
    	)
    * NOTE: Free table, so no long field names!
    INDEX ON UPPER( UserToken) TAG UserToken
    INDEX ON TokenType TAG TokenType
    INDEX ON UPPER( UserId) TAG UserId
    INDEX ON DELETED() TAG Deleted
    use
    return 
  endfunc  && CreateTable
  * --------------------------------------------------------- *
  function ExpireSession(tcToken, tdDate, tcMsg) 
    local lnSelect, lcPath, llRet, lcFrom, loExc
    lnSelect = select()
    lcPath = this.getDataPath()
    try 
      lcFrom = forceext(m.lcPath + THIS.getTableName(m.tdDate), "DBF")

      if !file(m.lcFrom)
        error "No session file " + m.lcFrom
      endif
      use (m.lcFrom) again alias ExpireSession_ in select("ExpireSession_")
      select ExpireSession_
      locate for UserToken == m.tcToken
      if !found()
        error "Token not found " + m.tcToken
      endif
      if !rlock()
        error "Could not lock session record"
      endif
      if Expired
        error "Already expired"
      endif
      replace Expired with .t., ExpiryTime with datetime()
      unlock
      llRet = .t.
      
    catch to loExc when loExc.ErrorNo = 1098  && user-generated error
      tcMsg = loExc.Message 
    catch to loExc
      tcMsg = loExc.Message 
    finally
      use in select("ExpireSession_")
    endtry 
    select (m.lnSelect)
    return m.llRet
  endfunc 
  * --------------------------------------------------------- *
  function GetActiveSessions(tcMoreWhere, tdDate, tcAltFlds, tlInactive) 
    * tcMoreWhere : add to active criteria
    * tdDate      : option to use a different day's sessions
    * tcAltFlds   :
    * tlInactive  : .f. = active only DEFAULT; .t. = inactive only; NULL = ALL
    local lnSelect, lcSql, lcRet, loExc, lcWhere, lcFrom, lcPath, lcFlds
    lcFlds = evl(m.tcAltFlds, [UserToken, TokenType, UserId, IpAddress, ClientCRC] + ;
        [, Hits, LastHit, FirstHit, LoggedIn, CookieFlag])
    lnSelect = SELECT()
    lcPath = this.getDataPath()
    TRY
      lcFrom = FORCEEXT(m.lcPath + THIS.getTableName(m.tdDate), "DBF")

      if !file(m.lcFrom)
        error "No session file " + m.lcFrom
      endif 
      lcSql = [SELECT] + ;
        [ ] + m.lcFlds + [ FROM "] + m.lcFrom + ["]
      
      lcWhere = ""
      * Active/inactive filter:
      if !isnull(m.tlInactive)
        lcWhere = m.lcWhere + [ AND ] + iif(m.tlInactive, [!], []) + [(] + this.getActiveClause() + [)]
      endif
      *!* lcWhere = m.lcWhere + [ AND LastHit + ] + TRANSFORM(THIS.nTimeout) + [ > {] + TTOC(DATETIME()) + [}]
      if !empty(m.tcMoreWhere)
        lcWhere = m.lcWhere + [ AND (] + m.tcMoreWhere + [)]
      endif 
      if !empty(m.lcWhere)
        lcSql = lcSql + [ WHERE ] + SUBSTR(m.lcWhere, LEN(" AND ") + 1)
      endif 
      lcSql = lcSql + [ ORDER BY LastHit DESC INTO CURSOR Active_Sessions_]
      &lcSql
      lcRet = ""
      CURSORTOXML("Active_Sessions_", "lcRet", 1, 0, 0, "1")
      
    CATCH TO loExc WHEN loExc.ErrorNo = 1098  && user-generated error
      lcRet = loExc.Message 
    CATCH TO loExc
      lcRet = loExc.Message + [ (SQL: ] + m.lcSql + [)]
    FINALLY
      USE IN SELECT("Active_Sessions_")
    ENDTRY
    select ( m.lnSelect)
    return m.lcRet
  endfunc   && GetActiveSessions
  * --------------------------------------------------------- *
  function getActiveClause() && can subclass
    return [empty(LogoutTime) and !Expired and LastHit + ] + TRANSFORM(THIS.nTimeout) + [ > {] + TTOC(DATETIME()) + [}]
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION GetSessionVar(lcVarName)
    IF NOT THIS.IsValidSession()
      RETURN ""
    ENDIF
    LOCAL lcVar
    lcVar = Extract( SessVars, ;
    	'<' + m.lcVarName + '>', ;
    	'</' + m.lcVarName + '>', ;
    	, .F. )
    RETURN m.lcVar
  ENDFUNC  && GetSessionVar
  * --------------------------------------------------------- *
  FUNCTION SetSessionVar(lcVarName, lvValue)
    IF NOT THIS.IsValidSession()
      RETURN .F.
    ENDIF
    LOCAL lcOld, lcNew, llChanged, lcOldXml, lcNewXml, lnSize, ;
    	lnTries, lnTry, llRetVal
    lnTries = 10
    llRetVal = .T.
    llChanged = .T.
    lcOldXml = TRIM( SessVars )
    lcOld = THIS.GetSessionVar( m.lcVarName )
    IF VARTYPE( m.lvValue) <> "C"
    	lvValue = TRANSFORM( m.lvValue)
    ENDIF
    lcNew = '<' + m.lcVarName + '>' + m.lvValue + ;
    	'</' + m.lcVarName + '>' 
    DO CASE
    CASE m.lcOld == m.lvValue
    	* Do nothing, since setting is unchanged.
    	llChanged = .F.
    CASE EMPTY( m.lcOld)  && no previous setting
    	lcNewXml = m.lcNew + TRIM( SessVars )
    CASE EMPTY( m.lvValue)
    	* New value is empty--clear the setting entirely.
    	lcNewXml = STRTRAN( TRIM( SessVars), ;
    		'<' + m.lcVarName + '>' + m.lcOld + '</' + m.lcVarName + '>', ;
    		"" )
    OTHERWISE  && change of value
    	lcNewXml = STRTRAN( TRIM( SessVars), ;
    		'<' + m.lcVarName + '>' + m.lcOld + '</' + m.lcVarName + '>', ;
    		m.lcNew )
    ENDCASE
    IF m.llChanged
      llRetVal = THIS.SaveTextField("SessVars", @lcNewXml)
      *!*      	llRetVal = .F.
      *!*      	FOR lnTry = 1 TO m.lnTries
      *!*      		IF RLOCK()
      *!*      			llRetVal = .T.
      *!*      			* Reduce memo bloat by pre-allocating in blocks of 512 bytes:
      *!*      			lnSize = MAX( LEN( m.lcNewXml), LEN( SessVars) )
      *!*      			lnSize = 512 * CEILING( m.lnSize / 512 )
      *!*      			REPLACE SessVars WITH PADR( m.lcNewXml, m.lnSize )
      *!*      			UNLOCK
      *!*      			EXIT
      *!*      		ENDIF
      *!*      	ENDFOR
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && SetSessionVar
  * --------------------------------------------------------- *
  FUNCTION SaveTextField(lcFieldName AS String, lcValue AS String) AS Boolean
    LOCAL llRetVal, lnTry, lnSize
    llRetVal = .F.
    FOR lnTry = 1 TO 10
      IF RLOCK()
        llRetVal = .T.
        * Reduce memo bloat by pre-allocating in blocks of 512 bytes:
        lnSize = MAX( LEN( m.lcValue), LEN( &lcFieldName) )
        lnSize = 512 * CEILING( m.lnSize / 512 )
        REPLACE (m.lcFieldName) WITH PADR( m.lcValue, m.lnSize )
        UNLOCK
        EXIT
      ENDIF
    ENDFOR
    RETURN m.llRetVal
  ENDFUNC  && SaveTextField
  * --------------------------------------------------------- *
  FUNCTION SetObject(lcObjName AS String, loObj AS Object) AS Boolean
    IF NOT THIS.IsValidSession()
      RETURN .F.
    ENDIF
    LOCAL loXml, lcXML, lcNewAll, lcOldXml, lcName, ;
      llRetVal, llChanged, lnAt, lnTry, lnTries
    lcName = THIS.cMagicXmlPrefix + m.lcObjName
    llRetVal = .T.
    IF VARTYPE(m.loObj) = "O"
      loXml = CREATEOBJECT("wwXML")
      lcXML = loXml.CreateObjectXml(loObj, m.lcName, 0)
    ELSE
      lcXML = ""
    ENDIF
    lcOldXML = STREXTRACT(ObjectVars, '<' + m.lcName + '>', '</' + m.lcName + '>', 1, 0)
    IF NOT EMPTY(m.lcOldXml)
      lcOldXml = '<' + m.lcName + '>' + m.lcOldXml + '</' + m.lcName + '>'
      lnAt = AT("<" + m.lcName + ">", ObjectVars)
    ENDIF
    IF m.lcXml == m.lcOldXml
      llChanged = .F.
    ELSE
      llChanged = .T.
      IF EMPTY(m.lcOldXml)
        * Not saved before: just add to end.
        lcNewAll = ObjectVars + m.lcXml
      ELSE
        * Exists before: either strip or replace.
        lcNewAll = STUFF(ObjectVars, m.lnAt, LEN(m.lcOldXml), m.lcXML)
      ENDIF
    ENDIF
    IF m.llChanged
      llRetVal = THIS.SaveTextField("ObjectVars", @lcNewAll)
    ENDIF
    RETURN m.llRetVal
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetObject(lcObjName AS String, loObj AS Object) AS Boolean
    * Returns .F. if not found.
    * Pass in object with structure to have props populated.
    IF NOT THIS.IsValidSession()
      RETURN .F.
    ENDIF
    LOCAL lcXML, llResult
    lcXML = STREXTRACT(ObjectVars, ;
      '<' + THIS.cMagicXmlPrefix + m.lcObjName + '>', ;
      '</' + THIS.cMagicXmlPrefix + m.lcObjName + '>', ;
      1, 0)
    IF EMPTY( m.lcXML)
      llResult = .F.
    ELSE
      ** TRY
        LOCAL loXml
        loXml = CREATEOBJECT("wwXML")
        lcXML = "<xdoc>" + m.lcXML + "</xdoc>"
        loXml.XmlToObject(m.lcXML, loObj)
      ** CATCH
        ** llResult = .F.
        * TO DO: Inform of error, how?
      ** ENDTRY
    ENDIF
    RETURN m.llResult
  ENDFUNC  && GetObject
  * --------------------------------------------------------- *
  FUNCTION GetDebugInfo
    ** RETURN L7ShowObject(THIS, "Session Object")
    LOCAL lcTxt, ii, lcFld, lcVal
    lcTxt = ""
    IF NOT EMPTY(ALIAS())
      lcTxt = m.lcTxt + [<table border=1 class="DebugInfo">] + CR + ;
        [<caption>Session Data</caption>] + CR
      FOR ii = 1 TO FCOUNT()
        lcFld = FIELD(m.ii)
        lcVal = TRANSFORM(EVALUATE(m.lcFld))
        IF "<" $ m.lcVal
          lcVal = [<pre>] + FixHTMLForDisplay(m.lcVal) + [</pre>]
        ENDIF
        lcTxt = m.lcTxt + [<tr valign="top"><th align="right">] + TRANSFORM(m.lcFld) + ;
          [:</th>] + CR + [<td>] + m.lcVal + [</td></tr>] + CR
      ENDFOR
      lcTxt = m.lcTxt + [</table>] + CR
    ELSE 
      lcTxt = [<div class="DebugInfo"><h2>Session: No table is open.</h2>] + ;
        L7ShowObject(THIS, "Session Object") + ;
        [</div>]
    ENDIF
    RETURN m.lcTxt
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE  && L7Session
*** ========================================================= ***

#if .f.
12/24/2002 - Changed UserToken field to 32 chars to support GUID session IDs.
04/23/2003 - Removed lError and cErrorMessage properties.
           - Added cClientCRC as principle license plate verifier.
           - Revised GetDebugInfo() to show session record (vs. this object) info.
           - Added SetObject and GetObject.
09/05/2003 - added INIT with call to StandardVfpSettings().
           - revised GetDebugInfo to reveal object info if session info unavailable
           - revised OpenTable to facilitate debugging
           - added "AGAIN" to USE in OpenTable
10/23/2003 - fixed VerifyMatch() to deal with variable-length CRC.
12/09/2003 - fixed FindUserSession to deal with multiple browsers per user.
08/25/2005 - removed spurious UNLOCK statement from SetSessionVar.
03/13/2006 - SET MULTILOCKS OFF     

#endif
* End: L7Session.PRG
