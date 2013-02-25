* L7MultiControls.PRG
*
* Classes for L7 multiple-choice Controls 
*
* CLASS Hierarchy (in *this* PRG unless noted):
*
*   CLASS L7BaseControl (in L7BaseControls.PRG)
*   -- CLASS L7Control (in L7BaseControls.PRG)
*      -- L7MultiControl 
*         -- CLASS L7Popup 
*         -- CLASS L7RadioButton 
*         -- CLASS L7MultiCheckbox 
*         -- CLASS L7MultiTextbox 

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
DEFINE CLASS L7MultiControl AS L7_CONTROL_CLASS
  cHtmlName         = ""
  cControlCssClass  = "FormMultiControl"
  nPropCount        = L7_BASECONTROL_PROPCOUNT + 1  && need to push/pop lFirstItemSelected

  vOldValue         = []
  vNewValue         = []

  vFirstItemValue    = NULL  && set to a char value to use
  cFirstItemLabel    = NULL
  PROTECTED lUseFirstItem
  lUseFirstItem      = .F.   && possibly should be PROTECTED - set by BuildList
  lFirstItemSelected = .T.

  cValueExpression = NULL && what VALUE= should be based on (defaults to FIELD(1))
  cLabelExpression = NULL && what the displayed text should be (defaults to FIELD(2))

  vLastItemValue    = NULL   && [Feature not yet implemented.]
  cLastItemLabel    = NULL   && [Feature not yet implemented.]
  
  nOptionLength     = NULL
  lEnforceLengths   = .F.   && .F. for anything-goes approach: good luck!
  lCoerceLengths    = .T.   && mangle strings vs raising errors, upon mismatched lengths
  
  nRowSourceType    = L7_ROWSOURCETYPE_NONE  && _VALUE, _ALIAS
  cRowSource        = ""
  cRowSourceValueProperty = ""  && used with some collections
  cRowSourceLabelProperty = ""  &&   - ditto -
  
  cFilterExpression = ""  && filter of which items apply
  lListBuilt        = .F.
  lCheckedSet       = .F.

  nOptions          = 0
  DIMENSION aOptions[1, 2]
  * Columns are: 1 - Option Value; 2 - Display Text (optional)

  nMode              = L7_MULTI_POPUP
  lMultiSelect       = .F.
  lCheckAllLinks     = .T. && JS for multiselect checkboxes
  
  nSelections        = 0
  DIMENSION aSelections[1]
  nOldSelections     = 0
  DIMENSION aOldSelections[1]
  * [NOTE: Values in selction arrays are indices, not data values!]

  nSize             = 1 && affects POPUP display vertical size

  * Style Info for Radio Buttons or Check Boxes:
  nItemsPerRow      = 5  && applies to formatted (and horizontal??) style
  nStyle            = L7_MULTISTYLE_VERTICAL  && better for accessibility
  * nStyle            = L7_MULTISTYLE_HORIZONTAL
  *nStyle            = L7_MULTISTYLE_FORMATTED

  cIntraOptionText  = ""   && (vertical needs blank) CHR(38) + "nbsp;"   && text to put between each option -- for special table formatting
  lNoLabels         = .F.  && allows [ ] and ( ) to appear in columns with a heading

  * ------------------------------------------------------------------- *
  FUNCTION cDisplayValue_ACCESS
    
    * NOTE: Review notes in L7Control::cDisplayValue_ACCESS(). There are
    *   some Grid considerations there we may need to consider.
    
    * Used for hidden/read-only items.
    LOCAL lcDivider
    lcDivider = L7BR
    LOCAL ii, lcRet, lnCount
    lnCount = 0
    lcRet = ""
    FOR ii = 1 TO THIS.nOptions
      IF THIS.lMultiSelect
        ** llSelected = THIS.aOptions[ m.ii, 4]
        llSelected = THIS.nSelections > 0 AND ;
          ASCAN(THIS.aSelections, THIS.aOptions[m.ii,1]) > 0
        * [NOTE: Values in selction arrays are indices, not data values!]
      ELSE  && single choice
        llSelected = THIS.vNewValue == THIS.aOptions[ m.ii, 1]
      ENDIF
      IF m.llSelected
        lcRet = m.lcRet + TRIM(TRANSFORM(THIS.aOptions[ m.ii, 2]))
        IF THIS.lMultiSelect
          lnCount = m.lnCount + 1 
          IF m.lnCount > 1
            lcRet = m.lcRet + m.lcDivider
          ENDIF
        ELSE
          EXIT
        ENDIF
      ENDIF
    ENDFOR
    RETURN m.lcRet
  ENDFUNC  && cDisplayValue_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION StoreProperties(lnRow, llFirstCall)
    DODEFAULT(m.lnRow, m.llFirstCall)
    THIS.aPropValues(m.lnRow, L7_CONTROLPROP_FIRSTITEM) = THIS.lFirstItemSelected
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION LoadProperties(lnRow)
    DODEFAULT(m.lnRow)
    THIS.lFirstItemSelected = THIS.aPropValues(m.lnRow, L7_CONTROLPROP_FIRSTITEM) 
  ENDFUNC

  * Following is no good in an AddObject() environment, as it burns someone
  * who specifes mode after multiselect. Make them specify
  * multiselect correctly to begin with.
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION nMode_ASSIGN(tnMode)
  *!*      * "Assign" method for nMode property.
  *!*      THIS.nMode = m.tnMode
  *!*      DO CASE
  *!*      CASE m.tnMode = L7_MULTI_POPUP
  *!*      CASE m.tnMode = L7_MULTI_RADIOBUTTON
  *!*        THIS.lMultiSelect = .F.
  *!*      CASE m.tnMode = L7_MULTI_CHECKBOX
  *!*        THIS.lMultiSelect = .T.
  *!*      CASE m.tnMode = L7_MULTI_TEXTBOX
  *!*        THIS.lMultiSelect = .F.
  *!*      OTHERWISE
  *!*        ** ???
  *!*      ENDCASE
  *!*    ENDFUNC  && nMode_ASSIGN
  * ------------------------------------------------------------------- *
  PROTECTED FUNCTION AddSelection(lnIndex, llOld, llNew)
    * Internal worker function. Trusting calling function
    * to use appropriately. No check for dups performed!
    IF m.llOld
      THIS.nOldSelections = THIS.nOldSelections + 1 
      DIMENSION THIS.aOldSelections[THIS.nOldSelections]
      THIS.aOldSelections[THIS.nOldSelections] = m.lnIndex
    ENDIF
    IF m.llNew
      THIS.nSelections = THIS.nSelections + 1 
      DIMENSION THIS.aSelections[THIS.nSelections]
      THIS.aSelections[THIS.nSelections] = m.lnIndex
    ENDIF
    * [NOTE: Values in selction arrays are indices, not data values!]
  ENDFUNC  && AddSelection
  * ------------------------------------------------------------------- *
  FUNCTION AddItem(tcValue, tcDisplayText, tlPreSelected)
    * Add item to multiple-choice selection array.
    * 2nd parm optional -- display defaults to first
    * 3rd parm optional flag to pre-select items in list

    * First, see if we're enforcing constant lengths:
    IF THIS.lEnforceLengths AND VARTYPE(m.tcValue) = "C"
      IF ISNULL(THIS.nOptionLength)
        * "Guess" that first item tells the story.
        THIS.nOptionLength = LEN(m.tcValue)
      ENDIF
      IF LEN(m.tcValue) <> THIS.nOptionLength
        IF THIS.lCoerceLengths
          tcValue = PADR(m.tcValue, THIS.nOptionLength) && if you need PADL, it's up to you
        ELSE
          ERROR "Option length mismatch: (" + m.tcValue + ", " + TRANSFORM(THIS.nOptionLength) + ")"
        ENDIF
      ENDIF
    ENDIF
      
    THIS.nOptions = THIS.nOptions + 1
    DIMENSION THIS.aOptions[ THIS.nOptions, 2]
    THIS.aOptions[ THIS.nOptions, 1] = m.tcValue
    THIS.aOptions[ THIS.nOptions, 2] = m.tcDisplayText
    
    IF m.tlPreSelected
      IF THIS.lMultiSelect
        THIS.AddSelection(THIS.nOptions, .T., .T.)
        * [NOTE: Values in selction arrays are indices, not data values!]
      ELSE && non multiselect
        THIS.SetValue( m.tcValue)
        * [[To Do: This won't work for child records in a grid,
        * [[  as SetValue does not persist.
      ENDIF
    ENDIF

    IF THIS.nOptions = 1 AND NOT THIS.lValueSet AND ;
      THIS.cFieldType = "C" AND ;
      VARTYPE( m.tcValue) # "C"
      * We haven't set a value or field type yet, and the item being added
      * hints of a non-character type.
      THIS.cFieldType = VARTYPE( m.tcValue)
    ENDIF
  ENDFUNC  && AddItem
  * ------------------------------------------------------------------- *
  FUNCTION RemoveItem(tcValue)
    * Remove item from multiple-choice selection array.
    IF THIS.lMultiSelect AND (THIS.nSelections > 0 OR THIS.nOldSelections > 0)
      ERROR "Cannot remove multi-select arrays items when selections already exist."
      * [THIS WOULD BE HARD TO IMPLEMENT, DUE TO INDEX COLLAPSING, ETC.]
    ENDIF
    LOCAL lnRow
    lnRow = ASCAN(THIS.aOptions,m.tcValue,-1,-1,1,14)
    IF m.lnRow > 0
      ADEL(THIS.aOptions, m.lnRow)
      THIS.nOptions = THIS.nOptions - 1 
      DIMENSION THIS.aOptions[ THIS.nOptions, 2]
    ENDIF
  ENDFUNC  && RemoveItem
  * ------------------------------------------------------------------- *
  FUNCTION PreSelectItem(lvValue)
    * Pre-checks items in multiple-choice selection array.
    * Call this after BuildList(). Useful for building lists from
    * an Alias and then pre-checking some items. Note that manually
    * built lists can specify pre-checks directly in the AddItem method.
    * This will be slow for longer lists with many preselected items!
    * See also: PreSelectFromArray().
    IF NOT THIS.lListBuilt
      * Not cool?? BuildList should have been called by something/someone already.
      THIS.BuildList()
    ENDIF
    LOCAL lnIndex
    lnIndex = ASCAN(THIS.aOptions,m.lvValue,-1,-1,1,14)
    IF m.lnIndex > 0
      THIS.AddSelection(m.lnIndex,.T.,.T.)
    ELSE
      ERROR [Invalid multiple-selection option: ] + TRANSFORM(m.lvValue) + [.] 
    ENDIF
  ENDFUNC  && PreSelectItem
  * ------------------------------------------------------------------- *
  FUNCTION PreSelectFromArray
    * Pre-checks items in a multiple-choice selection based on an array of selected values.
    * Call this after BuildList(). Useful for building lists from
    * an Alias and then pre-checking some items. Note that manually
    * built lists can specify pre-checks directly in the AddItem method.
    * This may be faster that individual PreSelectItem() calls 
    * for longer lists with many preselected items!
    LPARAMETERS laArray  && pass by reference!
    EXTERNAL ARRAY laArray
    LOCAL lnIndex, lvValue
    FOR EACH lvValue IN laArray
      lnIndex = ASCAN(THIS.aOptions,m.lvValue,-1,-1,1,14)
      IF m.lnIndex > 0
        THIS.AddSelection(m.lnIndex,.T.,.T.)
      ELSE
        ERROR [Invalid multiple-selection option: ] + TRANSFORM(m.lvValue) + [.] 
      ENDIF
    ENDFOR
  ENDFUNC  && PreSelectFromArray
  * ------------------------------------------------------------------- *
  FUNCTION GetSelectedItemList
    * Return list of selected values wrapped in commas.
    LOCAL lnIndex, lcList
    lcList = ","
    IF THIS.nSelections > 0
      FOR EACH lnIndex IN THIS.aSelections
        lcList = m.lcList + TRANS(THIS.aOptions[m.lnIndex, 1]) + ","
      ENDFOR
    ENDIF
    RETURN m.lcList
  ENDFUNC  && GetSelectedItemList
  * ------------------------------------------------------------------- *
  FUNCTION BuildList
    * Is the "first item" feature used?:
    THIS.lUseFirstItem = ;
      INLIST( THIS.nMode, L7_MULTI_POPUP, L7_MULTI_RADIOBUTTON ) AND ;
      NOT ISNULL( THIS.vFirstItemValue )

    * Controversial - reset list:
    IF THIS.nRowSourceType # L7_ROWSOURCETYPE_NONE
      * Only if we don't build list manually, however.
      THIS.nOptions = 0
    ENDIF

    LOCAL ii, nn, cc, ss, at1, at1, lnSelect, llScan
    lnSelect = SELECT()
    DO CASE
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_NONE
      * List was build manually--nothing more to do here.
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_VALUE
      * Comma delimited list.
      * (You may need to set .nOptionLength if you use this.)
      ss = "," + THIS.cRowSource + ","
      nn = OCCURS( ",", m.ss) - 1
      FOR ii = 1 TO m.nn
        at1 = AT( ",", m.ss, m.ii )
        at2 = AT( ",", m.ss, m.ii + 1 )
        ** {10/21/1999} removed ALLTRIM here:
        ** cc = ALLTRIM( SUBSTR( m.ss, m.at1 + 1, m.at2 - m.at1 - 1) )
        cc = SUBSTR( m.ss, m.at1 + 1, m.at2 - m.at1 - 1) 
        THIS.AddItem( m.cc, m.cc )
      ENDFOR
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_ALIAS
      LOCAL lcAlias
      IF EMPTY(THIS.cRowSource)
        IF EMPTY(ALIAS()) && try current work area
          ERROR "No alias specified for control: " + THIS.Name
        ELSE
          lcAlias = ALIAS()
          llScan = .T.
        ENDIF
      ELSE && row source specified
        IF "(" $ THIS.cRowSource && expression support
          lcAlias = EVALUATE(THIS.cRowSource)
        ELSE
          lcAlias = THIS.cRowSource
        ENDIF
        IF USED(m.lcAlias)
          SELECT (m.lcAlias)
          llScan = .T.
        ELSE
          ERROR "Alias " + m.lcAlias + " is not in use for control: " + THIS.Name
        ENDIF
      ENDIF
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_SQL
      IF EMPTY( THIS.cRowSource )
        ERROR "No row-source SQL specified for control: " + THIS.Name
      ELSE
        IF NOT [INTO CURSOR] $ UPPER( THIS.cRowSource )
          THIS.cRowSource = THIS.cRowSource + [ INTO CURSOR ] + "_Cursor_" + ALLTRIM( SYS(3))
        ENDIF
        ss = THIS.cRowSource
        &ss
        llScan = .T.
      ENDIF    
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_ARRAY
      THIS.BuildListFromArray()  && hookable
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_COLLECTION
      THIS.BuildListFromCollection()  && hookable
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_FIELDS     
      ERROR "Not implemented."
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_FILES      
      ERROR "Not implemented."
    CASE THIS.nRowSourceType = L7_ROWSOURCETYPE_STRUCTURE  
      ERROR "Not implemented."
    ENDCASE

    IF m.llScan 
      IF NOT EMPTY( THIS.cFilterExpression )
        ss = [FOR ] + THIS.cFilterExpression
      ELSE
        ss = []
      ENDIF
      LOCAL lcValueExpr, lcLabelExpr, llTwoParms
      * The key is based on FIELD(1) unless a proeprty was set:
      IF ISNULL( THIS.cValueExpression )
        lcValueExpr = FIELD(1)
      ELSE
        lcValueExpr = THIS.cValueExpression
      ENDIF
      DO CASE
      CASE NOT ISNULL( THIS.cLabelExpression )
        lcLabelExpr = THIS.cLabelExpression
        llTwoParms = .T.
      CASE FCOUNT() >= 2
        lcLabelExpr = FIELD(2)
        llTwoParms = .T.
      OTHERWISE
        * One field cursor, use field for both value and display.
      ENDCASE  
      SCAN &ss
        IF m.llTwoParms = .F.
          THIS.AddItem( EVAL( m.lcValueExpr ))
        ELSE
          THIS.AddItem( EVAL( m.lcValueExpr ), EVAL( m.lcLabelExpr ))
        ENDIF
      ENDSCAN
    ENDIF  && scan needed
    SELECT ( m.lnSelect )
    THIS.lListBuilt = .T.
  ENDFUNC  && BuildList
  * ------------------------------------------------------------------- *
  FUNCTION BuildListFromArray
    *-- called from BuildList() when nRowSourceType = L7_ROWSOURCETYPE_ARRAY
    LOCAL at1, at2, ii, lcArray
    IF TYPE( THIS.cRowSource + '[1]') = 'U'
      ERROR "No array values specified for control: " + THIS.Name
    ELSE
      lcArray = THIS.cRowSource
      at1 = ALEN(&lcArray, 1)  && macro in case value is "obj.prop"
      at2 = ALEN(&lcArray, 2)
      FOR ii = 1 TO m.at1
        IF m.at2 < 2
          * 1-column array -- use for both value and display
          THIS.AddItem( ;
            EVAL( THIS.cRowSource + "[" + LTRIM( STR( m.ii)) + ",1]") )
        ELSE  && 2-column array -- separate display text strings
          THIS.AddItem( ;
            EVAL( THIS.cRowSource + "[" + LTRIM( STR( m.ii)) + ",1]"), ;
            EVAL( THIS.cRowSource + "[" + LTRIM( STR( m.ii)) + ",2]") )
        ENDIF
      ENDFOR
    ENDIF
  ENDFUNC  && BuildListFromArray
  * ------------------------------------------------------------------- *
  FUNCTION BuildListFromCollection
    *-- called from BuildList() when nRowSourceType = L7_ROWSOURCETYPE_COLLECTION
    *-- Get a reference:
    LOCAL loColl, llIsObj, loItem
    loColl = IIF(VARTYPE(THIS.cRowSource) = "O", THIS.cRowSource, EVALUATE(THIS.cRowSource))
    * (allows either a resolvable object name or an actual object to be specified)
    llIsObj = NULL
    *-- Iterate:
    FOR EACH loItem IN loColl
      llIsObj = NVL(m.llIsObj, IIF(VARTYPE(loItem) = "O", .T., .F.))
      IF m.llIsObj
        IF EMPTY(THIS.cRowSourceLabelProperty)
          THIS.AddItem(EVALUATE("loItem." + THIS.cRowSourceValueProperty))
        ELSE  && both a value and a label property are specified
          THIS.AddItem(EVALUATE("loItem." + THIS.cRowSourceValueProperty), ;
            EVALUATE("loItem." + THIS.cRowSourceLabelProperty))
        ENDIF
      ELSE  && not an object -- must be simple collection of values:
        THIS.AddItem(m.loItem)
      ENDIF
    ENDFOR
  ENDFUNC  && BuildListFromCollection
  * ------------------------------------------------------------------- *
  FUNCTION SetValueIfNeeded
    IF THIS.lMultiSelect
      RETURN
    ENDIF
    RETURN DODEFAULT()
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetChecked
    * Called internally to handle special case where a single value
    * was pre-set for a multi-select control.
    * Applies to multi-select items only (single-valued
    * items use normal vNewValue/vOldValue properties). 
    LOCAL lnIndex
    lnIndex = ASCAN(THIS.aOptions,THIS.vOldValue,1,-1,1,14)
    IF m.lnIndex > 0
      THIS.AddSelection(m.lnIndex, .T., .T.)
    ELSE
      ERROR [Invalid multiple-selection option: ] + TRANSFORM(THIS.vOldValue) + [.] 
    ENDIF    
    THIS.lCheckedSet = .T.
  ENDFUNC  && SetChecked
  * ------------------------------------------------------------------- *
  FUNCTION XMLInput

    ERROR "All XML functionality temporarily suspended pending a rewrite."

    LPARAMETER lcXml
    *!*      IF NOT THIS.lVisible
    *!*        RETURN
    *!*      ENDIF
    *!*      IF NOT THIS.lMultiSelect
    *!*        THIS.SetValueIfNeeded()
    *!*      ENDIF
    *!*      * Build the list if it hasn't been built yet:
    *!*      IF NOT THIS.lListBuilt
    *!*        THIS.BuildList()
    *!*      ENDIF
    *!*      IF THIS.lMultiSelect AND THIS.lValueSet AND NOT THIS.lCheckedSet
    *!*        THIS.SetChecked()
    *!*      ENDIF
    *!*      IF NOT THIS.lMultiSelect  && Single selection is just like any other form var.
    *!*        RETURN DODEFAULT(m.lcXml)
    *!*      ENDIF
    *!*      IF VARTYPE( m.lcXml) # 'C'
    *!*        lcXml = THIS.Parent.cXml
    *!*      ENDIF
    *!*      LOCAL lcName
    *!*      LOCAL ARRAY laSelects[1]
    *!*      lcName = THIS.cHtmlName
    *!*      THIS.nSelections = L7ExtractElementMultiple( m.lcXml, m.lcName, @laSelects )
    *!*      THIS.FillSelectionsFromArray( @laSelects )
  ENDFUNC  && XMLInput
  * ------------------------------------------------------------------- *
  FUNCTION IsItemSelected(lvItem)
    LOCAL lnIndex, llRetVal
    lnIndex = ASCAN(THIS.aOptions,m.lvItem,1,-1,1,14)
    IF m.lnIndex > 0
      llRetVal = THIS.nSelections > 0 AND ASCAN(THIS.aSelections,m.lnIndex) > 0
    ELSE
      llRetVal = .F.
    ENDIF
    RETURN m.llRetVal
  ENDFUNC  && IsItemSelected
  * ------------------------------------------------------------------- *
  FUNCTION XMLOutput

    ERROR "All XML functionality temporarily suspended pending a rewrite."

    *!*      IF NOT THIS.lVisible
    *!*        RETURN []
    *!*      ENDIF
    *!*      IF NOT THIS.lMultiSelect
    *!*        * (with multi-select, checking gets done in BuildList method)
    *!*        THIS.SetValueIfNeeded()
    *!*      ENDIF
    *!*      * Build the list if it hasn't been built yet:
    *!*      IF NOT THIS.lListBuilt
    *!*        THIS.BuildList()
    *!*      ENDIF
    *!*      * If there is a value, make sure we pre-check the right item.
    *!*      IF THIS.lMultiSelect AND THIS.lValueSet AND NOT THIS.lCheckedSet
    *!*        THIS.SetChecked()
    *!*      ENDIF
    *!*      IF NOT THIS.lMultiSelect  && Single selection is just like any other form var.
    *!*        RETURN DODEFAULT()
    *!*      ENDIF
    *!*      LOCAL lcName, lcXml, ii, lcItemValueString
    *!*      lcName = THIS.cHtmlName
    *!*      lcXml = []
    *!*      IF THIS.lFirstItemSelected
    *!*        lcXml = m.lcXml + [<] + m.lcName + [>] + TRANS( THIS.vFirstItemValue ) + ;
    *!*          [</] + m.lcName + [>]
    *!*      ENDIF
    *!*      FOR ii = 1 TO THIS.nOptions
    *!*        IF THIS.aOptions[ m.ii, 4] = .T.  && item selected
    *!*          lcItemValueString = THIS.aOptions[ m.ii, 1]
    *!*          * Convert to char for concatenation into HTML:
    *!*          IF VARTYPE( m.lcItemValueString) # "C"
    *!*            lcItemValueString = TRANSFORM( m.lcItemValueString )
    *!*          ENDIF
    *!*          lcXml = m.lcXml + [<] + m.lcName + [>] + m.lcItemValueString + ;
    *!*            [</] + m.lcName + [>]
    *!*        ENDIF      
    *!*      ENDFOR
    *!*      RETURN m.lcXml
  ENDFUNC && XMLOutput
  * ------------------------------------------------------------------- *
  FUNCTION GetOutput
    THIS.lOutputCreated = .T.
    LOCAL lcText, lcItemText, lcItemValueString, ii, lcValueType, ;
      lnItemCount, llWrapInTable, lcLabel, llSelected, lcID, llSelectionFound

    lcText = ""
    lnItemCount = 0
    lcID = THIS.GetID() && call once here--we'll suffix with option counts also
    
    llWrapInTable = THIS.nStyle = L7_MULTISTYLE_FORMATTED AND ;
      ( THIS.nMode = L7_MULTI_RADIOBUTTON OR ;
        THIS.nMode = L7_MULTI_CHECKBOX )
        
    IF THIS.lMultiSelect AND THIS.nMode = L7_MULTI_CHECKBOX  AND THIS.lCheckAllLinks = .T.
      lcText = m.lcText + THIS.GetCheckAllLinks()
    ENDIF

    IF NOT THIS.lMultiSelect
      * (with multi-select, checking gets done in BuildList method)
      THIS.SetValueIfNeeded()
    ENDIF
    * Build the list if it hasn't been built yet:
    IF NOT THIS.lListBuilt
      THIS.BuildList()
    ENDIF
    * If there is a value, make sure we pre-check the right item.
    IF THIS.lMultiSelect AND THIS.lValueSet AND NOT THIS.lCheckedSet
      THIS.SetChecked()
    ENDIF
    
    * DISABLED items:
    IF THIS.lDisabled
      lcTxt = [<span class="] + THIS.cReadOnlyDataCssClass + [">] 
      lcTxt = m.lcTxt + THIS.cDisplayValue  && see access method
      lcTxt = m.lcTxt + [</span>]
      RETURN m.lcTxt
    ENDIF
    
    * HIDDEN items:
    IF THIS.lHidden
      IF THIS.lMultiSelect = .F.
        RETURN THIS.GetHiddenOutput()
      ELSE && multi-select, hidden
        lcText = [<span class="] + THIS.cReadOnlyDataCssClass + [">] 
        FOR ii = 1 TO THIS.nOptions
          ** IF THIS.aOptions[ m.ii, 4] = .T.  && item selected
          IF THIS.nSelections > 0 AND ASCAN(THIS.aSelections, m.ii) > 0 && item selected
            lcText = m.lcText + [<input type="hidden" name="] + THIS.cHtmlName + ["] + ;
              [ value="] + TRANSFORM( THIS.aOptions[ m.ii, 1] ) + [" />] + CR
            IF THIS.lShowOnForm
              lcText = m.lcText + TRANSFORM( THIS.aOptions[ m.ii, 2]) + L7BR + CR
            ENDIF
          ENDIF      
        ENDFOR
        lcText = m.lcText + [</span>] + CR
        RETURN m.lcText
      ENDIF
    ENDIF

    * Create any output that precedes iteration of options:
    DO CASE
    CASE THIS.nMode = L7_MULTI_POPUP
      * Create opening <select> tag:
      IF THIS.lMultiSelect AND THIS.nSize < 3
        THIS.nSize = 3
      ENDIF
      lcText = m.lcText + [<select name="] + THIS.cHtmlName + ["] + ;
        [ size="] + LTRIM( STR( THIS.nSize)) +[" ]+ ;
        IIF( THIS.lMultiSelect, [ multiple], [] ) + ;
        IIF( EMPTY( THIS.cOnClick), [], [ onclick="] + THIS.cOnClick + ["]) + ;
        IIF( EMPTY( THIS.cOnChange), [], [ onchange="] + THIS.cOnChange + ["]) + ;
        IIF( EMPTY( THIS.cOnBlur), [], [ onblur="] + THIS.cOnBlur + ["]) + ;
        IIF( EMPTY( THIS.cControlCssStyle), [], [ style="] + THIS.cControlCssStyle + ["]) + ;
        IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
        [ id="] + m.lcID + ["] + [>] + CR
    ENDCASE
    IF m.llWrapInTable
      lcText = m.lcText + [<table class="multipleOptionTable">] + CR
    ENDIF

    * Iterate the choices, building output as we go:
    IF NOT THIS.lMultiSelect
      lcValueType = VARTYPE(THIS.vNewValue)
    ENDIF
    FOR ii = 1 TO THIS.nOptions
      llSelected = .F.
      lcItemText = ''
      lcItemValueString = THIS.aOptions[ m.ii, 1]
      * Convert to char for concatenation into HTML:
      IF VARTYPE( m.lcItemValueString) # "C"
        lcItemValueString = TRANSFORM( m.lcItemValueString )
      ENDIF
      
      * Set variable for whether this item is selected.
      IF THIS.lMultiSelect
        * multi-select items that are selected are stored in an array:
        llSelected = THIS.nSelections > 0 AND ASCAN(THIS.aSelections, m.ii) > 0
      ELSE  
        * single choice, should be easier (yeah, right):
        IF NOT m.llSelectionFound  && keep looking
          * Type-check first item:
          SET ASSERTS ON
          ASSERT m.ii > 1 OR m.lcValueType = VARTYPE(THIS.aOptions[ m.ii, 1]) ;
            MESSAGE "Variable type of form element (" + m.lcValueType + ;
              ") does not match variable type of option list (" + VARTYPE( THIS.aOptions[ m.ii, 1] ) + ")."
          * See if this option is the selected one:
          llSelected = ALLTRIM(TRANSFORM(THIS.vNewValue)) == ALLTRIM(m.lcItemValueString)
          IF m.llSelected
            llSelectionFound = .T.
          ENDIF
        ENDIF
      ENDIF

      * "First Item" handling:
      IF m.ii = 1 AND THIS.lUseFirstItem
        * A first item applies.
        lnItemCount = m.lnItemCount + 1
        IF m.llWrapInTable
          IF MOD( m.lnItemCount, THIS.nItemsPerRow) = 1
            lcItemText = m.lcItemText + [<tr>]
          ENDIF
          lcItemText = m.lcItemText + [<td>]
        ENDIF
        DO CASE
        CASE THIS.nMode = L7_MULTI_POPUP
          lcItemText = m.lcItemText + [<option]
          IF THIS.lFirstItemSelected
            * First item to be pre-selected
            IF (THIS.lMultiSelect AND THIS.nSelections = 0) OR ;
              (NOT THIS.lMultiSelect AND NOT m.llSelectionFound)
              * For single-selection items,
              * we don't want the "first item" to be selected if another item
              * in the list is indicated by the controls value.
              lcItemText = m.lcItemText + [ selected="selected" ]
            ENDIF
          ENDIF
          lcItemText = m.lcItemText + [ value="] + TRANSFORM( THIS.vFirstItemValue) + [">] + ;
            IIF( ISNULL( THIS.cFirstItemLabel), ;
              TRANSFORM( THIS.vFirstItemValue), THIS.cFirstItemLabel ) + ;
            [</option>]
        ENDCASE
        IF m.llWrapInTable
          lcItemText = m.lcItemText + [</td>]
          IF MOD( m.lnItemCount, THIS.nItemsPerRow) = 0
            lcItemText = m.lcItemText + [</tr>]
          ENDIF
        ENDIF
        lcItemText = m.lcItemText + CR
      ENDIF  && "First Item" check.

      lnItemCount = m.lnItemCount + 1
      
      IF NOT THIS.lNoLabels
        lcLabel = THIS.aOptions[ m.ii, 2]
        IF EMPTY( m.lcLabel)  && Missing--use first column.
          lcLabel = THIS.aOptions[ m.ii, 1]
        ENDIF
        lcLabel = TRIM(TRANSFORM(m.lcLabel))
      ENDIF

      IF m.llWrapInTable
        IF MOD( m.lnItemCount, THIS.nItemsPerRow) = 1
          lcItemText = m.lcItemText + [<tr>]
        ENDIF
        lcItemText = m.lcItemText + [<td>]
      ENDIF
      
      DO CASE
      CASE THIS.nMode = L7_MULTI_POPUP
        * <option> tag for popups
        lcItemText = m.lcItemText + [<option] + ;
          IIF( m.llSelected, [ selected="selected"], []) + ;
          [ value="] + m.lcItemValueString + [">] + m.lcLabel + [</option>]

      CASE THIS.nMode = L7_MULTI_RADIOBUTTON
        * <input> tag for radio buttons
        lcItemText = m.lcItemText + ;
          [<input type="radio" name="] + THIS.cHtmlName + ["] + ;
          IIF( EMPTY( THIS.cOnClick), [], [ onClick="] + THIS.cOnClick + ["]) + ;
          IIF( EMPTY( THIS.cOnChange), [], [ onChange="] + THIS.cOnChange + ["]) + ;
          IIF( m.llSelected, [ checked="checked"], []) + ;
          [ value="] + m.lcItemValueString + ["] + ;
          IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
          [ id="] + m.lcID + [_] + TRANSFORM(m.ii) + [" />] 
          
        IF NOT THIS.lNoLabels
          lcItemText = m.lcItemText + ;
            [<label class="FormCheckboxCaption" for="] + m.lcID + [_] + TRANSFORM(m.ii) + [">] + ;
            m.lcLabel + [</label>]
        ENDIF
        
      CASE THIS.nMode = L7_MULTI_CHECKBOX
        * <input> tag for checkboxes
        lcItemText = m.lcItemText + ;
          [<input type="checkbox" name="] + THIS.cHtmlName + ["] + ;
          IIF( EMPTY( THIS.cOnClick), [], [ onClick="] + THIS.cOnClick + ["]) + ;
          IIF( EMPTY( THIS.cOnChange), [], [ onChange="] + THIS.cOnChange + ["]) + ;
          IIF( m.llSelected, [ checked="checked"], []) + ;
          [ value="] + m.lcItemValueString + ["] + ;
          IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
          [ id="] + m.lcID + [_] + TRANSFORM(m.ii) + [" />] 
          
        IF NOT THIS.lNoLabels
          lcItemText = m.lcItemText + ;
            [<label class="FormCheckboxCaption" for="] + m.lcID + [_] + TRANSFORM(m.ii) + [">] + ;
            m.lcLabel + [</label>]
        ENDIF

      CASE THIS.nMode = L7_MULTI_TEXTBOX
        * <input> tag for textboxes comes at end
        *!*          lcItemText = m.lcItemText + ;
        *!*            [<input type="textbox" name="] + THIS.cHtmlName + ["] + ;
        *!*            [ value="] + TRANSFORM(THIS.vNewValue) + ["] + ;
        *!*            IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
        *!*            [ id="] + m.lcID + [_] + TRANSFORM(m.ii) + [">] 
          
      ENDCASE
        
      IF m.llWrapInTable
        lcItemText = m.lcItemText + [</td>]
        * End table row, if needed:
        IF MOD( m.lnItemCount, THIS.nItemsPerRow) = 0
          lcItemText = m.lcItemText + [</tr>]
        ENDIF
      ELSE  && not wrapping in table
        IF INLIST(THIS.nMode, L7_MULTI_RADIOBUTTON, L7_MULTI_CHECKBOX)
          * See if we should space out the items:
          IF NOT EMPTY( THIS.cIntraOptionText )
            IF m.lnItemCount > 1
              lcItemText = THIS.cIntraOptionText + m.lcItemText
            ENDIF
          ENDIF
          * Check line break need:
          IF THIS.nStyle = L7_MULTISTYLE_VERTICAL OR ;
            ( THIS.nStyle = L7_MULTISTYLE_HORIZONTAL AND ;
              MOD( m.lnItemCount, THIS.nItemsPerRow) = 0  )
            *
            lcItemText = m.lcItemText + L7BR
          ENDIF

        ENDIF
      ENDIF
      * Concatenate item text to master control text:
      lcText = m.lcText + m.lcItemText + CR
      
    ENDFOR  && end of item iteration  (ii = 1 TO THIS.nOptions)

    IF m.llWrapInTable
      IF MOD( m.lnItemCount, THIS.nItemsPerRow) # 0
        * Not at an even row boundary.
        lcText = m.lcText + REPLICATE( [<td>&nbsp;</td>], ;
          THIS.nItemsPerRow - MOD( m.lnItemCount, THIS.nItemsPerRow) )
        lcText = m.lcText + [</tr>] + CR
      ENDIF
      m.lcText = m.lcText + [</table>] + CR
    ENDIF

    * Create any output that is needed following iteration of choices:
    DO CASE
    CASE THIS.nMode = L7_MULTI_POPUP
      lcText = m.lcText + [</select>] + CR
    CASE THIS.nMode = L7_MULTI_TEXTBOX
      * <input> tag for textboxes comes at end
      lcText = m.lcText + ;
        [<input type="textbox" name="] + THIS.cHtmlName + ["] + ;
        [ value="] + TRANSFORM(THIS.vNewValue) + ["] + ;
        IIF( EMPTY( THIS.cControlCssClass), [], [ class="] + THIS.cControlCssClass + ["]) + ;
        [ id="] + m.lcID + [_] + TRANSFORM(m.ii) + [" />] 
    ENDCASE

    RETURN m.lcText 
  ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION GetCheckAllLinks()
    LOCAL lcCheckAllScript, lcCheckNoneScript, lcStr
    THIS.GetCheckAllScript(@lcCheckAllScript, @lcCheckNoneScript)
    lcStr = ;
      '<a class="FormMultiCheckAll" href="#" onclick="' + m.lcCheckAllScript + '">[Check All...]</a>' + ;
      '&nbsp;' + ;
      '<a class="FormMultiCheckAll" href="#" onclick="' + m.lcCheckNoneScript + '">[Check None...]</a>'
    RETURN m.lcStr
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION GetCheckAllScript(lcCheckAllScript, lcCheckNoneScript)
    lcFormName = THIS.Form.cHtmlName
    lcName = THIS.cHtmlName
    lcCheckAllScript  = [javascript: void L7checkAll('] + m.lcFormName + [','] + m.lcName + [',true);]
    lcCheckNoneScript = [javascript: void L7checkAll('] + m.lcFormName + [','] + m.lcName + [',false);]
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * Assumes Request object is available.
    IF NOT THIS.lMultiSelect
      THIS.SetValueIfNeeded()
    ENDIF
    * Build the list if it hasn't been built yet:
    IF NOT THIS.lListBuilt
      THIS.BuildList()
    ENDIF
    IF THIS.lMultiSelect AND THIS.lValueSet AND NOT THIS.lCheckedSet
      THIS.SetChecked()
    ENDIF

    * Read in form variables from the web hit.
    IF THIS.lMultiSelect
      * Multi-select version is much tougher and slower:
      LOCAL ARRAY laSelects[ 1]

      * Get an array of the multi-select choices:
      IF THIS.lMultiPart = .F.
        THIS.nSelections = Request.GetFormMultiple( @laSelects, THIS.cHtmlName )
      ELSE
        ** Following requires a sub-class of Web Connection's wwRequest, which
        ** does not support this method. See L7Request.PRG for the method code.
        THIS.nSelections = Request.GetMultipartFormMultiple( @laSelects, THIS.cHtmlName )
      ENDIF
      
      THIS.FillSelectionsFromArray( @laSelects )
      
    ELSE  && NOT multi-select
      LOCAL lcTemp, ii, lcItemValueString, llMatchFound

      ** was ALLTRIM'd -- appeared wrong:
      IF THIS.lMultiPart
        lcTemp = Request.GetMultiPartFormVar( THIS.cHtmlName )
      ELSE
        lcTemp = Request.Form( THIS.cHtmlName )
      ENDIF
      
      THIS.nSelections = IIF( EMPTY( m.lcTemp), 0, 1)
      
      * First check if "first item" was selected:
      IF THIS.lUseFirstItem
        IF TRANSFORM( THIS.vFirstItemValue) == m.lcTemp
          THIS.lFirstItemSelected = .T.
          THIS.vNewValue = THIS.vFirstItemValue
        ELSE
          THIS.lFirstItemSelected = .F.
        ENDIF
      ELSE
        THIS.lFirstItemSelected = .F.
      ENDIF

      IF NOT ( THIS.lUseFirstItem AND THIS.lFirstItemSelected )
        * Check real items for selection match:
        FOR ii = 1 TO THIS.nOptions
          lcItemValueString = THIS.aOptions[ m.ii, 1]
          * Convert to character:
          IF VARTYPE( m.lcItemValueString) # "C"
            lcItemValueString = TRANSFORM( m.lcItemValueString )
          ENDIF
          IF TRIM( m.lcItemValueString ) == TRIM( m.lcTemp )
            THIS.vNewValue = THIS.aOptions[ m.ii, 1]
            * stop checking
            llMatchFound = .T.
            EXIT
          ENDIF
        ENDFOR
        * [[ This is awkward: Maybe we shouldn't go back against the list at all until
        * tha validation stage. Still, we want to cast vNewValue at least to the 
        * right data type.
        IF NOT m.llMatchFound
          THIS.vNewValue = L7Cast(m.lcTemp, THIS.cFieldType)   && punt, until validation?!
        ENDIF
      ENDIF
    ENDIF  && multi-select
    THIS.AfterReadInput()
    THIS.lInputRead = .T.
    THIS.lUpdated = THIS.WasChanged()
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION Valid  && MultiControl Validation
    IF THIS.lRequired 
      IF THIS.lMultiSelect
        IF THIS.nSelections = 0
          THIS.AddValidationMessage(  ;
            IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
            ' must have at least one selection.')
        ENDIF
      ELSE  && not multi-select, just handle like normal

        IF EMPTY( THIS.vNewValue )
        **IF THIS.nSelections # 1
          *[[ Note: We don't use an EMPTY check, since we need to support numeric
          * values where 0 is a valid choise...HOWEVER...using nSelection check 
          * does not work in a Grid, because we don't flyweight that.
          
          THIS.AddValidationMessage(  ;
            IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
            ' must have a selection.')
        ELSE
          IF THIS.lUseFirstItem AND THIS.lFirstItemSelected 
            * "First Item" is not a valid value in a required single-selection list.
            THIS.AddValidationMessage(  ;
              IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
              ' must have a selection other than the first item.')
          ENDIF
        ENDIF
      ENDIF && multi
    ENDIF
    IF NOT THIS.lMultiSelect AND THIS.nSelections = 1 AND NOT THIS.lFirstItemSelected 
      LOCAL lnRow
      lnRow = ASCAN(THIS.aOptions, THIS.vNewValue, -1, -1, 1, 4+8)
      IF m.lnRow = 0
        THIS.AddValidationMessage(  ;
          IIF( THIS.cLabel == THIS.cHtmlName, 'Entry', '"' + THIS.cLabel + '"') + ;
          ' does not have a valid list selection!')
      ENDIF
    ENDIF
    RETURN ( THIS.nInvalidCount = 0 )
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    * L7MultiControl::WasChanged()

    IF THIS.lMultiSelect
      * If different *count*, then we don't even need to look further.
      IF THIS.nSelections <> THIS.nOldSelections
        RETURN .T.
      ENDIF
      
      LOCAL ii
      FOR ii = 1 TO THIS.nSelections
        IF THIS.aSelections[m.ii] <> THIS.aOldSelections[m.ii]
          * NOTE: This code is only comparing choice-by-choice. 
          * It doesn't seem possible that the same combination of 
          * choices could be selected but in a different order. (Think 
          * about this.) If it is possible, we would have to change the above 
          * line to:
          * IF NOT ASCAN(THIS.aOldSelections[m.ii], THIS.aSelections[m.ii])
          RETURN .T.
        ENDIF
      ENDFOR
      RETURN .F.  && All the same.
      
    ELSE
      * Single select, so treat in normal way as other form objects,
      * except ...
      IF VARTYPE( THIS.vNewValue) = "C"
        * Need to compare TRIM'd values, since lookup codes may not all
        * have same length:
        RETURN NOT ( ALLTRIM( THIS.vNewValue) == ALLTRIM( THIS.vOldValue) )
      ELSE
        RETURN NOT ( THIS.vNewValue = THIS.vOldValue )
      ENDIF
    ENDIF
  ENDFUNC  && WasChanged
  * ------------------------------------------------------------------- *
  FUNCTION FillSelectionsFromArray(laSelects)
    * Called from ReadInput() and XMLInput().
    * First, clear any previous selections:
    LOCAL llItems
    llItems = (THIS.nSelections > 0)
    THIS.nSelections = 0
    DIMENSION THIS.aSelections[1]
    IF m.llItems
      LOCAL lnIndex, lcValue, lcItemValue
      FOR EACH lcValue IN laSelects
        IF THIS.lUseFirstItem && not common for multi-selects
          IF m.lcValue == TRANSFORM(THIS.vFirstItemValue)
            THIS.lFirstItemSelected = .T.
            LOOP
          ENDIF
        ENDIF
        * Look for selected value in array of options. Can't use
        * ASCAN(), because value at this point is a string (raw request info).
        lcValue = TRIM(m.lcValue)
        FOR lnIndex = 1 TO THIS.nOptions
          lcItemValue = TRIM(TRANSFORM(THIS.aOptions[m.lnIndex,1]))
          IF m.lcValue == m.lcItemValue
            THIS.AddSelection(m.lnIndex,.F.,.T.)
            EXIT
          ENDIF
        ENDFOR 
      ENDFOR
    ENDIF
  ENDFUNC  && FillSelectionsFromArray
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7MultiControl

* ==================================================================== *
DEFINE CLASS L7Popup AS L7MultiControl
  nMode     = L7_MULTI_POPUP
  cControlCssClass = "FormPopup"
  * Set "lMultiSelect" in implementation code, since popup can be either.
ENDDEFINE  

* ==================================================================== *
DEFINE CLASS L7RadioButton AS L7MultiControl
  nMode        = L7_MULTI_RADIOBUTTON
  cControlCssClass    = "FormRadio"
  lMultiSelect = .F.  && Radio buttons are never multi.
ENDDEFINE  

* ==================================================================== *
DEFINE CLASS L7MultiCheckbox AS L7MultiControl
  nMode        = L7_MULTI_CHECKBOX
  cControlCssClass    = "FormCheckbox"
  lMultiSelect = .T.  && Check boxes are always multi.
ENDDEFINE  

* ==================================================================== *
DEFINE CLASS L7MultiTextbox AS L7MultiControl
  nMode        = L7_MULTI_TEXTBOX
  cControlCssClass    = "FormTextbox"
  lMultiSelect = .F.  && Text boxes are never multi.
ENDDEFINE  

* ==================================================================== *

* FILE END: L7MultiControls.PRG


#if .f.
07/09/2002 - Drop 4-column array in favor of small arrays of old/new selected items.
03/09/2003 - added support for collections, including hook
           - added hook for building from arrays
           - generate ERROR if unimplemented row-source-type is specified
05/11/2003 - Added "lCheckAllLinks" property. Presumes matching .JS available.
08/30/2003 - merged change from Carole (close </option> tags).
10/22/2003 - changed cIntraOptionText handling code
11/26/2003 - added draft support for rendering as _textbox_ (for certain DE and grid scenarios)
           - added safe code for protection from unequal length string issues
           - removed nMode_ASSIGN() method
06/07/2005 - changed call to Cast() to L7Cast()
#endif
