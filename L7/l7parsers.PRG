
******************************************************
*  Program...........: L7Parsers.prg
*  Author............: Lauren Clarke
*  Project...........: L7
*  Created...........: 05/30/2002
*  Copyright.........: see LICENSE BLOCK
*  Description.......: Various text to html parsers for general <textarea to memo use
*  Unit Test.........: L7Parsers_ut.prg
*  Dependencies......: VFP7, RELATION, L7Utils, VBScript.RegExp (or equiv)
*  Assumptions.......: SET EXACT OFF    
*  Last Change.......: 12/30/2002
*  Change Log........: See end of file
******************************************************

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

Contributor(s):
1. Lauren Clarke, Cornerstone Systems NW, provided the design for the
L7 parser technology (see L7Parsers.PRG).

***** END LICENSE BLOCK *****
#ENDIF


* COMMENTS
*
*
* USAGE
* See unit test for usage
*

#DEFINE L7_USE_PARAGRAPH_PARSER .T.

#INCLUDE L7.H
#UNDEFINE L7BR
#DEFINE L7BR [<br />]

#DEFINE L7_PARSER_PLACEHOLDER_DELIM CHR(222)

#DEFINE L7_PARSER_DEBUG_OBJECTS .f.
#DEFINE L7_PARSER_DEBUG .f.  && important to turn this off for the #N# parsers etc to work

#DEFINE L7_PARSER_PERFLOG .f.

*==============================================================================
*==============================================================================
* PRODUCTION PARSING CLASS IMPLEMENTATION
*==============================================================================
*==============================================================================
* The following classes are the final implementation level of the parsing society
* they are the ones most likely to be changed as we adjust the parsing features
* we want to implement. They in turn rest on a more generic society of classes 
* defined in the next section

*==============================================================================
* PRODUCTION PARSING CHAIN MANAGER
*==============================================================================

*** ========================================================== ***
DEFINE CLASS L7Parsers as L7ParseChainManager
* This is the big boss, manages and serves up parsing chains as requested

  FUNCTION init()
    LOCAL loChain
    loChain = this.addChain( "L7ParseOnSaveChain" )       && hit this on save
    *-- set this here so we don't have to pass it to parseByName() all the time
    loChain.setall("cDefaultContext",[SAVE])                  

    loChain = this.addChain( "L7ParseOnSaveChainADMIN" )  && hit this on admin save (does not strip active content)
    loChain.setall("cDefaultContext",[SAVE])  
        
    loChain = this.addChain( "L7ParseOnViewChain" )       && hit this on view
    loChain.setall("cDefaultContext",[VIEW])  

  ENDFUNC
  
ENDDEFINE


*==============================================================================
* PRODUCTION PARSING CHAINS
*==============================================================================

*** ========================================================== ***
DEFINE CLASS L7ParseOnSaveChain as L7ParseChainAnchor
* This chain is set up for "on save" parsing. IOW, it does things
* that would be performed on raw submissions prior to save
* NOTE: Keep this in sync with ADMIN version below...
  
  FUNCTION forgeChainImplementation()
    LOCAL loChain, loTemp 
  
    this.setSuccessor( "L7StripActiveContent" )   
    this.setSuccessor( "L7FixPastedValues"    )
    this.setSuccessor( "L7DynamicMarkers"     )

    this.setContext("SAVE")  && set the default context for this chain

  ENDFUNC && forgeChainImplementation

ENDDEFINE
*-- EOC  L7ParseOnSaveChain

*** ========================================================== ***
DEFINE CLASS L7ParseOnSaveChainADMIN as L7ParseChainAnchor
* This chain is set up for "on save" parsing. IOW, it does things
* that would be performed on raw submissions prior to save
* NOTE: Keep this in sync with non-ADMIN version above
  
  FUNCTION forgeChainImplementation()
    LOCAL loChain, loTemp 
  
     this.setSuccessor( "L7DynamicMarkers" )
     
     this.setContext("SAVE")  && set the default context for this chain

  ENDFUNC && forgeChainImplementation

ENDDEFINE
*-- EOC  L7ParseOnSaveChainADMIN


*** ========================================================== ***
DEFINE CLASS L7ParseOnViewChain as L7ParseChainAnchor
* A first stab at a generalized plain text parsing chain 
* this one is set up for "viewing", iow, content would be parsed 
* by this chain on each hit.

  FUNCTION forgeChainImplementation()
  
    this.setSuccessor( "L7IgnoreParser"     )  
    This.setSuccessor( "L7FlexTableParser"  )  && must preceed paragraph/BR parsing, and old table parser (if retained)
    this.setSuccessor( "L7IgnoreHTMLParser" )
    this.setSuccessor( "L7DynamicMarkers"   )
    this.setSuccessor( "L7TranslateLinks"   )
    this.setSuccessor( "L7InternetParser"   )
    This.setSuccessor( "L7ListParser"       )
    This.setSuccessor( "L7TableParser"      )  && must preceed TextDecorations to preserve the |* => <th> metaphor
    This.setSuccessor( "L7TextDecorationParser" )
#IF L7_USE_PARAGRAPH_PARSER
    This.setSuccessor( "L7ParagraphParser"  )
#ELSE
    This.setSuccessor( "L7CRParser"         )
#ENDIF

    RETURN 
  ENDFUNC && forgeChainImplementation

ENDDEFINE
*-- EOC L7ParseOnViewChain


*==============================================================================
* PRODUCTION PARSERS
*==============================================================================


*** ========================================================== ***
DEFINE CLASS L7BreakLines as L7BaseParser
* breaks lines at spaces (where possible) to be no longer that nMaxWidth

*-- a rough first pass this...there is probably a way to do this with Regexp alone, but it escapes me.
* cPattern     = [(.{75,75})(\s)]
* cReplacement = [$1$2] + CHR(13) + CHR(10)

nMaxWidth  = 70  && lines will be broken if longer than this
cBreakChar = CHR(13) + CHR(10)

*!*    FUNCTION setMemoWidth( tnWidth )
*!*      
*!*      IF VARTYPE( tnWidth ) # "N" 
*!*        tnWidth = 0
*!*      ENDIF
*!*      
*!*      *-- defensive
*!*      IF BETWEEN( tnWidth, 8, 8192 )
*!*        SET MEMOWIDTH TO tnWidth
*!*        RETURN .t.
*!*      ELSE
*!*        RETURN .f.
*!*      ENDIF
*!*    
*!*    ENDFUNC
*!*    
* this is nice, but won't work as it will break things like ALT="This is the alt text" which will
* cause javascript errors, could be fixed, but also don't like the problems _Mline usage might cause
* with nesting
*!*    FUNCTION parse( tcText )
*!*      LOCAL lnOldMemoWidth
*!*      lnOldMemoWidth = SET("memowidth")
*!*      
*!*      IF this.setMemoWidth( this.nMaxWidth )
*!*        lcTemp = []
*!*        _MLINE = 0
*!*        FOR lnK = 1 TO MEMLINES( tcText ) - 1
*!*          lcTemp = lcTemp + MLINE( tcText, 1, _MLINE ) + this.cBreakChar
*!*        ENDFOR
*!*        lcTemp = lcTemp + MLINE( tcText, 1, _MLINE ) 
*!*      ENDIF
*!*     
*!*      tcText = lcTemp
*!*        
*!*      this.setMemoWidth( lnOldMemoWidth )
*!*    ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION carefulBreak( tcText )
    * breaks string ( delimited attribute ) assignments into separate lines
    LOCAL lnLine, lnK, lnJ, lnOccurs, lnLineLen, lcLine, laLines(1), lcDelim, lnPos, ;
          lnBreakLocation
      
    lnLines = ALINES( lalines, m.tcText)
    tcText  = []
    FOR lnK = 1 TO m.lnLines 
      lcLine    = laLines( m.lnK )
      lnLineLen = LEN( m.lcLine )
      
      IF NOT m.lnLineLen <= this.nMaxWidth AND ;
        ( (["] $ m.lcLine ) OR (['] $ m.lcLine) ) AND ;
        ( ([=] $ m.lcLine ) )
        
        *-- we worry about string assignments as they will cause client-side errors if broken
        
        *-- break at the beginning of each string assignment
        lnOccurs = OCCURS([=], m.lcLine)
        FOR lnJ = 1 TO m.lnOccurs
          *-- break at the word prior to the = 
          * eg: "<img src="test" alt="this is a test">
          *          ^          ^
          lnBreakLocation = RAT([ ],LEFT( m.lcLine, AT( [=], m.lcLine, m.lnJ ))) + 1
          lcLine          = STUFF( m.lcLine, m.lnBreakLocation , 0 , this.cBreakChar )
        ENDFOR
        
        *-- break at the end of each string assignment
        * eg: "<img src="test" alt="this is a test">
        *                     ^                    ^
        FOR lnJ = 1 TO m.lnOccurs
          lnPos   = AT( [=] , m.lcLine, m.lnJ )
          *-- not at end of line?
          IF m.lnPos < LEN( m.lcLine ) - 1 
            lcDelim  = LEFT( ALLTRIM( SUBSTR( m.lcLine, m.lnPos + 1) ), 1) && the first non-space char after the =
            *-- delimiter is valid?
            IF m.lcDelim $ ['"]
              lnEndPos = AT( m.lcDelim, SUBSTR( m.lcLine, m.lnPos ), 2)
              *-- found end of delimited region?
              IF lnEndPos > 0
                lnEndPos = m.lnEndPos + m.lnPos
                *-- break after second (closing) delimiter
                lcLine   = STUFF( m.lcLine, m.lnEndPos, 0, this.cBreakChar )
              ENDIF
            ENDIF
          ENDIF
        ENDFOR
      ENDIF 
      *-- note, dependence on strip size below
      tcText = m.tcText + m.lcLine + CHR(13) + CHR(10)      
    ENDFOR
       
    *-- strip the last crlf
    tcText = LEFT( m.tcText, LEN( m.tcText) - 2 )
  
  ENDFUNC

  * --------------------------------------------------------- *  
  FUNCTION beforeParse( tcText ) 

    *-- reset the pattern in case properties changed
    lcMaxLen          = ALLTRIM(STR(this.nMaxWidth))
    this.cPattern     = [(.{] + m.lcMaxLen + [,] + m.lcMaxLen + [})(\s)]
    this.cReplacement = [$1$2] + this.cBreakChar
    
    *-- check that we might have assignments
    IF (["] $ m.tcText OR ['] $ m.tcText) AND ([=] $ m.tcText)
      this.carefulBreak( @m.tcText )
    ENDIF
    *-- note, this does not mean we'll escape breaking any strings up, but
    *   it gives us a better chance, since all attribute assignments in lines
    *   that are over the limit will be moved into their own lines
    *   if the attribute assignments themselves are over this.nMaxWidth, we
    *   are out of luck. 
    
  ENDFUNC

ENDDEFINE

*** ========================================================== ***
DEFINE CLASS L7FixPastedValues as L7MultiParser
* finds and replaces common problem characters that arise when content from word processors (like word)
* is pasted into a textarea. This parser can help keep open content W3C valid.
* Normally, you'll probably use this parser in a "ParseOnSave" chain.

  function parse( tcText )
    
    *-- look for & NOT part of a standard encoding
    *   read: & followed by 2 or more non-whitespace chars, followed by ; ... we push to stack to get them out of harm's way
    
    this.replaceex( @tcText, "((&)(\S{2,};))", [=this.pushtoStack($1)] )

    tcText = strtran( m.tcText, [&],      [&amp;]  ) && naked apersands  
    tcText = strtran( m.tcText, chr(133), [...]    ) && elipsis
    tcText = strtran( m.tcText, chr(145), [&#145;] ) && single quote open
    tcText = strtran( m.tcText, chr(146), [&#146;] ) && single quote close
    tcText = strtran( m.tcText, chr(149), [*]      ) && this is the "bullet" from word, use in conjunction with the ListParser, maybe 183 too?
    
    tcText = strtran( m.tcText, chr(167), [&sect;] ) && this is the section symbol
    
  endfunc
      
ENDDEFINE


*** ========================================================== ***
DEFINE CLASS L7StripActiveContent as L7MultiParser
* obviously, there are different levels of scrictness we could go to here
* http://www.cert.org/tech_tips/malicious_code_mitigation.html

  FUNCTION init()

    * note, this one may cause problems when people are "allowed" to post code, say with <code lang=> delimiters with the csCodeParser
    * this stripper will cause their <script code to be pre'd and not colored (maybe?)
    this.addParse( "(\<script)((.|\n)*?)((<\/script.?\>)|$)", [="<pre>"+encodeforHTML($1+$2+$4)+"</pre>"], .t., .t., .t. )

    this.addParse( "(^|\n|\W)(\<\%)", [ &lt;&#37;], .t., .t., .f. )

  ENDFUNC
  
  FUNCTION afterParse( tcText )
    IF this.nHits > 0
      * log an admin warning here?
    ENDIF
    RETURN DODEFAULT( @m.tcText )
  ENDFUNC
ENDDEFINE

*** ========================================================== ***
DEFINE CLASS L7TranslateLinks as L7BaseParser
  * dependent on Page object for relative URL info
  **[[to do: regEx approach -- worth it??
  FUNCTION parse( tcText )

    IF ATC("<link" + L7_TRANSLATE_LINKS_DELIMITER, m.tcText) = 0
      RETURN
    ENDIF
    IF( VARTYPE( m.PAGE ) # "O" )
      RETURN
    ENDIF

    ** tcText = m.PAGE.TranslateLinks( m.tcText )
    
    * Convert text with encoded links into actual
    * hyperlinks at runtime using StuffURL as needed. Links
    * are encoded using a format like:
    *
    *     <LINK:home>Text...</LINK>
    * or  <LINK:otherPage>
    * or  <LINK:custForm:cus=12>
    * or  <LINK:custForm:cus=(this.oCus.cus_pk)> <<*** NOT AVAILABLE -- SECURITY RISK ***
    *
    * This allows portability and incorporation URL-management context.
    LOCAL lcOut, lcTemp, lcURL, lcBaseUrl, lcLinked, lcParms, lnParms, ii, ;
      lcNewPage, lnAt11, lnAt12, lnAt21, lnAtColon, lnAtColon2, ;
      lnParmLength, lnAtEqual, lcParm, lcVar, lcValue
    LOCAL ARRAY laParms[1]
    * Determine starting point for URL. 
    lcBaseURL = Page.cUrlA  
    * Process <LINK:...>..</LINK> tags:
    lcTemp = m.tcText
    lcOut = ""
    DO WHILE .T.
      lcUrl = m.lcBaseUrl  && start over for each link
      * Keep going until no more links found.
      lnAt11 = ATC( "<LINK" + L7_TRANSLATE_LINKS_DELIMITER, m.lcTemp)
      IF m.lnAt11 = 0  && No tag found -- append balance of text and exit.
        lcOut = m.lcOut + m.lcTemp
        EXIT
      ENDIF
      lnAt12 = ATC( ">", SUBSTR( m.lcTemp, m.lnAt11) )
      IF m.lnAt12 < 7  && Could not find valid closing ">" - abort.
        lcOut = m.lcOut + m.lcTemp
        EXIT
      ENDIF
      * Extract "parameters" between "<LINK:" and ">":
      lcParms = SUBSTR( m.lcTemp, m.lnAt11 + 6, m.lnAt12 - 7)
      lnParms = GETWORDCOUNT(m.lcParms, L7_TRANSLATE_LINKS_DELIMITER)
      IF m.lnParms < 1 && Invalid format--less than 1 parameter--ignore.
        lcOut = m.lcOut + m.lcTemp
        EXIT
      ENDIF
      * Extract hyper-linked text.
      lcNewPage = GETWORDNUM(m.lcParms, 1, L7_TRANSLATE_LINKS_DELIMITER)
      IF EMPTY( m.lcNewPage)
        lcOut = m.lcOut + m.lcTemp
        EXIT
      ENDIF
      lnAt21 = ATC( "</LINK>", m.lcTemp )
      IF m.lnAt21 < m.lnAt11 + m.lnAt12  && Invalid/missing closing tag - IGNORE.
        lcOut = m.lcOut + m.lcTemp
        EXIT
      ENDIF
      lcLinked = SUBSTR(m.lcTemp, m.lnAt11 + m.lnAt12, m.lnAt21 - m.lnAt11 - m.lnAt12)
      IF m.lnAt11 > 1  && Insert all text before opening <LINK> begins:
        lcOut = m.lcOut + LEFT( m.lcTemp, m.lnAt11 - 1)
      ENDIF
      * Switch to new page:
      lcUrl = StuffURL( m.lcURL, 2, m.lcNewPage)
      * Now, add any extra "parameters" to the URL:
      FOR ii = 2 TO m.lnParms
        lcParm = GETWORDNUM(m.lcParms, m.ii, L7_TRANSLATE_LINKS_DELIMITER)
        lnAtEqual = AT( "=", m.lcParm )
        IF m.lnAtEqual >= 2  && it's var=value format
          lnParmLength = LEN( m.lcParm )
          lcVar = LEFT( m.lcParm, m.lnAtEqual - 1)
          IF m.lnAtEqual = m.lnParmLength
            * no value means "strip the parameter"
            lcURL = StuffURL( m.lcURL, m.lcVar, .F. )
          ELSE
            lcValue = SUBSTR(m.lcParm, m.lnAtEqual + 1)
            *!* DON'T USE FOLLOWING--SECURITY HOLE!
            *!* IF m.lcValue = "("  && support for embedded equations
            *!*   lcValue = EVALUATE(m.lcValue)
            *!* ENDIF
            lcURL = StuffURL( m.lcURL, m.lcVar, m.lcValue)
          ENDIF
        ENDIF
      ENDFOR
      lcOut = m.lcOut + [<a href="] + m.lcUrl + [">] + m.lcLinked + [</a>]
      IF LEN( m.lcTemp) <= m.lnAt21 + LEN("</LINK>") &&  No more text after closing tag.
        EXIT
      ENDIF
      * Iterate using remainder of string:
      lcTemp = SUBSTR( m.lcTemp, m.lnAt21 + LEN("</LINK>") )
      LOOP
    ENDDO  && WHILE .T.
    tcText = m.lcOut  && supports call-by-ref

  ENDFUNC

ENDDEFINE
*-- EOC TranslateL7Links

*** ========================================================== ***
DEFINE CLASS L7InternetParser as L7MultiParser
  
  cProtocols   = "http|https|ftp|mailto" && possibly add: news|telnet|gopher
  lpushtostack = .t. && we'll get these links out of harm's way
  lencodeEmail = .t. && an anti-spam measure see: http://www.cdt.org/speech/spam/030319spamreport.shtml
  lWordWrap    = .t. && try to help make long addresses wrappable
  * --------------------------------------------------------- *
  FUNCTION INIT()

    *-- remove all existing tags likely to be clobbered by the following link parsers
    *? would this be better as part of the ignore parser? or its own parser?
    this.addparse("((<a|<img)((.|\n)*?)>)", "$1" )
    * note that the above only removes the opening tag, the contents and closing tag will be left behind for subsequent parsing

    * 7/18/2007: Experimental! Wikipedia-like external link in brackets with optional text.
    this.addparse("\[((?:" + this.cProtocols + '):[^\]\s]+)(?:\s*([^\]]*))\]',  [=this.buildBracketedLink($1,$2)])

    
    *-- links with protocols
    *? perhaps .png, .jpg, .gif etc should be parsed to <img ?
    this.addparse("((?:(?:" + this.cProtocols + '):[^\]\}(\s\|\)|\"<>]+[^\]\}(\s\|\)|\"<>\.]))',     [<a href="$1">$1</a>])
    * 7/18/07, above had been this:
    * this.addparse("((?:(?:" + this.cProtocols + '):[^\]\}(\s\|\)|\"<>]+))',     [<a href="$1">$1</a>])
    * but change made to avoind end-of-sentence period being captured.
    

    *-- mail addresses
    this.addparse("([\w\.!#\$%\-+.]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+)", [=this.buildMailLink($1)]) 
    *? alternative that might work better: ^([a-zA-Z0-9_\-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$ 
    
    *-- www. (with no protocol)
    this.addparse("(www[\.!#\$%\-+.]+[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+)", [<a href="http://$1">$1</a>])
*     this.addparse("(\W)((www.(.|\n)*?)(\s|\|))",     [$1<a href="http:\\$3">$3</a>])
    
    RETURN DODEFAULT()
    
  ENDFUNC && init

  * --------------------------------------------------------- *
  function convertToHTMLCodes( tcString )
    local lcHTMLEncoded , lnChar
    lcHTMLEncoded = ""
    for lnChar = 1 to len( tcString )
      lcHTMLEncoded = m.lcHTMLEncoded + "&#" + TRANSFORM( ASC( SUBSTR( m.tcString, m.lnChar, 1 ) ) ) + ";"
    endfor
    return m.lcHTMLEncoded 
  endfunc
  
  * --------------------------------------------------------- *
  function buildBracketedLink( tcAddress, tcText )
    LOCAL lcText
    lcText = EVL(m.tcText, m.tcAddress)
    return [<a href="]+m.tcAddress+[" title="]+m.tcAddress+[">]+m.lcText+[</a>]
   endfunc  
  * --------------------------------------------------------- *
  function buildMailLink( tcAddress )
     
     local lcHref, lcAddress
     
     lcAddress = alltrim( m.tcAddress) 
     lcHref = "mailto:" + m.lcAddress
     
     IF this.lWordWrap
       lcAddress = STRTRAN(m.lcAddress, '@', ' @ ')
     ENDIF   
     *-- shall we encode the href to throw off the harvesters?
     if this.lencodeEmail  
       lcHref    = this.convertToHtmlCodes( m.lcHref )
       lcAddress = this.convertToHTMLCodes( m.lcAddress )
     ENDIF
     return [<a href="]+m.lcHref+[">]+m.lcAddress+[</a>]
   endfunc  
  
ENDDEFINE
*-- EOC InternetParser

*** ========================================================== ***
DEFINE CLASS L7TextDecorationParser as L7MultiParser
* provides basic plain-text to html wysiwyg pattern parsing

  * --------------------------------------------------------- *
  FUNCTION init()
    * Note: Parsing will be done in the order in which the parse patterns are added
    * in some implementations, we may wish  to drive this with meta data
  
    * arguments are addParse( tcPattern, tcReplacement, [tlGlobal] , [tlIgnoreCase], [tlPushToStack] )

    *-- "Heading" parsers. H2, H3, and H4. Note: H4 must be checked first, etc.
    this.addParse( "((^|\n)(\s)*)\[\[\[\[([^\s\*].*?)\]\]\]\]",[$1<h4>$4</h4>],           .t., .t., .f. )   
    this.addParse( "((^|\n)(\s)*)\[\[\[([^\s\*].*?)\]\]\]",    [$1<h3>$4</h3>],           .t., .t., .f. )   
    this.addParse( "((^|\n)(\s)*)\[\[([^\s\*].*?)\]\]",        [$1<h2>$4</h2>],           .t., .t., .f. )   
    * Usage:
    * If any new line starts with (optional white space and then) [[, [[[, or [[[[, followed by any
    * content on the same line that doesn't start with a space or asterisk, followed by an equal number of
    * closing "]" symbols, treat as a metaphor for a level 2, 3, or 4 heading (<h?> tag).
    * [NOTE: We don't do <h1>, because [] is likely intended as something else, and there should be only one <h1>
    * tag ever on a page, which is likely coming from a different source anyway. And we don't do <h5> and <h6>
    * because of frequency-vs-performance trade-off.]

    *-- Emphasis and strikeout inline parsers:
    this.addParse( "(^|\n|\W)-{2,}([^\s|-].*?)-{2,}(\W|$)",    [$1<strike>$2</strike>$3], .t., .t., .f. )
    this.addParse( "(^|\n|\W|_)\*([^\s|\*].*?)\*(_|\W|$)",     [$1<strong>$2</strong>$3], .t., .t., .f. )
    *-- Same as above, but with 2 or more ** 
    this.addParse( "(^|\n|\W)\*{2,}([^\s].*?)\*{2,}(\W|$)",    [$1<strong><em>$2</em></strong>$3], .t., .t., .f. )
    this.addParse( "(^|\n|\W)_([^\s|_].*?)_(\W|$)",            [$1<em>$2</em>$3], .t., .t., .f. )  
    *-- Same as above, but with 2 or more _
    this.addParse( "(^|\n|\W)_{2,}([^\s].*?)_{2,}(\W|$)",      [$1<strong><em>$2</em></strong>$3], .t., .t., .f. )
    * Usage (varies somewhat for minor reasons):
    * Words wrapped with matcing symbols have the symbols replaced with HTML tags as follows:
    * --text--  == <s>       (strikethrough)
    *  *text*   == <strong>
    * **text**  == <strong><em>
    *  _text_   == <em>
    * __text__  == <strong><em>

    *-- Superscript and subscript parsers:
    this.addParse( "\^\{(.*?)\}",                              [<sup>$1</sup>],   .t., .t., .f. )  
    this.addParse( "v\{(.*?)\}",                               [<sub>$1</sub>],   .t., .t., .f. )  
    * Usage:
    * Wrapping text like ^{text} or v{text} is interpreted
    * as superscript and subscript.

    *-- "Horizontal Rule" parsers:
    this.addparse( "(^|\n)----(\s?\r|$)",                      [$1<hr size=1>$2], .t., .t., .f. )
    this.addparse( "(^|\n)====(\s?\r|$)",                      [$1<hr size=4>$2], .t., .t., .f. )
    * Usage:
    * At the beginning of any line, if ---- or ==== is followed by (optional white space and then) nothing but an end-of-line, 
    * then substitute an a thin or thick <hr> tag.
  
    RETURN DODEFAULT() 
    
  ENDFUNC && init

ENDDEFINE 
*-- EOC TextDecorationParser


* CO-OPT parser is under construction

*!*	*** ========================================================== ***
*!*	DEFINE CLASS L7SiteCoOptParser as L7MultiParser
*!*	* use this parser to change \ to / for urls (so Mozilla-based browsers, others?)


*!*	* Typicaly, the next to properties would be set from 
*!*	* Request.getCurrentUrl() and Page.cBaseQueryString prior to parsing these properties establish 
*!*	* the "context" in which the page at hand should be parsed.

*!*	 cCurrentURL         = []  && the complete url for the current hit (configured from page)
*!*	 cBaseQueryString    = []  && the Current base url that L7 is proposing for this hit (configured from page)


*!*	 oPathMaps   = NULL && collection of mappings from current url, located url to "co-opted url"
*!*	 
*!*	 
*!*	#IF .F.
*!*	So, we'll look for URLs that are relative-only and where, say, the path and extension match the current page, 
*!*	and assume that those "belong" to the site we're coopting.

*!*	I suppose you could just parse any such string and find extras, but I had thought of limiting to ;
*!*	<a href="">  and <form action="">


*!*	First, the Rule: If "same path" and "same extension" and a valid-looking relative URL, then 
*!*	attach the string from Page.cBaseQueryString.

*!*	You need 3 columns: current logical path, string in page, and result. 
*!*	Randy Pearson says:
*!*	Current LogicalPath: 		String found in page: 		Convert to:	
*!*	/virtualA/mypage.htm?stuff      /virtualA/anotherPage.htm       /virtualA/anotherPage.htm?stuff
*!*	 				                /more/virtualA/apage.htm        *LEAVE* not same path
*!*	                                /virtualA/mypage.aspx           *LEAVE*  wrong extension (however tempting)


*!*	 Anything *not* in delimiters, I imagine, should not be converted.

*!*	Randy Pearson says:


*!*	Finally, you should probably plan for the possibility of some other way of specifying which paths apply. 
*!*	Not sure where thsi would be specified. But imagine a situation where the whole web site is fair game, 
*!*	or maybe a handful of paths, or maybe all subdirs of the current, etc. Possibly a collection of path patterns?
*!*	#ENDIF

*!*	  function init()
*!*	    *-- <a followed by a set of chars (non-greedy), followed by href=, followed by some chars, 
*!*	    *    followed by " or ' or > or space
*!*	    * we send the 5th sub-match (the url) for possible co-opting


*!*	    *[[ this scheme sends the delimiters along with the URL, coOptURL() will clean them.
*!*	    * we have <a followed by word boundary followed by some sort of href = followed by either " stuff " or ' stuff ' or stuff 
*!*	    * followed by a space or >.
*!*	    
*!*	    this.addParse( strtran("(<a\b)([^\>]+)(href\s*\=\s*)(``([^``]*)``|'([^']*)'|[^\'\``\>\s]+)[\s|>]",[``],["]), ;
*!*	                   [=$1+$2+$3+this.coOptUrl( $4 )+$5],.t., .t., .f. ) 
*!*	    
*!*	    this.oPathMaps = createobject("collection")
*!*	    this.setPathMaps()
*!*	     
*!*	  endfunc

*!*	  * --------------------------------------------------------- *
*!*	  FUNCTION garbagecollect()
*!*	    dodefault()
*!*	    this.oPathMaps = NULL
*!*	  endfunc
*!*	   
*!*	  function setPathMaps()
*!*	    * hook for subclassing
*!*	  endfunc

*!*	  * --------------------------------------------------------- *  
*!*	  function addPathMap( tcCurrent, tcURLPattern, tcReplacement )
*!*	    local loMap
*!*	    loMap = createobject("empty")
*!*	    addproperty( m.loMap, [cCurrentPattern],     m.tcCurrent     )
*!*	    addproperty( m.loMap, [cUrlPattern],         m.tcURLPattern  )
*!*	    addproperty( m.loMap, [cReplacement],        m.tcReplacement )
*!*	    this.oPathMap.add( m.loMap )
*!*	  endfunc
  
*!*	  * --------------------------------------------------------- *  
*!*	  function config( toPage )
*!*	    
*!*	    this.cCurrentURL = m.toPage.cBaseURL  && NOTE!! THIS NEEDS CHANGING
*!*	    this.cBaseURL    = m.toPage.cBaseURL
*!*	  endfunc
  
*!*	  * --------------------------------------------------------- *  
*!*	  function coOptUrl( tcURL )

*!*	    local lcURL, loMap, loParse, lcDelim
*!*	    if empty( m.tcURL )
*!*	      return m.tcURL
*!*	    endif
*!*	    
*!*	    lcURL = m.tcURL

*!*	    *-- after this, lcURL will be clean (trimmed, no '" delimiters on outside) and lcDelim will contain the delimiter used (if any)
*!*	    m.lcDelim = this.cleanURL( @lcURL )
*!*	    
*!*	    *[[ opt: could hold this as a property
*!*	    loParse = createobject("L7BaseParser")    && for .m() and .s() usage

*!*	    with loParse
*!*	        .setRegExp()
*!*	        .lGlobal            = .T.              && find all occurances by default
*!*	        .lIgnoreCase        = .T.              && 
*!*	        .lMultiLine         = .F.              
*!*	        .lPushToStack       = .F.              && if .t., matches will be placed on the stack and placeholders left behind in text
*!*	    endwith

*!*	    *-- now, we loop through all the mappings to see if the current URL, combined with the current baseQS and current URL
*!*	    *   are a hit

*!*	    local lcURLPattern, lcCurrentPattern, lcReplacement
*!*	    for each loMap in this.oPathMaps
*!*	      lcURLPattern     = loMap.cURLPattern
*!*	      lcCurrentPattern = loMpa.cCurrentPattern
*!*	      lcReplacement    = strtran( loMap.cReplacement, [$BASEQS], lcBaseQS,1,5,1)
*!*	      lcCurrentURL     = this.cCurrentURL
*!*	      
*!*	      *-- does the current url match the map's pattern?
*!*	      if loParse.m( m.lcCurrentURL, m.lcCurrentPattern )
*!*	      
*!*	        *-- does the URL we've found match the map's pattern?
*!*	        *[[ is this redundant with the s() call below?
*!*	        if ! loParse.m( m.lcURL, m.lcUrlPattern )
*!*	      
*!*	        *-- at this point, we know we have found a mapping for this 
*!*	        *   url given the current querystring
*!*	      
*!*	        * /virtualA/mypage.htm?stuff      /virtualA/anotherPage.htm       /virtualA/anotherPage.htm?stuff
*!*	 
*!*	        * recall cReplacement may look something like:   "P1?C5$BASEQS"
*!*	          lcReplacement = strtran( loMap.cReplacement, [$BASEQS], lcBaseQS,1,5,1)
*!*	          lcReplacement = strtran( m.lcReplacement, [P],[$])  && this is a kluge!
*!*	          loParse.s( @lcURL, loMap.cUrlPattern, m.lcReplacement ) 
*!*	          exit
*!*	        endif
*!*	      endif
*!*	     
*!*	    endfor
*!*	    
*!*	    return m.lcDelim + m.lcURL + m.lcDelim
*!*	    
*!*	  endfunc  
*!*	       
*!*	  * --------------------------------------------------------- *     
*!*	  function cleanURL( tcURL )
*!*	  * strip " or ' or leading spaces etc from passed URL  
*!*	  * returns the delimiter (if any)
*!*	  * tcURL is passed by ref 
*!*	    *[[ this might run us into delimter nesting problems on things like onMouseClick actions etc.
*!*	    local lcRet
*!*	    tcURL = alltrim( m.tcURL )
*!*	    lcRet = substr( m.tcURL,1,1 )
*!*	    lcRet = iif(m.lcRet $ ['"],m.lcRet, [])

*!*	    if m.lcRet $ ['"]
*!*	      tcURL = substr( m.tcURL,2,len( m.tcURL)-2)
*!*	    endif
*!*	    return m.lcRet
*!*	  endfunc
*!*	  

*!*	enddefine

*!*	*** ========================================================== ***
*!*	define class L7CoOptSample as L7SiteCoOptParser

*!*	* /virtualA/mypage.htm?stuff      /virtualA/anotherPage.htm       /virtualA/anotherPage.htm?stuff

*!*	  function setPathPatterns()
*!*	    * addPathPattern( tcCurrentPattern, tcPageURLPattern, tcReplacement)
*!*	    * think: If the currentURL looks like: tcCurrentPattern,
*!*	    *        and we fine a url that looks like tcURLPattern
*!*	    *        replace tcURLPattern with tcReplacement
*!*	    *        and, you can use Cn, Pn as submatch substitutions for the Current and Page
*!*	    *        patterns respectively, also, you can use ($BASEQS) as a holder for the current
*!*	    *        BaseURL proffered by the framework (stored in this.cBaseQueryString
*!*	    this.addPathPattern("\/virtualA\/([A-Za-z0-9\-]+)(.htm)(\?)((.|\n)*)", ;
*!*	                        "(\/virtualA\/([A-Za-z0-9\-]+)(.htm))",;
*!*	                        "P1?C5$BASEQS")
*!*	  endfunc
*!*	                        
*!*	enddefine




*** ========================================================== ***
DEFINE CLASS L7FixSlashParser as L7MultiParser
* use this parser to change \ to / for urls (so Mozilla-based browsers, others?)
* will work. 
* NOTE: May want to log hits on this parser so content can be fixed properly
* but, on open content sites, this is a nice parser to have as people
* may not be aware MSIE is cutting them slack with \ chars in URI's

  function init()
    *-- <a followed by a set of chars (non-greedy), followed by href=, followed by some chars, followed by >
    * we clean the 5th submatch.
    this.addParse( "(<a )((.|\n)*?)(href=)((.|\n)*?)(>)", [=$1+$2+$4+strtran($5,"\","/")+$7],.t., .t., .f. ) 
    this.addParse( "(<img)((.|\n)*?)(src=)((.|\n)*?)(>)", [=$1+$2+$4+strtran($5,"\","/")+$7],.t., .t., .f. ) 
    
   *[[ do we need <form here ?, probably a bad habit-forming thing.)
  endfunc
enddefine
  
*** ========================================================== ***
DEFINE CLASS L7IgnoreHTMLParser as L7MultiParser
* use this class when parsing "in traffic" that is, parsing text that 
* may already include some html eg: <!--Don't strike me--> etc.
*
* This parser should be placed prior to L7IgnoreParser in the chain.
*
* Note there is some dependency betwen this parser and the CR parser, the CR parser selectively
* places <br>'s at ends of lines, but it does NOT do so for <tr, td etc... this parser needs to be
* careful to leave enough of the tag behind so the CR parser can know if it needs to place a <br> or not. 

 
  FUNCTION init()
    * arguements are addParse( tcPattern, tcReplacement, [tlGlobal] , [tlIgnoreCase], [tlPushToStack] )
    
    *-- script snippets
    this.addParse( "(<script)((.|\n)*?)(</script)", [=$1+THIS.pushToStack($2)+$4],.t., .t., .f. ) 
 
    *-- PRE
    this.addParse( "(<pre)((.|\n)*?)(</pre)", [=$1+THIS.pushToStack($2)+$4],.t., .t., .f. ) 

    *-- comments
    this.addParse( "(<!-)((.|\n)*?)(->)",    [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. )   
    *-- anchors
    this.addParse( "(<a )((.|\n)*?)(</a>)",     [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. )   
    *-- table tags
    this.addParse( "(<table )((.|\n)*?)(>)", [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    this.addParse( "(<tr )((.|\n)*?)(>)",    [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    this.addParse( "(<td )((.|\n)*?)(>)",    [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    this.addParse( "(<th )((.|\n)*?)(>)",    [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    *-- img etc
    this.addParse( "(<img)((.|\n)*?)(>)",    [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    this.addParse( "(<ol )((.|\n)*?)(>)",    [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    this.addParse( "(<ul )((.|\n)*?)(>)",    [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    this.addParse( "(<li )((.|\n)*?)(>)",    [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    *-- span div etc
    this.addParse( "(<span )((.|\n)*?)(>)",  [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    this.addParse( "(<div )((.|\n)*?)(>)",   [=$1+THIS.pushToStack($2)+$4],           .t., .t., .f. ) 
    *-- style
    this.addParse( "(<style)((.|\n)*?)(</style)",  [=$1+THIS.pushToStack($2)+$4],     .t., .t., .f. ) 

    *-- form stuff
    this.addParse( "(<form)((.|\n)*?)(>)",              [=$1+THIS.pushToStack($2)+$4],.t., .t., .f. ) 
    this.addParse( "(<textarea)((.|\n)*?)(</textarea)", [=$1+THIS.pushToStack($2)+$4],.t., .t., .f. ) 
    this.addParse( "(<input)((.|\n)*?)(>)",             [=$1+THIS.pushToStack($2)+$4],.t., .t., .f. ) 
    this.addParse( "(<select)((.|\n)*?)(</select)",     [=$1+THIS.pushToStack($2)+$4],.t., .t., .f. ) 
    this.addParse( "(<button)((.|\n)*?)(</button)",     [=$1+THIS.pushToStack($2)+$4],.t., .t., .f. )    
        
    RETURN DODEFAULT()
  ENDFUNC
ENDDEFINE

*** ========================================================== ***
DEFINE CLASS L7CRParser as L7BaseParser
* provides <br's> for carriage returns
* due to lack of good lookbehind assertion grouping in vbscript, we'll 
* take the ALINES() route here.

  * tags we don't want to put <br> behind
  * use lowercase, both opening and closing tags will be blocked
  * ie, <table and </table will be blocked if |table| appears in the list
  cDisallowedEndingTags = [|table|tr|td|th|caption|ol|li|ul|hr|br|ig|p|div|!|h1|h2|h3|h4|-|script|style|pre|col|colgroup|thead|tbody|]
  
  *-- we won't add any <br> in blank lines following these tags, note you must
  *-- include both open and close tags here as needed
  cDisallowedFollowTags = [table,tr,/tr,td,/td,th,/th,p,/p]
  *-- note that we do allow <br>s after tables
  
  cBRTag = L7BR 
  
  * --------------------------------------------------------- *  
  FUNCTION isPatternPresent( tcText )
  RETURN !EMPTY( m.tcText )
  
  * --------------------------------------------------------- *
  FUNCTION tagOKForBR( tcTag )
    LOCAL llRetVal
    llRetval = ! ( [|] + ALLTRIM( LOWER( m.tcTag ) ) + [|] $ this.cDisallowedEndingTags )
    RETURN m.llRetVal
  ENDFUNC && tagOKForBR
  
  * --------------------------------------------------------- *  
  FUNCTION parse( tcText )
    *-- note: tcText is passed by reference

    LOCAL lnTotLines, laLines(1), lcLine, lcParsedText, llValidLine, lcTag, lnLastTag, lnLine, lcWholeTag, lcBRTag
    
    lcBRTag         = this.cBRTag
    lnTotLines      = ALINES( m.laLines, m.tcText )
    lcParsedText    = []
    lcTag           = [~]    && placeholder for first pass.
    lcWholeTag      = [~]
    
    FOR m.lnLine= 1 TO m.lnTotLines
    
      lcLine      = laLines( m.lnLine )  
      llValidLine = .t.  
      llValidLine = NOT( EMPTY( m.lcLine ) AND ;
                    m.lcWholeTag $ this.cDisallowedFollowTags )
      *---since the HTMLIgnore parser may be yanking things we should not
      *   be placing a <br> behind, we need to avoid the placeholder (left by HTMLIgnore)
      *   this can be a problem if *other* parsers yank stuff we *do* want to <br>
      *   Testing changes.. HTMLIgnore now leaves the tag tailings so CR parser can decide.
*      llValidLine = llValidLine and NOT( RIGHT( ALLTRIM( m.lcLine ), 1) = PLACEHOLDER_DELIM )
      
      IF llValidLine AND RIGHT( ALLTRIM( m.lcLine ), 1) = [>] 
          *-- does line end with a tag?    
          lnLasttag = OCCURS([<], m.lcLine)
        
          IF m.lnLastTag>0
            lcTag = STREXTRACT( ALLTRIM(m.lcLine) + [*], [<], [>*], m.lnLastTag)   
            lcWholeTag = GETWORDNUM( m.lcTag, 1) && includes possible leading / char 
            lcTag = IIF( m.lcTag = "/", SUBSTR( m.lcTag, 2 ), m.lcTag)
            
            lcTag = IIF( m.lcTag = "!", LEFT( m.lcTag, 1 ), m.lcTag)
            lcTag = GETWORDNUM( m.lcTag, 1)
            llValidLine = this.tagOKforBR( m.lctag )
          ENDIF
      ENDIF 
        
      *-- llValidLine will be .t. if this doesn't end with a bad tag
      lcParsedText = m.lcParsedText + ;
                     m.lcLine + ;
                     IIF( m.llValidLine and m.lnLine < m.lntotLines, m.lcBRTag, [] ) + CRLF 
          
    ENDFOR  
    tcText = m.lcParsedText

  ENDFUNC && parse
    
ENDDEFINE 
*-- EOC CRParser


*** ========================================================== ***
DEFINE CLASS L7ParagraphParser as L7BaseParser
* provides <p's> and <br's> for carriage returns
* due to lack of good lookbehind assertion grouping in vbscript, we'll 
* take the ALINES() route here.

  * tags we don't want to put <br> behind
  * use lowercase, both opening and closing tags will be blocked
  * ie, <table and </table will be blocked if |table| appears in the list
  cDisallowedEndingTags = [|table|tr|td|th|caption|ol|li|ul|hr|br|ig|p|div|!|h1|h2|h3|h4|-|script|style|pre|col|colgroup|thead|tbody|]
  
  *-- we won't add any <br> in blank lines following these tags, note you must
  *-- include both open and close tags here as needed
  cDisallowedFollowTags = [table,tr,/tr,td,/td,th,/th,p,/p]
  *-- note that we do allow <br>s after tables
  
  cBRTag = L7BR 
  
  lSingleCrDenotesParagraph = .F. && .F. means 2 CR's are required for a <p>, single means <br>
  lLastLineIsParagraph = .T.      && treat last line as <p> even though not an extra CR at end
  
  * --------------------------------------------------------- *  
  FUNCTION isPatternPresent( tcText )
  RETURN !EMPTY( m.tcText )
  
  * --------------------------------------------------------- *
  FUNCTION tagOKForBR( tcTag )
    LOCAL llRetVal
    llRetval = ! ( [|] + ALLTRIM( LOWER( m.tcTag ) ) + [|] $ this.cDisallowedEndingTags )
    RETURN m.llRetVal
  ENDFUNC && tagOKForBR
  
  * --------------------------------------------------------- *  
  FUNCTION parse( tcText )
    *-- note: tcText is passed by reference

    LOCAL lnTotLines, laLines(1), lcLine, lcNextLine, lcParsedText, llValidLine, lcTag, ;
      lnLastTag, lnLine, lcWholeTag, lcBRTag, llIsBr, llWasBr
    
    lcBRTag         = this.cBRTag
    lnTotLines      = ALINES( m.laLines, m.tcText )
    lcParsedText    = []
    lcTag           = [~]    && placeholder for first pass.
    lcWholeTag      = [~]
    
    FOR m.lnLine= 1 TO m.lnTotLines
    
      lcLine      = laLines( m.lnLine )  
      llValidLine = .t.  
      llValidLine = NOT( EMPTY( m.lcLine ) AND ;
                    m.lcWholeTag $ this.cDisallowedFollowTags )
      *---since the HTMLIgnore parser may be yanking things we should not
      *   be placing a <br> behind, we need to avoid the placeholder (left by HTMLIgnore)
      *   this can be a problem if *other* parsers yank stuff we *do* want to <br>
      *   Testing changes.. HTMLIgnore now leaves the tag tailings so CR parser can decide.
*      llValidLine = llValidLine and NOT( RIGHT( ALLTRIM( m.lcLine ), 1) = PLACEHOLDER_DELIM )
      
      IF llValidLine AND RIGHT( ALLTRIM( m.lcLine ), 1) = [>] 
          *-- does line end with a tag?    
          lnLasttag = OCCURS([<], m.lcLine)
        
          IF m.lnLastTag>0
            lcTag = STREXTRACT( ALLTRIM(m.lcLine) + [*], [<], [>*], m.lnLastTag)   
            lcWholeTag = GETWORDNUM( m.lcTag, 1) && includes possible leading / char 
            lcTag = IIF( m.lcTag = "/", SUBSTR( m.lcTag, 2 ), m.lcTag)
            
            lcTag = IIF( m.lcTag = "!", LEFT( m.lcTag, 1 ), m.lcTag)
            lcTag = GETWORDNUM( m.lcTag, 1)
            llValidLine = this.tagOKforBR( m.lctag )
          ENDIF
      ENDIF 
        
      *-- llValidLine will be .t. if this doesn't end with a bad tag
      *-- NOTE: Some repitition (and even magic strings) below, while we work out the logic and options...
      IF NOT m.llValidLine
        lcParsedText = m.lcParsedText + m.lcLine + CRLF
      ELSE
        IF m.lnLine >= m.lntotLines  && last line
          IF THIS.lSingleCrDenotesParagraph OR (THIS.lLastLineIsParagraph AND NOT m.llWasBr)
            lcParsedText = m.lcParsedText + [<p>] + m.lcLine + [</p>] + CRLF
          ELSE
            lcParsedText = m.lcParsedText + m.lcLine + CRLF  && no <br /> for last line
          ENDIF
        ELSE  && not last line; we'll "peek"
          lcNextLine = laLines( m.lnLine + 1)
          IF NOT EMPTY(m.lcNextLine)  && something comes next
            IF THIS.lSingleCrDenotesParagraph 
              lcParsedText = m.lcParsedText + [<p>] + m.lcLine + [</p>] + CRLF
            ELSE
              llIsBr = .T.
              lcParsedText = m.lcParsedText + m.lcLine + m.lcBRTag + CRLF  
            ENDIF
          ELSE && key case: 2 successive CRs (this needs work, proabably additional options necessary)
            lcParsedText = m.lcParsedText + [<p>] + m.lcLine + [</p>] + CRLF
            * For now, we'll trick the loop to skip over the next (empty) line:
            lnLine = m.lnLine + 1
          ENDIF
        ENDIF
      ENDIF
      
      llWasBr = m.llIsBr
      llIsBr = .F.
      
*!*        lcParsedText = m.lcParsedText + ;
*!*                       m.lcLine + ;
*!*                       IIF( m.llValidLine and m.lnLine < m.lntotLines, m.lcBRTag, [] ) + CRLF 
          
    ENDFOR  
    tcText = m.lcParsedText

  ENDFUNC && parse
    
ENDDEFINE 
*-- EOC ParagraphParser


*** ========================================================== ***
DEFINE CLASS L7TemplateParser as L7BaseParser

  cPattern     = "<%=((.)*?)%>"
  cReplacement = [=transform(evaluate($1))]

ENDDEFINE



*** ========================================================== ***
DEFINE CLASS L7IgnoreParser as L7BaseParser

  lPushToStack = .t.
  *-- note the non-greedy capture
  cPattern     = "<ig>((.|\n)*?)</ig>"
  cReplacement = "$1"

ENDDEFINE

*** ========================================================== ***
DEFINE CLASS L7FlexTableParser as L7BaseParser
  cPattern = .F.  && '(?:^|\n)\{\|([^\n]*)'
  oHelpers = NULL  
  cTableAttribs = [class="parsedtable"]  
  * --------------------------------------------------------- *
  FUNCTION garbagecollect()
 
    DODEFAULT()  && see L7CORLink, triggers recusion in successor chain
    THIS.oHelpers = NULL
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION addHelpers
    THIS.oHelpers = CREATEOBJECT("Collection")
    WITH this.oHelpers
      .Add(this.CreateHelperRegEx( '(?:^|\n)\{\|([^\n]*)',        .T., .F., .T.), "Tbl")     && {|       : table start
      .Add(this.CreateHelperRegEx( '\n\|\}',                      .T., .F., .T.), "Tbl2")    && |}       : table end
      .Add(this.CreateHelperRegEx( '(?:^|\n)\|\+[^\+]([^\|\n]*)', .F., .F., .T.), "Caption") && |+       : caption
      .Add(this.CreateHelperRegEx( '(?:^|\n)\|\+\+([^\|\n]*)',    .F., .F., .F.), "Summary") && |++      : summary

      .Add(this.CreateHelperRegEx( '(?:^|\n)\|:((?:.|\n)*?)(?:\n:\|)', .F., .F., .T.), "Style") && |: ... :| : style
      .Add(this.CreateHelperRegEx( '#?\bthis\b',                  .T., .T., .T.), "this")    && this{} in style blocks

      .Add(this.CreateHelperRegEx( '(?:^|\n)\|(\({1,2})([^\|\n]*)', .T., .F., .F.), "Cols")  && |( or |((: col or colgroup
      
      .Add(this.CreateHelperRegEx( '(?:^|\n)(\||!)-([^\|!]*)',    .T., .F., .T.), "Row")     && |- or !-): new row
      .Add(this.CreateHelperRegEx( '(^|\n)(\||!)|(!{2})|(\|{2})', .T., .F., .T.), "Cells")   && | or !   : cells
      .Add(this.CreateHelperRegEx( '^(?:([^|]*)\|)?((?:.|\n)*)$', .T., .F., .T.), "Cell")    && intra-cell support for attribs first
    ENDWITH
    RETURN
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION CreateHelperRegEx(tcPattern, tlGlobal, tlIgnoreCase, tlMultiLine)
    LOCAL loObj
    loObj = THIS.getObjectRef( THIS.cRegExpClass )
    loObj.Multiline = m.tlMultiLine
    loObj.Global = m.tlGlobal
    loObj.IgnoreCase = m.tlIgnoreCase
    loObj.Pattern = m.tcPattern
    RETURN m.loObj
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION isPatternPresent( tcText )
    LOCAL llRetval
    llRetval = "{|" $ m.tcText 

    RETURN m.llRetval
  
  ENDFUNC && isPatternPresent
  * --------------------------------------------------------- *
  FUNCTION parse( tcText )
    *-- note: tcText is passed by reference
    * Quick bail if no table marker present:
    IF AT('{|', m.tcText) = 0 OR AT('|}', m.tcText) = 0
      RETURN 
    ENDIF 
    
    * Setup helper objects: [[look into optimizing this for persistence in chains ...]]
    this.addHelpers()
    PRIVATE poREs && remove this later...
    poREs = this.oHelpers
    
    LOCAL lcWork, llExit, lnLoopControl
    lnLoopControl = NULL  && avoid endless loop, if we don't pull {| out of text
    lcWork = m.tcText
    
    * NOTE: The major complexity below is for handling nested tables (tables within a cell of an outer table)
    *  An "inner-most table first" strategy is used, rather than recursion.
    DO WHILE NOT m.llExit
      loTbls = poREs.item("Tbl").Execute(m.lcWork)
      IF loTbls.Count = 0
        EXIT
      ENDIF 
      IF ISNULL(m.lnLoopControl)  && 1st table
        lnLoopControl = loTbls.Count
      ENDIF
      loTbls2 = poREs.item("Tbl2").Execute(m.lcWork)
      IF loTbls2.Count <> loTbls.Count  && different number of table close/open markers
        EXIT
      ENDIF 
      
      * Parse the first leaf table available, then repeat. The leaf is the
      * table defined by the first closing tag, and the closest preceeding opening tag.
      loTbl2 = loTbls2.item[0]
      lnTbl2Pos = loTbl2.FirstIndex
      loTbl = NULL  
      FOR ii = 1 TO loTbls.Count
        loTemp = loTbls.item[m.ii - 1]
        IF loTemp.FirstIndex < m.lnTbl2Pos
          loTbl = loTemp && set this one, but keep looking
          LOOP 
        ELSE
          EXIT 
        ENDIF 
      NEXT ii
      IF ISNULL(loTbl)  && no table open before first table close
        EXIT
      ENDIF
      llExit = NOT this.ParseTable(@lcWork, loTbl, loTbl2)
      lnLoopControl = m.lnLoopControl - 1 
      IF m.lnLoopControl < 1
        EXIT
      ENDIF 
    ENDDO 
    
    tcText = m.lcWork  && substitute back (due to pass-by-reference)
    RETURN 
  ENDFUNC 

  * --------------------------------------------------------- *
  FUNCTION ParseTable(lcWork, loTbl, loTbl2)
    LOCAL loRowMtchs, lcInner, lcFront, lcOut, loMtch, lnPrevStart, lnPrevLen, ;
      lnRows, lnRow, lcRowStuff, lcEarlyRow, ;
      llHeadRows, llHeadRow, lcStyle, lcCaption, lcTableAttr, lcTemp
      
    lcInner = SUBSTR(m.lcWork, loTbl.FirstIndex + 1 + loTbl.Length, ;
        loTbl2.FirstIndex - loTbl.FirstIndex - loTbl.Length)
    loRowMtchs = poREs.item("Row").Execute(m.lcInner)
    lnRows = loRowMtchs.Count
    llHeadRows = NULL
    
    lcStuffOnLine1 = ALLTRIMX(NVL(loTbl.Submatches[0], ""))
    IF m.lnRows > 0
      lcStuffBeforeRow1 = ALLTRIM(LEFT(m.lcInner, loRowMtchs.item[0].FirstIndex))
    ELSE  && no rows -- we'll treat as 1-cell table, so we do *something* with apparent table directives
      lcStuffBeforeRow1 = ""
    ENDIF 

    * build <table> tag:
    ** lcOut = [<table] 
    STORE "" TO lcOut, lcTableAttr, lcStyle, lcCaption
    IF NOT EMPTY(this.cTableAttribs)
      lcTableAttr = m.lcTableAttr + [ ] + this.cTableAttribs
    ENDIF 
    IF NOT EMPTY(m.lcStuffOnLine1)
      lcTableAttr = m.lcTableAttr + [ ] + m.lcStuffOnLine1
    ENDIF 
    * [[might need conflict resolution for above 2 options]]
    
    * This was "cheap" to allow unstyled tables to have visual borders, but just looks "old"...
    *!*      IF NOT "border" $ LOWER(m.lcOut)
    *!*        lcOut = m.lcOut + [ border="1"]
    *!*      ENDIF 

    * Summary attribute, optional, triggered by new line with |++ (compare w/ caption)
    IF '|++' $ m.lcStuffBeforeRow1 
      LOCAL loSummMtchs, loSummMtch
      loSummMtchs = poREs.item("Summary").Execute(m.lcStuffBeforeRow1)
      IF loSummMtchs.Count > 0
        loSummMtch = loSummMtchs.item[0]
        lcTableAttr = m.lcTableAttr + [ summary="] + AllTrimX(NVL(loSummMtch.Submatches[0], "")) + ["] 
        * strip the match, to support parsing for cells here
        lcStuffBeforeRow1 = STUFF(m.lcStuffBeforeRow1, loSummMtch.FirstIndex + 1, loSummMtch.Length, "")
      ENDIF
    ENDIF
    
*!*      * End of <table> tag:
*!*      lcOut = m.lcOut + [>] + CRLF


    * <style> section with support for #this as ID swap, triggered by |: and :| 
    IF '|:' $ m.lcStuffBeforeRow1 
      LOCAL loStyleMtchs, loStyleMtch, lcID
      loStyleMtchs = poREs.item("Style").Execute(m.lcStuffBeforeRow1)
      IF loStyleMtchs.Count > 0
        loStyleMtch = loStyleMtchs.item[0]
        lcTemp = NVL(loStyleMtch.Submatches[0], "")
        IF "this" $ LOWER(m.lcTemp)
          lcID = "tbl" + SYS(3)
          ** lcTemp = STRTRAN(m.lcTemp, "#this", "#" + m.lcId)
          lcTemp = poREs.item("this").Replace(m.lcTemp, "#" + m.lcId)
          lcTableAttr = [id="] + m.lcID + [" ] + m.lcTableAttr
        ENDIF 
        lcStyle = CRLF + [<style type="text/css">] + CRLF + m.lcTemp + CRLF + [</style>] + CRLF
        
        * strip the match, to support parsing for cells here
        lcStuffBeforeRow1 = STUFF(m.lcStuffBeforeRow1, loStyleMtch.FirstIndex + 1, loStyleMtch.Length, "")
      ENDIF
    ENDIF
    
    * Caption element, optional, triggered by new line with |+ 
    IF '|+' $ m.lcStuffBeforeRow1 
      LOCAL loCaptMtchs, loCaptMtch
      loCaptMtchs = poREs.item("Caption").Execute(m.lcStuffBeforeRow1)
      IF loCaptMtchs.Count > 0
        loCaptMtch = loCaptMtchs.item[0]
        lcCaption = m.lcCaption + [<caption>] + AllTrimX(NVL(loCaptMtch.Submatches[0], "")) + [</caption>] + CRLF
        * strip the caption match, to support parsing for cells here
        lcStuffBeforeRow1 = STUFF(m.lcStuffBeforeRow1, loCaptMtch.FirstIndex + 1, loCaptMtch.Length, "")
      ENDIF
    ENDIF
    
    * Build early stuff:
    lcOut = m.lcOut + m.lcStyle + [<table ] + m.lcTableAttr + [>] + CRLF + m.lcCaption

    * Col or Colgroup:
    IF '|(' $ m.lcStuffBeforeRow1 
      lcOut = m.lcOut + THIS.parseColDefs(@lcStuffBeforeRow1 )
    ENDIF 
    
    * TEST: try parsing stuff before first row boundary in case cells are there:
    lcEarlyRow = THIS.ParseRow(m.lcStuffBeforeRow1)
    IF NOT EMPTY(m.lcEarlyRow)
      llHeadRows = .F.
      lcOut = m.lcOut + [<tbody>] + CRLF + [<tr>] + m.lcEarlyRow + [</tr>] + CRLF
    ENDIF 
    
    * Row-by-row:
    IF m.lnRows = 0  && user forgot rows, create 1-cell table
      lcOut = lcOut + [<tbody><tr><td>] + m.lcInner + [</td></tr>] + CRLF
    ELSE 
      FOR lnRow = 1 TO m.lnRows
        loMtch = loRowMtchs.item[m.lnRow - 1]
        llHeadRow = loMtch.Submatches[0] = "!" && |- vs. !- to designate <thead>
        DO CASE
        CASE ISNULL(m.llHeadRows)  && first row of any type
          IF m.llHeadRow
            lcOut = m.lcOut + [<thead>] + CRLF
            llHeadRows = .T.
          ELSE 
            lcOut = m.lcOut + [<tbody>] + CRLF
            llHeadRows = .F.
          ENDIF 
        CASE m.llHeadRows AND NOT m.llHeadRow  && switch
          lcOut = m.lcOut + [</thead>] + CRLF + [<tbody>] + CRLF
          llHeadRows = .F.
        ENDCASE 
        
        lcRowStuff = NVL(loMtch.Submatches[1], "")
        IF m.lnRow = m.lnRows  && last row
          lcContent = SUBSTR(m.lcInner, loMtch.FirstIndex + 1 + loMtch.Length)
        ELSE
          lcContent = SUBSTR(m.lcInner, loMtch.FirstIndex + 1 + loMtch.Length, ;
            loRowMtchs.item[m.lnRow].FirstIndex - loMtch.FirstIndex - loMtch.Length)
        ENDIF 
        lcOut = m.lcOut + [<tr ] + m.lcRowStuff + [>] + THIS.ParseRow(m.lcContent) + [</tr>] + CRLF
      ENDFOR 
    ENDIF 

    lcOut = lcOut + [</tbody>] + CRLF + [</table>] + CRLF
    lcWork = STUFF(m.lcWork, loTbl.FirstIndex + 1, ;
      loTbl2.FirstIndex - loTbl.FirstIndex + loTbl2.Length, ;
      m.lcOut)
      
    RETURN 
  ENDFUNC 

  * --------------------------------------------------------- *
  FUNCTION ParseRow(lcRow)
    LOCAL lcOut, loCellsMtchs, loCellMtchs, loCellDelim, loCellParts, lcTag, lcInner
    lcOut = ""
    loCellsMtchs = poREs.item("Cells").Execute(m.lcRow)
    FOR lnCell = 1 TO loCellsMtchs.Count
      loCellDelim = loCellsMtchs.item[m.lnCell - 1]
      lcTag = IIF("!" $ loCellDelim.Value, "th", "td")
      lnStart = loCellDelim.FirstIndex + 1 + loCellDelim.Length
      IF lnCell = loCellsMtchs.Count
        lnEnd = LEN(m.lcRow)
      ELSE
        lnEnd = loCellsMtchs.item[m.lnCell].FirstIndex
      ENDIF 
      lcInner = SUBSTR(m.lcRow, m.lnStart, m.lnEnd - m.lnStart + 1)
      loCellMtchs = poREs.item("Cell").Execute(m.lcInner)
      loCellParts = loCellMtchs.item[0]
      lcOut = m.lcOut + [<] + m.lcTag + [ ] + NVL(loCellParts.Submatches[0], '') + [>] + CRLF + ;
        NVL(loCellParts.Submatches[1], "") + [</] + m.lcTag + [>] + CRLF
    ENDFOR
    RETURN m.lcOut
  ENDFUNC 

  * --------------------------------------------------------- *
  FUNCTION parseColDefs(tcIn)
    LOCAL lnMtch, loMtchs, loMtch, lcOut, llInGroup
    lcOut = ""
    DO WHILE .t. 
      loMtchs = poREs.item("Cols").Execute(m.tcIn)
      IF loMtchs.Count = 0
        EXIT
      ENDIF
      loMtch = loMtchs.item[0]
      IF loMtch.Submatches[0] == "(("  && colgroup
        lcOut = m.lcOut + IIF(m.llInGroup, [</colgroup>] + CRLF, []) + ;
          [<colgroup ] + AlltrimX(NVL(loMtch.Submatches[1], "")) + [>] + CRLF
        llInGroup = .T.
      ELSE
        lcOut = m.lcOut + [<col ] + AlltrimX(NVL(loMtch.Submatches[1], "")) + [></col>] + CRLF
      ENDIF
      tcIn = STUFF(m.tcIn, loMtch.FirstIndex + 1, loMtch.Length, "")
    ENDDO 
    IF m.llIngroup
      lcOut = m.lcOut + [</colgroup>] + CRLF
    ENDIF 
    RETURN m.lcOut
  ENDFUNC 
ENDDEFINE

*** ========================================================== ***
DEFINE CLASS L7TableParser as L7BaseParser
* Simple single-row in a cell parser 

  cFormatRowChar= [>]           && rows starting with this will be used to set column formats only
  cDelimChar    = [|]
  cTableAttribs = [class="parsedtable"]  && was [border="1"]
  cBRTag        = L7BR 
  lMultiLine    = .t.
  
  * --------------------------------------------------------- *
  FUNCTION isPatternPresent( tcText )
    
    LOCAL llRetval, lcDelim
    lcDelim = this.cDelimChar
   
    llRetval = AT( CHR(10) + m.lcDelim, CHR(10) + m.tcText ) + ;
               AT( CHR(13) + m.lcDelim, m.tcText + CHR(13) ) ;
               > 0

    RETURN m.llRetval
  
  ENDFUNC && isPatternPresent
  
  * --------------------------------------------------------- *
  FUNCTION buildCellAttribs( tcCellType, tcAttribShortHand )
    LOCAL lcColSpan, lcRowSpan, lcAlignment, lcAttribs
    
    *-- extract only the digits
    lcColSpan = CHRTRAN( m.tcAttribShortHand, CHRTRAN( m.tcAttribShortHand, "1234567890,", []),[])
    lcRowSpan = GETWORDNUM( m.lcColSpan, 2, [,])
    lcColSpan = GETWORDNUM( m.lcColSpan, 1, [,])
    lcColSpan = IIF( VAL( m.lcColSpan ) > 0, m.lcColSpan, "1")
    lcRowSpan = IIF( VAL( m.lcRowSpan ) > 0, m.lcRowSpan, "1")
    
    *? there is a caseif util in L7?...
    lcAlignment = IIF("center" $ m.tcAttribShortHand,"center", ;
                      IIF( "left" $ m.tcAttribShortHand, "left" , ;
                           IIF( "right" $ m.tcAttribShortHand, "right", "")))
    
    lcAttribs = " colspan="+m.lcColSpan+" rowspan=" + m.lcRowSpan + " " + ;
                IIF( !EMPTY( m.lcAlignment ), [style="text-align: ]+m.lcAlignment+[;"],[])
    
    RETURN STRTRAN( m.tcCellType, [>], m.lcattribs+[>])
                
  ENDFUNC  &&buildCellAttribs
  
  * --------------------------------------------------------- *
  FUNCTION buildRow( tcRow )
    
    LOCAL lcDelim, lcRetVal
    lcDelim = this.cDelimChar

    *-- strip start and end delimiters    
    IF RIGHT( m.tcRow , 1 ) = m.lcDelim
      tcRow = LEFT( m.tcRow, LEN( m.tcRow ) -1 )
    ENDIF
    
    IF tcRow = m.lcDelim
      tcRow = SUBSTR( m.tcRow, 2)
    ENDIF
  
    *-- build the row
    lcRetVal = [<tr>] + CRLF + ; 
               [<td>] + ;
               STRTRAN( m.tcRow, m.lcDelim, [</td>] + CRLF + [<td>] ) + ;
               [</td>] + CRLF + ;
               [</tr>]
  
    *-- deal with th metaphor
    this.replaceex( @m.lcRetVal, "<td>\*([^\s\*].*?)\*(\s*)</td>","<th>$1</th>")

    *-- splice in any attributes eg: {center, 2} for center, colspan=2

    this.replaceex( @m.lcRetVal, "(<td>|<th>)\{([^\s\*].*?)\}","=this.buildcellattribs($1,$2)" )
   
    RETURN m.lcRetVal 
    
  ENDFUNC  && buildRow
  
  * --------------------------------------------------------- *
  FUNCTION parse( tcText )
    *-- note: tcText is passed by reference
    
    LOCAL lnTotLines, laLines(1), lnLine, llTableOpen, ;
          lcDelim, lcParsedText, lcParsedLine, lcLine, lnLine, ;
          lcFormatRowChar

    *-- look for and replace line-continuation markup
    this.replaceex( @m.tcText, "~\r\n", this.cBrTag )

    lnTotLines      = ALINES( laLines, m.tcText )
    llTableOpen     = .f.
    lcDelim         = this.cDelimChar
    lcFormatRow     = this.cFormatRowChar+this.cDelimChar
    lcParsedText    = []
    lcParsedLine    = []
    
    FOR lnLine= 1 TO m.lnTotLines

      lcLine = laLines( m.lnLine )

      DO CASE
      
        *-- are we closing the table?
        CASE m.llTableOpen AND ;
             ALLTRIM( m.lcLine ) # m.lcDelim AND ;
             ALLTRIM( m.lcLine ) # m.lcFormatRow

          lcParsedLine = [</table>] + CRLF + m.lcLine 
          llTableOpen  = .f.
          
        *-- are we opening a table or in a table?
        CASE m.llTableOpen OR ;
             ALLTRIM( m.lcLine ) = m.lcDelim OR ;
             ALLTRIM( m.lcLine ) = m.lcFormatRow
        
          lcParsedLine = this.buildRow( m.lcLine )
           
           IF !m.llTableOpen
             lcParsedLine = [<table] + ;
               IIF(EMPTY(this.cTableAttribs), [], [ ] + this.cTableAttribs) + ;
               [>] + CRLF + m.lcParsedLine
             llTableOpen  = .t.
           ENDIF
           
        *-- no table, move on
        OTHERWISE
          
          lcParsedLine = m.lcLine
          
      ENDCASE
      lcParsedText = m.lcParsedText + m.lcParsedLine + CRLF

    ENDFOR
  
    *-- make sure we close even if the text ends with a table
    IF llTableOpen 
      lcParsedText = m.lcParsedText + [</table>]
    ENDIF

    tcText = m.lcParsedText   
  
    ENDFUNC  && parse

ENDDEFINE
*-- EOC TableParser



*** ========================================================== ***
DEFINE CLASS L7FileDownloadLinkParser as L7BaseParser
* links filenames to files the current pattern links filenames that start with / or \ 
* subdirs may be used eg: \dir\file.doc or \file.doc

  *? not completely written yet.... 

  *? some browser-based behaviours might be needed to deal with / vs \ in the hrefs

  *? make extensions configurable
  cPattern        = "\s(\/|\\)([^\s\/].*?)\.(jpg|gif|jpeg|mp3|wav|bmp|png|htm|html|ppt|doc|pdf|zip|xls|txt)"
  cReplacement    = [=this.buildLink($2,$3)]
  cHomeDir        = []   && root dir, all files will be searched for relative to this dir
  cVirtualHomeDir = []   && links to filenames may use this to set relative path

  * --------------------------------------------------------- *
  FUNCTION buildLink( tcStem, tcExtension )
    LOCAL lcRet, lcFilename

    *-- quick bail on bad extension  
    IF ! this.isValidExtension( tcExtension )
      RETURN m.lcFileName
    ENDIF
   
    IF this.isFileFound( this.buildFileName( m.tcStem, m.tcExtension ) )
      lcRet = this.fileFoundLink( m.tcStem, m.tcExtension )
    ELSE
      lcRet = this.fileNotFoundLink( m.tcStem, m.tcExtension )
    ENDIF
  
    RETURN m.lcRet
    
  ENDFUNC && buildLink

  * --------------------------------------------------------- *
  FUNCTION  fileFoundLink( tcStem, tcExtension )
    *? it may be appropriate to change tag based on extension (eg: use <img for .jpg etc)
    LOCAL lcFileName, lcRet

    lcFileName = this.buildFileName( m.tcStem, m.tcExtension )
    lcRet      = [ <a href="] + ADDBS( this.cVirtualHomeDir ) + ;
                               m.lcFileName + '">[' + m.lcFileName + "]</a>"
    RETURN m.lcRet
 
  ENDFUNC  && fileFoundLink
  
  * --------------------------------------------------------- *
  FUNCTION fileNotFoundLink( tcStem, tcExtension )
  *? possibly link to a file upload page here
    RETURN " [FILE NOT FOUND: " + this.buildFileName( m.tcStem, m.tcExtension ) + "]"
  ENDFUNC && fileNotFoundLink
  
  * --------------------------------------------------------- *
  FUNCTION cleanFilenameForOS( tcFileName )
  * cleans for local file system
    LOCAL lcRet
 
    lcRet = STRTRAN( m.tcFileName, [/] , [\] )
    lcRet = ALLTRIM( m.lcRet )
  
    *-- strip any leading slashes
    DO WHILE m.lcRet = [\]
      lcRet = SUBSTR( m.lcRet, 2 )
    ENDDO
    RETURN m.lcRet
    
  ENDFUNC  && clearFilenameForOS

  * --------------------------------------------------------- *
  FUNCTION buildFilename( tcStem, tcExtension )
  LOCAL lcStem, lcExtension, lcRet
  
    ASSERT !EMPTY( m.tcStem ) MESSAGE this.Name + [::buildFileName() expects non-empty tcStem param)]
    ASSERT !EMPTY( m.tcExtension ) MESSAGE this.Name + [::buildFileName() expects non-empty tcExtension param)]
  
    lcStem      = ALLTRIM( m.tcStem )
    lcExtension = ALLTRIM( m.tcExtension )
    lcRet       = m.lcStem + [.] + m.lcExtension 
  
    RETURN m.lcRet

  ENDFUNC  && buildFilename

  * --------------------------------------------------------- *
  FUNCTION isFileFound( tcFileName )
    LOCAL lcFileName
    lcFileName = this.cleanFilenameForOS( m.tcFileName )
    RETURN FILE( ADDBS( this.cHomeDir ) + m.lcFileName )
    
  ENDFUNC  && isFileFound()

  * --------------------------------------------------------- *
  FUNCTION isValidExtension( tcFileName )
    RETURN .t.  && free pass for now
  ENDFUNC  &&isValidExpression

ENDDEFINE
*-- EOC: FileDownLoadLinkParser


*** ========================================================== ***
DEFINE CLASS L7ListParser AS L7BaseParser
* Implements <ol>,<ul> list parsing
    
  * --------------------------------------------------------- *
  FUNCTION isPatternPresent( tcText )
    LOCAL llRetval
    *-- not much we can do here, as we examine line by line
    llRetval = ! EMPTY( m.tcText )
    RETURN m.llRetval
  ENDFUNC  && isPatternPresent

  * --------------------------------------------------------- *
  FUNCTION parse( tcText )
    LOCAL ;
      lcParsedText, ;
      laLines(1), ;
      lcLine, ;
      lcContent, ;
      lcAttribs, ;
      lcAttribDelim, ;
      lcFirstChar, ;
      lcFirstWord, ;
      lnFirstCharAt, ;
      lnOldLevel, ;
      lcOldType, ;
      lnNewLevel, ;
      lcNewType, ;
      llIsListItem, ;
      lcOrderedListType, ;
      lcOrderedListStart, ;
      lnLine, ;
      lnTotLines, ;
      lcListStack, ;
      lnMarkSize, ;
      lcTag, ;
      lnLevel
    
    lcAttribDelim = "||"
    lcParsedText = ""
    lnOldLevel = 0
    lcOldType = ""  
    lcListStack = []  && Keeps track of open list tags so they can be closed properly.  eg. ulololulul
    lnTotLines= ALINES( m.laLines, m.tcText)

    FOR lnLine= 1 TO m.lnTotLines

      lcLine = laLines( m.lnLine )
      IF EMPTY(m.lcLine)
        llIsListItem = .F.
      ELSE 
        lcFirstWord = GETWORDNUM(m.lcLine, 1)  && this will include trailing period, such as "a."
        lcFirstChar = LEFT(m.lcFirstWord, 1)
        lnFirstCharAt = LEN( m.lcLine ) - LEN( LTRIM( m.lcLine )) + 1  && position of first (non-space) character
        llIsListItem = NOT m.lcFirstChar = "$" ; 
            AND ( ;
              ( m.lcFirstChar = "*" AND m.lcFirstWord = REPLICATE("*", LEN(m.lcFirstWord))) ;
              OR ;
              ( m.lcFirstChar = "#" AND m.lcFirstWord = REPLICATE("#", LEN(m.lcFirstWord))) ;
              OR ;
              ( RIGHT(m.lcFirstWord, 1) = [.]  ;
                AND (LOWER(m.lcFirstChar) $ [abcdefghivx] OR VAL( m.lcLine ) > 0 ) ;
                AND NOT LOWER( m.lcFirstWord) $ [dr.] ) ;
              )
      ENDIF 
      DO CASE 
      CASE NOT m.llIsListItem
        lnNewLevel = 0
        lcNewType = ""
      CASE (m.lcFirstChar = "*" and m.lcFirstWord = REPLICATE("*", LEN(m.lcFirstWord)))  && Bullets
        lcNewType = "ul"
        lnMarkSize = 1
        IF m.lnFirstCharAt = 1
          lnNewLevel = LEN(m.lcFirstWord)
        ELSE
          lnNewLevel = m.lnFirstCharAt
        ENDIF 
      CASE (m.lcFirstChar = "#" and m.lcFirstWord = REPLICATE("#", LEN(m.lcFirstWord)))  && Numbered
        lcNewType = "ol"
        lcOrderedListStart = []  && this doesn't apply to bullets
        lcOrderedListType  = [1] && this doesn't apply to bullets
        lnMarkSize = 1
        IF m.lnFirstCharAt = 1
          lnNewLevel = LEN(m.lcFirstWord)
        ELSE
          lnNewLevel = m.lnFirstCharAt
        ENDIF 
      CASE ( RIGHT(m.lcFirstWord, 1) = [.]  ;
                AND (INLIST(LOWER(m.lcFirstChar), [a],[b],[c],[d],[e],[f],[g], [i],[v],[x]) OR (VAL( m.lcLine ) > 0) ) ;
                AND NOT LOWER( m.lcFirstWord) $ [dr.] )
               
        lcNewType = "ol"
        lcOrderedListStart = []  && this doesn't apply to bullets
        lcOrderedListType  = [1] && this doesn't apply to bullets
        lnMarkSize = 1
        lnNewLevel = m.lnFirstCharAt
        DO CASE 
        CASE LOWER(m.lcFirstChar) $ [abcdefgh] && stop at H, as I will connote Roman numerals
          lcOrderedListType = IIF(UPPER(m.lcFirstChar) = m.lcFirstChar, [A], [a])
          lcOrderedListStart = STR( ASC( UPPER( m.lcFirstChar) ) - ASC("A") + 1)
        CASE VAL(m.lcLine) > 0
          lcOrderedListType  = [1]
          lcOrderedListStart = STRTRAN(m.lcFirstWord, [.])
        ENDCASE 
      ENDCASE
      
      IF m.llIsListItem
        lcContent = ALLTRIM(SUBSTR(m.lcLine, m.lnFirstCharAt + LEN(m.lcFirstWord)))
        IF m.lcAttribDelim $ m.lcContent  && *? only need to check this for first items in list
          
          * NOTE: To add style to the list, precede the first item with desired HTML attributes, 
          *  such as class= or style= settings, and separate from content via delimiter: ||
          *  Ex:  * class="tightList" ||First item text...
          * Attributes are applied to parent block tag (UL, OL), so likely defined classes will
          * provide more control than inline styles, as nested LI styles can then be defined.
          
          lcAttribs = " " + GETWORDNUM(m.lcContent, 1, m.lcAttribDelim)
          lcContent = GETWORDNUM(m.lcContent, 2, m.lcAttribDelim)
        ELSE 
          lcAttribs = ""
        ENDIF 
      ENDIF

      *-- Handle change (either more or less) to current nesting level:
      DO CASE
      *? following won't catch case where list type is switched, at same nesting level (odd case) -rp
      CASE m.lnNewLevel > m.lnOldLevel  && new nesting level (i.e., first item in list/sub-list)
        *? deprecation alert, TYPE and START should be handled with STYLE attributes
        lcTag = [<] + m.lcNewType + m.lcAttribs + ;
          IIF( m.lcNewType="ol" , [ type="]  + m.lcOrderedListType  + ["], "" ) + ;
          IIF( m.lcNewType="ol" , [ start="] + alltrim(m.lcOrderedListStart) + ["], "" ) + [>]
        lcParsedText = m.lcParsedText + REPLICATE( m.lcTag , m.lnNewLevel - m.lnOldLevel ) + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
        lcListStack = m.lcListStack + REPLICATE( m.lcNewType , m.lnNewLevel - m.lnOldLevel  )

      CASE m.lnNewLevel < m.lnOldLevel  && lesser nesting level, so need to close inner list(s)
        * FOR lnList = lnIndent TO lnNumber +1  STEP -1
        * Changed: 07/24/2002 by lc. eschew obscurification  
        FOR lnLevel = m.lnNewLevel TO m.lnOldLevel - 1
          lcParsedText = m.lcParsedText + [</] + RIGHT( m.lcListStack , 2 ) + [>] + CRLF
            * was: + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
          lcListStack = LEFT( m.lcListStack , LEN( m.lcListStack ) - 2 )
        ENDFOR
      ENDCASE

      IF m.llIsListItem
        lcParsedText = m.lcParsedText + [<li>] + m.lcContent + [</li>] + CRLF
      ELSE
        lcParsedText = m.lcParsedText + m.lcLine + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
      ENDIF

      lnOldLevel = m.lnNewLevel  && set indent level to new number for current line

    ENDFOR 

    *-- close any open lists
    DO WHILE LEN( m.lcListStack ) >= 2
      lcParsedText = m.lcParsedText + [</] + RIGHT( m.lcListStack , 2 ) + [>] + CRLF 
        * was: + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
      lcListStack = LEFT( m.lcListStack , LEN( m.lcListStack ) - 2 )
    ENDDO

    tcText = m.lcParsedText
    RETURN m.tcText
  ENDFUNC  && ListParser::parse
  * --------------------------------------------------------- *
  FUNCTION old_parse( tcText )
   
    LOCAL lnLine, ;
    lcLine, ;
    lcLeftChar, ;    && added by RP to simplify code and improve perf
    lcLeftWord, ;    && added by RP to simplify code and improve perf
    lnFirstCharAt, ; && added by RP to designate position of first non-space in line
    llNoParseLine, ; && added by RP to cope with VAL() bug with currency
    lcParsedText, ;
    lnIndent, ;      && current level of nesting (before processing pending line)
    lnNumber, ;      && level of nesting dictated by pending line
    lcListType, ;
    lcOrderedListType, ;
    lcOrderedListStart, ;
    lcMoreAttrib, ;
    lcListStack, ;
    laLines(1), ;
    lcTag, ;
    lnList, ;
    lcChar, ;
    lnTotLines, ;
    llWasOpen, ;
    lnMarkSize

    STORE 0 TO lnIndent, lnNumber

    lcParsedText       = ""
    lcChar             = []
    lcListType         = []
    lcOrderedListType  = []
    lcOrderedListStart = []

    lcListStack = []  && Keeps track of open list tags so they can be closed properly.  eg. ulololulul

    lnTotLines= ALINES( m.laLines, m.tcText)

    FOR lnLine= 1 TO m.lnTotLines

      lcLine= laLines( m.lnLine )
      IF EMPTY(m.lcLine)
        lcLeftChar = ""
        lcLeftWord = ""
        lnFirstCharAt = 0
        llNoParseLine = .T.
      ELSE
        lcLeftChar = LEFT(LTRIM(m.lcLine), 1)
        lcLeftWord = GETWORDNUM(m.lcLine, 1)  && this will include trailing period, such as "a."
        lnFirstCharAt = LEN( m.lcLine ) - LEN( LTRIM( m.lcLine )) + 1  && position of first (non-space) character
        llNoParseLine = m.lcLeftChar = "$"  && VFP used to crash on VAL() of lines starting with $...
      ENDIF 
        
      IF m.llNoParseLine  && was: EMPTY(lcLine)  -- blank line
        *-- close any open lists
        DO WHILE LEN( m.lcListStack ) >= 2
          lcParsedText = m.lcParsedText + [</] + RIGHT( m.lcListStack , 2 ) + [>] + CRLF
          lcListStack  = LEFT( m.lcListStack , LEN( m.lcListStack ) - 2 )
        ENDDO
        lnIndent = 0
      ENDIF

      lnMarkSize = 0
      lnNumber = 0

      DO CASE
      CASE m.llNoParseLine
        * do nothing more

*!*        * 01/06/2007: added this CASE, since all detailed processing was irrelevant
*!*        CASE m.lnFirstCharAt = m.lnIndent  && same intendure as previous item, so just tack on an <li> and skip other processing
*!*          lnNumber = m.lnFirstCharAt
      
      *[[ Change 07/12/2002: require a space after the * or balanced pairs of * in the line to avoid conflicts with the *strong* parser. 
      *[[ Change 01/20/2002: require a space after the * period, for footnotes.
      CASE m.lcLeftWord == "*" 
           * ... (SUBSTR( ALLTRIM(m.lcLine), 2, 1) = [ ]) && OR OCCURS( [*], SUBSTR( ALLTRIM( m.lcLine ), 2) ) % 2 = 0 )

        lcListType = [ul]
        ** lnNumber = IIF( LEFT( ALLTRIM( m.lcLine ), 1 ) = "*" , AT( "*" , m.lcLine ), 0 )
        lnNumber = m.lnFirstCharAt  && was: AT( "*" , m.lcLine )  && new nesting/indent level
        lnMarkSize = 1
      
      * Adopt WikiPedia syntax for numbered list, using #:
      CASE m.lcLeftWord == "#" 
           * ... (SUBSTR( ALLTRIM(m.lcLine), 2, 1) = [ ]) && OR OCCURS( [*], SUBSTR( ALLTRIM( m.lcLine ), 2) ) % 2 = 0 )

        lcListType = [ol]
        lcOrderedListStart = []
        lcOrderedListType  = [1]
        ** lnNumber = IIF( LEFT( ALLTRIM( m.lcLine ), 1 ) = "#" , AT( "#" , m.lcLine ), 0 )
        lnNumber = m.lnFirstCharAt  && was: AT( "#" , m.lcLine )  && new nesting/indent level
        lnMarkSize = 1
      
      *[[ Change 01/06/2007: moved this CASE below previous 2 to minimize calls to VAL, and improve performance of "preferred" lists types
      *[[ Change 01/06/2007: radical surgery to CASE statement for performance 
      CASE ( RIGHT(m.lcLeftWord, 1) = [.] ) ;
            AND (INLIST(LOWER(m.lcLeftChar), [a],[b],[c],[d],[e],[f],[g], [i],[v],[x]) OR (VAL( m.lcLine ) > 0) ) ;
            AND ( NOT LOWER( m.lcLeftWord) $ [dr.] )

        *? bit of a kluge that, but probably 99% use case handled above
        lcListType = [ol]
        lnNumber   = m.lnFirstCharAt  && was: LEN( m.lcLine ) - LEN( LTRIM( m.lcLine )) + 1  && new nesting/indent level
        lnMarkSize = LEN(m.lcLeftWord)

        lcOrderedListStart = []
        lcOrderedListType  = [1]

        * Sub-CASE structure based on specific ordered list type:
        DO CASE

        CASE INLIST( m.lcLeftChar, [a],[b],[c],[d],[e],[f],[g] )
          lcOrderedListType = [a]
          lcOrderedListStart = STR( ASC( UPPER( m.lcLeftChar) ) - ASC("A") + 1)

        CASE INLIST( m.lcLeftChar, [A],[B],[C],[D],[E],[F],[G] )
          lcOrderedListType = [A]
          lcOrderedListStart = STR( ASC( UPPER( m.lcLeftChar) ) - ASC("A") + 1)

        CASE INLIST( LOWER(m.lcLeftChar), [i], [v], [x] )  && Roman numerals
          LOCAL lcTemp, lcTemp2, llTempLower
          llTempLower = m.lcLeftChar = LOWER(m.lcLeftChar)
          lcOrderedListType = IIF(m.llTempLower, [i], [I])
          lcTemp = ",i,ii,iii,iv,v,vi,vii,viii,ix,x,"
          IF NOT m.llTempLower
            lcTemp = UPPER(m.lcTemp)
          ENDIF 
          lcTemp2 = [,] + STRTRAN( m.lcLeftWord, [.] ) + [,]
          lcOrderedListStart = STR( OCCURS(",", LEFT( m.lcTemp, AT( m.lcTemp2, m.lcTemp))))

        * 01/06/2007: moved last to minimize VAL() calls
        CASE VAL( m.lcLine ) > 0
          lcOrderedListType  = [1]
          lcOrderedListStart = STRTRAN(LOWER( LEFT( ALLTRIM( m.lcLine ) , 2 )),[.])

        ENDCASE
        lcOrderedListStart = ALLTRIM( m.lcOrderedListStart )

      ENDCASE

      *-- Handle change (either more or less) to current nesting level:
      DO CASE
      *? following won't catch case where list type is switched, at same nesting level (odd case) -rp
      CASE m.lnNumber > m.lnIndent  && new nesting level (i.e., first item in list/sub-list)
        *? deprecation alert, TYPE and START should be handled with STYLE attributes
        IF "||" $ m.lcLine  && attributes (style= or class=) indicated for 1st item in list, apply to parent tag
          *? should we just use one | for this?
        ELSE 
          lcMoreAttrib = ""
        ENDIF 
        lcTag = [<] + m.lcListType + ;
          IIF( m.lcListType="ol" , [ type="]  + m.lcOrderedListType  + ["], "" ) + ;
          IIF( m.lcListType="ol" , [ start="] + m.lcOrderedListStart + ["], "" ) + [>]
        lcParsedText = m.lcParsedText + REPLICATE( m.lcTag , m.lnNumber - m.lnIndent ) + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
        lcListStack = m.lcListStack + REPLICATE( m.lcListType , m.lnNumber - m.lnIndent )

      CASE m.lnNumber < m.lnIndent  && lesser nesting level, so need to close inner list(s)
        * FOR lnList = lnIndent TO lnNumber +1  STEP -1
        * Changed: 07/24/2002 by lc. eschew obscurification  
        FOR lnList = m.lnNumber TO m.lnIndent - 1
          lcParsedText = m.lcParsedText + [</] + RIGHT( m.lcListStack , 2 ) + [>] + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
          lcListStack = LEFT( m.lcListStack , LEN( m.lcListStack ) - 2 )
        ENDFOR
      ENDCASE

      lnIndent = m.lnNumber  && set indent level to new number for current line
      *? move this last (before ENDFOR) and revise next block to refer to lnNumber

      IF m.lnIndent > 0
        lcParsedText = m.lcParsedText + [<li>] + SUBSTR( m.lcLine , m.lnIndent + m.lnMarkSize ) + [</li>] + CRLF
      ELSE
        lcParsedText = m.lcParsedText + m.lcLine + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
      ENDIF

    ENDFOR
    
    *-- close any open lists
    DO WHILE LEN( m.lcListStack ) >= 2
      lcParsedText = m.lcParsedText + [</] + RIGHT( m.lcListStack , 2 ) + [>] + IIF( m.lnLine < m.lnTotLines, CRLF, [] )
      lcListStack = LEFT( m.lcListStack , LEN( m.lcListStack ) - 2 )
    ENDDO
    
    tcText = m.lcParsedText
    RETURN m.tcText
  ENDFUNC  && ListParser::parse
ENDDEFINE
*-- EOC ListParser

*** ========================================================== ***
DEFINE CLASS L7DynamicMarkers as L7MultiParser
* This chain is set up for "on save" parsing. IOW, it does things
* that would be performed on raw submissions prior to save
*

  * --------------------------------------------------------- *
  FUNCTION getDate()
    LOCAL ldRet

    ldRet = DATE()
    
    *-- fix the date so tests don't constantly fail
    #IF L7_PARSER_DEBUG
      ldRet = DATE(2002,8,01)
    #ENDIF
    
    RETURN m.ldRet
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION getDateDiff( tcJulianDay )
    LOCAL ldCurrentDate, lnJD
    
    ASSERT VARTYPE( m.tcJulianDay ) = "C" MESSAGE this.name + [::getDateDiff(c) expects character parameter ]
    
    IF VARTYPE( m.tcJulianDay ) # "C"
      tcJulianDay = "0"
    ENDIF
    
    lnJD   = VAL( m.tcJulianDay )
    
    ldCurrentDate = this.getDate()

    RETURN VAL( SYS(11, m.ldCurrentDate ) ) - m.lnJD
    
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION init()
    * NOTE: this is a "multi-context" parser, these sub-parses will fire (or not) depending on the context..
    
    this.addParse( "(^|\n|\W)(#d#)(\W|$)",         "=$1+'['+this.getDateMarker()+']'+$3", .t., .t., .f.,[SAVE])
    
    this.addParse( "(^|\n|\W)(#n#)(\W|$)",           [=$1+"<new="+SYS(11,this.getDate())+">"+$3], .t., .t., .f., [SAVE])
    this.addParse( "(^|\n|\W)(\<new=(\d+)\>)(\W|$)", [=$1+this.getNewMarker($3)+$4], .t., .t., .f., [VIEW])
    this.addParse( "(^|\n|\W)(#u#)(\W|$)",               [=$1+"<updated="+SYS(11,this.getDate())+">"+$3], .t., .t., .f., [SAVE])
    this.addParse( "(^|\n|\W)(\<updated=(\d+)\>)(\W|$)", [=$1+this.getUpdatedMarker($3)+$4], .t., .t., .f., [VIEW])
    
    RETURN DODEFAULT()
  
  ENDFUNC
 
  * --------------------------------------------------------- *
  FUNCTION getDateMarker()
  * returns <span class="updatedX">[Updated]</span>, or nothing.
  *? CSS ALERT
    * this is a hook incase we want to do special date formatting
    RETURN TRANSFORM( this.getDate() )
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION getNewMarker( tcJulianDay )
  * returns <span class="newX">[NEW]</span>, or nothing.
  *? CSS ALERT
    LOCAL lcStr, lnDiff
  
    lnDiff = this.getDateDiff( tcJulianDay )

    IF BETWEEN( m.lnDiff, 0, 8 )
      lcStr = [<span class="new] + ALLTRIM( STR( m.lnDiff ) ) + '">[NEW]' + [</span>]
    ELSE 
      lcStr = []
    ENDIF
    RETURN m.lcStr
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION getUpdatedMarker( tcJulianDay )
  * returns <span class="UpdatedX">[Updated]</span>, or nothing.
  *? CSS ALERT
    LOCAL lcStr, lnDiff
  
    lnDiff = this.getDateDiff( m.tcJulianDay )

    IF BETWEEN( m.lnDiff, 0, 8 )
      lcStr = [<span class="updated] + ALLTRIM( STR( m.lnDiff ) ) + '">[UPDATED]' + [</span>]
    ELSE 
      lcStr = []
    ENDIF
    RETURN m.lcStr
  ENDFUNC

ENDDEFINE



*==============================================================================
*==============================================================================
* END: PRODUCTION PARSING CLASSES
*==============================================================================
*==============================================================================


*==============================================================================
*==============================================================================
* PARSING SUPPORT CLASSES
*==============================================================================
*==============================================================================

*--- NOTE: Classes L7Lightweight and L7Stack are in L7Utils.PRG.


*** ========================================================== ***
DEFINE CLASS L7BaseParser AS L7CORLink

  cCurrentContext    = []               && set by setContext() to determine which parsers fire and how they fire
  cValidContextSet   = []               && the context(s) for which this parser is active
  cDefaultContext    = []               && the context under which this parser typically operates
  
  oRegExp            = NULL             && regular expression provider, may be shared over a chain
  oStack             = NULL             && stack to store extracted patterns (if needed) likely to be shared
                                        && over an entire chain and emptied by last link
                                        
  cRegExpClass = L7_REGEXP_CLASS        && the class to use by default for oRegExp
  cStackClass  = "L7Stack"              && the class to use by default for oStack

  cPattern           = .f.             && the pattern to look for (set to .f. to identify parsers that don't use patterns at all)
  cReplacement       = []               && the replacement (may include $1, $2 for submatches, and, may include a & prefix for macros)

  lGlobal            = .T.              && find all occurances by default
  lIgnoreCase        = .T.              && obvious
  lMultiLine         = .F.              
  lPushToStack       = .F.              && if .t., matches will be placed on the stack and placeholders left behind in text
  cPlaceHolderDelim  = L7_PARSER_PLACEHOLDER_DELIM && used to pad stack placeholders
  
  lisAnchored        = .f.              && will be .t. if link is anchored, ie, is owned by an L7ParseChainAnchor object
  nHitMod            = 1                && set to positive integer to limit the number of replacements made per execution 
                                        && modulo based, so a value of "2" will cause every other replacement to be made, 10, every 10th etc
                                        && first replacement is ALWAYS made
  
  *-- status logging properties       
  lLog               = .f.
  nHits              = 0
  nCumulativeHits    = 0
  nSeconds           = 0
  nCumulativeSeconds = 0
  nStartSeconds      = 0
  cStartText         = []
  cEndText           = []
  lVerbose           = .f.              && if .t., before and after text will also be displayed in status, caution: can eat memory fast this way.
 * cLogPlaceholder    = []               && used to find the log in the stack after parsing

  PROTECTED cCurrentContext, oRegExp, oStack, lisAnchored
  
  * --------------------------------------------------------- *
  FUNCTION garbagecollect()
 
    DODEFAULT()  && see L7CORLink, triggers recusion in successor chain
    this.oRegExp    = NULL
    this.oStack     = NULL
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION copyValueFromConfig( toConfig, tcConfigProp, tcThisProp )
    *-- Imputes config object property value to indicated this.prop.
    *   this function would be called from ::Config()
     
    *-- allow local property name to be assumed
    IF VARTYPE( tcThisProp ) # "C"
      tcThisProp = tcConfigProp
    ENDIF
    
    IF PEMSTATUS( toConfig,tcConfigProp, 5)
      this.&tcThisProp = toConfig.&tcConfigProp
    ENDIF
  
  ENDFUNC

  * --------------------------------------------------------- *  
  FUNCTION configImplementation(toConfig)
    *-- to be overridden in application subclasses...
    * the idea is to use this.imputeConfigValue() copy properties from toConfig into the parser
    *? consider an "auto config" that traverses all properties and looks for matches (exclude NAME etc)
  ENDFUNC
  
  * --------------------------------------------------------- *  
  FUNCTION config( toConfig )
    WITH this
      .configImplementation( toConfig )
      IF .hasSuccessor()
        this.oSuccessor.config(  toConfig )
      ENDIF
    ENDWITH
    
  ENDFUNC  
    
  * --------------------------------------------------------- *
  FUNCTION setContext( tcContext )
    THIS.SETALL( "cCurrentContext", m.tcContext )
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION resetContext()
    this.cCurrentContext = this.cDefaultContext
    IF this.hasSuccessor()
      this.oSuccessor.resetContext()
    ENDIF
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION isValidContext()
   
    *-- no valid contexts, we'll do anything
    *[[ consder using NULL for this.
    IF empty( this.cValidContextSet )
      RETURN .t.
    ENDIF
    
    IF !EMPTY( this.cCurrentContext ) && we've been given a specific context
      RETURN ([,] + ALLTRIM( this.cCurrentContext ) + [,]) $ ([,] + ALLTRIM( this.cValidContextSet ) + [,])
    ELSE
      RETURN ([,] + ALLTRIM( this.cDefaultContext ) + [,]) $ ([,] + ALLTRIM( this.cValidContextSet ) + [,])
    ENDIF
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION onEndOfChain( tcText )
    IF this.oStack.count>0
      THIS.clearStack( @m.tcText )
    ENDIF
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION buildPlaceholder( tcToken )
    *-- wraps stack element placeholders
    RETURN THIS.cPlaceHolderDelim + m.tcToken + THIS.cPlaceHolderDelim
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION pushToStack( tcReplacement )
    LOCAL lcRetVal, lnElements
    lnElements = THIS.oStack.PUSH( m.tcReplacement )
    lcRetVal   = THIS.buildPlaceholder( ALLTRIM( STR( m.lnElements ) ) )
    RETURN m.lcRetVal
  ENDFUNC



  * --------------------------------------------------------- *
  FUNCTION clearStack( tcText )
  * tcText passed by reference
  *-- spew stack contents back into placeholder positions
  *   normally only called on the last parser in the chain

    LOCAL lcText, llPushToStack, lcPlaceHolderPattern, lnIts

    lcPlaceHolderPattern = THIS.buildPlaceholder([(\d+)])

    *? kluge, we don't want replaceex() below to push to stack
    llPushToStack     = THIS.lPushToStack
  
    THIS.lPushToStack = .F.

    lnIts = 0
  
    *-- set the maximum nesting level to 10
    *   because stack contents may include placeholders (due to nested extractions)
    *   we may need to take multiple passes to clear all the placeholders
    *? OPT: because what is being done here is relatively simple, we could
    *  use native VFP (rather than regexp in replaceex() ) to get the job done
    DO WHILE THIS.m( m.tcText, m.lcPlaceHolderPattern ) AND m.lnIts < 10
      THIS.replaceex( @m.tcText, m.lcPlaceHolderPattern, [=this.oStack.getElement( $1 )] )
      lnIts = lnIts + 1
    ENDDO
    
    *-- reset the stack to clear memory
    
    this.oStack.reset()
    
    *-- reset to stored value
    THIS.lPushToStack = llPushToStack
    
  ENDFUNC  && clearStack
  
  * --------------------------------------------------------- *
  FUNCTION getLog()
    LOCAL lcStr
    
    lcStr = PADR( this.name, 20 ) + [|] + [H: ]   + PADR( this.nHits, 4 )           + ;
                              [|CH: ] + PADR( this.nCumulativeHits, 6 ) + ;
                              [|CX: ]  + PADR( this.cCurrentContext, 10 )        + ;
                              [|DX: ] + PADR( this.cDefaultContext, 10 ) + ;
                              [|VCX: ] + PADR( this.cValidContextSet, 20 )
                              
    IF this.lverbose AND this.nHits > 0
      LOCAL lcTextDelim
      lcTextDelim = + REPLICATE( "#",20) 
      lcStr = lcStr + CRLF + m.lcTextDelim + encodeForHTML(this.cStartText) + CRLF + ;
                             m.lcTextDelim + CRLF + ;
                             encodeforHTML(this.cEndText) + m.lcTextDelim + CRLF
                             
      *? consider getting even more verbose here with property settings, stack contents etc...
    ENDIF
    
    RETURN m.lcStr 
    
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION detectLoggingRequest( tcText )
  * checks the text for logging flags and sets chain members llLog and lVerbose accordingly
  
    *-- note: a bit of an extra cost here for long unachored chains
    IF !this.lisAnchored AND vartype(m.tcText) = "C" and ATC("showparselog", m.tcText ) > 0
  
      *-- first, turn on logging as needed
      DO CASE 
        CASE ATC("[showparselog]", m.tcText ) + ATC("[showparselog verbose]", m.tcText ) > 0
          this.setAll( [lLog] , .t. ) && do all of them
        CASE ATC("[showparselog ", m.tcText ) > 0
          PRIVATE pcTempText
          LOCAL lnPos
          lnPos      = ATC("[showparselog ", m.tcText )
          pcTempText = SUBSTR(m.tcText,m.lnPos)  && not, perfect but probably good enough
          this.setAllx( [llog], .t. , [' '+LOWER(this.NAME) $ LOWER( m.pcTempText ) ])
        otherwise
          error [L7Parser::detectLoggingRequest() unexpected status detected in set logging.]
      ENDCASE
      
      *-- second, turn on verbose as needed
      DO CASE
        CASE  ATC("[showparselog verbose", m.tcText) > 0
         this.setAll( [lVerbose], .t. )
        CASE ATC("verbose", m.tcText) > 0         
           PRIVATE pcTempText 
           pcTempText = m.tcText
           *-- conditionally set verbose on particular classes that have been requested
           this.setAllx( [lVerbose], .t., "LOWER(this.NAME) +' verbose' $ LOWER( m.pcTempText )" )
        otherwise
	       * no extra work to do
        ENDCASE
     ENDIF
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION beforeExecute( tcText )
    ** this.detectLoggingRequest( m.tcText ) 
    * 6/19/2005 - JRP added pass-by-reference:
    this.detectLoggingRequest( @m.tcText ) 
  ENDFUNC
   
  * --------------------------------------------------------- *
  FUNCTION getObjectRef( tcDefaultClass, tvObjectOrClass, tcModule )
    LOCAL loRet
    *? possibly hook out to optional factory object here

    DO CASE
      CASE VARTYPE( m.tvObjectOrClass ) = "O"
        loRet = m.tvObjectOrClass
     CASE VARTYPE( m.tvObject ) = "C"
       IF VARTYPE( m.tcModule ) = "C"
         loRet = NEWOBJECT( m.tvObjectOrClass, m.tcModule )
       ELSE
         loRet = CREATEOBJECT( m.tvObjectOrClass )
       ENDIF
     OTHERWISE
       loRet = CREATEOBJECT( m.tcDefaultClass )
     ENDCASE
    RETURN m.loRet
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION setStack( tvStack, tcModule )
    THIS.oStack = THIS.getObjectRef( THIS.cStackClass , m.tvStack, m.tcModule )
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION setRegExp( tvRegExp, tcModule )
    THIS.oRegExp = THIS.getObjectRef( THIS.cRegExpClass, m.tvRegExp, m.tcModule )
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION configRegExp() as boolean
    WITH THIS.oRegExp
      .GLOBAL     = THIS.lGlobal
      .ignorecase = THIS.lIgnoreCase
      .multiline  = THIS.lMultiLine
    ENDWITH
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION m( tcText, tcPattern ) as boolean
    * same as perl's m
    this.configRegExp()
    THIS.oRegExp.PATTERN = m.tcPattern
    RETURN THIS.oRegExp.test( m.tcText )
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION replaceex( tcText, tcSearchPattern, tcReplacePattern ) as integer
  * mimics perl's 's' function
  * take note: nested calls to replaceex() will fail if 
  * RegExp::Execute() fails to return NEW match collections, but as of 5.5 it does, and seems
  * unlikely it would stop doing so
  * also, tcText must be passed by reference

    LOCAL loRE, lcText, lnShift, lcReplacePattern, lcCommand
    LOCAL loMatch, loMatches, lnI, lcSubMatch, llevaluate, lcMatchDelim, lnHits
    LOCAL lcReplacement

    lnHits           = 0
          
    IF EMPTY( m.tcText )
      RETURN 0
    ENDIF
  
    this.configRegExp()
  
    loRE         = THIS.oRegExp
    loRE.PATTERN = m.tcSearchPattern
  
    *--- are we evaluating?
    IF tcReplacePattern = [=]
      llEvaluate        = .t.
      lcReplacePattern  = SUBSTR( m.tcReplacePattern, 2 )
    ELSE
      lcReplacePattern  = m.tcReplacePattern
    ENDIF
  
    *-- check for external calls
    IF this.llog OR llevaluate OR this.lPushToStack
      * in order to get counts to log, we always have to do this...
    
      lcText           = m.tcText
      lnShift          = 1
*      lcMatchDelim     = IIF( m.llEvaluate, [],[])  && depreciate this..
      loMatches        = loRE.execute( m.lcText )


      *? take note: fox bug, can't close datasession after this?
      * potential fix, use for lnK=1 to count instead...
      
      FOR EACH loMatch IN m.loMatches
      
        lnHits    = m.lnHits + 1  
       
        *-- implement governor
        if mod(lnHits-1,this.nHitMod)#0
          loop
        endif
        
        lcCommand = m.lcReplacePattern
        *? consider start with 0, the 0th submatch is the entire match
        lnI       = 1  
            
        FOR EACH lcSubMatch IN loMatch.SubMatches
       
          *-- we can't have cr's in code we are going to evaluate
          *   the typical situation is [&"<pre>"+encodeforHTML("$1$2$4")+"</pre>"]
          *   the linefeeds need to be escaped prior to the function call
          IF llEvaluate 
            * "escape" the string we are about to use in an evaluation.
            * it is important to escape due to possible delim chars (like ", ' etc)
            * malicious content, or VFP line-length violations.
            lcSubMatch = [this.oStack.getElement(]+ALLTRIM(STR(this.oStack.push( m.lcSubMatch )))+[)]
          ENDIF
          
          lcCommand = STRTRAN( m.lcCommand, "$" + ALLTRIM( STR( m.lnI ) ) , m.lcSubMatch)
          lnI = m.lnI + 1
        ENDFOR
     
        IF m.llEvaluate
          *[[ consider try/catch here
          lcReplacement = EVALUATE( m.lcCommand )
        ELSE
          lcReplacement = m.lcCommand
        ENDIF 
*        DEBUGOUT lcCommand + [|||] + lcReplacement
        IF THIS.lPushToStack
          *-- push the replacement to the stack and get a placeholder to use
          lcReplacement = THIS.pushToStack( m.lcReplacement )
        ENDIF

        lcText  = STUFF( m.lcText, loMatch.FirstIndex + m.lnShift, m.loMatch.LENGTH, m.lcReplacement )
        lnShift = m.lnShift + LEN( m.lcReplacement ) - m.loMatch.LENGTH

      ENDFOR
    
    ELSE
      *--- nothing fancy, just a raw replace
      * note: this code is not active if we are logging
      * it is faster, but we can't count hits...
      lcText = THIS.oRegExp.REPLACE( m.tcText, m.tcReplacePattern )
      
    ENDIF
    tcText = m.lcText && since we are passing tcText by reference
    RETURN m.lnHits
 
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION beforeParse( tcText ) AS boolean
  *-- hook. tcText passed by ref

    this.nHits         = 0 
    
    IF this.lLog 
      this.nStartSeconds = SECONDS()  
      this.cStartText    = m.tcText
    ENDIF
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION afterParse( tcText ) AS boolean
  *-- hook. tcText passed by ref
    *?! this may not be good default functionality...
    alltrimX( @m.tcText )
    
    IF this.lLog
      this.nSeconds           = this.nSeconds + SECONDS() - this.nStartSeconds
      *-- this.nHits is incremented in this.parse() 
      this.cEndText           = m.tcText
      this.nCumulativeHits    = this.nCumulativeHits    + this.nHits
      this.nCumulativeSeconds = this.nCumulativeSeconds + this.nSeconds
      tcText = m.tcText + this.pushtostack([<pre style="font-size: xx-small">]+this.getLog()+[</pre>] )
    ENDIF
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION parse( tcText ) AS boolean
      *-- hook, the meat, tcText passed by ref. Likely to be overwritten in subclass
      this.nHits = this.nHits + THIS.replaceex( @m.tcText , THIS.cPattern, THIS.cReplacement )
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION isActive( tcText ) AS boolean  && lparam required due to COR interface
    RETURN THIS.isValidContext() AND DODEFAULT()
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION isPatternPresent( tcText ) as Boolean
   
    if vartype( this.cPattern ) = "L"
      *-- we'll not even check in this case, thus allowing subclasses
      *   that do not use the pattern property to fire the parse() method by default
      return .t.
    endif
    
    IF EMPTY( this.cPattern ) OR EMPTY( m.tcText )
      RETURN .f.
    ENDIF
    
    RETURN this.m( m.tcText, this.cPattern )
      
  ENDFUNC

  * --------------------------------------------------------- *
  PROTECTED FUNCTION executeImplementation( tcText ) as boolean
  * main template method for the parsers
  * implementation code goes into the hooks called here
     
    *-- make sure we've got what we need.
    if isnull(this.oRegExp) 
      this.setRegExp()
    endif
    
    if isnull(this.oStack)
      this.setStack()
    endif
    
    *-- hook.
    THIS.beforeParse( @m.tcText )
    
    *-- check we've got work to do
    IF this.isPatternPresent( m.tcText )  && allow for quick bail 
      *-- hook.
      THIS.parse( @m.tcText )
    ENDIF
    
    *-- hook.
    THIS.afterParse( @m.tcText )
  
    RETURN

  ENDFUNC
  
ENDDEFINE
*-- EOC Base Parser
  
*** ========================================================== ***
DEFINE CLASS L7MultiParser as L7BaseParser
* extends the L7Baseparser with addParse() to add multiple simple parsing patterns
* use this for groups of simple parsing tasks that are related

  nParseCount = 0

  DIMENSION aParses(1)
  HIDDEN aParses

  * --------------------------------------------------------- *
  FUNCTION addParse( tcPattern, tcReplacement, tlGlobal, tlIgnoreCase, tlPushToStack, tcContextSet, tnHitMod )
    LOCAL lnPcount, llGlobal, llIgnoreCase, llPushToStack, lnPFlagcount,lcContextSet, lnHitMod

    lnPFlagcount = PCOUNT() - 2 && number of flags sent
    
    llGlobal      = IIF( m.lnPFlagcount>=1, m.tlGlobal,      this.lGlobal      )
    llIgnoreCase  = IIF( m.lnPFlagcount>=2, m.tlIgnoreCase,  this.lIgnoreCase  )
    llPushToStack = IIF( m.lnPFlagcount>=3, m.tlPushToStack, this.lPushToStack )
    lcContextSet  = IIF( m.lnPFlagcount>=4, m.tcContextSet,  this.cValidContextSet )
    lnHitMod     = IIF( m.lnPFlagcount>=5, m.tnHitMod,    this.nHitMod )
    
    this.nParseCount = this.nParseCount + 1 
    DIMENSION this.aParses( this.nParseCount, 7 )
  
    *-- take note: executeImplementation() depends on column order
    this.aParses( this.nParseCount , 1 ) = m.tcPattern
    this.aParses( this.nParseCount , 2 ) = m.tcReplacement 
    this.aParses( this.nParseCount , 3 ) = m.llGlobal
    this.aParses( this.nParseCount , 4 ) = m.llIgnoreCase
    this.aParses( this.nParseCount , 5 ) = m.llPushToStack
    this.aParses( this.nParseCount , 6 ) = m.lcContextSet
    this.aParses( this.nParseCount , 7 ) = m.lnHitMod
    
  ENDFUNC  && addParse
  
  * --------------------------------------------------------- *
  FUNCTION resetParses()
    this.nParseCount = 0
    DIMENSION this.aParses(1)
    this.aParses(1) = .f.
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION executeImplementation( tcText )
    LOCAL lnK,                 ;
          lcOldPattern,        ;
          lcOldReplacement,    ;
          llOldGlobal,         ;
          llOldPushToStack,    ;
          llOldIgnoreCase,     ;
          lcOldValidContextSet
  
    ASSERT VARTYPE( m.tcText ) = "C" MESSAGE this.Name + [::executeImplementation() expects a character argument ]
  
      *-- make sure we've got what we need.
    if isnull(this.oRegExp) 
      this.setRegExp()
    endif
    
    if isnull(this.oStack)
      this.setStack()
    ENDIF
    
    IF this.nParseCount > 0 
  
      lcOldPattern         = this.cPattern
      lcOldReplacement     = this.cReplacement
      llOldGlobal          = this.lGlobal
      llOldPushToStack     = this.lPushToStack
      llOldIgnoreCase      = this.lIgnoreCase
      lcOldValidContextSet = this.cValidContextSet
      
      this.beforeParse( @m.tcText )
     
      FOR lnK = 1 TO this.nParseCount
    
        *-- take note: the column order is established in addParse()
        this.cPattern         = this.aParses( m.lnK, 1 )
        this.cReplacement     = this.aParses( m.lnk, 2 )
        this.lGlobal          = this.aParses( m.lnK, 3 )
        this.lIgnoreCase      = this.aParses( m.lnK, 4 )
        this.lPushToStack     = this.aParses( m.lnK, 5 )
        this.cValidContextSet = this.aParses( m.lnK, 6 )
        this.nHitMod         = this.aParses( m.lnK, 7 )

        IF this.isValidContext()
          this.parse( @m.tcText )
        ENDIF    
      ENDFOR
    
      this.afterParse( @m.tcText )
    
      *-- replace divots
      this.cPattern         = m.lcOldPattern
      this.cReplacement     = m.lcOldReplacement
      this.lPushToStack     = m.llOldPushToStack
      this.lGlobal          = m.llOldGlobal
      this.lIgnoreCase      = m.llOldIgnoreCase
      this.cValidContextSet = m.lcOldValidContextSet
      
    ELSE
      *-- we have a simple this.cPattern, this.cReplacement based parsing job to do
      *   SimpleParser can handle this.
      DODEFAULT( @m.tcText )
    ENDIF
  
    ASSERT VARTYPE( m.tcText ) = "C" MESSAGE this.Name + [::executeImplementation() changing arguement type]
  
    RETURN
  ENDFUNC  && MultiParser::executeImplementation
ENDDEFINE
*-- EOC MultiParser 

*** ========================================================== ***
DEFINE CLASS L7ParseChainManager as L7Lightweight
*  Manages multiple chains, keeping them cached for repeated use
*  this class is meant to be hung of a persistent object (like oApp) 

nChainCount = 0
DIMENSION aChains(1)

PROTECTED nChainCount, aChains

  * --------------------------------------------------------- *
  FUNCTION getObjectRef( tcDefaultClass, tvObjectOrClass, tcModule )
    LOCAL loRet
    *? possibly hook out to optional factory object here

    DO CASE
      CASE VARTYPE( m.tvObjectOrClass ) = "O"
        loRet = m.tvObjectOrClass
     CASE VARTYPE( m.tvObject ) = "C"
       IF VARTYPE( m.tcModule ) = "C"
         loRet = NEWOBJECT( m.tvObjectOrClass, m.tcModule )
       ELSE
         loRet = CREATEOBJECT( m.tvObjectOrClass )
       ENDIF
     OTHERWISE
       loRet = CREATEOBJECT( m.tcDefaultClass )
     ENDCASE
    RETURN m.loRet
  ENDFUNC

  * --------------------------------------------------------- *  
  FUNCTION config( toConfig )
    local loChain
    IF VARTYPE( toConfig ) = "O"
      FOR EACH loChain IN this.aChains
        loChain.config( toConfig )
      ENDFOR
    ENDIF
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION addChain( tvChain, tcName )
    LOCAL loChain
    
    ASSERT VARTYPE( tvChain ) $ "CO" MESSAGE this.name + [::getChainByName( c ) expects character or object for 1st param ]
    
    IF NOT VARTYPE( tvChain ) $ "CO"
      RETURN .f.
    ENDIF
    
    IF VARTYPE(tvChain) = "C"
      *? factory alert
      loChain = this.getObjectRef( tvChain )
    ELSE
      loChain = m.tvChain
    ENDIF
 
    *-- give this chain it's name (will default to class name if not passed)
    *? perhaps check for uniqueness here?
    IF VARTYPE( tcName ) = "C"    
      loChain.Name = m.tcName
    ENDIF
  
    *-- forge the chain now, to have it hot and ready for the first hit
    *  might just be a basic chain, not anchored, so we check for the forgeChain method
    *? kluge alert... think about this some more...
    IF PEMSTATUS( loChain,[forgeChain],5)
      loChain.forgeChain()
    ENDIF
          
    this.nChainCount = this.nChainCount + 1 
    DIMENSION this.aChains( this.nChainCount )
    this.aChains( this.nChainCount ) = m.loChain
    
    RETURN m.loChain
    
  ENDFUNC
  

  * --------------------------------------------------------- *
  FUNCTION getChainByName ( tcName )
    LOCAL loChain
    
    ASSERT VARTYPE( m.tcName ) = "C" MESSAGE this.name + [::getChainByName( c ) expects character for 1st param ]
        
    FOR EACH loChain IN this.aChains
      IF ALLTRIM(UPPER(loChain.Name)) == ALLTRIM(UPPER( m.tcName))
        RETURN m.loChain
      ENDIF
    ENDFOR
    RETURN null

  ENDFUNC
    
    
  * --------------------------------------------------------- *
  FUNCTION parseByName( tcNames, tcText, tcContext )
    * parses tcText with the chains in TcNames, with context tcContext
    LOCAL laNames(1), lnK, lnTotalNames, llsetSpecialContext, loChain

    ASSERT VARTYPE( m.tcNames ) = "C" MESSAGE this.name + [::parseByName( c, c) expects character for 1st param ]
    ASSERT VARTYPE( m.tcText )  = "C" MESSAGE this.name + [::parseByName( c, c) expects character for 2nd param ]
    
    this.beforeParseByName( m.tcNames, @m.tcText, m.tcContext )
    
    llsetSpecialContext = VARTYPE( m.tcContext ) = "C"
    
    lnTotalNames = ALINES( m.laNames, m.tcNames, .t., [,] )
    
    FOR lnK = 1 TO m.lnTotalNames
      
      loChain = this.getChainByName( laNames( lnk ) )
      
      IF VARTYPE( loChain ) = "O"
        
        IF llsetSpecialContext
          loChain.setContext( m.tcContext )
        ENDIF
        
        loChain.execute( @m.tcText )
      
        IF llsetSpecialContext
          loChain.resetContext() && put each link's context back to default
        ENDIF
              
      ENDIF
      
    ENDFOR  
    
    this.afterParseByName( tcNames, @tcText, tcContext )
    
    *-- take note, we operate on tcText AND return it, that way this function can be called with tcText by 
    *   ref or by value
    RETURN m.tcText 
   
  endfunc
  
  function beforeParseByName( tcNames, tcText, tcContext )
  endfunc
  
  function afterParseByName( tcNames, tcText, tcContext )
  endfunc
  
ENDDEFINE
  
*** ========================================================== ***
DEFINE CLASS L7ParseChainAnchor as L7BaseParser
* a special link that brings one or more links with it
* orchestrates the chain to work coherently

  * --------------------------------------------------------- *
  FUNCTION cPlaceHolderDelim_ASSIGN( tvValue ) as boolean
    *-- ensures all parsers use the same placeholder
    this.setAll( "cPlaceHolderDelim", m.tvValue )
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION forgeChainImplementation()
    *-- build the chain here, possibly from meta data
    RETURN
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION forgeChain()
  *-- builds the chain, implement in subclass, often from meta data

    *-- build the chain
    this.forgeChainImplementation()  
    
    this.setAll("lisAnchored", .t. ) && indicate that all links are anchored
    this.lisAnchored = .f.           && the anchor isn't anchored, doesn't make sense...
    
    *-- instantiate the shared elements
    this.setStack()
    this.setRegexp()
  
    *-- pointer all links to the same oRegExp and oStack
    *? could do this conditionally with setAllx for oRegExp to allow some links to own their own regExp object..
    this.setall("oRegExp", this.oRegExp )
    this.setall("oStack" , this.oStack  )
 
    *-- same placeholder must be used in order to share the stack
    this.setall("cPlaceHolderDelim", this.cPlaceHolderDelim)
         
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION execute( tcText )
    *-- check that we have a chain attached
    *-- this allows delayed instantiation of the chain
    IF !this.hasSuccessor()
      this.forgeChain()
    endif
    if isnull(m.tcText)  && too much that cannot cope with non-strings--just set it:
      tcText = ""
    endif 
    return dodefault(@m.tcText )
  ENDFUNC
ENDDEFINE
*-- EOC ParseChainAnchor



*========================================================================
*  UDFs
*========================================================================

* --------------------------------------------------------- *
FUNCTION callparserdirect( tcText, tcParserClass, tcModule )
*-- note tcText may be passed by reference or by value
*-- note tcParseClass could be a Single Parser or a ParseChainAnchor
*? need param check

  tcParserClass = ALLTRIM( m.tcParserClass )

  LOCAL loParser

  IF VARTYPE( m.tcModule ) = "C"
    tcModule = ALLTRIM( m.tcModule )
    loParser = NEWOBJECT( m.tcParserClass, m.tcModule )
  ELSE
    loParser = CREATEOBJECT( m.tcParserClass )
  endif
  
  *-- take default stack and regExp objects
  loParser.setStack()
  loParser.setRegExp()
 
  loParser.execute( @m.tcText )

  RETURN m.tcText

ENDFUNC

* --------------------------------------------------------- *
FUNCTION callparserInContext( tcText, tcParserClass, tcContext )
*-- note tcText may be passed by reference or by value
*-- note tcParseClass could be a Single Parser or a ParseChain
*? need param check

  tcParserClass = ALLTRIM( m.tcParserClass )

  LOCAL loParser

  loParser = CREATEOBJECT( m.tcParserClass )

  *-- take default stack and regExp objects
  loParser.setStack()
  loParser.setRegExp()
  
  * kluge alert: a work around to force parsechainanchors to forge early so we can setContext below.
  IF PEMSTATUS( loParser,"forgeChain",5)
    loParser.forgeChain()
  ENDIF
 
  IF VARTYPE( m.tcContext ) = "C"
    loParser.setContext( m.tcContext )
  ENDIF 
  
  loParser.execute( @tcText )

  RETURN m.tcText

ENDFUNC

* --------------------------------------------------------- *
FUNCTION L7parseOnView( tcText)
  IF VARTYPE(goL7App) = "O" AND VARTYPE(goL7App.oParseManager) = "O"
    goL7App.oParseManager.parseByName("L7ParseOnViewChain", @tcText)
  ELSE
    callParserDirect(@tcText, "L7ParseOnViewChain")
  ENDIF
  RETURN m.tcText
ENDFUNC

*--------------------------------------------- 
function encodeForHTML( tcText ) as string 
* converts common code chars for html display
  tctext = strtran( m.tctext, [&], [&amp;] )
  tctext = strtran( m.tctext, [<], [&lt;]  )
  tctext = strtran( m.tctext, [>], [&gt;]  )
 * tctext = strtran(tctext, ["], [&quot;])
return m.tcText
endfunc

**************************************************************************
** CHANGE LOG
**************************************************************************
#IF .f.
07/18/2002:  Wrote tests for and fixed various text decorators that failed if the pattern was at the very start or very end of the string
07/19/2002:  Wrote extra tests for tables at start and end of text fixed tableparser to pass
07/20/2002:  Re-wrote CRParser to work without regexp and to avoid cutting up tables, lists, etc
07/20/2002:  Resolved conflict between the |* th metaphor and *strong text decoration
07/20/2002:  Added InternetParser class
07/22/2002:  Fixed conflicts between InternetParser class and existing links in the text
07/22/2002:  Extended TableParser features to include {align,colspan} directives
07/24/2002:  Fixed bug in TextDecorator that causes _*strong,emph*_ to not be parsed
07/24/2002:  Added L7PageLink parser (delegates to PAGE) 
07/24/2002:  Tracked down some rogue CRLF's being inserted by the ListParser
08/15/2002:  Renamed to L7 prefixes, refactored some methods up into L7BaseParser,  and removed SingleParser, added logging to L7BaseParser
08/16/2002:  Brought code to framework level, added m., declared locals etc
08/19/2002:  Added L7ParseChainManager, L7StripActiveContent, added "contextSet" param to L7MultiParser::addParse()
08/20/2002:  Added L7DynamicMarkers, tidied some aspects of setting and checking context
08/21/2002:  finished L7ParseChainManager, added tests, debugged, added default context checking in isValidContext
09/09/2002:  added PEMSTATUS L7ParseChainManager, so chains to not have to be anchored to be managed
09/11/2002:  added L7ParseOnView() UDF [RP].
09/16/2002:  added L7BreakLines class [lc]
10/22/2002:  vast improvements to CR parser, now can function in the context of mixed html/plaintext
10/22/2002:  added IgnoreHTMLParser for parsing text that contains a mixture of raw HTML and plain-text to be parsed
10/27/2002:  re-vamped the replaceex() function to properly escape any content used in EVALUTE() this allows much larger strings and enhances security
10/31/2002:  small modifications to internet parser to allow more link variations (query string params etc)
11/02/2002:  fixed memory leak in stack usage
11/15/2002:  minor bug fixes and enhancements to internet parser and br parser
12/30/2002:  added <script to the list of things IgnoreHTMLParser will remove since we'll almost never want to parse that region
12/30/2002:  added rowspan capabilitites to TableParser via {cols,rows} attributes. Also added multi-line capabilitites with ~ extension
01/08/2003:  added config methods to parsers and managers to allow a config object to be passed down the chain
01/20/2003:  added dependency on L7BR, and L7.H in general
01/22/2003:  fixed list parser to ignore * that do not have a space after them to allow footnotes and the like.
02/12/2003:  added some extra table tags to the CR parser to avoid col,colgroup,tbody etc
02/17/2003:  added <form tags to the HTMLIgnore parser
02/20/2003:  moved L7Lightweight and L7Stack to l7utils.prg [RP]
02/20/2003:  added H3 and H4 parsers after H2 parser [RP]
02/22/2003:  fixed L7CORLink to comply with L7-standard template method (blocking before call etc) [LC]
02/22/2003:  moved L7CORLink to L7Utils.prg [LC]
03/30/2003:  fixed problem with IgnoreHTML parser and Internet parser that left contents of <a tags open to be re-parsed causing double-linking in some cases
04/16/2003:  added .lEncodeEmail option to the internet parser to encode MailTo: links as an anti-spam measure. By default, this is on. [lc]
04/17/2003:  added preliminary L7ParseCleanup class for cleaning common illegal chars [LC]
11/29/2003:  changed "goApp" to "goL7App" in L7ParseOnView() UDF [RP]
12/01/2003:  added CHR(167) to &sect; in pasted-value parser [RP]
10/28/2005:  added nHitMod governer to BaseParser and MultiParser support for it [LC]
10/03/2006:  added # as numeric trigger for list parser [RP]
#ENDIF