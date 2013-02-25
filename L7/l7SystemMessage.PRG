* L7SystemMessage.PRG
#include l7.h

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


*** --------------------------------------------------------- ***
DEFINE CLASS L7SystemMessage AS L7PageElement
  cTag = "div"
  cCssClass = "ErrorMsg"

  cMessageDetails = ""
  cMessageGotoUrl = ""
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcTxt)
    THIS.RenderTitle(@lcTxt)
    THIS.RenderDetails(@lcTxt)
    IF NOT EMPTY(THIS.cMessageGotoUrl)
      lcTxt = m.lcTxt + THIS.RenderURL(THIS.cMessageGotoUrl) 
    ENDIF
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION RenderTitle(lcTxt)
    lcTxt = m.lcTxt + HTWrap(m.Page.cSubTitle, 'h2')
  ENDFUNC    
  * --------------------------------------------------------- *
  FUNCTION RenderDetails(lcTxt)
    IF NOT EMPTY( THIS.cMessageDetails) 
      lcTxt = m.lcTxt + [<div class="] + THIS.cCssClass + [Details">] + CRLF
      * Thus CSS class name is something like "ErrorMsgDetails".
      * This allows different CSS attributes for different message types, app-wide.  
      lcTxt = m.lcTxt + L7ParseOnView(THIS.cMessageDetails) + [</div>] + CRLF
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderURL(m.lcUrl)
    RETURN [<div class="] + THIS.cCssClass+ [Link">] + ;
      [<a target="_top" href="] + m.lcUrl + [">] + ;
      [<img border=0 src="] + m.Page.cImagePath + [/ok.gif" alt="OK Button">] + ;
      [</a></div>] + CRLF
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE  && L7SystemMessage

#if .f.
#endif
