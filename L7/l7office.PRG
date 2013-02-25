* L7Office.PRG
#include L7Office.H

* TO DO: Look into setting Word.Options.ConfirmConversions to FALSE
* (Office 2007 default to True)

DEFINE CLASS L7DocParser AS Custom 
  cComClass = "Word.Application"
  oComApp = NULL
  cComErrorMsg = ""
  nComError = 0
  oDoc = NULL
  lTryGetObject = .T.  && set to False to force CREATEOBJECT
  lGetObject = .F.  && did GETOBJECT() work?
  lWasVisible = .F.
  nProt = 0
  lVisible = .f.
  nSaveAsFormat = wdFormatDocument  && 0, Word .doc format 
  DIMENSION aProt[1]
  * ----------------------------------------------------------- *
  FUNCTION lVisible_ASSIGN(tlSet)
    THIS.lVisible = m.tlSet
    IF NOT ISNULL(THIS.oComApp)
      THIS.oComApp.Visible = m.tlSet
    ENDIF 
    RETURN  
  ENDFUNC && lVisible_ASSIGN(tlSet)
  * ----------------------------------------------------------- *
  FUNCTION SetApplication(toComObj)  && pass in running COM moniker to instance of Word
    WITH this
      .CloseDoc()  && in case
      .oComApp = NULL
      .oComApp = m.toComObj
      * Assume active document is of interest:
      IF .oComApp.Documents.Count > 0
        .oDoc = .oComApp.ActiveDocument
      ENDIF 
    ENDWITH
    RETURN
  ENDFUNC  && SetApplication
  * ----------------------------------------------------------- *
  FUNCTION CloseApplication()
    THIS.CloseDoc()
    IF NOT ISNULL(THIS.oComApp)
      IF NOT THIS.lGetObject  && created it
        TRY
          THIS.oComApp.Quit(.F.)
        CATCH
          * ??
          = .F.
        ENDTRY
      ELSE
        IF THIS.lWasVisible
          TRY 
            THIS.oComApp.Visible = .T.
          CATCH
            = .F.
          ENDTRY
        ENDIF
      ENDIF
      THIS.oComApp = NULL
    ENDIF
    RETURN 
  ENDFUNC
  * ----------------------------------------------------------- *
  FUNCTION OpenApplication
    LOCAL loObj, llError
    IF ISNULL(THIS.oComApp)
      TRY 
        TRY
          IF THIS.lTryGetObject 
            loObj = GETOBJECT(, THIS.cComClass)
            THIS.lGetObject = .T.
          ELSE
            loObj = CREATEOBJECT(THIS.cComClass)
            THIS.lGetObject = .F.
          ENDIF 
        CATCH TO loExc
          TRY
            loObj = CREATEOBJECT(THIS.cComClass)
            THIS.lGetObject = .F.
          CATCH TO loExc
            llError = .T.
            THIS.nComError = loExc.ErrorNo
            THIS.cComErrorMsg = loExc.Message 
          ENDTRY
        ENDTRY
      CATCH TO loExc
        llError = .T.
      ENDTRY
      IF m.llError
      ELSE
        THIS.oComApp = m.loObj
        IF m.loObj.Visible
          THIS.lWasVisible = .T.
        ENDIF
        loObj.Visible = this.lVisible
      ENDIF
    ENDIF
    RETURN NOT m.llError
  ENDFUNC
  * ----------------------------------------------------------- *
  function setApplication(toWord) && shortcut if Word object is already created
    this.oComApp = m.toWord
    return 
  endfunc 
  * ----------------------------------------------------------- *
  function setDocument(toDoc) && shortcut if Document object is already created
    this.oDoc = m.toDoc
    return 
  endfunc 
  * ----------------------------------------------------------- *
  FUNCTION OpenDoc(tcFileName, tlConfirmConversions, tlReadOnly, tlAddToRecent)
    IF NOT THIS.OpenApplication()
      ERROR "Could not open application " + THIS.cComClass + ": " + THIS.cComErrorMsg
    ENDIF
    LOCAL loDoc, llReadOnly
    llReadOnly = IIF(PCOUNT() < 3, .T., m.tlReadOnly) && default to read-only if not passed
    loDoc = THIS.oComApp.Documents.Open(m.tcFileName, m.tlConfirmConversions, m.llReadOnly, m.tlAddToRecent)
    THIS.oDoc = m.loDoc
    RETURN m.loDoc
  ENDFUNC 
  * ----------------------------------------------------------- *
  FUNCTION CloseDoc(llSave)
    IF NOT ISNULL(THIS.oDoc)
      THIS.oDoc.Close(m.llSave) && don't save changes
      THIS.oDoc = NULL
    ENDIF
    RETURN 
  ENDFUNC
  * ----------------------------------------------------------- *
  FUNCTION SaveDocAs( tcFilename )
    IF NOT ISNULL(THIS.oDoc)
      THIS.oDoc.Saveas(m.tcFilename,this.nSaveAsFormat) 
    ENDIF
    RETURN 
  ENDFUNC
  * ----------------------------------------------------------- *
  function SetDocumentView(tlOriginal, tlShowRevisions)
    * defaults to "Final" by passing nothing or .f., .f.
    * w/o calling this, you're captive to how document was saved and local Word options! 
    local loView
    loView = this.oDoc.ActiveWindow.View && [[ does this work w/ multiple docs open??
    loView.RevisionsView = iif(m.tlOriginal, wdRevisionsViewOriginal, wdRevisionsViewFinal)
    loView.ShowRevisionsAndComments = m.tlShowRevisions
    return
  endfunc 
  * ----------------------------------------------------------- *
  FUNCTION UnprotectDoc()
    THIS.nProt = THIS.oDoc.Sections.Count
    DIMENSION THIS.aProt[THIS.nProt]
    LOCAL ii, loSec, loExc
    FOR ii = 1 TO THIS.nProt 
      loSec = THIS.oDoc.Sections(m.ii)
      IF loSec.ProtectedForForms
        THIS.aProt[m.ii] = .T.  && store in case we want to revert
        TRY
          loSec.ProtectedForForms = .F.
        CATCH TO loExc
        ENDTRY
        IF VARTYPE(loExc) = "O"
          ERROR "Could not unprotect document. Perhaps it is password-protected?"
        ENDIF
      ENDIF
    ENDFOR
    RETURN 
  ENDFUNC 
  * ----------------------------------------------------------- *
  FUNCTION ReadFormFields
    LOCAL loVars, loFF, lcResult, lcName, lcPrevName, lnCount, loExc, llError
    lnCount = 1
    loVars = CREATEOBJECT("L7DocParserCollection")
    lcPrevName = ""  && help locate corruption in DOC files
    FOR EACH loFF IN THIS.oDoc.Range.FormFields
      lnCount = lnCount + 1  && just for debugging ID issues
      TRY
        lcResult = m.loFF.Result  
        * this has trigger Com error:
        * "OLE IDispatch exception code 0 from Microsoft Word: Object has been deleted"
        * when someone has messed with the form, thus the TRY/CATCH--
        * we'll skip over the problem field
        
        lcResult = THIS.CleanResult(m.lcResult)
        lcName = m.loFF.Name
      CATCH TO loExc
        lcName = ""  && cause the problem field to be skipped
      ENDTRY
      IF EMPTY(m.lcName)  && corrupt/unnamed form field
        LOOP
      ENDIF
      TRY
        loVars.Add(m.lcResult, m.lcName)
        lcPrevName = m.lcName
      CATCH TO loExc WHEN loExc.ErrorNo = 2062
        = .F.  && duplicate key: we'll ignore subsequent
      CATCH TO loExc
        llError = .T.
        EXIT
      ENDTRY
    ENDFOR
    IF m.llError  && unknown error
      ERROR loExc.Message + ;
        ", Line: " + TRANSFORM(loExc.LineNo) + ;
        " of " + m.loExc.Procedure
    ENDIF
    RETURN m.loVars
  ENDFUNC 
  * ----------------------------------------------------------- *
  FUNCTION CleanResult(lcResult)
    IF VARTYPE(m.lcResult) = "C"
      IF OCCURS(CHR(13), m.lcResult) > 0
        * Ensure all CRs have LFs:
        lcResult = STRTRAN(STRTRAN(m.lcResult, CHR(10)), CHR(13), CHR(13) + CHR(10))
      ENDIF
    ENDIF
    RETURN m.lcResult
  ENDFUNC
  * ----------------------------------------------------------- *
  FUNCTION ReadTable(lnEarlyNum, lnLateNum, lcTextInCellOne, tlLoadWordObjects)
    * supports _hunting_ for the "right" table
    * if you have the table already, call LoadTable
    
    LOCAL loTable, lnCount, loComTable, lcComText
    lnCount = THIS.oDoc.Tables.Count
    * If no start # specified, start at first table:
    lnEarlyNum = EVL(m.lnEarlyNum, 1)
    * If no end # specified, go through last table:
    lnLateNum = MIN(m.lnCount, EVL(m.lnLateNum, m.lnCount))
    * Iterate tables looking for right one:
    FOR ii = m.lnEarlyNum TO m.lnLateNum
      loComTable = THIS.oDoc.Tables(m.ii)
      loComTable.Range.Font.Hidden = 0  && unhide, so we can read it
      IF NOT EMPTY(m.lcTextInCellOne)
        * We're identifying by tables with specific text in first cell.
        lcComText = loComTable.Cell(1,1).Range.Text
        IF UPPER(m.lcTextInCellOne) $ UPPER(m.lcComText)
          EXIT && got it
        ELSE
          loComTable = .F.
          LOOP
        ENDIF
      ELSE
        * First table must be it.
      ENDIF
    ENDFOR
    IF VARTYPE(m.loComTable) = "O"
      loTable = THIS.LoadTable(m.loComTable, m.tlLoadWordObjects)
    ENDIF 
    RETURN m.loTable
  ENDFUNC && ReadTable
  * ----------------------------------------------------------- *
  FUNCTION LoadTable(toComTbl, tlLoadWordCellObjects)
    * Load a Word table into an array in an object. 
    * Copes with irregular tables in Word by placing NULL in "missing" cells. 
    * (New) optional property to load Word cell objects (vs. range text), which 
    *   could be used to do further Word parsing work cell-by-cell.
    LOCAL loTable, ii, jj, lcProp, loCells, loCell
    loTable = CREATEOBJECT("Empty")

    lcProp = "aVals[" + TRANSFORM(toComTbl.Rows.Count) + ;
      "," + TRANSFORM(toComTbl.Columns.Count) + "]"
    ADDPROPERTY(m.loTable, m.lcProp)
    loTable.aVals = NULL  && set NULL to cover irregular tables
    loCells = toComTbl.Range.Cells
    for each loCell in loCells
      ii = loCell.RowIndex
      jj = loCell.ColumnIndex
      if m.tlLoadWordCellObjects
        loTable.aVals[m.ii, m.jj] = m.loCell
      else  && just text
        loTable.aVals[m.ii, m.jj] = THIS.GetCellText(m.loCell)
      endif
    next && cell 
    * NOTE: Any "missing cell" (due to irregular tables) will be NULL.


      * This had problems with irregular tables:
      *!*        FOR ii = 1 TO .Rows.Count
      *!*          FOR jj = 1 TO .Columns.Count
      *!*            loTable.aVals[m.ii, m.jj] = ;
      *!*              AlltrimX(STRTRAN(.Rows(m.ii).Cells(m.jj).Range.text, CHR(7)))
      *!*          ENDFOR
      *!*        ENDFOR

    RETURN m.loTable
  ENDFUNC && LoadTable
  * ----------------------------------------------------------- *
  * CAUTION: Some versions of Word, including Office 2007, do not
  * throw errors and return wrong results if you request a cell in
  * a row greater than the table's row count! 
  *
  * Be careful to bound your code with checks of tbl.rows.count 
  * before calling IsCellChecked, IsTextInCell or GetCellText!!
  * ----------------------------------------------------------- *
  FUNCTION IsCellChecked(tvTblOrCell, tnRow, tnCol)
    * Does cell either have an "x" or a checked checkbox.
    LOCAL loRange, llRet, loFF, lcText
    IF PCOUNT() = 1 && assume cell itself passed in, not table
      loRange = m.tvTblOrCell.Range
    ELSE 
      loRange = THIS.GetCellRange(m.tvTblOrCell, m.tnRow, m.tnCol)
    ENDIF 
    IF loRange.FormFields.Count > 0  && form, look for checkbox
      loFF = loRange.FormFields.Item(1)
      IF loFF.Type = wdFieldFormCheckBox 
        IF loFF.Result = "1"
          * alt: IF loFF.Checkbox.Value = .T.
          llRet = .T.
        ENDIF 
      ENDIF
    ELSE  && basic text, look for X
      lcText = THIS.GetRangeText(m.loRange)
      
      * This violated DRY and _failed_ to pick up &nbsp; handling.
      *!*        lcText = NVL(loRange.Text, "") && convert empty to string
      *!*        lcText = CHRTRAN(STRTRAN(m.lcText, CHR(13) + CHR(7), ""), CHR(7), "")
      *!*        lcText = AllTrimX(m.lcText)

      llRet = INLIST(LEFT(m.lcText, 2), "x", "X", CHR(237), CHR(205))
      * 11/28/2007: added CHR(237) fox X-like symbol
    ENDIF 
    RETURN m.llRet
  ENDFUNC  && IsCellChecked
  * ----------------------------------------------------------- *
  FUNCTION IsTextInCell(tcTxt, tvTbl, tnRow, tnCol, tlCaseSense)
    LOCAL lcContents
    lcContents = THIS.GetCellText(tvTbl, tnRow, tnCol)
    IF m.tlCaseSense
      RETURN m.tcTxt $ m.lcContents
    ELSE
      RETURN LOWER(m.tcTxt) $ LOWER(m.lcContents)
    ENDIF
  ENDFUNC  && IsTextInCell
  * ----------------------------------------------------------- *
  FUNCTION GetCellText(tvTblOrCell, tnRow, tnCol)
    * Fetches plain text "value" from a cell, where formatting is ignored and
    * multi-paragraph text is not expected.
    LOCAL loTbl, loCell
    IF PCOUNT() = 1 && assume cell itself passed in, not table
      loCell = m.tvTblOrCell
    ELSE
      IF VARTYPE(m.tvTblOrCell) = "O"
        loTbl = m.tvTblOrCell
      ELSE  && assume table index passed
        loTbl = THIS.oDoc.Tables(m.tvTblOrCell)
      ENDIF
      IF VARTYPE(m.tnCol) = "N"
        loCell = loTbl.Cell(m.tnRow, m.tnCol)
      ELSE  && single cell index
        loCell = loTbl.Range.Cells(m.tnRow)
      ENDIF
    ENDIF && PCOUNT of 1 = cell passed
    RETURN THIS.GetRangeText(m.loCell.Range)
    * alt: L7Doc_GetStructuredRangeText
  ENDFUNC 
  * ----------------------------------------------------------- *
  FUNCTION GetRangeText(toRng)
    LOCAL lcText
    lcText = NVL(toRng.Text, "") && convert empty to string
    lcText = this.cleanRangeText(m.lcText)
    return m.lcText
  ENDFUNC  && GetRangeText
  * ----------------------------------------------------------- *
  FUNCTION cleanRangeText(lcText)
    RETURN L7Doc_cleanRangeText(m.lcText) && UDF in this file 
  ENDFUNC  && cleanRangeText
  * ----------------------------------------------------------- *
  FUNCTION GetRangeTextWithHyperlinks(toRng)  && new!!
    LOCAL lcText, loLinks, loLink, lcLink, lnStart, lnLastStart, lnEnd
    lnStart = toRng.Start
    lnEnd = toRng.End 
    
    lcText = ""
    lnLastEnd = m.lnStart 
    loLinks = toRng.hyperlinks
    for each loLink in loLinks
      if empty(nvl(loLink.Address, ""))
        loop
      endif
      if m.lnLastEnd < loLink.range.start  && insert any text before 1st hyperlink
        lcText = m.lcText + nvl(toRng.Document.Range(m.lnLastEnd, loLink.range.start).text, "")
      endif 
      lnLastEnd = loLink.range.End
      lcLink = HTLink(loLink.Address, nvl(loLink.TextToDisplay,"")) && requires L7HtmlLib be loaded
      lcText = m.lcText + m.lcLink
      
    next && link
    if m.lnLastEnd < m.lnEnd  && add text after last hyperlink (or all text if no hyperlinks)
      lcText = m.lcText + nvl(toRng.Document.Range(m.lnLastEnd, m.lnEnd).text, "")
    endif 
    
    lcText = this.cleanRangeText(m.lcText)
    RETURN m.lcText
  ENDFUNC  && GetRangeTextWithHyperlinks
  * ----------------------------------------------------------- *
  FUNCTION GetCellRange(tvTbl, tnRow, tnCol)
    LOCAL loTbl, loCell
    IF VARTYPE(m.tvTbl) = "O"  && table object passed
      loTbl = m.tvTbl
    ELSE  && table index passed
      loTbl = THIS.oDoc.Tables(m.tvTbl)
    ENDIF
    IF VARTYPE(m.tnCol) = "N"
      loCell = loTbl.Cell(m.tnRow, m.tnCol)
    ELSE  && single cell index
      loCell = loTbl.Range.Cells(m.tnRow)
    ENDIF
    RETURN m.loCell.Range
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION IsNewTable(toPara)  && orig: iiWordImport 2007
    * determine if a Paragraph is the start of a new Table
    LOCAL llRet, loPrev
    llRet = .F.
    IF toPara.Range.Tables.Count > 0 && P is in a table
      loPrev = toPara.Previous
      llRet = ISNULL(loPrev) ; && no previous P
        OR loPrev.Range.Tables.Count = 0 ; && or previous P not in a table
        OR loPrev.Range.Tables(1).NestingLevel < toPara.Range.Tables(1).NestingLevel && or previous P table was "less nested"
      * note: this logic is a complete quirk of the Word object model
    ENDIF 
    RETURN m.llRet
  ENDFUNC  && IsNewTable
  * ------------------------------------------------------------------- *
  function IsListItem(toPara)  && && orig: iiWordImport 2007
    * is a Paragraph part of a list (bullets, etc.)
    return L7Doc_IsListItem(m.toPara)
  endfunc  && IsListItem
enddefine 

*[[ Nothing special here. Promote this to L7Collection:
DEFINE CLASS L7DocParserCollection AS Collection
  * ----------------------------------------------------------- *
  FUNCTION Ravel(llNoRecurse)
    * support debugging by ravelling to array (viewable in watch window)
    IF THIS.Count > 0
      IF VARTYPE(THIS.aRaveledNodes[1]) = "U"
        THIS.AddProperty('aRaveledNodes[1]', .F.)
      ENDIF
      DIMENSION THIS.aRaveledNodes[THIS.Count, 2]
      LOCAL ii, loObj
      FOR ii = 1 TO THIS.Count
        loObj = THIS.Item[m.ii]
        THIS.aRaveledNodes[m.ii, 1] = m.loObj
        THIS.aRaveledNodes[m.ii, 2] = THIS.GetKey(m.ii)
        IF NOT m.llNoRecurse AND PEMSTATUS(loObj, 'ravel', 5)
          loObj.Ravel(m.llNoRecurse) && recursion
        ENDIF
      ENDFOR
    ENDIF
  ENDFUNC  && Ravel
ENDDEFINE
* 07/15/2009 - added ability to force createobject()

  * TO DO: Turn methods into UDFs when the L7DocParser class isn't needed.
  * ------------------------------------------------------------------- *
  function L7Doc_IsListItem(toPara)
    * is a Paragraph part of a list (bullets, etc.)
    local llRet, loFmt
    llRet = .F.
    loFmt = toPara.Range.ListFormat
    llRet = !nvl(loFmt.ListValue, 0) = 0
    return m.llRet
  endfunc  && IsListItem

  *--------------------------------------------            
  function L7Doc_GetStructuredRangeText(toRng, toOpt)
    local lcOut, loRng, lcTmp, loPar, loParRng, loFmt, lcListStr
    lcOut = ""
    * be sure we have a Range:
    loRng = iif(pemstatus(m.toRng, "Range", 5), toRng.Range, m.toRng)
    for each loPar in loRng.paragraphs
      loParRng = loPar.range
      lcTmp = L7Doc_ParseParagraphText(m.loParRng, m.toOpt)
      do case
      case L7Doc_IsListItem(m.loPar) && bullet
        loFmt = loParRng.ListFormat
        lcListStr = loFmt.ListString
        * [[Following needs to handle any ListString types that L7Parsers can interpret/render.
        * [[Currently this is defaulting to bullets too early (if NAN). 
        lcOut = m.lcOut + SPACE(loFmt.ListLevelNumber - 1) + ;
          IIF(VAL(m.lcListStr) = 0 and right(m.lcListStr, 1) <> '.', "*", m.lcListStr) + ; && attempt to grab "a." type items too 
          " " + m.lcTmp + chr(13) + chr(10) 
        * subtract 1 from ListLevelNumber, because plain paragraphs seem to have a ListLevelNumber of 1: first-order bullets start at 2
      otherwise && plain Para
        lcOut = m.lcOut + m.lcTmp + chr(13) + chr(10) + chr(13) + chr(10)
      endcase 
    next loPar
    return m.lcOut
  endfunc && L7Doc_GetStructuredRangeText
  *--------------------------------------------            
  function L7Doc_ParseParagraphText(toPar, toOpt)  
    * Typically called from a higher-order processing logic that
    * is iterating through paragraph objects. 
     
    local loDflt, loRng, ;
      lcText, loLinks, loLink, lcLink, lnStart, lnLastStart, lnEnd, lcTmp
    
    loDflt = createobject("Empty")
    addproperty(loDflt, 'lProcessBold', .t.) 
    addproperty(loDflt, 'lProcessItalics', .t.) 
    addproperty(loDflt, 'lProcessExternalHyperlinks', .t.) 
    addproperty(loDflt, 'lProcessInternalHyperlinks', .f.)  && internal approach TBD--bookmarks etc. not groked yet
    addproperty(loDflt, 'lTerminateAtBreak', .t.) 
    addproperty(loDflt, 'lCleanRangeText', .f. )
    if vartype(m.toOpt) = "O" && options passed in--extend defaults 
      loDflt = extend(.f., m.loDflt, m.toOpt)
    endif 
    * Be sure we have a Range:
    loRng = iif(pemstatus(m.toPar, "Range", 5), toPar.Range, m.toPar)
    
    * plan: unless a complex stack-based approach was created, hyperlinks and inline formats (bold/ital)
    * need to be processed together, or else fetching one loses the other
    lnStart = loRng.Start
    lnEnd = loRng.End 
    lnLastEnd = m.lnStart 
    
    lcText = ""
    loLinks = loRng.hyperlinks
    for each loLink in loLinks
      * insert any text before 1st hyperlink
      if m.lnLastEnd < loLink.range.start  
        lcTmp = L7Doc_ParseCharacterFormats(loRng.document.range(m.lnLastEnd, loLink.range.start), m.loDflt)
        lcText = m.lcText + m.lcTmp
      endif 
      * get text of hyperlink--but only that within current range!
      loTmpRng = loRng.document.range( ;
        max(loLink.range.start, m.lnStart), min(loLink.range.end, m.lnEnd))
      
      lcTmp = L7Doc_ParseCharacterFormats(m.loTmpRng, m.loDflt)
      * decide whether to transform text into link
      do case
      case loDflt.lProcessExternalHyperlinks and !empty(nvl(loLink.Address, ""))
        lcText = m.lcText + HTLink(loLink.Address, m.lcTmp)
      case loDflt.lProcessInternalHyperlinks and !empty(nvl(loLink.SubAddress, ""))
        lcText = m.lcText + HTLink("#" + loLink.SubAddress, m.lcTmp)
      otherwise
        lcText = m.lcText + m.lcTmp
      endcase
      
      lnLastEnd = loLink.range.End
    next && link

    * insert any text before 1st hyperlink
    if m.lnLastEnd < m.lnEnd 
      lcTmp = L7Doc_ParseCharacterFormats(loRng.document.range(m.lnLastEnd, m.lnEnd), m.loDflt)
      lcText = m.lcText + m.lcTmp
    endif 
    
    if loDflt.lCleanRangeText
      lcText = L7Doc_cleanRangeText(m.lcText)
    endif
    return m.lcText
  endfunc && L7Doc_ParseParagraphText

  *--------------------------------------------            
  function L7Doc_ParseCharacterFormats(toRng, toOpt)  
    * short circuit character processing when nothing to do:
    if vartype(m.toOpt) = 'O' and !(toOpt.lProcessBold or toOpt.lProcessItalics)
      return toRng.text 
    endif

    local loDflt, lcNext, lcPref, lcSuf, lnCount, lnChr, loChr, lcOut, llBold, llItalic, llProcessed
    lcOut = ""
    loDflt = createobject("Empty")
    addproperty(loDflt, 'lProcessBold', .t.) 
    addproperty(loDflt, 'lProcessItalics', .t.) 
    addproperty(loDflt, 'lTerminateAtBreak', .t.) 
    addproperty(loDflt, 'lShowTiming', .t.) 
    addproperty(loDflt, 'lResolveGlobally', .t.) && temp switch
    
    if vartype(m.toOpt) = "O" && options passed in--extend defaults 
      loDflt = extend(.f., m.loDflt, m.toOpt)
    endif 
    * Process one character at a time. Sequence to ensure valid HTML.
    lnCount = toRng.Characters.count
    lnSeconds = SECONDS()
    
    if loDflt.lResolveGlobally 
      * check if range-level properties tell full story
      if (!loDflt.lProcessBold or inlist(toRng.Bold, -1, 0)) and ;
        (!loDflt.lProcessItalics or inlist(toRng.Italic, -1, 0))
        
        lcOut = toRng.Text 
        if loDflt.lTerminateAtBreak && get CR out before wrapping
          lcOut = getwordnum(m.lcOut, 1, chr(13))
        endif 
        
        if loDflt.lProcessItalics and toRng.Italic = -1
          lcOut = "<em>" + m.lcOut + "</em>"
        endif
        if loDflt.lProcessBold and toRng.Bold = -1
          lcOut = "<strong>" + m.lcOut + "</strong>"
        endif
        llProcessed = .t. && prevent char-level processing
      endif
    endif
        
    if !m.llProcessed
    * character-level processing--slow
      for lnChr = 1 to lnCount 
        loChr = toRng.Characters(m.lnChr)
        store "" to lcPref, lcSuf
        lcNext = loChr.text
        if asc(m.lcNext) = 13
          if loDflt.lTerminateAtBreak
            exit
          else && potentially support calls for multi-par block
            lcNext = chr(13) + chr(10) + chr(13) + chr(10)
          endif
        endif
        * BOLD:
        if loDflt.lProcessBold
          if loChr.bold = -1
            if !m.llbold
              m.llbold = .t.
              lcPref = "<strong>" + m.lcPref
            endif
          else
            if m.llBold
              lcSuf = m.lcSuf + "</strong>"
              m.llBold = .f.
            endif
          endif
        endif
        * ITALICS:
        if loDflt.lProcessItalics
          if loChr.italic = -1
            if !m.llItalic
              m.llItalic = .t.
              lcPref = m.lcPref + "<em>"
            endif
          else
            if m.llItalic
              lcSuf = "</em>" + m.lcSuf 
              m.llItalic = .f.
            endif
          endif
        endif        
        m.lcOut = m.lcOut + m.lcPref + m.lcNext + m.lcSuf
      next && loChr
      * close any open tags
      if m.llItalic
        lcOut = m.lcOut + "</em>" 
        m.llItalic = .f.
      endif      
      if m.llBold
        lcOut = m.lcOut + "</strong>"
        m.llBold = .f.
      endif
    endif 
    if loDflt.lShowTiming
      ? mline(lcOut,1) + "..."
      ?(SECONDS()-lnSeconds), lnCount, (SECONDS()-lnSeconds)/lnCount
    endif
    return m.lcOut
  endfunc && L7Doc_ParseParagraphText
    
* ----------------------------------------------------------- *
function L7Doc_cleanRangeText(lcText, llNoTrim)
 
  lcText = strtran(m.lcText,chr(2)) && not sure what this is...
  lcText = strtran(m.lcText,chr(150),"-")  && long dash
  lcText = CHRTRAN(STRTRAN(m.lcText, CHR(13) + CHR(7), ""), CHR(7), "")  && purge end-of-cell marker
  lcText = CHRTRAN(STRTRAN(m.lcText, CHR(13) + CHR(160), ""), CHR(160), SPACE(1))  && deal with non-breaking space 
  * smart quote and similar handling (copied from L7Textarea):
  lcText = CHRTRAN( m.lcText, CHR(146) + CHR(147) + CHR(148) + CHR(149), ['""*])
  if !m.llNoTrim
    * (re-)trim:
    lcText = AllTrimX(m.lcText) && doesn't remove leading/trailing non-breaking space
  endif 
  return m.lcText
endfunc  && L7Doc_cleanRangeText


* end: L7Office.prg 

