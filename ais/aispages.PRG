* AisPages.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ========================================================= ***
define class aisPage as L7Page

  lUsesLicensePlates       = .T.  && App uses License Plates as a last resort.
  nMinIdentificationMethod = L7_NONE  && L7_IDENTIFICATION_LICENSE_PLATE (none allows crawlers)
  nIdentificationActual    = L7_NONE

  * security model props:
  lDeveloperRequired = .f.
  lAdminRequired = .f.
  lCoreOK = .t.
  lArtistOK = .t.
  
  * By default, any added page requires user be logged in. Override any for which this
  * is not the case by setting subclass property to L7_NONE:
  nMinLoginLevel =  L7_LOGIN_LOGGED_IN 
  lLoginPage = .F.

  cTopPage      = "Home"
  cCancelPage   = "Home"
  
  cFavicon = "http://knitthebridge.com/favicon.ico"

  cCssFile = null
  cJsFile  = null 
  
  cBodyElementClass = "aisBody"

  cArt = ""
  oArt = null
  lArtRequired = .f.

  cPnl = ""
  oPnl = null
  lPnlRequired = .f.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lArtRequired
      if empty(this.cArt)
        this.cArt = evl(this.cArt, this.StripUrl("art", .f., .t.))
      endif 
      if empty(this.cArt)  && Item required, but neither set nor found in URL.
        this.NotFound()
      else 
        this.VerifyArtist()
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyArtist(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cArt)
    loData = createobject("AisArtData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cArt
        this.oArt = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
  * --------------------------------------------------------- *
  function VerifyPanel(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cPnl)
    loData = createobject("AisPnlData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cPnl
        this.oPnl = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
  * --------------------------------------------------------- *
  function BeforeIdentifyUser()
    local llPageRequiresSession, llSessionRequired, llBlock, lcSessID, lcReason, lcSessUser, llLoggedIn, llReestablish, ;
      lcUrl, lcUsr_Id, loSession, loUser, ;
      loReg, loDevice, loPolicy

    * Objects governing device-virtual combinations:
    loDevice = Environ.item('app.client_device')   && loaded in app.determineBrowser
    
    llPageRequiresSession = this.nMinLoginLevel >= L7_LOGIN_LOGGED_IN  && does page require it?
    llSessionRequired = m.llPageRequiresSession && [[ why the 2nd var?
    this.App_Log(L7_SEVERITY_DEBUG, iif(m.llSessionRequired, upper(this.class) + " process requires a session.", "Process class does not require a session."))

    * Check if there is a valid session, irrespective of policy:
    with this
      loSession = .oSession
      loUser = CurrentUser 
  
      llBlock = .t.  && prevent framework default IdentifyUser() from running!
      lcUsr_Id = "--"
      
      * See if a session ID is present (check on every hit):
      lcSessID = loDevice.getSessionID()
      
      * If a session, see if valid:
      if empty(nvl(m.lcSessId,""))
        this.App_Log(L7_SEVERITY_DEBUG, "No session ID from client.")
      else
        this.App_Log(L7_SEVERITY_DEBUG, "Session ID from client: " + m.lcSessID)

        lcReason = ""
        if !loSession.FindLicensePlateSession(m.lcSessId, @lcReason)

          this.App_Log(iif(this.lLoginPage, L7_SEVERITY_DEBUG, L7_SEVERITY_INFO), ; && reduced level if re-logging-in
            "Invalid session: " + m.lcReason)
          
          * need to re-establish login here (403, redirect, etc)
          if m.llPageRequiresSession  && don't force this on login page itself.
            llReestablish = .t.
          endif 
                    
        else && session found
          * note: FindLicensePlateSession also updates the session hits/timestamp
          this.App_Log(L7_SEVERITY_DEBUG, "Server session is valid.")

          if .lLogoutRequested  && explicit request (vs. timeout-driven)
            * clear the login indication: 
            loSession.SetLoginStatus(.F.)
            this.App_Log(L7_SEVERITY_DEBUG, "Client just logged out.")
          endif 

          if loSession.LicensePlateIdentifiesUser()  

            lcSessUser = loSession.GetUserID() 
            environ.set('app.session_userID', m.lcSessUser)
            this.App_Log(L7_SEVERITY_DEBUG, "Session says User ID is: " + m.lcSessUser)  
            
            if loSession.IsLoggedIn() 
              this.App_Log(L7_SEVERITY_DEBUG, "Session says user is logged in.")
              if loUser.findUserByUserId(m.lcSessUser) 
                llLoggedIn = .t.
                Environ.set("app.currentUser.name", loUser.getUserName())
                Environ.set("app.currentUser.email", loUser.getEmailAddress())
              else
                this.App_Log(L7_SEVERITY_WARNING, "Could not find application user from session user!") && impossible?
              endif
            else
              this.App_Log(L7_SEVERITY_DEBUG, "Session says user is NOT logged in.")
            endif 
            if !m.llLoggedIn
              this.App_Log(L7_SEVERITY_DEBUG, "Anonymous context assumed.")
              loUser.InitAnonymousUser() 
              Environ.set("app.currentUser.name", "--anonymous--")
              Environ.set("app.currentUser.email", "")
            endif
            * else: presume impossible but should fail severely..
          endif

          .nIdentificationActual = L7_IDENTIFICATION_LICENSE_PLATE && [[ should be Environ setting, not page prop

          Environ.Set('app.session_id', m.lcSessId)
          lcSessUser = Session.GetUserId()
          Environ.Set('app.user_id', m.lcSessUser) && note: actual login ID, not entity key Usr_Id
          lcUsr_Id = loUser.getUserID()
          Environ.Set('app.usr_id', m.lcUsr_Id) 

          * See also: class _Login below for implementation of Login sequence. 

        endif && find LP
      endif && no session ID
      
      if !m.llLoggedIn 
        this.App_Log(L7_SEVERITY_DEBUG, "Anonymous context assumed.")
        loUser.initAnonymousUser() && maybe redundant, but safe
        Environ.set("app.currentUser.name", "--anonymous--")
        Environ.set("app.currentUser.email", "")
      else

        if loUser.isDeveloper()
          this.App_Log(L7_SEVERITY_DEBUG, "User is a DEVELOPER ")
        else
          if loUser.isAdministrator()
            this.App_Log(L7_SEVERITY_DEBUG, "User is an ADMINISTRATOR ")
          endif
        endif
      endif

      goWcServer.cExtraStatusInfo = trim(m.lcUsr_Id) + " [" + Request.cIPAddress + "]"
      
      * Enforce security policy if this page requires login:
      if !m.llLoggedIn and ( m.llSessionRequired or m.llReestablish )
      
        this.lProcessPage = .f.
        this.App_Log(L7_SEVERITY_DEBUG, "No login for page requiring sessions, aborting in lieu of login.")

        if !loDevice.IsWebBrowser 
          this.Forbidden("Login Required: no session")  
        else
          * Note: "classic" L7 would interpose a login form here instead by flagging this.lShowLoginForm
          lcUrl = StuffUrl(this.cUrlA, 2, "Login")  
          if upper(request.cMethod) = "GET" and !this.lLoginPage
            lcUrl = stuffUrl(m.lcUrl, "origreq", this.cUrlB) && attempt retention for redirect
          endif 
          this.redirect(m.lcUrl)
        endif
        
        return .f.  
        * Explicit RETURN is used to abort further code below from doing additional HTTP 
        * redirects or 403s. We've decided a login is needed right now, and don't want 
        * anything else to take precedence. Not ideal to RETURN, but...
      endif 
      
    endwith && this

    return !m.llBlock && .f. blocks the default IdentifyUser() approach
  endfunc && BeforeIdentifyUser
  * --------------------------------------------------------- *
  function DoProcessRequest
    local lcStr
    * Called by L7Page::Execute()
    this.cCopyright = [&copy;&nbsp;] + transform(year(date())) + [ by ] + THISAPP_ORG_NAME 

    * Set up "context" object, which holds security flags, etc:
    private poContext  && object to replace other private variables
    poContext = createobject('Empty')
    this.SetSecurityContext(poContext, CurrentUser)

    if this.lProcessPage
      if vartype(CurrentUser.oData) = 'O'
        lcStr = THIS.FullUrl(StuffUrl(this.cUrlA, 'artHome', 'art', CurrentUser.oData.Art_PK))
        this.App_Log(L7_SEVERITY_INFO, textmerge("User is [<<trim(CurrentUser.getUserName())>>, <<m.lcStr>>]"))
      endif 

      if this.lDeveloperRequired AND !poContext.lDeveloper
        this.App_Log(L7_SEVERITY_WARNING, "Non-developer hitting developer-only link")
        this.Forbidden("Function not available")  
        return .f.
      endif 

      if this.lAdminRequired AND !poContext.lAdmin
        this.App_Log(L7_SEVERITY_WARNING, "Non-admin hitting admin-only link")
        this.Forbidden("Function not available")  
        return .f.
      endif 

      if !THIS.SecurityCheck() 
        this.App_Log(L7_SEVERITY_WARNING, "Security block by SecurityCheck()", m.poContext)
        this.Forbidden("Function not available")  
        return .f.
      endif 
      
      if !poContext.lViewPage
        this.App_Log(L7_SEVERITY_WARNING, "Security block by lViewPage flag", m.poContext)
        this.Forbidden("Function not available")  
        return .f.
      endif 
      
      *!*        if !this.SSLCheck()  && see if SSL required/present
      *!*          this.ForceSSL()
      *!*          return .f.
      *!*        endif  

      this.DoMenus()  && template method below
      
      ****************************************************************** 
      if this.lProcessPage
        this.App_Log("Debug", "ProcessRequest initiated for class " + this.Class)
        this.ProcessRequest()  && <==== This is where all your work gets done! 
      endif 
      ****************************************************************** 
    endif  && ProcessPage
    return  
  endfunc  && DoProcessRequest
  * ----------------------------------------------------- *  
  function SetSecurityContext(loContext, loUser)
    
    * Called after:
    *   - user is identified
    *   - BeforeProcessRequest has bootstrapped request context
    * Called before:
    *   - DoMenus
    *   - ProcessRequest

    WITH m.loUser
      * Admin, Core ... and Anonymous:
      ADDPROPERTY(m.loContext, 'lDeveloper', .IsDeveloper())
      ADDPROPERTY(m.loContext, 'lAdmin',     m.loContext.lDeveloper or .IsAdministrator()) && developers are admins
      ADDPROPERTY(m.loContext, 'lCore',      m.loContext.lAdmin or .IsCore()) && admins are also core
      ADDPROPERTY(m.loContext, 'lArtist',    .IsArtist()) 
      ADDPROPERTY(m.loContext, 'lAnonymous', !loContext.lCore and !loContext.lArtist)
      
      * Flags that can be decorated at the page level:
      ADDPROPERTY(m.loContext, 'lViewPage', .T.)  && "Yes" unless determined otherwise.
      ADDPROPERTY(m.loContext, 'lEditPage', .F.)  && "No" unless determined otherwise.

      * Self:
      ADDPROPERTY(m.loContext, 'lThisPerson', .F.)   && self

    endwith 
    return   
  endfunc  && SetSecurityContext
  * ----------------------------------------------------- *  
  function SecurityCheck  
    * hook to set lViewPage, lEditPage and anything more.
    * precedes addDefaultMenu
    local llOK
    if this.nMinLoginLevel = L7_NONE  && users always need access to login form, for example
      return .t.
    endif

    with m.poContext
      llOK = ;
        .lAdmin ;
        or (.lCore and this.lCoreOK) ;
        or (.lArtist and this.lArtistOK) 
        
    endwith 

    return m.llOK
  endfunc && SecurityCheck  

  * --------------------------------------------------------- *
  function AfterDetermineBrowser
    * Framework hook. Set CSS here, etc.
    *!* this.lStatelessUser = this.oApp.lAllowStateless AND Browser.lCrawler
    this.SetCss()
    this.SetJs()
    return
  endfunc && AfterDetermineBrowser
  * --------------------------------------------------------- *
  function RenderBodyTag
    this.alterBodyProperties()
    return dodefault()
  endfunc 
  * --------------------------------------------------------- *
  function alterBodyProperties()
    this.cBodyCssClass = "server-override" 
    return 
  endfunc 
  * --------------------------------------------------------- *
  function CreateBodyElement
    local loObj
    loObj = dodefault()
    loObj.setClass("+" + lower(this.class))
    loObj.setClass("+" + config.cServerRole)
    return m.loObj
  endfunc 

  * --------------------------------------------------------- *
  FUNCTION SetupErrorOutput
    THIS.oBody = NULL  && kills any current body
    THIS.SetupBodyElement()
    THIS.CreateMenu()
    THIS.cTitle = THIS.oApp.cTitle
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  function SetCss  && defeat parent
    this.oHead.AddCssLink("../ktb-content/css/ktb-ais.css", "all")
    this.oHead.AddCssLink("../ktb-content/css/ktb-aisForm.css", "all")
    return  
  endfunc  
  * --------------------------------------------------------- *
  function SetJs
    * all files listed in cJsFile come before these:
    with this.oHead

      .AddJavaScript("", [../ktb-content/js/prototype-1.7.0.js]) && Prototype (./js/prototype-1.5.1.js)
      .AddJavaScript("", [../ktb-content/js/jquery-1.7.1.js])    && jQuery (./js/jquery-1.3.1.js)

      * jQuery conflict avoidance w/ Prototype; Use $ for Prototype, $j for jQuery
      .AddJavaScript([var $j = jQuery.noConflict();] + CRLF)
       
      * sortable (Prototype):
      .AddJavaScript("", [../ktb-content/js/sortTable.js]) && needs to come after conflict avoidance
      * L7 Core:
      .AddJavaScript("", [../ktb-content/js/l7CoreP.js]) && L7 Core (Prototype version)
      .AddJavaScript("", [../ktb-content/js/l7CoreJQ.js]) && L7 Core (jQuery version)
      
    endwith 
    return 
  endfunc     
  * --------------------------------------------------------- *
  function DoMenus 
    if !Environ.item['app.client_device'].IsWebBrowser
      return
    endif 
    this.AddMenuHeadings()
    this.AddDefaultMenu()
  endfunc 
  * ----------------------------------------------------- *  
  function AddMenuHeadings
    this.AddSubMenu("This", "THIS PAGE")
    this.AddSubMenu("Reports", "Listings")
    this.AddSubMenu("Navigate", "Navigate AIS")
    this.AddSubMenu("Links", "Links")
    this.AddSubMenu("Search", "Search")
    if poContext.lAdmin
      this.AddSubMenu("Admin", "Admin")
    endif
    this.AddSubMenu("User", "User")
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local lcMenu, lcLpInfo, lcForm
    lcMenu = "main\Navigate"
    this.addMenuItem(m.lcMenu, 'People', StuffUrl(this.cUrlA, 2, "ArtList", "flags", "core", "fields", "contact"))

    lcLpInfo = THIS.GetBaseHiddenFormvars() && sustains license plate, etc. for GET form
    
    lcForm = [<form style="margin:0;" method="get" action="] + StuffUrl(THIS.cUrlA, 2, "ArtList") + ;
      ["><input id="srch1" alt="Search string" type="text" name="srch1" size="16" maxlen="40" value="" onchange="this.form.submit();">] + ;
      m.lcLpInfo + ;
      [<br><input style="margin: 1px 0px 0px 0px;" name="btn" type="submit" value="Search People">] + ;
      [<input name="fields" type="hidden" value="contact,registry">] + ;
      [</form>]
    this.AddMenuItem("main\Search", m.lcForm, .t.)

    this.addMenuItem(m.lcMenu, 'Pieces and Railings', StuffUrl(this.cUrlA, 2, "PceList", "type", "Panels", "orphans", "1"))
    this.addMenuItem(m.lcMenu, 'Panels', StuffUrl(this.cUrlA, 2, "PnlList"))
    this.addMenuItem(m.lcMenu, 'Facilities', StuffUrl(this.cUrlA, 2, "FacList"))
    ** this.addMenuItem(m.lcMenu, 'Bridge Locations', StuffUrl(this.cUrlA, 2, "LocList"))
    this.addMenuItem(m.lcMenu, 'Dahntahn Locations', StuffUrl(this.cUrlA, 2, "LocList", "side", "Down"))
    this.addMenuItem(m.lcMenu, 'Uptahn Locations', StuffUrl(this.cUrlA, 2, "LocList", "side", "Up"))
    
    ** this.addMenuItem(m.lcMenu, 'About', StuffUrl(this.cUrlA, 2, "About"), "About")
    if poContext.lAdmin
      *!* this.addMenuItem("main\Admin", 'Refresh Content', StuffUrl(this.cUrlA, 2, "RefreshContent"))
    endif

    lcMenu = "main\Links"
    this.addMenuItem(m.lcMenu, 'KtB Webpage', "/")
    this.addMenuItem(m.lcMenu, 'KtB Blog', "http://knitthebridge.wordpress.com/")

    this.addMenuItem('main\User', 'My Account', StuffUrl(this.cUrlA, 2, 'ArtHome', 'art', CurrentUser.getUserKey()))
    this.addMenuItem('main\User', 'Sign Out', StuffUrl(this.cUrlA, 2, 'Login', 'l', '0'))

    dodefault()  && always chain upward
    return 
  endfunc  && addDefaultMenu
  * --------------------------------------------------------- *
enddefine && AisPage

*** ========================================================= ***
define class ais_Home as aisPage 
  ** nMinLoginLevel = L7_NONE  && users always need access to login form
  cSubTitle = "Home"
  * ----------------------------------------------------- *  
  function ProcessRequest
    Response.Write("Home page content goes here...")
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_About as aisPage 
  nMinLoginLevel = L7_NONE  
  cSubTitle = "About"
  * ----------------------------------------------------- *  
  function ProcessRequest
    Response.Write("About page content goes here...")
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_ThankYou as aisPage 
  nMinLoginLevel = L7_NONE  
  cSubTitle = "Thank You!"
  * ----------------------------------------------------- *  
  function ProcessRequest
    Response.Write(HTWrap("Knit the Bridge thanks you for signing up! We will contact you soon.", "p"))
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_Login as aisPage 
  cPage_OrigReq = ""
  lLoginPage = .t. 
  nMinLoginLevel = L7_NONE  && users always need access to login form
  * --------------------------------------------------------- *
  function beforeProcessRequest
    this.cPage_origReq = this.stripUrl("origreq", .f., .f., .t., L7_QS_CHARACTERS + L7_URL_PUNCTUATION_CHARACTERS)
    if !empty(this.cPage_origReq)
      this.App_Log(L7_SEVERITY_DEBUG, "Original request was: " + this.cPage_origReq)
    endif
    dodefault()
  endfunc 
  * --------------------------------------------------------- *
  function processRequest
    local loUser, loForm, loOut, lcSessId, lcUsrId, lcUrl, loDevice, loOneUser
    loUser = TrueUser
    
    loDevice = Environ.item('app.client_device')   && loaded in app.determineBrowser

    loForm = createobject("aisLoginForm")
    loForm.cAction = this.cUrlC  && hold the orig request
    
    loOut = createobject("Empty")
    addproperty(loOut, "success", .f.)

    with loForm
      .addControls()
      .doEvents()
      if .wasPosted()
        this.App_Log(L7_SEVERITY_DEBUG, "Login form POST detected")
        if loUser.JustLoggedIn(, m.loForm)

          lcUsrId = loUser.getUserId()
          this.App_Log(L7_SEVERITY_INFO, "Successful login for user: " + m.lcUsrId) 
          * add user ID and email to response, so app has both, no matter which login used: 
          addproperty(loOut, "usr_id", m.lcUsrId)
          addproperty(loOut, "usr_email", loUser.getEmailAddress())

          lcSessId = getGuidString(32)
          this.App_Log(L7_SEVERITY_DEBUG, "Session ID assigned: " + m.lcSessId)

          * All of following throw errors on failure:
          Session.NewLicensePlateSession(m.lcSessId, "LP")
          Session.SetUserId(m.lcUsrId)
          Session.SetLoginStatus(.t.)
          Session.SetUserInfo(m.loUser) && additional params set in session table 
          *!* Session.SetEnvironInfo()
          
          ** THIS.AddBaseUrlParameter("s", m.lcSessId)  && ensure usage in managed URLs
          THIS.cLicensePlate = m.lcSessId 

          Environ.Set('app.session_id', m.lcSessId)
          Environ.Set('app.user_id', m.lcUsrId) && note: actual login ID
          *!* Environ.Set('app.usr_id', loUser.getUserKey()) && usr_id entity key 
          
          loOut.success = .t.
          addproperty(loOut, "session_id", m.lcSessId)
          loDevice.NoteNewSession(m.lcSessId, this)

          * add full name, PK, and other key params to response:
          addproperty(loOut, "usr_full_name", loUser.getUserName())
          addproperty(loOut, "usr_fk", CurrentUser.oData.Art_PK)
          * add global flags so client can make assumptions of what server allows:
          addproperty(loOut, "is_developer", CurrentUser.isDeveloper())
          addproperty(loOut, "is_admin", CurrentUser.isAdministrator())

          Response.Write( HTWrap("Log In Successful!", 'h3'))
          if !empty(this.cPage_origReq)  && need to redirect
            lcUrl = this.cPage_origReq
          else
            lcUrl = stuffUrl(this.cUrlA, 2, 'Home')
          endif
          Response.Write( HTWrap("Redirecting to: " + HTLink(m.lcUrl), 'h3'))
          Response.Write( HTWrap(L7JsonSerialize(loOut), 'pre'))
          this.App_Log(L7_SEVERITY_DEBUG, "Redirecting to: " + m.lcUrl)

          THIS.oHead.SetRefresh(0, m.lcUrl )
          return

        else && login failed
          this.App_Log(L7_SEVERITY_DEBUG, "Message to user: " + this.cLoginFailureMessage)
          .cCustom_Message = Page.cLoginFailureMessage 
        endif && just logged in
        
      else  && not a POST
        if this.lLogoutRequested  && login with l=0
          this.cLoginFailureMessage = "No login because user logged out"
          this.App_Log(L7_SEVERITY_DEBUG, this.cLoginFailureMessage)
        else && not a logout
          this.cLoginFailureMessage = "Please log in"
          this.App_Log(L7_SEVERITY_DEBUG, "No login attempted")
        endif
      endif && posted
        
    endwith

    * applies both initially and upon UID/PW failure
    if not empty(this.cLoginFailureMessage)
      response.write(HTWrap(this.cLoginFailureMessage, 'h3'))
    endif
    response.write(loForm.Render())
    return

  endfunc
enddefine 


* end: AisPages

