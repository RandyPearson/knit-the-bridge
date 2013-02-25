* L7TableRender.PRG
*
* Object-oriented, programmatic creation of HTML tables from VFP cursors.

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


* See L7Table.PRG for revision notes.

#INCLUDE L7.H

*** ====================================================== ***
DEFINE CLASS L7TableRender AS CUSTOM
  cCellTag = ""
  cRowTag = ""
  cEmptyContent = ""
  lAllowRepeatSuppression = .T.
  * ---------------------------------------------------------- *
  FUNCTION OpenTable
  ENDFUNC  && OpenTable
  * ---------------------------------------------------------- *
  FUNCTION InsertExtraRow( ii, lnLocation, lnLevel)
    WITH THIS.Parent
      .Write( .aExtraRows[ m.ii].GetOutput( m.lnLocation, m.lnLevel ) )
    ENDWITH
    RETURN
  ENDFUNC  && InsertExtraRow
  * ---------------------------------------------------------- *
  FUNCTION RepeatTableHeader
  ENDFUNC  && RepeatTableHeader
  * ---------------------------------------------------------- *
  FUNCTION BeforeFirstRecord
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION ProcessRecord
    * Template method.
    WITH THIS.Parent
      LOCAL lcText, lcTemp
      * Note that we build the whole record and *then* write
      * it, so we are not adding too many bite-sized pieces to a 
      * long stream.
      lcText = ""
      lcText = m.lcText + THIS.OpenRow() 
      IF .lSimple
        LOCAL loElem
        FOR EACH loElem IN .aElements
          IF loElem.lActive = .F.
            LOOP
          ENDIF
          * avoid recursion/concat bug via 2-step (if tables are nested):
          lcTemp = loElem.Process()
          lcText = m.lcText + m.lcTemp
        ENDFOR
      ELSE
        LOCAL loCol
        FOR EACH loCol IN .aColumns
          IF loCol.lActive = .F.
            LOOP
          ENDIF
          lcTemp = loCol.Process()
          lcText = m.lcText + m.lcTemp
        ENDFOR
      ENDIF
      lcText = m.lcText + THIS.CloseRow()
      .Write( m.lcText )
    ENDWITH
    RETURN
  ENDFUNC  && ProcessRecord
  * ---------------------------------------------------------- *
  FUNCTION ColumnHeadingRow
    * Template method.
    WITH THIS.Parent
      THIS.OpenColumnHeadingRow()
      LOCAL loItem
      IF .lSimple
        FOR EACH loItem IN .aElements
          IF loItem.lActive = .F.
            LOOP
          ENDIF
          THIS.ItemHeading(loItem)
        ENDFOR
      ELSE
        FOR EACH loItem IN .aColumns
          IF loItem.lActive = .F.
            LOOP
          ENDIF
          THIS.ItemHeading(loItem) 
        ENDFOR
      ENDIF
      THIS.CloseColumnHeadingRow()
    ENDWITH
    RETURN
  ENDFUNC  && ColumnHeadingRow
  * ---------------------------------------------------------- *
  FUNCTION OpenRow
    RETURN THIS.Parent.cBeforeFirstColumn  && access method in parent
  ENDFUNC && OpenRow
  * ---------------------------------------------------------- *
  FUNCTION CloseRow
    RETURN THIS.Parent.cAfterLastColumn  && access method in parent
  ENDFUNC && CloseRow
  * ---------------------------------------------------------- *
  FUNCTION GetElement(loElem)
    LOCAL lcText, lnCount, llRepeat, lvVal, lcExpr
    WITH loElem
      * If we're using supression, compare to previous value and decide
      * whether we're dealing with a repeat that should be supressed:
      IF THIS.lAllowRepeatSuppression AND .lSupressRepeats
        IF ISNULL( .vNewValue) OR ISNULL( .vOldValue) OR ;
          .oTable.nGroupRowCount = 1 OR ;
          NOT .vOldValue == .vNewValue
          *
          llRepeat = .F.
        ELSE
          llRepeat = .T.
        ENDIF
        .vOldValue = .vNewValue
      ENDIF

      * Now decide what value we're going to show, based on display type.
      lvVal = .vNewValue
      DO CASE
      CASE .nDisplayType = 2  && running total
        lvVal = IIF( .nResetLevel = 0, .nGrandTotal, ;
          .aGroupTotal[ .nResetLevel - 2] )
        * If it's an AVERAGE, need to divide by running count:
        IF .nCalcType = L7_CALCTYPE_AVG
          lnCount = IIF( .nResetLevel = 0, .nGrandCount, ;
            .aGroupCount[ .nResetLevel - 2] )
          IF m.lnCount > 0 AND VARTYPE( m.lvVal) = "N"
            lvVal = m.lvVal / m.lnCount
          ENDIF
        ENDIF 
      ENDCASE

      * Finally, apply any optional transforming, including
      * replacement strings for NULL and empty values:
      DO CASE
      
      * LIMITATION: If the primary field is NULL, nothing in cDisplayExpression will be invoked, 
      *   because the isnull() CASE comes first. This means if you need to transform a column where
      *   the transform applies to nulls, you need to adjust the element's expression itself, which
      *   may have other issues. 
      * DON'T TRY: changing the order of CASE's below! Many reports will break...
      * ONE POSSIBILITY: some sort of override flag that, in effect, says cDisplayExpression should always rule.
      
      CASE ISNULL( m.lvVal)  && NULL
        IF NOT EMPTY( .cNullDisplay)
          IF LEFT(.cNullDisplay,1) = "="
            TRY
              lcText = EVALUATE(SUBSTR(.cNullDisplay, 2))
            CATCH
              lcText = "Error in " + .cNullDisplay
            ENDTRY 
          ELSE  && static NULL string
            lcText = .cNullDisplay
          ENDIF 
        ELSE
          lcText = TRANSFORM( m.lvVal)  && should honor SET NULLDISPLAY
        ENDIF
      
      CASE m.llRepeat
        lcText = THIS.cEmptyContent
      
      CASE NOT EMPTY( .cDisplayExpression)
        * This CASE comes before "empty" case for a reason--assuming if
        * you create an expression, it is robust. 
        * [2/16/2006 - I don't like this argument. -RP]
        * [8/5/2009 - additional logic added below, after running the expression--best of both worlds]
        LOCAL lcDispExpr, loExc  && so we get debug info
        IF .lDisplayTextmerge
          lcDispExpr = .cDisplayExpression
          lcText = TextMergeX( m.lcDispExpr)
        ELSE
          lcDispExpr = .cDisplayExpression
          TRY
            lcText = EVALUATE(m.lcDispExpr)
            * 8/5/2009, add:
            IF EMPTY(m.lcText) AND NOT EMPTY(.cEmptyDisplay)
              * If expression returns empty text and an alternative is specified we should use it.
              * That way the expression doesn't need to be aware of container (cell) display needs.
              lcText = .cEmptyDisplay
            ENDIF 
            * [[probably should treat nulls this way too?? (currently nulls don't even make it to this CASE)
          CATCH TO loExc
            lcText = "ERR (" + L7ExceptionMessage(m.loExc) + "): " + m.lcDispExpr
          ENDTRY
        ENDIF
      
      CASE EMPTY( m.lvVal) AND NOT EMPTY(.cEmptyDisplay)
        lcText = .cEmptyDisplay
        
      CASE NOT EMPTY( .cFormatString ) && eval string with %1
        ** lcExpr = STRTRAN(.cFormatString, [%1], [m.lvVal])
        lcExpr = STRTRAN(.cFormatString, [%1], TRANSFORM(m.lvVal))
        lcText = EVALUATE(m.lcExpr)

      CASE EMPTY( .cTransform )
        IF VARTYPE( m.lvVal) <> "C"
          lcText = TRANSFORM( m.lvVal)
        ELSE
          lcText = RTRIM( m.lvVal)
        ENDIF
      
      OTHERWISE  && an explicit format is specified
        lcText = TRANSFORM( m.lvVal, .cTransform )
      ENDCASE
      
    ENDWITH
    RETURN m.lcText 
  ENDFUNC  && GetElement
  * ---------------------------------------------------------- *
ENDDEFINE  && L7TableRender 

*** ====================================================== ***
DEFINE CLASS L7TableHtmlRender AS L7TableRender 
  cCellTag = "td"
  cRowTag = "tr"
  cEmptyContent = CHR(38) + "nbsp;"  && non-breaking space
  lBodyOpen = .f.
  * ---------------------------------------------------------- *
  FUNCTION OpenTable
    LOCAL loItem
    WITH THIS.Parent
      .WriteLn( CHR(13) + CHR(10) + [<] + .cRootElement + ;
        IIF( VARTYPE( .nTableBorder) = "N", [ border="] + TRANSFORM( .nTableBorder) + ["], []) + ;
        IIF( EMPTY( .cTableBorderColor), [], [ bordercolor="] + .cTableBorderColor + ["]) + ;
        IIF( VARTYPE( .nTableCellPadding) = "N", [ cellpadding="] + TRANSFORM( .nTableCellPadding) + ["], []) + ;
        IIF( VARTYPE( .nTableCellSpacing) = "N", [ cellspacing="] + TRANSFORM( .nTableCellSpacing) + ["], []) + ;
        IIF( EMPTY( .cTableBgColor), [], [ bgcolor="] + .cTableBgColor + ["] ) + ;
        IIF( EMPTY( .cTableWidth), [], [ width="] + .cTableWidth + ["] ) + ;
        IIF( EMPTY( .cTableAlign), [], [ align="] + .cTableAlign + ["] ) + ;
        IIF( NOT .lUseCss, [], ;
          IIF( EMPTY( .cTableClass), [], [ class="] + .cTableClass + ["] ) + ;
          IIF( EMPTY( .cTableStyle), [], [ style="] + .cTableStyle + ["] ) ;
          ) + ;
        [ id="] + NVL(.cTableID, "tbl_" + SYS(3)) + ["] + ;
        IIF( EMPTY( .cTableSummary), [], [ summary="] + .cTableSummary  + ["] ) + ;
        IIF( EMPTY( .cTableAttributes), [], [ ] + .cTableAttributes ) + ;
        [>] + CHR(13) + CHR(10) )

**        [ cols="] + TRANS( .nActiveColumns) + ["] + 

      * Add a caption, if specified:
      IF NOT EMPTY( .cTableCaption)
        .WriteLn( [<caption] + ;
          IIF( NOT .lUseCss, [], ;
            IIF( EMPTY( .cTableCaptionClass), [], [ class="] + .cTableCaptionClass + ["]) ;
            ) + ;
          IIF( EMPTY( .cTableCaptionAttributes), [], [ ] + .cTableCaptionAttributes) + ;
          [>] + .cTableCaption + [</caption>] + CHR(13) + CHR(10) )
      ENDIF
      
      * Insert <colgroup> and <col> tags.
      IF .F. && some decision on whether to use??
        IF .lEqualWidthColumns
          .WriteLn( [<colgroup ] + ;
            [ span="] + TRANSFORM(.nActiveColumns) + ["] + ;
            [ width="] + TRANSFORM(100/MAX(1,.nActiveColumns)) + [%"] + [>])
          .WriteLn( [</colgroup>])  
        ELSE
          .WriteLn( [<colgroup>])  && should we specify table defaults here??
          FOR EACH loItem IN .aColumns
            IF loItem.lActive = .F.
              LOOP
            ENDIF
            .WriteLn( [<col] + ;
              IIF(VARTYPE(loItem.cWidth)="C", [ width="] + loItem.cWidth + ["], []) + ;
              [>])
          ENDFOR
          
          .WriteLn( [</colgroup>])  
        ENDIF
        
      ENDIF
      .WriteLn([<thead>])
          
      #IF L7_SHAREWARE
        .WriteLn( CHR(13) + CHR(10) + ;
          [<!-- This table was produced by an unlicensed evaluation copy of the Level 7 Components.] + ;
          [ Please contact Cycla Corporation to obtain a licensed copy. -->]  + ;
          CHR(13) + CHR(10)  + CHR(13) + CHR(10) )
      #ENDIF
    ENDWITH  && THIS.Parent
    RETURN
  ENDFUNC  && OpenTable
  * ---------------------------------------------------------- *
  FUNCTION InsertExtraRow( ii, lnLocation, lnLevel)
    WITH THIS.Parent
      .Write( .aExtraRows[ m.ii].GetOutput( m.lnLocation, m.lnLevel ) )
    ENDWITH
    RETURN
  ENDFUNC  && InsertExtraRow
  * ---------------------------------------------------------- *
  FUNCTION TitleRow
    WITH THIS.Parent
      LOCAL lcTitle, lcStr
      IF NOT EMPTY( .cTitle )
         lcTitle = .cTitle
         * Wrap title with attributes:
         IF VARTYPE( .cTitleFontAttributes) = "C" 
           IF "B" $ .cTitleFontAttributes
             lcTitle = [<b>] + m.lcTitle + [</b>]
           ENDIF
           IF "I" $ .cTitleFontAttributes
             lcTitle = [<i>] + m.lcTitle + [</i>]
           ENDIF
           IF "U" $ .cTitleFontAttributes
             lcTitle = [<u>] + m.lcTitle + [</u>]
           ENDIF
        ENDIF
        * See if we need a <font> tag:
        lcStr = IIF( VARTYPE( .cTitleFontColor) = "C", [ color="] + .cTitleFontColor + ["], []) + ;
           IIF( VARTYPE( .cTitleFontFace) = "C", [ face="] + .cTitleFontFace + ["], []) + ;
           IIF( VARTYPE( .cTitleFontSize) = "C", [ size="] + .cTitleFontSize + ["], []) 
        IF NOT EMPTY( m.lcStr)
          lcTitle = [<font] + m.lcStr + [>] + CR + m.lcTitle + [</font>] + CR
        ENDIF
        * Check Style or Class:
        IF .lUseCss
          lcStr = IIF( EMPTY( .cTitleFontClass), [], [ class="] + .cTitleFontClass + ["]) + ;
             IIF( EMPTY( .cTitleFontStyle), [], [ style="] + .cTitleFontStyle + ["]) 
          IF NOT EMPTY( m.lcStr)
            lcTitle = [<span] + m.lcStr + [>] + CR + m.lcTitle + [</span>] + CR
          ENDIF
        ENDIF

        .Write( [<tr><th] + ;
          IIF( NOT .lUseCss, [], ;
            IIF( EMPTY( .cTitleClass), [], [ class="] + .cTitleClass + ["] ) + ;
            IIF( EMPTY( .cTitleStyle), [], [ style="] + .cTitleStyle + ["] ) ;
            ) + ;
           [ colspan=] + TRANS( .nActiveColumns) + ;
           IIF( VARTYPE( .cTitleBgColor) = "C", [ bgcolor="] + .cTitleBgColor + ["], []) + ;
           IIF( VARTYPE( .cTitleAlign) = "C", [ align="] + .cTitleAlign + ["], []) + ;
           [>] + ;
           m.lcTitle + ;
          [</td></th>] + CHR(13) + CHR(10) )
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC  && TitleRow
  * ---------------------------------------------------------- *
  FUNCTION RepeatTableHeader
    * Doesn't work, problem with multiple THEAD
    THIS.ColumnHeadingRow()
    RETURN
  ENDFUNC  && RepeatTableHeader
  * ---------------------------------------------------------- *
  FUNCTION OpenColumnHeadingRow
    WITH THIS.Parent
      .WriteLn( [<tr] + ;
        IIF( EMPTY( .cHeadingRowBgColor), [], [ bgcolor="] + .cHeadingRowBgColor + ["] ) + ;
        IIF( EMPTY( .cHeadingRowValign), [], [ valign="] + .cHeadingRowValign + ["] ) + ;
        IIF( NOT .lUseCss, [], ;
          IIF( EMPTY( .cHeadingRowClass), [], [ class="] + .cHeadingRowClass + ["] ) + ;
          IIF( EMPTY( .cHeadingRowStyle), [], [ style="] + .cHeadingRowStyle + ["] ) ;
          ) + ;
        [>] )
    ENDWITH
    RETURN
  ENDFUNC  && OpenColumnHeadingRow
  * ---------------------------------------------------------- *
  FUNCTION CloseColumnHeadingRow
    WITH THIS.Parent
      .WriteLn( [</tr>] + CHR(13) + CHR(10) )
    ENDWITH
    RETURN
  ENDFUNC  && CloseColumnHeadingRow
  * ---------------------------------------------------------- *
  FUNCTION ItemHeading(loItem)
    WITH loItem
      LOCAL lcTag, lcStr
      * Use a TH tag unless otherwise specified:
      lcTag = IIF( EMPTY( .cHeadingTag), [th], .cHeadingTag )

      IF LOWER(m.lcTag) <> [th] AND VARTYPE( .cHeadingAlign) <> "C"
        * Non-TH cells are not centered by default. Adjust this.
        .cHeadingAlign = "center"
      ENDIF
      * Now create the entire heading with opening and closing elements:
      * [NOTE: More is going on here than it may appear! The cHeading property uses
      * an ACCESS method which accumulates heading properties from any contained
      * element properties.]

      ** need some unqiue ID--this isn't:
      **  [ id="] + THIS.Parent.Name + "_" + m.loItem.Name + ["] +
      lcStr = .cHeading
      
      lcStr = [<] + m.lcTag + ;
        IIF( VARTYPE( .cWidth) = "C", ;
          [ width="] + .cWidth + ["], []) + ;
        IIF( VARTYPE( .cHeadingBgColor) = "C", ;
          [ bgcolor="] + .cHeadingBgColor + ["], []) + ;
        IIF( VARTYPE( .cHeadingAlign) = "C", ;
          [ align="] + .cHeadingAlign + ["], []) + ;
        IIF( NOT .oTable.lUseCss, [], ;
          IIF( EMPTY( .cHeadingClass), [], [ class="] + .cHeadingClass + ["]) + ;
          IIF( EMPTY( .cHeadingStyle), [], [ style="] + .cHeadingStyle + ["]) ;
          ) + ;
        [>] + m.lcStr + [</] + m.lcTag + [>]
    ENDWITH
    THIS.Parent.WriteLn( m.lcStr)
    RETURN
  ENDFUNC  && ItemHeading
  * ---------------------------------------------------------- *
  function WrapColumnHeading(loItem, lcText)
    * called from cHeading_ACCESS method in L7TableColumn
    with loItem
      
      * deprecated FONT tag approach:
      if vartype(.cHeadingFontColor) = "C" or vartype(.cHeadingFontFace) = "C" OR ;
        vartype(.cHeadingFontSize) = "C" or ;
        vartype(.cHeadingFontClass) = "C" or vartype(.cHeadingFontStyle) = "C" 
        * at least one FONT property
        lcText = [<font] + ;
          iif(vartype(.cHeadingFontClass) = "C" and !empty(.cHeadingFontClass), ;
            [ class="] + .cHeadingFontClass + ["], []) + ;
          iif(vartype(.cHeadingFontStyle) = "C" and !empty(.cHeadingFontStyle), ;
            [ style="] + .cHeadingFontStyle + ["], []) + ;
          iif(vartype(.cHeadingFontColor) = "C" and !empty(.cHeadingFontColor), ;
            [ color="] + .cHeadingFontColor + ["], []) + ;
          iif(vartype(.cHeadingFontSize) = "C" and !empty(.cHeadingFontSize), ;
            [ size="] + .cHeadingFontSize + ["], []) + ;
          iif(vartype(.cHeadingFontFace) = "C" and !empty(.cHeadingFontFace), ;
            [ face="] + .cHeadingFontFace + ["], []) + ;
          [>] + m.lcText + [</font>]
      endif
      
      * deprecated wrap attributes:
      if vartype(.cHeadingFontAttributes) = "C" 
        if "B" $ .cHeadingFontAttributes
          lcText = [<b>] + m.lcText + [</b>]
        endif
        if "I" $ .cHeadingFontAttributes
          lcText = [<i>] + m.lcText + [</i>]
        endif
        if "U" $ .cHeadingFontAttributes
          lcText = [<u>] + m.lcText + [</u>]
        endif
      endif
      
    endwith 
    return  m.lcText
  endfunc && WrapColumnHeading
  * ---------------------------------------------------------- *
  FUNCTION BeforeFirstRecord
    LOCAL lcStr
    WITH this.Parent
      .WriteLn([</thead>])
      this.lBodyOpen = .t.
      lcStr = [<tbody] + ;
        IIF(EMPTY(.cBodyClass), [], [ class="] + .cBodyClass + ["]) + ;
        IIF(EMPTY(.cBodyStyle), [], [ style="] + .cBodyStyle + ["]) + ;
        [>]
      .WriteLn(m.lcStr)
    ENDWITH 
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION CloseTable
    WITH THIS.Parent
      if this.lBodyOpen
        .WriteLn([</tbody>])
        this.lBodyOpen = .f.
      endif 
      .WriteLn([</] + .cRootElement + [>] + CHR(13) + CHR(10) )
    ENDWITH
    RETURN
  ENDFUNC  && CloseTable
  * ---------------------------------------------------------- *
  FUNCTION GroupHeader(ii)
    LOCAL lcText, lcGroupValue
    WITH THIS.Parent
      IF .aGroups[ m.ii].lHeaderRow
        IF NOT EMPTY( .aGroups[ m.ii].cDisplayExpression )
          lcGroupValue = .aGroups[ m.ii].cDisplayValue
        ELSE
          lcGroupValue = TRANS( .aGroups[ m.ii].vValue )
        ENDIF
        lcText = ""
        lcText = m.lcText + ;
          [<tr] + ;
            IIF( EMPTY( .aGroups[ m.ii].cHeaderRowClass), [], ;
              [ class="] + .aGroups[ m.ii].cHeaderRowClass + ["]) + ;
          [>] + CRLF + ;
          [<td colspan="] + TRANSFORM(.nActiveColumns) + [">] + m.lcGroupValue + ;
          [</td>] + CRLF + ;
          [</tr>]
        .Write( m.lcText)
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC  && GroupHeader
  * ---------------------------------------------------------- *
  FUNCTION GroupFooter(ii)
    LOCAL lcText, lcGroupValue, lnColCount, lnConsumedByColspan, loGrp
    lnColCount = 0
    lnConsumedByColspan = 0
    WITH THIS.Parent
      loGrp = .aGroups[ m.ii]
      IF NOT EMPTY( loGrp.cDisplayExpression )
        lcGroupValue = loGrp.cDisplayValue
      ELSE
        lcGroupValue = TRANSFORM(loGrp.vValue )
      ENDIF

      lcText = ""

      * -- Special case where we need a label, but all columns are "used up"
      * -- with their own group total display needs:
      IF NOT EMPTY( loGrp.cTotalText )
        * Some text is specified, such as "Totals:". 
        IF .nFooterTextColumn = -1
          * No space found, so insert special row:
          lcText = m.lcText + [<tr><td align="left" colspan="] + ;
            TRANSFORM(.nActiveColumns) + ["] + ;
            IIF( EMPTY( loGrp.cFooterRowClass), [], ;
              [ class="] + loGrp.cFooterRowClass + ["]) + ;
            IIF( EMPTY( loGrp.cFooterRowStyle), [], ;
              [ style="] + loGrp.cFooterRowStyle + ["]) + ;
            [>] + ;
            IIF(loGrp.lValueInFooter, m.lcGroupValue + [ ], []) + ;
            loGrp.cTotalText + ;
            [</td></tr>] + CRLF
        ENDIF
      ENDIF

      lcText = m.lcText + [<tr] + ;
        IIF( VARTYPE( loGrp.cValign) = "C", ;
          [ valign="] + loGrp.cValign + ["], []) + ;
        IIF( VARTYPE( loGrp.cRowBgColor) = "C", ;
          [ bgcolor="] + loGrp.cRowBgColor + ["], []) + ;
        IIF( NOT .lUseCss, [], ;
          IIF( VARTYPE( loGrp.cRowClass) = "C", ;
            [ class="] + loGrp.cRowClass + ["], []) + ;
          IIF( VARTYPE( loGrp.cRowStyle) = "C", ;
            [ style="] + loGrp.cRowStyle + ["], []) ;
          ) + ;
         [>] + CHR(13) + CHR(10)
         
      FOR EACH loCol IN .aColumns
        IF loCol.lActive = .F.
          LOOP
        ENDIF
        lnColCount = m.lnColCount + 1
        IF m.lnConsumedByColspan > 0
          lnConsumedByColspan = m.lnConsumedByColspan - 1
          LOOP
        ENDIF
        
        IF (.lSimple AND loCol.nCalcType = L7_CALCTYPE_NONE) ;
          OR ;
          (NOT .lSimple AND loCol.nCalcElements = 0)
          * This column has no data requirements for group footer row. See if it
          * can be used for group label instead:
          IF NOT EMPTY( loGrp.cTotalText ) AND .nFooterTextColumn = m.lnColCount
            * This column is available for showing group label.
            lcText = m.lcText + [<td] + ;
              IIF( VARTYPE( loGrp.cLabelClass) = "C", [ class="] + loGrp.cLabelClass + ["], []) + ;  && was hardcoded "groupFooterLabel"
              IIF( VARTYPE( loGrp.cLabelStyle) = "C", [ style="] + loGrp.cLabelStyle + ["], []) + ;  
              [ colspan="] + TRANSFORM(.nFooterTextColspan ) + ["] + ;
              [><span>] + ;
              IIF(loGrp.lValueInFooter, m.lcGroupValue + [ ], []) + ;
              loGrp.cTotalText + [</span></td>] + CHR(13) + CHR(10)
            
            IF .nFooterTextColspan > 1
              * Colspan available for string. Reserve the space to extra TDs are not written.
              lnConsumedByColspan = .nFooterTextColspan - 1
            ENDIF
          ELSE  && this column has no group footer content
            lcText = m.lcText + [<td>&nbsp;</td>] + CHR(13) + CHR(10)
          ENDIF
        
        ELSE && This column has data requirements for group footer.
          lcText = m.lcText + [<td] + ;
            IIF( VARTYPE( loCol.cAlign) = "C", [ align="] + loCol.cAlign + ["], [] ) + ;
            IIF( VARTYPE( loCol.cCellClass) = "C", [ class="] + loCol.cCellClass + ["], [] ) + ;
            IIF( VARTYPE( loCol.cCellStyle) = "C", [ style="] + loCol.cCellStyle + ["], [] ) + ;
            IIF( VARTYPE( loGrp.cCellBgColor) = "C", [ bgcolor="] + loGrp.cCellBgColor + ["], [] ) + ;
              [>]

          IF .lSimple
            IF loCol.nCalcType > L7_CALCTYPE_NONE
              lcText = m.lcText + THIS.GetElemGroupFooter( loCol, m.ii )
            ENDIF  && loElem.nCalcType > L7_CALCTYPE_NONE
          ELSE
            FOR EACH loElem IN m.loCol.aElements
              IF loElem.nCalcType > L7_CALCTYPE_NONE
                lcText = m.lcText + THIS.GetElemGroupFooter( loElem, m.ii)
              ENDIF  && loElem.nCalcType > L7_CALCTYPE_NONE
              
            ENDFOR  && EACH loElem IN m.loCol.aElements
          ENDIF
          
          lcText = m.lcText + [</td>] + CHR(13) + CHR(10)
        ENDIF  && loCol.nCalcElements = 0
        
      ENDFOR  && EACH loCol IN .aColumns
      lcText = m.lcText + [</tr>] + CHR(13) + CHR(10)
      
      .Write( m.lcText )
    ENDWITH
    RETURN
  ENDFUNC  && GroupFooter
  * --------------------------------------------------------- *
  FUNCTION GetElemGroupFooter(loElem, ii)
    WITH THIS.Parent
      LOCAL llCount, lvVal, lcElemText, loGrp
      loGrp = .aGroups[m.ii]
      llCount = loElem.nCalcType = L7_CALCTYPE_COUNT
      IF m.llCount
        lvVal = NVL(loElem.aGroupTotal[ m.ii], 0)
      ELSE
        lvVal = loElem.aGroupTotal[ m.ii]
        IF loElem.nCalcType = L7_CALCTYPE_AVG 
          IF VARTYPE( m.lvVal) $ "NIYBD" AND loElem.aGroupCount[ m.ii] > 0
            lvVal = m.lvVal / loElem.aGroupCount[ m.ii]
          ENDIF
        ENDIF
      ENDIF
      IF NOT m.llCount AND VARTYPE(loElem.cTransform) = "C"
        *[[ really we should allow some group-element transform
        lcElemText = TRANSFORM( m.lvVal, loElem.cTransform )
      ELSE
        lcElemText = TRANSFORM( m.lvVal )
      ENDIF
      IF VARTYPE( loGrp.cFontAttributes) = "C" 
        IF "B" $ loGrp.cFontAttributes
          lcElemText = [<b>] + m.lcElemText + [</b>] 
        ENDIF
        IF "I" $ loGrp.cFontAttributes
          lcElemText = [<i>] + m.lcElemText + [</i>] 
        ENDIF
        IF "U" $ loGrp.cFontAttributes
          lcElemText = [<u>] + m.lcElemText + [</u>] 
        ENDIF
      ENDIF
      IF VARTYPE( loGrp.cFontColor) = "C"
        lcElemText = [<font color="] + loGrp.cFontColor + [">] + ;
          m.lcElemText + [</font>] 
      ENDIF
      IF .lUseCss AND ( ;
        NOT EMPTY( loGrp.cFontClass) OR ;
        NOT EMPTY( loGrp.cFontStyle) )
        *
        lcElemText = [<span] + ;
          IIF( EMPTY( loGrp.cFontClass), ;
            [], [ class="] + loGrp.cFontClass + ["] ) + ;
          IIF( EMPTY( loGrp.cFontStyle), ;
            [], [ style="] + loGrp.cFontStyle + ["] ) + ;
          [>] + m.lcElemText + [</span>]
      ENDIF
    ENDWITH
    RETURN m.lcElemText
  ENDFUNC  && GetElemGroupFooter           
  * ---------------------------------------------------------- *
  FUNCTION OnZeroRecords
    WITH THIS.Parent
      IF NOT EMPTY( .cZeroRecordString )
        LOCAL lcText
        IF .lZeroRecordTable  && render inside table, as a spanned cell
          lcText = [<tr><td align=center colspan=] + TRANS( .nActiveColumns) + [>] + ;
            [<span class="] + .cZeroRecordMessageClass + [">] + ;
            .cZeroRecordString + [</span></td></tr>] + CHR(13) + CHR(10)
        ELSE  && no table
          lcText = [<div class="] + .cZeroRecordMessageClass + [">] + ;
            .cZeroRecordString + [</div>] + CHR(13) + CHR(10)
        ENDIF 
        .Write( m.lcText )
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC  && OnZeroRecords
  * ---------------------------------------------------------- *
  FUNCTION GrandTotals
    LOCAL lcText, lcLabel, loCol, loElem, lcElemText, lvVal, ;
      lnColCount, lnConsumedByColspan, lcRowAttr, lcLabelAttr
    lnColCount = 0
    lnConsumedByColspan = 0
    
    WITH THIS.Parent

      if this.lBodyOpen
        .WriteLn([</tbody>])
        this.lBodyOpen = .f.
      endif 
      .WriteLn([<tfoot>])

      lcRowAttr = ;
        IIF( VARTYPE( .cGrandValign) = "C", [ valign="] + .cGrandValign + ["], []) + ;
        IIF( VARTYPE( .cGrandRowBgColor) = "C", [ bgcolor="] + .cGrandRowBgColor + ["], []) + ;
        IIF( VARTYPE( .cGrandRowClass) = "C", [ class="] + .cGrandRowClass + ["], []) + ;
        IIF( VARTYPE( .cGrandRowStyle) = "C", [ sytle="] + .cGrandRowStyle + ["], []) 
      lcLabelAttr = ;
        IIF( VARTYPE( .cGrandLabelClass) = "C", [ class="] + .cGrandLabelClass + ["], []) + ;  
        IIF( VARTYPE( .cGrandLabelStyle) = "C", [ style="] + .cGrandLabelStyle + ["], [])

      lcText = ""
      lcLabel = "" 
      IF NOT EMPTY( .cGrandTotalText ) && text is specified (e.g. "Grand Totals:") 
        lcLabel = [<span>] + .cGrandTotalText + [</span>] 
        IF .nFooterTextColumn = -1 && no Hz space found, so insert special row:
          lcText = m.lcText + [<tr] + m.lcRowAttr + [>] + ;
            [<td colspan="] + TRANSFORM(.nActiveColumns) + ["] + m.lcLabelAttr + ;
            [>] + m.lcLabel + [</td></tr>] + CRLF
        ENDIF
      ENDIF
      * Grand row:
      lcText = m.lcText + [<tr] + m.lcRowAttr + [>] + CHR(13) + CHR(10)

      * See GroupFooter method for logic explanation.
      FOR EACH loCol IN .aColumns
        IF loCol.lActive = .F.
          LOOP
        ENDIF
        lnColCount = m.lnColCount + 1
        IF m.lnConsumedByColspan > 0
          lnConsumedByColspan = m.lnConsumedByColspan - 1
          LOOP
        ENDIF
        IF .lSimple AND loCol.nCalcType = L7_CALCTYPE_NONE OR ;
          NOT .lSimple AND loCol.nCalcElements = 0
          *
          IF NOT EMPTY( .cGrandTotalText ) AND .nFooterTextColumn = m.lnColCount
            * Here is open column where label text can go:
            lcText = m.lcText + [<td colspan="] + TRANSFORM(.nFooterTextColspan) + ["] + m.lcLabelAttr + ;
              [>] + m.lcLabel + [</td>]
              
            IF .nFooterTextColspan > 1
              * Colspan available for string. Reserve the space to extra TDs are not written.
              lnConsumedByColspan = .nFooterTextColspan - 1
            ENDIF
          ELSE  && unoccupied cell in grand footer
            lcText = m.lcText + [<td>&nbsp;</td>] + CHR(13) + CHR(10)
          ENDIF
        ELSE  && actual data total for column
          lcText = m.lcText + [<td] + ;
            IIF( VARTYPE( loCol.cAlign) = "C", [ align="] + loCol.cAlign + ["], [] ) + ;
            IIF( VARTYPE( loCol.cCellClass) = "C", [ class="] + loCol.cCellClass + ["], [] ) + ;
            IIF( VARTYPE( loCol.cCellStyle) = "C", [ style="] + loCol.cCellStyle + ["], [] ) + ;
            IIF( VARTYPE( .cGrandCellBgColor) = "C", [ bgcolor="] + .cGrandCellBgColor + ["], [] ) + ;
              [>]

          IF .lSimple
            IF loCol.nCalcType > L7_CALCTYPE_NONE
              lcText = m.lcText + THIS.GetElemGrandTotal( m.loCol )
            ENDIF
          ELSE
            FOR EACH loElem IN m.loCol.aElements
              IF loElem.nCalcType > L7_CALCTYPE_NONE
                lcText = m.lcText + THIS.GetElemGrandTotal( m.loElem )
              ENDIF
            ENDFOR
          ENDIF
          lcText = m.lcText + [</td>] + CHR(13) + CHR(10)
        ENDIF
      ENDFOR
      lcText = m.lcText + [</tr>] + CHR(13) + CHR(10)
      
      .Write( m.lcText )
      .WriteLn([</tfoot>])
    ENDWITH
    RETURN
  ENDFUNC  && GrandTotals
  * --------------------------------------------------------- *
  FUNCTION GetElemGrandTotal(loElem)
    LOCAL lvVal, lcElemText, llCount
    lvVal = loElem.GetGrandTotal()
    WITH THIS.Parent
      IF NOT loElem.nCalcType = L7_CALCTYPE_COUNT AND VARTYPE( loElem.cTransform) = "C"
        lcElemText = TRANSFORM( m.lvVal, loElem.cTransform )
      ELSE
        lcElemText = TRANSFORM( m.lvVal )
      ENDIF
      IF VARTYPE( .cGrandFontAttributes) = "C" 
        IF "B" $ .cGrandFontAttributes
          lcElemText = [<b>] + m.lcElemText + [</b>] 
        ENDIF
        IF "I" $ .cGrandFontAttributes
          lcElemText = [<i>] + m.lcElemText + [</i>] 
        ENDIF
        IF "U" $ .cGrandFontAttributes
          lcElemText = [<u>] + m.lcElemText + [</u>] 
        ENDIF
      ENDIF
      IF VARTYPE( .cGrandFontColor) = "C"
        lcElemText = [<font color="] + .cGrandFontColor + [">] + ;
          m.lcElemText + [</font>] 
      ENDIF
      IF .lUseCss AND ( ;
        NOT EMPTY( .cGrandFontClass) OR ;
        NOT EMPTY( .cGrandFontStyle) )
        *
        lcElemText = [<span] + ;
          IIF( EMPTY( .cGrandFontClass), ;
            [], [ class="] + .cGrandFontClass + ["] ) + ;
          IIF( EMPTY( .cGrandFontStyle), ;
            [], [ style="] + .cGrandFontStyle + ["] ) + ;
          [>] + m.lcElemText + [</span>]
      ENDIF
    ENDWITH
    RETURN m.lcElemText
  ENDFUNC  && GetElemGrandTotal
  * ---------------------------------------------------------- *
  FUNCTION WritePageLinks
    LOCAL lcText, ii
    lcText = ""
    WITH THIS.Parent
      DO CASE
      CASE .nPage_AutoGeneration = 1  && simple previous/next

      CASE .nPage_AutoGeneration = 2  && one link per page
        lcText = m.lcText + .cPage_PageLabel
        FOR ii = 1 TO .nPage_TotalPages
          IF m.ii = .nPage_ShowPage  && current page
            lcText = m.lcText + '<b>[' + TRANS( m.ii) + ']</b> '
          ELSE
            lcText = m.lcText + '<a href="' + .aPage_URLs[ m.ii] + ;
              '">[' + TRANS( m.ii) + ']</A> '
          ENDIF
        ENDFOR
      ENDCASE
      lcText = [<tr><td align=center colspan=] + TRANS( .nActiveColumns) + ;
        [>] + m.lcText + [</td></tr>]
        
      .Write( m.lcText )
    ENDWITH
    RETURN
  ENDFUNC  && WritePageLinks
  * ---------------------------------------------------------- *
  FUNCTION GetExtraRow( loRow, pnLocation, pnGroup)
    LOCAL lcText
    WITH loRow
      lcText = ""
      lcText = m.lcText + [<tr] + ;
        IIF( VARTYPE( .cRowClass) = "C", ;
          [ class="] + .cRowClass + ["], [] ) + ;
        IIF( VARTYPE( .cRowStyle) = "C", ;
          [ style="] + .cRowStyle + ["], [] ) + ;
        IIF( VARTYPE( .cValign) = "C", ;
          [ valign="] + .cValign + ["], [] ) + ;
        IIF( VARTYPE( .cBgColor) = "C", ;
          [ bgcolor="] + .cBgColor + ["], [] ) + ;
        [>] + CR
      lcText = m.lcText + [<td] + ;
        IIF( VARTYPE( .cCellClass) = "C", ;
          [ class="] + .cCellClass + ["], [] ) + ;
        IIF( VARTYPE( .cCellStyle) = "C", ;
          [ style="] + .cCellStyle + ["], [] ) + ;
        IIF( VARTYPE( .cAlign) = "C", ;
          [ align="] + .cAlign + ["], [] ) + ;
        [ colspan=] + TRANS( .oTable.nActiveColumns ) + ;
        [>] + CR

      DO CASE
      CASE VARTYPE( .cDynamicText) = "C"
        lcText = m.lcText + TRANS( EVAL( .cDynamicText ))
      CASE VARTYPE( .cText) = "C"
        lcText = m.lcText + .cText
      OTHERWISE
        lcText = m.lcText + "<b><i>Special Row at Location " + TRANS( m.pnLocation ) + " [no content]</b></i>"
      ENDCASE
      lcText = m.lcText + [</td></tr>]
    ENDWITH
    RETURN m.lcText
  ENDFUNC  && GetExtraRow
  * ---------------------------------------------------------- *
  FUNCTION PreProcessCellTags(loItem)
    * Handles either a column (complex table) or an element (simple table).
    
    * Now we'll also deal with the TD wrapper, since in a simple table 
    * there is no separate column object that contains the element object:
    LOCAL lcText1, lcText2
    lcText1 = '[<' + THIS.cCellTag + ']'
    lcText2 = '[</' + THIS.cCellTag + '>]+CHR(13)+CHR(10)'

    WITH loItem
      IF VARTYPE( .cAlign) = "C" AND NOT EMPTY( .cAlign)
        lcText1 = m.lcText1 + '+[ align="' + .cAlign + '"]'
      ENDIF
      IF .oTable.lUseCss 
        IF VARTYPE( .cCellClass) = "C" AND NOT EMPTY( .cCellClass )
          IF "(" $ .cCellClass  && dynamic CSS class name
            lcText1 = m.lcText1 + '+[ class="]+' + .cCellClass + '+["]'
          ELSE  && static CSS class name
            lcText1 = m.lcText1 + '+[ class="' + .cCellClass + '"]'
          ENDIF
        ENDIF
        IF VARTYPE( .cCellStyle ) = "C" AND NOT EMPTY( .cCellStyle )
          IF "(" $ .cCellStyle  && dynamic CSS style
            lcText1 = m.lcText1 + '+[ style="]+' + .cCellStyle + '+["]'
          ELSE  && static CSS style
            lcText1 = m.lcText1 + '+[ style="' + .cCellStyle + '"]'
          ENDIF
        ENDIF
      ENDIF
      IF VARTYPE( .cBgColor) = "C" AND NOT EMPTY( .cBgColor)
        IF "(" $ .cBgColor && dynamic background color 
          lcText1 = m.lcText1 + '+[ bgcolor="]+' + .cBgColor + '+["]'
        ELSE  && static background color 
          lcText1 = m.lcText1 + '+[ bgcolor="' + .cBgColor + '"]'
        ENDIF
      ENDIF

      lcText1 = m.lcText1 + '+[>]'

      .cBeforeTags = m.lcText1 + [+] + .cBeforeTags
      .cAfterTags  = .cAfterTags + [+] + m.lcText2
    ENDWITH
    RETURN 
  ENDFUNC  && PreProcessCellTags
  * ---------------------------------------------------------- *
  FUNCTION PreProcessElementTags(loItem)
    LOCAL lcText1, lcText2, lcFontText
    lcText1 = '""'
    lcText2 = '""'
    WITH loItem
      * Check FONT Face, Size and Color to see if we need a FONT tag:
      lcFontText = ""
      IF VARTYPE( .cFontColor) = "C" AND NOT EMPTY( .cFontColor)
        IF "(" $ .cFontColor  && Expression - need to EVAL for each record!
          lcFontText = m.lcFontText + '+[ color="]+' + .cFontColor + '+["]'
        ELSE
          lcFontText = m.lcFontText + '+[ color="' + .cFontColor + '"]'
        ENDIF
      ENDIF
      IF VARTYPE( .cFontFace) = "C" AND NOT EMPTY( .cFontFace)
        IF "(" $ .cFontFace  && Expression - need to EVAL for each record!
          lcFontText = m.lcFontText + '+[ face="]+' + .cFontFace + '+["]'
        ELSE
          lcFontText = m.lcFontText + '+[ face="' + .cFontFace + '"]'
        ENDIF
      ENDIF
      IF VARTYPE( .cFontSize) = "C" AND NOT EMPTY( .cFontSize)
        IF "(" $ .cFontSize  && Expression - need to EVAL for each record!
          lcFontText = m.lcFontText + '+[ size="]+' + .cFontSize + '+["]'
        ELSE
          lcFontText = m.lcFontText + '+[ size="' + .cFontSize + '"]'
        ENDIF
      ENDIF
      IF .oTable.lUseCss 
        IF VARTYPE( .cFontClass) = "C" AND NOT EMPTY( .cFontClass)
          IF "(" $ .cFontClass  && Expression - need to EVAL for each record!
            lcFontText = m.lcFontText + '+[ class="]+' + .cFontClass + '+["]'
          ELSE
            lcFontText = m.lcFontText + '+[ class="' + .cFontClass + '"]'
          ENDIF
        ENDIF
        IF VARTYPE( .cFontStyle) = "C" AND NOT EMPTY( .cFontStyle)
          IF "(" $ .cFontStyle  && Expression - need to EVAL for each record!
            lcFontText = m.lcFontText + '+[ style="]+' + .cFontStyle + '+["]'
          ELSE
            lcFontText = m.lcFontText + '+[ style="' + .cFontStyle + '"]'
          ENDIF
        ENDIF
      ENDIF
      IF NOT EMPTY( m.lcFontText)
        lcText1 = m.lcText1 + '+[<font]' + m.lcFontText + '+[>]'
        lcText2 = '[</font>]+' + m.lcText2
      ENDIF

      * Bold and italics, if requested:
      IF VARTYPE( .cFontAttributes ) = "C" AND NOT EMPTY( .cFontAttributes )
        IF "(" $ .cFontAttributes  && Expression - need to EVAL for each record!
          lcText1 = m.lcText1 + '+IIF([B]$' + .cFontAttributes + ',[<b>],[])'
          lcText2 = 'IIF([B]$' + .cFontAttributes + ',[</b>],[])+' + m.lcText2
          lcText1 = m.lcText1 + '+IIF([I]$' + .cFontAttributes + ',[<i>],[])'
          lcText2 = 'IIF([I]$' + .cFontAttributes + ',[</i>],[])+' + m.lcText2
          lcText1 = m.lcText1 + '+IIF([U]$' + .cFontAttributes + ',[<u>],[])'
          lcText2 = 'IIF([U]$' + .cFontAttributes + ',[</u>],[])+' + m.lcText2
        ELSE  && Static attributes.
          IF "B" $ .cFontAttributes
            lcText1 = m.lcText1 + '+[<b>]'
            lcText2 = '[</b>]+' + m.lcText2 
          ENDIF
          IF "I" $ .cFontAttributes
            lcText1 = m.lcText1 + '+[<i>]'
            lcText2 = '[</i>]+' + m.lcText2 
          ENDIF
          IF "U" $ .cFontAttributes
            lcText1 = m.lcText1 + '+[<u>]'
            lcText2 = '[</u>]+' + m.lcText2 
          ENDIF
        ENDIF
      ENDIF

      .cBeforeTags = m.lcText1
      .cAfterTags  = m.lcText2

      IF VARTYPE( .cPrefix) <> "C"
        .cPrefix = ""
      ENDIF
      IF VARTYPE( .cSuffix) <> "C"
        .cSuffix = ""
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC  && PreProcessElementTags
  * ---------------------------------------------------------- *
  FUNCTION GetElement(loElem)
    LOCAL lcText, lcLinkText, lvVal
    * First, call abstract class behavior:
    lcText = DODEFAULT( m.loElem)
    * Then apply and specific transformations:
    WITH loElem
      lvVal = .vNewValue
      * Optional memo handling:        
      IF .cDataType = "M" and!isnull(m.lvVal) and EMPTY(.cDisplayExpression)
        * 04/06/2012 - added isnull() check above, because
        * default behavior handles null transforms (bug caused by 
        * this code originating before null memo's were in use)
        IF .nMemoTranslation = 0 OR .nMemoTranslation = 1 AND ;
          ( m.lvVal = "<" OR "<p>" $ UPPER( m.lvVal ) )
          *
          lcText = m.lvVal
        ELSE
          lcText = STRTRAN( STRTRAN( m.lvVal, ;
            CHR(13) + CHR(10) + CHR(13) + CHR(10), [<P>] ), ;
            CHR(13) + CHR(10), [<br>] )
        ENDIF
      ENDIF  
      * Dynamic and static hyperlinks:
      IF INLIST( .nType, L7_ELEMENTTYPE_STATIC_HYPERLINK, L7_ELEMENTTYPE_DYNAMIC_HYPERLINK) AND ;
        NOT ISNULL( m.lvVal ) AND NOT EMPTY( m.lvVal ) && hyperlink
        * Get the display portion of the link:
        DO CASE
        CASE NOT EMPTY( .cDynamicLinkText )
          lcLinkText = RTRIM( TRANSFORM( EVAL( .cDynamicLinkText )))
        CASE NOT EMPTY( .cLinkText)
          lcLinkText = .cLinkText
        OTHERWISE  && force to literal URL
          lcLinkText = m.lcText
        ENDCASE
        * Optional no-break handling (experimental 01/10/2002):
        IF .lNoBR
          lcLinkText = [<nobr>] + m.lcLinkText + [</nobr>]
        ENDIF
        * Now wrap the text and link in the A element tags:
        lcText = [<a href="] + m.lcText + ["] + ;
          IIF( EMPTY( .cLinkAttributes), [], [ ] + .cLinkAttributes ) + ;
          [>] + m.lcLinkText + [</a>]
      ELSE
        * Optional no-break handling (experimental 01/10/2002):
        IF .lNoBR
          lcText = [<nobr>] + m.lcText + [</nobr>]
        ENDIF
      ENDIF
    ENDWITH
    RETURN m.lcText 
  ENDFUNC  && GetElement
  * ---------------------------------------------------------- *
ENDDEFINE  && L7TableHtmlRender 


*** ====================================================== ***
DEFINE CLASS L7TableExcelXmlRender AS L7TableRender 
  cCellTag = "Cell"
  cRowTag = "Row"
  cEmptyContent = ""
  * ---------------------------------------------------------- *
  FUNCTION OpenTable
    LOCAL lcText
    lcText = ""
    WITH THIS.Parent

TEXT TO lcText ADDITIVE TEXTMERGE NOSHOW    
<?xml version="1.0" encoding="ISO-8859-1" ?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
 <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">
  <Author>L7 Framework</Author>
  <LastAuthor>L7 Framework</LastAuthor>
  <Version>10.3501</Version>
 </DocumentProperties>
 <OfficeDocumentSettings xmlns="urn:schemas-microsoft-com:office:office">
  <DownloadComponents/>
  <LocationOfComponents HRef="file:///\\"/>
 </OfficeDocumentSettings>
 <ExcelWorkbook xmlns="urn:schemas-microsoft-com:office:excel">
  <WindowHeight>10995</WindowHeight>
  <WindowWidth>17115</WindowWidth>
  <WindowTopX>240</WindowTopX>
  <WindowTopY>120</WindowTopY>
  <ProtectStructure>False</ProtectStructure>
  <ProtectWindows>False</ProtectWindows>
 </ExcelWorkbook>
 <Styles>
  <Style ss:ID="Default" ss:Name="Normal">
   <Alignment ss:Vertical="Bottom"/>
   <Borders/>
   <Font/>
   <Interior/>
   <NumberFormat/>
   <Protection/>
  </Style>
  <Style ss:ID="s21">
   <Font x:Family="Swiss" ss:Bold="1"/>
  </Style>
 </Styles>
 <Worksheet ss:Name="Sheet1">
  <Table>
ENDTEXT    
      .WriteLn( m.lcText)

      * Add a caption, if specified:
      IF NOT EMPTY( .cTableCaption)
        .WriteLn( [<Row><Cell><Data ss:Type="String">] + ;
          .cTableCaption + [</Data></Cell></Row>] + CHR(13) + CHR(10) )
      ENDIF
          
      #IF L7_SHAREWARE
        .WriteLn( CHR(13) + CHR(10) + ;
          [<!-- This table was produced by an unlicensed evaluation copy of the Level 7 Components.] + ;
          [ Please contact Cycla Corporation to obtain a licensed copy. -->]  + ;
          CHR(13) + CHR(10)  + CHR(13) + CHR(10) )
      #ENDIF
    ENDWITH  && THIS.Parent
    RETURN
  ENDFUNC  && OpenTable
  * ---------------------------------------------------------- *
  FUNCTION TitleRow
    WITH THIS.Parent
      IF NOT EMPTY( .cTitle )
        .WriteLn( [<Row><Cell><Data ss:Type="String">] + ;
          .cTitle + [</Data></Cell></Row>] + CHR(13) + CHR(10) )
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC  && TitleRow
  * ---------------------------------------------------------- *
  FUNCTION OpenColumnHeadingRow
    WITH THIS.Parent
      .WriteLn( [<Row>] )
    ENDWITH
    RETURN
  ENDFUNC  && OpenColumnHeadingRow
  * ---------------------------------------------------------- *
  FUNCTION CloseColumnHeadingRow
    WITH THIS.Parent
      .WriteLn( [</Row>] + CHR(13) + CHR(10) )
    ENDWITH
    RETURN
  ENDFUNC  && CloseColumnHeadingRow
  * ---------------------------------------------------------- *
  FUNCTION ItemHeading(loItem)
    WITH THIS.Parent
      THIS.Parent.WriteLn( [<Cell><Data>] + loItem.cHeading + ;
        [</Data></Cell>] )
    ENDWITH
    RETURN
  ENDFUNC  && ElementHeading
  * ---------------------------------------------------------- *
  FUNCTION WrapColumnHeading( loItem, lcText)
    RETURN m.lcText
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION CloseTable
    LOCAL lcText
    lcText = ""
    WITH THIS.Parent

TEXT TO lcText ADDITIVE TEXTMERGE NOSHOW    
  </Table>
  <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
   <Selected/>
  </WorksheetOptions>
 </Worksheet>
</Workbook>
ENDTEXT
      .WriteLn( m.lcText)
    ENDWITH
    RETURN
  ENDFUNC  && CloseTable
  * ---------------------------------------------------------- *
  FUNCTION GroupHeader(ii)
    LOCAL lcText, lcGroupValue, loGrp
    WITH THIS.Parent
      loGrp = .aGroups[m.ii]
      IF loGrp.lHeaderRow
        IF NOT EMPTY( loGrp.cDisplayExpression )
          lcGroupValue = loGrp.cDisplayValue
        ELSE
          lcGroupValue = TRANS( loGrp.vValue )
        ENDIF
        lcText = ""
        lcText = m.lcText + [<Row><Cell><Data>] + ;
          m.lcGroupValue + [</Data></Cell></Row>]
        .Write( m.lcText)
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC  && GroupHeader
  * ---------------------------------------------------------- *
  FUNCTION GroupFooter(ii)
    LOCAL loGrp, lcText, lcGroupValue, lnColCount, lnConsumedByColspan, loCol, loElem
    lnColCount = 0
    lnConsumedByColspan = 0
    WITH THIS.Parent
      loGrp = .aGroups[m.ii]
      IF NOT EMPTY( loGrp.cDisplayExpression )
        lcGroupValue = loGrp.cDisplayValue
      ELSE
        lcGroupValue = TRANSFORM( loGrp.vValue )
      ENDIF

      lcText = ""

      lcText = m.lcText + [<Row>] + CHR(13) + CHR(10)
         
      FOR EACH loCol IN .aColumns
        IF loCol.lActive = .F.
          LOOP
        ENDIF
        lnColCount = m.lnColCount + 1
        IF m.lnConsumedByColspan > 0
          lnConsumedByColspan = m.lnConsumedByColspan - 1
          LOOP
        ENDIF
        IF .lSimple AND loCol.nCalcType = L7_CALCTYPE_NONE OR ;
          NOT .lSimple AND loCol.nCalcElements = 0
          *
          IF NOT EMPTY( loGrp.cTotalText ) AND ;
            .nFooterTextColumn = m.lnColCount
            * Here is where text is to be placed.
            lcText = m.lcText + [<td align=left colspan=] + ;
             TRANS( .nFooterTextColspan ) + ;
             [><strong>] +  m.lcGroupValue + [ ] + loGrp.cTotalText + [</strong></td>]
            
            IF .nFooterTextColspan > 1
              * Colspan available for string. Reserve the space to extra TDs are not written.
              lnConsumedByColspan = .nFooterTextColspan - 1
            ENDIF
          ELSE
            lcText = m.lcText + [<td>&nbsp;</td>] + CHR(13) + CHR(10)
          ENDIF
        ELSE
          lcText = m.lcText + [<TD] + ;
            IIF( VARTYPE( loCol.cAlign) = "C", ;
              [ align=] + loCol.cAlign, [] ) + ;
            IIF( VARTYPE( loGrp.cCellBgColor) = "C", ;
              [ bgcolor="] + loGrp.cCellBgColor + ["], [] ) + ;
              [>]

          IF .lSimple
            IF loCol.nCalcType > L7_CALCTYPE_NONE
              lcText = m.lcText + .GetElemGroupFooter( loCol, m.ii )
            ENDIF  && loElem.nCalcType > L7_CALCTYPE_NONE
          ELSE
            FOR EACH loElem IN m.loCol.aElements
              IF loElem.nCalcType > L7_CALCTYPE_NONE
                lcText = m.lcText + THIS.GetElemGroupFooter( loElem, m.ii)
              ENDIF  && loElem.nCalcType > L7_CALCTYPE_NONE
              
            ENDFOR  && EACH loElem IN m.loCol.aElements
          ENDIF
          
          lcText = m.lcText + [</TD>] + CHR(13) + CHR(10)
        ENDIF  && loCol.nCalcElements = 0
        
      ENDFOR  && EACH loCol IN .aColumns
      lcText = m.lcText + [</tr>] + CHR(13) + CHR(10)
      
      .Write( m.lcText )
    ENDWITH
    RETURN
  ENDFUNC  && GroupFooter
  * --------------------------------------------------------- *
  FUNCTION GetElemGroupFooter(loElem, ii)
    WITH THIS.Parent
      LOCAL lvVal, lcElemText
      lvVal = loElem.aGroupTotal[ m.ii]
      IF loElem.nCalcType = L7_CALCTYPE_AVG 
        IF VARTYPE( m.lvVal) $ "NIYBD" AND loElem.aGroupCount[ m.ii] > 0
          lvVal = m.lvVal / loElem.aGroupCount[ m.ii]
        ENDIF
      ENDIF
      IF VARTYPE( loElem.cTransform) = "C"
        lcElemText = TRANSFORM( m.lvVal, loElem.cTransform )
      ELSE
        lcElemText = TRANSFORM( m.lvVal )
      ENDIF
    ENDWITH
    RETURN m.lcElemText
  ENDFUNC  && GetElemGroupFooter           
  * ---------------------------------------------------------- *
  FUNCTION OnZeroRecords
    WITH THIS.Parent
      IF NOT EMPTY( .cZeroRecordString )
        LOCAL lcText
        lcText = [<Row><Cell><Data>] + ;
          .cZeroRecordString + [</Data></Cell></Row>] + CHR(13) + CHR(10)
        .Write( m.lcText )
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC  && OnZeroRecords
  * ---------------------------------------------------------- *
  FUNCTION GrandTotals
    LOCAL lcText, lcLabel, loCol, loElem, lcElemText, lvVal, ;
      lnColCount, lnConsumedByColspan
    lnColCount = 0
    lnConsumedByColspan = 0
    
    WITH THIS.Parent
      lcText = ""
      lcLabel = "" 
      IF NOT EMPTY( .cGrandTotalText )
        * Some text is specified, such as "Grand Totals:". 
        IF NOT EMPTY( .cGrandRowLabelClass )
          lcLabel = [<span class="] + .cGrandRowLabelClass + [">] + ;
            m.lcLabel + [</span>]
        ELSE
          lcLabel = [<strong>] + m.lcLabel + [</strong>]
        ENDIF
        IF .nFooterTextColumn = -1
          * No space found, so insert special row:
          lcText = m.lcText + [<tr><td align=left colspan=] + TRANS( .nActiveColumns) + ;
            [>] + m.lcLabel + [</td></tr>]
        ENDIF
      ENDIF
      
      lcText = m.lcText + [<TR] + ;
         IIF( VARTYPE( .cGrandValign) = "C", ;
           [ valign=] + .cGrandValign, []) + ;
         IIF( VARTYPE( .cGrandRowBgColor) = "C", ;
           [ bgcolor="] + .cGrandRowBgColor + ["], []) + ;
         IIF( .lUseCss = .F., [], ;
           IIF( VARTYPE( .cGrandRowClass) = "C", ;
             [ class="] + .cGrandRowClass + ["], []) + ;
           IIF( VARTYPE( .cGrandRowStyle) = "C", ;
             [ sytle="] + .cGrandRowStyle + ["], []) ;
           ) + ;
         [>] + CHR(13) + CHR(10)


      FOR EACH loCol IN .aColumns
        IF loCol.lActive = .F.
          LOOP
        ENDIF
        lnColCount = m.lnColCount + 1
        IF m.lnConsumedByColspan > 0
          lnConsumedByColspan = m.lnConsumedByColspan - 1
          LOOP
        ENDIF
        IF .lSimple AND loCol.nCalcType = L7_CALCTYPE_NONE OR ;
          NOT .lSimple AND loCol.nCalcElements = 0
          *
          IF NOT EMPTY( .cGrandTotalText ) AND ;
            .nFooterTextColumn = m.lnColCount
            * Here is where text is to be placed.
            lcText = m.lcText + [<td align=left colspan=] + TRANS( .nFooterTextColspan ) + ;
              [>] + m.lcLabel + [</td>]
              
            IF .nFooterTextColspan > 1
              * Colspan available for string. Reserve the space to extra TDs are not written.
              lnConsumedByColspan = .nFooterTextColspan - 1
            ENDIF
          ELSE
            lcText = m.lcText + [<td>&nbsp;</td>] + CHR(13) + CHR(10)
          ENDIF
        ELSE
          lcText = m.lcText + [<td] + ;
            IIF( VARTYPE( loCol.cAlign) = "C", ;
              [ align=] + loCol.cAlign, [] ) + ;
            IIF( VARTYPE( .cGrandCellBgColor) = "C", ;
              [ bgcolor="] + .cGrandCellBgColor + ["], [] ) + ;
              [>]

          IF .lSimple
            IF loCol.nCalcType > L7_CALCTYPE_NONE
              lcText = m.lcText + THIS.GetElemGrandTotal( m.loCol )
            ENDIF
          ELSE
            FOR EACH loElem IN m.loCol.aElements
              IF loElem.nCalcType > L7_CALCTYPE_NONE
                lcText = m.lcText + THIS.GetElemGrandTotal( m.loElem )
              ENDIF
            ENDFOR
          ENDIF
          lcText = m.lcText + [</td>] + CHR(13) + CHR(10)
        ENDIF
      ENDFOR
      lcText = m.lcText + [</tr>] + CHR(13) + CHR(10)
      
      .Write( m.lcText )
    ENDWITH
    RETURN
  ENDFUNC  && GrandTotals
  * --------------------------------------------------------- *
  FUNCTION GetElemGrandTotal
    LPARAMETERS loElem

    LOCAL lvVal, lcElemText
    lvVal = loElem.nGrandTotal
    WITH THIS.Parent
      IF loElem.nCalcType = L7_CALCTYPE_AVG 
        IF VARTYPE( m.lvVal) $ "NIYBD" AND loElem.nGrandCount > 0
          lvVal = m.lvVal / loElem.nGrandCount
        ENDIF
      ENDIF
      IF VARTYPE( loElem.cTransform) = "C"
        lcElemText = TRANSFORM( m.lvVal, loElem.cTransform )
      ELSE
        lcElemText = TRANSFORM( m.lvVal )
      ENDIF
      IF VARTYPE( .cGrandFontAttributes) = "C" 
        IF "B" $ .cGrandFontAttributes
          lcElemText = [<b>] + m.lcElemText + [</b>] 
        ENDIF
        IF "I" $ .cGrandFontAttributes
          lcElemText = [<i>] + m.lcElemText + [</i>] 
        ENDIF
        IF "U" $ .cGrandFontAttributes
          lcElemText = [<u>] + m.lcElemText + [</u>] 
        ENDIF
      ENDIF
      IF VARTYPE( .cGrandFontColor) = "C"
        lcElemText = [<font color="] + .cGrandFontColor + [">] + ;
          m.lcElemText + [</font>] 
      ENDIF
      IF .lUseCss AND ( ;
        NOT EMPTY( .cGrandFontClass) OR ;
        NOT EMPTY( .cGrandFontStyle) )
        *
        lcElemText = [<span] + ;
          IIF( EMPTY( .cGrandFontClass), ;
            [], [ class="] + .cGrandFontClass + ["] ) + ;
          IIF( EMPTY( .cGrandFontStyle), ;
            [], [ style="] + .cGrandFontStyle + ["] ) + ;
          [>] + m.lcElemText + [</span>]
      ENDIF
    ENDWITH
    RETURN m.lcElemText
  ENDFUNC  && GetElemGrandTotal
  * ---------------------------------------------------------- *
  FUNCTION WritePageLinks
  ENDFUNC  && WritePageLinks
  * ---------------------------------------------------------- *
  FUNCTION GetExtraRow( loRow, pnLocation, pnGroup)
    LOCAL lcText
    WITH loRow
      lcText = ""
      lcText = m.lcText + [<Row><Cell><Data>] 

      DO CASE
      CASE VARTYPE( .cDynamicText) = "C"
        lcText = m.lcText + TRANS( EVAL( .cDynamicText ))
      CASE VARTYPE( .cText) = "C"
        lcText = m.lcText + .cText
      OTHERWISE
        lcText = m.lcText + "Special Row at Location " + TRANS( m.pnLocation ) + " [no content]"
      ENDCASE
      lcText = m.lcText + [</Data></Cell></Row>]
    ENDWITH
    RETURN m.lcText
  ENDFUNC  && GetExtraRow
  * ---------------------------------------------------------- *
  FUNCTION PreProcessCellTags(loItem)
    * Handles either a column (complex table) or an element (simple table).
    
    * Now we'll also deal with the TD wrapper, since in a simple table 
    * there is no separate column object that contains the element object:
    LOCAL lcText1, lcText2
    lcText1 = '[<' + THIS.cCellTag + '>]'
    lcText2 = '[</' + THIS.cCellTag + '>]+CHR(13)+CHR(10)'

    WITH loItem
      .cBeforeTags = m.lcText1 + [+] + .cBeforeTags
      .cAfterTags  = .cAfterTags + [+] + m.lcText2
    ENDWITH
    RETURN
  ENDFUNC  && PreProcessCellTags
  * ---------------------------------------------------------- *
  FUNCTION PreProcessElementTags(loItem)
    LOCAL lcText1, lcText2, lcFontText
    lcText1 = '""'
    lcText2 = '""'
    WITH loItem
      .cBeforeTags = m.lcText1
      .cAfterTags  = m.lcText2

      IF VARTYPE( .cPrefix) <> "C"
        .cPrefix = ""
      ENDIF
      IF VARTYPE( .cSuffix) <> "C"
        .cSuffix = ""
      ENDIF
    ENDWITH
    RETURN
  ENDFUNC  && PreProcessElementTags
  * ---------------------------------------------------------- *
  FUNCTION OpenRow
    RETURN [<Row>] + CR
  ENDFUNC && OpenRow
  * ---------------------------------------------------------- *
  FUNCTION CloseRow
    RETURN [</Row>] + CR
  ENDFUNC && CloseRow
  * ---------------------------------------------------------- *
  FUNCTION GetElement(loElem)
    LOCAL lcText, lcLinkText, lvVal, lcComment
    * First, call abstract class behavior:
    lcText = DODEFAULT( m.loElem)
    lcText = STRTRAN( m.lcText, "&nbsp;", "")
    * Then apply and specific transformations:
    WITH loElem
      lvVal = .vNewValue
      * Dynamic and static hyperlinks:
      IF INLIST( .nType, L7_ELEMENTTYPE_STATIC_HYPERLINK, L7_ELEMENTTYPE_DYNAMIC_HYPERLINK) AND ;
        NOT ISNULL( m.lvVal ) AND NOT EMPTY( m.lvVal ) && hyperlink
        * Get the display portion of the link:
        DO CASE
        CASE NOT EMPTY( .cDynamicLinkText )
          lcLinkText = RTRIM( TRANSFORM( EVAL( .cDynamicLinkText )))
        CASE NOT EMPTY( .cLinkText)
          lcLinkText = .cLinkText
        OTHERWISE  && force to literal URL
          lcLinkText = m.lcText
        ENDCASE
        * Now wrap the text and link in the A element tags:
        lcText = [<a href="] + m.lcText + ["] + ;
          IIF( EMPTY( .cLinkAttributes), [], [ ] + .cLinkAttributes ) + ;
          [>] + m.lcLinkText + [</a>]
      ENDIF
      IF EMPTY( .cComment)
        lcComment = ""
      ELSE
        IF "(" $ .cComment
          lcComment = EVALUATE( .cComment)
          IF NOT EMPTY( m.lcComment)
            lcComment = [<Comment>] + m.lcComment + [</Comment>] + CR
          ENDIF
        ELSE
          lcComment = [<Comment>] + .cComment + [</Comment>] + CR
        ENDIF
      ENDIF
    ENDWITH
    * Following <Data> tag needs a data type attribute added:
    RETURN [<Data>] + m.lcText + [</Data>] + m.lcComment
  ENDFUNC  && GetElement
  * ---------------------------------------------------------- *
ENDDEFINE  && L7TableExcelXmlRender 

#if .f.
06/14/2010 - kludge to force grand total into TFOOT (so sortable ignores)
01/09/2003 - Fixed bug in HTML ItemHeading method.
03/29/2005 - Fixed bug that omitted "grand total" label.
#endif

* End: L7TableRender.PRG

