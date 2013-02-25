* L7CacheManager.PRG

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

* ==================================================================== *
DEFINE CLASS L7CacheManager AS CUSTOM
  * Instantiate this at the server/top level and leave it running.
  * Pass SQL statements (without INTO clauses!).
  * Receive the name of the cursor in return.
  * If SQL matches previous SQL that has been run in less than the
  *   timeout interval, the cursor is reused.

  cCursorCacheAlias = "L7CacheManager_CursorCache"
  nDefaultTimeoutSeconds = 1800  && half hour
  cStringCacheAlias = "L7CacheManager_StringCache"
  * ------------------------------------------------------------------- *
  FUNCTION CacheCursor( lcSql, lnTimeoutSeconds, lcName, lcMode)
    LOCAL llRecreate, lcWholeSql, lcMessage
    lcMessage = ""
    llRecreate = .T.
    THIS.OpenCursorOfCursors()
    IF [ INTO ] $ UPPER( m.lcSql)
    	ERROR "L7CacheManager: INTO clause not allowed in SELECT statement."
    ENDIF
    IF EMPTY( m.lnTimeoutSeconds)
    	lnTimeoutSeconds = THIS.nDefaultTimeoutSeconds
    ENDIF
    IF EMPTY( m.lcName)
    	LOCATE FOR cSql == m.lcSql
    ELSE
    	LOCATE FOR cAlias = PADR( m.lcName, LEN( cAlias)) AND cSql == m.lcSql
    ENDIF
    IF FOUND()  && there's a matching record with same SQL
    	lcName = TRIM( cAlias)
    	IF EMPTY( tCreated) OR ;
    		DATETIME() - tCreated > m.lnTimeoutSeconds OR ;
    		lCleared OR ;
    		NOT USED( m.lcName)
    		* Timed out or else the cursor is gone.
    		#IF .F.
    		DO CASE
    		CASE EMPTY( tCreated) OR ;
    			DATETIME() - tCreated > m.lnTimeoutSeconds OR ;
    			lCleared
    			*
    			lcMessage = "Cursor was timed out."
    		CASE NOT USED( m.lcName)
    			lcMessage = "Cursor was not available."
    		OTHERWISE
    			lcMessage = "Unknown cursor problem."
    		ENDCASE
    		#ENDIF
    		llRecreate = .T.
    	ELSE
    		llRecreate = .F.
    	ENDIF
    ELSE
    	APPEND BLANK
    	lcName = IIF( EMPTY( m.lcName), ;
    		"L7CachedCursor_" + TRANS( RECNO()), m.lcName )
    	REPLACE cSql WITH m.lcSql ;
    		cAlias WITH m.lcName
    	llRecreate = .T.
    ENDIF
    IF m.llRecreate
    	USE IN SELECT( m.lcName)
    	lcWholeSql = m.lcSql + [ INTO CURSOR ] + m.lcName 
    	* Note: if you need NOFILTER, pass it in your SQL
    	&lcWholeSql
    	REPLACE tCreated WITH DATETIME() ;
    		lCleared WITH .F. ;
    		IN ( THIS.cCursorCacheAlias)
    ELSE
    	lcMessage = "Reused " + m.lcName + "..."
    ENDIF
    *!*	WAIT WINDOW NOWAIT "L7CacheManager: " + m.lcMessage
    SELECT ( m.lcName)
    RETURN m.lcName
  ENDFUNC  && CacheCursor
  * ------------------------------------------------------------------- *
  FUNCTION OpenCursorOfCursors
    IF NOT USED( THIS.cCursorCacheAlias)
    	SELECT 0
    	CREATE CURSOR ( THIS.cCursorCacheAlias) ;
    		(	cSql M, ;
    			tCreated T, ;
    			lCleared L, ;
    			cAlias C(40) )
    ENDIF
    SELECT ( THIS.cCursorCacheAlias)
  ENDFUNC  && OpenCursorOfCursors
  * ------------------------------------------------------------------- *
  FUNCTION GetCachedString(m.lcCacheID, m.lnCacheTime)
    LOCAL lcRet, lcKey, ltNow, lnSel, loExc
    lnSel = SELECT()
    ltNow = DATETIME()
    lcRet = ""
    lnCacheTime = EVL(m.lnCacheTime, THIS.nDefaultTimeoutSeconds)
    TRY
      THIS.OpenCursorOfStrings()
      lcKey = SYS(2007, m.lcCacheId, -1, 1)
      LOCATE FOR Key = m.lcKey
      IF FOUND()
        IF NOT Cleared AND Refreshed + m.lnCacheTime > m.ltNow
          * lcRet = Content
          lcRet = FILETOSTR(FORCEPATH(FORCEEXT(m.lcKey, "txt"), ;
            ADDBS(goL7App.cMessagingPath)))
        ENDIF
      ENDIF
    CATCH TO loExc
      lcRet = ""
    FINALLY
      SELECT (m.lnSel)
    ENDTRY
    RETURN m.lcRet
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION SetCachedString(m.lcContent, m.lcCacheID, m.lnCacheTime)
    LOCAL lcKey, ltNow, lnSel, loExc
    lnSel = SELECT()
    ltNow = DATETIME()
    lnCacheTime = EVL(m.lnCacheTime, THIS.nDefaultTimeoutSeconds)
    TRY
      THIS.OpenCursorOfStrings()
      lcKey = SYS(2007, m.lcCacheId, -1, 1)
      LOCATE FOR Key = m.lcKey
      IF NOT FOUND()
        APPEND BLANK
        REPLACE ;
          ID WITH m.lcCacheId ;
          Key WITH m.lcKey ;
          Created WITH m.ltNow
      ENDIF
      IF RLOCK()
        TRY
          STRTOFILE(m.lcContent, FORCEPATH(FORCEEXT(m.lcKey, "txt"), ;
            ADDBS(goL7App.cMessagingPath)), 0)
          REPLACE ;
            Refreshed WITH m.ltNow ;
            Cleared WITH .F. 
            * Content WITH m.lcContent
        CATCH TO loExc
          = .F.
        FINALLY
          UNLOCK
        ENDTRY
      ENDIF
    CATCH 
    FINALLY
      SELECT (m.lnSel)
    ENDTRY
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION OpenCursorOfStrings
    IF NOT USED( THIS.cStringCacheAlias)
      SELECT 0
      LOCAL lcFile
      lcFile = ADDBS(goL7App.cMessagingPath) + THIS.cStringCacheAlias 
      IF NOT FILE(FORCEEXT(m.lcFile, "DBF"))
        CREATE TABLE ( m.lcFile) FREE ;
          ( ID M, ;
            Key C(10), ;
            Created T, ;
            Refreshed T, ;
            Cleared L, ;
            Content M )
        USE
      ENDIF
      USE (m.lcFile) AGAIN IN 0 ALIAS (THIS.cStringCacheAlias)
    ENDIF
    SELECT (THIS.cStringCacheAlias)
  ENDFUNC  && OpenCursorOfStrings
  * ------------------------------------------------------------------- *
  * ------------------------------------------------------------------- *
ENDDEFINE  && CLASS L7CacheManager 
* ==================================================================== *

#if .f.
01/17/2005 - Added persistent cached strings.
01/30/2005 - Revised cached strings to use TXT files vs. memo fields.
#endif
