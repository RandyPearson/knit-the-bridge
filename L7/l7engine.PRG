* L7Engine.PRG

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
DEFINE CLASS L7Engine AS CUSTOM  && had been SESSION
  cDataPath                 = ""
  cDatabase                 = ""
  tTimestamp                = NULL
  lError                    = .F.
  cErrorMessage             = ""
  cSuccessMessage           = ""  && optional feedback in subclass
  * --------------------------------------------------------- *
  FUNCTION INIT
    ** not needed in same datasession: DO StandardVfpSettings  && SET EXACT, DELETED, etc.

    IF ISNULL( THIS.tTimestamp)
    	THIS.tTimestamp = DATETIME()
    ENDIF

    IF EMPTY(THIS.cDataPath) AND VARTYPE(m.goL7App) = "O"
    	THIS.cDataPath = goL7App.cDataPath
    	THIS.cDataBase = goL7App.cDataBase
    ENDIF

    IF NOT DBUSED(THIS.cDatabase)
    	OPEN DATABASE (THIS.cDataPath + THIS.cDatabase)
    ENDIF
    SET DATABASE TO (THIS.cDatabase)
    RETURN 
  ENDFUNC  
  * --------------------------------------------------------- *
#IF L7_ENGINE_ERROR_HANDLING
  FUNCTION ERROR( lnError, lcMethod, lnLine )
    THIS.lError = .T.
    THIS.cErrorMessage = THIS.cErrorMessage + ;
    	[Error ] + TRANSFORM( m.lnError) + ;
    	[ in ] + m.lcMethod + [, Line ] + ;
    	TRANSFORM( m.lnLine) + [: ] + MESSAGE() + ;
    	L7BR + CHR(13) + CHR(10)

    = RevertTables()  && in L7Utils.PRG
    IF LOWER( m.lcMethod ) = "execute" AND ;
    	NOT LOWER( m.lcMethod ) == "execute"
    	* Abort engine implementation.
    	RETURN TO Execute
    ENDIF
  ENDFUNC  
#ENDIF
  * --------------------------------------------------------- *
  FUNCTION SetError
    LPARAMETERS lcMessage
    THIS.lError = .T.
    THIS.cErrorMessage = THIS.cErrorMessage + ;
    	m.lcMessage + L7BR + CHR(13) + CHR(10)
    #IF NOT L7_ENGINE_ERROR_HANDLING
      ERROR THIS.cErrorMessage
    #ENDIF
    RETURN 
  ENDFUNC  && SetError
  * --------------------------------------------------------- *
  FUNCTION Execute
    LOCAL llSuccess
    llSuccess = THIS.ExecuteImplementation() 
    RETURN m.llSuccess AND NOT THIS.lError
  ENDFUNC  && Execute
  * --------------------------------------------------------- *
  PROTECTED FUNCTION ExecuteImplementation
    * This is where your code goes.
    ERROR PROGRAM() + " must be implemented in a subclass!"
  ENDFUNC  && ExecuteImplementation
  * --------------------------------------------------------- *
ENDDEFINE  && L7Engine
*** ===================================================== ***

* 5/17/2006: changed from SESSION to CUSTOM, to avoid isolating transactions from engines 