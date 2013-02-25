* L7FormRender.PRG
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



** [[ TO DO: BeforeRender() and AfterRender() of controls!!!?????

* Example to show super-simple renderer subclass:
DEFINE CLASS L72ColRender AS LINE
  cPattern = '<tr><th>%l</th>(%w%c)</tr>'
  FUNCTION Render(loForm)
    LOCAL lcTxt, lcTemp
    lcTxt = loForm.FormOpen() + '<table border=1>'
    * First the title:
    lcTxt = m.lcTxt + [<tr><th colspan="2"] + ;
      IIF( EMPTY( loForm.cTitleCssClass), [], [ class="] + loForm.cTitleCssClass + ["]) + ;
      IIF( EMPTY( loForm.cTitleBgColor), [], [ bgcolor="] + loForm.cTitleBgColor + ["]) + ;
      [>] + CR + loForm.cTitle + [</th></tr>] + CRLF
      
    FOR EACH loControl IN loForm.Controls
      DO CASE
      CASE loControl.lVisible = .F. OR loControl.lAutoRender = .F.
      CASE loControl.lSpanColumns
        lcTxt = m.lcTxt + [<tr><td colspan=2>] 
        lcTxt = m.lcTxt + m.loControl.Render()
        lcTxt = m.lcTxt + [</td></tr>]
      OTHERWISE
        loControl.cWrapperTag = 'td'
        loControl.cDefaultPattern = THIS.cPattern
        lcTemp = loControl.Render()
        lcTxt = m.lcTxt + m.lcTemp
      ENDCASE
    NEXT loControl
    
    lcTxt = m.lcTxt + [<tr><td colspan="2"] + [>] + CR + ;
      loForm.Toolbar.Render() + [</td></tr>] + CRLF    
    RETURN lcTxt + [</table>] + loForm.FormClose()
  ENDFUNC
ENDDEFINE

* ==================================================================== *
DEFINE CLASS L7FormRender AS Container
  oForm = NULL
  cCurrentGroupID = ""  && support renderer-optional grouping of elements
  cDefaultControlPattern = [%l(%s%i)%b%c(%b%v)%w]
  * ------------------------------------------------------------------- *
  FUNCTION Render( loForm)

    ERROR "Abstract method not implemented: " + PROGRAM()

    * NOTE: We may convert this to an abstract template method later,
    *  but at least for now, the rendering implementation is seprated
    *  from the interface (bridge pattern).

  ENDFUNC && Render
  * ------------------------------------------------------------------- *
  FUNCTION RenderTitle( loForm)
    LOCAL lcTxt 
    * First the title:
    lcTxt = [<div] + ;
      IIF( EMPTY( loForm.cTitleCssClass), [], [ class="] + loForm.cTitleCssClass + ["]) + ;
      IIF( EMPTY( loForm.cTitleBgColor), [], [ bgcolor="] + loForm.cTitleBgColor + ["]) + ;
      [>] + CR
    IF NOT EMPTY( loForm.cTitleFontColor)
      lcTxt = m.lcTxt + [<font color="] + loForm.cTitleFontColor + [">] + CR
    ENDIF
    * The Title itself:
    lcTxt = m.lcTxt + loForm.cTitle
    IF NOT EMPTY( loForm.cTitleFontColor)
      lcTxt = m.lcTxt + [</font>] + CR
    ENDIF
    lcTxt = m.lcTxt + [</div>] + CR
    RETURN m.lcTxt
  ENDFUNC  && RenderTitle
  * ------------------------------------------------------------------- *
  FUNCTION RenderInstructions(loForm)
    LOCAL lcTxt, lcCls
    lcTxt = loForm.cInstructions
    IF NOT EMPTY( m.lcTxt)
      lcTxt = [<div] + ;
        IIF( EMPTY( loForm.cInstructionsCssClass), [], [ class="] + loForm.cInstructionsCssClass + ["]) + ;
        [>] + CR + ;
        loForm.cInstructions + ;
        [</div>] + CR
    ENDIF
    RETURN m.lcTxt
  ENDFUNC  && RenderInstructions
  * ------------------------------------------------------------------- *
  FUNCTION RenderValidation( loForm)
    LOCAL lcTxt
    lcTxt = [<div] + ;
      IIF( EMPTY( loForm.cValidationCssClass), [], [ class="] + loForm.cValidationCssClass + ["]) + ;
      [>] + CR + ;
      "<strong>" + loForm.cValidationHeading + "</strong>"+L7BR + CR + ;
      loForm.cValidationMessage + ;
      [</div>] + CR
    RETURN m.lcTxt
  ENDFUNC && RenderValidation
  * ------------------------------------------------------------------- *
  FUNCTION RenderToolbar( loForm)  && DEPRECATED
    LOCAL lcTxt 
    WITH loForm.Toolbar
      IF NOT .lVisible
        lcTxt = ""
      ELSE
        lcTxt = .Render()
      ENDIF
    ENDWITH
    RETURN m.lcTxt
  ENDFUNC  && RenderToolbar
  * ------------------------------------------------------------------- *
  FUNCTION RenderFootnotes( loForm)
    LOCAL lcTxt
    lcTxt = [<div] + ;
      IIF( EMPTY( loForm.cFootnoteCssClass), [], [ class="] + loForm.cFootnoteCssClass + ["]) + ;
      [>] + CR + ;
      loForm.cFootnoteText + ;
      [</div>] + CR
    RETURN m.lcTxt
  ENDFUNC && RenderFootnotes
  * ------------------------------------------------------------------- *
  FUNCTION BeginGroup(loControl, loForm)
    RETURN [<table id="] + loControl.cGroupId + [" class="FormContainer" border="0"] + ;
      IIF( ISNULL( loForm.nCellSpacing), [], [ cellspacing="] + TRANSFORM(loForm.nCellSpacing) + ["]) + ;
      [>] + CR + ;
      [<tr valign="top">] + CR + ;
      THIS.BeginGroupControl(loControl)
  ENDFUNC && BeginGroup
  * ------------------------------------------------------------------- *
  FUNCTION BeginGroupControl(loControl)
*!*      loControl.cWrapperTag = "span"  
*!*      LOCAL lcClass
*!*      lcClass = loControl.cDynamicCssClass
*!*      RETURN [<td] + IIF(EMPTY(m.lcClass),[],[ class="] + m.lcClass + ["]) + ;
*!*        [>] + CR
    loControl.cWrapperTag = "td"
    RETURN ""
  ENDFUNC && BeginGroup
  * ------------------------------------------------------------------- *
  FUNCTION EndGroup()
    RETURN THIS.EndGroupControl() + [</tr></table>] + CR
  ENDFUNC && EndGroup
  * ------------------------------------------------------------------- *
  FUNCTION EndGroupControl()
*!*      RETURN [</td>] + CR
    RETURN ""
  ENDFUNC && EndGroup
  * ------------------------------------------------------------------- *
  FUNCTION IntraGroup(loControl)
    RETURN THIS.EndGroupControl() + THIS.BeginGroupControl(m.loControl)
  ENDFUNC && IntraGroup
  * ------------------------------------------------------------------- *
ENDDEFINE  && Class L7FormRender

* ==================================================================== *
DEFINE CLASS L7FormRenderOverUnder AS L7FormRender

  cDefaultControlPattern = [%l(%s%i)%b%c(%b%v)%w]
  * Pattern explanation:
  *
  *   %l     = label
  *   (%s%i) = conditional non-breaking space before instructions (i.e., only if non-empty)
  *   %b     = conditional <br> if there's anything to the left (label and/or instructions)
  *   %c     = control itself (incldues any JS)
  *   (%b%v) = validation message, w/ leading conditional <br>
  *   %w     = directive to wrap the whole thing in specified tag (cWrapperTag) w/ CSS class
  * ------------------------------------------------------------------- *
  FUNCTION Render( loForm)
    LOCAL lcTxt, loControl, lcStr, llNoShow, lcItemTxt, lcControlTxt, ;
      lcClass, lcStyle
    lcTxt = ""
    * <form> tag:
    lcTxt = m.lcTxt + loForm.FormOpen()
    * <table> wrapper:
    lcTxt = m.lcTxt + loForm.OpenWrapperTag()
    * Form Title:
    IF NOT EMPTY( loForm.cTitle)
      lcTxt = m.lcTxt + THIS.RenderTitle( m.loForm)
    ENDIF
    * If any invalid information was entered, show the form-level message:
    IF loForm.nInvalidCount > 0 OR loForm.lInvalidControls
      lcTxt = m.lcTxt + THIS.RenderValidation( m.loForm)
    ENDIF
    * Form Instructions:
    IF NOT EMPTY( loForm.cInstructions)
      lcTxt = m.lcTxt + THIS.RenderInstructions( m.loForm)
    ENDIF
    * Toolbar at Top:  && DEPRECATED
    IF loForm.lToolbarAtTop
      lcTxt = m.lcTxt + THIS.RenderToolbar( m.loForm)
    ENDIF
    
    * EACH Control:
    FOR EACH loControl IN loForm.Controls
      IF loControl.lVisible = .F. OR loControl.lAutoRender = .F.
        LOOP
      ENDIF
      IF NOT loControl.cGroupID == THIS.cCurrentGroupID  && group change
        * Close out any old group (this is repeated at end):
        IF NOT EMPTY(THIS.cCurrentGroupId)
          lcTxt = m.lcTxt + THIS.EndGroup()
        ENDIF
        * Swap:
        THIS.cCurrentGroupID = loControl.cGroupID 
        * Open any new group:
        IF NOT EMPTY(THIS.cCurrentGroupId)
          lcTxt = m.lcTxt + THIS.BeginGroup(loControl, loForm)
        ENDIF
      ELSE  && no group change
        IF NOT EMPTY( THIS.cCurrentGroupID)
          lcTxt = m.lcTxt + THIS.IntraGroup(loControl)
        ENDIF
      ENDIF
      
      DO CASE
      CASE loControl.lSpanColumns
      CASE loControl.lHidden AND NOT loControl.lShowOnForm
      OTHERWISE
      ENDCASE
      
      lcItemTxt = ""
      ** * Get the basic control output, so we can check for errors, etc:
      ** lcControlTxt = loControl.RenderControl()
      
      llNoShow = loControl.lHidden AND NOT loControl.lShowOnForm
      IF m.llNoShow
        * Just render control (probably <input type="hidden">)
        *!* lcItemTxt = m.lcItemTxt + m.lcControlTxt
        lcItemTxt = m.lcItemTxt + loControl.Render([%c])
      ELSE
        loControl.cDefaultPattern = THIS.cDefaultControlPattern
        
        lcItemTxt = m.lcItemTxt + loControl.Render()
        
*!*          * Outer DIV/SPAN tag with optional tooltip:
*!*          lcClass = loControl.cDynamicCssClass
*!*          lcStyle = loControl.cCssStyle
*!*          lcItemTxt = m.lcItemTxt + [<] + loControl.cWrapperTag + ;
*!*            IIF( EMPTY( m.lcClass), [], [ class="] + m.lcClass + ["]) + ;
*!*            IIF( EMPTY( m.lcStyle), [], [ style="] + m.lcStyle + ["]) + ;
*!*            IIF( EMPTY( loControl.cToolTipText), [], CR + ;
*!*              [ title="] + loControl.cToolTipText + ["]) + ;
*!*            [>] + CR
*!*          lcItemTxt = m.lcItemTxt + loControl.RenderLabel() + [&nbsp;] + ;
*!*            IIF( loControl.lDisabled, [], loControl.RenderInstructions()) + [<] + [br>] + CR
*!*          lcItemTxt = m.lcItemTxt + m.lcControlTxt
*!*          lcStr = m.loControl.RenderValidation()
*!*          IF NOT EMPTY( m.lcStr)
*!*            lcItemTxt = m.lcItemTxt + [<] + [br>] + CR + m.lcStr
*!*          ENDIF
*!*          lcItemTxt = m.lcItemTxt + [</] + loControl.cWrapperTag + [>] + CR
      ENDIF

      * Attach item to master form output:
      lcTxt = m.lcTxt + m.lcItemTxt
    ENDFOR  && EACH Control

    * Close out any old group (this is repeated within loop):
    IF NOT EMPTY(THIS.cCurrentGroupId)
      lcTxt = m.lcTxt + THIS.EndGroup()
    ENDIF
    
    * Toolbar at Bottom:  && DEPRECATED
    IF loForm.lToolbarAtBottom
      lcTxt = m.lcTxt + THIS.RenderToolbar( m.loForm)
    ENDIF
    * Insert form-level footnotes:   && DEPRECATED
    IF NOT EMPTY( loForm.cFootnoteText )
      lcTxt = m.lcTxt + THIS.RenderFootnotes( m.loForm)
    ENDIF

    * Various close tags:
    *!* lcTxt = m.lcTxt + [</td></tr>] + CR
    *!* lcTxt = m.lcTxt + [</table>] + CR
    lcTxt = m.lcTxt + loForm.CloseWrapperTag()
    lcTxt = m.lcTxt + loForm.FormClose()
    RETURN lcTxt
  ENDFUNC && Render
  * ------------------------------------------------------------------- *
  FUNCTION BeginGroup(loControl, loForm)
    LOCAL lcText, lcCls, lcTemp
    lcText = DODEFAULT(m.loControl, m.loForm)
    lcTemp = loControl.cGroupLabel
    IF NOT EMPTY(m.lcTemp)
      lcCls = loControl.cLabelCssClass
      IF NOT EMPTY( m.lcCls)
        lcTemp = [<span class="] + m.lcCls + [">] + ;
          m.lcTemp + [:] + [</span>]
      ENDIF
      lcText = m.lcTemp + L7BR + m.lcText 
    ENDIF
    RETURN m.lcText
  ENDFUNC
  * ------------------------------------------------------------------- *
ENDDEFINE  && Class L7FormRenderOverUnder

* ==================================================================== *
DEFINE CLASS L7FormRenderOneLineOverUnder AS L7FormRender
  * ------------------------------------------------------------------- *
  FUNCTION Render( loForm)
    LOCAL lcTxt, loControl, lcStr, llNoShow, lcItemTxt, lcControlTxt, ;
      lnCols, lcPreText, lcPostText
    STORE "" TO lcTxt, lcPreText, lcPostText, lcLastGroup
    lnCols = 0

    * EACH Control:
    * (Do the controls first, so we know how many cells there are for COLSPAN.)
    FOR EACH loControl IN loForm.Controls
      IF loControl.lVisible = .F. OR loControl.lAutoRender = .F.
        LOOP
      ENDIF
      
      loControl.cWrapperTag = "span"
      
      lcItemTxt = ""
      * Get the basic control output, so we can check for errors, etc:
      lcControlTxt = loControl.RenderControl()

*!*        lcControlTxt = IIF( loControl.lContainer, ;
*!*          loControl.Render(), loControl.RenderControl() )

      IF loControl.lContainer
        lcItemTxt = m.lcItemTxt + m.lcControlTxt
      ELSE
        llNoShow = loControl.lHidden AND NOT loControl.lShowOnForm
        IF m.llNoShow
          * Just render control (probably <input type="hidden">)
          lcItemTxt = m.lcItemTxt + m.lcControlTxt
        ELSE
          lnCols = m.lnCols + 1
          * Outer DIV tag with optional tooltip:
          lcItemTxt = m.lcItemTxt + [<td class="] + ;
            loControl.cDynamicCssClass + ["] + ;
            IIF( EMPTY( loControl.cToolTipText), [], CR + [ title="] + loControl.cToolTipText + ["]) + ;
            [>] + CR
          lcItemTxt = m.lcItemTxt + loControl.RenderLabel() + [&nbsp;] + ;
            loControl.RenderInstructions() + L7BR + CR
          lcItemTxt = m.lcItemTxt + m.lcControlTxt
          lcStr = m.loControl.RenderValidation()
          IF NOT EMPTY( m.lcStr)
            lcItemTxt = m.lcItemTxt + L7BR + CR + m.lcStr
          ENDIF
          lcItemTxt = m.lcItemTxt + [</td>] + CR
        ENDIF
      ENDIF
      * Attach item to master form output:
      lcTxt = m.lcTxt + m.lcItemTxt
    ENDFOR  && EACH Control

    * Toolbar at right:   && DEPRECATED?
    FOR ii = 1 TO loForm.Toolbar.nItems
      loObj = loForm.Toolbar.aItems[ m.ii, 2] 
      IF NOT loObj.lVisible
        LOOP
      ENDIF
      lnCols = m.lnCols + 1
      lcTxt = m.lcTxt + [<td>] + loObj.RenderControl() + [</td>] + CR
    ENDFOR
    
    * <form> tag:
    lcPreText = m.lcPreText + loForm.FormOpen()
    * <table> wrapper:
    lcPreText = m.lcPreText + [<table] + ;
      IIF( EMPTY( loForm.cCssClass), [], [ class="] + loForm.cCssClass + ["]) + ;
      IIF( EMPTY( loForm.cAlign), [], [ align="] + loForm.cAlign + ["]) + ;
      IIF( ISNULL( loForm.nBorder), [], [ border="] + TRANSFORM(loForm.nBorder) + ["]) + ;
      [>] + CR 
    * Form Title:
    IF NOT EMPTY( loForm.cTitle)
      lcPreText = m.lcPreText + [<tr><th colspan="] + TRANSFORM( m.lnCols) + [">] + ;
        THIS.RenderTitle( m.loForm) + [</th></tr>] + CR
    ENDIF
    * If any invalid information was entered, show the form-level message:
    IF loForm.nInvalidCount > 0 OR loForm.lInvalidControls
      lcPreText = m.lcPreText + [<tr><td colspan="] + TRANSFORM( m.lnCols) + [">] + ;
        THIS.RenderValidation( m.loForm) + [</td></tr>] + CR
    ENDIF

    lcPostText = [</tr>] + CR
    * Insert form-level footnotes:
    IF NOT EMPTY( loForm.cFootnoteText )
      lcPostText = m.lcPostText + [<tr><td colspan="] + TRANSFORM( m.lnCols) + [">] + ;
        THIS.RenderFootnotes( m.loForm) + [</td></tr>] + CR
    ENDIF
    * Various close tags:
    lcPostText = m.lcPostText + [</table>] + CR
    lcPostText = m.lcPostText + loForm.FormClose()
    RETURN m.lcPreText + m.lcTxt + m.lcPostText
  ENDFUNC && Render
  * ------------------------------------------------------------------- *
ENDDEFINE  && Class L7FormRenderOneLineOverUnder
* ==================================================================== *

* ==================================================================== *
DEFINE CLASS L7FormRenderTwoColumn AS L7FormRender
  nCols = 2
  * ------------------------------------------------------------------- *
  FUNCTION Render( loForm)
    LOCAL lcTxt, loControl, lcStr, llNoShow, lcItemTxt, lcControlTxt, ;
      lcColspan, lcToolTxt, llContainer
    lcColspan = [ colspan="] + TRANSFORM( THIS.nCols) + ["]
    lcTxt = ""
    * <form> tag:
    lcTxt = m.lcTxt + loForm.FormOpen()
    * <table> wrapper:
    lcTxt = m.lcTxt + [<table] + ;
      IIF( EMPTY( loForm.cCssClass), [], [ class="] + loForm.cCssClass + ["]) + ;
      IIF( EMPTY( loForm.cAlign), [], [ align="] + loForm.cAlign + ["]) + ;
      IIF( ISNULL( loForm.nBorder), [], [ border="] + TRANSFORM(loForm.nBorder) + ["]) + ;
      [>] + CR 
    * Form Title:
    IF NOT EMPTY( loForm.cTitle)
      lcTxt = m.lcTxt + [<tr><td] + m.lcColspan + [>] + CR + ;
        THIS.RenderTitle( m.loForm) + [</td></tr>]
    ENDIF
    * If any invalid information was entered, show the form-level message:
    IF loForm.nInvalidCount > 0 OR loForm.lInvalidControls
      lcTxt = m.lcTxt + [<tr><td] + m.lcColspan + [>] + CR + ;
        THIS.RenderValidation( m.loForm) + [</td></tr>]
    ENDIF
    * Toolbar at Top:   && DEPRECATED
    IF loForm.lToolbarAtTop OR loForm.lToolbarAtBottom
      * Pre-fetch toolbar text:
      lcToolTxt = [<tr><td] + m.lcColspan + [>] + CR + ;
        THIS.RenderToolbar( m.loForm) + [</td></tr>]
    ENDIF
    IF loForm.lToolbarAtTop   && DEPRECATED
      lcTxt = m.lcTxt + m.lcToolTxt
    ENDIF
    
    * EACH Control:
    FOR EACH loControl IN loForm.Controls
      WITH loControl
        IF .lVisible = .F. OR .lAutoRender = .F.
          LOOP
        ENDIF
        llContainer = .lContainer
        lcItemTxt = ""
        * Get the basic control output, so we can check for errors, etc:
        lcControlTxt = IIF( m.llContainer, .RenderNestedControls(), .RenderControl() )
        llNoShow = m.llContainer = .F. AND .lHidden AND NOT .lShowOnForm
        IF m.llNoShow
          * Just render control (probably <input type="hidden">)
          lcItemTxt = m.lcItemTxt + m.lcControlTxt
        ELSE
          * Outer DIV tag with optional tooltip:
          lcItemTxt = m.lcItemTxt + [<tr class="] + ;
            .cDynamicCssClass + ["] + ;
            IIF( m.llContainer OR EMPTY( .cToolTipText), [], CR + [ title="] + .cToolTipText + ["]) + ;
            [>] + CR
          
          IF .lNoLabel = .F.
            lcItemTxt = m.lcItemTxt + [<td align="right">] + CR
            * Label:
            lcItemTxt = m.lcItemTxt + .RenderLabel() + [</td><td>]
          ELSE
            lcItemTxt = m.lcItemTxt + [<td] + m.lcColspan + [>]
          ENDIF
          * Instructions:
          IF NOT .lDisabled
            lcStr = .RenderInstructions() 
            IF NOT EMPTY( m.lcStr)
              lcItemTxt = m.lcItemTxt + m.lcStr + L7BR + CR
            ENDIF
          ENDIF
          * Add the control itself:
          lcItemTxt = m.lcItemTxt + m.lcControlTxt
          * Validation Text:
          IF NOT m.llContainer
            lcStr = .RenderValidation()
            IF NOT EMPTY( m.lcStr)
              lcItemTxt = m.lcItemTxt + L7BR  + CR + m.lcStr
            ENDIF
          ENDIF
          lcItemTxt = m.lcItemTxt + [</td></tr>] + CR
        ENDIF
      ENDWITH 
      * Attach item to master form output:
      lcTxt = m.lcTxt + m.lcItemTxt
      
    ENDFOR  && EACH Control
    
    * Toolbar at Bottom:  && DEPRECATED
    IF loForm.lToolbarAtBottom
      lcTxt = m.lcTxt + m.lcToolTxt
    ENDIF
    * Insert form-level footnotes:
    IF NOT EMPTY( loForm.cFootnoteText )
      lcTxt = m.lcTxt + [<tr><td] + m.lcColspan + [>] + CR + ;
        THIS.RenderFootnotes( m.loForm) + [</td></tr>]
    ENDIF
    * Various close tags:
    lcTxt = m.lcTxt + [</table>] + CR
    lcTxt = m.lcTxt + loForm.FormClose()
    RETURN lcTxt
  ENDFUNC && Render
  * ------------------------------------------------------------------- *
ENDDEFINE  && Class L7FormRenderTwoColumn
* ==================================================================== *

#if .f.
07/03/2003 - added support for cGroupLabel in over-under renderer
08/04/2003 - revised RenderValidation to use form.cValidationHeading
08/30/2003 - revised RenderToolbar to return "" for invisible toolbars
#endif

* End-of-file: L7FormRender.PRG
