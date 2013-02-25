* L7DBC.prg
*
* DBC tools

#include L7.h

* OPEN DATA ...
* DO L7DbcTraverseTest in L7Dbc with "Some Title"
* --------------------------------------------------------- *
FUNCTION L7DbcTraverseTEST(tcTitle, tcDbc)
  SET PROCEDURE TO ;
    L7Utils, L7API, wwUtils, wwAPI ;
    additive 
  
  LOCAL loDBC, loState, loRpt
  CLEAR 
  if !empty(m.tcDbc)
    open database (m.tcDbc)
  endif
  loDBC = CREATEOBJECT("L7DbcTraverse")
  loState = loDBC.Setup()
  ADDPROPERTY(loState, "ReportTitle", textmerge(evl(m.tcTitle, "Listing <<datetime()>>")))

  loRPT = CREATEOBJECT("L7DbcHTMLReport")
  loRPT.Setup(loDBC, loState)

  loDBC.Traverse(m.loState)
  l7ShowHtml(loRpt.cTop + loRpt.cMain + loRpt.cBottom)
  RETURN 
ENDFUNC 

*** ========================================================= ***
DEFINE CLASS L7DbcHTMLReport as Custom 
  cMain = ""
  cTop = ""
  cBottom = ""
  cTableTopTmp = ""
  cTableBottomTmp = ""
  cFieldTmp = ""
  * --------------------------------------------------------- *
  FUNCTION Setup(toDBC, toState)
    BINDEVENT(toDBC, "TraverseTable", THIS, "OnTraverseTable", 0)
    BINDEVENT(toDBC, "TraverseTable", THIS, "OnAfterTraverseTable", 1)
    BINDEVENT(toDBC, "NoteField", THIS, "OnNoteField")
    WITH toState
      TEXT TO this.cTop TEXTMERGE NOSHOW 
        <html>
        <head>
        <title><<.ReportTitle>></title>
        <style>
        body, p, th, td{font: small sans-serif;}
        table, th, td {border-collapse: collapse; border: 1px solid brown;}
        table, p {margin: 0.5em 0 1em 1.5em;}
        h3{page-break-before: always;}
        th, td {padding: 0.25em;} 
        h1, h2 {color: darkgreen;}
        h3, caption, th {color: brown;}
        caption {}
        </style>
        
        </head>
        <body>
          <h1><<.ReportTitle>></h1>
          <h2>Database Dictionary as of <<date()>></h2>
          
      ENDTEXT 
      TEXT TO this.cFieldTmp noshow
        <tr>
          <td><<toState.ActiveFieldName>></td>
          <td><<toState.ActiveFieldType>></td>
          <td><<toState.ActiveFieldSize>></td>
          <td><<EVL(toState.ActiveFieldDec,'&nbsp;')>></td>
          <td><<iif(toState.ActiveFieldNull, 'NULL', '&nbsp;')>></td>
          <td><<toState.ActiveFieldCaption>></td>
          <td><<toState.ActiveFieldComment>></td>
        </tr>
      ENDTEXT 
      TEXT TO this.cTableTopTmp NOSHOW 
          <h3>Table: <<.ActiveTableName>></h3>
          <<.ActiveTableComment>></p>
          <table width="90%">
            <caption><<.ActiveTableName>> Table</caption>
          <thead>
           <tr>
            <th width="20%">Field Name</th>
            <th width="5%">Type</th>
            <th width="5%">Size</th>
            <th width="5%">Dec</th>
            <th width="5%">Null</th>
            <th width="20%">Friendly Name</th>
            <th width="40%">Comments</th>
           </tr>
          </thead>

      ENDTEXT 
      TEXT TO this.cTableBottomTmp NOSHOW 
          </table>

      ENDTEXT 
      TEXT TO this.cBottom TEXTMERGE NOSHOW 
          <p>Generated via L7DbcHtmlReport: <b><<DATETIME()>></b></p>
          </body>
        </html>

      ENDTEXT 
    ENDWITH 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION OnTraverseTable(toState)
    LOCAL lcTable, lnFields, laFields[1], lcField, lnFld
    WITH toState
      lcTable = toState.Tables(toState.ActiveTable)
      IF toState.Stage = "Main"
        lcTxt = TEXTMERGE(THIS.cTableTopTmp)
        this.cMain = this.cMain + m.lcTxt
      ENDIF
    ENDWITH 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION OnAfterTraverseTable(toState)
    WITH toState
      IF toState.Stage = "Main"
        lcTxt = TEXTMERGE(THIS.cTableBottomTmp)
        this.cMain = this.cMain + m.lcTxt
      ENDIF 
    ENDWITH 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION OnNoteField(toState)
    LOCAL lcTxt
    WITH toState
      IF toState.Stage = "Main"
        lcTxt = TEXTMERGE(THIS.cFieldTmp)
        this.cMain = this.cMain + m.lcTxt
      ENDIF
    ENDWITH 
    RETURN 
  ENDFUNC 
 
ENDDEFINE && L7DbcHTMLReport 

*** ========================================================= ***
DEFINE CLASS L7DbcTraverse as Custom
  cPath = NULL
  cDBC = NULL
  * --------------------------------------------------------- *
  FUNCTION Setup()
    LOCAL loState
    loState = THIS.GetStateObject()
    RETURN loState
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION Traverse(toState)
    RAISEEVENT(THIS, "OpenDBC", m.toState)
    RAISEEVENT(THIS, "GetTables", m.toState)
    toState.Stage = "Setup"
    RAISEEVENT(THIS, "TraverseTables", m.toState)
    toState.Stage = "Main"
    RAISEEVENT(THIS, "TraverseTables", m.toState)
    toState.Stage = "Cleanup"
    RAISEEVENT(THIS, "TraverseTables", m.toState)
    RAISEEVENT(THIS, "TraversalComplete", m.toState)
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION GetTables(toState)
    LOCAL ii
    toState.TableCount = ADBOBJECTS( toState.Tables, "TABLE")
    ASORT( toState.Tables )
    FOR ii = 1 TO toState.TableCount
      toState.ActiveTable = m.ii
      THIS.TraverseTable(toState)
    NEXT ii 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION TraversalComplete(toState)
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION TraverseTables(toState)
    LOCAL ii, lcTable
    WITH toState
      FOR .ActiveTable = 1 TO .TableCount
        lcTable = .Tables(.ActiveTable)
        .ActiveTableName = m.lcTable
        USE (m.lcTable) AGAIN ALIAS __Table IN SELECT("__Table")
        .ActiveTableComment = DBGETPROP( m.lcTable, "Table", "Comment") 
        .ActiveTableReccount = RECCOUNT("__Table")
        RAISEEVENT(THIS, "TraverseTable", m.toState)
      NEXT ii 
    ENDWITH 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION TraverseTable(toState)
    LOCAL lcTable, lnFields, laFields[1], lcField, lnFld
    WITH toState
      lcTable = .Tables(.ActiveTable)
      IF .Stage = "Main"
        ** ? m.lcTable
        lnFields = AFIELDS( laFields, "__Table" )
        FOR lnFld = 1 TO m.lnFields
          .ActiveFieldName = laFields[m.lnFld, 1]
          .ActiveFieldType = laFields[m.lnFld, 2]
          .ActiveFieldSize = laFields[m.lnFld, 3]
          .ActiveFieldDec = laFields[m.lnFld, 4]
          .ActiveFieldNull = laFields[m.lnFld, 5]
          .ActiveFieldCaption = DBGETPROP( m.lcTable + "." + .ActiveFieldName, "Field", "Caption") 
          .ActiveFieldComment = DBGETPROP( m.lcTable + "." + .ActiveFieldName, "Field", "Comment") 
          RAISEEVENT(THIS, "NoteField", m.toState)
        ENDFOR 
      ENDIF
    ENDWITH 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION NoteField(toState)
    ** ? toState.ActiveFieldName 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION OpenDBC(toState)
    IF ISNULL(THIS.cDbc)
      IF EMPTY(SET('DATABASE'))
        ERROR 'No database open or specified.'
      ENDIF 
    ELSE
      OPEN DATABASE (THIS.cDBC)
    ENDIF 
    toState.Database = SET('DATABASE')
    RETURN
  ENDFUNC    
  * --------------------------------------------------------- *
  FUNCTION GetStateObject
    LOCAL loState
    loState = CREATEOBJECT("Empty")
    ADDPROPERTY(m.loState, "Database", NULL)
    ADDPROPERTY(m.loState, "TableCount", 0)
    ADDPROPERTY(m.loState, "Tables[1]", .F.)
    ADDPROPERTY(m.loState, "ActiveTable", 0)
    ADDPROPERTY(m.loState, "ActiveTableName", "")
    ADDPROPERTY(m.loState, "ActiveTableComment", "")
    ADDPROPERTY(m.loState, "ActiveTableReccount", 0)
    ADDPROPERTY(m.loState, "Stage", "none")
    ADDPROPERTY(m.loState, "ActiveFieldName", "")
    ADDPROPERTY(m.loState, "ActiveFieldType", "")
    ADDPROPERTY(m.loState, "ActiveFieldSize", 0)
    ADDPROPERTY(m.loState, "ActiveFieldDec", 0)
    ADDPROPERTY(m.loState, "ActiveFieldNull", "")
    ADDPROPERTY(m.loState, "ActiveFieldCaption", "")
    ADDPROPERTY(m.loState, "ActiveFieldComment", "")
    RETURN m.loState
  ENDFUNC 
ENDDEFINE && L7DbcTraverse 

*** ========================================================= ***
* end: L7DBC