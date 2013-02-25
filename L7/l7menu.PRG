* L7Menu.PRG
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


*** =========================================================== ***
DEFINE CLASS L7Menu AS L7CollectionHierarchy 
  * NOTES: 
  *  - The role of "prompt" is played by hierarchy's "cDisplayName" property.
  *  - Submenus are serviced by the "folder" PEM in the hierarchy class.

  lImputeFolders = .T.

  * Bridge overrides:
  cItemClass    = "L7Menu"
  cFolderClass  = "L7Menu"
  
  * Menu-specific item properties:
  cUrl     = ""
  cTooltip = ""
  cLinkAtt = ""
  cFullNodePath = ""
  * ----------------------------------------------------------- *
  FUNCTION AddMenuItem(lcSubmenu, lcName, lcPrompt, lcUrl, lcTooltip, lcAttrib)
    LOCAL loSub, loItem
    IF EMPTY(m.lcSubmenu)
      loSub = THIS
    ELSE
      loSub = THIS.GetItem(m.lcSubmenu)
      IF VARTYPE(loSub) <> 'O'
        loSub = THIS.AddFolder(m.lcSubmenu)
      ENDIF
    ENDIF
    lcName = EVL(m.lcName, "Item" + TRANSFORM(loSub.Count + 1))
    loItem = loSub.AddItem(m.lcName, m.lcPrompt, m.lcUrl, m.lcTooltip, m.lcAttrib)
    RETURN loItem
  ENDFUNC  && AddMenuItem
  * ----------------------------------------------------------- *
  FUNCTION AddNamedMenuItem(lcPath, lcPrompt, lcUrl, lcTooltip, lcAttrib)
    * Derivative of AddMenuItem when you want to pre-name individual
    * leaf nodes. 
    LOCAL lcName, loItem
    lcName = JUSTSTEM(m.lcPath)
    lcPath = JUSTPATH(m.lcPath)
    loItem = THIS.AddMenuItem(m.lcPath, m.lcName, m.lcPrompt, m.lcUrl, m.lcTooltip, m.lcAttrib)
    RETURN m.loItem
  ENDFUNC  && AddNamedMenuItem
  * ----------------------------------------------------------- *
  FUNCTION AddMenuItemMultiple(lcMenuList, lcPrompt, lcUrl, lcTooltip, lcAttrib)
    * Add many of the same link at once to separate menus. 
    * Unlike other Add..() methods, does NOT return any object reference.
    LOCAL laPaths[1]
    ALINES(laPaths, m.lcMenuList, .T., [,])
    FOR EACH lcPath IN laPaths
      THIS.AddMenuItem(m.lcPath, , m.lcPrompt, m.lcUrl, m.lcTooltip, m.lcAttrib)
    ENDFOR
  ENDFUNC  && AddMenuItemMultiple
  * ----------------------------------------------------------- *
  FUNCTION AddItem(lcName, lcPrompt, lcUrl, lcTooltip, lcAttrib)
    LOCAL loObj
    loObj = DODEFAULT(m.lcName, m.lcPrompt)  && this does the Add()
    * Assign further menu-specific properties:
    loObj.cUrl = m.lcUrl
    loObj.cTooltip = m.lcTooltip
    loObj.cLinkAtt = m.lcAttrib
    RETURN loObj
  ENDFUNC  && AddItem
  * ----------------------------------------------------------- *
  FUNCTION AddFolder(lcPath, lcDisplayName, lcUrl, lcTooltip, lcAttrib)
    LOCAL loObj
    loObj = DODEFAULT(m.lcPath, m.lcDisplayName)
    * Assign further menu-specific properties:
    loObj.cUrl = m.lcUrl
    loObj.cTooltip = m.lcTooltip
    loObj.cLinkAtt = m.lcAttrib
    RETURN m.loObj
  ENDFUNC
  * ----------------------------------------------------------- *
  FUNCTION AddSubmenu(lcPath, lcPrompt)  && (somewhat) Deprecated
    RETURN THIS.AddFolder(m.lcPath, m.lcPrompt)
  ENDFUNC
  * ----------------------------------------------------------- *
  FUNCTION IsSubmenu()
    RETURN THIS.IsFolder()
  ENDFUNC
  * ----------------------------------------------------------- *
ENDDEFINE  && L7NewMenu

*** =========================================================== ***
DEFINE CLASS L7CollectionHierarchy AS Collection
  lImputeFolders = .T.

  * Bridges:
  cItemClass    = "L7CollectionHierarchy"
  cFolderClass  = "L7CollectionHierarchy"
  
  * Item properties:
  cDisplayName  = ""
  * ----------------------------------------------------------- *
  FUNCTION AddFolder(lcPath, lcDisplayName)
    THIS.CleanPath(@lcPath)
    LOCAL lnCount, lnKey, lcWord, loObj, loRet
    lcWord = GETWORDNUM(m.lcPath, 1, [\])
    IF EMPTY(m.lcWord)
      ERROR "Invalid path sent to AddFolder method."
    ENDIF
    lnCount = GETWORDCOUNT(m.lcPath, [\])
    lnKey = THIS.GetKey(m.lcWord)
    IF m.lnKey = 0  && top-level item in path does not exist
      loObj = CREATEOBJECT(THIS.cFolderClass)
      loObj.cDisplayName = m.lcWord  
      IF NOT EMPTY(THIS.cFullNodePath)
        loObj.cFullNodePath = ADDBS(THIS.cFullNodePath) + m.lcWord
      ELSE
        loObj.cFullNodePath = m.lcWord
      ENDIF
      THIS.Add(m.loObj, m.lcWord)
    ELSE
      loObj = THIS.Item(m.lnKey)
    ENDIF
    IF m.lnCount = 1  && no further path -- return this object
      IF NOT EMPTY(m.lcDisplayName)
        loObj.cDisplayName = m.lcDisplayName
      ENDIF
      loRet = m.loObj
    ELSE  && traverse further
      LOCAL lcChildPath
      lcChildPath = SUBSTR(m.lcPath, LEN(m.lcWord) + 2)
      loRet = m.loObj.AddFolder(m.lcChildPath, m.lcDisplayName)
    ENDIF
    RETURN m.loRet
  ENDFUNC  && AddFolder
  * ----------------------------------------------------------- *
  FUNCTION AddItem(lcName, lcDisplayName)
    * Low-level method. Generally not to be called from client code.
    * Call from higher-level methods once paths have been dealt with.
    LOCAL loObj, lnKey
    * See if key already exists:
    lnKey = THIS.GetKey(m.lcName)
    IF EMPTY(m.lnKey)  && No, so create new object.
      loObj = CREATEOBJECT(THIS.cItemClass)
      loObj.Name = m.lcName
      loObj.cFullNodePath = ADDBS(THIS.cFullNodePath) + m.lcName
      * Add to collection
      THIS.Add(loObj, m.lcName)
    ELSE  && node exists -- just replace properties
      loObj = THIS.Item(m.lnKey)
    ENDIF
    * Set passed properties:
    loObj.cDisplayName = m.lcDisplayName
    RETURN loObj
  ENDFUNC  && AddItem
  * ----------------------------------------------------------- *
  FUNCTION GetItem(lcPath)
    THIS.CleanPath(@lcPath)
    LOCAL lnKey, lcWord
    lcWord = GETWORDNUM(m.lcPath, 1, [\])
    IF EMPTY(m.lcWord)
      RETURN NULL
    ENDIF
    lnKey = THIS.GetKey(m.lcWord)
    IF m.lnKey = 0  && unknown
      RETURN NULL
    ELSE
      IF GETWORDCOUNT(m.lcPath, [\]) = 1  && immediate node
        RETURN THIS.Item(m.lnKey)
      ELSE  && traverse further down path hierarchy
        LOCAL lcChildPath
        lcChildPath = SUBSTR(m.lcPath, LEN(m.lcWord) + 2)
        RETURN THIS.Item(m.lnKey).GetItem(m.lcChildPath)
      ENDIF
    ENDIF
  ENDFUNC  && GetItem
  * ----------------------------------------------------------- *
  FUNCTION IsFolder()
    RETURN THIS.Count > 0  && subclass if this doesn't work for you
  ENDFUNC
  * ----------------------------------------------------------- *
  FUNCTION CleanPath(lcPath)
    * - removes any leading or trailing "\" chars 
    * - supports pass by reference 
    IF RIGHT(m.lcPath, 1) = [\]
      lcPath = LEFT(m.lcPath, LEN(m.lcPath) - 1)
    ENDIF
    IF LEFT(m.lcPath, 1) = [\]
      lcPath = SUBSTR(m.lcPath, 2)
    ENDIF
    RETURN m.lcPath
  ENDFUNC  && CleanPath
  * ----------------------------------------------------------- *
  FUNCTION Ravel(llNoRecurse)
    * support debugging by ravelling to array (viewable in watch window)
    IF THIS.Count > 0
      IF VARTYPE(THIS.aRaveledNodes[1]) = "U"
        THIS.AddProperty('aRaveledNodes[1]', .F.)
      ENDIF
      DIMENSION THIS.aRaveledNodes[THIS.Count, 2]
      LOCAL ii, loObj
      FOR ii = 1 TO THIS.Count
        loObj = THIS.Item[m.ii]
        THIS.aRaveledNodes[m.ii, 1] = m.loObj
        THIS.aRaveledNodes[m.ii, 2] = THIS.GetKey(m.ii)
        IF NOT m.llNoRecurse AND PEMSTATUS(loObj, 'ravel', 5)
          loObj.Ravel(m.llNoRecurse) && recursion
        ENDIF
      ENDFOR
    ENDIF
  ENDFUNC  && Ravel
  * ----------------------------------------------------------- *
ENDDEFINE  && L7CollectionHierarchy

#if .f.
01/03/2002 - Created class.
12/03/2003 - revised L7Menu.AddFolder() to allow adding submenus with URLs, etc.
#endif

* End: L7Menu.prg
