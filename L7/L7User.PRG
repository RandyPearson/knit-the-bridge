* L7User.PRG
*
* User Class for L7 Framework.
*  - Often subclassed in application.
*  - Subclass via Page.cUserClass property.
*  - Individual PEM indicating subclassing potential.
*  - Also look at companion session class, L7Session.
 
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


*** ======================================================== ***
DEFINE CLASS L7User AS SESSION
  oData      = NULL
  cDatapath  = ""
  cTableName = "L7User" && override if your app has its user info in the database 
  cAlias     = NULL
  cUserToken = "x"      && used by framework for cookie/LP interaction
  cUserName  = ""       && convenience: see Access Method
  * --------------------------------------------------------- *
  FUNCTION cUserName_ACCESS
    RETURN THIS.GetUserName()
  ENDFUNC && cUserName_ACCESS
  * --------------------------------------------------------- *
  FUNCTION RELEASE
    * Garbage collection:
    this.oData = null 
    RETURN
  ENDFUNC && DESTROY
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    * Sometimes subclassed if user preference changes should
    * be saved as the object is destroyed.
    THIS.RELEASE()
    RETURN
  ENDFUNC && DESTROY
  * --------------------------------------------------------- *
  * FUNCTION INIT(loPage)
    * THIS.oPage = m.loPage
  function init 
    DO StandardVfpSettings  && required for new private datasession
    SET MULTILOCKS OFF      && only one user at a time
   
    LOCAL llFail
    #IF DEBUGMODE = .F.
    TRY
    #ENDIF
      THIS.OpenTable()
    #IF DEBUGMODE = .F.
    CATCH TO loExc
      THROW loExc.Message + " initializing user object."
      llFail = .T.
    ENDTRY
    #ENDIF
    RETURN NOT m.llFail && [[ why a flag for init() ??
  ENDFUNC  && INIT
  * --------------------------------------------------------- *
  FUNCTION ChangePasswordForm(llRequirePrevious)
    * This adds interface only so far, provide actual 
    * form in subclass...
    RETURN [<h2>Function Not Implemented</h2>]
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION LoginForm(lcUrl, lcUser, llAllowChange)
    * *Often* fully overriden in a subclass with a form more
    * suitable to the app needs!
    *   lcUrl          : form Action
    *   lcUser         : pre-assign user ID
    *   llAllowChange  : can they change user ID
    LOCAL loForm
    loForm = CREATEOBJECT( "L7Form")
    WITH loForm
    	.cFormName = "LoginForm"
      .cHtmlName = "LoginForm"
    	.cTitle = "User Login Form"
    	IF VARTYPE( m.lcUrl) = "C"
    		.cAction = m.lcUrl
    	ENDIF
    	.AddObject( "txtUserId", "L7Textbox" )
    	WITH .txtUserId
        .cHtmlName = "txtUserId"
    		.nSize = 20
    		.cLabel = "User ID"
    		IF VARTYPE( m.lcUser) = "C"
    			.SetValue( m.lcUser)
    		ENDIF
    	ENDWITH
    	.AddObject( "txtPassword", "L7Textbox" )
    	WITH .txtPassword
        .cHtmlName = "txtPassword"
    		.lPassword = .T.
    		.nSize = 24
    		.cLabel = "Password"
    		.cInstructions = "(case sensitive)"
    	ENDWITH
    ENDWITH  && loForm
    RETURN loForm.Render()  
  ENDFUNC  && LoginForm                    
  * --------------------------------------------------------- *
  FUNCTION JustLoggedIn(lcId) && Optional User ID to force.
    ** [[ TO DO: 
    ** - Revise this and LoginForm() so that they use a 
    ** common form class.
    ** - Investigate CryptoAPI.
    ** - Password reminder phrase and email support.
    
    * If LoginForm() above is overridden in a subclass, this
    * method generally needs to be also!

    IF NOT Request.Form( "FormName") = "LoginForm"
    	RETURN .F.
    ENDIF
    LOCAL llRetVal, lcPass
    lcPass = Request.Form( "LoginForm_txtPassword" )
    llRetVal = THIS.OpenTable() 

    IF m.llRetVal
    	IF VARTYPE( m.lcId) <> "C" OR EMPTY( m.lcId)
    		lcId = Request.Form( "LoginForm_txtUserId")
    	ENDIF
    	lcId = PADR( UPPER( m.lcId ), LEN( UserId ) )
      SELECT (THIS.cAlias)
    	LOCATE FOR UPPER( UserId ) = m.lcId
    	IF NOT FOUND() 
    		llRetVal = .F.
    	ELSE
    		IF THIS.CheckPassword(m.lcPass, Password, m.lcId) 
    			llRetVal = .T.
    		ELSE
    			llRetVal = .F.
    		ENDIF
    	ENDIF
    ENDIF
    RETURN m.llRetVal 
  ENDFUNC  && JustLoggedIn
  * --------------------------------------------------------- *
  FUNCTION CheckPassword(lcPassEntered, lcPassStored, lcIdPadded)
    * Hook to allow other password storage mechanisms.
    RETURN m.lcPassStored = THIS.EncryptPassword( ;
      PADR( m.lcPassEntered, LEN( m.lcPassStored)), ;
      UPPER(m.lcIdPadded) )
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION MustChangePassword
    RETURN .F.  && subclass if funciton needed
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION EncryptPassword(lcPassPadded, lcIdPadded)
    RETURN L7Encode(1, lcPassPadded, UPPER(m.lcIdPadded))
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetUserId
    * Override if you use your own table structure.
    RETURN TRIM( EVALUATE(THIS.cAlias + ".UserId"))
  ENDFUNC  && GetUserId                    
  * --------------------------------------------------------- *
  FUNCTION GetUserKey
    * Override to return primary key if you 
    * use your own table structure.
    RETURN RECNO(THIS.cAlias)
  ENDFUNC  && GetUserKey                    
  * --------------------------------------------------------- *
  FUNCTION IsTester && check if automotron to allow alert emails to be shuttered
    RETURN .f.
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION IsDeveloper
    RETURN .f.
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION IsAdministrator
    * Override if you use your own table structure.
    RETURN EVALUATE(THIS.cAlias + ".Admin")
  ENDFUNC  && IsAdministrator              
  * --------------------------------------------------------- *
  FUNCTION IsAdministrator
    * Override if you use your own table structure.
    RETURN EVALUATE(THIS.cAlias + ".Admin")
  ENDFUNC  && IsAdministrator              
  * --------------------------------------------------------- *
  FUNCTION IsUserManager
    * Override if you use your own table structure.
    RETURN EVALUATE(THIS.cAlias + ".UserMgr")
  ENDFUNC  && IsUserManager                
  * --------------------------------------------------------- *
  FUNCTION IsReadOnly
    * Override if you use your own table structure.
    RETURN EVALUATE(THIS.cAlias + ".ReadOnly")
  ENDFUNC  && IsUserManager                
  * --------------------------------------------------------- *
  FUNCTION IsAnonymous
    * Override if you use your own table structure.
    RETURN EVALUATE(THIS.cAlias + ".Anonymous")
  ENDFUNC  && IsAnonymous

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
  FUNCTION GetUserName
    * Override if you use your own table structure.
    LOCAL lnSelect, lcRet
    lcRet = ""
    lnSelect = SELECT()
    SELECT (THIS.cAlias)
    IF EMPTY( LastName)
    	lcRet = TRIM( UserId )
    ELSE
    	IF EMPTY( NickName)
    		lcRet = TRIM( LastName)
    	ELSE
    		lcRet = TRIM( NickName) + [ ] + TRIM( LastName)
    	ENDIF
    ENDIF
    SELECT (m.lnSelect)
    RETURN m.lcRet
  ENDFUNC  && GetUserName                  
  * --------------------------------------------------------- *
  FUNCTION GetEmailAddress
    * Override if you use your own table structure.
    RETURN TRIM(EVALUATE(THIS.cAlias + ".Email"))
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION GetPhoneNumber
    * Override if you use your own table structure.
    RETURN TRIM(EVALUATE(THIS.cAlias + ".Phone"))
  ENDFUNC  
  * --------------------------------------------------------- *
  function SelectTable
    this.OpenTable()
    select (this.cAlias)
    return 
  endfunc 
  * --------------------------------------------------------- *
  function OpenTable
    * Override if you have an application object that
    * provides its own datapath or table opening service.
    if !isnull(this.cAlias) and used(this.cAlias)
      return .t. && already open
    endif 
    local llRetVal
    llRetVal = .T.
    if !empty(this.cDatapath)
    	this.cDatapath = addbs(this.cDatapath)
    else
      * Use the application object's data path:
      this.cDatapath = goL7App.cDatapath
    endif 
    if !file(this.cDatapath + this.cTableName + ".DBF")
    	llRetVal = this.CreateTable() 
    endif 
    use (this.cDatapath + this.cTableName + ".DBF" ) again
    this.cAlias = ALIAS()
    return m.llRetVal 
  endfunc  && OpenTable
  * --------------------------------------------------------- *
  FUNCTION CreateTable
    * Override, possibly with no action other than RETURN .F.,
    * if your user info is part of a larger database.
    CREATE TABLE ( THIS.cDatapath + THIS.cTableName ) ;
    	FREE ;
    	( ;
    		UserId C(20), ;
    		Password C(24), ;
    		NetUserId C(20), ;
    		Email C(40), ;
        Phone C(20), ;
        PassHint C(80), ;
        GUID C(16), ;
    		LastName C(20), ;
    		NickName C(20), ;
    		Cookie C(32), ;
    		Admin L, ;
    		UserMgr L, ;
    		ReadOnly L, ;
    		Anonymous L, ;
    		Inactive L, ;
    		Disabled L, ;
    		Prefs M ;
    	)
    * NOTE: Free table, so no long field names!
    INDEX ON UPPER( UserId) TAG UserId
    INDEX ON UPPER( NetUserId) TAG NetUserId
    INDEX ON DELETED() TAG Deleted
    USE
    RETURN
  ENDFUNC  && CreateTable
  * --------------------------------------------------------- *
  FUNCTION NewCookieUser(lcCookie, lcUser)
    * Override, possibly with no action other than RETURN .F.,
    * if your user info is part of a larger database.
    LOCAL lnTry, lnTries, llRetVal
    IF EMPTY( m.lcUser)
    	lcUser = m.lcCookie
    ENDIF
    lnTries = 25
    SELECT (THIS.cAlias)
    FOR lnTry = 1 TO m.lnTries
    	APPEND BLANK
    	IF NOT RLOCK()
    		llRetVal = .T.
    		REPLACE Cookie WITH m.lcCookie ;
    			UserId WITH m.lcUser ;
    			LastName WITH "Unknown"
    		EXIT
    	ENDIF
    ENDFOR
    RETURN m.llRetVal
  ENDFUNC  && NewCookieUser                

  * --------------------------------------------------------- *
  function getUsersWhere(tcCond)
    this.OpenTable()
    local lnSelect, lcSql, loRet, loRec
    lnSelect = select()
    loRet = createobject("Collection")
    lcSql = textmerge([select * from <<this.cAlias>> where <<m.tcCond>> into cursor _<<program()>>])
    scan
      scatter memo name loRec
      loRet.add(m.loRec)  && this could be keyed, but that would fail with integer PKs
    endscan
    use in select("_" + program())      
    select (m.lnSelect)
    return m.loRet
  endfunc  && getUsersWhere
  * --------------------------------------------------------- *
  function LocateUserWhere(tcCond, tlReturnObject)
    local lnSelect, lvRet
    lnSelect = select()
    this.selectTable()
    locate for &tcCond
    if !found()
      lvRet = iif(m.tlReturnObject, null, .f.)
    else
      scatter memo name lvRet
      if !tlReturnObject && store here and return .t.
        this.oData = m.lvRet
        lvRet = .t.
      endif 
    endif
    select (m.lnSelect)
    return m.lvRet
  endfunc 
  * --------------------------------------------------------- *
  function FindUser(tcId, tlReturnObject)
    this.selectTable() && needed to find field length
    return this.LocateUserWhere([upper(UserId) = "] + padr(upper(m.tcId), len(UserId)) + ["], m.tlReturnObject)
  endfunc 
  *!*    * --------------------------------------------------------- *
  *!*    FUNCTION FindUser(lcId)
  *!*      * Often overridden with code that finds the 
  *!*      * user record and then scatters to a member object.
  *!*      IF VARTYPE( m.lcId) <> "C" OR EMPTY( m.lcId)
  *!*      	RETURN .F.
  *!*      ENDIF
  *!*      LOCAL llRetVal
  *!*      llRetVal = THIS.OpenTable()

  *!*      IF m.llRetVal
  *!*        select (this.cAlias) 
  *!*      	lcId = PADR( UPPER( m.lcId ), LEN( UserId ) )
  *!*      	LOCATE FOR UPPER( UserId ) = m.lcId
  *!*      	llRetVal = FOUND() 
  *!*      ENDIF
  *!*      RETURN m.llRetVal 
  *!*    ENDFUNC  && FindUser
  * --------------------------------------------------------- *
  FUNCTION InitAnonymousUser
    * Sets the user record to that for the generic
    * anonymous user.
    * Override if you use your own table structure.
    SELECT (THIS.cAlias)
    LOCAL lcId, llRetVal
    llRetVal = .T.
    lcId = L7_ANONYMOUS_USERID
    IF VARTYPE( m.lcId ) = "C"
    	lcId = PADR( m.lcId, LEN( UserId) )
    ENDIF
    LOCATE FOR UserId = L7_ANONYMOUS_USERID
    IF NOT FOUND()
    	llRetVal = .F.
    	LOCAL lnTries
    	FOR lnTries = 1 TO 10
    		APPEND BLANK
    		IF RLOCK()
    			REPLACE ;
    				UserId WITH UPPER( m.lcId) ;
    				Anonymous WITH .T.
    			UNLOCK
    			llRetVal = .T.
    			EXIT
    		ENDIF
    	ENDFOR
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && InitAnonymousUser            
  * --------------------------------------------------------- *
  FUNCTION CreateAuthenticatedUser(lcNetUser)
    * Receives a network ID and adds a user record.
    * Override, possibly with no action other than RETURN .F.,
    * if your user info is part of a larger database.
    IF VARTYPE( m.lcNetUser) <> "C" OR EMPTY( m.lcNetUser)
    	RETURN .F.
    ENDIF
    SELECT (THIS.cAlias)
    LOCAL lnTries, llRetVal
    llRetVal = .F.
    FOR lnTries = 1 TO 10
    	APPEND BLANK
    	IF RLOCK()
    		REPLACE ;
    			UserId WITH UPPER( m.lcNetUser) ;
    			NetUserId WITH UPPER( m.lcNetUser) ;
    			LastName WITH m.lcNetUser
    		UNLOCK
    		llRetVal = .T.
    		EXIT
    	ENDIF
    ENDFOR
    RETURN m.llRetVal
  ENDFUNC  && CreateAuthenticatedUser
  * --------------------------------------------------------- *
  FUNCTION ValidateAuthenticatedUser(lcNetUser)
    * Receives a network ID and checks if a system
    * user has that ID.
    * Override if you use your own table structure.
    IF VARTYPE( m.lcNetUser) <> "C" OR EMPTY( m.lcNetUser)
    	RETURN .F.
    ENDIF
    LOCAL llRetVal
    llRetVal = .T.
    IF m.llRetVal AND THIS.OpenTable()
    	lcNetUser = UPPER( PADR( lcNetUser, LEN( NetUserId)))
    	LOCATE FOR UPPER( NetUserId) = m.lcNetUser
    	llRetVal = FOUND()
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && ValidateAuthenticatedUser    
  * --------------------------------------------------------- *
  FUNCTION ValidatePersistentCookieUser(lcCookieVal)
    * Receives a cookie value and checks if a system
    * user has that cookie.
    * Override if you use your own table structure.
    IF VARTYPE( m.lcCookieVal) <> "C" OR EMPTY( m.lcCookieVal)
    	RETURN .F.
    ENDIF
    LOCAL llRetVal
    llRetVal = .T.
    IF m.llRetVal AND THIS.OpenTable() 
    	lcCookieVal = PADR( lcCookieVal, LEN( Cookie) )
    	LOCATE FOR Cookie = m.lcCookieVal
    	llRetVal = FOUND()
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && ValidatePersistentCookieUser  
  * --------------------------------------------------------- *
  FUNCTION GetPreference(lcVarName)
    LOCAL lcVar
    SELECT (THIS.cAlias)
    lcVar = Extract( Prefs, ;
    	'<' + m.lcVarName + '>', ;
    	'</' + m.lcVarName + '>', ;
    	, .F. )
    RETURN m.lcVar
  ENDFUNC  && GetPreference
  * --------------------------------------------------------- *
  FUNCTION SetPreference(lcVarName, lvValue)
    LOCAL lcOld, lcNew
    SELECT (THIS.cAlias)
    lcOld = THIS.GetPreference( m.lcVarName )
    IF VARTYPE( m.lvValue) <> "C"
    	lvValue = TRANSFORM( m.lvValue)
    ENDIF
    lcNew = '<' + m.lcVarName + '>' + m.lvValue + ;
    	'</' + m.lcVarName + '>' 
    TRY
      DO CASE
      CASE m.lcOld == m.lvValue
      	* Do nothing, since setting is unchanged.
      CASE EMPTY( m.lcOld)
      	REPLACE Prefs WITH m.lcNew + Prefs
      CASE EMPTY( m.lvValue)
      	REPLACE Prefs WITH STRTRAN( Prefs, ;
      		'<' + m.lcVarName + '>' + m.lcOld + '</' + m.lcVarName + '>' )
      OTHERWISE  && change
      	REPLACE Prefs WITH STRTRAN( Prefs, ;
      		'<' + m.lcVarName + '>' + m.lcOld + '</' + m.lcVarName + '>', ;
      		m.lcNew )
      ENDCASE
    CATCH TO loExc WHEN INLIST(loExc.ErrorNo, 109, 130)
      * Do nothing if can't lock--it's only a preference.
      = .F.
    ENDTRY
    RETURN
  ENDFUNC  && SetPreference
  * --------------------------------------------------------- *
  FUNCTION ClearPreferences
    * Override if you use your own table structure.
    SELECT (THIS.cAlias)
    IF RLOCK()
      REPLACE Prefs WITH ''
      UNLOCK
    ENDIF
    RETURN
  ENDFUNC  && ClearPreferences
  * --------------------------------------------------------- *
  FUNCTION GetDebugInfo(tcTitle) && recommended to override in subclasses
    LOCAL lcResult
    TRY 
      lcResult = L7ShowObject(THIS, EVL(m.tcTitle, "User Object"),,"Password")
    CATCH TO loExc
      lcResult = [<div>] + PROGRAM() + " error: " + loExc.Message + [</div>]
    ENDTRY
    RETURN m.lcResult 
  ENDFUNC
ENDDEFINE  && L7User

* For testing only:
*** ========================================================= ***
DEFINE CLASS L7FakeUser AS CUSTOM
  cUserId = ""
  * --------------------------------------------------------- *
  FUNCTION INIT(lcUserId)
    IF NOT EMPTY( m.lcUserId )
      THIS.cUserId = m.lcUserId
    ENDIF
  ENDFUNC  && INIT
  * --------------------------------------------------------- *
  FUNCTION GetUserName
    RETURN THIS.cUserId
  ENDFUNC  && GetUserName
  * --------------------------------------------------------- *
ENDDEFINE  && L7FakeUser

*** ========================================================= ***
* End: L7User.PRG

#if .f.
12/24/2002 - Changed Cookie field to 32 chars to support GUID session IDs.
01/14/2003 - Changed "permanent" to "persistent".
04/21/2003 - Eliminated lError and cErrorMsg props.
           - Added cAlias property and SELECT statements where needed.
           - Added GetDebugInfo method (see L7App for one use).
05/20/2003 - fixed Endode -> L7Encode
05/22/2003 - fixed missing "."'s
           - added some RETURN lines
09/05/2003 - added StandardVfpSettings() to INIT.
03/13/2006 - added SET MULTILOCKS OFF

TO DO: Make this persistent (create from App) so object not created on each hit.

#endif
