* L7RTF.PRG  - Rich Text Format library
#include L7.H

*** ============================================================ ***
DEFINE CLASS L7RtfTable AS Custom
  ADD OBJECT Columns AS Collection
  cColumnClass = "L7RtfTableColumn"
  nWidth = 1440 * 6
  nBorderWidth = 20
  nGapHalf = 90
  nLeftMargin = 0
  cRowFormat = ""
  PROTECTED nRowCount
  nRowCount = 0
  PROTECTED nCurrentColumn
  nCurrentColumn = 0
  PROTECTED cText
  cText = ""
  * ---------------------------------------------------------- *
  FUNCTION CreateColumn(lcName)
    LOCAL loCol
    loCol = CREATEOBJECT(THIS.cColumnClass)
    THIS.Columns.Add(m.loCol, EVL(m.lcName, SYS(2015)))
    RETURN m.loCol
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION WriteHeaderRow(lcText, lcCellFmt, lcRowFmt)
    * single spanned row
    LOCAL lcStr, ii
    lcStr = ""
    WITH THIS
      lcStr = m.lcStr + THIS.GetRowStart(.T., m.lcRowFmt)
      FOR ii = 1 TO .Columns.Count
        IF m.ii = 1
          lcStr = m.lcStr + "\pard\intbl" + ;
            EVL(m.lcCellFmt, "") + ;
            "{" + m.lcText + "}\cell" + CRLF
        ELSE
          lcStr = m.lcStr + "\pard \intbl \cell" + CRLF
        ENDIF
      ENDFOR
      lcStr = m.lcStr + THIS.GetRowEnd()
      .Write(m.lcStr)
    ENDWITH
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION WriteCell(lcText, lcCellFmt, lcRowFmt)
    LOCAL lcStr
    lcStr = ""
    WITH THIS
      IF .nCurrentColumn = 0
        .nRowCount = .nRowCount + 1
        lcStr = m.lcStr + THIS.GetRowStart(.F., m.lcRowFmt)
      ENDIF
      lcStr = m.lcStr + "\pard\intbl" + ;
        EVL(m.lcCellFmt, "") + ;
        "{" + m.lcText + "}\cell" + CRLF
      * Set next column number: 
      .nCurrentColumn = MOD(.nCurrentColumn + 1, .Columns.Count)
      IF .nCurrentColumn = 0  && end of row
        lcStr = m.lcStr + THIS.GetRowEnd()
      ENDIF
      .Write(m.lcStr)
    ENDWITH
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION GetRowStart(llMerged, lcExtraFmt)
    LOCAL lcStr, lnCumTwips, lcBorder, lcBrdr, llFirstCell
    lcStr = ""
    lnCumTwips = 0
    llFirstCell = .T.
    * Cope with variable border stuff later:
    IF THIS.nBorderWidth > 0
      lcBrdr = "\brdrs" + "\brdrw" + TRANSFORM(THIS.nBorderWidth) 
      lcBorder = ;
        "\clbrdrt" + m.lcBrdr + " " + ;
        "\clbrdrl" + m.lcBrdr + " " + ;
        "\clbrdrb" + m.lcBrdr + " " + ;
        "\clbrdrr" + m.lcBrdr + " " 
    ELSE
      lcBorder = ""
    ENDIF
    WITH THIS
      lcStr = m.lcStr + "\trowd " + "\trgaph" + TRANSFORM(.nGapHalf) 
      * left table margin:
      IF .nLeftMargin <> 0
        lcStr = m.lcStr + "\trleft" + TRANSFORM(.nLeftMargin) 
        lnCumTwips = .nLeftMargin
      ENDIF
      * optional formatting passed?:
      IF NOT EMPTY(m.lcExtraFmt)
        lcStr = m.lcStr + m.lcExtraFmt
      ENDIF
      lcStr = m.lcStr + .cRowFormat + CRLF
        
      FOR EACH loCol IN THIS.Columns
        lnCumTwips = m.lnCumTwips + loCol.nWidthTwips
        
        lcStr = m.lcStr + ;
          IIF(m.llMerged, IIF(m.llFirstCell, '\clmgf ', '\clmrg '), '') + ;
          loCol.cCellFormat + ;
          m.lcBorder + ;
          "\cellx" + TRANSFORM(m.lnCumTwips) + CRLF
          
        llFirstCell = .F.
      ENDFOR
    ENDWITH
    RETURN m.lcStr
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION GetRowEnd()
    LOCAL lcStr
    lcStr = ""
    lcStr = m.lcStr + "\row " + CRLF
    RETURN m.lcStr
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION Write(lcTxt)
    THIS.cText = THIS.cText + m.lcTxt
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION Render
    RETURN THIS.cText
  ENDFUNC
ENDDEFINE

*** ============================================================ ***
DEFINE CLASS L7RtfTableColumn AS Line
  nWidthPct = NULL
  nWidthTwips = 1440
  cCellFormat = ""
ENDDEFINE


*** ============================================================ ***
DEFINE CLASS L7RtfDoc AS Custom
  ADD OBJECT Fonts AS L7RtfFontTable
  ADD OBJECT Colors AS L7RtfColorTable
  ADD OBJECT Sections AS Collection
  ** cOutput = ""
  cStartText = "{\rtf1\ansi\deff0"
  cText = "\deflang1033\widowctrl"
  cEndText = "}"
  ActiveSection = NULL
  cSectionClass = "L7RtfSection"
  lPageNumbering = .T.
  cHeaderText = ""
  cFooterText = ""
  * ---------------------------------------------------------- *
  FUNCTION INIT
    THIS.AddSection("Default")
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION AddSection(lcKey, llNoPoint)
    lcKey = EVL(m.lcKey, "Section" + TRANSFORM(1 + THIS.Sections.Count))
    THIS.Sections.Add(CREATEOBJECT(THIS.cSectionClass), m.lcKey)
    IF NOT m.llNoPoint
      THIS.ActiveSection = THIS.Sections[m.lcKey]
    ENDIF
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION Render()
    LOCAL lcTxt
    lcTxt = ""
    WITH THIS
      .RenderFontTable(@lcTxt)
      .RenderColorTable(@lcTxt)
      IF NOT EMPTY(THIS.cText)  && not clear where this should go yet
        lcTxt = m.lcTxt + THIS.cText + CRLF
      ENDIF
      .RenderDocumentFormatting(@lcTxt)
      .RenderSections(@lcTxt)
      .WrapProlog(@lcTxt)
    ENDWITH
    RETURN m.lcTxt
  ENDFUNC  && Render
  * ---------------------------------------------------------- *
  FUNCTION RenderDocumentFormatting(lcTxt)
    lcTxt = m.lcTxt + "{\margl720\margr720\margt1080\margb720}" + CRLF
    IF NOT EMPTY(THIS.cHeaderText)
      lcTxt = m.lcTxt + "{\header " + THIS.cHeaderText + "}" + CRLF
    ENDIF
    IF THIS.lPageNumbering
      lcTxt = m.lcTxt + "{\footer " + ;
        IIF(EMPTY(THIS.cFooterText), "", ;
          "\pard\ql " + THIS.cFooterText + "\par ") + ;
        "\pard\qr\plain\f0\chpgn\par}" + CRLF
    ENDIF
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION WrapProlog(lcTxt)
    lcTxt = THIS.cStartText + CRLF + ;
      m.lcTxt + CRLF + ;
      THIS.cEndText
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION RenderFontTable(lcTxt)
    LOCAL lcStr, lcFont, ii
    lcStr = "{\fonttbl" + CRLF
    FOR ii = 1 TO THIS.Fonts.Count
      lcStr = m.lcStr + "{\f" + TRANSFORM(m.ii - 1) + " " + THIS.Fonts[m.ii] + ";}" + CRLF
    ENDFOR
    lcStr = m.lcStr + "}" + CRLF
    lcTxt = m.lcTxt + m.lcStr
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION RenderColorTable(lcTxt)
    LOCAL lcStr, lcColor
    IF THIS.Colors.Count = 0
      RETURN
    ENDIF
    lcStr = "{\colortbl;" 
    FOR EACH lcColor IN THIS.Colors
      lcStr = m.lcStr + m.lcColor
    ENDFOR
    lcStr = m.lcStr + "}" + CRLF
    lcTxt = m.lcTxt + m.lcStr
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION RenderSections(lcTxt)
    LOCAL loSection
    FOR EACH loSection IN THIS.Sections
      lcTxt = m.lcTxt + loSection.Render()
    ENDFOR
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION Write(lcTxt)
    THIS.cText = THIS.cText + m.lcTxt
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION GetFont(lcFont)
    * Used both for adding and getting reference to font names.
    * Send a font name, e.g., "Courier" and get an RTF command
    * to use in line. If the font is not yet in the font table for
    * the document, it is added. The font table is rendered at the end.
    * ex: 
    *     lcCmd = loRtfDoc.GetFont("Verdana")  && sends \fN
    LOCAL lnKey
    lnKey = THIS.Fonts.GetKey(m.lcFont)
    IF lnKey = 0
      THIS.Fonts.Add(m.lcFont, m.lcFont)
      lnKey = THIS.Fonts.Count
    ENDIF
    RETURN "\f" + TRANSFORM(m.lnKey) + CRLF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION GetColor(lcName, llBG)
    * Gets a color command for the specifies color name. Pass TRUE
    * as 2nd param to get a background command.
    * Colors need first to be loaded into the table using
    *
    * doc.Colors.Add(<cName>, <nRed>, <nGreen>, <nBlue>)
    LOCAL lnKey
    lnKey = THIS.Colors.GetKey(m.lcName) && if not found, uses 0, which is "default"
    RETURN "\c" + IIF(m.llBG, "b", "f") + TRANSFORM(m.lnKey) + CRLF
  ENDFUNC
  * ---------------------------------------------------------- *
ENDDEFINE

*** ============================================================ ***
DEFINE CLASS L7RtfSection AS Custom
  cText = ""
  * ---------------------------------------------------------- *
  FUNCTION WriteParagraph(lcTxt, lcFormat)
    LOCAL lcStr
    lcStr = "{\pard" + CRLF + ;
      IIF(EMPTY(m.lcFormat), "", m.lcFormat + CRLF) + ;
      m.lcTxt + CRLF + "\par}" + CRLF
      
    THIS.cText = THIS.cText + m.lcStr
    RETURN
  ENDFUNC 
  * ---------------------------------------------------------- *
  FUNCTION Write(lcTxt)
    THIS.cText = THIS.cText + m.lcTxt
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION Render
    RETURN THIS.cText
  ENDFUNC
  * ---------------------------------------------------------- *
ENDDEFINE

*** ============================================================ ***
DEFINE CLASS L7RtfFontTable AS Collection
  * ---------------------------------------------------------- *
  FUNCTION INIT
    THIS.Add("Arial", "Arial")
    THIS.Add("Times New Roman", "Times New Roman")
    THIS.Add("Courier New", "Courier New")
    THIS.Add("Monospace", "Monospace")
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
ENDDEFINE

*** ============================================================ ***
DEFINE CLASS L7RtfColorTable AS Collection
  * ---------------------------------------------------------- *
  FUNCTION INIT
    THIS.AddColor("Red", 192, 0, 0)
    THIS.AddColor("Green", 0, 128, 0)
    THIS.AddColor("Blue", 0, 0, 255)
    THIS.AddColor("Brown", 192, 80, 72)
    THIS.AddColor("DarkGreen", 16, 64, 16)
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION AddColor(m.lcName, m.lnRed, m.lnGreen, m.lnBlue)
    THIS.Add(;
      "\red" + TRANSFORM(m.lnRed) + ;
      "\green" + TRANSFORM(m.lnGreen) + ;
      "\blue" + TRANSFORM(m.lnBlue) + ";", ;
      m.lcName)
    RETURN
  ENDFUNC
  * ---------------------------------------------------------- *
ENDDEFINE

*** UDF's:

* ============================================================ *
FUNCTION RtfItalic(lcTxt)
  * Italics: Either starts or wraps.
  IF VARTYPE(m.lcTxt) = "C"
    lcTxt = "{\i " + m.lcTxt + "}"
  ELSE
    lcTxt = "\i "
  ENDIF
  RETURN m.lcTxt
ENDFUNC 
* ============================================================ *
FUNCTION RtfBold(lcTxt)
  * Bold: Either starts or wraps.
  RETURN RtfCommand("\b", @lcTxt)
ENDFUNC 
* ============================================================ *
FUNCTION RtfCommand(lcCmd, lcTxt)
  * Generic: Either starts or wraps.
  IF LEFT(m.lcCmd,1) <> "\"
    lcCmd = "\" + m.lcCmd
  ENDIF
  IF VARTYPE(m.lcTxt) = "C"
    lcTxt = "{" + m.lcCmd + " " + m.lcTxt + "}"
  ELSE
    lcTxt = m.lcCmd + " "
  ENDIF
  RETURN m.lcTxt
ENDFUNC 
* ============================================================ *
FUNCTION RtfEscape(tcText)
  tcText = STRTRAN(STRTRAN(STRTRAN(m.tcText, '\', '\\'), '{', '\{'), '}', '\}')
  RETURN m.tcText
ENDFUNC
* ============================================================ *
FUNCTION RtfBookmark(lcTxt, lcBM)
  lcTxt = "{\*\bkmkstart " + m.lcBM + "}" + ;
    m.lcTxt + "{\*\bkmkend " + m.lcBM + "}" 
  RETURN m.lcTxt
ENDFUNC
* ============================================================ *
FUNCTION RtfLink(lcHref, lcTxt)
  lcTxt = EVL(m.lcTxt, m.lcHref)
  lcTxt = ;
    [{\field] + ;
      [{\*\fldinst] + ;
        [{HYPERLINK \\l "] + m.lcHref + ["}] + ;
      [}] + ;
      [{\fldrslt{\ul ] + m.lcTxt + [}}] + ;
    [}] 
  RETURN m.lcTxt
ENDFUNC
* ============================================================ *
FUNCTION L7parseToRtf( tcText)
  IF VARTYPE(goL7App) = "O" AND VARTYPE(goL7App.oParseManager) = "O"
    goL7App.oParseManager.parseByName("L7ParseToRtfChain", @tcText)
  ELSE
    callParserDirect(@tcText, "L7ParseToRtfChain")
  ENDIF
  RETURN m.tcText
ENDFUNC

*** ============================================================ ***
DEFINE CLASS L7ParseToRtfChain AS L7ParseChainAnchor
  FUNCTION forgeChainImplementation()

    this.setSuccessor( "L7RtfEscapeParser")  && must come first
    this.setSuccessor( "L7RtfHtmlEscapeParser")
    this.setSuccessor( "L7RtfTextDecorationParser")
    this.setSuccessor( "L7RtfListParser")
    this.setSuccessor( "L7RtfParagraphParser")
     
    RETURN
  ENDFUNC
ENDDEFINE

*** ============================================================ ***
DEFINE CLASS L7RtfEscapeParser as L7BaseParser
  FUNCTION parse(tcText)
    * assumes no RTF codes already in text!
    tcText = STRTRAN(STRTRAN(STRTRAN(m.tcText, '\', '\\'), '{', '\{'), '}', '\}')
    RETURN m.tcText
  ENDFUNC
ENDDEFINE

*** ============================================================ ***
DEFINE CLASS L7RtfHtmlEscapeParser as L7BaseParser
  lIgnoreCase  = .T.      
  cPattern     = "(&#(\d{1,3});)"
  cReplacement = [="\'"+TRANSFORM(INT(VAL($2)/16))+TRANSFORM(MOD(VAL($2),16))] 
ENDDEFINE


*** ========================================================== ***
DEFINE CLASS L7RtfParagraphParser AS L7BaseParser
  * --------------------------------------------------------- *
  FUNCTION isPatternPresent( tcText )
    LOCAL llRetval
    *-- not much we can do here...
    llRetval = ! EMPTY( m.tcText )
    RETURN m.llRetval
  ENDFUNC  && isPatternPresent

  * --------------------------------------------------------- *
  FUNCTION parse( tcText )
    LOCAL ;
      laLines[1], ;
      lcParsedText, ;
      lcLine, ;
      lnTotLines, ;
      lnLine

    lcParsedText = ""
    lnTotLines= ALINES( m.laLines, m.tcText)

    FOR lnLine= 1 TO m.lnTotLines
      lcLine= laLines( m.lnLine )
      IF LEFT(m.lcLine, 1) $ '{\' OR RIGHT(m.lcLine,1) = "}" 
        * already a command or group -- don't fiddle with it!
        lcParsedText = m.lcParsedText + m.lcLine + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
      ELSE
        * seems to be a raw paragraph
        IF NOT EMPTY(m.lcLine)  && avoids multiple p's in a row
          lcParsedText = m.lcParsedText + m.lcLine + [\par ] + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
        ENDIF
      ENDIF
    ENDFOR
    tcText = m.lcParsedText
    RETURN m.tcText

  ENDFUNC  && ParagraphParser::parse

ENDDEFINE
*-- EOC L7RtfParagraphParser 

*** ========================================================== ***
DEFINE CLASS L7RtfListParser AS L7BaseParser
* Implements RTF equivalent of <ol>,<ul> list parsing
    
  * --------------------------------------------------------- *
  FUNCTION isPatternPresent( tcText )
    LOCAL llRetval
    *-- not much we can do here...
    llRetval = ! EMPTY( m.tcText )
    RETURN m.llRetval
  ENDFUNC  && isPatternPresent

  * --------------------------------------------------------- *
  FUNCTION parse( tcText )
   
    LOCAL lnLine, ;
    lcLine, ;
    lcParsedText, ;
    lnIgOpen, ;
    lnIgClose, ;
    lnIndent, ;
    lnNumber, ;
    lcListType, ;
    lcOrderedListType, ;
    lcOrderedListStart, ;
    lcListStack, ;
    laLines(1), ;
    lcTag, ;
    lnList, ;
    lcChar, ;
    lntotlines, ;
    llWasOpen, ;
    lnMarkSize

    STORE 0 TO lnIgOpen, lnIgClose, lnIndent, lnNumber

    lcParsedText       = ""
    lcChar             = []
    lcListType         = []
    lcOrderedListType  = []
    lcOrderedListStart = []
    lcRtfListCommand   = []

    lcListStack = []  && Keeps track of open list tags so they can be closed properly.  eg. ulololulul

    lnTotLines= ALINES( m.laLines, m.tcText)

    FOR lnLine= 1 TO m.lnTotLines

      lcLine= laLines( m.lnLine )

        IF EMPTY(lcLine)  && blank line
          *-- close any open lists
          DO WHILE LEN( m.lcListStack ) >= 2
            **HTML: lcParsedText = m.lcParsedText + [</] + RIGHT( m.lcListStack , 2 ) + [>] + CRLF
            lcListStack  = LEFT( m.lcListStack , LEN( m.lcListStack ) - 2 )
          ENDDO
          lnIndent = 0
        ENDIF


        lnMarkSize = 0
        lnNumber = 0
        * Step 1. Recognition of list semantics. (output-independent)
        DO CASE
        * Enumerated (ordered) lists:
        CASE (( VAL( m.lcLine ) > 0 )  OR ;
          (INLIST( LOWER( LEFT( ALLTRIM( m.lcLine ) , 1 ) ) , [a],[b],[c],[d],[e],[f],[g] , [i],[v],[x] ) ) ) AND ;
          ( RIGHT(GETWORDNUM( m.lcLine ,1),1)=[.] ) AND ( ! LOWER( GETWORDNUM( m.lcLine ,1)) $ [dr.] )

          *? bit of a kluge that, but probably 99% use case handled above
          lcListType = [ol]
          lnNumber   = LEN( m.lcLine ) - LEN( LTRIM( m.lcLine ))+1
          lnMarkSize = LEN(GETWORDNUM( m.lcLine, 1 ))

          lcOrderedListStart = []
          lcOrderedListType  = [1]

          DO CASE

          CASE VAL( m.lcLine ) > 0
            lcOrderedListType  = [1]
            lcRtfListCommand   = [\pndec ]
            lcOrderedListStart = STRTRAN(LOWER( LEFT( ALLTRIM( m.lcLine ) , 2 )),[.])

          CASE INLIST( LEFT( ALLTRIM( m.lcLine ) , 1 ) , [a],[b],[c],[d],[e],[f],[g]  )
            lcOrderedListType = [a]
            lcRtfListCommand   = [\pnlcltr ]
            lcOrderedListStart = STR( ASC( UPPER( LEFT( ALLTRIM( m.lcLine ) , 1 )) ) - ASC("A")+1)

          CASE INLIST( LEFT( ALLTRIM( m.lcLine ) , 1 ) , [A],[B],[C],[D],[E],[F],[G]  )
            lcOrderedListType = [A]
            lcRtfListCommand   = [\pnucltr ]
            lcOrderedListStart = STR( ASC( UPPER( LEFT( ALLTRIM( m.lcLine ) , 1 )) )-ASC("A")+1)

          CASE INLIST( LEFT( ALLTRIM( m.lcLine ) , 1 ) , [i],[v],[x]  )
            lcOrderedListType = [i]
            lcRtfListCommand   = [\pnlcrm ]
            LOCAL lcTemp, lcTemp2
            lcTemp=",i,ii,iii,iv,v,vi,vii,viii,ix,x,"
            lcTemp2 = [,]+STRTRAN( GETWORDNUM( m.lcLine,1 ) , [.] )+[,]

            lcOrderedListStart= STR( OCCURS(",",LEFT( m.lcTemp, AT( m.lcTemp2, m.lcTemp))))

          CASE INLIST( LEFT( ALLTRIM( m.lcLine ) , 1 ) , [I],[V],[X]  )
            lcOrderedListType = [I]
            lcRtfListCommand   = [\pnucrm ]
            LOCAL lcTemp, lcTemp2
            lcTemp=UPPER(",i,ii,iii,iv,v,vi,vii,viii,ix,x,")
            lcTemp2 = [,]+STRTRAN( GETWORDNUM( m.lcLine, 1 ) , [.] )+[,]

            lcOrderedListStart= STR( OCCURS(",",LEFT( m.lcTemp, AT( m.lcTemp2, m.lcTemp))))
          ENDCASE

          lcOrderedListStart = ALLTRIM( m.lcOrderedListStart )

        * Bulleted (unordered) lists:
        *[[ Change 07/12/2002: require a space after the * or balanced pairs of * in the line to avoid conflicts with the *strong* parser. 
        *[[ Change 01/20/2003: require a space after the * period, for footnotes.
        CASE LEFT( ALLTRIM( m.lcLine ), 1 ) = "*" AND ;
             (SUBSTR( ALLTRIM(m.lcLine), 2, 1) = [ ]) && OR OCCURS( [*], SUBSTR( ALLTRIM( m.lcLine ), 2) ) % 2 = 0 )

          lcListType = [ul]
          lcRtfListCommand = [{\pntxtb \'95}]
          lnNumber = IIF( LEFT( ALLTRIM( m.lcLine ), 1 ) = "*" , AT( "*" , m.lcLine ), 0 )
          lnMarkSize = 1
        
        ENDCASE

        * Step 2. Output.
        DO CASE

        CASE  m.lnNumber > m.lnIndent
          IF m.lnIndent = 0  && list just starting
            lcParsedText = m.lcParsedText + [\sectd\sbknone ] + CRLF + ;
              [{\*\pnseclvl1\pndec\pnb\pnstart1\pnindent720\pnhang {\pntxta .}{\pntxtb}}] + CRLF + ;
              [{\*\pnseclvl2\pnlcltr\pnb\pnstart1\pnindent1440\pnhang {\pntxta .}{\pntxtb}}] + CRLF

          ENDIF
          
          *? deprecation alert, TYPE and START should be handled with STYLE attributes
          **HTML: lcTag = [<] + m.lcListType + ;
          **HTML: IIF( m.lcListType="ol" , [ type="]  + m.lcOrderedListType  + ["], "" ) + ;
          **HTML: IIF( m.lcListType="ol" , [ start="] + m.lcOrderedListStart + ["], "" ) + [>]
          **HTML: lcParsedText = m.lcParsedText + REPLICATE( m.lcTag , m.lnNumber - m.lnIndent ) + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
          lcListStack = m.lcListStack + REPLICATE( m.lcListType , m.lnNumber - m.lnIndent )

        CASE  m.lnNumber < m.lnIndent
         
          * FOR lnList = lnIndent TO lnNumber +1  STEP -1
          * Changed: 07/24/2002 by lc. eschew obscurification  
          FOR lnList = m.lnNumber TO m.lnIndent - 1
            **HTML: lcParsedText = m.lcParsedText + [</] + RIGHT( m.lcListStack , 2 ) + [>] + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
            lcListStack = LEFT( m.lcListStack , LEN( m.lcListStack ) - 2 )
          ENDFOR

        ENDCASE

     *   DEBUGOUT [lcListStack=]+ lcListStack + [, lnIndent=] +TRANSFORM(lnIndent) + [, lnNumber=] + TRANSFORM(lnNumber )+ [, lcListType=] + lcListType + [, lnMarkSize=] +TRANSFORM(lnMarkSize) + [, lcOrderedListType=]+ lcOrderedListType + ", lcLine="+lcLine

        lnIndent = m.lnNumber

        IF lnIndent> 0
          **HTML: lcParsedText = m.lcParsedText + [<li>] + SUBSTR( m.lcLine , m.lnIndent + m.lnMarkSize ) + [</li>] + CRLF
          lcAmt = TRANSFORM(m.lnIndent * 720)
          lcParsedText = m.lcParsedText + [{\pard\fi-720\li] + m.lcAmt + [{\*\pn\pnlvl] + ;
            IIF(m.lcListType = "ul", "blt", TRANSFORM(m.lnIndent)) + ;
            m.lcRtfListCommand + ;
            [\pnindent] + m.lcAmt + [\pnhang] + [}] + CRLF + ;
            SUBSTR(m.lcLine, m.lnIndent + m.lnMarkSize ) + [\par}] + CRLF
        ELSE
          lcParsedText = m.lcParsedText + m.lcLine + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
        ENDIF

 *     ENDIF


    ENDFOR
    
    *-- close any open lists
    DO WHILE LEN( m.lcListStack ) >= 2
      **HTML: lcParsedText = m.lcParsedText + [</] + RIGHT( m.lcListStack , 2 ) + [>] + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
      lcListStack = LEFT( m.lcListStack , LEN( m.lcListStack ) - 2 )
    ENDDO
    
    tcText= m.lcParsedText
    RETURN m.tcText

  ENDFUNC  && ListParser::parse

ENDDEFINE
*-- EOC ListRtfParser

*** ============================================================ ***
DEFINE CLASS L7RtfTextDecorationParser as L7MultiParser
* provides basic plain-text to RTF wysiwyg pattern parsing
  * --------------------------------------------------------- *
  FUNCTION init()
    * Note: Parsing will be done in the order in which the parse patterns are added
    * in some implementations, we may wish  to drive this with meta data
  
    * arguments are addParse( tcPattern, tcReplacement, [tlGlobal] , [tlIgnoreCase], [tlPushToStack] )

    *-- "Heading" parsers. H2, H3, and H4. Note: H4 must be checked first, etc.
    * (these need to be recast with styles)
    this.addParse( "((^|\n)(\s)*)\[\[\[\[([^\s\*].*?)\]\]\]\]",[$1{\pard\fs22\b $4\par}],           .t., .t., .f. )   
    this.addParse( "((^|\n)(\s)*)\[\[\[([^\s\*].*?)\]\]\]",    [$1{\pard\fs24\b $4\par}],           .t., .t., .f. )   
    this.addParse( "((^|\n)(\s)*)\[\[([^\s\*].*?)\]\]",        [$1{\pard\fs26\b $4\par}],           .t., .t., .f. )   
    * Usage:
    * If any new line starts with (optional white space and then) [[, [[[, or [[[[, followed by any
    * content on the same line that doesn't start with a space or asterisk, followed by an equal number of
    * closing "]" symbols, treat as a metaphor for a level 2, 3, or 4 heading (<h?> tag).
    * [NOTE: We don't do <h1>, because [] is likely intended as something else, and there should be only one <h1>
    * tag ever on a page, which is likely coming from a different source anyway. And we don't do <h5> and <h6>
    * because of frequency-vs-performance trade-off.]


    *-- Emphasis and strikeout inline parsers:
    this.addParse( "(^|\n|\W)-{2,}([^\s|-].*?)-{2,}(\W|$)",    [$1{\strike $2}$3], .t., .t., .f. )
    this.addParse( "(^|\n|\W|_)\*([^\s|\*].*?)\*(_|\W|$)",     [$1{\b $2}$3], .t., .t., .f. )
    *-- Same as above, but with 2 or more ** 
    this.addParse( "(^|\n|\W)\*{2,}([^\s].*?)\*{2,}(\W|$)",    [$1{\b\i $2}$3], .t., .t., .f. )
    this.addParse( "(^|\n|\W)_([^\s|_].*?)_(\W|$)",            [$1{\i $2}$3], .t., .t., .f. )  
    *-- Same as above, but with 2 or more _
    this.addParse( "(^|\n|\W)_{2,}([^\s].*?)_{2,}(\W|$)",      [$1{\b\i $2}$3], .t., .t., .f. )
    * Usage (varies somewhat for minor reasons):
    * Words wrapped with matcing symbols have the symbols replaced with RTF commands as follows:
    * --text--  == {\strike text...}     (strikethrough)
    *  *text*   == {\b text...}
    * **text**  == {\b\i text...}
    *  _text_   == {\i text...}
    * __text__  == {\b\i text...}  

    *-- Superscript and subscript parsers:
    this.addParse( "\^\{(.*?)\}",                              [{\super $1}],   .t., .t., .f. )  
    this.addParse( "v\{(.*?)\}",                               [{\sub $1}],   .t., .t., .f. )  
    * Usage:
    * Wrapping text like ^{text} or v{text} is interpreted
    * as superscript and subscript.

    *-- "Horizontal Rule" parsers:
    this.addparse( "(^|\n)----(\s?\r|$)",                      [$1{\pard \brdrb \brdrs \brdrw10 \brsp20 \par}{\pard\par}$2], .t., .t., .f. )
    this.addparse( "(^|\n)====(\s?\r|$)",                      [$1{\pard \brdrb \brdrs \brdrw40 \brsp20 \par}{\pard\par}$2], .t., .t., .f. )
    * Usage:
    * At the beginning of any line, if ---- or ==== is followed by (optional white space and then) nothing but an end-of-line, 
    * then substitute an a thin or thick <hr> tag.
    
    RETURN DODEFAULT()
  ENDFUNC

ENDDEFINE
