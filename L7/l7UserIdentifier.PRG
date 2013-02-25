* L7UserIdentifier.PRG

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


*** ========================================================== ***
DEFINE CLASS L7UserIdentifier AS LINE
  cIdStrategy = "guid"
  cRealm = "/"
  * --------------------------------------------------------- *
  FUNCTION IdentifyUser
    WITH THIS.Parent  && page
      LOCAL llDecided, llIdentified, llShowLogin, llLoginRequired, llRetVal
      * llDecided       : flag of whether we made a decision
      * llIdentified    : flag of whether we figured out the user
      * llShowLogin     : flag of whether to display dialog
      * llLoginRequired : does this page require login
      llDecided       = .F.
      llIdentified    = .F.
      llShowLogin     = .F.  && 5/7/06, was: llShowLogin = .lLoginRequested
      llLoginRequired = .nMinLoginLevel >= L7_LOGIN_LOGGED_IN 
       
      * Easy references to collaborating objects:
      LOCAL loPage, loUser, loSession
      loPage    = THIS.Parent
      loUser    = CurrentUser  && [[fy11: .oUser
      loSession = Session && [[fy11: .oSession

      #IF L7_ENABLE_AUTHENTICATION
      * Move this up here, so we check authenticated name, 
      * even if we're not using authentication.
      .cAuthenticatedUser = Request.GetAuthenticatedUser()
      IF .lUsesAuthentication 
        * This application makes use of authentication (app-level setting).
        IF .T. 
          * [AuthenticationOK()] acceptable for this page
          * Read network user ID, if any (requires that basic authentication
          * be used on the web server under IIS):
          ** THIS.cAuthenticatedUser = Request.GetAuthenticatedUser() && [this is now done above]
          IF NOT EMPTY( .cAuthenticatedUser)  && User is already authenticated.
            .App_Log(L7_SEVERITY_DEBUG, "AUTH identification of use as: " + .cAuthenticatedUser)
            IF loUser.ValidateAuthenticatedUser( .cAuthenticatedUser) 
              * Network user is a recognized user of *this* app.
              llIdentified = .T.
              llDecided = .T.
              .nIdentificationActual = L7_IDENTIFICATION_AUTHENTICATION
            ELSE
              IF .lSingleLogin AND .lAutoAcceptNetworkUsers
                * Policy is to accept anyone validated on the network.
                IF loUser.CreateAuthenticatedUser( .cAuthenticatedUser )
                  llIdentified = .T.
                  llDecided = .T.
                  .nIdentificationActual = L7_IDENTIFICATION_AUTHENTICATION
                ENDIF
              ENDIF
            ENDIF
            IF m.llIdentified
              * We've identified the user via this method.
              .cUserId = loUser.GetUserId()
              IF NOT loSession.FindUserSession( .cUserId )
                loSession.NewUserSession( .cUserId )
              ENDIF

              * Determine if a login dialog is required:
              IF .lLogoutRequested AND NOT .lSingleLogin
                * Logout requested on this hit.
                loSession.SetLoginStatus( .F.)
              ENDIF
              
              DO CASE
              CASE .lSingleLogin
                * Nothing more to do, since the policy states
                * that a network login is all that's needed.
                loSession.SetLoginStatus( .T.)
              CASE loSession.IsLoggedIn()
                * User is already logged in.
              CASE loUser.JustLoggedIn( .cUserId )
                loSession.SetLoginStatus( .T.)
              CASE NOT m.llLoginRequired
                * This page does not care.
              OTHERWISE
                * Even though user is logged in on the network, a
                * separate application login is required by policy.
                llShowLogin = .T.
              ENDCASE
            ELSE  && unidentified network user
              * Could be network user with no business on this app.
              * We'll ignore the fact that they are authenticated, and
              * process them like any other anonymous user below.
            ENDIF
          ELSE
            * Do nothing here, since we decide later if we want to 
            * force authentication at this time.
          ENDIF  && user is authenticated
        ENDIF  && authentication is OK
      ENDIF  && app uses authentication
      #ENDIF

      * Persistent Cookie Strategy
      #IF L7_ENABLE_COOKIES
      IF !m.llDecided AND .lUsesPersistentCookies AND !EMPTY( .cPersistentCookieName )
        * We didn't decide about the user in the above code *and*
        * this application employs Persistent cookies as an option.
        IF .nMinIdentificationMethod <= L7_IDENTIFICATION_PERSISTENT_COOKIE
          * Persistent cookie is acceptable for this page.
          .cPersistentCookieValue = Request.GetCookie( .cPersistentCookieName )
          IF !EMPTY( .cPersistentCookieValue ) && user has such a cookie already
            .App_Log(L7_SEVERITY_DEBUG, "Incoming persistent cookie: " + .cPersistentCookieValue)
            IF loUser.ValidatePersistentCookieUser( .cPersistentCookieValue )
              * Cookie info allowed us to identify user.
              .cUserId = loUser.GetUserID()
              IF NOT loSession.FindUserSession(.cUserId)
                loSession.NewUserSession(.cUserId)
              ENDIF
              llIdentified = .T.
              llDecided = .T.
              * Clear out any license plate that was temporarily assigned
              * pending check to see if cookie would be accepted:
              IF .lUsesLicensePlates
                THIS.ClearLicensePlate()
              ENDIF
              .nIdentificationActual = L7_IDENTIFICATION_PERSISTENT_COOKIE
              
              * Determine if a login dialog is required:
              IF .lLogoutRequested AND NOT .lCookieSatisfiesLogin
                * Logout requested on this hit.
                loSession.SetLoginStatus( .F.)
              ENDIF
              *
              DO CASE
              CASE .lCookieSatisfiesLogin
                * Nothing more to do, since the policy states
                * that existence of a cookie is all that's needed.
                * [NOT RECOMMENDED--WEAK SECURITY!]
                loSession.SetLoginStatus(.T.)
              CASE loSession.IsLoggedIn()
                * user already has done it
              CASE loSession.nHits > 1 AND loUser.JustLoggedIn(.cUserId)
                loSession.SetLoginStatus(.T.)
              CASE NOT m.llLoginRequired AND NOT .lLoginRequested
                * App/page allow anonymous users *and* URL isn't indicating a login request.
                llIdentified = .T.
                .App_Log(L7_SEVERITY_DEBUG, "Anonymous user context loaded")
                loUser.InitAnonymousUser()
              OTHERWISE
                * Need to ask them to log in.
                llShowLogin = .T.
              ENDCASE
            ELSE  && Not a valid cookie--either a hack or maybe 
              * they got the cookie from another L7 app in same realm.
              * ???
            ENDIF
          ELSE  && No cookie yet.
            * Do nothing here, since we decide later if we want to 
            * add a cookie at this time.
          ENDIF
        ENDIF
      ENDIF

      * Temporary Cookie Strategy
      *  [Note: Major difference is that here you start with the session
      *  info. With Persistent cookies, you use the cookie value to find 
      *  the user ID and then create a session for it.]
      *
      IF !m.llDecided AND .lUsesTemporaryCookies AND !EMPTY(.cTemporaryCookieName)
        * We didn't decide about the user in the above code *and*
        * this application employs temporary cookies as an option.
        IF .nMinIdentificationMethod <= L7_IDENTIFICATION_TEMPORARY_COOKIE
          * Temporary cookie is acceptable for this page.
          
          .cTemporaryCookieValue = Request.GetCookie(.cTemporaryCookieName)
          IF !EMPTY(.cTemporaryCookieValue) && user has a cookie already
            .App_Log(L7_SEVERITY_DEBUG, "Incoming temporary cookie: " + .cTemporaryCookieValue)
            llDecided = .T.
            .nIdentificationActual = L7_IDENTIFICATION_TEMPORARY_COOKIE
            * Clear out any license plate that was temporarily assigned
            * pending check to see if cookie would be accepted:
            IF .lUsesLicensePlates
              THIS.ClearLicensePlate()
            ENDIF
            * See if session has expired, and if so, create a new one:
            
            * 07/03/2010: 
            * [[ Big problem here! If the session was bad (expired, wrong CRC), a new
            *    session was created _using the same token_. This cause duplicate tokens in the
            *    session table. On the next hit, the bad record would be found and used. 
            * [[ Need a CheckForCookie() method before llDecided is set .t., which if fails
            *  causes a new session ID to be created. 
            
            if !loSession.FindTokenSession(.cTemporaryCookieValue, "TC")
              *!* .App_Log(L7_SEVERITY_INFO, "New temporary cookie session using same token!: " + .cTemporaryCookieValue)
              *!* loSession.NewTokenSession(.cTemporaryCookieValue, "TC")
              this.AssignCookie(.f., .t.)
              .App_Log(L7_SEVERITY_INFO, "Discarding unfound temporary cookie and creating new one!: " + .cTemporaryCookieValue)
            endif
            
            * Check the session object to see if a User ID has been associated 
            * with the session (ie, if a user has logged in). [Note the difference from
            * the Persistent cookie case, where the cookie is linked to the user
            * via the user table.]
            IF .lLogoutRequested 
              * Logout requested on this hit.
              .App_Log(L7_SEVERITY_DEBUG, "User requested to log out")
              loSession.SetLoginStatus(.F.)
              loSession.SetUserId("")
              .cUserId = ""
            ELSE  && Read user ID from session object:
              .cUserId = loSession.GetUserID() 
              .App_Log(L7_SEVERITY_DEBUG, "Session says User ID is: " + .cUserId)  
            ENDIF
            
            * If we don't know who the user is from the session, let's see if
            * they are posting login information on *this* hit:
            if empty(.cUserId)  && Session record has no user ID.
              * 07/07/2010: reversed next 2 IF blocks to enable app_log warning when 2nd hit policy is invoked
              if loUser.JustLoggedIn()  
                .App_Log(L7_SEVERITY_DEBUG, "This request included a valid login post.")
                * 11/29/2012: new cookie once logged in, to prevent session hijack
                this.AssignCookie(.f., .t.)
                
                .App_Log(L7_SEVERITY_DEBUG, "Hit count is " + transform(loSession.nHits)) 
                if loSession.nHits >= 0  && (change 0 to 1 to enforce policy)  5/7/06: foil brute force attempt that POSTs login on first hit
                  .cUserId = loUser.GetUserId()
                  * Also mark the session so on future hits, we know the user:
                  loSession.SetUserId(.cUserId)
                  loSession.SetLoginStatus(.t.)
                  *!* .Redirect(.cUrlB)  && [[ 08/30/2006 - experimental!! -- bad idea (cookie lost)
                else
                  .app_Log(L7_SEVERITY_NOTICE, "Login rejected on first hit of session (policy).") 
                endif 
              endif && just logged in
            endif 
            
            IF !empty(.cUserId)  && we have a user ID as reported from Session
              llIdentified = .T.
              IF loSession.IsLoggedIn()
                * User already has logged in--verify still OK with user object:
                IF loUser.FindUser(.cUserId)  && user (from session) is OK
                ELSE  && not! - maybe URL indicates scope change excluding user? (uncommon/untested use case)
                  .app_Log(L7_SEVERITY_WARNING, "Session user no longer accepted: " + .cUserId) 
                  llIdentified = .F.
                  loSession.SetLoginStatus( .F.)
                  loSession.SetUserId("") && [[ really clear it? -- how about leave alone, and create new session? 
                  .cUserId = ""
                ENDIF
              else  && not logged in
                * Possibly the session timed out and they are just logging in again:
                if loUser.JustLoggedIn(.cUserId)
                  .App_Log(L7_SEVERITY_DEBUG, "This request included a valid login post.")
                  * 11/29/2012: new cookie once logged in, to prevent session hijack
                  this.AssignCookie(.f., .t.)
                  loSession.SetLoginStatus(.t.)
                  loSession.SetUserId(.cUserId)
                ELSE
                  IF .nMinLoginLevel >= 2  && This page requires login.
                    * set flag to present the dialog
                    llShowLogin = .T.
                    ** loUser.InitAnonymousUser()  && ???
                  ENDIF  && LoginRequired
                ENDIF  && Just logged in.
              ENDIF && LoggedIn
            ENDIF && NOT EMPTY( .cUserID)
            
            IF EMPTY(.cUserId)  && cookie not identifying a user
              DO CASE
              CASE loSession.lJustExpired
                * If we just expired a real user, have them log in again.
                .App_Log(L7_SEVERITY_DEBUG, "Session just expired - login form to be rendered")
                llShowLogin = .T.
              CASE NOT m.llLoginRequired AND NOT .lLoginRequested
                * App/page allow anonymous users *and* URL isn't indicating a login request.
                llIdentified = .T.
                .App_Log(L7_SEVERITY_DEBUG, "Anonymous user context loaded")
                loUser.InitAnonymousUser()
              OTHERWISE
                .App_Log(L7_SEVERITY_DEBUG, "Login is required - form to be rendered")
                llShowLogin = .T.
              ENDCASE
            ENDIF
          ELSE  && No cookie.
            .App_Log(L7_SEVERITY_DEBUG, "NO incoming temporary cookie")
            * Do nothing here, since we decide later if we want to 
            * add a cookie at this time.
          ENDIF
        ENDIF
      ENDIF
      #ENDIF

      * License Plate Strategy:
      IF !m.llDecided AND loPage.lUsesLicensePlates
        * We didn't decide about the user in the above code *and*
        * this application employs license plates as an option.
        IF loPage.nMinIdentificationMethod <= L7_IDENTIFICATION_LICENSE_PLATE
          * LP is sufficient for this page.
          ** llDecided = .T.
          .nIdentificationActual = L7_IDENTIFICATION_LICENSE_PLATE
          IF THIS.CheckForLicensePlate()  && user already has one
            llDecided = .T.
          ELSE
            #IF L7_ENABLE_COOKIES
              IF .lCookieAttempted OR ;
                NOT ( .lUsesTemporaryCookies OR .lUsesPersistentCookies )
                * If we tried a cookie last time and it wasn't accepted, OR
                * we aren't using cookies at all, we give them a license plate:
                THIS.AssignLicensePlate()
                llDecided = .T.
              ENDIF
            #ELSE
              THIS.AssignLicensePlate()
              * Give them a new license plate.
              llDecided = .T.
            #ENDIF
          ENDIF
          if m.llDecided
            * Is Logout requested on this hit?
            if .lLogoutRequested 
              loSession.SetLoginStatus(.F.)
              .App_Log(L7_SEVERITY_DEBUG, "User requested to log out")
            endif 
            
            if !loSession.LicensePlateIdentifiesUser()
              * Can't tell the user from the license plate. See if they
              * are posting login info now.

              * 07/07/2010: reversed next 2 IF blocks to enable app_log warning when 2nd hit policy is invoked
              if loUser.JustLoggedIn()  && A valid login was just submitted.
                .App_Log(L7_SEVERITY_DEBUG, "This request included a valid login post.")
                * 11/29/2012: new LP once logged in, to prevent session hijack
                this.AssignLicensePlate(.t.)

                .App_Log(L7_SEVERITY_DEBUG, "Hit count is " + transform(loSession.nHits)) 
                if loSession.nHits >= 0  && (make the 0 a 1 to enforce) 5/7/06: foil brute force attempt that POSTs login on first hit
                  .cUserId = loUser.GetUserId()
                  * Also mark the session so on future hits, we know the user:
                  loSession.SetUserId(.cUserId)
                  loSession.SetLoginStatus(.t.)
                else
                  .app_Log(L7_SEVERITY_NOTICE, "Login rejected on first hit of session (policy).") 
                endif 
              endif && just logged in
            endif && LP idenitfies
            
            * Re-ask question, in case they just logged in:
            if loSession.LicensePlateIdentifiesUser()
              * Using the LP, we could tell who the user is from
              * the session table.
              llIdentified = .T.
              .cUserId = loSession.GetUserID() && note the difference from [[?? from what, cookie case?
              
              IF loSession.IsLoggedIn() && User is logged in.
                .App_Log(L7_SEVERITY_DEBUG, "Session says User ID is: " + .cUserId)  
                * User already has logged in--verify still OK with user object:
                IF loUser.FindUser(.cUserId)  && user (from session) is OK
                ELSE  && not! - maybe URL indicates scope change excluding user? (uncommon/untested use case)
                  .app_Log(L7_SEVERITY_WARNING, "Session user no longer accepted: " + .cUserId) 
                  llIdentified = .F.
                  loSession.SetLoginStatus( .F.)
                  loSession.SetUserId("") && [[ really clear it? -- how about leave alone, and create new session? 
                  .cUserId = ""
                ENDIF
              ELSE
                IF loUser.JustLoggedIn(.cUserId)
                  this.AssignLicensePlate(.t.)
                  loSession.SetUserId(.cUserId)
                  loSession.SetLoginStatus(.t.)
                  .App_Log(L7_SEVERITY_DEBUG, "User just logged in via this hit" )  
                ELSE
                  
                  .App_Log(L7_SEVERITY_DEBUG, "Anonymous user context loaded")
                  loUser.InitAnonymousUser() && 03/05/2007 - debugging...
                  
                  ** IF .nMinLoginLevel >= L7_LOGIN_LOGGED_IN  && This page requires login.
                  IF .lLoginRequested OR .nMinLoginLevel >= L7_LOGIN_LOGGED_IN  && 03/05/2007 alt
                  
                    * You could get to this state, despite the temporary nature
                    * of license plates, by enabling a Log Out menu item, which
                    * turns off their logged-in status, while still identifying them.
                    llShowLogin = .T.
                  ENDIF  && LoginRequired
                ENDIF
              ENDIF && LoggedIn
            else  && LP doesn't ID user
              if .IsAnonymousOK() AND !.lLoginRequested
                llIdentified = .T.
                .App_Log(L7_SEVERITY_DEBUG, "Anonymous user context loaded")
                loUser.InitAnonymousUser()
              else 
                .App_Log(L7_SEVERITY_DEBUG, "Login is required - form to be rendered")
                llShowLogin = .T.
              endif 
            endif  && ID user
          endif  && llDecided
        endif  && LP's are sufficient for this page
      endif  && using license plates

      * If we get here and llDecided is still false, we have not found any 
      * way of identifying the user. Most likely it is the first hit to the 
      * site, possibly ever, but at least for this session. Now, we go back up 
      * the line of allowed strategies, attaching the first that is allowed.
      
      * {04/14/2003} New! -- no session at all
      if !m.llDecided AND .nMinIdentificationMethod = L7_NONE ;
          and .IsAnonymousOK()  ;   && 02/24/2007 (is this OK, redundant)
          and !.lLoginRequested  && 02/24/2007 (if login requested, cannot leave stateless)
          
        llDecided = .T.
        .nIdentificationActual = L7_NONE
        .App_Log(L7_SEVERITY_DEBUG, "Anonymous user context loaded")
        loUser.InitAnonymousUser()  && 03/05/2007 
      endif 

      #IF L7_ENABLE_COOKIES
      if !m.llDecided AND .lUsesTemporaryCookies
        IF .nMinIdentificationMethod <= L7_IDENTIFICATION_TEMPORARY_COOKIE
          llDecided = .T.
          .nIdentificationActual = L7_IDENTIFICATION_TEMPORARY_COOKIE
          THIS.AssignCookie(.F.)
          IF .lUsesLicensePlates
            THIS.AssignLicensePlate()  && in case cookie rejected!
          ENDIF
          IF .IsAnonymousOK() AND NOT .lLoginRequested
            llIdentified = .T.
            .App_Log(L7_SEVERITY_DEBUG, "Anonymous context assumed.")
            loUser.InitAnonymousUser()
          ELSE
            llShowLogin = .T.
          ENDIF
        ENDIF
      ENDIF

      IF !m.llDecided AND .lUsesPersistentCookies
        IF .nMinIdentificationMethod <= L7_IDENTIFICATION_PERSISTENT_COOKIE
          llDecided = .T.
          .nIdentificationActual = L7_IDENTIFICATION_PERSISTENT_COOKIE
          THIS.AssignCookie(.T.)
          IF .lUsesLicensePlates
            THIS.AssignLicensePlate()  && in case cookie rejected!
          ENDIF
          IF .IsAnonymousOK() AND NOT .lLoginRequested
            llIdentified = .T.
            .App_Log(L7_SEVERITY_DEBUG, "Anonymous user context loaded")
            loUser.InitAnonymousUser()
          ELSE
            llShowLogin = .T.
          ENDIF
        ENDIF
      ENDIF
      #ENDIF

      #IF L7_ENABLE_AUTHENTICATION
      IF !m.llDecided AND .lUsesAuthentication
        llDecided = .T.
        .nIdentificationActual = L7_IDENTIFICATION_AUTHENTICATION
        .Authenticate()
      ENDIF
      #ENDIF

      IF NOT .lError AND m.llShowLogin = .T.
        * We need to present the login form.
        .lShowLogin = .T.
        .App_Log(L7_SEVERITY_DEBUG, "Login form queued")
      ENDIF  && login dialog needed

      IF !m.llIdentified
      ** IF NOT m.llIdentified AND NOT m.llShowLogin
        loUser.InitAnonymousUser()
        .App_Log(L7_SEVERITY_DEBUG, "Anonymous user context loaded")
      ENDIF

      llRetVal = m.llDecided AND !.lError AND !.lShowLogin AND !.lAuthenticate

    ENDWITH  && THIS.Parent

    RETURN m.llRetVal
  ENDFUNC  && IdentifyUser
  * --------------------------------------------------------- *
  FUNCTION AssignCookie(llPersistent, llNoLP)
    LOCAL lcCookie
    lcCookie = THIS.GetNewSessionID()

    WITH THIS.Parent
      IF m.llPersistent
        ** lcCookie = "PC" + m.lcCookie
        .cPersistentCookieValue = m.lcCookie
        .oHttpHeader.AddCookie( ;
          .cPersistentCookieName, m.lcCookie, THIS.cRealm, "NEVER", ;
          Request.isLinkSecure(), .t.) && Secure and HttpOnly flags
        .oSession.NewTokenSession( m.lcCookie, "PC+" )
        .App_Log(L7_SEVERITY_DEBUG, "New persistent cookie session: " + m.lcCookie)
      ELSE
        ** lcCookie = "TC" + m.lcCookie
        .cTemporaryCookieValue = m.lcCookie
        .oHttpHeader.AddCookie( ;
          .cTemporaryCookieName, m.lcCookie, THIS.cRealm, , ;
          Request.isLinkSecure(), .t.) && Secure and HttpOnly flag
        .oSession.NewTokenSession( m.lcCookie, iif(m.llNoLP, "TC", "TC+") )
        .App_Log(L7_SEVERITY_DEBUG, "New temporary cookie session: " + m.lcCookie)
      endif
      if !m.llNoLP
        * Be sure all URLs on the page indicate that a cookie was sent. We will
        * examine the next hit for this info, and assign a license plate if the 
        * user rejected the cookie:
        .AddBaseUrlParameter("c", "1")
      endif 
    endwith
    return 
  ENDFUNC  && AssignCookie
  * --------------------------------------------------------- *
  FUNCTION AssignLicensePlate(tlForceNew)
    * Uses the session object to create a new license plate and 
    * then modifies the base URL to contain its value.
    local lcLP, llUseCurrent
    with this.Parent
      if !empty(.cLicensePlate) and !m.tlForceNew
        * [[ Is this Kosher?
        .App_Log(L7_SEVERITY_WARNING, "AssignLicensePlate called with existing page token?")
      else
        if !m.tlForceNew and .oSession.IsValidSession()
          lcLp = .oSession.GetToken()
        endif 
        if empty(m.lcLp)
          lcLP = this.GetNewSessionID()
        else 
          llUseCurrent = .T.
        endif 
        .cLicensePlate = m.lcLP
        .AddBaseUrlParameter("s", m.lcLP)
        .App_Log(L7_SEVERITY_DEBUG, "License Plate added to URL: " + m.lcLP)
        if m.llUseCurrent
          * Already a valid session object (probably with a cookie)
          * so add a LP to it.
          .oSession.AddLicensePlate(m.lcLP) 
        else 
          .oSession.NewLicensePlateSession(m.lcLP, "LP")  && what if this fails? - revised to throw error for now...
        endif 
      endif 
    endwith 
    return 
  endfunc  && AssignLicensePlate           
  * --------------------------------------------------------- *
  function CheckForLicensePlate
    * Checks for a current license plate and validates it as being 
    * for a valid current session. Sets property cLicensePlate if valid.
    LOCAL lcId, lcReason
    lcId = Request.QueryString("s")
    IF !empty( m.lcId)
      this.Parent.App_Log(L7_SEVERITY_DEBUG, "License plate from URL: " + m.lcID)
      if THIS.Parent.oSession.FindLicensePlateSession(m.lcId, @lcReason)
        this.Parent.App_Log(L7_SEVERITY_DEBUG, "Valid license plate session exists")
        this.Parent.AddBaseUrlParameter("s", m.lcId)  && ensure usage in managed URLs
      else 
        ** this.Parent.App_Log(L7_SEVERITY_WARNING, textmerge("INVALID license plate session: <<m.lcReason>>"))
        this.Parent.App_Log(L7_SEVERITY_INFO, textmerge("INVALID license plate session: <<m.lcReason>>"))
        lcId = ""
      endif
    else
      this.Parent.App_Log(L7_SEVERITY_DEBUG, "No license plate in URL")
      = .f. && no license plate
    endif 
    THIS.Parent.cLicensePlate = m.lcId 
    return !EMPTY( m.lcId)
  endfunc  && CheckForLicensePlate         
  * --------------------------------------------------------- *
  function ClearLicensePlate
    * Remove the license plate from all base URL properties.
    * Called when cookies are confirmed to be accepted by user.
    * 12/24/2002: "s" used to be "lp"
    local lcStr
    lcStr = Request.QueryString("s")
    if !empty(m.lcStr)
      this.Parent.App_Log(L7_SEVERITY_DEBUG, "License plate removed from URL")
      this.Parent.StripUrl("s")
    endif
    return 
  endfunc  && ClearLicensePlate
  * --------------------------------------------------------- *
  function GetNewSessionID()
    do case 
    case  THIS.cIdStrategy == "basic" OR EMPTY(THIS.cIdStrategy)
      return SYS(3) + SUBSTR(TRANS(RAND()), 3, 4)
    case THIS.cIdStrategy == "guid"
      return CHRTRAN(GetGUIDString(),"{}-","")
    otherwise 
      error "Unknown session ID generation strategy."
    endcase 
    return 
  endfunc 
  * --------------------------------------------------------- *
enddefine  && L7UserIdentifier

#if .f.
12/23/2002 - created by mass migration from L7wcPage::IdentifyUser().
12/23/2002 - changed name 'Permanent' to 'Persistent' w.r.t. cookies
04/14/2003 - added code for no session at all (nMinIdent.. = 0)
03/07/2007 - added code to initialize anonymous user during login process, to provide some user context
#endif
