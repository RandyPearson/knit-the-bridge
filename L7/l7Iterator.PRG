* L7Iterator.PRG
*
* Data iterator classes used by L7Table and L7Grid.

#INCLUDE L7.H
#INCLUDE ADO.H

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

define class L7FolderIterator_Sample as line
  function init(tcPath)
    local loIter as L7FolderIterator
    loIter = createobject("L7FolderIterator")
    bindevent(loIter, "visitFile", this, "onFile")
    loIter.traverse(m.tcPath)
  endfunc 
  function onFile(toFile, toState)
    ? toFile.Name
  endfunc
enddefine 
  
*** ========================================================== ***
define class L7FolderIterator AS CUSTOM 
  lFilesFirst = .t.
  * oFSO
  * ---------------------------------------------------------- *
  function traverseSubfolders(toFolder, toState)  
    local loFolder
    toState.Depth = toState.Depth + 1 
    for each loFolder in toFolder.subFolders
      raiseevent(this, "visitFolder", m.loFolder, m.toState)  && nested
    next loFolder
    toState.Depth = toState.Depth - 1 
    return 
  endfunc 
  * ---------------------------------------------------------- *
  function traverseFiles(toFolder, toState)  
    local loFile
    for each loFile in toFolder.files
      raiseevent(this, "visitFile", m.loFile, m.toState)
    next loFolder
    return 
  endfunc 
  * ---------------------------------------------------------- *
  function visitFile(toFile, toState)  
    return 
  endfunc 
  * ---------------------------------------------------------- *
  function visitFolder(toFolder, toState)  
    toState.CurrentFolder = toFolder.Path
    if this.lFilesFirst
      this.traverseFiles(m.toFolder, m.toState)
      this.traverseSubfolders(m.toFolder, m.toState)
    else
      this.traverseSubfolders(m.toFolder, m.toState)
      this.traverseFiles(m.toFolder, m.toState)
    endif 
    return 
  endfunc 
  * ---------------------------------------------------------- *
  function traverse(tvFolder, toState)  
    local loFolder, loState
    loState = iif(vartype(m.toState) = 'O', m.toState, createobject("Empty"))
    if vartype(m.tvFolder) = "C"
      local lofso as Scripting.FileSystemObject
      loFso = createobject("Scripting.FileSystemObject")
      loFolder = loFso.GetFolder(m.tvFolder)
    else
      loFolder = m.tvFolder
    endif
    if !pemstatus(m.loState, 'Recurse', 5)
      addproperty(m.loState, 'Recurse', .t.)
    endif 
    if !pemstatus(m.loState, 'Cancel', 5)
      addproperty(m.loState, 'Cancel', .f.)
    endif 
    addproperty(m.loState, "RootPath", loFolder.Path)
    addproperty(m.loState, "CurrentFolder", loFolder.Path)
    addproperty(m.loState, "Depth", 1)
    raiseevent(this, "visitFolder", m.loFolder, m.loState)
    return 
  endfunc 
enddefine  


*** ========================================================== ***
DEFINE CLASS L7DataIterator AS CUSTOM
  lError        = .F.
  cErrorMessage = ""

  lObjectBased = .f.  && set .t. for collections--suggests client calling getRecord() always 
  
  EOF = .F.
  nFieldCount    = 0
  nAbsoluteRecno = 0
  nRecCount      = 0

  cAlias = ""  
  lStructureAvailable = .F.
  DIMENSION aStructure[ 1, 5]
  
  ** PROTECTED cFilter
  cFilter = ""

  * ---------------------------------------------------------- *
  FUNCTION nAbsoluteRecNo_ACCESS
    RETURN RECNO( THIS.cAlias )
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION nRecCount_ACCESS
    LOCAL lnCount
    IF NOT EMPTY(THIS.cFilter)
      LOCAL lnRec
      lnRec = RECNO()
      COUNT FOR THIS.&cFilter TO lnCount
      GOTO m.lnRec
    ELSE
      lnCount = RECCOUNT( THIS.cAlias )
    ENDIF
    RETURN m.lnCount
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION nFieldCount_ACCESS
    RETURN FCOUNT( THIS.cAlias )
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION EOF_ACCESS
    RETURN EOF( THIS.cAlias )
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION INIT( lvParm)
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION SetFilter(lcFilter)
    * Use leading dot notation to support objects too. 
    * Ex:   .Status = "OPEN"
    IF EMPTY(m.lcFilter)
      this.cFilter = ""
    ELSE
      * Support "." WITH-like notation to refer to a field in the alias
      * and allow inteface compatibility with objects? EXPERMIENTAL!!
      lcFilter = STRTRAN(m.lcFilter, [.T.], [//TRUE//])
      lcFilter = STRTRAN(m.lcFilter, [.F.], [//FALSE//])
      lcFilter = LTRIM(;
        STRTRAN(" " + m.lcFilter, " .", " " + THIS.cAlias + ".") ;
        )
      lcFilter = STRTRAN(m.lcFilter, [//TRUE//], [.T.])
      lcFilter = STRTRAN(m.lcFilter, [//FALSE//], [.F.])
      THIS.cFilter = m.lcFilter
    ENDIF 
  ENDFUNC
  * ---------------------------------------------------------- *
  PROTECTED FUNCTION EnumerateStructure
    AFIELDS( THIS.aStructure, THIS.cAlias )
    THIS.lStructureAvailable = .T.
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION GetRecord()
    * returns an object
    * [[ check eof()/bof() each time, or trust developer??
    LOCAL loRec
    SELECT (THIS.cAlias)
    SCATTER MEMO NAME loRec
    RETURN m.loRec
  ENDFUNC 
  * ---------------------------------------------------------- *
  FUNCTION GetFieldName( lnField)
    IF BETWEEN( m.lnField, 1, THIS.nFieldCount)
      RETURN FIELD( m.lnField, THIS.cAlias )
    ELSE
      RETURN ""
    ENDIF
  ENDFUNC  && GetFieldName
  * ---------------------------------------------------------- *
  FUNCTION GetFieldType( lnField)
    IF BETWEEN( m.lnField, 1, THIS.nFieldCount)
      RETURN TYPE( FIELD( m.lnField, THIS.cAlias))
    ELSE
      RETURN "U"
    ENDIF
  ENDFUNC  && GetFieldType
  * ---------------------------------------------------------- *
  FUNCTION GetFieldLength( lnField)
    IF NOT THIS.lStructureAvailable
      THIS.EnumerateStructure()
    ENDIF
    IF BETWEEN( m.lnField, 1, THIS.nFieldCount)
      RETURN THIS.aStructure[ m.lnField, 3]
    ELSE
      RETURN 0
    ENDIF
  ENDFUNC  && GetFieldLength
  * ---------------------------------------------------------- *
  FUNCTION GetFieldPrecision( lnField)
    IF NOT THIS.lStructureAvailable
      THIS.EnumerateStructure()
    ENDIF
    IF BETWEEN( m.lnField, 1, THIS.nFieldCount)
      RETURN THIS.aStructure[ m.lnField, 4]
    ELSE
      RETURN 0
    ENDIF
  ENDFUNC  && GetFieldPrecision
  * ---------------------------------------------------------- *
  FUNCTION GetFieldValue( lcField)
    SELECT ( THIS.cAlias )
    RETURN EVAL( m.lcField)
  ENDFUNC  && GetFieldValue
  * ---------------------------------------------------------- *
  FUNCTION MoveFirst
    SELECT ( THIS.cAlias )
    GO TOP
    IF NOT EMPTY(THIS.cFilter)
      DO WHILE NOT EOF() AND NOT EVALUATE(THIS.cFilter)
        SKIP
      ENDDO
    ENDIF
  ENDFUNC  && MoveFirst
  * ---------------------------------------------------------- *
  FUNCTION MoveNext
    SELECT ( THIS.cAlias )
    DO WHILE NOT EOF()
      SKIP
      IF NOT EMPTY(THIS.cFilter) AND NOT EVALUATE(THIS.cFilter) && record not in filter
        LOOP
      ELSE  && record OK
        EXIT
      ENDIF
    ENDDO
  ENDFUNC  && MoveNext
  * ---------------------------------------------------------- *
  FUNCTION Move( lnRecs, lnBase )
    ** TO DO: Make compatible with 2nd parameter in ADO.
    IF NOT EMPTY(THIS.cFilter)
      ERROR "Move() iterator method not available for filtered datasets."  && [[ deal w/ this later
    ENDIF
    SELECT ( THIS.cAlias )
    SKIP m.lnRecs
  ENDFUNC  && Move
  * ---------------------------------------------------------- *
  FUNCTION AddNew()
    SELECT ( THIS.cAlias )
    APPEND BLANK    
  ENDFUNC  && AddNew
  * ---------------------------------------------------------- *
ENDDEFINE  && L7DataIterator

*** ========================================================== ***
DEFINE CLASS L7CursorIterator AS L7DataIterator
  lObjectBased = .f.  
  * Sub-class for VFP cursors.
  FUNCTION INIT( lvParm)
    IF VARTYPE( m.lvParm) = "C"  && specific alias passed in
      THIS.cAlias = m.lvParm
    ELSE
      * Assume current alias:
      THIS.cAlias = ALIAS()
    ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
ENDDEFINE  && L7CursorIterator

*** ========================================================== ***
DEFINE CLASS L7CollectionIterator AS L7BizIterator
  lObjectBased = .t.  && collections--suggests client calling getRecord() always 
  nActiveItem = 0  && don't assume collection maintains any state
  * ---------------------------------------------------------- *
  FUNCTION EOF_ACCESS
    RETURN THIS.nActiveItem > THIS.oBiz.Count
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION oActive_ACCESS
    RETURN THIS.oBiz.Item[THIS.nActiveItem]
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION SetFilter(lcFilter)
    THIS.cFilter = m.lcFilter
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION MoveFirst
    THIS.nActiveItem = 1 
    IF NOT EMPTY(THIS.cFilter)
      LOCAL loItem
      DO WHILE NOT THIS.EOF
        loItem = THIS.oActive
        WITH loItem  && supports . notation
          IF NOT EVALUATE(THIS.cFilter)
            THIS.nActiveItem = THIS.nActiveItem + 1 
            LOOP
          ELSE
            EXIT 
          ENDIF
        ENDWITH 
      ENDDO
    ENDIF
  ENDFUNC  && MoveFirst
  * ---------------------------------------------------------- *
  FUNCTION MoveNext
    THIS.nActiveItem = THIS.nActiveItem + 1 
    IF NOT EMPTY(THIS.cFilter)
      LOCAL loItem
      DO WHILE NOT THIS.EOF
        loItem = THIS.oActive
        WITH loItem  && supports . notation
          IF NOT EVALUATE(THIS.cFilter)
            THIS.nActiveItem = THIS.nActiveItem + 1 
            LOOP
          ELSE
            EXIT 
          ENDIF
        ENDWITH 
      ENDDO
    ENDIF
  ENDFUNC  && MoveNext
  * ---------------------------------------------------------- *
  FUNCTION Move( lnRecs, lnBase )
    ** TO DO: Make compatible with 2nd parameter in ADO.
    IF NOT EMPTY(THIS.cFilter)
      ERROR "Move() iterator method not available for filtered datasets."  && [[ deal w/ this later
    ENDIF
    THIS.nActiveItem = THIS.nActiveItem + m.lnRecs
  ENDFUNC  && Move
  * ---------------------------------------------------------- *
  * Not really intended. Usage of this iterator is intended to
  * come after a collection is "loaded".
  FUNCTION AddNew(loItem)  && Warning: different interface!!
    THIS.oBiz.Add(loItem)
    THIS.nActiveItem = THIS.oBiz.Count
  ENDFUNC  && AddNew
ENDDEFINE

*** ========================================================== ***
DEFINE CLASS L7BizIterator AS L7DataIterator
  lObjectBased = .t.  && collections--suggests client calling getRecord() always 
  * Sub-class for L7Biz business objects.
  oBiz = NULL
  oActive = NULL
  oEmpty = NULL
  * ---------------------------------------------------------- *
  FUNCTION oActive_ACCESS
    ** IF THIS.EOF (this didn't work--same object returned)
    IF THIS.oBiz.nActiveItem > THIS.oBiz.nItems
      RETURN THIS.oEmpty
    ELSE
      RETURN THIS.oBiz.aItems[THIS.oBiz.nActiveItem]
    ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION INIT( lvParm)
    IF VARTYPE( m.lvParm) = "O"  && business object passed in
      THIS.oBiz = m.lvParm
    ENDIF
  ENDFUNC  && INIT
  * ---------------------------------------------------------- *
  FUNCTION EOF_ACCESS
    ** RETURN THIS.oBiz.nActiveItem > THIS.oBiz.nItems
    RETURN THIS.oBiz.nActiveItem > THIS.oBiz.nOldItems
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION SetFilter(lcFilter)
    ERROR "Filtering not implemented for BizObj iterators."
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION GetRecord()
    RETURN this.oActive  
  ENDFUNC 
  * ---------------------------------------------------------- *
  FUNCTION GetFieldValue( lcField)
    * ALT: Endow L7Biz with a GetFieldValue(<fld>,<nItem>) method.
    ** LOCAL lnItem, loObj, lcEval
    ** lnItem = THIS.oBiz.nActiveItem
    ** loObj = THIS.oBiz.aItems[m.lnItem]
    LOCAL loObj, lcEval
    loObj = THIS.oActive
    * Deal with concatenated expression:
    lcEval = "loObj." + STRTRAN(m.lcField,"+","+loObj.")
    ** RETURN loObj.&lcField
    RETURN EVALUATE(m.lcEval)
  ENDFUNC  && GetFieldValue
  * ---------------------------------------------------------- *
  FUNCTION MoveFirst
    THIS.oBiz.nActiveItem = 1 
  ENDFUNC  && MoveFirst
  * ---------------------------------------------------------- *
  FUNCTION MoveNext
    THIS.oBiz.nActiveItem = THIS.oBiz.nActiveItem + 1 
  ENDFUNC  && MoveNext
  * ---------------------------------------------------------- *
  FUNCTION Move( lnRecs, lnBase )
    ** TO DO: Make compatible with 2nd parameter in ADO.
    THIS.oBiz.nActiveItem = THIS.oBiz.nActiveItem + m.lnRecs
  ENDFUNC  && Move
  * ---------------------------------------------------------- *
  FUNCTION AddNew()
    THIS.oBiz.Add()
    * Should be redundant?:
    THIS.oBiz.nActiveItem = THIS.oBiz.nItems
  ENDFUNC  && AddNew
  * ---------------------------------------------------------- *
ENDDEFINE  && L7BizIterator 

*** ========================================================== ***
DEFINE CLASS L7AdoIterator AS L7DataIterator
  * Sub-class for ADO recordsets.
  oRS = NULL
  cAlias = ""  && alias for conversion to VFP record

  cCreateCommand = ""
  cInsertCommand = ""

  lRecordAtATime = .F.
  lCursorCreated = .F.

  *** IDEA: Maybe we can create a 1-record cursor each time we move to a new 
  ***   record (MoveFirst, MoveNext, Move, ..). Then we can refer to fields
  ***   as regular expressions and have same interface!

  * ---------------------------------------------------------- *
  FUNCTION lRecordAtATime_ACCESS
    IF NOT THIS.lRecordAtATime
      * We want a VFP cursor, so make sure it has been created!
      IF NOT THIS.lCursorCreated
        THIS.CreateCursor()
      ENDIF
    ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION cAlias_ACCESS
    IF EMPTY( THIS.cAlias)
      THIS.cAlias = THIS.Name + "_Data_"
    ENDIF
    RETURN THIS.cAlias
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION nFieldCount_ACCESS
    RETURN THIS.oRS.Fields.Count
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION EOF_ACCESS
    IF THIS.lRecordAtATime
      RETURN THIS.oRS.EOF
    ELSE
      RETURN DODEFAULT()
    ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION INIT( lvParm)
    IF VARTYPE( m.lvParm) = "O"  && recordset object passed in
      THIS.oRS = m.lvParm
    ENDIF
  ENDFUNC  && INIT
  * ---------------------------------------------------------- *
  FUNCTION SetFilter(lcFilter)
    ERROR "Filtering not implemented for ADO iterators."
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION SelectAlias
    IF USED( THIS.cAlias)
      IF NOT ALIAS() = THIS.cAlias
        SELECT ( THIS.cAlias)
      ENDIF
    ELSE  && ??
      SELECT 0
    ENDIF
  ENDFUNC  && SelectAlias
  * ---------------------------------------------------------- *
  FUNCTION BuildCommands
    THIS.SelectAlias()
    USE  && clear out old, which may have invalid sizes

    LOCAL lcBuild, lcInsert, lcCmd
    STORE "" TO lcBuild, lcInsert
      
    FOR EACH loField IN THIS.oRS.Fields
      lnType = loField.Type
      * Try to pick the best VFP field type for each ADO
      * field type:
      DO CASE
      CASE INLIST( m.lnType, ADCHAR, ADBSTR ) && Character.
        lcBuild = m.lcBuild + [, ] + loField.Name + ;
          [ C(] + TRANS( loField.DefinedSize) + [)]
      CASE INLIST( m.lnType, ADVARCHAR, ADLONGVARCHAR, ;
        ADBINARY, ADVARBINARY, ADLONGVARBINARY, ;
        ADWCHAR, ADVARWCHAR, ADLONGVARWCHAR )
        *
        lcBuild = m.lcBuild + [, ] + loField.Name + [ M]
      CASE INLIST( m.lnType, ADNUMERIC, ADVARNUMERIC )
        lcBuild = m.lcBuild + [, ] + loField.Name + ;
          [ N(] + TRANS( loField.DefinedSize) + [,] + ;
          TRANS( loField.Precision) + [)]
      CASE INLIST( m.lnType, ADSINGLE )
        lcBuild = m.lcBuild + [, ] + loField.Name + ;
          [ F(] + TRANS( loField.DefinedSize) + [,] + ;
          TRANS( loField.Precision) + [)]
      CASE INLIST( m.lnType, ADDOUBLE )
        lcBuild = m.lcBuild + [, ] + loField.Name + ;
          [ B(] + TRANS( loField.DefinedSize) + [,] + ;
          TRANS( loField.Precision) + [)]
      CASE INLIST( m.lnType, ADINTEGER, ADSMALLINT, ADTINYINT, ;
        ADUNSIGNEDINT, ADUNSIGNEDTINYINT, ADUNSIGNEDSMALLINT, ;
        ADUNSIGNEDBIGINT )
        *
        lcBuild = m.lcBuild + [, ] + loField.Name + [ I]
      CASE INLIST( m.lnType, ADBOOLEAN )
        lcBuild = m.lcBuild + [, ] + loField.Name + [ L]
      CASE INLIST( m.lnType, ADCURRENCY )
        lcBuild = m.lcBuild + [, ] + loField.Name + [ Y]
      CASE INLIST( m.lnType, ADDBDATE, ADDATE )
        lcBuild = m.lcBuild + [, ] + loField.Name + [ D]
      CASE INLIST( m.lnType, ADDBTIME, ADDBTIMESTAMP )
        lcBuild = m.lcBuild + [, ] + loField.Name + [ T]
      OTHERWISE
        
        *** NOTE: Some types above are not tested and there
        ***   are several ADO types that are not yet included.
        ***   Please contact me if you have a problem/need
        ***   with a specific type!
        
        LOOP  && don't allow lcInsert to be altered
      ENDCASE
      lcInsert = m.lcInsert + ;
        ', THIS.oRS.Fields["' + loField.Name + ;
        '"].Item.Value'
    ENDFOR
    IF NOT EMPTY( m.lcBuild)
      THIS.cCreateCommand = 'CREATE CURSOR ' + THIS.cAlias + ' (' + ;
        SUBSTR( m.lcBuild, 2) + ')'
      THIS.cInsertCommand = 'INSERT INTO ' + THIS.cAlias + ' VALUES (' + ;
        SUBSTR( m.lcInsert, 2) + ')'
    ENDIF
  ENDFUNC  && BuildCommands
  * ---------------------------------------------------------- *
  FUNCTION CreateCursor
    THIS.BuildCommands()
    THIS.SelectAlias()
    LOCAL lcCmd
    lcCmd = THIS.cCreateCommand
    &lcCmd
    lcCmd = THIS.cInsertCommand
    THIS.oRS.MoveFirst()
    DO WHILE NOT THIS.oRS.EOF
      &lcCmd
      THIS.oRS.MoveNext()
    ENDDO
    THIS.lCursorCreated = .T.
  ENDFUNC  && CreateCursor
  * ---------------------------------------------------------- *
  FUNCTION ConvertRecord
    IF NOT THIS.EOF
      ** Iterate the Fields collection and create a 1-record
      ** cursor with the values
      THIS.SelectAlias()
      USE  && clear out old, which may have invalid sizes
      LOCAL lcBuild, lcInsert, lcCmd
      STORE "" TO lcBuild, lcInsert, lcVfpType
      
      FOR EACH loField IN THIS.oRS.Fields
        lnType = loField.Type
        lcVfpType = THIS.VfpType( m.lnType)
        * Try to pick the best VFP field type for each ADO
        * field type:
        DO CASE
        CASE INLIST( m.lnType, ADCHAR, ADBSTR ) && Character.
          lcBuild = m.lcBuild + [, ] + loField.Name + ;
            [ C(] + TRANS( loField.ActualSize) + [)]
        CASE INLIST( m.lnType, ADVARCHAR, ADLONGVARCHAR, ;
          ADBINARY, ADVARBINARY, ADLONGVARBINARY, ;
          ADWCHAR, ADVARWCHAR, ADLONGVARWCHAR )
          *
          lcBuild = m.lcBuild + [, ] + loField.Name + [ M]
        CASE INLIST( m.lnType, ADNUMERIC, ADVARNUMERIC )
          lcBuild = m.lcBuild + [, ] + loField.Name + ;
            [ N(] + TRANS( loField.ActualSize) + [,] + ;
            TRANS( loField.Precision) + [)]
        CASE INLIST( m.lnType, ADSINGLE )
          lcBuild = m.lcBuild + [, ] + loField.Name + ;
            [ F(] + TRANS( loField.ActualSize) + [,] + ;
            TRANS( loField.Precision) + [)]
        CASE INLIST( m.lnType, ADDOUBLE )
          lcBuild = m.lcBuild + [, ] + loField.Name + ;
            [ B(] + TRANS( loField.ActualSize) + [,] + ;
            TRANS( loField.Precision) + [)]
        CASE INLIST( m.lnType, ADINTEGER, ADSMALLINT, ADTINYINT, ;
          ADUNSIGNEDINT, ADUNSIGNEDTINYINT, ADUNSIGNEDSMALLINT, ;
          ADUNSIGNEDBIGINT )
          *
          lcBuild = m.lcBuild + [, ] + loField.Name + [ I]
        CASE INLIST( m.lnType, ADBOOLEAN )
          lcBuild = m.lcBuild + [, ] + loField.Name + [ L]
        CASE INLIST( m.lnType, ADCURRENCY )
          lcBuild = m.lcBuild + [, ] + loField.Name + [ Y]
        CASE INLIST( m.lnType, ADDBDATE, ADDATE )
          lcBuild = m.lcBuild + [, ] + loField.Name + [ D]
        CASE INLIST( m.lnType, ADDBTIME, ADDBTIMESTAMP )
          lcBuild = m.lcBuild + [, ] + loField.Name + [ T]
        OTHERWISE
          
          *** NOTE: Some types above are not tested and there
          ***   are several ADO types that are not yet included.
          ***   Please contact me if you have a problem/need
          ***   with a specific type!
          
          LOOP  && don't allow lcInsert to be altered
        ENDCASE
        lcInsert = m.lcInsert + ;
          ', THIS.oRS.Fields["' + loField.Name + ;
          '"].Item.Value'
      ENDFOR
      IF NOT EMPTY( m.lcBuild)
        lcCmd = 'CREATE CURSOR ' + THIS.cAlias + ' (' + ;
          SUBSTR( m.lcBuild, 2) + ')'
        &lcCmd
        lcCmd = 'INSERT INTO ' + THIS.cAlias + ' VALUES (' + ;
          SUBSTR( m.lcInsert, 2) + ')'
        &lcCmd
      ENDIF
    ENDIF
  ENDFUNC  && ConvertRecord
  * ---------------------------------------------------------- *
  FUNCTION VfpType( lnType)
    * Get VFP type from ADO type.
    LOCAL lcType
    DO CASE
    CASE INLIST( m.lnType, ADCHAR, ADBSTR ) && Character.
      lcType = "C"
    CASE INLIST( m.lnType, ADVARCHAR, ADLONGVARCHAR, ;
      ADBINARY, ADVARBINARY, ADLONGVARBINARY, ;
      ADWCHAR, ADVARWCHAR, ADLONGVARWCHAR )
      *
      lcType = "M"
    CASE INLIST( m.lnType, ADNUMERIC, ADVARNUMERIC )
      lcType = "N"
    CASE INLIST( m.lnType, ADSINGLE )
      lcType = "F"
    CASE INLIST( m.lnType, ADDOUBLE )
      lcType = "B"
    CASE INLIST( m.lnType, ADINTEGER, ADSMALLINT, ADTINYINT, ;
      ADUNSIGNEDINT, ADUNSIGNEDTINYINT, ADUNSIGNEDSMALLINT, ;
      ADUNSIGNEDBIGINT )
      *
      lcType = "I"
    CASE INLIST( m.lnType, ADBOOLEAN )
      lcType = "L"
    CASE INLIST( m.lnType, ADCURRENCY )
      lcType = "Y"
    CASE INLIST( m.lnType, ADDBDATE, ADDATE )
      lcType = "D"
    CASE INLIST( m.lnType, ADDBTIME, ADDBTIMESTAMP )
      lcType = "T"
    OTHERWISE
      lcType = "U"
    ENDCASE
    RETURN m.lcType
  ENDFUNC  && VfpType
  * ---------------------------------------------------------- *
  FUNCTION GetFieldName( lnField)
    IF THIS.lRecordAtATime
      IF BETWEEN( m.lnField, 1, THIS.nFieldCount)
        RETURN THIS.oRS.Fields( m.lnField - 1).Name
      ELSE
        RETURN ""
      ENDIF
    ELSE
      RETURN DODEFAULT( m.lnField)
    ENDIF
  ENDFUNC  && GetFieldName
  * ---------------------------------------------------------- *
  FUNCTION GetFieldType( lnField)
    IF THIS.lRecordAtATime
      IF BETWEEN( m.lnField, 1, THIS.nFieldCount)
        LOCAL lnType
        lnType = THIS.oRS.Fields( m.lnField - 1).Type
        RETURN THIS.VfpType( m.lnType)
      ELSE
        RETURN ""
      ENDIF
    ELSE
      RETURN DODEFAULT( m.lnField)
    ENDIF
  ENDFUNC  && GetFieldName
  * ---------------------------------------------------------- *
  FUNCTION GetFieldLength( lnField)
    IF BETWEEN( m.lnField, 1, THIS.nFieldCount)
      RETURN THIS.oRS.Fields( m.lnField - 1).DefinedSize
    ELSE
      RETURN 0
    ENDIF
  ENDFUNC  && GetFieldPrecision
  * ---------------------------------------------------------- *
  FUNCTION GetFieldPrecision( lnField)
    IF BETWEEN( m.lnField, 1, THIS.nFieldCount)
      RETURN THIS.oRS.Fields( m.lnField - 1).Precision
    ELSE
      RETURN 0
    ENDIF
  ENDFUNC  && GetFieldPrecision
  * ---------------------------------------------------------- *
  FUNCTION GetFieldValue( lcField)
    IF THIS.lRecordAtATime
      RETURN THIS.oRS.Fields( m.lcField).Value
    ELSE
      RETURN DODEFAULT( m.lcField)
    ENDIF
  ENDFUNC  && GetFieldValue
  * ---------------------------------------------------------- *
  FUNCTION MoveFirst
    IF THIS.lRecordAtATime
      THIS.oRS.MoveFirst()
      THIS.ConvertRecord()
    ELSE
      RETURN DODEFAULT()
    ENDIF
  ENDFUNC  && MoveFirst
  * ---------------------------------------------------------- *
  FUNCTION MoveNext
    IF THIS.lRecordAtATime
      THIS.oRS.MoveNext()
      THIS.ConvertRecord()
    ELSE
      RETURN DODEFAULT()
    ENDIF
  ENDFUNC  && MoveNext
  * ---------------------------------------------------------- *
  FUNCTION AddNew()
    RETURN THIS.oRS.AddNew()
  ENDFUNC  && AddNew
  * ---------------------------------------------------------- *
ENDDEFINE  && L7AdoIterator
*** ========================================================== ***

#if .f.
Revision History
----------------
10/19/03 - Added cFilter support.
11/04/04 - Added collection iterator.
         - Added GetRecord() to interface.
#endif
