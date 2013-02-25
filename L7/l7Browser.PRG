* L7Browser.PRG

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


*[[ Should we indicate Doctype/HTML version support level somehow here?
*** ========================================================= ***
DEFINE CLASS L7Browser AS LINE

  lW3CDom    = .T.
  lAllDom    = .F.
  lLayersDom = .F.

  cBrowser   = ""
  cMake      = ""
  cVersion   = ""
  nVersion   = 0
  cLanguage  = "en"  &&[[ To Do: Parse this out.
  cBrowserOS = ""    &&[[ To Do: Parse this out.
  lCrawler   = .F.

  nCssLevel        = 1.0  && set these in ResetProperties!
  nJavaScriptLevel = 1.2  && set these in ResetProperties!
  nVBScriptLevel   = 0    && set these in ResetProperties!
  
  * Element support props:
  lIframes   = .T.
  * --------------------------------------------------------- *
  FUNCTION INIT
    this.resetProperties() && assure object works same on first use
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION ResetProperties
    THIS.lW3CDom    = .T.
    THIS.lAllDom    = .F.
    THIS.lLayersDom = .F.
    
    THIS.cMake      = "[unknown]"
    THIS.cVersion   = "[unknown]"
    THIS.nVersion   = 0
    THIS.cLanguage  = "[unknown]"
    THIS.cBrowserOS = "[unknown]"
    THIS.lCrawler   = .F.

    THIS.nCssLevel  = 1.0
    THIS.nJavaScriptLevel = 1.2
    THIS.nVBScriptLevel   = 0

    THIS.lIframes   = .T.
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetBrowser(lcName)
    * This wasn't appropriate. App (or host) determines calling time for this.
    * See iaBrowser, where we override some native behavior.
    *!* THIS.ResetProperties()
    THIS.cBrowser = m.lcName
    * Parse out names and versions. Add to this as we learn more 
    * about browser strings.
    LOCAL lnAt1, lnAt2, lcStr, lcLower
    lcLower = LOWER(m.lcName)

    DO CASE
    CASE THIS.ParseAsMake( "Opera") 
      * must put Opera before MSIE, as it includes MSIE in UA string
      THIS.SetOperaValues()
      
    CASE THIS.ParseAsMake( "Netscape") 
      * Netscape 6 references Mozilla 5, so sort that out first
      THIS.SetNetscapeValues()
      
    CASE "MSIE" $ m.lcName
    	THIS.cMake = "Microsoft"
    	lnAt1 = AT( "MSIE", m.lcName)
    	lcStr = SUBSTR( m.lcName, m.lnAt1 + 5)
    	lnAt2 = AT( ";", m.lcStr)
    	THIS.cVersion = ALLTRIM( LEFT( m.lcStr, m.lnAt2 - 1))
    	THIS.nVersion = VAL( THIS.cVersion )
      THIS.SetMSIEValues()
      
    CASE "mozilla" $ LOWER(m.lcName)
    	THIS.cMake = "Mozilla"
    	lnAt1 = AT( "/", m.lcName)
    	lcStr = SUBSTR( m.lcName, m.lnAt1 + 1)
    	THIS.nVersion = VAL( m.lcStr )
    	THIS.cVersion = LTRIM( STR( THIS.nVersion, 10, 2))
      THIS.SetMozillaValues()
      
      
    OTHERWISE
    	* use defaults set in ResetProperties
    ENDCASE
    
    * Set flag for BOTs/crawlers:
    IF "crawler" $ m.lcLower ;
        OR "archive" $ m.lcLower ;
        OR "slurp" $ m.lcLower ;  && Yahoo! - added 12/3/2009
        OR "robot" $ m.lcLower ;
        OR "googlebot" $ m.lcLower ;
        OR "mediapartners-google" $ m.lcLower ; && added per SB post on WW Threads
        OR "discovery" $ m.lcLower ; && added 09/10/2012 (discoverybot/2.0)
        OR "msnbot" $ m.lcLower ;
        OR "exabot" $ m.lcLower ;
        OR "becomebot" $ m.lcLower ;
        OR "newt activex" $ m.lcLower ;
        OR "cherrypicker" $ m.lcLower ;
        OR "wget/" $ m.lcLower ; && added 4/15/2010 (Wget/1.11.4)
        OR "toolpak" $ m.lcLower ;
        OR "ocelli" $ m.lcLower ; && added 11/05/2010 
        OR "yandex" $ m.lcLower &&  added 11/05/2010 (YandexBot/3.0)

        * "search" $ m.lcLower ; removed 11/02/2011 conflicted with SearchToolbar in MSIE 8
        
      THIS.lCrawler = .T.
    ENDIF

#if .f.
* Chrome:
Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.2.149.27 Safari/525.13

* some example crawler strings
mozilla/5.0 (compatible; archive.org_bot/1.0.5-200410290941 +http://www.archives.gov/crawl.html
#endif
    RETURN 

  ENDFUNC  && SetBrowser
  * --------------------------------------------------------- *
  FUNCTION ParseAsMake( lcMake)
    IF NOT m.lcMake $ THIS.cBrowser
      RETURN .F.
    ENDIF
    THIS.cMake = m.lcMake
    LOCAL lcStr, lnAt1
    lnAt1 = AT( m.lcMake, THIS.cBrowser)
    * Following was a bug, evaluating version to 0, because of the / in UA strings.
    *!* lcStr = LTRIM( SUBSTR( THIS.cBrowser, m.lnAt1 + LEN( m.lcMake)))
    lcStr = LTRIM( SUBSTR( THIS.cBrowser, m.lnAt1 + LEN( m.lcMake) + 1))
    
    THIS.nVersion = VAL( m.lcStr )
    THIS.cVersion = ALLTRIM( STR( THIS.nVersion, 6, 2))
    RETURN .T.
  ENDFUNC  &&  ParseAsMake( lcMake)
  * --------------------------------------------------------- *
  FUNCTION SetMozillaValues
    THIS.nJavaScriptLevel = 1.5
    THIS.lW3CDom = .T.
    DO CASE
    CASE THIS.nVersion >= 6
      THIS.nCssLevel = 2.0  
    CASE THIS.nVersion >= 5
      THIS.nCssLevel = 1.0  
    CASE THIS.nVersion >= 4
      THIS.nCssLevel = 0.8  && not bad
      THIS.lIframes   = .F.
    CASE THIS.nVersion < 4
      THIS.nCssLevel = 0.5
      THIS.lIframes   = .F.
    ENDCASE
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION SetOperaValues
    THIS.nVBScriptLevel = 1.0  &&[[ is this right???
    THIS.nJavaScriptLevel = 1.5
    THIS.lW3CDom = .T.
    DO CASE
    CASE THIS.nVersion >= 6
      THIS.nCssLevel = 2.0  
    CASE THIS.nVersion >= 5
      THIS.nCssLevel = 1.0  
    CASE THIS.nVersion >= 4
      THIS.nCssLevel = 0.8  && not bad
      THIS.lIframes   = .F.
    CASE THIS.nVersion < 4
      THIS.nCssLevel = 0.5
      THIS.lIframes   = .F.
    ENDCASE
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION SetNetscapeValues
    THIS.nJavaScriptLevel = 1.5
    THIS.lW3CDom    = .T.
    THIS.lAllDom    = .F.
    THIS.lLayersDom = .F.

    DO CASE
    CASE THIS.nVersion >= 7
      THIS.nCssLevel = 2.0
    CASE THIS.nVersion >= 6
      THIS.nCssLevel = 1.5
    CASE THIS.nVersion >= 4
      THIS.lW3CDom    = .F.
      THIS.lLayersDom = .T.
      THIS.nCssLevel = 0.5  && poor but existent
      IF THIS.nVersion < 4.06
        THIS.nJavaScriptLevel = 1.2
      ELSE
        THIS.nJavaScriptLevel = 1.3
      ENDIF
      THIS.lIframes   = .F.
    CASE THIS.nVersion < 4
      THIS.lW3CDom    = .F.
      THIS.nCssLevel = 0
      IF THIS.nVersion < 3
        THIS.nJavaScriptLevel = 1.0
      ELSE
        THIS.nJavaScriptLevel = 1.1
      ENDIF
      THIS.lIframes   = .F.
    ENDCASE
  ENDFUNC  && SetNetscapeValues
  * --------------------------------------------------------- *
  FUNCTION SetMSIEValues
    THIS.nVBScriptLevel = 1.0
    THIS.nJavaScriptLevel = 1.5
    THIS.lW3CDom    = .T.
    THIS.lAllDom    = .T.
    DO CASE
    CASE THIS.nVersion >= 6
      THIS.nCssLevel = 2.0  
    CASE THIS.nVersion >= 5
      *[[ May need to differentiate 5.0 from 5.5.
      THIS.nCssLevel = 1.0  && close enough
    CASE THIS.nVersion >= 4
      THIS.lW3CDom    = .F.
      THIS.nCssLevel = 0.8  && not bad
      THIS.nJavaScriptLevel = 1.3
    CASE THIS.nVersion < 4
      THIS.lW3CDom    = .F.
      THIS.lAllDom    = .F.
      THIS.nCssLevel = 0.5
      THIS.nJavaScriptLevel = 1.1
    ENDCASE
  ENDFUNC  && SetMSIEValues

ENDDEFINE  && L7Browser

*** ========================================================= ***
#if .f.
05/14/2003 - adjusted JavaScript levels per O'Reilly Pocket Reference.
05/16/2003 - added 3 DOM flags
07/08/2003 - added lCrawler flag and (rough) determination
01/02/2004 - added IFRAME element support flag
02/23/2007 - added INIT method, and planned for persistance and setup from App object
03/12/2010 - removed resetProperties call from setBrowser
#endif

* End: L7Browser.PRG
