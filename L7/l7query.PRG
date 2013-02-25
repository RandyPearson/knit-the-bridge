#INCLUDE L7.H
#DEFINE THIS_DEBUG_OBJECTS .F.

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
DEFINE CLASS L7Query AS RELATION
  * Properties:
  lOldEngineBehavior = .F. && set .T. to force VFP 7 SQL behavior
  
  EOF = .F.  && dummy prop - see access method

  cDataPath = ""
  cDatabase = ""

  DIMENSION aFieldList[ 1, 2]
  nFields = 0
  cFieldList = ""
  lFieldListBuilt = .F.
  cDefaultFieldList = ""

  cSelectClause = ""
  lSelectBuilt = .F.
  lDistinct = .F.
  nTopN = 0
  lTopPercent = .F.
  
  DIMENSION aWhereConditions[ 1, 2] && optional for non-subclassed generic use, see applyWhereConditions()
  nWhereConditions = 0
  cWhereClause = ""
  cInnerWhere = ""  && force AND'ing of sensitive condition, typically security
  lWhereBuilt = .F.

  cHavingClause = ""
  lHavingBuilt = .F.

  DIMENSION aJoins[ 1, 3]
  nJoins = 0
  cJoinClause = ""
  lJoinBuilt = .F.

  DIMENSION aOrderBy[ 1, 2]
  nOrderBy = 0
  cOrderByClause = ""
  lOrderByBuilt = .F.
  cOrderBy = "" && metphor for setting order with string - see assign method

  nGrouping = 0
  cGroupByClause = ""
  lGroupByBuilt = .F.

  *!*	cIntoClause = ""
  *!*	lIntoBuilt = .F.
  lAutoIntoClause = .T. && turn off only if SQL will be used *within* another query 

  cSqlStatement = ""
  lSqlBuilt = .F.
  lReadWrite = .F. && toggle READWRITE option of INTO clause
  cAlias = ""
  cBaseTable = ""
  cBaseTableAlias = ""
  nTally = -1  && not executed

  cTitle = "Query"  && place to describe filtering, if desired

  nMinTally = NULL  && less than this triggers an error
  nMaxTally = NULL  && more than this triggers an error
  
  lArrayResults = .F.
  DIMENSION aResults[1]
  
  lError = .F.
  nError = 0
  cErrorMessage = ""
  cErrorInfo = ""

  * --------------------------------------------------------- *
  FUNCTION cOrderBy_ASSIGN( lcString)
    * Allows you to set ORDER BY without knowing array stuff.
    lcString = CHRTRAN( lcString, ',', CHR(13) )
    IF EMPTY( m.lcString)
    	THIS.nOrderBy = 0
    ELSE
    	LOCAL ARRAY laLines[1]
    	LOCAL ii, lcStr, lnAt
    	THIS.nOrderBy = ALINES( laLines, m.lcString)
    	DIMENSION THIS.aOrderBy[ THIS.nOrderBy, 2]
    	FOR ii = 1 TO THIS.nOrderBy
    		lcStr = ALLTRIM( laLines[ m.ii] )
    		lnAt = AT( " ", m.lcStr)  && parse for DESC or ASC 
    		IF m.lnAt = 0
    			THIS.aOrderBy[ m.ii, 1] = m.lcStr
          THIS.aOrderBy[ m.ii, 2] = .F.  && defaults to .F.
    		ELSE
    			THIS.aOrderBy[ m.ii, 1] = LEFT( m.lcStr, m.lnAt - 1)
          * Check for DESC attribute:
  				THIS.aOrderBy[ m.ii, 2] = (UPPER( SUBSTR( m.lcStr, m.lnAt + 1)) == "DESC")
    		ENDIF
    	ENDFOR
    ENDIF
  ENDFUNC && cOrderBy_ASSIGN
  * --------------------------------------------------------- *
  FUNCTION INIT
    ** 10/13/2004: looks wrong (intended for private datasession?):
    ** DO StandardVfpSettings  && SET EXACT, DELETED, etc.

    IF VARTYPE( goL7App) = "O"
    	THIS.cDataPath = goL7App.cDataPath
    	THIS.cDataBase = goL7App.cDataBase
    ENDIF

    THIS.cAlias = THIS.Name + "_"
    *!*	IF USED( THIS.cAlias )
    *!*		USE IN ( THIS.cAlias )
    *!*	ENDIF
    
    THIS.AddDefaultFields()
#IF THIS_DEBUG_OBJECTS
    DEBUGOUT THIS.Name + " created."
#ENDIF
  ENDFUNC  && INIT
  * ------------------------------------------------------------------- *
  FUNCTION DESTROY
#IF THIS_DEBUG_OBJECTS
    DEBUGOUT THIS.Name + " destroyed."
#ENDIF
  ENDFUNC  && DESTROY
  * --------------------------------------------------------- *
#IF L7_QUERY_ERROR_HANDLING = .T.
  FUNCTION ERROR(lnError, lcMethod, lnLine)
    THIS.lError = .T.
    THIS.nTally = -2
    THIS.cErrorMessage = MESSAGE( )
     
    LOCAL ARRAY laError[1]
    = AERROR( laError)
    THIS.cErrorInfo = ErrorToXML( THIS.Class, lnError, lcMethod, lnLine, @laError)
  ENDFUNC  && Error
#ENDIF
  * -------------------------------------------------- *
  FUNCTION SetError( tcMessage )
    * Simulate error condition by setting flag and
    * message programatically.
    THIS.lError = .T.
    THIS.nError = 1098
    THIS.cErrorMessage = IIF( EMPTY( m.tcMessage), ;
    	"User-initiated error.", m.tcMessage )
    THIS.cErrorInfo = [<AppErrorInfo><ErrorMessage>] + THIS.cErrorMessage + ;
    	[</ErrorMessage></AppErrorInfo>]
#IF NOT L7_QUERY_ERROR_HANDLING 
      * We've excluded any internal Error method, so raise
      * an error to the application:
      ERROR THIS.cErrorMessage
#ENDIF
  ENDFUNC  && SetError
  * --------------------------------------------------------- *
  FUNCTION ResetProperties
    THIS.lFieldListBuilt = .F.
    THIS.lOrderByBuilt = .F.
    THIS.lGroupByBuilt = .F.
    THIS.lJoinBuilt = .F.
    THIS.lSqlBuilt = .F.
    THIS.lSelectBuilt = .F.
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddDefaultFields()
    IF NOT EMPTY( THIS.cDefaultFieldList )
      THIS.AddFields( THIS.cDefaultFieldList )
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ClearFields()
    * Handles setting after Init().
    THIS.nFields = 0
    THIS.lFieldListBuilt = .F.
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddFields(lcFields)
    
    * NOTE: This is ignored, once BuildFieldList() is called, unless
    * ClearFields() intervenes. This allows forging the field list and
    * preventing "helpful" components from trying to add unwanted columns,
    * which could poison GROUP BY clauses, etc.
    
    LOCAL lnOccurs, lcTxt, ii, lcFld, lnAt1, lnAt2
    lcTxt = "," + m.lcFields + ","
    lnOccurs = OCCURS( ",", m.lcTxt ) - 1
    FOR ii = 1 TO m.lnOccurs
    	lnAt1 = AT( ",", m.lcTxt, m.ii )
    	lnAt2 = AT( ",", m.lcTxt, m.ii + 1)
    	lcFld = ALLTRIM( SUBSTR( m.lcTxt, m.lnAt1 + 1, m.lnAt2 - m.lnAt1 - 1 ))
    	IF NOT EMPTY( m.lcFld )
    		THIS.AddField( m.lcFld )
    	ENDIF
    ENDFOR
    RETURN 
  ENDFUNC  && AddFields
  * --------------------------------------------------------- *
  FUNCTION AddField(lcField, lcAs)
    * See note in AddFields() method.
    LOCAL ii, llFound
    * See if there:
    FOR ii = 1 TO THIS.nFields
    	IF UPPER( THIS.aFieldList[ m.ii, 1]) == UPPER( m.lcField)
    		llFound = .T.
    		EXIT
    	ENDIF
    ENDFOR
    IF NOT m.llFound
    	THIS.nFields = THIS.nFields + 1
    	DIMENSION THIS.aFieldList[ THIS.nFields, 2]
    	THIS.aFieldList[ THIS.nFields, 1] = m.lcField
    	THIS.aFieldList[ THIS.nFields, 2] = m.lcAs
    ENDIF
    RETURN 
  ENDFUNC  && AddField
  * --------------------------------------------------------- *
  FUNCTION BuildFieldList
    IF THIS.lFieldListBuilt = .F.
    	LOCAL lcTxt, ii
    	lcTxt = ""
    	FOR ii = 1 TO THIS.nFields
    		lcTxt = m.lcTxt + IIF( EMPTY( m.lcTxt), '', ', ') + ;
    			THIS.aFieldList[ m.ii, 1] + ;
    			IIF( empty(THIS.aFieldList[ m.ii, 2]), "", " AS " + THIS.aFieldList[ m.ii, 2])
    	ENDFOR
    	IF EMPTY( m.lcTxt)
    		lcTxt = "*"
    	ENDIF
    	THIS.cFieldList = m.lcTxt
    	THIS.lFieldListBuilt = .T.
    ENDIF
    RETURN 
  ENDFUNC  && BuildFieldList
  * ------------------------------------------------ *
  FUNCTION BuildSelectClause
    WITH THIS
      IF .lSelectBuilt = .F.
        .cSelectClause = ""
        IF .nTopN > 0
          .cSelectClause = .cSelectClause + [TOP ] + TRANSFORM(.nTopN) + [ ]
          IF .lTopPercent 
            .cSelectClause = .cSelectClause + [PERCENT ] 
          ENDIF
        ENDIF
        IF .lDistinct 
          .cSelectClause = .cSelectClause + [DISTINCT ]
        ENDIF
        .lSelectBuilt = .T.
      ENDIF
    ENDWITH
    RETURN 
  ENDFUNC  && BuildSelectClause
  * ------------------------------------------------ *
  FUNCTION AddJoinCondition( tcTable, tcExpr, tcType)
    ** TO DO: Add redundancy checking code.
    THIS.nJoins = THIS.nJoins + 1
    DIMENSION THIS.aJoins[ THIS.nJoins, 3]
    THIS.aJoins[ THIS.nJoins, 1] = m.tcTable
    THIS.aJoins[ THIS.nJoins, 2] = m.tcExpr
    THIS.aJoins[ THIS.nJoins, 3] = m.tcType  && "LEFT" etc. (optional)
    RETURN 
  ENDFUNC  && AddJoinCondition
  * ------------------------------------------------ *
  FUNCTION BuildJoinClause
    IF THIS.lJoinBuilt = .F.
    	LOCAL lcJoin, ii
    	lcJoin = ""
    	FOR ii = 1 TO THIS.nJoins
    		lcJoin = m.lcJoin + ;
    			IIF( EMPTY( THIS.aJoins[ m.ii, 3]), ;
    				[], [ ] + THIS.aJoins[ m.ii, 3]) + ;
    			[ JOIN ] + THIS.aJoins[ m.ii, 1] + ;
    			[ ON ]   + THIS.aJoins[ m.ii, 2]
    	ENDFOR
    	THIS.cJoinClause = m.lcJoin
    	THIS.lJoinBuilt = .T.
    ENDIF
    RETURN 
  ENDFUNC  && BuildJoinClause
  * --------------------------------------------------------- *
  FUNCTION AddOrderBy(lcOrderBy, llDescending, llAppend)
    IF VARTYPE( lcOrderBy) <> "C" OR EMPTY( m.lcOrderBy)
    	* Clear any existing expressions.
    	THIS.nOrderBy = 0
    ELSE
    	THIS.nOrderBy = IIF( m.llAppend, 1 + THIS.nOrderBy, 1)
    	DIMENSION THIS.aOrderBy[ THIS.nOrderBy, 2]
    	THIS.aOrderBy[ THIS.nOrderBy, 1] = m.lcOrderBy
    	THIS.aOrderBy[ THIS.nOrderBy, 2] = m.llDescending
    ENDIF
    RETURN 
  ENDFUNC  && AddOrderBy
  * --------------------------------------------------------- *
  FUNCTION BuildOrderByClause
    IF THIS.lOrderByBuilt = .F.
    	LOCAL lcTxt, ii
    	lcTxt = ""
    	FOR ii = 1 TO THIS.nOrderBy
    		lcTxt = m.lcTxt + IIF( EMPTY( m.lcTxt), 'ORDER BY ', ', ') + ;
    			THIS.aOrderBy[ m.ii, 1] + ;
    			IIF( THIS.aOrderBy[ m.ii, 2], " DESC", "")
    	ENDFOR
    	THIS.cOrderByClause = m.lcTxt
    	THIS.lOrderByBuilt = .T.
    ENDIF
    RETURN 
  ENDFUNC  && BuildOrderByClause
  * --------------------------------------------------------- *
  FUNCTION SetOrderByClause(lcTxt)
    * Pre-specify the entire clause.
    IF NOT EMPTY(m.lcTxt) AND NOT UPPER(m.lcTxt) = "ORDER BY"
      lcTxt = "ORDER BY " + m.lcTxt
    ENDIF
    THIS.cOrderByClause = m.lcTxt
    THIS.lOrderByBuilt = .T.
    RETURN 
  ENDFUNC  && SetOrderByClause
  * --------------------------------------------------------- *
  FUNCTION BuildGroupByClause
    * Note: Grouping is only possible if ORDERING has been set.
    * You can group up to the level of ordering. Specify the nGrouping
    * property to group.
    IF THIS.lGroupByBuilt = .F.
    	LOCAL lcTxt, ii
    	lcTxt = ""
    	FOR ii = 1 TO THIS.nGrouping
    		lcTxt = m.lcTxt + IIF( EMPTY( m.lcTxt), 'GROUP BY ', ', ') + ;
    			THIS.aOrderBy[ m.ii, 1]
    	ENDFOR
    	THIS.cGroupByClause = m.lcTxt
    	THIS.lGroupByBuilt = .T.
    ENDIF
    RETURN 
  ENDFUNC  && BuildGroupByClause
  * --------------------------------------------------------- *
  FUNCTION BuildHavingClause
    IF NOT THIS.lHavingBuilt
      THIS.lHavingBuilt = .T.
    ENDIF
    RETURN 
  ENDFUNC  && BuildhavingClause
  * --------------------------------------------------------- *
  FUNCTION cSqlStatement_ACCESS
    IF THIS.lSqlBuilt = .F.
    	THIS.BuildSqlStatement()
    ENDIF
    RETURN THIS.cSqlStatement
  ENDFUNC  && cSqlStatement_ACCESS
  * --------------------------------------------------------- *
  FUNCTION SetSqlStatement(lcStmt)
    * Allows direct query creation for ad-hoc queries by bypassing
    * all class clause building mechanisms. Optionally adds an INTO clause
    * (recommended, as then THIS.cAlias will be correct for referencing).
    IF THIS.lAutoIntoClause AND NOT [INTO CURSOR ] $ UPPER( m.lcStmt)
    	lcStmt = m.lcStmt + THIS.GetIntoClause()
    ENDIF
    THIS.cSqlStatement = m.lcStmt
    THIS.lSqlBuilt = .T.
    RETURN 
  ENDFUNC  && SetSqlStatement
  * ------------------------------------------------ *
  function AddWhereCondition(tcExpr) && 2nd param could be and/or, or nesting
    this.nWhereConditions = this.nWhereConditions + 1
    dimension this.aWhereConditions[THIS.nWhereConditions , 2]
    this.aWhereConditions[this.nWhereConditions, 1] = m.tcExpr
    return  
  endfunc  && AddWhereCondition
  * --------------------------------------------------------- *
  function DoBuildWhereClause
    if !this.lWhereBuilt
      this.BuildWhereClause()
      if upper(left(this.cWhereClause, 6)) == "WHERE "
        this.cWhereClause = substr(this.cWhereClause, 7)
      endif
      this.applyInnerWhere()
      if !empty(this.cWhereClause)
        this.cWhereClause = "WHERE " + this.cWhereClause
      endif
      this.lWhereBuilt = .T.
    endif 
    return  
  endfunc  && BuildWhereClause
  * --------------------------------------------------------- *
  function BuildWhereClause  && often subclassed, but may just use what follows
    this.applyWhereConditions() && subclasses must call this if desired
    return 
  endfunc  && BuildWhereClause
  * --------------------------------------------------------- *
  function applyWhereConditions() && subclasses must call this if desired
    if this.nWhereConditions = 0
      return
    endif
    local lcTxt, ii
    lcTxt = ""
    for ii = 1 to this.nWhereConditions
      lcTxt = m.lcTxt + iif(empty(m.lcTxt), '', ' and ') + this.aWhereConditions[ m.ii, 1]
    next 
    * combine with any pre-built piece
    this.cWhereClause = this.cWhereClause + iif(!empty(this.cWhereClause), ' and ', '') + m.lcTxt
    return 
  endfunc  && applyWhereConditions
  * --------------------------------------------------------- *
  function ApplyInnerWhere && see note in constructor re. cInnerWhere property
    if empty(this.cInnerWhere)
      return
    endif
    if empty(this.cWhereClause)
      this.cWhereClause = this.cInnerWhere
    else
      this.cWhereClause = '(' + this.cWhereClause + ') and (' + this.cInnerWhere + ')'
    endif
    return 
  endfunc   
  * --------------------------------------------------------- *
  FUNCTION BuildSqlStatement()
    IF THIS.lSqlBuilt = .F.
    	THIS.DoBuildWhereClause()  && must come first
      THIS.BuildSelectClause()
    	THIS.BuildFieldList()
    	THIS.BuildJoinClause()
    	THIS.BuildOrderByClause()
    	THIS.BuildGroupByClause()
      THIS.BuildHavingClause()
    	LOCAL lcTxt
    	lcTxt = [SELECT ] + THIS.cSelectClause  && DISTINCT, TOP n
      lcTxt = m.lcTxt + THIS.cFieldList
    	lcTxt = m.lcTxt + [ FROM ] + THIS.cBaseTable
    	IF NOT EMPTY( THIS.cBaseTableAlias)
    		lcTxt = m.lcTxt + [ ] + THIS.cBaseTableAlias
    	ENDIF
    	IF NOT EMPTY( THIS.cJoinClause )
    		lcTxt = m.lcTxt + [ ] + THIS.cJoinClause
    	ENDIF
    	IF NOT EMPTY( THIS.cWhereClause )
    		lcTxt = m.lcTxt + [ ] + THIS.cWhereClause
    	ENDIF
    	IF NOT EMPTY( THIS.cOrderByClause )
    		lcTxt = m.lcTxt + [ ] + THIS.cOrderByClause
    	ENDIF
    	IF NOT EMPTY( THIS.cGroupByClause )
    		lcTxt = m.lcTxt + [ ] + THIS.cGroupByClause
    	ENDIF
      IF NOT EMPTY( THIS.cHavingClause )
        lcTxt = m.lcTxt + [ ] + THIS.cHavingClause
      ENDIF
      IF THIS.lAutoIntoClause
      	lcTxt = m.lcTxt + THIS.GetIntoClause()
      ENDIF
    	THIS.cSqlStatement = m.lcTxt
    	THIS.lSqlBuilt = .T.
    ENDIF
    RETURN 
  ENDFUNC  && BuildSqlStatement
  * --------------------------------------------------------- *
  FUNCTION GetIntoClause
    * Usage may be different for remote data w/ SQL passthrough.
    LOCAL lcRet
    IF THIS.lArrayResults
      lcRet = [ INTO ARRAY THIS.aResults]
    ELSE
      lcRet = [ INTO CURSOR ] + THIS.cAlias + ;
        IIF( THIS.lReadWrite, [ READWRITE], [ NOFILTER])
    ENDIF
    RETURN m.lcRet
  ENDFUNC  && GetIntoClause
  * --------------------------------------------------------- *
  FUNCTION Execute
    LOCAL lcSql, lnEngineBehavior, loExc
    IF NOT THIS.lError
      TRY 
        lnEngineBehavior = SET("EngineBehavior")
        SET ENGINEBEHAVIOR IIF(THIS.lOldEngineBehavior, 70, 80)
        lcSql = THIS.cSqlStatement
      	&lcSql
      CATCH TO loExc
        IF _VFP.StartMode = 0
          _CLIPTEXT = TRANSFORM(m.lcSql)
          WAIT WINDOW NOWAIT "SQL Statement Pasted to Clipboard!"
        ENDIF
        THIS.lError = .T.
        THIS.nError = loExc.ErrorNo
        THIS.nTally = -2
        THIS.cErrorMessage = "Query Error " + TRANSFORM(loExc.ErrorNo) + ": " + ;
          loExc.Message + ' [ ' + TRANSFORM(m.lcSql) + ' ]'
      FINALLY
        SET ENGINEBEHAVIOR m.lnEngineBehavior
      ENDTRY
    ENDIF
    IF THIS.lError
      ERROR THIS.cErrorMessage
    ELSE
    	THIS.nTally = _TALLY
      IF NOT ISNULL( THIS.nMinTally) AND THIS.nTally < THIS.nMinTally
        THIS.SetError( "Error: Only " + TRANSFORM( THIS.nTally) + ;
          " records returned by " + THIS.Class + ;
          " (minimum " + TRANSFORM( THIS.nMinTally) + " required).")
      ENDIF
      IF NOT ISNULL( THIS.nMaxTally) AND THIS.nTally > THIS.nMaxTally
        THIS.SetError( "Error: " + TRANSFORM( THIS.nTally) + ;
          " records returned by " + THIS.Class + ;
          " (maximum " + TRANSFORM( THIS.nMaxTally) + " allowed).")
      ENDIF
    ENDIF
    RETURN THIS.nTally
  ENDFUNC  && Execute
  * --------------------------------------------------------- *
  FUNCTION EOF_ACCESS
    * 06/12/2002: Added [ OR NOT USED(THIS.cAlias) ] to avoid
    *   an error if L7ShowObject() tried to expand this in
    *   an Error() routine, and the alias had never been built.
    RETURN THIS.lError OR NOT USED(THIS.cAlias) OR EOF(THIS.cAlias)
  ENDFUNC  && EOF_ACCESS
  * --------------------------------------------------------- *
  FUNCTION MoveFirst
    IF THIS.nTally >= 0
    	GO TOP IN ( THIS.cAlias )
    ENDIF
    RETURN 
  ENDFUNC  && MoveFirst
  * --------------------------------------------------------- *
  FUNCTION MoveNext
    IF THIS.nTally >= 0
    	SKIP IN ( THIS.cAlias )
    ENDIF
    RETURN 
  ENDFUNC  && MoveNext
  * --------------------------------------------------------- *
  FUNCTION GetData(lcProp)
    IF THIS.nTally >= 0
    	LOCAL lnSelect, lvReturn
    	lnSelect = SELECT()
    	SELECT ( THIS.cAlias )
    	lvReturn = EVAL( m.lcProp )
    	SELECT ( m.lnSelect )
    	RETURN m.lvReturn
    ELSE
    	RETURN NULL
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetRecord
    * Create a data object for the current record and return 
    * an object reference.
    IF THIS.nTally >= 0
    	LOCAL loRec, lnSelect
    	lnSelect = SELECT()
    	SELECT ( THIS.cAlias ) 
    	SCATTER MEMO NAME loRec
    	SELECT ( m.lnSelect )
    	RETURN m.loRec
    ELSE
    	RETURN NULL
    ENDIF
  ENDFUNC  && GetRecord
  * --------------------------------------------------------- *
  FUNCTION ScanToString(lcExpr)
    * Allows you to cross COM barriers and get a string back
    * with the result of a SCAN. Pass an expression to be 
    * evaluated for each record. If you  need delimiters,
    * make them part of your expression!
    IF THIS.nTally >= 0
    	LOCAL lcText, lnSelect
    	lcText = ""
    	lnSelect = SELECT()
    	SELECT ( THIS.cAlias ) 
    	SCAN
    		lcText = m.lcText + EVAL( m.lcExpr )
    	ENDSCAN
    	SELECT ( m.lnSelect )
    	RETURN m.lcText
    ELSE
    	RETURN ""
    ENDIF
  ENDFUNC  && ScanToString
  * --------------------------------------------------------- *
  FUNCTION Render()
    LOCAL lcRet, loTable
    IF THIS.lArrayResults
      lcRet = THIS.aResults[1]
    ELSE
      SELECT ( THIS.cAlias ) 
      loTable = CREATEOBJECT('L7Table')
      loTable.SetupFromCursor()
      lcRet = loTable.Render()
    ENDIF 
    RETURN m.lcRet
  ENDFUNC  && Render
  * --------------------------------------------------------- *
ENDDEFINE  && L7Query

*** ===================================================== ***
#if .f.

05/06/2005 - added DISTINCT and TOP N support.

#endif

* EOF: L7Query.PRG
