* L7Trans.PRG
#INCLUDE L7.H

* Level 7 Transaction Classes

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

*** ===================================================== ***
DEFINE CLASS L7ViewTransaction AS LINE
  DIMENSION aCursors[ 1]
  nCursors  = 0
  
  DIMENSION aFailures[ 1]
  nFailures = 0
  lError    = .F.
  
  lSaved                 = NULL
  lReadOnlyUser          = .F.  && set by calling app
  lAllowReadOnlySave     = .F.  && override with TRUE in special cases 
  *                         && like a user saving their own contact info
  lErrorOnUnchangedSave  = .F.
  lAutoCloseViews        = .T.

  * updategrams:
  lWriteXmlupdategram    = .F.
  lXmlupdategramOnErrors = .T.
  cXmlupdategram         = ""

  * logging properties:
  cLogPath               = NULL
  lLogTransactions       = .F.
  lDailyLogFolders       = .T.
  cTransId               = NULL
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    IF THIS.lAutoCloseViews
      THIS.CloseCursors()
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ERROR( lnErr, lcMeth, lnLine )
    THIS.lError = .T.
    THIS.nFailures = AERROR( THIS.aFailures)
    RETURN 
  ENDFUNC  && ERROR
  * --------------------------------------------------------- *
  FUNCTION GetErrorInfo
    IF THIS.lError
      RETURN TRANSFORM( THIS.aFailures[1, 1]) + [ :] + ;
        THIS.aFailures[1, 2]
    ELSE
      RETURN "No error information available. [L7Trans]"
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION OpenView(lcName)
    * opens a view and adds cursor to transaction
    * (any parameters required by view must be available as private)
    USE (m.lcName) AGAIN IN SELECT(m.lcName)
    CURSORSETPROP("Buffering", 5, m.lcName)  && assume we need table buffering
    THIS.AddCursor(m.lcName)
    RETURN 
  ENDFUNC  && AddCursor
  * --------------------------------------------------------- *
  FUNCTION AddCursor( lcName)
    THIS.nCursors = THIS.nCursors + 1
    DIMENSION THIS.aCursors[ THIS.nCursors ]
    THIS.aCursors[ THIS.nCursors ] = m.lcName
    RETURN 
  ENDFUNC  && AddCursor
  * --------------------------------------------------------- *
  FUNCTION AddCursors(lcList) && multi call to addCursor
    LOCAL ii, lnCnt, lcItem
    lnCnt = GETWORDCOUNT(m.lcList, ",")
    FOR ii = 1 TO m.lnCnt
      lcItem = ALLTRIM(GETWORDNUM(m.lcList, m.ii, ","))
      THIS.AddCursor(m.lcItem)
    ENDFOR
    RETURN 
  ENDFUNC  && AddCursors
  * --------------------------------------------------------- *
  FUNCTION CloseCursors()
    * Convenience clean-up method.
    LOCAL ii
    FOR ii = THIS.nCursors TO 1 STEP -1
      USE IN SELECT( THIS.aCursors[ m.ii])
      THIS.nCursors = m.ii - 1
    ENDFOR
    RETURN 
  ENDFUNC  && CloseCursors
  * --------------------------------------------------------- *
  function Save
    * Template Method!
    * In a subclass, override BeforeSave()/AfterSave().
    local llSaved
    if this.lReadOnlyUser AND NOT this.lAllowReadOnlySave
      error "Read only user cannot save."  && [to do: find more graceful approach]
    endif  
    if this.lLogTransactions
      this.lWriteXmlupdategram = .T. && even if not otherwise requested
    endif 
    if this.BeforeSave() AND !this.lError
      llSaved = this.SaveImplementation()
      this.lSaved = m.llSaved
    endif 
    this.AfterSave()
    this.Log()
    return this.lSaved
  endfunc  && Save
  * --------------------------------------------------------- *
  function BeforeSave && blocking hook, return .f. to block
    return .t. 
  endfunc 
  * --------------------------------------------------------- *
  function AfterSave && hook, could tweak logging choices
    return .t. 
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION SaveImplementation
    LOCAL llTransOK, lnCursor
    llTransOK = .T.
    IF NOT THIS.lError
      IF THIS.lErrorOnUnchangedSave
        IF NOT THIS.PendingChanges()
          ERROR "No changes were made!"
          RETURN .F.
        ENDIF
      ENDIF
      THIS.Updategram()
      BEGIN TRANSACTION
      FOR lnCursor = 1 TO THIS.nCursors
        SELECT ( THIS.aCursors[ m.lnCursor] )
        llTransOK = TABLEUPDATE(1)
        IF NOT m.llTransOK AND NOT THIS.lError
          ROLLBACK
          IF NOT THIS.lError  && failure array not popuplated
            THIS.nFailures = AERROR( THIS.aFailures)
          ENDIF
          = RevertTables()  && error recovery function in L7Utils.PRG
          EXIT
        ENDIF
      ENDFOR
      IF m.llTransOK AND NOT THIS.lError
        END TRANSACTION
      ENDIF
    ENDIF
    RETURN m.llTransOK AND NOT THIS.lError
  ENDFUNC  && SaveImplementation
  * --------------------------------------------------------- *
  FUNCTION Updategram
    IF NOT THIS.lWriteXmlupdategram AND NOT THIS.lXmlupdategramOnErrors
      RETURN
    ENDIF 
    LOCAL lcCursors, lnCursor
    lcCursors = ""
    FOR lnCursor = 1 TO THIS.nCursors
      lcCursors = lcCursors + "," + THIS.aCursors[ m.lnCursor]
    ENDFOR 
    TRY
      THIS.cXmlupdategram = XMLUPDATEGRAM(SUBSTR(m.lcCursors,2))
    CATCH
      = .f. 
    ENDTRY 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  function Log
    local loExc, loExc2, lcFile, lcPath, llLog
    try 
      if !this.lSaved 
        if this.lXmlupdategramOnErrors
          llLog = .T.
          lcPath = THIS.GetFailureLogPath()
        endif 
      else  && saved
        if this.lLogTransactions 
          llLog = .T.
          lcPath = THIS.cLogPath
        endif 
      endif  
      if m.llLog
        if !directory(m.lcPath)
          mkdir (m.lcPath)
        endif  
        lcFile = addbs(m.lcPath) + forceext(this.cTransId, "xml")
        strtofile(this.cXmlUpdateGram, m.lcFile)
      endif  
    catch to loExc
      * can't afford to do anything here (perhaps app_log??), as 
      * additional error could mask original transaction result 
      * trying app_log...
      try 
        goL7App.app_log(L7_SEVERITY_WARNING, L7ExceptionMessage(m.loExc))
      catch to loExc2
        = .f.  && giving up
      endtry 
    endtry 
    
    return  
  endfunc && Log 
  * --------------------------------------------------------- *
  function SetID(lcId)
    this.cTransId = m.lcId
    return  
  endfunc  
  * --------------------------------------------------------- *
  function GetFailureLogPath()
    return addbs(this.cLogPath) + "Failures\"
  endfunc  
  * --------------------------------------------------------- *
  function SetLogPath(lcTopPath)  && called by App/Page factory
    local ldDate
    ldDate = date()
    if this.lDailyLogFolders 
      lcTopPath = addbs(m.lcTopPath) + ;
        str(year(m.ldDate), 4, 0)  + "-Q" + str(ceiling(month(m.ldDate) / 3), 1, 0) + "\" + ;
        padl(month(m.ldDate), 2, "0") + "\" + ;
        padl(day(m.ldDate), 2, "0") + "\"
      * e.g., path...\2006-Q4\12\01\
    endif 
    this.cLogPath = addbs(m.lcTopPath)
    return  
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION PendingChanges
    * Are any changes pending (i.e., not yet saved).
    LOCAL llFlag, lnCursor
    llFlag = .F.
    FOR lnCursor = 1 TO THIS.nCursors
      IF GETNEXTMODIFIED( 0, THIS.aCursors[ m.lnCursor]) <> 0
        * Anything but 0 (+ or -) indicates a change.
        llFlag = .T.
        EXIT
      ENDIF
    ENDFOR
    RETURN m.llFlag
  ENDFUNC  && PendingChanges
*!*    * --------------------------------------------------------- *
*!*    FUNCTION AuditInfo
*!*      * Produces audit trail of what was changed.
*!*      LOCAL lcItem, lnCursor, lnMod, lcState, lcKeyExpr, lvKeyVal, ;
*!*        lcTable, lcType, ii, lcGUID
*!*      THIS.AddProperty( 'cID')
*!*      THIS.cID = GetGUID()
*!*      THIS.AddProperty( 'nRecords')
*!*      THIS.nRecords = 0
*!*      THIS.AddProperty( 'nFields')
*!*      THIS.nFields = 0
*!*      THIS.AddProperty( 'aRecords[1,4]')
*!*      THIS.AddProperty( 'aFields[1,4]')
*!*      
*!*      FOR lnCursor = 1 TO THIS.nCursors
*!*        SELECT ( THIS.aCursors[ m.lnCursor])
*!*        lcKeyExpr = CURSORGETPROP("KeyFieldList")
*!*        lcTable = CURSORGETPROP("Tables")
*!*        lnMod = 0
*!*        DO WHILE .T.
*!*          lnMod = GETNEXTMODIFIED( m.lnMod)
*!*          * Anything but 0 (+ or -) indicates a change.
*!*          IF m.lnMod = 0
*!*            EXIT
*!*          ENDIF
*!*          GOTO m.lnMod
*!*          IF m.lnMod < 0
*!*            IF DELETED()
*!*              LOOP
*!*            ELSE
*!*              lcType = "A"
*!*            ENDIF
*!*          ELSE
*!*            lcType = IIF( DELETED(), "D", "U")
*!*          ENDIF
*!*          lvKeyVal = EVALUATE( m.lcKeyExpr)
*!*          lcGUID = GetGUID()
*!*          THIS.AuditInfoHeader( m.lcTable, m.lvKeyVal, m.lcType, m.lcGUID)
*!*          lcState = GETFLDSTATE()
*!*          FOR ii = 2 TO LEN( m.lcState)
*!*            cc = SUBSTR( m.lcState, m.ii)
*!*            DO CASE
*!*            CASE m.lcType = "D"
*!*              * If we're deleting the record, record *all* the old values.
*!*              THIS.AuditInfoDetail( m.lcGUID, FIELD( m.ii - 1), ;
*!*                EVALUATE( FIELD( m.ii - 1), NULL )
*!*            CASE m.lcType = "A"
*!*              * If we're adding, just add the 
*!*        ENDIF
*!*      ENDFOR
*!*    ENDFUNC  && AuditInfo
  * --------------------------------------------------------- *
ENDDEFINE  && L7ViewTransaction
*** ===================================================== ***

