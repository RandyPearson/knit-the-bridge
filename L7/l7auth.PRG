* L7Auth.PRG

#INCLUDE L7.H

*** ========================================================= ***
define class L7AuthLog AS SESSION



  cErrorMsg = ""
  cLogFile = ""
  cLogAlias = "" && see ACCESS method
  cPreviousLogAlias = ""
  cLogFilePath = ".\" && see ACCESS method, also often assigned by Application
  cLogFilePrefix = "L7AuthLog" 
  lDailyLogs = .T.
  lQuarterlyFolders = .T. && separates logs into different subfolders by quarter, eg: ..\LogFiles\2006-Q1\
  lCloseLog = .F.



  * 05/15/2010: inserted UserToken C(32) to allow link to Session table.
  cStructureBase = [Time T, App C(10), ClassName C(32), Lockout L, IpAddress C(15), User_ID C(20), Success L, Reason C(32), Removed L]

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
    * e.g., "L7AuthLog_20020301" on 03/01/2002.
  endfunc 
  * --------------------------------------------------------- *
  function cPreviousLogAlias_ACCESS
    return this.cLogFilePrefix + ;
      iif(this.lDailyLogs, [_] + dtos(date() - 1), [])
  endfunc 
  * --------------------------------------------------------- *

*[[ DRY w/ L7LogRequest--inherit from a new base?

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
  function Log(toAuth)  && Template Method
    local lnSelect, llRet
    lnSelect = select()
    if this.OpenLog()
      this.AddEntry(m.toAuth)
      this.AfterAddEntry(m.toAuth)  && hook
      this.OptionalCloseLog()
      llRet = .T.
    endif 
    select (m.lnSelect)
    return m.llRet
  endfunc  && Log
  * --------------------------------------------------------- *
  function AddEntry(toAuth)
    LOCAL lnSelect, llIsRequest, llIsPage, loNewRec
    llIsPage = VARTYPE( m.Page) = "O"
    llIsRequest = VARTYPE( m.Request) = "O"
    
    lnSelect = SELECT()
    select (this.cLogAlias)
    scatter memo blank name loNewRec
    with m.loNewRec
      .className = upper(toAuth.class)
      .lockout = toAuth.lLockoutTrigger
      .success = toAuth.lSuccess
      .app = goL7App.cApplication 
      if !isnull(toAuth.cUser_Id)
        .User_id = upper(toAuth.cUser_Id)
      endif 
      if m.llIsPage
        .Time = Page.tNow 
      else 
        .Time = DATETIME() 
      endif 
      if m.llIsRequest
        .IpAddress = Request.cIpAddress 
      endif 

      this.AddAugmentedData(m.loNewRec, m.toAuth)
    endwith 
      
    insert into (this.cLogAlias) from name m.loNewRec
    select (m.lnSelect)
    return 
  endfunc  && AddEntry
  * --------------------------------------------------------- *
  function AddAugmentedData(toRec, toAuth)
  endfunc 
  * --------------------------------------------------------- *
  function AfterAddEntry(toAuth)
    this.checkLockout(m.toAuth)
    return 
  endfunc 
  * --------------------------------------------------------- *
  function checkLockout(toAuth)
    local lnSelect, lnCount
    if toAuth.lLockoutTrigger and !isnull(toAuth.cUser_Id) and !empty(toAuth.cUser_Id)

      lnSelect = select()
      select (this.cLogAlias)
      count for Removed = .f. and Lockout = .t. and User_ID = toAuth.cUser_Id and Time > datetime() - (60 * L7_AUTH_LOCKOUT_WINDOW) ;
        to lnCount
      if m.lnCount >= L7_AUTH_LOCKOUT_ATTEMPTS
        toAuth.lLockout = .t. && passes suggestion back to App (nothing can be done here now, as Account gets altered)
        
      endif

*!*  #DEFINE L7_AUTH_LOCKOUT_ATTEMPTS  5
*!*  #DEFINE L7_AUTH_LOCKOUT_WINDOW   15
*!*  #DEFINE L7_AUTH_LOCKOUT_CLEAR    60 
      
    endif
    return 
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
      ENDIF
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
enddefine && L7AuthLog


*** ================================================ ***
define class L7AuthBehavior as Custom
  lAttempt = .t. && yes unless otherwise selected
  lSuccess = .f. && fails unless otherwise selected
  lLogOutcome = .f.
  cReason = "No reason"
  cMessageToUser = null && if null, show them cReason
  lLockoutTrigger = .f. && if .t., this event can lead to lockouts
  lLockout = .f. && if .t., lockout suggested (if supported)
  nSeverity = L7_SEVERITY_DEBUG
  cUser_Id = null && app can populate with user's attempt (or actual)
  * ------------------------------------------------ *
  function cMessageToUser_access
    return nvl(this.cMessageToUser, this.cReason)
  endfunc 
  * ------------------------------------------------ *
  function INIT(tcUser_Id)
    if vartype(m.tcUser_Id) = 'C' && not all behaviors know
      this.cUser_Id = m.tcUser_Id
    endif 
    return 
  endfunc && INIT
enddefine 

* L7Page.cLoginFailureMessage had:
* "User ID not found and/or incorrect password! (Note: Passwords are case-sensitive.)"

*** ================================================ ***
define class L7AuthNoAttempt as L7AuthBehavior 
  lAttempt = .f. && typical for public access 
  lSuccess = .f. 
  cReason = "No login attempted"
enddefine 

*** ================================================ ***
define class L7AuthSuccess as L7AuthBehavior 
  lSuccess = .t. 
  lLogOutcome = .t. 
  cReason = "Successful login"
enddefine 

*** ================================================ ***
define class L7AuthBadForm as L7AuthBehavior 
  cReason = "Invalid login form"
enddefine 

*** ================================================ ***
define class L7AuthNoUser as L7AuthBehavior 
  cReason = "User ID not entered"
enddefine 

*** ================================================ ***
define class L7AuthDeletedUser as L7AuthBehavior 
  cReason = "User has been removed"
enddefine 

*** ================================================ ***
define class L7AuthNoPassword as L7AuthBehavior 
  cReason = "Password not entered"
enddefine 

*** ================================================ ***
define class L7AuthBadAttempt as L7AuthBehavior && abstract subclass
  cMessageToUser = "User ID not found and/or incorrect password! (Note: Passwords are case-sensitive.)"
  lLogOutcome = .t.
  nSeverity = L7_SEVERITY_INFO  && can be escalated if lockout occurs 
enddefine 

*** ================================================ ***
define class L7AuthBadUser as L7AuthBadAttempt && inherits generic message to user
  cReason = "User not found"
enddefine 

*** ================================================ ***
define class L7AuthAmbiguousUser as L7AuthBadAttempt && inherits generic message to user
  cReason = "User token not unique, cannot identify user"
  nSeverity = L7_SEVERITY_NOTICE
enddefine 

*** ================================================ ***
define class L7AuthBadPassword as L7AuthBadAttempt && inherits generic message to user
  lLockoutTrigger = .T. 
  cReason = "Incorrect password"
enddefine 

*** ================================================ ***
define class L7AuthIPUnallowed as L7AuthBehavior 
  cReason = "User not connecting from approved network!"
  lLogOutcome = .t.
enddefine 

*** ================================================ ***
define class L7AuthAccountRevoked as L7AuthBehavior 
  cReason = "Account has been revoked!"
  nSeverity = L7_SEVERITY_NOTICE
  lLogOutcome = .t.
enddefine 

*** ================================================ ***
define class L7AuthAccountDisabled as L7AuthBehavior 
  cReason = "Account is disabled!"
  lLogOutcome = .t.
  nSeverity = L7_SEVERITY_NOTICE
enddefine 

*** ================================================ ***
define class L7AuthAccountInactive as L7AuthBehavior 
  cReason = "Inactive account!"
  lLogOutcome = .t.
  nSeverity = L7_SEVERITY_NOTICE
enddefine 

*** ================================================ ***
define class L7AuthPasswordExpired as L7AuthBehavior 
enddefine 

*** ================================================ ***
define class L7AuthAccountLockout as L7AuthBehavior 
  cReason = "Account is locked out!"
  * note no severity bump--we notify *when* the lockout occurs, not on each hit thereafter
enddefine 

*** ================================================ ***
define class L7AuthAccountExpired as L7AuthBehavior 
  cReason = "Account has expired!"
  nSeverity = L7_SEVERITY_NOTICE
  lLogOutcome = .t.
enddefine 

*** ================================================ ***
define class L7AuthOther as L7AuthBehavior 
  cReason = "Other login failure"  && set to better string in app
  nSeverity = L7_SEVERITY_WARNING  && mainly because it's unexpected (I think)
  lLogOutcome = .t.
enddefine 

*** ================================================ ***

*end: L7Auth.PRG

