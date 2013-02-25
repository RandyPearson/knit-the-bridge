* L7DebugInfoElement.PRG
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
DEFINE CLASS L7DebugInfoElement AS L7PageElement
  cMenuItemClass = "DebugInfoMenuItem"
  cMenuClass     = "DebugInfoMenu"
  cErrorMessage  = ""
  ADD OBJECT Artifacts AS Collection
  * --------------------------------------------------------- *
  FUNCTION AddDebugObject(loObj, llToPage, llToEmail, lcName)
    TRY
      THIS.AddShowObject(m.loObj, m.llToPage, m.llToEmail, m.lcName)
    CATCH TO loExc
      THIS.cErrorMessage = THIS.cErrorMessage + ;
        L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show object:' + TRANSFORM(m.lcName) + '.]'
    ENDTRY
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddStandardInfo(lnPageInfo, lnEmailInfo)
    LOCAL llPage, llEmail, loObj, loAppObj, llIsApp
    IF TYPE("goL7AppManager.ActiveApplication") = "O"
      loAppObj = goL7AppManager.ActiveApplication
      llIsApp = .T.
    ELSE
      loAppObj = NULL
    ENDIF
    * Environ:
    IF VARTYPE(m.Environ) = "O"
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_ENVIRON_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_ENVIRON_OBJECT) > 0
      IF m.llEmail OR m.llPage
        TRY
          loObj = THIS.GetEmptyArtifact()
          loObj.cName = "Environ Object"
          loObj.cContent = m.Environ.GetDebugInfo()
          loObj.lResponse = m.llPage
          loObj.lEmail = m.llEmail
          THIS.AddArtifact(m.loObj)
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show request debug info.]'
        ENDTRY
      ENDIF
    ENDIF

    * Log:
    IF m.llIsApp and VARTYPE(m.Environ) = "O"
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_LOG_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_LOG_OBJECT) > 0
      IF m.llEmail OR m.llPage
        try
          loObj = THIS.GetEmptyArtifact()
          loObj.cName = "AppLog Object"
          loObj.cContent = '<strong>App Log:</strong>' + CRLF + ;
            '<pre>' + CRLF + goL7AppManager.getFullLog(m.Environ) + '</pre>' + CRLF
          loObj.lResponse = m.llPage
          loObj.lEmail = m.llEmail
          THIS.AddArtifact(m.loObj)
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show App Log info.]'
        ENDTRY
      ENDIF
    ENDIF

    * Call Stack:
    llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_PROGRAM_STACK) > 0
    llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_PROGRAM_STACK) > 0
    IF m.llEmail OR m.llPage
      TRY
        THIS.AddShowStackInfo(m.llPage, m.llEmail, , -2)
      CATCH TO loExc
        THIS.cErrorMessage = THIS.cErrorMessage + ;
          L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show call stack.]'
      ENDTRY
    ENDIF
        
    * User:
    IF vartype(m.CurrentUser) = "O" and pemstatus(m.CurrentUser, 'getDebugInfo', 5)
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_USER_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_USER_OBJECT) > 0
      IF m.llEmail OR m.llPage
        TRY 
          loObj = THIS.GetEmptyArtifact()
          loObj.cName = "Current User Data"
          loObj.cContent = CurrentUser.GetDebugInfo()
          loObj.lResponse = m.llPage
          loObj.lEmail = m.llEmail
          THIS.AddArtifact(m.loObj)
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred in line ' + TRANSFORM(loExc.LineNo) + ;
            ' of ' + loExc.Procedure + ' while trying to show user data.]' 
        ENDTRY
      ENDIF
    ENDIF
*!*      IF TYPE("CurrentUser.oData") = "O" 
*!*        llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_USER_OBJECT) > 0
*!*        llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_USER_OBJECT) > 0
*!*        IF m.llEmail OR m.llPage
*!*          TRY 
*!*            THIS.AddShowObject(CurrentUser.oData, m.llPage, m.llEmail, "Current User")
*!*          CATCH TO loExc
*!*            THIS.cErrorMessage = THIS.cErrorMessage + ;
*!*              L7BR + '[Exception: "' + loExc.Message + '" occurred in line ' + TRANSFORM(loExc.LineNo) + ;
*!*              ' of ' + loExc.Procedure + ' while trying to show user data.]' 
*!*          ENDTRY
*!*        ENDIF
*!*      ENDIF

    * Session:
    IF m.llIsApp AND VARTYPE(goL7App.oSession) = "O"
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_SESSION_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_SESSION_OBJECT) > 0
      IF m.llEmail OR m.llPage
        TRY
          loObj = THIS.GetEmptyArtifact()
          loObj.cName = "Session Object"
          loObj.cContent = goL7App.oSession.GetDebugInfo()
          loObj.lResponse = m.llPage
          loObj.lEmail = m.llEmail
          THIS.AddArtifact(m.loObj)
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show Session object.]'
        ENDTRY
      ENDIF
    ENDIF

    * Request:
    IF VARTYPE(m.Request) = "O"
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_REQUEST_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_REQUEST_OBJECT) > 0
      IF m.llEmail OR m.llPage
        TRY
          loObj = THIS.GetEmptyArtifact()
          loObj.cName = "Request Object"
          loObj.cContent = m.Request.GetDebugInfo()
          loObj.lResponse = m.llPage
          loObj.lEmail = m.llEmail
          THIS.AddArtifact(m.loObj)
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show request debug info.]'
        ENDTRY
      ENDIF
    ENDIF

    * Config:
    IF m.llIsApp AND VARTYPE(m.loAppObj.oConfig) = "O"
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_CONFIG_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_CONFIG_OBJECT) > 0
      IF m.llEmail OR m.llPage
        TRY 
          THIS.AddShowObject(m.loAppObj.oConfig, m.llPage, m.llEmail, "App Config Object")
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show application config object.]'
        ENDTRY
      ENDIF
    ENDIF

    * Work areas:
    llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_WORKAREAS) > 0
    llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_WORKAREAS) > 0
    IF m.llEmail OR m.llPage
      TRY
        THIS.AddShowWorkAreas(m.llPage, m.llEmail)
      CATCH TO loExc
        THIS.cErrorMessage = THIS.cErrorMessage + ;
          L7BR + '[Exception: "' + loExc.Message + '" occurred in line ' + ;
          TRANSFORM(loExc.LineNo) + ' of ' + loExc.Procedure + ' while trying to show work areas.]'
      ENDTRY
    ENDIF

    * Application object:
    IF m.llIsApp
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_APP_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_APP_OBJECT) > 0
      IF m.llEmail OR m.llPage
        TRY 
          THIS.AddShowObject(m.loAppObj, m.llPage, m.llEmail, "App Object")
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show application object.]'
        ENDTRY
      ENDIF
    ENDIF
  
    * Page:
    IF m.llIsApp AND VARTYPE(m.loAppObj.oActivePage) = "O"
    **IF VARTYPE(m.Page) = "O"
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_PAGE_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_PAGE_OBJECT) > 0
      IF m.llEmail OR m.llPage
        TRY 
          THIS.AddShowObject(m.loAppObj.oActivePage, m.llPage, m.llEmail, "Page Object")
          ** THIS.AddShowObject(m.Page, m.llPage, m.llEmail, "Page Object")
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show page object.]'
        ENDTRY
      ENDIF
    ENDIF

    * App Manager:
    IF VARTYPE(m.goL7AppManager) = "O" 
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_APPMANAGER_OBJECT) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_APPMANAGER_OBJECT) > 0
      IF m.llEmail OR m.llPage
        TRY
          loObj = THIS.GetEmptyArtifact()
          loObj.cName = "App Manager"
          loObj.cContent = m.goL7AppManager.GetDebugInfo()
          loObj.lResponse = m.llPage
          loObj.lEmail = m.llEmail
          THIS.AddArtifact(m.loObj)
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred while trying to show App Manager debug info.]'
        ENDTRY
      ENDIF
    ENDIF

    * Server variables:
    IF VARTYPE(m.Request) = "O"
      llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_SERVER_VARIABLES) > 0
      llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_SERVER_VARIABLES) > 0
      IF m.llEmail OR m.llPage
        TRY
          loObj = THIS.GetEmptyArtifact()
          loObj.cName = "Server Variables"
          loObj.cContent = L7ShowServerVariables(m.Request)
          loObj.lResponse = m.llPage
          loObj.lEmail = m.llEmail
          THIS.AddArtifact(m.loObj)
        CATCH TO loExc
          THIS.cErrorMessage = THIS.cErrorMessage + ;
            L7BR + '[Exception: "' + loExc.Message + '" occurred in line ' + TRANSFORM(loExc.LineNo) + ;
            ' of ' + loExc.Procedure + '" occurred while trying to show server variables.]'
        ENDTRY
      ENDIF
    ENDIF

    * Show memory:
    llPage  = BITAND(m.lnPageInfo,  L7_ERRORINFO_LIST_MEMORY) > 0
    llEmail = BITAND(m.lnEmailInfo, L7_ERRORINFO_LIST_MEMORY) > 0
    IF m.llEmail OR m.llPage
      TRY
        THIS.AddShowMemory(m.llPage, m.llEmail)
      CATCH TO loExc
        THIS.cErrorMessage = THIS.cErrorMessage + ;
          L7BR + '[Exception: "' + loExc.Message + '" occurred in line ' + TRANSFORM(loExc.LineNo) + ;
          ' of ' + loExc.Procedure + '" occurred while trying to show memory.]'
      ENDTRY
    ENDIF
    RETURN 
  ENDFUNC  && AddStandardInfo
  * --------------------------------------------------------- *
  FUNCTION AddArtifact(loObj, lcKey)
    lcKey = EVL(m.lcKey, loObj.cName)
    TRY
      THIS.Artifacts.Add(m.loObj, m.lcKey)
    CATCH TO loExc
      * Assume duplicate key. Replace object? Error?
      = .F.  && allow first object to persist, for now
    ENDTRY
    RETURN 
  ENDFUNC  && AddStandardInfo
  * --------------------------------------------------------- *
  FUNCTION AddShowObject(loShowObj, llResp, llEmail, lcTitle)
    IF EMPTY(m.lcTitle)
      lcTitle = IIF(VARTYPE(loShowObj.Name) = "C", loShowObj.Name + " Object", SYS(3))
    ENDIF
*!*      SET STEP ON 
*!*      LOCAL lap[1,1], lnp
*!*      lnp = AMEMBERS(lap,loshowobj, 0, [G#])
    LOCAL loObj, lcContent
    loObj = THIS.GetEmptyArtifact()
    WITH loObj
      .cName = m.lcTitle
      #IF .T.
      lcContent = L7ShowObject(m.loShowObj, m.lcTitle)
      #ELSE  && for debugging
      LOCAL loXML AS wwXML OF wwXML
      loXML = CREATEOBJECT("wwXML") 
      lcContent = loXML.createobjectxml(m.loShowObj, m.lcTitle, 0)
      lcContent = FixHTMLForDisplay(m.lcContent)
      #ENDIF
      .cContent = m.lcContent
      .lResponse = m.llResp
      .lEmail = m.llEmail
    ENDWITH
    THIS.AddArtifact(m.loObj, m.lcTitle)
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddShowStackInfo(llResp, llEmail, lcTitle, lnTruncate)
    lcTitle = EVL(m.lcTitle, "Stack Info")
    LOCAL loObj
    loObj = THIS.GetEmptyArtifact()
    WITH loObj
      .cName = m.lcTitle
      .cContent = L7ShowStackInfo(,, m.lnTruncate)
      .lResponse = m.llResp
      .lEmail = m.llEmail
    ENDWITH
    THIS.AddArtifact(m.loObj, m.lcTitle)
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddShowWorkAreas(llResp, llEmail, lcTitle)
    lcTitle = EVL(m.lcTitle, "Work Areas")
    LOCAL loObj
    loObj = THIS.GetEmptyArtifact()
    WITH loObj
      .cName = m.lcTitle
      .cContent = L7ShowWorkAreas()
      .lResponse = m.llResp
      .lEmail = m.llEmail
    ENDWITH
    THIS.AddArtifact(m.loObj, m.lcTitle)
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddShowMemory(llResp, llEmail)
    LOCAL loObj
    loObj = THIS.GetEmptyArtifact()
    WITH loObj
      .cName = "List Memory"
      .cContent = L7ShowMemory()
      .lResponse = m.llResp
      .lEmail = m.llEmail
    ENDWITH
    THIS.AddArtifact(m.loObj)
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetEmptyArtifact()
    LOCAL loObj
    loObj = CREATEOBJECT("Empty")
    ADDPROPERTY(loObj, "cName", SYS(3))
    ADDPROPERTY(loObj, "cContent", "")
    ADDPROPERTY(loObj, "lResponse", .F.)
    ADDPROPERTY(loObj, "lEmail", .F.)
    RETURN m.loObj
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderForEmail()
    LOCAL lcErrDoc, loAppObj, llIsApp
    IF TYPE("goL7AppManager.ActiveApplication") = "O"
      loAppObj = goL7AppManager.ActiveApplication
      llIsApp = .T.
    ELSE
      loAppObj = NULL
    ENDIF
    lcErrDoc = ""
    IF m.llIsApp
      lcErrDoc = m.lcErrDoc + HTWrap(m.loAppObj.cErrorTitle, [h3])
      lcErrDoc = m.lcErrDoc + HTWrap(m.loAppObj.cErrorMessage, [div])
    ENDIF
    THIS.RenderArtifacts(@lcErrDoc, .T.)
    RETURN "<html><body>" + CRLF + m.lcErrDoc + "</body></html>" + CRLF
  ENDFUNC  && RenderImplementation
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    THIS.RenderArtifacts(@lcText, .F.)
  ENDFUNC  && RenderImplementation
  * --------------------------------------------------------- *
  FUNCTION RenderArtifacts(lcText, llEmail)
    LOCAL lcMenu AS String, lcContent AS String, loItem, lnK
    * First build menu, because it gets inserted between artifacts.
    STORE "" TO lcMenu, lcContent
    TRY
      FOR lnK = 1 TO THIS.Artifacts.Count
        loItem = THIS.Artifacts(m.lnK)
        IF m.llEmail AND NOT loItem.lEmail OR NOT m.llEmail AND NOT loItem.lResponse
          LOOP
        ENDIF
        lcMenu = m.lcMenu + ;
          [<a href="#] + URLEncode(loItem.cName) + ["] + ;
          [ class="] + THIS.cMenuItemClass + [">] + ;
          loItem.cName + [</a>] + CRLF
      ENDFOR
      lcMenu = [<div class="] + THIS.cMenuClass + [">] + CRLF + ;
        m.lcMenu + [</div>] + CRLF
      * Then build content:
      FOR EACH loItem IN THIS.Artifacts
        IF m.llEmail AND NOT loItem.lEmail OR NOT m.llEmail AND NOT loItem.lResponse
          LOOP
        ENDIF
        lcContent = m.lcContent + ;
          [<a name="] + URLEncode(loItem.cName) + ["></a>] + CRLF + ;
          m.lcMenu + ;
          loItem.cContent
      ENDFOR
      IF NOT EMPTY(THIS.cErrorMessage)
        lcContent = [<div class="DebugInfo">] + THIS.cErrorMessage + [</div>] + ;
          CRLF + m.lcContent
      ENDIF
    CATCH TO loExc
      lcContent = [<h2 class="DebugInfo">] + loExc.Message + [</h2>] + CRLF
    ENDTRY
    * Store it to passed text string:
    lcText = m.lcText + THIS.GetStyle() + m.lcContent
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetStyle()
    LOCAL lcStyle
    lcStyle = ;
      [<style>] + CR + ;
      [body{font-family:Arial,Helvatica,sans-serif;font-size:10pt;background-color:#FDF2E3;}] + CRLF + ;
      [a:link,a:visited{color:#000080;text-decoration:none;}] + CRLF + ;
      [a:active,a:focus,a:hover{color:#800000;background-color:#ffffc0;text-decoration:none;}] + CRLF + ;
      [table{width:100%;border-collapse:collapse;border:3px #800000 solid;background-color:#c0c0c0;}] + CRLF + ;
      [tr{vertical-align:top;font-size:10pt;}] + CRLF + ;
      [td{padding:2px;border:1px #FFFFFF solid;}] + CRLF + ;
      [pre{width:100%;background-color:#ffffff;font-family:"courier new",courier;font-size:9pt;padding:2px;margin:0px;}] + CRLF + ;
      [h3{text-align:left;margin:0;border-bottom:1px #000000 solid;}] + CRLF + ;
      [.DebugInfo{clear:left;}] + CRLF + ;
      [.DebugInfoShowMemory td{padding:2px;border:1px #666666 solid;}] + CRLF + ;
      [.DebugInfoShowMemory th{padding:2px;border:1px #666666 solid;}] + CRLF + ;
      [.DebugInfoSectionHeading{clear:left;border:1px #FFFFFF solid;padding:2px;text-align:left;font-size:10pt;color:#ffffff;background-color:#000000;}] + CRLF + ;
      [.DebugInfoMenu{clear: left;text-align:left;font-size:8pt;margin:10px;}] + CRLF + ;
      [.DebugInfoMenuItem{display: block; float: left; border:1px solid blue;}] + CRLF + ;
      [</style>] + CRLF
    RETURN m.lcStyle
  ENDFUNC
  
ENDDEFINE  && Class L7DebugInfoElement

#if .f.
04/xx/2003 - created
05/07/2003 - RenderArtifacts: changed for each iteration to for 1 to count
#endif

