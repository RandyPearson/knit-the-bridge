* L7Table.PRG
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


#INCLUDE L7.H

* * * Frequently-used client code lines:
#if .f.
loTbl = createobject("L7Table")
with loTbl
  loGrp = .addGroup(lcExpr, lcHeading, llHeadRow, lcDisplayExpr)

  loCol = .addCursorColumn(<cField>, <cHeading>)
  loCol = .addCursorColumn(<cField>, <cHeading>, <cDispExpression>)
  loCol = .addCursorColumn(<cField>, <cHeading>, <cDispExpression>, <cClass>, <cStyle>)
  
  lcStr = .Render()
endwith
#endif
 
* * *



** Major Design Notes:
**
*!*  1) There are two different table classes available. One, L7Table, allows only
*!*  one element (field) per column. The other, L7ComplexTable, allows many (often
*!*  stacked) elements per column, each element having its own formatting and statistics.
*!*  The complex version is much slower to process, because there are both 
*!*  column objects and element objects created, whereas in the simple table,
*!*  a single object encapsulates both concepts.

*!*  2) See L7TableDEMO.prg for example code.

* Classes and Class Hierarchy
*   L7AbstractTable
*   -- L7ComplexTable (columns can have multiple elements; slower, more-complex object model)
*   -- L7Table (faster, but columns can have only one data element)
*   L7TableColumn (used in complex tables only, contain multiple elements)
*   L7TableElement
*   -- L7SimpleTableElement (element-column combined class for simple tables only)
*   L7TableGroup (for grouping and statistical rows)
*   L7TableExtraRow (for inserting extra content in specific places)
*
* Also uses [in L7TableRender.PRG]:
*   L7TableRender (abstract renderer)
*   -- L7TableHtmlRender (concrete renderer for HTML tables)
*
* Also uses [in L7Iterator.PRG]:
*   L7DataIterator (abstract class) 
*   -- L7CursorIterator (concrete implementation for VFP cursors)
*   -- L7ADOIterator (concrete implementation for ADO record sets)

* Revision 0 archived 03/10/2000.
* Revision 1
*
* - Revised structure to allow for Simple version that does not have the 
*   column-=element hierarchy.

* TO DO:
*  - Accessibility needs with table headers, and other tags.

* 09/17/2002
*  - Revised table element instantiation to allow optional passing
*    of a specific class name for any single element, thus overriding
*    the table-level default. (Bridge Pattern) This allows creation
*    of subclasses that can be used in some, but not all, columns.
*    Example Usage: BpsWeb/BpsWebGraph/ERStatus().
*  - Added serveral HTML 4.0 aspects including:
*      cols= attribute in <table> tag;
*      colgroup and col tags.
*    See L7TableRender::OpenTable().
*  - Revised Extra Row class to include lFullRowText property. Setting
*    this to .T. means to interpret cText as the entire row, including
*    <tr> tag, thus avoiding any auto-colspan, etc.

* 12/26/2001
*  - Changed indentation and class/function format.
*  - Revised all HTML tags/attributes to lower case.
*  - Revised extra rows to pass group numbers and allow filters.

* 12/13/2001
*  - Added support for <Caption> (.cTableCaption) and summary=.


**** Wrapper Code to allow single function call interface. Not typically used!
LPARAMETER lvParm, lcTitle
* If an object, set as output receptor.
* Otherwise, return result.
LOCAL loTable
loTable = CREATEOBJECT( "L7Table", lvParm )
loTable.cDataBehaviorClass = "L7CursorIterator"  && VFP Cursor 
*!*  loTable.cDataBehaviorClass = "L7TableVFPBehavior"  && VFP Cursor 
loTable.cTableCaption = IIF( VARTYPE( m.lcTitle) = "C", m.lcTitle, ALIAS() )
loTable.lSumNumerics = .T.
loTable.cNullDisplay = "&nbsp;"
loTable.ProcessCursor()

** = ShowHtml( loTable.GetOutput() )
IF VARTYPE( lvParm) = "O"
	RETURN
ELSE
	RETURN loTable.GetOutput()
ENDIF
**** END: Wrapper Code


*** ====================================================== ***
DEFINE CLASS L7AbstractHtmlTable AS CUSTOM
  * This abstract class has two subclasses defined further down.
  * 1. "L7Table" - simple class with one field/expression per column.
  * 2. "L7ComplexTable" - complex class that allows multiple "Element"
  *    objects per "Column" object. Allows for stacking fields vertically, etc.
  * The property "lSimple" distinguishes these classes.

  ** Optional output receptor object. Can be passed into INIT. If provided,
  ** must support Write and WriteLn methods, such as a wwResponse object. If not
  ** passed, output is handled internally, and you must fetch it after calling
  ** ProcessCursor() via the Render() method.
  oOutput = NULL
  
  cProtocol      = "html"   && or "xml"
  cRootElement   = "table"
  cRecordElement = "tr"
  
  cRenderClass   = "L7TableHtmlRender"
  cResult        = ""    && holding tank for PreRender() results
  lRendered      = .F.   && set by PreRender() 

  ** Error Handling Properties:
  lError        = .F.  && Has an error occurred?
  cErrorMessage = ""   && Result of MESSAGE().
  cErrorInfo    = ""   && Full XML error info from AERROR().

  ** VFP Worker Classes (by specifying as properties, you can subclass these individually):
  cColumnVfpClass    = "L7TableColumn"
  cGroupVfpClass     = "L7TableGroup"
  cExtraRowVfpClass  = "L7TableExtraRow"
  cElementVfpClass   = "L7TableElement"

  * Choice of data behavior classes:
  cDataBehaviorClass = "L7CursorIterator"  && [1] VFP Cursor 
  ** cDataBehaviorClass = "L7TableADOIterator"  && [2] ADO Recordset

  ** PROTECTED oDataBehavior
  oDataBehavior  = .F.  && object reference to data behavior (Iterator) object
  cFilter        = ""   && filter condition

  ** Calculated during ProcessCursor():
  lCursorProcessed    = .F.&& Flag to enable bootstrap code.
  nCalcElementCount   = 0  && Shortcut to keep track of whether there are calculated elements.
  nActiveColumns      = 0  && Number of visible columns (used for COLSPAN attributes).
  nGroupRowCount      = 0  && running count of rows in current grouping (lowest level)
  nRowCount           = 0  && running count of number of rows in cursor
  * Implemented by data behavior:
  nAbsoluteRecno = 0
  nRecCount      = 0
  * Absolute number of groups:
  nAbsoluteGroupNo = 0  && see OpenGroup

  ** Multi-Paging properties (where possible, same as Web Connection names in ShowCursor):
  nPage_ItemsPerPage   = 0    && set this to # of items to show on a page
  cPage_PageURL        = ""   && base URL from which to construct page links
  nPage_ShowPage       = 0    && set this to the current page number (DEFAULT=1)
  cPage_PageVarName    = "pg" && leave blank to simply append ~nn to the URL
  nPage_AutoGeneration = 2    && 0 = none, 1 = Previous/Next, 2 = All Page Numbers 
  nPage_LinkLocation   = 1    && 1 = end of table (more options to be added later ?)
  cPage_PageLabel      = "Page: "

  nPage_TotalPages     = 0    && calculated
  DIMENSION aPage_URLs[ 1]    && used internally

  * These properties are calculated if multi-paging properties are set, but if not,
  * these can be specified directly:
  nStartRow      = -1
  nEndRow        = -1

  ** Arrays of object pointers:
  * 1. Columns
  DIMENSION aColumns[ 1]
  nColumns = 0
  * 2. Groups
  DIMENSION aGroups[ 1]
  nGroups = 0
  * 3. Display Elements
  DIMENSION aElements[1]
  nElements = 0
  * 4. Extra Rows
  DIMENSION aExtraRows[1]
  nExtraRows = 0

  ** <table> Tag Properties:
  cTableClass         = "DataTable"  && CSS Class
  cTableAlign         = ""
  cTableWidth         = ""
  cTableBgColor       = ""
  cTableStyle         = ""           && CSS
  nTableBorder        = 1
  cTableBorderColor   = ""
  nTableCellSpacing   = NULL         && had been 2, NULL will remove attribute 
  nTableCellPadding   = NULL         && had been 0, NULL will remove attribute 
  cTableOther         = ""           && allows extra attributes to be tacked on
  cTableAttributes    = ""           && covers anything unspecified

  cBodyClass       = ""   && CSS Class
  cBodyStyle       = ""   && CSS for <tbody>

  ** Table "Title" Row Properties (also consider using "Caption" instead):
  cTitle            = .F.         && set to a character value to cause a title row (<tr>) to appear 
  cTableID          = NULL
  cTitleClass       = "TableTitle"&& CSS Class
  cTitleStyle       = .F.         && CSS 
  cTitleAlign       = "center"    && 
  cTitleBgColor     = .F.         && 

  cTitleFontAttributes = ""       && also support I and BI, "" = none, .F. = use base element
  cTitleFontFace    = .F.         && 
  cTitleFontColor   = .F.         && 
  cTitleFontSize    = .F.         && 
  cTitleFontClass   = ""          && CSS Class
  cTitleFontStyle   = ""          && CSS 

  * Caption and Summary:
  cTableCaption          = .F.            && <caption>
  cTableCaptionClass     = "TableCaption" && <caption class="">
  cTableCaptionAttributes = ""            && covers anything unspecified
  cTableSummary          = .F.            && <table summary="">

  * Colump group info:
  lEqualWidthColumns  = .F.
  
  * Zero Records Message String:
  lZeroRecordTable        = .T.  && set .F. to avoid a table at all if no data
  cZeroRecordMessageClass = "ZeroRecordMessage"
  cZeroRecordString       = [Sorry. No items matched the search conditions.]

  ********* DEFAULT Properties for Headings and Data *********
  *
  * IMPORTANT NOTE: Specifying a property here bubbles down to all individual data elements that are
  * not otherwise specified. For almost all properties, a value of .F. means "no default is specified",
  * while an empty string would signify to leave that attribute blank. If no default is specified, then
  * any value set in the constructor of the individual element class, if any, will be used. This approach 
  * provides for maximum flexibility when needed, but also minimizes application coding that is required 
  * when you want a consistent look across one table or all tables in an application.
  *
  * EXAMPLE: "Font Color"
  * 1. To change the color to "green" for a single field, simply change the "cFontColor" property for
  *    that column/element.
  * 2. To make all data columns green for a single table, simply change the "cDataFontColor" property
  *    in the main table object (i.e., this object).
  * 3. To make all data columns green for all tables in your application, subclass the table (or element)
  *    class and change the property value in the constructor code. Alternatively, you could use DEFINE
  *    constants, INI settings, user preference schemes, etc. to establish such. Further, if you are in
  *    a full CSS environment, you can simply specify the "cDataFontClass" property and then set all the
  *    desired properties in an external CSS file!

  ** Default Column Heading properties (row and cell):
  lColumnHeadingRow  = .T.          && set to .F. to remove the column heading row entirely!

  cHeadingRowValign  = "BOTTOM"
  cHeadingRowBgcolor = .F.
  cHeadingRowClass   = "HeadingRow"
  cHeadingRowStyle   = .F.

  cHeadingClass      = "HeadingCell"
  cHeadingStyle      = .F.
  cHeadingFontColor  = .F.
  cHeadingBgColor    = .F.          && BGCOLOR for individual heading cell (see cHeadingRowBgColor)
  cHeadingFontSize   = .F.          && abosulte or relative, change to .F. for none
  cHeadingFontFace   = .F.          && change to .F. for none
  cHeadingFontAttributes = .F.      && "B", "I", "BI" (can be affected by cHeadingTag -- TH is usually Bold regardless)
  cHeadingTag        = "th"         && if .F., element class value is used -- generally "TH"
  cHeadingFontClass  = .F.          && CSS class name
  cHeadingFontStyle  = .F.          && CSS

  ** Default Data Row properties (affect <tr> for each row): 
  cDataRowValign     = "top"
  cDataRowBgColor    = .F.
  cDataRowClass      = "DataRow"    && CSS class for row - assigned to <tr>
  cDataRowStyle      = .F.          && CSS 
  cDataRowMouseOverClass = .F.      && CSS (called by Java Script)
  cDataRowOnClickUrlExpression = .F.&& dynamic URL for row-based navigation

  ** Default Data Element properties:
  cDataCellClass     = "DataCell"   && CSS class for cell - assigned to <td>
  cDataCellStyle     = .F.          && CSS 
  cDataFontColor     = .F.          && if you use hex codes, be sure to include leading '#'
  cDataFontSize      = .F.          && abosulte or relative, change to .F. for none
  cDataFontFace      = .F.      && change to .F. for none
  cDataFontAttributes= .F.          && "B", "I", "BI"
  cDataFontClass     = .F.          && CSS class name
  cDataFontStyle     = .F.          && CSS
  cNullDisplay       = .F.          && default for all elements (inherits from VFP environment, SET( "NULLDISPLAY")

  ** Default Group properties: (used in ReconcileFormats when group objects have no settings)
  cGroupRowValign  = .F.
  cGroupRowBgcolor = .F.
  cGroupRowClass   = "GroupFooterRow"
  cGroupRowStyle   = .F.
  cGroupHeaderRowClass = "GroupHeaderRow"
  cGroupHeaderRowStyle = .F.
  cGroupLabelClass = "GroupLabel"
  cGroupLabelStyle = .F.

  cGroupCellClass   = "GroupCell"
  cGroupCellBgColor = .F.         && BGCOLOR for individual cell (see cGroupRowBgColor)

  cGroupFontColor  = .F.
  cGroupFontSize   = .F.          && abosulte or relative, change to .F. for none
  cGroupFontFace   = .F.          && change to .F. for none
  cGroupFontAttributes= "B"       && "B", "I", "BI" (can be affected by cHeadingTag -- TH is usually Bold regardless)
  cGroupFontClass  = .F.          && CSS class name
  cGroupFontStyle  = .F.          && CSS

  ** Calculation and Grand Total properties:
  lSumNumerics        = .F.         && All new numeric elements are set to be summed.
  nFooterTextColumn   = 0           && Which column to display words like "Grand Totals:"
  nFooterTextColspan  = 1           && COLSPAN attribute for above

  lSuppressOneRecordFooters = .F.   && suppress total rows when only one record in group
  
  lDisplayGrandTotals = .T.         && Flag for whether to show grand totals.
  cGrandTotalText     = "Grand Totals:"
  cGrandRowClass      = "GrandRow"  && CSS class
  cGrandLabelClass    = "GrandLabel"  && CSS class
  cGrandLabelStyle    = .F.
  cGrandRowStyle      = .F.         && CSS 
  cGrandValign        = "top"       && 
  cGrandRowBgColor    = .F.         &&
  cGrandBgColor       = .F.         &&
  cGrandFontAttributes= "B"         && also support I and BI, "" = none, .F. = use base element
  cGrandFontFace      = .F.         && 
  cGrandFontColor     = .F.         && 
  cGrandFontClass     = "GrandCell" && CSS 
  cGrandFontStyle     = .F.         && CSS

  *** Cascading Style Sheet (CSS) class properties:
  * (NOTE: To acheieve an application-wide appearance,
  * you can create your own CSS file with these class
  * names defined, *or* you can sub-class L7Table
  * and change the default class names. You can affect
  * the style of individual tables and elements by simply
  * setting the specific c???Class properties in your code.)
  *
  lUseCss = .T.  && when FALSE, disables all production of CLASS= attributes
  *
  * Here is a synopsis of all properties above that specify
  * specific CSS Class names:
  *
  *!*	cTableClass       = "DataTable"  
  *!*	cTitleClass       = "TableTitle" 
  *!*	cTitleFontClass   = "TitleFont"  
  *!* cTableCaptionClass   = "TitleFont"  
  *!* cZeroRecordMessageClass   = "ZeroRecordMessage"  
  *!*	cHeadingRowClass  = "HeadingRow"
  *!* cHeadingClass     = "HeadingCell"
  *!*	cHeadingFontClass = .F.          
  *!*	cDataRowClass     = "DataRow"    
  *!*	cDataCellClass    = "DataCell"   
  *!*	cDataFontClass    = .F.          
  *!*	cGroupRowClass    = "GroupRow"
  *!* cGroupCellClass   = "GroupCell"  
  *!*	cGroupFontClass   = .F.
  *!* cGrandRowClass    = "GrandRow"   
  *!*	cGrandFontClass   = "GrandCell"
  *!* cGrandRowLabelClass = "GrandLabel"  

  ** Pre-evaluated items (internal use only):
  *!*    PROTECTED cBeforeFirstColumn, lBeforeFirstColumnEVAL, ;
  *!*    	cAfterLastColumn, lAfterLastColumnEVAL 
  cBeforeFirstColumn     = ""
  lBeforeFirstColumnEVAL = .F.  && .F. = literal, .T. = expression
  cAfterLastColumn       = NULL
  lAfterLastColumnEVAL   = .F.  && .F. = literal, .T. = expression

  * ---------------------------------------------------------- *
  function AddTableClass(tcVal)
    this.cTableClass = ltrim(this.cTableClass + " " + m.tcVal)
    return 
  endfunc 
  * ---------------------------------------------------------- *
  FUNCTION cBeforeFirstColumn_ACCESS
    LOCAL lcTxt
    lcTxt = THIS.cBeforeFirstColumn
    RETURN IIF( THIS.lBeforeFirstColumnEVAL, ;
    	EVAL( THIS.cBeforeFirstColumn ), THIS.cBeforeFirstColumn)
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION cAfterLastColumn_ACCESS
    RETURN IIF( THIS.lAfterLastColumnEVAL, ;
    	EVAL( THIS.cAfterLastColumn ), ;
      IIF(ISNULL(THIS.cAfterLastColumn), ;
        [</] + THIS.cRecordElement + [>] + CHR(13) + CHR(10), ;
        THIS.cAfterLastColumn))
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION nAbsoluteRecNo_ACCESS
    RETURN THIS.oDataBehavior.nAbsoluteRecNo
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION nRecCount_ACCESS
    RETURN THIS.oDataBehavior.nRecCount
    ** RETURN RECCOUNT()
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION cTableWidth_ASSIGN( lvWidth)
    * Protect against numeric values being passed.
    IF VARTYPE( m.lvWidth) = "C"
    	THIS.cTableWidth = m.lvWidth
    ELSE 
    	THIS.cTableWidth = TRANS(m.lvWidth )
    ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION DESTROY
    THIS.RELEASE()
    #IF L7_TABLE_DEBUG = .T.
    DEBUGOUT THIS.Name + ' [' + THIS.Class + '] destroyed'
    #ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION RELEASE
    NOTE: Subclasses call additional Release() methods and then DODEFAULT() to here.

    LOCAL ii
    FOR ii = 1 TO THIS.nGroups
    	IF TYPE( "THIS.aGroups[ m.ii]") = "O" AND VARTYPE( THIS.aGroups[ m.ii]) = "O"
    		THIS.aGroups[ m.ii].Release()
    		THIS.aGroups[ m.ii] = .F.
    	ENDIF
    ENDFOR
    THIS.nGroups = 0

    FOR ii = 1 TO THIS.nExtraRows
    	IF TYPE( "THIS.aExtraRows[ m.ii]") = "O" AND VARTYPE( THIS.aExtraRows[ m.ii]) = "O"
    		THIS.aExtraRows[ m.ii].Release()
    		THIS.aExtraRows[ m.ii] = .F.
    	ENDIF
    ENDFOR
    THIS.nExtraRows = 0

    FOR ii = 1 TO THIS.nElements
    	IF TYPE( "THIS.aElements[ m.ii]") = "O" AND VARTYPE( THIS.aElements[ m.ii]) = "O"
    		THIS.aElements[ m.ii].Release()
    		THIS.aElements[ m.ii] = .F.
    	ENDIF
    ENDFOR
    THIS.nElements = 0
    
    ** Can't do this since output object may be called seprately.
    ** This architecture is flawed--need to change it. We're
    ** calling RELEASE from ProcessCursor--seems wrong. Maybe need
    ** a ReleaseObjects() or whatever???
    ** THIS.oOutput = NULL
  ENDFUNC  && RELEASE
  * ---------------------------------------------------------- *
  FUNCTION INIT( loResponse)
    IF VARTYPE( m.loResponse) = "O"
    	* We've passed in a response object to write to.
    	* Note that this object must have an interface that includes
    	* public Write and (potentially) GetOutput methods.
    	
    	THIS.oOutput = m.loResponse
    ELSE
    	* Create our own text stream handling object. You then call
    	* its GetOutput method after processing the cursor.
    	THIS.oOutput = CREATEOBJECT( "L7TextStream" )
    ENDIF

    #IF L7_TABLE_DEBUG = .T.
    DEBUGOUT THIS.Name + ' [' + THIS.Class + '] initialized'
    #ENDIF
  ENDFUNC  && INIT
  * ---------------------------------------------------------- *
  #IF L7_TABLE_ERROR_HANDLING = .T.
  FUNCTION ERROR( lnErr, lcMthd, lnLine )
    THIS.lError = .T.
    THIS.cErrorMessage = MESSAGE()
    THIS.cErrorInfo = "Error " + TRANS( m.lnErr) + " in line " + ;
    	TRANS( m.lnLine ) + " of method " + m.lcMthd + "."
  ENDFUNC  && ERROR
  #ENDIF
  * ---------------------------------------------------------- *
  FUNCTION Write( lcText)
    IF VARTYPE( m.lcText) <> "C"
    	lcText = TRANSFORM( m.lcText)
    ENDIF
    THIS.oOutput.Write( m.lcText )
  ENDFUNC  && Write
  * ---------------------------------------------------------- *
  FUNCTION WriteLn( lcText)
    IF VARTYPE( m.lcText) <> "C"
    	lcText = TRANSFORM( m.lcText)
    ENDIF
    THIS.oOutput.Write( m.lcText + CHR(13) + CHR(10) )
  ENDFUNC  && Write
  * --------------------------------------------------------- *
  function Reset
    * Enable same column setup to be reused.
    local ii 
    with this
      .lRendered = .F.
      .cResult = ""
      .lCursorProcessed = .F.
      .oOutput.Clear()
      * call Reset method on each column/element (clears totals)
      for ii = 1 TO this.nElements
        if type("THIS.aElements[ m.ii]") = "O" AND vartype(this.aElements[ m.ii]) = "O"
          this.aElements[ m.ii].Reset() 
        endif 
      next  
      .oDataBehavior = NULL   && iterators could have state issues
      if type("THIS.oRender") = "O"
        .RemoveObject('oRender')
      endif 
    endwith 
    return 
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION PreRender()
    * For debugging, or to adjust timing, or for items 
    * that are rendered more than once.
    THIS.cResult = THIS.Render()
    THIS.lRendered = .T. && so we don't need to render twice
  ENDFUNC  && PreRender
  * ---------------------------------------------------------- *
  FUNCTION Render
    IF THIS.lRendered = .T.
      RETURN THIS.cResult
    ENDIF
    RETURN THIS.GetOutput()
  ENDFUNC  && Render
  * ---------------------------------------------------------- *
  FUNCTION GetOutput
    private THISTABLE
    THISTABLE = THIS  && support dynamic expressions, particularly CSS 
    IF THIS.lCursorProcessed = .F.
      THIS.ProcessCursor()  && boot-strap if developer forgot
    ENDIF
    RETURN THIS.oOutput.GetOutput()
  ENDFUNC  && GetOutput
  * ---------------------------------------------------------- *
  FUNCTION SetupDataBehavior( lvParm)
    private poTable
    poTable = this
    IF VARTYPE( THIS.oDataBehavior ) <> 'O'
    	THIS.oDataBehavior = ;
    		CREATEOBJECT( THIS.cDataBehaviorClass, m.lvParm )
      * Pass along any filter:,
      IF NOT EMPTY(THIS.cFilter)
        THIS.oDataBehavior.SetFilter(THIS.cFilter)
      ENDIF
    ENDIF
    RETURN 
  ENDFUNC  && SetupDataBehavior
  * ---------------------------------------------------------- *
  FUNCTION AddExtraRow(lnLocation, lcClass)
    lcClass = IIF( EMPTY( m.lcClass), THIS.cExtraRowVfpClass, m.lcClass)
    THIS.nExtraRows = THIS.nExtraRows + 1
    DIMENSION THIS.aExtraRows[ THIS.nExtraRows]
    THIS.aExtraRows[ THIS.nExtraRows] = ;
    	CREATEOBJECT( m.lcClass, THIS, m.lnLocation )
    * Return an object reference to the Row object:
    RETURN THIS.aExtraRows[ THIS.nExtraRows]
  ENDFUNC  && AddExtraRow
  * ---------------------------------------------------------- *
  * ex: loGrp = .addGroup('par_state', 'State: ', .t., ["State: " + Par_State])
  FUNCTION AddGroup(lcExpr, lcHeading, llHeadRow, lcDisplayExpr)
    LOCAL loObj
    loObj = CREATEOBJECT( THIS.cGroupVfpClass, THIS, m.lcExpr, m.lcHeading, m.lcDisplayExpr )
    IF m.llHeadRow
      loObj.lHeaderRow = .T.
    ENDIF 
    THIS.nGroups = THIS.nGroups + 1
    DIMENSION THIS.aGroups[ THIS.nGroups]
    THIS.aGroups[ THIS.nGroups] = m.loObj
    * Return an object reference to the Group object:
    RETURN m.loObj
  ENDFUNC  && AddGroup
  * ---------------------------------------------------------- *
  function SetupFromSpec(toSpec)
    for lnCol = 1 to toSpec.columns.count
      loCol = toSpec.columns[m.lnCol]
      lcClass = iif(pemstatus(loCol, "cVfpClass", 5), loCol.cVfpClass, THIS.cElementVfpClass)
      lnType = iif(pemstatus(loCol, "nType", 5), loCol.nType, L7_ELEMENTTYPE_FIELD)
      * [[ ...
    next 
  endfunc 
  * ---------------------------------------------------------- *
  * Table::AddElement
  FUNCTION AddElement(lnType, lvItem, lcHead, lcDisplayExpr, lcClass)
    * lnType : type of element (see constants L7_ELEMENTTYPE_??)
    * lvItem : field name or other expression
    * lcHead : (optional) element column header string 
    * lcDisplayExpr : (optinal) alternative expression to eval/display (instead of raw field value)
    lcClass = IIF(EMPTY(m.lcClass), THIS.cElementVfpClass, m.lcClass)
    THIS.nElements = THIS.nElements + 1
    DIMENSION THIS.aElements[ THIS.nElements]
    THIS.aElements[ THIS.nElements] = CREATEOBJECT( m.lcClass, ;
    	THIS, m.lnType, m.lvItem, m.lcHead, m.lcDisplayExpr )
    * Pass back an object reference:
    RETURN THIS.aElements[ THIS.nElements]
  ENDFUNC  && AddElement
  * ---------------------------------------------------------- *
  * Table::GetElement
  FUNCTION GetElement(lcField, lcPropName)
    * Get an object reference to an existing element, by passing 
    * in the field name. Convenient for modifying a single item
    * after having used SetupFromCursor().
    * ALT: Can return eval'd property name or method call (2nd parm).
    * Returns NULL if a matching field is not found.
    LOCAL ii, lcExpr, loElem, lcType
    lcType = VARTYPE( m.lcField)
    loElem = NULL
    DO CASE
    CASE m.lcType = "N"
    	loElem = THIS.aElements[ m.lcField]
    CASE m.lcType = "C"
    	FOR ii = 1 TO THIS.nElements
    		lcExpr = THIS.aElements[ m.ii].cExpression
    		IF VARTYPE( m.lcExpr) = "C" AND LOWER( m.lcExpr) == LOWER( m.lcField)
    			loElem = THIS.aElements[ m.ii]
    			EXIT
    		ENDIF
    	ENDFOR
    ENDCASE
    
    IF EMPTY( m.lcPropName) OR ISNULL( m.loElem)
      * Pass back an object reference:
      RETURN m.loElem
    ELSE
      RETURN EVALUATE( "m.loElem." + m.lcPropName)
    ENDIF
  ENDFUNC  && GetElement
  * ---------------------------------------------------------- *
  * Table::SetElementProperty
  FUNCTION SetElementProperty(lcField, lcProp, lvValue)
    * Sets an element object's property, by referring to just the field
    * name, without having to obtain an object reference. Convenient 
    * for modifying a single properties after having used SetupFromCursor().
    * Returns .T. if successful.
    LOCAL ii, lcExpr, loElem, lcType, llResult
    lcType = VARTYPE( m.lcField)
    loElem = NULL
    llResult = .F.
    DO CASE
    CASE m.lcType = "N"
    	loElem = THIS.aElements[ m.lcField]
    	llResult = .T.
    CASE m.lcType = "C"
    	FOR ii = 1 TO THIS.nElements
    		lcExpr = THIS.aElements[ m.ii].cExpression
    		IF VARTYPE( m.lcExpr) = "C" AND LOWER( m.lcExpr) == LOWER( m.lcField)
    			loElem = THIS.aElements[ m.ii]
    			llResult = .T.
    			EXIT
    		ENDIF
    	ENDFOR
    ENDCASE
    IF m.llResult
    	STORE m.lvValue TO ( "loElem." + m.lcProp )
    ENDIF
    RETURN m.llResult
  ENDFUNC  && SetElementProperty
  * ---------------------------------------------------------- *
  FUNCTION SetupFromCursor(lcFieldList, llInvertFieldList)
    * OPTIONAL step that creates one column for each field
    * in the current cursor.
    THIS.SetupDataBehavior()
    THIS.BeforeSetupFromCursor()
    LOCAL ii, loCol, lcField, llList
    llList = NOT EMPTY(m.lcFieldList)
    IF m.llList  && we've passed list to include or exclude
      LOCAL laFields[1]
      ALINES(laFields, m.lcFieldList, .T., ",")
    ENDIF
    FOR ii = 1 TO THIS.oDataBehavior.nFieldCount
      IF m.llList
        lcField = THIS.oDataBehavior.GetFieldName(m.ii)
        IF (NOT m.llInvertFieldList AND ASCAN(laFields, m.lcField, -1, -1, -1, 7) = 0) OR ;
          (m.llInvertFieldList AND ASCAN(laFields, m.lcField, -1, -1, -1, 7) > 0)
          *
          LOOP
        ENDIF
      ENDIF
    	THIS.AddCursorColumn( m.ii )
    	IF THIS.lError
    		EXIT
    	ENDIF
    ENDFOR
  ENDFUNC  && SetupFromCursor
  * ---------------------------------------------------------- *
  FUNCTION AddCursorColumn( lvField, lcHead, lcDisplayExpr, lcClass, lcStyle, lcDataType )
    * lvField : field name or number
    * lcHead : (optional) element column header string 
    * lcDisplayExpr : (optinal) alternative expression to eval/display (instead of raw field value)
    * lcDataType : if specified, pre-sets type without examining cursor [MANDATORY IF CURSOR NOT AVAILABLE!!]
    LOCAL loCol, lcType, lcName
    IF VARTYPE( m.lvField ) = "N"  && passed field number
    	lcName = THIS.oDataBehavior.GetFieldName( m.lvField )
      IF EMPTY(m.lcDataType)
      	lcType = THIS.oDataBehavior.GetFieldType( m.lvField )
      ELSE
        lcType = m.lcDataType
      ENDIF 
    ELSE  && passed field name or expression
    	lcName = m.lvField
      IF EMPTY(m.lcDataType)
      	lcType = TYPE( m.lvField )
      ELSE
        lcType = m.lcDataType
      ENDIF 
    ENDIF
    IF EMPTY(m.lcDisplayExpr)
      IF m.lcType = "L"  && give logical fields a default Yes/No look
        lcDisplayExpr = [IIF(] + m.lcName + [,"Yes","No ")]
      ENDIF
    ENDIF
    IF THIS.lSimple && for simple tables, just add as an element
    	loCol = THIS.AddElement( 1, m.lcName, m.lcHead, m.lcDisplayExpr )
    	IF m.lcType <> "U"
    		loCol.cDataType = m.lcType
    		IF m.lcType $ "INFBY" AND THIS.lSumNumerics
    			loCol.nCalcType = L7_CALCTYPE_SUM
    		ENDIF
    	ENDIF
    ELSE  && for complex tables, add a column and specify this as first element
    	loCol = THIS.AddColumn( 1, m.lcName, m.lcHead, m.lcDisplayExpr )

    	IF m.lcType <> "U"
    		loCol.aElements[ 1].cDataType = m.lcType
    		IF m.lcType $ "INFBY" AND THIS.lSumNumerics
    			loCol.aElements[1].nCalcType = L7_CALCTYPE_SUM
    		ENDIF
    	ENDIF
    ENDIF
    * process optional class/style params:
    IF NOT EMPTY(m.lcClass)
      loCol.cCellClass = m.lcClass
    ENDIF 
    IF NOT EMPTY(m.lcStyle)
      loCol.cCellStyle = m.lcStyle
    ENDIF 

    RETURN loCol
  ENDFUNC  && AddCursorColumn
  * ---------------------------------------------------------- *
  FUNCTION BeforeSetupFromCursor  && Hook
    * Example that adds row numbers:
    * THIS.AddColumn( -1)
  ENDFUNC 
  * ---------------------------------------------------------- *
  FUNCTION SetupRenderer
    * Class factory.
    IF TYPE( "THIS.oRender") <> "O"
      THIS.ADDOBJECT( "oRender", THIS.cRenderClass)
    ENDIF
  ENDFUNC  && SetupRenderer
  * ---------------------------------------------------------- *
  FUNCTION ProcessCursor
    LOCAL loCol, loElem, loGroup, llSkip, lxVal, ii
    private THISRECORD 
    WITH this 
      * Mark flag that we've run the thing (see bootstrap from GetOutput):
      .lCursorProcessed = .T.
      
      .SetupRenderer()
      .SetupDataBehavior()

      IF .lSimple AND .nElements = 0 OR ;
      	NOT .lSimple AND .nColumns = 0
      	* No column definitions sent in!
      	.SetupFromCursor()
      ENDIF
      
      IF .lSimple
        * In case of reset:
        .nColumns = 0
        DIMENSION .aColumns[1,1]
        * Copy elements to columns:
      	ACOPY( .aElements, .aColumns )
      	.nColumns = .nElements
      ENDIF

      * Set up any calculated elements to contain arrays for totals:
      .nCalcElementCount = 0

      * Set up calculation arrays, bubble settings from column to element, establish
      * location of footer text, etc:
      .ReconcileCalculationProperties()

      .SetActiveColumnCount()

      * Pre-establish formats and expressions once to improve performance
      * on all subsequent records:
      .ReconcileFormats()

      * Go to first record, if any:
      .oDataBehavior.MoveFirst()
      IF NOT .oDataBehavior.EOF OR .lZeroRecordTable        
        * Open table and column headers:
        .BeforeFirstRecord()
      ENDIF 
      
      * Set up paging if specified:
      IF .nPage_ItemsPerPage > 0
      	IF .nPage_ShowPage = 0
      		.nPage_ShowPage = 1
      	ENDIF
      	.nStartRow = 1 + .nPage_ItemsPerPage * ( .nPage_ShowPage - 1 )
      	.nEndRow = .nPage_ItemsPerPage * .nPage_ShowPage 
      ENDIF

      .nRowCount = 0
      .nGroupRowCount = 0

      * Loop through all records:
      DO WHILE NOT .oDataBehavior.EOF
        if .oDataBehavior.lObjectBased
          THISRECORD = .oDataBehavior.getRecord()
        endif 

        .nRowCount = .nRowCount + 1
        .nGroupRowCount = .nGroupRowCount + 1

      	llSkip = .F.

      	*** WARNING: Using the StartRow/EndRow feature is INCOMPATIBLE
      	*** with using the Group feature!!
      	
      	IF .nGroups > 0
      		* See if group will change before processing record, so we
      		* can insert group headers and footer:
      		
      		IF .nRowCount = 1 && 1st row - must open all groups!
      			.OpenGroup( 1)
      		ELSE
      			FOR ii = 1 TO .nGroups
      				* Peek at what the group value will be in the new record.
      				lxVal = EVAL( .aGroups[ m.ii].cExpression )
      				
      				IF NOT m.lxVal == .aGroups[ m.ii].vValue AND ;
      					NOT ( ISNULL( m.lxVal) AND ISNULL( .aGroups[ m.ii].vValue) )
      					* Value will change. Exit here, leaving ii set
      					* to the highest group level that is changing.
      					EXIT
      				ENDIF
      			ENDFOR
      			IF m.ii <= .nGroups  && Change detected at group level ii.
      				.CloseGroup( m.ii)
      				.OpenGroup( m.ii)
      			ENDIF
      		ENDIF
      		* Increment each group's row counter:
      		FOR EACH loGroup IN .aGroups
      			loGroup.nCounter = loGroup.nCounter + 1
      		ENDFOR
      	ENDIF

      	IF .nStartRow > 0 AND .nRowCount < .nStartRow
      		* We have not encountered the desired starting row.
      		llSkip = .T.
      	ENDIF
      	IF .nEndRow > 0 AND .nRowCount > .nEndRow
      		* We are past the desired ending row.
      		llSkip = .T.
      	ENDIF
      	
      	******* MAIN EVENT *******
      	IF m.llSkip = .F.
      		.ProcessRecord()
      		
      		#IF L7_SHAREWARE
      		DECLARE Sleep IN WIN32API INTEGER
      		Sleep( 50)  && 0.05 second delay for each record
      		#ENDIF
      	ENDIF
      	**************************

      	* Move to next record:
      	.oDataBehavior.MoveNext()
      ENDDO

      * After exiting the loop, we need to close 
      * all groups to get the final footers:
      IF .nGroups > 0
      	.CloseGroup( 1)
      ENDIF

      * Handle condition where cursor is empty:
      IF .nRowCount = 0  && no records at all
      	.OnZeroRecords()
      ELSE
      	IF .nExtraRows > 0
      		.ProcessExtraRows( L7_TABLEROWLOCATION_AFTER_LAST_RECORD )
      	ENDIF
      ENDIF

      * Grand Total row:
      IF .lDisplayGrandTotals = .T. AND .nCalcElementCount > 0 AND .nRowCount > 0
      	.GrandTotals()
      ENDIF

      * Paging links:
      IF .nPage_ItemsPerPage > 0 AND .nRowCount > 0
      	.PageLinks()
      ENDIF

      * Close the table:
      IF .nRowCount > 0 OR .lZeroRecordTable        
        .AfterLastRecord()
      ENDIF 
      
      ** THIS.Release()  && Clear out all child objects here!
    ENDWITH 
    RETURN 
  ENDFUNC  && ProcessCursor
  * ---------------------------------------------------------- *
  FUNCTION ProcessRecord
    * Called from ProcessCursor method once per record.
    THIS.oRender.ProcessRecord()
    IF THIS.nExtraRows > 0
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_AFTER_EACH_RECORD )
    ENDIF
    RETURN 
  ENDFUNC  && ProcessRecord
  * ---------------------------------------------------------- *
  FUNCTION ProcessExtraRows(lnLocation, lnLevel)
    LOCAL ii
    FOR ii = 1 TO THIS.nExtraRows
    	IF BITAND( m.lnLocation, THIS.aExtraRows[ m.ii].nLocation ) > 0
    		* This row belongs here!
        THIS.Write( THIS.aExtraRows[ m.ii].GetOutput( m.lnLocation, m.lnLevel ) )
    	ENDIF
    ENDFOR
    RETURN 
  ENDFUNC  && ProcessExtraRows
  * ---------------------------------------------------------- *
  FUNCTION ReconcileFormats
    LOCAL loCol, loGroup, loElem, lcText, lcActiveText

    * Call each element routine that builds tags once and uses on every record.
    IF THIS.nElements > 0
    	FOR EACH loElem IN THIS.aElements
    		loElem.PreProcessTags()
    	ENDFOR
    ENDIF

    * Process each group object:
    IF THIS.nGroups > 0
    	FOR EACH loGroup IN THIS.aGroups
    		* Push down any table-level defaults where there is nothing specified
    		* for the group object:
    		IF VARTYPE( loGroup.cFontColor) <> "C" AND VARTYPE( THIS.cGroupFontColor) = "C"
    			loGroup.cFontColor = THIS.cGroupFontColor
    		ENDIF
    		IF VARTYPE( loGroup.cFontSize) <> "C" AND VARTYPE( THIS.cGroupFontSize) = "C"
    			loGroup.cFontSize = THIS.cGroupFontSize
    		ENDIF
    		IF VARTYPE( loGroup.cFontFace) <> "C" AND VARTYPE( THIS.cGroupFontFace) = "C"
    			loGroup.cFontFace = THIS.cGroupFontFace
    		ENDIF
    		IF VARTYPE( loGroup.cFontAttributes) <> "C" AND VARTYPE( THIS.cGroupFontAttributes) = "C"
    			loGroup.cFontAttributes = THIS.cGroupFontAttributes
    		ENDIF
    		IF VARTYPE( loGroup.cRowValign) <> "C" AND VARTYPE( THIS.cGroupRowValign) = "C"
    			loGroup.cRowValign = THIS.cGroupRowValign
    		ENDIF
    		IF VARTYPE( loGroup.cRowBgcolor) <> "C" AND VARTYPE( THIS.cGroupRowBgcolor) = "C"
    			loGroup.cRowBgcolor = THIS.cGroupRowBgcolor
    		ENDIF
    		IF VARTYPE( loGroup.cCellBgcolor) <> "C" AND VARTYPE( THIS.cGroupCellBgcolor) = "C"
    			loGroup.cCellBgcolor = THIS.cGroupCellBgcolor
    		ENDIF

    *[[ TO DO: Need to handle group.cHeader/Footer Class setting here -lc

    		IF THIS.lUseCss
    			* For any group w/o styles, use defaults:
    			IF VARTYPE( loGroup.cFontClass) <> "C"
    				loGroup.cFontClass = THIS.cGroupFontClass
    			ENDIF
    			IF VARTYPE( loGroup.cFontStyle) <> "C"
    				loGroup.cFontStyle = THIS.cGroupFontStyle
    			ENDIF
          * group header row:
    			IF VARTYPE( loGroup.cHeaderRowStyle) <> "C"
    				loGroup.cHeaderRowStyle = THIS.cGroupHeaderRowStyle
    			ENDIF
    			IF VARTYPE( loGroup.cHeaderRowClass) <> "C"
    				loGroup.cHeaderRowClass = THIS.cGroupHeaderRowClass
    			ENDIF
          * group footer (total) row:
          IF VARTYPE( loGroup.cRowStyle) <> "C"
            loGroup.cRowStyle = THIS.cGroupRowStyle
          ENDIF
          IF VARTYPE( loGroup.cRowClass) <> "C"
            loGroup.cRowClass = THIS.cGroupRowClass
          ENDIF
          * group label text:
          IF VARTYPE( loGroup.cLabelStyle) <> "C"
            loGroup.cLabelStyle = THIS.cGroupLabelStyle
          ENDIF
          IF VARTYPE( loGroup.cLabelClass) <> "C"
            loGroup.cLabelClass = THIS.cGroupLabelClass
          ENDIF
          
    		ENDIF
    	ENDFOR  && each group
    ENDIF

    * Set NULL Display Strings to the table default:
    IF VARTYPE( THIS.cNullDisplay) <> "C"
    	THIS.cNullDisplay = SET( "NULLDISPLAY")
    ENDIF
    IF THIS.nElements > 0
    	FOR EACH loElem IN THIS.aElements
    		IF VARTYPE( loElem.cNullDisplay) <> "C"
    			loElem.cNullDisplay = THIS.cNullDisplay
    		ENDIF
    	ENDFOR
    ENDIF

    * Establish the row opening string:
    lcText = [<] + THIS.cRecordElement 
    lcActiveText = []
    IF VARTYPE( THIS.cDataRowValign) = "C" AND NOT EMPTY( THIS.cDataRowValign)
    	lcText = m.lcText + [ valign="] + THIS.cDataRowValign + ["]
    ENDIF

    IF THIS.lUseCss 
    	IF VARTYPE( THIS.cDataRowClass) = "C" AND NOT EMPTY( THIS.cDataRowClass)
        IF "(" $ THIS.cDataRowClass  && Expression.
          lcActiveText = m.lcActiveText + ' + [ class="] + ' + THIS.cDataRowClass + ' + ["]'
        ELSE
      		lcText = m.lcText + [ class="] + THIS.cDataRowClass + ["]
        ENDIF
        * [[ why is following nested down a level? is it only applicable when dataRowClass is specified?
        IF VARTYPE( THIS.cDataRowMouseOverClass) = "C" AND NOT EMPTY( THIS.cDataRowMouseOverClass)
          lcText = m.lcText + [ onMouseOver="this.className='] + THIS.cDataRowMouseOverClass + [';"] + ;
            [ onMouseOut="this.className='] + THIS.cDataRowClass + [';"]
        ENDIF
    	ENDIF
    	IF VARTYPE( THIS.cDataRowStyle) = "C" AND NOT EMPTY( THIS.cDataRowStyle)
        IF "(" $ THIS.cDataRowStyle  && Expression.
          lcActiveText = m.lcActiveText + ' + [ style="] + ' + THIS.cDataRowStyle + ' + ["]'
        ELSE 
      		lcText = m.lcText + [ style="] + THIS.cDataRowStyle + ["]
        ENDIF 
    	ENDIF
    ENDIF
    
    IF VARTYPE( THIS.cDataRowBgColor) = "C" AND NOT EMPTY( THIS.cDataRowBgColor)
    	IF "(" $ THIS.cDataRowBgColor  && Expression - need to EVAL for each record!
    		lcActiveText = m.lcActiveText + '+ [ bgcolor="] + ' + THIS.cDataRowBgColor + ' + ["]'
    	ELSE
    		lcText = m.lcText + [ bgcolor="] + THIS.cDataRowBgColor + ["]
    	ENDIF
    ENDIF
    IF VARTYPE( THIS.cDataRowOnClickUrlExpression) = "C" AND NOT EMPTY( THIS.cDataRowOnClickUrlExpression)
      lcActiveText = m.lcActiveText + ' + [ onClick="document.location=' + ['] + ']'
      lcActiveText = m.lcActiveText + ' + ' + THIS.cDataRowOnClickUrlExpression
      lcActiveText = m.lcActiveText + ' + [' + ['] + ';"]'
    ENDIF
    * See if any active text, and also add trailing >.
    IF NOT EMPTY(m.lcActiveText)
      THIS.lBeforeFirstColumnEVAL = .T.
      lcText = '[' + m.lcText + ']' + m.lcActiveText
      lcText = m.lcText + ' + [>] + CHR(13) + CHR(10)'
    ELSE
      lcText = m.lcText + [>] + CHR(13) + CHR(10)
    ENDIF
    THIS.cBeforeFirstColumn = m.lcText 

    RETURN 
  ENDFUNC  && ReconcileFormats
  * --------------------------------------------------------- *
  FUNCTION TransferTableDefaults(loCol)
    * loCol : column or simple element

    * Wherever there is a table-level default property, and the column does not have a
    * specific setting for the same property, set the column property to the table property:
    *
    IF VARTYPE( loCol.cFontColor ) <> "C" AND VARTYPE( THIS.cDataFontColor) = "C"
    	loCol.cFontColor = THIS.cDataFontColor
    ENDIF
    IF VARTYPE( loCol.cFontFace ) <> "C" AND VARTYPE( THIS.cDataFontFace ) = "C"
    	loCol.cFontFace = THIS.cDataFontFace
    ENDIF
    IF VARTYPE( loCol.cFontSize ) <> "C" AND VARTYPE( THIS.cDataFontSize ) = "C"
    	loCol.cFontSize = THIS.cDataFontSize
    ENDIF
    IF VARTYPE( loCol.cFontAttributes ) <> "C" AND VARTYPE( THIS.cDataFontAttributes ) = "C"
    	loCol.cFontAttributes = THIS.cDataFontAttributes
    ENDIF
    IF VARTYPE( loCol.cHeadingTag ) <> "C" AND VARTYPE( THIS.cHeadingTag ) = "C"
    	loCol.cHeadingTag = THIS.cHeadingTag
    ENDIF
    IF VARTYPE( loCol.cHeadingBgColor ) <> "C" AND VARTYPE( THIS.cHeadingBgColor ) = "C"
    	loCol.cHeadingBgColor = THIS.cHeadingBgColor
    ENDIF
    IF VARTYPE( loCol.cHeadingFontColor ) <> "C" AND VARTYPE( THIS.cHeadingFontColor) = "C"
    	loCol.cHeadingFontColor = THIS.cHeadingFontColor
    ENDIF
    IF VARTYPE( loCol.cHeadingFontFace ) <> "C" AND VARTYPE( THIS.cHeadingFontFace ) = "C"
    	loCol.cHeadingFontFace = THIS.cHeadingFontFace
    ENDIF
    IF VARTYPE( loCol.cHeadingFontSize ) <> "C" AND VARTYPE( THIS.cHeadingFontSize ) = "C"
    	loCol.cHeadingFontSize = THIS.cHeadingFontSize
    ENDIF
    IF VARTYPE( loCol.cHeadingFontAttributes ) <> "C" AND VARTYPE( THIS.cHeadingFontAttributes ) = "C"
    	loCol.cHeadingFontAttributes = THIS.cHeadingFontAttributes
    ENDIF

    * If we're using CSS and the column doesn't have specific
    * CLASS and/or STYLE, use the table's default value:
    IF THIS.lUseCss
    	* Cell class/style:
    	IF VARTYPE( loCol.cCellClass ) <> "C"
    		loCol.cCellClass = THIS.cDataCellClass
    	ENDIF
    	IF VARTYPE( loCol.cCellStyle ) <> "C"
    		loCol.cCellStyle = THIS.cDataCellStyle
    	ENDIF
    	* Font class/style:
    	IF VARTYPE( loCol.cFontClass ) <> "C" AND VARTYPE( THIS.cDataFontClass ) = "C"
    		loCol.cFontClass = THIS.cDataFontClass
    	ENDIF
    	IF VARTYPE( loCol.cFontStyle ) <> "C" AND VARTYPE( THIS.cDataFontStyle ) = "C"
    		loCol.cFontStyle = THIS.cDataFontStyle
    	ENDIF
    	* Heading Font class/style:
      IF VARTYPE( loCol.cHeadingClass ) <> "C" AND VARTYPE( THIS.cHeadingClass ) = "C"
        loCol.cHeadingClass = THIS.cHeadingClass
      ENDIF
      IF VARTYPE( loCol.cHeadingStyle ) <> "C" AND VARTYPE( THIS.cHeadingStyle ) = "C"
        loCol.cHeadingStyle = THIS.cHeadingStyle
      ENDIF
    	IF VARTYPE( loCol.cHeadingFontClass ) <> "C" AND VARTYPE( THIS.cHeadingFontClass ) = "C"
    		loCol.cHeadingFontClass = THIS.cHeadingFontClass
    	ENDIF
    	IF VARTYPE( loCol.cHeadingFontStyle ) <> "C" AND VARTYPE( THIS.cHeadingFontStyle ) = "C"
    		loCol.cHeadingFontStyle = THIS.cHeadingFontStyle
    	ENDIF
    ENDIF
    RETURN 
  ENDFUNC  && TransferTableDefaults        
  * ---------------------------------------------------------- *
  FUNCTION OnZeroRecords
    * You can override this method, or just change the text
    * property to affect this behavior.
    THIS.oRender.OnZeroRecords()
*!*      IF NOT EMPTY( THIS.cZeroRecordString )
*!*      	LOCAL lcText
*!*      	lcText = [<tr><td align=center colspan=] + TRANS( THIS.nActiveColumns) + [>] + ;
*!*      		[<span class="] + THIS.cZeroRecordMessageClass + [">] + ;
*!*          THIS.cZeroRecordString + [</span></td></tr>] + CHR(13) + CHR(10)
*!*      	THIS.Write( m.lcText )
*!*      ENDIF
    IF THIS.nExtraRows > 0 AND THIS.lZeroRecordTable
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_ON_ZERO_RECORDS )
    ENDIF
    RETURN 
  ENDFUNC  && OnZeroRecords
  * ---------------------------------------------------------- *
  FUNCTION OpenGroup( tnLevel)
    * Note: Groups have no methods of their own. They just 
    *   hold data about the grouping. We manage that data from
    *   here and in the renderers.
    LOCAL ii, loElem, lcText, lcGroupValue, lcDispExpr
    THIS.nAbsoluteGroupNo = THIS.nAbsoluteGroupNo + 1 
    THIS.nGroupRowCount = 1
    lcText = ""
    
    * Whenever we open a group, we open all groups at lower
    * levels as well:
    FOR ii = m.tnLevel TO THIS.nGroups
      WITH this.aGroups[m.ii]
        * Set group value to that of current record:
      	.vValue = EVALUATE(.cExpression )
        * Reset the counter:
      	.nCounter = 0

      	IF NOT EMPTY(.cDisplayExpression)
          lcDispExpr = .cDisplayExpression
          IF .lDisplayTextmerge
            lcText = TextMergeX( m.lcDispExpr)
          ELSE  && just evaluate
            TRY
              lcText = TRANSFORM(EVALUATE(m.lcDispExpr))
            CATCH TO loExc
              lcText = "ERR (" + L7ExceptionMessage(m.loExc) + "): " + m.lcDispExpr
            ENDTRY
          ENDIF
          .cDisplayValue = m.lcText
      	ENDIF
      	
      	* Loop through all elements and clear any group totals and counts.
      	FOR EACH loElem IN THIS.aElements
      		IF loElem.nCalcType > L7_CALCTYPE_NONE
            IF loElem.nCalcType = L7_CALCTYPE_COUNT
        			loElem.aGroupTotal[ m.ii ] = 0
            ELSE
              loElem.aGroupTotal[ m.ii ] = NULL
            ENDIF
      			loElem.aGroupCount[ m.ii ] = 0
      		ENDIF
      	ENDFOR
      ENDWITH 
    ENDFOR

    IF THIS.nExtraRows > 0
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_BEFORE_GROUP_HEADER, m.tnLevel )
    ENDIF

    LOCAL llRepeatTableHeader
    llRepeatTableHeader = .F.

    FOR ii = m.tnLevel TO THIS.nGroups
      THIS.oRender.GroupHeader(m.ii)
    	
    	IF THIS.aGroups[ m.ii].lRepeatTableHeader
    		llRepeatTableHeader = .T.
    	ENDIF
    ENDFOR

    IF THIS.nExtraRows > 0
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_AFTER_GROUP_HEADER, m.tnLevel )
    ENDIF

    IF m.llRepeatTableHeader
    	* TO DO!!
      THIS.oRender.RepeatTableHeader()
    ENDIF
    RETURN 
  ENDFUNC  && OpenGroup
  * ---------------------------------------------------------- *
  FUNCTION CloseGroup( tnLevel)
    * Called at any group ending. The highest-order group number where a
    * change occurred is passed.  This method closes all lower groups as well.

    LOCAL ii, jj, lcText, loCol, loElem, lcElemText, lvVal, ;
    	lcGroupValue, lnColCount, lnConsumedByColspan, loGrp
    lnColCount = 0
    lnConsumedByColspan = 0

    * Iterate backward from lowest-order group 
    * to the group whose value changed:
    FOR ii = THIS.nGroups TO m.tnLevel STEP -1
      loGrp = THIS.aGroups[ m.ii]
      WITH loGrp
      	* If there are any calculated columns, output group footer rows for 
      	* any group that specifies their use:
      	IF THIS.nCalcElementCount > 0 AND .lTotalRow = .T.
          IF THIS.nExtraRows > 0
            THIS.ProcessExtraRows( L7_TABLEROWLOCATION_BEFORE_GROUP_FOOTER, m.tnLevel )
          ENDIF
          IF .nCounter >= 2 OR NOT THIS.lSuppressOneRecordFooters
            THIS.oRender.GroupFooter(m.ii)
          ENDIF
      		IF THIS.nExtraRows > 0
      			THIS.ProcessExtraRows( L7_TABLEROWLOCATION_AFTER_GROUP_FOOTER, m.tnLevel )
      		ENDIF
      	ENDIF  && THIS.nCalcElementCount > 0 AND .lTotalRow = .T.
      	IF .lFooterRow
      		** [[ FUTURE USE ]]
      	ENDIF
      ENDWITH     	
    ENDFOR  && ii = THIS.nGroups TO m.tnLevel STEP -1

    FOR ii = THIS.nGroups TO m.tnLevel STEP -1
    	= .F.
    ENDFOR
    RETURN 
  ENDFUNC  && CloseGroup
  * ---------------------------------------------------------- *
  FUNCTION DetermineFooterTextColumns
    * Called only if not specfied, thus only called once per report,
    * either at first group footer or in grand totals.
    LOCAL lnStart, lnCounter, lnSpan, loCol
    lnStart = 0
    lnCounter = 0
    lnSpan = 1
    * Loop trhough each active column.
    FOR EACH loCol IN THIS.aColumns
    	IF loCol.lActive = .F.
    		LOOP
    	ENDIF
    	lnCounter = m.lnCounter + 1
    	IF loCol.nCalcElements = 0  && This column has no calc elements.
    		IF m.lnStart = 0  && first such column - we'll start here
    			lnStart = m.lnCounter
    		ELSE  && continuum -- just add to colspan
    			lnSpan = m.lnSpan + 1
    		ENDIF
    	ELSE  && a calc column
    		IF m.lnStart = 0  && haven't found a place yet -- keep trying
    			LOOP
    		ELSE  && OK, we're done
    			EXIT
    		ENDIF
    	ENDIF
    ENDFOR
    IF m.lnStart = 0  && never found a place
    	THIS.nFooterTextColumn = -1
    ELSE
    	THIS.nFooterTextColumn = m.lnStart
    	THIS.nFooterTextColspan = m.lnSpan
    ENDIF
    RETURN 
  ENDFUNC  && DetermineFooterTextColumns
  * ---------------------------------------------------------- *
  FUNCTION GrandTotals
    IF THIS.nCalcElementCount > 0
    	IF THIS.nExtraRows > 0
    		THIS.ProcessExtraRows( L7_TABLEROWLOCATION_BEFORE_GRAND_TOTALS )
    	ENDIF
      
      IF THIS.nRowCount >= 2 OR NOT THIS.lSuppressOneRecordFooters
        THIS.oRender.GrandTotals()
      ENDIF

    	IF THIS.nExtraRows > 0
    		THIS.ProcessExtraRows( L7_TABLEROWLOCATION_AFTER_GRAND_TOTALS )
    	ENDIF
    ENDIF
    RETURN 
  ENDFUNC  && GrandTotals
  * ---------------------------------------------------------- *
  FUNCTION PageLinks
    IF THIS.nPage_ItemsPerPage > 0
    	THIS.nPage_TotalPages = CEILING( THIS.nRowCount / THIS.nPage_ItemsPerPage )
    ENDIF
    IF THIS.nPage_TotalPages > 0 AND NOT EMPTY( THIS.cPage_PageURL)
    	* Create an array of hyperlinks to each of the pages.
    	DIMENSION THIS.aPage_URLs[ THIS.nPage_TotalPages]
    	FOR ii = 1 TO THIS.nPage_TotalPages
    		IF EMPTY( THIS.cPage_PageVarName )
    			* Just tack a ~nn to end of URL: 
    			THIS.aPage_URLs[ m.ii] = THIS.cPage_PageURL + "~" + TRANS( m.ii)
    		ELSE
    			* Create a URL that includes &pg=nn without adding another ~.
    			* You process this by Request.QueryString( "pg").
    			* This is the preferred approach.
    			THIS.aPage_URLs[ m.ii] = StuffURL( THIS.cPage_PageURL, ;
    				THIS.cPage_PageVarName, TRANS( m.ii))
    		ENDIF
    	ENDFOR
    	IF THIS.nPage_AutoGeneration > 0
    		* We call a separate method, so that you can subclass and overwrite the 
    		* appearance-creation code without having to repeat the URL creation code
    		* and other logic:
        THIS.oRender.WritePageLinks()
    	ENDIF
    ENDIF
    RETURN 
  ENDFUNC  && PageLinks
  * ---------------------------------------------------------- *
  FUNCTION SetActiveColumnCount
    * Determine number of active columns by checking if all elements
    * in a column are disabled. Getting the count is also needed for
    * COLSPAN values in title rows:
    LOCAL loCol, loElem, lnCount, ii, lcTitle
    lnCount = 0
    IF THIS.lSimple
    	FOR EACH loElem IN THIS.aElements
    		IF NOT loElem.lDisabled
    			lnCount = m.lnCount + 1
    		ENDIF
    	ENDFOR
    ELSE
    	FOR EACH loCol IN THIS.aColumns
    		IF loCol.lActive = .F.
    			LOOP
    		ENDIF
    		IF loCol.nElements = 0
    			lnCount = m.lnCount + 1
    		ELSE
    			loCol.lActive = .F.
    			FOR EACH loElem IN loCol.aElements
    				IF loElem.nDisplayType > 0
    					lnCount = m.lnCount + 1
    					loCol.lActive = .T.
    					EXIT
    				ENDIF
    			ENDFOR
    		ENDIF
    	ENDFOR
    ENDIF
    THIS.nActiveColumns = m.lnCount
    RETURN 
  ENDFUNC  && SetActiveColumnCount
  * ---------------------------------------------------------- *
  FUNCTION BeforeFirstRecord
    LOCAL lcTitle, lcStr
    * Open Table:
    THIS.oRender.OpenTable()

    * Before Title Row:
    IF THIS.nExtraRows > 0
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_BEFORE_TITLE  )
    ENDIF
    * Title Row:
    THIS.oRender.TitleRow()
    * After Title Row:
    IF THIS.nExtraRows > 0
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_AFTER_TITLE  )
    ENDIF

    * Column Heading Row:
    IF THIS.lColumnHeadingRow
    	THIS.ColumnHeadingRow()
    ENDIF
    IF THIS.nExtraRows > 0
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_AFTER_HEADING  )
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_BEFORE_FIRST_RECORD )
    ENDIF
    
    * Call renderer-specific needs:
    THIS.oRender.BeforeFirstRecord()
    RETURN 
  ENDFUNC  && BeforeFirstRecord
  * ---------------------------------------------------------- *
  FUNCTION ColumnHeadingRow
    * Writes row of column heading. Called from BeforeFirstRecord(),
    * depending on property lColumnHeadingRow. Could also be called
    * elsewhere, such as when a new group starts.
    THIS.oRender.ColumnHeadingRow()
  ENDFUNC  && ColumnHeadingRow
  * ---------------------------------------------------------- *
  FUNCTION AfterLastRecord
    IF THIS.nExtraRows > 0
    	THIS.ProcessExtraRows( L7_TABLEROWLOCATION_AFTER_EVERYTHING )
    ENDIF
    THIS.oRender.CloseTable()
  ENDFUNC  && AfterLastRecord
  * ---------------------------------------------------------- *
ENDDEFINE  && L7AbstractHtmlTable

*** ========================================================== ***
DEFINE CLASS L7ComplexTable AS L7AbstractHtmlTable
  lSimple = .F.

  * 1. Columns
  DIMENSION aColumns[ 1]
  nColumns = 0

  * ---------------------------------------------------------- *
  FUNCTION RELEASE
    LOCAL ii
    * MUST release columns before elements, since they hold extra
    * object references:
    FOR ii = 1 TO THIS.nColumns
    	IF TYPE( "THIS.aColumns[ m.ii]") = "O" AND VARTYPE( THIS.aColumns[ m.ii]) = "O"
    		IF NOT THIS.lSimple
    			THIS.aColumns[ m.ii].Release()
    		ENDIF
    		THIS.aColumns[ m.ii] = .F.
    	ENDIF
    ENDFOR
    THIS.nColumns = 0
    * Call default behavior, which handles the simple table objects:
    DODEFAULT()
  ENDFUNC  && RELEASE

  * ---------------------------------------------------------- *
  FUNCTION AddColumn(lnType, lcField, lcHead, lcDisplayExpr, lcClass)
    lcClass = IIF(EMPTY(m.lcClass), THIS.cColumnVfpClass, m.lcClass)
    THIS.nColumns = THIS.nColumns + 1
    DIMENSION THIS.aColumns[ THIS.nColumns]
    THIS.aColumns[ THIS.nColumns] = ;
    	CREATEOBJECT( m.lcClass, THIS, m.lnType, m.lcField, m.lcHead, m.lcDisplayExpr )
    * Return an object reference to the column object:
    RETURN THIS.aColumns[ THIS.nColumns]
  ENDFUNC  && AddColumn

  * ---------------------------------------------------------- *
  FUNCTION ReconcileCalculationProperties
    LOCAL loElem, loCol
    IF THIS.nColumns > 0
    	* Bubble down any column settings to individual elements that
    	* have no settings:
    	FOR EACH loCol IN THIS.aColumns
    		IF loCol.nElements > 0
    			FOR EACH loElem IN loCol.aElements
    				* Calc-Type:
    				IF ( VARTYPE( loElem.nCalcType) <> "N" OR loElem.nCalcType <= 1 ) AND ;
    					VARTYPE( loCol.nCalcType ) = "N"
    					*
    					loElem.nCalcType = loCol.nCalcType
    				ENDIF
    			ENDFOR
    		ENDIF
    	ENDFOR
    ENDIF

    IF THIS.nElements > 0
    	* For each calculated element, initialize arrays to hold
    	* group totals and counts:
    	FOR EACH loElem IN THIS.aElements
    		IF loElem.nCalcType > L7_CALCTYPE_NONE
    			IF THIS.nGroups > 0
    				DIMENSION loElem.aGroupTotal[ THIS.nGroups]
    				DIMENSION loElem.aGroupCount[ THIS.nGroups]
    			ENDIF
    			THIS.nCalcElementCount = THIS.nCalcElementCount + 1
    		ENDIF	
    	ENDFOR
    	* Also update each column's counter for formatting purposes:
    	IF THIS.nCalcElementCount > 0 
    		FOR EACH loCol IN THIS.aColumns
    			FOR EACH loElem IN loCol.aElements
    				IF loElem.nCalcType > L7_CALCTYPE_NONE
    					loCol.nCalcElements = loCol.nCalcElements + 1
    				ENDIF	
    			ENDFOR
    		ENDFOR
    		* And determine where to place any generic footer text:
    		IF THIS.nFooterTextColumn = 0
    			* Not specified by user, so figure out a reasonable default.
    			THIS.DetermineFooterTextColumns()
    		ENDIF
    	ENDIF
    ENDIF
    RETURN
  ENDFUNC  && ReconcileCalculationProperties
  * ---------------------------------------------------------- *
  FUNCTION ReconcileFormats
    * Complex Class Version.
    LOCAL loCol, loGroup, loElem, lcText

    * Process each column object:
    IF THIS.nColumns > 0
    	FOR EACH loCol IN THIS.aColumns
    		* For any column with one element, use that element's alignment.
    		IF VARTYPE( loCol.cAlign) <> "C" AND loCol.nElements >= 1
    			loCol.cAlign = loCol.aElements[1].cAlign
    		ENDIF
    		
    		THIS.TransferTableDefaults( m.loCol )

    		* NOTE: None of the following code IF..ENDIF ever gets processed for Simple tables!
    		*
    		* Now process each element in the column.
    		*
    		* Wherever there is a column-level default property, and the element does not have a
    		* specific setting for the same property, set the element property to the column property:
    		*
    		IF loCol.nElements > 0
    			FOR EACH loElem IN loCol.aElements
    				* Color:
    				IF VARTYPE( loElem.cFontColor) <> "C" AND VARTYPE( loCol.cFontColor) = "C"
    					loElem.cFontColor = loCol.cFontColor
    				ENDIF
    				* Font-style:
    				IF VARTYPE( loElem.cFontAttributes ) <> "C" AND VARTYPE( loCol.cFontAttributes ) = "C"
    					loElem.cFontAttributes = loCol.cFontAttributes
    				ENDIF
    				* Font-size:
    				IF VARTYPE( loElem.cFontSize ) <> "C" AND VARTYPE( loCol.cFontSize ) = "C"
    					loElem.cFontSize = loCol.cFontSize
    				ENDIF
    				* Font-face:
    				IF VARTYPE( loElem.cFontFace ) <> "C" AND VARTYPE( loCol.cFontFace ) = "C"
    					loElem.cFontFace = loCol.cFontFace
    				ENDIF
    				* CSS Classes
    				IF THIS.lUseCss
    					* Font Class:
    					IF VARTYPE( loElem.cFontClass ) <> "C" AND VARTYPE( loCol.cFontClass ) = "C"
    						loElem.cFontClass = loCol.cFontClass
    					ENDIF
    					* Font Style:
    					IF VARTYPE( loElem.cFontStyle ) <> "C" AND VARTYPE( loCol.cFontStyle ) = "C"
    						loElem.cFontStyle = loCol.cFontStyle
    					ENDIF
    					* NOTE: Cell Class property doesn't go to the element level.
    				ENDIF
    				* Prefix:
    				IF VARTYPE( loElem.cPrefix ) <> "C" AND VARTYPE( loCol.cPrefix ) = "C"
    					loElem.cPrefix = loCol.cPrefix
    				ENDIF
    				* Suffix:
    				IF VARTYPE( loElem.cSuffix ) <> "C" AND VARTYPE( loCol.cSuffix ) = "C"
    					loElem.cSuffix = loCol.cSuffix
    				ENDIF
    			ENDFOR
    		ENDIF

    		* Call column routine that builds tags once and uses on every record.
    		loCol.PreProcessTags()

    	ENDFOR
    ENDIF
    DODEFAULT()
    RETURN
  ENDFUNC  && ReconcileFormats
  * ---------------------------------------------------------- *
ENDDEFINE  && L7ComplexTable

*** ========================================================== ***
DEFINE CLASS L7Table AS L7AbstractHtmlTable
  lSimple = .T.
  cElementVfpClass   = "L7SimpleTableElement"
  * ---------------------------------------------------------- *
  FUNCTION AddColumn(lnType, lcField, lcHead, lcDisplayExpr, m.lcClass)
    * Retained for compatability. Just calls AddElement.
    LOCAL loObj
    loObj = THIS.AddElement( m.lnType, m.lcField, m.lcHead, m.lcDisplayExpr, m.lcClass )

    *!*	* [Reconsider this strategy later.]
    *!*	* Mirror the column and element arrays for simple tables:
    *!*	THIS.nColumns = THIS.nColumns + 1
    *!*	DIMENSION THIS.aColumns[ THIS.nColumns]
    *!*	THIS.aColumns[ THIS.nColumns] = m.loObj

    * Return an object reference to the column object:
    RETURN m.loObj
  ENDFUNC  && AddColumn
  * ---------------------------------------------------------- *
  FUNCTION ReconcileCalculationProperties
    LOCAL loElem
    IF THIS.nElements > 0
    	* For each calculated element, initialize arrays to hold
    	* group totals and counts:
    	FOR EACH loElem IN THIS.aElements
    		IF loElem.nCalcType > L7_CALCTYPE_NONE
    			IF THIS.nGroups > 0
    				DIMENSION loElem.aGroupTotal[ THIS.nGroups]
    				DIMENSION loElem.aGroupCount[ THIS.nGroups]
    			ENDIF
    			THIS.nCalcElementCount = THIS.nCalcElementCount + 1
    		ENDIF	
    	ENDFOR
    	IF THIS.nCalcElementCount > 0 
    		* And determine where to place any generic footer text:
    		IF THIS.nFooterTextColumn = 0
    			* Not specified by user, so figure out a reasonable default.
    			THIS.DetermineFooterTextColumns()
    		ENDIF
    	ENDIF
    ENDIF
    RETURN
  ENDFUNC  && ReconcileCalculationProperties
  * ---------------------------------------------------------- *
  FUNCTION ReconcileFormats
    LOCAL loElem
    * Process each column object:
    IF THIS.nElements > 0
    	FOR EACH loElem IN THIS.aElements
    		THIS.TransferTableDefaults( m.loElem )
    	ENDFOR
    ENDIF
    DODEFAULT()
    RETURN
  ENDFUNC  && ReconcileFormats
  * ---------------------------------------------------------- *
ENDDEFINE  && L7Table

*** ========================================================== ***
DEFINE CLASS L7TableGroup AS CUSTOM
  oTable = .F.

  lError = .F.
  cErrorMessage = ""

  cPrefix        = ""
  cExpression    = ""
  vValue         = NULL && current value of group expression
  cHeading       = ""
  nCounter       = 0    && running row count within group

  cDisplayExpression = ""
  lDisplayTextmerge  = .F.
  cDisplayValue      = ""

  lTotalRow   = .T.
  lHeaderRow  = .F.
  lFooterRow  = .F.

  lValueInFooter = .T.  
  cTotalText  = "Total:"

  lRepeatTableHeader = .F.

  cRowClass    = .F.
  cRowStyle    = .F.
  cValign      = "TOP"
  cRowBgColor  = .F.

  cHeaderRowClass   = .F.  && "GroupHeaderRow"
  cHeaderRowStyle   = .F.  && 
  
  cLabelClass = .F.
  cLabelStyle = .F.

  cCellBgColor = .F.

  cFontAttributes = .F.  && also support I and BI, "" = none, .F. = use base element
  cFontFace    = .F.
  cFontSize    = .F.
  cFontColor   = .F.
  cFontClass   = .F.
  cFontStyle   = .F.  && CSS

  * ---------------------------------------------------------- *
  FUNCTION DESTROY
    * Group::Destroy()
    THIS.RELEASE()
    #IF L7_TABLE_DEBUG = .T.
    DEBUGOUT THIS.Name + ' [' + THIS.Class + '] destroyed'
    #ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION RELEASE
    * Group::Release()
    THIS.oTable = .F.
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION INIT(loTable, lcExpr, lcHeading, lcDispExpr)
    * Group::Init()
    THIS.oTable = m.loTable
    IF NOT EMPTY( m.lcExpr)
    	THIS.cExpression = m.lcExpr
    ENDIF
    IF NOT EMPTY( NVL(m.lcDispExpr, ""))
      THIS.cDisplayExpression = m.lcDispExpr
      IF "<<" $ m.lcDispExpr AND ">>" $ m.lcDispExpr
        THIS.lDisplayTextmerge = .T.
      ENDIF 
    ENDIF
    IF VARTYPE( m.lcHeading) = "C"
    	THIS.cHeading = m.lcHeading
    ELSE
    	THIS.cHeading = THIS.cExpression
    ENDIF
    #IF L7_TABLE_DEBUG = .T.
    DEBUGOUT THIS.Name + ' [' + THIS.Class + '] initialized'
    #ENDIF
  ENDFUNC  && INIT
  * ---------------------------------------------------------- *
  #IF L7_TABLE_ERROR_HANDLING = .T.
    FUNCTION ERROR( lnErr, lcMthd, lnLine )
      THIS.lError = .T.
      THIS.cErrorMessage = MESSAGE()
      IF VARTYPE( THIS.oTable) = "O"
      	THIS.oTable.ERROR( m.lnErr, m.lcMthd, m.lnLine )
      ENDIF
    ENDFUNC  && ERROR
  #ENDIF
  * ---------------------------------------------------------- *
ENDDEFINE  && L7TableGroup

*** ========================================================== ***
DEFINE CLASS L7TableExtraRow AS CUSTOM
  oTable            = .F.

  lError            = .F.
  cErrorMessage     = ""

  nLocation         = 0   && sum of constants (BITAND is used in parent)
  cText             = ""  && was .F. ???
  cDynamicText      = .F.
  lFullRowText      = .F. && if .T., bypass renderer and return the text
  cFilterExpression = []

  * A few elements you can specify. Everything else must be in the
  * content you provide via cText or cDynamicText:
  cRowClass  = .F.
  cRowStyle  = .F.
  cBgColor   = .F.
  cValign    = .F.       && MIDDLE, TOP, BOTTOM, etc
  cCellClass = .F.
  cAlign     = .F.
  cCellStyle = .F.
  * ---------------------------------------------------------- *
  FUNCTION DESTROY
    * Group::Destroy()
    THIS.RELEASE()
    #IF L7_TABLE_DEBUG = .T.
      DEBUGOUT THIS.Name + ' [' + THIS.Class + '] destroyed'
    #ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION RELEASE
    * Group::Release()
    THIS.oTable = .F.
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION INIT(loTable, lnLocation)
    * Group::Init()
    THIS.oTable = m.loTable
    IF VARTYPE( m.lnLocation ) = "N"
    	THIS.nLocation = m.lnLocation
    ENDIF
    #IF L7_TABLE_DEBUG = .T.
      DEBUGOUT THIS.Name + ' [' + THIS.Class + '] initialized'
    #ENDIF
  ENDFUNC  && INIT
  * ---------------------------------------------------------- *
  #IF L7_TABLE_ERROR_HANDLING = .T.
    FUNCTION ERROR( lnErr, lcMthd, lnLine )
      THIS.lError = .T.
      THIS.cErrorMessage = MESSAGE()
      IF VARTYPE( THIS.oTable) = "O"
      	THIS.oTable.ERROR( m.lnErr, m.lcMthd, m.lnLine )
      ENDIF
    ENDFUNC  && ERROR
  #ENDIF
  * ---------------------------------------------------------- *
  FUNCTION GetOutput(pnLocation, pnGroup)
    * pnGroup is the group number and is only passed for
    * before/after group header/footer events. Although
    * not implemented below, could be accessed in a subclass.
    
    * Filter the row, if specified:
    IF NOT EMPTY( THIS.cFilterExpression)
      IF NOT EVALUATE( THIS.cFilterExpression)
        * Exclude the row entirely.
        RETURN ""
      ENDIF
    ENDIF
    
    LOCAL lcText
    IF THIS.lFullRowText
      IF VARTYPE(THIS.cDynamicText) = "C"
        lcText = EVALUATE(THIS.cDynamicText)
      ELSE
        lcText = THIS.cText
      ENDIF
    ELSE
      lcText = THIS.oTable.oRender.GetExtraRow( THIS, pnLocation, pnGroup)
    ENDIF
    
    RETURN m.lcText
  ENDFUNC  && GetOutput
  * ---------------------------------------------------------- *
  FUNCTION Write(lvItem)
    IF VARTYPE(m.lvItem) = "O"
      this.ctext = this.ctext + lvItem.Render()
    ELSE
      this.ctext = this.ctext + m.lvItem  && assume text
    ENDIF
    RETURN
  ENDFUNC 
  * ---------------------------------------------------------- *
ENDDEFINE  && L7TableExtraRow

*** ========================================================== ***
DEFINE CLASS L7TableColumn AS CUSTOM
  * This class used in complex tables only! In simple tables
  * columns and elements are all one object.
  oTable = NULL

  lError = .F.
  cErrorMessage = ""

  * Note that this is an array of object reference *copies*
  * only. The actual object creation and referencing is done
  * in the parent table object. This allows repeated use of 
  * elements in different columns.

  lActive = .T.

  DIMENSION aElements[1]
  nElements = 0
  nCalcElements = 0  && how many elements in *this* column are calc'd

  cHeading           = .F.  && text of heading -- calculated!
  cHeadingAlign      = .F.
  cHeadingBgColor    = .F.
  cHeadingTag        = .F.  && can change to TD if it suits your CSS design
  cHeadingClass      = .F.
  cHeadingStyle      = .F.
  cHeadingFontColor  = .F.
  cHeadingFontFace   = .F.
  cHeadingFontSize   = .F.  && leave at .F. to use table defaults
  cHeadingFontAttributes = .F.
  cHeadingFontClass  = .F.
  cHeadingFontStyle  = .F.

  cCellClass   = .F.
  cCellStyle   = .F.
  cBgColor     = .F.
  cWidth       = .F.  && If specified, used in heading cell (and <col> tag) only.

  * Pass-through properties. If set, these affect all elements
  * in the column:
  cAlign      = .F.    && leave at .F. to adapt alignment to field type
  cVAlign     = .F.    && leave .F. to use row's alignment
  cFontColor  = .F.
  cFontFace   = .F.
  cFontSize   = .F.    && leave at .F. to use table defaults
  cFontAttributes = .F.
  cFontClass  = .F.
  cFontStyle  = .F.

  nCalcType   = .F.
  nResetLevel = .F.

  cPrefix     = .F.
  cSuffix     = .F.
  cHeadingSuffix = .F.
  cNullDisplay   = .F.
  cEmptyDisplay  = .F.

  * Pre-evaluated items (for performance):
  cBeforeTags      = "[]"
  cAfterTags       = "[]"
  *!*    These are implemented as *expressions* not strings. That is,
  *!*    they are EVALUATE()'d for each record, thus supporting
  *!*    dynamic expressions in properties like class,style, and bgcolor.
  
  * ---------------------------------------------------------- *
  FUNCTION cHeading_ACCESS
    * Column::cHeading_access

    * "Called" by GetHeading().

    * Here's how column headings work: If you define a heading for
    * the column, it is used. If not, it iterates the *elements* of
    * the column and uses their headings.
    LOCAL lcText
    IF VARTYPE( THIS.cHeading) <> "C"
    	LOCAL ii
    	lcText = ""
    	FOR ii = 1 TO THIS.nElements
    		lcText = m.lcText + THIS.aElements[ m.ii].cHeading + ;
    			THIS.aElements[ m.ii].cHeadingSuffix
    	ENDFOR
    ELSE
    	lcText = THIS.cHeading
    ENDIF
    lcText = THIS.oTable.oRender.WrapColumnHeading(THIS, m.lcText)

    RETURN m.lcText
  ENDFUNC  && cHeading_ACCESS
  * ---------------------------------------------------------- *
  FUNCTION DESTROY
    * Column::DESTROY
    THIS.RELEASE()
    #IF L7_TABLE_DEBUG = .T.
    DEBUGOUT THIS.Name + ' [' + THIS.Class + '] destroyed'
    #ENDIF
  ENDFUNC  && DESTROY
  * ---------------------------------------------------------- *
  FUNCTION RELEASE
    * Column::RELEASE
    * Kill off entire array.
    THIS.aElements = .F.
    THIS.nElements = 0
    THIS.oTable = .F.
  ENDFUNC  && RELEASE
  * ---------------------------------------------------------- *
  FUNCTION INIT(loTable, lnType, lcField, lcHead, lcDisplayExpr)
    * Column::INIT
    * Optional parameter to create 1-field column in simple call.
    THIS.oTable = m.loTable
    IF VARTYPE( m.lnType) = "N" OR NOT EMPTY( m.lnType)
    	THIS.AddElement( m.lnType, m.lcField, m.lcHead, m.lcDisplayExpr )
    ENDIF
    #IF L7_TABLE_DEBUG = .T.
      DEBUGOUT THIS.Name + ' [' + THIS.Class + '] initialized'
    #ENDIF
  ENDFUNC && INIT
  * ---------------------------------------------------------- *
  #IF L7_TABLE_ERROR_HANDLING = .T.
    FUNCTION ERROR( lnErr, lcMthd, lnLine )
      THIS.lError = .T.
      THIS.cErrorMessage = MESSAGE()
      IF VARTYPE( THIS.oTable) = "O"
      	THIS.oTable.ERROR( m.lnErr, m.lcMthd, m.lnLine )
      ENDIF
    ENDFUNC  && ERROR
  #ENDIF
  * ---------------------------------------------------------- *
  FUNCTION AddElement(lnType, lvItem, lcHead, lcDisplayExpr)
    * Column::AddElement
    
    * Adds an element to a column's collection. Element can
    * be either a field name/expression, or an object reference
    * to an existing element object. The latter allows items to
    * be repeated in 2 separate columns of the table without 
    * creating them twice.

    THIS.nElements = THIS.nElements + 1
    DIMENSION THIS.aElements[ THIS.nElements]
    IF VARTYPE( m.lnType) = "O"  && pre-established element object
    	* Ask the parent object to add the element:
    	THIS.aElements[ THIS.nElements] = m.lnType
    ELSE  && field name, typically
    	THIS.aElements[ THIS.nElements] = ;
    		THIS.oTable.AddElement( m.lnType, m.lvItem, m.lcHead, m.lcDisplayExpr )
    ENDIF
    * Pass back an object reference:
    RETURN THIS.aElements[ THIS.nElements]
  ENDFUNC  && AddElement
  * ---------------------------------------------------------- *
  FUNCTION Process
    * Column::Process
    * Process the column by processing each element in the column.
    LOCAL lcText, m.ii, lvVal, loElem, lcElemText
    lcText = ""
    lcText = m.lcText + EVAL( THIS.cBeforeTags )
    IF THIS.nElements > 0
    	FOR EACH loElem IN THIS.aElements
    		IF loElem.nDisplayType = 0
    			LOOP
    		ENDIF
    		lcElemText = loElem.Process()
    		IF VARTYPE( m.lcElemText ) <> "C"
    			lcElemText = TRANSFORM( m.lcElemText )
    		ENDIF
    		lcText = m.lcText + m.lcElemText 
    	ENDFOR
    ENDIF
    lcText = m.lcText + EVAL( THIS.cAfterTags )
    RETURN m.lcText
  ENDFUNC  && Process
  * ---------------------------------------------------------- *
  FUNCTION PreProcessTags

    THIS.oTable.oRender.PreProcessCellTags( THIS)
  ENDFUNC  && PreProcessTags
  * ---------------------------------------------------------- *
ENDDEFINE  && L7TableColumn

*** ========================================================== ***
DEFINE CLASS L7SimpleTableElement AS L7TableElement
  * Add properties that are defined at the *column* level in
  * complex tables. (With simple tables, there is no column object
  * that contains the element object.)

  lActive   = .T.

  cCellClass         = .F.
  cCellStyle         = .F.
  cWidth             = .F.

  cHeadingClass      = .F.
  cHeadingStyle      = .F.
  cHeadingAlign      = .F. 
  cHeadingBgColor    = .F.
  cHeadingTag        = .F.  && can change to TD if it suits your CSS design
  cHeadingFontColor  = .F.
  cHeadingFontFace   = .F.
  cHeadingFontSize   = .F.  && leave at .F. to use table defaults
  cHeadingFontAttributes = .F.
  cHeadingFontClass  = .F.
  cHeadingFontStyle  = .F.

  nCalcElements    = 0  && see ACCESS method

  * ---------------------------------------------------------- *
  FUNCTION nCalcElements_ACCESS
    RETURN IIF( THIS.nCalcType > L7_CALCTYPE_NONE, 1, 0)
  ENDFUNC  && nCalcElements_ACCESS
  * ---------------------------------------------------------- *
  FUNCTION lActive_ACCESS
    RETURN NOT THIS.lDisabled
  ENDFUNC  && lActive_ACCESS
  * ---------------------------------------------------------- *
  FUNCTION PreProcessTags
    * This deals with the data element itself:
    DODEFAULT()
    * Prefix/suffix are not logical to have in simple table:
    THIS.cPrefix = ""
    THIS.cSuffix = ""

    THIS.oTable.oRender.PreProcessCellTags( THIS)
  ENDFUNC  && PreProcessTags
  * ---------------------------------------------------------- *
ENDDEFINE  && L7SimpleTableElement 

*** ========================================================== ***
DEFINE CLASS L7TableElement AS LINE
  lError = .F.
  cErrorMessage = ""

  nType = 1
  * 0 : Fixed Text
  * 1 : Expression (often a field name)
  * 2 : Fixed Hyperlink
  * 3 : Dynamic Hyperlink (URL and text can vary)
  * Special:
  * -1 : Relative record number.
  * -2 : Absolute record number.
  * -3 : Record count.

  cDataType          = "U"
  cExpression        = ""
  cHeading           = ""
  cHeadingExpression = .F.
  cDisplayExpression = .F.  && optional, 
  lDisplayTextmerge  = .F.  && if .T., use TEXTMERGE() with cDisplayExpression
  cTransform         = .F.  && optional, 2nd parm to TRANSFORM()
  cFormatString      = .F.  && optional transformation using %1 as value, e.g.: "CMONTH(%1)"
  lNoBR              = .F.  && option to force <nobr> wrapping
  cComment           = ""   && can be expression or string

  lSupressRepeats    = .F.
*!*    PROTECTED vOldValue
  vOldValue          = NULL
  vNewValue          = NULL

  * Alternative string when field evaluates to NULL:
  cNullDisplay       = .F.  && .F. to employ table defaults
  * Insert a non-breaking space when the field is empty:
  cEmptyDisplay      = CHR(38) + "nbsp" + CHR(59)  

  * Properties used in hyperlink element types:
  cLinkText          = ""   && If blank, defaults to cExpression.
  cDynamicLinkText   = ""
  cLinkAttributes    = ""   && e.g., "TARGET=_NEW"

  nMemoTranslation = 2    && 0 = never, 1 = content-dependent, 2 = always 

  nDisplayType  = 1  && 0 = disabled, 1 = normal, 2 = running sub-total

  * Calculated field type: 
  nCalcType = L7_CALCTYPE_NONE
  *!*	#DEFINE L7_CALCTYPE_NONE  1
  *!*	#DEFINE L7_CALCTYPE_COUNT 2
  *!*	#DEFINE L7_CALCTYPE_SUM   3
  *!*	#DEFINE L7_CALCTYPE_AVG   4
  *!*	#DEFINE L7_CALCTYPE_MIN   5
  *!*	#DEFINE L7_CALCTYPE_MAX   6
  *!*	#DEFINE L7_CALCTYPE_STDDV 7
  *!*	#DEFINE L7_CALCTYPE_VAR   8

  nResetLevel = 0  && reset at end-of-report
  * To reset at a group boundary, set to 2 + Group # (ie, 3 for Group 1)

  DIMENSION aGroupTotal[ 1]
  DIMENSION aGroupCount[ 1]
  * Group count and running total arrays.
  * One row for each group.

  nGrandTotal      = NULL && report grand total
  nGrandCount      = 0    && report total count
  cGrandExpression = ""   && EXPERIMENTAL!

  lVisible  = .T.  && calc'd but not displayed
  lDisabled = .F.  && ignored entirely

  oTable           = NULL
  cPrefix          = .F.
  cSuffix          = .F.
  cHeadingSuffix   = ""

  cAlign      = .F.    && leave at .F. to adapt alignment to field type
  cVAlign     = .F.    && really a column property
  cBgColor    = .F.    && not implemented yet--use column property

  cFontColor  = .F.
  cFontFace   = .F.
  cFontSize   = .F.    && leave at .F. to use table defaults
  cFontAttributes = .F.
  cFontClass  = .F.
  cFontStyle  = .F.

  * Pre-evaluated items:
  cBeforeTags      = "[]"
  cAfterTags       = "[]"

  * ---------------------------------------------------------- *
  FUNCTION cDataType_ASSIGN( lcType)
    * Assign method that adjusts alignment based on data type.
    THIS.cDataType = m.lcType
    IF VARTYPE( THIS.cAlign) <> "C"  && alignment not specified
    	DO CASE
    	CASE m.lcType $ "NIBY"
        IF THIS.oTable.lSimple
          THIS.cCellStyle = EVL(THIS.cCellStyle, "text-align: right;")
        ELSE 
          THIS.cAlign = "right"
        ENDIF
    	CASE m.lcType $ "LDT"
        IF THIS.oTable.lSimple
          THIS.cCellStyle = EVL(THIS.cCellStyle, "text-align: center;")
        ELSE 
          THIS.cAlign = "center"
        ENDIF
    	OTHERWISE
    		* default to nothing -- LEFT
    	ENDCASE
    ENDIF
    RETURN 
  ENDFUNC  && cDataType_ASSIGN
  * ---------------------------------------------------------- *
  FUNCTION cHeading_ACCESS
    * Element::cHeading_access
    LOCAL lcText
    IF NOT EMPTY( THIS.cHeadingExpression) 
    	lcText = TRANSFORM( EVAL( THIS.cHeadingExpression ) )
    ELSE
    	lcText = THIS.cHeading
    ENDIF
    lcText = THIS.oTable.oRender.WrapColumnHeading(THIS, m.lcText)

    RETURN m.lcText
  ENDFUNC  && cHeading_ACCESS
  * ---------------------------------------------------------- *
  FUNCTION INIT(loTable, lnType, lcExpr, lcHead, lcDisplayExpr)
    * Element::INIT
    THIS.oTable = m.loTable
    IF VARTYPE( m.lnType) <> "N"
    	* We didn't pass in a type, assume short-hand of
    	* field name only!
    	THIS.nType = L7_ELEMENTTYPE_FIELD
    	THIS.cExpression = m.lnType
    ELSE
    	THIS.nType = m.lnType
    	THIS.cExpression = m.lcExpr
    ENDIF
    * Set Heading:
    IF VARTYPE( m.lcHead) = "C"  && an explicit heading was passed in
    	THIS.cHeading = m.lcHead
    ELSE
    	DO CASE
    	CASE INLIST( THIS.nType, L7_ELEMENTTYPE_FIELD)
    		* Typical field. Strip out _ and convert to 
    		* proper case as a default look:
    		THIS.cHeading = PROPER( ALLTRIM( CHRTRAN( TRANS( THIS.cExpression), ;
    			"_()", "   ")))
    	CASE INLIST( THIS.nType, L7_ELEMENTTYPE_RELATIVE_RECNO, L7_ELEMENTTYPE_ABSOLUTE_RECNO )
    		THIS.cHeading = "No."
    	OTHERWISE
    		THIS.cHeading = ""
    	ENDCASE
    ENDIF
    * Set Data Type:
    DO CASE
    CASE INLIST( THIS.nType, L7_ELEMENTTYPE_FIXED_TEXT, ;
    	L7_ELEMENTTYPE_STATIC_HYPERLINK, L7_ELEMENTTYPE_DYNAMIC_HYPERLINK )
    	*
    	THIS.cDataType = "C"
    CASE THIS.nType < 0 && any Record Counter type
    	THIS.cDataType = "N"
    ENDCASE
    * Handle alt Display Expression, if any:
    IF VARTYPE( m.lcDisplayExpr) = "C"
    	IF INLIST( THIS.nType, L7_ELEMENTTYPE_DYNAMIC_HYPERLINK )
    		THIS.cDynamicLinkText = m.lcDisplayExpr
    	ELSE
    		THIS.cDisplayExpression = m.lcDisplayExpr
    	ENDIF
    ENDIF
    #IF L7_TABLE_DEBUG = .T.
      DEBUGOUT THIS.Name + ' [' + THIS.Class + '] initialized'
    #ENDIF
  ENDFUNC  && INIT
  * ---------------------------------------------------------- *
  FUNCTION DESTROY
    * Element::Destroy
    THIS.RELEASE()
    #IF L7_TABLE_DEBUG = .T.
      DEBUGOUT THIS.Name + ' [' + THIS.Class + '] destroyed'
    #ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION RELEASE
    * Element::Release
    THIS.oTable = .F.
  ENDFUNC
  * ---------------------------------------------------------- *
  #IF L7_TABLE_ERROR_HANDLING = .T.
    FUNCTION ERROR( lnErr, lcMthd, lnLine )
      THIS.lError = .T.
      THIS.cErrorMessage = MESSAGE()
      IF VARTYPE( THIS.oTable) = "O"
      	THIS.oTable.ERROR( m.lnErr, m.lcMthd, m.lnLine )
      ENDIF
    ENDFUNC  && ERROR
  #ENDIF
  * ---------------------------------------------------------- *
  function Reset()
    with this
      .nGrandTotal      = NULL && report grand total
      .nGrandCount      = 0    && report total count

      .aGroupTotal = NULL
      .aGroupCount = 0
    endwith
    return 
  endfunc 
  * ---------------------------------------------------------- *
  FUNCTION Process
    * Element::Process

    LOCAL lcExpression, lcRet, loExc, lcTmp
    WITH THIS
      lcExpression = .cExpression  && for debugging (gets added to error message)
      * First, determine this element's current value:
      DO CASE
      CASE .nType = L7_ELEMENTTYPE_FIXED_TEXT  && 0 - fixed text
        .vNewValue = .cExpression
      CASE .nType = L7_ELEMENTTYPE_FIELD  && 1 - field/expression
        .vNewValue = EVAL( .cExpression )
      CASE .nType = L7_ELEMENTTYPE_STATIC_HYPERLINK  && 2 - fixed hyperlink
        .vNewValue = .cExpression
      CASE .nType = L7_ELEMENTTYPE_DYNAMIC_HYPERLINK  && 3 - dynamic hyperlink
        .vNewValue = EVAL( .cExpression )
      CASE .nType = L7_ELEMENTTYPE_RELATIVE_RECNO  && -1
        .vNewValue = TRANS( .oTable.nGroupRowCount ) + "."
      CASE .nType = L7_ELEMENTTYPE_ABSOLUTE_RECNO  && -2
        .vNewValue = TRANS( .oTable.nRowCount ) + "."
      CASE .nType = L7_ELEMENTTYPE_RECCOUNT  && -3
        .vNewValue = TRANS( .oTable.nRecCount ) + "."
      ENDCASE

      * Update calculated totals and counts:
      IF .nCalcType > L7_CALCTYPE_NONE
        FOR ii = 1 TO .oTable.nGroups
          .aGroupTotal[ m.ii] = ;
            .UpdateRunningTotal( .nCalcType, .vNewValue, .aGroupTotal[ m.ii])
          IF NOT ISNULL( .vNewValue)
            .aGroupCount[ m.ii] = .aGroupCount[ m.ii] + 1
          ENDIF
        ENDFOR
        .nGrandTotal = ;
            .UpdateRunningTotal( .nCalcType, .vNewValue, .nGrandTotal)
        IF NOT ISNULL( .vNewValue)
          .nGrandCount = .nGrandCount + 1
        ENDIF
      ENDIF
    ENDWITH
    
    * Attach any prefix or suffix:
    TRY
      lcRet = THIS.cPrefix + EVAL( THIS.cBeforeTags ) 
      lcTmp = THIS.oTable.oRender.GetElement( THIS)
      IF VARTYPE(m.lcTmp) <> "C"
        lcTmp = TRANSFORM(m.lcTmp)
      ENDIF
      lcRet = m.lcRet + m.lcTmp
      lcRet = m.lcRet + EVAL(THIS.cAfterTags) + THIS.cSuffix

    CATCH TO loExc
      lcRet = THIS.cPrefix + EVAL( THIS.cBeforeTags ) + ;
        "ERR: " + L7ExceptionMessage(m.loExc) + ;
      EVAL( THIS.cAfterTags ) + THIS.cSuffix
    ENDTRY
      
    RETURN m.lcRet
    
    
*!*      RETURN THIS.cPrefix + EVAL( THIS.cBeforeTags ) + ;
*!*        THIS.oTable.oRender.GetElement( THIS) + ;
*!*        EVAL( THIS.cAfterTags ) + THIS.cSuffix

  ENDFUNC  && Process
  * ---------------------------------------------------------- *
  FUNCTION PreProcessTags
    THIS.oTable.oRender.PreProcessElementTags( THIS)
  ENDFUNC  && PreProcessTags
  * ---------------------------------------------------------- *
  FUNCTION UpdateRunningTotal(tnType, txNew, txOld)
    DO CASE
    CASE ISNULL( m.txNew)
    	RETURN m.txOld
    CASE m.tnType = L7_CALCTYPE_COUNT
    	RETURN IIF( EMPTY( m.txNew), m.txOld, IIF( ISNULL( m.txOld), 1, 1 + m.txOld))
    CASE INLIST( m.tnType, L7_CALCTYPE_SUM, L7_CALCTYPE_AVG)
    	RETURN IIF( ISNULL( m.txOld), m.txNew, m.txNew + m.txOld)
    CASE m.tnType = L7_CALCTYPE_MAX
    	RETURN IIF( ISNULL( m.txOld), m.txNew, MAX( m.txNew, m.txOld))
    CASE m.tnType = L7_CALCTYPE_MIN
    	RETURN IIF( ISNULL( m.txOld), m.txNew, MIN( m.txNew, m.txOld))
    OTHERWISE
    	RETURN NULL
    ENDCASE
  ENDFUNC  && UpdateRunningTotal
  * ---------------------------------------------------------- *
  FUNCTION GetGrandTotal
    LOCAL lvVal, llCount
    llCount = THIS.nCalcType = L7_CALCTYPE_COUNT
    IF EMPTY(THIS.cGrandExpression)
      IF m.llCount
        lvVal = NVL(THIS.nGrandTotal, 0)
      ELSE
        lvVal = THIS.nGrandTotal
        IF THIS.nCalcType = L7_CALCTYPE_AVG 
          IF VARTYPE( m.lvVal) $ "NIYBD" AND THIS.nGrandCount > 0
            lvVal = m.lvVal / THIS.nGrandCount
          ENDIF
        ENDIF
      ENDIF
    ELSE
      lvVal = EVALUATE(THIS.cGrandExpression)
    ENDIF
    RETURN m.lvVal
  ENDFUNC  && GetGrandTotal
  * ---------------------------------------------------------- *

ENDDEFINE  && L7TableElement


* From L7.H. Repeated for convenience:

*!*	#DEFINE L7_ELEMENTTYPE_RECCOUNT         -3
*!*	#DEFINE L7_ELEMENTTYPE_ABSOLUTE_RECNO   -2
*!*	#DEFINE L7_ELEMENTTYPE_RELATIVE_RECNO   -1
*!*	#DEFINE L7_ELEMENTTYPE_FIXED_TEXT        0
*!*	#DEFINE L7_ELEMENTTYPE_FIELD             1
*!*	#DEFINE L7_ELEMENTTYPE_STATIC_HYPERLINK  2
*!*	#DEFINE L7_ELEMENTTYPE_DYNAMIC_HYPERLINK 3

*!*	** Calculation Types:
*!*	#DEFINE L7_CALCTYPE_NONE  1
*!*	#DEFINE L7_CALCTYPE_COUNT 2
*!*	#DEFINE L7_CALCTYPE_SUM   3
*!*	#DEFINE L7_CALCTYPE_AVG   4
*!*	#DEFINE L7_CALCTYPE_MIN   5
*!*	#DEFINE L7_CALCTYPE_MAX   6
*!*	#DEFINE L7_CALCTYPE_STDDV 7
*!*	#DEFINE L7_CALCTYPE_VAR   8

*!*	** Which columns to display:
*!*	#DEFINE L7_DISPLAYTYPE_NONE   0 && show nothing
*!*	#DEFINE L7_DISPLAYTYPE_BASE   1 && show the field value (DEFAULT)
*!*	#DEFINE L7_DISPLAYTYPE_CALC   2 && show the running calculation

*!*	** Group Offset constant:
*!*	#DEFINE L7_GROUP_OFFSET   2 && Add this to the group number for ResetLevels

*!*	#DEFINE L7_TABLEROWLOCATION_BEFORE_TITLE         0x0001
*!*	#DEFINE L7_TABLEROWLOCATION_AFTER_TITLE          0x0002
*!*	#DEFINE L7_TABLEROWLOCATION_AFTER_HEADING        0x0004
*!*	#DEFINE L7_TABLEROWLOCATION_BEFORE_FIRST_RECORD  0x0008
*!*	#DEFINE L7_TABLEROWLOCATION_AFTER_EACH_RECORD    0x0010
*!*	#DEFINE L7_TABLEROWLOCATION_ON_ZERO_RECORDS      0x0020
*!*	#DEFINE L7_TABLEROWLOCATION_AFTER_LAST_RECORD    0x0040
*!*	#DEFINE L7_TABLEROWLOCATION_BEFORE_GROUP_HEADER  0x0080
*!*	#DEFINE L7_TABLEROWLOCATION_AFTER_GROUP_HEADER   0x0100
*!*	#DEFINE L7_TABLEROWLOCATION_BEFORE_GROUP_FOOTER  0x0200
*!*	#DEFINE L7_TABLEROWLOCATION_AFTER_GROUP_FOOTER   0x0400
*!*	#DEFINE L7_TABLEROWLOCATION_BEFORE_GRAND_TOTALS  0x0800
*!*	#DEFINE L7_TABLEROWLOCATION_AFTER_GRAND_TOTALS   0x1000
*!*	#DEFINE L7_TABLEROWLOCATION_AFTER_EVERYTHING     0x2000

#if .f.
04/15/2003 - added preRender(), cResult, and lRendered; adjusted Render() to utilize
10/19/2003 - added filter support
           - added reset() support
03/10/2005 - fixed bug where LOCAL loElem was needed in 3 places
12/21/2005 - added optional suppression of total footers when only 1 record in table
           - fixed ProcessCursor so row counts stay at 0 for no-record condition

#endif
