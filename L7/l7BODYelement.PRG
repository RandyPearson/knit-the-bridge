* L7BodyElement.PRG
*
* Various examples of <body> layouts. Or, you can create your own...

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


* !! Very basic, one-element body:
*** ========================================================= ***
DEFINE CLASS L7BodyElement AS L7PageElement
  * --------------------------------------------------------- *
  FUNCTION CurrentOutputObject_ACCESS
    RETURN THIS  && where Response should Write()
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    lcText = lcText + [<div class="PageTitle">] + CR + ;
      Page.cTitle + ;
      [</div>] + CR 
    lcText = lcText + [<div class="MainContent">] + CR + ;
      THIS.cText + ;
      [</div>] + CR 
  ENDFUNC  && RenderImplementation
ENDDEFINE


* !! Representative example: 4-part body with menu that can be turned off and/or switch sides.
* !!    Title and Footer can also be switched off, say for a "printable" version of content.
*** ========================================================= ***
DEFINE CLASS L7FourPartBody AS L7BodyElement
  ADD OBJECT oTitleBar AS L7PageElement
  ADD OBJECT oMenu     AS L7MainTextMenu
  ADD OBJECT oContent  AS L7PageElement
  ADD OBJECT oFooter   AS L7PageElement
  lShowMenu     = .T.     && switch to turn menu off (e.g, on forms)
  cMenuLocation = "left"  && position of menu {left, right}
  lShowTitle    = .T.     && flag to disable title bar
  lShowFooter   = .T.     && flag to disable footer
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    LOCAL lnCols, lcMenu
    IF NOT THIS.lShowMenu
      lnCols = 1
    ELSE
      lnCols = 2
      lcMenu = [<td class="MainMenu">] + CR + THIS.oMenu.Render() + [</td>] + CR
    ENDIF
    * Open an outer table to wrap the whole page:
    lcText = m.lcText + [<table summary="layout" class="PageWrapper">] + CR
    * Add the title bar:
    IF THIS.lShowTitle
      lcText = m.lcText + [<tr><td class="TitleBar" colspan="] + TRANSFORM(m.lnCols) + [">] + CR + ;
        THIS.oTitleBar.Render() + [</td></tr>] + CR
    ENDIF
    * Add the content and "optional" menu:
    lcText = m.lcText + [<tr>] + CR + ;
      IIF(THIS.lShowMenu AND THIS.cMenuLocation == "left", m.lcMenu, "") + ;
      [<td class="MainContent">] + THIS.oContent.Render() + [</td>] + CR + ;
      IIF(THIS.lShowMenu AND THIS.cMenuLocation == "right", m.lcMenu, "") + ;
      [</tr>] + CR
    * Now the footer element:
    IF THIS.lShowFooter
      lcText = m.lcText + [<tr><td class="Footer" colspan="] + TRANSFORM(m.lnCols) + [">] + CR + ;
        THIS.oFooter.Render() + [</td></tr>] + CR
    ENDIF
    * And close the outer table:
    lcText = m.lcText + [</table><!-- End: "PageWrapper"-->] + CR
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION CurrentOutputObject_ACCESS
    RETURN THIS.oContent  && point Response private variable to content section
  ENDFUNC  
ENDDEFINE  && L7FourPartBody



* !! The next example is somewhat dated -- not using CSS as completely as possible:
* !!
*** ========================================================= ***
DEFINE CLASS L7TwoPartBody AS L7PageElement
  * Example application sub-class to achieve a standard style
  * on all pages. This creates a left-hand menu and a right-hand
  * main (content) area (with the title at the top). Each is an object
  * that can be written to separately, and the output is not 
  * reassembled until the end of the process. Thus, you can change
  * the menu items very late in the page processing code/script.
  *
  * Layout:
  *!*	____________________________
  *!*	|   |     (Title Here)      |
  *!*	| M |                       |
  *!*	| e |                       |
  *!*	| n |         Main          |
  *!*	| u |       (Content)       |
  *!*	|   |                       |
  *!*	|   |                       |
  *!*	-----------------------------

  *!*	HTML Implementation:
  *!*	 1-row 2-cell table. 
  ADD OBJECT oMenu AS L7MainTextMenu  
  ADD OBJECT oMain AS L7PageElement
   
  lMenuOnRight = .F.  && switch menu to right of content

  *!*	oHeader = NULL
  *!*	oFooter = NULL

  cMainBackground     = ""
  cMainBgColor        = "#FFFFFF"

  cMenuImage          = ""
  cMenuBackground     = ""
  cMenuBgColor        = "#9999FF"
  cMenuLinkColor      = ""
  cMenuTitleBgColor   = "#0000CC"
  cMenuTitleFontColor = "#FFFFFF"

  cHeaderBgColor      = "#0000CC"
  cHeaderFontColor    = "#FFFFFF"

  lNoBackground    = .F. && switch to turn off background for page
  nMainCellPadding = 6   && can lower for special purposes (like further nesting of tables)
  * --------------------------------------------------------- *
  FUNCTION CurrentOutputObject_ACCESS
    RETURN THIS.oMain  && where Response should Write()
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION GetMenu()
    LOCAL lcText
    lcText = [<!-- Menu Cell -->] + CR + ;
      [<td class="MainMenu">] + CR 
    THIS.BeforeRenderMenu(@lcText)
    lcText = m.lcText + THIS.oMenu.Render()
    THIS.AfterRenderMenu(@lcText)
    lcText = m.lcText + [</td>] + CR + ;
   		[<!-- End: Menu Cell -->] + CR + CR
    RETURN m.lcText
  ENDFUNC  && GetMenu
  * --------------------------------------------------------- *
  FUNCTION BeforeRenderMenu(lcText)
  * --------------------------------------------------------- *
  FUNCTION AfterRenderMenu(lcText)
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    LOCAL lcTitleText
    lcText = m.lcText + CR + CR + ;
    	[<!-- BEGIN: Outer Table -->] + CR + ;
      [<table summary="layout" style="height: 100%; width: 100%; margin: 0;" border=1>] + CR + CR

    lcText = m.lcText + [<tr valign="top">] + CR

    * Attach Menu, if indicated for left-hand side:
    IF NOT Page.lPrint AND NOT THIS.oMenu.lCancelled AND NOT THIS.lMenuOnRight 
    	* Include Menu only when not in "printable mode" and menu not cancelled elsewhere in Page.
    	lcText = m.lcText + THIS.GetMenu()
    ENDIF

    *[[ 03/01/2001: Removed WIDTH="99%" from following TD to avoid NS 6 issue.
    lcText = m.lcText + ;
    	[<!-- Main "Content" Cell -->] + CR + ;
      [<td class="MainContent" align="left">] + CR

    IF NOT EMPTY( Page.cTitle )
    	lcTitleText = Page.cTitle
    	IF NOT "<" $ m.lcTitleText
  			lcTitleText = HTWrap( m.lcTitleText, 'SPAN', 'CLASS="MainTitle"')
    	ENDIF
    	lcText = m.lcText + ;
    		[<!-- Begin: Header Table -->] + CR + ;
    		[<table summary="layout" width="100%" cellpadding=2 cellspacing=0>] + CR + ;
    		[  <tr><td align="center">] + ;
    		m.lcTitleText + ;
    		[</td></tr></table>] + CR + ;
    		[<!-- End: Header Table -->] + CR
    ENDIF
    	
    IF THIS.nMainCellPadding > 0
    	lcText = m.lcText + ;
    		[<!-- Content-wrapper table for padding only. -->] + CR + ;
    		[<table summary="layout" class="MainContentPadding" width="100%" cellpadding="] + TRANSFORM( THIS.nMainCellPadding ) + [">] + ;
        [<tr valign="top"><td>] + CR
    ENDIF

    lcText = m.lcText + THIS.oMain.Render() + CR

    IF THIS.nMainCellPadding > 0
    	lcText = m.lcText + ;
    		[</td></tr></table>] + CR + ;
    		[<!-- End: Content-wrapper table. -->] + CR
    ENDIF

    lcText = m.lcText + ;
    	[</td>] + CR + ;
    	[<!-- End: Content Cell -->] + CR + CR 

    * Attach Menu, if indicated for right-hand side:
    IF NOT Page.lPrint AND NOT THIS.oMenu.lCancelled AND THIS.lMenuOnRight 
    	* Include Menu only when not in "printable mode" and menu not cancelled elsewhere in Page.
    	lcText = m.lcText + THIS.GetMenu( m.loScheme)
    ENDIF

    lcText = m.lcText + ;
    	[</tr></table>] + CR + ;
    	[<!-- END: Outer Table -->] + CR + CR

    ***  Request.GetDebugInfo()
    	
  ENDFUNC  && RenderImplementation
  * --------------------------------------------------------- *
ENDDEFINE  && L7TwoPartBody


* !!! REMAINING SUBCLASSES ARE DEPRECATED BUT RETAINED FOR BACKWARD COMPATIBILITY!
* !!! DO NOT USE FOR NEW APPLICATIONS! THESE CLASSES DO NOT USE CSS APPROACH!
*** ========================================================= ***
DEFINE CLASS L7ThreePartBody AS L7PageElement

  * Example application sub-class to achieve a standard style
  * on all pages. This creates a left-hand menu and a right-hand
  * main area, with a header band. Each is an object
  * that can be written to separately, and the output is not 
  * reassembled until the end of the process. Thus, you can change
  * the header or menu very late in the page processing code/Page.
  *
  * Layout:
  *!*	____________________________
  *!*	|   |       Header          |
  *!*	| M |-----------------------|
  *!*	| e |                       |
  *!*	| n |         Main          |
  *!*	| u |       (Content)       |
  *!*	|   |                       |
  *!*	|   |                       |
  *!*	-----------------------------

  *!*	HTML Implementation:
  *!*	 2-row table. First cell with ROWSPAN of 2.
   
  ADD OBJECT oMenu AS L7TextMenu  && (defined in this PRG for now)
  ADD OBJECT oMain AS L7PageElement
  ADD OBJECT oHeader AS L7PageElement

  cMainBackground     = ""
  cMainBgColor        = "#FFFFFF"

  cMenuImage          = ""
  cMenuBackground     = ""
  cMenuBgColor        = "#9999FF"
  cMenuLinkColor      = ""
  cMenuTitleBgColor   = "#0000CC"
  cMenuTitleFontColor = "#FFFFFF"

  cHeaderBgColor      = "#0000CC"
  cHeaderFontColor    = "#FFFFFF"

  lNoBackground    = .F. && switch to turn off background for page
  nMainCellPadding = 6   && can lower for special purposes (like further nesting of tables)
  * --------------------------------------------------------- *
  FUNCTION CurrentOutputObject_ACCESS
    RETURN THIS.oMain  && where Response should Write()
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    LOCAL loScheme, llCss
    llCss = Page.oBrowser.nCssLevel >= 0.5
    loScheme = Page.oColorScheme
    lcText = m.lcText + CR + CR + ;
    	[<!-- BEGIN: Outer Table -->] + CR + ;
    	[<table summary="layout" height="100%" width="100%" cellspacing="0" cellpadding="0" border="1">] + CR + CR

    IF NOT Page.lPrint
    	* Include Menu and Header only when not "printable mode".
    	lcText = m.lcText + [<tr valign="top">] + CR

    	lcText = m.lcText + ;
    		[<!-- Begin: Menu Cell -->] + CR + ;
    			[<td rowspan=3 height="100%" width=160 align="left"] + ;
    			IIF( EMPTY( m.loScheme.cMenuBgColor), [], [ bgcolor="] + m.loScheme.cMenuBgColor + ["]) + ;
    			IIF( EMPTY( m.loScheme.cMenuBackground), [], [ background="] + m.loScheme.cMenuBackground + ["]) + ;
    			[>] + CR + ;
    		[<!-- Inner Table for Menu -->] + CR + ;
        [<table summary="layout" height="99%" border=0 cellspacing=0 width=160>] + ;
    		[<font face="Arial" size=2>] + CR + ;
    		THIS.oMenu.Render() + ;
        [</table>] + CR + ;
    		[</td>] + CR + ;
    		[<!-- End: Menu Cell -->] + CR + CR

    	lcText = m.lcText + ;
    		[<!-- Begin: Header Cell -->] + CR + ;
    		[<td align="center" width="99%" bgcolor="] + ;
    		m.loScheme.cHeaderBgColor + [">] + CR + ;
    		[  <table summary="layout" width="100%" cellpadding=1 cellspacing=1>] + CR + ;
    		[    <tr><td align=center bgcolor="] + ;
    		m.loScheme.cHeaderBgColor + [">] + ;
    		[<font] + ;
    			IIF( m.llCss, [ class="SiteTitle"], [ face="Arial" size="2"] ) + ;
    			[color="] + m.loScheme.cHeaderFontColor + [">] + CR + ;
    		[    ] + THIS.oHeader.Render() + CR + ;
    		[</td></tr></table>] + CR + ;
    		[</td></tr>] + CR + ;
    		[<!-- End: Header Cell -->] + CR + CR
    ENDIF
    	
    lcText = m.lcText + ;
    	[<!-- Main "Content" Cell -->] + CR + ;
    	[<tr height="100%" valign="top"><td height="100%" width="99%" align="left" bgcolor="] + ;
    	m.loScheme.cMainBgColor + ["] + ;
    	IIF( THIS.lNoBackground OR Page.lPrint OR EMPTY( m.loScheme.cMainBackground), ;
    		[], [ background="] + m.loScheme.cMainBackground + ["]) + ;
    	[>] + CR + ;
    	[<!-- Content-wrapper table for padding only. -->] + CR + ;
    	[<table summary="layout" width="100%" cellpadding=] + TRANSFORM( THIS.nMainCellPadding ) + [><tr valign=top><td>] + ;
    	[<font face="Arial"><small>] + CR + ;
    	THIS.oMain.Render() + CR + ;
      [</font></td></tr></table>] + CR + ;
    	[<!-- End: Content-wrapper table. -->] + CR + CR + ;
      [</td></tr>] + CR + ;
    	[<!-- End: Content Cell -->] + CR + CR

    lcText = m.lcText + ;
    	[<!-- Footer Cell -->] + CR + ;
    	[<tr valign="bottom"><td align="center" bgcolor="] + ;
    	m.loScheme.cMainBgColor + ["] + ;
    	[><font size=1 face="Arial">] + CR + ;
    	[&copy;&nbsp;] + TRANSFORM( YEAR( DATE())) + [ by Cycla Corporation] + ;
    	[</td></tr>] + CR + ;
    	[<!-- End: Footer Cell -->] + CR + CR

    lcText = m.lcText + ;
    	[</table>] + CR + ;
    	[<!-- END: Outer Table -->] + CR + CR
    	
  ENDFUNC  && RenderImplementation
* --------------------------------------------------------- *
ENDDEFINE  && L7ThreePartBody

* !!! REMAINING SUBCLASSES ARE DEPRECATED BUT RETAINED FOR BACKWARD COMPATIBILITY!
* !!! DO NOT USE FOR NEW APPLICATIONS! THESE CLASSES DO NOT USE CSS APPROACH!
*** ========================================================= ***
DEFINE CLASS L7OldFourPartBody AS L7PageElement
  * Example application sub-class to achieve a standard style
  * on all pages. This creates a left-hand menu and a right-hand
  * main area, with header and footer bands. Each is an object
  * that can be written to separately, and the output is not 
  * reassembled until the end of the process. Thus, you can change
  * the header or menu very late in the page processing code/Page.

  ADD OBJECT oMenu AS L7TextMenu  && (defined in this PRG for now)
  ADD OBJECT oMain AS L7PageElement
  ADD OBJECT oHeader AS L7PageElement
  ADD OBJECT oFooter AS L7PageElement
  cMenuBgColor     = "#9999FF"
  cMainBgColor     = "#FFFFFF"
  cMainBackground  = ""
  cHeaderBgColor   = "orange"
  cHeaderFontColor = "purple"
  *cFooterBgColor   = "orange"
  *cFooterFontColor = "purple"
  * --------------------------------------------------------- *
  FUNCTION CurrentOutputObject_ACCESS
    RETURN THIS.oMain  && where Response should Write()
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)

    LOCAL loScheme, llCss
    llCss = Page.oBrowser.nCssLevel >= 0.5
    loScheme = Page.oColorScheme
    lcText = ""
    lcText = m.lcText + CR + CR + ;
    	[<!-- BEGIN: Outer Table -->] + CR + ;
      [<table summary="layout" height="100%" width="100%" cellspacing="0" cellpadding="0" border="] + ;
    	IIF( Page.oBrowser.cMake = "Microsoft", "0", "1") + [">] + CR + CR

    lcText = m.lcText + ;
    	[<!-- Begin: Header Cell -->] + CR + ;
    	[<tr><td colspan=2 style="border:] + m.loScheme.cHeaderBgColor + [ outset 2" align="center" bgcolor="] + ;
    	m.loScheme.cHeaderBgColor + [">] + ;
      [<font face="arial" size=2 color="] + m.loScheme.cHeaderFontColor + [">] + CR + ;
    	THIS.oHeader.Render() + CR + ;
      [</td></tr>] + CR + ;
    	[<!-- End: Header Cell -->] + CR + CR
    	
    lcText = m.lcText + ;
    	[<!-- Menu Cell -->] + CR + ;
      [<tr valign="top">] + ;
        [<td height="100%" style="border:] + m.loScheme.cMenuBgColor + [ inset 2" width=160 align="left" bgcolor="] + ;
    		m.loScheme.cMenuBgColor + [">] + CR + ;
    	[<!-- Inner Table for Menu -->] + CR + ;
      [<table summary="layout" height="99%" border="0" cellspacing="0" width="160">] + ;
    	[<font face="Arial" size="2">] + CR + ;
    	THIS.oMenu.Render() + ;
    	[</table>] + CR + ;
    	[</td>] + CR + ;
    	[<!-- End: Menu Cell -->] + CR + CR

    lcText = m.lcText + ;
    	[<!-- Main "Content" Cell -->] + CR + ;
    	[<td height="100%" style="border:] + m.loScheme.cMainBgColor + [ inset 2" width="99%" align="left" bgcolor="] + ;
    	m.loScheme.cMainBgColor + ["] + ;
    	IIF( EMPTY( m.loScheme.cMainBackground), [], [ background="] + m.loScheme.cMainBackground + ["]) + ;
    	[>] + CR + ;
    	[<!-- Content-wrapper table for padding only. -->] + CR + ;
      [<table summary="layout" width="100%" cellpadding="6"><tr valign="top"><td>] + ;
    	[<font face="Arial" size="2">] + CR + ;
    	THIS.oMain.Render() + CR + ;
    	[</td></tr></table>] + CR + ;
    	[</td></tr>] + CR + ;
    	[<!-- End: Content Cell -->] + CR + CR

    *!*	lcText = m.lcText + ;
    *!*		[<!-- Footer Cell -->] + CR + ;
    *!*		[<TR><TD COLSPAN=2 STYLE="border:] + THIS.cFooterBgColor + ;
    *!*		[ outset 2" ALIGN="CENTER" BGCOLOR="] + THIS.cFooterBgColor + [">] + ;
    *!*		[<FONT FACE="Arial" SIZE=2 COLOR="] + THIS.cFooterFontColor + [">] + CR + ;
    *!*		THIS.oFooter.Render() + CR + ;
    *!*		[</TD></TR>] + CR + ;
    *!*		[<-- End: Footer Cell -->] + CR + CR

    lcText = m.lcText + ;
    	[</table>] + CR + CR + ;
    	[<!-- END: Outer Table -->] + CR + CR
    	
  ENDFUNC  && RenderImplementation
  * --------------------------------------------------------- *
ENDDEFINE  && L7OLDFourPartBody


* !!! REMAINING SUBCLASSES ARE DEPRECATED BUT RETAINED FOR BACKWARD COMPATIBILITY!
* !!! DO NOT USE FOR NEW APPLICATIONS! THESE CLASSES DO NOT USE CSS APPROACH!
*** Here is an (OLD) example of subclassing one layout from another.
*** The "pieces" stay the same--they are just arranged differently.
*** ========================================================= ***
DEFINE CLASS L7InvertedElBody AS L7OldFourPartBody
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    LOCAL loScheme, llCss
    llCss = Page.oBrowser.nCssLevel >= 0.5
    loScheme = Page.oColorScheme
    lcText = m.lcText + CR + CR + ;
    	[<!-- BEGIN: Outer Table -->] + CR + ;
    	[<table summary="layout" height="100%" width="100%" cellspacing="0" cellpadding="0" border="1">] + CR + CR

    lcText = m.lcText + [<tr valign="top">] + CR
    lcText = m.lcText + [<td height="100%" width="160">] + CR

    lcText = m.lcText + [<table summary="layout" height="100%" width="160" cellspacing="0" cellpadding="0" border="1">] + CR
    lcText = m.lcText + [<tr valign="center">] + CR

    lcText = m.lcText + ;
    	[<!-- Begin: Logo Cell -->] + CR + ;
      [<td height="160" width="160" align="center" bgcolor="] + ;
    	m.loScheme.cHeaderBgColor + [">] + ;
      [<font face="Arial" size=2 color="] + m.loScheme.cHeaderFontColor + [">] + CR + ;
    	"Logo Goes Here!" + CR + ;
    	[</td>] + CR + ;
    	[<!-- End: Logo Cell -->] + CR + CR

    lcText = m.lcText + [</tr><tr valign="top">] + CR

    lcText = m.lcText + ;
    	[<!-- Menu Cell -->] + CR + ;
      [<td height="100%" width="160" align="left" bgcolor="] + ;
    		m.loScheme.cMenuBgColor + [">] + CR + ;
    	[<!-- Inner Table for Menu -->] + CR + ;
      [<table summary="layout" height="100%" border="0" cellspacing="0" width="160">] + ;
    	[<font face="Arial" size="2">] + CR + ;
    	THIS.oMenu.Render() + ;
    	[</table>] + CR + ;
    	[</td>] + CR + ;
    	[<!-- End: Menu Cell -->] + CR + CR

    lcText = m.lcText + [</tr></table>] + CR
    lcText = m.lcText + [</td><td height="100% width="100%">] + CR
    lcText = m.lcText + [<table summary="layout" width="100%" height="100%" cellspacing="0" cellpadding="0" border="1">] + CR
    lcText = m.lcText + [<tr valign="top">] + CR

    lcText = m.lcText + ;
    	[<!-- Begin: Header Cell -->] + CR + ;
      [<td width="100%" align="center" bgcolor="] + ;
    	m.loScheme.cHeaderBgColor + [">] + ;
    	[<font face="Arial" size="2" color="] + m.loScheme.cHeaderFontColor + [">] + CR + ;
    	THIS.oHeader.Render() + CR + ;
    	[</td>] + CR + ;
    	[<!-- End: Header Cell -->] + CR + CR

    lcText = m.lcText + [</tr><tr valign="top">] + CR

    lcText = m.lcText + ;
    	[<!-- Main "Content" Cell -->] + CR + ;
      [<td height="100%" width="100%" align="left" bgcolor="] + ;
    	m.loScheme.cMainBgColor + ["] + ;
    	IIF( EMPTY( m.loScheme.cMainBackground), [], [ background="] + m.loScheme.cMainBackground + ["]) + ;
    	[>] + CR + ;
    	[<!-- Content-wrapper table for padding only. -->] + CR + ;
      [<table summary="layout" width="100%" cellpadding="6"><tr valign="top"><td>] + ;
    	[<font face="Verdana,Sans-Serif" size=2>] + CR + ;
    	THIS.oMain.Render() + CR + ;
    	[</td></tr></table>] + CR + ;
    	[</td>] + CR + ;
    	[<!-- End: Content Cell -->] + CR + CR

    lcText = m.lcText + [</tr></table>] + CR
    lcText = m.lcText + [</td></tr>] + CR

    lcText = m.lcText + ;
    	[</table>] + CR + CR + ;
    	[<!-- END: Outer Table -->] + CR + CR
    	
  ENDFUNC  && RenderImplementation
  * --------------------------------------------------------- *
ENDDEFINE  && L7InvertedElBody


**************************************************************************
** CHANGE LOG
**************************************************************************
#IF .f.

12/19/2002:  
- Rewrote built-in concrete classes to use containership (ADD OBJECT vs. CREATEOBJECT). 
- Rewrote all for compliance with Render template design. Changed render() in 
  all cases to use RenderImplementation(lcText) with lcText passed by reference.
12/31/2002 - renamed various "layer" classes to use term "element" instead
01/04/2003 - moved L7TextMenu to L7PageElements.PRG.
05/26/2003 - changed all tags to lower case, adjusted some older subclass code.
           - added DEPRECATION note to old classes
           - renamed some old classes 
           - added a modern L7FourPartBody
09/16/2003 - standards upgrade
#ENDIF

* End: L7BodyElement.PRG
