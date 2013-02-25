* L7PageElements.PRG
* 
* Subclasses of L7PageElement that implement specific artifacts.

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

* Test mode
IF PROGRAM(-1) = 1
  * just like __Name__ = "__Main__" in Python
  SET PROCEDURE TO L7PageElement, L7Utils, L7HtmlLib ADDITIVE 
  CLEAR
  
  LOCAL loEl, loItem
  loEl = CREATEOBJECT("L7SuperArtifactsElement")
  WITH loEl
    .AddObserver("L7IntraItemMenuObserver")
    * .cTag = ""
    loItem = .GetEmptyItem()  
    loItem.lTextmergeAfterRender = .T.
    loItem.cName = "date"
    loItem.cTitle = "the date"
    loItem.vBaseItem = "<<DATE()>>"
    .Artifacts.Add(loItem)
    loItem = .GetEmptyItem()  
    loItem.lTextmergeAfterRender = .T.
    loItem.vBaseItem = HTWrap("<<VERSION()>>", 'h2')
    .Artifacts.Add(loItem)
    .Artifacts.Add(.Adapt("dumb string"))
    ?
    ? DATETIME()
    ? .Render()
  ENDWITH 
ENDIF 
RETURN 

*** ===================================================== ***
DEFINE CLASS L7SuperArtifactsObserver AS Custom
  cGUID = NULL
  * --------------------------------------------------------- *
  FUNCTION init
    this.cGUID = GetGUIDString(32)
  ENDFUNC   
  * --------------------------------------------------------- *
  FUNCTION setup(loElem)
    * override in subclass to bind events of target element
  ENDFUNC 
ENDDEFINE 

*** ===================================================== ***
DEFINE CLASS L7IntraItemMenuObserver AS L7SuperArtifactsObserver
  lExtraMenuAtEnd = .F.
  * --------------------------------------------------------- *
  FUNCTION setup(toElem)
    BINDEVENT(m.toElem, "WouldRenderArtifacts", THIS, "BeforeRenderArtifacts")
    BINDEVENT(m.toElem, "BeforeRenderOneArtifact",    THIS, "BeforeRenderOneArtifact")
    BINDEVENT(m.toElem, "AfterRenderOneArtifact",    THIS, "AfterRenderOneArtifact")
    BINDEVENT(m.toElem, "DidRenderArtifacts",   THIS, "AfterRenderArtifacts")
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION BeforeRenderArtifacts(toStt)
    LOCAL loObj
    * Attach a sub-object for this observer to element's state object.
    loObj = CREATEOBJECT("Empty")
    ADDPROPERTY(loObj, "cMenu", "")
    ADDPROPERTY(toStt, "obs" + THIS.cGUID, m.loObj)
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION BeforeRenderOneArtifact(toStt, toItem)
    LOCAL loObj
    loObj = EVALUATE("toStt.obs" + THIS.cGUID)
    IF NOT ISNULL(toItem.cTitle)
      loObj.cMenu = loObj.cMenu + TEXTMERGE([<a href="#<<toItem.cName>>"><<toItem.cTitle>></a>]) 
    ENDIF 
    IF toItem.lMenuBefore
      toStt.cCurrObjOut = toStt.cCurrObjOut + ;
        TEXTMERGE([<div class="ipMenu" id="<<toItem.cName>>"><<CRLF>>INSERT<<THIS.cGUID>></div>])
    ENDIF 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION AfterRenderOneArtifact(toStt, toItem)
    LOCAL loObj
    loObj = EVALUATE("toStt.obs" + THIS.cGUID)
    IF toItem.lMenuAfter
      toStt.cCurrObjOut = toStt.cCurrObjOut + ;
        TEXTMERGE([<div class="ipMenu" id="<<toItem.cName>>-2"><<CRLF>>INSERT<<THIS.cGUID>></div>])
    ENDIF 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION AfterRenderArtifacts(toStt)
    LOCAL loObj
    loObj = EVALUATE("toStt.obs" + THIS.cGUID)
    IF this.lExtraMenuAtEnd
      toStt.cCombo = toStt.cCombo + ;
        TEXTMERGE([<div class="ipMenu"><<CRLF>>INSERT<<THIS.cGUID>></div>])
    ENDIF 
    toStt.cCombo = STRTRAN(toStt.cCombo, "INSERT" + THIS.cGUID, loObj.cMenu)
    RETURN 
  ENDFUNC 
ENDDEFINE 

*** ===================================================== ***
DEFINE CLASS L7SuperArtifactsElement AS L7PageElement
  ADD OBJECT Observers AS Collection
  ADD OBJECT Artifacts AS Collection
  lTextmergeCombo = .F.
  cNamePrefix = ""
  * --------------------------------------------------------- *
  FUNCTION AddObserver(tvClassOrObject)
    LOCAL loObs
    loObs = IIF(VARTYPE(m.tvClassOrObject) = "C", CREATEOBJECT(m.tvClassOrObject), m.tvClassOrObject)
    THIS.Observers.Add(m.loObs)
    loObs.Setup(THIS)
    RETURN m.loObs
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcTxt)
    LOCAL loObj, lvItem, lcType, loState
    loState = CREATEOBJECT("Empty")
    ADDPROPERTY(loState, "cCombo", "")
    ADDPROPERTY(loState, "oCurrObj", NULL)
    ADDPROPERTY(loState, "cCurrObjOut", "")
    ADDPROPERTY(loState, "lRenderCurrObj", .F.)
    RAISEEVENT(THIS, "WouldRenderArtifacts", loState)
    FOR EACH loObj IN THIS.Artifacts
      loState.cCurrObjOut = ""
      loState.lRenderCurrObj = .T.
      IF PEMSTATUS(loObj, "cIncludeWhen", 5) AND NOT EVALUATE(loObj.cIncludeWhen)
        LOOP
      ENDIF 
      RAISEEVENT(THIS, "BeforeRenderOneArtifact", m.loState, m.loObj)
      IF loState.lRenderCurrObj
        IF PEMSTATUS(loObj, "vBaseItem", 5) 
          lvItem = loObj.vBaseItem
        ELSE 
          lvItem = m.loObj
        ENDIF   
        lcType = VARTYPE(m.lvItem)
        DO CASE
        CASE m.lcType = "O" && object, assume a render method
          lcTmp = lvItem.Render()
        CASE m.lcType = "C" && already a string
          lcTmp = m.lvItem
        OTHERWISE
          lcTmp = TRANSFORM(m.lvItem)
        ENDCASE
      
        * Apply post-render() textmerge, if specified. NOTE: This is
        * independent of pre-rendering, allowing page element to be 
        * called in a loop, with different values merged into "rendered" output.
        * When combined with "include expressions", provides for both
        * dynamic combinations and content.
        *
        IF PEMSTATUS(loObj, "lTextmergeAfterRender", 5) AND loObj.lTextmergeAfterRender
          lcTmp = TEXTMERGE(m.lcTmp)
        ENDIF 
        loState.cCurrObjOut = loState.cCurrObjOut + m.lcTmp
        RAISEEVENT(THIS, "AfterRenderOneArtifact", m.loState, m.loObj)
      ENDIF 
      * Add item to overall string.
      loState.cCombo = loState.cCombo + loState.cCurrObjOut 
    ENDFOR
    RAISEEVENT(THIS, "DidRenderArtifacts", loState)
    * Add item to overall string (passed by ref).
    lcTxt = m.lcTxt + loState.cCombo
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION WouldRenderArtifacts(toState)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION DidRenderArtifacts(toState)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION BeforeRenderOneArtifact(toState, loObj)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AfterRenderOneArtifact(toState, loObj)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddArtifact(toArt)
    this.Artifacts.Add(m.toArt)
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION AddItem(tvItem, tcName, tcTitle, tcWhen, tlTextmerge)
    LOCAL loObj
    loObj = THIS.Adapt(m.tvItem)
    this.Artifacts.Add(m.loObj)
    IF VARTYPE(m.tcName) = "C"
      loObj.cName = THIS.cNamePrefix + m.tcName  && refactor to more accessible spot
    ENDIF 
    IF VARTYPE(m.tcTitle) = "C"
      loObj.cTitle = m.tcTitle
    ENDIF 
    IF VARTYPE(m.tcWhen) = "C"
      loObj.cIncludeWhen = m.tcWhen
    ENDIF 
    loObj.lTextmergeAfterRender = m.tlTextmerge
    RETURN m.loObj
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION Adapt(tvItem)
    LOCAL loObj
    loObj = CREATEOBJECT("L7ArtifactItem")
    loObj.vBaseItem = m.tvItem
    RETURN m.loObj
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION GetEmptyItem
    RETURN CREATEOBJECT("L7ArtifactItem")
  ENDFUNC 
ENDDEFINE && L7SuperArtifactsElement

*** ===================================================== ***
DEFINE CLASS L7ArtifactItem AS Line
  vBaseItem = NULL
  cName = NULL
  cTitle = NULL
  cIncludeWhen = ".T."
  lTextmergeAfterRender = .F.
  lMenuBefore = .T.  && only applicable if an observer cares
  lMenuAfter  = .F.  && only applicable if an observer cares
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7HorizontalMenuBand AS L7PageElement
  oMenu = NULL
  cCssPrefix = ""
  cTag = "div"
  * --------------------------------------------------------- *
  FUNCTION SetMenuObject(loObj)
    THIS.oMenu = m.loObj
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)  
    LOCAL loItem, llFirst, lcOptions, lcLinkText
    THIS.cCssClass = THIS.cCssPrefix + "Menu"
    * Loop through menu structures, starting with sub-menus:
    llFirst = .T.
    FOR EACH loItem IN THIS.oMenu


      IF llFirst = .T.
         llFirst = .F.
         *  [<div class="] + THIS.cCssPrefix + [Menu">] + CR + 

         lcText = m.lcText + ;
           [<table summary="layout" cellspacing=1 class="] + THIS.cCssPrefix + [MenuTable">] + CR + ;
           [<tr>] + CR
      ENDIF
      lcOptions = EVL(loItem.cLinkAtt, []) + ;
        IIF(EMPTY(loItem.cToolTip), [], [ title="] + loItem.cToolTip + ["])
      lcLinkText = loItem.cDisplayName
      lcText = m.lcText + ;
        [<td class="] + THIS.cCssPrefix + [MenuItem">] 
      IF EMPTY(loItem.cURL)
        lcText = m.lcText + HTWrap(m.lcLinkText, [span], m.lcOptions)
      ELSE
        lcText = m.lcText + HTLink(loItem.cURL, m.lcLinkText, m.lcOptions)
      ENDIF
      lcText = m.lcText + [</td>] + CR
    ENDFOR
    IF NOT m.llFirst  && an item was encountered
      ** lcText = m.lcText + [</tr>] + [</table>] + [</div>] + CR
      lcText = m.lcText + [</tr>] + [</table>] + CR
    ENDIF
  ENDFUNC  && RenderImplementation
ENDDEFINE  && L7HorizontalMenuBand 

*** ========================================================= ***
DEFINE CLASS L7ListedMenu AS L7PageElement
  oMenu = NULL
  cCssPrefix = ""
  cTag = "div"
  * --------------------------------------------------------- *
  FUNCTION SetMenuObject(loObj)
    THIS.oMenu = m.loObj
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)  
    LOCAL loItem, llFirst, lcOptions, lcLinkText
    THIS.cCssClass = THIS.cCssPrefix + "Menu"
    * Loop through menu structures, starting with sub-menus:
    llFirst = .T.
    FOR EACH loItem IN THIS.oMenu
      IF llFirst = .T.
        llFirst = .F.
        lcText = m.lcText + [<ol>] + CR
      ENDIF
      lcOptions = EVL(loItem.cLinkAtt, []) + ;
        IIF(EMPTY(loItem.cToolTip), [], [ title="] + loItem.cToolTip + ["])
      lcLinkText = loItem.cDisplayName
      lcText = m.lcText + ;
        [<li>] 
      IF EMPTY(loItem.cURL)
        lcText = m.lcText + HTWrap(m.lcLinkText, [span], m.lcOptions)
      ELSE
        lcText = m.lcText + HTLink(loItem.cURL, m.lcLinkText, m.lcOptions)
      ENDIF
      lcText = m.lcText + [</li>] + CR
    ENDFOR
    IF NOT m.llFirst  && an item was encountered
      lcText = m.lcText + [</ul>] + CR
    ENDIF
  ENDFUNC  && RenderImplementation
ENDDEFINE  && L7ListedMenu

*** ========================================================= ***
DEFINE CLASS L7MenuElement as L7PageElement
  * base menu renderer

  cPath                        = []  && the submenu of interest for this bar (this is a group)
  cCurrentContext              = []  && a menu path representing the current context of the user
  lRenderParentMenus           = .f.
  oMenu                        = null  && the menu to render (may be NULL in which case, we take the
  
  *-- css properties
  cMenuCSSClass                = [Menu]     && overall menu class
  cSubMenuCSSClass             = [SubMenu]   && overall normal sub-menu class
  cSubMenuSelectedCSSClass     = [SubMenuCurrent]  && 
  cSubMenuCurrentCSSClass      = [SubMenuSelected]
  
  cMenuItemCSSClass            = [MenuItem]
  cMenuItemCurrentCSSClass     = [MenuItemCurrent]  && current means anything on the current menu path
  cMenuItemSelectedCSSClass    = [MenuItemSelected] && "selected" means the current menu item selected 
  cMenuItemHoverCSSClass       = [MenuItemHover]    && class for client-side hover-swap

  * --------------------------------------------------------- *
  function prepFromPage( toPage )
    this.cPath              = toPage.cMenuPath            && position in the menu hierarchy to start rendering
    this.cCurrentContext    = toPage.cCurrentMenuContext  && current context (used for style selections)
    this.lRenderParentMenus = toPage.lRenderParentMenus   && if .t., all parent menus will be rendered as well
    if isnull( this.oMenu )
      this.oMenu = page.oMenu.getItem( this.cPath )
    endif
  endfunc

  * --------------------------------------------------------- *
  function beforeRender(lcText)
    this.prepFromPage( m.page )
  endfunc

  * --------------------------------------------------------- *
  function isInContext( tcContextPath, toItem )
    * returns .t. if loItem is in the current path
    * eg: admin\users\adduser = admin\user
    * that is, admin\user is along the complete context path of admin\users\adduser
    return tcContextPath = toItem.cFullNodePath
  endfunc
  * --------------------------------------------------------- *
  function renderMenuStart( toMenu )
    return [<div class="] + this.cMenuCSSClass + [">] + CR
  * --------------------------------------------------------- *
  function renderMenuEnd( toMenu )
    return [</div>] + CR
  * --------------------------------------------------------- *
  function renderSubMenuStart( toMenu )
    return [<div class="] + this.cSubMenuCSSClass + [">] + CR
  * --------------------------------------------------------- *
  function renderSubMenuEnd( toMenu )
    return [</div>]
  * --------------------------------------------------------- *
  function renderMenuItemStart( toMenuItem )
    return [<div class="] + this.cMenuItemCSSClass + [">] + CR
  * --------------------------------------------------------- *
  function renderMenuItemEnd( toMenuItem )
    return [</div>]
  * --------------------------------------------------------- *
  function renderMenuItem( toMenuItem )
    *-- obviously, this should be overwritten.
    return toMenuItem.cDisplayName

  * --------------------------------------------------------- *
  FUNCTION renderImplementation( lcRet )

    lcRet = lcRet + THIS.renderMenuStart()
    LOCAL loItem
    FOR EACH loItem IN THIS.oMenu
      IF loItem.isSubMenu() 
        lcRet = m.lcRet + THIS.renderSubMenu( loItem)
      ENDIF
    ENDFOR
    lcRet = lcRet + THIS.renderMenuEnd()
    RETURN .T.
  ENDFUNC

  * --------------------------------------------------------- *
  function renderSubMenu( toMenu )
    *-- called from renderImplementation()
    local lcRet

    lcRet = this.renderSubMenuStart( toMenu ) + ;
            this.renderMenuItems( toMenu ) + ;
            this.renderSubMenuEnd( toMenu )
    return lcRet
  endfunc
  * --------------------------------------------------------- *
  function renderMenuItems( toMenu )
    local lcRet, loItem
    lcRet = []
    for each loItem in toMenu
    
      lcRet = lcRet + this.renderMenuItemStart( loItem ) + ;
                      this.renderMenuItem( loItem ) + ;
                      this.renderMenuItemEnd( loItem )
    endfor
    return lcRet
  endfunc
  * --------------------------------------------------------- *
ENDDEFINE  && L7MenuElement

*** ========================================================= ***
DEFINE CLASS L7MainTextMenu AS L7MenuElement
  lIncludeProcessingInfo = .F.
  * --------------------------------------------------------- *
  function prepFromPage( toPage )
    this.oMenu = page.oMenu.getItem( "main" )
    dodefault( m.toPage )
  endfunc
  * --------------------------------------------------------- *
  function renderMenuStart( toMenu )
    local lcRet
    lcRet = []
    lcRet = m.lcRet + [<!-- Inner Table for Menu -->] + CR + ;
        [<table summary="layout" class="] + THIS.cMenuCssClass + [">] + CR 
    return lcRet
  endfunc
  
  * --------------------------------------------------------- *
  function renderMenuEnd( toMenu )
    local lcRet
    lcRet = []
    
    *[[move this to BodyLayer defintion:
    IF THIS.lIncludeProcessingInfo
      *? for some reason, the height=99 is not working to move the info to the bottom...
      lcRet = m.lcRet + ;
        [<tr valign="bottom"><td style="height: 99%; text-align: center;">] + CR + ;
        [<p class="ProcessingInfo">]

      lcRet = m.lcRet + Page.GetProcessingInfo() 
      lcRet = m.lcRet + [</p></td></tr>] + CR
    ENDIF
    
    lcRet = m.lcRet + [</table>] + CR + ;
      [<!-- END: Inner Table for Menu -->] + CR
    return lcRet
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
                [<tr valign="top">] + CR + ;
                [<td class="] + THIS.cSubMenuCssClass + [">] + ;
                m.lcRet + ;
                [</td></tr>] + CR 
     ENDWITH 
    return lcRet
  endfunc

  * --------------------------------------------------------- *
  function renderSubMenuEnd( toMenu )
    return CR
  endfunc

  * --------------------------------------------------------- *
  function renderMenuItemStart( toMenu )
    local lcRet
    lcRet =   [<tr><td class="] + THIS.cMenuItemCssClass + [">] + CR 
    return lcRet
  endfunc

  * --------------------------------------------------------- *
  function renderMenuItemEnd( toMenu )
    return [</td></tr>] + CR
  endfunc

  * --------------------------------------------------------- *
  function renderMenuItem( toItem )
    local lcOptions, lcLinkText, lcRet, llInContext
    
    *[[ Change this STYLE= thing once we have color scheme CSS files:
    *[[

    with toItem
      llInContext = this.isInContext( this.cCurrentContext, m.toItem)
      lcOptions  = LTRIM(IIF( empty( .cLinkAtt ), [], .cLinkAtt ) + ;
                   IIF( EMPTY( .cToolTip ), "", [ title="] + .cToolTip + ["] ))
      lcLinkText = .cDisplayName 
      

      IF m.llInContext
        lcLinktext = [<span class="] + THIS.cMenuItemSelectedCssClass + [">] + ;
          m.lcLinktext + [</span>]
      ENDIF

      *? LC: I don't particularly like this overloading deal. 
      *  Cognitive friction, and rendering class clutter are the main reasons.                        
      IF NOT m.llInContext AND VARTYPE(toItem.cUrl) = 'C' AND NOT EMPTY(.cUrl)
        lcLinkText = HTLink( .cURL, m.lcLinkText, m.lcOptions )
      ENDIF
      
      lcRet = m.lcLinkText + CR
    endwith
    return lcRet
  endfunc
  * --------------------------------------------------------- *
ENDDEFINE  && L7MainTextMenu

*** ===================================================== ***
DEFINE CLASS L7LinearArtifactsElement AS L7PageElement
  * sequential linear renderer of ad-hoc material
  ADD OBJECT Artifacts AS Collection
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcTxt)
    LOCAL lvItem, lcType
    FOR EACH lvItem IN THIS.Artifacts
      lcType = VARTYPE(m.lvItem)
      DO CASE
      CASE m.lcType = "O" && object, assume a render method
        lcTxt = m.lcTxt + lvItem.Render()
      CASE m.lcType = "C" && already a string
        lcTxt = m.lcTxt + m.lvItem
      OTHERWISE
        lcTxt = m.lcTxt + TRANSFORM(m.lvItem)
      ENDCASE
    ENDFOR
  ENDFUNC
ENDDEFINE  && L7LinearArtifactsElement 

*** =================================================== ***
DEFINE CLASS L7PerformanceInfoElement AS L7PageElement
* Very crude class for quick debugging of performance issues.
*       usage: loPerf = createobject("L7PerformanceInfoElement")
*  as desired: loPerf.AddItem("item description text")
*   to render: Response.Write(loPerf.Render())
  cTag = "div"
  cCssClass = "DebugInfo"
  lAutoAddStartLine = .T.
  lAutoAddFinishLine = .T.
  PROTECTED nItems
  DIMENSION aItems[ 1, 2]
  nItems = 0
  nStart = 0
  nLast = 0
  nBadNewsTime = 0.05
  * ------------------------------------------------------- *
  FUNCTION AfterInit
    THIS.Reset()
    RETURN
  ENDFUNC
  * ------------------------------------------------------- *
  FUNCTION Reset
    WITH THIS
      .nStart = SECONDS()
      .nLast = THIS.nStart
      IF .lAutoAddStartLine
        .nItems = 1
        DIMENSION .aItems[ 1, 2]
        .aItems[ 1, 1] = "Performance Object Started"
        .aItems[ 1, 2] = 0
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC
  * ------------------------------------------------------- *
  FUNCTION AddItem( lcText)
    LOCAL lnSeconds, lnDiff
    lnSeconds = SECONDS()
    lnDiff = MOD( m.lnSeconds - THIS.nLast, 86400 )
    THIS.nLast = m.lnSeconds
    THIS.nItems = THIS.nItems + 1
    DIMENSION THIS.aItems[ THIS.nItems, 2]
    THIS.aItems[ THIS.nItems, 1] = m.lcText
    THIS.aItems[ THIS.nItems, 2] = m.lnDiff
    RETURN
  ENDFUNC
  * ------------------------------------------------------- *
  FUNCTION RenderImplementation(tcTxt)
    LOCAL ii, lcStr, lnCum, lnAmt, lnTot
    WITH THIS
      IF .lAutoAddFinishLine
        .AddItem("Performance Object Finished")
      ENDIF
      lcStr = ;
        [<table>] + CRLF + ;
        [<caption>Performance Information</caption>] + CRLF + ;
        [<thead><tr valign="bottom">] + CRLF + ;
        [<th>Process Milestone</th><th>Incremental<br />Time</th><th>Cumulative<br />Time</th><th>Graph</th>] + ;
        [</tr>] + CRLF + [</thead><tbody>] + CRLF
      lnCum = 0
      lnTot = MOD( SECONDS() - .nStart, 86400)
      lnTot = MAX( 0.01, m.lnTot)  && just in case we didn't add anything, avoid divide by 0
      FOR ii = 1 TO THIS.nItems
        lnAmt = THIS.aItems[ m.ii, 2]
        lnCum = m.lnCum + m.lnAmt
        lcStr = m.lcStr + [<tr><td>] + .aItems[ m.ii, 1] + ;
          [</td><td align="right">] + ;
            IIF( m.lnAmt >= .nBadNewsTime, [<em>], []) + ;
            TRANSFORM( m.lnAmt, "999.99") + ;
            IIF( m.lnAmt >= .nBadNewsTime, [</em>], []) + ;
          [</td><td align="right">] + TRANSFORM( m.lnCum, "999.99" ) + ;
          [</TD><TD>] + REPLICATE( "x", INT( 50 * ( m.lnAmt / m.lnTot ))) + ;
          [&nbsp;</td></tr>] + CRLF
      ENDFOR
      lcStr = m.lcStr + [</tbody></table>] + CRLF
    ENDWITH
    tcTxt = m.tcTxt + m.lcStr
    RETURN
  ENDFUNC
ENDDEFINE && CLASS L7PerformanceInfoElement

*** ===================================================== ***
DEFINE CLASS L7RecordElement AS L7PageElement
  lTextStream       = .T.
  cCaption          = ""
  cSummary          = "layout"
  cTag              = "div"
  cCssClass         = "Record"
  cHeadingCssClass  = "RecordHeading"  && default for separator rows
  lAllowLabelBreaks = .F.
  cRowConfigClass   = "L7RecordElement_RowConfig"
  * --------------------------------------------------------- *
  FUNCTION GetRowObject  && factory
    RETURN CREATEOBJECT(THIS.cRowConfigClass)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION BeforeRender(lcTxt)
    lcTxt = m.lcTxt + CRLF + [<table cellspacing="0"] + ;
      [ summary="] + THIS.cSummary + ["] + ;
      [>] + CRLF
    IF NOT EMPTY(THIS.cCaption)
      lcTxt = m.lcTxt + [<caption>] + THIS.cCaption + [</caption>] + CRLF
    ENDIF
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcTxt)
    DODEFAULT(@lcTxt)
    lcTxt = m.lcTxt + [</table>] + CRLF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddRowEx(loRowObj)
    LOCAL lcRowTag, lcLabelTag, lcValueTag, lvValue, lcLink
    WITH loRowObj
      lvValue = .vValue
      IF .lEval
        lvValue = EVALUATE(m.lvValue)
      ENDIF
      IF .lSkipIfEmpty AND EMPTY(m.lvValue)
        RETURN  && don't transform or anything
      ENDIF
      IF .lTextmerge
        lvValue = TEXTMERGE(m.lvValue)
      ENDIF
      IF NOT EMPTY(.cFormatString)
        lvValue = EVALUATE(STRTRAN(.cFormatString,[%1],[m.lvValue]))
      ENDIF
      IF VARTYPE(m.lvValue) <> "C"
        lvValue = TRANSFORM(m.lvValue)
      ENDIF
      STORE "" TO lcRowTag, lcLabelTag, lcValueTag
      lcRowTag = [<tr] + ;
        IIF(EMPTY(.cRowCssClass), [], [ class="] + .cRowCssClass + ["]) + ;
        IIF(EMPTY(.cRowCssStyle), [], [ style="] + .cRowCssStyle + ["]) + ;
        [>] + CRLF
      lcLabelTag = [<th] + ;
        IIF(EMPTY(.cLabelCssStyle), [], [ style="] + .cLabelCssStyle + ["]) + ;
        [>] + .cLabel 
      FOR EACH lcLink IN .Links
        lcLabelTag = m.lcLabelTag + .cLinkDivider +  m.lcLink + CRLF
      ENDFOR
      IF NOT EMPTY(.cInstructions)
        lcLabelTag = m.lcLabelTag + ;
          [<div class="Instructions">] + ;
          .cInstructions + CRLF + ;
          [</div>] + CRLF
      ENDIF
      lcLabelTag = m.lcLabelTag + [</th>] + CRLF
      
      lcValueTag = [<td] + ;
        IIF(EMPTY(.cValueCssStyle), [], [ style="] + .cValueCssStyle + ["]) + ;
        [>] + m.lvValue + [</td>] + CRLF
      THIS.Write( m.lcRowTag + m.lcLabelTag + m.lcValueTag + [</tr>] + CRLF)
    ENDWITH
    RETURN
  ENDFUNC  && AddRowEx()
  * --------------------------------------------------------- *
  FUNCTION AddHeadingEx(loRowObj)
    LOCAL lcRowTag, lcLabelTag, lcLink, lcRowCssClass
    WITH loRowObj
      STORE "" TO lcRowTag, lcLabelTag
      lcRowCssClass = EVL(.cRowCssClass, THIS.cHeadingCssClass) && if no class passed, use default      
      lcRowTag = [<tr] + ;
        IIF(EMPTY(m.lcRowCssClass), [], [ class="] + m.lcRowCssClass + ["]) + ;
        IIF(EMPTY(.cRowCssStyle), [], [ style="] + .cRowCssStyle + ["]) + ;
        [>] + CRLF
      lcLabelTag = [<th colspan="2"] + ;
        IIF(EMPTY(.cLabelCssStyle), [], [ style="] + .cLabelCssStyle + ["]) + ;
        [>] + .cLabel 
      FOR EACH lcLink IN .Links
        lcLabelTag = m.lcLabelTag + .cLinkDivider +  m.lcLink + CRLF
      ENDFOR
      IF NOT EMPTY(.cInstructions)
        lcLabelTag = m.lcLabelTag + ;
          [<div class="Instructions">] + ;
          .cInstructions + CRLF + ;
          [</div>] + CRLF
      ENDIF
      lcLabelTag = m.lcLabelTag + [</th>] + CRLF
      THIS.Write( m.lcRowTag + m.lcLabelTag + [</tr>] + CRLF)
    ENDWITH
    RETURN
  ENDFUNC  && AddHeadingEx()
  * --------------------------------------------------------- *
  FUNCTION AddRow(lcLabel, lvValue, llSkipIfEmpty, ;
    lcRowCssClass, lcRowCssStyle, lcLabelCssStyle, lcValueCssStyle)
    * Typical calls:  .AddRow( "<Field>", <Field>)
    *                 .AddRow( "<Field>", <Field>, .T.)  && omit row if value is empty/null
    * Remaining 4 parameters are for exception-based formatting.
    
    IF VARTYPE(m.lcLabel) = "O"
      RETURN THIS.AddRowEx(m.lcLabel)
    ENDIF
    
    IF m.llSkipIfEmpty AND (ISNULL( m.lvValue) OR EMPTY( m.lvValue))
      RETURN
    ENDIF
    IF VARTYPE(m.lvValue) = "L" && avoid unsightly .T. or .F.
      lvValue = IIF(m.lvValue, "Yes", "No") && app should provide transform if it doesn't like this
    ENDIF
    LOCAL lcRowTag, lcLabelTag, lcValueTag, llNullLabel
    STORE "" TO lcRowTag, lcLabelTag, lcValueTag
    llNullLabel = ISNULL(m.lcLabel)
    lcRowTag = [<tr] + ;
      IIF(EMPTY(m.lcRowCssClass), [], [ class="] + m.lcRowCssClass + ["]) + ;
      IIF(EMPTY(m.lcRowCssStyle), [], [ style="] + m.lcRowCssStyle + ["]) + ;
      [>] + CRLF
    IF m.llNullLabel
      lcLabelTag = ""
    ELSE
      IF NOT THIS.lAllowLabelBreaks
        lcLabel = [<nobr>] + m.lcLabel + [</nobr>]
        * [[ revise this to use CSS whitespace control, if support improves
      ENDIF
      lcLabelTag = [<th] + ;
        IIF(EMPTY(m.lcLabelCssStyle), [], [ style="] + m.lcLabelCssStyle + ["]) + ;
        [>] + m.lcLabel + [</th>] + CRLF
    ENDIF
    lcValueTag = [<td] + ;
      IIF(m.llNullLabel, [ colspan="2"], []) + ;
      IIF(EMPTY(m.lcValueCssStyle), [], [ style="] + m.lcValueCssStyle + ["]) + ;
      [>] + TRANSFORM(m.lvValue) + [</td>] + CRLF
    THIS.Write( m.lcRowTag + m.lcLabelTag + m.lcValueTag + [</tr>] + CRLF)
    RETURN
  ENDFUNC  && AddRow
  * --------------------------------------------------------- *
  FUNCTION AddHeading(lcLabel, ;
    lcRowCssClass, lcRowCssStyle, lcLabelCssStyle, lcValueCssStyle)

    IF VARTYPE(m.lcLabel) = "O"
      RETURN THIS.AddHeadingEx(m.lcLabel)
    ENDIF

    LOCAL lcRowTag, lcLabelTag
    STORE "" TO lcRowTag, lcLabelTag
    lcRowCssClass = EVL(m.lcRowCssClass, THIS.cHeadingCssClass) && if no class passed, use default
    lcRowTag = [<tr] + ;
      IIF(EMPTY(m.lcRowCssClass), [], [ class="] + m.lcRowCssClass + ["]) + ;
      IIF(EMPTY(m.lcRowCssStyle), [], [ style="] + m.lcRowCssStyle + ["]) + ;
      [>] + CRLF
    lcLabelTag = [<th colspan="2"] + ;
      IIF(EMPTY(m.lcLabelCssStyle), [], [ style="] + m.lcLabelCssStyle + ["]) + ;
      [>] + m.lcLabel + [</th>] + CRLF
    THIS.Write( m.lcRowTag + m.lcLabelTag + [</tr>] + CRLF)
    RETURN
  ENDFUNC  && AddHeading
  * --------------------------------------------------------- *
  FUNCTION AddXmlNodeRows( lcXML, lcXPath)
    LOCAL loXML, lnRows, lcReason, loNode, loParentNode, lcValue, lcName, lcLabel
    lnRows = 0
    TRY
      loXML = CREATEOBJECT(XML_XMLDOM_PROGID)
      WITH loXML
        .Async = .T.
        .LoadXML(m.lcXML)
        lcReason = .ParseError.Reason
        IF NOT EMPTY(m.lcReason)
          ERROR m.lcReason
        ENDIF
        loParentNode = .SelectSingleNode(m.lcXPath)
        IF VARTYPE(loParentNode) = "O"
          loNode = loParentNode.FirstChild
          DO WHILE VARTYPE(loNode) = "O"
            lcValue = loNode.Text
            IF m.lcValue == ".NULL."
              * no row added
            ELSE  
              DO CASE
              CASE m.lcValue == ".T."
                lcValue = "Yes"
              CASE m.lcValue == ".F."
                lcValue = "No"
              ENDCASE
              THIS.AddRow(loNode.NodeName, m.lcValue)
              lnRows = m.lnRows + 1
            ENDIF
            loNode = loNode.NextSibling
          ENDDO
        ENDIF
      ENDWITH
    CATCH TO loExc
      lnRows = -1
      THIS.AddRow("Error!", loExc.Message + ", while processing Xpath: " + m.lcXPath )
    FINALLY
      ** loXML = NULL
    ENDTRY
    RETURN m.lnRows
  ENDFUNC
  * --------------------------------------------------------- *
  * Used for easy conversion from deprecated Page.ContentRow():
  FUNCTION ContentRow( lcLabel, lvValue, llSkipIfEmpty, lcCssClass)
    * If *value* is not passed, assume a Section Heading row.
    LOCAL lcTxt, lcClass, lcValue, lcType, llHeading
    llHeading = PCOUNT() = 1
    IF m.llHeading
      THIS.AddHeading(m.lcLabel)
    ELSE
      THIS.AddRow(m.lcLabel, m.lvValue, m.llSkipIfEmpty, m.lcCssClass)
    ENDIF
  ENDFUNC  && ContentRow
ENDDEFINE

*** ===================================================== ***
DEFINE CLASS L7RecordElement_RowConfig AS Container
  ADD OBJECT Links AS Collection
  cLabel = ""
  cInstructions = ""
  vValue = ""
  lSkipIfEmpty = .F.
  lEval = .F.
  lTextmerge = .F.
  cFormatString = ""
  cRowCssClass = ""
  cRowCssStyle = ""
  cLabelCssStyle = ""
  cValueCssStyle = ""
  cLinkDivider = ''  && '<br />'
  * --------------------------------------------------------- *
  FUNCTION Clear
    WITH THIS
      DO WHILE .Links.Count > 0
        .Links.Remove(1)
      ENDDO
      .cLabel = ""
      .cInstructions = ""
      .vValue = ""
      .lSkipIfEmpty = .F.
      .lEval = .F.
      .lTextmerge = .F.
      .cFormatString = ""
      .cRowCssClass = ""
      .cRowCssStyle = ""
      .cLabelCssStyle = ""
      .cValueCssStyle = ""
      .cLinkDivider = ''  && '<br />'
    ENDWITH
  ENDFUNC
ENDDEFINE

*** ===================================================== ***
define class L7HtmlPageElement as L7PageElement && L7LinearArtifactsElement 

* [[ New class 2/15/2010 - only use for now is IA. Fair game to alter.

  cTag = "html"  
  cID = ""
  cPreText = L7_DOCTYPE_LOOSE + CRLF
  Head = null
  cHeadClass = "L7HeadElement"
  Body = null
  * --------------------------------------------------------- *
  function AfterInit()
    with this
      .Head = this.createHead(this.cHeadClass)
      .Body = createobject("L7PageElement", "", 'body')
    endwith
    return 
  endfunc 
  * --------------------------------------------------------- *
  function createHead(tcHeadClass)
    this.head = null
    this.head = createobject(m.tcHeadClass, '', 'head')
    return
  endfunc
  * --------------------------------------------------------- *
  function RenderImplementation(tcTxt)
    local lcStr, loObj
    * tcTxt = m.tcTxt + [<html] + [>] + CRLF
    if !isnull(this.Head)
      lcStr = this.Head.render()
      tcTxt = m.tcTxt + m.lcStr
    endif
    if !isnull(this.Body)
      lcStr = this.Body.render()
      tcTxt = m.tcTxt + m.lcStr
    endif
    ** tcTxt = m.tcTxt + [</html>] + CRLF
    return 
  endfunc 

enddefine


#if .f.
10/25/2003 - added summary="layout" for tables, removed some hard-coded HTML "styles" from markup
11/20/2003 - added AddXmlNodeRows() to L7RecordElement
12/03/2003 - revised text menu to support submenu headings with links
#endif
