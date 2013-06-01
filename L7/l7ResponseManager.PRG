* L7ResponseManager.PRG

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
define class L7ResponsePieces AS Custom 
  * Properties moved across (sister re-factor pattern) from L7Page:
  lRendered            = .F.  && have we rendered yet?
  cResult              = ""   && pre-render container

  * JSON response properties
  oJsonContents = NULL
  
  * File handling properties (used by GetFileContents() method):
  cFileContents = ""  && set either this or next 2 for templates, etc.
  cFilePath     = ""
  cFileName     = ""
  cFileNameSent = ""  && optional override physical filename for user
  lFileDownload = .F. && use octet-stream binary download response
  lFileTransmit = .F.

  * Values used in <head> section of response:
  cTitle               = NULL  && NULL means inherit from app
  cSubTitle            = ""
  cGenerator           = "" && "L7 Framework for VFP" RETIRED
  cAuthor              = ""
  cCopyright           = ""
  cKeywords            = ""
  cDescription         = ""
  
  * HTTP header and response construction properties:
  lIncludeHttpHeader   = .T.
  oHttpHeader          = NULL
  oHead                = NULL
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
  cBodyAttributes      = ""   && merge-able <body> tag attributes (also see ExpandTemplate)
  cBodyCssClass        = ""

  lPrint               = .F.  && printable version of page requested?
  nRefresh             = 0    && requested refresh time in seconds (0 = none)

  * --------------------------------------------------------- *
  function init
    this.oHttpHeader = createobject("L7HttpHeader") && needed to be "in place" by alt responses 
    return 
  endfunc 
  * --------------------------------------------------------- *
  * Formerly an L7Page method
  function GetFileContents() 
    * NOTE: this doesn't use cFileNameSent override--that happens in HTTP header (see L7FileResponse)
    with this
      do case
      case !empty(.cFileContents)
        return .cFileContents
      case !empty(.cFileName)
        local lcFile
        lcFile = iif(empty(.cFilePath), "", addbs(.cFilePath)) + .cFileName
        if file(m.lcFile)
          return filetostr(m.lcFile)
        else 
          error [File "] + m.lcFile + [" not found.]
          return 
        endif 
      otherwise 
        error "No return file contents specified."
        return 
      endcase 
    endwith 
  endfunc   && GetFileContents
  * --------------------------------------------------------- *
  function GetJSONContents
    local loExc, loJson, lcOut
    loJson = iif(isnull(this.oJsonContents), createobject("Empty"), this.oJsonContents)
    try
      * What if contents are already a string?
      if vartype(m.loJson) = "C"
        lcOut = m.loJson  && assume it's already-serialized...should we check it?
      else 
        lcOut = L7JsonSerialize(m.loJson)
      endif 
    catch to loExc
      lcOut = [{"Error": "error"}]  && placeholder
    endtry  
    return m.lcOut
  endfunc  && GetJSONContents
  * --------------------------------------------------------- *
  function RenderBodyTag
    local lcBodyTag
    with this
      lcBodyTag = [<body] + iif(empty(.cBodyAttributes), [], [ ] + .cBodyAttributes)
      if !empty(.cBodyCssClass)
        lcBodyTag = m.lcBodyTag + [ class="] + .cBodyCssClass + ["]
      endif 
      if !empty(.cOnLoad) 
        lcBodyTag = m.lcBodyTag + [ onLoad="] + .cOnLoad + ["]
      endif 
      lcBodyTag = m.lcBodyTag + [>] + CR
      #IF L7_SHAREWARE
        lcBodyTag = m.lcBodyTag + ;
          [<p style="margin: 0; border: 1px; background-color: orange; color: #333333; text-align: center; font-size: 11px; font-style: italic; font-weight: medium; font-family: Cursive;">] + ;
          [This page was produced by an unlicensed evaluation copy of The L7 Framework for Web Connection!] + ;
          [<br>Licensed copies can be attained from Cycla Corporation ] + ;
          [(<a href="mailto:L7@cycla.com">mailto:L7@cycla.com</a>).] + ;
          [</p>] + CR
      *[[TO DO: Revise this so all response assemblers will deal with shareware situation.
      #ENDIF
    endwith 
    return  m.lcBodyTag
  endfunc && RenderBodyTag
  
enddefine && L7ResponsePieces 

*** ========================================================= ***
DEFINE CLASS L7ResponseManager AS Collection
  FUNCTION AddItem(lcClass, lcName)
    THIS.Add(CREATEOBJECT(m.lcClass), m.lcName)
  ENDFUNC
ENDDEFINE

* NOTE: The following classes are meant to be used as persistent, 
*   near-stateless strategy objects. They should utilize the properties
*   of other objects, such as Page, to assemble responses.
*** ========================================================= ***
DEFINE CLASS L7Response AS Container
  cErrorResponse   = "ErrorResponse"
  lCanReportError = .F.
  * --------------------------------------------------------- *
  function ToFile(tcFile, toApp, toPieces, tcAltReturn)
    * Sends result to a file (for WWWC file-based messaging).
    local llSuccess, lcOldSafety, loExc
    if empty(m.tcFile)
      toApp.SetError('Return filename not specified.')
    else 
      lcOldSafety = set("SAFETY") 
      set safety off 
      * Q: Do we want Render() inside TRY/ENDTRY? This eliminates
      * passing the string around, but is it good or bad in case the
      * error is not with the file writing, but with the rendering?
      #IF DEBUGMODE = .F.
      TRY
      #ENDIF
        private poPieces && takes place of Page. 
        poPieces = m.toPieces
        if empty(m.tcAltReturn)
          strtofile(this.Render(), m.tcFile)
        else 
          STRTOFILE(m.tcAltReturn, m.tcFile)
        endif 
        llSuccess = .T.
      #IF DEBUGMODE = .F.
      CATCH TO loExc
        toApp.SetError(loExc.Message, "Response Manager Error", m.loExc)
      FINALLY
      ENDTRY
      #ENDIF
      if m.lcOldSafety = "ON"
        set safety on  
      endif 
    endif 
    return  m.llSuccess
  endfunc  && ToFile
  * --------------------------------------------------------- *
  function ToProperty(tcProp, toApp, toPieces, tcAltReturn)
    * Sends result to property of an object (such as Server.cOutput for COM).
    local llSuccess, loExc
    #IF DEBUGMODE = .F.
    TRY
    #ENDIF
      private poPieces && takes place of Page. 
      poPieces = m.toPieces
      IF EMPTY(m.tcAltReturn)
        STORE THIS.Render() TO (m.tcProp)
      ELSE
        STORE m.tcAltReturn TO (m.tcProp)
      ENDIF
      llSuccess = .T.
    #IF DEBUGMODE = .F.
    CATCH TO loExc
      toApp.SetError(loExc.Message, "Response Manager Error", m.loExc)
    FINALLY
    ENDTRY
    #ENDIF
    RETURN m.llSuccess
  ENDFUNC  && ToProperty
  * --------------------------------------------------------- *
  FUNCTION ShowOutput
    * Basic idea from a tip from Rick Strahl in FoxPro Advisor.
    LOCAL lnResult, lcFile, llOldHeader

    * Turn off header to call show, reset afterward. 
    llOldHeader = poPieces.lIncludeHTTPHeader
    poPieces.lIncludeHTTPHeader = .F.
    lcFile = ADDBS( SYS( 2023) ) + "tmp_l7Page.htm"
    STRTOFILE( THIS.Render(), m.lcFile )
    poPieces.lIncludeHTTPHeader = m.llOldHeader 

    DECLARE INTEGER ShellExecute IN Shell32.DLL ;
      INTEGER hwnd, ;
      STRING lpOperation, ;
      STRING lpFile, ;
      STRING lpParameters, ;
      STRING lpDirectory, ;
      INTEGER nShowCmd

    DECLARE INTEGER FindWindow IN Win32API ;
      STRING cNull, ;
      STRING cWinName

    lnResult = ShellExecute( ;
      FindWindow( 0, _SCREEN.Caption), ;
      "OPEN", ;
      m.lcFile,;
      "", ;
      SYS(2023), ;
      1)
    RETURN m.lnResult
  ENDFUNC  && ShowOutput
  * --------------------------------------------------------- *
  FUNCTION CreateHttpHeader
    RETURN CREATEOBJECT("L7HttpHeader")
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Render
    LOCAL loHttpHeader, lcHttpHeader, lcText
    loHttpHeader = THIS.CreateHttpHeader()
    lcText = ""
    IF THIS.BeforeRender(@lcText, m.loHttpHeader)
      THIS.RenderImplementation(@lcText, m.loHttpHeader)
    ENDIF
    THIS.AfterRender(@lcText, m.loHttpHeader)
    lcHttpHeader = THIS.RenderHttpHeader(m.loHttpHeader, @lcText)
    RETURN m.lcHttpHeader + m.lcText
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(tcText, toHeader)
    ERROR PROGRAM() + " must be implemented in subclass."
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION BeforeRender(tcText, toHeader)  && hook
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderHttpHeader(toHttpHeader, tcText)  
    toHttpHeader.nContentLength = LEN(m.tcText)
    RETURN toHttpHeader.Render()
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AfterRender(tcText, toHeader)  && hook to look at result for a last time
    * header isn't yet rendered, in case this hook affects content, even if just length
  ENDFUNC
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7HtmlResponse AS L7FileResponse
  cDocType = L7_DOCTYPE_LOOSE 
  * --------------------------------------------------------- *
  FUNCTION GetDocType
    RETURN THIS.cDocType + CRLF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetDocStart
    RETURN [<html><body>] + CRLF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetDocEnd
    RETURN [</body></html>] + CRLF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION CreateHttpHeader
    LOCAL loObj
    * loObj = DODEFAULT() && <- this failed if Page d.n.e.
    loObj = CREATEOBJECT("L7HttpHeader")
    loObj.cContentType = "text/html"
    RETURN m.loObj
  ENDFUNC
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7FileResponse AS L7Response
  ** lDownloadFile = .F.  && send as octet-stream
  nFileSize     = 0
  lFileNotFound = .F.  && force 404 respose
  * --------------------------------------------------------- *
  FUNCTION CreateHttpHeader
    RETURN poPieces.oHttpHeader
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderHttpHeader(toHeader, tcText)  
    LOCAL lcHttp, lcFileNameSent
    lcHttp = ""
    lcFileNameSent = evl(poPieces.cFileNameSent, poPieces.cFileName)

    WITH toHeader
      IF poPieces.lFileDownload
        .nContentLength = THIS.nFileSize
        .cContentType = "application/octet-stream"
        .cContentDisposition = "attachment"
        .cContentFilename = m.lcFileNameSent && poPieces.cFileName
        lcHttp = .Render()
      ELSE
        IF poPieces.lFileTransmit
          .nContentLength = THIS.nFileSize
          IF EMPTY(.cContentType)
            .cContentType = ;
              L7ExtensionToContentType(JUSTEXT(poPieces.cFileName))
          ENDIF
          .cContentDisposition = "inline"  && experiment--to coax filename suggestion
        .cContentFilename = m.lcFileNameSent && poPieces.cFileName
          lcHttp = .Render()
        ELSE
          lcHttp = DODEFAULT(m.toHeader, @tcText)  
        ENDIF
      ENDIF
    ENDWITH 
    RETURN m.lcHttp
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(tcText, toHeader)
    IF poPieces.lFileDownload OR poPieces.lFileTransmit
      LOCAL lcFile, lnSize
      lcFile = IIF(EMPTY(poPieces.cFilePath), "", ADDBS(poPieces.cFilePath)) + poPieces.cFileName
      IF FILE(m.lcFile)
        THIS.nFileSize = FileSize(lcFile)  && see RenderHttpHeader()
        tcText = "WC_TRANSMITFILE: " + m.lcFile + CRLF
      ELSE
        goL7App.SetError( "File " + m.lcFile + " not found.")
      ENDIF
    ELSE
      TRY
        tcText = m.tcText + m.poPieces.GetFileContents()
        ** not needed: THIS.nFileSize = LEN(m.lcText)
      CATCH TO loExc
        goL7App.SetError(loExc.Message, "Response Manager Error", m.loExc)
      ENDTRY
    ENDIF
    RETURN 
  ENDFUNC
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7JsonResponse AS L7Response
  lCanReportError = .T.
  lErrorAsPlainText = .T.  && vs trying to send json _about_ the error
  cSecurePrefix = '/*-secure-' + CHR(13) + CHR(10)  && compat w/ evalJson in Prototype
  cSecureSuffix = CHR(13) + CHR(10) + '*/'          && ditto
  * --------------------------------------------------------- *
  FUNCTION CreateHttpHeader
    LOCAL loObj
    loObj = CREATEOBJECT("L7HttpHeader")
    loObj.cContentType = L7ExtensionToContentType("json")  && "application/x-javascript"
    RETURN m.loObj
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AfterRender(tcText, toHeader)  
    if toHeader.cContentType = L7ExtensionToContentType("json")
      * checks that an error or whatever hasn't removed us from json space
      if not empty(this.cSecurePrefix + this.cSecureSuffix)
        tcText = this.cSecurePrefix + m.tcText + this.cSecureSuffix
      endif 
    endif
    return  
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(tcText, toHeader)
    IF goL7App.lErrorMsg OR goL7App.lError
      THIS.RenderError(@tcText, m.toHeader)
      RETURN 
    ENDIF 

    TRY
      tcText = m.tcText + m.poPieces.GetJsonContents()
    CATCH TO loExc
      ** tcText = '{"Error", "' + loExc.Message + '"}'
      * Need app-level error involvement here!!        
      THIS.RenderError(@tcText, m.toHeader, m.loExc)
    ENDTRY
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderError(tcText, toHeader, tvErrorInfo)
    toHeader.cStatus = "500 Internal Server Error"
    if this.lErrorAsPlainText
      toHeader.cContentType = "text/plain"
    endif 
    LOCAL loObj, loExc
    TRY 
      DO CASE 
      CASE VARTYPE(tvErrorInfo) = "O" && likely an exception object
        if this.lErrorAsPlainText
          tcText = L7ExceptionMessage(m.tvErrorInfo)
        else
          tcText = L7JsonSerialize(m.tvErrorInfo)
        endif 
        
      CASE goL7App.lErrorMsg OR goL7App.lError  && error occurred in app/page processing
        if this.lErrorAsPlainText
          tcText = evl(goL7App.cErrorTitle, "Server Application Error") + ": " + evl(goL7App.cErrorMessage, "no error message")
        else
          loObj = CREATEOBJECT("Empty")
          ADDPROPERTY(m.loObj, "ErrorTitle", goL7App.cErrorTitle)
          ADDPROPERTY(m.loObj, "ErrorMessage", goL7App.cErrorMessage)
          * [[to do: debug info?
          tcText = L7JsonSerialize(m.loObj)
        endif

      CASE VARTYPE(tvErrorInfo) = "C" && simple error message string
        if this.lErrorAsPlainText
          tcText = m.tvErrorInfo  && likely inappropriate mark-up, so prefer previous CASE
        else
          loObj = CREATEOBJECT("Empty")
          ADDPROPERTY(m.loObj, "ErrorTitle", "Condition Error")
          ADDPROPERTY(m.loObj, "ErrorMessage", m.tvErrorInfo)
          tcText = L7JsonSerialize(m.loObj)
        endif 
        
      OTHERWISE   
        if this.lErrorAsPlainText
          tcText = "Server Error with no further error information."
        else
          loObj = CREATEOBJECT("Empty")
          ADDPROPERTY(m.loObj, "ErrorMessage", "Server Error with no further error information.")
          tcText = L7JsonSerialize(m.loObj)
        endif 

      ENDCASE  
    CATCH TO loExc
      tcText = "Error encountered while reporting another error: " + loExc.Message
      if !this.lErrorAsPlainText
        tcText = '{"ErrorTitle": ' + m.tcText + ', "ErrorMessage": null}'
      endif
    ENDTRY 
    RETURN 
  ENDFUNC
ENDDEFINE  && json response

*** ========================================================= ***
define class L7HtmlFragmentResponse as L7HtmlResponse
  * --------------------------------------------------------- *
  function  CreateHttpHeader
    return poPieces.oHttpHeader
  endfunc 
  * --------------------------------------------------------- *
  function RenderImplementation(tcText, toHeader)
    local lcRet

    with m.Page
      if .lRendered = .T.
        tcText = m.tcText + .cResult
        return 
      endif 
      
      lcRet = .oBody.Render()
      tcText = m.tcText + m.lcRet 

      .lRendered = .T.  && ???
    endwith 
    return   
  endfunc 
  * --------------------------------------------------------- *
enddefine   && L7HtmlFragmentResponse 

*** ========================================================= ***
DEFINE CLASS L7StandardResponse AS L7HtmlResponse
  * --------------------------------------------------------- *
  FUNCTION CreateHttpHeader
    RETURN poPieces.oHttpHeader
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(tcText, toHeader)
    WITH m.Page
      if .lRendered = .T.
        tcText = m.tcText + .cResult
        return 
      endif 
      LOCAL lcBody, lcBodyTag
      IF NOT .lError AND ;
        VARTYPE( .oBody) = "O" AND ;
        ( VARTYPE( .oBody.lCancelled) <> "L" OR NOT .oBody.lCancelled )
        *
        IF NOT EMPTY(.cDocType)
          tcText = m.tcText + .cDocType + CRLF
        ENDIF
        tcText = m.tcText + [<html lang="] + .cPageLanguage + [">] + CRLF
        IF VARTYPE( .oHead.lCancelled) = "L" AND NOT .oHead.lCancelled
          tcText = m.tcText + .oHead.Render() + CRLF
        ENDIF
        IF NOT .lFrameSet
          lcBody = .oBody.Render()
          IF .lNoBodyTag
            tcText = m.tcText + m.lcBody + CRLF
          ELSE
            lcBodyTag = .RenderBodyTag()
            tcText = m.tcText + m.lcBodyTag + m.lcBody + [</body>] + CRLF
          ENDIF
        ELSE  && frameset
          tcText = m.tcText + [<frameset] + ;
            IIF( EMPTY( .cFrameSetAttributes), [], [ ] + .cFrameSetAttributes ) + [>] + ;
            .oBody.Render() + ;
            [</frameset>] + CRLF
        ENDIF
        tcText = m.tcText + [</html>] + CR
      ENDIF 

      .lRendered = .T.  && ???
    ENDWITH
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE  && L7StandardResponse

*** ========================================================= ***
DEFINE CLASS L7TemplateResponse AS L7StandardResponse
  * For pages that comprising _single_ templates. 
  cExpanderClass = "L7ExpandTemplate"
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(tcText, toHeader)
    * Assumes appropriate body element class and
    * proper pointering of Response objRef.
    LOCAL loExpander, lcTemplate
    TRY
      loExpander = CREATEOBJECT(THIS.cExpanderClass)
      loExpander.Expand(m.poPieces.GetFileContents())
      DODEFAULT(@tcText)
    CATCH TO loExc
      goL7App.SetError(loExc.Message, "Response Manager Error", m.loExc)
    ENDTRY
    RETURN 
  ENDFUNC
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7ErrorResponse AS L7HtmlResponse
  lCanReportError = .T.
  * --------------------------------------------------------- *
  FUNCTION GetDocStart
    RETURN [<html><head>] + ;
      [<title>] + goL7App.cErrorTitle + [</title>] + ;
      [</head><body class="ErrorPage">] + CRLF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(tcText, toHeader)
    LOCAL lcErrDoc
    
    toHeader.cStatus = "500 Internal Server Error"  && added 02/27/2009

 *[[ NOTE: Attempt to reference CSS classes does not work because this
 * class has no <link> to any CSS file!
    
    lcErrDoc = THIS.GetDocType()
    lcErrDoc = m.lcErrDoc + THIS.GetDocStart()
    lcErrDoc = m.lcErrDoc + HTWrap(goL7App.cErrorTitle, [h1])
    lcErrDoc = m.lcErrDoc + HTWrap(goL7App.cErrorMessage, [div],, [ErrorMessage])
    DO CASE
    CASE goL7App.lErrorMsg = .T. && not a full-fledged error
    CASE VARTYPE(goL7App.oDebugInfo) = "O"
      lcErrDoc = m.lcErrDoc + goL7App.oDebugInfo.Render()
    *!*      CASE NOT EMPTY(goL7App.cErrorMessage) 
    *!*        lcErrDoc = m.lcErrDoc + goL7App.cErrorMessage
    OTHERWISE
      lcErrDoc = m.lcErrDoc + [<h1>Error!</h1>] + [<p>No further error information.</p>]  
    ENDCASE
    lcErrDoc = m.lcErrDoc + THIS.GetDocEnd()
    tcText = m.tcText + m.lcErrDoc
    RETURN 
  ENDFUNC
ENDDEFINE  && L7ErrorResponse

*** ========================================================= ***

#if .f.
02/26/2009 - added L7JSONResponse
           - revised BeforeRender and RenderImplementation to pass header
04/06/2003 - created.
05/09/2003 - revised L7TemplateResponse to be based on L7StandardResponse
09/01/2003 - revised L7StandardResponse to include lang="" in <html> tag
10/22/2003 - referenced new constant L7_DOCTYPE_LOOSE
#endif

* End: L7ResponseManager.PRG
