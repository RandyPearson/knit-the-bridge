* AisClasses.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* App Classes:
set procedure to AisApp     additive  && Application Object
set procedure to AisClasses additive  && THIS file
set procedure to AisUtils   additive  && special tools (import...)
set procedure to AisUser    additive  && User class
set procedure to AisDQ      additive  && Data and Query classes 

* Page Classes:
set procedure to AisPages   additive   
set procedure to AisAdm     additive  && ADMIN pages  
set procedure to AisArt     additive  && Artist pages  
set procedure to AisPce     additive  && Piece pages  
set procedure to AisPnl     additive  && Panel pages  
set procedure to AisFac     additive  && Facility pages  
set procedure to AisLoc     additive  && Location pages  
set procedure to AisFil     additive  && FILE pages  
set procedure to AisDon     additive  && Donation pages  
set procedure to AisTrn     additive  && Training pages  
set procedure to AisSft     additive  && Shift pages  

return 

* --------------------------------------------------------- *
function AisFormatID(lcId)
  if !vartype(m.lcId) == "C" or isnull(m.lcId) or empty(m.lcId)
    return m.lcId
  endif 
  local loRE, lcRepl, lcRet, loExc
  loRE = goL7App.helpers.item("RegEx-Zero-Padding")

  ** lcPat = '([A-Z]*?[A-Z])(0+)([1-9][0-9]*)'
  lcRepl = '$1<span class="padl">$2</span>$3'
  try
    lcRet = loRE.Replace(m.lcId, m.lcRepl)
  catch to loExc
    lcRet = m.lcId
  endtry 
  return m.lcRet
endfunc 
* --------------------------------------------------------- *
function AisAssignID(lcPref)
  local lnNo, lcRet
  lcPref = upper(alltrim(m.lcPref))
  lcPref = chrtran(m.lcPref, chrtran(m.lcPref, L7_ALPHA_UPPER_CHARACTERS, ''), '')
  lnNo = AisNextId(m.lcPref)
  return m.lcPref + padl(transform(m.lnNo), THISAPP_LENGTH_ID_FIELDS - len(m.lcPref), "0")
endfunc 
* --------------------------------------------------------- *
function AisNextId(lcName)
  local lnNextId, loSelect, vp_cName, ii, llOK
  lcName = padr(upper(m.lcName), THISAPP_LENGTH_UNIQUE_NAME)
  loSelect = createobject("L7PreserveSelect") 
  lnNextId = -1
  use KtbAis!Unique again alias AisNextId_ in select("AisNextId_")
  select AisNextId_ 
  llOk = .t.
  locate for Unq_Name = m.lcName

  if !found()
    lnNextId = 1
    append blank
    = rlock()
    replace Unq_Name WITH m.lcName
  else
    if rlock() 
      lnNextId = Unq_Last_Num + 1
    else
      llOK = .f. 
      error "could not lock Unique"
    endif 
  endif 
  if m.llOK
    replace Unq_Last_Num WITH m.lnNextId, ;
      Unq_Rev_Time with Environ.item("appManager.startTime")
  endif 
  unlock 
  use in select("AisNextId_")
  return m.lnNextId
endfunc 
* End: NextId()

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
  
  cActionEmail         = "KnitTheBridge@gmail.com" 
  cActionFrom          = "Amanda Gross" 
  
  lLockLocations       = .t.
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

*** ========================================================= ***
define class aisVirtualPolicy as Custom
  cTitle = "default" 
  nSessionTimeout = null  && null === use app default
  lAuthRequired = .f. && for info only--IIS must be configured for this
  lLogins = .t.
  lPublicFacing = .f.
  cCssClass = "ktb-ais"
enddefine

*** ========================================================= ***
define class aisKtbAisVirtualPolicy as aisVirtualPolicy 
  cTitle = "AIS" 
  lAuthRequired = .f.  && for info only--IIS must be configured for this
  cCssClass = "ktb-ais"
enddefine

*** ========================================================= ***
define class aisKtbPubVirtualPolicy as aisVirtualPolicy 
  cTitle = "PUB" 
  lAuthRequired = .f.  && for info only--IIS must be configured for this
  lLogins = .f.
  lPublicFacing = .t.
  cCssClass = "ktb-pub"
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
        <h2 id="server-app-title"><<page.cTitle>></h2>
        <h1 id="server-page-title"><<page.cSubTitle>></h1>

      endtext
      .Write(textmerge(m.lcTmp))

      if !CurrentUser.IsAnonymous()
        text to lcTmp noshow pretext 3
          <div class="user">
            User: <span class="user-name"><<CurrentUser.getUserName()>></span> 
            (<a href="<<stuffUrl(page.cUrlA,'l','0',2,'Login')>>" id="signOut">sign out</a>)
          </div>

        endtext
        .Write(textmerge(m.lcTmp))
      endif

      lcText = m.lcText + .Render() + CRLF
    endwith 

    lcText = m.lcText + THIS.oMain.Render() + CRLF 
    
    lcText = m.lcText + THIS.oSidebar.Render() + CRLF

    with this.oStatusBar
      text to lcTmp noshow pretext 3
        <div id="statusText">Server: <<request.getServerName()>> (<<config.cServerRole>>) at <<datetime()>></div>
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
    local lcRet, lcOptions
    with toMenu
      lcRet = evl(.cDisplayName, .cFullNodePath )
      if vartype(.cUrl) = "C" and !empty(.cUrl)
        lcOptions = ltrim(iif(vartype(.cLinkAtt) <> 'C' or empty(.cLinkAtt ), [], .cLinkAtt) + ;
                    iif(empty(.cToolTip ), "", [ title="] + .cToolTip + ["] ))
        lcRet = HTLink(.cUrl, m.lcRet, m.lcOptions)
      endif 
      lcRet =   [<!-- ] + toMenu.cFullNodePath + [ Sub-Menu -->] + CR + ;
                [<h2>] + m.lcRet + [</h2>] + CR + ;
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
      lcOptions  = ltrim(iif(vartype(.cLinkAtt) <> 'C' or empty(.cLinkAtt), [], .cLinkAtt ) + ;
                   iif(empty( .cToolTip ), "", [ title="] + .cToolTip + ["] ))
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
define class aisRecordElement as L7RecordElement
  cTag              = "div"
  cCssClass         = "record"
  cHeadingCssClass  = "record-heading"  && default for separator rows
enddefine 

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
  nTableCellSpacing = null
  nTableBorder      = null
  
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
  *!* cCssStyle = "width: 80%;"
  cRenderClass = "L7FormRenderOverUnder"
  nLayoutStyle = 2  && 1 = over/under, 2 = 2-column
  lToolbarAtTop = .T.
  lResetButton = .F.
  lNewRecord = .F.
  lPreventMultipleSubmissions = .F.  && allow re-submit 
  cSubmitCaption = "Save"
  * customize: 
  cEntityAlias = null  && e.g., "Artist"
  cEntityAbbr  = null  && e.g., "Art"
  * --------------------------------------------------------- *
  function addTimeStampControls()
    local lcFld1, lcFld2
    with this
      .AddObject("lblRev_Time", "L7Label")
      with .lblRev_Time
        .cGroupId = 'timestamp'
        .cLabel = "Record last updated"
        lcFld1 = this.cEntityAlias + "." + this.cEntityAbbr + "_Rev_Time"
        lcFld2 = this.cEntityAlias + "." + this.cEntityAbbr + "_Rev_Art_FK"
        .cShowExpression = [L7TimeDiff(] + m.lcFld1 + [) + " by " + aisArtistName(] + m.lcFld2 + [)]
        .cCssClass = "FormControlPrivate"
      endwith 

      .AddObject("lblOrig_Time", "L7Label")
      with .lblOrig_Time
        .cGroupId = 'timestamp'
        .cLabel = "Record first created"
        lcFld1 = this.cEntityAlias + "." + this.cEntityAbbr + "_Orig_Time"
        lcFld2 = this.cEntityAlias + "." + this.cEntityAbbr + "_Orig_Art_FK"
        .cShowExpression = [L7TimeDiff(] + m.lcFld1 + [) + " by " + aisArtistName(] + m.lcFld2 + [)]
        .cCssClass = "FormControlPrivate"
      endwith 
      
    endwith
    return 
  endfunc  && addTimeStampControls
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
define class AisRadioCheckbox AS L7Checkbox
  nMode = L7_MULTI_RADIOBUTTON
  nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
  lFalseBeforeTrue = .T.
  cInterControlText = NULL 
enddefine 

*** ========================================================= ***
* End: AisClasses.PRG
