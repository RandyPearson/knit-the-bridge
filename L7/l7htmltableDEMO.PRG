#INCLUDE L7.H

* L7HtmlTableDemo.PRG
*
* Demos the power and simplicity of the L7HtmlTable classes.
* Requires tastrade be available.

* To call: DO L7HtmlTableDemo WITH <n>  && pass a demo number
*

LPARAMETERS lnDemo, llSimple
lnDemo = IIF( EMPTY( m.lnDemo), 1, m.lnDemo )
LOCAL lcTableClass
lcTableClass = IIF( m.llSimple, "L7Table", "L7ComplexTable")
PRIVATE pnStart, pnSql
pnStart = SECONDS()
pnSql = 0

PRIVATE loTable
LOCAL lcPath, loElem, loCol
lcPath = "D:\PROGRAM FILES\MICROSOFT VISUAL STUDIO\MSDN\99APR\1033\SAMPLES\VFP98\TASTRADE\DATA\"
OPEN DATA ( m.lcPath + "TASTRADE.DBC" )

* Level 7 Procedures/Classes:
SET PROCEDURE TO L7HtmlTable  ADDITIVE
SET PROCEDURE TO L7Utils      ADDITIVE
SET PROCEDURE TO L7TextStream ADDITIVE
SET PROCEDURE TO L7Api        ADDITIVE
* Web Connection Procedures/Classes:
SET PROCEDURE TO wwUtils      ADDITIVE

SET TALK OFF
SET CONSOLE OFF

DO CASE
CASE m.lnDemo = 1  && Basic call to wrapper program.
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		INTO CURSOR TQuery_
	? L7HtmlTable( .F., "Quick Customer Query" )

	* This is a useless example other than to see an HTML table quickly. Let's get
	* into controlling the object model directly, starting with the Table object.

CASE m.lnDemo = 2  && Almost the same, but you are in the driver seat.
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )
	loTable.cTitle = "Basic Example"
	loTable.SetupFromCursor()  && RAD technique that quickly creates a column for each table

	loTable.ProcessCursor()    && you *always* call this once everything is setup
	= ShowDemoResult( loTable )
	
CASE m.lnDemo = 3  && Reduce number of records *displayed* to top 25.
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )
	loTable.SetupFromCursor()  
	loTable.nEndRow = 25  && <<== Cutoff after nn rows (not the same as paging).

	WITH loTable
		.cTitle = "Cut-off After 25 Records"
		.cTitleBgColor = "brown"
		.cTitleFontColor = "yellow"
		.cTableBgColor = "#CCCCCC"
	ENDWITH
	
	loTable.ProcessCursor()    
	= ShowDemoResult( loTable )

CASE m.lnDemo = 4  && Apply "data grouping".
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		WHERE Country IN ( "Mexico", "Canada", "Germany", "UK" ) ;
		ORDER BY Country ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )
	WITH loTable
		.cTitle = "Add a Grouping Level: Group by Country"
		.cTitleBgColor = "brown"
		.cTitleFontColor = "yellow"
		.cTableBgColor = "#CCCCCC"

		** Option: .lColumnHeadingRow = .F.  && turn off column headings
		.lSumNumerics = .T.
		.AddGroup( "Country" )  && <<== That's all there is to it!!
		
		* Examples ability to insert an extra row with anything you want:
		LOCAL loExtraRow
		loExtraRow = .AddExtraRow( ;
			L7_TABLEROWLOCATION_AFTER_TITLE + ;
			L7_TABLEROWLOCATION_AFTER_LAST_RECORD + ;
			L7_TABLEROWLOCATION_AFTER_EVERYTHING )
		loExtraRow.cDynamicText = ["<b>Hello, I'm a multiply-placed extra row. This instance is at location: " + TRANS( m.pnLocation )]
		
		LOCAL loExtraRow
		loExtraRow = .AddExtraRow( ;
			L7_TABLEROWLOCATION_BEFORE_GROUP_HEADER )
		loExtraRow.cText = [<b><FONT COLOR="RED">New Group Starts Here:</FONT></B>]
		loExtraRow.cAlign = "LEFT"  && default is center

		.SetupFromCursor()  
		loElem = .GetElement( "Max_Order_Amt")
		loElem.nCalcType = L7_CALCTYPE_SUM
		
		**loTable.aElements[ loTable.nElements].nCalcType = L7_CALCTYPE_SUM
		.cGrandTotalText = "Report Totals:"
		.nFooterTextColumn = 5  && also try -1
		.nFooterTextColspan = 2
	
		.ProcessCursor()    
	ENDWITH
	= ShowDemoResult( loTable )

CASE m.lnDemo = 5  && Now lets start setting up the columns individually for more control.
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		WHERE Country IN ( "Mexico", "Canada", "Germany", "UK" ) ;
		ORDER BY Country ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )

	WITH loTable
		.cTitle = "Data Grouping Example"
		.cTitleBgColor = "brown"
		.cTitleFontColor = "yellow"
		.cTableBgColor = "#CCCCCC"
	ENDWITH

	loTable.lSumNumerics = .F.
	loTable.AddGroup( "Country" )  
	* Add a special first column that gives you a "row counter":
	loTable.AddColumn( L7_ELEMENTTYPE_RELATIVE_RECNO )  && record counter column
	
	loCol = loTable.AddCursorColumn( "Company_Name" )  && Add a column individually.

	loCol = loTable.AddCursorColumn( "Contact_Name" )
	loCol.cFontColor = "darkgreen"  && Apply some style to it.
	
	loCol = loTable.AddCursorColumn( "Phone" )
	loCol = loTable.AddCursorColumn( "City" )
	loCol = loTable.AddCursorColumn( "Country" )
	loCol = loTable.AddCursorColumn( "Max_Order_Amt" )

	loCol.nCalcType = L7_CALCTYPE_SUM  && Show country average (It never made sense to sum this!)

	loTable.ProcessCursor()    
	= ShowDemoResult( loTable )

CASE m.lnDemo = 6  && Add some more styles and add a running total column.
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		WHERE Country IN ( "Mexico", "Canada", "Germany", "UK" ) ;
		ORDER BY Country ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )

	WITH loTable
		.cTitle = "Addition of Styles and a Running Total Column"
		.cTitleBgColor = "brown"
		.cTitleFontColor = "yellow"
		.cTableBgColor = "#CCCCCC"
	ENDWITH


	loTable.lSumNumerics = .F.
	loTable.AddGroup( "Country" )  
	loCol = loTable.AddCursorColumn( "Company_Name" )  
	loCol = loTable.AddCursorColumn( "Contact_Name" )
	loCol.cFontColor = "darkgreen"  
	loCol = loTable.AddCursorColumn( "Phone" )
	loCol = loTable.AddCursorColumn( "City" )

	loCol = loTable.AddCursorColumn( "Country" )
	WITH loCol
		.cHeadingBgColor = "black"  && [03/14/2000]
		.cHeadingFontColor = "yellow"
		
		.cBgColor = [IIF(Country="Mexico","red","blue")] && a paren in a property triggers runtime EVAL
		.cFontColor = "white"
		.cFontAttributes = "B"
		.cAlign = "CENTER"
	ENDWITH
	
	loCol = loTable.AddCursorColumn( "Max_Order_Amt" )
	loCol.nCalcType = L7_CALCTYPE_AVG

	* WARNING: The next column demos a very advanced feature -- the ability to 
	*   change a column with a calculation to display the running (cummulative) total, instead
	*   of the current record's value. Don't worry if this isn't completely obvious:
	*
	loCol = loTable.AddCursorColumn( "Max_Order_Amt" )    && add another column for same field!
	IF loTable.lSimple
		loElem = loCol
	ELSE
		loElem = loCol.aElements[1]
	ENDIF
	WITH loElem
		.cHeading = "Country<BR>Max Order"
		.nCalcType = L7_CALCTYPE_SUM        && change its calc type
		.nDisplayType = L7_DISPLAYTYPE_CALC && running total
		
		* Now try one or the other of the following 2 lines:
		*.nResetLevel = L7_GROUP_OFFSET + 1  && reset when group 1 changes
		.nResetLevel = 0                    && show running total for entire report
	ENDWITH

	loTable.cGrandTotalText = "Report Average:"
	loTable.nFooterTextColumn = 5  && Also try -1
	loTable.nFooterTextColspan = 2
	
	loTable.ProcessCursor()    
	= ShowDemoResult( loTable )

CASE m.lnDemo = 7  && Alternating row BG color.
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		WHERE Country IN ( "Mexico", "Canada", "Germany", "UK" ) ;
		ORDER BY Country ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )

	WITH loTable
		.cTitle = "How To Alternate a Row Background Color"
		.cTitleBgColor = "brown"
		.cTitleFontColor = "yellow"
		.cTableBgColor = "#CCCCCC"
	ENDWITH

	loTable.lSumNumerics = .F.
	loTable.cTableBgColor = "#CCCCCC"
	loTable.cDataRowBgColor = "lightgreen"
	loTable.cDataRowBgColor = [IIF(THIS.nGroupRowCount%2=1,"#FFFFFF","lightgreen")] 
	loTable.AddGroup( "Country" )  

	loTable.AddColumn( L7_ELEMENTTYPE_RELATIVE_RECNO )
	loCol = loTable.AddCursorColumn( "Company_Name" )  
*	loCol.cFontColor = [IIF(THIS.oTable.nGroupRowCount%2=1,"blue","red")]   
	
	loCol = loTable.AddCursorColumn( "Contact_Name" )
	loCol.cFontColor = "darkgreen"  
*	loCol.cFontAttributes = [IIF(Country="Mexico","I","B")]

	loCol = loTable.AddCursorColumn( "Phone" )
	loCol = loTable.AddCursorColumn( "City" )
	loCol.cFontAttributes = "B"
	
	loCol = loTable.AddCursorColumn( "Country" )
	WITH loCol
		.cBgColor = [IIF(Country="Mexico","red","blue")] 
		.cFontColor = "white"
		.cFontAttributes = "B"
		.cAlign = "CENTER"
	ENDWITH
	
	loCol = loTable.AddCursorColumn( "Max_Order_Amt" )
	loCol.nCalcType = L7_CALCTYPE_MAX
	** loCol.nCalcType = L7_CALCTYPE_AVG

	loTable.ProcessCursor()    
	= ShowDemoResult( loTable )

CASE m.lnDemo = 8  && Handling zero records in query.
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		WHERE .F. ;
		ORDER BY Country ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )

	WITH loTable
		.cTitle = "Handling the Case Where No Records are Returned"
		.cTitleBgColor = "brown"
		.cTitleFontColor = "yellow"
		.cTableBgColor = "#CCCCCC"
	ENDWITH

	** loTable.cZeroRecordString = "You lose, dummy!"  && override polite message with your own
	loTable.ProcessCursor()    
	= ShowDemoResult( loTable )
	
CASE m.lnDemo = 9  && Adding dynamic hyperlink columns.

	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		WHERE Country IN ( "Mexico", "Canada", "Germany", "UK" ) ;
		ORDER BY Country ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )

	loTable.AddColumn( L7_ELEMENTTYPE_RELATIVE_RECNO )
	
	WITH loTable
		.cTitle = "Adding a Dynamic Hyperlink"
		.cTitleBgColor = "brown"
		.cTitleFontColor = "yellow"
		.cTableBgColor = "#CCCCCC"
	ENDWITH

	loCol = loTable.AddCursorColumn( "Company_Name" )  
	loCol = loTable.AddCursorColumn( "Contact_Name" )
	loCol = loTable.AddCursorColumn( "Phone" )
	loCol.cFontSize = [IIF(Country="Mexico","+1","")]
	loCol.cFontColor = [IIF(Country="Mexico","red","brown")]
	loCol = loTable.AddCursorColumn( "City" )
	loCol.cFontFace = "Arial"
	loCol = loTable.AddCursorColumn( "Country" )

	* Now, add a hyperlink to a hypothetical follow-up page:
	loCol = loTable.AddColumn( L7_ELEMENTTYPE_DYNAMIC_HYPERLINK, ;
		['/wconnect/wc.dll?cust~details~' + Customer_ID], ;
		[Link to Customer] )
	IF loTable.lSimple
		loCol.cLinkText = '[Details...]'
	ELSE
		loCol.aElements[1].cLinkText = '[Details...]'
	ENDIF
	loTable.ProcessCursor()    
	= ShowDemoResult( loTable )

CASE m.lnDemo = 10  && Paging demo.

	SELECT Customer_ID, Company_Name, Contact_Name, Phone, City, Country, Max_Order_Amt ;
		FROM Customer ;
		ORDER BY Country ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )
	WITH loTable
		.cTitle = "Paging Demonstration: Page 2 with 20 Records/Page"
		.cTitleBgColor = "brown"
		.cTitleFontColor = "yellow"
		
		.cTableBgColor = "#CCCCCC"
	
		loCol = .AddColumn( L7_ELEMENTTYPE_RELATIVE_RECNO )
		loCol.cFontAttributes = "B"
		loCol.cFontColor = "brown"
	
		.SetupFromCursor()  && no special column fomatting in this example

		* Set some paging proeprties
		.nPage_ItemsPerPage   = 20    && set this to # of items to show on a page
		.cPage_PageURL        = "/wconnect/wc.dll?cust~custlist"
		.nPage_ShowPage       = 2    && set this to the current page number (DEFAULT=1)
	
		* Some other settings you could alter:
		** loTable.cPage_PageVarName    = "pg" && leave blank to simply append ~nn to the URL
		** loTable.nPage_AutoGeneration = 2    && 0 = none, 1 = Previous/Next, 2 = All Page Numbers 
		** loTable.nPage_LinkLocation   = 1    && 1 = end of table (more options to be added later ?)
		** loTable.cPage_PageLabel      = "Page: "

		.SetElementProperty( "City", "cHeading", [DTOC(DATE())] )
		
		.ProcessCursor()    
	ENDWITH
	= ShowDemoResult( loTable )

CASE m.lnDemo = 11  && Show how a column can contain several elements.

	IF m.llSimple
		= MESSAGEBOX( "NOTE: This demo cannot be run with the simple table class!" )
		RETURN
	ENDIF
	
	SELECT Customer_ID, Company_Name, Contact_Name, Phone, ;
			City, Region, Country, Postal_Code, Max_Order_Amt ;
		FROM Customer ;
		INTO CURSOR TQuery_
		
	pnSql = SECONDS()
	loTable = CREATE( m.lcTableClass )
	WITH loTable
		.cTitle = "2 Approaches for Including Multiple Elements in One Column"
		.cTableBgColor = "#EEEEEE"
		.cTitleFontColor = "brown"
		.nPage_ItemsPerPage = 20

		.AddColumn( -1)
		
		* First, a simple column:
		.AddCursorColumn( "Customer_ID", "ID")

		* Next a single-element column, but with a complex *expression*:
		.AddCursorColumn( [TRIM( City) + ", " + TRIM( Region) + "<BR>" + Country + " " + Postal_Code], ;
			"Location" )
		
		* Now a colmplex column with multiple separate element objects:
		loCol = .AddColumn()
		WITH loCol
			.cHeading = "Contact Info"
			
			loElem = .AddElement( "Company_Name")
			WITH loElem
				.cPrefix = "Company: "
				.cFontAttributes = "B"
			ENDWITH
			
			loElem = .AddElement( "Contact_Name")
			WITH loElem
				.cPrefix = "<BR>Contact: "
				.cFontColor = "brown"
			ENDWITH
		ENDWITH
		.ProcessCursor()    
	ENDWITH
	= ShowDemoResult( loTable )

OTHERWISE
	= MESSAGEBOX( "Undefined Test Case Number!" )
ENDCASE

SET TALK ON
SET CONSOLE ON

PROCEDURE ShowDemoResult( loTable)

LOCAL lnEnd, lcTimes, lcTable
lnEnd = SECONDS()
lcTable = loTable.GetOutput()
lcTimes = [<FONT SIZE=3><PRE>] + ;
	"Process SQL: " + TRANS( m.pnSql - m.pnStart, "999.999" ) + CHR( 13) + CHR(10 ) + ;
	"Build Table: " + TRANS( m.lnEnd - m.pnSql, "999.999" ) + CHR( 13) + CHR(10 ) + ;
	" Total Time: " + TRANS( m.lnEnd - m.pnStart, "999.999" ) + CHR( 13) + CHR(10 ) + ;
	"    Records: " + TRANS( RECCOUNT()) + CHR( 13) + CHR(10 ) + ;
	"      Bytes: " + LTRIM( TRANS( LEN( m.lcTable), "99,999,999")) + CHR( 13) + CHR(10 ) + ;
	"  Shareware: " + IIF( L7_SHAREWARE, "YES", "no") + CHR( 13) + CHR(10 ) + ;
	[</PRE></FONT>] 
	
lnEnd = SECONDS()
* Display in a browser:
= ShowHTML( ;
	[<HTML><HEAD>] + ;
	[<LINK REL="STYLESHEET" TYPE="TEXT/CSS" HREF="http://www.cycla.com/software/l7/l7.css">] + ;
	[</HEAD><BODY>] + ;
	[<P ALIGN=CENTER><FONT SIZE=2>L7HtmlTable Test: <B>] + LOWER( TRANS( DATETIME())) + [</B></P>] + ;
	m.lcTable + ;
	m.lcTimes + ;
	[</BODY></HTML>] )

ENDPROC
