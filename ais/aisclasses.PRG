* AisClasses.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* App Classes:
set procedure to AisApp     additive  && Application Object
set procedure to AisClasses additive  && THIS file
set procedure to AisUser    additive  && User class
set procedure to AisDQ      additive  && Data and Query classes 

* Page Classes:
set procedure to AisPages   additive   
set procedure to AisArt     additive  && Artist pages  
set procedure to AisPce     additive  && Piece pages  

return 

* --------------------------------------------------------- *
function aisArtistName(tvArt)
  local loData, loPreserve
  if vartype(m.tvArt) = "O"
    loData = m.tvArt
  else
    loPreserve = createobject("L7PreserveSelect")
    select * from KtbAis!Artist ;
      where Art_PK = m.tvArt ;
      into cursor aisArtistName_
    if _tally < 1
      error "Artist " + m.tvArt + " was not found!"
    endif
    scatter memo name loData
    loPreserve = null 
  endif 
    
  if empty(loData.Art_Last_Name )
    return trim(loData.Art_User_ID )
  else 
    if empty(loData.Art_First_Name )
      return trim(loData.Art_Last_Name )
    else 
      return trim(loData.Art_First_Name ) + [ ] + trim(loData.Art_Last_Name )
    endif 
  endif 
  return  
endfunc  && aisArtistName

*** ========================================================= ***
* [[ all methods here need to defend against correct database not being current
* [[ same for IMDB, etc...
define class AisLookup AS Line
  * --------------------------------------------------------- *
  function GetSnippet(tcTitle, tlNoParse, tcDefault)
    local lcAlias, loEnv, lcRet
    loEnv = CREATEOBJECT("L7PreserveSelect")
    lcAlias = goL7App.oCacheManager.CacheCursor( ;
      [SELECT Snp_PK, Snp_Title, Snp_Textmerge, Snp_Parse, Snp_Text] + ;
      [ FROM ] + THISAPP_DATABASE + [!Snippet] + ;
      [ WHERE NOT Snp_Inactive])
    tcTitle = PADR(m.tcTitle, LEN(Snp_Title))
    locate for Snp_Title = m.tcTitle
    if !found()
      if vartype(m.tcDefault) = "C"  && a default is passed, even ""
        lcRet = m.tcDefault
      else   
        lcRet = "[" + TRIM(m.tcTitle) + "]" && decent placeholder for text not yet developed
      endif  
    else 
      lcRet = AllTrimX(Snp_Text)
      if Snp_Parse AND NOT m.tlNoParse
        L7ParseOnView(@lcRet)
      endif 
    endif 
    return m.lcRet
  endfunc 
  * --------------------------------------------------------- *
  function GetAlias(lcName)
    local lcAlias
    do case 
    *!*      case lcName == "RuleSections"
    *!*        lcAlias = goL7App.oCacheManager.CacheCursor( ;
    *!*          [SELECT Sec_PK, Sec_Name, Sec_Number, Sec_Parent_Sec_FK] + ;
    *!*          [ FROM ] + THISAPP_DATABASE + [!Section] + ;
    *!*          [ WHERE NOT Sec_Inactive] + ;
    *!*          [ ORDER BY Sec_Number])
    otherwise 
      error "Lookup.GetAlias(): " + "Alias not defined: " + m.lcName
    endcase 
    return  m.lcAlias
  endfunc 
enddefine 

*** ========================================================= ***
* Configuration class for the application -- values controlled by matching INI file settings:
define class AisConfig as L7AppConfig
  cPageExtension       = "ktb"
  cServerRole          = "production"
  nSessionTimeout      = 14400  && 4 hrs 

  lReadOnly            = .F.
  lDebugQueries        = .F.
  lSendMailImmediately = .T.

  cFilePath            = "d:\WebDocs\ktb-ais\" && for doc/pdf/etc.
  cHTMLPagePath        = "c:\Inetpub\wwwroot\ktb-ais\" && css, js 
  cDATAPath            = "c:\vfpdata\ais\"
  cLogPath             = "d:\VfpLogs\ktb-ais\"
  cMessagingPath       = "d:\VfpMessaging\ktb-ais\"
  cTransactionPath     = "d:\VfpTransaction\ktb-ais\"
enddefine 


*** ========================================================= ***
define class aisDevice as Custom
  cType = null
  cTitle = "default" 
  IsWebBrowser = .f.
  * --------------------------------------------------------- *
  function CompilerRequiresLogins
    return .t.
  endfunc 
  * --------------------------------------------------------- *
  function getSessionID 
    error "getSessionID must be defined in subclass"
  endfunc 
  * --------------------------------------------------------- *
  function NoteNewSession(tcSessId, toPage)
  endfunc 
enddefine

*** ========================================================= ***
define class aisBrowserDevice as aisDevice
  cType = "browser"
  cTitle = "Web Browser Device" 
  IsWebBrowser = .T.  && affects 403 vs redirect decisions, possibly others
  * --------------------------------------------------------- *
  function getSessionID  && browser uses temp/session cookies:
    return Request.getCookie('KTB_SESSION_ID')
  endfunc 
  * --------------------------------------------------------- *
  function NoteNewSession(tcSessId, toPage, toPolicy)
    page.oHttpHeader.AddCookie('KTB_SESSION_ID', m.tcSessID, "/",, ;
      Request.isLinkSecure(), .t.) && Secure and HttpOnly flags
    return
  endfunc 
enddefine

*** ===================================================== ***
define class aisLogRequest as L7LogRequest 
  cStructureAugment = [User_PK C(32), User_ID C(32), Emulate_PK C(32), Emulate_ID C(32)] + ;
    [, Request_ID C(32)]
  * --------------------------------------------------------- *
  function AddAugmentedData(toRec)
    local lcCurrKey, lcCurrID, lcTrueKey, lcTrueID, lvItem
    
    with m.toRec
      * adjust URL if indicated
      lcStr = Environ.item('app.log_url')
      if !empty(m.lcStr)
        m.toRec.URL = m.lcStr
      endif 
      if vartype(CurrentUser) = "O"
        lcCurrKey = CurrentUser.GetUserKey()
        lcCurrID = CurrentUser.GetUserID()
        if vartype(TrueUser) = "O"
          lcTrueKey = TrueUser.GetUserKey()
          lcTrueID = TrueUser.GetUserID()
        else 
          lcTrueKey = m.lcCurrKey
          lcTrueID = m.lcCurrId
        endif 
        .User_PK = m.lcTrueKey  && 02-06-2010: leading "." was missing in these 2 lines
        .User_ID = m.lcTrueId
        if m.lcTrueKey <> m.lcCurrKey
          .Emulate_PK = m.lcCurrKey 
          .Emulate_ID = m.lcCurrId
        endif 
      endif
    endwith   

    return  
  endfunc  && addAugmentedData 
enddefine   && aisLogRequest 

*** ===================================================== ***
define class aisBody AS L7PageElement

  ADD OBJECT oSidebar   AS aisSidebar          WITH cID = "sidebar"  
  ADD OBJECT oHeader    AS L7PageElement       WITH cID = "header"
  ADD OBJECT oMain      AS aisContentElement   WITH cID = "content"
  ADD OBJECT oStatusBar AS L7PageElement       WITH cID = "status_bar"
   
  cTag = "div"  && outer div
  cID  = "outer-bundle"
  * --------------------------------------------------------- *
  function CurrentOutputObject_ACCESS
    return THIS.oMain  && where Response should Write()
  endfunc   
  * --------------------------------------------------------- *
  function RenderImplementation(lcText)
    local lcText, lcTmp

    with this.oHeader
      .WriteLn(textmerge('<div id="server-override-notice-content"><<request.getServerName()>></div>'))

      text to lcTmp noshow pretext 3
        <h2 id="server-page-title"><<page.cSubTitle>></h2>
        <div class="user">
          User: <span class="user-name"><<CurrentUser.getUserName()>></span> 
          (<a href="<<stuffUrl(page.cUrlA,'l','0',2,'Login')>>" id="signOut">sign out</a>)
        </div>

      endtext
      .Write(textmerge(m.lcTmp))

      lcText = m.lcText + .Render() + CRLF
    endwith 

    lcText = m.lcText + THIS.oMain.Render() + CRLF 
    
    lcText = m.lcText + THIS.oSidebar.Render() + CRLF

    with this.oStatusBar
      text to lcTmp noshow pretext 3
        <div>Server: <<request.getServerName()>> (<<config.cServerRole>>) at <<datetime()>></div>
      endtext
      .Write(textmerge(m.lcTmp))
      lcText = m.lcText + .Render() + CRLF
    endwith 

    return 
  endfunc  && RenderImplementation
  * --------------------------------------------------------- *
  function  AfterRender(lcText)
    return 
  endfunc 
enddefine 

*** ========================================================= ***
define class aisSidebar AS L7MenuElement
  cMenuItemCssClass = "link"
  * --------------------------------------------------------- *
  function prepFromPage( toPage )
    this.oMenu = page.oMenu.getItem( "main" )
    dodefault( m.toPage )
  endfunc
  * --------------------------------------------------------- *
  function renderMenuStart( toMenu )
    return []  && [<div style="display: block;" id="sidebar">] + CR 
  endfunc
  * --------------------------------------------------------- *
  function renderMenuEnd( toMenu )
    return []  && [</div><!-- sidebar end -->] + CR 
  endfunc
  * --------------------------------------------------------- *
  function renderSubMenuStart( toMenu )
    local lcRet
    WITH toMenu
      lcRet = EVL(.cDisplayName, .cFullNodePath )
      IF VARTYPE(.cUrl) = "C" AND NOT EMPTY(.cUrl)
        LOCAL lcOptions
        lcOptions  = LTRIM(IIF( empty( .cLinkAtt ), [], .cLinkAtt ) + ;
                     IIF( EMPTY( .cToolTip ), "", [ title="] + .cToolTip + ["] ))
        lcRet = HTLink(.cUrl, m.lcRet, m.lcOptions)
      ENDIF
      lcRet =   [<!-- ] + toMenu.cFullNodePath + [ Sub-Menu -->] + CR + ;
                [<h1>] + m.lcRet + [</h1>] + CR + ;
                [<ul>] + CR
     ENDWITH 
    return lcRet
  endfunc
  * --------------------------------------------------------- *
  function renderSubMenuEnd( toMenu )
    return [</ul>] + CR
  endfunc
  * --------------------------------------------------------- *
  function renderMenuItemStart( toMenu )
    local lcRet
    lcRet =   [<li class="] + THIS.cMenuItemCssClass + [">] + CR 
    return lcRet
  endfunc
  * --------------------------------------------------------- *
  function renderMenuItemEnd( toMenu )
    return [</li>] + CR
  endfunc

  * --------------------------------------------------------- *
  function renderMenuItem( toItem )
    local lcOptions, lcLinkText, lcRet, llInContext
    
    with toItem
      llInContext = this.isInContext( this.cCurrentContext, m.toItem)
      lcOptions  = LTRIM(IIF( empty( .cLinkAtt ), [], .cLinkAtt ) + ;
                   IIF( EMPTY( .cToolTip ), "", [ title="] + .cToolTip + ["] ))
      lcLinkText = .cDisplayName 

      IF m.llInContext
        lcLinktext = [<span class="] + THIS.cMenuItemSelectedCssClass + [">] + ;
          m.lcLinktext + [</span>]
      ENDIF

      if !m.llInContext AND VARTYPE(toItem.cUrl) = 'C' AND NOT EMPTY(.cUrl)
        lcLinkText = HTLink( .cURL, m.lcLinkText, m.lcOptions )
      endif 
      
      lcRet = m.lcLinkText + CR
    endwith
    return lcRet
  endfunc
  * --------------------------------------------------------- *
enddefine  && aisSidebar

*** ===================================================== ***
define class aisContentElement AS L7PageElement
  * --------------------------------------------------------- *
  function RenderImplementation(tcText)
    dodefault(@tcText)
    tcText = ;
      [<!--EXTRACT START-->] + CRLF + ;
      m.tcText + ;
      CRLF + [<!--EXTRACT END-->] + CRLF 
    return   
  endfunc  
enddefine  

*** ===================================================== ***
define class aisTable as L7Table
  * table class determinants:
  lSortable      = .t. 
  cTableClass    = "display"  && CSS Class [note, will have sortable added if above flag set]
  * additional overrides of L7Table:
  nTableCellSpacing = 0
  cDataRowClass  = [IIF(THIS.nGroupRowCount%2=1,"oddX","evenX")] 
  cNullDisplay   = "--"  && CHR(38) + [nbsp;]
  *--------------------------------------------  
  function cTableClass_ACCESS  && ref: L7HtmlTableRender.openTable in L7TableRender.prg
    * note: base L7Table class does not use an access method here
    return alltrim(;
      this.cTableClass + " " + iif(this.lSortable, "sortable", "") ;
      )  && alltrim trick to remove space on either side unless needed as separator
  endfunc
  *--------------------------------------------  
  function addCounterColumn(tnType, tcHeading, tcClass)
    local loCol
    loCol = this.addColumn( ;
      evl(m.tnType, L7_ELEMENTTYPE_RELATIVE_RECNO), ;
      .f., ;
      evl(m.tcHeading, "#"))
      
    loCol.cDataType = "I"
    if !empty(m.tcClass)
      loCol.cCellStyle = "" && needed to override L7 _assign setting based on data type
      loCol.cCellClass = m.tcClass
    endif
    
    return m.loCol
  endfunc   
enddefine  

*** ===================================================== ***
define class aisForm AS L7Form
  * App-wide sub-class.
  cCssStyle = "width: 80%;"
  cRenderClass = "L7FormRenderOverUnder"
  nLayoutStyle = 2  && 1 = over/under, 2 = 2-column
  lToolbarAtTop = .T.
  lResetButton = .F.
  lNewRecord = .F.
  cSubmitCaption = "Save"
enddefine   && aisForm

*** ===================================================== ***
define class AisLoginForm AS L7Form
  cFormName = "LoginForm"
  cHtmlName = "LoginForm"
  lResetButton = .F.
  cSubmitCaption = "Log In"
  cCssStyle = "width: 40em;"
  cTitle = "User Login Form"
  cCustom_Message = ""
  cCustom_Warning = ""
  cCustom_Help = ""
  * --------------------------------------------------------- *
  function AddControls
    local lcStr
    with this
      if !empty(this.cCustom_Warning)
        .AddObject("lblWarning", "L7Divider")
        with .lblWarning
          ** .cCssClass = "FormControlInvalid"
          .cLabel = THIS.cCustom_Warning
        endwith 
      endif 
      if !empty(this.cCustom_Help)
        .AddObject("lblHelp", "L7Divider")
        with .lblHelp
          .cCssClass = "FormControl"
          .cLabel = this.cCustom_Help
        endwith 
      endif 
      .AddObject( "txtUserId", "L7Textbox" )
      with .txtUserId
        .nSize = 40
        .cLabel = "User ID"
        ** .lAutoComplete = .F.
        .cValidChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-.@ '
        .cFieldType = "C"  
        .lLtrimInput = .T.
      endwith 
      .AddObject( "txtPassword", "AisPasswordTextbox" ) && this allows PW-appropriate special chars
      with .txtPassword
        .cLabel = "Password"
        .cInstructions = "(case sensitive)"
      endwith 
      if !empty(this.cCustom_Message)
        .AddObject("lblFailure", "L7Divider")
        with .lblFailure
          .cCssClass = "FormControlInvalid"
          .cLabel = THIS.cCustom_Message
        endwith 
      endif 
    endwith   && THIS
    return  
  endfunc    && AddControls
enddefine  && AisLoginForm

*** ========================================================= ***
define class AisPasswordTextbox AS L7Textbox
  lPassword = .T.
  lRequired = .T.
  nSize = 24
  cLabel = "Password"
  cValidChars = L7_PASSWORD_CHARACTERS
  cInstructions = "(case sensitive)"
enddefine   

*** ========================================================= ***
* End: AisClasses.PRG
