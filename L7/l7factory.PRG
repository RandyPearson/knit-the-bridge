* L7Factory.PRG
*
* Class factory classes.
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
DEFINE CLASS L7PageFactory AS RELATION
  cAlias = ""
  * --------------------------------------------------------- *
  FUNCTION SetAlias(lcAlias)
    THIS.cAlias = m.lcAlias
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION LOAD
    IF NOT FILE( THIS.cAlias + ".DBF")
      * This allows you to run the app once and have
      * the table created for you.
      THIS.CreateTable()
    ENDIF
    USE (THIS.cAlias) AGAIN IN SELECT(THIS.cAlias)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SelectAlias
    IF NOT USED(THIS.cAlias)
      USE (THIS.cAlias) AGAIN IN 0
    ENDIF
    SELECT (THIS.cAlias)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION CreateTable
    SELECT 0
    CREATE TABLE (THIS.cAlias) FREE ;
      ( Page C(24), ;
        Extension C(6), ;
        Class C(30), ;
        Module C(30), ;
        Inactive L, ;
        Default L, ;
        Properties M, ;
        Notes M )
    INDEX ON UPPER(Page) TAG U_Page
    USE
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION FindHandler(loApp)
    LOCAL llFound
    LOCATE FOR Inactive = .F. AND ;
      LIKE( ;
        TRIM(UPPER(Page)) + [.] + ;
        IIF(EMPTY(Extension), [*], TRIM(UPPER(Extension))), ;
        UPPER(m.loApp.cActivePage) + [.] + UPPER(m.loApp.cActivePageExtension))
    llFound = FOUND()
    IF NOT m.llFound
      LOCATE FOR Default = .T. AND Inactive = .F.
      llFound = FOUND()
    ENDIF
    RETURN m.llFound
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetObject(loApp)
    * If you make decisions based on file extensions or virtual
    * folders, you need a custom factory method!
    LOCAL lnSelect, lcPattern, loObj, lcPage
    lnSelect = SELECT()
    THIS.SelectAlias()
    IF NOT THIS.FindHandler(m.loApp)
      RETURN .F.
    ENDIF
    LOCAL loObj
    IF EMPTY(Module)
      loObj = CREATEOBJECT(TRIM(Class), loApp)
    ELSE
      loObj = NEWOBJECT(TRIM(Class), TRIM(Module), '', m.loApp)
    ENDIF
    IF VARTYPE(m.loObj) <> "O"
      RETURN .F.
    ENDIF
    IF NOT EMPTY(Properties)
      * Parse each line in Properties memo field and
      * execute it as though it were in the class constructor.
      * Include quotes as appropriate. Example:
      *   lAdding = .F.
      *   cMyProp = "My Value"
      LOCAL laLines[1], lcLine, lcCmd
      ALINES(laLines, Properties, .T.)
      FOR EACH lcLine IN laLines
        IF EMPTY(m.lcLine)
          LOOP
        ENDIF
        lcCmd = "loObj." + TRIM(m.lcLine)
        &lcCmd
      ENDFOR
    ENDIF
    SELECT (m.lnSelect)
    RETURN loObj
  ENDFUNC  && GetObject

  *!*    * --------------------------------------------------------- *
  *!*    FUNCTION GetObject(loApp)
  *!*      * If you make decisions based on file extensions or virtual
  *!*      * folders, you need a custom factory method!
  *!*      LOCAL lnSelect, lcPage
  *!*      lnSelect = SELECT()
  *!*      THIS.SelectAlias()
  *!*      lcPage = PADR(UPPER(m.loApp.cActivePage),LEN(Page))
  *!*      IF NOT SEEK(m.lcPage, ALIAS(), "U_Page")
  *!*        RETURN .F.
  *!*      ENDIF
  *!*      LOCAL loObj
  *!*      *[[ TRY
  *!*        IF EMPTY(Module)
  *!*          loObj = CREATEOBJECT(TRIM(Class), loApp)
  *!*        ELSE
  *!*          loObj = NEWOBJECT(TRIM(Class), TRIM(Module), loApp)
  *!*        ENDIF
  *!*      *[[ CATCH
  *!*      *[[  = .F.
  *!*      *[[ ENDTRY
  *!*      IF VARTYPE(m.loObj) <> "O"
  *!*        RETURN .F.
  *!*      ENDIF
  *!*      IF NOT EMPTY(Properties)
  *!*        * Parse each line in Properties memo field and
  *!*        * execute it as though it were in the class constructor.
  *!*        * Include quotes as appropriate. Example:
  *!*        *   lAdding = .F.
  *!*        *   cMyProp = "My Value"
  *!*        LOCAL laLines[1], lcLine, lcCmd
  *!*        ALINES(laLines, Properties, .T.)
  *!*        FOR EACH lcLine IN laLines
  *!*          IF EMPTY(m.lcLine)
  *!*            LOOP
  *!*          ENDIF
  *!*          lcCmd = "loObj." + TRIM(m.lcLine)
  *!*          &lcCmd
  *!*        ENDFOR
  *!*      ENDIF
  *!*      SELECT (m.lnSelect)
  *!*      RETURN loObj
  *!*    ENDFUNC  && GetObject
  * --------------------------------------------------------- *
ENDDEFINE  && L7PageFactory

#if .f.
12/19/2002 - Added oApp parameter to INIT() sequence for creating pages.
06/01/2003 - Modified GetObject to receive App object as sole parameter.
           - Removed TRY/CATCH.
06/28/2003 - Corrected cActiveExtension to cActivePageExtension, and xDefault to Default.           
#endif
* End: L7Factory
