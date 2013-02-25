* L7Xtab.PRG - Cross-tab reporting.
#include l7.h

*** ==================================================================== ***
DEFINE CLASS L7Xtab AS Custom
  cTitle = "Cross-Tabulation Report"
  cAlias = "XtabData_"  && override with your own cursor name
  ADD OBJECT Groups AS L7XtabGroups
  ADD OBJECT ColumnGroup AS L7XtabColumnGroup
  ADD OBJECT Elements AS Collection
  DIMENSION Listeners[1]
  nListeners = 0
  * ADD OBJECT Listeners AS Collection
  DIMENSION aGrandGrid[1,1]
  DIMENSION aGrandTotalGrid[1]
  * -------------------------------------------------------------------- *
  FUNCTION CreateListener(lcClass)
    THIS.nListeners = THIS.nListeners + 1 
    DIMENSION THIS.Listeners[THIS.nListeners]
    THIS.AddObject("Listeners[" + TRANSFORM(THIS.nListeners) + "]", m.lcClass)
    RETURN THIS.Listeners[THIS.nListeners]
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION ProcessData
    WITH THIS
      .SetupCalcs()
      .SetIterator()
      .SetBindings()
      .Iterate()
      .DeliverOutput()
      .Release()
    ENDWITH
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION SetupCalcs
    FOR ii = 1 TO THIS.Groups.Count
      loGrp = THIS.Groups.Item(m.ii)
      DIMENSION loGrp.aGrid[THIS.Elements.Count, THIS.ColumnGroup.ColumnDefs.Count]
      loGrp.aGrid = 0
      DIMENSION loGrp.aTotalGrid[THIS.Elements.Count]
      loGrp.aTotalGrid = 0
    ENDFOR
    DIMENSION THIS.aGrandGrid[THIS.Elements.Count, THIS.ColumnGroup.ColumnDefs.Count]
    THIS.aGrandGrid = 0
    DIMENSION THIS.aGrandTotalGrid[THIS.Elements.Count]
    THIS.aGrandTotalGrid = 0
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION SetIterator
    THIS.AddObject("Iterator", "L7XtabIterator")
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION SetBindings
    LOCAL loListener, ii
    BINDEVENT(THIS.Iterator, "OnMove", THIS, "OnMove")
    FOR ii = 1 TO THIS.nListeners
      loListener = THIS.Listeners(m.ii)
      loListener.SetBindings(THIS)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION Release
    UNBINDEVENTS(THIS)
    FOR ii = 1 TO THIS.nListeners
      TRY
        THIS.Listeners(m.ii).Release()
      CATCH
        *
      ENDTRY
    ENDFOR
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION OnMove
    LOCAL laEvt[1], loSrc
    AEVENTS(laEvt, 0)
    loSrc = laEvt[1]
    IF loSrc.BOF
      THIS.BeforeStart(m.loSrc)
    ENDIF
    *THIS.BeforeDetail(m.loSrc)
    THIS.Detail(m.loSrc)
    *THIS.AfterDetail(m.loSrc)
    IF loSrc.EOF
      THIS.AfterEnd(m.loSrc)
    ENDIF
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION BeforeStart(loSrc)
    LOCAL loListener, ii
    FOR ii = 1 TO THIS.nListeners
      loListener = THIS.Listeners(m.ii)
      loListener.BeforeStart(loSrc)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION GroupChange(loSrc)  && bind to me?
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION Detail(loSrc)
    LOCAL loListener, ii, jj, kk, nn, loGrp
    THIS.Groups.Detail(m.loSrc)
    FOR ii = 1 TO THIS.nListeners
      loListener = THIS.Listeners(m.ii)
      loListener.Detail(loSrc)
    ENDFOR
    IF NOT loSrc.EOF
      nn = m.loSrc.nColumn
      FOR kk = 1 TO THIS.Elements.Count
        lvVal = EVALUATE("loSrc.NewRec" + THIS.Elements.Item(m.kk).cDataExpression)

        FOR ii = 1 TO THIS.Groups.Count
          loGrp = THIS.Groups.Item(m.ii)
          loGrp.aGrid[m.kk, m.nn] = loGrp.aGrid[m.kk, m.nn] + m.lvVal
          loGrp.aTotalGrid[m.kk] = loGrp.aTotalGrid[m.kk] + m.lvVal
        ENDFOR

        THIS.aGrandGrid[m.kk, m.nn] = THIS.aGrandGrid[m.kk, m.nn] + m.lvVal
        THIS.aGrandTotalGrid[m.kk] = THIS.aGrandTotalGrid[m.kk] + m.lvVal
      ENDFOR
    ENDIF
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION AfterEnd(loSrc)
    LOCAL loListener, ii
    FOR ii = 1 TO THIS.nListeners
      loListener = THIS.Listeners(m.ii)
      loListener.AfterEnd(loSrc)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION DeliverOutput()
    LOCAL loListener, ii
    FOR ii = 1 TO THIS.nListeners
      loListener = THIS.Listeners(m.ii)
      loListener.DeliverOutput()
    ENDFOR
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION Iterate
    THIS.Iterator.Iterate()
  ENDFUNC
ENDDEFINE
*** ==================================================================== ***
DEFINE CLASS L7XtabElement AS LINE
  cDataExpression = NULL
  cHeading = "Heading"
  nCalcType = L7_CALCTYPE_NONE
  cCellClass = NULL
ENDDEFINE
*** ==================================================================== ***
DEFINE CLASS L7XtabListener AS LINE
  * -------------------------------------------------------------------- *
  FUNCTION Release
    UNBINDEVENTS(THIS)
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION SetBindings(loXtab)
    BINDEVENT(m.loXtab.Iterator, "OnMove", THIS, "OnMove")
    BINDEVENT(m.loXtab, "GroupChange", THIS, "OnGroupChange")
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION BeforeStart(loSrc)
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION Detail(loSrc)
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION OnGroupChange(loSrc)
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION AfterEnd(loSrc)
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION DeliverOutput()
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION OnMove()
  ENDFUNC
ENDDEFINE

*** ==================================================================== ***
DEFINE CLASS L7XtabHtmlListener AS L7XtabListener
  cResult = ""
  nCols = NULL
  * -------------------------------------------------------------------- *
  FUNCTION BeforeStart(loSrc)
    LOCAL lcTxt, loTop, llMultiRow, lnElems, lnGrpCols
    TEXT TO lcTxt NOSHOW PRETEXT 3
      <style type="text/css">
      .xtab CAPTION{color: brown; font-size: larger; font-style; italic; font-weight: bold;}
      .xtab TR{background-color: #ccc;}
      TR.xtabRow0{background-color: #fff;}
      TR.xtabGrand TD{font-weight: bold; background-color: #dfd;}
      TD.xtabRowTot{font-weight: bold; background-color: #ccc;}
      TR.xtabRow0 TD.xtabRowTot{background-color: #fff;}
      TR.xtabGrand TD.xtabRowTot{font-weight: bold; color: brown; background-color: #ffa;}
      .xtab TH, .xtab TD {border: 1px solid #333; border-collapse: collapse;
        }
      .xtab TH{font-weight: normal; color: brown; vertical-top: bottom; font-style: normal; white-space: nowrap;}
      TR.xtabHead TH{font-weight: normal; vertical-align: bottom; font-style: italic; white-space: normal;}
      .xtab TD{text-align: right;}
      .xtab TD.money{color: darkgreen;}
      </style>
    ENDTEXT
    THIS.cResult = THIS.cResult + m.lcTxt 
    loTop = THIS.Parent
    lnElems = loTop.Elements.Count
    lnGrpCols = loTop.ColumnGroup.ColumnDefs.Count
    THIS.nCols = ;
      loTop.Groups.Count + ;
      (m.lnElems * (1 + m.lnGrpCols))
      
    llMultiRow = m.lnElems > 1
    TEXT TO lcTxt NOSHOW PRETEXT 3
      <table class="xtab"><caption><<THIS.Parent.cTitle>></caption>
    ENDTEXT
    THIS.cResult = THIS.cResult + TEXTMERGE(m.lcTxt) + CRLF
    FOR ii = 1 TO IIF(m.llMultiRow, 2, 1)
      lcTxt = [<tr class="xtabHead">] + CRLF
      IF m.ii = 1
        * Group headings w/rowspan if needed:
        FOR jj = 1 TO loTop.Groups.Count
          lcTxt = m.lcTxt + [<th] + IIF(m.llMultiRow, [ rowspan="2"], []) + [>] + ;
            loTop.Groups.Item(m.jj).cHeading + [</th>] + CRLF
        ENDFOR
        * Main column headings:
        FOR jj = 1 TO m.lnGrpCols
          loItem = loTop.ColumnGroup.ColumnDefs.Item(m.jj)
          lcHeadExpr = loTop.ColumnGroup.cHeadingExpression
          WITH loItem
            lcTxt = m.lcTxt + [<th] + ;
              IIF(m.lnElems > 1, [ colspan="] + TRANSFORM(m.lnElems) + ["], []) + [>] + ;
              EVALUATE(m.lcHeadExpr) + ;
              [</th>] + CRLF
          ENDWITH
        ENDFOR
        lcTxt = m.lcTxt + [<th] + ;
          IIF(m.lnElems > 1, [ colspan="] + TRANSFORM(m.lnElems) + ["], []) + [>] + ;
          "TOTALS" + ;
          [</th>] + CRLF
      ENDIF
      IF m.ii = 2
        FOR jj = 1 TO m.lnGrpCols + 1
          FOR kk = 1 TO m.lnElems
            lcTxt = m.lcTxt + [<th>] + loTop.Elements.Item(m.kk).cHeading + [</th>] + CRLF
          ENDFOR
        ENDFOR
      ENDIF
      lcTxt = m.lcTxt + [</tr>] + CRLF
      THIS.cResult = THIS.cResult + m.lcTxt 
    ENDFOR
    RETURN
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION OnGroupChange(loSrc)
    IF loSrc.BOF  && this logic would change if group headers were involved
      RETURN
    ENDIF
    LOCAL ii, jj, loObj, lcTxt, lnGrps, lnChng, loData
    loObj = loSrc.Parent
    loData = loSrc.OldRec
    lnGrps = loObj.Groups.Count
    lnChng = loSrc.nGroupChangeLevel

    * -- Iterate backward from least-significant group to change point:
    FOR rr = m.lnGrps TO m.lnChng STEP -1
      loRowGrp = loObj.Groups.Item(m.rr)
      
      lcTxt = [<tr class="xtabRow] + TRANSFORM(m.lnGrps - m.rr) + [">]
      * On one line, iterate all groups forward to show current *group value*:
      FOR gg = 1 TO m.lnGrps
        WITH loData
          IF m.rr = m.gg AND m.gg < m.lnGrps && total row
            lcTxt = m.lcTxt + [<th colspan="] + TRANSFORM(1 + m.lnGrps - m.gg) + [">] + ;
              TRANSFORM(loObj.Groups.Item(m.gg).CurValDisplay) + [ TOTAL] + [</th>] + CRLF
            EXIT  && and don't show any lower group values (spanned "totals" cell handles)
          ELSE && lowest-level row
            lcTxt = m.lcTxt + [<th>] + TRANSFORM(loObj.Groups.Item(m.gg).CurValDisplay) + [</th>] + CRLF
          ENDIF
        ENDWITH
      ENDFOR
      * Show the "data":
      FOR jj = 1 TO ALEN(loRowGrp.aGrid, 2)
        FOR ii = 1 TO ALEN(loRowGrp.aGrid, 1)
          loElem = loObj.Elements.Item(m.ii)
          lcTxt = lcTxt + [<td] + IIF(ISNULL(loElem.cCellClass), [], [ class="] + loElem.cCellClass + ["]) + [>] + ;
            TRANSFORM(loRowGrp.aGrid[m.ii, m.jj]) + [</td>]
        ENDFOR
        lcTxt = m.lcTxt + CRLF
      ENDFOR
      loRowGrp.aGrid = 0  && reset group numbers
      * Show row totals:
      FOR ii = 1 TO ALEN(loRowGrp.aTotalGrid)
        lcTxt = lcTxt + [<td class="xtabRowTot">] + TRANSFORM(loRowGrp.aTotalGrid[m.ii]) + [</td>]
      ENDFOR
      loRowGrp.aTotalGrid = 0  && reset group totals

      THIS.cResult = THIS.cResult + m.lcTxt + [</tr>] + CRLF
    ENDFOR
    * if group headers were involved, we would now iterate *forward* with new headers
    RETURN
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION AfterEnd(loSrc)
    LOCAL ii, jj, loObj, lcTxt
    loObj = loSrc.Parent
    lcTxt = [<tr class="xtabGrand"><th colspan="<<loObj.Groups.Count>>">Grand Totals</th>]
    lcTxt = TEXTMERGE(m.lcTxt) + CRLF
    FOR jj = 1 TO ALEN(loObj.aGrandGrid, 2)
      FOR ii = 1 TO ALEN(loObj.aGrandGrid, 1)
        lcTxt = lcTxt + [<td>] + TRANSFORM(loObj.aGrandGrid[m.ii, m.jj]) + [</td>]
      ENDFOR
      lcTxt = m.lcTxt + CRLF
    ENDFOR
    FOR ii = 1 TO ALEN(loObj.aGrandTotalGrid)
      lcTxt = lcTxt + [<td class="xtabRowTot">] + TRANSFORM(loObj.aGrandTotalGrid[m.ii]) + [</td>]
    ENDFOR
    lcTxt = m.lcTxt + "</tr>" + CRLF + [</table>] + CRLF
    THIS.cResult = THIS.cResult + m.lcTxt 
    RETURN
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION Render()
    RETURN THIS.cResult
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION ShowOutput()
    L7ShowHtml(THIS.cResult)
  ENDFUNC
ENDDEFINE

*** ==================================================================== ***
DEFINE CLASS L7XtabWaitWindowListener AS L7XtabListener
  * -------------------------------------------------------------------- *
  FUNCTION OnMove()
    LOCAL laEvt[1], loSrc
    AEVENTS(laEvt, 0)
    loSrc = laEvt[1]
    WAIT WINDOW TIMEOUT 0.1 TRANSFORM(loSrc.BOF) + " / " + TRANSFORM(loSrc.EOF)
  ENDFUNC
ENDDEFINE
*** ==================================================================== ***
DEFINE CLASS L7XtabIterator AS Custom
  BOF = .F.
  EOF = .F.
  OldRec = NULL
  NewRec = NULL
  nColumn = NULL
  nGroupChangeLevel = NULL
  * -------------------------------------------------------------------- *
  FUNCTION Iterate()
    WITH THIS
      SELECT (.Parent.cAlias)
      .DoMove(.T.)
      DO WHILE NOT THIS.EOF
        .DoMove(.F.)
      ENDDO
    ENDWITH
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION DoMove(llFirst)
    IF m.llFirst
      GO TOP
      THIS.BOF = .T.
    ELSE
      SKIP
      THIS.OldRec = THIS.NewRec
      THIS.BOF = .F.
    ENDIF
    IF THIS.IsEOF()
      THIS.NewRec = NULL
      THIS.EOF = .T.
    ELSE
      SCATTER MEMO NAME THIS.NewRec
      THIS.nColumn = THIS.Parent.ColumnGroup.GetColumnNumber(THIS)
    ENDIF
    THIS.OnMove()
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION OnMove()  && bind to me!
  ENDFUNC
  * -------------------------------------------------------------------- *
  FUNCTION IsEOF()
    RETURN EOF()
  ENDFUNC
  * -------------------------------------------------------------------- *
ENDDEFINE

*** ==================================================================== ***
DEFINE CLASS L7XtabColumnGroup AS CUSTOM
  cDataExpression = NULL
  cHeadingExpression = NULL
  lCreateFromData = .T.
  ADD OBJECT ColumnDefs AS Collection
  * -------------------------------------------------------------------- *
  FUNCTION GetColumnNumber(loSrc)
    LOCAL lvVal, ii, loObj, lnRet
    lnRet = 0
    lvVal = EVALUATE("loSrc.NewRec" + THIS.cDataExpression)
    FOR ii = 1 TO THIS.ColumnDefs.Count
      lvRefVal = EVALUATE("THIS.ColumnDefs.Item(m.ii)" + THIS.cDataExpression)
      IF m.lvRefVal = m.lvVal
        lnRet = m.ii
        EXIT
      ENDIF
    ENDFOR
    ** ? "Column:", m.lnRet
    RETURN m.lnRet
  ENDFUNC
ENDDEFINE

*** ==================================================================== ***
DEFINE CLASS L7XtabGroup AS LINE
  cDataExpression = NULL
  cDisplayExpression = NULL
  lCreateFromData = .T.
  cHeading = "Group" && specify
  CurVal = NULL
  NewVal = NULL
  CurValDisplay = NULL
  DIMENSION aGrid[1,1]
  DIMENSION aTotalGrid[1]
ENDDEFINE

*** ==================================================================== ***
DEFINE CLASS L7XtabGroups AS Collection
  * -------------------------------------------------------------------- *
  FUNCTION Detail(loSrc)
    LOCAL lnGroupChangeLevel, ii, loGrp, lvNewVal 
    lnGroupChangeLevel = 0
    IF loSrc.EOF
        lnGroupChangeLevel = 1
    ELSE
      IF loSrc.BOF
        lnGroupChangeLevel = 1
      ELSE && hunt for group change level
        FOR ii = 1 TO THIS.Count
          loGrp = THIS.Item(m.ii)
          WITH loSrc.NewRec
            lvNewVal = EVALUATE(loGrp.cDataExpression)
            IF ISNULL(loGrp.CurVal) OR m.lvNewVal <> loGrp.CurVal
              lnGroupChangeLevel = m.ii
              EXIT
            ENDIF
          ENDWITH
        ENDFOR
      ENDIF
    ENDIF
    IF m.lnGroupChangeLevel > 0
      loSrc.nGroupChangeLevel = m.lnGroupChangeLevel
      THIS.Parent.GroupChange(loSrc)
      
      IF NOT loSrc.EOF
        * Set CurVal in changed groups to new value:
        FOR ii = m.lnGroupChangeLevel TO THIS.Count
          loGrp = THIS.Item(m.ii)
          WITH loSrc.NewRec
            loGrp.CurVal = EVALUATE(loGrp.cDataExpression)
            IF NOT ISNULL(loGrp.cDisplayExpression)
              loGrp.CurValDisplay = EVALUATE(loGrp.cDisplayExpression)
            ELSE  && just use the raw value
              loGrp.CurValDisplay = loGrp.CurVal
            ENDIF
          ENDWITH
          ** ? REPLICATE(SPACE(2), m.ii), loGrp.cDataExpression, "=", TRANSFORM(m.lvNewVal)
        ENDFOR
      ENDIF
    ENDIF

  ENDFUNC
ENDDEFINE

#if .f.
09/15/2004 - initial creation
#endif
