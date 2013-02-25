* L7wwServer.PRG
#INCLUDE WCONNECT.H
* above should pull L7.H because of required use of #INCLUDE L7.H
* in WCONNECT_OVERRIDE.H

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

Contributor(s):
1. Lauren Clarke, Cornerstone Systems NW, provided the design for the
L7 parser technology (see L7Parsers.PRG).

2. Portions of the L7 subclass for the Web Connection server (see 
L7wwServer.PRG) derived and/or copied from West-Wind Technologies
original wwServer class. That code is also thus Copyright (C) 2004 by 
West-Wind Technologies. All Rights Reserved.
***** END LICENSE BLOCK *****
#ENDIF

*** ========================================================= ***
DEFINE CLASS L7wwServer AS wwServer
  * Add some L7 Properties:
  cBadApps    = ""
  oAppManager = NULL  && Left here to retain COM signature.
  PROTECTED cAppManagerClass
  cAppManagerClass = "L7AppManager"
  PROTECTED cServerConfigClass
  cServerConfigClass = "L7wwServerConfig" && bridge
  PROTECTED lConfigFileExisted 
  lConfigFileExisted = .T.
  PROTECTED lAutoSaveConfig
  lAutoSaveConfig  = .F.  && see SaveConfigurationOnExit
  PROTECTED lRequireConfiguration
  lRequireConfiguration = .F. && controls whether it is tolerable to start with no config file
  * Add this to make Registry use optional:
  PROTECTED lStorePathInRegistry 
  lStorePathInRegistry = .F.
  * Flag for whether caller is async:
  lAsyncHandler = .F.
  * Allow access to hit start time:
  tHitStart        = NULL
  nStartSeconds    = NULL
  nTimeZoneOffset  = NULL
  nStatusLines     = 7
  cExtraStatusInfo = "" 
  * --------------------------------------------------------- *
  FUNCTION nTimeZoneOffset_ACCESS
    IF ISNULL( THIS.nTimeZoneOffset)
      THIS.nTimeZoneOffset = GetTimeZoneOffset()  && In L7Api.PRG
    ENDIF
    RETURN THIS.nTimeZoneOffset
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION INIT
    LOCAL ln_K, llRet, lcFailStep
    llRet = .T.
    lcFailStep = ""
    * Template method for easy subclassing.
    WITH THIS
      FOR ln_K = 1 TO 1  && easy exit
        .lInStartup = .T.
        .SetupMessagingMode()
        .SetupGlobalReference()
        .SetupAPI()
        .SetupVFPEnvironment()
        .SetupProcessID()
        .SetupPath()
        .SetupConfigFilename()
        .SetupErrorHandler()
        IF NOT .SetServerEnvironment()
          llRet = .F.  && prevents server creation
          lcFailStep = "SetServerEnvironment"
          EXIT
        ENDIF
        .CreateConfigObject()
        .ReadConfiguration()
        .AfterReadConfiguration()
        .SetupServerForm()
        ** .SetupProcessMonitor()
        IF NOT .SetupApplications()  && L7 apps envoked
          llRet = .F.  && prevents server creation
          lcFailStep = "SetupApplications"
          EXIT
        ENDIF
        IF NOT .DoSetServerProperties()
          llRet = .F.  && prevents server creation
          lcFailStep = "DoSetServerProperties"
          EXIT
        ENDIF
        .CreateRequestObject()
        IF NOT .lCOMObject
          .SetupFileBased()  && timer, etc.
        else
          * Removed 01/05/2010 as WWC5.51 dropped MTS code:
          *!*            .SetupCOM()  && COM+, etc.
        ENDIF
        .lInStartup = .F.
      ENDFOR
      IF NOT m.llRet
        LOCAL lcMessage
        lcMessage = "Server not created. Problem with: " + m.lcFailStep
        IF .HasUI()
          WAIT WINDOW m.lcMessage TIMEOUT 3
        ENDIF
        IF .lCOMObject
          COMRETURNERROR("Server Load Error", m.lcMessage)
        ENDIF
        RETURN .F.  && server not created
      ENDIF
    ENDWITH
  ENDFUNC  && INIT
  * --------------------------------------------------------- *
  FUNCTION HasUI
    RETURN NOT (THIS.lComObject AND SYS(2335) == "0")
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupMessagingMode
    IF INLIST(APPLICATION.STARTMODE,2,3,5)
      THIS.lComObject = .T.
      SET RESOURCE OFF
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupGlobalReference()
    PUBLIC goWCServer
    goWCServer = THIS
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupAPI()
    DECLARE INTEGER GetLastError IN Win32API
    *** Used in polling loop - Causes no error
    DECLARE INTEGER DeleteFile IN Win32API STRING cFileName
    *** Create API object used for various API calls
    THIS.oAPI=CREATEOBJECT("wwAPI")
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupVFPEnvironment()
    DO StandardVfpSettings  && see L7Utils.PRG
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupProcessID()
    DECLARE INTEGER GetCurrentProcessId IN WIN32API
    *** Assign a unique id
    THIS.cServerId=LTRIM(STR(GetCurrentProcessId()))
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetAppStartPath(lcPath)
    IF THIS.lStorePathInRegistry = .T.
      RETURN DODEFAULT(m.lcPath)  && use framework approach
    ELSE
      RETURN GetAppStartPath() && just call Fn in wwUtils
    ENDIF
  ENDFUNC  && GetAppStartPath
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupPath()
    *** Read the App Base Path (from EXE filename on OLE Servers)
    *** This value can be overridden in SetServerEnvironment
    THIS.cAppStartPath = THIS.GetAppStartPath()
    *** Add the basic path to the startup application
    DO PATH WITH (THIS.cAppStartPath), "ADD"
    *** All Exe's can SET DEFAULT TO - DLLs cannot
    IF APPLICATION.STARTMODE # 3 AND APPLICATION.STARTMODE # 5 && COM EXE
       SET DEFAULT TO (THIS.cAppStartPath)
    ENDIF
  ENDFUNC  && SetupPath
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupConfigFilename()
    *** Set default server names - default to this class for the INI file
    *** and section within it
    THIS.cAppName = THIS.CLASS
    THIS.cAppIniFile = THIS.cAppStartPath + THIS.cAppName + ".ini"
    * NOTE: These settings can be overridden in SetServerEnvironment()
    * hook before config object load is attempted.
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupErrorHandler
    #IF NOT DEBUGMODE
       *** Backup Error handler only - startup code and a few file access errors
       ***                             are the only things handled by this one
       ON ERROR DO ErrorHandler WITH ;
         ERROR(),MESSAGE(),MESSAGE(1),SYS(16),LINENO() ;
         IN L7WwServer.PRG
    #ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION CreateConfigObject()
    IF VARTYPE(THIS.oConfig) # "O"
      THIS.oConfig = CREATEOBJECT(THIS.cServerConfigClass)
      THIS.oConfig.cFileName = THIS.cAppIniFile
    ENDIF  
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ReadConfiguration(lcIniFile)
    * Repeat this block, in case file name is passed:
    IF EMPTY(m.lcIniFile)
      lcIniFile = THIS.cAppIniFile
    ENDIF
    * Now, add the optional file check:
    THIS.lConfigFileExisted = FILE(m.lcIniFile)
    IF THIS.lRequireConfiguration
      IF NOT THIS.lConfigFileExisted
        ERROR "Configuration file " + m.lcIniFile + " was not found."
        CANCEL  && Would prefer RETURN .F., but INIT method doesn't react to that.
        *!* RETURN .F.
      ENDIF
    ENDIF
    * Survived that, so call the WC default behavior:
    RETURN DODEFAULT(m.lcIniFile)
  ENDFUNC  && ReadConfiguration
  * --------------------------------------------------------- *
  PROTECTED FUNCTION AfterReadConfiguration
    LOCAL lcStr
    THIS.cCOMReleaseUrl = THIS.oConfig.cComReleaseUrl
    * this was too early?? caused CoCreateInstance failed with err code 80004005: Unspecified error
    *!*      IF THIS.lUnattendedComMode AND this.lComObject
    *!*        SYS(2335,0) && ensure an early dialog doesn't hang app
    *!*      ENDIF
    IF THIS.oConfig.nMemUsage > 0
      * Control VFP Memory background Settings
      SYS(3050,2,THIS.oConfig.nMemUsage)
    ENDIF
    lcStr = THIS.oConfig.cCommonPath
    IF NOT EMPTY(m.lcStr)
      ** SET PATH to '&lcStr' ADDITIVE
      ** lcStr = [SET PATH TO "] + m.lcStr + [" ADDITIVE]
      ** &lcStr
      DO path WITH m.lcStr, "ADD"
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupServerForm
    IF THIS.lShowServerForm OR NOT THIS.lComObject
       THIS.ShowServerForm()
       WITH THIS.oServerForm
         .LockScreen = .T.
         .Caption = THIS.cServerID + ;
           " WC/L7: " + THIS.oConfig.cL7Apps + ;
           " (" + SET("HELP") + "," + SET("RESOURCE") + ")"
         LOCAL lnIncrWidth, lnIncrHeight, loCtrl
         lnIncrWidth = 480  && parameterize these somewhere
         lnIncrHeight = 100   && leave 0 until we move lower objects
         .Width = .Width + m.lnIncrWidth
         .Height = .Height + m.lnIncrHeight
         ** .Left = _Screen.Width - .Width && right-justify
         .edtShowStats.Width = .edtShowStats.Width + m.lnIncrWidth
         .edtShowStats.height = .edtShowStats.Height + m.lnIncrHeight
         for each loCtrl in .controls
           if loCtrl.top > .edtShowStats.top && lower than textarea--move down
             loCtrl.top = loCtrl.top + m.lnIncrHeight  && move down
           endif           
         endfor
         .LockScreen = .F.
       ENDWITH
       THIS.AfterSetupServerForm() && hook
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION AfterSetupServerForm
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupApplications()
    LOCAL lcMember, loMgr, loConfig, llRet
    loMgr = CREATEOBJECT( THIS.cAppManagerClass )
    loMgr.Persist(.F.)
    llRet = loMgr.LoadApplications()
    IF m.llRet
      IF NOT THIS.lConfigFileExisted
        THIS.oConfig.Save()
      ENDIF
      * Re-read configuration with new apps available.
      THIS.ReadConfiguration()
      loMgr.DoSetup() && have the manager setup the apps
    ENDIF
    RETURN m.llRet
  ENDFUNC  
  * --------------------------------------------------------- *
  PROTECTED FUNCTION DoSetServerProperties
    LOCAL llRet
    llRet = THIS.BeforeSetServerProperties()
    llRet = m.llRet AND THIS.SetServerProperties()
    llRet = m.llRet AND THIS.AfterSetServerProperties()
    * If any above fail, RETURN .F., thus blocking server creation.
    RETURN m.llRet
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION BeforeSetServerProperties
  * --------------------------------------------------------- *
  PROTECTED FUNCTION AfterSetServerProperties
  * --------------------------------------------------------- *
  PROTECTED FUNCTION CreateRequestObject()
    IF VARTYPE(THIS.oRequest) # "O"
      THIS.oRequest = CREATEOBJECT(THIS.cRequestClass)
    ENDIF  
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION SetupFileBased
    THIS.ADDOBJECT("tmrFileTimer", THIS.cTimerClass)
    THIS.tmrFileTimer.INTERVAL = THIS.nTimerInterval
    THIS.tmrFileTimer.ENABLED = .T. && Start it!
  ENDFUNC
  * --------------------------------------------------------- *
*!*    PROTECTED FUNCTION SetupCOM
*!*      IF THIS.lUseMts
*!*        THIS.oMTS = CREATE("MTXaS.Appserver.1")
*!*      ENDIF
*!*    ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    * Template method for easy subclassing.
    THIS.GarbageCollect()
    THIS.KillGlobalReference()
    THIS.SaveConfigurationOnExit()
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GarbageCollect()
    * this comes first, in case it wants to examine apps before release:
    IF VARTYPE(THIS.oServerForm) = "O"
      THIS.oServerForm = NULL
    ENDIF
    IF VARTYPE(goL7AppManager) = "O"
      LOCAL loMgr
      loMgr = goL7AppManager
      loMgr.GarbageCollect()
      loMgr = NULL
    ENDIF
    THIS.oRequest = NULL
    THIS.oAPI = NULL
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION KillGlobalReference()
    IF THIS.lComObject
      goWCServer = NULL
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SaveConfigurationOnExit()
    IF VARTYPE(THIS.oConfig) = "O"
      IF THIS.lAutoSaveConfig
        #IF DEBUGMODE = .F.
        TRY
        #ENDIF
          THIS.oConfig.Save()
        #IF DEBUGMODE = .F.
        CATCH TO loExc
          * Not sure if we want to do anything really. Mainly trying
          * to avoid annoying IDE errors when you want to Cancel during 
          * a debugging session and this stupid thing tries to run in 
          * the midst of a CLEAR ALL routine.
        ENDTRY
        #ENDIF
      ENDIF
      THIS.oConfig = NULL  && GC
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SendErrorEmail(lcTitle, lcDetails)
    #IF DEBUGMODE = .F.
    TRY
    #ENDIF
      IF THIS.oConfig.lAdminSendErrorEmail
        LOCAL loIP, lcMethod, llIsRequest
        llIsRequest = VARTYPE( THIS.oRequest) = "O"

        #if WWVERSION_NUMBER <= 5.50
          loIP = CREATEOBJECT("wwIpStuff") 
        #else
          loIP = CREATEOBJECT("wwSMTP") && wwIpStuff deprecated as of 5.51
          loIP.nMailMode = 2  && 1 = new .NET
        #endif

        loIP.cMailServer = THIS.oConfig.cAdminMailServer
        loIP.cSenderEmail = THIS.oConfig.cAdminEmail
        loIP.cRecipient = THIS.oConfig.cAdminEmail
        loIP.cSubject = m.lcTitle
        IF m.llIsRequest
          lcMethod = THIS.oRequest.ServerVariables("REQUEST_METHOD")
          loIP.cMessage = m.lcDetails + CRLF + CRLF + [<pre>] + ;
            "   Problem URL: " + THIS.oRequest.GetCurrentURL() + CR + ;
            "   HTTP Method: " + m.lcMethod + CR + ;
            " Physical Path: " + THIS.oRequest.GetPhysicalPath() + CR + ;
            "  Logical Path: " + THIS.oRequest.GetLogicalPath() + CR + ;
            " Referring URL: " + THIS.oRequest.GetPreviousURL() + CR + ;
            "   Server Name: " + THIS.oRequest.GetServerName() + CR + ;
            "  Machine Info: " + SYS(0) + CR + ;
            "    Auth  User: " + THIS.oRequest.GetAuthenticatedUser() + CR + ;
            "     Remote IP: " + THIS.oRequest.GetIPAddress() + CR + ;
            "    User-Agent: " + THIS.oRequest.GetBrowser() + CR + ;
            "    Time Stamp: " + TRANSFORM( DATETIME()) + CR + ;
            " Email Trigger: " + PROGRAM() + CR
          IF m.lcMethod = "POST"
            loIP.cMessage = loIP.cMessage + CR + ;
            "Form Variables: " + THIS.oRequest.cFormVars + CR + CR
          ENDIF
          loIP.cMessage = loIP.cMessage + [</pre>] + CR
        ELSE
          loIP.cMessage = CRLF + ;
            "WARNING: No valid request object was available!!"
        ENDIF
        loIp.cMessage = [<html><head>] + CR + ;
          IIF( NOT m.llIsRequest, "", ;
            [<base href="] + Request.GetRelativeSecureLink("", NOT Request.IsLinkSecure()) + [">] + CR ) + ;
          [</head><body>] + loIp.cMessage + [</body></html>]
        loIP.cContentType = [text/html]
        loIP.SendMailAsync()
      ENDIF
    #IF DEBUGMODE = .F.
    CATCH TO loExc
      * Don't let emailing error stop the response process.
      lcDetails = m.lcDetails + '<h2>Error Trying to Email Error: ' + loExc.Message + '</h2>'
    ENDTRY
    #ENDIF
    return 
  endfunc && sendErrorEmail
  * --------------------------------------------------------- *
  FUNCTION ErrorAdvise(lcTitle, lcDetails, llSendMail)
    m.lcTitle = EVL(m.lcTitle, '[Untitled L7 Error Reported by Server]')
    m.lcDetails = EVL(m.lcDetails, '[No details provided.]')
    PRIVATE Response
    Response = CREATEOBJECT( [WWC_RESPONSESTRING])

    IF m.llSendMail
      this.sendErrorEmail(m.lcTitle, m.lcDetails)
    ENDIF

    Response.StandardPage( m.lcTitle, m.lcDetails )

    IF THIS.lCOMObject
    	*** Simply assign to output property
    	THIS.cOutput=Response.GetOutput()
    ELSE
    	*** FileBased - must output to file
    	File2Var(THIS.oRequest.GetOutputFile(),Response.GetOutput())
    endif
    return 
  ENDFUNC  && ErrorAdvise
  * --------------------------------------------------------- *
  PROCEDURE UpdateStatus
    LPARAMETER lnSeconds, loForm
    * Left here to retain COM signature.
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ProcessHit(lcRequestBuffer, llAsync)
    IF m.llAsync  && hit processed by async handler
      THIS.lAsyncHandler = .T.  && info used by L7Page.OffloadRequest() 
    ELSE
      THIS.lAsyncHandler = .F.
    ENDIF
    * Template method for easy subclassing:
    WITH THIS
      IF .lUnattendedComMode AND .lComObject
        SYS(2335,0) && ensure a dialog doesn't hang app
      ENDIF

      .cOutput = "" && Always clear output for COM operation
      .ResetProperties()
      .ResetRequest(@lcRequestBuffer)
      #IF L7_MONITOR_PROCESS
        LOCAL loProcMon
        loProcMon = goL7AppManager.oProcessMonitor
        loProcMon.BeforeServerProcessHit(THIS, @lcRequestBuffer)
      #ENDIF
      IF .BeforeProcessHit(@lcRequestBuffer)  && hook
        * Perform standard sequence, unless blocked by hook.
        .StatusMessage(.F.)
        .DoProcess() && includes hooks, plus call to Process()
        .CheckSaveRequestFiles()
        IF .lFirstHit
          .OnFirstHit()
        ENDIF
        .StatusMessage(.T.)
        .CheckLogToFile()
      ENDIF
      .AfterProcessHit() && hook: may need to handle file-based and COM differently!
      #IF L7_MONITOR_PROCESS
        loProcMon.AfterServerProcessHit(THIS)
      #ENDIF
      IF .lComObject
        IF EMPTY(.cOutput)
          .OnNoOutput()
        ENDIF
*!*          IF .lUseMTS
*!*            .CompleteCOMPlusTransaction()
*!*          ENDIF
        IF .lASPObject
          RETURN .T.  && ASP Response object is written separately.
        ENDIF
        RETURN .cOutput
      ELSE
        .SendReturnMessageFile()
      ENDIF
    ENDWITH
  ENDFUNC  && ProcessHit
  * --------------------------------------------------------- *
  PROTECTED FUNCTION BeforeProcessHit(lcRequestBuffer)
    * Hook for subclassing.
    * Note: buffer passed by reference, so you can 
    * alter what gets sent to base class ProcessHit.
    * RETURN .F. to skip standard processing
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION StatusMessage(llAfter)
    IF THIS.lshowstatus AND THIS.lShowServerForm
      IF m.llAfter
        THIS.oServerform.UpdateStatus(THIS.GetElapsedTime())
      ELSE
        THIS.oServerform.UpdateStatus()
      ENDIF
    ENDIF
  ENDFUNC  && StatusMessage
  * --------------------------------------------------------- *
  PROTECTED FUNCTION DoProcess
    * Wrapper around possible call to Process().
    PRIVATE Request, Server
    Request = THIS.oRequest
    Server = THIS
    IF THIS.BeforeProcess()
      IF NOT THIS.ProcessedByFramework() && allow an L7 app to handle it
        THIS.Process()  && call legacy WC app code
      ENDIF
      THIS.AfterProcess()
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION BeforeProcess
  * --------------------------------------------------------- *
  PROTECTED FUNCTION ProcessedByFramework
    * Pass request to L7 and report whether an L7 app claimed and processed it.
    LOCAL llResult
    * Can't use TRY...CATCH here
    * because App object uses RETURN TO in errorMsg/error code. 
    llResult = goL7AppManager.HandleRequest()
    
    IF NOT m.llResult AND NOT EMPTY(THIS.cBadApps)
      THIS.ErrorAdvise("L7 Framework Processing Error", ;
        "<h2>Applications Not Instantiated: " + THIS.cBadApps + "</h2>", .T.)
      llResult = .T.
    endif
    RETURN m.llResult 
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION AfterProcess
  * --------------------------------------------------------- *
  PROTECTED FUNCTION ResetProperties
    WITH THIS
      .cOutput = ""  && Always clear output for COM operation
      .NoteStartTime()
      .cErrorMsg = ""
      .lError = .F.
    endwith
    return 
  ENDFUNC  && ResetProperties
  * --------------------------------------------------------- *
  PROTECTED FUNCTION NoteStartTime
    THIS.tHitStart = DATETIME()
    THIS.nStartSeconds = SECONDS()
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetElapsedTime
    RETURN MOD(SECONDS() - THIS.nStartSeconds, 24 * 60 * 60)
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION ResetRequest(lcRequestBuffer)
    WITH THIS
      IF NOT .lAspObject
        .oRequest.InitializeRequest(@lcRequestBuffer, .cTempFilepath)
      ELSE  && ASP
        .oRequest.InitializeRequest(THIS.oASPScriptingContext.Request())
        IF NOT EMPTY(m.lcRequestBuffer)
          .oRequest.cQueryString = m.lcRequestBuffer + "~&" + THIS.oASPScriptingContext.Request().QueryString().Item()
          *& EXTRACT(lcRequestBuffer,"QUERY_STRING=","&") + "&" + .oRequest.cQueryString
          .oRequest.ParseQueryString()
        ENDIF
      ENDIF
    ENDWITH
  ENDFUNC  && ResetRequest
  * --------------------------------------------------------- *
  PROTECTED FUNCTION CheckSaveRequestFiles
    IF THIS.lSaveRequestFiles
      THIS.SaveRequestFiles()
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION OnFirstHit
    IF VARTYPE(THIS.oRequest) = "O"
      THIS.cDLLIniFile = THIS.oRequest.ServerVariables("wcConfig")
      IF NOT EMPTY(THIS.cDLLIniFile)
        THIS.lFirstHit=.F.
      ENDIF
    ENDIF
  ENDFUNC  && OnFirstHit
  * --------------------------------------------------------- *
  PROTECTED FUNCTION CheckLogToFile
    IF THIS.lLogToFile
      THIS.LogRequest(;
        THIS.oRequest.QueryString(), ;
        THIS.oRequest.GetIPAddress(), ;
        THIS.GetElapsedTime())
    ENDIF
  ENDFUNC  && CheckLogToFile
  * --------------------------------------------------------- *
  PROTECTED FUNCTION AfterProcessHit && Hook
  * --------------------------------------------------------- *
  PROTECTED FUNCTION OnNoOutput
    LOCAL loHTML
    loHTML=CREATE([WWC_RESPONSESTRING])
    loHTML.StandardPage("No Output Was Returned", ;
       "The Web Connection application has not returned any data or an error occurred during the process.<P>"+CRLF+;
       "<i>The error string returned (if any) is:</i><p><PRE>" + THIS.cErrorMsg + "</PRE>")
    THIS.cOutput=loHTML.GetOutput()
  ENDFUNC
  *!*    * --------------------------------------------------------- *
  *!*    PROTECTED FUNCTION CompleteComPlusTransaction
  *!*      IF NOT THIS.lMtsCompleted
  *!*        THIS.MTSSetComplete()
  *!*      ENDIF
  *!*      THIS.oMTSObjectContext = .NULL.
  *!*    ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetDebugInfo(lcTitle)
    *!*      RETURN "<h2>Server Debug Info Placeholder</h2>" + ;
    *!*        L7ShowStackInfo()
    RETURN L7ShowObject(THIS, EVL(m.lcTitle, "Server Object"))
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE  && L7WwServer

*** ========================================================= ***
DEFINE CLASS L7FakeServer AS CUSTOM
  nTimeZoneOffset = 0
  * --------------------------------------------------------- *
  FUNCTION INIT
    THIS.nTimeZoneOffset = GetTimeZoneOffset()
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE  && L7FakeServer

*** ========================================================= ***
DEFINE CLASS L7wwServerConfig AS wwServerConfig
  cL7Apps          = ""  && comma-delimited list 
  cProcessMonitors = ""  && list of classes to instantiate as monitors (see L7ProcessMonitor)
  cAdminCC         = ""
  nSslPort         = 0   && often 443, 0 = SSL unavailable
  cCommonPath      = ""  && set path additive used, if specified
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7AppConfig AS wwConfig
  lDisabled            = .F. && turn OFF the app temporarily
  cHTMLPagePath        = ""  && physical path for templates, etc.
  cDataPath            = ""  && physical path for data, if applicable
  cBackupDataPath      = ""  && often used for copying prior rev before structure mods
  cMessagingPath       = ""  && schedule task server data path
  cLogPath             = ""  && request logs
  nVirtualLevel        = 1   && http path levels consumed reaching virtual (0 = root operation)
  cVirtualPath         = ""  && (optional, ex: "/myApp/")
  cPageExtension       = ""  && (optional) app-specific script map
  * Email, and other STS settings:
  lSendMailImmediately = .T.  && after queueing, attempt send
  * Override app-server-level defaults:
  cAdminEmail          = ""  && one address only! (also used as "from")
  cAdminCC             = ""  && can be multiple
  
  nSessionTimeout      = 3600 && in seconds, 3600 = 1 hour

  nDurationLevelNotice = 0  && ms before alerting

ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7wwServerFormVfpFrame AS wwServerFormVfpFrame
  ADD OBJECT oStatusUpdater AS L7wwServerFormStatusUpdater
  * --------------------------------------------------------- *
  FUNCTION UpdateStatus(lnStartSeconds)
    ** goWCServer.UpdateStatus( m.lnStartSeconds, THIS)    
    THIS.oStatusUpdater.UpdateStatus( m.lnStartSeconds, m.goWCServer)    
  ENDFUNC  && UpdateStatus
ENDDEFINE  && L7wwServerFormVfpFrame 

*** ========================================================= ***
DEFINE CLASS L7wwServerForm AS wwServerForm
  ADD OBJECT oStatusUpdater AS L7wwServerFormStatusUpdater
  * --------------------------------------------------------- *
  FUNCTION UpdateStatus(lnStartSeconds)
    ** goWCServer.UpdateStatus( m.lnStartSeconds, THIS)    
    THIS.oStatusUpdater.UpdateStatus( m.lnStartSeconds, m.goWCServer)    
  ENDFUNC  && UpdateStatus
ENDDEFINE  && L7wwServerForm

*** ========================================================= ***
DEFINE CLASS L7wwServerFormStatusUpdater AS LINE
  Visible = .F.
  * --------------------------------------------------------- *
  PROCEDURE UpdateStatus(lnSeconds, loServer)
    LOCAL lcLink, lcNewData
    WITH THISFORM
      *** Write the beginning of the request out so we can see something's happening
      IF VARTYPE(m.lnSeconds) <> "N"
        .picBulb.Picture = "Lightred.bmp"
        .cmdExit.Enabled = .F.
      
        lcLink = loServer.oRequest.cMethod + " " + ;
          JUSTFNAME(loServer.oRequest.GetPhysicalPath()) + " " + ;
          loServer.oRequest.QueryString()
        lcNewData = SYS(1011) + " " + TIME() + " " + m.lcLink
        *** Scroll up a line if oversizing edit box
        IF OCCURS( CHR(13), .edtShowStats.VALUE) > loServer.nStatusLines 
          .edtShowStats.Value = SUBSTR( .edtShowStats.Value, ;
            AT(CHR(13), .edtShowStats.Value, 1) +1) + ;
            m.lcNewData
        ELSE
          .edtShowStats.Value = .edtShowStats.Value + m.lcNewData
        ENDIF
      ELSE
        *** Now finish the output
        .edtShowStats.Value = .edtShowStats.Value + ": " + ;
          loServer.cExtraStatusInfo + " " + ;
          LTRIM( STR( m.lnSeconds, 8, 3)) + ;
          CHR(13)
        .picBulb.PICTURE = "LightOff.bmp"
        .cmdExit.ENABLED = .T.
      ENDIF
    ENDWITH
  ENDPROC  && UpdateStatus
ENDDEFINE

*** ========================================================= ***
PROCEDURE ErrorHandler
  PARAMETER t_errorno,t_mess1,t_mess2,t_module,t_lineno
  LOCAL llOldLogging, lcProcess, lcOldError
  lcOldError = ON("ERROR")

  *** Further errors should be ignored here
  ON ERROR *

  IF TYPE("goWCServer")="O"
     IF TYPE("goWCServer.oRequest")="O"
        lcProcess= CR+goWCServer.oRequest.QueryString()+CR+CR
     ELSE
        lcProcess=""
     ENDIF

     goWCServer.LogRequest("Processing Error"+ L7BR +CR+;
                         lcProcess+CR+;
                         "<pre>"+CR+;
                         "Error: "+STR(T_errorno)+CR+;
                         "Message: "+T_Mess1+CR+;
                         "Code: "+T_mess2+CR+;
                         "Program: "+T_Module+CR+;
                         "Line No: "+STR(T_lineno)+CR+"</pre>",;
                         "Local",0,.t.)

  ENDIF

  CLOSE DATA
  ON ERROR &lcOldError
  *** Restart - ie. hit the main loop
  RETURN TO MASTER
ENDPROC  && ErrorHandler

*** ========================================================= ***
PROCEDURE Shutit  && Global ON SHUTDOWN handler.
  ON ERROR *
  RELEASE goWCServer
  ON SHUTDOWN
  QUIT
  RETURN
  * CAUTION: Your main program needs to release this by issuing
  *    ON SHUTDOWN
  * after a file-based server is released, or you could get the
  * dread "cannot quit visual foxpro" error.
ENDPROC

#if .f.
01/13/2003 - Changed SetupApplications so call to AppManager matches revised parameters in that class.
           - Call SetApplicationConfig in AppManager instead of talking to App directly.
           - PROTECTED several properties.
11/02/2003 - Revisions prior to open-source release.
#endif
