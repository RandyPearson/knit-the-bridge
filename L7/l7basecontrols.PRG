* Set this to .T. to see if they've fixed the variable '   ' is not found bug:
#DEFINE TESTING_VFP_CONCATENATION_BUG .F.
* Some test code for this bug is in L7Container_Examples.PRG. Lauren has
* production forms that trigger this bug too.


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



* L7BaseControls.PRG
*
* Base Classes for Cycla Html-based Controls 
*
* CLASS Hierarchy (classes in *this* PRG unless noted):
*
*   CLASS L7BaseControl
*   -- CLASS L7ContainerControl
*      -- L7Form (in L7Form.PRG)
*      -- L7Grid (in L7Grid.PRG)
*   -- CLASS L7CollectionControl
*      -- CLASS L7Toolbar
*   -- CLASS L7Control
*      -- L7Textbox, L7Checkbox, etc. (in L7Controls.PRG)
*      -- L7MultiControl (and decendants) (in L7MultiControls.PRG)
*
* Collateral classes:
*   -- L7FormRender (L7FormRender.PRG)
*   -- L7Iterator (L7Iterator.PRG, used by L7Grid)

#INCLUDE L7.H
***           RECORD OF REVISION          ***
* ===========================================
* 11/30/2001
*  - Begin major refactoring intended to support:
*     o New class hierarchy.       
*     o Nested containership.       
*     o Flexible rendering.       
*     o Various other concepts.

* 10/05/2000
*  - Fix problem where lValueSet would never be flagged for items with no 
*    control source.

* 10/21/1999
*  - Revised order of INIT paramters to controls (label first) to 
*    help prevent situation where bypassing the value to send the label
*    would be interpreted as passing a .F., thus making the control believe
*    its value had already been set and not using the control source.

* ==================================================================== *
DEFINE CLASS L7BaseControl AS CONTAINER  && does this need to be "CUSTOM"???
  * From this will be derived the container hierarchy and the simple
  * control hierarchy.
  Form                 = NULL

  * Properties:
  cHTMLName            = ""
  * 12/01/2009 - revise to make NULL the default behavior so "" can explicitly mean "no prefix"
  * 03/31/2011 - encountered issue w/ this decision if controls are in the wild--the NULL created type mis-match errors
  ** cIDPrefix            = "" && handed down from form/containers
  cIDPrefix            = NULL
  
  cIDSuffix            = "" && used in grids for row IDs
  cID                  = "" && see cID_ACCESS method.
  nTimesRendered       = 0  && for ID control when items rendered more than once
  
  nPropCount           = L7_BASECONTROL_PROPCOUNT     && some subclasses may need more
  lContainer           = .F.
  lForm                = .F.
  lSpanColumns         = .F.  && layout indication to renderer (for titles, toolbars, etc)
  lAutoReadInput       = .T.  && indicates postback should be read
  lAutoRender          = .T.  && is control rendered directly (vs served by proxy)?
  lHasContent          = .F.  && affected whether form's lUpdated flag should be triggered
  cDefaultPattern      = [%c%w]
  cPattern             = NULL && see access method
  cWrapperTag          = NULL
  cWrapperTagID        = ""  && provides ability to manipulate styles with getElementById();
  
  cPreText             = ""  && appears before *everything* (supports expression--see access method)
  cPostText            = ""  && appears after *everything* (supports expression--see access method)
  cPreControlText      = ""  && just before actual HTML control (supports expression--see access method)
  cPostControlText     = ""  && just after actual HTML control (supports expression--see access method)
  
  lVisible             = .T.
  lDisabled            = .F. 
  cDisabledExpression  = ""  && eval'd once in SetupObjects loop
  
  *!*    lEnabled             = .F.  && see ACCESS method (checks Visible&&Disabled)
  lInputRead           = .F.
  lUpdated             = .F.
  lHidden              = .F.
  lShowOnForm          = .F.  && set to TRUE to show hidden control's values on form

  *** CSS Properties:
  cCssStyle             = ""                        && allows override of CLASS with STYLE props
  * CSS classes affecting entire "block":
  cCssClass             = "FormControl"             && Class for DIV or other container. 
  cDisabledCssClass     = "FormControlDisabled"     && Class to use when disabled.
  cRequiredCssClass     = "FormControlRequired"     && Class to use when a required field.
  cInvalidCssClass      = "FormControlInvalid"      && Class to use when entry is invalid.
  cDynamicCssClass      = "" && See cDynamicCssClass_ACCESS Method!

  * CSS Classes affecting pieces of the block:
  cValidationCssClass   = "FormControlValidation"    && Class for validation error text.
  cLabelCssClass        = "FormControlLabel"         && Class for SPAN of label text.
  cLabelCssStyle        = ""                         && Style for SPAN of label text.
  cRequiredNoteCssClass = "FormControlRequiredNote"  && Class for note indicating 'required' status (different from cRequiredCssClass above).
  cInstructionsCssClass = "FormControlInstructions"  && Class for detailed instructions.
  cControlCssClass      = ""                         && Class for specific control, such as INPUT tag.
  cControlCssStyle      = ""
  cReadOnlyDataCssClass = "FormReadOnlyData"         && Class for data value when control is read-only (disabled, etc)

  * CSS override options when control used in grids:
  cColumnHeaderCssClass = ""
  cColumnHeaderCssStyle = ""
  cHeaders              = ""   && used in grids in conjunction with <th id="xxx">

  cRenderClass         = ""    && optional override (partial bridge) 
  cLabel               = NULL
  cInstructions        = ""
  lNoLabel             = .F.
  lAllowLabelBreaks    = .T.   && word-wrap labels if needed
  lAppendColonToLabel  = .T.   && auto-add a ":" to the label
  lMultiPart           = .F.
  lMultiRow            = .F.
  
  cInstructions        = ""
  cToolTipText         = ""

  cControlSourceType           = ""  && Form will set to "Record" or "Object"
  lDetermineActualNumericSizes = .T. && {04/04/2002} Had been .F. before.

  * Control grouping properties:
  *   (these can optionally be supported in a renderer as an easier
  *   technique for horizontal arrangement than using containership for grouping)
  * Note: All renderers may not support these properties.
  cGroupID          = ""   && set several (consecutive) elements to same ID to group them
  cGroupLabel       = ""   && option for first control in group
  lFirstInGroup     = .F.  && [DEPRECATED--use cGroupId] indicates that subsequent controls go in same row
  lShowWithPrevious = .F.  && [DEPRECATED--use cGroupId] keep on same row as previous (previous must have lFirstIngroup = .T.)

  * Validation:
  nInvalidCount        = 0    && form-level validation problems
  cValidationMessage   = ""
  lRequired            = .F.

  * JavaScript Handling:
  oJavaScriptManager   = NULL
  lJavaScriptCollected = .F.
  cJavaScript          = ""
  
  * ACCESS/ASSIGN Methods:
  * ------------------------------------------------------------------- *
  FUNCTION cPreText_ACCESS
    IF THIS.cPreText = "="
      RETURN EVAL(SUBSTR(THIS.cPreText,2))  && treat as expression
    ELSE
      RETURN THIS.cPreText  && treat as literal (could also be empty)
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION cPostText_ACCESS
    IF THIS.cPostText = "="
      RETURN EVAL(SUBSTR(THIS.cPostText,2))  && treat as expression
    ELSE
      RETURN THIS.cPostText  && treat as literal (could also be empty)
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION cPreControlText_ACCESS
    IF THIS.cPreControlText = "="
      RETURN EVAL(SUBSTR(THIS.cPreControlText,2))  && treat as expression
    ELSE
      RETURN THIS.cPreControlText  && treat as literal (could also be empty)
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION cPostControlText_ACCESS
    IF THIS.cPostControlText = "="
      RETURN EVAL(SUBSTR(THIS.cPostControlText,2))  && treat as expression
    ELSE
      RETURN THIS.cPostControlText  && treat as literal (could also be empty)
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION Form_ACCESS
    LOCAL loObj
    loObj = THIS
    DO WHILE VARTYPE(loObj.Parent) = "O"
      loObj = loObj.Parent && climb the hierarchy
      IF loObj.lForm
        RETURN m.loObj
      ENDIF
    ENDDO
    ERROR "Control not contained in form."    
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION cPattern_ACCESS
    IF ISNULL(THIS.cPattern)
      RETURN THIS.cDefaultPattern
    ELSE
      RETURN THIS.cPattern
    ENDIF
  ENDFUNC && cPattern_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION cDynamicCssClass_ACCESS
    * Special property (implemented as access method) allowing
    * controls to dynamically adjust their CSS class according 
    * to their state. 
    *
    * This property is intended to be used in custom "renderer"
    * classes. Simply refer to: control.cDynamicCssClass. In your 
    * application, set the subservient CSS properties and let this
    * property work for you automatically.
    *
    * Note how some states can be avoided by not specifying a CSS class. 
    * For example, if disabled controls should have same look as 
    * regular ones, simply set cDisabledCssClass to "".
    
    IF NOT EMPTY(THIS.cDynamicCssClass)
      * If specified directly, just return it.
      RETURN THIS.cDynamicCssClass
    ENDIF
    LOCAL lcTxt
    * Start with default:
    lcTxt = THIS.cCssClass
    DO CASE
    CASE THIS.lDisabled AND NOT EMPTY( THIS.cDisabledCssClass )
      lcTxt = THIS.cDisabledCssClass
    CASE THIS.nInvalidCount > 0 AND NOT EMPTY( THIS.cInvalidCssClass )
      lcTxt = THIS.cInvalidCssClass
    CASE THIS.lRequired AND NOT EMPTY( THIS.cRequiredCssClass )
      lcTxt = THIS.cRequiredCssClass
    ENDCASE
    RETURN m.lcTxt
  ENDFUNC  && cDynamicCssClass_ACCESS
  * ------------------------------------------------------------------- *
  function cHtmlName_ACCESS
    * Default HTML form name to VFP object name, if empty:
    * 03/31/2011 - encountered issue w/ controls in the wild--the NULL created type mis-match errors
    *   added nvl() guards.
    return nvl(this.cIDPrefix, "") + ;
      iif(empty(this.cHtmlName), this.Name, this.cHtmlName ) + ;
      nvl(this.cIDSuffix, "") 
  endfunc  && cHtmlName_ACCESS
  * ------------------------------------------------------------------- *
  *!*    FUNCTION cID_ACCESS
  *!*      IF EMPTY( THIS.cID)
  *!*        THIS.cID = THIS.cHtmlName
  *!*      ENDIF
  *!*      RETURN THIS.cID
  *!*    ENDFUNC  && cID_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION GetID
    * Provides uniqueness when items rendered more than once.
    LOCAL lcID
    * If no ID, use Name attribute:
    lcID = IIF(EMPTY(THIS.cID), THIS.cHtmlName, THIS.cID)
    * Provide uniqueness for multiply-rendered items (like toolbar controls):
    IF THIS.nTimesRendered > 0
      lcID = m.lcId + "__" + TRANSFORM(THIS.nTimesRendered)
    ENDIF
    RETURN m.lcID
  ENDFUNC
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION lEnabled_ACCESS
  *!*      RETURN THIS.lVisible AND NOT THIS.lDisabled
  *!*    ENDFUNC  && lEnabled_ACCESS
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION lEnabled_ASSIGN( llEnabled)
  *!*      THIS.lDisabled = NOT m.llEnabled
  *!*    ENDFUNC  && lEnabled_ASSIGN
  * --------------------------------------------------------- *
  FUNCTION cLabel_ACCESS
    * "Access" method that defaults Label name to Html name. 
    IF ISNULL( THIS.cLabel)
      RETURN ""
    ENDIF
    IF EMPTY( THIS.cLabel )
      LOCAL lcTxt, lnAt
      lcTxt = THIS.cHtmlName
      lnAt = RAT( "_", m.lcTxt)
      IF m.lnAt > 0
        lcTxt = SUBSTR( m.lcTxt, m.lnAt + 1)
      ENDIF
      RETURN PROPER( m.lcTxt)
    ENDIF
    RETURN THIS.cLabel
  ENDFUNC  && cLabel_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION lMultiPart_ACCESS
    * Overridden in container subclasses. Needed here to allow
    * DODEFAULT() checks.
    RETURN THIS.lMultiPart
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION lMultiPart_ASSIGN( llMulti)
    * Overridden in container subclasses. Needed here to allow
    * DODEFAULT() checks, etc.
    THIS.lMultiPart = m.llMulti
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetDisabledFlag  && called during SetupObjects()
    IF NOT EMPTY(THIS.cDisabledExpression)
      THIS.lDisabled = EVALUATE(THIS.cDisabledExpression)
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION INIT
    * WARNING: If your subclass or instance class has an INIT
    * method, it *must* call DODEFAULT()!!
    *
    #IF L7_FORM_DEBUG_OBJECTS
    DEBUGOUT THIS.Name + " created."
    #ENDIF
  ENDFUNC  && INIT
  * ------------------------------------------------------------------- *
  FUNCTION DESTROY
    THIS.GarbageCollect()
    #IF L7_FORM_DEBUG_OBJECTS
    DEBUGOUT THIS.Name + " destroyed."
    #ENDIF
  ENDFUNC  && DESTROY
  * ------------------------------------------------------------------- *
  FUNCTION GarbageCollect
    LOCAL loControl
    FOR EACH loControl IN This.Controls
      IF PEMSTATUS( m.loControl, "GarbageCollect", 5)
        loControl.GarbageCollect()
      ENDIF
    ENDFOR
    * Clear any non-contained object references:
    THIS.oJavaScriptManager = NULL
    
    * If a subclass includes any object pointers, do this:
    * DODEFAULT()
    * THIS.oPointer1 = NULL
    * THIS.oPointer2 = NULL
    * etc.
  ENDFUNC   && GarbageCollect
  * ------------------------------------------------------------------- *
  PROCEDURE RELEASE
    THIS.GarbageCollect()
    RELEASE THIS
  ENDFUNC  && RELEASE
  * ------------------------------------------------------------------- *
  FUNCTION BeforePrepareObjects  && hook
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION AfterPrepareObjects  && hook
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetMultiRowMode(lnRows)
    THIS.lMultiRow = .T.  && signals flyweight mode
    * MAX(1,) in following assures the property is added, even if 
    * no items are yet in existence:
    THIS.AddProperty( 'aPropValues(' + TRANSFORM(MAX(1,m.lnRows)) + ;
      ',' + TRANSFORM(THIS.nPropCount) + ')')
  ENDFUNC
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION SelfBind
  *!*      BINDEVENT(THIS, "lDisabled",          THIS, "PropertyChanger")
  *!*      BINDEVENT(THIS, "nInvalidCount",      THIS, "PropertyChanger")
  *!*      BINDEVENT(THIS, "cValidationMessage", THIS, "PropertyChanger")
  *!*      BINDEVENT(THIS, "lVisible",           THIS, "PropertyChanger")
  *!*    ENDFUNC
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION PropertyChanger
  *!*      LOCAL aa[3]
  *!*      AEVENTS(aa, 0)
  *!*      *!*      WAIT WINDOW aa[2] + " changed to " + TRANSFORM(EVALUATE("THIS." + aa[2]))
  *!*      *!*      DO CASE
  *!*      *!*      CASE aa[2] = "VNEWVALUE"
  *!*      *!*        THIS.aPropValues( THIS.Parent.nActiveRow, L7_CONTROLPROP_NEWVALUE) = THIS.vNewValue
  *!*      *!*      OTHERWISE
  *!*      *!*        WAIT WINDOW aa[2] + " cannot be changed."
  *!*      *!*      ENDCASE
  *!*    ENDFUNC
  * ------------------------------------------------------------------- *
  *!*  #DEFINE L7_CONTROLPROP_OLDVALUE          1
  *!*  #DEFINE L7_CONTROLPROP_NEWVALUE          2
  *!*  #DEFINE L7_CONTROLPROP_DISABLED          3
  *!*  #DEFINE L7_CONTROLPROP_UPDATED           4
  *!*  #DEFINE L7_CONTROLPROP_INVALIDCOUNT      5
  *!*  #DEFINE L7_CONTROLPROP_VALIDATIONMESSAGE 6
  *!*  #DEFINE L7_CONTROLPROP_DISPLAYVALUE      7
  *!*  #DEFINE L7_CONTROLPROP_VISIBLE           8
  *!*  #DEFINE L7_CONTROLPROP_FIRSTITEM         9
  * ------------------------------------------------------------------- *
  FUNCTION StoreProperties(lnRow, llFirstCall)
    ** THIS.aPropValues( m.lnRow, L7_CONTROLPROP_OLDVALUE) = THIS.vOldValue
    ** THIS.aPropValues( m.lnRow, L7_CONTROLPROP_NEWVALUE) = THIS.vNewValue
    ** THIS.aPropValues( m.lnRow, L7_CONTROLPROP_UPDATED) = THIS.lUpdated
    THIS.aPropValues( m.lnRow, L7_CONTROLPROP_INVALIDCOUNT) = THIS.nInvalidCount
    THIS.aPropValues( m.lnRow, L7_CONTROLPROP_VALIDATIONMESSAGE) = THIS.cValidationMessage
    ** THIS.aPropValues( m.lnRow, L7_CONTROLPROP_DISPLAYVALUE) = THIS.cDisplayValue
    
    IF m.llFirstCall && these props cannot change during input processing
      THIS.aPropValues( m.lnRow, L7_CONTROLPROP_DISABLED) = THIS.lDisabled
      THIS.aPropValues( m.lnRow, L7_CONTROLPROP_VISIBLE) = THIS.lVisible
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION LoadProperties(lnRow)
    ** THIS.vOldValue          = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_OLDVALUE)
    ** THIS.vNewValue          = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_NEWVALUE)
    THIS.lDisabled          = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_DISABLED)
    ** THIS.lUpdated           = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_UPDATED)
    THIS.nInvalidCount      = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_INVALIDCOUNT)
    THIS.cValidationMessage = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_VALIDATIONMESSAGE) 
    ** THIS.cDisplayValue      = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_DISPLAYVALUE) 
    THIS.lVisible           = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_VISIBLE) 
  ENDFUNC
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION SetMultiRowMode(lnRows)
  *!*      THIS.lMultiRow = .T.  && signals flyweight mode
  *!*    ENDFUNC
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION StoreProperties(lnRow)
  *!*    ENDFUNC
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION LoadProperties(lnRow)
  *!*    ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION Render(lcPattern)
    * Renders control w/artifacts based on pattern passed (or default pattern).
    *
    * IMPORTANT NOTE: The difference between calling Render() and 
    * RenderArtifacts() directly is that the former also invokes both the
    * BeforeRender/AfterRender hooks *and* the automatic JavaScript collection
    * for the control *and* attaches any text specified in cPreText/cPostText.
    *
    * It is HIGHLY RECOMMENDED that each control have the Render() method called exactly 
    * once (when the root control gets rendered), with any special layout needs 
    * implemented by additional calls to RenderArtifacts() as needed.
    * 
    * For example, to render the "label" in a separate table cell from the
    * remainder of the control artifacts, you could call RenderArtifacts(%l),
    * separately for the label, and then call Render() for everything else
    * (using a pattern that omits repeating the label).
    
    * Don't override this method, unless you *really* know what
    * you're doing. Instead, overide either the individual
    * methods called by RenderArtifacts() below.

    * lcPattern : allows passing of layout sequence by renderer object
    
    * Do this first so no lower controls render their own JS:
    THIS.CollectJavaScript()
    
    LOCAL lcTxt
    IF NOT EMPTY(THIS.cRenderClass)  
      * This control has a custom renderer - you're on your own! (Hint: don't call back to here <s>.)
      LOCAL loObj
      loObj = THIS.GetRenderObject()
      lcTxt = loObj.Render(THIS)
    ELSE
      * template method
      lcTxt = THIS.cPreText
      IF THIS.BeforeRender(@lcTxt) 
        IF EMPTY(m.lcPattern)
          lcPattern = THIS.GetPattern()
        ENDIF
        lcTxt = m.lcTxt + THIS.RenderArtifacts(m.lcPattern) 

*!*          IF NOT EMPTY(m.lcPattern)
*!*            lcTxt = m.lcTxt + THIS.RenderArtifacts(m.lcPattern) 
*!*          ELSE  && no pattern specified -- use default:
*!*            lcTxt = m.lcTxt + THIS.RenderArtifacts(THIS.cPattern) 
*!*          ENDIF
        THIS.AfterRender(@lcTxt)
      ENDIF
      lcTxt = m.lcTxt + THIS.cPostText && [[[is this expensive?]]]
    ENDIF
    * Irrespective of any clever renderers, we need to attach any
    * required JS to the end:
    lcTxt = m.lcTxt + THIS.RenderJavaScript()
    * We add JS to the end, so that any object ID already exists by the
    * time the script is run. [[Verify this always makes sense!]]
    RETURN m.lcTxt
  ENDFUNC  && L7BaseControl::Render
  * ------------------------------------------------------------------- *
  FUNCTION GetPattern
    IF ISNULL(THIS.cPattern)
      RETURN THIS.cDefaultPattern
    ELSE
      RETURN THIS.cPattern
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION RenderArtifacts(lcPat)
    * Create ad-hoc combination of control artifacts as
    * indicated in a pattern. Artifacts can include (pattern
    * directives in parentheses):
    *
    * a) the control iteslf (%c)
    * b) the label, including accessibility factors (%l)
    * c) validation errors (%v)
    * d) additional instructions (%i)
    * e) enclose class/style/tooltip in wrapper tag (%w) -- exact
    *    tag as specified in cWrapperTag property (span, div, or td)
    *
    * Other pattern features:
    * 
    * f) %b : conditional break <br> based on adjacent content not
    *    being empty; example is %i%b, which adds a break 
    *    only if "additional instructions" string is not empty; to break
    *    based on content to the right, nest in parens, such as %l(%b%i).
    * g) %s : same as above with non-breaking space
    * h) () cause recursive call to provide high flexibility for %b and %s.
    *
    * SEE IMPORTANT NOTE in Render method (above) concerning difference
    * between calling Render() and RenderArtifacts()!
    *
    
    LOCAL lcOutputString
    LOCAL lnLen, lnPtr, lcChr, lcNext, lcPrev
    LOCAL lnPtr2, lnStack, llStartCBR, llStartCSP, llWrap, lcTemp
    
    lcOutputString = ""
    
    IF ISNULL(m.lcPat)
      ERROR "Null pattern passed to artifact renderer."
    ENDIF
    lnLen = LEN(m.lcPat)
    lnPtr = 1
    lcPrev = ""
    * Iterate through the string, either appending character to an
    * output string, or performing the indicated replacement.
    DO WHILE m.lnPtr <= m.lnLen
      IF m.lnPtr > 1
        lcPrev = m.lcChr  && look behind
      ENDIF 
      lcChr = SUBSTR(m.lcPat,m.lnPtr,1)
      DO CASE
      CASE m.lcChr = "%" AND NOT m.lcPrev $ '0123456789'  && beginning of a processing instruction
        lcNext = SUBSTR(m.lcPat,m.lnPtr + 1,1)
        DO CASE
        CASE m.lcNext = "l"  && label
          lcOutputString = m.lcOutputString + THIS.RenderLabel()
          lnPtr = m.lnPtr + 2
        CASE m.lcNext = "c"  && control
          #IF TESTING_VFP_CONCATENATION_BUG
          lcOutputString = m.lcOutputString + THIS.RenderControl()
          #ELSE  && known-to-work version
          lcTemp = THIS.RenderControl()
          lcOutputString = m.lcOutputString + m.lcTemp
          #ENDIF

          *!*            TRY 
          *!*              lcOutputString = m.lcOutputString + THIS.RenderControl()
          *!*            CATCH TO loExc
          *!*              LOCAL laErr[1]
          *!*              AERROR(laErr)
          *!*              SUSPEND
          *!*            ENDTRY
          
          lnPtr = m.lnPtr + 2
        CASE m.lcNext = "v"  && validation
          lcOutputString = m.lcOutputString + THIS.RenderValidation()
          lnPtr = m.lnPtr + 2
        CASE m.lcNext = "i"  && instructions
          lcOutputString = m.lcOutputString + THIS.RenderInstructions()
          lnPtr = m.lnPtr + 2
        CASE m.lcNext = "b"  && conditional <br>
          IF m.lnPtr = 1
            llStartCBR = .T.
            lnPtr = m.lnPtr + 2
          ELSE
            IF NOT EMPTY(m.lcOutputString)
              lcOutputString = m.lcOutputString + L7BR 
            ENDIF
            lnPtr = m.lnPtr + 2
          ENDIF
        CASE m.lcNext = "s"  && conditional space
          IF m.lnPtr = 1
            llStartCSP = .T.  && set flag for later
            lnPtr = m.lnPtr + 2
          ELSE && conditional on left text
            IF NOT EMPTY(m.lcOutputString)
              lcOutputString = m.lcOutputString + [&nbsp;]
            ENDIF
            lnPtr = m.lnPtr + 2
          ENDIF
        CASE m.lcNext = "w"  && wrap with tag
          llWrap = .T.
          lnPtr = m.lnPtr + 2
        CASE m.lcNext = "%"  && escaped literal "%"
          lcOutputString = m.lcOutputString + '%'
          lnPtr = m.lnPtr + 2
        OTHERWISE
          ERROR "Unknown substitution in render pattern."
        ENDCASE
        LOOP
      CASE m.lcChr = "("  && indicates nested pattern to be called recursively
        * Need to find matching close ")", knowing that nesting is possible:
        lnStack = 1
        FOR lnPtr2 = m.lnPtr + 1 TO m.lnLen
          lcNext = SUBSTR(m.lcPat,m.lnPtr2,1)
          DO CASE
          CASE m.lcNext = ")"
            lnStack = m.lnStack - 1 
            IF m.lnStack = 0
              * Found matching ")". Make recursive call:
              lcTemp = THIS.RenderArtifacts(SUBSTR(m.lcPat,m.lnPtr+1,m.lnPtr2-m.lnPtr-1))
              lcOutputString = m.lcOutputString + m.lcTemp
              lnPtr = m.lnPtr2 + 1
              EXIT
            ENDIF
          CASE m.lcNext = "(" && Nested deeper.
            lnStack = m.lnStack + 1
          ENDCASE
        ENDFOR  && lnPtr2
        IF m.lnStack > 0
          ERROR "Mismatched parentheses in render pattern."
        ELSE
          LOOP
        ENDIF
      ENDCASE
      lcOutputString = m.lcOutputString + m.lcChr
      lnPtr = m.lnPtr + 1
    ENDDO
    * Finally, check whether we've flagged the need for opening 
    * break or space, or to wrap content:
    IF m.llStartCBR AND NOT EMPTY(m.lcOutputString)
      lcOutputString = L7BR + m.lcOutputString
    ENDIF
    IF m.llStartCSP AND NOT EMPTY(m.lcOutputString)
      lcOutputString = "&nbsp;" + m.lcOutputString
    ENDIF
    IF m.llWrap
      THIS.ApplyWrapperTag(@lcOutputString)
    ENDIF
    RETURN m.lcOutputString
  ENDFUNC && RenderArtifacts
  * ------------------------------------------------------------------- *
  FUNCTION RenderControl
    * Template Method -- DO NOT Override
    LOCAL lcText
    lcText = THIS.cPreControlText
    lcText = m.lcText + THIS.GetOutput()  && this is what gets subclassed
    RETURN m.lcText + THIS.cPostControlText
  ENDFUNC  && RenderControl
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    THIS.lOutputCreated = .T.
    ERROR ["GetOutput" method must be implemented in a subclass.]
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION GetRenderObject
    * Factory Method pattern.
    LOCAL loRender
    loRender = CREATEOBJECT( THIS.cRenderClass )
    RETURN m.loRender
  ENDFUNC  && GetRenderObject
  * ------------------------------------------------------------------- *
  FUNCTION BeforeRender(lcTxt) && pass by reference
    * Hook. Return .F. to block call to Render().
  ENDFUNC  && L7BaseControl::BeforeRender
  * ------------------------------------------------------------------- *
  FUNCTION AfterRender(lcTxt) && pass by reference
    * Hook.
  ENDFUNC  && L7BaseControl::AfterRender
  * ------------------------------------------------------------------- *
  FUNCTION RenderLabel(llNoLabelTag)
    LOCAL lcTxt
    WITH THIS
      IF .lNoLabel 
        lcTxt = ""
      ELSE
        lcTxt = .cLabel
        IF NOT EMPTY( m.lcTxt)
          IF .lAppendColonToLabel
            lcTxt = m.lcTxt + [:]
          ENDIF
          IF NOT .lAllowLabelBreaks
            lcTxt = [<nobr>] + m.lcTxt + [</nobr>]
          ENDIF
        ENDIF
      ENDIF
      IF NOT EMPTY(m.lcTxt) 
        IF NOT m.llNoLabelTag
          lcTxt = [<label for="] + .GetId() + [">] + m.lcTxt + [</label>]
        ENDIF
        lcTxt = [<span] + ;
          IIF(EMPTY(.cLabelCssClass), [], [ class="] + .cLabelCssClass + ["]) + ;
          IIF(EMPTY(.cLabelCssStyle), [], [ style="] + .cLabelCssStyle + ["]) + ;
          [>] + m.lcTxt + [</span>] + CRLF
      ENDIF
      lcTxt = m.lcTxt
    ENDWITH
    RETURN m.lcTxt
  ENDFUNC  && RenderLabel
  * ------------------------------------------------------------------- *
  FUNCTION RenderInstructions
    LOCAL lcTxt, lcCls
    IF THIS.lDisabled  && 7/25/2006 - revised to remove instructions for disabled controls
      lcTxt = ""
    ELSE
      lcTxt = THIS.cInstructions
      IF NOT EMPTY( m.lcTxt)
        lcCls = THIS.cInstructionsCssClass
        IF NOT EMPTY( m.lcCls)
          lcTxt = [<span class="] + m.lcCls + [">] + m.lcTxt + [</span>]
        ENDIF
      ENDIF
    ENDIF 
    RETURN m.lcTxt
  ENDFUNC  && RenderInstructions
  * ------------------------------------------------------------------- *
  FUNCTION RenderValidation
    LOCAL lcTxt, lcCls
    lcTxt = THIS.cValidationMessage
    IF NOT EMPTY( m.lcTxt)
      lcCls = THIS.cValidationCssClass
      IF NOT EMPTY( m.lcCls)
        lcTxt = [<span class="] + m.lcCls + [">] + m.lcTxt + [</span>]
      ENDIF
    ENDIF
    RETURN m.lcTxt
  ENDFUNC  && RenderValidation
  * ------------------------------------------------------------------- *
  FUNCTION ApplyWrapperTag(lcTxt)
    * NOTE: lcTxt is passed by *reference*!
    IF ISNULL(THIS.cWrapperTag) OR EMPTY(THIS.cWrapperTag)
      RETURN
    ENDIF
    LOCAL lcDiv, lcStyle, lcClass
    lcClass = THIS.cDynamicCssClass
    lcStyle = THIS.cCssStyle
    * Outer DIV/SPAN tag with optional tooltip:
    lcDiv = [<] + THIS.cWrapperTag + ;
      IIF(EMPTY(THIS.cWrapperTagID), [], [ id="] + THIS.cWrapperTagID + ["]) + ;
      IIF(EMPTY(m.lcClass), [], [ class="] + m.lcClass + ["]) + ;
      IIF(EMPTY(m.lcStyle), [], [ style="] + m.lcStyle + ["]) + ;
      IIF(EMPTY(THIS.cToolTipText), [], CR + [ title="] + THIS.cToolTipText + ["]) + ;
      [>] 
    lcTxt = m.lcDiv + m.lcTxt + [</] + THIS.cWrapperTag + [>] + CRLF
  ENDFUNC  && ApplyWrapperTag
  * ------------------------------------------------------------------- *
  FUNCTION AddValidationMessage(lcMessage)
    THIS.nInvalidCount = THIS.nInvalidCount + 1
    THIS.cValidationMessage = THIS.cValidationMessage + ;
      m.lcMessage + L7BR + CR
  ENDFUNC  && AddValidationMessage
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * L7BaseControl::ReadInput()
    THIS.AfterReadInput()
    THIS.lInputRead = .T.
    THIS.lUpdated = THIS.WasChanged() && protected method
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION AfterReadInput
  ENDFUNC  && AfterReadInput
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    RETURN .F.  && override in specific control subclasses
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION UpdateControlSources
    ERROR [Method "UpdateControlSources" must be overridden in subclass.]
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION RenderJavaScript
    LOCAL lcTxt
    lcTxt = ""
    IF THIS.lJavaScriptCollected
      * A higher-level container has already collected our JS.
      lcTxt = ""
    ELSE
      THIS.CollectJavaScript()  && ensure we honor any contained needs
      IF VARTYPE( THIS.oJavaScriptManager) = "O"
        lcTxt = THIS.oJavaScriptManager.GetJavaScript()
      ELSE
        lcTxt = ""
      ENDIF
    ENDIF
    RETURN m.lcTxt
  ENDFUNC  && RenderJavaScript
  * --------------------------------------------------------- *
  FUNCTION AddJavaScript(lcCode, lcUrl, lcVersion)
    IF VARTYPE( THIS.oJavaScriptManager) <> "O"
      THIS.oJavaScriptManager = CREATEOBJECT( "L7JavaScriptManager")
    ENDIF
    THIS.oJavaScriptManager.AddJavaScript( lcCode, lcUrl, lcVersion )
  ENDFUNC  && AddJavaScript
  * ------------------------------------------------------------------- *
  FUNCTION CollectJavaScript
    *!*      * Set flag so we don't also render JS at this level:
    *!*      THIS.lJavaScriptCollected = .T.
    * (Above was wrong. We only want to set child flags.)
    
    LOCAL loObj, loControl
    FOR EACH loControl IN THIS.Controls
      IF VARTYPE(loControl.lJavaScriptCollected) = "L" AND ;
        NOT loControl.lJavaScriptCollected 
        *
        loObj = loControl.CollectJavaScript()
        loControl.lJavaScriptCollected = .T.
      
        IF VARTYPE( loObj) = "O"
          IF VARTYPE( THIS.oJavaScriptManager) <> "O"
            THIS.oJavaScriptManager = CREATEOBJECT( "L7JavaScriptManager")
          ENDIF
          THIS.oJavaScriptManager.Merge( m.loObj)
          loObj = NULL
        ENDIF
      ENDIF
    ENDFOR
    * 07/05/2002: Added cJavaScript property support for
    *   ease of form class definition.
    IF NOT EMPTY(THIS.cJavaScript)  && direct script specified in property
      IF VARTYPE( THIS.oJavaScriptManager) <> "O"
        THIS.oJavaScriptManager = CREATEOBJECT( "L7JavaScriptManager")
      ENDIF
      THIS.oJavaScriptManager.AddJavaScript(THIS.cJavaScript)
    ENDIF
    
    RETURN THIS.oJavaScriptManager  && NULL if no JS
  ENDFUNC  && CollectJavaScript
  * --------------------------------------------------------- *
ENDDEFINE  && Class L7BaseControl

* ==================================================================== *
DEFINE CLASS L7Control AS L7BaseControl

  cDefaultPattern = [(%l%b)(%i%b)%c(%b%v)%w]

  lContainer    = .F.
  cHtmlName     = ""

  cWrapperTag   = "div" && experimental!! -- container can alter via SetAll()
  
  *!*    *** CSS Classes:
  *!*    * CSS classes affecting entire "block":
  *!*    cCssClass             = "FormControl"             && Class for DIV or other container. 
  *!*    cDisabledCssClass     = "FormControlDisabled"     && Class to use when disabled.
  *!*    cRequiredCssClass     = "FormControlRequired"     && Class to use when a required field.
  *!*    cInvalidCssClass      = "FormControlInvalid"      && Class to use when entry is invalid.
  *!*    cDynamicCssClass      = "" && See cDynamicCssClass_ACCESS Method!

  * CSS Classes affecting pieces of the block:
  cValidationCssClass   = "FormControlValidation"    && Class for validation error text.
  cLabelCssClass        = "FormControlLabel"         && Class for label text.
  cRequiredNoteCssClass = "FormControlRequiredNote"  && Class for note indicating 'required' status (different from cRequiredCssClass above).
  cInstructionsCssClass = "FormControlInstructions"  && Class for detailed instructions.
  cControlCssClass      = ""                         && Class for specific control, such as INPUT tag.
  cReadOnlyDataCssClass = "FormReadOnlyData"         && Class for data value when control is read-only (disabled, etc)
  
  cExtraTags    = ""
  cBgColor      = ""   && deprecated in favor of CSS

  * Properties from higher in class hierarchy:
  *
  cLabel          = ""  && defaults to control's cHtmlName
  * lNoLabel      = .F.
  lAppendColonToLabel = .T.  && auto-add a ":" to the label
  * lMultiPart        = .F.

  * JavaScript events:
  cOnChange      = ""   && support expressions - see access method
  cOnClick       = ""   && support expressions - see access method
  cOnBlur        = ""   && support expressions - see access method

  cFieldType     = "C"  && "D", "N", "L", "T"
  vOldValue      = []
  vNewValue      = []
  cControlSource = []

  lSpanColumns   = .F.  && layout indication to renderer (for titles, toolbars, etc)
  lAutoReadInput = .T.  && indicates postback should be read
  lAutoRender    = .T.  && is control rendered directly (vs served by proxy)?
  lHasContent    = .T.  && affects whether form's lUpdated flag should be triggered
  
  ** lToolbarControl   = .F. && see lAutoRender

  cShowExpression   = NULL  && alternative to show when disabled/hidden
  cDisplayValue     = NULL  && character representation--handled by ACCESS method

  lOutputCreated    = .F.  && indicates if GetOutput was called
  lValueSet         = .F.

  * ------------------------------------------------------------------- *
  FUNCTION cOnChange_ACCESS
    IF THIS.cOnChange = "="
      RETURN EVAL(SUBSTR(THIS.cOnChange,2))  && treat as expression
    ELSE
      RETURN THIS.cOnChange  && treat as literal (could also be empty)
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION cOnClick_ACCESS
    IF THIS.cOnClick = "="
      RETURN EVAL(SUBSTR(THIS.cOnClick,2))  && treat as expression
    ELSE
      RETURN THIS.cOnClick  && treat as literal (could also be empty)
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION cOnBlur_ACCESS
    IF THIS.cOnBlur = "="
      RETURN EVAL(SUBSTR(THIS.cOnBlur,2))  && treat as expression
    ELSE
      RETURN THIS.cOnBlur  && treat as literal (could also be empty)
    ENDIF
  ENDFUNC
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
  FUNCTION INIT
    * L7Control::INIT
    IF NOT EMPTY( THIS.cControlSource)
      * Control Source specified in form class constructor code.
      THIS.DetermineTypeFromControlSource()
      * Note: above method is also called from cControlSource_ASSIGN. This supports 
      * 2 models, instance design (.AddObject) and class design (ADD OBJECT).
    ENDIF
    RETURN DODEFAULT()
  ENDFUNC  && INIT
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION SelfBind
  *!*      DODEFAULT()
  *!*      BINDEVENT(THIS, "vNewValue",     THIS, "PropertyChanger")
  *!*      BINDEVENT(THIS, "vOldValue",     THIS, "PropertyChanger")
  *!*      BINDEVENT(THIS, "lUpdated",      THIS, "PropertyChanger")
  *!*      BINDEVENT(THIS, "cDisplayValue", THIS, "PropertyChanger")
  *!*    ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION StoreProperties(lnRow, llFirstCall)
    DODEFAULT(m.lnRow, m.llFirstCall)
    THIS.aPropValues( m.lnRow, L7_CONTROLPROP_OLDVALUE) = THIS.vOldValue
    THIS.aPropValues( m.lnRow, L7_CONTROLPROP_NEWVALUE) = THIS.vNewValue
    ** THIS.aPropValues( m.lnRow, L7_CONTROLPROP_DISABLED) = THIS.lDisabled
    THIS.aPropValues( m.lnRow, L7_CONTROLPROP_UPDATED) = THIS.lUpdated
    ** THIS.aPropValues( m.lnRow, L7_CONTROLPROP_INVALIDCOUNT) = THIS.nInvalidCount
    ** THIS.aPropValues( m.lnRow, L7_CONTROLPROP_VALIDATIONMESSAGE) = THIS.cValidationMessage
    THIS.aPropValues( m.lnRow, L7_CONTROLPROP_DISPLAYVALUE) = THIS.cDisplayValue
    ** THIS.aPropValues( m.lnRow, L7_CONTROLPROP_VISIBLE) = THIS.lVisible
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION LoadProperties(lnRow)
    DODEFAULT(m.lnRow)
    THIS.vOldValue          = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_OLDVALUE)
    THIS.vNewValue          = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_NEWVALUE)
    ** THIS.lDisabled          = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_DISABLED)
    THIS.lUpdated           = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_UPDATED)
    ** THIS.nInvalidCount      = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_INVALIDCOUNT)
    ** THIS.cValidationMessage = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_VALIDATIONMESSAGE) 
    THIS.cDisplayValue      = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_DISPLAYVALUE) 
    ** THIS.lVisible           = THIS.aPropValues( m.lnRow, L7_CONTROLPROP_VISIBLE) 
  ENDFUNC
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
  *!*      *[[ Need type conversion here in subclasses!

  *!*      THIS.vNewValue = m.lxValue
  *!*      *[[ Should we call SetValue() method instead???
  *!*    ENDFUNC && XMLInput
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION XMLOutput
  *!*      IF NOT THIS.lVisible OR NOT THIS.lAutoReadInput
  *!*        RETURN []
  *!*      ENDIF
  *!*      LOCAL lcName
  *!*      lcName = THIS.cHtmlName
  *!*      RETURN [<] + m.lcName + [>] + TRANS( THIS.vNewValue ) + ;
  *!*        [</] + m.lcName + [>]
  *!*    ENDFUNC && XMLOutput
  * ------------------------------------------------------------------- *
  FUNCTION Valid
    IF THIS.lRequired AND EMPTY( THIS.vNewValue )
      THIS.AddValidationMessage(  ;
        IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
        ' must not be left blank.')
    ENDIF
    RETURN ( THIS.nInvalidCount = 0 )
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
  FUNCTION cControlSource_ASSIGN(lcSource)
    STORE m.lcSource TO THIS.cControlSource
    THIS.DetermineTypeFromControlSource()
    * Note: above method is also called from INIT(). This supports 2
    * models, instance design (.AddObject) and class design (ADD OBJECT).
  ENDFUNC  && cControlSource_ASSIGN
  * ------------------------------------------------------------------- *
  FUNCTION SetControlSource(lcSource)
    STORE m.lcSource TO THIS.cControlSource
    *[[ Experimental: Attempt to update field type, if different, ;
    *[[ so we get numerics handled.
    * Following should not be needed, since the above STORE command
    * triggers the cControlSource_ASSIGN method, which in turn 
    * calls DetermineTypeFromControlSource:
    * = THIS.DetermineTypeFromControlSource()
  ENDFUNC  && SetControlSource
  * ------------------------------------------------------------------- *
  FUNCTION DetermineTypeFromControlSource
    * Called from INIT and SetControlSource, and cControlSource_ASSIGN
    LOCAL lcType
    lcType = TYPE( THIS.cControlSource)
    IF m.lcType # "U" AND m.lcType # THIS.cFieldType
      THIS.cFieldType = m.lcType
    ENDIF
  ENDFUNC && DetermineTypeFromControlSource
  * ------------------------------------------------------------------- *
  FUNCTION SetValueIfNeeded
    * Should be called before either ReadInput or GetOutput
    * to confirm value has been populated from cControlSource
    * if needed.
    IF NOT THIS.lValueSet
      IF NOT EMPTY( THIS.cControlSource)
        * [04/29/2002] Added next line:
        * [07/07/2003] Moved same inside 2nd IF, so only applies when there is a source:
        THIS.cDisplayValue = NULL  && clear out any old setting (needed for grids)
        THIS.SetValue( EVAL( THIS.cControlSource ) )
      ELSE
        * [[11/17/2000: Added ELSE portion here.]]
        IF THIS.cFieldType # "C" 
          * There is no control source but the field type is non-character,
          * so change value properties to match.
          DO CASE
          CASE THIS.cFieldType $ "NI"
            THIS.SetValue( 0)
          CASE THIS.cFieldType $ "D"
            THIS.SetValue( {//})
          CASE THIS.cFieldType $ "T"
            THIS.SetValue( {//::})
          ENDCASE
        ENDIF
      ENDIF
    ENDIF
  ENDFUNC  && SetValueIfNeeded
  * ------------------------------------------------------------------- *
  FUNCTION SetValue(lvValue, lvNewValue)
    * Set values equal before reading input. We'll use the new value
    * to paint the form, and compare to old value to see what has changed:
    IF PCOUNT() >= 2 AND ;
      VARTYPE( m.lvValue ) = VARTYPE( m.lvNewValue )
      * Allows seeding the new value as different from the old value, 
      * such as when adding records, and you have an initial form
      * value that is different from the control source.
      STORE m.lvValue    TO THIS.vOldValue
      STORE m.lvNewValue TO THIS.vNewValue
    ELSE
      STORE m.lvValue TO THIS.vNewValue, THIS.vOldValue
    ENDIF
    THIS.lValueSet = .T.
    * NOTE: Additional behavior exists in subclasses, such
    *  as setting TEXTBOX size from value/type information.
  ENDFUNC  && L7Control::SetValue
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * L7Control::ReadInput()
    THIS.SetValueIfNeeded()
    IF THIS.lMultiPart = .F.
      THIS.vNewValue = ALLTRIM( Request.Form( THIS.cHtmlName ))
    ELSE
      THIS.vNewValue = ALLTRIM( Request.GetMultiPartFormVar( THIS.cHtmlName ))
    ENDIF
    THIS.AfterReadInput()
    THIS.lInputRead = .T.
    THIS.lUpdated = THIS.WasChanged()
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    RETURN NOT ( THIS.vNewValue = THIS.vOldValue )
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION UpdateControlSources
    IF NOT THIS.lVisible OR NOT THIS.lAutoReadInput OR ;
      (THIS.lDisabled AND NOT THIS.WasChanged())
      * [final combo above contemplates an edit that would make item subsequently disabled]
      RETURN
    ENDIF
    LOCAL lcSource, lvOldVal, lcType, llChanged, loExc, llFail, lcExcMessage
    lcSource = THIS.cControlSource
    IF NOT EMPTY( m.lcSource )

      * {Historical Note} We can't call this only if m.ii.WasChanged() 
      *   is TRUE, because if the form is seeded with a *default* value, and it 
      *   isn't edited, the value never gets saved!!
      
      IF THIS.cControlSourceType = "Object" && source is a data object
        *[[ LC Had to use & here in stead of () for collection-based control sources
        STORE THIS.vNewValue TO &lcSource 
        ** STORE THIS.vNewValue TO ( m.lcSource )

      ELSE  && control source is a table/view
      
        * {02/02/2002} Updated to avoid a REPLACE if value is 
        *   unchanged, so that in buffered views we don't trigger
        *   GETFLDSTATE() needlessly.
        
        lvOldVal = EVALUATE( m.lcSource )
        lcType = VARTYPE( m.lvOldVal)
        IF m.lcType = "C"
          * llChanged = NOT ( TRIM( m.lvOldVal) == THIS.vNewValue )
          * 10/28/2004:
          llChanged = NOT ( TRIM( m.lvOldVal) == TRIM( THIS.vNewValue ))
        ELSE
          llChanged = NOT ( m.lvOldVal = THIS.vNewValue )
        ENDIF
        
        IF m.llChanged
          * {Caution!} If writing direct to local tables (no buffering)
          *   you better RLOCK() before attempting this update!
          
          *!*            lnAt = AT( ".", m.lcSource )
          *!*            IF m.lnAt > 0  && alias.field
          *!*              lcAlias = LEFT( m.lcSource, m.lnAt - 1 )
          *!*              lcField = SUBSTR( m.lcSource, m.lnAt + 1 )
          *!*              REPLACE ( m.lcField ) WITH THIS.vNewValue IN ( m.lcAlias )
          *!*            ELSE  && assume/hope alias is selected
          *!*              REPLACE ( m.lcSource ) WITH THIS.vNewValue
          *!*            ENDIF  && lnAt > 0
          
          lnAt = AT( ".", m.lcSource )
          IF m.lnAt > 0  && alias.field
            lcAlias = LEFT( m.lcSource, m.lnAt - 1 )
            lcField = SUBSTR( m.lcSource, m.lnAt + 1 )
          ELSE  && assume/hope alias is selected
            lcAlias = ALIAS()
            lcField = m.lcSource
          ENDIF  && lnAt > 0
          llFail = .F.
          TRY
            REPLACE ( m.lcField ) WITH THIS.vNewValue IN ( m.lcAlias )
          CATCH TO loExc
            llFail = .T.
          ENDTRY 
          IF m.llFail
            TRY 
              TEXT TO lcExcMessage NOSHOW PRETEXT 7
                Error <<loExc.ErrorNo>>, <<loExc.Message>>, in line <<loExc.LineNo>> of <<loExc.Procedure>> while 
                attempting save [<<THIS.vNewValue>>] to <b><<m.lcSource>></b>.
              ENDTEXT
              lcExcMessage = TEXTMERGE(m.lcExcMessage)
              lcExcMessage = CHRTRAN(m.lcExcMessage, CRLF, SPACE(2))
            CATCH TO loExc
              lcExcMessage = "Error while trying to report data-save error: " + loExc.Message
            ENDTRY
            ERROR m.lcExcMessage 
          ENDIF 

        ENDIF
      ENDIF  && type = "Object"
    ENDIF  && EMPTY( source )
    RETURN 
  ENDFUNC  && UpdateControlSources
  * ------------------------------------------------------------------- *
  FUNCTION GetExtendedOutput  && DEPRECATED! (use Render with a pattern)
    * Enables displaying validation messages along with control in one
    * function call.
    LOCAL lcText
    lcText = ""
    IF THIS.nInvalidCount > 0
      lcText = m.lcText + [<font color="red">] + ;
        THIS.cValidationMessage + [</font>]+ L7BR 
    ENDIF
    lcText = m.lcText + THIS.GetOutput()
    RETURN m.lcText
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION GetHiddenOutput
    THIS.lOutputCreated = .T.
    LOCAL lcTxt
    THIS.SetValueIfNeeded()
    lcTxt = [<input type="hidden" name="] + THIS.cHtmlName + ["] + ;
      [ value="] + TRIM( THIS.cDisplayValue) + ["] + ;
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
ENDDEFINE  && L7Control

* ==================================================================== *
DEFINE CLASS L7ControlProxy AS L7_CONTROL_CLASS
  * Proxy to locate another control. Used when a control doesn't
  * know how to self-orient, is not to be rendered in the order
  * created, or is to be rendered more than once. Driving Use Case
  * is for Toolbars.

  cPattern       = [%c]  && We want nothing but the control (the underlying control will feed its artifacts)
  cControl       = NULL
  lAutoReadInput = .F.
  lAutoRender    = .T.
  lValueSet      = .T.
  * ------------------------------------------------------------------- *
  FUNCTION lSpanColumns_ACCESS
    RETURN EVALUATE("THIS.Parent." + THIS.cControl + ".lSpanColumns")
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION cDefaultPattern_ASSIGN(lcPat)
    STORE m.lcPat TO ("THIS.Parent." + THIS.cControl + ".cDefaultPattern")
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION cWrapperTag_ASSIGN(lcTag)
    STORE m.lcTag TO ("THIS.Parent." + THIS.cControl + ".cWrapperTag")
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    THIS.lOutputCreated = .T.
    LOCAL loControl, lcOutput
    loControl = EVALUATE("THIS.Parent." + THIS.cControl)
    lcOutput = loControl.Render()
    RETURN m.lcOutput
  ENDFUNC
ENDDEFINE  && L7ControlProxy

* ==================================================================== *
DEFINE CLASS L7ContainerControl AS L7BaseControl
  * NOTE: "Container" controls are very different from Collection controls.
  *
  * This is classic VFP containership. Primary subclasses are:
  *
  *  - L7Form (the form itself)
  *  - L7Grid (a most complex class)
  *
  * Properties:
  cDefaultPattern = [(%l%b)%c]  && (label w/cond <br>) plus control itself
  lContainer      = .T.
  cLabelCssClass  = "FormControlLabel"
  
  cWrapperTag     = "div" && experimental!! -- container can alter via SetAll()
  * These next 3 allow for crude defaults for RAD purposes:
  cPreText          = [<table class="FormContainer"><tr><td>]
  cPostText         = [</td></tr></table>]
  cInterControlText = [</td><td>]

  lHasContent       = .T.  && affected whether form's lUpdated flag should be triggered
                           && change this in subclass if no input occurs inside container

  lInvalidControls  = .F.  && flag for at least one invalid control entry
  * ------------------------------------------------------------------- *
  FUNCTION cIDPrefix_ASSIGN( lcPrefix)
    * Cascade the ID attribute to avoid any conflicts. Thus a textbox
    * in a container of a form gets something like:
    * ID="MyForm_ContainerA_Textbox1", even though you only named it
    * "Textbox1". This is good when you have multiple containers, or
    * multiple forms on one page!

    THIS.cIDPrefix = m.lcPrefix
    LOCAL loControl, lcNewPrefix
    lcNewPrefix = THIS.GetID() + "_"
    FOR EACH loControl IN THIS.Controls
      if isnull(loControl.cIDPrefix) && if not null, has been assigned explicitly
        loControl.cIDPrefix = m.lcNewPrefix
      endif 
    endfor
    return 
  ENDFUNC  && cIDPrefix_ASSIGN( lcPrefix)
  * ------------------------------------------------------------------- *
  FUNCTION lMultiPart_ACCESS
    * Determine if the entire form should be multi-part by cascading
    * a check down the containership for any control with that need.
    LOCAL llRet, loObj
    llRet = THIS.lMultiPart
    IF NOT m.llRet
      FOR EACH loObj IN THIS.Controls
        IF NOT loObj.lVisible OR loObj.lDisabled OR NOT loObj.lAutoReadInput
          LOOP  && n/a
        ENDIF
        IF loObj.lMultiPart
          llRet = .T.
          EXIT
        ENDIF
      ENDFOR
    ENDIF
    RETURN m.llRet
  ENDFUNC  && lMultiPart_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION BeforePrepareObjects
    FOR EACH loControl IN THIS.Controls
      loControl.BeforePrepareObjects()
    ENDFOR
    DODEFAULT()
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION AfterPrepareObjects
    FOR EACH loControl IN THIS.Controls
      loControl.AfterPrepareObjects()
    ENDFOR
    DODEFAULT()  &&[[ should this be first or second?
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetValueIfNeeded
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    *[[[ Q: Why the separate method vs. just putting that
    *    code here?
    RETURN THIS.RenderNestedControls()
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION RenderNestedControls
    LOCAL lcTxt, ii, loObj, lcTemp
    lcTxt = THIS.cPreText
    FOR ii = 1 TO THIS.CONTROLCOUNT
      loObj = THIS.CONTROLS[m.ii]
      IF loObj.lVisible = .F.
        LOOP
      ENDIF
      * Flow down the Disabled flag:
      IF THIS.lDisabled
        loObj.lDisabled = .T. && SetAll() not used so nested containers have more control.
      ENDIF
      loObj.cWrapperTag = "span"  && don't want blocks!
      **[VFP Bug: lcTxt = m.lcTxt + loObj.Render()

      #IF TESTING_VFP_CONCATENATION_BUG
      lcTxt = m.lcTxt + loObj.Render()
      #ELSE
      lcTemp = loObj.Render()
      lcTxt = m.lcTxt + m.lcTemp + CRLF
      #ENDIF
      
      IF m.ii < THIS.CONTROLCOUNT
        lcTxt = m.lcTxt + THIS.cInterControlText 
      ENDIF
    ENDFOR
    lcTxt = m.lcTxt + THIS.cPostText
    RETURN ( m.lcTxt)
  ENDFUNC  && L7Container::RenderNestedControl
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * L7Container::ReadInput()
    LOCAL loObj
    FOR EACH loObj IN THIS.CONTROLS
      IF loObj.lDisabled OR NOT loObj.lVisible 
        LOOP
      ENDIF
      loObj.ReadInput()
      IF loObj.lUpdated
        THIS.lUpdated = .T.
      ENDIF
    ENDFOR
    THIS.AfterReadInput()
    THIS.lInputRead = .T.
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION Valid
    LOCAL llObjectsValid, ii
    llObjectsValid = .T.
    FOR EACH ii IN THIS.Controls
      IF m.ii.lDisabled OR NOT m.ii.lVisible
        LOOP
      ENDIF
      * Potential trap here. If control's Valid() triggers any problems
      * via AddValidationMessage, but still RETURN's .T., this statement
      * would not detect it:
      *!* IF NOT m.ii.Valid()
      * So, it seems we should use:
      IF NOT m.ii.Valid() OR m.ii.nInvalidCount > 0
        llObjectsValid = .F.
        THIS.lInvalidControls = .T.
      ENDIF
    ENDFOR
    THIS.AfterValidateControls()  && hook
    RETURN m.llObjectsValid AND ( THIS.nInvalidCount = 0 )
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
  FUNCTION GetValidationMessages
    * NOTE: Unlike collection control, container does not accumulate
    * its member messages during validation. 
    LOCAL ii, lcMcg
    lcMsg = ""
    
    for each ii in THIS.Controls
      IF m.ii.lDisabled OR NOT m.ii.lVisible
        LOOP
      ENDIF

      IF m.ii.nInvalidCount > 0
        lcMsg = m.lcMsg + m.ii.cValidationMessage
      endif
    next ii
    return m.lcMsg
  endfunc && GetValidationMessages
  * ------------------------------------------------------------------- *
  FUNCTION AfterValidateControls
    * intended for container instances to perform extra
    * validation after each control has been validated
  ENDFUNC  && AfterValidateControls
  * ------------------------------------------------------------------- *
  FUNCTION UpdateControlSources
    LOCAL loObj, llRetVal
    llRetVal = .T.
    FOR EACH loObj IN THIS.Controls
      IF NOT m.loObj.lVisible OR m.loObj.lDisabled 
        LOOP
      ENDIF
      * Delegate to the control:
      IF NOT m.loObj.UpdateControlSources()
        llRetVal = .F.
        EXIT
      ENDIF
    ENDFOR  && EACH control
    RETURN m.llRetVal
  ENDFUNC  && UpdateControlSources
  * ------------------------------------------------------------------- *
ENDDEFINE  && Class L7ContainerControl

* ==================================================================== *
DEFINE CLASS L7CollectionControl AS L7BaseControl
  * NOTE: "Collection" controls are very different from Container controls.
  *
  * A collection control provides a way to collect several immediate form
  * members for the purposes of rendering together. Classic example is a 
  * toolbar. The controls are unrelated from the collection for input
  * and validation purposes. Typically the collection is not rendered itself
  * but instead uses one or more proxy controls. This allows the same collection
  * to be rendered more than once, such as a toolbar that needs to appear
  * at the top and the bottom of a lengthy form.
  
  ** cDefaultPattern = [%c%w]  && just the control with wrapper
  cDefaultPattern = [(%l%b)(%i%b)%c(%b%v)%w]
  cWrapperTag = [div]

  cCssClass             = "FormControl"             && Class for DIV or other container. 

  * Pattern to apply to all hosted controls as their default:
  cDefaultControlPattern = NULL  
  
  DIMENSION aItems[ 1]
  nItems = 0

  lInvalidControls  = .F.  && flag for at least one invalid control entry
  
  cTag              = "div"                 && ("span" and "td" are alternatives)
  cTagCssClass      = "FormContainer"    && 
  
  cInterControlText = CHR(38) + 'nbsp;'       && &nbsp
  
  lAutoRender    = .F.
  lAutoReadInput = .F.
  lValueSet      = .F.
  * --------------------------------------------------------- *
  FUNCTION AddObjectToParent(tcName, tcClass)
    * Adds a control to the form *and* records it as a member of
    * the collection. Convenience method for easy addition of controls.
    THIS.Parent.AddObject(m.tcName, m.tcClass)
    loObj = EVALUATE("THIS.Parent." + m.tcName)
    loObj.lAutoRender = .F.  && assume main purpose of collection is rendering
    THIS.AddItem(m.loObj, m.tcName)
    RETURN m.loObj
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetValueIfNeeded
  * ------------------------------------------------------------------- *
  FUNCTION UpdateControlSources
  * ------------------------------------------------------------------- *
  FUNCTION VALID()
    * Collect validation info to display at the "super-control" level:
    LOCAL lnK, loControl
    FOR lnK = 1 TO THIS.nItems
      loControl = THIS.aItems[m.lnK, 2]
      IF loControl.nInvalidCount > 0
        THIS.nInvalidCount = THIS.nInvalidCount + loControl.nInvalidCount
        *[[ Following line is unclear in value. Maybe better not to collect
        * the text, but to have RenderValidation() walk the members.
        * Inefficiency here when used in grids (flyweight chatter).
        THIS.cValidationMessage = THIS.cValidationMessage + loControl.cValidationMessage
      ENDIF
    ENDFOR
    * Any "combination of controls" stuff could go here...
    RETURN ( THIS.nInvalidCount = 0 )
  ENDFUNC  && VALID
  * ------------------------------------------------------------------- *
  FUNCTION DESTROY
    THIS.GarbageCollect()
  ENDFUNC  && DESTROY
  * ------------------------------------------------------------------- *
  FUNCTION GarbageCollect
    DODEFAULT()
    DIMENSION THIS.aItems[ 1]
    THIS.aItems[ 1] = NULL
    THIS.nItems = 0
  ENDFUNC  && GarbageCollect
  * ------------------------------------------------------------------- *
  FUNCTION AddItem( loObj, lcName, lcBeforeName, lcAfterName)
    * 11/30/2002
    *  - Reversed 1st and 2nd param for consistency with new Collection base class.
    *  - Removed class factory approach. Need to pass object.
    * 05/30/2002
    *  - Added support for inserting items via 4th parameter [11/30/2002: now 3rd parameter]
    LOCAL lnRow
    lnRow = 0
    IF NOT EMPTY(m.lcBeforeName) && try to insert it
      lnRow = ASCAN(THIS.aItems, m.lcBeforeName, -1, -1, 1, 15)
    ENDIF
    THIS.nItems = THIS.nItems + 1
    DIMENSION THIS.aItems[ THIS.nItems, 2]
    IF m.lnRow = 0  && either not inserted, or inserted name d.n.e.
      lnRow = THIS.nItems
    ELSE  && insert
      AINS(THIS.aItems,m.lnRow)
    ENDIF
    THIS.aItems[ m.lnRow, 1] = m.lcName
    THIS.aItems[ m.lnRow, 2] = m.loObj
    loObj.lAutoRender = .F. && Make sure control doesn't render again by itself.
    RETURN m.loObj  && send back an ObjRef
  ENDFUNC  && AddItem
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    LOCAL lcTxt, ii, loObj, lcTag, lcTmp
    lcTxt = ""
    lcTag = THIS.cTag
    IF NOT EMPTY( m.lcTag)
      lcTmp = [<] + m.lcTag + ;
        [ id="] + THIS.cId + ["] + ;
        IIF( EMPTY( THIS.cTagCssClass), [], [ class="] + THIS.cTagCssClass + ["]) + ;
        [>] + CHR(13) + CHR(10)
      lcTxt = m.lcTxt + m.lcTmp
    ENDIF
    FOR ii = 1 TO THIS.nItems
      loObj = THIS.aItems[ m.ii, 2] 
      IF NOT loObj.lVisible
        LOOP
      ENDIF
        * Pattern to apply to all contained controls as their default:
      IF NOT ISNULL(THIS.cDefaultControlPattern)
        loObj.cDefaultPattern = THIS.cDefaultControlPattern
      ENDIF
       
      lcTmp = loObj.Render() + CRLF
      lcTxt = m.lcTxt + m.lcTmp
      * Intersperse spacing characters, if applicable:
      IF m.ii < THIS.nItems AND NOT EMPTY(THIS.cInterControlText)
        lcTxt = m.lcTxt + THIS.cInterControlText
      ENDIF
      * Increment control's render count to allow for unique IDs
      * in cases where the toolbar appears more than once (top/bottom):
      loObj.nTimesRendered = THIS.nTimesRendered + 1
    ENDFOR
    IF NOT EMPTY( m.lcTag)
      lcTxt = m.lcTxt + [</] + m.lcTag + [>] + CRLF
    ENDIF
    RETURN m.lcTxt
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION CollectJavaScript
    DODEFAULT()
    * Now iterate the array:
    LOCAL loControl, loObj, ii
    FOR ii = 1 TO THIS.nItems
      loControl = THIS.aItems[ m.ii, 2]

      IF VARTYPE( loControl.lJavaScriptCollected ) = "L" AND ;
        NOT loControl.lJavaScriptCollected 
        *
        loObj = loControl.CollectJavaScript()
        loControl.lJavaScriptCollected = .T.
        IF VARTYPE( loObj) = "O"
          IF VARTYPE( THIS.oJavaScriptManager) <> "O"
            THIS.oJavaScriptManager = CREATEOBJECT( "L7JavaScriptManager")
          ENDIF
          THIS.oJavaScriptManager.Merge( m.loObj)
          loObj = NULL
        ENDIF
      ENDIF
    ENDFOR
    RETURN THIS.oJavaScriptManager  && NULL if no JS
  ENDFUNC  && CollectJavaScript
  * ------------------------------------------------------------------- *
ENDDEFINE  && Class L7CollectionControl

* ==================================================================== *
DEFINE CLASS L7Toolbar AS L7CollectionControl
  * (Temporary) properties used in rendering for now:
  cWrapperTag = "" && don't want outer DIV
  cTag = "div"                 && ("span" and "td" are alternatives)
  cTagCssClass = "FormToolbar"    && 
  cInterControlText = CHR(38) + 'nbsp;'       && &nbsp
  
  lAutoRender    = .F.
  lAutoReadInput = .F.
  lSpanColumns   = .T.
  * ------------------------------------------------------------------- *
  FUNCTION cControlSourceType_ASSIGN(lcType AS String) AS VOID
    * Toolbar isn't a true container, so we need to force
    * any setting down the chain.
    LOCAL ii, loObj
    FOR ii = 1 TO THIS.nItems
      loObj = THIS.aItems[ m.ii, 2] 
      IF NOT loObj.lVisible
        LOOP
      ENDIF
      loObj.SetAll("cControlSourceType", m.lcType)
    ENDFOR
  ENDFUNC  && cControlSourceType_ASSIGN
  * ------------------------------------------------------------------- *
  FUNCTION INIT
    DODEFAULT()
    THIS.AddDefaultControls()
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION AddDefaultControls
    THIS.BeforeDefaultControls()
    WITH THIS.Parent
      IF .lSubmitButton
        .AddObject('btnSubmit', "L7SubmitButton")
        WITH .btnSubmit
          .cHtmlName = "btnSubmit"
          .lVisible = .T.
          * 01/14/2005: added form-level submit caption:
          IF ISNULL(.vOldValue)
            .vOldValue = THIS.Parent.cSubmitCaption
          ENDIF
        ENDWITH
        THIS.AddItem(.btnSubmit, "btnSubmit")
      ENDIF
      IF .lPreviewButton
        .AddObject('btnPreview', "L7PreviewButton")
        WITH .btnPreview
          .cHtmlName = "btnPreview"
          .lVisible = .T.
        ENDWITH
        THIS.AddItem(.btnPreview, "btnPreview")
      ENDIF
      IF .lResetButton
        .AddObject('btnReset', "L7ResetButton")
        WITH .btnReset
          .cHtmlName = "btnReset"
          .lVisible = .T.
        ENDWITH
        THIS.AddItem( .btnReset, "btnReset")
      ENDIF
      IF .lCancelButton
        .AddObject('btnCancel', "L7CancelButton")
        WITH .btnCancel
          .cHtmlName = "btnCancel"
          .lVisible = NOT EMPTY(THIS.Parent.cCancelURL)
        ENDWITH
        THIS.AddItem(.btnCancel, "btnCancel")
      ENDIF
    ENDWITH
    THIS.AfterDefaultControls()
  ENDFUNC  && AddDefaultControls
  * ------------------------------------------------------------------- *
  FUNCTION BeforeDefaultControls
  ENDFUNC  && BeforeDefaultControls
  * ------------------------------------------------------------------- *
  FUNCTION AfterDefaultControls
  ENDFUNC  && AfterDefaultControls
  * ------------------------------------------------------------------- *
ENDDEFINE  && Class L7Toolbar

*** ===================================================== ***
define class L7CheckboxCollection AS L7CollectionControl  
  cDefaultControlPattern = "%c(%s%i)"
  cInterControlText = L7BR  && CHR(38) + 'nbsp;'       && &nbsp
  ** nStyle = L7_MULTISTYLE_VERTICAL
  lAutoRender = .T.
  nMinChecked = 0
  nMaxChecked = NULL && positive integer to enforce
  * --------------------------------------------------------- *
  function Valid
    * Collect validation info to display at the "super-control" level:
    local lnK, loControl, lnChecked
    lnChecked = 0
    for lnK = 1 TO THIS.nItems
      loControl = THIS.aItems[m.lnK, 2]
      if vartype(loControl.vNewValue) <> "L"
        loop  && not a checkbox! -- something else inserted for rendering purposes
      endif 
      if loControl.vNewValue = .T.
        lnChecked = m.lnChecked + 1 
      endif 
      if loControl.nInvalidCount > 0
        this.nInvalidCount = this.nInvalidCount + loControl.nInvalidCount
        *[[ Following line is unclear in value. Maybe better not to collect
        * the text, but to have RenderValidation() walk the members.
        * Inefficiency here when used in grids (flyweight chatter).
        this.cValidationMessage = this.cValidationMessage + loControl.cValidationMessage
      endif 
    next  
    if this.nMinChecked > m.lnChecked
      this.AddValidationMessage(textmerge("Must check at least <<THIS.nMinChecked>>."))
    endif 
    if !isnull(this.nMaxChecked) and this.nMaxChecked < m.lnChecked
      this.AddValidationMessage(textmerge("Cannot check more than <<THIS.nMaxChecked>>."))
    endif 
    * Any "combination of controls" stuff could go here...
    return (this.nInvalidCount = 0 )
  endfunc   
enddefine && L7CheckboxCollection 

#if .f.
05/06/2003 - added cPreText/cPostText properties and adjusted Render() to use.
05/07/2003 - RenderLabel: added flag to quash <label for> wrapper (used by grids)
           - renamed WrapTag to ApplyWrapperTag
05/11/2003 - added cPreControlText and cPostControlText and set RenderControl() to use
           - added ACCESS methods to all of the following controls, allowing for
             dynamic expressions via "=" character
               -- cPreText and cPostText
               -- cPreControlText and cPostControlText 
               -- cOnChange, cOnClick, cOnBlur
05/22/2003 - added prefix to L7ExtractElement
05/28/2003 - removed lEnabled pseudo-property (always use lDisabled!)
           - added support for lDisabled being an expression (char value starting with "=")
           - added lDisabled method
           - renamed flyweight methods to LoadProperties() and StoreProperties()
           - revised container not to use SetAll -- anticipating nested containers
07/07/2003 - fixed bug where cDisplayValue gets reset to NULL when there is no control source
09/03/2003 - fixed SetMultiRowMode to deal with zero-row condition
10/09/2003 - fixed Collection rendering so inter-control text isn't appended after last control
10/28/2004 - changed UpdateControlSource to TRIM() both sides and compare with ==
#endif

* EOF: L7BaseControls.PRG
