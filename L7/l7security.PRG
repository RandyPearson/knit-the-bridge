* L7Security.PRG
*
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
DEFINE CLASS L7Security AS Custom
  * Abstract interface for plugging security managers into L7 apps.
  cTokenGeneratorAlias = NULL
  cStructure = [Post L, Read L, Edit L, Manage L, Admin L, UserKey I]
  cStructureAugment = NULL  && allow specifying extras without mucking with L7 defaults
  * ----------------------------------------------------- *
  FUNCTION DESTROY
    IF NOT ISNULL(THIS.cTokenGeneratorAlias)
      USE IN SELECT(THIS.cTokenGeneratorAlias)
    ENDIF
  ENDFUNC
  * ----------------------------------------------------- *
  FUNCTION GetPermissionsToken(loUser, lcResource)
    LOCAL loToken
    loToken = THIS.CreatePermissionsToken()
    THIS.FillPermissionsToken(m.loUser, m.lcResource, m.loToken)
    RETURN m.loToken
  ENDFUNC
  * ----------------------------------------------------- *
  FUNCTION FillPermissionsToken(loUser, loResource, loToken)
    * You override this.
  ENDFUNC
  * ----------------------------------------------------- *
  FUNCTION CreatePermissionsToken
    * Note: building from a cursor is faster than
    * creating an Empty object and using ADDPROPERTY().
    LOCAL loObj, lnSelect
    lnSelect = SELECT()
    THIS.OpenCursor()
    SCATTER MEMO NAME loObj
    SELECT (m.lnSelect)
    RETURN m.loObj
  ENDFUNC
  * ----------------------------------------------------- *
  FUNCTION OpenCursor
    IF ISNULL(THIS.cTokenGeneratorAlias) OR NOT USED(THIS.cTokenGeneratorAlias)
      THIS.cTokenGeneratorAlias = "__L7Security__" + SYS(3)
      LOCAL lcStructure
      lcStructure = THIS.cStructure
      IF NOT ISNULL(THIS.cStructureAugment)
        lcStructure = m.lcStructure + [, ] + THIS.cStructureAugment
      ENDIF
      SELECT 0
      CREATE CURSOR (THIS.cTokenGeneratorAlias) ( &lcStructure )
    ENDIF
    SELECT (THIS.cTokenGeneratorAlias)
  ENDFUNC
ENDDEFINE  && L7Security

* Example, very simple concrete classes:
*** ===================================================== ***
DEFINE CLASS L7NoSecurity AS L7Security 
  * Concrete class for wide-open apps. Hint: Just an example <s>.
  * ----------------------------------------------------- *
  FUNCTION FillPermissionsToken(loUser, lcResource, loToken)
    WITH loToken
      .Post = .T.
      .Read = .T.
      .Edit = .T.
      .Manage = .T.
      .Admin = .T.
      .UserKey = loUser.GetUserKey()
    ENDWITH
  ENDFUNC
ENDDEFINE  && L7NoSecurity

*** ===================================================== ***
DEFINE CLASS L7ReadOnlySecurity AS L7Security 
  * Concrete class for open reading apps plus administrator.
  * ----------------------------------------------------- *
  FUNCTION FillPermissionsToken(loUser, lcResource, loToken)
    WITH loToken
      IF loUser.IsAdministrator() && assume derived from L7User class
        .Post = .T.
        .Read = .T.
        .Edit = .T.
        .Manage = .T.
        .Admin = .T.
      ELSE  && just read
        .Post = .F.
        .Read = .T.
        .Edit = .F.
        .Manage = .F.
        .Admin = .F.
      ENDIF
      .UserKey = loUser.GetUserKey()
    ENDWITH
  ENDFUNC
ENDDEFINE  && L7ReadOnlySecurity


#if .f.
01/13/2003 - created.
#endif
