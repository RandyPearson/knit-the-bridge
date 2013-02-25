* L7ExpandTemplate.PRG

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

#if .f.  && EXAMPLE SNIPPET:
  <!-- DISPLAY LIST OF NOTIFICATIONS -->
  <l7:if expr="page.nNtf=0">
   
   <table cellpadding=2 cellspacing=1 border=0 id="ntf_table">
    <thead>
     <tr>
      <th id="opr_short_name">Operator</th>
      <th id="ntf_title">Title</th>
      <th id="ntf_status">Status</th>
      <th id="ntf_date" abbr="date">Date of<br>OPS Review</th>
     </tr>
    </thead>
    <tbody>
     <l7:scan>
      <tr valign=top>
       <td headers="opr_short_name"><<opr_short_name>></td>
       <td headers="ntf_title">
         <a href="<<StuffUrl(page.cUrl,'ntf',Ntf_PK)>>"><<Ntf_title>>
         </a></td>
       <td headers="ntf_status">
        <<Ntf_Status>>
        <<IIF(Ntf_Interstate,"","<br>(State: " + TRIM(Ntf_Affected_States)+")")>>
       </td>
       <td headers="ntf_date"><<EVL(Ntf_Response_Date,"&nbsp;")>></td>
      </tr>
     </l7:scan>
    </tbody>
   </table>
  </l7:if>
  <!-- END: DYNAMIC IMDB CONTENT -->
#endif

FUNCTION L7ExpandTemplateSnippet(tcStr)
  LOCAL loET
  loET = CREATEOBJECT("L7ExpandTemplate")
  loET.MergeText(@tcStr)
  RETURN m.tcStr
ENDFUNC 

*** ========================================================= ***
DEFINE CLASS L7ExpandTemplate AS CUSTOM
  cScript          = ""
  cFileName        = ""
  *!* nHeadOptions     = 0
  oHeadStrategy    = NULL
  nBodyTagOptions  = 0
  cHeadSection     = ""
  cBodySection     = ""
  cBodyAttributes  = ""
  lTesting         = .F.
  lCodeLines       = .T.  && run lines between <l7:codelines>...</l7:codelines>
  lSafeTextmerge   = .F.  && avoid textmerge recursion by using eval()
  
  cDelimA = L7_TEXTMERGE_DELIM_1  && "<%=" && switch to "<<" for pure textmerge (DEFAULT)
  cDelimB = L7_TEXTMERGE_DELIM_2  && "%>"  &&           ">>"
  * CAUTION: If you're thinking of overriding these properties, you
  * should consider use of SetDelimiters() instead.
  * --------------------------------------------------------- *
  FUNCTION SetDelimiters(lcA, lcB)
    THIS.cDelimA = m.lcA
    THIS.cDelimB = m.lcB
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Expand(lcScript)
    IF NOT EMPTY(m.lcScript)
      THIS.cScript = m.lcScript
    ENDIF
    IF EMPTY(THIS.cScript)
      IF NOT EMPTY(THIS.cFileName)
        IF NOT FILE(THIS.cFileName)
          ERROR [File "] + THIS.cFileName + [" not found!]
          RETURN
        ELSE
          THIS.cScript = FILETOSTR(THIS.cFileName)
        ENDIF
      ENDIF
    ENDIF
    IF VARTYPE(Response) <> "O" && enable testing
      PRIVATE Response
      Response = CREATEOBJECT("L7PageElement")
      THIS.lTesting = .T.
    ENDIF
    THIS.ParseElements()
    THIS.ProcessHeadSection()
    THIS.ProcessBodyTag()
    THIS.ProcessBodySection()
    IF THIS.lTesting
      ShowHtml(Response.Render())
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ParseElements
    LOCAL lnAt1, lnAt2, lnAt3, lcScript
    lcScript = THIS.cScript
    lnAt1 = ATC("<body", m.lcScript)
    IF m.lnAt1 > 0
      lnAt2 = AT('>',SUBSTR(m.lcScript,m.lnAt1))
      IF m.lnAt2 > 0
        IF m.lnAt2 > LEN("<body>")
          THIS.cBodyAttributes = ALLTRIM( ;
            SUBSTR(m.lcScript,m.lnAt1 + LEN("<body"), m.lnAt2 - 1 - LEN("<body")))
        ENDIF
        lnAt3 = ATC("</body>",m.lcScript)
        IF m.lnAt3 > m.lnAt1
          THIS.cBodySection = SUBSTR(m.lcScript, m.lnAt1 + m.lnAt2, lnAt3 - (m.lnAt1 + m.lnAt2))
        ELSE
          THIS.cBodySection = SUBSTR(m.lcScript, m.lnAt1 + m.lnAt2)
        ENDIF
      ELSE
        ERROR "Invalid template--could not parse BODY tag."
        RETURN
      ENDIF
      * Get HEAD section if any:
      lnAt1 = ATC("<head>", m.lcScript)
      IF m.lnAt1 > 0
        lnAt2 = ATC("</head>", m.lcScript)
        IF m.lnAt2 = 0 && no closing tag
          lnAt2 = ATC("<body", m.lcScript)
        ENDIF
        THIS.cHeadSection = SUBSTR(m.lcScript, m.lnAt1 + LEN("<head>"), ;
          m.lnAt2 - m.lnAt1 - LEN("<head>"))
      ELSE  && no head section, that's OK
      ENDIF
    ELSE  && no body tag--assume all
      THIS.cBodySection = STRTRAN(STRTRAN(m.lcScript,"<html>","",1,1,1),"</html>","",1,1,1)
    ENDIF
  ENDFUNC  && ParseElements
  * --------------------------------------------------------- *
  FUNCTION ProcessHeadSection
    LOCAL lcText
    lcText = THIS.MergeText(THIS.cHeadSection)
    IF THIS.lTesting = .F.
      Page.oHead.Merge(m.lcText, THIS.oHeadStrategy) && pass optional head-merge-strategy object
    ELSE
      Response.Write([<html><head>] + m.lcText + [</head>])
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ProcessBodyTag
    LOCAL lcText
    IF NOT EMPTY(THIS.cBodyAttributes)
      lcText = L7MergeText(THIS.cBodyAttributes)
    ELSE
      lcText = ""
    ENDIF
    IF NOT THIS.lTesting
      IF NOT EMPTY(m.lcText)
        Page.cBodyAttributes = m.lcText
      ENDIF
    ELSE
      Response.Write([<body ] + m.lcText + [>])
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ProcessBodySection
    * Expand main body into current Response object. Up to application
    * to decide what that should be (entire Body Element, or a sub-Element).
    LOCAL lcText 
    lcText = THIS.MergeText(THIS.cBodySection)
    Response.Write(m.lcText)
    IF THIS.lTesting
      Response.Write('</body></html>')
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION MergeText(lcText)
    LOCAL lcNS, lcPattern, loRE, loMatches, loMatch, llFound, lcMethod, ;
      loTagProps, lnOpenStart, lcOpenTag, lnCloseStart, lcCloseTag, ;
      lcBefore, lcBetween, lcAfter, ;
      lnStackCount, llFoundMate, ii
      
    lcNS = "L7:" && namespace - magic string
    IF ATC("<" + m.lcNS, m.lcText) > 0  && pre-screen looks good
      llFound = .T.
      lcPattern = '<' + m.lcNS + '(\w+)' + ;
        '(' + ;
          '\s+\w+\s*=\s*"[^"]*"' + '|' + ;
          "\s+\w+\s*=\s*'[^']*'" + '|' + ;
          '\s+\w+\s*=\s*\w+' + ;
        ')*\s*>'
      loRE = CREATEOBJECT(L7_REGEXP_CLASS)
      WITH loRE
        .MultiLine = .T.
        .Global = .F. && just seeking first instance, for now
        .IgnoreCase = .T.
        .Pattern = m.lcPattern
        loMatches = .Execute(m.lcText)
      ENDWITH
      IF loMatches.Count < 1
        llFound = .F.
      ELSE
        loMatch = loMatches.item[0]
        lcMethod = LOWER(m.loMatch.submatches[0])
        IF NOT (THIS.lCodeLines AND m.lcMethod=="codelines") AND ;
          ( NOT PEMSTATUS(THIS, m.lcMethod, 5) OR NOT PEMSTATUS(THIS, m.lcMethod, 4) )
          * Ensure we're not calling some VFP method or an undefined one!
          ERROR m.lcNS + m.lcMethod + " is not a valid template tag(0)."
        ENDIF
        lnOpenStart = loMatch.FirstIndex + 1
        lcOpenTag = loMatch.Value
        * Now find all the open/close tags for this method, in order to find the mate.
        WITH loRE
          .Global = .T.  && want all matches this time, both open and close tags
          .Pattern = '<' + m.lcNS + m.lcMethod + '\W' + '|<\/' + m.lcNS + m.lcMethod + '\s*>' 
          loMatches = NULL
          loMatches = .Execute(m.lcText)
          lnCount = loMatches.Count
          IF m.lnCount < 2
            ERROR "No closing tag, or mismatched tags (1)."
          ENDIF
        ENDWITH
        loRE = NULL  &&[[ or, could try to recycle it...
        * Now, iterate the matches until we find an "aligned" closing tag.
        lnStackCount = 0
        llFoundMate = .F.
        FOR ii = 1 TO loMatches.count 
          loMatch = loMatches.item[m.ii - 1]
          lcCloseTag = m.loMatch.Value  && just in case this is "the one"
          llCloseTag = SUBSTR(m.lcCloseTag, 2, 1) == "/"
          IF m.ii = 1  && this should be the very tag we're focusing on -- do some QA checks
            IF loMatch.FirstIndex + 1 <> m.lnOpenStart
              ERROR "Template tag mismatch or parsing error (3)."
            ENDIF
          ENDIF
          IF NOT m.llCloseTag  && open tag
            lnStackCount = m.lnStackCount + 1 
          ELSE
            lnStackCount = m.lnStackCount - 1 
            IF m.lnStackCount = 0
              llFoundMate = .T.
              lnCloseStart = loMatch.FirstIndex + 1
              EXIT  && stop looking 
            ENDIF
          ENDIF
        ENDFOR
        IF NOT m.llFoundMate
          ERROR "No closing tag, or mismatched tags (2)."
        ENDIF
        loTagProps = L7TagToObject(m.lcOpenTag)
        
        lcBefore = LEFT(m.lcText, m.lnOpenStart - 1)
        lcBefore = L7MergeText(m.lcBefore, THIS.cDelimA, THIS.cDelimB)

        lcBetween = SUBSTR(m.lcText, m.lnOpenStart + LEN(m.lcOpenTag), ;
          m.lnCloseStart - m.lnOpenStart - LEN(m.lcOpenTag))
        IF NOT m.lcMethod == "codelines"  && all but "codelines" can be delegated
          lcBetween = EVALUATE("THIS." + m.lcMethod + "(m.lcBetween, m.loTagProps)")
        ELSE  && "codelines"  -- need to run this in-line so PRIVATE's stay in scope
          LOCAL laCodeLines[1], lcCodeLine
          ALINES(laCodeLines, m.lcBetween, .T.)  && must be 1 command per line, no wraps or continuations
          lcBetween = ""  && replace with nada
          FOR EACH lcCodeLine IN laCodeLines
            &lcCodeLine
          ENDFOR
        ENDIF
        
        lcAfter = SUBSTR(m.lcText, m.lnCloseStart + LEN(m.lcCloseTag))
        lcAfter = THIS.MergeText(m.lcAfter)  && recurse, so later structures are covered

        lcText = m.lcBefore + m.lcBetween + m.lcAfter
        
      ENDIF  && loMatches.Count < 1
    ENDIF  && ATC() pre-check        
    IF NOT m.llFound
      IF THIS.lSafeTextmerge
        ** L7SafeMergeText(@lcText, THIS.cDelimA, THIS.cDelimB )
        SafeTextmerge(@lcText, THIS.cDelimA, THIS.cDelimB )
      ELSE
        L7MergeText(@lcText, THIS.cDelimA, THIS.cDelimB )
      ENDIF
    ENDIF
    RETURN m.lcText
  ENDFUNC  && MergeText
  * --------------------------------------------------------- *
  FUNCTION Scan(lcStr, loTagProps)
    LOCAL lcAlias, lcRet, lcStr, lnSelect, lcTemp, lcClauses
    lnSelect = SELECT()
    TRY
      lcAlias = IIF(VARTYPE(loTagProps.Alias) <> "C", "", m.loTagProps.Alias)
      lcRet = ""
      IF NOT EMPTY(m.lcAlias)
        SELECT (m.lcAlias)
      ENDIF
      IF EMPTY(ALIAS())  && preclude open file dialog
        ERROR 52
      ENDIF
      lcClauses = "" + ;
        IIF(VARTYPE(loTagProps.For) <> "C" OR EMPTY(m.loTagProps.For), "", " FOR " + m.loTagProps.For)
      SCAN &lcClauses
        * Combining next 2 lines as 1 triggers VFP bug when recursion occurs: 
        lcTemp = THIS.MergeText(m.lcStr)
        lcRet = m.lcRet + m.lcTemp
      ENDSCAN
    CATCH TO loExc
      lcRet = '[ERROR ' + TRANSFORM(loExc.ErrorNo) + ': "' + loExc.Message + '" in L7Scan tag processing.]'
    FINALLY
      *[[ any need to restore record pointer?
      SELECT (m.lnSelect)
    ENDTRY
    RETURN m.lcRet
  ENDFUNC  && Scan
  * --------------------------------------------------------- *
  FUNCTION ForEach(lcStr, loTagProps)
    LOCAL lcVar, lcGroup, lcStr, lcRet, lcTemp
    TRY
      lcRet = ""
      lcVar = IIF(VARTYPE(loTagProps.Var) <> "C", "poForVar", m.loTagProps.Var)
      lcGroup = loTagProps.Group
      PRIVATE &lcVar
      FOR EACH (m.lcVar) IN (m.lcGroup)
        * Combining next 2 lines as 1 triggers VFP bug when recursion occurs: 
        lcTemp = THIS.MergeText(m.lcStr)
        lcRet = m.lcRet + m.lcTemp
      ENDFOR
    CATCH TO loExc
      lcRet = '[ERROR: "' + loExc.Message + '" in L7ForEach processing.]'
    ENDTRY
    RETURN m.lcRet
  ENDFUNC  && ForEach
  * --------------------------------------------------------- *
  FUNCTION If(lcStr, loTagProps)
    LOCAL lcExpr, llIsTrue, lcRet, lcStr
    TRY
      lcExpr = loTagProps.Expr 
      llIsTrue = EVALUATE(m.lcExpr)
      IF NOT m.llIsTrue
        lcRet = ""
      ELSE
        IF NOT EMPTY(m.lcStr)
          lcRet = THIS.MergeText(m.lcStr)
        ELSE
          lcRet = ""
        ENDIF
      ENDIF
    CATCH TO loExc
      lcRet = '[ERROR: "' + loExc.Message + '" in L7IF tag processing.]'
    ENDTRY
    RETURN m.lcRet
  ENDFUNC  && If
  * --------------------------------------------------------- *
ENDDEFINE  && L7ExpandTemplate 

#if .f.
12/31/2002 - renamed various "layer" classes to use term "element" instead
05/19/2003 - added support for <l7:scan>, <l7:if> and <l7:foreach> (others in l7: namespace easily accomodated)
11/02/2003 - added support for "safe" textmerging (see L7Utils and L7PageElement, also)
11/12/2005 - revised to allow <head> strategy object
#endif

* End: L7ExpandTemplate.PRG
