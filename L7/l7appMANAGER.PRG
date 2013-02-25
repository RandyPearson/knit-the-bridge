* L7AppManager.PRG

#INCLUDE L7.H

#UNDEF THIS_DEBUG_OBJECTS 
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


*** ================================================== ***
DEFINE CLASS L7AppManager AS Custom
  ADD OBJECT Applications AS Collection
  ActiveApplication = NULL
  cAppClass         = "L7App"
  cAppAlias         = "L7App"  && metadata location, if default factory is used
  nAppCreation      = L7_APPCREATION_FACTORY + L7_APPCREATION_DIRECT

  * ISAPI Connector behavior:
  oConnector        = NULL
  cConnectorClass   = "L7WcConnector"  && WWWC - override for other ISAPI apps

  * --------------------------------------------------------- *
  FUNCTION INIT
    * ISAPI behavior object:
    THIS.oConnector = CREATEOBJECT(THIS.cConnectorClass)
    * Process monitor:  [[ should this be #IF dependent?
    THIS.SetupProcessMonitor()
    #IF THIS_DEBUG_OBJECTS
        DEBUGOUT "============================"
        DEBUGOUT "APPLICATION MANAGER started..."
    #ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Persist(llTerminate)
    * New! Reconsider after some reflection.
    * Should this be connector behavior??
    IF NOT m.llTerminate
      IF VARTYPE(_SCREEN._L7) = 'U'
        ADDPROPERTY( _SCREEN, '_L7')
      ENDIF
      _SCREEN._L7 = THIS
      IF VARTYPE(m.goL7AppManager) = "U"
        PUBLIC goL7AppManager
        goL7AppManager = THIS
      ENDIF
    ELSE
      IF VARTYPE(_SCREEN._L7) <> 'U'
        REMOVEPROPERTY(_SCREEN, '_L7')
      ENDIF
      IF VARTYPE(m.goL7AppManager) <> "U"
        RELEASE goL7AppManager
      ENDIF
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Destroy
    THIS.GarbageCollect()
    #IF THIS_DEBUG_OBJECTS
    DEBUGOUT "APPLICATION MANAGER stopped!"
    #ENDIF
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GarbageCollect
    * Avoid typical GC issue:
    THIS.ActiveApplication = NULL
    * Call GC for each app:
    PRIVATE goL7App
    LOCAL lnK
    FOR lnK = 1 TO THIS.Applications.Count
      goL7App = THIS.Applications[m.lnK]
      IF VARTYPE(m.goL7App) = "O"
        #IF DEBUGMODE = .F.
        TRY
          m.goL7App.GarbageCollect()
        CATCH && so other apps are attempted even if one has error
        ENDTRY
        #ELSE
          m.goL7App.GarbageCollect()
        #ENDIF
      ENDIF
    ENDFOR
    * Save for last in case an app needs the connector for cleanup:
    THIS.oConnector = NULL
    THIS.ShutdownProcessMonitor()
    RETURN
  ENDFUNC  && GarbageCollect
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupProcessMonitor
    THIS.AddObject("oProcessMonitor", "L7AnchorProcessMonitor")
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION ShutdownProcessMonitor
    IF VARTYPE(THIS.oProcessMonitor) = "O"
      THIS.oProcessMonitor.Shutdown(THIS)
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetDebugInfo
    LOCAL lcTxt, lnK, loObj, lcRow, lcStatus
    * Basic Request Info:
    lcTxt = [<table border=1 align=center class="DebugInfo">] + ;
      [<tr><th colspan="7" class="DebugInfoSectionHeading">Application Manager Information</th></tr>] + CRLF 
    lcTxt = m.lcTxt + ;
      [<tr>] + ;
      [<th>No.</th>] + ;
      [<th>App</th>] + ;
      [<th>Title</th>] + ;
      [<th>Hits</th>] + ;
      [<th>Status Flags</th>] + ;
      [<th>App]+L7BR+[Datasession</th>] + ;
      [<th>Session]+L7BR+[Datasession</th>] + ;
      [</tr>]
    FOR lnK = 1 TO THIS.Applications.Count
      loObj = THIS.Applications[m.lnK]
      lcStatus = ;
        IIF(m.loObj.lAppOpen, [Open ], []) + ;
        IIF(m.loObj.lError, [Error ], []) + ;
        IIF(m.loObj.lHack, [Hack ], []) + ;
        IIF(m.loObj.lMaintenanceFlag, [Maintenance ], [])
      lcRow = [<tr>] + ;
        [<th>] + TRANSFORM(m.lnK) + [.</th>] + CRLF + ;
        [<td>] + loObj.cApplication + [</td>] + CRLF + ;
        [<td>] + loObj.cTitle + [</td>] + CRLF + ;
        [<td align="right">] + TRANSFORM(loObj.nHits) + [</td>] + CRLF + ;
        [<td>] + m.lcStatus + [</td>] + CRLF + ;
        [<td align="center">] + TRANSFORM(loObj.DataSessionID) + [</td>] + CRLF + ;
        [<td align="center">] + ;
          IIF(VARTYPE(loObj.oSession) <> 'O', [&nbsp;], ;
          TRANSFORM(loObj.oSession.DataSessionID)) + [</td>] + CRLF + ;
        [</tr>]
      lcTxt = m.lcTxt + m.lcRow
    ENDFOR
    lcTxt = m.lcTxt + [</table>]
    RETURN m.lcTxt
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION LoadApplications()
    LOCAL llRet
    llRet = .T.
    #IF L7_MONITOR_PROCESS
      LOCAL loProcMon
      loProcMon = THIS.oProcessMonitor
      loProcMon.BeforeAppManagerLoadApplications(THIS)
    #ENDIF
    IF BITAND(THIS.nAppCreation, L7_APPCREATION_DIRECT) > 0
      * Create app objects directly, using brain-dead default naming.
      llRet = m.llRet AND THIS.LoadAppsDirect()
    ENDIF
    IF BITAND(THIS.nAppCreation, L7_APPCREATION_FACTORY) > 0
      * Create app objects from factory (using metadata).
      llRet = m.llRet AND THIS.LoadAppsViaFactory()
    ENDIF
    #IF L7_MONITOR_PROCESS
      loProcMon.AfterAppManagerLoadApplications(THIS)
    #ENDIF
    RETURN m.llRet
  ENDFUNC  && LoadApplications
  * --------------------------------------------------------- *
  PROTECTED FUNCTION LoadAppsViaFactory()
    * Basic factory to load apps from metadata. This can be overridden.
    LOCAL llRet, loApp, loConfig, loConn, loExc, lcMessage
    llRet = .T.
    loConn = THIS.oConnector
    #IF DEBUGMODE = .F.
    TRY
    #ENDIF
      THIS.GetAppList()
      SELECT AppList_
      SCAN FOR NOT Disabled
        loApp = THIS.AddItem(TRIM(Class), TRIM(Module), TRIM(Acronym))
        loConfig = loConn.GetAppConfig(m.loApp)
        loApp.SetConfigObject(m.loConfig) 
      ENDSCAN
    #IF DEBUGMODE = .F.
    CATCH TO loExc
      llRet = .F.
      IF VARTYPE(loExc.UserValue) = "O"
        lcMessage = loExc.UserValue.Message
      ELSE
        lcMessage = loExc.Message
      ENDIF
      IF m.loConn.HasUI()
        WAIT WINDOW "App load error: " + m.lcMessage TIMEOUT 3
      ENDIF
      EXIT
    FINALLY
    #ENDIF
      USE IN SELECT("AppList_")
    #IF DEBUGMODE = .F.
    ENDTRY
    #ENDIF
    RETURN m.llRet
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetAppList  && somewhat crude for now
    SELECT 0
    IF NOT FILE(FORCEEXT(THIS.cAppAlias, "DBF"))
      CREATE TABLE (THIS.cAppAlias) FREE( ;
          Disabled L, ;
          Acronym C(10), ;
          Class C(20), ;
          Module C(24), ;
          BeforeApp C(10), ;
          AfterApp C(10), ;
          Properties M, ;
          Notes M ;
        )
      USE
    ENDIF
    SELECT * FROM (THIS.cAppAlias) INTO CURSOR AppList_ NOFILTER
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION LoadAppsDirect()
    * Used to respond to INI setting of L7Apps=<comma-delim-list>
    LOCAL llRet, lcAppList, loConn, lcMsg, ;
      aa[1], lcApp, loApp, loConfig, loExc

    llRet = .T.
    loConn = THIS.oConnector
    lcAppList = loConn.GetAppList()
    IF NOT EMPTY(m.lcAppList)
      ALINES(aa, m.lcAppList, .T., ",")
      FOR EACH lcApp IN aa
        #IF DEBUGMODE = .F.
        TRY
        TRY
        #ENDIF
          loApp = THIS.AddItem(m.lcApp + "App", m.lcApp + "App.PRG", m.lcApp)
          loConfig = THIS.oConnector.GetAppConfig(m.loApp)
          loApp.SetConfigObject(m.loConfig) 
          * This establishes the reference, but nothing more,
          * since we have yet to re-read the config file settings.
        #IF DEBUGMODE = .F.
        CATCH TO loExc
          IF m.loConn.HasUI()
            lcMsg = IIF(VARTYPE(loExc.UserValue) = "O", ;
              loExc.UserValue.Message, loExc.Message)
            WAIT WINDOW m.lcApp + " app load error: " + m.lcMsg TIMEOUT 3
          ENDIF
          ** llRet = .F. && try just avoiding this app, and let others run???
          EXIT
        ENDTRY
        CATCH
          IF m.loConn.HasUI()
            WAIT WINDOW m.lcApp + " was not loaded." TIMEOUT 2
          ENDIF
        ENDTRY
        #ENDIF
      ENDFOR
    ENDIF
    RETURN m.llRet
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddItem(lcAppClass, lcAppModule, lcAcronym)
    * Instantiate an app object and add it to the collection.
    * Nothing special going on here. You can always create objects
    * yourself and ADD() them to THIS.Applications directly.
    LOCAL loObj
    * Default a few things:
    lcAppClass = EVL(m.lcAppClass, THIS.cAppClass)
    
    * If module not passed, assume it's available via SET PROC in main program.
    *!* lcAppModule = EVL(m.lcAppModule, m.lcAppClass + ".prg")
    *!*      * Bootstrap SET PROC to avoid app-specific code in main program:
    *!*      IF UPPER(m.lcAppModule) <> "L7"
    *!*        SET PROCEDURE TO &lcAppModule ADDITIVE
    *!*      ENDIF

    * Create the object:
    #IF DEBUGMODE = .F.
    TRY
    #ENDIF
      IF EMPTY(m.lcAppModule)
        loObj = CREATEOBJECT(m.lcAppClass, m.lcAcronym)
      ELSE
        loObj = NEWOBJECT(m.lcAppClass, m.lcAppModule, "", m.lcAcronym)
      ENDIF
      * Add to collection:
      THIS.Applications.Add(loObj, loObj.cApplication)
      #IF THIS_DEBUG_OBJECTS
        DEBUGOUT "Added " + loObj.cApplication + " to Application Manager."
      #ENDIF
    #IF DEBUGMODE = .F.
    CATCH TO loExc
      #IF THIS_DEBUG_OBJECTS
        DEBUGOUT "Error: " + loExc.Message + " adding item to Application Manager."
      #ENDIF
      THROW loExc
    ENDTRY
    #ENDIF
    * Pass back an object reference:
    RETURN loObj
  ENDFUNC  && AddItem
  * --------------------------------------------------------- *
  FUNCTION DoSetup
    PRIVATE goL7App
    LOCAL lnK
    FOR lnK = 1 TO THIS.Applications.Count
      goL7App = THIS.Applications[m.lnK]
      IF VARTYPE(m.goL7App) = "O"
        m.goL7App.Setup()
      ENDIF
    ENDFOR
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION HandleRequest( llCheckOnly)
    * Receive a request and return .T. if one of the
    * managed applications handles it.
    LOCAL llHandled, lnK, loExc, llProcessed, loConn
    loConn = THIS.oConnector
    * Create private "app" variable that can be referenced:
    PRIVATE goL7App
    * [Note: From a Page, you can also refer to "THIS.oApp".]
    PRIVATE Environ  && , StartResponse
    Environ = CREATEOBJECT("L7Environ")
    with Environ 
      .add(createobject("Collection"), "log")  && new 02/15/2010
      .add(createobject("Empty"), "page.processState") && 3/17/2011: universally available, avoids trouble finding state in bound events 
      addproperty(.item("page.processState"), "success", .t.) 
      .add(createobject("L7ResponsePieces"), "page.responsePieces") && 06/29/2012 

      addproperty(.item("log"), "nMinSeverity", L7_SEVERITY_NONE) && added 2/14/2011
      addproperty(.item("log"), "nSeverityThreshold", L7_SEVERITY_NOTICE) && level at which to send email
      * Concept is _anything_ (app, page) can add items to log and anything else
      * can process the items (send email, record on disk, stick in response).
      * If something is left unprocessed at end of this method, that's bad. See below.
    
      .Seed_WWWC(Request)
      .Add(version(4),     "appManager.vfp.version")
      .Add(_vfp.ProcessId, "appManager.vfp.processId")
      .Add(sys(1016),      "appManager.vfp.memUsage")
      .Add(datetime(),     "appManager.startTime")
      .Add(sys(2023),      "appManager.windows.tmpfiles")
      .Add(sys(0),         "appManager.windows.id") && "machine # user" format 
    endwith 
    
    * Loop through the application objects asking if any "claim" the 
    * request. Once claimed, call the app's ProcessPage() method and
    * then exit. [Future: Could multiple apps ever want to claim the
    * same request, similar to a filter or chain-of-authority?]    
    FOR lnK = 1 TO THIS.Applications.Count
      goL7App = THIS.Applications[m.lnK]
      IF VARTYPE(m.goL7App) <> "O"
        LOOP
      ENDIF
      * First, see if the app "owns" the request:
      m.goL7App.ResetProperties()
      llHandled = m.goL7App.IsMyRequest()
      IF m.goL7App.lError
      
        * 2 approaches under consideration:
        #IF .F.
          goL7App.lOutputDelivered = .F.
          goL7App.DeliverOutput(Environ.item("page.responsePieces"))  && could be more than app should be asked to do?
          
        #ELSE && easier but less-informative:
          loConn.ErrorAdvise( ;
            EVL(m.goL7App.cErrorTitle, m.goL7App.cApplication + " Problem") + " [L7AppManager]", ;
            EVL(m.goL7App.cErrorMessage, m.goL7App.cApplication + " could not process your request."), ;
            .T. )
        #ENDIF

        m.goL7App.ResetProperties()
        RETURN .T.  
      ENDIF
      IF m.llHandled
        ** llHandled = .T.
        IF NOT m.llCheckOnly
          * Check if application is disabled:
          IF m.goL7App.IsDisabled()
            loConn.ErrorAdvise( ;
              m.goL7App.cApplication + " Disabled", ;
              m.goL7App.cApplication + " has been disabled and is unavailable to process your request.")
          ENDIF
          * Tell the application to process the page:

          *[[ #IF NOT L7_PAGE_DEBUG
          *[[ TRY
          *[[ #ENDIF

          THIS.ActiveApplication = m.goL7App
          goL7App.ResetProperties()
          
          ******************
          
          llProcessed = m.goL7App.ProcessPage() AND m.goL7App.lOutputDelivered  && <<== MAIN CALL TO APP
          
          ******************
          
          * We check lOutputDelivered flag, in case of a RETURN TO <here>
          * from an error() prior to the ability to process a response.
          IF NOT m.llProcessed
            loConn.ErrorAdvise( ;
              EVL(m.goL7App.cErrorTitle, m.goL7App.cApplication + " Problem") + " [L7AppManager]", ;
              EVL(m.goL7App.cErrorMessage, m.goL7App.cApplication + " could not process your request."), ;
              m.goL7App.lError )
            m.goL7App.ClearErrors()
          ENDIF

          *[[#IF NOT L7_PAGE_DEBUG
          *[[CATCH TO loExc
          *[[  LOCAL lcErrorText
          *[[  lcErrorText = [Error ] + TRANSFORM(loExc.ErrorNo) + [, "] + loExc.Message + ;
              [" occurred while processing your request.]
          *[[  loConn.ErrorAdvise( ;
              "Application Error [L7AppManager]", ;
              m.lcErrorText, ;
              .T. )
          *[[FINALLY
          *[[#ENDIF

          THIS.ActiveApplication = NULL

          *[[#IF NOT L7_PAGE_DEBUG
          *[[ENDTRY
          *[[#ENDIF
        ENDIF
        EXIT  && stop asking other apps
      ENDIF
    next  && application
    
    this.checkLog(m.Environ)
    release Environ, goL7App
    return m.llHandled
  ENDFUNC  && HandleRequest
  * --------------------------------------------------------- *
  function checkLog(toEnv)
    * Note that response is probably delivered already, and we're outside
    * the app, so unprocessed log items need ginger handling.
    local lnK, loItem, lcMsg, lcOut, loLog, loExc
    try 
      loLog = toEnv.item["log"]
      lcOut = ""
      for lnK = 1 to loLog.count
        loItem = loLog.item(m.lnK)
        if loItem.processed
          loop
        endif
        if loItem.Severity >= L7_SEVERITY_NOTICE
          loop  && not important enough for appManager action??
        endif 
        lcMsg = loItem.Render()
        lcOut = m.lcOut + m.lcMsg
      next && Item in log
      if not empty(m.lcOut)
        this.oConnector.ErrorEmail( "Unprocessed Log Entries [AppManager]", m.lcOut + CRLF + CRLF)
        * [[ write it somewhere too??
      endif 
    catch to loExc
      = .f. && not good, but don't take down server for it
    endtry

    return 
  endfunc 
  * --------------------------------------------------------- *
  function getFullLog(toEnv)
    * Return everything in log, whether or not processed already.
    * Presumably for error emails or other debugging.
    local lnK, loItem, lcMsg, lcOut, loLog, loExc
    lcOut = ""
    try 
      loLog = toEnv.item["log"]
      for lnK = 1 to loLog.count
        loItem = loLog.item(m.lnK)
        lcMsg = loItem.RenderPlain()
        lcOut = m.lcOut + m.lcMsg
      next && Item in log
    catch to loExc
      = .f. && not good, but don't take down server for it
      lcOut = "Error fetching full log: " + loExc.Message
    endtry

    return m.lcOut
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION GetApplication(lcApp)
    * Get a specific app object reference.
    LOCAL lvKey
    lvKey = THIS.Applications.GetKey(m.lcApp)
    IF EMPTY(m.lvKey)
      RETURN NULL
    ENDIF
    RETURN THIS.Applications.Item(m.lvKey)
  ENDFUNC  && GetApplication
  * --------------------------------------------------------- *
ENDDEFINE  && L7AppManager

*** ===================================================== ***
DEFINE CLASS L7AbstractConnector AS CUSTOM
  lAdminSendErrorEmail = .F.
  cAdminEmail = ""
  cAdminCC = ""
  nSslPort = 0
  * --------------------------------------------------------- *
  FUNCTION ErrorAdvise(lcTitle, lcDetails, llSendMail)
    ERROR "ErrorAdvise method not implemented! (This is probably not good news.)"
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ErrorEmail(lcTitle, lcDetails) && email w/o altering response
    ERROR "ErrorEmail method not implemented! (This is probably not good news.)"
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetExtraStatusInfo(lcTxt)
    * Abstract method. Please override me!
  ENDFUNC
ENDDEFINE 

*** ===================================================== ***
DEFINE CLASS L7WcConnector AS L7AbstractConnector
  * Sub-class for use with West-Wind Web Connection.
  * --------------------------------------------------------- *
  FUNCTION GetAppList
    RETURN goWcServer.oConfig.cL7Apps
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetProcessMonitors
    RETURN goWcServer.oConfig.cProcessMonitors
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetAppConfig(loApp)
    local lcApp, loConfig
    lcApp = m.loApp.cApplication
    IF TYPE("goWcServer.oConfig." + "o" + m.lcApp) <> "O"
      loConfig = CREATEOBJECT(m.loApp.cConfigClass)
      goWcServer.oConfig.AddProperty("o" + m.lcApp, m.loConfig)
    ELSE
      loConfig = EVALUATE("m.loServer.oConfig." + "o" + m.lcApp)
    ENDIF
    RETURN m.loConfig
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ErrorAdvise(lcTitle, lcDetails, llSendMail)
    RETURN goWcServer.ErrorAdvise(m.lcTitle, m.lcDetails, m.llSendMail)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ErrorEmail(lcTitle, lcDetails) && email w/o altering response
    RETURN goWcServer.SendErrorEmail(m.lcTitle, m.lcDetails)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION nSslPort_ACCESS
    RETURN INT(goWcServer.oConfig.nSslPort)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION lAdminSendErrorEmail_ACCESS
    RETURN goWcServer.oConfig.lAdminSendErrorEmail
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cAdminEmail_ACCESS
    RETURN goWcServer.oConfig.cAdminEmail
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cAdminCC_ACCESS
    IF VARTYPE(goWcServer.oConfig.cAdminCC) = "C"
      RETURN goWcServer.oConfig.cAdminCC
    ELSE
      RETURN ""
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetConnectorFile
    RETURN "wc.dll"
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION DeliverHow
    IF Server.lComObject
      RETURN "ToProperty"
    ELSE
      RETURN "ToFile"
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION DeliverWhere
    IF Server.lComObject
      RETURN "Server.cOutput"
    ELSE
      RETURN Request.GetOutputFile()
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetExtraStatusInfo(lcTxt)
    goWcServer.cExtraStatusInfo = m.lcTxt
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION HasUI()
    RETURN goWcServer.HasUI()
  ENDFUNC
ENDDEFINE  && L7WcConnector


#if .f.
01/02/2003 - created this PRG (was part of L7App) and migrated to Collection approach
01/08/2003 - added bracketed code to allow either Collection or Array approach.
01/13/2003 - revised AddItem to remove config parameter.
04/25/2003 - added some TRY/CATCH.
05/04/2003 - replace LOCAL "ii" with direct usage of PRIVATE "goL7App"
05/06/2003 - removed any use of FOR EACH with collections!!
05/23/2003 - removed all bracketed code for whether to use a Collection
06/15/2003 - added DEBUGMODE blocks around TRY/CATCH code
#endif
