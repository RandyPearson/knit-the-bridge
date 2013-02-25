* L7Controls.PRG
*
* Cycla Html-based Controls (see also: L7Form and L7FormRender)
*
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


* ==================================================================== *
DEFINE CLASS L7Divider AS L7_CONTROL_CLASS
  * Divider line in form - for RAD forms.
  * (Former class name: L7Line)
  lSingleColumn   = .T.
  lAutoReadInput  = .F.
  lHasContent     = .F.  && affected whether form's lUpdated flag should be triggered

  lValueSet = .T.
  cCssClass = "FormDivider"
  cPattern = [(%c)(%s%i)(%b%v)%w]
  * ------------------------------------------------------------------- *
  FUNCTION cLabel_ACCESS
    * Override default behavior.
    RETURN THIS.cLabel
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    THIS.lOutputCreated = .T.
    LOCAL lcRet
    IF ISNULL(THIS.cLabel) OR EMPTY(THIS.cLabel) && simple divider: <hr>
      lcRet = [<hr class="] + THIS.cCssClass + [">]
    ELSE
      *!* lcRet = [<span class="] + THIS.cCssClass + [">] + THIS.cLabel + [</span>] 
      * Removed <span> wrapper since we may want block-level content.
      lcRet = THIS.cLabel
    ENDIF
    * NOTE: Form renderer is responsible for "packaging" this in the right
    * tag, such as a <div> or a <tr><td colspan=2>.
    RETURN m.lcRet
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION RenderLabel
    RETURN ""
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * L7Divider::ReadInput()
    THIS.lInputRead = .T.
    THIS.lUpdated = .F.
    RETURN
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    RETURN .F.
  ENDFUNC  && WasChanged
  * ------------------------------------------------------------------- *
  FUNCTION Valid
    RETURN .T.
  ENDFUNC
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7Divider

* ==================================================================== *
DEFINE CLASS L7Label AS L7_CONTROL_CLASS
  * Read-only label control--for displaying dynamic data without any
  * request-side processing. Different from HIDDEN form vars!!

  cControlCssClass = "FormLabel"
  cDisplayValue = NULL  && character representation--handled by ACCESS method
  lDisabled = .T.       && so control source doesn't update

  *!*  * ------------------------------------------------------------------- *
  *!*  FUNCTION cDisplayValue_ACCESS
  *!*  IF ISNULL( THIS.cDisplayValue )
  *!*    IF VARTYPE( THIS.vNewValue) = "C"
  *!*      THIS.cDisplayValue = TRIM( THIS.vNewValue )
  *!*    ELSE
  *!*      THIS.cDisplayValue = TRANSFORM( THIS.vNewValue )
  *!*    ENDIF
  *!*  ENDIF
  *!*  RETURN THIS.cDisplayValue
  *!*  ENDFUNC  && cDisplayValue_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    LOCAL lcRet
    THIS.lOutputCreated = .T.
    THIS.SetValueIfNeeded()  && Added 12/12/2001
    * 01/06/2003 - Added ID= attribute so matching LABEL FOR passes W3C validation.
    lcRet = [<span] + ;
      [ id="] + THIS.GetID() + ["] + ;
      IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
      IIF( EMPTY( THIS.cControlCssStyle), [], [ style="] + THIS.cControlCssStyle + ["]) + ;
      [>] + ;
      THIS.cDisplayValue + [</span>] + CR
    RETURN m.lcRet
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * L7Label::ReadInput()
    THIS.SetValueIfNeeded()  && Added 04/29/2002
    THIS.lInputRead = .T.
    THIS.lUpdated = .F.
    RETURN
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    RETURN .F.
  ENDFUNC  && WasChanged
  * ------------------------------------------------------------------- *
  FUNCTION Valid
    RETURN .T.
  ENDFUNC
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7Label

* ==================================================================== *
DEFINE CLASS L7Button AS L7_CONTROL_CLASS
  * Property Definitions:
  cHtmlTag          = "input"   && "button", "input" or "a"
  cContent          = NULL       && for <button></button> construct
  
  cCssClass         = "FormButton"
  cControlCssClass  = "Button"
  cOnClick          = ""
  ** cOnSubmit         = ""
  cOnMouseOver      = "this.className='ButtonOver'"
  cOnMouseOut       = "this.className='Button'"

  lAutoReadInput    = .T.  && indicates postback should be read
  lAutoRender       = .F.  && typically buttons are rendered from a toolbar proxy
  lHasContent       = .F.  && affected whether form's lUpdated flag should be triggered
  
  lRenderWhenDisabled = .F.  && flag to render anyhow if disabled (handy when whole
                             && form is disabled, and a button is used to enable it)
  cWrapperTag       = "span"  
  cType             = "button"
  cHtmlName         = ""
  vOldValue         = "submit"
  vNewValue         = ""
  vDataValue        = NULL  && used to store a different value to be saved to Control Source
                            && so that literal text of button (vOldValue) can vary
  * ------------------------------------------------------------------- *
  FUNCTION cContent_ACCESS
    IF ISNULL(THIS.cContent)
      RETURN THIS.vOldValue  && default content to value
    ELSE
      RETURN THIS.cContent
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION BeforeUpdateControlSources()  && blocking hook
    ** SET STEP ON 
    IF NOT THIS.WasClicked()
      RETURN .F.  && prevent button from affecting anything
    ENDIF
    IF NOT EMPTY(THIS.cControlSource) AND NOT ISNULL(THIS.vDataValue)
      * Button has special vDataValue override.
      IF THIS.cControlSourceType = "Object" && source is a data object
        STORE THIS.vDataValue TO ( THIS.cControlSource )
      ELSE  && control source is a table/view
        IF "." $ THIS.cControlSource
          REPLACE (SUBSTR(THIS.cControlSource,AT(".",THIS.cControlSource)+1)) ;
            WITH THIS.vDataValue ;
            IN (LEFT(THIS.cControlSource,AT(".",THIS.cControlSource)-1))
        ELSE
          REPLACE (THIS.cControlSource) WITH THIS.vDataValue
        ENDIF
      ENDIF
      RETURN .F.
    ENDIF
    RETURN
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION Click
    * This gets called because the control will be added to the form's
    * member event list when it is detected during ReadInput() that this
    * button is the one that was clicked.
    
    ** WAIT WINDOW (THIS.Name + " clicked!")
  ENDFUNC  && Click
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    LOCAL llRet
    * See if button was clicked:
    llRet = THIS.lVisible AND NOT EMPTY( THIS.vNewValue )
    RETURN m.llRet
    *** RETURN THIS.WasClicked()
  ENDFUNC  && WasClicked
  * ------------------------------------------------------------------- *
  FUNCTION WasClicked
    RETURN THIS.lUpdated
  ENDFUNC  && WasClicked
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * L7Button::ReadInput()
    IF (THIS.lDisabled AND NOT THIS.lRenderWhenDisabled) OR NOT THIS.lVisible
      RETURN
    ENDIF
    IF THIS.lMultiPart = .F.
      THIS.vNewValue = ALLTRIM( Request.Form( THIS.cHtmlName ))
    ELSE
      THIS.vNewValue = ALLTRIM( Request.GetMultiPartFormVar( THIS.cHtmlName ))
    ENDIF
    THIS.AfterReadInput()
    * More To Do Here!  Need to consider single-textbox bug in MSIE!!!
    THIS.lInputRead = .T.
    THIS.lUpdated = THIS.WasChanged()
    IF THIS.lUpdated AND VARTYPE(THIS.Parent) = "O"
      THIS.Parent.AddMemberEvent(THIS.Name, "CLICK")
    ENDIF
    RETURN
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION RenderLabel
    RETURN ""
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    THIS.lOutputCreated = .T.
    IF THIS.lDisabled AND NOT THIS.lRenderWhenDisabled
      RETURN ""
    ENDIF
    IF THIS.lHidden
      RETURN THIS.GetHiddenOutput()
    ENDIF
    LOCAL lcText
    lcText = ""
    lcText = m.lcText + [<] + THIS.cHtmlTag + [ type="] + THIS.cType + ["] + ;
      [ value="] + TRIM( THIS.vOldValue) + ["] + ;
      [ name="] + THIS.cHtmlName + ["] + ;
      [ id="] + THIS.GetID() + ["] + ;
      IIF( EMPTY( THIS.cOnClick), [], [ onclick="] + THIS.cOnClick + ["]) + ;
      IIF( EMPTY( THIS.cOnMouseOver), [], [ onmouseover="] + THIS.cOnMouseOver + ["]) + ;
      IIF( EMPTY( THIS.cOnMouseOut), [], [ onmouseout="] + THIS.cOnMouseOut + ["]) + ;
      IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cCssClass + ["]) + ;
      IIF( EMPTY( THIS.cExtraTags), [], [ ] + THIS.cExtraTags)

    IF INLIST(THIS.cHtmlTag, "button", "a")
      lcText = m.lcText + THIS.cContent + [</] + THIS.cHtmlTag + [>]
    ELSE && <input> control, so just close empty element:
      lcText = m.lcText + [ />]
    ENDIF
    RETURN m.lcText + CR
  ENDFUNC  && GetOutput
ENDDEFINE  && L7Button

* ==================================================================== *
DEFINE CLASS L7NavigateButton AS L7Button
  * Property Definitions:
  cClickURL = ""
  cType     = "SUBMIT"  && "BUTTON"
  cHtmlName = "btnNavigate"
  vOldValue = "Navigate"
  vNewValue = ""
  * ------------------------------------------------------------------- *
  FUNCTION cOnClick_ACCESS
    IF EMPTY(THIS.cClickURL)
      RETURN THIS.cOnClick
    ELSE
      RETURN "window.location='" + THIS.cClickURL + "';return false;"
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION CLICK
    * Technically this code will only be called if JS is off, since this
    * button is supposed to call client-side navigation.
    IF NOT EMPTY(THIS.cClickUrl)
      *[[ tentative:
      THIS.Parent.Cancel(THIS.cClickUrl)
    ELSE
      ERROR THIS.cHtmlName + ;
        " button pressed, and I have not been told what to do when this happens."
    ENDIF
    RETURN
  ENDFUNC
ENDDEFINE  && L7CancelButton

* ==================================================================== *
DEFINE CLASS L7CancelButton AS L7NavigateButton
  * Property Definitions:
  cControlCssClass = "Cancel"
  cOnMouseOver      = "this.className='CancelOver'"
  cOnMouseOut       = "this.className='Cancel'"
  *cOnClick  = "history.back();"
  cOnClick  = ""
  cType     = "BUTTON"
  cHtmlName = "btnCancel"
  vOldValue = "Cancel"
  vNewValue = ""
  lRenderWhenDisabled = .T.  
  * ------------------------------------------------------------------- *
  FUNCTION AfterPrepareObjects  
    * If button hasn't been assigned an activity, have it
    * navigate to parent form's cancel URL. If there is not
    * one, remove the cancel button.
    IF EMPTY(THIS.cOnClick)
      IF EMPTY(THIS.Parent.cCancelUrl)
        THIS.lVisible = .F.
      ELSE
        THIS.cClickUrl = THIS.Parent.cCancelUrl
      ENDIF
    ENDIF
    DODEFAULT()
    RETURN
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION CLICK
    * Technically this code should never be called, since this
    * button is supposed to call client-side navigation.
    IF VARTYPE( THIS.Parent) = "O"
      THIS.Parent.Cancel()
    ENDIF
    RETURN
  ENDFUNC
ENDDEFINE  && L7CancelButton

* ==================================================================== *
DEFINE CLASS L7PreviewButton AS L7Button
  * Property Definitions:
  cControlCssClass = "Preview"
  *cOnClick  = "history.back();"
  cOnClick  = ""
  cType     = "submit"
  cHtmlName = "btnPreview"
  vOldValue = "Preview"
  vNewValue = ""
  * ------------------------------------------------------------------- *
  FUNCTION CLICK
    IF VARTYPE( THIS.Parent) = "O"
      THIS.Parent.ReDisplay()
    ENDIF
    RETURN
  ENDFUNC
ENDDEFINE  && L7PreviewButton

* ==================================================================== *
DEFINE CLASS L7SubmitButton AS L7Button
  * Property Definitions:
  cControlCssClass  = "Submit"
  cOnMouseOver  = "this.className='SubmitOver';"
  cOnMouseOut   = "this.className='Submit';"
  cOnClick  = ""
  cType     = "submit"
  cHtmlName = "btnSubmit"
  vOldValue = NULL && NULL causes form's cSubmitCaption to rule "Submit"
  vNewValue = ""
ENDDEFINE  && L7SubmitButton

* ==================================================================== *
DEFINE CLASS L7ResetButton AS L7Button
  * Property Definitions:
  cControlCssClass = "Reset"
  cOnClick  = ""
  cType     = "RESET"
  cHtmlName = "btnReset"
  vOldValue = "Reset"
  vNewValue = ""
ENDDEFINE  && L7ResetButton

* ==================================================================== *
DEFINE CLASS L7Hidden AS L7Textbox
  * Property Definitions:
  cControlCssClass   = "FormHidden"
  lHidden     = .T.
  lShowOnForm = .F.  && Used by L7Form to decide on displaying value.
  cShowExpression  = NULL   && Show something different from the value.
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    RETURN THIS.GetHiddenOutput()
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7Hidden

* ==================================================================== *
DEFINE CLASS L7Checkbox AS L7_CONTROL_CLASS
  * Property Definitions:
  nMode            = L7_MULTI_CHECKBOX && or L7_MULTI_RADIOBUTTON
  nStyle           = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
  cControlCssClass = "FormCheckbox"
  cLabel           = NULL
  vNewValue        = .F.
  vOldValue        = .F.
  cFieldType       = "L"  
  cCaption         = "Yes"   && allows over-ride of cLabel w/ longer text.
  cFalseCaption    = "No"    && used when displayed as radio buttons (nMode=2)
  lFalseBeforeTrue = .F.
  cInterControlText = NULL 
  cShowExpression  = [IIF(THIS.vNewValue,THIS.cCaption,THIS.cFalseCaption)]
  cCheckedValue    = "ON"
  cUncheckedValue  = "OFF"  && used when displayed as radio buttons (nMode=2)
  lAllowUnanswered = .F.    && when no radio button checked
  lUnansweredValue = NULL
  lCheckRequired   = .F.    && set TRUE for policy checkboxes that must be checked
  * ------------------------------------------------------------------- *
  FUNCTION cDisplayValue_ACCESS
    IF ISNULL( THIS.cDisplayValue )
      IF ( THIS.lHidden OR THIS.lDisabled ) AND ;
        NOT ISNULL( THIS.cShowExpression) AND ;
        NOT EMPTY( THIS.cShowExpression) 
        *
        * THIS.cDisplayValue = TRANS( EVAL( THIS.cShowExpression))
        RETURN TRANS( EVAL( THIS.cShowExpression))
        * RETURN it, don't store it, so it gets re-evaluated each time,
        * which is essential for controls in Grids.
      ELSE
        IF VARTYPE( THIS.vNewValue) = "C"
          THIS.cDisplayValue = TRIM( THIS.vNewValue )
        ELSE
          THIS.cDisplayValue = TRANSFORM( THIS.vNewValue )
        ENDIF
      ENDIF
    ENDIF
    RETURN THIS.cDisplayValue
  ENDFUNC  && cDisplayValue_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION GetHiddenOutput
    THIS.lOutputCreated = .T.
    LOCAL lcTxt
    THIS.SetValueIfNeeded()
    lcTxt = [<input type="hidden" name="] + THIS.cHtmlName + ["] + ;
      [ value="] + IIF( THIS.vNewValue, THIS.cCheckedValue, []) + ["] + ;
      [ />] + CR
    IF THIS.lShowOnForm
      lcTxt = m.lcTxt + THIS.cDisplayValue + CR
      IF NOT EMPTY( THIS.cReadOnlyDataCssClass)
        lcTxt = [<span class="] + THIS.cReadOnlyDataCssClass + [">] + ;
          m.lcTxt + [</span>]
      ENDIF
    ENDIF
    RETURN m.lcTxt
  ENDFUNC  && GetHiddenOutput
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    THIS.lOutputCreated = .T.
    THIS.SetValueIfNeeded()
    LOCAL lcText, lcCaption, lcId
    STORE "" TO lcText, lcCaption
    lcId = THIS.GetID()
    
    DO CASE
    CASE ISNULL( THIS.cCaption)
      lcCaption = ""
    CASE EMPTY( THIS.cCaption)
      lcCaption = IIF( EMPTY( THIS.cLabel), THIS.cHtmlName, THIS.cLabel )
    OTHERWISE
      lcCaption = THIS.cCaption
    ENDCASE

    lcText = ""
    DO CASE
    CASE THIS.lDisabled
      lcText = m.lcText + [<span] + ;
        IIF(EMPTY(THIS.cReadOnlyDataCssClass), [], ;
          [ class="] + THIS.cReadOnlyDataCssClass + ["]) + [>] + ;
        ALLTRIM(TRANSFORM(THIS.cDisplayValue)) + [</span>]
    CASE THIS.lHidden
      lcText = m.lcText + THIS.GetHiddenOutput()
    OTHERWISE
      DO CASE
      CASE THIS.nMode = L7_MULTI_CHECKBOX
        lcText = m.lcText + [<input type="checkbox" name="] + THIS.cHtmlName + ["] + ;
          IIF( THIS.vNewValue, [ checked="checked"], []) + ;
          [ value="] + THIS.cCheckedValue + ["] + ;
          IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
          IIF( EMPTY( THIS.cOnClick), [], [ onclick="] + THIS.cOnClick + ["]) + ;
          IIF( EMPTY( THIS.cOnChange), [], [ onchange="] + THIS.cOnChange + ["]) + ;
          IIF( EMPTY( THIS.cOnBlur), [], [ onblur="] + THIS.cOnBlur + ["]) + ;
          [ id="] + m.lcId + [" />]

        lcText = m.lcText + ;
          [<label class="FormCheckboxCaption" for="] + m.lcId + [">] + ;
          m.lcCaption + [</label>]
        
      CASE THIS.nMode = L7_MULTI_RADIOBUTTON
        LOCAL lcTrue, lcFalse, lcBetween
        lcTrue = THIS.GetTrueOutput(m.lcId, m.lcCaption)
        lcFalse = THIS.GetFalseOutput(m.lcId)
        lcBetween = NVL(THIS.cInterControlText, ;
          IIF(THIS.nStyle = L7_MULTISTYLE_VERTICAL, L7BR, "&nbsp;"))

        IF THIS.lFalseBeforeTrue
          lcText = m.lcText + m.lcFalse + m.lcBetween + m.lcTrue
        ELSE
          lcText = m.lcText + m.lcTrue + m.lcBetween + m.lcFalse
        ENDIF
       
      OTHERWISE
        ERROR "Undefined mode for logical field control."
      ENDCASE
    ENDCASE

    RETURN m.lcText 
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION GetTrueOutput(lcId, lcCaption)
    * TRUE radio button
    LOCAL lcRet
    lcRet = ;
      [<input type="radio" name="] + THIS.cHtmlName + ["] + ;
      IIF( THIS.vNewValue = .T., [ checked="checked"], []) + ;
      [ value="] + THIS.cCheckedValue + ["] + ;
      IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
      IIF( EMPTY( THIS.cOnClick), [], [ onclick="] + THIS.cOnClick + ["]) + ;
      IIF( EMPTY( THIS.cOnChange), [], [ onchange="] + THIS.cOnChange + ["]) + ;
      IIF( EMPTY( THIS.cOnBlur), [], [ onblur="] + THIS.cOnBlur + ["]) + ;
      [ id="] + m.lcID + [_1" />] + ;
      [<label class="FormCheckboxCaption" for="] + m.lcID + [_1">] + ;
      m.lcCaption + [</label>]
    RETURN m.lcRet
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION GetFalseOutput(lcId)
    * FALSE radio button
    LOCAL lcRet
    lcRet = ;
      [<input type="radio" name="] + THIS.cHtmlName + ["] + ;
      IIF( THIS.vNewValue = .F., [ checked="checked"], []) + ;
      [ value="] + THIS.cUncheckedValue + ["] + ;
      IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
      IIF( EMPTY( THIS.cOnClick), [], [ onclick="] + THIS.cOnClick + ["]) + ;
      IIF( EMPTY( THIS.cOnChange), [], [ onchange="] + THIS.cOnChange + ["]) + ;
      IIF( EMPTY( THIS.cOnBlur), [], [ onblur="] + THIS.cOnBlur + ["]) + ;
      [ id="] + m.lcID + [_0" />] + ;
      [<label class="FormCheckboxCaption" for="] + m.lcID + [_0">] + ;
      THIS.cFalseCaption + [</label>]
    RETURN m.lcRet
  ENDFUNC
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION XMLOutput
  *!*      IF NOT THIS.lVisible OR NOT THIS.lAutoReadInput
  *!*        RETURN []
  *!*      ENDIF
  *!*      LOCAL lcName
  *!*      lcName = THIS.cHtmlName
  *!*      RETURN [<] + m.lcName + [>] + IIF( THIS.vNewValue, THIS.cCheckedValue, THIS.cUncheckedValue ) + ;
  *!*        [</] + m.lcName + [>]
  *!*    ENDFUNC && XMLOutput
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION XMLInput
  *!*      LPARAMETERS lcXml && optional, use Parent.cInputXML if not passed
  *!*      IF NOT THIS.lVisible 
  *!*        RETURN
  *!*      ENDIF
  *!*      IF NOT THIS.SetValueIfNeeded()
  *!*        RETURN .F.
  *!*      ENDIF
  *!*      IF VARTYPE( m.lcXml) # "C"
  *!*        lcXml = THIS.Parent.cInputXML
  *!*      ENDIF
  *!*      LOCAL lcName, lxValue
  *!*      lcName = THIS.cHtmlName
  *!*      lxValue = L7ExtractElement( m.lcXml, m.lcName )
  *!*      THIS.vNewValue = ( m.lxValue == THIS.cCheckedValue )
  *!*    ENDFUNC && XMLInput
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * L7Checkbox::ReadInput()
    IF NOT THIS.lVisible OR THIS.lDisabled
      RETURN
    ENDIF
    IF NOT THIS.SetValueIfNeeded()
      RETURN .F.
    ENDIF
    LOCAL lcPostVal
    IF THIS.lMultiPart = .F.
      lcPostVal = Request.Form( THIS.cHtmlName ) 
    ELSE
      lcPostVal = Request.GetMultiPartFormVar( THIS.cHtmlName ) 
    ENDIF
      
    DO CASE
    CASE THIS.nMode = L7_MULTI_CHECKBOX
      THIS.vNewValue = m.lcPostVal == THIS.cCheckedValue
    CASE THIS.nMode = L7_MULTI_RADIOBUTTON
      DO CASE
      CASE m.lcPostVal == THIS.cCheckedValue
        THIS.vNewValue = .T.
      CASE m.lcPostVal == THIS.cUncheckedValue
        THIS.vNewValue = .F.
      OTHERWISE
        THIS.vNewValue = NULL
      ENDCASE
    OTHERWISE
      ERROR "Undefined mode for logical field control."
    ENDCASE

    THIS.AfterReadInput()
    THIS.lInputRead = .T.
    THIS.lUpdated = THIS.WasChanged()
    RETURN
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION AfterReadInput
    IF THIS.nMode = L7_MULTI_RADIOBUTTON
      IF ISNULL(THIS.vNewValue) AND THIS.lAllowUnanswered = .T.
        THIS.vNewValue = THIS.lUnansweredValue
      ENDIF
    ENDIF
    RETURN
  ENDFUNC  && AfterReadInput
  * ------------------------------------------------------------------- *
  FUNCTION Valid
    IF ISNULL(THIS.vNewValue) AND THIS.lAllowUnanswered = .F.
      * Presumably only applies under radio button mode, but possibly
      * applicable if back end supports NULLs.
      THIS.AddValidationMessage( ;
        IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
        ' must not be left blank!')
    ENDIF
    IF THIS.nInvalidCount = 0 AND THIS.lCheckRequired AND (ISNULL(THIS.vNewValue) OR THIS.vNewValue = .F.)
      THIS.AddValidationMessage( ;
        IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
        ' must be checked!')
    ENDIF 
    ** DODEFAULT()  && picks up required check in parent class
    RETURN ( THIS.nInvalidCount = 0 )
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7Checkbox

* ==================================================================== *
DEFINE CLASS L7Textbox AS L7_CONTROL_CLASS
  * Property Definitions:
  cControlCssClass      = "FormTextbox"
  lPassword      = .F.
  lAutoComplete  = .T.
  nSize          = 0
  nMinLength     = 0
  nMaxLength     = 0
  lAutoMaxLength = .T.
  vOldValue      = []
  vNewValue      = []
  vMinValue      = NULL
  vMaxValue      = NULL
  lFileUpload    = .F.

  * For textboxes only:
  cDisplayValue  = NULL && always character--what to show in box
  cFieldType     = "C"  && "D", "N"
  nDecimals      = NULL   && NULL: use defaults, 0: no decimals
  lUpperCase     = .F.  && .T. to force to upper case
  lLtrimInput    = .T.
  lRtrimInput    = .T.  && 12/16/2001 (had been .F.)
  lDisallowSpaces = .F. && don't allow any embedded spaces
  lDisallowSingleQuotes = .F. && ' not allowed
  cPadlChar      = NULL
  lSelectOnEntry = .F.
  cOnKeyUp       = ""    
  cStripChars     = "<>" && take these characters out of textboxes entirely--DON'T CONSIDER INVALID
  cValidChars = L7_FIELD_CHARACTERS  && if non-empty, input is INVALID unless all characters are from this set (e.g., '0123456789')
  cInvalidChars = ""   && if non-empty, input is INVALID if any of these characters appears (e.g., '{}[]<>')
  * ------------------------------------------------------------------- *
  FUNCTION SetValue(lvValue, lvNewValue)
    * L7Textbox::SetValue
    * Call basic control default behavior:
    DODEFAULT( m.lvValue, m.lvNewValue )
    
    IF THIS.cFieldType = "C" AND VARTYPE( m.lvValue) <> "C"
      * We've failed to set the type explicitly, so we need to guess:
      THIS.cFieldType = VARTYPE( m.lvValue)
      * Note: It is better to set the cFieldType for any non-character
      * fields as explicit control properties!
    ENDIF
    
    THIS.cDisplayValue = NULL  && reset this in case it was set by a previous read operation

    IF THIS.nSize <= 0  && NOT explicitly set in form class constructor code
      DO CASE
      CASE THIS.cFieldType = "C"
        THIS.nSize = MAX(4, LEN(THIS.vOldValue))
      CASE THIS.cFieldType = "D"
        THIS.nSize = 10
      CASE THIS.cFieldType = "T"
        THIS.nSize = 22
      CASE THIS.cFieldType = "I"
        THIS.nSize = 11
      CASE THIS.cFieldType = "Y"  && Currency
        THIS.nSize = 16
        IF ISNULL( THIS.nDecimals )   && NULL is metaphor for "use defaults", while 0 means "no decimals"
          THIS.nDecimals = 2
        ENDIF
      CASE THIS.cFieldType = "N"
        IF ISNULL(THIS.nDecimals)
          * Decimals not explicitly set in form defintion.
          IF THIS.lDetermineActualNumericSizes
            * Derive decimals from the data. 
            IF NOT EMPTY( THIS.cControlSource)
              * If a control source, use that (rather than explicit value,
              * in case we've set a default without worrying about precision).
              THIS.nDecimals = DecimalPlaces(EVALUATE(THIS.cControlSource))
            ELSE
              THIS.nDecimals = DecimalPlaces(THIS.vOldValue)
            ENDIF
          ELSE && use defaults
            THIS.nDecimals = SET("DECIMALS")
          ENDIF
        ENDIF
        THIS.nSize = MAX(THIS.nSize,10+THIS.nDecimals)
      OTHERWISE
        THIS.nSize = LEN( TRANSFORM( THIS.vOldValue ) )
      ENDCASE
    ENDIF  && THIS.nSize <= 0
    * MaxLength handling:
    IF THIS.lAutoMaxLength AND THIS.nMaxLength <= 0
      IF THIS.cFieldType = "C" AND NOT EMPTY(THIS.cControlSource)
        * Character field with a control source. Use value to determine max size.
        THIS.nMaxLength = LEN(THIS.vNewValue)
      ENDIF
    ENDIF
    RETURN 
  ENDFUNC  && L7Textbox::SetValue
  * ------------------------------------------------------------------- *
  FUNCTION cDisplayValue_ACCESS
    IF ISNULL( THIS.cDisplayValue )
      LOCAL lcType
      lcType = VARTYPE(THIS.vNewValue)
      DO CASE
      CASE m.lcType = "C"
        THIS.cDisplayValue = TRIM( THIS.vNewValue )
      CASE m.lcType $ "N" 
        IF NOT ISNULL(THIS.nDecimals)
          THIS.cDisplayValue = TRIM(PADR(ROUND(THIS.vNewValue,THIS.nDecimals),40))
        ELSE
          THIS.cDisplayValue = TRIM(PADR(THIS.vNewValue,40))
        ENDIF
      CASE m.lcType $ "Y" 
        IF NOT ISNULL(THIS.nDecimals)
          THIS.cDisplayValue = TRANSFORM(ROUND(MTON(THIS.vNewValue),THIS.nDecimals))
        ELSE
          THIS.cDisplayValue = TRANSFORM(MTON(THIS.vNewValue))
        ENDIF
      CASE m.lcType $ "DT" AND EMPTY(THIS.vNewValue)
        * Leave date/time textboxes blank for empty fields.
        THIS.cDisplayValue = "" 
      OTHERWISE
        THIS.cDisplayValue = TRANSFORM( THIS.vNewValue )
      ENDCASE
    ENDIF
    RETURN THIS.cDisplayValue
  ENDFUNC  && cDisplayValue_ACCESS
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION XMLInput
  *!*      LPARAMETERS lcXml && optional, use Parent.cInputXML if not passed
  *!*      IF NOT THIS.lVisible 
  *!*        RETURN
  *!*      ENDIF
  *!*      IF VARTYPE( m.lcXml) # "C"
  *!*        lcXml = THIS.Parent.cInputXML
  *!*      ENDIF
  *!*      LOCAL lcName, lxValue
  *!*      lcName = THIS.cHtmlName
  *!*      lxValue = L7ExtractElement( m.lcXml, m.lcName )
  *!*      THIS.cDisplayValue = m.lxValue
  *!*      THIS.AfterReadInput()
  *!*    ENDFUNC && XMLInput
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * With textboxes, we operate on cDisplayValue as a character value,
    * and then translate to actual field values separately.
    LOCAL lcStr
    IF NOT THIS.lVisible OR THIS.lDisabled
      RETURN
    ENDIF
    THIS.SetValueIfNeeded()
    * 12/12/2001: Removed ALLTRIM() from the following 2 
    *   method calls, so that specific control trimming options can be honored.
    IF THIS.lMultiPart = .F.
      lcStr = Request.Form( THIS.cHtmlName )
    ELSE
      lcStr = Request.GetMultiPartFormVar( THIS.cHtmlName )
    ENDIF
    IF CHR(10) $ m.lcStr OR CHR(13) $ m.lcStr && browser allowed multi-line paste or EOL
      lcStr = CHRTRAN(m.lcStr, CHR(10), CHR(13))
      lcStr = LEFT(m.lcStr, AT(CHR(13), m.lcStr) - 1)
    ENDIF
    THIS.cDisplayValue = m.lcStr
    THIS.AfterReadInput()
    THIS.lInputRead = .T.
    THIS.lUpdated = THIS.WasChanged()
    RETURN
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION AfterReadInput
    * Post-ReadInput hook.
    * Also called from XMLInput()
    DO CASE
    CASE THIS.cFieldType = "C"
      LOCAL lnPointer
      FOR lnPointer = 1 TO LEN(THIS.cStripChars)
        THIS.cDisplayValue = STRTRAN(THIS.cDisplayValue, SUBSTR(THIS.cStripChars, m.lnPointer, 1))
      ENDFOR
      IF THIS.lUpperCase
        THIS.cDisplayValue = UPPER( THIS.cDisplayValue )
      ENDIF
      IF THIS.lLtrimInput
        THIS.cDisplayValue = LTRIM( THIS.cDisplayValue )
      ENDIF
      IF THIS.lRtrimInput
        THIS.cDisplayValue = RTRIM( THIS.cDisplayValue )
      ENDIF
      IF NOT ISNULL(THIS.cPadlChar)
        THIS.cDisplayValue = PADL(THIS.cDisplayValue,LEN(THIS.vOldValue),THIS.cPadlChar)
      ENDIF
      THIS.vNewValue = THIS.cDisplayValue

    CASE THIS.cFieldType = "D"  && Date
      THIS.vNewValue = CTOD( THIS.cDisplayValue )

    CASE THIS.cFieldType $ "NBY"
      * Strip any commas entered, so VAL() works:
      THIS.vNewValue = VAL( STRTRAN( THIS.cDisplayValue, ",") )
      * 05/06/2001: Added NOT in following expression:
      IF NOT ISNULL( THIS.nDecimals)
        THIS.vNewValue = ROUND( THIS.vNewValue, THIS.nDecimals )
      ENDIF
      IF THIS.cFieldType = "Y"  && specifically Currency
        THIS.vNewValue = NTOM( THIS.vNewValue )
      ENDIF

    CASE THIS.cFieldType = "I"  && Integer
      THIS.vNewValue = ROUND( VAL( STRTRAN( THIS.cDisplayValue, ",") ), 0 )

*!*      CASE THIS.cFieldType = "Y"  && Currency
*!*        THIS.vNewValue = NTOM( VAL( THIS.cDisplayValue ) )

    CASE THIS.cFieldType = "T"
      THIS.vNewValue = CTOT( THIS.cDisplayValue )

    OTHERWISE  && Probably not going to work.
      THIS.vNewValue = THIS.cDisplayValue
    ENDCASE
    RETURN
  ENDFUNC  && AfterReadInput
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    IF THIS.cFieldType = "C"
      RETURN NOT ( ALLTRIM( THIS.vNewValue) == ALLTRIM( THIS.vOldValue) )
    ELSE
      RETURN NOT ( THIS.vNewValue == THIS.vOldValue )
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION Valid  && Textbox Validation.
    local lcStr
    IF THIS.nMaxLength > 0 AND LEN(THIS.cDisplayValue) > THIS.nMaxLength
      THIS.AddValidationMessage( 'Exceeded maximum input length.')
      RETURN .F.
    ENDIF
    if this.nMinLength > 0 AND LEN(THIS.cDisplayValue) < THIS.nMinLength
      THIS.AddValidationMessage( 'Input must be at least ' + transform(THIS.nMinLength) + ' characters.')
      return .F. 
    endif 
    IF THIS.cFieldType = "D" AND ;
      NOT EMPTY( THIS.cDisplayValue ) AND ;
      LTRIM( THIS.cDisplayValue) # "/" AND ;
      EMPTY( THIS.vNewValue )
      *
      * Date value invalid. This must be checked first, since vNewValue
      * will be empty for a special reason.
      THIS.AddValidationMessage( 'Field "' + THIS.cLabel + '" has invalid date or invalid format (MM/DD/YYYY).')
    ELSE
      * Check for empty value of -required- items:
      IF NOT THIS.cFieldType $ "NYIB"  && Not applicable to numerics
        IF THIS.lRequired AND EMPTY( THIS.vNewValue )
          THIS.AddValidationMessage( ;
            IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
            ' must not be left blank.')
        ENDIF
      ENDIF
      * Embedded space check:
      IF THIS.cFieldType = "C" AND THIS.lDisallowSpaces
        IF SPACE(1) $ ALLTRIM( THIS.vNewValue )
          THIS.AddValidationMessage( ;
            IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
            ' cannot have embedded spaces.')
        ENDIF
      ENDIF
      * Single quote check:
      IF THIS.cFieldType = "C" AND THIS.lDisallowSingleQuotes
        IF ['] $ ALLTRIM( THIS.vNewValue )
          THIS.AddValidationMessage( ;
            IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
            ' cannot have quotes or apostrophes.')
        ENDIF
      ENDIF
      * Valid and Invalid Chars Check:
      IF THIS.cFieldType = "C" 
        IF !EMPTY(THIS.cValidChars)
          lcStr = CHRTRAN(THIS.vNewValue, THIS.cValidChars, '') && invalid chars in remainder
          IF !EMPTY(m.lcStr)
            * something in addition to valid chars included
            THIS.AddValidationMessage( ;
              IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
              ' has unallowed characters (err: ' + transform(256 - asc(left(m.lcStr, 1))) + ')')
              
            * (validation message obfuscated with 256-asc() of 1st invalid char)
            * remove bad chars, to prevent content-injection hack on re-display: 
            this.cDisplayValue = chrtran(this.cDisplayValue, CHRTRAN(THIS.cDisplayValue, THIS.cValidChars, ''), '')
          ENDIF
        ENDIF
        IF NOT EMPTY(THIS.cInvalidChars)
          IF NOT CHRTRAN(THIS.vNewValue, THIS.cInvalidChars, '') == THIS.vNewValue
            * invalid chars included
            THIS.AddValidationMessage( ;
              IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
              ' has unallowed characters.')
            * remove bad chars, to prevent content-injection hack on re-display: 
            THIS.cDisplayValue = CHRTRAN(THIS.cDisplayValue, THIS.cInvalidChars, '')
          ENDIF
        ENDIF
      ENDIF
      * Minimum check:
      IF NOT ISNULL( THIS.vMinValue) AND THIS.vNewValue < THIS.vMinValue
        THIS.AddValidationMessage( ;
          IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
          ' can be no less than ' + TRANSFORM( THIS.vMinValue) + '.')
      ENDIF
      * Maximum check:
      IF NOT ISNULL( THIS.vMaxValue) AND THIS.vNewValue > THIS.vMaxValue
        THIS.AddValidationMessage( ;
          IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
          ' can be no greater than ' + TRANSFORM( THIS.vMaxValue) + '.')
      ENDIF
    ENDIF
    RETURN ( THIS.nInvalidCount = 0 )
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    THIS.lOutputCreated = .T.
    THIS.SetValueIfNeeded()
    
    *[[? Should the next 2 parts be reversed? (ie, if a control is both hidden and disabled)
    IF THIS.lDisabled
      RETURN [<span] + ;
        IIF( EMPTY( THIS.cReadOnlyDataCssClass), [], ;
          [ class="] + THIS.cReadOnlyDataCssClass + ["]) + ;
        [>] + ;
        ALLTRIM( TRANSFORM( THIS.vNewValue )) + [</span>]
    ENDIF
    IF THIS.lHidden
      RETURN THIS.GetHiddenOutput()
    ENDIF
    IF THIS.nSize = 0
      IF VARTYPE( THIS.vNewValue ) # "C" OR LEN( THIS.vNewValue) = 0
        THIS.nSize = 10
      ELSE
        THIS.nSize = LEN( THIS.vNewValue )
      ENDIF
    ENDIF
    LOCAL lcText
    lcText = ""

    lcText = m.lcText + [<input type="] + ;
      IIF( THIS.lPassword, "password", ;
        IIF( THIS.lFileUpload, "file", "text" ) ) + ["] + ;
      [ name="] + THIS.cHtmlName + ["] + ;
      [ id="] + THIS.GetID() + ["] + ;
      [ value="] + THIS.cDisplayValue + ["] + ;  && [[ still need protection against double-quotes in data!
      IIF(THIS.lAutoComplete, [], [ autocomplete="off"]) + ;
      IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
      IIF( EMPTY( THIS.cControlCssStyle), [], [ style="] + THIS.cControlCssStyle + ["])
      
    *!*      lcText = m.lcText + ;
    *!*        [ name="] + THIS.cHtmlName + ["] + ;
    *!*        [ id="] + THIS.GetID() + ["] + ;
    *!*        [ value="] + THIS.cDisplayValue + ["] 
      
    IF NOT EMPTY(THIS.cExtraTags)
      lcText = m.lcText + [ ] + THIS.cExtraTags
    ENDIF

    lcText = m.lcText + [ size="] + LTRIM( STR( THIS.nSize)) + ["] + ;
      IIF( THIS.nMaxLength > 0, ;
        [ maxlength="] + LTRIM( STR( THIS.nMaxLength)) + ["], [])
    lcText = m.lcText + THIS.GetEventAttributes()
    lcText = m.lcText + [ />]

    RETURN m.lcText 
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION GetEventAttributes()
    LOCAL lcAttr
    lcAttr = ;
      IIF( EMPTY( THIS.cOnClick), [], [ onclick="] + THIS.cOnClick + ["]) + ;
      IIF( EMPTY( THIS.cOnChange), [], [ onchange="] + THIS.cOnChange + ["]) + ;
      IIF( EMPTY( THIS.cOnBlur), [], [ onblur="] + THIS.cOnBlur + ["]) + ;
      IIF( EMPTY( THIS.cOnKeyUp), [], [ onkeyup="] + THIS.cOnKeyUp + ["]) + ;
      IIF( NOT THIS.lSelectOnEntry, [], [ onfocus="select();"])
    RETURN m.lcAttr
  ENDFUNC
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7Textbox

* ==================================================================== *
DEFINE CLASS L7FileUpload AS L7Textbox
  * USAGE NOTES: While this control *can* be used to write the uploaded file 
  *  to disk, using the SaveAs() method, you should consider doing this 
  *  yourself. Your application may need to decide where to put the
  *  file, what to name it (if different), and how to deal with permissions,
  *  previous existence of a file with the same name, etc.
  *
  * Use STRTOFILE( object.cFileContents, yourpath + object.cFileName )
  *  or similar to create the file.

  lFileUpload   = .T.
  lAutoSave     = .F.  && automatically call SaveAs() if Valid() passes (not encouraged)
  lMultiPart    = .T.
  nFileSize     = 0
  cFieldType    = "C"
  vOldValue     = ""
  vNewValue     = ""
  cFileName     = ""
  cFileContents = ""
  nMaxFilenameSize = NULL  && set to bound field size to force validation errors
  
  * SaveAs properties:
  cSaveAsFolder   = ""
  cSaveAsName     = ""
  
  * These strips and replaces occur _prior_ to validation:  
  cStripChars     = "#<>" && take these characters out of file names entirely
  lConvertSpacesToUnderscores = .F. && superseded by cSpaceReplacement
  cSpaceReplacement = ""   && use " " to leave alone, "" to strip, "_" for underscore
  cCommaReplacement = "-"  && use "," to leave alone, "" to strip, "_" for underscore
  cAmpersandReplacement = "-" 
  cTransformExtraPeriodString = "_"  && set NULL for no action
  
  * Note: cValidChars or cInvalidChars matches create VALIDATION ERRORS, but any
  * stripping and replacing of characters (per above) occur before validation.
  cValidChars     = null && if specified, overrides cInvalidChar use
  cInvalidChars   = L7_INVALID_FILENAME_CHARACTERS  && see L7.H

  lOverwriteProtection = .T.
  cSaveErrorMessage = ""
  nBytesWritten = 0
  
  * Extension validation:
  cDisallowExtensions = ""
  cAllowExtensions    = ""
  lAllowNoExtension   = .F.
  cForceEmptyExtension = NULL
  * cTransformExtraPeriodString = "_" also affects this
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    IF NOT THIS.lVisible OR THIS.lDisabled
      RETURN
    ENDIF
    LOCAL lcFileName, lcBuffer
    lcFileName = ""
    lcBuffer = Request.GetMultiPartFile( THIS.cHtmlName, @lcFileName)
    THIS.nFileSize = LEN( m.lcBuffer)
    IF THIS.nFileSize > 0
      IF CHR(10) $ m.lcFileName OR CHR(13) $ m.lcFileName && browser allowed multi-line paste or EOL
        lcFileName = CHRTRAN(m.lcFileName, CHR(10), CHR(13))
        lcFileName = LEFT(m.lcFileName, AT(CHR(13), m.lcFileName) - 1)
      ENDIF
      THIS.cFileName = ALLTRIM(m.lcFileName)
      THIS.cFileContents = m.lcBuffer
    ENDIF
    THIS.AfterReadInput()
    THIS.lInputRead = .T.
    THIS.lUpdated = THIS.WasChanged()
    RETURN
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION AfterReadInput
    IF NOT EMPTY(THIS.cFileName)
      THIS.cFileName = THIS.CleanFilename(THIS.cFileName)
    ENDIF
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION CleanFilename(lcName)
    LOCAL lnPointer, lcExt, lnOccurs
    FOR lnPointer = 1 TO LEN(nvl(THIS.cStripChars, ""))
      lcName = STRTRAN(m.lcName, SUBSTR(THIS.cStripChars, m.lnPointer, 1))
    ENDFOR
    IF THIS.lConvertSpacesToUnderscores
      lcName = STRTRAN(m.lcName, ' ', '_')
    ENDIF
    IF NOT nvl(THIS.cSpaceReplacement, " ") == " "
      lcName = STRTRAN(m.lcName, ' ', THIS.cSpaceReplacement)
    ENDIF
    * 08/24/2009: Added comma-replacement. Commas create issues when emailing files, as that is delimiter between filenames.
    IF NOT nvl(THIS.cCommaReplacement, ",") == ","
      lcName = STRTRAN(m.lcName, ',', THIS.cCommaReplacement)
    ENDIF
    * '&' in file name (validation issue--can't just encode in URLs):
    IF VARTYPE(THIS.cAmpersandReplacement) = "C" 
      lcName = STRTRAN(m.lcName, '&', THIS.cAmpersandReplacement)
    ENDIF
    * Extension:
    lcExt = JUSTEXT(m.lcName)
    IF EMPTY(m.lcExt)
      IF NOT RIGHT(m.lcName,1) = "."
        * Adding explicit "." prevents some failures, such as
        * VFP commands like RENAME that "assume" a DBF extension.
        lcName = m.lcName + "."
      ENDIF
      IF NOT ISNULL(THIS.cForceEmptyExtension)
        lcName = FORCEEXT(m.lcName, THIS.cForceEmptyExtension)
      ENDIF
    ENDIF
    lnOccurs = OCCURS(".", m.lcName)
    IF m.lnOccurs > 1 AND NOT ISNULL(THIS.cTransformExtraPeriodString)
      lcName = STRTRAN(m.lcName, ".", THIS.cTransformExtraPeriodString, 1, m.lnOccurs - 1)
    ENDIF
    RETURN m.lcName
  ENDFUNC  && CleanFilename
  * ------------------------------------------------------------------- *
  FUNCTION Valid
    * L7FileUpload::Valid()
    IF THIS.lRequired AND EMPTY( THIS.cFileName)
      THIS.AddValidationMessage( 'A file was not uploaded for ' + ;
        IIF( THIS.cLabel == THIS.cHtmlName, '', ' "' + THIS.cLabel + '"') + ;
        '.')
    ENDIF
    IF NOT EMPTY( THIS.cFileName) AND THIS.nFileSize <= 0
      THIS.AddValidationMessage( 'No bytes were received for file ' + ;
        THIS.cFileName + '.')
    ENDIF
    IF NOT EMPTY( THIS.cFileName) AND THIS.nInvalidCount = 0
      THIS.ValidateStem()
      THIS.ValidateExtension()
      THIS.ValidateFilenameSize()
    ENDIF
    IF THIS.nInvalidCount = 0 AND THIS.lAutoSave AND THIS.nFileSize > 0
      IF NOT THIS.SaveAs()
        THIS.AddValidationMessage( 'File ' + ;
          THIS.cFileName + ' could not be saved to disk.')
      ENDIF
    ENDIF
    RETURN ( THIS.nInvalidCount = 0 )
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
  FUNCTION ValidateFilenameSize(tcFile)
    IF NVL(THIS.nMaxFilenameSize, 0) = 0
      RETURN
    ENDIF 
    LOCAL lcFile
    lcFile = EVL(m.tcFile, THIS.cFileName) && allows passing of alternative name to check, such as a "rename" candidate
    IF LEN(m.lcFile) > THIS.nMaxFilenameSize
      THIS.AddValidationMessage('File name too long (stems) to store in database.' + ;
        ' (Max: ' + TRANSFORM(THIS.nMaxFilenameSize) + ' characters.)')
    ENDIF
    RETURN
  ENDFUNC  && ValidateStem
  * ------------------------------------------------------------------- *
  FUNCTION ValidateStem(tcFile)
    LOCAL lcStem, lcFile, lcInvalChrs
    lcFile = EVL(m.tcFile, THIS.cFileName) && allows passing of alternative name to check, such as a "rename" candidate
    lcStem = JUSTSTEM(m.lcFile)
    IF EMPTY(m.lcStem)
      THIS.AddValidationMessage('Files without names (stems) are not allowed.')
    ELSE
      DO CASE
      case !isnull(this.cValidChars) and !empty(this.cValidChars)
        lcStem = lower(m.lcStem)
        lcInvalChrs = chrtran(m.lcStem, lower(this.cValidChars), '')
        if !empty(m.lcInvalChrs)
          this.AddValidationMessage('Filenames may not include these characters: ' + m.lcInvalChrs)
          return .F.
        endif 

        * This didn't help them see the problem chars:        
        *!*          if ! m.lcStem == chrtran(m.lcStem, chrtran(m.lcStem, lower(this.cValidChars), ''), '')
        *!*            THIS.AddValidationMessage('Filenames must include only these characters: ' + THIS.cValidChars)
        *!*            RETURN .F.
        *!*          endif 
  
      CASE NOT EMPTY(THIS.cInvalidChars) && explicit "disallow" list
        IF NOT m.lcStem == CHRTRAN(m.lcStem, THIS.cInvalidChars, "")
          THIS.AddValidationMessage('The following characters are not allowed in file names: ' + THIS.cInvalidChars)
          RETURN .F.
        ENDIF
      ENDCASE
    ENDIF
    RETURN
  ENDFUNC  && ValidateStem
  * ------------------------------------------------------------------- *
  FUNCTION ValidateExtension(tcFile)
    LOCAL lcExt, lcRule, lcFile
    lcFile = EVL(m.tcFile, THIS.cFileName) && allows passing of alternative name to check, such as a "rename" candidate
    lcExt = UPPER(JUSTEXT(m.lcFile))
    IF EMPTY(m.lcExt)
      IF NOT THIS.lAllowNoExtension 
        THIS.AddValidationMessage('Files without extension names are not allowed.')
      ENDIF
    ELSE
      DO CASE
      CASE NOT EMPTY(THIS.cAllowExtensions) && explicit "allow" list
        lcRule = "," + STRTRAN(UPPER(THIS.cAllowExtensions)," ") + ","
        IF NOT "," + m.lcExt + "," $ m.lcRule
          THIS.AddValidationMessage('Only files of type ' + ;
            THIS.cAllowExtensions + ' are allowed.')
          RETURN .F.
        ENDIF
      CASE NOT EMPTY(THIS.cDisallowExtensions) && explicit "disallow" list
        lcRule = "," + STRTRAN(UPPER(THIS.cDisallowExtensions)," ") + ","
        IF "," + m.lcExt + "," $ m.lcRule
          THIS.AddValidationMessage('Files of type ' + ;
            m.lcExt + ' are not allowed.')
          RETURN .F.
        ENDIF
      ENDCASE
    ENDIF
    RETURN
  ENDFUNC  && ValidateExtension
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION XMLOutput
  *!*      ERROR "L7FileUpload Class does not support XML at this time!"
  *!*      RETURN []
  *!*    ENDFUNC

  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION XMLInput
  *!*      LPARAMETERS lcXml
  *!*      ERROR "L7FileUpload Class does not support XML at this time!"
  *!*    ENDFUNC

  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    RETURN THIS.nFileSize > 0
  ENDFUNC
  * ------------------------------------------------------------------- *
  function SaveAs(tcFilePath, tcFileName)
    * If parameters passed, uses those. Otherwise uses properties. 
    * If properties and parameters are blank (not recommended), 
    * uses current web path plus the user's file name.
    
    local lcPath, lcName
    * Resolve path:
    if !empty( m.tcFilePath)
      lcPath = addbs(m.tcFilePath)
    else && path not passed
      if !empty(this.cSaveAsFolder)
        lcPath = addbs(this.cSaveAsFolder)
      else  && rogue--default to current web folder:
        lcPath = addbs(justpath( Request.ServerVariables("PHYSICAL_PATH")))
      endif 
    endif 
    * Resolve file name:
    if !empty(m.tcFileName)
      lcName = alltrim(m.tcFileName)
    else 
      if !empty(this.cSaveAsName)
        lcName = alltrim(this.cSaveAsName)
      else  && default to same name as on user's system
        lcName = alltrim(this.cFileName)
      endif 
    endif 
    if !empty(m.lcName)
      * Write the file, respecting overwrite protection.
      if this.lOverwriteProtection
        if file(m.lcPath + m.lcName)
          this.cSaveErrorMessage = "File " + m.lcPath + m.lcName + " already exists."
          return .F.
        endif 
      endif 
      local lnBytes
      lnBytes = strtofile( this.cFileContents, m.lcPath + m.lcName )
      do case 
      case m.lnBytes = this.nFileSize
        = .F.
      case m.lnBytes = 0
        this.cSaveErrorMessage = "File " + m.lcPath + m.lcName + " could not be written."
        return .f.
      otherwise 
        this.cSaveErrorMessage = transform( m.lnBytes, "999,999,999,999") + ;
          " bytes were written to disk, compared to the uploaded file size of " + ;
          transform(this.nFileSize, "999,999,999,999") + ;
          " for file " + m.lcPath + m.lcName + "."
      endcase 
    endif 
    return 
  endfunc  && SaveAs
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7FileUpload

* ==================================================================== *
define class L7JsonTextarea as L7TextArea 
  * Property Overrides--prevent control from munging JSON:
  nMaxChars = -1
  lNoScript       = .f. 
  lLtrimInput     = .f.
  lRtrimInput     = .f.
  lUpperCase      = .f.
  lFixSmartQuotes = .f.
  nTabsToSpaces   = -1   && positive number causes translation
  lSmartTrim      = .f.  && force AllTrimX()
  cReplaceCRLF    = NULL
enddefine  && L7JsonTextarea 

* ==================================================================== *
DEFINE CLASS L7TextArea AS L7_CONTROL_CLASS
  * Property Definitions:
  cControlCssClass = "FormTextarea"
  nRows      = 4  && set to NULL to have calculation performed
  nCharsPerRow = 100
  nMaxRows     = 30
  nMinRows  = 4
  nCols     = 60
  cWidth    = ""  && mutually exclusive with nCols, presumably??
  nMaxChars = -1  && -1 = no limit
  cWrap     = "soft"  && "VIRTUAL" is not in the standard
  vOldValue = []
  vNewValue = []

  * Textarea-specific:
  lNoScript       = .T. && treat <script as breach
  lLtrimInput     = .F.
  lRtrimInput     = .T.
  lUpperCase      = .F.
  lFixSmartQuotes = .T.
  nTabsToSpaces   = 2   && positive number causes translation
  lSmartTrim      = .F. && force AllTrimX()
  cReplaceCRLF    = NULL
  cDisabledTransformationUDF = "HTMemo"  && could substitute a different parser
  * ------------------------------------------------------------------- *
  function nRows_ACCESS
    if isnull(THIS.nRows)
      this.nRows = max(4, int(len(this.vNewValue)/this.nCharsPerRow))
      this.nRows = min(this.nRows, this.nMaxRows)
      this.nRows = MAX(this.nRows, this.nMinRows)
    endif
    return this.nRows
  endfunc
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION XMLInput
  *!*      LPARAMETERS lcXml && optional, use Parent.cInputXML if not passed
  *!*      IF NOT THIS.lVisible OR NOT THIS.lAutoReadInput
  *!*        RETURN
  *!*      ENDIF
  *!*      IF VARTYPE( m.lcXml) # "C"
  *!*        lcXml = THIS.Parent.cInputXML
  *!*      ENDIF
  *!*      LOCAL lcName, lxValue
  *!*      lcName = THIS.cHtmlName
  *!*      lxValue = L7ExtractElement( m.lcXml, m.lcName )
  *!*      lxValue = L7ExtractCDATA( m.lxValue)
  *!*      THIS.vNewValue = m.lxValue
  *!*    ENDFUNC && XMLInput
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION XMLOutput
  *!*      IF NOT THIS.lVisible OR NOT THIS.lAutoReadInput
  *!*        RETURN []
  *!*      ENDIF
  *!*      LOCAL lcName
  *!*      lcName = THIS.cHtmlName
  *!*      * Embed in CDATA section:
  *!*      RETURN [<] + m.lcName + [>] + IIF( EMPTY( THIS.vNewValue), '', ;
  *!*        '![CDATA[' + THIS.vNewValue + ']]' ) + ;
  *!*        [</] + m.lcName + [>]
  *!*    ENDFUNC && XMLOutput
  * ------------------------------------------------------------------- *
  FUNCTION Valid  && TextArea Validation
    IF THIS.nMaxChars > 0
      LOCAL lnLen
      lnLen = LEN( THIS.vNewValue )
      IF m.lnLen > THIS.nMaxChars
        THIS.AddValidationMessage(  ;
          IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
          ' cannot exceed ' + ;
          LTRIM( STR( THIS.nMaxChars)) + ' characters (currently ' + ;
          LTRIM( STR( m.lnLen )) + ').')
      ENDIF
    ENDIF
    IF THIS.lNoScript AND '<script' $ LOWER(THIS.vNewValue)
      ERROR 'Unauthorized attempt to insert JavaScript into text field!'
    ENDIF 
    IF THIS.lRequired AND EMPTY( THIS.vNewValue )
      THIS.AddValidationMessage( ;
        IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
        ' must not be left blank.')
    ENDIF
    RETURN ( THIS.nInvalidCount = 0 )
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
  FUNCTION AfterReadInput
    LOCAL lcTxt
    lcTxt = THIS.vNewValue
    IF THIS.lFixSmartQuotes = .T.
      * TO DO: Handle more possible problem characters:
      lcTxt = CHRTRAN( m.lcTxt, CHR(146) + CHR(147) + CHR(148) + CHR(149), ['""*])
    ENDIF
    IF THIS.nTabsToSpaces > 0   && positive number causes translation
      lcTxt = STRTRAN( m.lcTxt, CHR(9), SPACE( THIS.nTabsToSpaces))
    ENDIF
    IF THIS.lLtrimInput
      lcTxt = LTRIM( m.lcTxt )
    ENDIF
    IF THIS.lRtrimInput
      lcTxt = RTRIM( m.lcTxt )
    ENDIF
    IF THIS.lUpperCase
      lcTxt = UPPER( m.lcTxt )
    ENDIF
    IF THIS.lSmartTrim  = .T. 
      lcTxt = AllTrimX( m.lcTxt) && see L7Utils.PRG
    ENDIF
    IF NOT ISNULL(THIS.cReplaceCRLF) 
      lcTxt = STRTRAN(m.lcTxt, CHR(13) + CHR(10), THIS.cReplaceCRLF)
    ENDIF
    THIS.vNewValue = m.lcTxt
    RETURN 
  ENDFUNC  && AfterReadInput
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    * TextArea::GetOutput
    THIS.lOutputCreated = .T.
    THIS.SetValueIfNeeded()
    IF THIS.lDisabled
      LOCAL lcDisabledText
      IF NOT EMPTY(THIS.cDisabledTransformationUDF)
        lcDisabledText = EVALUATE(THIS.cDisabledTransformationUDF + [(THIS.vNewValue)])
      ELSE
        lcDisabledText = THIS.vNewValue
      ENDIF
      * NOTE: Following used to wrap with <span>, but that's illegal since <p>'s etc.,
      * are not allowed inside a <span>:
      RETURN [<div] + ;
        IIF( EMPTY( THIS.cReadOnlyDataCssClass), [], ;
          [ class="] + THIS.cReadOnlyDataCssClass + ["]) + ;
        [>] + ;
        m.lcDisabledText + [</div>]
    ENDIF
    IF THIS.lHidden
      RETURN THIS.GetHiddenOutput()  && see below--special textarea handling
    ENDIF
    LOCAL lcText
    lcText = ""
    * NOTE: "nRows" has an access method (above).
    lcText = m.lcText + [<textarea name="] + THIS.cHtmlName + ["] + ;
      [ id="] + THIS.GetID() + ["] + ;
      IIF( EMPTY( THIS.cOnClick), [], [ onclick="] + THIS.cOnClick + ["]) + ;
      IIF( EMPTY( THIS.cOnChange), [], [ onchange="] + THIS.cOnChange + ["]) + ;
      IIF( EMPTY( THIS.cOnBlur), [], [ onblur="] + THIS.cOnBlur + ["]) + ;
      IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
      IIF( EMPTY( THIS.cControlCssStyle), [], [ style="] + THIS.cControlCssStyle + ["]) + ;
      [ rows="] + LTRIM( STR( THIS.nRows)) + ["] + ;
      IIF( EMPTY( THIS.nCols), [], [ cols="] + LTRIM( STR( THIS.nCols)) + ["]) + ;
      IIF( EMPTY( THIS.cWidth), [], [ width="] + THIS.cWidth + ["]) + ;
      IIF( EMPTY( THIS.cWrap), [], [ wrap="] + THIS.cWrap + ["]) + ;
      [>] + ;
      THIS.EncodeValue() + ; 
      [</textarea>]

    RETURN m.lcText 
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION GetHiddenOutput
    THIS.lOutputCreated = .T.
    THIS.SetValueIfNeeded()
    LOCAL lcTxt
    * [Note: By using CSS "display: none" we include the full formatted text
    * in a <textarea> so formatting is not lost. Note that an INPUT
    * with TYPE of HIDDEN does not allow this. We also toss in small
    * values for ROWS and COLS, so that non-CSS browsers will at least
    * not waste tons of space on this "hidden" control.]
    lcTxt = [<] + [textarea style="display: none;"] + ;
      [ name="] + THIS.cHtmlName + [" rows="1" cols="20">] + ;
      THIS.EncodeValue() + ;
      [</] + [textarea>] + CR
    IF THIS.lShowOnForm
      * Convert memo-type text ofr HTML read-only display:
      lcTxt = m.lcTxt + HTMemo(THIS.vNewValue) + CR
      IF NOT EMPTY( THIS.cReadOnlyDataCssClass)
        lcTxt = [<span class="] + THIS.cReadOnlyDataCssClass + [">] + ;
          m.lcTxt + [</span>]
      ENDIF
    ENDIF
    RETURN m.lcTxt
  ENDFUNC  && GetHiddenOutput
  * ------------------------------------------------------------------- *
  FUNCTION EncodeValue
    LOCAL lcTxt
    lcTxt = STRTRAN(THIS.vNewValue, "&", AMPERSAND_ENCODED) && testing 07/20/2004
    IF "textarea" $ LOWER(m.lcTxt)  && trouble!
      LOCAL loRE
      loRE = CREATEOBJECT(L7_REGEXP_CLASS)
      WITH loRE
        .pattern = "<[/]*textarea"
        .global = .t.
        .ignorecase = .T.
        .multiline=.t.
        lcTxt = .replace(m.lcTxt, "&lt;textarea")
      ENDWITH 
    ENDIF
    RETURN m.lcTxt
  ENDFUNC && EncodeValue
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    RETURN NOT ( ALLTRIM( THIS.vNewValue) == ALLTRIM( THIS.vOldValue) )
  ENDFUNC
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7TextArea

***           RECORD OF REVISION          ***
* ===========================================
* 12/16/2001
*  - Moved L7Control class to L7BaseControl.PRG.
*  - Moved L7MultiControl (and decendants) to L7MultiControls.PRG.

* 10/31/1999
*  - Changed L7Hidden to be based on L7Textbox, so it could
*    also house numeric parameters and use cDisplayValue property.
#if .f.
03/20/2003 - reworked L7Checkbox to support radio-button option for logicals
04/22/2003 - textarea wrap= attribute is now omitted if cWrap=""
08/30/2003 - textarea.GetOutput() revised to wrap disabled text in <div> vs. <span>
10/22/2003 - revised L7Divider class to remove <span> tag wrapping
10/28/2003 - revised L7Checkbox to support false-before-true order option
11/16/2003 - revised L7Divider to handle NULL labels as well as empty
08/05/2004 - added cStripChars support to Textbox (also recently added to FileUpload)
10/26/2004 - file.SaveAs(), consideration for no filename added
08/09/2005 - added cValidChars and cInvalidChars to text box
           - inserted RETURN statements throughout
02/06/2006 - added protection against CRLF characters being pasted by browsers
#endif

* FILE END: L7Controls.PRG
