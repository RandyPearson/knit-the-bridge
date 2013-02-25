#INCLUDE L7.H

*** ===================================================== ***
DEFINE CLASS L7ColorScheme AS RELATION
*** ===================================================== ***
cSchemeName = "American"

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

* --------------------------------------------------------- *
FUNCTION INIT
LPARAMETERS lcSchemeName
IF NOT EMPTY( m.lcSchemeName)
	THIS.SetSchemeName( m.lcSchemeName )
ELSE
	THIS.LoadScheme()
ENDIF
ENDFUNC  && INIT
* --------------------------------------------------------- *
FUNCTION SetSchemeName
LPARAMETERS lcSchemeName
THIS.cSchemeName = m.lcSchemeName
THIS.LoadScheme()
ENDFUNC  && SetSchemeName
* --------------------------------------------------------- *
FUNCTION LoadScheme
lcScheme = LOWER( ALLTRIM( THIS.cSchemeName))
DO CASE
CASE m.lcScheme == "beach1"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#FFFFFF"  && 
	THIS.cHeaderFontColor    = "#008000"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#99FF88"  

	* Menu Area:
	THIS.cMenuBgColor        = "#99CCFF"  && 
	THIS.cMenuLinkColor      = "#006699"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#008800"  && 
	THIS.cMenuTitleFontColor = "#DDFFDD"  && 

CASE m.lcScheme == "beach2"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#88BBEE"  && 
	THIS.cHeaderFontColor    = "#000000"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#99FF88"  

	* Menu Area:
	THIS.cMenuBgColor        = "#88BBEE"  && 
	THIS.cMenuLinkColor      = "#FFFFFF"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   =  "#6699CC"  
	THIS.cMenuTitleFontColor = "#000000"  && "#CC6600"

CASE m.lcScheme == "mount"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#996600"  && 
	THIS.cHeaderFontColor    = "#FFCC66"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#BBFF99"  && 

	* Menu Area:
	THIS.cMenuBgColor        = "#FFCC66"  && 
	THIS.cMenuLinkColor      = "#996600"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#996600"  && 
	THIS.cMenuTitleFontColor = "#FFFFFF"  && 

CASE m.lcScheme == "mount1"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#348017"  && 
	THIS.cHeaderFontColor    = "#FFFEDC"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#C8B189"  && SAME AS MENU TITLES

	* Menu Area:
	THIS.cMenuBgColor        = "#348017"  && 
	THIS.cMenuLinkColor      = "#FFFEDC"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#C8B189"  && 
	THIS.cMenuTitleFontColor = "#655507"  && 

CASE m.lcScheme == "mount2"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#617C17"  && 
	THIS.cHeaderFontColor    = "#FFFEDC"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#348017"  && 

	* Menu Area:
	THIS.cMenuBgColor        = "#E78E17"  && 
	THIS.cMenuLinkColor      = "#FFF7D7"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#D9A51C"  && 
	THIS.cMenuTitleFontColor = "#7F5217"  && 

CASE m.lcScheme == "desert2"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#DCCAAC"  && 
	THIS.cHeaderFontColor    = "#806752"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#FFFF88"  && 

	* Menu Area:
	THIS.cMenuBgColor        = "#FDF178"  && 
	THIS.cMenuLinkColor      = "#AD7007"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#E78E35"  && 
	THIS.cMenuTitleFontColor = "#980517"  && 

CASE m.lcScheme == "desert3"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#B04807"  && 
	THIS.cHeaderFontColor    = "#FCF3E2"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#FCF3E2"  && 

	* Menu Area:
	THIS.cMenuBgColor        = "#C45817"  && 
	THIS.cMenuLinkColor      = "#DECCAE"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#DCCAAC"  && 
	THIS.cMenuTitleFontColor = "#980517"  && 

CASE m.lcScheme == "tiffany"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#53CFD7"  && 
	THIS.cHeaderFontColor    = "#00484E"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#EEEEEE"  && 

	* Menu Area:
	THIS.cMenuBgColor        = "#43BFC7"  && 
	THIS.cMenuLinkColor      = "#EFF7FF"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#30787E"  && 
	THIS.cMenuTitleFontColor = "#EFF7FF"  && 

CASE m.lcScheme == "royal"  && purple 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#990099"  && 
	THIS.cHeaderFontColor    = "#FFCC66"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#DDBBDD"  && 

	* Menu Area:
	THIS.cMenuBgColor        = "#990099"  && 
	THIS.cMenuLinkColor      = "#FFCC66"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#FFCC66"  && 
	THIS.cMenuTitleFontColor = "#000000"  && 

CASE m.lcScheme == "rusty"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#000000"  && 
	THIS.cHeaderFontColor    = "#CC6600"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#EEBB77"  && 

	* Menu Area:
	THIS.cMenuBgColor        = "#CC6600"  && 
	THIS.cMenuLinkColor      = "#FFFFFF"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#000000"  && 
	THIS.cMenuTitleFontColor = "#FFFFFF"  && 

CASE m.lcScheme == "khaki"  && 

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#336699"  && 
	THIS.cHeaderFontColor    = "#CCCC99"  && 
	
	* Content Area:
	THIS.cMainBgColor        = "#FFFFFF"  && 

	* Menu Area:
	THIS.cMenuBgColor        = "#CCCC99"  && 
	THIS.cMenuLinkColor      = "#000000"  &&

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#336699"  && 
	THIS.cMenuTitleFontColor = "#CCCC99"  && 

CASE m.lcScheme == "desert"  && burnt orange and blue

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#0000CC"  && blue
	THIS.cHeaderFontColor    = "#FFFFFF"  && white
	
	* Content Area:
	THIS.cMainBgColor        = "#FFFF99"  && very light yellow

	* Menu Area:
	THIS.cMenuBgColor        = "#FFCC33"  && burnt orange
	THIS.cMenuLinkColor      = ""

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#0000CC"  && blue
	THIS.cMenuTitleFontColor = "#FFFFFF"  && white

CASE m.lcScheme == "tropics"  && blue and green

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#009966"  && dark green
	THIS.cHeaderFontColor    = "#FFFFFF"  && white
	
	* Content Area:
	THIS.cMainBgColor        = "#BBDDEE"  && light blue

	* Menu Area:
	THIS.cMenuBgColor        = "#009966"  && dark green
	THIS.cMenuLinkColor      = "#FFFFFF"  && white

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#99FFCC"  && light green
	THIS.cMenuTitleFontColor = "#008811"  && dark green

CASE m.lcScheme == "raiders"  && black and silver

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#000000"  && black
	THIS.cHeaderFontColor    = "#FFFFFF"  && white
	
	* Content Area:
	THIS.cMainBgColor        = "#C0C0C0"  && silver

	* Menu Area:
	THIS.cMenuBgColor        = "#000000"  && black
	THIS.cMenuLinkColor      = "#FFFFFF"  && white

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#C0C0C0"  && silver
	*THIS.cMenuTitleBgColor   = "#B0C4DE"  && lightsteelblue
	THIS.cMenuTitleFontColor = "#000000"  && black

CASE m.lcScheme == "barbie"  && pinks and purples

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#FF0099"
	THIS.cHeaderFontColor    = "#CCCCCC"

	* Content Area:
	THIS.cMainBgColor        = "#CC99FF"  && very light purple
	
	* Menu Area:
	THIS.cMenuBgColor        = "#9900FF"  && 
	THIS.cMenuLinkColor      = "#FFFFFF"  && white

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#CC99FF"  && very light purple
	THIS.cMenuTitleFontColor = "#9900FF"  && dark purple

CASE m.lcScheme == "christmas"  && green and red

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#CC0000"  && red
	THIS.cHeaderFontColor    = "#FFFFFF"  && white
	
	* Content Area:
	THIS.cMainBgColor        = "#FFDDDD"  && very light red

	* Menu Area:
	THIS.cMenuBgColor        = "#009966"  && dark green
	THIS.cMenuLinkColor      = "#FFFFFF"  && white

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#99FFCC"  && light green
	THIS.cMenuTitleFontColor = "#CC0000"  && dark red

CASE m.lcScheme == "plain"  && no color

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#FFFFFF"  && white
	THIS.cHeaderFontColor    = "#000000"  && black
	
	* Content Area:
	THIS.cMainBgColor        = "#FFFFFF"  

	* Menu Area:
	THIS.cMenuBgColor        = "#FFFFFF"  
	THIS.cMenuLinkColor      = ""

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#FFFFFF"  && white
	THIS.cMenuTitleFontColor = "#000000"  && black

OTHERWISE && m.lcScheme == "american"  && red, white and blue

	* Header Line (above content):
	THIS.cHeaderBgColor      = "#990033"  && red
	THIS.cHeaderFontColor    = "#FFFFFF"  && white
	
	* Content Area:
	THIS.cMainBgColor        = "#99BBDD"  && light gray-blue

	* Menu Area:
	THIS.cMenuBgColor        = "#990033"  && blue
	THIS.cMenuLinkColor      = "#FFFFFF"  && white

	* Menu Section Titles:
	THIS.cMenuTitleBgColor   = "#000066"  && red
	THIS.cMenuTitleFontColor = "#FFFFFF"  && white
	
ENDCASE
ENDFUNC  && LoadScheme
* --------------------------------------------------------- *
ENDDEFINE   && CLASS L7ColorScheme 
*** ===================================================== ***
