* L7Utils.PRG
*
* Level 7 Cycla Utilities
*
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

Contributor(s):
1. Lauren Clarke, Cornerstone Systems NW, provided the design for the
L7 parser technology (see L7Parsers.PRG).

***** END LICENSE BLOCK *****
#ENDIF

__main()
return 
* --------------------------------------------------------- *
function __main
  __test()  
endfunc 
* --------------------------------------------------------- *
function __test
  set procedure to L7Api, wwAPI additive
  set memowidth to 72
  ? date()
  local loObj, ii, jj
  loObj = createobject('L7ProcessingTime')
  with loObj
    .noteStart()

    sleep(2)
    for ii = 1 to 3
      .noteStart('two')
      sleep(2)
      for jj = 1 to 7
        .noteStart('three.a')
        sleep(1)
        * .noteEnd('three.a')
        .noteEnd()
        .noteStart('three.b')
        sleep(1)
        .noteEnd('three.b')
      next 
      .noteEnd('two')
    next
    
    .noteEnd('one')
    ? .render()
  endwith 
  ?
  ?
endfunc && __test

* --------------------------------------------------------- *
function __macro()
  * Alt-C macro commands: (don't try running, instead record as macro, and save as default)
  _GENSCRN = _FOXCODE
  _FOXCODE = ""
  SET DEVELOPMENT ON
  SET PROCEDURE TO
  SET CLASS TO
  CLOSE DATABASES ALL
  CLEAR ALL
  CLEAR
  CANCEL
  CLEAR PROGRAM
  _FOXCODE = _GENSCRN
endfunc 

*** ===================================================== ***
define class L7ProcessingTime as Custom
  nFreq = null
  oRoot = null 
  *--------------------------------------------
  function DESTROY
    this.release()
  endfunc
  *--------------------------------------------
  function release
    if !isnull(this.oRoot)
      this.releaseItem(this.oRoot)
      this.oRoot = null
    endif
  endfunc
  *--------------------------------------------
  function releaseItem(toNode)
    local lnItem, loChild
    for lnItem = 1 to toNode.oNested.count 
      loChild = toNode.oNested.item[m.lnItem]
      this.releaseItem(m.loChild) && recurse
    next
    toNode.oNested.remove(-1)
    toNode.oCurrent = null
    return 
  endfunc
  *--------------------------------------------
  function init
    this.setup()
  endfunc 
  *--------------------------------------------
  function Setup
    this._setFrequency()
    this.oRoot = this._NewItem('MAIN')
  endfunc 
  *--------------------------------------------
  function _setFrequency
    this.nFreq = L7GetPerfFrequency() && L7API.prg
    return  
  endfunc 
  *--------------------------------------------
  function _NewItem(tcId)
    local loObj
    loObj = createobject("Empty")
    addproperty(m.loObj, "cName", m.tcId)
    addproperty(m.loObj, "nUsages", 0)
    addproperty(m.loObj, "nStartCounter", null)
    addproperty(m.loObj, "nMax", null)
    addproperty(m.loObj, "nCumTime", 0)
    addproperty(m.loObj, "oCurrent", null)
    addproperty(m.loObj, "oNested", createobject("Collection"))
    return m.loObj
  endfunc 
  *--------------------------------------------
  function _clearBelow(toNode)
    local lnItem, loChild
    for lnItem = 1 to toNode.oNested.count 
      loChild = toNode.oNested.item[m.lnItem]
      this._clearBelow(m.loChild) && recurse! 
      loChild.oCurrent = null
    next
    * Note done here: toNode.oCurrent = null
    return 
  endfunc
  *--------------------------------------------
  function _noteNodeStart(toNode)
    toNode.nStartCounter = L7GetPerfCounter()
    return 
  endfunc
  *--------------------------------------------
  function _noteNodeEnd(toNode, tnEnd)
    local lnItem, loChild, lnElapsed
    if !isnull(toNode.nStartCounter) && was started
      if empty(m.tnEnd)
        tnEnd = L7GetPerfCounter()
      endif
      lnElapsed = (m.tnEnd - toNode.nStartCounter) / this.nFreq

      toNode.nUsages = toNode.nUsages + 1
      toNode.nCumTime = toNode.nCumTime + m.lnElapsed
      if isnull(toNode.nMax) or m.lnElapsed > toNode.nMax
        toNode.nMax = m.lnElapsed 
      endif 
      toNode.nStartCounter = null
      for lnItem = 1 to toNode.oNested.count 
        loChild = toNode.oNested.item[m.lnItem]
        this._noteNodeEnd(m.loChild, m.tnEnd) && recurse! 
        * by passing tnEnd down, we synchronize all end points, and avoid PerfCounter calls 
      next
    endif 
    return 
  endfunc
  *--------------------------------------------
  function _getCurrent(toNode, tcId, tlClear)
    local loNode, lvRet
    loNode = iif(vartype(m.toNode) = 'O', m.toNode, this.oRoot)
    if empty(m.tcId) && simply looking for whatever is current
      if isnull(m.loNode.oCurrent)
        lvRet = m.loNode
      else
        if isnull(m.loNode.oCurrent.oCurrent)
          lvRet = m.loNode.oCurrent
          if m.tlClear
            loNode.oCurrent = null
          endif
        else
          lvRet = this._getCurrent(m.loNode.oCurrent,, m.tlClear) && recurse!
        endif
      endif
    else
      if loNode.cName == m.tcId
        lvRet = loNode 
      else
        if isnull(loNode.oCurrent) && nothing below--strike out!
          lvRet = null
        else
          if m.loNode.oCurrent.cName == m.tcId
            lvRet = m.loNode.oCurrent
            if m.tlClear
              loNode.oCurrent = null
            endif
          else
            lvRet = this._getCurrent(m.loNode.oCurrent, m.tcId, m.tlClear) && recurse!
          endif 
        endif
      endif 
    endif 
    return m.lvRet
  endfunc 
  *--------------------------------------------
  function NoteStart(tcID)
    local loNode, loParent, lnKey, llNew
    if empty(m.tcId)
      tcId = this.oRoot.cName
    endif
    loNode = this._getCurrent(this.oRoot, m.tcId)
    if isnull(m.loNode) && ID not found in current path
      loParent = this._getCurrent()
      lnKey = loParent.oNested.getkey(m.tcId)
      if m.lnKey = 0 && need new child for this parent
        if !isnull(loParent.oCurrent) && something else was current
          this._clearBelow(loParent.oCurrent)
          this._noteNodeEnd(loParent.oCurrent)
        endif
        llNew = .t.
        loNode = this._newItem(m.tcId)
        loParent.oNested.add(m.loNode, m.tcId)
        ** ? 'added', loNode.cName, 'below', loParent.cname
      else && previously existing node becoming current again 
        loNode = loParent.oNested.item[m.lnKey]
      endif 
      loParent.oCurrent = m.loNode
    else
      this._clearBelow(m.loNode)
      this._noteNodeEnd(m.loNode)
    endif
    if isnull(this.oRoot.nStartCounter)
      this._noteNodeStart(this.oRoot)
    endif
    this._noteNodeStart(m.loNode)
    return
  endfunc 
  *--------------------------------------------
  function NoteEnd(tcID)
    local loNode, loParent
    if empty(m.tcId)
      loNode = this._getCurrent(this.oRoot,, .t.)
    else
      loNode = this._getCurrent(this.oRoot, m.tcId, .t.)
    endif
    if isnull(m.loNode) && ID not found in current path
      * error?
    else
      this._clearBelow(m.loNode)
      this._noteNodeEnd(m.loNode)
    endif 
    return
  endfunc 
  *--------------------------------------------
  function Render(toNode, tnLvl, tnTT)  && plain text suitable for L7ParseOnView()
    local lcRet, loNode, lnLvl, lnTT, lnPct, lcMsg, lnItem, loChild, lcTmp
    lcRet = ""
    loNode = iif(vartype(m.toNode) = "O", m.toNode, this.oRoot)
    this.noteEnd(this.oRoot.cName) && JIC left open
    lnLvl = evl(m.tnLvl, 0)
    lnTT = evl(m.tnTT, loNode.nCumTime)
    lnPct = loNode.nCumTime / max(m.lnTT, 0.001)
    lcMsg = textmerge([<<100 * m.lnPct>>%])
    if m.lnPct > 0.05
      lcMsg = "*" + m.lcMsg + "*"
    endif 
    lcRet = space(m.lnLvl) + "* " + textmerge([<<m.lcMsg>>, <<loNode.cName>>, <<loNode.nUsages>> calls, cum: <<loNode.nCumTime>> sec, max: <<loNode.nMax>> sec]) + CRLF
    if loNode.oNested.count > 0
      for lnItem = 1 to loNode.oNested.count
        loChild = loNode.oNested.item[m.lnItem]
        lcTmp = this.render(m.loChild, m.lnLvl + 1, m.lnTT) && recurse! 
        lcRet = m.lcRet + m.lcTmp
      next
    endif
    return m.lcRet
  endfunc 
enddefine && L7ProcessingTime 

*** ===================================================== ***
define class BAD_L7ProcessingTime as Custom
  cName = "MAIN"
  oCurrent = null 
  tStart = null
  nStartCounter = null
  nUsages = 0
  nMax = null
  nCumTime = 0
  nFreq = null
  add object oNested as collection
  *--------------------------------------------
  function DESTROY
    this.release()
  endfunc
  *--------------------------------------------
  function release
    this.oNested.remove(-1)
    if !isnull(this.oCurrent)
      this.oCurrent.release()
      this.oCurrent = null
    endif
    return 
  endfunc
  *--------------------------------------------
  function getCurrent(tcId)
    if !empty(m.tcId) and this.cName == m.tcId
      return this
    endif 
    return iif(isnull(this.oCurrent), this, this.oCurrent.getCurrent(m.tcId)) && recursive method!
  endfunc 
  *--------------------------------------------
  function NoteStart(tcID)
    local loItem, lnKey, loTmp, lcId
    lcID = iif(empty(m.tcId), this.cName, m.tcId)
    if isnull(this.nFreq) && only affects top object
      this.setFrequency()
    endif
    loItem = this.getCurrent(m.lcId)
    if !loItem.cName == m.lcId
      lnKey = loItem.oNested.getkey(m.lcId)
      if m.lnKey = 0
        if !loItem.cName == m.lcId
          loTmp = loItem.NewItem(m.lcId)
          loItem = m.loTmp
        endif 
      else
        loTmp = loItem.oNested.item[m.lnKey]
        loItem.oCurrent = m.loTmp
        loItem = m.loTmp
      endif
    endif 
    if !isnull(loItem.nStartCounter)
      loItem.noteMyEnd()
    endif
    loItem.nStartCounter = L7GetPerfCounter()
    loItem.tStart = datetime()
    if isnull(this.nStartCounter) && root item must be started
      this.nStartCounter = loItem.nStartCounter 
      this.tStart = loItem.tStart
    endif
    return 
  endfunc 
  *--------------------------------------------
  function noteEnd(tcId)  && param not yet used
    local lcId, loItem
    
    if empty(m.tcId) && must assume current node intended
      loItem = this.getCurrent()
      lcId = loItem.cName
    else
      lcId = m.tcId
    endif
    
    if this.cName == m.lcId
      this.noteMyEnd()
    else
      this.oCurrent.noteEnd(m.lcId)
      if this.oCurrent.cName = m.lcId 
        this.oCurrent = null
      endif
    endif
    
    
    ** lcID = iif(empty(m.tcId), this.cName, m.tcId)
*!*      loItem = this.getCurrent(m.tcId)
*!*      loItem.noteMyEnd()

*!*      if !isnull(this.oCurrent)
*!*        if this.oCurrent.noteEnd()
*!*        ** if isnull(this.oCurrent.oCurrent) && next node down was current--now ended
*!*          this.oCurrent = null
*!*        endif
*!*      else
*!*        llWasMe = .t.
*!*        this.noteMyEnd()
*!*      endif 
*!*      return m.llWasMe
  endfunc 
  *--------------------------------------------
  function noteMyEnd(tnForce)
    local lnElapsed, lnEndCounter, loItem, lnItem
    lnEndCounter = iif(empty(m.tnForce), L7GetPerfCounter(), m.tnForce)
      if !isnull(this.nStartCounter)
        * lnElapsed = datetime() - .tStart
        lnElapsed = (m.lnEndCounter - this.nStartCounter) / this.nFreq
        this.nUsages = this.nUsages + 1
        this.nCumTime = this.nCumTime + m.lnElapsed
        if isnull(this.nMax) or m.lnElapsed > this.nMax
          this.nMax = m.lnElapsed 
        endif 
        this.tStart = null
        this.nStartCounter = null
      endif
      if this.oNested.count > 0
        for lnItem = 1 to this.oNested.count
          loItem = this.oNested.item[m.lnItem]
          loItem.noteMyEnd(m.lnEndCounter)
        next
      endif

    return 
  endfunc 
  *--------------------------------------------
  function NewItem(tcId)
    local loObj
    loObj = createobject(this.Class)
    loObj.cName = m.tcId
    loObj.nFreq = this.nFreq 
    this.oNested.add(m.loObj, m.tcId)
    this.oCurrent = m.loObj
    return m.loObj
  endfunc 
  *--------------------------------------------
  function Render(tnLvl, tnTT, tnForceEnd)  && plain text suitable for L7ParseOnView()
    local lcRet, lcTmp, loItem, lnItem, lnLvl, lnTT, lcNote, lnPct, lnEnd
    lcRet = ""
    lnEnd = iif(empty(m.tnForceEnd), L7GetPerfCounter(), m.tnForceEnd)
    this.noteMyEnd(m.lnEnd) && JIC left open
    lnLvl = evl(m.tnLvl, 0)
    lnTT = evl(m.tnTT, this.nCumTime)
    lnPct = this.nCumTime / max(m.lnTT, 0.001)
    lcMsg = textmerge([<<100 * m.lnPct>>%])
    if m.lnPct > 0.05
      lcMsg = "*" + m.lcMsg + "*"
    endif 
    lcRet = space(m.lnLvl) + "* " + textmerge([<<m.lcMsg>>, <<this.cName>>, <<this.nUsages>> calls, cum: <<this.nCumTime>> sec, max: <<this.nMax>> sec]) + CRLF
    if this.oNested.count > 0
      for lnItem = 1 to this.oNested.count
        loItem = this.oNested.item[m.lnItem]
        lcTmp = loItem.render(m.lnLvl + 1, m.lnTT, m.lnEnd)
        lcRet = m.lcRet + m.lcTmp
      next
    endif
    return m.lcRet
  endfunc 
  *--------------------------------------------
  function setFrequency
    this.nFreq = L7GetPerfFrequency() && L7API.prg
    return  
  endfunc 
  
enddefine && BAD_L7ProcessingTime 

*** ===================================================== ***
define class L7SemaphoreLock as Line 
  cFullPath = null
  lWrite = .t.
  nHandle = 0
  lCloseOnRelease = .t. && dangerous not to set TRUE
  lDeleteOnClose = .t.
  *--------------------------------------------
  function release()
    if this.nHandle > 0 and this.lCloseOnRelease
      try 
        fclose(this.nHandle)
        this.nHandle = 0
        if this.lDeleteOnClose
          erase (this.cFullPath)
        endif
      catch to loExc
        = .f.
      endtry
    endif
    return 
  endfunc 
  *--------------------------------------------
  function destroy
    this.release()
    return 
  endfunc 
  *--------------------------------------------
  function isLocked
    return this.nHandle > 0
  endfunc 
  *--------------------------------------------
  function Lock(tcFullpath, tlWrite, tcTxt)
    local lnAtt, lnH, lcTxt
    lnAtt = iif(m.tlWrite, 12, 10)
    lnH = 0 && not yet tried
    lcTxt = iif(empty(m.tcTxt), textmerge([Created <<datetime()>> by processID <<_vfp.ProcessId>>]), m.tcTxt)
    this.cFullPath = m.tcFullPath
    if !file(m.tcFullPath)
      lnH = fcreate(m.tcFullPath)
      if m.lnH > 0
        fwrite(m.lnH, m.lcTxt)
        if !m.tlWrite && need to revert to read/shared use
          fclose(m.lnH)
          lnH = 0
        endif
      endif
    endif  
    if m.lnH = 0 && not yet tried, or created and closed for re-opening shared
      lnH = fopen(m.tcFullPath, m.lnAtt)
    endif 
    this.nHandle = m.lnH
    return this.nHandle > 0
  endfunc 
enddefine && L7SemaphoreLock 

*** ===================================================== ***
define class L7ArrayCompare as Line 
  *--------------------------------------------
  * calling example
  *  loComp = createobject("L7ArrayCompare")
  *  bindevent(loComp, "onItem", this, "onComparisonItem")
  *  loComp.raiseoldnew(m.loOld, "id_set", m.loNew, "id_set")
  *--------------------------------------------
  function raiseoldnew(toOld, tcOldProp, toNew, tcNewProp, tcCallbackId)
    local loTemp, lcId, lnIdx
    loTemp = createobject("collection")
    if !isnull(m.toOld.&tcOldProp)
      for lnIdx = 1 to alen(toOld.&tcOldProp)
        lcId = toOld.&tcOldProp[m.lnIdx]
        try
          loTemp.add(m.lcId, m.lcId)
        catch
        endtry
      endfor 
    endif

    if !isnull(m.toNew.&tcNewProp)
      for lnIdx = 1 to alen(toNew.&tcNewProp)
        lcId = toNew.&tcNewProp[m.lnIdx]
        if loTemp.getkey(m.lcId) > 0
          raiseevent(this, "onItem", m.lcId, m.lcId, m.tcCallbackId)
          loTemp.remove(m.lcId)
        else
          raiseevent(this, "onItem", null, m.lcId, m.tcCallbackId)
        endif
      endfor 
    endif
    
    for each lcId in loTemp
      raiseevent(this, "onItem", m.lcId, null, m.tcCallbackId)
    next
    return 
  endfunc 
  *--------------------------------------------
  function onItem(tcOld, tcNew)
  endfunc 
  *--------------------------------------------
enddefine 

*--------------------------------------------
* Example for next 2 functions:
*  local loStart
*  loStart = L7noteObjectState(someObj)
*  do whatever processing...
*  if !L7compareObjectState(someObj, toStart)
*    alert( 'object intended for persistence was changed!'
*  endif
*--------------------------------------------
function L7noteObjectState(toObj)
  * Note object state for later comparison to check stateless candidacy.
  local laProps[1], lnProps, lcName, ii, loRet, lvVal
  loRet = createobject("Collection")  && return a collection of prop-level comparison data
  
  * Process 1st object:
  lnProps = amembers(laProps, m.toObj, 0) && 0 = properties only in 1-D array
  for ii = 1 to m.lnProps
    lcName = laProps[m.ii]
    if !pemstatus(m.toObj, m.lcName, 5) or pemstatus(m.toObj, m.lcName, 1)
      * prop d.n.e.                     or readonly prop
      loop
    endif
    if pemstatus(m.toObj, m.lcName, 0)  && changed -- need to note value for comparing later
      lvVal = m.toObj.&lcName
      loRet.add(m.lvVal, m.lcName) && do we need to screen protected props??
      * debugout m.lcName, m.lvVal
    endif
  next && prop
  return m.loRet
endfunc 
*--------------------------------------------
function L7compareObjectState(toObj, toOrigVals, tcInfo)
  * Sister to L7noteObjectState().
  local laProps[1], lnProps, lcName, ii, llRet, lvVal, lnKey
  tcInfo = ""
  llRet = .t.
  * Process 1st object:
  lnProps = amembers(laProps, m.toObj, 0) && 0 = properties only in 1-D array
  for ii = 1 to m.lnProps
    lcName = laProps[m.ii]
    if !pemstatus(m.toObj, m.lcName, 5) or pemstatus(m.toObj, m.lcName, 1)
      * prop d.n.e.                     or readonly prop
      loop
    endif
    if pemstatus(m.toObj, m.lcName, 0)  && changed -- see if different than when noted first
      lvVal = m.toObj.&lcName
      lnKey = toOrigVals.getkey(m.lcName)
      if m.lnKey = 0 && not changed when first noted
        llRet = .f.
        debugout m.lcName, "set to:", m.lvVal
      else && tougher case--was already changed when we started, looking for further change
        if vartype(m.lvVal) = "O"
          debugout m.lcName, "cannot tell--accepting"
        else
          if !m.lvVal == toOrigVals.item(m.lnKey)
            llRet = .f.        
            debugout m.lcName, "changed to:", m.lvVal
          endif
        endif
        * arrays?, collections?
      endif 
    else
      * do we need to check for value reverted?
    endif
  next && prop
  return m.llRet
endfunc 
*--------------------------------------------
function extend(tlRecurse, toTarg, toWith1, toWith2)
  * Extend target object with properties of a source "extend with" object.
  * - adds non-matching properties, updates values on matching properties
  * - good for "parameter" object being passed to function with default object settings
  
  local llRecurse, loTarg, loWith, lo3rd, laPEM[1], lnPEM, lnPEMs, lcPEM
  * recurse param included, but not supprted yet
  llRecurse = iif(vartype(m.tlRecurse) = "L", m.tlRecurse, .f.)
  loTarg = iif(vartype(m.tlRecurse) = "L", m.toTarg, m.tlRecurse) && matching jQuery parm sequence
  loWith = iif(vartype(m.tlRecurse) = "L", m.toWith1, m.toTarg) 
  lo3rd = iif(vartype(m.tlRecurse) = "L", m.toWith2, m.toWith1) 
  
  if vartype(m.loWith) = "O" && be graceful if "with" object was optional
    lnPEMs = amembers(laPEM, m.loWith, 0)
    for lnPEM = 1 to m.lnPEMs
      lcPEM = laPEM[m.lnPEM]
      if !pemstatus(m.loTarg, m.lcPEM, 5)
        addproperty(m.loTarg, m.lcPEM)
      endif
      store loWith.&lcPEM to loTarg.&lcPEM
    next && property
  endif
    
  if vartype(m.lo3rd) = "O"  && extend with another obj
    loTarg = Extend(m.llRecurse, m.loTarg, m.lo3rd)
  endif
    
  return loTarg
endfunc && extend 

*--------------------------------------------
function L7MKDir(tcPath, toFSO) && Recursive, case-maintaining version of MKDIR
  * Pass in a full spec. Creates folders recursively if needed.
  * Does nothing if folder already exists (i.e., safe to call w/o checking).
  * TO DO: handle relative paths (uses FSO, so "current directory" is not in context)
  if directory(m.tcPath)
    return
  endif
  if empty(m.tcPath)
    return
  endif 
  local lcParent
  if vartype(m.toFso) <> 'O'
    toFSO = createobject("Scripting.FileSystemObject")
  endif
  lcParent = toFSO.GetParentFolderName(m.tcPath)
  if !toFSO.FolderExists(m.lcParent) && parent folder d.n.e.
    L7MKDir(m.lcParent, m.toFSO)  && Recursion!
  endif
  toFSO.CreateFolder(m.tcPath)
  return
endfunc && L7MKDir

*--------------------------------------------
function L7EventCreate(tcMsg, tnId, tnSeverity, tcSource)
  * severity: 4 = error, 5 = warning, 7 = information
  local loEC as L7EventCreate, loItem
  loEC = createobject("L7EventCreate")
  loItem = loEC.getParameterObject()
  with loItem
    .Description = m.tcMsg
    .ID = evl(m.tnID, .ID)
    .Severity = evl(m.tnSeverity, .Severity)
    * .Log = "application"
    .Source = evl(m.tcSource, .Source)
  endwith
  loEC.Write(m.loItem)
  return && [[ try/catch and return t/f based on success?
endfunc 

*** ===================================================== ***
define class L7EventCreate as Line
  *--------------------------------------------
  function getParameterObject
    local loObj
    loObj = createobject("Empty")
    addproperty(loObj, "Severity", L7_SEVERITY_ERROR) && default to worst case if not spec'd
    addproperty(loObj, "Log", "application")
    addproperty(loObj, "Description", "-no event description-")
    addproperty(loObj, "Source", "L7 Application")
    addproperty(loObj, "ID", 800)
    addproperty(loObj, "Command", null)
    addproperty(loObj, "Success", null)
    * add support for computer, user, password if needed (see notes below)
    return m.loObj
  endfunc
  *--------------------------------------------
  function write(toObj)
    local lcCmd, lcTmp, lcSev
    with toObj
      lcSev = this.getEventSeverity(toObj.Severity)

      if OS(3) > '5' OR (OS(3) = '5' AND OS(4) >= '1')  && XP and Win2K3 support EVENTCREATE, but not Win2000 and before
        TEXT TO lcTmp NOSHOW PRETEXT 3
          RUN /N7 EVENTCREATE /so "<<.Source>>" /t <<m.lcSev>> /l <<.Log>> /id <<.ID>> /d "<<.Description>>"
        ENDTEXT
        lcCmd = TEXTMERGE(m.lcTmp)
        toObj.Command = m.lcCmd
        &lcCmd
        toObj.Success = .t. && [[ this doesn't catch a problem w/ the command!
      else  && could do more here if Win2000 support mattered:
        * ??
        lcCmd = ""
        toObj.Success = .f.
      endif  
    endwith 
    return m.lcCmd
  endfunc
  *--------------------------------------------
  function getEventSeverity(tvSev)  && return choices acceptable to event logs
    local lcRet
    if vartype(m.tvSev) = "C"
      tvSev = L7SeverityNumber(m.tcSev)
    endif
    do case
    case m.tvSev <= L7_SEVERITY_ERROR
      lcRet = "error"
    case m.tvSev <= L7_SEVERITY_WARNING
      lcRet = "warning"
    otherwise 
      lcRet = "information"
    endcase
    return m.lcRet
  endfunc 
enddefine  && L7EventCreate 

*----------- EVENTCREATE NOTES (distilled from Microsoft info) --------------
#if .f.
  Eventcreate is a command-line utility ...:
    * /s computer
    * /u domain\user
    * /p password
    * /l - name of the log where the event will be created. Only APPLICATION or SYSTEM are permitted.
    * /so - source name (source name that is generating the event, and this can be any string, but is typically the program)
    * /t - type of event to create. The valid event types are ERROR, WARNING, and INFORMATION.
    * /id EventID (integer between 1 and 1000; IDs do not have to be unique, and it is a good idea to use them to record an identifiable error number such as the exit code from a program.)
    * /d - description to use for the newly-created event. Use quotation marks (") to specify a multi-word string.
  NOTE: You must supply values for the /t, /id and /d options, and another value for the /l or /so option.

  Create an event in the Application Log
  To create an error event in the Application log with the "Application failed" description, use the 
  eventcreate /t error /id 1000 /l application /d "Application failed" command.

  Create an event for a specific program in the Application log
  To create an information event in the program for Winword.exe with the "Printed ten documents" description, use the 
  eventcreate /t information /id 1 /l application /so winword /d "Printed ten documents" command.

* ex: EVENTCREATE /so "My WC App" /t Warning /l Application /id 800 /d "Invalid user action"
#endif 

*** ===================================================== ***
define class l7LogItem as Line
  Processed = .f.
  Severity = L7_SEVERITY_DEFAULT
  LogLine = ""
  Details = null  && info not suitable to single-line output
  TimeStamp = null
  App = ""
  Page = ""
  *------------------------------------------------------------------
  function render
    return this.renderHtml()
  endfunc 
  *------------------------------------------------------------------
  function renderPlain
    local lcRet
    lcRet = textmerge([<<this.timestamp>> <<padr(l7SeverityName(this.severity) + ":", 10)>> <<this.LogLine>>]) + CRLF
    return m.lcRet
  endfunc 
  *------------------------------------------------------------------
  function renderHtml
    local lcRet, lcSev, lcTmp
    lcSev = l7SeverityName(this.severity)
    text to lcTmp noshow pretext 3
      <span class="<<m.lcSev>>">
        <span class="timestamp"><<this.timestamp>></span>
        <span class="severity"><<m.lcSev>></span>:
        <span class="logline"><<this.LogLine>></span>
      </span>
      
    endtext 
    lcRet = textmerge(m.lcTmp) + CRLF
    return m.lcRet
  endfunc 
  
enddefine 

*--------------------------------------------
function L7SeverityName(tnSev)
  tnSev = evl(m.tnSev, L7_SEVERITY_DEFAULT)
  return icase(;
    m.tnSev = L7_SEVERITY_EMERGENCY, "EMERGENCY", ; && 1
    m.tnSev = L7_SEVERITY_ALERT, "ALERT", ;         && 2 immediate action needed (email + page)
    m.tnSev = L7_SEVERITY_CRITICAL, "CRITICAL", ;   && 3 critical conditions
    m.tnSev = L7_SEVERITY_ERROR, "ERROR", ;         && 4
    m.tnSev = L7_SEVERITY_WARNING, "WARNING", ;     && 5
    m.tnSev = L7_SEVERITY_NOTICE, "NOTICE", ;       && 6 normal but significant 
    m.tnSev = L7_SEVERITY_INFO, "INFO", ;           && 7 info-only
    m.tnSev = L7_SEVERITY_DEBUG, "DEBUG", ;         && 8 debug-level messages
    "?????") 
endfunc 
*--------------------------------------------
function L7SeverityNumber(tcSev)
  tcSev = upper(evl(m.tcSev, L7_SEVERITY_DEFAULT_NAME))
  return icase(;
    m.tcSev = "EMERGENCY", L7_SEVERITY_EMERGENCY, ; && 1
    m.tcSev = "ALERT", L7_SEVERITY_ALERT, ;         && 2 immediate action needed (email + page)
    m.tcSev = "CRITICAL", L7_SEVERITY_CRITICAL, ;   && 3 critical conditions
    m.tcSev = "ERROR", L7_SEVERITY_ERROR, ;         && 4
    m.tcSev = "WARNING", L7_SEVERITY_WARNING, ;     && 5
    m.tcSev = "NOTICE", L7_SEVERITY_NOTICE, ;       && 6 normal but significant 
    m.tcSev = "INFO", L7_SEVERITY_INFO, ;           && 7 info-only
    m.tcSev = "DEBUG", L7_SEVERITY_DEBUG, ;         && 8 debug-level messages
    0) 
endfunc 
*--------------------------------------------
function PEMaddUpdate( toObj, tcProp, tvValue )
  * sets a property value, adding the property if needed
  if !pemstatus(m.toObj, m.tcProp, 5)
    addproperty(m.toObj, m.tcProp)
  endif
  toObj.&tcProp = m.tvValue
  return
endfunc
*--------------------------------------------
function PEMisValue( toObj, tcProp, tvValue )
  * return TRUE if toObj has a property tcProp with a value of tvValue [or NULL]
  local llRet, lvVal
  if !pemstatus(m.toObj, m.tcProp, 5) 
    llRet = .f.
  else 
    lvVal = toObj.&tcProp
    if isnull(m.tvValue) 
      llRet = isnull(m.lvVal)
    else
      llRet = !isnull(m.lvVal) and (m.lvVal == m.tvValue) && note: no type checking--error if unmatched
    endif
  endif
   = m.tvValue
  return m.llRet
endfunc  && PEMisValue
*--------------------------------------------
function isNullOrEmptyorMissing( toObj, tcProp )
  return isMissingorNullorEmpty( m.toObj, m.tcProp )
endfunc
*--------------------------------------------
function isMissingOrNullOrEmpty( toObj, tcProp )
  local lvVal
* is not null or empty
  if !pemstatus(m.toObj, m.tcprop, 5) 
    return .t.
  else
    lvVal = toObj.&tcProp
    return iif(isnull(m.lvVal), .t., iif(empty(m.lvVal), .t., .f.))
  endif
  return 
endfunc  && isNullOrEmptyorMissing
*------------------------------------------------------------------
function L7tableToCollection( tcKeyExpr, tcFilter, toCol)
  local loCol, loRec
  if vartype(toCol) = "O"  && collection passed (likely memeber of another object
    loCol = m.toCol
  else 
    loCol = createobject("collection")
  endif 
  if vartype(tcFilter)#"C"
    tcFilter = ".t."
  endif
  
  go top
  scan for &tcFilter
    scatter memo name loRec
    if empty(m.tcKeyExpr)
      loCol.add(loRec)
    else
      loCol.add(loRec,&tcKeyExpr)
    endif
  endscan
  return m.loCol
endfunc  && L7tableToCollection

*--------------------------------------------------------------------*
function JustQueryString(tcUri)
  * take anything after the ?, but removing any hash:
  local lcRet
  lcRet = evl(m.tcUri, "")
  lcRet = getwordnum(m.lcRet, 1, "#")
  lcRet = getwordnum(m.lcRet, 2, "?")
  if !empty(m.lcRet)
    lcRet = "?" + m.lcRet  && consistent with JavaScript's "search" property which includes the "?"
  endif  
  return m.lcRet
endfunc  
*--------------------------------------------------------------------*
function L7TimeDiff(ttThen, ttNow)
  * Pass a datetime from the past and get difference phrase from now; or
  * Pass an older and a reference time, and get a difference phrase; or
  * Pass a delta-T directly [NOW minus THEN] and get a difference phrase.
  if vartype(m.ttThen) <> "N" and (isnull(m.ttThen) or empty(m.ttThen))
    return "NEVER"
  endif 
  
  local lnDiff, lnAbsDiff, lnDays, llLater, lcRet
  * 1. depnding on params, build diff and later flag:
  if vartype(m.ttThen) = "N" && direct pass of diff to get phrase
    lnDiff = m.ttThen  
    llLater = null && don't send "from now" or "ago"
  else
    ttNow = iif(empty(nvl(m.ttNow, "")), datetime(), m.ttNow)
    lnDiff = m.ttNow - m.ttThen
    llLater = m.lnDiff < 0 && set flag to earlier/later
  endif 
  lnAbsDiff = abs(m.lnDiff) && then make absolute for phrase-gen phase
  
  * 2. using lnDiff and llLater, construct phrase:
  do case
  case m.lnAbsDiff < 1
    lcRet = "less than 1 second"
  case m.lnAbsDiff < 50
    lcRet = transform(m.lnAbsDiff) + " seconds"
  case m.lnAbsDiff < 50 * 60
    lcRet = transform(round(m.lnAbsDiff / 60, 0)) + " minutes"
  case m.lnAbsDiff < 23 * 60 * 60
    lcRet = transform(round(m.lnAbsDiff / (60 * 60), 0)) + " hours"
  otherwise
    lnDays = round(m.lnAbsDiff / (60 * 60 * 24), 0)
    do case
    case m.lnDays < 92
      lcRet = transform(m.lnDays) + " days"
    case m.lnDays < 2 * 365
      lcRet = transform(round(m.lnDays / 30.6, 0)) + " months"
    otherwise
      lcRet = transform(round(m.lnDays / 365.25, 0)) + " years"
    endcase
  endcase
  if isnull(m.llLater)
    lcRet = iif(m.lnDiff < 0, "Negative ", "") + ltrim(m.lcRet)
  else
    lcRet = ltrim(m.lcRet) + iif(m.llLater, " from now", " ago")
  endif
    
  return m.lcRet
  
endfunc && l7TimeDiff
*--------------------------------------------------------------------*
FUNCTION L7DateToQuarter(tdDate, tvBiasMonths)
	LOCAL ldDate, lcQtr, lnGoMonths
	ldDate = EVL(m.tdDate, DATE())
	lnGoMonths = 0
	DO CASE 
	CASE VARTYPE(m.tvBiasMonths) = "L" AND m.tvBiasMonths = .T.
		lnGoMonths = 3  && treat .T. as flag for US Govt FY
  CASE VARTYPE(m.tvBiasMonths) = "N"
  	lnGoMonths = m.tvBiasMonths
  ENDCASE 
  IF m.lnGoMonths <> 0
	  ldDate = GOMONTH(m.ldDate, m.lnGoMonths)
	ENDIF 
	lcQtr = TRANSFORM(YEAR(m.ldDate)) + ;
		"-Q" + TRANSFORM(CEILING(MONTH(m.ldDate) / 3))
	RETURN m.lcQtr
ENDFUNC 

*--------------------------------------------------------------------*
FUNCTION L7QuarterToDate(tcQtr, tvBiasMonths, tlReturnFirstDay)
	* tcQtr of pattern: \d{4}-Q[1-4]
	tcQtr = ALLTRIM(m.tcQtr)
	LOCAL ldDate, lcY, lcQ, lnGoMonths
	IF NOT (LEN(m.tcQtr) >= 7 AND SUBSTR(m.tcQtr, LEN(m.tcQtr) - 2, 2) = "-Q")
		ERROR "Invalid quarter format: " + m.tcQtr
  ENDIF 
  lcY = GETWORDNUM(m.tcQtr, 1, "-")
  lcQ = RIGHT(m.tcQtr, 1)
  IF NOT (ISDIGIT(m.lcY) AND m.lcQ $ '1234')
		ERROR "Invalid quarter format: " + m.tcQtr
	ENDIF 	
	
	ldDate = DATE(VAL(m.lcY), 3 * VAL(m.lcQ) - 2, 1)  && basic formula
	
	* adjust backward for FY bias (opposite of L7DateToQuarter)
	lnGoMonths = 0
	DO CASE 
	CASE VARTYPE(m.tvBiasMonths) = "L" AND m.tvBiasMonths = .T.
		lnGoMonths = -3  && treat .T. as flag for US Govt FY
  CASE VARTYPE(m.tvBiasMonths) = "N"
  	lnGoMonths = -1 * m.tvBiasMonths
  ENDCASE 
  IF m.lnGoMonths <> 0
	  ldDate = GOMONTH(m.ldDate, m.lnGoMonths)
	ENDIF 
  
  IF NOT m.tlReturnFirstDay  && last day of quarter requested
  	ldDate = GOMONTH(m.ldDate, 3) - 1  
  ENDIF 

	RETURN m.ldDate
ENDFUNC 

*--------------------------------------------------------------------*
function L7InListX( tcString1, tcString2, tcDelim )
* Description.......: FUNCTION multiInList
*                     Return .t. if lists share one or more elements
*  Calling Samples...: InListx( <expC>, <expC>)
*                      InListx( "8,17,182,2", "11,2,234,982")  returns .t. (2 is common)
  local la1(1), la2(1), ln1, ln2, lnK, lnJ
  
  if empty(tcDelim)
    tcDelim = [,]
  endif
  
  ln1 = alines(m.la1,m.tcString1,m.tcDelim)
  ln2 = alines(m.la2,m.tcString2,m.tcDelim)
  
  for lnK = 1 to m.ln1
    for lnJ = 1 to m.ln2
      if la1(m.lnK)=la2(m.lnJ)
        return .t.
      endif
    endfor
  endfor
  return .f.
endfunc
*--------------------------------------------------------------------*
FUNCTION L7InlistLike(lcList, lcTestStr, lcDelim)  
  LOCAL llOK, ii, lcItem
  lcDelim = EVL(m.lcDelim, ",")
  FOR ii = 1 TO GETWORDCOUNT(m.lcList, m.lcDelim)
    lcItem = ALLTRIM(GETWORDNUM(m.lcList, m.ii, m.lcDelim))
    IF LIKE(m.lcItem, m.lcTestStr)
      llOK = .T.
      EXIT
    ENDIF
  ENDFOR 
  RETURN m.llOK
ENDFUNC

*--------------------------------------------------------------------*
FUNCTION L7Cast(lcStr, lcType)  
  * was named Cast() before VFP 9 added native CAST(eExpr AS cType)
  LOCAL lvVal
  DO CASE
  CASE m.lcType $ "IN"
    lvVal = VAL(m.lcStr)
  CASE m.lcType = "D"
    lvVal = CTOD(m.lcStr)
  CASE m.lcType = "T"
    lvVal = CTOT(m.lcStr)
  CASE m.lcType = "L"
    lvVal = m.lcStr = ".T."
  OTHERWISE
    lvVal = m.lcStr
  ENDCASE
  RETURN m.lvVal
ENDFUNC
*--------------------------------------------------------------------*

FUNCTION ADDFS(lcPath)  && like native ADDBS()
  * Crude: assumes something reasonable is passed in.
  IF RIGHT(m.lcPath, 1) == "/"
    RETURN m.lcPath
  ELSE
    RETURN m.lcPath + "/"
  ENDIF
ENDFUNC

*--------------------------------------------------------------------*
function L7tagToObject( tcTag, toRet )
  * Purpose
  *   Converts a tag like: <gi a="12" b="d=7" c='123456'> into an object with 
  *   properties a, b, c containing the given attribute values
  *   if toRet is passed, properties will be added to it, otherwise EMPTY is used
  *
  * Assumptions:
  *   1. attributes must use =, ie single word attributes (like 'disabled') are not picked up
  * 
  * Usage: 
  *   see tests above
  *
  * Author: Lauren Clarke
  *
  * Change Log: 
  *   05/15/2003: Written [LC]
  *   05/15/2003: Re-written to use array of simpler patterns and single match passes [LC]

  local loRE, lcTag, loRet, loM, llError, lcSubmatch, laPats[3,2], lcDelim

  if vartype( m.toRet ) # [O] 
    loRet = createobject( "Empty" )
  else 
    loRet = m.toRet  
  endif
  
  lcTag = m.tcTag
  loRE  = createobject( L7_REGEXP_CLASS )
  loRE.global = .t.
  loRE.multiLine = .t.

  *-- pattern delimiter pairs 
  laPats(1,1) = '(\s+\w+\s*=\s*"[^"]*")'
  laPats(1,2) = ["]
  laPats(2,1) = "(\s+\w+\s*=\s*'[^']*')"
  laPats(2,2) = [']
  laPats(3,1) = strtran('(\s+\w+\s*=\s*[^`"\s>]+)',[`],['])
  laPats(3,2) = [=]  && this works because of the "2" in the call to strextract below.
  
  for lnK = 1 to alen( laPats, 1)
    loRE.pattern = laPats( m.lnK, 1 )
    lcDelim      = laPats( m.lnK, 2 )
    llError = .f.
 
    try
      loM = loRE.execute( m.lcTag )
    catch
      llerror = .t.
    endtry
    *-- bail on error
    if llerror
      error "L7tagToObject pattern execute failed."
      return m.loRet
    endif
  
    for lnJ = 1 to loM.Count
      lcSubMatch = nvl( loM.item(m.lnJ-1).submatches(0),[] )
      if not empty( lcSubMatch )      
        lcProperty = strtran(getwordnum( lcSubMatch ,1,[=]),[ ])
        lcProperty = strtran(m.lcProperty,chr(10))
        lcProperty = strtran(m.lcProperty,chr(13))
        lcProperty = strtran(m.lcProperty,chr(9))

        if not pemstatus( m.loRet,m.lcProperty,5)
          *[[ bad things can happen here like illegal properties names
          *   consider try-catch, or some sort of inspection if properties are
          *   open content
          * ? lcProperty
          addproperty( m.loRet, m.lcProperty )
        endif  
          *[[ bad things can happen here too like read-only properties
          store strextract( lcSubMatch,lcDelim,lcDelim,1,2 ) to loRet.&lcProperty
        endif
     endfor
  endfor
  return m.loRet
ENDFUNC  && L7tagToObject
* ------------------------------------------------------- *
FUNCTION L7GetEmbeddedTagInfo(lcSource, lnPointer, lcForceTag)
  * Returns an object with info about a tag within a larger string.
  LOCAL loObj, loRE, lcMainTag, lnAtStart, lnAtTemp, lnAtTemp2, lnLoopPtr, ;
    lnStackCount, lcCloseTag, lnAtSpace, lnAtNewLine, lnTagEnd, lnAtClose, lnAtNextOpen
  loObj = CREATEOBJECT("L7EmbeddedTagInfo")
  WITH loObj
    TRY
      * Normally lnPointer will be set to a spot where critical info exists. But if not...
      IF EMPTY(m.lnPointer)
        * Instead we're looking for a critical tag within an entire string.
        IF EMPTY(m.lcForceTag)
          ERROR "Tag not specified."
        ELSE
          lcMainTag = m.lcForceTag
          lnAtStart = L7RegExpATC([<] + m.lcMainTag + [((\s+)|>)], m.lcSource)
          ** lnAtStart = ATC([<] + m.lcMainTag + [ ], m.lcSource)
          IF m.lnAtStart = 0
            ERROR "Open " + m.lcForceTag + " tag not found."
          ENDIF
        ENDIF
      ELSE && already pointing to a location within the content
        .nPointer = m.lnPointer
        * look backward for beginning of open tag: 
        IF NOT EMPTY(m.lcForceTag) && we want a *specfic* type of tag (parent wrapper - looking for whole table/form/div)
          lcStr = [<] + m.lcForceTag + [((\s+)|>)]
          lnAtStart = L7RegexpRAT(m.lcStr, LEFT(m.lcSource, m.lnPointer))
          IF m.lnAtStart = 0
            ERROR "Open " + m.lcForceTag + " tag not found."
          ENDIF
        ELSE
          lnAtStart = RAT("<", LEFT(m.lcSource, m.lnPointer))
          IF m.lnAtStart = 0
            ERROR "Open tag symbol not found."
          ENDIF
        ENDIF
      ENDIF
      .nOpenStart = m.lnAtStart  && mark beginning
      lnAtSpace   = AT(" ", SUBSTR(m.lcSource, m.lnAtStart))      && first space after tag open
      lnAtNewLine = AT(CHR(13), SUBSTR(m.lcSource, m.lnAtStart))  && first new line
      lnAtTagEnd  = AT([>], SUBSTR(m.lcSource, m.lnAtStart))      && first >
      IF m.lnAtTagEnd = 0
        ERROR "No ending > for open tag."
      ENDIF
      .nOpenEnd = .nOpenStart + m.lnAtTagEnd - 1
      lnAtTemp = m.lnAtTagEnd
      lnAtTemp = IIF(BETWEEN(m.lnAtSpace, 2, m.lnAtTemp - 1), m.lnAtSpace, m.lnAtTemp)
      lnAtTemp = IIF(BETWEEN(m.lnAtNewLine, 2, m.lnAtTemp - 1), m.lnAtNewLine, m.lnAtTemp)
      lcMainTag = SUBSTR(m.lcSource, m.lnAtStart + 1, m.lnAtTemp - 2)
      .cTagName = m.lcMainTag
      .cOpenTag = SUBSTR(m.lcSource, .nOpenStart, .nOpenEnd - .nOpenStart + 1)
      IF SUBSTR(.cOpenTag, LEN(.cOpenTag) - 1, 1) == "/"  && premature finale
        .lEmptyTag = .T.
        .nCloseEnd = .nOpenEnd
      ELSE  && look for true close tag
        lnLoopPtr = .nOpenEnd + 1
        lnStackCount = 0
        lcCloseTag = [</] + .cTagName + [>]
        DO WHILE .T.
          lnAtClose = ATC(m.lcCloseTag, SUBSTR(m.lcSource, m.lnLoopPtr))
          IF m.lnAtClose = 0
            ERROR "No matching " + .cTagName + " closing tag."
          ENDIF
          * Before we get too excited:
          lnAtNextOpen = L7RegexpATC([<] + .cTagName + [((\s+)|>)], SUBSTR(m.lcSource, m.lnLoopPtr))
          ** lnAtNextOpen = ATC([<] + .cTagName + [ ], SUBSTR(m.lcSource, m.lnLoopPtr))
          IF m.lnAtNextOpen > 0 AND m.lnAtNextOpen < m.lnAtClose  && we encounter a nested open tag!
            lnStackCount = m.lnStackCount + 1 
            lnLoopPtr = m.lnLoopPtr + m.lnAtNextOpen + 3
            LOOP
          ENDIF
          IF m.lnStackCount > 0  && we're already nested -- start digging out
            lnStackCount = m.lnStackCount - 1 
            lnLoopPtr = m.lnLoopPtr + m.lnAtClose + 3
            LOOP
          ENDIF
          .nCloseStart = m.lnLoopPtr + m.lnAtClose - 1
          .nCloseEnd = .nCloseStart + LEN(m.lcCloseTag) - 1
          .cCloseTag = SUBSTR(m.lcSource, .nCloseStart, .nCloseEnd - .nCloseStart + 1)
          EXIT
        ENDDO
      ENDIF
      .lValid = .T.
      .nLength = .nCloseEnd - .nOpenStart + 1  && convenient for 3rd parm to STUFF()
      .lBetweenTags = NOT .lEmptyTag AND .nPointer > .nOpenEnd  && this may be unallowable in some use cases
    CATCH TO loExc WHEN loExc.ErrorNo = 1098
      loObj.lValid = .F.
      loObj.cErrorMessage = loExc.Message
      loObj.nErrorNo = loExc.ErrorNo
    CATCH TO loExc
      loObj.lValid = .F.
      loObj.cErrorMessage = loExc.Message + [ on line ] + TRANSFORM(loExc.LineNo) 
      loObj.nErrorNo = loExc.ErrorNo
    ENDTRY 
  ENDWITH
  RETURN m.loObj  
ENDFUNC  && L7GetEmbeddedTagInfo
* ------------------------------------------------------- *
DEFINE CLASS L7EmbeddedTagInfo AS L7Lightweight
  lValid        = .F.
  cOpenTag      = ""
  nPointer      = -1
  nOpenStart    = -1
  nOpenEnd      = -1
  nCloseStart   = -1
  nCloseEnd     = -1
  cCloseTag     = ""
  lEmptyTag     = .F.
  lBetweenTags  = .F.  && pointer between open and close tag (vs. within open)
  cTagName      = ""
  nLength       = 0
  cErrorMessage = ""
  nErrorNo      = 0
ENDDEFINE
* ------------------------------------------------------- *
FUNCTION L7ExtensionToContentType(lcExt)
  LOCAL lcType
  lcExt = LOWER(m.lcExt)
  DO CASE
  * Text types:
  CASE LIKE("*htm*", m.lcExt)
    lcType = "text/html"
  CASE m.lcExt == "xml" OR m.lcExt == "rtf" OR m.lcExt == "css" 
    lcType = "text/" + m.lcExt
  * Application types:
  CASE m.lcExt == "pdf"
    lcType = "application/pdf"
  CASE m.lcExt == "fdf"
    lcType = "application/vnd.fdf"
  CASE m.lcExt == "doc"
    lcType = "application/msword"
  CASE m.lcExt == "ppt"
    lcType = "application/vnd.ms-powerpoint"
  CASE m.lcExt == "xls" OR m.lcExt == "iqy"
    lcType = "application/vnd.ms-excel"
  CASE m.lcExt == "txt" OR m.lcExt == "asc" OR m.lcExt == "sdf" OR m.lcExt == "prg"
    lcType = "text/plain"
  CASE m.lcExt == "file" OR m.lcExt == "exe" OR m.lcExt == "dll" OR m.lcExt == "bin"
    lcType = "application/octet-stream"
  CASE LIKE("wp*", m.lcExt)
    lcType = "application/wordperfect5.1"
  CASE LIKE("vs?", m.lcExt)
    lcType = "application/vnd.visio"
  CASE m.lcExt == "js" OR m.lcExt == "json"
    lcType = "application/x-javascript"
  CASE m.lcExt == "manifest"  && html5 offline cache handling
    lcType = "text/cache-manifest"
  CASE m.lcExt == "zip"
    lcType = "application/zip"
  * Image types:
  CASE LIKE("jp*g", m.lcExt)
    lcType = "image/jpeg"
  CASE LIKE("tif*", m.lcExt)
    lcType = "image/tiff"
  CASE m.lcExt == "gif" OR m.lcExt == "bmp" OR m.lcExt == "tng" 
    lcType = "image/" + m.lcExt
  CASE LIKE("svg*", m.lcExt)
    lcType = "image/svg-xml"
  * Default?:
  OTHERWISE
    LOCAL loApi
    TRY
      * Check registry for additional file types using Rick Strahl's wwApi class, if available:
      loApi = CREATEOBJECT("wwAPI")
      lcType = loAPI.ReadRegistryString(HKEY_CLASSES_ROOT, "." + m.lcExt, "Content Type")
    CATCH
      = .F.
    ENDTRY
    IF ISNULL(m.lcType) OR EMPTY(m.lcType)
      lcType = "application/octet-stream"
    ENDIF
  ENDCASE
  RETURN m.lcType
ENDFUNC  && L7ExtensionToContentType
* ------------------------------------------------------- *
function L7ExceptionMessage(toOrigExc)
  * this can have no errors!! (often called from catch, errors here would mask reporting the real errors)
  local lcMsg, loBaseExc, loNewExc
  lcMsg = ""
  try
    if !pemstatus(m.toOrigExc, "BaseClass", 5) or !m.toOrigExc.BaseClass = "Exception"
      lcMsg = "Object sent to L7ExceptionMessage was not an Exception."
    else
      if toOrigExc.ErrorNo = 2071 and vartype(toOrigExc.userValue) = 'O'
        lcMsg = "Thrown exception: "
        loBaseExc = m.toOrigExc.UserValue && the thrown exception
      else
        loBaseExc = m.toOrigExc
      endif
      lcMsg = m.lcMsg + m.loBaseExc.Message
      lcMsg = m.lcMsg + ", Line: " + transform(m.loBaseExc.LineNo)
      lcMsg = m.lcMsg + ", Module: " + m.loBaseExc.Procedure 
    endif
  catch to loNewExc
    if !empty(m.lcMsg)  && partial, append
      lcMsg = m.lcMsg + ", Subsequent error reporting first error: " + loNewExc.Message 
    else
      lcMsg = "Error reporting error: " + loNewExc.Message 
    endif 
  endtry
  return m.lcMsg
endfunc 
* ------------------------------------------------------- *
FUNCTION L7ErrorToException(lnError, lcMethod, lnLine)
  LOCAL lo AS Exception
  lo = CREATEOBJECT("L7Exception") && defined below
  lo.ErrorNo = m.lnError
  lo.Procedure = m.lcMethod
  lo.LineNo = m.lnLine
  lo.LineContents = MESSAGES(1)
  lo.Message = MESSAGES()
  lo.StackLevel = PROGRAM(-1) - 2  && guess
  lo.Details = SYS(2018)
  lo.LoadErrorArray()
  RETURN m.lo
ENDFUNC
* ------------------------------------------------------- *
FUNCTION L7CopyMatchedProperties(loSource, loTarget, lcPattern)
  lcPattern = UPPER(EVL(m.lcPattern, '*'))
  LOCAL laMem[1], lcMem
  AMEMBERS(laMem, m.loSource, 0)
  FOR EACH lcMem IN laMem
    IF LIKE(m.lcPattern, m.lcMem)
      IF VARTYPE(m.loTarget.&lcMem) <> "U"
        STORE m.loSource.&lcMem TO m.loTarget.&lcMem
      ENDIF
    ENDIF
  ENDFOR
ENDFUNC
* ------------------------------------------------------- *
* Deprecated as of VFP8:
FUNCTION TextMergeX(lcText, llRecurse, lcDelimA, lcDelimB)
  * Cope with TEXTMERGE bug in VFP 7.
  LOCAL lcOut
  IF VARTYPE(m.lcDelimA) = "C"
    lcOut = TEXTMERGE(m.lcText+CHR(0), m.llRecurse, m.lcDelimA, m.lcDelimB)
  ELSE
    lcOut = TEXTMERGE(m.lcText+CHR(0), m.llRecurse)
  ENDIF
  RETURN CHRTRAN(m.lcOut,CHR(0),"")
ENDFUNC  && TextMergeX
* ------------------------------------------------------- *
FUNCTION SafeTextMerge(lcTxt, lcDel1, lcDel2, loWatchDog)
  * Allows avoidance of VFP's recursive textmerge errors.
  LOCAL lcOut, lcTmp, lcDel1, lcDel2, lcRest, lcStr, lnAt1, lnAt2
  lcRest = m.lcTxt
  lcOut = ""
  IF EMPTY(m.lcDel1)  && delimiters not passed
    lcDel1 = SET('TEXTMERGE', 1) && def: '<<>>'
    lcDel2 = RIGHT(m.lcDel1, INT(LEN(m.lcDel1)/2))
    lcDel1 = LEFT(m.lcDel1, LEN(m.lcDel1) - LEN(m.lcDel2))
  ENDIF
  DO WHILE LEN(m.lcRest) > 0
    lnAt1 = AT(m.lcDel1, m.lcRest)
    IF m.lnAt1 = 0
      EXIT
    ENDIF
    lnAt2 = AT(m.lcDel2, m.lcRest)
    IF m.lnAt2 <= m.lnAt1
      EXIT
    ENDIF
    IF m.lnAt1 > 1
      lcOut = m.lcOut + LEFT(m.lcRest, m.lnAt1 - 1)
    ENDIF
    lcStr = SUBSTR(m.lcRest, m.lnAt1 + LEN(m.lcDel1), m.lnAt2 - m.lnAt1 - LEN(m.lcDel1))
    IF VARTYPE(m.loWatchDog) = "O"
      IF NOT loWatchDog.Check(m.lcStr)
        ERROR loWatchDog.cReason
        RETURN 
      ENDIF
    ENDIF
    * 2-step concat, to avoid VFP bug with nested concats:
    lcTmp = TRANSFORM(EVALUATE(m.lcStr))
    lcOut = m.lcOut + m.lcTmp
    ** lcOut = m.lcOut + TRANSFORM(EVALUATE(m.lcStr))
    
    lcRest = SUBSTR(m.lcRest, m.lnAt2 + LEN(m.lcDel2))
  ENDDO
  IF LEN(m.lcRest) > 0
    lcOut = m.lcOut + m.lcRest
  ENDIF
  lcTxt = m.lcOut  && in case pass-by-ref is used
  RETURN m.lcTxt
ENDFUNC  && SafeTextMerge
* ------------------------------------------------------- *
*!*  FUNCTION L7SafeMergeText(lcText, lcDelimA, lcDelimB)
*!*    lcDelimA = IIF( EMPTY( m.lcDelimA), L7_TEXTMERGE_DELIM_1, m.lcDelimA)
*!*    lcDelimB = IIF( EMPTY( m.lcDelimB), L7_TEXTMERGE_DELIM_2, m.lcDelimB)
*!*    LOCAL lnAt1, lnAt2, lcStr, lcEval
*!*    DO WHILE .T.
*!*      lnAt1 = AT(m.lcDelimA, m.lcText)
*!*      IF m.lnAt1 = 0
*!*        EXIT
*!*      ENDIF
*!*      lnAt2 = AT(m.lcDelimB, m.lcText)
*!*      IF m.lnAt2 < m.lnAt1
*!*        EXIT
*!*      ENDIF
*!*      lcStr = SUBSTR(m.lcText, m.lnAt1 + LEN(m.lcDelimA), m.lnAt2 - m.lnAt1 - LEN(m.lcDelimA))
*!*      lcEval = TRANSFORM(EVALUATE(m.lcStr))
*!*      lcText = STUFF(m.lcText, m.lnAt1, ;
*!*        LEN(m.lcStr + m.lcDelimA + m.lcDelimB), m.lcEval)
*!*    ENDDO
*!*    RETURN m.lcText
*!*  ENDFUNC  && 
* ------------------------------------------------------- *
FUNCTION L7MergeText(lcText, lcDelimA, lcDelimB, llAllowCB)
* COMING SOON: L7MergeTextReplaces(@lcText)
  lcDelimA = IIF( EMPTY( m.lcDelimA), L7_TEXTMERGE_DELIM_1, m.lcDelimA)
  lcDelimB = IIF( EMPTY( m.lcDelimB), L7_TEXTMERGE_DELIM_2, m.lcDelimB)
  lcText = STRTRAN(STRTRAN(m.lcText, m.lcDelimA, "<|"), m.lcDelimB, "|>")
  lcText = TEXTMERGE(m.lcText, .F., "<|", "|>")
  *!* lcText = TextMergeX(m.lcText,.F.,"<|","|>")
  RETURN m.lcText
ENDFUNC  && L7MergeText
* ------------------------------------------------------- *
FUNCTION L7MergeTextIfs(lcText)
*[[ REWRITE TO USE FULL TAG SEARCH. THIS CODE IS FRAGILE NOW if < or > is in other quotes!
  * Look for l7:if="" attributes in tags and remove whole tag if 
  * expression evals to .F.
  * *Requires* matching closing tags in full document!
  LOCAL loRE, loMatches, loMatch, llEval, lcExpr, lcAttr, loObj, llRepeat, lnCount, lnChanges, lnSpace
  llRepeat = .T. 
  lnChanges = 0
  DO WHILE m.llRepeat
    llRepeat = .F.
    IF ATC([l7:if=], m.lcText) = 0
      EXIT
    ENDIF
    loRE = CREATEOBJECT(L7_REGEXP_CLASS) && regular expression
    loRE.MultiLine = .T.
    loRE.Global = .T. 
    loRE.IgnoreCase = .T.
    loRE.Pattern = '(\s+)(l7:if="([^"]+)")'
    loMatches = loRE.Execute(m.lcText)
    lnCount = loMatches.Count
    FOR ii = 1 TO m.lnCount
      loMatch = loMatches.item[m.ii - 1]
      lnSpace = LEN(loMatch.Submatches[0])  && length of leading whitespace
      lcAttr = loMatch.Submatches[1]
      lcExpr = loMatch.Submatches[2]
      lnStart = loMatch.FirstIndex
      loMatch = NULL
      loObj = L7GetEmbeddedTagInfo(m.lcText, m.lnStart + 1)
      IF m.loObj.lValid = .F. OR m.loObj.lBetweenTags = .T.
        * not well-structured or not an attribute of a tag
        LOOP
      ENDIF
      TRY
        llEval = EVALUATE(m.lcExpr)
        IF VARTYPE(llEval) <> "L"
          ERROR ["l7:if" attribute requires logical expression.]
        ENDIF
      CATCH TO loExc
        llEval = .F.  &&[[ do domething else here later!
      ENDTRY
      IF NOT m.llEval  && false -- squelch
        lnChanges = m.lnChanges + 1 
        lcText = STUFF(m.lcText, loObj.nOpenStart, loObj.nLength, "")
        llRepeat = (m.ii < m.lnCount)
        EXIT  && must jump to outer loop and repeat, since remainder of matches may now be invalid
      ELSE  && .T., just remove the *if* attribute:
        lnChanges = m.lnChanges + 1 
        * Replace with same number of spaces, so other matches are still valid:
        lcText = STUFF(m.lcText, m.lnStart + 1 + m.lnSpace, LEN(m.lcAttr), SPACE(LEN(m.lcAttr)))
      ENDIF
    ENDFOR
    loMatches = NULL
    loRE = NULL
    IF m.llRepeat
      LOOP
    ENDIF
  ENDDO
  RETURN m.lnChanges
ENDFUNC  && L7MergeTextIfs
* ------------------------------------------------------- *
FUNCTION L7MergeTextReplaces(lcText)
*[[ THIS ISN'T WORKING YET. MIGHT NEED STACK HERE. AWAIT REWRITE OF ABOVE METHOD FIRST!
  * Look for l7:replace="" attributes in tags and swap the whole tag with the 
  * result of evaluating the expression
  LOCAL loRE, loMatches, loMatch, llEval, lcExpr, lcAttr, loObj, llRepeat, lnCount, lnChanges
  llRepeat = .T. 
  lnChanges = 0
  DO WHILE m.llRepeat
    llRepeat = .F.
    IF ATC([if=], m.lcText) = 0
      EXIT
    ENDIF
    loRE = CREATEOBJECT(L7_REGEXP_CLASS) && regular expression
    loRE.MultiLine = .T.
    loRE.Global = .T. 
    loRE.IgnoreCase = .T.
    loRE.Pattern = '\s+(if="([^"]+)")'
    loMatches = loRE.Execute(m.lcText)
    lnCount = loMatches.Count
    FOR ii = 1 TO m.lnCount
      loMatch = loMatches.item[m.ii - 1]
      lcAttr = loMatch.Submatches[0]
      lcExpr = loMatch.Submatches[1]
      lnStart = loMatch.FirstIndex
      loMatch = NULL
      loObj = L7GetEmbeddedTagInfo(m.lcText, m.lnStart)
      IF m.loObj.lValid = .F. OR m.loObj.lBetweenTags = .T.
        * not well-structured or not an attribute of a tag
        LOOP
      ENDIF
      TRY
        llEval = EVALUATE(m.lcExpr)
        IF VARTYPE(llEval) <> "L"
          ERROR ["if" attribute requires logical expression.]
        ENDIF
      CATCH TO loExc
        llEval = .F.  &&[[ do domething else here later!
      ENDTRY
      IF NOT m.llEval  && false -- squelch
        lnChanges = m.lnChanges + 1 
        lcText = STUFF(m.lcText, loObj.nOpenStart, loObj.nLength, "")
        llRepeat = (m.ii < m.lnCount)
        EXIT  && must jump to outer loop and repeat, since remainder of matches may now be invalid
      ELSE  && .T., just remove the *if* attribute:
        lnChanges = m.lnChanges + 1 
        * Replace with same number of spaces, so other matches are still valid:
        lcText = STUFF(m.lcText, m.lnStart, LEN(m.lcAttr), SPACE(LEN(m.lcAttr)))
      ENDIF
    ENDFOR
    loMatches = NULL
    loRE = NULL
    IF m.llRepeat
      LOOP
    ENDIF
  ENDDO
  RETURN m.lnChanges
ENDFUNC  && L7MergeTextReplaces
* ------------------------------------------------------- *
FUNCTION XOR( ll_X, ll_Y)
  RETURN m.ll_X AND NOT m.ll_Y OR m.ll_Y AND NOT m.ll_X
ENDFUNC && XOR

* ------------------------------------------------------- *
FUNCTION L7RandomString(tnLen)
  LOCAL lcStr, lcGuid, lnLen
  lnLen = EVL(m.tnLen, 10)
  lcGuid = GetGUID()
  lcStr = ALLTRIM(SYS(2007, m.lcGuid, -1, 1)) && reduce to 10-char hash using CRC-32
  lcStr = PADL(m.lcStr, m.lnLen, "0")         && just in case length isn't 10
  RETURN m.lcStr
ENDFUNC
* ------------------------------------------------------- *
* Following GUID functions based on approach by Rick Strahl, West Wind Technologies.
* (Revised to be more modular, so 16-byte values can be stored.)
* ------------------------------------------------------- *
FUNCTION GetGUIDString(lnLen)
  * Gets a 38-char GUID string from scratch.
  * May also need 36-char version without {}, or 32-char w/o -'s.
  LOCAL lcStr
  lcStr = GUIDToString(GetGUID())
  IF EMPTY(m.lnLen)
  ELSE
    IF INLIST(m.lnLen, 36, 32)
      lcStr = STRTRAN(STRTRAN(m.lcStr, "{", ""), "}", "")
      IF m.lnLen = 32
        lcStr = STRTRAN(m.lcStr, "-", "")
      ENDIF
    ENDIF
  ENDIF
  RETURN m.lcStr
ENDFUNC  && GetGUIDString
* ------------------------------------------------------- *
FUNCTION GetGUID
  * Gets a 16-byte GUID (suitable for storage).
  * WARNING: SQL Server stores GUIDs as 36 characater strings!
  DECLARE INTEGER CoCreateGuid ;
    IN Ole32.dll ;
    STRING @lcGUIDStruc
  * Simulate GUID strcuture with a string:
  LOCAL lcStruc_GUID
  lcStruc_GUID = SPACE(16) 
  IF CoCreateGuid(@lcStruc_GUID) # 0
    RETURN ""
  ENDIF
  RETURN m.lcStruc_GUID
ENDFUNC  && GetGUID
* ------------------------------------------------------- *
FUNCTION GUIDToString(lcStruc_GUID)
  * Converts a 16-byte GUID to a 38-byte GUID string, {...}.
  IF EMPTY(m.lcStruc_GUID)
    RETURN ""
  ENDIF
  DECLARE INTEGER StringFromGUID2 ;
    IN Ole32.dll ;
    STRING cGUIDStruc, ;
    STRING @cGUID, ;
    LONG nSize
  LOCAL lcGUID, lnSize
  lcGUID = SPACE(80)
  lnSize = LEN(m.lcGUID) / 2
  IF StringFromGUID2(m.lcStruc_GUID, @lcGuid, m.lnSize) = 0
    RETURN ""
  ENDIF
  *** String is UNICODE so we must convert to ANSI:
  RETURN STRCONV(LEFT(m.lcGUID, 76), 6)
ENDFUNC  && GUIDToString
* ------------------------------------------------------- *
function ValidGUID(tcId, tlIgnoreCase)
  * only uppercase passes, unless 2nd param is .T.
  if isnull(m.tcID) or !vartype(m.tcID) == 'C'
    return .f.
  endif 
  if len(m.tcId) = 16
    return .t.  && don't know how to judge binary GUIDs, so accept them 
  endif
  local lcId
  lcId = chrtran(m.tcId, '{}-', '') && remove any MS formatting
  if m.tlIgnoreCase
    lcId = upper(m.lcId)
  endif
  * string should be 32 characters and contain only uppercase Hex chars:
  return len(m.lcId) = 32 and empty(chrtran(m.lcId, 'ABCDEF0123456789', ''))
endfunc  && validGuid
* ------------------------------------------------------- *
FUNCTION GetChangedFieldList(lcList)
  LOCAL lcState, ii
  lcList = ""
  lcState = GETFLDSTATE(-1)
  FOR ii = 2 TO LEN(m.lcState)
    IF SUBSTR( m.lcState, m.ii, 1) $ [24]
      lcList = m.lcList + [,] + FIELD( m.ii - 1)
    ENDIF
  ENDFOR
  lcList = SUBSTR( m.lcList, 2)
  RETURN m.lcList
ENDFUNC  && GetChangedFieldList
* ------------------------------------------------------- *
FUNCTION L7GenericFactory( lvObjOrClass, lcModule, lcApp, lvParm1)
  * Either produce a class or accept an existing object,
  * and in either event, return an object reference.
  LOCAL loObj
  DO CASE
  CASE VARTYPE( m.lvObjOrClass) = "O"
    loObj = m.lvObjOrClass
  CASE VARTYPE( m.lvObjOrClass) = "C"
    IF EMPTY( m.lcModule)
      IF PCOUNT() >= 4
        loObj = CREATEOBJECT( m.lvObjOrClass, m.lvParm1)
      ELSE
        loObj = CREATEOBJECT( m.lvObjOrClass)
      ENDIF
    ELSE
      IF PCOUNT() >= 4
        loObj = NEWOBJECT( m.lvObjOrClass, m.lcModule, m.lcApp, lvParm1)
      ELSE
        loObj = NEWOBJECT( m.lvObjOrClass, m.lcModule, m.lcApp)
      ENDIF
    ENDIF
  OTHERWISE
    ERROR "No object or class defintion!"
    RETURN
  ENDCASE
  RETURN m.loObj
ENDFUNC  && L7GenericFactory
* ------------------------------------------------------- *
FUNCTION L7ShowHtml( tcHtml, tcCss, tcJS, lcTitle, tcFile)
  * For testing purposes only. Send an HTML fragment and view it
  * in MSIE. If .T. for CSS or JS sent as 2nd/3rd params, handy defaults are used.
  LOCAL llWrap, lcCss, lcJS, lcHtml, lcFile
  IF EMPTY(m.tcFile)
    lcFile = ""  && let WC name
  ELSE
    lcFile = m.tcFile
    IF NOT ":" $ m.lcFile AND NOT "\" $ m.lcFile
      lcFile = ADDBS(SYS(2023)) + m.lcFile
    ENDIF 
  ENDIF
  
  IF NOT [<html] $ LOWER( m.tcHtml)
    lcHtml = L7_DOCTYPE_LOOSE + CRLF + ;
      [<html>] + CRLF + [<head><title>] + ;
      EVL(m.lcTitle, PROGRAM() + " Output") + ;
      [</title>] + CRLF + ;
      [</head><body>] + m.tcHtml + [</body></html>]
  ELSE
    lcHtml = m.tcHtml
  ENDIF
  IF NOT EMPTY(m.tcCss)
    IF VARTYPE(m.tcCss) = "L"
      lcCss = "http://www.cycla.com/software/l7/l7.css" 
    ELSE
      lcCss = m.tcCss
    ENDIF
    lcHtml = STUFF( m.lcHtml, AT( [<head>], LOWER( m.lcHtml)) + 6, 0, ;
      [<link rel="stylesheet" type="text/css" href="] + m.lcCss + [">] + CRLF)
  ENDIF 
  IF NOT EMPTY(m.tcJs)
    IF VARTYPE(m.tcJs) = "L"
      lcJs = "http://www.cycla.com/software/l7/l7Core.js" 
    ELSE
      lcJs = m.tcJs
    ENDIF
    lcHtml = STUFF( m.lcHtml, AT( [<head>], LOWER( m.lcHtml)) + 6, 0, ;
      [<script src="] + m.lcJs + ["></script>] + CRLF)
  ENDIF 
  ShowHtml( m.lcHtml, m.lcFile ) && dependency on Web Connection (WWWC)
  RETURN 
ENDFUNC  && L7ShowHtml
* ------------------------------------------------------- *
FUNCTION ConcatenateEmail(lcMailList, lcAddress) && does not validate
  IF EMPTY(m.lcMailList) OR EMPTY(m.lcAddress)
    RETURN m.lcMailList + m.lcAddress
  ENDIF
  LOCAL laLines[1], lnLines, lcLine
  lcAddress = STRTRAN(m.lcAddress, ";", ",")
  lcMailList = STRTRAN(m.lcMailList, ";", ",")
  lnLines = ALINES(laLines, m.lcAddress, .T., ",")
  FOR EACH lcLine IN laLines
    IF NOT "," + LOWER(m.lcLine) + "," $ "," + LOWER(m.lcMailList) + ","
      * Not already in list.
      lcMailList = m.lcMailList + "," + m.lcLine
    ENDIF
  ENDFOR
  RETURN m.lcMailList
ENDFUNC  && ConcatenateEmail
* ------------------------------------------------------- *
FUNCTION IsValidEmail(lcIn, llAllowList)
  * Checks if an email address is valid (in syntax only).
  * Optional 2nd parameter indicates if string can be a *list*
  * of email addresses ("bob@x.com, mary@y.org")
  IF VARTYPE(m.lcIn) <> "C" 
    RETURN .F.
  ENDIF
  lcIn = CHRTRAN(ALLTRIM(m.lcIn), ";", ",")
  IF m.llAllowList AND "," $ m.lcIn
    * multiple names passed -- parse and make recursive call
    LOCAL laNames[1], lnNames, ii, llOK
    lnNames = ALINES( laNames, m.lcIn, .T., ",")
    llOK = .T.
    FOR ii = 1 TO m.lnNames
      IF IsValidEmail(laNames[ m.ii])  && recursion!
        LOOP
      ELSE
        llOK = .F.
        EXIT
      ENDIF
    ENDFOR
    RETURN m.llOK
  ELSE  && single value check
    LOCAL lnAt, lcLeft, lcRight
    lnAt = AT("@", m.lcIn)
    * quick checks first:
    IF " " $ lcIn OR NOT "." $ m.lcIn OR ;
      NOT BETWEEN(m.lnAt, 2, LEN(m.lcIn) - 3) OR OCCURS("@", m.lcIn) > 1
      * [[Probably need a check of acceptable chars from the standard, if reliable.
    	RETURN .F.
    ENDIF
    lcLeft = LEFT( m.lcIn, m.lnAt - 1)
    lcRight = SUBSTR( m.lcIn, m.lnAt + 1)
    IF RIGHT(m.lcRight, 1) = "." OR LEFT(m.lcRight, 1) = "." OR NOT "." $ m.lcRight
    	RETURN .F.
    ENDIF
  ENDIF
ENDFUNC  && IsValidEmail
* ------------------------------------------------------- *
FUNCTION MemoToEmail(lcText)
  * Chops into lines for plain text.
  LOCAL lcOut, lnPrev, ii
  lnPrev = SET("MEMOWIDTH")
  SET MEMOWIDTH TO 70
  lcOut = ""
  FOR ii = 1 TO MEMLINES(m.lcText)
    lcOut = lcOut + LTRIM(MLINE(m.lcText, m.ii)) + CRLF
  ENDFOR
  SET MEMOWIDTH TO m.lnPrev
  RETURN m.lcOut
ENDFUNC
* ------------------------------------------------------- *
FUNCTION STOD(lcStr)
  * Inverse of VFP's DTOS() function.
  IF VARTYPE( m.lcStr) <> "C"
  	RETURN {}
  ENDIF
  LOCAL lcTemp
  lcTemp = PADR( m.lcStr, 8)
  lcTemp = [{^] + LEFT( m.lcTemp, 4) + [-] + ;
  	SUBSTR( m.lcTemp, 5, 2) + [-] + ;
  	RIGHT( m.lcTemp, 2) + [}]
  RETURN EVAL( m.lcTemp)
ENDFUNC  && STOD
* ------------------------------------------------------- *
FUNCTION L7ExtractElementMultiple(lcText, lcElement, laArray)
  * Extracts an element's value from an XML string. Pass array by refernece.
  LOCAL lnOccurs, ii
  lnOccurs = L7CountElements( m.lcText, m.lcElement)
  IF m.lnOccurs > 0
  	DIMENSION laArray[ m.lnOccurs]
  	FOR ii = 1 TO m.lnOccurs
  		laArray[ m.ii] = L7ExtractElement( m.lcText, m.lcElement, m.ii)
  	ENDFOR
  ENDIF
  RETURN m.lnOccurs
ENDFUNC  
* ------------------------------------------------------- *
FUNCTION L7ExtractElement(lcText, lcElement, lnOccur, llReturnOuter)
  * Extracts an element's value from an XML string. Optionally supports
  * an occurrence number. See CountElements() for determining number in advance.
  LOCAL lcReturn, lnAt1, lnAt2, lnAt3, lnCount, lnRealCount, lcNext
  lcReturn = ""
  lnOccur = IIF( VARTYPE( m.lnOccur) <> "N" OR EMPTY( m.lnOccur), 1, m.lnOccur )
  lcElement = ALLTRIM( CHRTRAN( m.lcElement, "<>", "  ") )
  lnCount = 1
  lnRealCount = 0
  DO WHILE .T.
  	lnAt1 = ATC( "<" + m.lcElement, m.lcText, m.lnCount )
  	IF m.lnAt1 = 0  && element not found
  		EXIT
  	ENDIF
  	lnCount = m.lnCount + 1  && update AT occurrence counter
  	lcNext = SUBSTR( m.lcText, m.lnAt1 + LEN( m.lcElement) + 1, 1)
  	IF NOT INLIST( m.lcNext, " ", ">", "/" )  
  		* Not the right element name -- a root of a longer name?
  		LOOP
  	ENDIF
  	lnRealCount = m.lnRealCount + 1  && update true count for compare to lnOccur parameter
  	IF m.lnRealCount < m.lnOccur
  		* Not the right occurrence -- keep looking.
  		LOOP
  	ENDIF
  	* We're on the right occurrence.
  	lcRest = SUBSTR( m.lcText, m.lnAt1)
  	lnAt2 = AT( ">", m.lcRest )
  	IF m.lnAt2 = 0
  		EXIT
  	ENDIF
  	lcOpenTag = LEFT( m.lcRest, m.lnAt2 )
  	IF SUBSTR( m.lcOpenTag, m.lnAt2 - 1, 1) = "/"  && empty element, like <Book/>
  		lcReturn = IIF( m.llReturnOuter, m.lcOpenTag, "")
  		EXIT
  	ENDIF
  	lnAt3 = ATC( "</" + m.lcElement + ">", m.lcRest )
  	IF m.lnAt3 = 0  && invalid/missing close tag
  		EXIT
  	ENDIF
  	IF m.llReturnOuter
  		lcReturn = LEFT( m.lcRest, m.lnAt3 + 2 + LEN( m.lcElement) )
  	ELSE
  		lcReturn = SUBSTR( m.lcRest, m.lnAt2 + 1, m.lnAt3 - m.lnAt2 - 1 )
  	ENDIF
  	EXIT
  ENDDO
  RETURN m.lcReturn
ENDFUNC   && L7ExtractElement
* ------------------------------------------------------- *
FUNCTION L7ExtractCDATA(lcText)
  IF NOT '![CDATA[' $ m.lcText
  	RETURN m.lcText
  ENDIF
  *[[ This is crude!!  Fix up later:
  RETURN STRTRAN( STRTRAN( m.lcText, '![CDATA[', ''), ']]', '')
ENDFUNC  
* ------------------------------------------------ *
FUNCTION L7CountElements(lcText, lcElement)
  * Returns number of occurrences of an element in an XML string.
  LOCAL lcReturn, lnAt1, lnAt2, lnAt3, lnCount, lnRealCount, lcNext
  lcReturn = ""
  lcElement = ALLTRIM( CHRTRAN( m.lcElement, "<>", "  ") )
  lnCount = 1
  lnRealCount = 0
  DO WHILE .T.
  	lnAt1 = ATC( "<" + m.lcElement, m.lcText, m.lnCount )
  	IF m.lnAt1 = 0  && element not found
  		EXIT
  	ENDIF
  	lnCount = m.lnCount + 1  && update AT occurrence counter
  	lcNext = SUBSTR( m.lcText, m.lnAt1 + LEN( m.lcElement) + 1, 1)
  	IF NOT INLIST( m.lcNext, " ", ">", "/" )  
  		* Not the right element name -- a root of a longer name?
  		LOOP
  	ENDIF
  	lnRealCount = m.lnRealCount + 1  && update true count for return
  ENDDO
  RETURN m.lnRealCount
ENDFUNC   && L7CountElements
* ------------------------------------------------ *
FUNCTION StandardVfpSettings
  SET DELETED       ON
  SET EXCLUSIVE     OFF
  SET UNIQUE        OFF
  SET MULTILOCKS    ON
  SET CENTURY       ON
  SET EXACT         OFF
  SET ANSI          OFF
  SET COMPATIBLE    OFF
  SET CPDIALOG      OFF    && added 11/02/2003
  SET NOTIFY        OFF    && added 11/02/2003
  SET STRICTDATE TO 0

  SET REPROCESS TO 2  && 2 attempts at .333 sec interval, latter adjustable by sys(3051)
  && SET RESOURCE OFF ????
  SET SAFETY       OFF  
  SET TABLEPROMPT  OFF     && added 10/12/2006 to avoid hung servers
  SET TALK         OFF
  SET TEXTMERGE    NOSHOW  && added 01/06/2002
  RETURN
ENDFUNC  && StandardVfpSettings
* --------------------------------------------------------- *
FUNCTION RevertTables
  * Reverts tables and clears transactions in current
  * datasession only.
  DO WHILE TXNLEVEL() > 0
  	ROLLBACK
  ENDDO
  LOCAL lnUsed, ii, lcAlias
  LOCAL ARRAY laUsed[ 1]
  lnUsed = AUSED( laUsed )
  FOR ii = 1 TO m.lnUsed
  	lcAlias = laUsed[ m.ii, 1]
  	IF CURSORGETPROP( "Buffering", m.lcAlias) > 1
  		* Row or table buffering in effect.
  		TABLEREVERT( .T. , m.lcAlias )
  	ENDIF
  ENDFOR
  RETURN
ENDFUNC  && RevertTables
* ------------------------------------------------ *
FUNCTION CursorToText(lcMerge, lcAlias)
  * Loops through a cursor, concatenating a textmerge.
  * Primary usage is passing one parameter, a textmerge expression
  *   to be applied to each record.
  * Example: 
  *  SELECT Email FROM Whatever INTO CURSOR Query
  *  STRTOFILE( CursorToText('<<TRIM(Email)>>' + CRLF), 'MailingList.TXT') 
  
  LOCAL lnSel, lcOut, lnRec, ii
  * Default to current workarea:
  lcAlias = EVL(m.lcAlias, ALIAS()) 
  
  * Preserve environment:
  lnSel = SELECT()
  IF NOT UPPER(m.lcAlias) == ALIAS()
    SELECT (m.lcAlias)
  ENDIF
  lnRec = RECNO()
  
  * Crude default in case no textmerge expression passed in:
  IF EMPTY(m.lcMerge)
    lcMerge = ""
    FOR ii = 1 TO FCOUNT()
      IF TYPE(FIELD(m.ii)) $ "G"
        lcMerge = m.lcMerge + FIELD(m.ii) + ": (general field)" + CRLF
      ELSE
        lcMerge = m.lcMerge + FIELD(m.ii) + ": " + "<<" + FIELD(m.ii) + ">>" + CRLF
      ENDIF
    ENDFOR
    lcMerge = m.lcMerge + CRLF && blank line between records
  ENDIF

  * Build result string:
  lcOut = ""
  SCAN
    lcOut = m.lcOut + TEXTMERGE(m.lcMerge)
  ENDSCAN
  
  * Restore environment:
  IF BETWEEN(m.lnRec, 1, RECCOUNT())
    GOTO m.lnRec
  ENDIF
  SELECT (m.lnSel)
  
  RETURN m.lcOut
ENDFUNC  && CursorToText
* ------------------------------------------------ *
function ListToCollection(tcList, tlNoTrim)
  * Turns a comma-delimited list into a collection.
  local loRet, lnWord, lcWord
  loRet = createobject("Collection")
  for lnWord = 1 to getwordcount(m.tcList)
    lcWord = getwordnum(m.tcList, m.lnWord, ",")
    loRet.add(iif(m.tlNoTrim, m.lcWord, alltrim(m.lcWord)))
  next 
  return m.loRet
endfunc 
* ------------------------------------------------ *
FUNCTION ListToArray(lcList, laArray, lcType)
  * Turns a comma-delimited list into an array. Pass
  * array by reference. Returns number of elements.
  * Optional 3rd argument causes type conversion.
  IF EMPTY( m.lcList)
  	RETURN 0
  ENDIF
  LOCAL lnOccurs, lnAt1, lnAt2, lcStr, ii
  IF LEFT(m.lcList,1)<>"," OR RIGHT(m.lcList,1)<>","
  	lcList = "," + m.lcList + ","
  	lcList = STRTRAN( m.lcList, ",,", ",")
  ENDIF
  lnOccurs = OCCURS( ",", m.lcList ) - 1
  IF m.lnOccurs = 0
  	RETURN 0
  ENDIF
  DIMENSION laArray[ m.lnOccurs]
  lnAt2 = 1
  FOR ii = 1 TO m.lnOccurs
  	lnAt1 = m.lnAt2
  	lnAt2 = AT( ",", m.lcList, m.ii + 1)
  	lcStr = ALLTRIM( SUBSTR( m.lcList, m.lnAt1 + 1, m.lnAt2 - m.lnAt1 - 1))
  	DO CASE
  	CASE EMPTY( m.lcType)
  		laArray[ m.ii] = m.lcStr
  	CASE m.lcType $ "I"
  		laArray[ m.ii] = ROUND( VAL(m.lcStr), 0)
  	CASE m.lcType $ "BFNY"
  		laArray[ m.ii] = VAL(m.lcStr)
  	CASE m.lcType $ "D"
  		laArray[ m.ii] = CTOD(m.lcStr)
  	CASE m.lcType $ "L"
  		laArray[ m.ii] = (m.lcStr=".T.")
  	OTHERWISE
  		laArray[ m.ii] = m.lcStr
  	ENDCASE
  ENDFOR
  RETURN m.lnOccurs
ENDFUNC  && ListToArray
*------------------------------------------------------------------------------*
function IsCollection(toObject) 
  * returns True if an object derives from Collection base class
  * CAUTION: JsonArray objects are collections (will return TRUE here)
  * see: BasedOn(toObj, tcClass) below for extended needs
  return vartype(m.toObject) = "O" and ;
    pemstatus(m.toObject, "baseclass",5 ) and ;
    lower(m.toObject.baseClass) == "collection"
endfunc 
* ------------------------------------------------ *
FUNCTION BasedOn(toObj, tcClass)
  * Is an object based on a specific class?
  * [[ PEMSTATUS should be used in some spots below.
  IF VARTYPE(m.toObj) <> "O" OR VARTYPE(m.tcClass) <> "C" OR EMPTY(m.tcClass)
  	RETURN .F.
  ENDIF
  tcClass = UPPER(ALLTRIM(m.tcClass))
  *[[ Added by LC 12/31/2003 
  *-- quick bail for empty objects
  IF VARTYPE(m.toObj.Class)=[U]  
    RETURN m.tcClass == [EMPTY]
  ENDIF
  * Quick check to avoid array creation when possible:
  IF m.toObj.Class == m.tcClass OR m.toObj.ParentClass == m.tcClass OR m.toObj.BaseClass == m.tcClass
  	RETURN .T.
  ENDIF
  LOCAL lnClasses, ii
  LOCAL ARRAY laClasses[ 1]
  lnClasses = ACLASS(laClasses, m.toObj)
  FOR ii = 1 TO m.lnClasses
  	IF laClasses[m.ii] == m.tcClass
  		RETURN .T.
  	ENDIF
  ENDFOR
  RETURN .F.
ENDFUNC  && BasedOn
* ------------------------------------------------ *
FUNCTION StuffUrlFileName(lcUrl, lcParm, lvValue)
  lnAt = AT("?", m.lcUrl)
  IF m.lnAt > 0
    lcPath = LEFT(m.lcUrl, m.lnAt - 1)
    lcQS = SUBSTR(m.lcUrl, m.lnAt)
  ELSE
    lcPath = m.lcUrl
    lcQS = ""
  ENDIF
  lcFile = JUSTFNAME(m.lcPath)
  lnParts = ALINES(laParts, JUSTSTEM(m.lcFile), .F., "_")
  llFound = .F.
  IF m.lnParts >= 3
    FOR ii = 2 + MOD(m.lnParts - 1, 2) TO m.lnParts - 1 STEP 2
      IF LOWER(laParts[m.ii]) == LOWER(m.lcParm)
        llFound = .T.
        EXIT
      ENDIF
    ENDFOR
  ENDIF
  IF m.llFound
    IF EMPTY(m.lvValue)
      ADEL(laParts, m.ii + 1)
      ADEL(laParts, m.ii)
      DIMENSION laParts[m.lnParts - 2]
    ELSE
      laParts[m.ii + 1] = TRANSFORM(m.lvValue)
    ENDIF
  ELSE  && not found
    IF EMPTY(m.lvValue)
    ELSE
      DIMENSION laParts[m.lnParts + 2]
      laParts[m.lnParts + 1] = m.lcParm
      laParts[m.lnParts + 2] = TRANSFORM(m.lvValue)
    ENDIF
  ENDIF
  lcNewFile = ""
  FOR ii = 1 TO ALEN(laParts)
    lcNewFile = m.lcNewFile + "_" + laParts[m.ii]
  ENDFOR
  lcNewFile = FORCEEXT(SUBSTR(m.lcNewFile, 2), JUSTEXT(m.lcFile))
  lcPath = STUFF(m.lcPath, AT(m.lcFile, m.lcPath), LEN(m.lcFile), m.lcNewFile)
  RETURN m.lcPath + m.lcQS
ENDFUNC  
* ------------------------------------------------ *
FUNCTION ReadUrlFileName(lcUrl, lcParm)
  LOCAL lcResult, lnAt, lcPath, lcFile, lnParts, ii, laParts[1]
  lnAt = AT("?", m.lcUrl)
  IF m.lnAt > 0
    lcPath = LEFT(m.lcUrl, m.lnAt - 1)
  ELSE
    lcPath = m.lcUrl
  ENDIF
  lnParts = ALINES(laParts, JUSTSTEM(m.lcPath), .F., "_")
  lcResult = ""
  IF m.lnParts >= 3
    FOR ii = 2 + MOD(m.lnParts - 1, 2) TO m.lnParts - 1 STEP 2
      IF LOWER(laParts[m.ii]) == LOWER(m.lcParm)
        lcResult = laParts[m.ii + 1]
        EXIT
      ENDIF
    ENDFOR
  ENDIF
  RETURN m.lcResult
ENDFUNC  
* ------------------------------------------------ *
FUNCTION StuffURL(tcUrl, ;
  	p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, ;
  	p13, p14, p15, p16, p17, p18, p19, p20, p21, p22, p23)

  * 07/24/1999
  *  - Modified numeric portion to deal with script-mapped file
  *    names.

  * 10/26/1998 
  *  - Revised to INSERT new setting close to beginning
  *    of URL to cause it to be seen in MSIE and WC status window.

  * Inserts a &param=value pair into an existing URL,
  * removing any prior param of same name.
  *
  *   - OR -
  *
  * Removes a &param=value pair (by sending a empty value).
  *
  *   - OR -
  *   
  * Replaces a numbered URL parameter with a different one:
  *
  * First approach is to allow replacement of a named query
  * string variable, such as for dynamic column ordering of
  * a table. 2nd parameter is character indicating name of parm.
  *
  * ?  StuffURL( "wc.dll?prg~mthd~&sub=02&order=id", "order", "duedate" )
  *
  * Result:  "wc.dll?prg~mthd~&sub=02&order=duedate"
  *
  * Second approach allows you to maintain all of the context of the 
  * application, but call a different page. Use 2 to change methods (pages
  * within same top-level app):
  *
  * ? StuffURL( "wc.dll?prg~Page1~&id=003&sys=02", 2, "Page2" )
  *
  * Result:  "wc.dll?prg~Page2~&id=003&sys=02"
  *
  * [You can force multiple translations in 1 call by stringing along extra
  *  parameter pairs. Mixing numeric/char methods is fine.]
  *
  LOCAL lcOut, lnAt1, lnAt2, lcStuff, lnParms, ii, ;
  	tuParm, tcValue, lcValueType, lnAnchor, lcLeadChar
  lnParms = PCOUNT()

  * First, fix up the URL so there is an anchor ? or tilde (~). If nothing comes after it
  * when we are done, we'll trim it off:
  IF NOT "?" $ m.tcUrl
  	tcUrl = m.tcUrl + "?"
  ELSE  && There is a "?" - check on need for tilde.
  	IF NOT "=" $ m.tcUrl
  		* There is no equal sign, thus no var=value settings. Given this, we need to 
  		* make sure there is a tilde that separates any numeric parameters before we add
  		* any named parameters.
  		IF NOT RIGHT( m.tcUrl, 1) $ '?~'
  			tcUrl = m.tcUrl + "~"
  		ENDIF
  	ENDIF && no "="
  ENDIF  && no "?"

  FOR ii = 1 TO INT( ( m.lnParms - 1)/ 2 )
  	* Repeat for each *pair* of parameters passed:
  	tuParm  = EVAL( "m.p" + LTRIM( STR( m.ii * 2 - 1)) )
  	tcValue = EVAL( "m.p" + LTRIM( STR( m.ii * 2 )) )

  	* 1999-11-11: Moved the TRANSFORM before the IF NOT EMPTY
  	* so that numeric 0 is included in URL rather than dropped.
  	* 1999-06-24:
  	* Mainly to allow Integers to be passed easily.
  	lcValueType = VARTYPE( m.tcValue )
  	DO CASE
  	CASE m.lcValueType $ "C"
  		* = .F.  && leave alone
  	CASE m.lcValueType = "L"
  		* .F. removes a parameter
  		tcValue = IIF( m.tcValue, "1", "")
  	OTHERWISE
  		tcValue = TRANSFORM( m.tcValue )
  	ENDCASE
  	IF NOT EMPTY( m.tcValue )
  		tcValue = URLEncode( m.tcValue )
  	ENDIF

  	IF VARTYPE( m.tuParm) = "C"
* --- "Named Parameter" -- 2nd parameter will be the "value".
      *
  		* (See ELSE code for Numbered Parameters.)
      
      * 01/06/2003 - added:
      *!* tuParm = URLEncode(m.tuParm)  && just in case
      * 05/21/2009 - removed above, because it encoded underscore in parm *name*, 
      *   which was incompatible with request.queryString!
  		
  		lcOut = ""
  		* Find the right-most tilde or question mark:
  		lnAnchor = MAX( RAT( "~", m.tcUrl), RAT( "?", m.tcUrl) )
  		
  		IF EMPTY( m.tcValue ) && no value -- we're removing the setting, if any
  			lcStuff = ""
  		ELSE  && value sent for named parameter
  			lcStuff = m.tuParm + '=' + m.tcValue
  			** [07/20/2000] lcStuff = '&' + m.tuParm + '=' + m.tcValue
  		ENDIF
  		
  		* Look for this variable in the current URL:
  		** lnAt1 = ATC( '&' + m.tuParm + '=', m.tcUrl)
  		IF NOT LOWER( m.tuParm) + "=" $ LOWER( m.tcUrl)
  			* No need to bother looking more closely.
  			lnAt1 = 0
  		ELSE && looks like we found it, need to verify it isn't a suffix of another name
  			lnAt1 = ATC( AMPERSAND_ENCODED + m.tuParm + '=', m.tcUrl)
  			IF m.lnAt1 = 0 && Not w/ leading "&" -- try ? and tilde.
  				lnAt1 = ATC( '?' + m.tuParm + '=', m.tcUrl)
  				IF m.lnAt1 = 0 
  					lnAt1 = ATC( '~' + m.tuParm + '=', m.tcUrl)
            lcLeadChar = '~'
          ELSE
            lcLeadChar = '?'
          ENDIF
        ELSE
          lcLeadChar = AMPERSAND_ENCODED  && Caution: This isn't single char any more--affects math further below!
  			ENDIF
  		ENDIF
  		
  		IF m.lnAt1 = 0  
  			* No parameter with this name was there before.
  			IF NOT EMPTY( m.tcValue )
  				* There's a value too, so we need to stuff it into the URL.
  				* We'll insert the new parameter FIRST so you see it
  				* near the beginning of the URL.
  				
  				* 02/26/2001: Inserted the "&":
  				lcOut = LEFT( m.tcUrl, m.lnAnchor) + AMPERSAND_ENCODED + m.lcStuff 
  				IF m.lnAnchor < LEN( m.tcUrl) && There was more to the right.
  					lcOut = m.lcOut + AMPERSAND_ENCODED + SUBSTR( m.tcUrl, m.lnAnchor + 1)
  				ENDIF
  				* 02/26/2001: Remove any double "&"'s:
  				lcOut = STRTRAN( m.lcOut, AMPERSAND_ENCODED + AMPERSAND_ENCODED, AMPERSAND_ENCODED )
  				
  *!*					lnAt2 = AT( '&', m.tcUrl)
  *!*					IF m.lnAt2 = 0  && No & parameters at all in the URL.
  *!*						lcOut = m.tcUrl + ;
  *!*							IIF( RIGHT( m.tcUrl, 1) = "~", "", "~") + m.lcStuff
  *!*					ELSE
  *!*						* We'll insert the new parameter FIRST so you see it
  *!*						* near the beginning of the URL.
  *!*						lcOut = STUFF( m.tcURL, m.lnAt2, 0, m.lcStuff )
  *!*					ENDIF
  			ELSE
  				* No value was passed, so there's nothing to do at all, since
  				* this parameter was not there before.
  				lcOut = m.tcUrl
  			ENDIF
  		ELSE  
  			* Parameter existed before, so we're either changing values
  			* or removing.
        
  			*!* 01/07/2003 - lcLeadChar is now calculated previously (above)
        *!* lcLeadChar = SUBSTR( m.tcUrl, m.lnAt1, 1)
        
  			* See if any other parameters exist to the right of this one:
        lnAt2 = AT( AMPERSAND_ENCODED, SUBSTR( m.tcUrl, m.lnAt1 + 1))
        
        * Caution! 4 different combinations are covered in nested IF's below:
  			IF m.lnAt2 = 0  && No further parmeters to the right in URL.
  				IF EMPTY( m.lcStuff)
            * Removing this parameter (and there's nothing else to the right):
  					lcOut = LEFT( m.tcUrl, m.lnAt1 - 1) + IIF( m.lcLeadChar $ '?~', m.lcLeadChar, '')
  				ELSE
            * Changing value of this parameter (and there's nothing else to the right):
  					lcOut = LEFT( m.tcUrl, m.lnAt1 - 1) + m.lcLeadChar + m.lcStuff
  				ENDIF
  			ELSE && Further parameters to the right of this one.
  				IF EMPTY( m.lcStuff)
            * Removing this parameter (but there's something else to the right):
            IF m.lcLeadChar = AMPERSAND_ENCODED
    					lcOut = LEFT( m.tcUrl, m.lnAt1 - 1) + ;
                SUBSTR( m.tcUrl, m.lnAt2 + m.lnAt1 )
            ELSE 
              ** lcOut = LEFT( m.tcUrl, m.lnAt1 + 1) + ;
              **   SUBSTR( m.tcUrl, m.lnAt2 + m.lnAt1 + 1)
              **
              ** 09/05/2005, replaced above with:
              lcOut = LEFT( m.tcUrl, m.lnAt1 - 1 + LEN(m.lcLeadChar)) + ;
                 SUBSTR( m.tcUrl, m.lnAt2 + m.lnAt1)
            ENDIF
  				ELSE
            * Changing value of this parameter (and there's something else to the right):
  					lcOut = LEFT( m.tcUrl, m.lnAt1 - 1 + LEN(m.lcLeadChar)) + m.lcStuff + ;
              SUBSTR( m.tcUrl, m.lnAt2 + m.lnAt1)
  				ENDIF
  			ENDIF
  		ENDIF
      * remove extra ampersand if now at start:
      lcOut = STRTRAN(m.lcOut, "?" + AMPERSAND_ENCODED, "?")

  	ELSE
* --- Numbered (positional) URL Parameter:
  		IF NOT ".exe" $ LOWER( m.tcUrl) AND NOT ".dll" $ LOWER( m.tcUrl )
  			* It's a script-mapped extension, so the 1 and 2 parameters
  			* are actually part of the "file" name, separated by underscores.
  			DO CASE

  			* 09/04/2001
  			*  - Change from underscore syntax to filename+extension syntax.
  			*  - First two CASEs reflect this change.
  			CASE m.tuParm = 1
  				* 1st parameter *is* the extension
  				lnAt1 = AT( ".", m.tcUrl)
  				lnAt2 = AT( "?", m.tcUrl )
  			CASE m.tuParm = 2
  				* 2nd parameter *is* the filename stem
  				lnAt1 = RAT( "/", m.tcUrl)
  				lnAt2 = AT( ".", m.tcUrl)
  				
  			CASE m.tuParm = 3
  				* 3rd parameter is after the ? and before the first ~.
  				lnAt1 = AT( "?", m.tcUrl )
  				lnAt2 = AT( "~", m.tcUrl )
  			OTHERWISE
  				* All additional parms are between 2 tildes.
  				lnAt1 = AT( "~", m.tcUrl, m.tuParm - 3)
  				lnAt2 = AT( "~", m.tcUrl, m.tuParm - 2)
  			ENDCASE

  			DO CASE
  			CASE m.lnAt1 > 0 AND m.lnAt2 > lnAt1  && Normal URL.
  				lcOut = STUFF( m.tcUrl, m.lnAt1 + 1, ;
  					m.lnAt2 - m.lnAt1 - 1, m.tcValue )
  			CASE m.lnAt1 > 0  && No subsequent parameter.
  				lcOut = LEFT( m.tcUrl, m.lnAt1) + m.tcValue
  			OTHERWISE && No parameter there yet.
  				lcOut = m.tcUrl + IIF( m.tuParm = 1, "?", "~") + m.tcValue
  			ENDCASE

  		ELSE
  			IF m.tuParm = 1
  				* 1st parameter starts after ? in URL.
  				lnAt1 = AT( "?", m.tcUrl )
  				lnAt2 = AT( "~", m.tcUrl )
  			ELSE
  				lnAt1 = AT( "~", m.tcUrl, m.tuParm - 1)
  				lnAt2 = AT( "~", m.tcUrl, m.tuParm )
  			ENDIF
  		
  			DO CASE
  			CASE m.lnAt1 > 0 AND m.lnAt2 > lnAt1  && Normal URL.
  				lcOut = STUFF( m.tcUrl, m.lnAt1 + 1, ;
  					m.lnAt2 - m.lnAt1 - 1, m.tcValue )
  			CASE m.lnAt1 > 0  && No subsequent parameter.
  				lcOut = LEFT( m.tcUrl, m.lnAt1) + m.tcValue
  			OTHERWISE && No parameter there yet.
  				lcOut = m.tcUrl + IIF( m.tuParm = 1, "?", "~") + m.tcValue
  			ENDCASE
  		ENDIF
  	ENDIF
  *!*		IF RIGHT( m.lcOut, 1) = "~"
  *!*			lcOut = LEFT( m.lcOut, LEN( m.lcOut) - 1)
  *!*		ENDIF
  	tcUrl = m.lcOut
  ENDFOR

  * Remove trailing ? or ~, if any:
  IF RIGHT( m.tcUrl, 1) $ '?~'
  	tcUrl = LEFT( m.tcUrl, LEN( m.tcUrl) - 1)
  ENDIF

  * Check for special flag to remove &amp; encoding (not typical):
  IF MOD(m.lnParms, 2) = 0
    LOCAL llFinalParm
    llFinalParm = EVAL("m.p" + TRANSFORM(m.lnParms - 1))
    IF VARTYPE(llFinalParm) = "L" AND m.llFinalParm  && flag to squash amp-encoding (for request-side processing)
      tcUrl = STRTRAN(m.tcUrl, AMPERSAND_ENCODED, "&")
    ENDIF
  ENDIF
  
  RETURN m.tcUrl
ENDFUNC  && StuffURL
* ------------------------------------------------ *
FUNCTION L7Nullify
  * Completely blanks the current record in the current work area.
  PRIVATE ALL
  IF EMPTY( ALIAS()) OR BOF() OR EOF() OR RECNO() = 0
  	RETURN .F.
  ELSE
  	IF LOCK()
  		SCATTER MEMVAR MEMO BLANK
  		GATHER MEMVAR MEMO
  		UNLOCK
  	ELSE
  		RETURN .F.
  	ENDIF
  ENDIF
  RETURN 
ENDFUNC  
* --------------------------------------------------------- *
FUNCTION GMTTime(ltTime, lnOffset)
  IF VARTYPE( m.ltTime) <> "T"
  	IF VARTYPE( m.ltTime) = "D"
  		ltTime = DTOT( m.ltTime)
  	ELSE
  		ltTime = DATETIME()
  	ENDIF
  ENDIF
  IF VARTYPE( m.lnOffset) <> "N"
  	lnOffset = GetTimeZoneOffset()  && In API lib.
  ENDIF
  LOCAL ltGmtTime, lcStr
  ltGmtTime = m.ltTime + 60 * m.lnOffset
  lcStr = LEFT( CDOW( m.ltGmtTime), 3) + ", " + ;
  	PADL( LTRIM( STR( DAY( m.ltGmtTime))), 2, "0") + "-" + ;
  	LEFT( CMONTH( m.ltGmtTime), 3) + "-" + ;
  	STR( YEAR( m.ltGmtTime), 4) + " " + ;
  	PADL( LTRIM( STR( HOUR( m.ltGmtTime))), 2, "0") + ":" + ;
  	PADL( LTRIM( STR( MINUTE( m.ltGmtTime))), 2, "0") + ":" + ;
  	PADL( LTRIM( STR( SEC( m.ltGmtTime))), 2, "0") + " GMT"
  RETURN m.lcStr
ENDFUNC  && GMTTime
* ------------------------------------------------------------------- *
FUNCTION Mil_Time(pc_time)
  RETURN TYPE("m.pc_time") = "C" AND ;
  	LEN(m.pc_time) = 4 AND ;
  	BETWEEN(LEFT(m.pc_time, 1), "0", "2") AND ;
  	BETWEEN(SUBSTR(m.pc_time, 2, 1), "0", "9") AND ;
  	BETWEEN(SUBSTR(m.pc_time, 3, 1), "0", "5") AND ;
  	BETWEEN(RIGHT(m.pc_time, 1), "0", "9") AND ;
  	BETWEEN(m.pc_time, "0000", "2359")
ENDFUNC  && Mil_Time
* ------------------------------------------------------------------- *
FUNCTION OpenIfNot( lcTable, lcAlias, lcOrder, lcPath )
  lcAlias = IIF( EMPTY( m.lcAlias), m.lcTable, m.lcAlias )
  IF NOT USED( m.lcAlias)
    IF NOT EMPTY( m.lcPath )
    	USE ( ADDBS( m.lcPath ) + m.lcTable ) AGAIN ALIAS ( m.lcAlias) IN 0
    ELSE
      USE ( m.lcTable ) AGAIN ALIAS ( m.lcAlias) IN 0
    ENDIF
  ENDIF
  IF NOT EMPTY( m.lcOrder )
  	* Call this separately for performance reasons:
  	SET ORDER TO ( m.lcOrder ) IN ( m.lcAlias )
  ENDIF
  RETURN
ENDFUNC && OpenIfNot
* ------------------------------------------------------------------- *
FUNCTION CloseIfOpen( tcAlias)
	USE IN SELECT( m.tcAlias)
ENDFUNC  && CloseIfOpen
* ------------------------------------------------------------------- *
FUNCTION L7Left(tcText, toObj)
  LOCAL lcRet, lnKey, lvVal, lnLen
  lcRet = m.tcText
  lnLen = LEN(m.tcText)
  WITH toObj
    lnKey = .GetKey("Paragraphs")
    IF m.lnKey > 0
      lvVal = .Item("Paragraphs")
      lnAt = AT(CRLF, m.lcRet, m.lvVal)
      IF m.lnAt > 0
        lcRet = LEFT(m.lcRet, m.lnAt + LEN(CRLF) - 1)
      ENDIF 
    ENDIF       
    lnKey = .GetKey("Characters")
    IF m.lnKey > 0 
      lvVal = .Item("Characters")
      IF m.lvVal < LEN(m.lcRet)
        lnAt = AT(CRLF, m.lcRet, .Item("Paragraphs"))
        lcRet = LEFT(m.lcRet, m.lvVal)
      ENDIF 
    ENDIF       
    IF LEN(m.lcRet) < m.lnLen
      lcRet = m.lcRet + EVL(.Item("MoreText"), " [More...]")
    ENDIF 
  ENDWITH 
  tcText = m.lcRet  && support pass-by-ref
  RETURN m.lcRet
ENDFUNC 
* ------------------------------------------------------------------- *
FUNCTION AllTrimX( lcString)
  * Take out unwanted characters at beginning and end of string.
  * Can also pass by reference.

  * NOTE: doesn't remove leading/trailing non-breaking space, CHR(160); should it?
  IF EMPTY(m.lcString) OR VARTYPE( m.lcString) <> "C"
    lcString = ""
  ELSE
    LOCAL lcBad
    lcBad = CHR(10) + CHR(13) + CHR(9) + CHR(160)
    DO WHILE .T.
    	* First a normal trim. This is done inside the loop,
      * so when we remove a CR, we then also remove further
      * embedded spaces, etc:
    	lcString = ALLTRIM( m.lcString)
    	DO CASE
    	CASE EMPTY( m.lcString)
    		EXIT
    	CASE RIGHT( m.lcString, 1) $ m.lcBad
    		lcString = LEFT( m.lcString, LEN( m.lcString) - 1)
    	CASE LEFT( m.lcString, 1) $ m.lcBad
    		lcString = SUBSTR( m.lcString, 2)	
    	OTHERWISE
    		EXIT
    	ENDCASE
    ENDDO
  ENDIF
  RETURN m.lcString
ENDFUNC  && AllTrimX
* ------------------------------------------------------------------- *
FUNCTION DecimalPlaces(lnVal)
  * Number of decimal places (precision) of a numeric value.
  LOCAL lcVal, lnAT, lnDecs
  lcVal = TRIM(PADR(m.lnVal, 40))
  lnDecs = 0
  lnAT = AT(SET("POINT"), m.lcVal)
  IF m.lnAT > 0
    lnDecs = LEN(SUBSTR(m.lcVal, m.lnAT + 1))
  ENDIF
  RETURN m.lnDecs
ENDFUNC && DecimalPlaces(lnVal)
* ------------------------------------------------------------------- *
FUNCTION DelimitX
  *
  * Delimit list with commas (or specified string).
  *
  * Pass parameter by reference to modify.
  * Example call: = DelimitX(@m.EditUsers))
  * Always returns .T. (so it can be a valid expression).

  PARAMETER pcString, pcDelStr, plNoUpper, plNoTrim, pnFixedLen

  * Record original length.
  PRIVATE lnOrigLen
  lnOrigLen = LEN( m.pcString)

  * Set delimiter string.
  PRIVATE lcDelStr
  IF TYPE( "m.pcDelStr") = "C"
  	lcDelStr = m.pcDelStr
  ELSE
  	* default
  	lcDelStr = ","
  ENDIF

  * Convert to upper case, if appropriate.
  IF NOT m.plNoUpper
  	* conversion is the default
  	pcString = UPPER( m.pcString)
  ENDIF

  * Take any TAB, SPACE, CR-LF or semi-colon and convert
  * to desired character.
  pcString = ;
  	STRTRAN( ;
  	STRTRAN( ;
  	STRTRAN( ;
  	STRTRAN( ;
  		m.pcString, ;
  		",", m.lcDelStr), ;
  		SPACE(1), m.lcDelStr), ;
  		CHR(13) + CHR(10), m.lcDelStr), ;
  		CHR(59), m.lcDelStr)

  * Put one in front and back to allow EXACT to be OFF
  * when looking for membership.
  pcString = m.lcDelStr + m.pcString + m.lcDelStr

  * Eliminate redundancies.
  DO WHILE REPL( m.lcDelStr, 2) $ m.pcString
  	pcString = STRTRAN( m.pcString, ;
  		REPL( m.lcDelStr, 2), m.lcDelStr )
  ENDDO

  * If not to be trimmed, re-PAD with spaces (this
  * handles character fields vs. memo fields).
  IF m.plNoTrim
  	pcString = PADR( m.pcString, m.lnOrigLen)
  ENDIF

  RETURN .T.
ENDFUNC  && DelimitX
* ------------------------------------------------------------------- *
FUNCTION Case
  * Simulate R&R's CASE() function.
  * * Note: VFP now has ICASE() as well.
  LPARAMETERS p_1, p_2, p_3, p_4, p_5,	p_6, p_7, p_8, p_9, ;
  	p_10, p_11, p_12, p_13, p_14, p_15, p_16, p_17, ;
  	p_18, p_19, p_20, p_21,	p_22, p_23, p_24
  * NOTE: 24 is maximum PARAMETERS in Visual FoxPro.

  LOCAL ln_parms, ln_cases, ii, lc_temp, lx_result, lc_type, lnMaxPass
  * NOTE: 'lx_" is used for result variable because type is unknown.
  ln_parms = PCOUNT()
  ln_cases = INT((m.ln_parms - 2) / 2)
  IF m.ln_cases # (m.ln_parms - 2) / 2
  	ERROR "FUNCTION Case: # of parameters must be even."
  	RETURN ""
  ENDIF
  lnMaxPass = 11  && maybe VFP 23 will increase param count?
  
  IF NOT BETWEEN(m.ln_parms, 4, 2 + 2 * m.lnMaxPass)
  	* Too few (presumably FP would issue error
  	* first if too many. [Check this.]
  	ERROR "FUNCTION Case: At least 4 parameters required."
  	RETURN ""
  ENDIF

  lc_type = TYPE("m.p_1")

  IF NOT m.lc_type $ "CDNFL"
  	ERROR "FUNCTION Case: Invalid parameter type."
  	RETURN ""
  ENDIF

  * Assign 'default' (last parameter) 
  * to result variable:
  lc_temp = 'p_' + LTRIM(STR(m.ln_parms))
  * e.g., 'p_12'
  lx_result = &lc_temp

  FOR ii = 1 TO m.ln_cases
  	lc_temp = 'p_' + LTRIM(STR(2 * m.ii))
  	IF p_1 = &lc_temp
  		* Match found - assign value to result
  		* and stop checking further:
  		lc_temp = 'p_' + LTRIM(STR(1 + 2 * m.ii))
  		lx_result = &lc_temp
  		* Quit evaluating more cases:
  		EXIT
  	ENDIF
  ENDFOR

  RETURN m.lx_result
ENDFUNC && Case
* ------------------------------------------------------------------- *
FUNCTION L7RandomChoice(p_1, p_2, p_3, p_4, p_5, p_6, p_7, p_8, p_9, ;
    p_10, p_11, p_12, p_13, p_14, p_15, p_16, p_17, ;
    p_18, p_19, p_20, p_21,  p_22, p_23, p_24)
  * Call L7RandomSeed() first yourself if you need to.
  LOCAL ii, lnCount, llCharMode
  lnCount = PCOUNT()
  IF m.lnCount = 1
    llCharMode = .T.
    lnCount = LEN( m.p_1 )
  ENDIF
  ii = 1 + FLOOR( m.lnCount * RAND())
  IF m.llCharMode
    RETURN SUBSTR( m.p_1, m.ii, 1)
  ELSE
    RETURN EVAL( "m.p_" + LTRIM(STR(m.ii)))
  ENDIF
ENDFUNC  
* ------------------------------------------------------------------- *
FUNCTION L7RandomSeed
  RAND(-1)
  RETURN 
ENDFUNC
* ------------------------------------------------------------------- *
FUNCTION L7RandomPassword(lcTxt, lnMinLen)
  * Returns unencrypted random password for adding to a new account.
  LOCAL lcChars, lcColors, lcStructures, lcAnimals, lcAdjectives
  lcAdjectives = ["large","small","good","cold","fast","slow","quick","able"]
  lcColors = ["purple","orange","brown","gray","green","blue","yellow","aqua","teal","gold","silver"]
  lcAnimals = ["cat","dog","horse","bear","tiger","bird","bear","pony","goat","steer","rabbit"]
  lcStructures = ["house","auto","roof","wall","truck","barge","shed","barn","store","beach"]
  lcChars = [!@#$%?*]
  lcTxt = EVL(m.lcTxt, 'colordigitstructure')
  lnMinLen = EVL(m.lnMinLen, 8)
  
  L7RandomSeed()
  TRY
    DO WHILE .T.
      DO CASE
      CASE "color" $ m.lcTxt
        lcTxt = STUFF(m.lcTxt, AT("color", m.lcTxt), 5, L7RandomChoice(&lcColors))
      CASE "adjective" $ m.lcTxt
        lcTxt = STUFF(m.lcTxt, AT("adjective", m.lcTxt), 9, L7RandomChoice(&lcAdjectives))
      CASE "animal" $ m.lcTxt
        lcTxt = STUFF(m.lcTxt, AT("animal", m.lcTxt), 6, PROPER(L7RandomChoice(&lcAnimals)))
      CASE "structure" $ m.lcTxt
        lcTxt = STUFF(m.lcTxt, AT("structure", m.lcTxt), 9, PROPER(L7RandomChoice(&lcStructures)))
      CASE "digit" $ m.lcTxt
        lcTxt = STUFF(m.lcTxt, AT("digit", m.lcTxt), 5, STR(FLOOR(10 * RAND()), 1, 0))
      CASE "char" $ m.lcTxt  && special char
        lcTxt = STUFF(m.lcTxt, AT("char", m.lcTxt), 4, SUBSTR(m.lcChars, 1 + INT(RAND() * LEN(m.lcChars)), 1))
      OTHERWISE
        EXIT
      ENDCASE
    ENDDO
    DO WHILE LEN(m.lcTxt) < m.lnMinLen  && pad with digits if needed
      lcTxt = m.lcTxt + STR(FLOOR(10 * RAND()), 1, 0)
    ENDDO
  CATCH TO loExc
    * do nothing - just let unaltered string go back
  ENDTRY
  
  RETURN m.lcTxt
ENDFUNC  && L7RandomPassword
* ------------------------------------------------------------------- *
FUNCTION L7EnCode
  para t,s,u
  priv l,r,k,i,j,n,m
  if set("TALK")=="ON"
  set talk off
  k=.t.
  else
  k=.f.
  endi
  n=pcount()
  if n>=3
  m=len(u)
  else
  m=0
  endi
  l=len(s)
  j=asc(left(s,1))
  r=chr(255-j)
  if t=2
  j=asc(r)
  endi
  for i=2 to l
  if t=1
  r=r+chr(mod((5*j)+(asc(subs(r,i-1,1)))+(asc(subs(s,i,1)))+(iif(m=0,0,asc(subs(u,1+mod(i,m),1)))),256))
  j=j+i+asc(righ(r,1))
  else
  r=r+chr(mod(asc(subs(s,i,1))-5*j-asc(subs(s,i-1,1))-iif(m=0,0,asc(subs(u,1+mod(i,m),1))),256))
  j=j+i+asc(subs(s,i,1))
  endi
  endf
  if k
  set talk on
  endi
  retu r
ENDFUNC

* ------------------------------------------------------------------- *
FUNCTION HowMany
  * Determine how many records match specified conditions.
  *
  * Created 01/01/1993 by Randy Pearson, CYCLA Corp.
  *
  * Syntax: [<expN>] = How_Many(<alias>, <expC>)
  *
  *   NOTE: <expC> must evaluate to logical when macro expanded.
  *
  PARAMETERS pc_alias, pc_expr
  *
  PRIVATE lcAlias, lnAt
  lnAt = RAT( "\", m.pc_alias)
  IF m.lnAt = 0
  	* no path - just table
  	lcAlias = m.pc_alias
  ELSE
  	lcAlias = SUBSTR( m.pc_alias, m.lnAt + 1)
  ENDIF

  PRIVATE ll_open, la_count, lc_fld_1, ln_select, ln_recno
  * PRIVATE ll_open, la_count

  * Following statement added:
  ln_select = SELECT()
  ln_recno = RECNO()

  ll_open = USED( m.lcAlias)

  * This whole IF...ENDIF added:
  IF NOT m.ll_open
  	SELECT 0
  	USE ( m.pc_alias) AGAIN ALIAS ( m.lcAlias)
  ELSE
  	SELECT ( m.lcAlias)
  ENDIF

  * This statement added.
  * Get something to select:
  lc_fld_1 = FIELD(1)

  SELECT &lc_fld_1 ;
  	FROM ( m.pc_alias) ;
  	WHERE &pc_expr ;
  	INTO ARRAY la_count
  	
  *	SELECT COUNT(*) ;
  *		FROM (m.pc_alias) ;
  *		WHERE &pc_expr ;
  *		INTO ARRAY la_count

  IF NOT m.ll_open
  	USE IN ( m.lcAlias)
  ENDIF

  * This added:
  SELECT ( m.ln_select)

  IF BETWEEN( m.ln_recno, 1, RECCOUNT()) AND ;
  	RECNO() <> m.ln_recno
  	*
  	* SQL bug caused record movement!
  	GOTO m.ln_recno
  ENDIF

  RETURN IIF(TYPE("la_count[1]") = "U", ;
  	0, ALEN(la_count, 1))
ENDFUNC  && HowMany

* ------------------------------------------------ *
FUNCTION DeQuote
  * Remove quote delimiters from character string.
  LPARAMETERS str_data
  IF TYPE( 'm.str_data') <> 'C'
  	RETURN m.str_data
  ENDIF
  LOCAL ii
  str_data=ALLTRIM(m.str_data)
  ii=LEN(m.str_data)-2
  IF LEFT(m.str_data,1)=='"' AND RIGHT(m.str_data,1)=='"'
    RETURN SUBSTR(m.str_data,2,m.ii)
  ENDIF
  IF LEFT(m.str_data,1)=="'" AND RIGHT(m.str_data,1)=="'"
    RETURN SUBSTR(m.str_data,2,m.ii)
  ENDIF
  IF LEFT(m.str_data,1)=='[' AND RIGHT(m.str_data,1)==']'
    RETURN SUBSTR(m.str_data,2,m.ii)
  ENDIF
  RETURN m.str_data
ENDFUNC  &&DeQuote

* --------------------------------------------------------- *
FUNCTION GIFSize( pcFileName, pnWidth, pnHeight )
  * Returns the size WxH of a GIF file.
  * by Thomas Gehrke
  *
  * EXAMPLE 1:
  * 
  * ? GIFSize( "C:\IMAGES\Test.GIF")
  * 
  * Returns: "320x200"
  *
  * Pass optional numeric 2nd and 3rd parameters BY REFERENCE
  * to receive separate values into variables.
  *
  * EXAMPLE 2:
  * 
  * LOCAL lnWidth, lnHeight
  * STORE 0 TO lnWidth, lnHeight
  * = GIFSize( "C:\IMAGES\Test.GIF", @lnWidth, @lnHeight)
  * 
  IF EMPTY( m.pcFileName)
  	pcFileName = GETFILE( "GIF", "Select GIF File:", "Get Size")
  ENDIF

  IF EMPTY( m.pcFileName)
  	RETURN ""
  ENDIF

  PRIVATE lnHandle, lcRetStr
  lnHandle = FOPEN( m.pcFileName)
  lcRetStr = ""

  IF m.lnHandle > -1

  	PRIVATE lnFileSize, lnCounter, lcBytes
  	lnFileSize = FSEEK( m.lnHandle, 0, 2)
  	lnCounter  = 0
  	
  	IF m.lnFileSize >= 10
  		= FSEEK( m.lnHandle, 0, 0)

  		* Read the 1st 10 bytes:
  		lcBytes = FREAD( m.lnHandle, 10)
  	
  		= FCLOSE( m.lnHandle)
  	
  		pnWidth  = ASC( SUBSTR( m.lcBytes, 8, 1)) * 256 + ;
  			ASC( SUBSTR( m.lcBytes, 7, 1))
  	
  		pnHeight = ASC( SUBSTR( m.lcBytes, 10, 1)) * 256 + ;
  			ASC( SUBSTR( m.lcBytes, 9, 1))

  		lcRetStr = LTRIM( STR( m.pnWidth)) + "x" + LTRIM( STR( m.pnHeight))
  	ENDIF
  ELSE
  	pnWidth = 0
  	pnHeight = 0
  	lcRetStr = ""
  ENDIF

  RETURN m.lcRetStr
ENDFUNC  && GIFSize

* --------------------------------------------------------- *
FUNCTION JPGSize( pcFileName, pnWidth, pnHeight )
  * Returns the size WxH of a JPG file.
  * by Thomas Gehrke
  *
  * See Comments to function GIFSize() for usage notes.
  *
  IF EMPTY( m.pcFileName)
  	pcFileName = GETFILE( "JPG", "Select JPG File:", "Get Size")
  ENDIF

  IF EMPTY( m.pcFileName)
  	RETURN ""
  ENDIF

  PRIVATE lnHandle, lcRetStr
  lnHandle = FOPEN( m.pcFileName)
  lcRetStr = ""

  IF m.lnHandle > -1

  	PRIVATE lnFileSize, lnCounter, lcBytes
  	lnFileSize = FSEEK( m.lnHandle, 0, 2)
  	lnCounter  = 0
  	
  	= FSEEK( m.lnHandle, 0, 0)

  	FOR lnCounter = 1 TO m.lnFileSize - 2
  		lcBytes = FREAD( m.lnHandle, 3)

  		IF m.lcBytes = CHR(0) + CHR(17) + CHR(8) OR ;
  			m.lcBytes = CHR(0) + CHR(11) + CHR(8)
  			*
  			* Found block marker for dimensions!
  			lcBytes = FREAD( m.lnHandle, 4)
  			EXIT			
  		ELSE
  			= FSEEK( m.lnHandle, -2, 1)
  		ENDIF
  	ENDFOR
  	
  	= FCLOSE( m.lnHandle)
  	
  	pnWidth  = ASC( SUBSTR( m.lcBytes, 3, 1)) * 256 + ;
  		ASC( SUBSTR( m.lcBytes, 4, 1))
  	
  	pnHeight = ASC( SUBSTR( m.lcBytes, 1, 1)) * 256 + ;
  		ASC( SUBSTR( m.lcBytes, 2, 1))

  	lcRetStr = LTRIM( STR( m.pnWidth)) + "x" + LTRIM( STR( m.pnHeight))

  ELSE
  	pnWidth = 0
  	pnHeight = 0
  	lcRetStr = ""
  ENDIF

  RETURN m.lcRetStr
ENDFUNC  && JPGSize

*--------------------------------------------------------------------*
FUNCTION IPv4PAD(tcIP, tcChr)  && format IPv4 addresses into sortable, aligned format C(15) 
	LOCAL lcChr, ii, lcIp, lcWord
	lcChr = EVL(m.tcChr, " ")
	lcIp = ""
	FOR ii = 1 TO 4
		lcIp = m.lcIp + "." + PADL(ALLTRIM(GETWORDNUM(m.tcIp, m.ii, ".")), 3, m.lcChr)
	ENDFOR 
	RETURN SUBSTR(m.lcIp, 2)
ENDFUNC 
*--------------------------------------------------------------------*
FUNCTION IP2Long(tcIP)  
  LOCAL lnIP, ii, lcWord, lnVal
  lnIP = 0
  IF GETWORDCOUNT(m.tcIP, ".") = 4
    FOR ii = 1 TO 4
      lcWord = GETWORDNUM(m.tcIP, m.ii, ".")
      lnVal = VAL(m.lcWord)
      IF NOT BETWEEN(m.lnVal, 0, 255)
        lnIP = 0
        EXIT
      ENDIF 
      lnIP = m.lnIP + (m.lnVal * 256 ^ (4 - m.ii))
    ENDFOR 
  ENDIF 
  RETURN m.lnIP
ENDFUNC 
*--------------------------------------------------------------------*
FUNCTION Long2IP(tnLong)  
  LOCAL lcIP, ii, lnFactor
  lcIP = ""
  IF BETWEEN(m.tnLong, 0, 256 ^ 4 - 1)  && fix this
    lnCurr = m.tnLong
    FOR ii = 3 TO 1 STEP -1
      lnFactor = 256 ^ m.ii
      lnTemp = INT(m.lnCurr / m.lnFactor)
      lnCurr = MOD(m.lnCurr, m.lnFactor)
      lcIP = m.lcIp + TRANSFORM(m.lnTemp) + "."
    ENDFOR 
    lcIP = m.lcIp + TRANSFORM(m.lnCurr) 
  ENDIF 
  RETURN m.lcIp
ENDFUNC 

*--------------------------------------------------------------------*
FUNCTION Ip2CountryParseCSV(tlFill)
  * For ip-to-country.csv downloaded from http://ip-to-country.webhosting.info
  * Creates 2 DBFs: ip-to-country.dbf and ip-to-country_countries.dbf
  LOCAL lcCsv, lcTbl1, lcTbl2
  lcCsv = GETFILE("CSV", "Locate Ip-To-Country CSV File", "Parse")
  CREATE CURSOR Ip2Country (FromStr C(12), ToStr C(12), FromInt N(10,0), ToInt N(10,0), FromIP C(15), ToIP C(15), Country2 C(2), Country3 C(3), Country C(48))
  APPEND FIELDS FromStr, ToStr, Country2, Country3, Country ;
    FROM (m.lcCsv) type CSV
  IF m.tlFill
    REPLACE ALL ;
      FromInt WITH VAL(FromStr) ;
      ToInt WITH VAL(ToStr) ;
      FromIp WITH Long2IP(VAL(FromStr)) ;
      ToIp WITH Long2IP(VAL(ToStr))
  ENDIF 
  * patch for missing country codes in last available version:
  SCAN FOR EMPTY(Country)
    DO case
    CASE Country2 = 'AX'
      replace Country3 WITH "???", Country WITH "ÅLAND ISLANDS"
    CASE Country2 = 'IM'
      replace Country3 WITH "???", Country WITH "ISLE OF MAN"
    CASE Country2 = 'JE'
      replace Country3 WITH "???", Country WITH "JERSEY"
    CASE Country2 = 'ME'
      replace Country3 WITH "MNE", Country WITH "MONTENEGRO"
    CASE Country2 = 'MF'
      replace Country3 WITH "???", Country WITH "SAINT MARTIN"
    CASE Country2 = 'RS'
      replace Country3 WITH "SRB", Country WITH "SERBIA"
    OTHERWISE && avoid blanks by using 2-letter code
      replace Country3 WITH "???", Country WITH Country2
    ENDCASE 
  ENDSCAN 
  * Create main table:
  lcTbl1 = ["] + FORCEEXT(m.lcCsv, "DBF") + ["]
  lcTbl2 = STUFF(m.lcTbl1, AT(".DBF", UPPER(m.lcTbl1)), 0, "_Countries")
  COPY TO (lcTbl1)
  USE (FORCEEXT(m.lcCsv, "DBF")) EXCLUSIVE
  * Performance indexes:
  INDEX ON FromInt TAG FromInt
  INDEX ON ToInt TAG ToInt
  * Create unique country table:
  SELECT DISTINCT Country2, Country3, Country ;
    FROM &lcTbl1 ;
    INTO TABLE &lcTbl2
  USE
  
  RETURN 
ENDFUNC  && Ip2CountryParseCSV
*--------------------------------------------------------------------*
FUNCTION IsPrivateIp(tcIP)
  return m.tcIp = "::1" or ;
    LIKE([127*], m.tcIp) or ; && LOCALHOST
    LIKE([192.168.*], m.tcIp) or ; 
    LIKE([172.16.*], m.tcIp) or ; 
    LIKE([10.*], m.tcIp) 
endfunc && IsPrivateIP
*--------------------------------------------------------------------*
FUNCTION Ip2Country(tcIP, tcAlias)
  LOCAL lnInt, lcRet, lnSelect, loExc
  lcRet = ""
  DO CASE 
  CASE LIKE([127*], m.tcIp) or m.tcIp = "::1"
    lcRet = "N/A - LOCALHOST!"
  CASE LIKE([192.168.*], m.tcIp) 
    lcRet = "N/A - private 192.168.0.0 network!"
  CASE LIKE([172.16.*], m.tcIp) 
    lcRet = "N/A - private 172.16.0.0 network!"
  CASE LIKE([10.*], m.tcIp) 
    lcRet = "N/A - private 10.0.0.0 network!"
  CASE NOT EMPTY(m.tcAlias) && pre-opened table, for use in loops for performance
    lnSelect = SELECT()
    lnInt = IP2Long(m.tcIP)
    TRY
    	SELECT (m.tcAlias)
    	LOCATE FOR FromInt <= m.lnInt AND ToInt >= m.lnInt
      IF FOUND()
        lcRet = TRIM(Country)
      ELSE
        lcRet = [IP RANGE NOT FOUND!]
      ENDIF 
    CATCH TO loExc
      lcRet = loExc.Message + "!"
    FINALLY
	    SELECT (m.lnSelect)
    ENDTRY 
  	
  OTHERWISE 
    lnSelect = SELECT()
    lnInt = IP2Long(m.tcIP)
    TRY
      SELECT Country2, Country3, Country ;
        FROM "Ip-To-Country" ;
        WHERE FromInt <= m.lnInt AND ToInt >= m.lnInt ;
        INTO CURSOR Ip2Country_Query_
        
      IF _TALLY = 1
        lcRet = TRIM(Country)
      ELSE
        lcRet = [IP RANGE NOT FOUND!]
      ENDIF 
    CATCH TO loExc
      lcRet = loExc.Message + "!"
    FINALLY
	    SELECT (m.lnSelect)
    ENDTRY 
  ENDCASE 
  RETURN m.lcRet
ENDFUNC  && Ip2Country

* ------------------------------------------------------------------- *
FUNCTION IpToNumber(lcIp)
  * Translate IP address to numeric value using standard formula.
  LOCAL laPieces[1], lnPieces, lnRet
  lnRet = 0
  TRY
    lnPieces = ALINES(laPieces, m.lcIp, .T., ".")
    IF m.lnPieces = 4
      lnRet = INT(VAL(laPieces[4]) + 256 * VAL(laPieces[3]) + ;
        256 ^ 2 * VAL(laPieces[2]) + 256 ^ 3 * VAL(laPieces[1]))
    ENDIF
  CATCH
    lnRet = 0
  ENDTRY
  RETURN m.lnRet
ENDFUNC  && IpToNumber

* ------------------------------------------------------------------- *
FUNCTION NumberToIp(tnNum)
  * Reverse of IpToNumber().
  LOCAL lcRet, ii, lnNum, lnMod
  lcRet = ""
  lnNum = m.tnNum
  FOR ii = 1 TO 4
    IF m.ii < 4
      lnMod = m.lnNum % 256
      lcRet = "." + LTRIM(STR(m.lnMod)) + m.lcRet
      lnNum = INT(m.lnNum / 256)
    ELSE
      lcRet = LTRIM(STR(m.lnNum)) + m.lcRet
    ENDIF
  ENDFOR
  RETURN m.lcRet
ENDFUNC  && NumberToIp

* ------------------------------------------------------------------- *
FUNCTION IpToNetwork( lcIp)
  * Translate IP address to its network address.
  LOCAL lcNet
  IF OCCURS(".", m.lcIp) <> 3
  	lcNet = m.lcIp
  ELSE
  	LOCAL ln1, lnAt1, lnAtX
  	lnAt1 = AT(".", m.lcIp, 1)
  	ln1 = VAL( LEFT( m.lcIp, m.lnAt1 - 1))
  	DO CASE
  	CASE BETWEEN( m.ln1, 1, 126)  && Class A
  		lcNet = LEFT( m.lcIp, m.lnAt1 ) + "0.0.0"
  	CASE BETWEEN( m.ln1, 128, 191)  && Class B
  		lcNet = LEFT( m.lcIp, AT( ".", m.lcIp, 2 )) + "0.0"
  	CASE BETWEEN( m.ln1, 192, 223)  && Class C
  		lcNet = LEFT( m.lcIp, AT( ".", m.lcIp, 3 )) + "0"
  	OTHERWISE  && Loopback, experimental, or invalid.
  		lcNet = m.lcIp
  	ENDCASE
  ENDIF
  RETURN STRTRAN( m.lcNet, " ")
ENDFUNC  && IpToNetwork

* --------------------------------------------------------- *
FUNCTION L7TempFileName( tcType, tcPrefix, tcDir, tnMaxNum)
  * Create an available temporary file name.
  IF TYPE("m.tcType") = "C"
  	tcType = STRTRAN( m.tcType, ".", "")
  ELSE
  	tcType = "TXT"
  ENDIF

  IF TYPE( "m.tcPrefix") # "C" .OR. EMPTY( m.tcPrefix)
  	tcPrefix = "CY"
  ENDIF
  tcPrefix = ALLTRIM( PADR( m.tcPrefix, 7))  && max 7 characters

  IF EMPTY( m.tcDir)  && assume CURDIR--makes FILE() behave
  	tcDir = "."
  ELSE
  	IF NOT RIGHT( m.tcDir, 1) $ "\"
  		tcDir = m.tcDir + "\"
  	ENDIF
  ENDIF

  IF EMPTY( m.tnMaxNum) OR NOT TYPE( "m.tnMaxNum") $ "IN"
  	tnMaxNum = 10 ** ( 8 - LEN( m.tcPrefix)) - 1
  ENDIF

  LOCAL ii, lcFullPath
  FOR ii = 0 TO m.tnMaxNum
  	lcFullPath = m.tcDir + m.tcPrefix + ;
  		PADL( LTRIM( STR( m.ii)), 6, "0") + "." + m.tcType
  	IF NOT FILE( m.lcFullPath)
  		RETURN m.lcFullPath
  	ENDIF
  ENDFOR
  RETURN ""  && none available
ENDFUNC  && L7TempFileName

* --------------------------------------------------------- *
FUNCTION L7DeleteFiles(lcSpec, tvCutoff, lnSkips, lnFails)
  * Deletes files older than specified with specified skeleton.
  * Not recursive and does not remove directories.
  * tvCutoff can be:
  *   numeric == # of seconds old, before deleting
  *   date    == date of file before which to delete
  *   empty   == delete all matching files

  ** lnSecondsOld = IIF( EMPTY( m.lnSecondsOld), 0, m.lnSecondsOld )
  lnSkips = 0  && pass by reference to get count of skips (not old enough)
  lnFails = 0  && pass by reference to get count of failures (in use)

  LOCAL laFiles[ 1, 5], lnFiles, lnHandle, lnDelCount, ii, ;
  	lcFile, ltCutoff, ltFileTime
  DO CASE
  CASE VARTYPE(m.tvCutoff) $ "IN"
  	ltCutoff = DATETIME() - m.tvCutoff
  CASE VARTYPE(m.tvCutoff) = "T"
  	ltCutoff = m.tvCutoff
  CASE VARTYPE(m.tvCutoff) = "D"
  	ltCutoff = DTOT(m.tvCutoff) && convert date to time
  CASE ISNULL(m.tvCutoff) OR EMPTY(m.tvCutoff)
  	ltCutoff = DATETIME()
  OTHERWISE
  	ERROR "Invalid cutoff value passed to L7DeleteFiles."
  ENDCASE 
  
  lnDelCount = 0
  lnFiles = ADIR( laFiles, m.lcSpec)
  FOR ii = 1 TO m.lnFiles
		*!*	  	IF DATETIME() - m.lnSecondsOld > ;
		*!*	  		CTOT( DTOC( laFiles[ m.ii, 3]) + " " + laFiles[ m.ii, 4] )

  	ltFileTime = CTOT(DTOC(laFiles[ m.ii, 3]) + " " + laFiles[ m.ii, 4])
  	IF m.ltCutoff > m.ltFileTime  && file older than cutoff time, erase
  		lcFile = ADDBS( JUSTPATH( m.lcSpec)) + laFiles[ m.ii, 1]
  		* Try to open it with LLFF to see if it's in use:
  		lnHandle = FOPEN( m.lcFile )
  		IF m.lnHandle < 0  && error -- file open somewhere
  			lnFails = m.lnFails + 1
  		ELSE
  			FCLOSE( m.lnHandle)
  			ERASE ( m.lcFile )
  			lnDelCount = m.lnDelCount + 1
  		ENDIF
  	ELSE
  		lnSkips = m.lnSkips + 1
  	ENDIF
  ENDFOR
  RETURN m.lnDelCount  && In case app wants to show.
ENDFUNC  && L7DeleteFiles

* --------------------------------------------------------- *
FUNCTION L7ErrorToXML(lcClass, lnError, lcMethod, lnLine, laArr)
  * Create XML string with VFP Error information. Includes
  * any COM or ODBC error(s). Intended to be called 
  * from an object's error handler by passing in a class name
  * followed by the parameters *it* received.
  *
  * If the object's error handler already performs an AERROR(), 
  * pass in the array by reference. Otherwise AERROR() is 
  * called by this procedure.

  *EXTERNAL ARRAY laArr
  LOCAL lcTxt, ii
  IF VARTYPE( m.lcClass) <> 'C' OR ;
  	VARTYPE( m.lnError) <> 'N' OR ;
  	VARTYPE( m.lcMethod) <> 'C' OR ;
  	VARTYPE( m.lnLine) <> 'N'
  	* 
  	RETURN ""
  ENDIF
  LOCAL ARRAY laError[1]
  IF TYPE( "m.laErr[1]") = "U"
  	= AERROR( laError)
  ELSE
  	= ACOPY( laArr, laError )
  ENDIF

  lcTxt = ""
  * We don't include an XML header, since we expect this snippet
  * of XML to be combined with other information returned from
  * a non-visual object:
  *!*	lcTxt = m.lcTxt + [<?xml version="1.0"?>] + CHR(13) + CHR(10) 
  *!*	lcTxt = m.lcTxt + CHR(13) + CHR(10) 

  lcTxt = m.lcTxt + "<VfpErrorInfo>" + CHR(13) + CHR(10) 
  lcTxt = m.lcTxt + SPACE(2) + "<ErrorTime>" + ;
    TRANS( DATETIME()) + "</ErrorTime>" + ;
    CHR(13) + CHR(10) 
  lcTxt = m.lcTxt + SPACE(2) + "<ErrorServerContext>" + ;
    SYS(0) + "</ErrorServerContext>" + ;
    CHR(13) + CHR(10) 
  lcTxt = m.lcTxt + SPACE(2) + "<VfpErrorNo>" + ;
  	LTRIM( STR( m.lnError)) + "</VfpErrorNo>" + ;
  	CHR(13) + CHR(10) 
  lcTxt = m.lcTxt + SPACE(2) + "<ErrorClass>" + ;
  	m.lcClass + "</ErrorClass>" + ;
  	CHR(13) + CHR(10) 
  lcTxt = m.lcTxt + SPACE(2) + "<ErrorMethod>" + ;
  	m.lcMethod + "</ErrorMethod>" + ;
  	CHR(13) + CHR(10) 
  lcTxt = m.lcTxt + SPACE(2) + "<ErrorLine>" + ;
  	LTRIM( STR( m.lnLine)) + "</ErrorLine>" + ;
  	CHR(13) + CHR(10) 

  lcTxt = m.lcTxt + SPACE(2) + "<ErrorArray>" + CHR(13) + CHR(10) 

  FOR ii = 1 TO ALEN( laError, 1)
  	lcTxt = m.lcTxt + SPACE(4) + "<ErrorItem>" + CHR(13) + CHR(10) 
  	lcTxt = m.lcTxt + SPACE(6) + "<VfpErrorNo>" + ;
  		LTRIM( STR( laError[ m.ii, 1])) + "</VfpErrorNo>" + ;
  		CHR(13) + CHR(10) 
  	lcTxt = m.lcTxt + SPACE(6) + "<ErrorMessage>" + ;
  		laError[ m.ii, 2] + "</ErrorMessage>" + ;
  		CHR(13) + CHR(10) 
  	DO CASE
  	CASE INLIST( m.lnError, 1427, 1429) && COM Errors
  		lcTxt = m.lcTxt + SPACE(6) + "<ComErrorMessage>" + ;
  			laError[ m.ii, 3] + "</ComErrorMessage>" + ;
  			CHR(13) + CHR(10) 
  		lcTxt = m.lcTxt + SPACE(6) + "<ComComponent>" + ;
  			laError[ m.ii, 4] + "</ComComponent>" + ;
  			CHR(13) + CHR(10) 
  			
  	CASE INLIST( m.lnError, 1526) && ODBC Errors
  		lcTxt = m.lcTxt + SPACE(6) + "<ODBCErrorMessage>" + ;
  			laError[ m.ii, 3] + "</ODBCErrorMessage>" + ;
  			CHR(13) + CHR(10) 
  		lcTxt = m.lcTxt + SPACE(6) + "<SQLState>" + ;
  			laError[ m.ii, 4] + "</SQLState>" + ;
  			CHR(13) + CHR(10) 
  		lcTxt = m.lcTxt + SPACE(6) + "<DataSourceErrorNo>" + ;
  			LTRIM( STR( laError[ m.ii, 5])) + "</DataSourceErrorNo>" + ;
  			CHR(13) + CHR(10) 
  		lcTxt = m.lcTxt + SPACE(6) + "<ConnectionHandle>" + ;
  			LTRIM( STR( laError[ m.ii, 6])) + "</ConnectionHandle>" + ;
  			CHR(13) + CHR(10) 
  	OTHERWISE
  		IF NOT ISNULL( laError[ m.ii, 3])
  			lcTxt = m.lcTxt + SPACE(6) + "<ErrorParameter>" + ;
  				TRANSFORM(laError[ m.ii, 3]) + "</ErrorParameter>" + ;
  				CHR(13) + CHR(10) 
  		ENDIF
  		IF NOT ISNULL( laError[ m.ii, 4])
  			lcTxt = m.lcTxt + SPACE(6) + "<ErrorWorkArea>" + ;
  				LTRIM( STR( laError[ m.ii, 4])) + "</ErrorWorkArea>" + ;
  				CHR(13) + CHR(10) 
  		ENDIF
  		IF NOT ISNULL( laError[ m.ii, 5])
  			lcTxt = m.lcTxt + SPACE(6) + "<TriggerType>" + ;
  				LTRIM( STR( laError[ m.ii, 5])) + "</TriggerType>" + ;
  				CHR(13) + CHR(10) 
  		ENDIF
  	ENDCASE
  	
  	lcTxt = m.lcTxt + SPACE(4) + "</ErrorItem>" + CHR(13) + CHR(10) 
  ENDFOR
  lcTxt = m.lcTxt + SPACE(2) + "</ErrorArray>" + CHR(13) + CHR(10) 

  lcTxt = m.lcTxt + "</VfpErrorInfo>" + CHR(13) + CHR(10) 
  RETURN m.lcTxt
ENDFUNC  && L7ErrorToXML
* --------------------------------------------------------- *

*** ========================================================= ***
DEFINE CLASS L7PreserveSelect AS LINE
  nSelect = 0
  * --------------------------------------------------------- *
  FUNCTION INIT
    THIS.nSelect = SELECT()
    * Move away so we don't USE over top:
    SELECT 0
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    SELECT (THIS.nSelect)
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7HtmlParser AS LINE
  cHTML = ""
  * --------------------------------------------------------- *
  FUNCTION SetHTML
    LPARAMETER lcHtml
    THIS.cHTML = m.lcHTML
  ENDFUNC  && SetHtml
  * --------------------------------------------------------- *
  FUNCTION GetBodyInnerHtml
    LOCAL lnAt1, lnAt2, lcHTML, lcTxt
    lcHTML = UPPER( THIS.cHTML)
    lnAt1 = AT( "<BODY", m.lcHTML )
    IF m.lnAt1 = 0
    	RETURN THIS.cHTML
    ENDIF
    lnAt2 = AT( "</BODY>", m.lcHTML )
    IF m.lnAt2 = 0
    	lcTxt = SUBSTR( THIS.cHTML, m.lnAt1 + 5)
    ELSE
    	lcTxt = SUBSTR( THIS.cHTML, m.lnAt1 + 5, m.lnAt2 - m.lnAt1 - 5)
    ENDIF
    lnAt1 = AT( ">", m.lcTxt )
    RETURN SUBSTR( m.lcTxt, m.lnAt1 + 1)
  ENDFUNC  && GetBodyInnerHtml
  * --------------------------------------------------------- *
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS BackupDBC AS RELATION
  * Properties:
  cDBCName           = ""  && required !
  cBackupDBCName     = ""  && optional, cDbcName + suffix is default
  cBackupPath        = ""  && path to where files are copied
  cBackupTableSuffix = "_backup"  && optional suffix for each filename

  lSingleTable = .F.
  cSingleTableName = ""

  * --------------------------------------------------------- *
  FUNCTION Execute
    LOCAL ARRAY laTables[ 1]
    LOCAL lnTables, ii, llOldSafety, lnOldSelect, lcOldDatabase, llDbcUsed

    * Groom the backup path:
    IF NOT EMPTY( THIS.cBackupPath)
    	THIS.cBackupPath = ADDBS( THIS.cBackupPath)
    ENDIF
    IF NOT DIRECTORY( THIS.cBackupPath)
      ERROR "Directory " + THIS.cBackupPath + " does not exist."
      RETURN .F.
    ENDIF
    
    THIS.cDbcName = JUSTSTEM( THIS.cDbcName) && in case they passed the ".DBC" part

    * Groom the backup DBC name:
    IF EMPTY( THIS.cBackupDBCName)
    	THIS.cBackupDBCName = THIS.cDBCName + THIS.cBackupTableSuffix
    ENDIF

    * Open database if not open already. Up to your app to ensure it's available in the path:
    IF NOT DBUSED( THIS.cDBCName)
    	llDbcUsed = .F.	
    	SET DATABASE TO
    	OPEN DATABASE ( THIS.cDBCName)
    ELSE
    	llDbcUsed = .T.	
    	SET DATABASE TO ( THIS.cDBCName)
    ENDIF

    lnTables = ADBOBJECTS( laTables, "table")
    llOldSafety = ( SET( "SAFETY") = "ON" )
    lnOldSelect = SELECT()
    lcOldDatabase = SET( "DATABASE" )
    IF DBUSED( THIS.cBackupDBCName )
    	SET DATABASE TO ( THIS.cBackupDBCName ) 
    	CLOSE DATABASE 
    ENDIF
    IF m.lcOldDatabase == UPPER( THIS.cBackupDBCName)
    	m.lcOldDatabase = ""
    ENDIF

    SET SAFETY OFF
    CREATE DATABASE ( THIS.cBackupPath + THIS.cBackupDBCName )
    IF m.llOldSafety
    	SET SAFETY ON
    ENDIF

    SET DATABASE TO ( THIS.cDBCName)
    SELECT 0
    FOR ii = 1 TO m.lnTables
    	* Process each Table.
    	USE ( laTables[ m.ii]) AGAIN
    	
    	* Defaults to copying in Primary Key order:
    	lcTag = DBGETPROP( laTables[ ii], "table", "PrimaryKey")
    	IF NOT EMPTY( m.lcTag)
    		SET ORDER TO ( m.lcTag)
    	ENDIF
    	* Get the physical file name (in case Table "Name" is different in DBC).
    	lcFileName = JUSTSTEM( DBF())
    	
    	SET SAFETY OFF
    	COPY TO ( THIS.cBackupPath + m.lcFileName + ;
    			THIS.cBackupTableSuffix ) ;
    		DATABASE ( THIS.cBackupDBCName ) ;
    		NAME ( laTables[ m.ii] )
    	IF m.llOldSafety
    		SET SAFETY ON
    	ENDIF
    		
    	USE
    ENDFOR

    SET DATABASE TO ( THIS.cBackupDBCName )
    CLOSE DATABASE

    SET DATABASE TO ( m.lcOldDatabase )
    IF m.llDbcUsed = .F.	
    	CLOSE DATABASE
    ENDIF
    SELECT ( m.lnOldSelect )
  ENDFUNC  && Execute
  * --------------------------------------------------------- *
ENDDEFINE  && CLASS BackupDBC

*** ========================================================= ***
DEFINE CLASS BackupFreeTables AS RELATION
  * Properties:
  cDataPath          = ""  && required !
  cBackupPath        = ""  && path to where files are copied
  cBackupTableSuffix = "_backup"  && optional suffix for each filename

  lSingleTable = .F.
  cSingleTableName = ""
  DIMENSION aSkipTables[1]
  nSkipTables = 0
  * --------------------------------------------------------- *
  FUNCTION SkipTable(lcName)
    THIS.nSkipTables = THIS.nSkipTables + 1 
    DIMENSION THIS.aSkipTables[THIS.nSkipTables]
    THIS.aSkipTables[THIS.nSkipTables] = m.lcName
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Execute
    LOCAL ARRAY laTables[ 1]
    LOCAL lnTables, ii, jj, llOldSafety, lnOldSelect, lcFileName, llSkip

    * Groom the backup path:
    IF NOT EMPTY( THIS.cBackupPath)
      THIS.cBackupPath = ADDBS( THIS.cBackupPath)
    ENDIF
    IF NOT DIRECTORY( THIS.cBackupPath)
      ERROR "Directory " + THIS.cBackupPath + " does not exist."
      RETURN .F.
    ENDIF
    
    lnTables = ADIR( laTables, THIS.cDataPath + "*.DBF")
    llOldSafety = ( SET( "SAFETY") = "ON" )
    lnOldSelect = SELECT()

    SELECT 0
    FOR ii = 1 TO m.lnTables
      * Process each Table.
      lcFileName = laTables[m.ii,1]
      IF THIS.nSkipTables > 0
        llSkip = .F.
        FOR jj = 1 TO THIS.nSkipTables
          IF UPPER(THIS.aSkipTables[m.jj]) == UPPER(JUSTSTEM(m.lcFileName))
            llSkip = .T.
            EXIT
          ENDIF
        ENDFOR
        IF m.llSkip
          LOOP
        ENDIF
      ENDIF
      USE ( THIS.cDataPath + m.lcFileName) AGAIN
      
      SET SAFETY OFF
      COPY TO (THIS.cBackupPath + ;
        JUSTSTEM(m.lcFileName) + THIS.cBackupTableSuffix )
        
      IF m.llOldSafety
        SET SAFETY ON
      ENDIF
        
      USE
    ENDFOR

    SELECT ( m.lnOldSelect )
  ENDFUNC  && Execute
  * --------------------------------------------------------- *
ENDDEFINE  && CLASS BackupFreeTables

*** ========================================================= ***
DEFINE CLASS L7Environment AS Relation
  lAutoCloseTables = .F.
  PROTECTED lStateSaved, lStateRestored
  lStateSaved = .F.
  lStateRestored = .F.
  lLeaveCacheTablesOpen = .T. && tables with "_cache" in name
  
  * Open table preservation properties:
  nOldUsed = 0
  DIMENSION aOldUsed[ 1, 2]
  aOldUsed[ 1, 1] = .F.
  nOldDatabase = 0
  DIMENSION aOldDatabase[ 1, 2]
  aOldDatabase[ 1, 1] = .F.
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    * Garbage collection strategy to force state restoration:
    IF THIS.lStateSaved AND NOT THIS.lStateRestored
      THIS.RestoreState()
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RestoreState
    IF THIS.lAutoCloseTables = .T.
      THIS.CloseNewlyOpenedTables()
    ENDIF
    THIS.lStateRestored = .T.
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SaveState
    IF THIS.lAutoCloseTables = .T.
      THIS.NoteOpenTables()
    ENDIF
    THIS.lStateSaved = .T.
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION NoteOpenTables
    THIS.nOldDatabase = ADATABASE( THIS.aOldDatabase)
    THIS.nOldUsed = AUSED( THIS.aOldUsed)
  ENDFUNC
  * --------------------------------------------------------- *
  PROTECTED FUNCTION CloseNewlyOpenedTables
    LOCAL ii, jj, lnUsed, laUsed, lnDatabase, laDatabase, lcItem

    DIMENSION laDatabase[ 1, 2]
    lnDatabase = ADATABASES( laDatabase)
    FOR ii = 1 TO m.lnDatabase  && for each currently open database
      FOR jj = 1 TO THIS.nOldDatabase  && loop through previously used list
        IF THIS.aOldDatabase[ m.jj, 1] == laDatabase[ m.ii, 1]  && same database was in use
          EXIT
        ENDIF
      ENDFOR
      IF m.jj > THIS.nOldDatabase  && no match
        SET DATABASE TO ( laDatabase[ m.ii, 1])
        CLOSE DATABASE
      ENDIF
    ENDFOR

    DIMENSION laUsed[ 1, 2]
    lnUsed = AUSED( laUsed)
    FOR ii = 1 TO m.lnUsed  && for each currently used area
      lcItem = laUsed[m.ii, 1]
      IF THIS.lLeaveCacheTablesOpen AND "_CACHE_" $ m.lcItem
        LOOP
      ENDIF
      IF THIS.nOldUsed = 0  && nothing was open before
        USE IN ( laUsed[ m.ii, 2])
      ELSE
        lnRow = ASCAN(THIS.aOldUsed, m.lcItem, 1, -1, 1, 14)
        IF m.lnRow = 0 OR THIS.aOldUsed[m.lnRow, 2] <> laUsed[m.ii, 2]
          * Not used before, or used in a different work area.
          USE IN ( laUsed[ m.ii, 2])
        ENDIF
      ENDIF
    ENDFOR
  ENDFUNC  && CloseNewlyOpenedTables
  * --------------------------------------------------------- *
ENDDEFINE  && L7Environment 

* --------------------------------------------------------- *
FUNCTION L7RegexpAT( lcPattern, lcSourceString, lnOcc, llIgCase, llRTOL )
  LOCAL loObj, lnResult
  loObj = CREATEOBJECT("L7RegExp")
  lnResult = loObj.AT(m.lcPattern, @lcSourceString, m.lnOcc, m.llIgCase, m.llRTOL)
  loObj = NULL
  RETURN m.lnResult
ENDFUNC  && L7RegExpAT
* --------------------------------------------------------- *
FUNCTION L7RegexpRAT(lcPattern AS String, lcSourceString AS String, lnOcc AS Integer)
  RETURN L7RegexpAT(m.lcPattern, @lcSourceString, m.lnOcc, .F., .T.)
ENDFUNC
* --------------------------------------------------------- *
FUNCTION L7RegexpRATC(lcPattern AS String, lcSourceString AS String, lnOcc AS Integer)
  RETURN L7RegexpAT(m.lcPattern, @lcSourceString, m.lnOcc, .T., .T.)
ENDFUNC
* --------------------------------------------------------- *
FUNCTION L7RegexpATC(lcPattern AS String, lcSourceString AS String, lnOcc AS Integer)
  RETURN L7RegexpAT(m.lcPattern, @lcSourceString, m.lnOcc, .T.)
ENDFUNC

* --------------------------------------------------------- *
FUNCTION L7RegexpOccurs( tcText, tcPattern ) as Integer
  * Like L7RegExpTest, but return number of matches.
  * Examples:
  *   ? L7RegexpOccurs('abracadabra', 'ab')     && 2
  *   ? L7RegexpOccurs('abracadabra', '(ab\w+)')  && 1 (greedy)
  *   ? L7RegexpOccurs('abracadabra', '(ab\w+)?') && 2 (non-greedy)
  *
  LOCAL loObj, loMatches, lnResult
  loObj = CREATEOBJECT("L7RegExp")
  loObj.Pattern = m.tcPattern
  loMatches = loObj.Execute( m.tcText )
  lnResult = loMatches.Count
  loMatches = NULL
  loObj = NULL
  RETURN m.lnResult
ENDFUNC  && L7RegexpOccurs

* --------------------------------------------------------- *
FUNCTION L7IsRegexpPattern( tcPattern ) as Boolean
  * Crude Fn to determine search-form "intent".
  LOCAL lcTelltaleChars
  lcTelltaleChars = '[]\?$^()'
  RETURN NOT EMPTY(CHRTRAN(m.tcPattern, CHRTRAN(m.tcPattern, m.lcTellTaleChars, ""), ""))
ENDFUNC
* --------------------------------------------------------- *
FUNCTION L7RegexpTest( tcText, tcPattern ) as Boolean
  * same as perl's m
  * Examples:
  *   ? L7RegexpTest('abracadabra', '(ab)')     && .T.
  *
  LOCAL loObj, llResult
  loObj = CREATEOBJECT("L7RegExp")
  loObj.Pattern = m.tcPattern
  llResult = loObj.Test( m.tcText )
  loObj = NULL
  RETURN m.llResult
ENDFUNC  && L7RegexpTest

* --------------------------------------------------------- *
FUNCTION L7RegexpReplace( tcText, tcSearchPattern, tcReplacePattern ) as String
  * mimics perl's 's' function -- EXCEPT
  * returns STRING instead of hit count -- 
  * can also pass tcText by reference to get replacement that way
  * Examples:
  *   ? L7RegexpReplace('abracadabra', 'ab', 'cd')     && "cdracadcdra"
  *
  * or with pass by reference:
  *
  *   lcText = 'abracadabra'
  *   L7RegexpReplace(@lcText, 'ab', 'cd')
  *
  LOCAL loObj, lnResult, loMatches
  loObj = CREATEOBJECT("L7RegExp")
  loObj.Pattern = m.tcSearchPattern
  *!* Wasted step, just to get hit count:
  *!* loMatches = loObj.Execute( m.tcText )
  *!* lnResult = loMatches.Count
  * Now do the real thing:
  *!* IF m.lnResult > 0
  tcText = loObj.Replace(m.tcText, m.tcReplacePattern)
  *!* ENDIF
  loObj = NULL
  *!* RETURN m.lnResult
  RETURN m.tcText
ENDFUNC  && L7RegexpReplace

*** ========================================================= ***
DEFINE CLASS L7RegExp AS LINE
  cRegexpClass = L7_REGEXP_CLASS
  Pattern      = [*]
  MultiLine    = .F.
  Global       = .T.
  IgnoreCase   = .T.
  * --------------------------------------------------------- *
  FUNCTION AT(lcPattern AS String, lcSourceString AS String, lnOcc AS Integer, llIgnoreCase AS Boolean, llFromRight AS Boolean)
    THIS.IgnoreCase = m.llIgnoreCase
    THIS.MultiLine  = .T.
    THIS.Global     = .T.
    THIS.Pattern    = m.lcPattern
    lnOcc = EVL(m.lnOcc, 1)
    LOCAL loObj, lnResult, loMatches, loMatch, lnCount
    lnResult = 0
    loObj = CREATEOBJECT(THIS.cRegexpClass)
    THIS.ConfigRegExp(m.loObj)
    loMatches = loObj.Execute(m.lcSourceString)
    lnCount = m.loMatches.Count
    IF m.lnCount >= m.lnOcc
      loMatch = loMatches.item[IIF(m.llFromRight, m.lnCount - m.lnOcc, m.lnOcc - 1)]
      lnResult = loMatch.FirstIndex + 1
    ENDIF
    RETURN m.lnResult
  ENDFUNC  && AT()
  * --------------------------------------------------------- *
  FUNCTION RAT(lcPattern AS String, lcSourceString AS String, lnOcc AS Integer)
    RETURN THIS.AT(m.lcPattern, @lcSourceString, m.lnOcc, .F., .T.)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RATC(lcPattern AS String, lcSourceString AS String, lnOcc AS Integer)
    RETURN THIS.AT(m.lcPattern, @lcSourceString, m.lnOcc, .T., .T.)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ATC(lcPattern AS String, lcSourceString AS String, lnOcc AS Integer)
    RETURN THIS.AT(m.lcPattern, @lcSourceString, m.lnOcc, .T.)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Test(lcSourceString AS String) AS Boolean 
    LOCAL loObj, llResult
    * Remove and create new object on every request, because
    * we've noted some corruption in the COM object:
    loObj = CREATEOBJECT(THIS.cRegexpClass)
    THIS.ConfigRegExp(m.loObj)
    TRY
      llResult = loObj.Test(m.lcSourceString)
    CATCH TO loExc WHEN loExc.ErrorNo = 1426
      THROW "COM error testing regular expression."
    ENDTRY
    loObj = NULL
    RETURN m.llResult
  ENDFUNC  && Test()
  * --------------------------------------------------------- *
  FUNCTION Replace(lcSourceString AS String, lcReplaceString AS String) AS String
    LOCAL loObj, lcResult
    * Remove and create new object on every request, because
    * we've noted some corruption in the COM object:
    loObj = CREATEOBJECT(THIS.cRegexpClass)
    THIS.ConfigRegExp(m.loObj)
    lcResult = loObj.Replace(m.lcSourceString, m.lcReplaceString)
    loObj = NULL
    RETURN m.lcResult
  ENDFUNC  && Replace()
  * --------------------------------------------------------- *
  FUNCTION Execute(lcSourceString AS String) AS Object
    LOCAL loObj, lnNewMatch, loMatches, loMatch, loRet AS Collection, lcSub 
    * Remove and create new object on every request, because
    * we've noted some corruption in the COM object:
    loObj = CREATEOBJECT(THIS.cRegexpClass)
    THIS.ConfigRegExp(m.loObj)
    loMatches = loObj.Execute(m.lcSourceString)
    loRet = CREATEOBJECT("Collection")
    FOR EACH loMatch IN loMatches
      loNewMatch = CREATEOBJECT("L7RegExpMatch")
      WITH loNewMatch
        .Value = loMatch.Value
        .Length = loMatch.Length
        FOR EACH lcSub IN loMatch.SubMatches
          .SubMatches.Add(m.lcSub)
        ENDFOR
      ENDWITH
      loRet.Add(loNewMatch)
    ENDFOR
    loObj = NULL
    RETURN m.loRet
  ENDFUNC  && Execute()
  * --------------------------------------------------------- *
  FUNCTION ConfigRegExp(loObj)
    WITH loObj
      .Pattern    = THIS.Pattern
      .Global     = THIS.Global
      .IgnoreCase = THIS.IgnoreCase
      .MultiLine  = THIS.MultiLine
    ENDWITH
  ENDFUNC  
  * --------------------------------------------------------- *
ENDDEFINE  && L7RegExp

*** ========================================================= ***
DEFINE CLASS L7RegExpMatch AS Container
  Value = NULL
  Length = 0
  ADD OBJECT SubMatches AS Collection
ENDDEFINE  && L7RegExpMatch

*** ========================================================== ***
DEFINE CLASS L7Lightweight AS RELATION

  HIDDEN CHILDALIAS
  HIDDEN CHILDORDER
  HIDDEN ONETOMANY
  HIDDEN PARENTALIAS
  HIDDEN RELATIONALEXPR
  
ENDDEFINE

*** ========================================================== ***
DEFINE CLASS L7Collection AS Collection
  * --------------------------------------------------------- *
  FUNCTION AddUpdate(lvItem, lcKey, lvBefore, lvAfter)  
    * Like Add, but does not fail if key exists--instead "replaces"
    * item (value), like Python dict's.
    LOCAL lnIndex
    lnIndex = THIS.GetKey(m.lcKey) 
    IF m.lnIndex > 0  && key exists
      THIS.Remove(m.lnIndex)
    ENDIF
    DO CASE
    CASE PCOUNT() <= 2
      THIS.Add(m.lvItem, m.lcKey)  
    CASE PCOUNT() = 3
      THIS.Add(m.lvItem, m.lcKey, m.lvBefore)  
    CASE PCOUNT() >= 4
      THIS.Add(m.lvItem, m.lcKey, m.lvBefore, m.lvAfter)  
    ENDCASE
    RETURN 
  ENDFUNC
ENDDEFINE

*** ========================================================== ***
DEFINE CLASS L7UrlCollection AS L7Collection
  * --------------------------------------------------------- *
  FUNCTION Add(lvItem, lcKey, lvBefore, lvAfter)  
    NODEFAULT
    TRY
      DODEFAULT(m.lvItem, m.lcKey)
    CATCH TO loExc WHEN loExc.ErrorNo = 2062 && key exists - assume dup
    ENDTRY
    RETURN
  ENDFUNC
ENDDEFINE

* --------------------------------------------------------- *
FUNCTION L7Dict( ;
    p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, ;
    p13, p14, p15, p16, p17, p18, p19, p20, p21, p22, p23, p24)

  LOCAL loObj, ii, lcName, lvVal, lnParms
  lnParms = PCOUNT()
  loObj = CREATEOBJECT("L7DictCollection")
  loObj.cOnCollision = "Replace"

  FOR ii = 1 TO INT(m.lnParms / 2)
    * Repeat for each *pair* of parameters passed:
    lcName  = EVAL( "m.p" + LTRIM( STR( m.ii * 2 - 1)) )
    lvVal = EVAL( "m.p" + LTRIM( STR( m.ii * 2 )) )
    loObj.Add(m.lvVal, m.lcName)
  NEXT ii 

  RETURN m.loObj
ENDFUNC && L7Dict

*** ========================================================== ***
DEFINE CLASS L7DictCollection as Collection
  * Add optional collision handling
  * to the BaseCollection class.
  cOnCollision = "Replace" && choose from {Error, Ignore, Replace}
  vDefault = ""            && value on item() lookup failure, start with "=" to eval()
  * --------------------------------------------------------- *
  ** reverse param order from add()
  FUNCTION Set(tcKey, tvItem)  && more like natural: name = value
    THIS.Add(m.tvItem, m.tcKey)
  ENDFUNC && set
  * --------------------------------------------------------- *
  FUNCTION add(tvItem, tcKey)
    NODEFAULT 
    LOCAL lnKey
    lnKey = THIS.GetKey(m.tcKey)
    IF m.lnKey > 0 
      * key exists
      DO CASE
      CASE THIS.cOnCollision = "Ignore" 
        RETURN 
      CASE THIS.cOnCollision = "Replace" 
        THIS.Remove(m.tcKey)
        * then, let all the other before/after stuff happen below
      OTHERWISE && presume "Error" 
        ERROR 2062  && simulate same error they would have received
      ENDCASE
    ENDIF

    DODEFAULT(m.tvItem, m.tcKey)
  ENDFUNC && add
  * --------------------------------------------------------- *
  FUNCTION item(tvIndex)

    IF NOT ISNULL(THIS.vDefault) AND VARTYPE(m.tvIndex) = "C"
      LOCAL lnKey, lvVal
      lnKey = THIS.GetKey(m.tvIndex)
      IF m.lnKey = 0 && d.n.e. 
        NODEFAULT 
        lvVal = THIS.vDefault
        IF VARTYPE(m.lvVal) = "C" 
          IF SET("TEXTMERGE", 1) $ m.lvVal
            lvVal = TEXTMERGE(m.lvVal)
          ENDIF 
          IF LEFT(m.lvVal, 1) == "="
            lvVal = EVALUATE(SUBSTR(m.lvVal,2))
          ENDIF 
        ENDIF 
        THIS.Add( m.lvVal, m.tvIndex) 
        RETURN m.lvVal
      ENDIF
    ENDIF 

    RETURN DODEFAULT(m.tvIndex)
  ENDFUNC && item
  * --------------------------------------------------------- *
ENDDEFINE  && L7DictCollection

*** ========================================================== ***
DEFINE CLASS L7Stack AS L7Lightweight
* some parsers and page elements need a stack to hide their content to

  COUNT      = 0      && returns nElements, see count_access
  nSizeInc   = 5      && size by which the array will be redim'ed (avoides redimensioning on each push()
  nArraySize = 0      && the actual size of the array (some elements may be unused)
  nElements  = 0      && the actual size of the stack (always <= nArraySize)

  DIMENSION aStck(1)  && storage

  HIDDEN nElements, aStck, nArraySize

  * --------------------------------------------------------- *  
  function reset()
    DIMENSION THIS.aStck( THIS.nSizeInc )
    *? OPT: could leave dimension as is (maybe with a max) to avoid lots
    *  of redim's next time.
    
    *-- wipe out all previous (if any) values
    store NULL to this.aStck
    
    THIS.nArraySize = THIS.nSizeInc
    this.nElements = 0
    
  endfunc
  
  * --------------------------------------------------------- *
  FUNCTION INIT()
    this.reset()
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION Count_access
    RETURN THIS.nElements
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION isEmpty()
    RETURN THIS.nElements = 0
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION push( tvValue )

    *-- check if we need to take another chunk of memory
    IF THIS.nElements = THIS.nArraySize
      this.nArraySize =  THIS.nArraySize + THIS.nSizeInc 
      DIMENSION THIS.aStck( THIS.nArraySize )
    
    ENDIF
    THIS.nElements               = THIS.nElements + 1
    THIS.aStck( THIS.nElements ) = m.tvValue
    RETURN THIS.nElements
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION pop()

    IF THIS.nElements > 0
      THIS.nElements = THIS.nElements - 1
      RETURN THIS.aStck( THIS.nElements + 1 )
    ELSE
      RETURN []
    ENDIF
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION getElement( tvElement )

    LOCAL lnElement
    lnElement = IIF( VARTYPE( m.tvElement ) # "N", VAL( m.tvElement ), m.tvElement )
    ASSERT (m.lnElement <= this.nElements) AND m.lnElement > 0 MESSAGE this.NAME + [::getElement() tnElement out of bounds]
 
    IF m.lnElement <= THIS.nElements AND m.lnElement > 0
      RETURN THIS.aStck( m.lnElement )
    ENDIF
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION setElement( tnElement, tvValue )
  
    LOCAL lnElement
  
    lnElement = IIF( VARTYPE( m.tvElement ) # "N", VAL( m.tvElement ), m.tvElement )
    ASSERT ( m.lnElement <= this.nElements) AND m.lnElement > 0 MESSAGE this.NAME + [::setElement() tnElement out of bounds]
  
    THIS.aStck( m.lnElement ) = m.tvValue
  ENDFUNC

ENDDEFINE
*-- EOC Stack


*** ========================================================== ***
DEFINE CLASS L7CORLink AS L7Lightweight

* Defines the COR participant's interface, implements base methods

  oSuccessor    =  NULL    && the next link
  lactive       = .T.      && if .t., this link with pass-through

  lerror        = .f.      && very simplistic, a link can be in two states: error or no error
  cErrorMessage = []
  lhaltonerror  = .f.      && if .t., the chain will terminate if one of the links has an error
  
  protected lactive

  * --------------------------------------------------------- *
  FUNCTION hasSuccessor()
    RETURN VARTYPE( THIS.oSuccessor ) = "O"
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION isActive(tvParam) && subclasses may want to base answer on content
    *-- subclasses may override this for more complex rules
    RETURN THIS.lactive
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION garbagecollect()
    IF THIS.hasSuccessor()
      THIS.oSuccessor.garbagecollect()
    ENDIF
    THIS.oSuccessor = NULL
  ENDFUNC
  
    * ------------------------------------------------------------------- *
  FUNCTION DESTROY
    THIS.GarbageCollect()
    DODEFAULT()
  ENDFUNC  && DESTROY

  * --------------------------------------------------------- *
  FUNCTION RELEASE()
    this.garbageCollect()
    RELEASE this
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION executeImplementation( tvParam )
  * implement in subclass
  * tvParam will be passed by reference
  ENDFUNC
 
  * --------------------------------------------------------- *
  FUNCTION beforeExecute( tvParam )
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION afterExecute( tvParam ) 
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION execute( tvParam )
  * The main invoker, template method
  * tvParam must always be passed by reference (or better, be an object)
       
    this.lError = .f.   && innocent until proven guilty
    
    if this.beforeExecute( @m.tvParam )
      * 04/09/2011 - added passing of payload to isActive(), used in IA generators
      if this.isActive( @m.tvParam ) and not (this.lerror and this.lhaltonerror)
        this.lError = this.executeImplementation( @m.tvParam )
      endif
    endif   
    this.afterExecute( @m.tvParam )
 
    if not (this.lerror and this.lhaltonerror)  && we may block the rest of the chain after the first error
      IF THIS.hasSuccessor()
        THIS.oSuccessor.execute( @m.tvParam )
      endif
    endif
     
    * a hook for special behaviour at the end of the chain
    * NOTE: This fires even if we are in an error condition
    this.onEndOfChain( @m.tvParam )
       
    return NOT this.lError
 
  ENDFUNC  && execute()

  * --------------------------------------------------------- *
  FUNCTION onEndOfChain( tvParam )
  * fires post execute only if this link is the last in the chain
  ENDFUNC

  * --------------------------------------------------------- *
  FUNCTION linkCount( tnCount )
  * returns the total number of links in the chain from this point on
    IF VARTYPE( m.tnCount ) #"N"
      tnCount = 1
    ELSE
      tnCount = m.tnCount + 1
    ENDIF
    
    IF THIS.hasSuccessor()
      RETURN THIS.oSuccessor.linkCount( m.tnCount )
    ELSE
      RETURN m.tnCount
    ENDIF
  
  ENDFUNC && linkCount
  
  * --------------------------------------------------------- *
  FUNCTION setAll( tcPropertyName, tvValue)
  *-- set property value for all links in the chain

    THIS.&tcPropertyName = m.tvValue
    IF THIS.hasSuccessor()
      THIS.oSuccessor.SETALL( m.tcPropertyName, m.tvValue )
    ENDIF  
    return 
  ENDFUNC
  
  * --------------------------------------------------------- *
  FUNCTION setAllx( tcPropertyName, tvValue, tcExpression )
  *-- set property value for links for which tcExpression evals to true
    LOCAL llcheckExpression, lcExpression
  
    ASSERT (VARTYPE( m.tcExpression ) $ "C") MESSAGE this.NAME + [::setAllx() expects character tcExpression ]
  
    IF EVALUATE( m.tcExpression )
      THIS.&tcPropertyName = m.tvValue
    ENDIF

    IF THIS.hasSuccessor()
      THIS.oSuccessor.setAllx( m.tcPropertyName, m.tvValue, m.tcExpression )
    endif
    return 
  ENDFUNC  && setAllx
  
  * --------------------------------------------------------- *
  FUNCTION setSuccessor( tvSuccessor )
    LOCAL loSuccessor
  
    IF VARTYPE( m.tvSuccessor ) = "C"
      loSuccessor = CREATEOBJECT( m.tvSuccessor )
    ELSE
      loSuccessor = m.tvSuccessor
    ENDIF

    ASSERT (VARTYPE( m.loSuccessor ) = "O") MESSAGE this.Name + [:: setSuccessor() requires an object or a class name ]
  
    IF THIS.hasSuccessor()
      RETURN THIS.oSuccessor.setSuccessor( m.loSuccessor )
    ELSE
      *-- return a reference as we might want to tweak this link after adding it
      THIS.oSuccessor = m.loSuccessor
      RETURN m.loSuccessor
    ENDIF

  ENDFUNC  && setSuccessor

ENDDEFINE
*--EOC COR Link

*** ========================================================== ***
DEFINE CLASS L7Exception AS Exception
  PROTECTED Parent, ParentClass, BaseClass, Tag
  DIMENSION aErrors[1,7]
  nErrors = 0
  FUNCTION LoadErrorArray
    THIS.nErrors = AERROR(THIS.aErrors)
  ENDFUNC
ENDDEFINE  && L7Exception

#if .f.
05/29/2002 - Revised string parsing routines to work with pass-by-reference.
01/06/2003 - Change "&" usage to "&amp;" (via #DEFINE, in case no workie).
01/14/2003 - Fixed missing ) bug that was masked from compiler detection by ampersand.
02/17/2003 - Moved L7Lightweight and L7Stack from L7Parsers.prg.
02/22/2003 - Moved L7CORLink from L7Parsers.prg [LC]
04/15/2003 - Renamed several fn's to include "L7" prefix to support combining with other frameworks ("singleton issue" of fn. libs)
           - Added L7ExtensionToContentType().
05/11/2003 - Added new L7GetEmbeddedTagInfo plus supporting class L7EmbeddedTagInfo
           - Added various AT()-style methods to RegExp capabilities.
10/27/2003 - Added ADDFS() to parallel native ADDBS().
10/29/2003 - Modified GETGUIDSTRING() to allow passing 32 or 36 to strip punctuation.
10/30/2003 - OpenIfNot() - added path optional parameter
11/02/2003 - added support for "safe" textmerging (see L7PageElement and L7ExpandTemplate, also)
12/24/2003 - added registry check as OTHERWISE approach to L7ExtensionToContentType()
01/01/2004 - updated BasedOn() to deal with Empty objects
11/02/2004 - revised ConcatenateMail to allow two lists to be merged
02/19/2005 - added L7RandomString() which uses GUIDs to create string of variable lengths.
06/07/2005 - renamed Cast() to L7Cast().
10/28/2005 - fixed bug in L7RandomString where SYS(2017) had been used instead of SYS(2007)
#endif

* END: L7Utils.PRG
