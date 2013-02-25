#INCLUDE L7.H

* ---------------------------------------------------------------- *
FUNCTION ConstructorToAddObject(lcText)
  LOCAL la[1], llFail, lcOut, llClipboard, llInOne, lcName, lcClass, lcInProc, lcIndent, ;
    lnAt1, lnAt2, lnAt3, lnAt4, lnAt5, lnAt6
  llClipboard = EMPTY(m.lctext)
  IF m.llClipboard
    lcText = _CLIPTEXT && work off clipboard if nothing passed
  ENDIF
  lcOut = ""
  ALINES(la, lcText)
  llInOne = .F.
  FOR EACH lcLine IN la
    IF m.llInOne
      lnAt4 = RAT(";", m.lcLine)
      IF m.lnAt4 = 0  && last line
        lcLine = ALLTRIM(m.lcLine)
      ELSE
        lnAt5 = RAT(",", m.lcLine)
        ASSERT m.lnAt5 > 0 MESSAGE "No comma in multiline statement."
        lcLine = ALLTRIM(LEFT(m.lcLine, m.lnAt5 - 1))
      ENDIF
      lnAt6 = AT("=", m.lcLine)
      lcInProc = m.lcInProc + m.lcIndent + SPACE(2) + "." + m.lcLine + CRLF
      IF m.lnAt4 = 0
        lcOut = m.lcOut + m.lcInProc + m.lcIndent + [ENDWITH] + CRLF
        llInOne = .F.
      ENDIF
    ELSE
      IF ALLTRIM(m.lcLine) <> "ADD OBJECT "
        lcOut = m.lcOut + m.lcLine + CRLF
      ELSE
        llInOne = .T.
        lnAt1 = AT("ADD OBJECT", m.lcLine)
        lnAt2 = AT(" AS", m.lcLine)
        lnAt3 = AT(" WITH", m.lcLine)
        lcName = ALLTRIM(SUBSTR(m.lcLine, m.lnAt1 + LEN("ADD OBJECT "), ;
          m.lnAt2 - m.lnAt1 - LEN("ADD OBJECT ")))
        lcClass = ALLTRIM(SUBSTR(m.lcLine, m.lnAt2 + LEN("AS "), ;
          m.lnAt3 - m.lnAt2 - LEN("AS ")))
        lcIndent = LEFT(m.lcLine, m.lnAt1 - 1)
        lcInProc = m.lcIndent + ;
          [.AddObject("] + m.lcName + [", "] + m.lcClass + [")] + CRLF + ;
          m.lcIndent + [WITH .] + m.lcName + CRLF
      ENDIF
    ENDIF
  ENDFOR

  IF m.llClipboard
    _CLIPTEXT = m.lcOut
    MESSAGEBOX("Converted text placed on clipboard. Check carefully.")
  ENDIF
  RETURN m.lcOut
ENDFUNC
* ---------------------------------------------------------------- *
FUNCTION NewForm
  LOCAL lcRet, lcItem, ii, lcFld, lcType, lcStub, aa[1], llUse, laFlds[1], lnFlds, lcFormCls
  lcFormCls = PROPER( SUBSTR( ALIAS(), 3)) + "Form"
  lcRet = ;
    [*** ========================================================= ***] + CRLF + ;
    [DEFINE CLASS ] + m.lcFormCls + [ AS L7Form] + CRLF + ;
    [  cTitle = "] + PROPER( SUBSTR( ALIAS(), 3)) + [ Form"] + CRLF + ;
    [  * --------------------------------------------------------- *] + CRLF + ;
    [  FUNCTION AddControls] + CRLF + ;
    [    WITH THIS] + CRLF 
  lnFlds = AFIELDS( laFlds)
  FOR ii = 1 TO m.lnFlds
    lcFld = laFlds[ m.ii,1]
    lcProperFld = STRTRAN(PROPER(STRTRAN(m.lcFld,"_"," "))," ", "_")
    lcStub = SUBSTR( lcFld, 5)
    lcProperStub = SUBSTR( lcProperFld, 5)
    SET EXACT ON  && egad!!
    llUse = NOT INLIST( UPPER( m.lcStub), "ORIG_PAR_FK", ;
      "ORIG_TIME", "REV_PAR_FK", "REVISION", "MORE_DATA")
    SET EXACT OFF
    IF NOT m.llUse
      LOOP
    ENDIF
    lcType = laFlds[ m.ii, 2]
    lcItem = ""
    DO CASE
    CASE m.lcStub == "PK" 
      lcItem = ;
        [      .AddObject("lbl] + m.lcProperStub + [", "L7Label")] + CRLF + ;
        [      WITH .lbl] + m.lcProperStub + CRLF + ;
        [        .cGroupID = "ADMIN"] + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "ID"] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcStub == "REV_TIME" 
      lcItem = ;
        [      .AddObject("lbl] + m.lcProperStub + [", "L7Label")] + CRLF + ;
        [      WITH .lbl] + m.lcProperStub + CRLF + ;
        [        .cGroupID = "ADMIN"] + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "Last Revised"] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcStub == "INACTIVE" 
      lcItem = ;
        [      .AddObject("chk] + m.lcProperStub + [", "L7Checkbox")] + CRLF + ;
        [      WITH .chk] + m.lcProperStub + CRLF + ;
        [        .cGroupID = "ADMIN"] + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "Delete?"] + CRLF + ;
        [        .lDisabled = NOT m.poContext.lAdmin] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcStub == "STATUS" 
      lcItem = ;
        [      .AddObject("opg] + m.lcProperStub + [", "L7RadioButton")] + CRLF + ;
        [      WITH .opg] + m.lcProperStub + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "] + STRTRAN(m.lcProperStub, "_", " ") + ["] + CRLF + ;
        [        .nRowSourceType = ] + TRANSFORM( L7_ROWSOURCETYPE_VALUE) + [] + CRLF + ;
        [        .cRowSource = THISAPP_] + m.lcFld + [ES] + CRLF + ;
        [        .nStyle = L7_MULTISTYLE_NONE] + CRLF + ;
        [        .lRequired = .T.] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcType = "C"
      lcItem = ;
        [      .AddObject("txt] + m.lcProperStub + [", "L7Textbox")] + CRLF + ;
        [      WITH .txt] + m.lcProperStub + CRLF + ;
        [        .cFieldType = "C"] + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "] + STRTRAN(m.lcProperStub, "_", " ") + ["] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcType = "D"
      lcItem = ;
        [      .AddObject("txt] + m.lcProperStub + [", "L7Textbox")] + CRLF + ;
        [      WITH .txt] + m.lcProperStub + CRLF + ;
        [        .cFieldType = "D"] + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "] + STRTRAN(m.lcProperStub, "_", " ") + ["] + CRLF + ;
        [        .cInstructions = "MM/DD/YYYY"] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcType = "N"
      lcItem = ;
        [      .AddObject("txt] + m.lcProperStub + [", "L7Textbox")] + CRLF + ;
        [      WITH .txt] + m.lcProperStub + CRLF + ;
        [        .cFieldType = "N"] + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "] + STRTRAN(m.lcProperStub, "_", " ") + ["] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcType = "Y"
      lcItem = ;
        [      .AddObject("txt] + m.lcProperStub + [", "L7Textbox")] + CRLF + ;
        [      WITH .txt] + m.lcProperStub + CRLF + ;
        [        .cFieldType = "Y"] + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "] + STRTRAN(m.lcProperStub, "_", " ") + ["] + CRLF + ;
        [        .cInstructions = "$ US"] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcType = "M"
      lcItem = ;
        [      .AddObject("edt] + m.lcProperStub + [", "L7Textarea")] + CRLF + ;
        [      WITH .edt] + m.lcProperStub + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "] + STRTRAN(m.lcProperStub, "_", " ") + ["] + CRLF + ;
        [        .nRows = 5] + CRLF + ;
        [      ENDWITH] + CRLF
    CASE m.lcType = "L"
      lcItem = ;
        [      .AddObject("chk] + m.lcProperStub + [", "L7Checkbox")] + CRLF + ;
        [      WITH .chk] + m.lcProperStub + CRLF + ;
        [        .cControlSource = "] + PROPER( ALIAS()) + [.] + m.lcProperFld + ["] + CRLF + ;
        [        .cLabel = "] + STRTRAN(m.lcProperStub, "_", " ") + ["] + CRLF + ;
        [      ENDWITH] + CRLF
    OTHERWISE
      lcItem = ""
    ENDCASE
    lcRet = m.lcRet + m.lcItem
  ENDFOR
  lcRet = m.lcRet + [    ENDWITH] + CRLF + [  ENDFUNC] + CRLF + [ENDDEFINE  &] + [& ] + m.lcFormCls + CRLF
  _CLIPTEXT = m.lcRet
  MESSAGEBOX( "Form code placed on clipboard.")
ENDFUNC
* ---------------------------------------------------------------- *
FUNCTION NewForm_CONSTRUCTOR  && like NewForm, but using ADD OBJECT
  LOCAL lcRet, lcItem, ii, lcFld, lcType, lcStub, aa[1], llUse, laFlds[1], lnFlds, lcFormCls
  lcFormCls = PROPER( SUBSTR( ALIAS(), 3)) + "Form"
  lcRet = ;
    [DEFINE CLASS ] + m.lcFormCls + [ AS L7Form] + CRLF + ;
    [  cTitle = "] + PROPER( SUBSTR( ALIAS(), 3)) + [ Form"] + CRLF
  lnFlds = AFIELDS( laFlds)
  FOR ii = 1 TO m.lnFlds
    lcFld = laFlds[ m.ii,1]
    lcStub = SUBSTR( lcFld, 5)
    SET EXACT ON
    llUse = NOT INLIST( UPPER( m.lcStub), "PK", "INACTIVE", "ORIG_PAR_FK", ;
      "ORIG_TIME", "REV_PAR_FK", "REV_TIME", "REVISION", "MORE_DATA")
    SET EXACT OFF
    IF NOT m.llUse
      LOOP
    ENDIF
    lcType = laFlds[ m.ii, 2]
    lcItem = ""
    DO CASE
    CASE m.lcStub == "STATUS" 
      lcItem = ;
        [  ADD OBJECT opg] + m.lcStub + [ AS L7RadioButton WITH ;] + CRLF + ;
        [    cControlSource = "] + PROPER( ALIAS()) + [.] + PROPER( m.lcFld) + [", ;] + CRLF + ;
        [    cLabel = "] + PROPER( m.lcStub) + [", ;] + CRLF + ;
        [    nRowSourceType = ] + TRANSFORM( L7_ROWSOURCETYPE_VALUE) + [, ;] + CRLF + ;
        [    cRowSource = THISAPP_] + m.lcFld + [ES, ;] + CRLF + ;
        [    nStyle = L7_MULTISTYLE_NONE, ;] + CRLF + ;
        [    lRequired = .T.] + CRLF
    CASE m.lcType = "C"
      lcItem = ;
        [  ADD OBJECT txt] + m.lcStub + [ AS L7Textbox WITH ;] + CRLF + ;
        [    cControlSource = "] + PROPER( ALIAS()) + [.] + PROPER( m.lcFld) + [", ;] + CRLF + ;
        [    cLabel = "] + PROPER( m.lcStub) + [", ;] + CRLF + ;
        [    cInstructions = "", ;] + CRLF + ;
        [    lRequired = .F.] + CRLF
    CASE m.lcType = "D"
      lcItem = ;
        [  ADD OBJECT txt] + m.lcStub + [ AS L7Textbox WITH ;] + CRLF + ;
        [    cFieldType = "D", ;] + CRLF + ;
        [    cControlSource = "] + PROPER( ALIAS()) + [.] + PROPER( m.lcFld) + [", ;] + CRLF + ;
        [    cLabel = "] + PROPER( m.lcStub) + [", ;] + CRLF + ;
        [    lRequired = .F.] + CRLF
    CASE m.lcType = "N"
      lcItem = ;
        [  ADD OBJECT txt] + m.lcStub + [ AS L7Textbox WITH ;] + CRLF + ;
        [    cFieldType = "N", ;] + CRLF + ;
        [    cControlSource = "] + PROPER( ALIAS()) + [.] + PROPER( m.lcFld) + [", ;] + CRLF + ;
        [    cLabel = "] + PROPER( m.lcStub) + [", ;] + CRLF + ;
        [    cInstructions = "", ;] + CRLF + ;
        [    nMinValue = 0] + CRLF
    CASE m.lcType = "M"
      lcItem = ;
        [  ADD OBJECT edt] + m.lcStub + [ AS L7Textarea WITH ;] + CRLF + ;
        [    cControlSource = "] + PROPER( ALIAS()) + [.] + PROPER( m.lcFld) + [", ;] + CRLF + ;
        [    cLabel = "] + PROPER( m.lcStub) + [", ;] + CRLF + ;
        [    nRows = 5] + CRLF
    CASE m.lcType = "L"
      lcItem = ;
        [  ADD OBJECT chk] + m.lcStub + [ AS L7Checkbox WITH ;] + CRLF + ;
        [    cControlSource = "] + PROPER( ALIAS()) + [.] + PROPER( m.lcFld) + [", ;] + CRLF + ;
        [    cLabel = "] + PROPER( m.lcStub) + ["] + CRLF
    OTHERWISE
      lcItem = ""
    ENDCASE
    lcRet = m.lcRet + m.lcItem
  ENDFOR
  lcRet = m.lcRet + [ENDDEFINE  &] + [& ] + m.lcFormCls + CRLF
  _CLIPTEXT = m.lcRet
  MESSAGEBOX( "Form code placed on clipboard.")
ENDFUNC
* ---------------------------------------------------------------- *
FUNCTION NewTable
* Put a new table on the clipboard.
LPARAMETERS lnCols
* Pass .T. to use current alias!
LOCAL lcType, llUseCurrent
lcType = VARTYPE( m.lnCols )
DO CASE
CASE m.lcType = 'N'
	lnCols = MAX( 1, m.lnCols)
CASE m.lcType = "L" AND m.lnCols = .T. AND NOT EMPTY( ALIAS())
	llUseCurrent = .T.
	lnCols = FCOUNT()
OTHERWISE 
	lnCols = 3
ENDCASE

LOCAL lcText, ii
lcText = ""

lcText = m.lcText + '.WriteLn( [<TABLE CLASS="L7DataTable" WIDTH="100%" BGCOLOR="#FFFFFF" BACKGROUND="" BORDER=1>])' + ;
	CR + CR
lcText = m.lcText + [* Table Title Row:] + CR
lcText = m.lcText + ;
	'.WriteLn( [<TR>])' + CR + ;
	CHR(9) + '.WriteLn( [<TH CLASS="L7DataTableTitle" COLSPAN=' + TRANS( m.lnCols) + '>])' + CR + ;
	CHR(9) + '.WriteLn( [' + IIF( m.llUseCurrent, ALIAS(), "Table Title") + '])' + CR + ;
	CHR(9) + '.WriteLn( [</TH>])' + CR + ;
	'.WriteLn( [</TR>])' + CR + CR
	
lcText = m.lcText + [* Column Heading Row:] + CR
lcText = m.lcText + '.WriteLn( [<TR VALIGN="BOTTOM">])' + CR
FOR ii = 1 TO m.lnCols
	lcText = m.lcText + CHR(9) + '.WriteLn( [<TH ALIGN="CENTER" CLASS="L7DataHeading">' + ;
		IIF( m.llUseCurrent, ;
			PROPER( STRTRAN( FIELD( m.ii), "_", " ")), ;
			"Heading " + TRANS( m.ii)) + ;
		'</TH>])' + CR
ENDFOR
lcText = m.lcText + '.WriteLn( [</TR>])' + CR + CR

lcText = m.lcText + 'SCAN' + CR
lcText = m.lcText + CHR(9) + [* One row per record:] + CR
lcText = m.lcText + CHR(9) + '.WriteLn( [<TR VALIGN="TOP">])' + CR
FOR ii = 1 TO m.lnCols
	lcText = m.lcText + CHR(9) + CHR(9) + ;
		'.WriteLn( [<TD ALIGN="' + ;
		IIF( m.llUseCurrent AND TYPE( FIELD( m.ii)) $ "CM", [LEFT], [CENTER] ) + ;
		'" CLASS="L7DataValue">] + ' + ;
		IIF( m.llUseCurrent, ;
			IIF( TYPE( FIELD( m.ii)) $ "CM", ;
				'TRIM( ' + FIELD( m.ii) + ')', ;
				'TRANS( ' + FIELD( m.ii) + ')' ), ;
			'< Column ' + TRANS( m.ii) + '>' ) + ;
		' + [&nbsp;</TD>] )' + CR
ENDFOR
lcText = m.lcText + CHR(9) + '.WriteLn( [</TR>])' + CR
lcText = m.lcText + 'ENDSCAN' + CR + CR
lcText = m.lcText + [* End of Table:] + CR
lcText = m.lcText + '.WriteLn( [</TABLE>] )' + CR

_CLIPTEXT = m.lcText
ENDFUNC  && NewTable

* ---------------------------------------------------------------- *
FUNCTION NewAdoTable
* Put a new table on the clipboard.
LPARAMETERS lnCols
lnCols = IIF( VARTYPE( m.lnCols) = 'N', MAX( 1, m.lnCols), 3 )

LOCAL lcText, ii
lcText = ""

lcText = m.lcText + '.WriteLn( [<TABLE CLASS="L7DataTable" WIDTH="100%" BGCOLOR="#FFFFFF" BACKGROUND="" BORDER=1>])' + CR
lcText = m.lcText + '.WriteLn( [<TR VALIGN="BOTTOM">])' + CR
FOR ii = 1 TO m.lnCols
	lcText = m.lcText + '.WriteLn( [<TH ALIGN="CENTER"><FONT CLASS="L7DataColumnHeading">Heading</FONT></TH>])' + CR
ENDFOR
lcText = m.lcText + '.WriteLn( [</TR>])' + CR

lcText = m.lcText + 'loQuery.MoveFirst()' + CR
lcText = m.lcText + 'DO WHILE NOT loQuery.EOF' + CR
lcText = m.lcText + CHR(9) + 'loRecord = loQuery.GetRecord()' + CR
lcText = m.lcText + CHR(9) + '.WriteLn( [<TR VALIGN="TOP">])' + CR
FOR ii = 1 TO m.lnCols
	lcText = m.lcText + CHR(9) + '.WriteLn( [<TD ALIGN="CENTER"><FONT CLASS="L7DataColumnValue">] + loRecord.Name + [&nbsp;</FONT></TD>] )' + CR
ENDFOR
lcText = m.lcText + CHR(9) + '.WriteLn( [</TR>])' + CR
lcText = m.lcText + CHR(9) + 'loQuery.MoveNext()' + CR
lcText = m.lcText + 'ENDDO' + CR
lcText = m.lcText + '.WriteLn( [</TABLE>] )' + CR

_CLIPTEXT = m.lcText
ENDFUNC  && NewTable

* ---------------------------------------------------------------- *
FUNCTION NewRecordElement(lcClass)
  * Put a new table on the clipboard (1 field per row).
  LOCAL lnFlds, laFlds[1], lcTxt, ii, lcLabel, lcExpr, lcStem, lcFld, lcType, ;
    lcStd, lcAdmin, llAdm
  STORE "" TO lcStd, lcAdmin, lcTxt, lcFKTbl
  lnFlds = AFIELDS(laFlds)
  FOR ii = 1 TO m.lnFlds
    lcFld = laFlds[m.ii, 1]
    lcType = laFlds[m.ii, 2]
    lcBase = LEFT(m.lcFld, 3)
    lcStem = SUBSTR(m.lcFld, 5)
    lcLabel = PROPER(STRTRAN(m.lcStem, "_", SPACE(1)))
    IF INLIST(m.lcStem, "ORIG_PAR_FK", "REV_PAR_FK", "MORE_DATA")
      LOOP
    ENDIF
    llAdm = INLIST(m.lcStem, "ORIG_TIME", "REV_TIME", "INACTIVE", "PK", "NOTES")
    DO CASE
    CASE m.lcStem == "REV_TIME"
      lcLabel = "Last Modified"
      lcExpr = 'TRANSFORM(loData.' + m.lcFld + ') + [ by ] + ' + ;
        'goL7App.oLookup.GetUserName(loData.' + m.lcBase + '_Rev_Par_FK)'
    CASE m.lcStem == "ORIG_TIME"
      lcLabel = "Created"
      lcExpr = 'TRANSFORM(loData.' + m.lcFld + ') + [ by ] + ' + ;
        'goL7App.oLookup.GetUserName(loData.' + m.lcBase + '_Orig_Par_FK)'
    CASE RIGHT(m.lcStem, 2) == "FK"
      lcLabel = LEFT(m.lcStem, LEN(m.lcStem) - 3)
      lcFKTbl = RIGHT(m.lcLabel, 3)
      lcExpr = [HTLink(StuffUrl(THIS.cUrlA, 2, "] + m.lcFKTbl + [Home", "] + ;
        m.lcFKTbl + [", loData.] + m.lcFld + [), "] + m.lcLabel + [ Page...")]
    CASE m.lcType = "M"
      lcExpr = "L7ParseOnView(loData." + m.lcFld + ")"
    CASE m.lcType = "C"
      lcExpr = "TRIM(loData." + m.lcFld + ")"
    OTHERWISE
      lcExpr = "loData." + m.lcFld
    ENDCASE
    IF m.llAdm
      TEXT TO lcAdmin TEXTMERGE ADDITIVE NOSHOW
        .AddRow("<<lcLabel>>", <<m.lcExpr>>, .F., "Private")
        
      ENDTEXT
    ELSE
      TEXT TO lcStd TEXTMERGE ADDITIVE NOSHOW 
        .AddRow("<<lcLabel>>", <<m.lcExpr>>, .F.)
      
      ENDTEXT
    ENDIF
  ENDFOR
  TEXT TO lcTxt NOSHOW 
    LOCAL loRecord
    loRecord = CREATEOBJECT("<<EVL(m.lcClass, 'L7RecordElement')>>")
    WITH loRecord
      .AddHeading('<<PROPER(ALIAS())>> Information')
<<m.lcStd>>
      IF poContext.lCore
        .AddHeading('Administrative Information')
<<m.lcAdmin>>
      ENDIF 
    ENDWITH
    
  ENDTEXT
  lcTxt = TEXTMERGE(m.lcTxt)
  _CLIPTEXT = m.lcTxt
  MESSAGEBOX( "Record code placed on clipboard.")
  RETURN 
ENDFUNC  && NewRecordElement
* ---------------------------------------------------------------- *

* ---------------------------------------------------------------- *
FUNCTION NewRecordTable
* Put a new table on the clipboard (1 field per row).
LPARAMETERS lnCols
lnCols = IIF( VARTYPE( m.lnCols) = 'N', MAX( 1, m.lnCols), 3 )

LOCAL lcText, ii
lcText = ""

lcText = m.lcText + '.WriteLn( [<TABLE CLASS="L7RecordTable" WIDTH="100%" BGCOLOR="#FFFFFF" BACKGROUND="" BORDER=0>])' + CR
lcText = m.lcText + '.WriteLn( [<TR VALIGN="BOTTOM">])' + CR
lcText = m.lcText + '.WriteLn( [<TH COLSPAN=2 ALIGN="CENTER"><FONT CLASS="L7RecordTableHeading">Table Heading</FONT></TH>])' + CR
lcText = m.lcText + '.WriteLn( [</TR>])' + CR

FOR ii = 1 TO m.lnCols
	lcText = m.lcText + CHR(9) + '.WriteLn( [<TR VALIGN="TOP">])' + CR
	lcText = m.lcText + CHR(9) + CHR(9) + ;
		'.WriteLn( [<TD CLASS="L7RecordRowHeading" ALIGN="RIGHT"><FONT CLASS="L7RecordRowHeading">Heading:</FONT></TD>] )' + CR
	lcText = m.lcText + CHR(9) + CHR(9) + ;
		'.WriteLn( [<TD CLASS="L7RecordRowValue"><FONT CLASS="L7RecordRowValue">] + "[value]" + [&nbsp;</FONT></TD>] )' + CR
	lcText = m.lcText + CHR(9) + '.WriteLn( [</TR>])' + CR
ENDFOR
lcText = m.lcText + '.WriteLn( [</TABLE>] )' + CR

_CLIPTEXT = m.lcText
ENDFUNC  && NewRecordTable
* ---------------------------------------------------------------- *

FUNCTION ModiCommSearch( lcString, lcFiles)
  * MODI COMM all files containing lcString.
  lcFiles = IIF( EMPTY( m.lcFiles), '*.prg', m.lcFiles)
  LOCAL laFiles[1], lnFiles, ii, lcFile, hh
  lnFiles = ADIR( laFiles, m.lcFiles)
  FOR ii = 1 TO m.lnFiles
    lcFile = laFiles[ m.ii, 1]
    hh = FOPEN( m.lcFile)
    IF hh < 0
      LOOP
    ENDIF
    = FCLOSE( m.hh)
    IF ATC( m.lcString, FILETOSTR( m.lcFile)) > 0
      MODIFY COMMAND ( m.lcFile) NOWAIT
    ENDIF
  ENDFOR
  
ENDFUNC && ModiCommSearch

* ---------------------------------------------------------------- *
DEFINE CLASS L7FormTricks AS CUSTOM
  * If you can instance a form, this will output an L7Record script
  * code to the clipboard.
  FUNCTION Form2Record(loForm, lcDataPref)
    LOCAL loControl, lcTxt
    lcTxt = []
    FOR EACH loControl IN loForm.Controls
      IF NOT loControl.lVisible = .F. AND ;
        VARTYPE(loControl.cControlSource) = "C" AND ;
        NOT EMPTY(loControl.cControlSource)
        lcTxt = m.lcTxt + ;
          TEXTMERGE([.AddRow("<<loControl.cLabel>>", <<EVL(m.lcDataPref,"")>><<JUSTEXT(loControl.cControlSource)>>)]) + ;
          CHR(13) + CHR(10)
      ENDIF
    ENDFOR
    RETURN m.lcTxt
  ENDFUNC
ENDDEFINE
