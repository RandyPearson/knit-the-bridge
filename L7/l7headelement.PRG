* L7HeadElement.PRG
*
* Encapsulate <head> element section.
*
#INCLUDE L7.H

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


*** ========================================================= ***
DEFINE CLASS L7HeadElement AS L7PageElement
  * Special sub-class to handle the <HEAD>...</HEAD> section.
  cTag = "head"

  * <base> URI:
  cBaseUrl = NULL
  
  * Array for handling <meta name= ... > tags:
  DIMENSION aMetaNames[ 1, 2]
  nMetaNames = 0
  * plus special properties for robot control:
  lRobotsIndex = .F.
  lRobotsFollow = .F.

  * Array for handling <meta http-equiv= ... > tags:
  DIMENSION aMetaHttpEquivs[ 1, 2]
  aMetaHttpEquivs[ 1, 1] = "Content-Style-Type"
  aMetaHttpEquivs[ 1, 2] = "text/css"
  nMetaHttpEquivs = 1

  * Array for links to external style sheets:
  DIMENSION aCssLinks[ 1, 2]
  nCssLinks = 0

  * Array for <style> tag content:
  DIMENSION aStyles[ 1, 2]  && cols are: content, media (def: all)
  nStyles = 0

  * This is now encapsulated in JS manager object:
  *!*    * Array for JavaScript:
  *!*    DIMENSION aJavaScript[ 1, 3]
  *!*    * Columns are code, source, and language version.
  *!*    nJavaScript = 0
  
  * Properties typically inherited from Page object:
  cTitle       = NULL
  cSubTitle    = NULL  && allow cascaded page title spec.
  cTopUrl      = NULL
  cAuthor      = NULL
  cKeywords    = NULL
  cGenerator   = NULL
  cDescription = NULL
  cFavicon     = NULL 
  cCssFile     = NULL
  cJsFile      = NULL
  lInheritFromPage = .T.

  * Extra relative URL support:
  cPreviousUrl = NULL
  cNextUrl     = NULL
  cUpUrl       = NULL
  cFirstUrl    = NULL
  cLastUrl     = NULL
  
  ADD OBJECT oJavaScriptManager AS L7JavaScriptManager
  * Note TITLE, AUTHOR, KEYWORDS, etc. are parent-level properties.
  * --------------------------------------------------------- *
  FUNCTION Clear
    THIS.nMetaNames = 0
    THIS.nMetaHttpEquivs = 0
    DODEFAULT()
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION IsInPage
    RETURN VARTYPE(m.Page) = "O" && crude heuristic
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION InheritFromPage
    LOCAL loPage
    loPage = m.Page
    WITH THIS
      .cTitle       = NVL(.cTitle, m.loPage.cTitle)
      .cSubTitle    = NVL(.cSubTitle, m.loPage.cSubTitle)
      .cTopUrl      = NVL(.cTopUrl, m.loPage.cTopUrl)
      .cAuthor      = NVL(.cAuthor, m.loPage.cAuthor)
      .cKeywords    = NVL(.cKeywords, m.loPage.cKeywords)
      .cGenerator   = NVL(.cGenerator, m.loPage.cGenerator)
      .cCssFile     = NVL(.cCssFile, m.loPage.cCssFile)
      .cJsFile      = NVL(.cJsFile, m.loPage.cJsFile)
      .cDescription = NVL(.cDescription, m.loPage.cDescription)
      .cFavicon     = NVL(.cFavicon, m.loPage.cFavicon)
    ENDWITH
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcTxt)
    WITH THIS
      LOCAL llInPage
      IF THIS.lInheritFromPage
        llInPage = .IsInPage()
        IF m.llInPage
          .InheritFromPage()
        ENDIF
      ENDIF
      lcTxt = m.lcTxt + .GetBaseTag()  && per spec, this must come before any external HREF
      lcTxt = m.lcTxt + .GetMetaHttpEquivs()
      lcTxt = m.lcTxt + .GetTitle()
      IF NOT EMPTY( .cTopUrl ) AND NOT ISNULL( .cTopUrl)
        lcTxt = m.lcTxt + [<link rel="home" title="Home" href="] + .cTopUrl + [" />] + CRLF
      ENDIF
      IF NOT EMPTY( .cUpUrl ) AND NOT ISNULL( .cUpUrl)
        lcTxt = m.lcTxt + [<link rel="up" title="Up" href="] + .cUpUrl + [" />] + CRLF
      ENDIF
      IF NOT ISNULL( .cFirstUrl)
        lcTxt = m.lcTxt + [<link rel="first" title="First" href="] + .cFirstUrl + [" />] + CRLF
      ENDIF
      IF NOT ISNULL( .cPreviousUrl)
        lcTxt = m.lcTxt + [<link rel="previous" title="Previous" href="] + .cPreviousUrl + [" />] + CRLF
      ENDIF
      IF NOT ISNULL( .cNextUrl)
        lcTxt = m.lcTxt + [<link rel="next" title="Next" href="] + .cNextUrl + [" />] + CRLF
      ENDIF
      IF NOT ISNULL( .cLastUrl)
        lcTxt = m.lcTxt + [<link rel="last" title="Last" href="] + .cLastUrl + [" />] + CRLF
      ENDIF
      IF NOT ISNULL( .cFavicon)
        lcTxt = m.lcTxt + [<link rel="icon"] + ;
          [ type="image/] + juststem(.cFavicon) + [" href="] + .cFavicon + [" />] + CRLF
      ENDIF

      IF NOT EMPTY( .cAuthor ) AND NOT ISNULL( .cAuthor)
      	lcTxt = m.lcTxt + [<meta name="author" content="] + .cAuthor + [" />] + CRLF
      ENDIF
      IF NOT EMPTY( .cKeywords ) AND NOT ISNULL( .cKeywords)
      	lcTxt = m.lcTxt + [<meta name="keywords" content="] + .cKeywords + [" />] + CRLF
      ENDIF
      IF NOT EMPTY( .cDescription ) AND NOT ISNULL( .cDescription )
      	lcTxt = m.lcTxt + [<meta name="description" content="] + .cDescription + [" />] + CRLF
      ENDIF
      IF NOT EMPTY( .cGenerator ) AND NOT ISNULL( .cGenerator)
      	lcTxt = m.lcTxt + [<meta name="generator" content="] + .cGenerator + [" />] + CRLF
      ENDIF

      lcTxt = m.lcTxt + .GetMetaNames()
      lcTxt = m.lcTxt + .GetCssLinks()
      lcTxt = m.lcTxt + .GetStyles()
      
      IF NOT m.llInPage OR NOT (Page.lError OR Page.lErrorMsg)
        * If any error occurred, assume JS etc. should not be included
        * (could provide content/function the user doesn't deserve):
        lcTxt = m.lcTxt + .GetJavaScript()
        lcTxt = m.lcTxt + .cText
      ENDIF
      
      * Note: ApplyTag() will now wrap this all with <head>...</head>
    ENDWITH
    RETURN
  ENDFUNC  && RenderImplementation
  * --------------------------------------------------------- *
  FUNCTION GetBaseTag
    LOCAL lcStr
    lcStr = ""
    IF NOT ISNULL(THIS.cBaseUrl) AND NOT EMPTY(THIS.cBaseUrl) 
      lcStr = [<base href="] + THIS.cBaseUrl + [" />] + CRLF
    ENDIF
    RETURN m.lcStr
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetRefresh(lnSeconds, lcAltUrl)
  *[[ TO DO: refactor this so properties are set and used later
  * to build the string -- that way properties can get set again w/o creating 2 elements
    * Defaults to 15 minutes if no time constant passed.
    THIS.AddMetaHttpEquiv( "Refresh", ;
    	LTRIM( STR( IIF( VARTYPE( m.lnSeconds) <> "N", 300, m.lnSeconds))) + ;
    	IIF( EMPTY( m.lcAltUrl), '', ';URL=' + m.lcAltUrl) )
    RETURN
  ENDFUNC  && SetRefresh
  * --------------------------------------------------------- *
  FUNCTION AddKeywords(lcList)
    * Allows appending w/o worrying about current value.
    LOCAL lcTxt
    lcTxt = NVL(THIS.cKeywords, "")
    lcTxt = m.lcTxt + IIF(EMPTY(m.lcTxt), [], [, ]) + m.lcList
    THIS.cKeywords = m.lcTxt
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddMetaName(lcName, lcContent)
    LOCAL ii, llFound
    FOR ii = 1 TO THIS.nMetaNames
    	IF THIS.aMetaNames[ m.ii, 1] == m.lcName
    		* Already exists, replace!
    		llFound = .T.
    		THIS.aMetaNames[ m.ii, 2] = m.lcContent
    		EXIT
    	ENDIF
    ENDFOR
    IF NOT m.llFound
    	THIS.nMetaNames = THIS.nMetaNames + 1
    	DIMENSION THIS.aMetaNames[ THIS.nMetaNames, 2]
    	THIS.aMetaNames[ THIS.nMetaNames, 1] = m.lcName
    	THIS.aMetaNames[ THIS.nMetaNames, 2] = m.lcContent
    ENDIF
    RETURN
  ENDFUNC  && AddMetaName
  * --------------------------------------------------------- *
  FUNCTION AddJavaScript(lcCode, lcUrl, lcVersion)
    THIS.oJavaScriptManager.AddJavaScript( lcCode, lcUrl, lcVersion )
    RETURN
  ENDFUNC  && AddJavaScript
  * --------------------------------------------------------- *
  FUNCTION GetJavaScript
    LOCAL lcTxt, lnWord, lcWord
    lcTxt = ""
    IF NOT EMPTY(THIS.cJsFile) AND NOT ISNULL(THIS.cJsFile)
      * 7/30/07 - revised to support comma-delimied list of files
      FOR lnWord = 1 TO GETWORDCOUNT(THIS.cJsFile, ",")
        lcWord = ALLTRIM(GETWORDNUM(THIS.cJsFile, m.lnWord, ","))
        IF NOT EMPTY(m.lcWord)
          lcTxt = m.lcTxt + [<script type="text/javascript"] + ;
            [ language="javascript] + L7_DEFAULT_JAVASCRIPT_VERSION + ["] + ;
            [ src="] + m.lcWord + ["></script>] + CRLF
        ENDIF 
      NEXT lnWord
    ENDIF
    lcTxt = m.lcTxt + THIS.oJavaScriptManager.GetJavaScript( )
    RETURN m.lcTxt 
  ENDFUNC  && GetJavaScript
  * --------------------------------------------------------- *
  FUNCTION GetTitle
    LOCAL lcTxt
    lcTxt = ""
    WITH THIS
      IF NOT EMPTY(.cTitle) AND NOT ISNULL(.cTitle)
        lcTxt = m.lcTxt + STRTRAN( .cTitle, L7BR, [: ], -1, -1, 1)
        IF NOT EMPTY(.cSubTitle) AND NOT ISNULL(.cSubTitle)
          lcTxt = m.lcTxt + ": " + .cSubTitle
        ENDIF
        lcTxt = [<title>] + m.lcTxt + [</title>] + CRLF
      ENDIF
    ENDWITH
    RETURN m.lcTxt
  ENDFUNC  && GetTitle
  * --------------------------------------------------------- *
  FUNCTION GetMetaNames
    LOCAL ii, lcRet, llGotRobots
    lcRet = ""
    FOR ii = 1 TO THIS.nMetaNames
    	lcRet = m.lcRet + [<meta name="] + ;
    		THIS.aMetaNames[ m.ii, 1] + [" content="] + ;
    		THIS.aMetaNames[ m.ii, 2] + [" />] + CHR(13) + CHR(10)
      IF LOWER(THIS.aMetaNames[ m.ii, 1]) == "robots"
        llGotRobots = .T.
      ENDIF
    ENDFOR
    IF NOT m.llGotRobots 
      lcRet = m.lcRet + THIS.GetRobots()
    ENDIF
    RETURN m.lcRet
  ENDFUNC  && GetMetaNames
  * --------------------------------------------------------- *
  FUNCTION GetRobots
    IF THIS.lRobotsIndex AND THIS.lRobotsFollow
      RETURN ""  && default: good practice is to omit directive entirely
    ELSE
      RETURN [<meta name="robots" content="] + ;
        IIF(THIS.lRobotsIndex, "index", "noindex") + ; 
        [,] + ;
        IIF(THIS.lRobotsFollow, "follow", "nofollow") + ; 
        [" />] + CRLF
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddMetaHttpEquiv(lcName, lcContent, llAppend)
    LOCAL ii, llFound
    FOR ii = 1 TO THIS.nMetaHttpEquivs
    	IF THIS.aMetaHttpEquivs[ m.ii, 1] == m.lcName
         llFound = .T.
         IF m.llAppend
            * Append to current
             THIS.aMetaHttpEquivs[ m.ii, 2] = THIS.aMetaHttpEquivs[ m.ii, 2] + ", " + m.lcContent
         ELSE
    		   * Already exists, replace!
    		   THIS.aMetaHttpEquivs[ m.ii, 2] = m.lcContent
         ENDIF m.llAppend
    		EXIT
    	ENDIF
    ENDFOR
    IF NOT m.llFound
    	THIS.nMetaHttpEquivs = THIS.nMetaHttpEquivs + 1
    	DIMENSION THIS.aMetaHttpEquivs[ THIS.nMetaHttpEquivs, 2]
    	THIS.aMetaHttpEquivs[ THIS.nMetaHttpEquivs, 1] = m.lcName
    	THIS.aMetaHttpEquivs[ THIS.nMetaHttpEquivs, 2] = m.lcContent
    ENDIF
    RETURN
  ENDFUNC  && AddMetaHttpEquiv
  * --------------------------------------------------------- *
  FUNCTION GetMetaHttpEquivs
    LOCAL ii, lcRet
    lcRet = ""
    FOR ii = 1 TO THIS.nMetaHttpEquivs
    	lcRet = m.lcRet + [<meta http-equiv="] + ;
    		THIS.aMetaHttpEquivs[ m.ii, 1] + [" content="] + ;
    		THIS.aMetaHttpEquivs[ m.ii, 2] + [" />] + CRLF
    ENDFOR
    RETURN m.lcRet
  ENDFUNC  && GetMetaHttpEquivs
  * --------------------------------------------------------- *
  FUNCTION AddStyle(lcContent, lcMedia, lvInsert)
    LOCAL lnRow, llFound, lcInsType
    lcMedia = EVL(m.lcMedia, "all")
    FOR lnRow = 1 TO THIS.nStyles
      IF THIS.aStyles[m.lnRow, 1] == m.lcContent AND THIS.aStyles[m.lnRow, 1] == m.lcMedia
        llFound = .T.
        EXIT
      ENDIF
    ENDFOR
    IF NOT m.llFound
      THIS.nStyles = THIS.nStyles + 1
      DIMENSION THIS.aStyles[ THIS.nStyles, 2]
      lcInsType = VARTYPE(m.lvInsert)
      DO CASE
      CASE m.lcInsType = "L" AND m.lvInsert = .T.
        * Insert at top.
        lnRow = 1
        AINS(THIS.aStyles, m.lnRow)
      CASE m.lcInsType = "N" AND m.lvInsert < THIS.nStyles
        * Insert before specific row.
        lnRow = m.lvInsert
        AINS(THIS.aStyles, m.lnRow)
      OTHERWISE  && at end
        lnRow = THIS.nStyles
      ENDCASE
      THIS.aStyles[m.lnRow, 1] = m.lcContent
      THIS.aStyles[m.lnRow, 2] = m.lcMedia
    ENDIF
    RETURN
  ENDFUNC  && AddStyle
  * --------------------------------------------------------- *
  FUNCTION GetStyles
    LOCAL ii, lcRet
    lcRet = ""
    WITH THIS
      * Attach each <style> block ad via AddStyle():
      FOR ii = 1 TO .nStyles
        lcRet = m.lcRet + [<style] + ;
          [ media="] + .aStyles[ m.ii, 2] + ["] + ;
          [ type="text/css">] + CRLF + ;
          .aStyles[ m.ii, 1] + ;
          [</style>] + CRLF
      ENDFOR
    ENDWITH
    RETURN m.lcRet
  ENDFUNC  && GetStyles
  * --------------------------------------------------------- *
  FUNCTION AddCssLink(lcFile, lcMedia)
    lcMedia = EVL(m.lcMedia, "all")
    THIS.nCssLinks = THIS.nCssLinks + 1
    DIMENSION THIS.aCssLinks[ THIS.nCssLinks, 2]
    THIS.aCssLinks[ THIS.nCssLinks, 1] = m.lcFile
    THIS.aCssLinks[ THIS.nCssLinks, 2] = m.lcMedia
    RETURN
  ENDFUNC  && AddCssLink
  * --------------------------------------------------------- *
  FUNCTION GetCssLinks
    LOCAL ii, lcRet
    lcRet = ""
    WITH THIS
      * First, include any default CSS (media assumed to be "all"):
      IF NOT EMPTY( .cCssFile ) AND NOT ISNULL( .cCssFile )
      	lcRet = m.lcRet + [<link rel="stylesheet" href="] + .cCssFile + ;
          [" media="all" type="text/css" />] + CRLF
      ENDIF
      * Then attach each additional link added via AddCssLink():
      FOR ii = 1 TO .nCssLinks
      	lcRet = m.lcRet + [<link rel="stylesheet"] + ;
          [ href="] + .aCssLinks[ m.ii, 1] + ["] + ;
          [ media="] + .aCssLinks[ m.ii, 2] + ["] + ;
      		[ type="text/css" />] + CRLF
      ENDFOR
    ENDWITH
    RETURN m.lcRet
  ENDFUNC  && GetCssLinks
  * --------------------------------------------------------- *
  FUNCTION GetMergeStrategyObject
    LOCAL loObj
    loObj = CREATEOBJECT("Empty")
    ADDPROPERTY(m.loObj, "Title",  "SubTitle")  && {"IfEmpty", "SubTitle", "Replace", "Ignore"}
    ADDPROPERTY(m.loObj, "Script", "Append")
    ADDPROPERTY(m.loObj, "Style",  "Append")
    ADDPROPERTY(m.loObj, "LinkCss", "Append")   && {"Ignore", "Replace", "Append", "Prepend"}
    * Pending:
    ADDPROPERTY(m.loObj, "MetaHttpEquiv", "Ignore")
    * ADDPROPERTY(m.loObj, "MetaName", "Ignore")
    RETURN m.loObj
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Merge(lcTxt, loStrategy)
    * Takes an extracted block of HTML and merges the pieces into
    * the properties here, so that a fully-reconciled <head> section
    * can be generated, taking into account both application settings
    * and important artifacts found on any merged page(s).
    WITH THIS
      IF VARTYPE(m.loStrategy) <> 'O'
        * The idea here is that a participating object _can_ set up its 
        * own merge-strategy settings, but it doesn't have to, in which case
        * the defaults here will govern.
        loStrategy = .GetMergeStrategyObject()
      ENDIF
      .MergeTitles(@lcTxt, m.loStrategy)
      .MergeCssLinks(@lcTxt, m.loStrategy)
      .MergeScripts(@lcTxt, m.loStrategy)
      .MergeMetaHttpEquivs(@lcTxt, m.loStrategy)
    ENDWITH
    RETURN
    
    * (possible) Placeholder approach:
    *  - ignore meta tags 
    *  - use TITLE only if this object doesn't have one
    *  - add any <link>, <style> or <script> tags at end
    
    * Placeholder for placeholder approach <s>:
    *  - just write whole thing to end for now -- this whole thing needs more thought
    ** THIS.Write(m.lcTxt)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION MergeTitles(lcText, loStrategy)
    * Possibilities:
    * - the page class may know the right title
    * - the template itself may have the right title
    * - the template may have a "dumb" title inserted by the visual tool
    * - we could want a subtitle situation, such as "App Title: Page Title"
    LOCAL lcStrategy
    lcStrategy = loStrategy.Title
    * Quick relevancy checks to avoid RegExp expense:
    IF m.lcStrategy == "IfEmpty" AND NOT EMPTY(THIS.GetTitle())
      RETURN
    ENDIF
    IF NOT "," + m.lcStrategy + "," $ ',Replace,SubTitle,'
      RETURN
    ENDIF
    LOCAL loRE, loMatches, lcTitle, loMatch
    loRE = CREATEOBJECT("L7RegExp")
    WITH loRE
      .Pattern = '(?:<title[^>]*>)([^<]*)(?:<\/title>)'  && [[ verify pattern
      .IgnoreCase = .T.
      .MultiLine = .T.
      .Global = .F. && only one title, we hope; use .T. in most other cases
      loMatches = .Execute(@lcText) && [[pass-by-ref OK here?
      IF loMatches.Count < 1
        lcTitle = ""
      ELSE
        loMatch = loMatches.item[1]
        lcTitle = loMatch.SubMatches[1]
      ENDIF
    ENDWITH
    IF EMPTY(m.lcTitle)
      * Do nothing. [[Are there any cases where we still would do something?
    ELSE
      DO CASE
      CASE m.lcStrategy == "Replace" OR m.lcStrategy == "IfEmpty" && we already verified IfEmpty relevancy above
        THIS.cTitle = m.lcTitle
      CASE m.lcStrategy == "SubTitle"
        THIS.cSubTitle = m.lcTitle
      ENDCASE
    ENDIF
    RETURN
  ENDFUNC  && MergeTitles
  * --------------------------------------------------------- *
  FUNCTION MergeCssLinks(lcText, loStrategy)
    * Possibilities:
    * - start with application settings, but append page settings if present
    LOCAL lcStrategy
    lcStrategy = loStrategy.LinkCss
    * Quick relevancy check to avoid RegExp expense:
    IF NOT "," + m.lcStrategy + "," $ ',Replace,Append,Prepend,'
      RETURN
    ENDIF
    LOCAL loRE, loMatches, loMatch, loTag, ii, lcHref, lcMedia
    loRE = CREATEOBJECT("L7RegExp")
    WITH loRE
      .Pattern = '<link[^>]*>'  && [[ verify pattern
      .IgnoreCase = .T.
      .MultiLine = .T.
      .Global = .T. 
      loMatches = .Execute(@lcText) && [[pass-by-ref OK here?
      FOR ii = 1 TO loMatches.Count 
        loMatch = loMatches.item[m.ii]
        loTag = L7TagToObject(loMatch.Value)
        IF (VARTYPE(loTag.Rel) <> 'C' OR loTag.Rel <> 'stylesheet') AND ;
          (VARTYPE(loTag.Type) <> 'C' OR loTag.Type <> 'text/css')
          * Some other <link> tag.
          LOOP
        ENDIF
        lcHref = IIF(VARTYPE(loTag.Href) = "C", loTag.Href, "")
        IF EMPTY(m.lcHref)
          LOOP
        ENDIF
        lcMedia = IIF(VARTYPE(loTag.Media) = "C", loTag.Media, "all")
        * Assume for the moment that Append is only strategy:
        THIS.AddCssLink(m.lcHref, m.lcMedia)
      ENDFOR
    ENDWITH
    RETURN
  ENDFUNC  && MergeCssLinks
  * --------------------------------------------------------- *
  FUNCTION MergeScripts(lcText, loStrategy)
    * Possibilities:
    * - start with application scripts, but append page scripts if present
    LOCAL lcStrategy
    lcStrategy = loStrategy.Script
    * Quick relevancy check to avoid RegExp expense:
    IF NOT "," + m.lcStrategy + "," $ ',Replace,Append,Prepend,'
      RETURN
    ENDIF
    LOCAL loRE, loMatches, loMatch, loTag, ii, lcSrc, lcCode, lcVersion
    loRE = CREATEOBJECT("L7RegExp")
    WITH loRE
      .Pattern = '(<script[^>]*>)(.*?)<\/script>'  && [[ verify pattern
      .IgnoreCase = .T.
      .MultiLine = .T.
      .Global = .T. 
      loMatches = .Execute(@lcText) && [[pass-by-ref OK here?
      FOR ii = 1 TO loMatches.Count 
        loMatch = loMatches.item[m.ii]
        loTag = L7TagToObject(loMatch.Submatches[1])
        lcScript = ALLTRIM(loMatch.Submatches[2])
        
        * We're dealing with either 
        * 1) External JS:
        *    <script language="JavaScript" src="something.js" ...></script>
        * 2) Inline JS code:
        *    <script language="JavaScript" ...>JS code here...</script>
        
        IF VARTYPE(loTag.Type) = "C" AND LOWER(loTag.Type) <> "text/javascript"
          LOOP
        ENDIF
        lcVersion = ""
        IF VARTYPE(loTag.Language) = "C" 
          lcLang = loTag.Language
          IF LOWER(m.lcLang) <> "javascript"
            LOOP
          ENDIF
          lcVersion = SUBSTR(m.lcLang, 1 + LEN("javascript"))
        ENDIF
        lcSrc = IIF(VARTYPE(loTag.Src) = "C", loTag.Src, "")
        * Assume for the moment that Append is only strategy:
        THIS.AddJavaScript(m.lcScript, m.lcSrc, m.lcVersion)
      ENDFOR
    ENDWITH
    RETURN
  ENDFUNC  && MergeScripts
  * --------------------------------------------------------- *
  FUNCTION MergeMetaHttpEquivs(lcText, loStrategy)
    * Possibilities:
    * - start with application settings, but append page settings if present
    LOCAL lcStrategy
    lcStrategy = loStrategy.LinkCss
    * Quick relevancy checks to avoid RegExp expense:
    IF NOT "<meta http-equiv" $ LOWER(m.lcText)
      RETURN
    ENDIF
    IF NOT "," + m.lcStrategy + "," $ ',Replace,Append,Prepend,'
      RETURN
    ENDIF
    LOCAL loRE, loMatches, loMatch, lcName, lcContent
    loRE = CREATEOBJECT("L7RegExp")
    WITH loRE
      .Pattern = '<meta http-equiv="([^"]+)" content="([^"]+)".*>'  && [[ verify pattern
      .IgnoreCase = .T.
      .MultiLine = .T.
      .Global = .T. 
      loMatches = .Execute(@lcText) && [[pass-by-ref OK here?
      FOR ii = 1 TO loMatches.Count 
        loMatch = loMatches.item[m.ii]

        lcName = ALLTRIM(loMatch.Submatches[1])
        lcContent = ALLTRIM(loMatch.Submatches[2])

        IF EMPTY(m.lcName) OR EMPTY(m.lcContent)
          LOOP
        ENDIF
        * Assume for the moment that Append is only strategy:
        THIS.AddMetaHttpEquiv(m.lcName, m.lcContent)
      ENDFOR
    ENDWITH
    RETURN
  ENDFUNC  && MergeMetaHttpEquivs
  
ENDDEFINE  && L7HeadElement

*** ===================================================== ***
#if .f.
12/21/2002 - changed media from "screen" to "all" for default CSS link.
12/31/2002 - renamed various "layer" classes to use term "element" instead
01/10/2003 - added meta name="robots" support
01/12/2003 - remove DODEFAULT() from Render() and eliminate JS inclusion if errors occurred in page
01/14/2002 - changed render() to renderImplementation to fit with new template methods in L7PageElement
01/18/2003 - changed cElement to cTag, and removed call to RenderSimple
01/19/2003 - made capable of running standalone (i.e., with no Page)
04/03/2003 - removed media default of "Screen" (sic)
04/15/2003 - added cDescription to InheritFromPage()
05/09/2003 - added support for optional page.cJsFile 
09/01/2003 - added cTopUrl property and generation of <link rel="home"> tag
           - added AddKeywords() method
09/16/2003 - corrected cTopUrl typo in InheritFromPage()
           - added default HTTP-EQUIV for Content-Style-Type = "text/css"
           - revised GetRobots() to be silent when all defaults are set
10/09/2003 - added <base href=""> support. See GetBaseTag().
10/28/2003 - commenced development of detailed Merge methods.
09/06/2004 - GetJavaScript() revised to specify v. 1.2 for external links
03/15/2005 - revised BASE tag to use full Request.cCurrentUrl (so hash links don't cause server hits)
03/24/2005 - revised BASE tag so it doesn't attempt to extract from Page or Request
08/04/2005 - added flag to block inheriting from Page object
#endif

* End: L7HeadElement.PRG
