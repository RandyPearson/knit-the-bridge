* ktbmain.prg  && Kint-the-Bridge project

#INCLUDE WCONNECT.H 
* L7.H is "included" via WCONNECT_OVERRIDE.H

*** PUBLIC flag allows server to never quit 
*** - unless EXIT button code is executed

if Application.StartMode = 0
  ? datetime(), program(), "started" 
endif 
close databases all && avoid issue with wrong DBC open in development
release goWCServer
set talk off
set notify off

do WConnect  && Load Web Connection framework classes.
#IF L7_SHAREWARE
  do L7Classes.APP && Load L7 framework classes.
#ELSE
  do L7Classes.PRG && Load L7 framework classes.
#ENDIF

public goWcServer, glExitServer
goWcServer = CREATEOBJECT("KtbServer")  && << === NOTE: Name change in every server.
if vartype(goWCServer) # "O"
  messagebox("Unable to load Web Connection Server", 48, "Web Connection Error")
  return 
endif 
if !goWCServer.lDebugMode
  set debug off
  set status bar off
  set develop off
  set sysmenu off
endif 

*** Make the server live - Show puts the server online and in polling mode
read events

on shutdown
on error
release glExitCGIServer
release goWcServer

set sysmenu on
set debug on
set status bar on
set talk on

set development on
clear all
release all
clear program
set sysmenu to default
set procedure to
set classlib to
close database all
* CLEAR && leave up in case we wrote something
if Application.StartMode = 0
  ? datetime(), program(), "ended" 
  ?
  activate window command
endif 

return 


*** ========================================================= ***
define class KtbServer AS L7wwServer olepublic 
  lAutoSaveConfig  = .T.  && see SaveConfigurationOnExit
  * --------------------------------------------------------- *
  protected function BeforeProcess
    if Request.QueryString(1) == "lsevenmaint"
      if "," + Request.QueryString(2) + "," $ ",editconfig,wcdllerrorlog,"
        do wwMaint with this
        return .F.
      endif 
    endif 
    return .T.
  endfunc && BeforeProcess
    * --------------------------------------------------------- *
  protected function SetupVFPEnvironment()
    dodefault()
    *!*      LOCAL lnMem
    *!*      lnMem = INT( VAL( SYS(3050, 1)) / 3) 
    *!*      = SYS(3050, 1, m.lnMem) && Foreground memory limit.
    *!*      = SYS(3050, 2, m.lnMem) && Background memory limit.
    
    SYS(3050, 1, MIN(536870912, VAL(SYS(3050, 1, 0))))
    SYS(3050, 2, MIN(536870912, VAL(SYS(3050, 1, 0))))
    * See for why we changed this:
    * http://fox.wikis.com/wc.dll?Wiki~sys3050 
    
  endfunc && SetupVFPEnvironment
enddefine  && CLASS ktbServer


#if .f.
01/21/2012 - changed sys(3050) approach
#endif

* End: KtbMain.PRG

