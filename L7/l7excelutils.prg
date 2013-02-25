* L7ExcelUtils.PRG

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

#DEFINE L7EXCEL_STARTROW 2  && row to start a list in a new sheet
#DEFINE L7EXCEL_STARTCOL 2  && col to start a list in a new sheet

IF PROGRAM(-1) = 1
  __Test__()
ENDIF   
RETURN 

FUNCTION __Test__
CursorToSheet()
ENDFUNC 

FUNCTION CursorToSheet(tcAlias, tcShtName, tlRecnoCol, tlMakeTable)
  * Takes any VFP cursor and creates an Excel list in an existing or new worksheet.
  * By default, tries to use a sheet w/ same name as alias.
  *
  * Important: For now, uses currently open active workbook!!
  *
  * [To Do: opening of Excel, specifying a file, etc.]
  
  LOCAL ;
    loWB   as Excel.Workbook, ;
    loXl   as Excel.Application, ;
    loSht  as Excel.Worksheet, ;
    loRng  as Excel.Range
  LOCAL lcAlias, lcShtName, lnFieldColStart
  
  loXl = GETOBJECT(, "Excel.Application")
  loWb = loXl.ActiveWorkbook
  lcAlias = EVL(m.tcAlias, ALIAS())
  lcShtName = EVL(m.tcShtName, m.lcAlias)
  lnFieldColStart = L7EXCEL_STARTCOL + IIF(m.tlRecnoCol, 1, 0)
  TRY 
    loSht = loWb.Sheets(m.lcShtName)
  CATCH TO loExc  && no sheet by specified name, create new sheet
    loSht = loWb.Sheets.Add(,loWb.Sheets.Item(loWb.Sheets.Count))
    loSht.Name = L7Proper(m.lcShtName)
  ENDTRY 
  loSht.Select
  IF m.tlRecnoCol
    loSht.Cells(L7EXCEL_STARTROW, L7EXCEL_STARTCOL).Value = "RECNO"
  ENDIF 
  FOR lnFld = 1 TO FCOUNT()
    loSht.Cells(L7EXCEL_STARTROW, m.lnFieldColStart - 1 + m.lnFld).Value = L7Proper(FIELD(m.lnFld))

  NEXT lnFld
  lnRecno = 0
  SCAN 
    lnRecno = lnRecno + 1 
    IF m.tlRecnoCol
      loSht.Cells(L7EXCEL_STARTROW + m.lnRecno, L7EXCEL_STARTCOL).Value = m.lnRecno
    ENDIF 
    FOR lnFld = 1 TO FCOUNT()
      lvVal = EVL(NVL(EVAL(FIELD(m.lnFld)), ''),'')
      loSht.Cells(L7EXCEL_STARTROW + m.lnRecno, m.lnFieldColStart - 1 + m.lnFld).Value = m.lvVal

    NEXT lnFld
    
  ENDSCAN  
  
  * Now select the range and turn it into a table/list:
  if m.tlMakeTable
    loRng = loSht.Range(;
      loSht.Cells(L7EXCEL_STARTROW, L7EXCEL_STARTCOL), ;
      loSht.Cells(L7EXCEL_STARTROW + m.lnRecno, L7EXCEL_STARTCOL - IIF(m.tlRecnoCol, 0, 1) + FCOUNT()))
      
    loSht.ListObjects.Add(1,loRng,, .F.)
    * [[ above will throw OLE error if another (old) table is stil there, overlapping
  endif
  
  return 
ENDFUNC  && CursorToSheet

FUNCTION L7Proper(tcName)
  RETURN CHRTRAN(PROPER(CHRTRAN(TRIM(m.tcName), "_", " ")), " ", "_")
ENDFUNC 
