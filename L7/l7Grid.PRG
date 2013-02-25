* L7Grid.PRG
*
* Parent Class: L7ContainerControl (in L7BaseControls.PRG)
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


*** ======================================================== ***
DEFINE CLASS L7Grid AS L7ContainerControl
  nExtraRows = 0  && # of blank child rows to include at end
  nRows      = 0  && calculated in SetupColumns()
  nCols      = 0  && calculated in SetupColumns()
  
  nActiveRow = 0 && used by contained controls for flyweight binding

  nRepeatHeaderRowCount = 0  && experimental!
  nTableCount           = 1  && 
  
  cControlCssClass   = "FormGrid"  && used by form renderer
  cControlCssStyle   = ""          &&  
  cWrapperTag        = "div" && [[this property isn't in L7ContainerControl -- should it be???
  
  * Special grid CSS class for table:
  cGridTableCssClass = "FormGridTable"
  cGridTableCssStyle = ""
  
  * Summary and Caption support:
  cSummary         = ""
  cCaption         = ""
  cCaptionCssClass = "FormGridCaption"
  cCaptionCssStyle = ""
  
  nZeroRowBehavior = L7_GRID_ZEROROW_BLANKROW
  
  * Pattern to apply to all contaoned controls as their default:
  cDefaultControlPattern = "%c(%b%v)" && validation under control [alt: %c(%s%v) - validation to right of control]
  
  cValignRows     = "top"
  cRowCssClass    = ""       && for alternating-row styles, use comma-delim list (e.g., "OddGridRow,EvenGridRow")
  cRowCssStyle    = ""       &&   - same -
  cNewRowCssClass = NULL     && defaults to same as current row
  cNewRowCssStyle = NULL     &&   - same -
  
  cHeaderRowCssClass = ""
  cHeaderRowCssStyle = "vertical-align: bottom;"
  cPreHeaderText     = ""  && ostensibly for <thead> area
  cPostControlsText  = ""  && ostensibly for <tfoot> area
  
  cColumnHeaderTag      = "th"  && highly discouraged to override!
  cColumnHeaderCssClass = ""
  cColumnHeaderCssStyle = ""
  
  cPreText  = ""
  cPostText = ""

  * Props related to iterating data or BizObj:
  cIteratorClass      = "L7CursorIterator"
  oIterator           = NULL
  cControlSource      = ""  && for BizObj referencing, see CreateIterator()
  cChildAlias         = ""
  cChildKeyExpression = ""
  vChildKeyValue      = ""
  
  PROTECTED lColumnsSetup, cCurrentGroupID  && internal use
  lColumnsSetup = .F.
  cCurrentGroupID = ""  && support vertical grouping of elements in a column
  * ------------------------------------------------------------------- *
  FUNCTION GarbageCollect
    *!*    THIS.TeardownBindings()
    DODEFAULT()
    THIS.oIterator = NULL
  ENDFUNC   && GarbageCollect
  * ------------------------------------------------------------------- *
  FUNCTION CreateIterator
    IF ISNULL(THIS.oIterator)
      IF NOT EMPTY(THIS.cControlSource)
        THIS.oIterator = CREATEOBJECT(THIS.cIteratorClass, ;
          EVALUATE(THIS.cControlSource)) && iterate will assume, and focus on, an aItems array.
      ELSE
        IF NOT EMPTY(THIS.cChildAlias)
          THIS.oIterator = CREATEOBJECT(THIS.cIteratorClass, ;
            THIS.cChildAlias)
        ELSE
          THIS.oIterator = CREATEOBJECT(THIS.cIteratorClass)
        ENDIF
      ENDIF
    ENDIF
    RETURN 
  ENDFUNC  && CreateIterator
  * ------------------------------------------------------------------- *
  FUNCTION AfterPrepareObjects
    DODEFAULT()
    THIS.CreateIterator()
    THIS.SetupRowsAndColumns()
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION CountRows
    LOCAL lnCount
    * Get a quick (?) count of current data rows:
    lnCount = 0
    THIS.oIterator.MoveFirst()
    DO WHILE NOT THIS.oIterator.EOF
      lnCount = m.lnCount + 1
      THIS.oIterator.MoveNext()
    ENDDO
    THIS.nRows = m.lnCount
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetupRowsAndColumns
    IF NOT THIS.lColumnsSetup
      THIS.lColumnsSetup = .T.
      THIS.CountRows()
      THIS.SetupColumns()
      THIS.SetupRows()
      *!*      THIS.SetupBindings()
    ENDIF
  ENDFUNC  && SetupRowsAndColumns
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION SetupBindings
  *!*      LOCAL ii, loObj
  *!*      FOR ii = 1 TO THIS.CONTROLCOUNT
  *!*        loObj = THIS.CONTROLS[m.ii]
  *!*        * If controls is not visible, it is ignored:
  *!*        IF loObj.lVisible = .F.
  *!*          LOOP
  *!*        ENDIF
  *!*        loObj.SelfBind()  && delegate, in case custom control has extra special properties
  *!*      ENDFOR
  *!*    ENDFUNC
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION TeardownBindings
  *!*      LOCAL ii, loObj
  *!*      FOR ii = 1 TO THIS.CONTROLCOUNT
  *!*        loObj = THIS.CONTROLS[m.ii]
  *!*        UNBINDEVENTS(m.loObj)
  *!*      ENDFOR
  *!*    ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetupRows
    LOCAL ii, lnRow
    lnRow = 0
    THIS.oIterator.MoveFirst()
    DO WHILE NOT THIS.oIterator.EOF
      lnRow = m.lnRow + 1
      THIS.vChildKeyValue = THIS.oIterator.GetFieldValue( ;
        THIS.cChildKeyExpression)  && [[ is this needed?
      THIS.SetupRow( m.lnRow)
      THIS.oIterator.MoveNext()
    ENDDO
    FOR ii = 1 TO THIS.nExtraRows
      lnRow = m.lnRow + 1
      THIS.vChildKeyValue = [__] + TRANSFORM(m.ii) + [__]  && [[ is this needed?
      THIS.SetupRow( m.lnRow)
    ENDFOR
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetupRow(lnRow)
    LOCAL ii, loObj
    * Load all up front:
    FOR ii = 1 TO THIS.CONTROLCOUNT
      loObj = THIS.CONTROLS[m.ii]
      IF m.loObj.lVisible = .F.
        LOOP
      ENDIF
      loObj.lValueSet = .F.                && force re-eval [[ should we really do this for items w/o control sources?
      ** loObj.cID       = ""              && because of current cID_ACCESS() strategy
      ** loObj.cIDSuffix = [_] + TRIM(TRANSFORM(THIS.vChildKeyValue))
      loObj.SetValueIfNeeded()
      loObj.SetDisabledFlag()              && enables row-specific disabling
      loObj.StoreProperties(m.lnRow, .T.)  && flyweight, 1st time (so store everything)
    ENDFOR
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetupColumns
    * Setup member controls for flyweight, etc.:
    LOCAL lnCount, ii, loObj, lnRow, llNewCol
    FOR ii = 1 TO THIS.CONTROLCOUNT
      llNewCol = .T.
      loObj = THIS.CONTROLS[m.ii]
      * If controls is not visible, it is ignored:
      IF loObj.lVisible = .F.
        LOOP
      ENDIF
      * Disable all controls if grid is disabled:
      IF THIS.lDisabled = .T.
        ** THIS.SETALL("lDisabled", .T.)
        loObj.lDisabled = .T.
        loObj.cDisabledExpression = ""  && prevent "come-alive"
      ENDIF
      * Increment count of physical columns:
      IF NOT loObj.cGroupID == THIS.cCurrentGroupID  && group change
        * Swap:
        THIS.cCurrentGroupID = loObj.cGroupID 
      ELSE  && no group change
        IF NOT EMPTY( THIS.cCurrentGroupID) && in a group
          llNewCol = .F.
        ENDIF
      ENDIF
      IF m.llNewCol
        THIS.nCols = THIS.nCols + 1 
      ENDIF
      * Transfer default pattern from grid to control:
      IF NOT ISNULL(THIS.cDefaultControlPattern)
        loObj.cDefaultPattern = THIS.cDefaultControlPattern
      ENDIF
      * Convert nested objects to <span> vs. <div>:
      loObj.cWrapperTag = "span"
      * Endow controls with array for storing properties
      * as we move between rows (flyweight):
      loObj.SetMultiRowMode(THIS.nRows + THIS.nExtraRows)
      *!*            loObj.AddProperty( 'aPropValues(' + ;
      *!*              TRANSFORM( THIS.nRows + THIS.nExtraRows) + ;
      *!*              ',' + TRANSFORM( loObj.nPropCount) + ')')
    ENDFOR

    *!*        * Set individual control properties:
    *!*        IF THIS.nRows + THIS.nExtraRows = 0  && No rows!
    *!*          * Anything needed????? Should we render at all???
    *!*        ELSE
    *!*          THIS.cCurrentGroupId = ""  && reset from previous use
    *!*          FOR ii = 1 TO THIS.CONTROLCOUNT
    *!*            llNewCol = .T.
    *!*            loObj = THIS.CONTROLS[m.ii]
    *!*            IF loObj.lVisible = .F.
    *!*              LOOP
    *!*            ENDIF
    *!*            IF NOT loObj.cGroupID == THIS.cCurrentGroupID  && group change
    *!*              * Swap:
    *!*              THIS.cCurrentGroupID = loObj.cGroupID 
    *!*            ELSE  && no group change
    *!*              IF NOT EMPTY( THIS.cCurrentGroupID) && in a group
    *!*                llNewCol = .F.
    *!*              ENDIF
    *!*            ENDIF
    *!*            IF m.llNewCol
    *!*              THIS.nCols = THIS.nCols + 1 
    *!*            ENDIF

    *!*            * Transfer default pattern to control:
    *!*            IF NOT ISNULL(THIS.cDefaultControlPattern)
    *!*              loObj.cDefaultPattern = THIS.cDefaultControlPattern
    *!*            ENDIF
    *!*            * Convert nested objects to <span> vs. <div>:
    *!*            loObj.cWrapperTag = "span"
    *!*            * Endow controls with array for storing properties
    *!*            * as we move between rows:
    *!*            loObj.SetMultiRowMode(THIS.nRows + THIS.nExtraRows)
    *!*            *!*            loObj.AddProperty( 'aPropValues(' + ;
    *!*            *!*              TRANSFORM( THIS.nRows + THIS.nExtraRows) + ;
    *!*            *!*              ',' + TRANSFORM( loObj.nPropCount) + ')')
    *!*          ENDFOR
    *!*        ENDIF
    
  ENDFUNC  && SetupColumns
  * ------------------------------------------------------------------- *
  FUNCTION AfterRenderNestedControls(lcTxt)

  FUNCTION RenderNestedControls
    * Called from parent RenderSelf() method.
    LOCAL lcTxt, lcRowTxt, ii, lnRow, lnTableRow
    *!*      THIS.CreateIterator()
    *!*      THIS.SetupColumns()
    IF THIS.nRows + THIS.nExtraRows = 0 AND THIS.nZeroRowBehavior < L7_GRID_ZEROROW_HEADINGROW
      RETURN ""
    ENDIF
    lcTxt = THIS.cPreText
    *!*      lcTxt = m.lcTxt + [<table cellspacing=0] + ;
    *!*        IIF( EMPTY(THIS.cGridTableCssClass), [], [ class="] + THIS.cGridTableCssClass + ["]) + ;
    *!*        IIF( EMPTY(THIS.cGridTableCssStyle), [], [ style="] + THIS.cGridTableCssStyle + ["]) + ;
    *!*        IIF( EMPTY(THIS.cSummary), [], [ summary="] + THIS.cSummary + ["]) + ;
    *!*        [>]
    lcTxt = m.lcTxt + THIS.RenderTableStart()
    lcTxt = m.lcTxt + THIS.RenderCaption() + THIS.RenderHeaders() + [<tbody>] + CR
    lnRow = 0
    lnTableRow = 0
    * Render existing "real" rows:
    THIS.oIterator.MoveFirst()
    DO WHILE NOT THIS.oIterator.EOF
      lnRow = m.lnRow + 1
      IF THIS.nRepeatHeaderRowCount > 0 
        lnTableRow = m.lnTableRow + 1
        IF m.lnTableRow > THIS.nRepeatHeaderRowCount  && time for new <table>
          lcTxt = m.lcTxt + [</tbody>] + THIS.RenderTableEnd() + CR
          lcTxt = m.lcTxt + THIS.RenderTableStart() 
          lcTxt = m.lcTxt + THIS.RenderHeaders() + [<tbody>] + CR  &&[[ validation and accessibility issues with this!
          lnTableRow = 1
          THIS.nTableCount = THIS.nTableCount + 1 
        ENDIF
      ENDIF
      THIS.vChildKeyValue = THIS.oIterator.GetFieldValue( ;
        THIS.cChildKeyExpression)
      lcTxt = m.lcTxt + THIS.RenderRow( m.lnRow)
      THIS.oIterator.MoveNext()
    ENDDO
    * Render "extra" rows:
    IF NOT THIS.lDisabled
      * Only render extras if the grid is enabled.
      FOR ii = 1 TO THIS.nExtraRows
        lnRow = m.lnRow + 1
        THIS.vChildKeyValue = [__] + TRANSFORM(m.ii) + [__]
        lcTxt = m.lcTxt + THIS.RenderRow( m.lnRow)
      ENDFOR
    ENDIF
    * Deal w/ 0-row condition:
    IF THIS.nRows + THIS.nExtraRows = 0 AND THIS.nZeroRowBehavior = L7_GRID_ZEROROW_BLANKROW
      lcTxt = m.lcTxt + THIS.RenderRow(0)
    ENDIF
    * Render column "instructions" as footnotes below grid:
    IF NOT THIS.lDisabled
      *[[ Maybe this should be forced into <tfoot> at top?
      lcTxt = m.lcTxt + THIS.RenderColumnInstructions()  
    ENDIF
    *!*      lcTxt = m.lcTxt + [</tbody>] + [</table>] + CR
    lcTxt = m.lcTxt + [</tbody>] + THIS.RenderTableEnd() + CR
    THIS.AfterRenderNestedControls(@lcTxt)  && "parting shot"
    RETURN m.lcTxt
  ENDFUNC  && RenderNestedControls
  * ------------------------------------------------------------------- *
  FUNCTION RenderTableStart
    RETURN [<table cellspacing=0] + ;
      IIF( EMPTY(THIS.cGridTableCssClass), [], [ class="] + THIS.cGridTableCssClass + ["]) + ;
      IIF( EMPTY(THIS.cGridTableCssStyle), [], [ style="] + THIS.cGridTableCssStyle + ["]) + ;
      IIF( EMPTY(THIS.cSummary), [], [ summary="] + THIS.cSummary + ["]) + ;
      [>]
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION RenderTableEnd
    RETURN [</table>]
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION RenderRow(lnRow)
    * 04/30/2002: Added group support.
    LOCAL ii, loObj, lcTxt, lcItemTxt, lcStr, llNewCol, ;
      lcRowClass, lcRowStyle, llOpenCell, lcObjCssClass
    * Determine class and style for row.
    STORE "" TO lcRowClass, lcRowStyle
    THIS.RowCSS(m.lnRow, @lcRowClass, @lcRowStyle)  && allow override
    lcTxt = [<tr] + ;
      IIF(EMPTY(m.lcRowClass), [], [ class="] + m.lcRowClass + ["]) + ;
      IIF(EMPTY(m.lcRowStyle), [], [ style="] + m.lcRowStyle + ["]) + ;
      IIF(EMPTY(THIS.cValignRows), [], [ valign="] + THIS.cValignRows + ["]) + ;
      [>] + CR

    THIS.cCurrentGroupId = ""  && reset from previous use
    * Load all up front:
    IF m.lnRow > 0
      FOR ii = 1 TO THIS.CONTROLCOUNT
        loObj = THIS.CONTROLS[m.ii]
        loObj.LoadProperties(m.lnRow)  && Flyweight implementation.
        loObj.cID       = ""  && because of current cID_ACCESS() strategy
        loObj.cIDSuffix = [_] + TRIM(TRANSFORM(THIS.vChildKeyValue))
      ENDFOR
    ENDIF
    FOR ii = 1 TO THIS.CONTROLCOUNT
      loObj = THIS.CONTROLS[m.ii]
      llNewCol = .T.
      lcItemTxt = ""
      IF loObj.lVisible = .F.
        LOOP
      ENDIF
      IF loObj.lAutoRender = .F.
        LOOP
      ENDIF
      IF m.llOpenCell AND ;
        ( EMPTY(loObj.cGroupID) OR ;
          NOT loObj.cGroupID == THIS.cCurrentGroupID )
        * We've got a cell open, and the next object is not
        * part of same cell (due to grouping).
        * Close out any old group (this is repeated at end):
        lcTxt = m.lcTxt + [</td>] + CR
        llOpenCell = .F.
      ENDIF
      IF NOT loObj.cGroupID == THIS.cCurrentGroupID  && group change
        THIS.cCurrentGroupID = loObj.cGroupID 
      ELSE  && no group change
        IF NOT EMPTY(THIS.cCurrentGroupID) && already in a group
          llNewCol = .F. && same column
        ENDIF
      ENDIF
      IF m.llNewCol
        lcObjCssClass = m.loObj.cDynamicCssClass  
        lcItemTxt = m.lcItemTxt + [<td] + ;
          IIF(m.lnRow = 0 OR EMPTY(loObj.cHeaders), [], [ headers="] + loObj.cHeaders + ["]) + ;
          IIF(EMPTY(m.lcObjCssClass), '', ' class="' + m.lcObjCssClass + '"') + ;
          IIF(EMPTY(m.loObj.cCssStyle), '', ' style="' + m.loObj.cCssStyle + '"') + ;
          [>] + CR  && [[ Do we need individual Class/Style tags for the <td> itself?
          * [[ Another alternative may be to allow, when there is only control/row,
          * [[ for the control's own wrapper to be set to "td", and thus not use this one.
        llOpenCell = .T.
      ENDIF
      IF m.lnRow > 0
        lcItemTxt = m.lcItemTxt + loObj.Render() && control's artifact pattern should drive output
      ELSE
        lcItemTxt = m.lcItemTxt + SP  && space for blank row
      ENDIF
      lcTxt = m.lcTxt + m.lcItemTxt + CR
    ENDFOR
    * Close out final cell (this is repeated within loop, except when in a group):
    IF m.llOpenCell
      lcTxt = m.lcTxt + [</td>] + CR
    ENDIF
    lcTxt = m.lcTxt + [</tr>] + CR

    
    *!*      FOR EACH loObj IN THIS.CONTROLS
    *!*        UNBINDEVENTS(m.loObj)
    *!*        
    *!*      ENDFOR

    ** NOTE: No matching StoreProperties() here, because we're theoretically done, once we've rendered.
    **   (Also, it isn't clear if properties would be changed at the rendering stage, anyway.)
    
    RETURN m.lcTxt
  ENDFUNC  && RenderRow
  * ------------------------------------------------------------------- *
  FUNCTION RenderCaption()
    IF EMPTY(THIS.cCaption)
      RETURN ""
    ENDIF
    RETURN [<caption] + ;
      IIF(EMPTY(THIS.cCaptionCssClass), [], [ class="] + THIS.cCaptionCssClass + ["]) + ;
      IIF(EMPTY(THIS.cCaptionCssStyle), [], [ style="] + THIS.cCaptionCssStyle + ["]) + ;
      [>] + THIS.cCaption + [</caption>] + CR
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION RowCss(lnRow, lcRowClass, lcRowStyle)
    LOCAL lnOcc
    IF m.lnRow > THIS.nRows && new
      lcRowClass = NVL(THIS.cNewRowCssClass, THIS.cRowCssClass)
      lcRowStyle = NVL(THIS.cNewRowCssStyle, THIS.cRowCssStyle)
    ELSE
      lcRowClass = THIS.cRowCssClass
      lcRowStyle = THIS.cRowCssStyle
    ENDIF
    lnOcc = OCCURS(",", m.lcRowClass)
    IF m.lnOcc > 0  && alternating row classes
      lcRowClass = ALLTRIM(GETWORDNUM(m.lcRowClass, 1 + MOD(m.lnRow - 1, 1 + m.lnOcc), ","))
    ENDIF
    lnOcc = OCCURS(",", m.lcRowStyle)
    IF m.lnOcc > 0  && alternating row classes
      lcRowStyle = ALLTRIM(GETWORDNUM(m.lcRowStyle, 1 + MOD(m.lnRow - 1, 1 + m.lnOcc), ","))
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION BeforeRenderHeaders(lcTxt)
    IF NOT EMPTY(THIS.cPreHeaderText)
      lcTxt = m.lcTxt + [<tr><th colspan="] + TRANSFORM(THIS.nCols) + [">] + ;
        THIS.cPreHeaderText + [</th></tr>] 
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION AfterRenderHeaders(lcTxt)
    * Note: If you overrode
    IF NOT EMPTY(THIS.cPostControlsText)
      * This seems out of place because <tfoot> is supposed to come
      * before the <tbody>.
      lcTxt = m.lcTxt + [<tfoot>] + ;
        [<tr><th colspan="] + TRANSFORM(THIS.nCols) + [">] + ;
        THIS.cPostControlsText + [</th></tr>] + ;
        [</tfoot>] + CR
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION RenderHeaders
    LOCAL ii, loObj, lcTxt, llNewCol, lcStr, llOpenCell, lcColStyle, lcColClass
    lcTxt = [<thead>] + CR
    IF THIS.BeforeRenderHeaders(@lcTxt)
      lcTxt = m.lcTxt + [<tr] + ;
        IIF(EMPTY(THIS.cHeaderRowCssClass), [], [ class="] + THIS.cHeaderRowCssClass + ["]) + ;
        IIF(EMPTY(THIS.cHeaderRowCssStyle), [], [ style="] + THIS.cHeaderRowCssStyle + ["]) + ;
        [>] + CR
      THIS.cCurrentGroupId = ""  && reset from previous use
      FOR ii = 1 TO THIS.CONTROLCOUNT
        loObj = THIS.CONTROLS[m.ii]
        llNewCol = .T.
        IF loObj.lVisible = .F.
          LOOP
        ENDIF
        IF loObj.lAutoRender = .F.
          LOOP
        ENDIF
        IF m.llOpenCell AND ;
          ( EMPTY(loObj.cGroupID) OR ;
            NOT loObj.cGroupID == THIS.cCurrentGroupID )
          * We've got a cell open, and the next object is not
          * part of same cell (due to grouping).
          * Close out any old group (this is repeated at end):
          lcTxt = m.lcTxt + [</] + THIS.cColumnHeaderTag + [>] + CRLF
          llOpenCell = .F.
        ENDIF
        IF NOT loObj.cGroupID == THIS.cCurrentGroupID  && group change
          THIS.cCurrentGroupID = loObj.cGroupID 
        ELSE  && no group change
          IF NOT EMPTY( THIS.cCurrentGroupID) && already in a group
            llNewCol = .F.
          ENDIF
        ENDIF
        IF m.llNewCol
          STORE "" TO lcColStyle, lcColClass, lcHeadID
          THIS.ColCSS(m.loObj, @lcColClass, @lcColStyle)
          lcHeadId = THIS.GetID() + [_H_] + SYS(2015)  && temporary approach to ID/Headers accessibility issue
          loObj.cHeaders = m.lcHeadId
          lcTxt = m.lcTxt + [<] + THIS.cColumnHeaderTag + [ scope="col"] + ;
            IIF(EMPTY(m.lcColClass), [], [ class="] + m.lcColClass + ["]) + ;
            IIF(EMPTY(m.lcColStyle), [], [ style="] + m.lcColStyle + ["]) + ;
            [ id="] + m.lcHeadId + ["] + ;
            [>] + CR  
          llOpenCell = .T.
        ENDIF
        lcStr = ""
        IF NOT EMPTY(THIS.cCurrentGroupId) AND NOT EMPTY(loObj.cGroupLabel)
          lcStr = lcStr + [<span class="] + loObj.cLabelCssClass + [">] + ;
            loObj.cGroupLabel + [</span>]
        ELSE
          lcStr = lcStr + loObj.RenderLabel(.T.)
          lcStr = lcStr + IIF(EMPTY(m.lcStr), '', L7BR)
        ENDIF
        lcTxt = m.lcTxt + m.lcStr
      ENDFOR
      * Close out final cell (this is repeated within loop, except when in a group):
      IF m.llOpenCell
        lcTxt = m.lcTxt + [</] + THIS.cColumnHeaderTag + [>] + CRLF
      ENDIF
      lcTxt = m.lcTxt + [</tr>] + CR
    ENDIF
    lcTxt = m.lcTxt + [</thead>] + CR
    THIS.AfterRenderHeaders(@lcTxt)
    RETURN m.lcTxt
  ENDFUNC && RenderHeaders
  * ------------------------------------------------------------------- *
  FUNCTION ColCss(loObj, lcColClass, lcColStyle)
    lcColClass = EVL(m.loObj.cColumnHeaderCssClass, THIS.cColumnHeaderCssClass)
    lcColStyle = EVL(m.loObj.cColumnHeaderCssStyle, THIS.cColumnHeaderCssStyle)
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION RenderColumnInstructions
    LOCAL ii, loObj, lcTxt, lnSpan
    lcTxt = ""
    lnSpan = 0
    FOR ii = 1 TO THIS.CONTROLCOUNT
      loObj = THIS.CONTROLS[m.ii]
      IF loObj.lVisible = .F.
        LOOP
      ENDIF
      IF loObj.lAutoRender = .F.
        LOOP
      ENDIF
      lnSpan = m.lnSpan + 1
      IF NOT EMPTY( loObj.cInstructions)
        lcTxt = m.lcTxt + [<strong>] + ;
          STRTRAN( loObj.cLabel, [<br>]) + [:</strong> ] + ;
          loObj.cInstructions + [<br>] + CR
      ENDIF
    ENDFOR
    IF NOT EMPTY( m.lcTxt)
      lcTxt = [<tr><td colspan="] + TRANSFORM(m.lnSpan) + ["><small>] + ;
        m.lcTxt + ;
        [</small></td></tr>]
    ENDIF
    RETURN m.lcTxt
  ENDFUNC && RenderColumnInstructions
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    * L7Grid::ReadInput()
    LOCAL ii, lnRow
    lnRow = 0
    *!*      THIS.CreateIterator()
    *!*      THIS.SetupColumns()

    THIS.oIterator.MoveFirst()
    DO WHILE NOT THIS.oIterator.EOF
      lnRow = m.lnRow + 1
      THIS.vChildKeyValue = THIS.oIterator.GetFieldValue( ;
        THIS.cChildKeyExpression)
      THIS.ReadRow( m.lnRow)
      THIS.oIterator.MoveNext()
    ENDDO
    FOR ii = 1 TO THIS.nExtraRows
      lnRow = m.lnRow + 1
      THIS.vChildKeyValue = [__] + TRANSFORM(m.ii) + [__]
      THIS.ReadRow( m.lnRow)
    ENDFOR
    THIS.AfterReadInput()
    THIS.lInputRead = .T.
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION ReadRow( lnRow)
    LOCAL loObj
    FOR EACH loObj IN THIS.CONTROLS
      loObj.LoadProperties(m.lnRow)  && flyweight 
      ** loObj.lValueSet = .F. && force re-eval
      loObj.cID       = ""  && because of current cID_ACCESS() strategy
      loObj.cIDSuffix = [_] + TRIM( TRANSFORM( THIS.vChildKeyValue))
      *!* loObj.SelfBind()
    ENDFOR
    FOR EACH loObj IN THIS.CONTROLS
      IF NOT m.loObj.lVisible OR m.loObj.lDisabled
        LOOP
      ENDIF
      IF m.loObj.lAutoReadInput = .F.
        LOOP
      ENDIF

      *!*        IF loObj.lDisabled 
      *!*          *[[ To Do: Under what circumstance could this control
      *!*          * be disabled for some rows and not others? How would
      *!*          * we tell the control? The IF expression above might
      *!*          * require alteration.
      *!*          loObj.StoreProperties( m.lnRow)  && Flyweight implementation.
      *!*          LOOP
      *!*        ENDIF

      ** UPDATE ON BELOW: We now do unequivocal load/save!
      **
      *[[ Do we need a LoadProperties() here??  Since we Store..() 
      *[[ at the end of this method, is there any chance we could overwrite
      *[[ any properties from a previous row's usage of the object?
      *[[ Not sure: this happens before validation, and old value gets re'evaled,
      *[[ but maybe needed at least if we're going to support row-specific
      *[[ disabling later!
      
      loObj.ReadInput()
      IF loObj.lUpdated
        THIS.lUpdated = .T.
      ENDIF
    ENDFOR
    FOR EACH loObj IN THIS.CONTROLS
      *!* UNBINDEVENTS(m.loObj)
      loObj.StoreProperties(m.lnRow, .F.)  && flyweight 
    ENDFOR
  ENDFUNC  && ReadRow
  * ------------------------------------------------------------------- *
  FUNCTION Valid
    * L7Grid::Valid()
    LOCAL llObjectsValid, ii, lnRow
    llObjectsValid = .T.
    lnRow = 0
    THIS.oIterator.MoveFirst()
    DO WHILE NOT THIS.oIterator.EOF
      lnRow = m.lnRow + 1
      THIS.vChildKeyValue = THIS.oIterator.GetFieldValue( ;
        THIS.cChildKeyExpression)
      IF NOT THIS.ValidateRow( m.lnRow)
        llObjectsValid = .F. 
      ENDIF
      THIS.oIterator.MoveNext()
    ENDDO
    FOR ii = 1 TO THIS.nExtraRows
      lnRow = m.lnRow + 1
      THIS.vChildKeyValue = [__] + TRANSFORM(m.ii) + [__]
      IF NOT THIS.ValidateRow( m.lnRow)
        llObjectsValid = .F. 
      ENDIF
    ENDFOR
    THIS.AfterValidateControls()  && hook
    RETURN m.llObjectsValid AND ( THIS.nInvalidCount = 0 )
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
  FUNCTION ValidateRow(lnRow)
    LOCAL loObj, llObjectsValid, llUpdated, llNewRow
    llObjectsValid = .T.
    llNewRow = m.lnRow > THIS.nRows
    * Unequivocal load! Needed so all controls are in-sync, for cross-referencing, etc.
    FOR EACH loObj IN THIS.CONTROLS
      loObj.LoadProperties(m.lnRow)  && Flyweight implementation.
      loObj.cID       = ""  && because of current cID_ACCESS() strategy
      loObj.cIDSuffix = [_] + TRIM( TRANSFORM( THIS.vChildKeyValue))
      *!* loObj.SelfBind()
    ENDFOR

    * For new rows, only validate if anything was specfically entered:
    IF m.llNewRow
      FOR EACH loObj IN THIS.Controls
        IF NOT m.loObj.lVisible OR m.loObj.lDisabled
          LOOP
        ENDIF
        IF loObj.lAutoReadInput = .F.
          LOOP
        ENDIF
        *!* IF loObj.aPropValues[ m.lnRow, L7_CONTROLPROP_UPDATED] && updated
        IF loObj.lUpdated
          llUpdated = .T.
          EXIT
        ENDIF
      ENDFOR
      *!*        IF NOT m.llUpdated
      *!*          RETURN .T.  && EEEK!
      *!*        ENDIF
    ENDIF

    * Now proceed to validate the row:
    IF NOT (m.llNewRow AND NOT m.llUpdated)
      FOR EACH loObj IN THIS.CONTROLS
        IF loObj.lAutoReadInput = .F.
          LOOP
        ENDIF
        IF NOT loObj.lVisible 
          LOOP
        ENDIF
        IF m.loObj.lDisabled
          LOOP
        ENDIF
        IF NOT m.loObj.Valid()
          llObjectsValid = .F.
          THIS.lInvalidControls = .T.
        ENDIF
      ENDFOR
    ENDIF
    
    * Allow non-auto-read controls (collections?) a shot at assembling validation info:
    FOR EACH loObj IN THIS.CONTROLS
      IF NOT loObj.lVisible OR m.loObj.lDisabled
        LOOP
      ENDIF
      IF loObj.lAutoReadInput = .T.
        LOOP  && already done
      ENDIF
      IF NOT m.loObj.Valid()
        llObjectsValid = .F.
        THIS.lInvalidControls = .T.
      ENDIF
    ENDFOR
    
    * Now call end-of-row hook
    IF NOT THIS.RowValid(m.lnRow) 
      llObjectsValid = .F.
    ENDIF

    * Validation *could* have changed the values, even if valid, 
    * such as by altering case or padding. Need to push onto stack:
    FOR EACH loObj IN THIS.CONTROLS
      *!* UNBINDEVENTS(m.loObj)
      loObj.StoreProperties(m.lnRow, .F.)  && flyweight 
    ENDFOR
    
    RETURN m.llObjectsValid 
  ENDFUNC  && ValidateRow
  * ------------------------------------------------------------------- *
  FUNCTION RowValid(lnRow)
    * This is a hook that can be implemented to check the
    * entire row after each element has been validated.
    * You can compare the lnRow parameter to THIS.nRows
    * to determine whether you're looking at previously-existing
    * records:
    *!*      IF m.lnRow <= THIS.nRows  && existing data
    *!*      ELSE  && new rows
    *!*      ENDIF
  ENDFUNC  && RowValid
  * ------------------------------------------------------------------- *
  FUNCTION AfterValidateControls
    * intended for container instances to perform extra
    * validation after each control has been validated
  ENDFUNC  && AfterValidateControls
  * ------------------------------------------------------------------- *
  FUNCTION UpdateControlSources
    * L7Grid::UpdateControlSources()
    LOCAL ii, lnRow
    lnRow = 0
    THIS.oIterator.MoveFirst()
    DO WHILE NOT THIS.oIterator.EOF
      lnRow = m.lnRow + 1
      THIS.vChildKeyValue = THIS.oIterator.GetFieldValue( ;
        THIS.cChildKeyExpression)
      THIS.UpdateRow( m.lnRow)
      THIS.oIterator.MoveNext()
    ENDDO
    FOR ii = 1 TO THIS.nExtraRows
      lnRow = m.lnRow + 1
      THIS.vChildKeyValue = [__] + TRANSFORM(m.ii) + [__]
      THIS.AddRow( m.lnRow)
    ENDFOR
    RETURN 
  ENDFUNC  && UpdateControlSources
  * ------------------------------------------------------------------- *
  FUNCTION AddRow(lnRow)
    LOCAL loObj, llUpdated
    FOR EACH loObj IN THIS.Controls
      IF loObj.lAutoReadInput = .F.
        LOOP
      ENDIF
      IF NOT m.loObj.lVisible OR m.loObj.aPropValues[ m.lnRow, L7_CONTROLPROP_DISABLED]
        * Note: We refer to the array to determine if the
        * item is disabled, rather than forcing all the values
        * back into properties at this time.
        LOOP
      ENDIF
      IF loObj.aPropValues[ m.lnRow, L7_CONTROLPROP_UPDATED] && updated
        llUpdated = .T.
        EXIT
      ENDIF
    ENDFOR
    IF m.llUpdated
      THIS.oIterator.AddNew()
      THIS.UpdateRow( m.lnRow)
    ENDIF
    RETURN m.llUpdated
  ENDFUNC  && AddRow
  * ------------------------------------------------------------------- *
  FUNCTION UpdateRow( lnRow)
    LOCAL loObj, llRetVal
    llRetVal = .T.
    FOR EACH loObj IN THIS.Controls
      IF NOT m.loObj.lVisible  
        LOOP
      ENDIF
      IF loObj.lAutoReadInput = .F.
        LOOP
      ENDIF
      loObj.LoadProperties(m.lnRow)  && Flyweight implementation.
      IF m.loObj.lDisabled
        LOOP
      ENDIF
      loObj.cID       = ""  && because of current cID_ACCESS() strategy
      loObj.cIDSuffix = [_] + TRIM( TRANSFORM( THIS.vChildKeyValue))
      * Delegate to the control:
      IF NOT m.loObj.UpdateControlSources()
        llRetVal = .F.
        EXIT
      ENDIF
    ENDFOR  && EACH control
    RETURN m.llRetVal
  ENDFUNC  && UpdateRow
  * ------------------------------------------------------------------- *
ENDDEFINE  && L7Grid

#if .f.
05/07/2003 - call to RenderLabel quashes <label for> wrapper 
           - column header cell now gets 'scope="col"'
           - changed all "heading" in PEM names to "header" for consistency -- CHECK SUBCLASSES!!
           - inserted <thead>, <tfoot>, and <tbody> as applicable
           - added props: cHeaderRowCssClass = ""
                          cHeaderRowCssStyle = "vertical-align: bottom;"
                          cTableCssStyle
                          cControlCssStyle
                          cPreHeaderText - used in new method BeforeRenderHeaders()
                          cPostControlsText - used in new method AfterRenderHeaders()
                          cRowCssClass    && for alternating-row styles, use comma-delim list (e.g., "OddGridRow,EvenGridRow")
                          cRowCssStyle    &&   - same -
                          cNewRowCssClass && defaults to same as current row
                          cNewRowCssStyle &&   - same -
                          cColumnHeaderCssClass (also added to individual controls to override grid default)
                          cColumnHeaderCssStyle   - same - 
           - changes to accomodate collection object in grid
           - added <caption> support
           - added summary="" support for <table> tag
           - added cControlSource and altered CreateIterator()
           - added support for <th id="xxx"> ... <td headers="xxx"> coordination

08/31/2003 - Fixed issues with grouped controls, including missing </td> and </th> tags.
#endif

* End: L7Grid.PRG
