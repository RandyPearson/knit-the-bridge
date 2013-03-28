* L7Page.PRG

#INCLUDE L7.H
#DEFINE THIS_DEBUG_OBJECTS .F.


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

* L7 RESERVED QueryString Parameters

* one-character variables:

* A : async ID (for automatic async request handling)
* C : cookie sent with previous response flag {1}
* E : edit mode switch (read-only toggle) {0,1}
* G : RESERVED for GUID use
* L : logout requested {0,1,2}
* M : minimum indetification method (force authentication) {3,5}
* P : printable version request {1}
* R : auto-refresh time constant (seconds)
* S : session ID (replaces LP)
* U : RESERVED for User specification/emulation (potential bootstrapping)
* W-Z : RESERVED (for company-specific framework needs)
* ? : any other 1-letter variable name not listed is RESERVED for L7 future use!

* other variables:

* LP : license plate [DEPRECATED]
* MSGBOX : Message Box answer.

*** ========================================================= ***
DEFINE CLASS L7Page AS CUSTOM
*** IMPORTANT NOTE:
***   Many properties and methods below that were holding response-building state
***   are DEPRECATED and are being replaced by L7ResponsePieces (in L7ResponseManager.prg)
*** 
  * Keep out of debugInfo:
  PROTECTED Parent, ParentClass, WhatsThisHelpId, Top, Left, Height, Width, Picture, Tag, Comment

  cNextID = 0  && for generating unique IDs attributes across all elements in a page -- see access method
  
  * Reference to "parent" generating application object:
  oApp                 = NULL

  * Values used in <head> section of response:
  cTitle               = NULL  && NULL means inherit from app
  cSubTitle            = ""
  cGenerator           = "L7 Framework for VFP"
  cAuthor              = ""
  cCopyright           = ""
  cKeywords            = ""
  cDescription         = ""
  cFavicon             = ""
 
  cTemplateExpanderClass = "L7ExpandTemplate"  && bridge pattern
  
  * HTTP header and response construction properties:
  lIncludeHttpHeader   = .T.
  oHttpHeader          = NULL
  cHTTPHeaderClass     = "L7HTTPHeader"
  oHead                = NULL
  cHeadElementClass    = "L7HeadElement"
  cPageLanguage        = "en"  && leads to: <html lang="en"> (see L7ResponseManager)

  * Frame/frameset properties:
  lFrameSet            = .F.  && FRAMESET pages need different handling
  cFrameSetAttributes  = ""   && attributes for <frameset>
  lFrame               = .F.  && flag for page being a FRAME in a set

  * Body element options:
  oBody                = NULL
  cDocType             = L7_DOCTYPE_LOOSE 
  lNoBodyTag           = .F.  && turn on to suppress addition of <body>..</body>
  cBackground          = ""   && image
  cBgColor             = ""   && DEPRECATED (CSS)
  cOnLoad              = ""   && JavaScript instruction
  cBaseFont            = ""   && DEPRECATED (CSS) [Ex: face="Arial" size=2]
  cBodyElementClass    = "L7PageElement"
  cBodyAttributes      = ""   && merge-able <body> tag attributes (also see ExpandTemplate)
  cBodyCssClass        = ""
  
  * Error handling properties:  
  lError               = .F.
  lErrorMsg            = .F.
  cErrorMessage        = ""  && show to user
  cErrorTitle          = "Error on Page"  && show to user
  **   cErrorInfo           = ""  && email to admin
  nErrorPageInfo       = L7_NONE          && in addition to App-level settings
  nErrorEmailInfo      = L7_NONE          &&    (see L7.H for values) 

  lPrintable           = .T.  && printable version of page allowed?
  lPrint               = .F.  && printable version of page requested?
  nMinimumRefresh      = -1   && minimum auto-refresh time in seconds (-1 = not allowed)
  nRefresh             = 0    && requested refresh time in seconds (0 = none)

*!*    * Color scheme properties:
*!*    oColorScheme         = NULL  && created in INIT
*!*    cColorSchemeClass    = "L7ColorScheme"
*!*    cColorSchemeName     = "American"

  cCssFile             = "http://www.cycla.com/software/l7/l7.css"    && eg, "thisapp.css"
  cJsFile              = "http://www.cycla.com/software/l7/l7Core.js" 
  
  cOutputFile          = ""

  oCurrent             = NULL
  lCancelled           = .F.
  lRedirected          = .F.
  lAuthRequired        = .F.  && Does page require authentication?
  lAuthenticate        = .F.  && Have we initiated authentication?

  lRendered            = .F.  && have we rendered yet?
  cResult              = ""   && pre-render container

  tNow                 = NULL    && Synchronized timestamp value. Set on each hit.
  nStartSeconds        = NULL
  nElapsedSeconds      = NULL    && see ACCESS method
  lDoNotLog            = .F.     && allows disabling logging for minor things like Pings

  oBrowser             = NULL
*!*    cBrowserClass        = "L7Browser"
*!*    cBrowserName         = "Mozilla/4.0 (compatible; MSIE 5.0; Windows NT; DigExt)"

  ****** Properties that had been in L7WCPage ******
  
  ** Total URL Management (TUM) properties:
  DIMENSION aBaseUrlParameters[1,3]  && populated by AddBaseUrlParameter method
  nBaseUrlParameters = 0
  cBaseURL         = ""  && base from which to add/modify parameters
  cBaseQueryString = ""  && see access method (also see GetBaseHiddenFormVars method)
  
  * Managed URLs (for developer convenience, see ReadQueryString() method):
  cUrlA = ""  && minimal QS parameters -- used for menus and navigation
  cUrlB = ""  && most like "current" URL -- for navigation within context of current page
  cUrlC = ""  && (rarely used) for special intra-page handling like sort orders (see MessageBox, for example)
  * DEPRECATED names: cUpUrl, cUrl, cDownUrl (handled with _access methods for right now)

  * Options for groking Home and Cancel "places" to send user when bad things happen:
  cTopPage     = "Home" && Override if your's is different.
  cTopUrl      = ""
  cCancelPage  = ""
  cCancelUrl   = ""

  * HTTP artifact paths:
  cStylePath    = "/L7/styles/"  && .CSS files
  cScriptPath   = "/L7/scripts/" && .JS files
  cImagePath    = "/L7/images/"  && .GIF files
  lWcPowerImage = .F.  && "Powered by Web Connection GIF"  && DEPRECATED
  *[[ Need L7 Image that is used by default in shareware mode.

  * Session-oriented properties:
  oSession        = NULL
  ** cSessionClass   = "L7Session"  && bridge pattern
  nSessionTimeout = NULL && Override of app-level setting.

  * Async processing properties:
  cAsyncID     = ""  && see CheckAsyncID()
  cAsyncClass  = "L7Async"  && bridge pattern
  
  * User Identification properties:
  *
  * These 4 flags control which types of user identification
  * schemes are used/supported by your application. In general,
  * you set these once for the application and don't change them
  * in individual pages. If a specific page has different requirements,
  * be it looser or stricter, you can use other properties, such as
  * "nMinIdentificationMethod" and "nMinLoginLevel" to alter behavior.
  *
  lUsesAuthentication      = .T.  && App uses Win authentication as #1 priority to identify users.
  lUsesPersistentCookies   = .F.  && App uses Persistent Cookies as #2 priority to identify users.
  lUsesTemporaryCookies    = .T.  && App uses Temporary Cookies as #3 priority to identify users.
  lUsesLicensePlates       = .T.  && App uses License Plates as a last resort.
  * NOTE: You can use any combination of the above flags.

  cUserIdentificationClass = "L7UserIdentifier" && bridge to strategy class
  nMinIdentificationMethod = L7_IDENTIFICATION_LICENSE_PLATE
  nIdentificationActual    = L7_NONE
  nMinLoginLevel           = L7_NONE  && L7_LOGIN_LOGGED_IN or L7_NONE
  lAutoAcceptNetworkUsers  = .F.  && Any network user is welcome and gets a user record.
  cLicensePlate            = ""   && Actual license plate value for user.
  lCookieSatisfiesLogin    = .F.  && Does existence of cookie == being logged in?
  lSingleLogin             = .T.  && Does authentication == being logged in?
  lShowLogin               = .F.  && Did we decide a login form should be displayed?
  lLoginFailure            = .F.  && set to TRUE by others when current login attempt failed 
  cLoginFailureMessage     = "User ID not found and/or incorrect password! (Note: Passwords are case-sensitive.)"

  * [See L7.H] Identification Methods are:
  * 1 = License Plate (URL)
  * 2 = Temporary Cookie
  * 3 = Persistent Cookie
  * 4 = [RESERVED]
  * 5 = NT Authentication (usage discouraged)

  * [[ This should be an app-level property:
  cUserClass   = "L7User"  && override this with your own class, if needed

  lLogoutRequested = .F.   && was a logout requested on this hit?
  lLoginRequested  = .F.   && was a new login specifically requested on this hit?

  cTemporaryCookieName  = "L7TEMPID"  && [[ was L7ID also ]]
  cPersistentCookieName  = "L7ID"  
  cTemporaryCookieValue = ""      
  cPersistentCookieValue = ""      
  lCookieAttempted      = .F.  && URL indicates cookie delivered on previous hit

  lProcessPage = .T.  && flag for continuing with page [PROTECTED?]

  * Specialized usage flags for developer convenience:
  lReadOnly    = .F.  && read-only user flag
  lEditMode    = .T.
  lAdding      = .F.  && flag for adding a new record (vs editing an existing one)

  PROTECTED nMessageBoxAnswer 
  nMessageBoxAnswer = -1  && see CheckMessageBox() and MessageBox() methods

  * Properties for saving/restoring environment:
  oEnvironment = NULL 
  lAutoCloseTables = .F. && flag determines whether push/pop is performed

  * Menu properties:
  oMenu               = NULL
  cMenuClass          = [L7Menu]  && bridge
  cCurrentMenuContext = []
  lRenderParentMenus  = .T.
  cMenuPath           = [main]
  
  * Auto-parsing:
  lParseContent  = .F.
  
  * Error-handling augmentation:
  lReturnHttpServerError = .T.
  
  PROTECTED cErrorMsgReturnMethod 
  cErrorMsgReturnMethod = ""
  cSystemMessageClass = "L7SystemMessage"  && bridge pattern for custom display of error messages

  * Special FW flag to enforce calls up the hierarchy:
  HIDDEN lBeforeProcessRequest_FW
  lBeforeProcessRequest_FW = .F.

  * JSON response properties
  oJsonContents = NULL
  
  * File handling properties (used by GetFileContents() method):
  cFileContents = ""  && set either this or next 2 for templates, etc.
  cFilePath     = ""
  cFileName     = ""
  lFileDownload = .F. && use octet-stream binary download response
  lFileTransmit = .F.
  
  cDLLName         = "wc.dll"  && in case you rename wc.dll (may be DEPRECATED)

  oArtifacts = NULL
  cArtifactsClass = "Collection"  && bridge

  oUrls = NULL
  cUrlsClass = "L7UrlCollection"  && bridge
  
  #IF .F.  && DEPRECATED names (to-be-deleted)
    cUpURL       = ""  && variation for up/out navigation (to higher places)
    cURL         = ""  && current URL, adjusted for framework requirements
    cDownURL     = ""  && variation for downward navigation (drilling, etc.)
    FUNCTION cUpUrl_ACCESS
      RETURN THIS.cUrlA
    ENDFUNC
    FUNCTION cUrl_ACCESS
      RETURN THIS.cUrlB
    ENDFUNC
    FUNCTION cDownUrl_ACCESS
      RETURN THIS.cUrlC
    ENDFUNC
  #ENDIF
 
  * --------------------------------------------------------- *
  function tNow_ACCESS  
    if vartype(m.Environ) = "O"
      return Environ.item("appManager.startTime")
    endif
    if isnull(this.tNow)
      this.tNow = datetime()  && not preferred--we're moving to stateless page processing
    endif
    return this.tNow
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION cNextID_ACCESS  && auto-incrementing property on each use
    * For general use anywhere. Just ask for Page.cNextID.
    THIS.cNextID = THIS.cNextID + 1 
    RETURN "L7Page_" + TRANSFORM(THIS.cNextID)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cTopUrl_ACCESS
    * ACCESS method for cCancelUrl property!
    DO CASE
    CASE NOT EMPTY( THIS.cTopUrl) 
      * Explicit URL has been dictated.
      RETURN THIS.cTopUrl
    OTHERWISE  
      * Nothing explicitly set, so return them to Top Page.
      RETURN StuffURL( THIS.cUrlA, 1, THIS.oApp.cActivePageExtension, ;
        2, THIS.cTopPage)
    ENDCASE
  ENDFUNC  && cTopUrl_ACCESS
  * --------------------------------------------------------- *
  FUNCTION cCancelUrl_ACCESS
    * ACCESS method for cCancelUrl property!
    DO CASE
    CASE NOT EMPTY( THIS.cCancelUrl) 
      * Explicit URL has been dictated.
      RETURN THIS.cCancelUrl
    CASE NOT EMPTY( THIS.cCancelPage)
      * Specific cancel page has been set as a property.
      RETURN StuffURL( THIS.cUrlA, 1, THIS.oApp.cActivePageExtension, ;
        2, THIS.cCancelPage)
    OTHERWISE  
      * Nothing explicitly set, so return them to Top Page.
      RETURN StuffURL( THIS.cUrlA, 1, THIS.oApp.cActivePageExtension, ;
        2, THIS.cTopPage)
    ENDCASE
  ENDFUNC  && cCancelUrl_ACCESS
  * --------------------------------------------------------- *
  FUNCTION lProcessPage_ACCESS  
    RETURN THIS.lProcessPage AND NOT THIS.lError AND ;
      NOT (VARTYPE(THIS.oApp) = "O" AND THIS.oApp.lError) AND ;
      NOT THIS.lErrorMsg AND NOT THIS.lRedirected 
  ENDFUNC  
  * --------------------------------------------------------- *
*!*    FUNCTION cUserName_ACCESS && what was point of this??
*!*      * Access Method for cUserName property.
*!*      IF VARTYPE( THIS.oUser) = "O"
*!*        RETURN THIS.oUser.GetUserName()
*!*      ELSE
*!*        RETURN ""
*!*      ENDIF
*!*    ENDFUNC  && cUserName_ACCESS
*!*    * --------------------------------------------------------- *
  FUNCTION nElapsedSeconds_ACCESS
    RETURN MOD( SECONDS() - THIS.nStartSeconds, 86400 )
  ENDFUNC  && nElapsedSeconds_ACCESS
  * --------------------------------------------------------- *
  FUNCTION INIT(loApp)
    ** THIS.tNow = DATETIME() && deprecated--see access method to cover old code
    THIS.nStartSeconds = SECONDS()
    IF VARTYPE( m.loApp ) = "O"
    	THIS.oApp = m.loApp
    ENDIF

    THIS.oArtifacts = CREATEOBJECT(THIS.cArtifactsClass)
    THIS.oUrls = CREATEOBJECT(THIS.cUrlsClass)
    
    THIS.oHttpHeader = CREATEOBJECT(THIS.cHttpHeaderClass)  && bridge
    * HTTP header is created by default. Set property lIncludeHttpHeader
    * to false to kill off the output from this.

    THIS.oHead = CREATEOBJECT(THIS.cHeadElementClass) && bridge

    THIS.AfterINIT()
    THIS.SetupBrowserObject()

    #IF THIS_DEBUG_OBJECTS
    DEBUGOUT THIS.Name + " created."
    #ENDIF
  ENDFUNC  && INIT
  * --------------------------------------------------------- *
  FUNCTION AfterINIT
    DO StandardVfpSettings   && In L7Utils.PRG
    SET SAFETY OFF           && In case not standard!
    THIS.oEnvironment = CREATEOBJECT("L7Environment")
    WITH THIS.oEnvironment
      .lAutoCloseTables = THIS.lAutoCloseTables
      * Stores state of open tables and databases for closeout.
      .SaveState()  && RestoreState called on Destroy().
    ENDWITH
  ENDFUNC  && AfterINIT
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    THIS.GarbageCollect()
  ENDFUNC  && DESTROY
  * --------------------------------------------------------- *
  FUNCTION GarbageCollect
    * Garbage collection, etc. Called by DESTROY().
    * NOTE: If you override this, be sure to DODEFAULT()!!

    * This is just an object reference:
    THIS.oCurrent = NULL

    * Release any child Page Element objects:
    IF VARTYPE( THIS.oHttpHeader ) = "O"
      THIS.oHttpHeader.GarbageCollect()
      THIS.oHttpHeader = NULL
    ENDIF
    IF VARTYPE( THIS.oHead ) = "O"
      THIS.oHead.GarbageCollect()
      THIS.oHead = NULL
    ENDIF
    IF VARTYPE( THIS.oBody ) = "O"
      THIS.oBody.GarbageCollect()
      THIS.oBody = NULL
    ENDIF
    * Clear back link reference:
    THIS.oApp = NULL

*!*      THIS.oUser     = .F.
*!*      THIS.oTempUser = .F.

    THIS.oSession  = .F.
    THIS.oMenu     = .F.
    
    THIS.oArtifacts = NULL
    THIS.oUrls = NULL
    
    * This should always come last, in case any other objects
    * above affect the current environment while releasing:
    IF VARTYPE(THIS.oEnvironment) = "O"
      THIS.oEnvironment.RestoreState()
      THIS.oEnvironment = NULL
    ENDIF

    #IF THIS_DEBUG_OBJECTS
    DEBUGOUT THIS.Name + " destroyed."
    #ENDIF
  ENDFUNC  && GarbageCollect
  * ------------------------------------------------------------------- *
  PROCEDURE RELEASE
    THIS.GarbageCollect()
    RELEASE THIS
  ENDFUNC  && RELEASE
  * --------------------------------------------------------- *
  FUNCTION SetError(lcMessage, lcTitle, loException)
    THIS.lError = .T.
    THIS.cErrorMessage = THIS.cErrorMessage + m.lcMessage 
    IF VARTYPE(lcTitle) = "C" AND NOT EMPTY(m.lcTitle) 
      THIS.cErrorTitle = m.lcTitle
    ENDIF
    THIS.oApp.SetError(THIS.cErrorMessage, THIS.cErrorTitle, m.loException)
  ENDFUNC  && SetError
  * --------------------------------------------------------- *
  FUNCTION GetFileContents() 
  * DEPRECATED (here). See L7ResponsePieces class.
    WITH THIS
      DO CASE
      CASE NOT EMPTY(.cFileContents)
        RETURN .cFileContents
      CASE NOT EMPTY(.cFileName)
        LOCAL lcFile
        lcFile = IIF(EMPTY(.cFilePath), "", ADDBS(.cFilePath)) + .cFileName
        IF FILE(m.lcFile)
          RETURN FILETOSTR(m.lcFile)
        ELSE
          ERROR [File "] + m.lcFile + [" not found.]
          RETURN
        ENDIF
      OTHERWISE
        ERROR "No return file contents specified."
        RETURN
      ENDCASE
    ENDWITH
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetupBodyElement
    IF NOT THIS.lFrameSet
      THIS.oBody = THIS.CreateBodyElement() 
      THIS.oCurrent = THIS.oBody.CurrentOutputObject
    ELSE  && <FRAMESET>
      * For framesets we want to insert frame info only,
      * and make sure menus, content, etc., are not used:
      THIS.oBody = CREATEOBJECT("L7PageElement")
      THIS.oCurrent = THIS.oBody
    ENDIF
  ENDFUNC  && SetupBodyElement
  * --------------------------------------------------------- *
  FUNCTION CreateBodyElement
    * Factory that implements a Bridge pattern.
    * Note: If you have a single class that requires different
    *   body element classes depending on URL (or other request)
    *   parameters, such that this simple bridge doesn't handle
    *   your situation, you can also override *this* method and
    *   do something further. Just make sure you return an object
    *   that complies with L7BodyElement interface.
    LOCAL loObj
    loObj = CREATEOBJECT(THIS.cBodyElementClass)
    RETURN m.loObj
  ENDFUNC  && CreateBodyElement
  * --------------------------------------------------------- *
  FUNCTION SetupBrowserObject
    LOCAL loObj 
    if vartype(this.oApp) = "O"
      loObj = THIS.oApp.GetBrowserObject()
    else
      loObj = createobject("L7Browser") && no app--perhaps a test
    endif 
    THIS.oBrowser = m.loObj
    RETURN 


    *!*      THIS.oBrowser = CREATEOBJECT( THIS.cBrowserClass)
    *!*      IF NOT EMPTY(THIS.cBrowserName)
    *!*        * In an ISAPI subclass, set this property to empty, and then
    *!*        * call SetBrowser() later after the string is read.
    *!*        THIS.oBrowser.SetBrowser( THIS.cBrowserName)
    *!*      ENDIF
    *!*      * Note: You can call this method again to change browsers.

  ENDFUNC  && SetupBrowserObject
  * --------------------------------------------------------- *
  FUNCTION SetExpires(lvExpires, llReplace)
    * Can be called from response object or directly, thus allowing
    * support for ASP syntax Response.Expires.
    THIS.oHttpHeader.SetExpires(m.lvExpires, m.llReplace)
    * NOTE: To force a reload, another possibility is a META
    * tag for HTTP-EQUIV="pragma" CONTENT="no-cache".
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION ForceReload
    THIS.oHead.AddMetaHttpEquiv( "pragma", "no-cache" )
    THIS.oHttpHeader.AddHeader("Cache-Control", "no-cache") && added 12/16/2004
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ForceNoFrames
    THIS.oHead.AddMetaHttpEquiv( "Window-target", "_top" )
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderBodyTag
  * DEPRECATED (here). See L7ResponsePieces class.
    LOCAL lcBodyTag
    lcBodyTag = [<body] + IIF(EMPTY(THIS.cBodyAttributes), [], ;
      [ ] + THIS.cBodyAttributes)
    IF NOT EMPTY(THIS.cBodyCssClass)
      lcBodyTag = m.lcBodyTag + [ class="] + THIS.cBodyCssClass + ["]
    ENDIF
    IF NOT EMPTY(THIS.cBackground) AND ATC(" background=", m.lcBodyTag) = 0
      lcBodyTag = m.lcBodyTag + [ background="] + THIS.cBackground + ["]
    ENDIF
    IF NOT EMPTY(THIS.cBGColor) AND ATC(" bgcolor=", m.lcBodyTag) = 0
      lcBodyTag = m.lcBodyTag + [ bgcolor="] + THIS.cBGColor + ["]
    ENDIF
    IF NOT EMPTY(THIS.cOnLoad) AND ATC(" onload=", m.lcBodyTag) = 0
      lcBodyTag = m.lcBodyTag + [ onLoad="] + THIS.cOnLoad + ["]
    ENDIF
    lcBodyTag = m.lcBodyTag + [>] + CR
    IF NOT EMPTY( THIS.cBaseFont)
      lcBodyTag = m.lcBodyTag + [<basefont ] + THIS.cBaseFont + [>] + CR
    ENDIF
    #IF L7_SHAREWARE
      lcBodyTag = m.lcBodyTag + ;
        [<p style="margin: 0; border: 1px; background-color: orange; color: #333333; text-align: center; font-size: 11px; font-style: italic; font-weight: medium; font-family: Cursive;">] + ;
        [This page was produced by an unlicensed evaluation copy of The L7 Framework for Web Connection!] + ;
        [<br>Licensed copies can be attained from Cycla Corporation ] + ;
        [(<a href="mailto:L7@cycla.com">mailto:L7@cycla.com</a>).] + ;
        [</p>] + CR
    *[[TO DO: Revise this so all response assemblers will deal with shareware situation.
    #ENDIF
    RETURN m.lcBodyTag
  ENDFUNC
  * --------------------------------------------------------- *
  function CreateTransaction(lcType)
    * mostly, passthrough to app.CreateTransaction
    local loExc, loTrans
    try 
      if empty(m.lcType) && if no name passed, build one from page name
        lcType = this.Class
        lcType = substr(m.lcType, 1 + at("_", m.lcType))  && remove app prefix, if applicable
      endif 
      loTrans = this.oApp.CreateTransaction(m.lcType)
      if vartype(m.CurrentUser) = "O" AND CurrentUser.IsReadOnly()
        loTrans.lReadOnlyUser = .T.  && can set .lAllowReadOnlySave for specific transactions
      endif  
    catch to loExc
    endtry 
    if vartype(loExc) = "O"
      if loExc.ErrorNo = 1098
        this.ErrorMsg("Cannot complete transaction at this time. " + loExc.Message)
      else 
        this.ErrorMsg("Cannot complete transaction at this time. " + loExc.Message)
      endif 
      return  
    endif 
    if vartype(loTrans) <> 'O'
      this.ErrorMsg("Cannot complete transaction at this time: Transaction object not created.")
      return  
    endif 
    return m.loTrans
  endfunc  && CreateTransaction
  * --------------------------------------------------------- *
  function AssertTransaction(lcViewList, lcUpdateGram, lcType)
    * Attempt transaction of specified views, and abort page creation
    * upon failure.
    local loTrans, lcMsg, llFail, llUpdateGram
    llUpdateGram = VARTYPE(m.lcUpdateGram) = "C"  && pass by reference
    loTrans = THIS.CreateTransaction(m.lcType)  && used to be direct class name: CREATE("GimTransaction")  
    loTrans.lAutoCloseViews = .T.
    if m.llUpdateGram
      loTrans.lWriteXmlupdategram = .T.
    endif 
    loTrans.AddCursors(m.lcViewList)
    if loTrans.Save()
      if m.llUpdateGram
        lcUpdateGram = loTrans.cXmlupdategram 
      endif 
    else 
      llFail = .T.
      lcMsg = loTrans.GetErrorInfo()
    endif 
    loTrans = NULL
    if m.llFail
      this.ErrorMsg( "Transaction failed", "Sorry, your changes could not be saved.", ;
        , , .T., m.lcMsg)
    endif 
    return !m.llFail
  endfunc && AssertTransaction
  * --------------------------------------------------------- *
  function AssertSave(loTrans)
    * Attempts save using existing transaction, and aborts page processing 
    * (via ErrorMsg) if save fails. Provides single-line handling of transaction logging/messaging. 
    local lcMsg, llFail
    if loTrans.Save()
    else 
      llFail = .T.
      lcMsg = loTrans.GetErrorInfo()
    endif 
    if m.llFail
      this.ErrorMsg( "Transaction failed", "Sorry, your changes could not be saved.", ;
        , , .T., m.lcMsg)
    endif 
    return !m.llFail
  endfunc  && AssertSave
  * --------------------------------------------------------- *
  FUNCTION SSLCheck
    IF THIS.lSSLRequired
      IF THIS.SSLAvailable()
        IF NOT Request.IsLinkSecure()
          RETURN .F.
        ENDIF 
      ENDIF
    ENDIF
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SSLAvailable
    RETURN goL7AppManager.oConnector.nSslPort > 0  && SSL available (INI setting)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ForceSSL
    LOCAL lcHeading, lcBody, lcUrl
    lcHeading = "Secure Protocol Required"
    TEXT TO lcBody NOSHOW PRETEXT 3
      <p>For privacy or security reasons, this page requires the
      HTTPS secure protocol. Follow the link below. </p>
    ENDTEXT
    lcUrl = Request.GetRelativeSecureLink(THIS.cUrlB)  && was THIS.cUrl
    THIS.StandardPage(m.lcHeading, m.lcBody, , , m.lcUrl)
    RETURN
  ENDFUNC 
  * --------------------------------------------------------- *
  * [[ Can the next 6 functions move up to L7App?
  * [[ Shouldn't most/all of the next 6 methods inject App_Log messages of their own?
  * --------------------------------------------------------- *
  FUNCTION NotFound(lcMsg)  && 404 Responses
    WITH THIS
      * .lError = .T.
      .lProcessPage = .F.
      .oApp.cActiveResponse = "FileResponse"  && "StandardResponse"
      .oHTTPHeader.cStatus = "404 Not Found"
      .oHTTPHeader.cContentType = "text/plain"
      
      lcMsg = EVL(m.lcMsg, '404 Not Found')
      .cFileContents = m.lcMsg  && avoids need for disk presence

      .App_Log(L7_SEVERITY_INFO, "Not Found (404) response: " + m.lcMsg)

      * HTML was not needed or always appropriate
      
      *!*        .oHTTPHeader.cStatus = "404 Not Found"

      *!*        .oHead = NULL  && release what we have so far
      *!*        .oHead = CREATEOBJECT("L7HeadElement")
      *!*        .oHead.cTitle = '404 Not Found'
      *!*        .oBody = NULL  && release what we have so far
      *!*        .oBody = CREATEOBJECT("L7PageElement")
      *!*        lcMsg = EVL(m.lcMsg, '404 Not Found')
      *!*        IF m.lcMsg <> '<'
      *!*          lcMsg = '<h1>' + m.lcMsg + '</h1>' + CRLF
      *!*        ENDIF
      *!*        WITH .oBody
      *!*          .cTag = 'body'
      *!*          .Write(m.lcMsg)
      *!*        ENDWITH

    ENDWITH
    RETURN 
  ENDFUNC && NotFound
  * --------------------------------------------------------- *
  function Conflict(lcMsg)  && 409 Responses
    with this
      * .lError = .T.
      .lProcessPage = .F.
      .oApp.cActiveResponse = "FileResponse"
      .oHTTPHeader.cStatus = "409 Conflict"
      .oHTTPHeader.cContentType = "text/plain"
      
      lcMsg = EVL(m.lcMsg, '409 Conflict')
      .cFileContents = m.lcMsg  && avoids need for disk presence
      
      .App_Log(L7_SEVERITY_INFO, "Conflict (409) response: " + m.lcMsg)
    endwith 
    return   
  endfunc && Conflict
  * --------------------------------------------------------- *
  function Locked(lcMsg, tnRetryMS, tcRetryName)  && 423 Responses
    with this
      * .lError = .T.
      .lProcessPage = .F.
      .oApp.Locked(m.lcMsg, m.tnRetryMS, m.tcRetryName) && defer to app's (new) method
*!*        .oApp.cActiveResponse = "FileResponse"
      
*!*        .oHTTPHeader.cStatus = "423 Locked"
*!*        .oHTTPHeader.cContentType = "text/plain"
*!*        
*!*        lcMsg = EVL(m.lcMsg, '423 Locked')
*!*        .cFileContents = m.lcMsg  && avoids need for disk presence
*!*        
*!*        .App_Log(L7_SEVERITY_INFO, "Locked (423) response: " + m.lcMsg)
    endwith 
    return  
  endfunc  && Locked
  * --------------------------------------------------------- *
  FUNCTION BadRequest(lcMsg)  && 400 Responses
    WITH THIS
      * .lError = .T.
      .lProcessPage = .F.
      .oApp.cActiveResponse = "FileResponse"
      .oHTTPHeader.cStatus = "400 Bad Request"
      .oHTTPHeader.cContentType = "text/plain"
      
      lcMsg = EVL(m.lcMsg, '400 Bad Request')
      .cFileContents = m.lcMsg  && avoids need for disk presence

      * This one suggests a warning. The remainder could be planned by app circumstances,
      * so app should trigger any flag-raising log messages.
      .App_Log(L7_SEVERITY_WARNING, "Bad Request (400) response: " + m.lcMsg)
    ENDWITH
    RETURN 
  ENDFUNC && BadRequest
  * --------------------------------------------------------- *
  function Forbidden(lcMsg)  && 403 Responses
    with this
      .lProcessPage = .F.
      .oApp.Forbidden(m.lcMsg) && defer to app's (new) method

      .oApp.cActiveResponse = "FileResponse"
*!*        .oHTTPHeader.cStatus = "403 Forbidden"
*!*        .oHTTPHeader.cContentType = "text/plain"
*!*        
*!*        lcMsg = EVL(m.lcMsg, '403 Forbidden')
*!*        .cFileContents = m.lcMsg  && avoids need for disk presence

*!*        .App_Log(L7_SEVERITY_INFO, "Forbidden (403) response: " + m.lcMsg)
    endwith 
    return   
  endfunc  && Forbidden
  * --------------------------------------------------------- *
  FUNCTION Gone(lcMsg)  && 410 Responses
    WITH THIS
      * .lError = .T.
      .lProcessPage = .F.
      .oApp.cActiveResponse = "FileResponse"
      .oHTTPHeader.cStatus = "410 Gone"
      .oHTTPHeader.cContentType = "text/plain"
      
      lcMsg = EVL(m.lcMsg, '410 Gone')
      .cFileContents = m.lcMsg  && avoids need for disk presence

      .App_Log(L7_SEVERITY_INFO, "Gone (410) response: " + m.lcMsg)
    ENDWITH
    RETURN 
  ENDFUNC && Gone
  * --------------------------------------------------------- *
  function ServerError(lcMsg)  && 500 Responses
    with this
      * .lError = .T.
      .lProcessPage = .F.
      .oApp.cActiveResponse = "FileResponse"
      .oHTTPHeader.cStatus = "500 Internal Server Error"
      .oHTTPHeader.cContentType = "text/plain"
      
      lcMsg = EVL(m.lcMsg, '500 Internal Server Error')
      .cFileContents = m.lcMsg  && avoids need for disk presence
      
      .App_Log(L7_SEVERITY_INFO, "ServerError (500) response: " + m.lcMsg)
    endwith 
    return  
  endfunc  && Locked
  * --------------------------------------------------------- *
  FUNCTION Unavailable(lcMsg)  && 503 Responses
    WITH THIS
      * .lError = .T.
      .lProcessPage = .F.
      .oApp.cActiveResponse = "FileResponse"
      .oHTTPHeader.cStatus = "503 Unavailable"
      .oHTTPHeader.cContentType = "text/plain"
      
      lcMsg = EVL(m.lcMsg, '503 Unavailable')
      .cFileContents = m.lcMsg  && avoids need for disk presence

      .App_Log(L7_SEVERITY_INFO, "Unavailable (503) response: " + m.lcMsg)
    ENDWITH
    RETURN 
  ENDFUNC && Gone
  * --------------------------------------------------------- *
  FUNCTION OK(lcMsg)  && 200 OK - direct plain/text Responses
    WITH THIS
      .lProcessPage = .F.
      .oApp.cActiveResponse = "FileResponse"
      .oHTTPHeader.cStatus = "200 OK"
      .oHTTPHeader.cContentType = "text/plain"
      
      lcMsg = EVL(m.lcMsg, '200 OK')
      .cFileContents = m.lcMsg  && avoids need for disk presence

      .App_Log(L7_SEVERITY_INFO, "OK (200) direct response: " + m.lcMsg)
    ENDWITH
    RETURN 
  ENDFUNC && OK
  * --------------------------------------------------------- *
  FUNCTION Moved(lcUrl)  && 301 Moved Permanently
    with this
      .lRedirected = .T.
      .lProcessPage = .F.  
      .oApp.cActiveResponse = "FileResponse"
      .oHTTPHeader.cRedirectUrl = m.lcUrl
      .oHTTPHeader.cStatus = "301 Moved Permanently"
      .oHTTPHeader.cContentType = "text/plain"

      .cFileContents = '301 Moved Permanently: ' + m.lcUrl && avoids need for disk presence

      .App_Log(L7_SEVERITY_INFO, "Moved (301) response: " + m.lcUrl)
    endwith 
    return
  * --------------------------------------------------------- *
  * [[ long-term, switch this to 303 See Other
  FUNCTION Redirect(lcUrl)  && 302 Moved Temporarily (comp w/ Moved())
    with this
      .lRedirected = .T.
      .lProcessPage = .F.  && added 3/25/2010, like Forbidden(), etc.
      .oApp.cActiveResponse = "FileResponse"
      .oHTTPHeader.cRedirectUrl = m.lcUrl
      .oHTTPHeader.cStatus = "302 Moved"
      .oHTTPHeader.cContentType = "text/plain"

      .cFileContents = '302 Moved: ' + m.lcUrl && avoids need for disk presence

      .App_Log(L7_SEVERITY_INFO, "Moved (302) response: " + m.lcUrl)
    endwith 
    return
    
    * old L7Page code, should not be needed
    *!*  IF VARTYPE(THIS.oHead) = "O"
    *!*    THIS.oHead.lCancelled = .T.
    *!*  ENDIF
    *!*  IF VARTYPE(THIS.oBody) = "O"
    *!*    THIS.oBody.lCancelled = .T.
    *!*  ENDIF
  endfunc && Redirect
  * --------------------------------------------------------- *
  * [[ should this act more like the above 6 methods:
  function Authenticate(lcRealm)
    *[[TO DO: Revise this so all response assemblers will know how to handle!
    with this
      .lProcessPage = .F.  && added 3/25/2010, like Forbidden(), etc.
      .lAuthenticate = .T.
      .oHTTPHeader.lAuthenticate = .T.
      if NOT EMPTY( m.lcRealm)
        .oHTTPHeader.cAuthRealm = m.lcRealm
      endif 
      .App_Log(L7_SEVERITY_INFO, "Authentication response indicated" )

      if vartype(.oHead) = "O"
      .oHead.lCancelled = .T.
      endif 
      if vartype(.oBody) = "O"
        .oBody.lCancelled = .T.
      endif 
    endwith
    return 
  endfunc  && Authenticate
  * --------------------------------------------------------- *
  FUNCTION ExpandTemplate(lcFileName, llIsString, loHeadStrategy)
    * Framework-based expansion, intended to merge template aspects,
    * such as <head> section details and <body> tag attributes with
    * those of the framework and application. (See also the L7PageElement
    * method ExpandTemplateSnippet() for a different option.)
    
    * Delegate to another class that can be subclassed. (Keeps current class
    * simpler, and allows developers to modify how things like the <head>
    * section merging is done, because some HTML authoring tools could
    * present unique challenges there.
    LOCAL loExpander
    loExpander = CREATEOBJECT(THIS.cTemplateExpanderClass)  && bridge pattern
    WITH loExpander
      .lSafeTextmerge = .T.  && avoid recursion if nested elements use textmerge
      IF m.llIsString
        .cScript = m.lcFileName
      ELSE && it's a file name
        .cFileName = m.lcFileName
      ENDIF
      *!* .nHeadOptions = m.lnHeadOptions
      IF VARTYPE(m.loHeadStrategy) = "O"
        .oHeadStrategy = m.loHeadStrategy
      ENDIF
      *!* .nBodyTagOptions = m.lnBodyTagOptions
      .Expand()
    ENDWITH
  ENDFUNC  && ExpandTemplate
  * --------------------------------------------------------- *
  PROTECTED FUNCTION ValidateRequest
    * hook to block lProcessPage if request looks like a hack
    local lcQS, lcBadChars, llBad, lnSet, lcSet, lcParm, lcVal 
    lcBadChars = "<>"
    lcQS = Request.QueryString()
    for lnSet = 1 to getwordcount(m.lcQS, '&')
      lcSet = getwordnum(m.lcQS, m.lnSet, '&')
      lcParm = getwordnum(m.lcSet, 1, "=")
      if !empty(chrtran(m.lcParm, L7_WORD_CHARACTERS, ''))
        this.forbidden("Illegal QS parameter name")
        llBad = .t.
        exit
      endif
      lcVal = urldecode(getwordnum(m.lcSet, 2, "="))
      if !chrtran(m.lcVal, m.lcBadChars, '') == m.lcVal
        this.forbidden("Illegal QS value")
        llBad = .t.
      endif 
    next 
    
    return !m.llBad
  endfunc && ValidateRequest
  * --------------------------------------------------------- *
  FUNCTION ExecuteRequest
    * Main function called by L7 "application" object.
    * Sets up environment and calls application wrapper function
    * DoProcessRequest(), which in turn calls page-specific ProcessRequest()
    * function to produce the output.
    *
    * This hierarchy allows for creation of a consistent, yet
    * simple environment from the standpoint of the user's individual
    * page creation code/script. Object references are available either
    * through PRIVATE variables (referencable at all containership levels)
    * or Page object properties. These include:
    *
    * Request       : uniform reference to incoming (ISAPI/CGI) web request
    * Response      : reference to current Element of output (HTML) page
    * Page          : THIS object
    * Page.oApp     : L7 application object
    * Browser       : browser object (properties of user's agent)
    * Config        : same as Page.oApp.oConfig
    * Artifacts     : Page.Artifacts object (collection of ad-hoc items)

    LOCAL lcStr
    ** PRIVATE Response, Page, Config, Browser, Content, Session, Artifacts, URLs
    PRIVATE Response, Page, Config, Content, Session, Artifacts, URLs

    Page      = THIS
    ** Browser   = THIS.oBrowser
    Artifacts = THIS.oArtifacts 
    URLs      = THIS.oUrls
    Config    = THIS.oApp.oConfig
    Session   = NULL

*[[ TRY
    * Setup TUM. We need this established early so that ErrorMsg() 
    * functions have a base URL to build from if we abort page processing:
    if !this.validateRequest()
      this.lProcessPage = .f.
    else
      THIS.SetupBaseURL()  
      THIS.SynchronizeManagedUrls()
    endif
    
    IF THIS.lProcessPage
      * Setup Menu object (done early so other hooks can add items):
      THIS.CreateMenu()
      
      * Setup the browser object:
      ** THIS.cBrowserName = Request.cBrowser  (handled in App now)
      ** THIS.oBrowser.SetBrowser( THIS.cBrowserName )
      THIS.AfterDetermineBrowser()  && Hook to allow CSS settings, etc.

      * Determine User Identity via call to IdentifyUser():
      THIS.oSession = THIS.GetSessionObject()  && Note: This will lead to first of two session.reset()'s
      Session = THIS.oSession
      THIS.oSession.cClientCRC = THIS.oApp.getClientCRC()  && Request.cClientCRC
      THIS.oSession.cIpAddress = Request.cIpAddress

      if !vartype(m.CurrentUser) = 'O'
        * allows App to create instead...
        CurrentUser = this.InstantiateUser() && 06/22/2010
        TrueUser = CurrentUser
        * Note: Your app can achieve emulation by pointing CurrentUser at a different object
      endif
      
      * Check URL to see if a login or logout was requested:
      lcStr = this.StripUrl("L")  && "L" for logout
      if empty(m.lcStr) && no logout requested
        * = .F.
      else 
        do case 
        case m.lcStr == "0"
          this.lLogoutRequested = .T. && this should now force session not to be valid ever again
        case m.lcStr == "1"
          this.lLoginRequested = .T.
        case m.lcStr == "2"
          this.lLogoutRequested = .T. && ditto
          this.lLoginRequested = .T.
        endcase 
      endif
      
      * Check URL to see if a cookie was sent with previous page:
      lcStr = THIS.StripUrl("C")  && "C" for cookie
      IF m.lcStr = "1"
        THIS.lCookieAttempted = .T.  && flag this, so we can revert to LP's if user rejected cookie
      ENDIF
      * See if the URL is forcing an authentication level:
      lcStr = THIS.StripURL("M")
      IF NOT EMPTY( m.lcStr )
        lcStr = VAL( m.lcStr)
        IF INLIST( m.lcStr, L7_IDENTIFICATION_Persistent_COOKIE, L7_IDENTIFICATION_AUTHENTICATION)
          THIS.nMinIdentificationMethod = m.lcStr
        ENDIF
      ENDIF

      * User identity and login checks:
      IF THIS.BeforeIdentifyUser()  && hook for setting up anything needed before login
        THIS.lProcessPage = THIS.lProcessPage AND THIS.IdentifyUser()  && major routine that implements user identification settings
      ENDIF
      IF THIS.lShowLogin  && we decided in IdentifyUser that we need to present the login form
        THIS.OnShowLogin()  && hook to do stuff like turning off the menu, etc.
      ENDIF
      IF THIS.lProcessPage 
        *!* PRIVATE CurrentUser, TrueUser && these PRIVATE's now created in App--really??
        *|* CurrentUser = THIS.oUser
        *|* TrueUser = THIS.oUser
        * Note: Your app can achieve emulation by pointing CurrentUser
        * to a different user object. [Need KB topic on this.]
        IF NOT THIS.AfterIdentifyUser() && hook for security call, etc.
          THIS.lProcessPage = .F.
        ENDIF
      ENDIF  
    ENDIF

    IF THIS.lProcessPage
      ** Response = THIS.oCurrent
      THIS.FrameworkPreprocessRequest()
    ENDIF

    #IF L7_MONITOR_PROCESS
    LOCAL loProcMon
    loProcMon = goL7AppManager.oProcessMonitor
    m.loProcMon.BeforePageProcessRequest(THIS)
    #ENDIF
    
    IF THIS.lProcessPage
      * Now set Up and Down URLS equal to base. From here on they are managed
      * independently by the application code:
      THIS.SynchronizeManagedURLs()
      * Hook for your page to read (and strip items out of) the URL, etc:
      THIS.cErrorMsgReturnMethod = "ExecuteRequest"
      THIS.BeforeProcessRequest()
      THIS.cErrorMsgReturnMethod = ""
    ENDIF
    
    IF THIS.lProcessPage
      IF NOT THIS.lBeforeProcessRequest_FW
        ERROR "DODEFAULT() chain at BeforeProcessRequest hook did not reach framework."
      ENDIF
      
      * [Note: This had been in INIT, but experimenting with delay to here, so
      * class factory can respond to items determined in BeforeProcessRequest().]
      THIS.SetupBodyElement()
      Response = THIS.oCurrent
      
      * Set up error handling so, upon any error in the
      * developer's Page, we return to a framework method:
      THIS.cErrorMsgReturnMethod = "DoProcessRequest"
      ***************************************************************************
      THIS.DoProcessRequest()  && Implementation-level hook that calls individual pages.
      ***************************************************************************
      * Clear error return mechanism:
      THIS.cErrorMsgReturnMethod = ""

      THIS.AfterProcessRequest()
    ENDIF

    #IF L7_MONITOR_PROCESS
    m.loProcMon.AfterPageProcessRequest(THIS)
    #ENDIF

    *[[ Decide if we should make decision here based on Server.lAsyncHandler, or
    *   whether server will do that. (Expect server will.)
    
    this.oApp.DeliverOutput(this) && [[ remove (this) param once L7ResponsePieces takes over for page!
    * Note: app will ignore this if output already delivered, due to an alt response 
    
    * Log the request before we lose any user context info:
    * [Re-factor this to app can get user context. 
    if !this.lDoNotLog
      this.oApp.DoLogRequest()
    endif   

*!*  CATCH TO loExc WHEN VARTYPE(loExc.UserValue) = "O" AND loExc.UserValue.ErrorNo = L7_CUSTOMERROR_ERRORMSG
*!*    THIS.oApp.SetError(m.loExc.UserValue.ErrorDetail, "Page Error", m.loExc.UserValue)

*!*  CATCH TO loExc
*!*    THIS.oApp.SetError(m.loExc.Message, "Page Error", m.loExc)

*!*  FINALLY
*!*      RELEASE CurrentUser, TrueUser
*!*      IF VARTYPE( THIS.oUser ) = "O"
*!*        THIS.oUser.RELEASE()
*!*        THIS.oUser = NULL
*!*      ENDIF
*!*      IF VARTYPE( THIS.oTempUser ) = "O"
*!*        THIS.oTempUser.RELEASE()
*!*        THIS.oTempUser = NULL
*!*      ENDIF

    if vartype( this.oSession ) = "O" && now persistent as App member
      this.oSession.Reset() && Note: Second of two session.reset()'s -- conservative but OK.
      THIS.oSession = NULL
    endif 
    
*!*  ENDTRY
    return 
  endfunc   && ExecuteRequest
  * --------------------------------------------------------- *
  FUNCTION OffloadRequest
    #IF .F.
    * To implement in your page, use this code:
    IF THIS.OffloadRequest()
      RETURN
    ENDIF
    * ... processing code here
    #ENDIF
    
    IF Server.lAsyncHandler 
      RETURN .F.  && allow processing to continue
    ENDIF
    LOCAL loAsync, lcId, lcStatus, llCancel
    PRIVATE poAsync  && private, so a template can reference its properties
    poAsync = CREATEOBJECT(THIS.cAsyncClass)  && default is "L7Async"
    lcId = THIS.cAsyncID
    IF EMPTY(m.lcID)  && new request to place in queue
      poAsync.EnQueue(Request)
      lcStatus = "Queued"
    ELSE
      IF NOT poAsync.Locate(m.lcID)
        THIS.ErrorMsg("Invalid Request", "Asynchronous request not found.", ;
          ,, .T., "Async ID: " + m.lcId)
      ELSE && request located
        llCancel = THIS.StripUrl("cancel") = "yes"
        lcStatus = poAsync.GetStatus()
        IF m.llCancel AND INLIST(m.lcStatus, "Queued", "Running")
          IF poAsync.Cancel() && might not be able to
            lcStatus = "Cancelled"
          ENDIF
        ENDIF
        DO CASE
        CASE m.lcStatus = "Completed"
          *[[ return result page here
        CASE m.lcStatus = "Failed"
          *[[ show failure message and abort
        CASE m.lcStatus = "Cancelled"
          *[[ show cancel page here
        ENDCASE
      ENDIF
    ENDIF
    Response.ExpandTemplateSnippet(poAsync.cStatusTemplate)
    RETURN .T.
  ENDFUNC  && OffloadRequest
  * --------------------------------------------------------- *
  FUNCTION DoProcessRequest  && was named ProcessCaller, CallProcessRequest, ...
    * Please override me in your app-level sub-class!
    IF THIS.lProcessPage
      THIS.ProcessRequest()
    ENDIF
    IF NOT THIS.lErrorMsg AND NOT THIS.lError
      * Normal, post-script code.
    ENDIF
    RETURN 
  ENDFUNC  && DoProcessRequest
  * --------------------------------------------------------- *
  FUNCTION ProcessRequest
    * You override this method with the code that produces your
    * actual output. This is just here so you can add placeholder 
    * classes that return a graceful message until you get to 
    * the page in question.
    THIS.StandardPage( [Under Development!], ;
      [<p>This page is being developed. It is shown here so that ] + ;
      [the development team can verify that the hyperlinks are functioning ] + ;
      [correctly, while the page content development is in process.] )
    RETURN 
  ENDFUNC  && ProcessRequest
  * ---------------------------------------------------------- *
  FUNCTION AfterProcessRequest
  * ---------------------------------------------------------- *
  FUNCTION GetSessionObject()
    LOCAL loObj 
    loObj = THIS.oApp.GetSessionObject()
    IF NOT ISNULL(THIS.nSessionTimeout)  && override app setting
      loObj.OverrideTimeout(THIS.nSessionTimeout) 
    ENDIF
    RETURN m.loObj
  ENDFUNC
  * ---------------------------------------------------------- *
  function InstantiateUser
    ** THIS.oUser = CREATEOBJECT( THIS.cUserClass, THIS )
    return createobject(this.cUserClass)  && to be stored to CurrentUser private var
  endfunc  && InstantiateUser
  * ---------------------------------------------------------- *
  FUNCTION BeforeIdentifyUser
  * ---------------------------------------------------------- *
  FUNCTION IdentifyUser
    * Main framework function to combine possible
    * strategies for login and authentication.
    LOCAL llID
    THIS.AddObject("oUserIdentifier", THIS.cUserIdentificationClass)
    llID = THIS.oUserIdentifier.IdentifyUser()
    RETURN m.llID
  ENDFUNC  && IdentifyUser                 
  * ---------------------------------------------------------- *
  FUNCTION AfterIdentifyUser
  * ---------------------------------------------------------- *
  FUNCTION OnShowLogin
    * Developer Note: We've been testing some overrides to this.
    * Be certain framework considerations are extracted from that testing!! -rp {3/6/2007}
    * [[ see OpsClasses and iaSecurity PRGs!
    WITH THIS
      .SetupBodyElement()
      Response = .oCurrent  && debatable--login may need to look like a full page
      .lFrameset = .F.   && in case the URL is for a FRAMESET
      * NOTE: Login form is called before FrameworkPreprocessRequest,
      * thus we need to patch the URL with base parameters, in case
      * license plates were added, etc. by IdentifyUser!! {03/06/2007}
      .cUrlB = .ApplyBaseUrlParameters(.cUrlB)
      .cUrlB = StuffUrl(.cUrlB, "l", "1") && 10/12/07, the l=1 was getting removed prematurely

      .Confirm( ;
        TrueUser.LoginForm( .cUrlB, .cUserId ), ;
        "", ;
        "Please Log In" )
      * Note that we pass the URL so that the form "action"
      * setting reflects any license plate we've assigned here.
      * [[Could we not just send cBaseQueryString instead?]]
    ENDWITH
  ENDFUNC
  * --------------------------------------------------------- *
  * Special menu-oriented Page component. The idea here is
  * to make asynch calls to AddMenuItem(), passing several 
  * parameters. These items are stored and then rendered at the
  * end when all menu choices have been made.
  FUNCTION CreateMenu
    IF NOT EMPTY(THIS.cMenuClass)
      THIS.oMenu = NULL && in case we're clearing after an error
      THIS.oMenu = CREATEOBJECT(THIS.cMenuClass)
      * THIS.oMenu.AddMenuItem("main", .F.)
      THIS.oMenu.AddSubMenu("main", .F.)
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddNamedMenuItem(lcPath, lcPrompt, lcUrl, lcTooltip, lcLinkAtt)
    THIS.oMenu.AddNamedMenuItem(m.lcPath, m.lcPrompt, m.lcUrl, m.lcTooltip, m.lcLinkAtt)
  ENDFUNC
  * --------------------------------------------------------- *
  function AddMenuItem( lcMenuList, lcPrompt, lcUrl, lcTooltip, lvExcludePage, lcLinkAtt)
    if vartype( m.lvExcludePage ) = "L" AND m.lvExcludePage
      return
    endif 
    if vartype( m.lvExcludePage ) = "C" and !empty( m.lvExcludePage )
      if upper( m.lvExcludePage) == upper( this.oApp.cActivePage )
        * Specfically exclude menu item -- typically because it is a link to the current page!
        return 
      endif 
      if empty( m.lcUrl )
        lcUrl = StuffURL( THIS.cUrlA, 2, m.lvExcludePage )
      endif 
    endif 
    if empty( m.lcPrompt)
      lcPrompt = m.lcURL
    endif 
    if [,] $ m.lcMenuList
      this.oMenu.AddMenuItemMultiple(m.lcMenuList, m.lcPrompt, m.lcUrl, m.lcTooltip, m.lcLinkAtt)
    else 
      this.oMenu.AddMenuItem(m.lcMenuList,, m.lcPrompt, m.lcUrl, m.lcTooltip, m.lcLinkAtt)
    endif 
    return  
  endfunc  && AddMenuItem
  * --------------------------------------------------------- *
  function AddSubmenu(lcMenu, lcPrompt, lcUrl, lcTooltip, lcLinkAtt)
    * Backward compatibility.
    *THIS.AddMenuItem("main\" + m.lcMenu, .F., m.lcPrompt)
    this.oMenu.AddFolder("main\" + m.lcMenu, m.lcPrompt, m.lcUrl, m.lcTooltip, m.lcLinkAtt)
    return 
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION GetPageMenu(lcRenderClass)
    LOCAL loElem, loMenu
    loMenu = THIS.oMenu.GetItem("page")
    IF VARTYPE(m.loMenu) <> "O" OR loMenu.Count < 1
      RETURN ""
    ENDIF
    lcRenderClass = EVL(m.lcRenderClass, "L7HorizontalMenuBand")
    loElem = CREATEOBJECT(m.lcRenderClass)
    loElem.cCssPrefix = 'Page'
    loElem.SetMenuObject(m.loMenu)
    RETURN loElem.Render()
  ENDFUNC  && GetPageMenu
  * --------------------------------------------------------- *
  FUNCTION ReadOnlyCheck
    * Call this just before performing any save operations
    * to enable support for read-only users.
    IF THIS.lReadOnly  && set in AfterDetermineUser()
      THIS.ErrorMsg( "Read-Only Notice", THIS.ReadOnlyMessage() )
    ENDIF
    RETURN 
  ENDFUNC  && ReadOnlyCheck
  * --------------------------------------------------------- *
  FUNCTION ReadOnlyMessage
    * Override if your app has a more personal approach:
    RETURN [Note: You are currently set as a "read-only" user. ] + ;
      [Thus the data you submitted will not be saved. ] + ;
      [If your account had full privileges, the data would be saved and ] + ;
      [you would no longer see this message. Click OK to proceed.]
  ENDFUNC  && ReadOnlyMessage
  * --------------------------------------------------------- *
  function app_Log(tnSev, tcMsg, tcDetails)
    goL7App.app_Log(m.tnSev, m.tcMsg, m.tcDetails, THIS)  && delegate up to app service
    return 
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION StandardPage(lcHeader, lcBody, lvHeader, lnRefreshSeconds, lcGotoUrl )
    * Supplied for ease of migrating from standard 
    * Web Connection techniques.
    * [Adapter Design Pattern]
    * The "lvHeader" 3rd parameter is ignored!
    THIS.ErrorMsg( m.lcHeader, m.lcBody, m.lcGotoUrl, .F., .F., .F., m.lnRefreshSeconds )
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  * "Unconditional" abort of page processing:
  FUNCTION ErrorMsg( lcMsgTitle, lcMsgDetails, lcGotoUrl, lcAltReturn, ;
      llHack, lcHackInfo, lnRefreshSeconds )
      
    * 09/19/2004:  Major change wherein we assume hack/serious unless llHack passed as .F.
      
    * 1. Sets lErrorMsg flag to .T., which other parts of framework use.
    * 2. Abandons current template strategy and writes straight to BODY Element.
    * 3. Attempts to "RETURN TO" a good place (so no more processing of
    *    your own code is done). You can optionally override this by
    *    telling it where to RETURN (by passing lcAltReturn) or remove
    *    the behavior (by passing "" or NULL). If you do either, make sure you
    *    are manually checking THIS.lErrorMsg to avoid further processing.
    * 4. Writes passed heading and detailed message with CSS class names.
    * 5. If optional "hack" flag is passed (meaning your code suspects
    *    hacking if this error condition is found), sets flag in oApp
    *    object (which is handled after this page closes).
    * 6. If optional URL is passed, displays OK button with link after message.
    * 7. Display content approach can be altered by bridge pattern (see
    *    cSystemMessageClass property).
    IF VARTYPE( m.lcGotoUrl) <> 'C'
      lcGotoUrl = THIS.cCancelUrl
    ENDIF
    IF VARTYPE( m.lcMsgTitle) <> "C"
      lcMsgTitle = "A Problem Was Encountered!"
    ENDIF
    IF VARTYPE( m.lnRefreshSeconds) = "N" 
      THIS.oHead.SetRefresh( m.lnRefreshSeconds, m.lcGotoUrl )
    ENDIF
    IF PCOUNT() < 5 OR ISNULL(m.llHack)
      llHack = .T.  && Assume bad news.
    ENDIF
    IF VARTYPE(m.llHack) = "C" AND NOT EMPTY(m.llHack) && antequated--support for previous interface
      lcHackInfo = m.llHack
      llHack = .T.
    ENDIF
    *!*      * 08/22/2004: added textmerge()
    *!*      IF NOT EMPTY(m.lcHackInfo) AND "<<" $ m.lcHackInfo
    *!*        lcHackInfo = TEXTMERGE(m.lcHackInfo)
    *!*      ENDIF
    IF m.llHack
      THIS.oApp.SetHack(.T., m.lcHackInfo, m.lcMsgTitle, m.lcMsgDetails)
      
      *!*        THIS.oApp.lHack = .T.
      *!*        THIS.oApp.cHackInfo = THIS.oApp.cHackInfo + ;
      *!*          [Server: ] + Request.cServerName + [<br>] + CR + ;
      *!*          IIF( VARTYPE( m.lcMsgTitle) = "C", ;
      *!*            [Message title: ] + m.lcMsgTitle + [<br>] + CR, "") + ;
      *!*          IIF( VARTYPE( m.lcMsgDetails) = "C", ;
      *!*            [Message to user: ] + m.lcMsgDetails + [<br>] + CR, "") + ;
      *!*          IIF( VARTYPE( m.lcHackInfo) = "C", ;
      *!*            [Administrator info: ] + m.lcHackInfo + [<br>] + CR, "") + ;
      *!*          CR + ;
      *!*          L7ShowStackInfo() + CR + ;
      *!*          L7ShowObject( CurrentUser, "Current User Object Properties") 
    ENDIF

    THIS.lErrorMsg = .T.
    THIS.SetupErrorOutput()  && can be hooked

    LOCAL loMsg
    loMsg = CREATEOBJECT(THIS.cSystemMessageClass)
    WITH loMsg
      THIS.cSubTitle = m.lcMsgTitle
      .cMessageDetails = m.lcMsgDetails
      .cMessageGotoUrl = m.lcGotoUrl
      THIS.oCurrent.Write(.Render())
    ENDWITH
    loMsg = NULL
    
    THIS.AfterErrorMsg()  && hook 
    
    * Decide to where we should RETURN after the error:
    IF NOT ISNULL(m.lcAltReturn)
      IF VARTYPE( m.lcAltReturn) = "C"
        IF EMPTY( m.lcAltReturn)
          RETURN
        ELSE
          IF "." $ lcAltReturn
            lcAltReturn = SUBSTR( m.lcAltReturn, AT(".", m.lcAltReturn) + 1 )
          ENDIF
        ENDIF
      ELSE
        lcAltReturn = THIS.cErrorMsgReturnMethod
      ENDIF
      IF NOT EMPTY(m.lcAltReturn)
        RETURN TO &lcAltReturn
      ENDIF
    ENDIF
    RETURN
  ENDFUNC  && ErrorMsg
  * --------------------------------------------------------- *
  FUNCTION SetupErrorOutput
    THIS.oBody = NULL  && kills any current body
    THIS.cTitle = THIS.oApp.cTitle
    THIS.oBody = CREATEOBJECT("L7BodyElement") && plain element for receipt of error message
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AfterErrorMsg 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Assert( llCondition, lcMessage, lcGotoURL, llHack, lcHackInfo)
    * Checks if condition is true, and if not calls ErrorMsg, which
    * will abort the process. Must only be called at hooks when 
    * cErrorMsgReturnMethod is set.
    IF m.llCondition
      RETURN
    ELSE
      IF EMPTY(THIS.cErrorMsgReturnMethod)
        ERROR "Assertion failure without structured return point. Message was: " + ;
          TRANSFORM(m.lcMessage)
      ENDIF
      IF EMPTY( m.lcMessage )
        lcMessage = "Assertion failed. Access is denied!" 
      ENDIF
      IF VARTYPE( m.lcGotoUrl ) <> 'C'
        lcGotoUrl = THIS.cCancelUrl
      ENDIF
      THIS.ErrorMsg( "System Notice", m.lcMessage, m.lcGotoUrl, , llHack, lcHackInfo )
      * Put nothing after this line of code - no return from ErrorMsg!!
    ENDIF
    RETURN 
  ENDFUNC  && Assert
  * --------------------------------------------------------- *
  FUNCTION Confirm(lcMessage, lcGotoURL, lcAltTitle, lnRefreshSeconds)
    * Similar to Assert, except:
    * - no logical condition to check first
    * - text is placed within context of master page (w/ menus, etc)
    * - no hack checking
    * - subsequent code can continue, so use RETURN after it if you don't want this!
    * - allows auto-refresh to new URL to avoid redirection issues
    IF VARTYPE( m.Response) <> "O"
      * Allow to be called from IdentifyUser.
      PRIVATE Response
      IF VARTYPE(THIS.oCurrent) <> "O"
        * No current output object. Probably we're trying to write a
        * login screen before any page elements has been created.
        THIS.oBody = CREATEOBJECT("L7BodyElement")
        THIS.oCurrent = THIS.oBody
      ENDIF
      Response = THIS.oCurrent
    ENDIF

    IF EMPTY( m.lcMessage )
      lcMessage = "Changes were saved successfully!" 
    ENDIF
    IF VARTYPE( m.lcGotoUrl ) <> 'C'
      lcGotoUrl = THIS.cCancelUrl
    ENDIF
    IF VARTYPE( m.lcAltTitle) <> "C"
      lcAltTitle = "Confirmation Message"
    ENDIF
    IF VARTYPE( m.lnRefreshSeconds) = "N" 
      THIS.oHead.SetRefresh( m.lnRefreshSeconds, m.lcGotoUrl )
    ENDIF
    
    Response.Write( [<div id="Confirmation" align="center">] )

*!*      Response.Write( HTWrap( m.lcAltTitle, ;
*!*        'table,tr,td,font,b', ;
*!*        'align=center bgcolor="#FFFFFF" border=1,,,size=4' ) )
    THIS.cSubTitle = m.lcAltTitle

    Response.Write( '<p>' + ;
      HTWrap( m.lcMessage, 'P', 'align="center"' ) )

    IF NOT EMPTY( m.lcGoToUrl )
      THIS.cOnLoad = [l7FocusConfirmOKButton();]
      LOCAL lcJs
      lcJs = [<script language="JavaScript">] + CR + ;
            [function l7FocusConfirmOKButton()] + CR + ;
            [{] + CR + ;
            [  if (document.getElementById)] + CR + ;
            [  {] + CR + ;
            [    var loObj;] + CR + ;
            [    loObj = document.getElementById('l7ConfirmOKButton');] + CR + ;
            [    loObj.focus();] + CR + ;
            [  }] + CR + ;
            [}] + CR + ;
            [</script>] + CR 
      Response.Write( m.lcJs + ;
        L7BR+[<p align="center">] + ;
        [<a id="l7ConfirmOKButton" href="] + m.lcGotoUrl + [">] + ;
        [<img border="0" src="] + THIS.cImagePath + [ok.gif" alt="OK Button" />] + ;
        [</a>] )
    ENDIF
    Response.Write( [</div>] )
    RETURN 
  ENDFUNC  && Confirm
  * ---------------------------------------------------------- *
  FUNCTION ConfirmSave  && DEPRECATED
    * wrapper around Confirm() to allow user and app defaults
    LPARAMETER lcMessage, lcGotoURL, lcAltTitle, lnRefreshSeconds
    lcMessage = IIF( VARTYPE( m.lcMessage) = "C", m.lcMessage, ;
      THIS.cSaveConfirmationMessage) 
    IF VARTYPE(m.lnRefreshSeconds)<>"N"
      lnRefreshSeconds = 10
    ENDIF
    * Force auto-refresh:
    RETURN THIS.Confirm(m.lcMessage, ;
      m.lcGotoURL, "Saving...", m.lnRefreshSeconds)
  ENDFUNC  && ConfirmSave
  * --------------------------------------------------------- *
  FUNCTION GetApplicationSetting && DEPRECATED
    LPARAMETERS lcSetting, lcSection
    IF EMPTY( m.lcSection)
      lcSection = THIS.cApplication
    ENDIF
    RETURN Server.oApi.GetProfileString( ;
      Server.cAppIniFile, ;
      m.lcSection, m.lcSetting )
  ENDFUNC  && GetApplicationSetting
  * --------------------------------------------------------- *
  FUNCTION AfterDetermineBrowser
    * Application hook. Originally implemented for browser-specific 
    * CSS settings, but other uses are possible.
    * Simple Example:
    *!*  IF THIS.oBrowser.cMake = "Microsoft"
    *!*    THIS.cCssFile = "myApp_MSIE.css"
    *!*  ELSE
    *!*    THIS.cCssFile = "myApp_Mozilla.css"
    *!*  ENDIF
  ENDFUNC  && AfterDetermineBrowser
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupBaseURL

** SET STEP ON 
    * Sets initial values for cBaseUrl *and* cUrl properties.
    LOCAL lcPhysicalPath, lcLogicalPath, lcQueryString, lcConnectorFile
    * Read URL information from current request:
    lcPhysicalPath  = LOWER(Request.cPhysicalPathX)
    lcLogicalPath   = LOWER(Request.cLogicalPath)
    lcQueryString   = Request.QueryString()
    lcConnectorFile = goL7AppManager.oConnector.GetConnectorFile()

    * 01/06/2003 - added:
    lcQueryString = STRTRAN(m.lcQueryString, "&", AMPERSAND_ENCODED)
    * We will build content-based HREF's from this, so we need expanded
    * ampersand (&amp;) for W3C compliance. (Supposedly) browsers convert
    * this back before sending over HTTP. We'll see ...
    
    * Handle both old "wc.dll?..." syntax and (preferred)
    * extension mapping (a.k.a. "script mapping") syntax:
    DO CASE
    CASE LOWER(m.lcConnectorFile) $ m.lcPhysicalPath  && Explicit DLL call (antequated).
      IF NOT LOWER(m.lcConnectorFile) $ m.lcLogicalPath
        * DLL File not explicitly in URL, so
        * DLL must be the specified "default document".
        THIS.cBaseUrl = m.lcLogicalPath + THIS.oApp.cActivePage + ;
          "." + LOWER( THIS.oApp.cActivePageExtension) + "?"
        THIS.cUrlB = THIS.cBaseUrl
        * [NOTE: Above code forces a switch to extension mapping. This may cause
        * compatibility issues for people that cannot (or will not) use this. We 
        * should revisit this decision.]
        
      ELSE  && "WC.DLL" is in the URL. 
        DO CASE
        CASE EMPTY(m.lcQueryString)
          * If there is *no* query string, we got here due to some
          * default class assignment. Let's create a scriptmap 
          * equivalent URL as the basis to proceed.
          THIS.cBaseUrl = STRTRAN( m.lcLogicalPath, ;
            LOWER(m.lcConnectorFile), ;
            THIS.oApp.cActivePage + "." + LOWER( THIS.oApp.cPageExtension) + "?" )
          THIS.cUrlB = THIS.cBaseUrl
          * [NOTE: Above code forces a switch to extension mapping. This may cause
          * compatibility issues for people that cannot (or will not) use this. We 
          * should revisit this decision.]
        CASE NOT "~" $ m.lcQueryString
          * Full class name not referenced in the URL. I'm not so sure of
          * every reason why this might happen. Most likely only the app was
          * specified, and a default page approach is being used.
          THIS.cBaseURL = LOWER(m.lcConnectorFile) + "?" + LOWER(THIS.oApp.cPageExtension) + ;
            "~" + THIS.oApp.cActivePage 
          THIS.cUrlB = THIS.cBaseUrl
        OTHERWISE  && There is a full query string. 
          * Create cBaseUrl and cUrl differently:
          THIS.cBaseURL = LOWER(m.lcConnectorFile) + "?" + LOWER(THIS.oApp.cPageExtension) + ;
            "~" + THIS.oApp.cActivePage 
          THIS.cUrlB = LOWER(m.lcConnectorFile) + "?" + m.lcQueryString
        ENDCASE
      ENDIF
    CASE "." + LOWER(THIS.oApp.cActivePageExtension) $ m.lcLogicalPath
      * The URL is for a normal script map extension. This is the most common case!
      * Be sure it is adjusted to current class name, in case some default
      * names or URL-managing has taken place.
      THIS.cBaseURL = STRTRAN( m.lcLogicalPath, JUSTFNAME( m.lcLogicalPath ), ;
        LOWER(THIS.oApp.cActivePage) + "." + LOWER(THIS.oApp.cActivePageExtension)) + "?"
      THIS.cUrlB = THIS.cBaseURL + m.lcQueryString
    OTHERWISE  
      * Above didn't handle case where path was empty due to default document.
      THIS.cBaseURL = m.lcLogicalPath + THIS.oApp.cActivePage + "." + ;
        LOWER(THIS.oApp.cActivePageExtension) + "?"
      THIS.cUrlB = THIS.cBaseURL 
    ENDCASE
    * Do we need trailing "?"?  Let's try removing:
    RETURN 
  ENDFUNC  && SetupBaseURL
  * --------------------------------------------------------- *
  FUNCTION AddBaseUrlParameter(lcParm, lcValue, llBookmark)
    * Called internally to store framework-required query string 
    * parameters. Your app can call this too, for special needs,
    * by augmenting the FrameworkPreprocessRequest method.
    * NOTE: You must convert value to string before passing here.
    THIS.nBaseUrlParameters = THIS.nBaseUrlParameters + 1 
    DIMENSION THIS.aBaseUrlParameters[THIS.nBaseUrlParameters, 3]
    THIS.aBaseUrlParameters[THIS.nBaseUrlParameters, 1] = URLEncode(m.lcParm)
    THIS.aBaseUrlParameters[THIS.nBaseUrlParameters, 2] = URLEncode(m.lcValue)
    THIS.aBaseUrlParameters[THIS.nBaseUrlParameters, 3] = m.llBookmark
  ENDFUNC
  * --------------------------------------------------------- *
  *[[ Revisit this. Do we want to construct this on every request?
  *   Issue is how to guarantee value is in sync otherwise--say, if
  *   an extra item is added via AddBaseUrlParameter().
  FUNCTION cBaseQueryString_ACCESS
    LOCAL lcStr, ii
    lcStr = ""
    FOR ii = 1 TO THIS.nBaseUrlParameters
      lcStr = m.lcStr + AMPERSAND_ENCODED + ;
        THIS.aBaseUrlParameters[m.ii, 1] + ;
        [=] + THIS.aBaseUrlParameters[m.ii, 2]
    ENDFOR
    RETURN m.lcStr
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ApplyBaseUrlParameters(lcUrl, llBookmark)
    * Applies (adds as needed) base parameters to a passed URL.
    * Generally an internal method, but OK to call if needed.
    LOCAL ii
    FOR ii = 1 TO THIS.nBaseUrlParameters
      IF m.llBookmark AND NOT THIS.aBaseUrlParameters[m.ii, 3]
        LOOP
      ENDIF
      lcUrl = StuffUrl(m.lcUrl, THIS.aBaseUrlParameters[m.ii, 1], ;
        THIS.aBaseUrlParameters[m.ii, 2])
    ENDFOR
    RETURN m.lcUrl
  ENDFUNC  && ApplyBaseUrlParameters
  * --------------------------------------------------------- *
  FUNCTION GetBaseHiddenFormVars 
    * String to insert into method="get" form in order to preserve
    * framework state between requests. Usage should be rare!
    LOCAL lcStr, ii
    lcStr = ""
    FOR ii = 1 TO THIS.nBaseUrlParameters
      lcStr = m.lcStr + [<input type="hidden" name="] + ;
        URLDecode(THIS.aBaseUrlParameters[m.ii, 1]) + [" value="] + ;
        URLDecode(THIS.aBaseUrlParameters[m.ii, 2]) + [" />]
    ENDFOR
    RETURN m.lcStr
  ENDFUNC  && GetBaseHiddenFormVars
  * --------------------------------------------------------- *
  FUNCTION FrameworkPreprocessRequest
    * Called by Execute() just before BeforeProcessRequest is called,
    * to allow L7 Framework to operate on built-in URL parameters,
    * and remove them before tha application gets involved.
    *
    * Template method pattern.
    * Designed to allow a subclass to override the individual methods 
    * called below or to override this entire method.
    WITH THIS
      .CheckPrintable()     && p=1  check for printable version
      .CheckAutoRefresh()   && r=nn check for auto-refresh seconds
      .CheckEditMode()      && e=1/0 edit/read mode check
      .CheckMessageBox()    && messagebox() form submission
      .CheckAsyncID()       && pull async process ID off URL
    ENDWITH
    * Now apply noted parameters to critical URL proeprties:
    THIS.cBaseUrl = THIS.ApplyBaseUrlParameters(THIS.cBaseUrl)
    THIS.cUrlB    = THIS.ApplyBaseUrlParameters(THIS.cUrlB)
    THIS.SynchronizeManagedUrls()
    RETURN 
  ENDFUNC  && FrameworkPreprocessRequest
  * --------------------------------------------------------- *
  FUNCTION SynchronizeManagedUrls
    ** THIS.cBaseURL = THIS.cUrlB
    THIS.cUrlA = THIS.cUrlB
    THIS.cUrlC = THIS.cUrlB
    * Hook point: if you have your own names, call DODEFAULT, then add code.
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION BeforeProcessRequest
    * Hook that *must* call back up entire chain!
    THIS.lBeforeProcessRequest_FW = .T.
    RETURN 
  ENDFUNC  && BeforeProcessRequest
  * --------------------------------------------------------- *
  FUNCTION CheckEditMode
    * Designed to allow individual method override.
    IF THIS.oSession.IsValidSession()
      LOCAL lcEditSwitch
      lcEditSwitch = Request.QueryString("e")
      IF NOT EMPTY(m.lcEditSwitch) && it's in the URL (toggle mode)
        * Get it out of the URL and set the flag:
        THIS.cUrlB = StuffURL(THIS.cUrlB, "e", .F.)
        THIS.lEditMode = (m.lcEditSwitch = "1")
        THIS.oSession.SetSessionVar("editmode", IIF(THIS.lEditMode, '1', '0'))
      ELSE && not specified in URL, so fetch from session state:
        lcEditSwitch = THIS.oSession.GetSessionVar("editmode")
        IF EMPTY(m.lcEditSwitch) && not in session state either
          * default to whether user is known (goofy, but reasonable):
          lcEditSwitch = IIF(CurrentUser.IsAnonymous(), "0", "1")
        ENDIF
        THIS.lEditMode = m.lcEditSwitch = "1"
      ENDIF
    ENDIF
  ENDFUNC  && CheckEditMode
  * --------------------------------------------------------- *
  FUNCTION CheckPrintable
    * Designed to allow individual method override.
    LOCAL lcPrintable
    lcPrintable = Request.QueryString("p")
    IF NOT EMPTY(m.lcPrintable)
      THIS.cUrlB = StuffURL(THIS.cUrlB, "p", .F.)
      IF THIS.lPrintable AND m.lcPrintable = "1"
        THIS.lPrint = .T.
      ENDIF
    ENDIF
  ENDFUNC  && CheckPrintable
  * --------------------------------------------------------- *
  FUNCTION CheckAutoRefresh
    * Designed to allow individual method override.
    LOCAL lcRefresh, lnRefresh
    lcRefresh = Request.QueryString("r")
    IF NOT EMPTY( m.lcRefresh)
      lnRefresh = VAL( m.lcRefresh)
      THIS.cUrlB = StuffURL(THIS.cUrlB, "r", .F.)
      IF THIS.nMinimumRefresh >= 0  && refresh allowed
        IF m.lnRefresh = 0  && turn OFF refresh
          THIS.nRefresh = 0
        ELSE
          THIS.nRefresh = m.lnRefresh
        ENDIF
      ENDIF
    ENDIF
    IF THIS.nMinimumRefresh >= 0 AND THIS.nRefresh > 0
      IF THIS.nMinimumRefresh > 0 AND THIS.nRefresh > 0 AND ;
        THIS.nRefresh < THIS.nMinimumRefresh 
        *
        THIS.nRefresh = THIS.nMinimumRefresh 
      ENDIF
      THIS.oHead.SetRefresh(THIS.nRefresh)
    ENDIF
  ENDFUNC  && CheckAutoRefresh
  * --------------------------------------------------------- *
  FUNCTION CheckMessageBox
    LOCAL lcMB
    lcMB = UPPER( Request.Form( "msgBox"))
    IF NOT EMPTY( m.lcMB)
      DO CASE
      CASE m.lcMB = "OK"
        THIS.nMessageBoxAnswer = IDOK         && 1 - OK button pressed
      CASE m.lcMB = "CANCEL"
        THIS.nMessageBoxAnswer = IDCANCEL     && 2 - Cancel button pressed
      CASE m.lcMB = "ABORT"
        THIS.nMessageBoxAnswer = IDABORT      && 3 - Abort button pressed
      CASE m.lcMB = "RETRY"
        THIS.nMessageBoxAnswer = IDRETRY      && 4 - Retry button pressed
      CASE m.lcMB = "IGNORE"
        THIS.nMessageBoxAnswer = IDIGNORE     && 5 - Ignore button pressed
      CASE m.lcMB = "YES"
        THIS.nMessageBoxAnswer = IDYES        && 6 - Yes button pressed
      CASE m.lcMB = "NO"
        THIS.nMessageBoxAnswer = IDNO         && 7 - No button pressed
      OTHERWISE
        THIS.nMessageBoxAnswer = 0  && invalid
      ENDCASE
      IF VARTYPE(THIS.oSession) = "O" AND THIS.oSession.IsValidSession()
        * Get previous form vars off the stack:
        Request.cFormVars = THIS.oSession.PopFormVars()
      ENDIF
    ENDIF
  ENDFUNC  && CheckMessageBox
  * --------------------------------------------------------- *
  FUNCTION MessageBox( lcMessage, lnType, lcTitle)
    * Web approximation to messagebox() function.
    * See companion method CheckMessageBox() further below.
    IF THIS.nMessageBoxAnswer > 0
      * Indicates that user just answered the call and
      * the return value was pulled off the URL by CheckMessageBox().
      RETURN THIS.nMessageBoxAnswer
    ENDIF
    * Default to Yes/No:
    IF VARTYPE(m.lnType) <> "N"
      lnType = MB_YESNO
    ENDIF
    IF VARTYPE(THIS.oSession) = "O" AND THIS.oSession.IsValidSession()
      * Save any current form vars while we ask this question:
      THIS.oSession.PushFormVars( Request.cFormVars)
    ENDIF
    LOCAL lcMsg, lcBtn
    IF VARTYPE( m.lcMessage) = "C"
      lcMsg = m.lcMessage
    ELSE
      lcMsg = ""
    ENDIF
    lcBtn = ""
    IF INLIST( m.lnType, MB_OK, MB_OKCANCEL )
      lcBtn = m.lcBtn + [&nbsp;] + [<input class="MsgBox" type="submit" name="msgBox" value="OK" />]
    ENDIF
    IF INLIST( m.lnType, MB_YESNOCANCEL, MB_YESNO )
      lcBtn = m.lcBtn + [&nbsp;] + [<input class="MsgBox" type="submit" name="msgBox" value="Yes" />]
    ENDIF
    IF INLIST( m.lnType, MB_YESNOCANCEL, MB_YESNO )
      lcBtn = m.lcBtn + [&nbsp;] + [<input class="MsgBox" type="submit" name="msgBox" value="No" />]
    ENDIF
    IF INLIST( m.lnType, MB_ABORTRETRYIGNORE )
      lcBtn = m.lcBtn + [&nbsp;] + [<INPUT CLASS="MsgBox" type=submit name="msgBox" value="Abort" />] + ;
        [&nbsp;] + [<input class="MsgBox" type="submit" name="msgBox" value="Retry" />] + ;
        [&nbsp;] + [<input class="MsgBox" type="submit" name="msgBox" value="Ignore" />]
    ENDIF
    IF INLIST( m.lnType, MB_RETRYCANCEL )
      lcBtn = m.lcBtn + [&nbsp;] + [<input class="MsgBox" type="submit" name="msgBox" value="Retry" />]
    ENDIF
    IF INLIST( m.lnType, MB_OKCANCEL, MB_YESNOCANCEL, MB_RETRYCANCEL )
      lcBtn = m.lcBtn + [&nbsp;] + [<input class="MsgBox" type="submit" name="msgBox" value="Cancel" />]
    ENDIF
    IF EMPTY( m.lcTitle)
      lcTitle = "System Message"
    ENDIF
    Response.Write( [<div class="MsgBox">] + CR + ;
      [<h4 align="center">] + m.lcTitle + [</h4>] + CR + ;
      [<p align="center">] + m.lcMsg + [</p>] + CR + ;
      [<p align="center"><form method="post" action="] + THIS.cUrlC + [">] + ;
      m.lcBtn + [</form></p>] + CR + ;
      [</div>] + CR )
    * NOTE: We use "cUrlC" to allow intra-page option handling. 
    RETURN TO DoProcessRequest
  ENDFUNC  && MessageBox
  * --------------------------------------------------------- *
  FUNCTION CheckAsyncID
    LOCAL lcID
    lcID = Request.QueryString( "a")
    IF NOT EMPTY( m.lcID)
      THIS.cUrlB = StuffURL(THIS.cUrlB, "a", .F.)
      THIS.cAsyncID = m.lcID
      * Will be used later in OffloadRequest().
    ENDIF
  ENDFUNC  && CheckPrintable
  * --------------------------------------------------------- *
  FUNCTION StripURL(lcVar, llUpFlag, llThisFlag, llDownFlag, lvValidator)
    * RETAINED FOR BACKWARD COMPATIBILITY - use ReadQueryString() instead
    *
    * Strips a var=value pair from the current URL. Returns any value
    * that was there (or an empty string). Handy for settings that apply
    * to the current page, but should not be propogated to further pages.
    *
    * NOTE: If you want more than 3 managed URLs, you will need to override 
    * this method, as well as the SynchronizeManagedUrls method!
    *
    * Flags indicate which URLs should be left alone (ie, not stripped):
    *
    * llUpFlag   = .T. : don't strip from THIS.cUrlA (rare!)
    * llThisFlag = .T. : don't strip from THIS.cUrlB (frequent)
    IF PCOUNT() < 4 AND m.llThisFlag
      * If current url is preserved, lower one must be also.
      llDownFlag = .T.
    ENDIF
    RETURN THIS.ReadQueryString(m.lcVar, !m.llUpFlag, !m.llThisFlag, !m.llDownFlag, m.lvValidator)
  ENDFUNC  && StripURL
  * --------------------------------------------------------- *
  function ReadQueryString(lcVar, llStrip1, llStrip2, llStrip3, lvValidator)
    * Reads and returns value from a query string ("" if not present).
    * Optionally can strip same setting from any of 3 managed URLs.
    * Often called early in process, such as at BeforeProcessRequest() hook.
    *
    local lcValue, llOK, lcOKChrs, lcMsg
    * get the real value:
    lcValue = Request.QueryString( m.lcVar )
    lcMsg = ''
    do case
    case isnull(m.lvValidator)  && specific plea not to validate
      llOK = .t.
      
    case vartype(m.lvValidator) = "O"
      * an object, run its test() method [regEx compatible]
      if pemstatus(m.lvValidator, "test", 5)
        llOK = lvValidator.test(m.lcValue)
      else
        error "Query string validator lacks a Test() method"
      endif
    
    ** case vartype(m.lvValidator) = "C" and left(m.lvValidator, 1) = "=" && expr
    
    case vartype(m.lvValidator) = "C" and left(m.lvValidator, 1) = "^" && pattern
      llOK = L7RegexpTest(m.lcValue, m.lvValidator)
      
    case (vartype(m.lvValidator) = "L" and !m.lvValidator) ; && nothing passed--force default or
      or vartype(m.lvValidator) = "C" && assume it's an alt string of acceptable chars
      
      lcOKChrs = iif(vartype(m.lvValidator) = "C", m.lvValidator, L7_QS_CHARACTERS )
      llOK = empty(chrtran(m.lcValue, m.lcOKChrs, ""))
      if !m.llOK
        lcMsg = ' (code: ' + transform(256 - mod(asc(left(chrtran(m.lcValue, m.lcOKChrs, ""), 1)), 256)) + ')'
      endif 
    endcase
    
    if !m.llOK
      ** [[ this would be better, but L7App.error() needs to be ready...
      ** error "400:Invalid query characters"
      this.badRequest("Invalid query characters" + m.lcMsg)
      return ""
    endif
    
    * If OK, perform any requested strips from managed URLs:
    if !empty( m.lcValue )
      if m.llStrip1
        this.cUrlA = StuffURL(this.cUrlA, m.lcVar, .F. )
      endif 
      if m.llStrip2
        this.cUrlB = StuffURL(this.cUrlB, m.lcVar, .F. )
      endif 
      if m.llStrip3
        this.cUrlC = StuffURL( this.cUrlC, m.lcVar, .F. )
      endif 
    endif 
    return m.lcValue
  endfunc  && ReadQueryString
  * --------------------------------------------------------- *
  FUNCTION FullURL(lcUrl, lcForceProtocol, lcForceHostName)
    * Returns a full URL that can be referenced from outside.
    *[[ TO DO: Check port and if not 80/443, add :port to URL.
    lcUrl = IIF( EMPTY( m.lcUrl), THIS.cUrlB, m.lcUrl)
    lcForceProtocol = IIF( EMPTY( m.lcForceProtocol), ;
      IIF( Request.IsLinkSecure(), 'https', 'http'), ;
      STRTRAN( m.lcForceProtocol, ':','') )
    lcForceHostName = IIF( EMPTY( m.lcForceHostName), ;
      Request.cServerName, ;
      STRTRAN( m.lcForceHostName + '/', '//', '/'))
    RETURN m.lcForceProtocol + "://" + m.lcForceHostName + m.lcUrl
  ENDFUNC  && FullUrl
  * --------------------------------------------------------- *
  FUNCTION IsAnonymousOK
    RETURN THIS.nMinLoginLevel < L7_LOGIN_IDENTIFIED
  ENDFUNC  && IsAnonymousOK                
  * --------------------------------------------------------- *
  FUNCTION InitAnonymousUser
  ENDFUNC  && InitAnonymousUser            
  * --------------------------------------------------------- *
  FUNCTION CreateForm(lcFormClass, lcAction)  && Factory Method pattern.
    LOCAL loForm
    loForm = CREATEOBJECT(evl(m.lcFormClass, "L7Form"))
    IF NOT EMPTY(m.lcAction)  && action value passed
      loForm.cAction = m.lcAction
    ELSE
      IF EMPTY(loForm.cAction)
        * No action assigned, set to THIS.cUrlB by default, so that
        * any stripped query string parameters are honored, and
        * any framework processing is included.
        loForm.cAction = THIS.cUrlB
      ENDIF
    ENDIF
    IF EMPTY(loForm.cCancelUrl) AND NOT EMPTY(THIS.cCancelUrl)
      loForm.cCancelUrl = THIS.cCancelUrl
    ENDIF
    RETURN loForm
  ENDFUNC  && CreateForm
  * --------------------------------------------------------- *
  FUNCTION ReadForm(loForm)
    * Orchestrate the reading of a form.
    * Allows clean handling if cancel/navigate is detected.
    loForm.DoEvents()
    IF loForm.WasCancelled()
      LOCAL lcReturn
      lcReturn = THIS.cErrorMsgReturnMethod
      RETURN TO &lcReturn
    ENDIF
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION RenderForm(loForm)
    * Orchestrate the rendering of a form.
    * [[ Ideas for this function: page-wide JavaScript collection, 
    * [[ finding first focus() candidate, etc.
    IF loForm.lFocusFirst
      IF NOT [focusFirst();] $ THIS.cOnLoad
        THIS.cOnLoad = THIS.cOnLoad + [focusFirst();]
      ENDIF
    ENDIF
    RETURN loForm.Render()
  ENDFUNC  && RenderForm
  * --------------------------------------------------------- *
  * NOTE: This is temporary code, which will be refactored in some
  * manner. Perhaps there will be a Memento with properties
  * and then you use/render as you wish.
  FUNCTION GetProcessingInfo
    LOCAL loElem, lcTxt
    loElem = CREATEOBJECT("L7ProcessingInfoElement")  && see below
    lcTxt = loElem.Render()
    RETURN m.lcTxt
  ENDFUNC    
  * --------------------------------------------------------- *
  FUNCTION GetJSONContents
  * DEPRECATED (here). See L7ResponsePieces class.
    LOCAL loExc, loJson, lcOut
    loJson = IIF(ISNULL(THIS.oJsonContents), CREATEOBJECT("Empty"), THIS.oJsonContents)
    try
      * What if contents are already a string?
      if vartype(m.loJson) = "C"
        lcOut = m.loJson  && assume it's already-serialized...should we check it?
      else 
        lcOut = L7JsonSerialize(m.loJson)
      endif 
    CATCH TO loExc
      lcOut = [{"Error": "error"}]  && placeholder
    ENDTRY 
    RETURN m.lcOut
  ENDFUNC 
ENDDEFINE  && L7Page

*** ========================================================= ***
DEFINE CLASS L7ErrorMsgException AS Exception
  ErrorNo = L7_CUSTOMERROR_ERRORMSG
  Message = "A Problem Was Encountered!"
  ErrorDetail = ""
  * --------------------------------------------------------- *
  FUNCTION INIT(lcDetails, lcTitle)
    THIS.ErrorDetail = m.lcDetails
    IF NOT EMPTY(m.lcTitle)
      THIS.Message = m.lcTitle
    ENDIF
  ENDFUNC
ENDDEFINE

*** ========================================================= ***
** [[ Totally antiquated class here!!
DEFINE CLASS L7ProcessingInfoElement AS L7PageElement
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    lcText = m.lcText + THIS.GetProcessingInfo()
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetProcessingInfo()
    LOCAL lcText, lcSecurityText
    lcText = ""
    WITH m.Page
      lcText = m.lcText + ;
        TTOC( .tNow) + L7BR + CR
      lcText = m.lcText + [Processing: ] + STR( .nElapsedSeconds, 6, 2) + [ sec.] + L7BR + CR
      IF VARTYPE( .oSession) = "O" AND .oSession.IsValidSession()
        lcText = m.lcText + CurrentUser.GetUserName() + ;
          " [" + TRANSFORM(.nIdentificationActual) + ;
          "," + TRANSFORM(.oSession.nHits) + "]" +L7BR + CR
*!*          IF VARTYPE( .oTempUser) = "O"
*!*            lcText = m.lcText + [(emulating ] + .oTempUser.GetUserName() + [)]+L7BR + CR
*!*          ENDIF
      ENDIF
      lcText = m.lcText + [Browser: ] + .oBrowser.cMake + " " + ;
        .oBrowser.cVersion + L7BR + CR
        
*!*        * Show cookie values and other security debugging info on page, if specified:
*!*        lcSecurityText = ""
*!*        IF NOT EMPTY( .cAuthenticatedUser )
*!*          lcSecurityText = m.lcSecurityText + [Auth: ] + .cAuthenticatedUser + L7BR + CR
*!*        ENDIF
*!*        IF NOT EMPTY( .cPersistentCookieValue )
*!*          lcSecurityText = m.lcSecurityText + [PC: ] + .cPersistentCookieValue + L7BR + CR
*!*        ENDIF
*!*        IF NOT EMPTY( .cTemporaryCookieValue )
*!*          lcSecurityText = m.lcSecurityText + [TC: ] + .cTemporaryCookieValue + L7BR + CR
*!*        ENDIF
*!*        IF NOT EMPTY( .cLicensePlate )
*!*          lcSecurityText = m.lcSecurityText + [LP: ] + .cLicensePlate + L7BR + CR
*!*        ENDIF
*!*        #IF L7_SECURITY_DEBUG_LEVEL > 0
*!*          lcText = m.lcText + m.lcSecurityText
*!*        #ELSE
*!*          lcText = m.lcText + [<!--] + m.lcSecurityText + [-->] + CR
*!*        #ENDIF

      lcText = m.lcText + .cErrorMessage

      *!*        IF NOT EMPTY( .cCopyright )
      *!*          lcText = m.lcText + [<!-- Copyright -->] + CR + .cCopyright + L7BR + CR 
      *!*        ENDIF
    ENDWITH
    RETURN m.lcText
  ENDFUNC  && GetProcessingInfo
  * --------------------------------------------------------- *
ENDDEFINE

#if .f.
12/30/2002 - Changed Release to GarbageCollect.
12/31/2002 - renamed various "layer" classes to use term "element" instead
01/24/2003 - added llReplace parameter to SetExpires(), see also change to l7httpHeader
04/10/2003 - merged with and retired L7WcPage;
           - migrated significant functionality (incl. error handling) to app-level
           - modified TUM to add ReadQueryString() method and cUrlA through cUrlC properties
05/08/2003 - added page.cNextID service for creating unique id="" attributes
           - added cJsFile, and pointed both CSS and JS to cycla.com by default (so they see something)
05/21/2003 - fixed naming: L7ShowStackInfo
07/08/2003 - Removed THROW from ErrorMsg() approach.
07/09/2003 - Changed all Request.GetXXX() to property references: Request.cXXX.
09/01/2003 - Added cPageLanguage property (defaults to "en").
09/03/2003 - Corrected ErrorMsg variable lcUrl to lcGotoUrl.
09/05/2003 - Added cBodyCssClass property.
10/02/2003 - Modified CreateForm() to allow action to be passed as 2nd parm.
10/22/2003 - referenced new constant L7_DOCTYPE_LOOSE
11/02/2003 - added support for "safe" textmerging (see L7Utils and L7ExpandTemplate, also)
12/03/2003 - revised AddSubMenu to allow adding submenus with URLs, etc.
12/05/2003 - moved translateLinks() code to L7parsers
12/31/2003 - refactored GetProcessingInfo() to its own L7PageElement subclass
           - retired ContentRow() in favor of using L7RecordElement objects
02/27/2004 - added oURLs property
11/24/2004 - lLoginFailure property added
12/16/2004 - added Cache-Control: no-cache for AddForceReload()
11/12/2005 - ExpandTemplate revised to allow <head> strategy object
05/31/2006 - TopUrl_Access and CancelUrl_Access, changed cPageExtension to cActivePageExtension (to allow * in former)
03/05/2007 - Removed browser object creation (now done at App level)
           - Revise IdentifyUser method to return a boolean response
           - Revise OnShowLogin to [re-]apply base URL parameters
#endif
#if .f. 

* Stateless Page Project notes.

* set this then examine debug window
addproperty(_screen, "_L7DebugPageState",.t.) 

* Properties with values noted at start:
  CAUTHOR 
  CBGCOLOR 
  CBODYCSSCLASS MenuContent
  CBODYELEMENTCLASS PrimisTablelessBody
  CCSSFILE .NULL.
  CGENERATOR 
  CIMAGEPATH /L7/images/
  CJSFILE 
  CLICENSEPLATE 
  CONLOAD 
  CSCRIPTPATH /L7/scripts/
  CSTYLEPATH /L7/styles/
  CSUBTITLE .NULL.
  CSYSTEMMESSAGECLASS PrimisSystemMessage
  CTEMPORARYCOOKIENAME PrimisID
  CTITLE .NULL.
  CTOPPAGE Home
  CUSERCLASS ImUser
  LAUTOACCEPTNETWORKUSERS .F.
  LAUTOCLOSETABLES .T.
  LCOOKIESATISFIESLOGIN .F.
  LSINGLELOGIN .T.
  LUSESAUTHENTICATION .F.
  LUSESLICENSEPLATES .T.
  LUSESTEMPORARYCOOKIES .T.
  NAME Im_home
  NIDENTIFICATIONACTUAL          0
  NMINIDENTIFICATIONMETHOD          0
  NMINIMUMREFRESH         -1
  NMINLOGINLEVEL          2
  NREFRESH          0
  NSESSIONTIMEOUT      10800
  NSTARTSECONDS      68486.605
  OAPP (Object)
  OARTIFACTS (Object)
  OBROWSER (Object)
  OENVIRONMENT (Object)
  OHEAD (Object)
  OHTTPHEADER (Object)
  OURLS (Object)
  TNOW 10/23/2010 07:01 PM

* Example of Values that changed during processing:

  CAUTHENTICATEDUSER set to: 
  CBASEURL set to: /imdb/home.imd?
  CBODYCSSCLASS changed to: ContentOnly
  CCOPYRIGHT set to: &copy;&nbsp;2010 by<br>Office of Pipeline Safety
  CTEMPORARYCOOKIEVALUE set to: 185173E7F16F4C26A03B56E48A63C378
  CURLA set to: /imdb/home.imd?
  CURLB set to: /imdb/home.imd?l=1
  CURLC set to: /imdb/home.imd?
  CUSERID set to: 
  LBEFOREPROCESSREQUEST_FW set to: .T.
  LDEBUGQUERIES set to: .F.
  LEDITMODE set to: .T.
  LFRAMESET set to: .F.
  LISLOGINPAGE set to: .T.
  LNOMENU set to: .T.
  LPROCESSPAGE set to: .F.
  LREADONLY set to: .F.
  LRENDERED set to: .T.
  LSHOWLOGIN set to: .T.
  LSSLREQUIRED set to: .T.
  LSTATELESSUSER set to: .F.
  NIDENTIFICATIONACTUAL changed to:          2
  OAPP cannot tell--accepting
  OARTIFACTS cannot tell--accepting
  OBODY set to: (Object)
  OBROWSER cannot tell--accepting
  OCURRENT set to: (Object)
  OENVIRONMENT cannot tell--accepting
  OHEAD cannot tell--accepting
  OHTTPHEADER cannot tell--accepting
  OMENU set to: (Object)
  OSESSION set to: .NULL.
  OURLS cannot tell--accepting

#endif
