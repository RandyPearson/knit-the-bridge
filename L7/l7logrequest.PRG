* L7LogRequest.PRG

#INCLUDE L7.H

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


*** ========================================================= ***
DEFINE CLASS L7LogRequest AS SESSION
  cErrorMsg = ""
  cLogFile = ""
  cLogAlias = "" && see ACCESS method
  cPreviousLogAlias = ""
  cLogFilePath = ".\" && see ACCESS method, also often assigned by Application
  cLogFilePrefix = "L7RequestLog"
  lDailyLogs = .T.
  lQuarterlyFolders = .T. && separates logs into different subfolders by quarter, eg: ..\LogFiles\2006-Q1\
  lCloseLog = .F.
  * 05/15/2010: inserted UserToken C(32) to allow link to Session table.
  cStructureBase = [UserToken C(32), CRC C(10), IpAddress C(15), Time T, ClassName C(24), AuthUser C(12), RecordId I, ] + ;
    [HttpMethod C(4), Tally N( 8), Duration N( 6, 2), ProcessId I, MemUsage I, ErrorFlag L, HackFlag L, ComFlag L, ] + ;
    [DebugInfo M, URL M, BackURL M, Browser M, DbVersion I ]
  cStructureAugment = [User_PK I, User_ID C(14)] && easier override
  * --------------------------------------------------------- *
  FUNCTION cLogAlias_ACCESS
    RETURN THIS.GetLogAlias(DATE())
    * e.g., "L7RequestLog_20020301" on 03/01/2002.
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetLogAlias(ldDate)
  	ldDate = EVL(m.ldDate, DATE()) && default to today
    RETURN THIS.cLogFilePrefix + ;
      IIF( THIS.lDailyLogs, [_] + DTOS(m.ldDate), [])
    * e.g., "L7RequestLog_20020301" on 03/01/2002.
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cPreviousLogAlias_ACCESS
    RETURN THIS.cLogFilePrefix + ;
      IIF( THIS.lDailyLogs, [_] + DTOS( DATE() - 1), [])
  ENDFUNC
*!*    * --------------------------------------------------------- *
*!*    FUNCTION cLogFilePath_ACCESS
*!*    	RETURN THIS.GetLogFilePath(DATE())
*!*    ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetLogFilePath(ldDate)
    LOCAL lcPath
    ldDate = EVL(m.ldDate, DATE())  && default to today
    lcPath = IIF( EMPTY( THIS.cLogFilePath), [.\], ADDBS( THIS.cLogFilePath))
    IF THIS.lQuarterlyFolders 
      * "Yes", this seems rather specific for a framework, but as quarterly
      * is a good minimum forensic retention period, a default that facilitates
      * quarterly log maintenance is worthwhile.
      lcPath = ADDBS(m.lcPath + ;
        STR(YEAR(m.ldDate), 4, 0) + "-Q" + STR(CEILING(MONTH(m.ldDate) / 3), 1, 0))
      * e.g., path.../2006-Q1/
    ENDIF
    RETURN m.lcPath
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    THIS.CloseLog()
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION INIT(lcBaseName)
    DO StandardVfpSettings  && 9/1/09, required for new private datasession
    IF NOT EMPTY(m.lcBaseName)
      THIS.cLogFilePrefix = m.lcBaseName
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetRecentHits(lnHits, lnSeconds, lcFlds, lcMoreWhere, ldDate, llAscending)
    LOCAL lnSelect, lcSql, lcRet, loExc, lcFlds, lcWhere, lcFrom
    ldDate = EVL(m.ldDate, DATE())
    lcFlds = EVL(m.lcFlds, ;
      [UserToken, CRC, IpAddress, Time, AuthUser, HttpMethod, Duration, MemUsage, ErrorFlag, HackFlag, ComFlag, URL, BackURL, Browser])
    lnSelect = SELECT()
    TRY
      ** IF NOT THIS.OpenLog()
      **   ERROR "Could not open log file."
      ** ENDIF
      lcFrom = ADDBS(THIS.GetLogFilePath(m.ldDate)) + THIS.GetLogAlias(m.ldDate)
      IF NOT FILE(FORCEEXT(m.lcFrom, "DBF"))
        ERROR "No log file for " + TRANSFORM(m.ldDate)
      ENDIF
      lcSql = [SELECT] + ;
        IIF(NOT EMPTY(m.lnHits), [ TOP ] + TRANSFORM(m.lnHits), []) + ;
        [ ] + m.lcFlds + [ FROM "] + m.lcFrom + ["]
      
      lcWhere = ""
      IF NOT EMPTY(m.lnSeconds)
        lcWhere = m.lcWhere + [ AND {] + TTOC(DATETIME()) + [}] + [ - Time <=] + TRANSFORM(m.lcSeconds)
      ENDIF
      IF NOT EMPTY(m.lcMoreWhere)
        lcWhere = m.lcWhere + [ AND (] + m.lcMoreWhere + [)]
      ENDIF
      IF NOT EMPTY(m.lcWhere)
        lcSql = lcSql + [ WHERE ] + SUBSTR(m.lcWhere, LEN(" AND ") + 1)
      ENDIF
      lcSql = lcSql + [ ORDER BY Time] + IIF(m.llAscending, [], [ DESC]) + [ INTO CURSOR Recent_Hits_]
      &lcSql
      
      lcRet = ""
      CURSORTOXML("Recent_Hits_", "lcRet", 1, 0, 0, "1")
      
    catch to loExc when loexc.ErrorNo = 1806 and loExc.details = "USERTOKEN"
      lcRet = "Error processing query. Log table did not have a UserToken field."
    CATCH TO loExc WHEN loExc.ErrorNo = 1098  && user-generated error
      lcRet = loExc.Message 
    CATCH TO loExc
      lcRet = loExc.Message + [ (SQL: ] + m.lcSql + [)]
    FINALLY
      USE IN SELECT("Recent_Hits_")
    ENDTRY
    ** THIS.OptionalCloseLog()
    SELECT ( m.lnSelect)
    RETURN m.lcRet
  ENDFUNC  && GetRecentHits
  * --------------------------------------------------------- *
  FUNCTION Log  && Template Method
    LOCAL lnSelect, llRet
    lnSelect = SELECT()
    IF THIS.OpenLog()
      THIS.AddRequest()
      THIS.AfterAddRequest()  && hook
      THIS.OptionalCloseLog()
      llRet = .T.
    ENDIF
    SELECT ( m.lnSelect)
    RETURN m.llRet
  ENDFUNC  && Log
  * --------------------------------------------------------- *
  FUNCTION AddRequest
    LOCAL lnSelect, llIsPage, loNewRec
    llIsPage = VARTYPE( m.Page) = "O"
    lnSelect = SELECT()
    SELECT ( THIS.cLogAlias)
    SCATTER MEMO blank NAME loNewRec
    WITH loNewRec
      IF m.llIsPage
        .Time = Page.tNow 
        .Duration = MOD(SECONDS() - Page.nStartSeconds, 86400) && Duration WITH DATETIME() - Page.tNow  
        .ClassName = Page.Class
      ELSE
        .Time = DATETIME() 
        .Duration = -1 
        .ClassName = goL7App.cActivePage
      ENDIF
      ** moved down: THIS.AddAugmentedData(m.loNewRec)
      IF VARTYPE( m.Request) = "O"
        .CRC = goL7App.getClientCRC()  && Request.cClientCRC 
        .IpAddress = Request.cIpAddress 
        .HttpMethod = Request.cMethod 
        .AuthUser = Request.cAuthenticatedUser 
        .URL = Request.cCurrentUrl 
        .BackURL = Request.cPreviousURL 
        .Browser = Request.cBrowser
      endif
      * 05/15/2010, added Session.UserToken insertion in request log:
      if pemstatus(loNewRec, "UserToken", 5) and vartype(m.Session) = "O"
        .UserToken = Session.GetToken()
      endif 
      IF goL7App.lError
        .ErrorFlag = .T. 
        .DebugInfo = .DebugInfo + goL7App.cErrorMessage
      ENDIF
      IF goL7App.lHack
        .HackFlag = .T. 
        .DebugInfo = .DebugInfo + goL7App.cHackInfo
      ENDIF
      IF TYPE("MemUsage") $ "IN"
        .MemUsage = VAL(SYS(1016))
      ENDIF
      IF TYPE("ProcessId") $ "IN"
        .ProcessId = _vfp.ProcessId  && added 01/11/2013 
      ENDIF
    ENDWITH 
    * Do this override hook last, so augmentation can alter default params: 
    THIS.AddAugmentedData(m.loNewRec)
    
    INSERT INTO ( THIS.cLogAlias) FROM NAME m.loNewRec
    SELECT(m.lnSelect) 
    RETURN
  ENDFUNC  && AddRequest
  * --------------------------------------------------------- *
  FUNCTION AddAugmentedData(toRec)
    IF VARTYPE( CurrentUser) = "O"
      toRec.User_PK = CurrentUser.GetUserKey()
      toRec.User_ID = CurrentUser.GetUserID()
    ENDIF
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AfterAddRequest
  * --------------------------------------------------------- *

* 07/29/2011, add trap for Error 2091:
* "Either the table record count does not match the actual records in the table, 
* or the file size on the disk does not match the expected file size from the table header. 
* Repair the table using an appropriate third-party repair utility for Visual FoxPro tables before opening the table again."

  function OpenLog
    local lcAlias, llRet, lcPath, lcDir, loExc, loExc2, lcRand
    llRet = .T.
    lcAlias = THIS.GetLogAlias()
    if !used( m.lcAlias)
      * cLogFileAlias is created from an ACCESS method, so that
      * daily log files are easily handled.
      this.ClosePreviousLog()
      lcDir = THIS.GetLogFilePath()
      lcPath = addbs(m.lcDir) + m.lcAlias + ".dbf"
      if !file(m.lcPath)
        llRet = this.CreateLog()
      endif 
      if m.llRet
        try
          ** use (m.lcPath) again shared in 0
          this.openLogFile(m.lcPath)
        catch to loExc when loExc.errorNo = 2091
          try
            goL7App.app_log(L7_SEVERITY_ERROR, "Log file corrupt. Rename and re-create attemted " + m.lcPath)
            lcRand = sys(3)
            rename (m.lcPath) to (m.lcPath + "." + m.lcRand)
            rename (forceext(m.lcPath, "fpt")) to (forceext(m.lcPath, "fpt") + "." + m.lcRand)
            goL7App.app_log(L7_SEVERITY_INFO, "Corrupt files renamed with extension: ." + m.lcRand)
          catch to loExc2
            goL7App.app_log(L7_SEVERITY_WARNING, "Rename error: " + loExc2.message)
          endtry
          llRet = this.CreateLog()
          if m.llRet
            try 
              this.openLogFile(m.lcPath)
            catch to loExc2
              llRet = .f. 
              goL7App.app_log(L7_SEVERITY_INFO, "Open log error: " + loExc2.message)
            endtry
          endif
        catch to loExc
          llRet = .f.
        endtry 
      endif 
    endif 
    return m.llRet
  endfunc  && OpenLog
  * --------------------------------------------------------- *
  protected function OpenLogFile(tcPath)
    use (m.tcPath) again shared in 0
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION CreateLog
    LOCAL lnSelect, lcFile, lcStru, llRet, loExc
    lnSelect = SELECT()
    TRY
      lcStru = THIS.GetStructure()
      lcFile = THIS.GetLogFileName()
      SELECT 0
      CREATE TABLE ( m.lcFile ) FREE ( &lcStru )
      USE
      llRet = .T.
      goL7App.app_log(L7_SEVERITY_INFO, "Log file created: " + m.lcFile)
    CATCH TO loExc
      llRet = .F.
      THIS.cErrorMsg = "CreateLog: " + loExc.Message
      goL7App.app_log(L7_SEVERITY_INFO, "Create log error: " + loExc.message)
    FINALLY
      SELECT ( m.lnSelect)
    ENDTRY
    RETURN m.llRet
  ENDFUNC  && CreateLog
  * --------------------------------------------------------- *
  FUNCTION GetStructure
    LOCAL lcStru
    lcStru = THIS.cStructureBase
    IF NOT EMPTY(THIS.cStructureAugment)
      lcStru = THIS.cStructureAugment + [,] + m.lcStru
    ENDIF
    RETURN m.lcStru
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetLogFileName
    LOCAL lcRet
    lcRet = THIS.GetLogFilePath()
    IF NOT DIRECTORY(m.lcRet)
      MKDIR (m.lcRet)
    ENDIF
    lcRet = ADDBS(m.lcRet) + FORCEEXT(THIS.cLogAlias, ".dbf")
    RETURN m.lcRet
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION CloseLog
    USE IN SELECT( THIS.cLogAlias)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION OptionalCloseLog
    IF THIS.lCloseLog
      THIS.CloseLog()
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ClosePreviousLog
    IF THIS.lDailyLogs
      USE IN SELECT( THIS.cPreviousLogAlias)
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *

ENDDEFINE && L7LogRequest

*** ========================================================= ***
#if .f.
03/04/2006 - added default quarterly log folders
06/25/2009 - switched code to INSERT INTO to avoid record in use conflicts (w/ append blank)
#endif
