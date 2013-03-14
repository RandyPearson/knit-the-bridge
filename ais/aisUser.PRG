* AisUser.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ========================================================= ***
define class aisUser as L7User

  oData = null
  cLoginFormClass = "aisLoginForm" 
  cTableName = "Artist" 
  * --------------------------------------------------------- *
  function destroy()
    return this.garbageCollect()
  endfunc
  *--------------------------------------------    
  function garbageCollect()
    this.release()
  endfunc 
  *--------------------------------------------    
  function release()  && fw calls this
    this.oData = null
  endfunc  
  * --------------------------------------------------------- *
  function initAnonymousUser
    this.oData = null
    return 
  endfunc
  * --------------------------------------------------------- *
  function CreateTable
    error "User table missing and cannot be created from here."
  endfunc 

  * --------------------------------------------------------- *
  function EncryptPassword(lcPassPadded, lcIdPadded)
    return AisPasswordHash(m.lcPassPadded, UPPER(m.lcIdPadded))
  endfunc 
  * --------------------------------------------------------- *
  function JustLoggedIn(tcId, toForm)  && Optional User ID to force.
    if Request.cMethod <> 'POST' OR !Request.Form("FormName") = "LoginForm"
      return .F.
    endif 
    local llRetVal, loAuth, lcPass, llFailure, lcReason, lcIdPosted, lcIdFmt, llFound, ;
      loUsr, loUsers, lcEmail
    loForm = m.toForm
    if loForm.wasPosted()
      lcIdPosted = loForm.txtUserId.vNewValue && need for debugging in case PW has bad chars
      goL7App.App_Log(L7_SEVERITY_DEBUG, 'User ID posted as ' + ;
        chrtran(m.lcIdPosted, chrtran(m.lcIdPosted, loForm.txtUserId.cValidChars, ''), ''))
    endif 
    if !loForm.Valid()
      loAuth = createobject(L7_AUTH_BAD_FORM)
      llRetVal = .F.
      llFailure = .T.
      lcReason = trim(strtran(strtran(loForm.GetValidationMessages(), L7BR, ' '), crlf, ' '))
      Page.cLoginFailureMessage = m.lcReason  && OK to tell user this one
      * [[ Page...ugh!
    endif 
    if !m.llFailure 
      lcPass = loForm.txtPassword.vNewValue
      if vartype(m.tcId) <> "C" or empty(m.tcId)
        tcId = loForm.txtUserId.vNewValue
      endif 
      do case
      case empty(m.tcId)
        llFound = .f.
      case "@" $ m.tcId  && presumed email address
        lcEmail = lower(m.tcId) 
        goL7App.App_Log(L7_SEVERITY_DEBUG, "Presumed login using email address " + m.lcEmail)

        loUsers = this.getUsersWhere([lower(Art_Email) = "] + padr(m.lcEmail, THISAPP_USER_EMAIL_LEN) + ["])
        do case
        case loUsers.count = 0
          loAuth = createobject(L7_AUTH_BAD_USER, m.lcEmail)
          llRetVal = .F.
          llFailure = .T.
          lcReason = "User not found."
        case loUsers.count = 1 && unique email match 
          loUsr = loUsers.item[1]
          if empty(loUsr.Art_ID) && not an approved user yet--email match premature
            loAuth = createobject(L7_AUTH_ACCOUNT_INACTIVE)
            llRetVal = .F.
            llFailure = .T.
            lcReason = "Person does not have an approved account."
            Page.cLoginFailureMessage = m.lcReason  && OK to tell user this one
          else
            llFound = .t. && no AUTH object yet...
            lcIdFmt = loUsr.Art_ID
          endif 
        otherwise 
          loAuth = createobject(L7_AUTH_AMBIGUOUS_USER)
          llFailure = .T.
          lcReason = textmerge([<<m.loUsers.Count>> users have same email address--ambiguous login denied])
          Page.cLoginFailureMessage = m.lcReason  && OK to tell user this one
        endcase 
      otherwise && assume basic UID
        lcIdFmt = padr(upper(m.tcId), THISAPP_LENGTH_ID_FIELDS)
        if !empty(m.lcIdFmt) && and !empty(m.lcPass) 
          loUsr = this.findUserByUserId(m.lcIdFmt, .t.) && 2nd param returns object
          llFound = !isnull(m.loUsr)
        endif  
      endcase 

      if m.llFound
        goL7App.App_Log(L7_SEVERITY_DEBUG, textmerge([Record with PK <<loUsr.Art_pk>> found for User]))
      endif 
      
      do case 
      
      * These CASE's _precede_ checking of the password:
      * (Additional CASE's below are only checked if logon succeeds.)
      case vartype(m.loAuth) = "O"
        = .f.  && already handled 
      case empty(m.lcIdFmt) && blank user
        loAuth = createobject(L7_AUTH_NO_USER)
        llRetVal = .F.
        llFailure = .T.
        lcReason = "User ID not entered."
        Page.cLoginFailureMessage = m.lcReason  && OK to tell user this one
      case !m.llFound  && possibly redundant...
        loAuth = createobject(L7_AUTH_BAD_USER, m.lcIdFmt)
        llRetVal = .F.
        llFailure = .T.
        lcReason = "User not found."

      case Art_Account_Lockout
        loAuth = createobject(L7_AUTH_ACCOUNT_LOCKOUT, m.lcIdFmt)
        llRetVal = .F.
        llFailure = .T.
        lcReason = "Account is locked out!"
        Page.cLoginFailureMessage = m.lcReason  && OK to tell user this one

      case empty(m.lcPass)
        loAuth = createobject(L7_AUTH_NO_PASSWORD)
        llRetVal = .F.
        llFailure = .T.
        lcReason = "Password not entered."
        Page.cLoginFailureMessage = m.lcReason  && OK to tell user this one
        
      otherwise 
        if this.CheckPassword(padr(m.lcPass, 24), loUsr.Art_Password_Hash, m.lcIdFmt)
          llRetVal = .T. && clears this hurdle, but not done yet
        else  
          loAuth = createobject(L7_AUTH_BAD_PASSWORD, m.lcIdFmt)
          llRetVal = .F.
          llFailure = .T.
          lcReason = "Incorrect password from User ID " + trim(m.lcIdFmt)
        endif 
      endcase 

      * enforce any network/IP restrictions here:
      * ...

      if m.llRetVal  && OK so far, but check a few other controls:
        do case
        * These CASE's _follow_ checking of the password:
        case pemstatus(loUsr, 'Art_Inactive', 5) and loUsr.Art_Inactive && in case we add this
          loAuth = createobject(L7_AUTH_DELETED_USER, m.lcIdFmt)
          llRetVal = .F.
          llFailure = .T.
          lcReason = "Inactive/deleted user record!"
        
        case Art_Account_Revoked
          loAuth = createobject(L7_AUTH_ACCOUNT_REVOKED, m.lcIdFmt)
          llRetVal = .F.
          llFailure = .T.
          lcReason = "Account has been revoked!"
          Page.cLoginFailureMessage = m.lcReason  && OK to tell user this one?
          
        case !loUsr.Art_Approved 
          loAuth = createobject(L7_AUTH_ACCOUNT_INACTIVE, m.lcIdFmt)
          llRetVal = .F.
          llFailure = .T.
          lcReason = "AIS User not flagged as Approved"
          Page.cLoginFailureMessage = m.lcReason  && OK to tell user this one

        *!* case PW expired...  loAuth = createobject(L7_AUTH_PASSWORD_EXPIRED, m.lcIdFmt)

        endcase 
      endif 
      
    endif 
    if m.llRetVal  && just logged in
      loAuth = createobject(L7_AUTH_SUCCESS, m.lcIdFmt)
      this.oData = m.loUsr
      this.OnLoginSuccess(m.tcId, m.loAuth)
    endif 
    if m.llFailure
      this.OnLoginFailure(m.tcId, m.lcPass, m.lcReason, m.loAuth)
    ENDIF
    loForm = NULL
    return m.llRetVal 
  endfunc  && JustLoggedIn
  * --------------------------------------------------------- *
  function OnLoginSuccess(tcId, toAuth)
    if toAuth.lLogOutcome && [[dry?
      goL7App.LogAuth(m.toAuth)
    endif 
    return 
  endfunc 
  * --------------------------------------------------------- *
  function OnLoginFailure(tcId, tcPass, tcReason, toAuth)
    local lcMsg, lnLvl

    if toAuth.lLogOutcome
      goL7App.LogAuth(m.toAuth)
      if toAuth.lLockout
        Page.App_Log(L7_SEVERITY_WARNING, trim(toAuth.cUser_ID) + " should be locked out per policy!")
      endif
    endif

    if vartype(m.toAuth) = 'O'
      
      * [[ temporary escalation:
      toAuth.nSeverity = min(toAuth.nSeverity, L7_SEVERITY_NOTICE)
      
      if !toAuth.nSeverity = L7_SEVERITY_NONE
        Page.App_Log(;
          iif(environ.item('app.auto_test') = '1', L7_SEVERITY_INFO, toAuth.nSeverity), ;
          textmerge([Login failure type <<toAuth.class>>, ID <<m.tcId>>]))
      endif 
    else  && old behavior
      lcMsg = "Login attempt" + iif(vartype(m.tcId) = "C", " by User " + m.tcId, "") + ;
        " failed: " + iif(vartype(m.tcReason) = "C", m.tcReason, "[no reason]")
      lnLvl = iif(environ.item('app.auto_test') = '1', L7_SEVERITY_INFO, L7_SEVERITY_NOTICE)
      Page.App_Log(m.lnLvl, m.lcMsg)
    endif 
    return 
  endfunc && OnLoginFailure
  * --------------------------------------------------------- *
  function CreateLoginForm(lcUrl)
    local loForm
    loForm = createobject(this.cLoginFormClass)
    if !empty(m.lcUrl)
      loForm.cAction = m.lcUrl
    endif 
    return m.loForm
  endfunc 
  * --------------------------------------------------------- *
  function findUserByEmailAddress(tcAddr, tlReturnObject) 
    * CAUTION: uniqueness not checked, use getUsersWhere() to check
    return this.LocateUserWhere([upper(Art_Email) = "] + padr(upper(m.tcAddr), THISAPP_USER_EMAIL_LEN) + ["], m.tlReturnObject)
  endfunc
  * --------------------------------------------------------- *
  function findUserByUserId(tcId, tlReturnObject) && synonym
    return this.FindUser(m.tcId, m.tlReturnObject)
  endfunc
  * --------------------------------------------------------- *
  function FindUser(tcId, tlReturnObject)
    return this.LocateUserWhere([Art_ID = "] + padr(upper(m.tcId), THISAPP_LENGTH_ID_FIELDS) + ["], m.tlReturnObject)
  endfunc 
  * --------------------------------------------------------- *
  function findUserByPK(tcPK, tlReturnObject) 
    return this.LocateUserWhere([Art_PK = "] + m.tcPK + ["], m.tlReturnObject)
  endfunc
  * --------------------------------------------------------- *
  function IsActive
    return !isnull(this.oData) and this.oData.Art_Approved 
  endfunc   && IsActive
  * --------------------------------------------------------- *
  function IsDeveloper
    return this.isActive() and this.oData.Art_Admin && nothing separate 
  endfunc
  * --------------------------------------------------------- *
  function IsAdministrator
    return this.isActive() and this.oData.Art_Admin 
  endfunc
  * --------------------------------------------------------- *
  function IsCore && just below Admin
    return this.isActive() and this.oData.Art_Core
  endfunc
  * --------------------------------------------------------- *
  function IsArtist
    return this.isActive() and this.oData.Art_Artist
  endfunc
  * --------------------------------------------------------- *
  function IsAnonymous
    return isnull(this.oData) or empty(this.oData.Art_Id)
  endfunc
  * --------------------------------------------------------- *
  function IsReadOnly
    return .f.  &&  THIS.oData.Par_Read_Only
  endfunc  && IsReadOnly           
  * --------------------------------------------------------- *
  function GetUserKey
    if isnull(this.oData)
      return "--no data--"
    endif
    return this.oData.Art_PK
  endfunc  && GetUserKey                  
  * --------------------------------------------------------- *
  function GetUserID
    if isnull(this.oData)
      return "--no data--"
    endif
    return this.oData.Art_ID 
  endfunc  && GetUserID              
  * --------------------------------------------------------- *
  function getContactInfo
    local lcRet, loExc
    try
      lcRet = this.getUserName() + ", " + this.GetEmailAddress() + ", " + this.GetPhoneNumber()
    catch to loExc
      lcRet = loExc.message
    endtry
    return m.lcRet 
  endfunc 
  * --------------------------------------------------------- *
  function GetUserName
    if isnull(this.oData)
      return "--no data--"
    endif
    return aisArtistName(this.oData)
  endfunc  && GetUserName                  
  * --------------------------------------------------------- *
  function GetEmailAddress
    if isnull(this.oData)
      return "--no data--"
    endif
    return alltrim(nvl(this.oData.Art_Email, ""))
  endfunc  
  * --------------------------------------------------------- *
  function GetPhoneNumber
    if isnull(this.oData)
      return "--no data--"
    endif
    return alltrim(nvl(this.oData.Art_Phone, ""))
  endfunc  

  * --------------------------------------------------------- *
  function GetDebugInfo(lcTitle) 
    local lcResult, loExc
    try  
      if isnull(this.oData)
        lcResult = [<div>NO USER OBJECT DATA!</div>]
      else 
        lcResult = L7ShowObject(this.oData, evl(m.lcTitle, "User Object"), , ;
          'Art_Password_Hash,Art_Previous_Passwords')
      endif 
    catch to loExc
      lcResult = [<div>] + PROGRAM() + " error: " + loExc.Message + [</div>]
    endtry 
    return  m.lcResult 
  endfunc 

enddefine && AisUser

*** ========================================================= ***
function AisPasswordHash(lcPW, lcUser)  && salted hash of PW
  return HashMD5([KnitTheBridge] + padr(m.lcPW, 24) + upper(padr(m.lcUser, THISAPP_LENGTH_ID_FIELDS)))
endfunc  

* end

