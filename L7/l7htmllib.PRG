* L7HtmlLib.PRG

#include L7.H

* Level 7 HTML Function Library.
*
* This is a function library, NOT a class, for better performance, 
* and so it can be called
* from _anywhere_. I know it breaks encapsulation, and I'm willing
* to live with it.

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


* --------------------------------------------------------- *
FUNCTION HTDir(lcOsPath, lcHttpPath, lcClass, lcSkel)
  lcClass = EVL(m.lcClass, "HTDir")
  lcSkel = EVL(m.lcSkel, [*.*])
  lcHttpPath = EVL(m.lcHttpPath, "")
  lcOsPath = EVL(m.lcOsPath, CURDIR())
  LOCAL laDir[1], lnDir, lcRet, ii, lcItem
  lnDir = ADIR(laDir, ADDBS(m.lcOsPath) + m.lcSkel)
  lcRet = [<ul class="] + m.lcClass + [">] + CRLF
  FOR ii = 1 TO m.lnDir
    lnSize = laDir[m.ii, 2]
    lcFile = laDir[m.ii, 1]
    lcItem = [  <li><a href="] + m.lcHttpPath + ;
      STRTRAN(m.lcFile, SPACE(1), "%20") + [">] + ;
      m.lcFile + [</a> (] + TRANSFORM(ROUND(m.lnSize/1024, 1)) + [ kB)</li>] + CRLF
    lcRet = m.lcRet + m.lcItem
  ENDFOR
  lcRet = m.lcRet + [</ul>] + CRLF
  RETURN m.lcRet
ENDFUNC

* --------------------------------------------------------- *
FUNCTION HTWrap(lcText, lcElems, lcAttribs, lcClasses)
  * Handy, quick-formatting function that wraps a string in HTML elements. 
  * Intended to allow quick formatting (and quick changes) without
  *  typing alot of HTML characters.
  *
  * Features and Options:
  *
  * Optional 3rd parameter to insert attributes. If multiple element
  *  specified in first parm, tags apply to first element.
  * If called with multiple, already-bracketed items, or items
  *  separated by commas, wraps closing tags in reverse order.
  *
  * Examples:
  * 1. HTWrap( 'Hello, world!', 'B' ) 
  *    Returns: "<b>Hello, world!</b>"
  * 2. HTWrap( 'Hello, world!', '<B>' ) 
  *    (also) Returns: "<b>Hello, world!</b>"
  * 3. HTWrap( 'Hello, world!', 'P', 'align="right"' ) 
  *    Returns: "<p align="right">Hello, world!</p>"
  * 4. HTWrap( 'Hello, world!', 'b,i' ) 
  *    Returns: "<b><i>Hello, world!</i></b>"
  * 5. HTWrap( 'Hello, world!', 'div', 'hello' ) 
  *    Returns: "<div class="hello">Hello, world!</div>"
  
  LOCAL lcPref, lcSuf, ii, lnElems, lcElem, lnAttribs, lcAttrib, lnClasses, lcClass
  STORE "" TO lcPref, lcSuf
  lcElems = EVL(m.lcElems, "")
  * Remove any < or >, in case developer is trying to "help".
  lcElems = CHRTRAN( m.lcElems, "<>", " ,")
  * Count the elements. (There is on more comma than element.
  lnElems = GETWORDCOUNT(m.lcElems, ",")
  * See if optional attribs were passed, and if so, for how many elements.
  lnAttribs = IIF(EMPTY(m.lcAttribs), 0, GETWORDCOUNT(m.lcAttribs, ","))
  * See if optional *classes* were passed, and if so, for how many elements.
  * Passing in class names is a shortcut to CLASS="name" in the attribute list.
  lnClasses = IIF(EMPTY(m.lcClasses), 0, GETWORDCOUNT(m.lcClasses, ","))

  FOR ii = 1 TO m.lnElems
  	lcElem = LOWER(ALLTRIM(GETWORDNUM(m.lcElems, m.ii, ",")))  && LOWER() gets us nearer to XHTML
  	IF NOT EMPTY(m.lcElem)
  		* See if this element has any optional attribs.
  		* Build the prefix in *forward* order.
  		lcPref = m.lcPref + '<' + m.lcElem 
  		IF m.ii <= m.lnAttribs  && May be optional attributes.
  			lcAttrib = ALLTRIM(GETWORDNUM(m.lcAttribs, m.ii, ",")) 
  			IF NOT EMPTY( m.lcAttrib)
          IF NOT "=" $ m.lcAttrib  && if not in form: attrib="value", assume a class name
            lcAttrib = [class="] + m.lcAttrib + ["]
          ENDIF
  				lcPref = m.lcPref + " " + m.lcAttrib
  			ENDIF
  		ENDIF
  		IF m.ii <= m.lnClasses  && May be "class" specified also.
        lcClass = ALLTRIM(GETWORDNUM(m.lcClasses, m.ii, ",")) 
  			IF NOT EMPTY( m.lcClass)
  				lcPref = m.lcPref + ' class="' + m.lcClass + '"'
  			ENDIF
  		ENDIF
  		lcPref = m.lcPref + '>'
  		* And the closing tags in *reverse* order:
  		lcSuf = '</' + m.lcElem + '>' + m.lcSuf
  	ENDIF
  ENDFOR
  * Wrap the passed text in the elements:
  RETURN m.lcPref + m.lcText + m.lcSuf

ENDFUNC  && HTWrap

*!*  * --------------------------------------------------------- *
*!*  FUNCTION HTWrap(lcText, lcElems, lcTags, lcClasses)
*!*    * Handy, quick-formatting function that wraps a string in HTML elements. 
*!*    * Intended to allow quick formatting (and quick changes) without
*!*    *  typing alot of HTML characters.
*!*    *
*!*    * Features and Options:
*!*    *
*!*    * Puts brackets in if needed.
*!*    * Optional 2nd parameter to insert tags. If multiple element
*!*    *  specified in first parm, tags apply to first element.
*!*    * If called with multiple, already-bracketed items, or items
*!*    *  separated by commas, wraps closing tags in reverse order.
*!*    *
*!*    * Examples:
*!*    * 1. HTWrap( 'Hello, world!', 'B' ) 
*!*    *    Returns: "<B>Hello, world!</B>"
*!*    * 2. HTWrap( 'Hello, world!', '<B>' ) 
*!*    *    Returns: "<B>Hello, world!</B>"
*!*    * 3. HTWrap( 'Hello, world!', '<P>', 'ALIGN="RIGHT"' ) 
*!*    *    Returns: "<P ALIGN="RIGHT">Hello, world!</P>"
*!*    * 4. HTWrap( 'Hello, world!', '<B><I>' ) 
*!*    *    Returns: "<B><I>Hello, world!</I></B>"
*!*    * 5. HTWrap( 'Hello, world!', 'B,I' ) 
*!*    *    Returns: "<B><I>Hello, world!</I></B>"
*!*    LOCAL lcPref, lcSuf, lnElems, ii, lcElem, lnAt1, lnAt2, lnTags, lcTag
*!*    STORE "" TO lcPref, lcSuf
*!*    lcElems = IIF( EMPTY( m.lcElems), "", m.lcElems )
*!*    * Convert any < or > to commas for easy parsing.
*!*    lcElems = STRTRAN( m.lcElems, "<", "")
*!*    lcElems = STRTRAN( m.lcElems, ">", ",")
*!*    * Wrap with commas to facilitate OCCURS counting and AT parsing.
*!*    lcElems = "," + m.lcElems + ","
*!*    * Xlate any double-commas to single.
*!*    DO WHILE ",," $ m.lcElems
*!*      lcElems = STRTRAN( m.lcElems, ",,", ",")
*!*    ENDDO
*!*    * Count the elements. (There is on more comma than element.
*!*    lnElems = OCCURS( ",", m.lcElems ) - 1
*!*    * See if optional tags were passed, and if so, for how many elements.
*!*    IF EMPTY( m.lcTags )
*!*      lnTags = 0
*!*    ELSE
*!*      * Prepare string for easy parsing.
*!*      lcTags = "," + m.lcTags + ","
*!*      lnTags = OCCURS( ",", m.lcTags ) - 1
*!*    ENDIF
*!*    * See if optional *classes* were passed, and if so, for how many elements.
*!*    * Passing in class names may be easier than CLASS="name" in the attribute
*!*    * list, for applications that use CSS alot.
*!*    IF EMPTY( m.lcClasses )
*!*      lnClasses = 0
*!*    ELSE
*!*      * Prepare string for easy parsing.
*!*      lcClasses = "," + m.lcClasses + ","
*!*      lnClasses = OCCURS( ",", m.lcClasses ) - 1
*!*    ENDIF
*!*    FOR ii = 1 TO m.lnElems
*!*      * Parse out each element.
*!*      lnAt1 = AT( ",", m.lcElems, m.ii )
*!*      lnAt2 = AT( ",", m.lcElems, m.ii + 1 )
*!*      lcElem = ALLTRIM( SUBSTR( m.lcElems, m.lnAt1 + 1, m.lnAt2 - m.lnAt1 - 1) )
*!*      IF NOT EMPTY( m.lcElem )
*!*        * See if this element has any optional tags.
*!*        * Build the prefix in *forward* order.
*!*        lcPref = m.lcPref + '<' + m.lcElem 
*!*        IF m.ii <= m.lnTags  && May be optional tag(s).
*!*          lnAt1 = AT( ",", m.lcTags, m.ii )
*!*          lnAt2 = AT( ",", m.lcTags, m.ii + 1 )
*!*          lcTag = ALLTRIM( SUBSTR( m.lcTags, m.lnAt1 + 1, m.lnAt2 - m.lnAt1 - 1) )
*!*          IF NOT EMPTY( m.lcTag)
*!*            lcPref = m.lcPref + " " + m.lcTag
*!*          ENDIF
*!*        ENDIF
*!*        IF m.ii <= m.lnClasses  && May be CLASS specified.
*!*          lnAt1 = AT( ",", m.lcClasses, m.ii )
*!*          lnAt2 = AT( ",", m.lcClasses, m.ii + 1 )
*!*          lcTag = ALLTRIM( SUBSTR( m.lcClasses, m.lnAt1 + 1, m.lnAt2 - m.lnAt1 - 1) )
*!*          IF NOT EMPTY( m.lcTag)
*!*            lcPref = m.lcPref + ' class="' + m.lcTag + '"'
*!*          ENDIF
*!*        ENDIF
*!*        lcPref = m.lcPref + '>'
*!*        * And the closing tags in *reverse* order:
*!*        lcSuf = '</' + m.lcElem + '>' + m.lcSuf
*!*      ENDIF
*!*    ENDFOR
*!*    * Wrap the passed text in the elements:
*!*    RETURN m.lcPref + m.lcText + m.lcSuf

*!*  ENDFUNC  && HTWrap

* --------------------------------------------------------- *
function HTNoBreak(tcStr, tlNoInsert, tlNoTrim) 
  * Replace spaces with &nbsp;, after trimming (optional), 
  * stuffing at least one &nbsp; where empty (optional).
  * Intended for report expressions: HTNoBreak(<field>)
  local lcRet
  lcRet = nvl(m.tcStr, "")
  if !m.tlNoTrim
    lcRet = trim(m.lcRet)
  endif 
  lcRet = strtran(m.lcRet, space(1), '&nbsp;')
  if empty(m.lcRet) and !m.tlNoInsert
    lcRet = '&nbsp;'
  endif
  return m.lcRet
endfunc  && HTNoBreak
* --------------------------------------------------------- *
FUNCTION HTFileName(tcFN)
  RETURN STRTRAN(TRIM(m.tcFN),'_', '_<wbr />')
ENDFUNC 
* --------------------------------------------------------- *
FUNCTION HTEmailLink(tcEmail, tcText, tcOptions, tlNoValidate, tlNoMunge)
  LOCAL lcRet
  tcEmail = ALLTRIM(m.tcEmail)
  IF NOT m.tlNoValidate AND NOT IsValidEmail(m.tcEmail)
    lcRet = m.tcEmail  && don't create a link that won't function
  ELSE
    lcRet = "mailto:" + m.tcEmail
    lcRet = HTLink(m.lcRet, EVL(m.tcText, m.tcEmail), m.tcOptions)
    IF NOT m.tlNoMunge
      lcRet = HTMunge(m.lcRet)  && munge parts of "mailto:" in addition to the address
    ENDIF
  ENDIF
  RETURN m.lcRet
ENDFUNC  && HTEmailLink
* --------------------------------------------------------- *
FUNCTION HTMunge(tcEmail)
  *[[ replace this with 2 #DEFINE's instead to allow some tweaking
  tcEmail = STRTRAN(STRTRAN(STRTRAN(STRTRAN(m.tcEmail,"@","&#64;"),".","&#46;"),":","&#58;"),"m","&#109;")
  RETURN m.tcEmail
ENDFUNC
* --------------------------------------------------------- *
FUNCTION HTLink( tcURL, tcText, tcOptions, tcClass, tlNoLink, tlNoContent )
  IF m.tlNoContent
    RETURN ""
  ENDIF
  IF m.tlNoLink OR EMPTY(m.tcUrl) && no hyperlink wanted or no URL provided
    RETURN m.tcText
  ENDIF
  LOCAL lcStr, lcOpt
  IF VARTYPE(m.tcText) <> "C"
  	* If no text passed in, repeat URL as text.
    IF EMPTY(m.tcText)
    	tcText = m.tcURL
    ELSE
      tcText = TRANSFORM(m.tcText)
    ENDIF
  ENDIF
  IF VARTYPE( m.tcOptions) = "C" AND NOT EMPTY(m.tcOptions)
  	IF [=] $ m.tcOptions
  		* There are specific settings, so use as-is.
  		lcOpt = [ ] + m.tcOptions
  	ELSE
  		* Assume it's a TITLE.
  		lcOpt = [ title="] + m.tcOptions + ["]
  	ENDIF
  ELSE
  	lcOpt = []
  ENDIF
  lcStr = '<a href="' + m.tcURL + '"' + ;
  	m.lcOpt + ;
  	IIF( VARTYPE( tcClass) = "C", [ class="] + m.tcClass + ["], []) + ;
  	'>' + m.tcText + '</a>'
  RETURN m.lcStr
ENDFUNC  && HTLink
* --------------------------------------------------------- *
FUNCTION HTImage(tcFile, tcAltText, tcAlign, tnBorder, tnWidth, tnHeight, tcOptions)
  LOCAL lcStr
  lcStr = '<img src="' + TRIM( m.tcFile) + '"'
  lcStr = m.lcStr + ' alt="' + IIF( EMPTY( m.tcAltText), m.tcFile, m.tcAltText) + '"'
  IF NOT EMPTY( m.tcAlign)
  	lcStr = m.lcStr + ' align="' + TRIM( UPPER( m.tcAlign)) + '"'
  ENDIF
  lcStr = m.lcStr + ' border="' + IIF( TYPE( "m.tnBorder") <> 'N', '0', LTRIM(STR( m.tnBorder))) + '"'
  IF TYPE( "m.tnWidth") = 'N'
  	lcStr = m.lcStr + ' width="' + LTRIM(STR(m.tnWidth)) + '"'
  ENDIF
  IF TYPE( "m.tnHeight") = 'N'
  	lcStr = m.lcStr + ' height="' + LTRIM(STR(m.tnHeight)) + '"'
  ENDIF
  IF TYPE( "m.tcOptions") = "C"
  	lcStr = m.lcStr + " " + m.tcOptions
  ENDIF
  lcStr = m.lcStr + '>'
  RETURN m.lcStr
ENDFUNC  && HTImage
* --------------------------------------------------------- *
FUNCTION HTMemo(lcText, llEmailCompatible, llNoContentCheck)
  * Translates CR's to <p>'s and <br />'s as needed for HTML output. 
  IF EMPTY(m.lcText)
    RETURN ""
  ENDIF
  IF VARTYPE( m.lcText ) = "C"
    IF NOT EMPTY(m.lcText)
    	IF NOT m.llNoContentCheck AND ( ;
    		LEFT( m.lcText, 1) = "<" OR ;
    		'<p>' $ LOWER( m.lcText ))
    		* Already is HTML, so leave alone.
    	ELSE  && not HTML yet, so convert
        * Remove trailing CR's:
        DO WHILE RIGHT(m.lcText,2) == CHR(13) + CHR(10)
          lcText = LEFT(m.lcText, LEN(m.lcText) - 2)
        ENDDO
    		lcText = [<p>] + STRTRAN( m.lcText, CHR(13) + CHR(10) + CHR(13) + CHR(10), [</p><p>] ) + [</p>]
    		lcText = STRTRAN( m.lcText, CHR(13) + CHR(10), L7BR )
    	ENDIF
    	IF m.llEmailCompatible
    		* Need to break up long lines:
    		LOCAL lcOut, lnLines, lnLinePointer
    		lcOut = ""
    		lnLines = MEMLINES( m.lcText)
    		_MLINE = 0
    		FOR m.lnLinePointer = 1 TO m.lnLines
    			lcOut = m.lcOut + MLINE( m.lcText, 1, _MLINE) + CHR(13) + CHR(10)
    		ENDFOR
        lcText = m.lcOut
    	ENDIF
    ENDIF
  ELSE
  	lcText = TRANS( m.lcText)
  ENDIF
  RETURN m.lcText
ENDFUNC  && HTMemo
* --------------------------------------------------------- *
FUNCTION HTArray( laArray, lcTableTags)
  * Convert array to (crude) HTML table.
  * Pass array by reference.
  EXTERNAL ARRAY laArray 
  LOCAL lnRows, lnCols, llOneDim, lcStr, lcRow, ii, jj
  lnRows = ALEN( laArray, 1)
  lnCols = ALEN( laArray, 2)
  IF lnCols = 0
  	lnCols = 1
  	llOneDim = .T.
  ENDIF
  IF VARTYPE( m.lcTableTags) <> "C"
  	lcTableTags = [border="1" cellspacing="1" align="center"]
  ENDIF
  lcStr = [<table ] + m.lcTableTags + [>]
  FOR ii = 1 TO m.lnRows
  	IF m.llOneDim
  		lcRow = [<tr><td align="center">] + TRANS( laArray[ m.ii]) + [</td></tr>]
  	ELSE
  		lcRow = "<TR>"
  		FOR jj = 1 TO m.lnCols
  			lcRow = m.lcRow + [<td align="center">] + TRANS( laArray[ m.ii, m.jj]) + [</td>]
  		ENDFOR
  		lcRow = m.lcRow + "</tr>"
  	ENDIF
  	lcStr = m.lcStr + m.lcRow
  ENDFOR
  RETURN m.lcStr + [</table>]
ENDFUNC  && HTArray
* --------------------------------------------------------- *
FUNCTION HTHR(lcText, lcClass)
  * Send a line break with optional centered text.
  LOCAL lcOut
  lcClass = EVL(m.lcClass, "L7HR")
  IF EMPTY( m.lcText)
    lcOut = [<hr class="] + m.lcClass + [">]
  ELSE
    IF NOT "<" $ m.lcText
      * If it's not formatted text, transform spaces to non-breaking.
      lcText = STRTRAN( m.lcText, " ", "&nbsp;" )
    ENDIF
    *[[ Should use <div> and CSS instead:
    lcOut = [<table class="] + m.lcClass + [" width="100%" cellpadding=2 cellspacing=0>] + ;
      [<tr><td width="2%"><hr class="] + m.lcClass + ["></td>] + ;
      '<td class="' + m.lcClass + '" align="left">' + m.lcText + '</td>' + ;
      [<td width="96%"><hr class="] + m.lcClass + ["></td></tr></table>] 
  ENDIF
  RETURN m.lcOut
ENDFUNC  && HTHR
* --------------------------------------------------------- *
FUNCTION HTDate( lxDate, llNoAbbreviate, llIncludeDow, llLeaveSpaces )
  * See Also: HTDateRange() for range of dates.
  * Produce Jan 16, 1999 style date with leading space
  
  LOCAL lcType, lnDay, lcMonth, lcRet
  lcType = VARTYPE( m.lxDate)
  IF NOT m.lcType $ 'DT' OR EMPTY(m.lxDate)
  	RETURN ""
  ENDIF
  lnDay = DAY( m.lxDate)
  lcMonth = CMONTH( m.lxDate)
  lcRet = ;
  	IIF( m.llIncludeDow, CDOW( m.lxDate) + " ", "") + ;
  	IIF( m.llNoAbbreviate, m.lcMonth, LEFT( m.lcMonth, 3) ) + " " + ;
  	IIF( m.lnDay < 10, "&nbsp;", "") + ;
  	TRANS( m.lnDay) + ;
  	", " + ;
  	STR( YEAR( m.lxDate), 4)
  IF NOT m.llLeaveSpaces  && translate spaces to non-breaking spaces
  	lcRet = STRTRAN( m.lcRet, ' ', '&nbsp;' )
  ENDIF
  RETURN m.lcRet
ENDFUNC  && HTDate
* --------------------------------------------------------- *
* Older name:
FUNCTION HTMLDate( lxDate, llNoAbbreviate, llIncludeDow, llLeaveSpaces )
  RETURN HTDate( lxDate, llNoAbbreviate, llIncludeDow, llLeaveSpaces )
ENDFUNC
* --------------------------------------------------------- *
FUNCTION HTDateRange(lvDate1, lvDate2, llNoAbbreviate, llLeaveSpaces )
  * Produce Jan 16-20, 1999 style date with leading space
  IF EMPTY(m.lvDate1) OR NOT VARTYPE(m.lvDate1) $ "DT"
    RETURN ""
  ENDIF
  LOCAL lcMonth1, lnDay1, lnYear1, lcText, lcRet
  lcMonth1 = TRIM(LEFT(CMONTH(m.lvDate1), IIF(m.llNoAbbreviate, 16, 3)))
  lnDay1 = DAY(m.lvDate1)
  lnYear1 = YEAR(m.lvDate1)

  IF EMPTY(m.lvDate2) OR (VARTYPE(m.lvDate2) = "D" AND m.lvDate1 = m.lvDate2) OR ;
    (VARTYPE(m.lvDate2) = "T" AND TTOD(m.lvDate1) = TTOD(m.lvDate2))
    lcText = [<<m.lcMonth1>> <<m.lnDay1>>, <<m.lnYear1>>]
  ELSE
    LOCAL lcMonth2, lnDay2, lnYear2
    lcMonth2 = TRIM(LEFT(CMONTH(m.lvDate2), IIF(m.llNoAbbreviate, 16, 3)))
    lnDay2 = DAY(m.lvDate2)
    lnYear2 = YEAR(m.lvDate2)
    DO CASE
    CASE m.lnYear1 <> m.lnYear2
      lcText = [<<m.lcMonth1>> <<m.lnDay1>>, <<m.lnYear1>>-<<m.lcMonth2>> <<m.lnDay2>>, <<m.lnYear2>>]
    CASE m.lcMonth1 <> m.lcMonth2
      lcText = [<<m.lcMonth1>> <<m.lnDay1>>-<<m.lcMonth2>> <<m.lnDay2>>, <<m.lnYear1>>]
    CASE m.lnDay1 <> m.lnDay2
      lcText = [<<m.lcMonth1>> <<m.lnDay1>>-<<m.lnDay2>>, <<m.lnYear1>>]
    OTHERWISE  && ???
      lcText = [<<m.lvDate1>> - <<m.lvDate2>>]
    ENDCASE
  ENDIF
  lcRet = TEXTMERGE(m.lcText)
  IF NOT m.llLeaveSpaces  && translate spaces to non-breaking spaces
    lcRet = STRTRAN( m.lcRet, ' ', '&nbsp;' )
  ENDIF
  RETURN m.lcRet
ENDFUNC  && HTDateRange
* --------------------------------------------------------- *
FUNCTION HTComment(tcText )
  RETURN [<!-- ] + m.tcText + [ -->] + CRLF
ENDFUNC  
* --------------------------------------------------------- *
#if .f.
10/23/2003 - revised HTMemo to use </p>'s 
           - fixed tags for XHTML compatibility
           - fixed HTLink so as to remove empty [title=""] when "" passed in
12/03/2003 - rewrote HTWrap to use GETWORDNUM(), etc.
12/27/2003 - added HTMunge() and rewrote HTEmailLink to us it *and* validate addresses
#endif
* END: L7HtmlLib.PRG
