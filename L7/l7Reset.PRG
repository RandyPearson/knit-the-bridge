* L7Reset.PRG

#INCLUDE L7.H

*** ========================================================= ***
define class L7ResetLog AS SESSION

  cErrorMsg = ""
  cLogFile = ""
  cLogAlias = "" && see ACCESS method
  cPreviousLogAlias = ""
  cLogFilePath = ".\" && see ACCESS method, also often assigned by Application
  cLogFilePrefix = "L7ResetLog" 
  lDailyLogs = .T.
  lQuarterlyFolders = .T. && separates logs into different subfolders by quarter, eg: ..\LogFiles\2006-Q1\
  lCloseLog = .F.

  cStructureBase = [PK C(32), CreateTime T, CreateType C(10), App C(10), ExpireTime T, CloseTime T, Consumed L, Success L, Reason C(32), Removed L]

  cStructureAugment = [UserToken C(32)] && easier override

  * --------------------------------------------------------- *
  function cLogAlias_ACCESS
    return this.GetLogAlias(date())
  endfunc 
  * --------------------------------------------------------- *
  function GetLogAlias(tdDate)
    local ldDate
    ldDate = EVL(m.tdDate, DATE()) && default to today
    return this.cLogFilePrefix + ;
      iif(THIS.lDailyLogs, [_] + dtos(m.ldDate), [])
    * e.g., "L7ResetLog_20020301" on 03/01/2002.
  endfunc 
  * --------------------------------------------------------- *
  function cPreviousLogAlias_ACCESS
    return this.cLogFilePrefix + ;
      iif(this.lDailyLogs, [_] + dtos(date() - 1), [])
  endfunc 
  * --------------------------------------------------------- *

*[[ DRY w/ L7LogRequest and L7AuthLog--inherit from a new base?

  function GetLogFilePath(tdDate)
    local lcPath, ldDate
    ldDate = evl(m.tdDate, date())  && default to today
    lcPath = iif( empty( this.cLogFilePath), [.\], addbs(this.cLogFilePath))
    if this.lQuarterlyFolders 
      * "Yes", this seems rather specific for a framework, but as quarterly
      * is a good minimum forensic retention period, a default that facilitates
      * quarterly log maintenance is worthwhile.
      lcPath = addbs(m.lcPath + ;
        str(year(m.ldDate), 4, 0) + "-Q" + str(ceiling(month(m.ldDate) / 3), 1, 0))
      * e.g., path.../2006-Q1/
    endif 
    return m.lcPath
  endfunc && GetLogFilePath
  * --------------------------------------------------------- *
  function DESTROY 
    this.CloseLog()
  endfunc 
  * --------------------------------------------------------- *
  function INIT(lcBaseName)
    do StandardVfpSettings  && 9/1/09, required for new private datasession
    if !empty(m.lcBaseName)
      this.cLogFilePrefix = m.lcBaseName
    endif 
  endfunc 
  * --------------------------------------------------------- *
  function getEntryByPK(tcKey) && returns entry or NULL
    local lnSelect, lvRet
    lvRet = null
    lnSelect = select()
    if this.OpenLog()
      select (this.cLogAlias)
      locate for PK = m.tcKey
      if found()
        scatter memo name lvRet
      endif
    endif 
    select (m.lnSelect)
    return m.lvRet
  endfunc  && getEntryForUser
  * --------------------------------------------------------- *
  function getEntryForUser(tcUser) && returns entry or NULL
    local lnSelect, lvRet
    lvRet = null
    lnSelect = select()
    if this.OpenLog()
      select (this.cLogAlias)
      locate for UserToken = m.tcUser and ExpireTime > datetime() and !Consumed and !Removed
      if found()
        scatter memo name lvRet
      endif
    endif 
    select (m.lnSelect)
    return m.lvRet
  endfunc  && getEntryForUser
  * --------------------------------------------------------- *
  function isValid(toRec) 
    return toRec.ExpireTime > datetime() and !toRec.Consumed and !toRec.Removed
  endfunc 
  * --------------------------------------------------------- *
  function updateEntry(toRec) 
    local lnSelect, lvRet
    lvRet = null
    lnSelect = select()
    if this.OpenLog()
      select (this.cLogAlias)
      locate for PK = toRec.PK
      if found()
        gather memo name toRec
      endif
    endif 
    select (m.lnSelect)
    return m.lvRet
  endfunc  && updateEntry
  * --------------------------------------------------------- *
  function createEntryForUser(tcUser) 
    local lnSelect, loRet, loCheck
    loRet = createobject('empty')
    addproperty(loRet, 'success', .f.)
    addproperty(loRet, 'reason', 'none')
    lnSelect = select()
    loCheck = this.getEntryForUser(m.tcUser)
    if !isnull(m.loCheck)
      loRet.reason = 'An open request for that user already exists.'
    else
      if this.OpenLog()
        select (this.cLogAlias)
        scatter memo blank name loNewRec
        with m.loNewRec
          .PK = GetGUIDString(32)
          .UserToken = m.tcUser
          .CreateTime = datetime()
          .ExpireTime = .CreateTime + 60 * 60 && an hour--app can change
          .app = goL7App.cApplication 
        endwith
        addproperty(loRet, 'payload', m.loNewRec)
        insert into (this.cLogAlias) from name m.loNewRec
        loRet.success = .t.
      else 
        loRet.reason = 'Could not open reset log.'
      endif
    endif 
    select (m.lnSelect)
    return m.loRet
  endfunc 
    * --------------------------------------------------------- *
  function OpenLog
    local lcAlias, llRet, lcPath
    llRet = .T.
    lcAlias = THIS.GetLogAlias()
    if !used(m.lcAlias)
      * cLogFileAlias is created from an ACCESS method, so that
      * daily log files are easily handled.
      this.ClosePreviousLog()
      lcPath = this.GetLogFilePath()
      if !file( addbs(m.lcPath) + m.lcAlias + ".dbf")
        llRet = this.CreateLog()
      endif 
      if m.llRet
        use (addbs(m.lcPath) + m.lcAlias + ".dbf") again shared in 0
      endif 
    endif 
    return m.llRet
  endfunc  && OpenLog
  * --------------------------------------------------------- *
  function CreateLog
    local lnSelect, lcFile, lcStru, llRet, loExc
    lnSelect = select()
    try
      lcStru = THIS.GetStructure()
      lcFile = THIS.GetLogFileName()
      select 0
      create table (m.lcFile) free (&lcStru)
      use
      llRet = .T.
    catch TO loExc
      llRet = .F.
      this.cErrorMsg = "CreateLog: " + loExc.Message
    finally
      select (m.lnSelect)
    endtry
    RETURN m.llRet
  endfunc  && CreateLog
  * --------------------------------------------------------- *
  function GetStructure
    local lcStru
    lcStru = this.cStructureBase
    if !empty(this.cStructureAugment)
      lcStru = this.cStructureAugment + [,] + m.lcStru
    endif 
    return m.lcStru
  endfunc 
  * --------------------------------------------------------- *
  function GetLogFileName
    local lcRet
    lcRet = this.GetLogFilePath()
    if !directory(m.lcRet)
      mkdir (m.lcRet)
    endif 
    lcRet = addbs(m.lcRet) + forceext(this.cLogAlias, ".dbf")
    return m.lcRet
  endfunc 
  * --------------------------------------------------------- *
  function CloseLog
    use in select( this.cLogAlias)
  endfunc 
  * --------------------------------------------------------- *
  function OptionalCloseLog
    if this.lCloseLog
      this.CloseLog()
    endif 
    return  
  endfunc 
  * --------------------------------------------------------- *
  function ClosePreviousLog
    if this.lDailyLogs
      use in select( this.cPreviousLogAlias)
    endif 
    return  
  endfunc 
  * --------------------------------------------------------- *
enddefine && L7ResetLog

*end: L7Reset.PRG

