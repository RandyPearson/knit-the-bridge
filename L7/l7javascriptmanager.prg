* L7JavaScriptManager.PRG
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


*** ===================================================== ***
DEFINE CLASS L7JavaScriptManager AS LINE
  * Array for JavaScript:
  DIMENSION aJavaScript[ 1, 3]
  * Columns are code, source (URL), and language version.
  nJavaScript = 0
  * --------------------------------------------------------- *
  FUNCTION Merge(loObj)
    * Merge this array with the array of another like object.
    LOCAL ii
    FOR ii = 1 TO ALEN( loObj.aJavaScript, 1)
      THIS.AddJavaScript( ;
        loObj.aJavaScript[ m.ii, 1], ;
        loObj.aJavaScript[ m.ii, 2], ;
        loObj.aJavaScript[ m.ii, 3] ;
        )
    ENDFOR
  ENDFUNC  && Merge
  * --------------------------------------------------------- *
  FUNCTION AddJavaScript(lcCode, lcUrl, lcVersion)
    LOCAL ii, llFound, llCode
    lcCode = IIF( EMPTY( m.lcCode), "", m.lcCode )
    lcUrl = IIF( EMPTY( m.lcUrl), "", m.lcUrl )
    lcVersion = IIF( EMPTY( m.lcVersion), L7_DEFAULT_JAVASCRIPT_VERSION, m.lcVersion )
    llCode = NOT EMPTY( m.lcCode)

    FOR ii = 1 TO THIS.nJavaScript
      IF ( m.llCode AND THIS.aJavaScript[ m.ii, 1] == m.lcCode OR ;
          NOT m.llCode AND THIS.aJavaScript[ m.ii, 2] == m.lcUrl ) AND ;
        THIS.aJavaScript[ m.ii, 3] == m.lcVersion
        * Already exists!
        llFound = .T.
        EXIT
      ENDIF
    ENDFOR
    IF NOT m.llFound
      THIS.nJavaScript = THIS.nJavaScript + 1
      DIMENSION THIS.aJavaScript[ THIS.nJavaScript, 3]
      THIS.aJavaScript[ THIS.nJavaScript, 1] = m.lcCode
      THIS.aJavaScript[ THIS.nJavaScript, 2] = m.lcUrl
      THIS.aJavaScript[ THIS.nJavaScript, 3] = m.lcVersion
    ENDIF
  ENDFUNC  && AddJavaScript
  * --------------------------------------------------------- *
  FUNCTION GetJavaScript
    LOCAL lcStr, ii, llCode
    lcStr = []
    FOR ii = 1 TO THIS.nJavaScript
      llCode = NOT EMPTY(THIS.aJavaScript[m.ii, 1]) && code-versus-external flag
      lcStr = m.lcStr + [<script type="text/javascript" language="javascript] + ;
        THIS.aJavaScript[ m.ii, 3] + ["]
      IF m.llCode
        lcStr = m.lcStr + [>] + CR + THIS.aJavaScript[ m.ii, 1] + CR
      ELSE
        lcStr = m.lcStr + [ src="] + THIS.aJavaScript[ m.ii, 2] + [">]
      ENDIF
      lcStr = m.lcStr + [</script>] + CR
    ENDFOR
    RETURN m.lcStr
  ENDFUNC  && GetJavaScript
  * --------------------------------------------------------- *
ENDDEFINE  && L7JavaScriptManager

*** ===================================================== ***
#if .f.
01/06/2003 - added [ type="text/javascript"] to GetJavaScript().
12/01/2003 - revised GetJavaScript to remove unnecessary CRs.
09/06/2004 - revised to use L7_DEFAULT_JAVASCRIPT_VERSION
#endif

* L7JavaScriptManager.PRG
