* L7LogHack.PRG

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


*** =================================================== ***
DEFINE CLASS L7LogHack AS Relation
  DataSourceType = "Native"
  DataSource     = ""
  cPath          = NULL
  cTableName     = "L7Hack"
  * --------------------------------------------------- *
  FUNCTION cPath_ACCESS
    IF ISNULL(THIS.cPath)
      RETURN ADDBS(CURDIR()) + "Logs\"
    ELSE
      RETURN ADDBS(THIS.cPath)
    ENDIF
  ENDFUNC
  * --------------------------------------------------- *
  FUNCTION Log(loApp)
    LOCAL lnSelect, llRet
    llRet = .T.
    lnSelect = SELECT()
    SELECT 0
    IF NOT THIS.OpenTable()
      llRet = .F.
    ELSE
      APPEND BLANK
      REPLACE ;
        AppName WITH loApp.cApplication ;
        HitTime WITH DATETIME() ;
        HackInfo WITH loApp.cHackInfo
      IF NOT VARTYPE( Request) = "O"
        IF TYPE( "m.Server.oRequest") = "O"
          PRIVATE Request
          Request = m.Server.oRequest
        ENDIF
      ENDIF
      * [[ Needs abstraction work:
      IF VARTYPE( Request) = "O"
        REPLACE Server WITH Request.ServerVariables( "SERVER_NAME" ) ;
          IpAddress WITH Request.ServerVariables( "REMOTE_ADDR" ) ;
          UserId WITH Request.ServerVariables( "REMOTE_USER" ) ;
          URL WITH Request.GetCurrentURL() ;
          PriorURL WITH Request.ServerVariables( "HTTP_REFERER") ;
          FormVars WITH Request.cFormVars ;
          ServerVars WITH Request.cServerVars
      ENDIF
      USE
    ENDIF
    SELECT (m.lnSelect)
    RETURN m.llRet
  ENDFUNC  && Log
  * --------------------------------------------------- *
  FUNCTION OpenTable
    TRY
      IF NOT FILE(THIS.cPath + THIS.cTableName + ".DBF")
        CREATE TABLE (THIS.cPath + THIS.cTableName) FREE ( ;
          AppName C(8), ;
          Notified L, ;
          NotifyTime T, ;
          HitTime T, ;
          Server C(32), ;
          IpAddress C(15),;
          UserId C(20), ;
          URL M, ;
          PriorURL M, ;
          HackInfo M, ;
          FormVars M, ;
          ServerVars M ;
          )
        USE
      ENDIF
      USE (THIS.cPath + THIS.cTableName) AGAIN SHARED
    CATCH TO loExc 
      ERROR [Error opening hack log: ] + loExc.Message
    ENDTRY
  ENDFUNC  && OpenTable
ENDDEFINE  && L7LogHack
*** =================================================== ***

#IF .F.
RECORD OF REVISIONS
12/14/2002 - Class created. (Refactored from L7App.LogHackAttempt.)
#ENDIF
