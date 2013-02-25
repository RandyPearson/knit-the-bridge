* L7ProcessMonitor.PRG
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


*** ================================================== ***
DEFINE CLASS L7AbstractProcessMonitor AS Container
  nItems = 0
  DIMENSION aItems[1]
  * -------------------------------------------------- *
  FUNCTION DESTROY
  * -------------------------------------------------- *
  FUNCTION Shutdown(loMgr)
    LOCAL loItem
    FOR EACH loItem IN THIS.Controls
      loItem.Shutdown(m.loMgr)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION BeforeAppManagerLoadApplications(loMgr)
    * Runs once before loading new apps from the appManager.
    * Any member can block entire L7 creation process.
    LOCAL llOK, loItem
    llOK = .T.
    FOR EACH loItem IN THIS.Controls
      llOK = loItem.BeforeAppManagerLoadApplications(m.loMgr)
      IF NOT m.llOK
        EXIT  && bail out if any member says "no"
      ENDIF
    ENDFOR
    RETURN m.llOK
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterAppManagerLoadApplications(loMgr)
    * Runs once after feeding new apps to Server.oAppManager.
    LOCAL loItem
    FOR EACH loItem IN THIS.Controls
      loItem.AfterAppManagerLoadApplications(m.loMgr)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION BeforeServerProcessHit(loServer, lcRequestBuffer)
    * Runs on each hit before feeding hit to appManager.
    * Blocking role still TBD. (For now, does not block.)
    LOCAL llOK, loItem
    llOK = .T.
    FOR EACH loItem IN THIS.Controls
      llOK = loItem.BeforeServerProcessHit(m.loServer, @lcRequestBuffer)
      IF NOT m.llOK
        EXIT  && bail out if any member says "no"
      ENDIF
    ENDFOR
    RETURN m.llOK
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterServerProcessHit(loServer)
    * Runs on each hit after processing is complete.
    LOCAL loItem
    FOR EACH loItem IN THIS.Controls
      loItem.AfterServerProcessHit(m.loServer)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION BeforeAppProcessPage(loApp)
    * Runs once before creating page object.
    * Any member can block page creation process.
    LOCAL llOK, loItem
    llOK = .T.
    FOR EACH loItem IN THIS.Controls
      llOK = loItem.BeforeAppProcessPage(m.loApp)
      IF NOT m.llOK
        EXIT  && bail out if any member says "no"
      ENDIF
    ENDFOR
    RETURN m.llOK
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterAppProcessPage(loApp)
    * Runs once after app has processed page.
    LOCAL loItem
    FOR EACH loItem IN THIS.Controls
      loItem.AfterAppProcessPage(m.loApp)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION BeforePageProcessRequest(loPage)
    * Runs once before page object calls ProcessRequest.
    * Any member can block page creation process.
    LOCAL llOK, loItem
    llOK = .T.
    FOR EACH loItem IN THIS.Controls
      llOK = loItem.BeforePageProcessRequest(m.loPage)
      IF NOT m.llOK
        EXIT  && bail out if any member says "no"
      ENDIF
    ENDFOR
    RETURN m.llOK
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterPageProcessRequest(loPage)
    * Runs once after app has processed page.
    LOCAL loItem
    FOR EACH loItem IN THIS.Controls
      loItem.AfterPageProcessRequest(m.loPage)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION DoMethod(lcMethod, loObjRef, loMemento)
    IF PEMSTATUS(THIS, m.lcMethod, 5) && If we have this method, run it.
      LOCAL lcCmd
      lcCmd = [THIS.] + m.lcMethod + [(m.loObjRef, m.loMemento)]
      EVALUATE(m.lcCmd)
    ENDIF
    * Give our members a shot at it too:
    LOCAL loItem
    FOR EACH loItem IN THIS.Controls
      loItem.DoMethod(m.lcMethod, m.loObjRef, m.loMemento)
    ENDFOR
  ENDFUNC
  * -------------------------------------------------- *
ENDDEFINE  && L7ProcessMonitor 

*** ================================================== ***
DEFINE CLASS L7AnchorProcessMonitor AS L7AbstractProcessMonitor 
  * DON'T SUBCLASS FROM THIS OR RECURSION WILL RESULT IN INIT()!!
  * SUBCLASS FROM ABSTRACT CLASS!
  * -------------------------------------------------- *
  FUNCTION INIT
    #IF L7_MONITOR_PROCESS
      * Check for monitors to load.
      LOCAL lcList
      lcList = ""
      #IF L7_SHAREWARE  
        * In SHAREWARE mode, force usage of slow-down monitor,
        * and don't allow others to be used.
        lcList = "L7SharewareProcessMonitor"
      #ELSE
        ** IF TYPE("THIS.Parent.oConfig.cProcessMonitors") = "C"
        **   lcList = THIS.Parent.oConfig.cProcessMonitors
        ** ENDIF
        lcList = THIS.Parent.oConnector.GetProcessMonitors()
      #ENDIF
      IF NOT EMPTY(m.lcList)
        LOCAL aa[1], lcClass
        ALINES(aa, m.lcList, .T., ",")
        FOR EACH lcClass IN aa
          IF NOT EMPTY(m.lcClass)
            THIS.nItems = THIS.nItems + 1 
            TRY
              THIS.AddObject('aItems[' + TRANSFORM(THIS.nItems) + ']', lcClass)
            CATCH TO loExc
              WAIT WINDOW TIMEOUT 2 loExc.Message
            ENDTRY
          ENDIF
        ENDFOR
      ENDIF
    #ENDIF && L7_MONITOR_PROCESS
  ENDFUNC  && INIT
ENDDEFINE

*** ================================================== ***
DEFINE CLASS L7SharewareProcessMonitor AS L7AbstractProcessMonitor 
  * Add painful delays to processing time.
  * -------------------------------------------------- *
  FUNCTION Shutdown(loMgr)
    LOCAL loItem
    FOR EACH loItem IN loMgr.Applications
      IF VARTYPE(loItem) = "O"
        WAIT WINDOW TIMEOUT 1 ;
          loItem.cApplication + " shutting down after processing " + ;
          TRANSFORM(loItem.nHits) + " hits."
      ENDIF
    ENDFOR
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION BeforeAppManagerLoadApplications(loMgr)
    WAIT WINDOW TIMEOUT 0.5 "Hello from " + ;
      GETWORDNUM(PROGRAM(),GETWORDCOUNT(PROGRAM(),"."),".")
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterAppManagerLoadApplications(loMgr)
    WAIT WINDOW TIMEOUT 0.5 "Hello from " + ;
      GETWORDNUM(PROGRAM(),GETWORDCOUNT(PROGRAM(),"."),".")
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION BeforeServerProcessHit(loServer, lcRequestBuffer)
    WAIT WINDOW TIMEOUT 0.25 "Hello from " + ;
      GETWORDNUM(PROGRAM(),GETWORDCOUNT(PROGRAM(),"."),".") + ;
      " (passed server: " + m.loServer.cServerID + ")"
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterServerProcessHit(loServer)
    WAIT WINDOW TIMEOUT 0.25 "Hello from " + ;
      GETWORDNUM(PROGRAM(),GETWORDCOUNT(PROGRAM(),"."),".") + ;
      " (passed server: " + m.loServer.cServerID + ")"
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION BeforeAppProcessPage(loApp)
    WAIT WINDOW TIMEOUT 0.25 "Hello from " + ;
      GETWORDNUM(PROGRAM(),GETWORDCOUNT(PROGRAM(),"."),".") + ;
      " (passed application: " + m.loApp.Name + ")"
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterAppProcessPage(loApp)
    WAIT WINDOW TIMEOUT 0.25 "Hello from " + ;
      GETWORDNUM(PROGRAM(),GETWORDCOUNT(PROGRAM(),"."),".") + ;
      " (passed application: " + m.loApp.Name + ")"
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION BeforePageProcessRequest(loPage)
    WAIT WINDOW NOWAIT ;
      "Processing page class " + loPage.Class + "..."
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterPageProcessRequest(loPage)
    WAIT CLEAR
  ENDFUNC
ENDDEFINE  && L7SharewareProcessMonitor

#if .f.
01/08/2003 - created
#endif
* end
