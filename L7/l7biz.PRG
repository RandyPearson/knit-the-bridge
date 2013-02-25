* L7Biz.PRG

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
DEFINE CLASS L7Biz AS CUSTOM
  nDataMode = 0     && local VFP data
  cTableName = NULL     && override
  cDataPath = NULL  
  vKeyValue = NULL
  cKeyExpr = NULL
  vParentKeyValue = NULL
  cLimitingExpression = ""
  cParentKeyExpr = NULL
  nActiveItem = 0
  ** oActiveItem = NULL  && unclear if we want this
  nItems = 0
  DIMENSION aItems[1]
  nOldItems = 0
  DIMENSION aOldItems[1]
  nNewItems = 0  && # of items added
  dDate = {}
  cTime = ""
  lChanged = .F.
  lDeleteMe = .F. && set flag to delete
  lValid = NULL
  lValidated = .F.
  lValidateOnSave = .F.
  nInvalidCount = 0
  cValidationMessage = ""
  cResultMessage = ""
  nRequired = 0
  DIMENSION aRequired[1]
  nDefaults = 0
  DIMENSION aDefaults[1,2]
  * -------------------------------------------------- *
  FUNCTION dDate_ACCESS
    IF EMPTY( THIS.dDate)
      IF TYPE("THIS.Parent") = "O"
        THIS.dDate = THIS.Parent.dDate
      ELSE
        THIS.dDate = DATE()
      ENDIF
    ENDIF
    RETURN THIS.dDate
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION cTime_ACCESS
    IF EMPTY( THIS.cTime)
      IF TYPE("THIS.Parent") = "O"
        THIS.cTime = THIS.Parent.cTime
      ELSE
        THIS.cTime = TIME()
      ENDIF
    ENDIF
    RETURN THIS.cTime
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION nNewItems_ACCESS
    RETURN THIS.nItems - THIS.nOldItems
  ENDFUNC
  *!*    * -------------------------------------------------- *
  *!*    FUNCTION INIT
  *!*    * The only allowed purpose of INIT is to call
  *!*    * THIS.AddRequiredField(<fld>) 
  *!*    * THIS.AddDefaultValue(<fld>,<value>)
  *!*    * THIS.SetDecimals(<fld>,<places>)
  *!*    ENDFUNC
  
  * -------------------------------------------------- *
  FUNCTION AddRequiredField(lcFld) 
    THIS.nRequired = THIS.nRequired + 1 
    DIMENSION THIS.aRequired[THIS.nRequired]
    THIS.aRequired[THIS.nRequired] = m.lcFld
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AddDefaultValue(lcFld, lvVal) 
    THIS.nDefaults = THIS.nDefaults + 1 
    DIMENSION THIS.aDefaults[THIS.nDefaults,2]
    THIS.aDefaults[THIS.nDefaults,1] = m.lcFld
    THIS.aDefaults[THIS.nDefaults,2] = m.lvVal
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION IsNewItem(lnItem)
    RETURN m.lnItem > THIS.nOldItems
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION IsChanged(lnItem)
    * Passing no item means check *all* items.
    LOCAL jj, mm, nn
    LOCAL ii, loOld, loNew, laProps[1], llChanged, lcProp
    IF VARTYPE(m.lnItem) = "N"
      STORE m.lnItem TO mm, nn
    ELSE  && all items
      mm = 1
      nn = THIS.nItems
    ENDIF
    llChanged = .F.
    FOR jj = m.mm TO m.nn
      IF THIS.IsNewItem(m.jj)
        llChanged = .T.  && all new items are "changed"
        EXIT
      ENDIF
      loOld = THIS.aOldItems[m.jj]
      loNew = THIS.aItems[m.jj]
      FOR ii = 1 TO AMEMBERS(laProps,m.loOld,1)
        lcProp = laProps[m.ii,1]
        IF NOT EVALUATE("loOld."+m.lcProp) == EVALUATE("loNew."+m.lcProp)
          llChanged = .T.
          EXIT
        ENDIF        
      ENDFOR
      IF m.llChanged
        EXIT
      ENDIF
    ENDFOR
    RETURN m.llChanged
  ENDFUNC  && IsChanged
  * -------------------------------------------------- *
  FUNCTION OnChange(loMember)
    * Hook.
  ENDFUNC  && OnChange
  * -------------------------------------------------- *
  FUNCTION Load
    * Loads either one response or all response for one Issue.
    DO CASE
    CASE NOT ISNULL(THIS.vKeyValue) && ID is specified
      THIS.LoadMain()
    CASE NOT ISNULL(THIS.vParentKeyValue) && Parent ID is specified
      THIS.LoadSiblings()
    OTHERWISE
      ERROR THIS.Class + ".Load: Don't know what to load!"
    ENDCASE
  ENDFUNC  && Load
  * -------------------------------------------------- *
  FUNCTION Valid
    LOCAL ii
    THIS.lValid = .T.
    FOR ii = 1 TO THIS.nItems
      IF THIS.IsChanged(m.ii)
        THIS.lChanged = .T.
        IF NOT THIS.ValidateItem(m.ii)
          THIS.lValid = .F.
        ENDIF
      ENDIF
    ENDFOR
    THIS.AfterValidateItems()
    THIS.lValidated = .T.
    RETURN THIS.lValid
  ENDFUNC && Valid
  * -------------------------------------------------- *
  FUNCTION ValidateItem(lnItem)
    * Setup code:
    PRIVATE poNew, poOld, plNewItem, pnItem
    pnItem = m.lnItem
    poNew = THIS.aItems[m.pnItem]
    plNewItem = THIS.IsNewItem(m.pnItem)
    IF NOT m.plNewItem
      poOld = THIS.aOldItems[m.pnItem]
    ENDIF
    * Template Method pattern:
    THIS.CheckRequiredFields(m.lnItem)
    THIS.ApplyBusinessRules(m.lnItem)
    * NOTE: Required fields represent pure
    *  failures when empty, whereas some business
    *  rules can manipulate data without necessarily
    *  signifying an invalid result.
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION ApplyBusinessRules(lnItem)
    * This is meant as a hook for subclassing.
    * You can either fill in values or raise validation
    * "errors". The latter should be done by calling
    * THIS.AddValidationMessage(). If you encounter
    * serious problems requiring aborting, you can even
    * raise a real error via the ERROR <cMsg> command.
    *
    * To talk to the data, refer to 
    * THIS.aItems[m.lnItem] for the changed values
    * and THIS.aOldItems[m.lnItem] for the original
    * values. Each is just a SCATTER'd object, so you
    * can address any field directly as a property.
    *
    * Examples:
    * 1) Filling in a calculated field:
    *    WITH THIS.aItems[m.lnItem]
    *      .Area = .Width * .Length
    *    ENDWITH
    * 2) Raising a validation error:
    *    WITH THIS.aItems[m.lnItem]
    *      IF .Quantity <= 0
    *        THIS.AddValidationMessage("Quantity cannot be negative.")
    *      ENDIF
    *    ENDWITH
    * 3) Checking a rule only if data was changed (expensive checks):
    *    * Setup code:
    *    LOCAL loNew, loOld, llNewItem
    *    loNew = THIS.aItems[m.lnItem]
    *    llNewItem = THIS.IsNewItem(m.lnItem)
    *    IF NOT m.llNewItem
    *      loOld = THIS.aOldItems[m.lnItem]
    *    ENDIF
    *    IF m.llNewItem OR NOT (loNew.Foreign==loOld.Foreign)
    *      IF NOT < LookupMethodOrFunction(loNew.Foreign) >
    *        THIS.AddValidationMessage("Failed lookup check.")
    *      ENDIF
    *    ENDIF
    * Notes:
    *  - Any rules as simple as required fields or
    *  default values should be handled by the automatic 
    *  array-based techniques, using AddDefaultValue() and
    *  AddRequiredField() instead of using this method.
    *
    *  - Multi-record rules within one table should be applied
    *  at the AfterValidateItems() hook.
    *
    *  - Multi-table rules should be applied at the 
    *  AfterValidateMembers() hook of the parent composite
    *  class.
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION CheckRequiredFields(lnItem)
    IF VARTYPE(THIS.aRequired[1])<>"C"
      RETURN .T.  && no required fields
    ENDIF
    LOCAL lcField, loData
    loData = THIS.aItems[m.lnItem]
    FOR EACH lcField IN THIS.aRequired
      IF EMPTY(loData.&lcField)
        THIS.AddValidationMessage('Required field "' + m.lcField + ;
          '" is empty.')
      ENDIF
    ENDFOR
  ENDFUNC  && CheckRequiredFields
  * -------------------------------------------------- *
  FUNCTION AfterValidateItems
  * -------------------------------------------------- *
  FUNCTION AddValidationMessage
    LPARAMETER lcMessage
    THIS.lValid = .F.
    THIS.nInvalidCount = THIS.nInvalidCount + 1
    THIS.cValidationMessage = THIS.cValidationMessage + ;
      m.lcMessage + CHR(13) + CHR(10)
  ENDFUNC  && AddValidationMessage
  * -------------------------------------------------- *
  FUNCTION AddResultMessage
    LPARAMETER lcMessage
    THIS.cResultMessage = THIS.cResultMessage + ;
      m.lcMessage + CHR(13) + CHR(10)
  ENDFUNC  
  * -------------------------------------------------- *
  FUNCTION Save
    IF NOT THIS.lValidated
      IF THIS.lValidateOnSave && not preferred
        THIS.Valid()
        IF THIS.nInvalidCount > 0
          ERROR "Validation errors occurred while attempting to save!"
          * Need a better approach here.
        ENDIF
      ELSE
        ERROR "Data has not been validated. Saving not allowed!"
      ENDIF
    ENDIF
    IF NOT THIS.BeforeSave()
      RETURN
    ENDIF
    FOR ii = 1 TO THIS.nItems
      IF THIS.IsChanged(m.ii)
        THIS.SaveItem(m.ii)
      ENDIF
    ENDFOR
    THIS.AfterSave()
  ENDFUNC  && Save
  * -------------------------------------------------- *
  FUNCTION BeforeSave
  * -------------------------------------------------- *
  FUNCTION SaveItem(lnItem)
    LOCAL lcErrMsg, loItem
    loItem = THIS.aItems[m.lnItem]
    IF THIS.nDataMode = 0
      IF THIS.lDeleteMe
        IF THIS.IsNewItem(m.lnItem)
        ELSE && no need to delete a new item
          THIS.DeleteItem(m.lnItem)
        ENDIF
      ELSE
        IF THIS.IsNewItem(m.lnItem)
          THIS.AssignKeys(m.lnItem)
          APPEND BLANK
        ELSE  && existing record--find it first
          LOCAL lcKey, lvKeyVal, lcEval
          lcKey = THIS.cKeyExpr
          lcEval = "loItem." + STRTRAN(m.lcKey, "+", "+loItem.")
          lvKeyVal = EVALUATE(m.lcEval)
          LOCATE FOR &lcKey = m.lvKeyVal
          IF NOT FOUND()
            lcErrMsg = THIS.cTableName + " record " + TRANSFORM(THIS.vKeyValue) + " not found!"
          ENDIF
        ENDIF
        IF EMPTY(m.lcErrMsg)
          THIS.TimestampItem(m.lnItem)
          IF RLOCK()
            GATHER MEMO NAME THIS.aItems[m.lnItem]
            UNLOCK
          ELSE
            lcErrMsg = THIS.cTableName + " record " + TRANSFORM(THIS.vKeyValue) + ;
              " could not be locked!"
          ENDIF
        ENDIF
      ENDIF
    ELSE
      lcErrMsg = "Unknown data mode."
    ENDIF
    IF EMPTY( m.lcErrMsg)
      RETURN .T.
    ELSE
      ERROR m.lcErrMsg
      RETURN .F.  && as if
    ENDIF
  ENDFUNC  && SaveItem
  * -------------------------------------------------- *
  FUNCTION DeleteItem(lnItem)
    * Don't presume deleting is a standard operation.
    ERROR PROGRAM() + " must be defined in subclass."
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterSave
  * -------------------------------------------------- *
  *!*    FUNCTION AssignKeys(lnItem)
  *!*      * Called by SaveItem() for each new item.
  *!*      ERROR PROGRAM() + " must be implemented in subclass."
  *!*    ENDFUNC  && AssignKeys
  * -------------------------------------------------- *
  FUNCTION Add(nn)
    * Adds nn new data objects to the collection. (Does
    * not save at this time!)
    nn = IIF( EMPTY(m.nn), 1, INT(m.nn))
    LOCAL ii
    DIMENSION THIS.aItems[THIS.nItems + m.nn]
    FOR ii = 1 TO m.nn
      THIS.nItems = THIS.nItems + 1 
      THIS.aItems[THIS.nItems]=THIS.GetEmptyRecord()
      THIS.nActiveItem = THIS.nItems
      THIS.SetDefaults(THIS.nActiveItem)
    ENDFOR
  ENDFUNC && Add
  * -------------------------------------------------- *
  FUNCTION SetDefaults(lnItem)
    IF THIS.nDefaults > 0
      LOCAL ii, loData, lcField
      loData = THIS.aItems[m.lnItem]
      FOR ii = 1 TO THIS.nDefaults
        lcField = THIS.aDefaults[m.ii,1]
        STORE THIS.aDefaults[m.ii,2] TO loData.&lcField
      ENDFOR
    ENDIF
    THIS.AfterSetDefaults(m.lnItem)
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION AfterSetDefaults(lnItem)
  * -------------------------------------------------- *
ENDDEFINE  && L7Biz

*** ================================================== ***
DEFINE CLASS L7CompositeBiz AS CUSTOM
  nDataMode = 0     && local VFP data
  lAdding = .F.
  vKeyValue = NULL
  dDate = {}
  cTime = ""
  lChanged = .F.
  lValidated = .F.
  lValid = NULL
  lValidateOnSave = .F.
  nInvalidCount = 0
  cValidationMessage = ""
  cResultMessage = ""
  nSubscriptions = 0
  DIMENSION aSubscriptions[1, 2]
  * -------------------------------------------------- *
  FUNCTION dDate_ACCESS
    IF EMPTY( THIS.dDate)
      THIS.dDate = DATE()
    ENDIF
    RETURN THIS.dDate
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION cTime_ACCESS
    IF EMPTY( THIS.cTime)
      THIS.cTime = TIME()
    ENDIF
    RETURN THIS.cTime
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION Load
  ENDFUNC  && Load
  * -------------------------------------------------- *
  FUNCTION Subscribe(loMember, lcTable)
    THIS.nSubscriptions = THIS.nSubscriptions + 1 
    DIMENSION THIS.aSubscriptions[THIS.nSubscriptions, 2]
    THIS.aSubscriptions[THIS.nSubscriptions, 1] = m.loMember
    THIS.aSubscriptions[THIS.nSubscriptions, 2] = m.lcTable
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION NotifySubscribers()
    LOCAL ii, loMember, lcTable, llChecked, llChanged
    FOR EACH loControl IN THIS.Controls
      lcTable = loControl.cTableName
      llChecked = .F.
      llChanged = .F.
      FOR ii = 1 TO THIS.nSubscriptions
        IF m.lcTable == THIS.aSubscriptions[m.ii, 2]
          IF NOT m.llChecked
            llChanged = loControl.IsChanged()
            llChecked = .T.
          ENDIF
          IF m.llChanged
            THIS.aSubscriptions[m.ii,1].onChange(m.loControl)
          ENDIF
        ENDIF
      ENDFOR
    ENDFOR
  ENDFUNC  && NotifySubscribers
  * -------------------------------------------------- *
  FUNCTION BeforeValid
  * -------------------------------------------------- *
  FUNCTION Valid
    IF NOT THIS.BeforeValid() && composite-level hook
      THIS.lValid = .F.
      RETURN .F.
    ENDIF
    LOCAL ii, loControl
    * First enable notification to other members of changes:
    THIS.NotifySubscribers()
    * Now check validation:
    THIS.lValid = .T.
    FOR EACH loControl IN THIS.Controls
      IF NOT loControl.Valid()
        THIS.lValid = .F.
        THIS.nInvalidCount = THIS.nInvalidCount + ;
          loControl.nInvalidCount
        THIS.cValidationMessage = THIS.cValidationMessage + ;
          loControl.cValidationMessage
      ENDIF
      IF loControl.lChanged
        THIS.lChanged = .T.  && something had changed
      ENDIF
    ENDFOR
    THIS.AfterValidateMembers()
    THIS.lValidated = .T.
    RETURN THIS.lValid
  ENDFUNC  && Valid
  * -------------------------------------------------- *
  FUNCTION AfterValidateMembers
  * -------------------------------------------------- *
  FUNCTION AddResultMessage(lcMessage)
    THIS.cResultMessage = THIS.cResultMessage + m.lcMessage + CHR(13) + CHR(10)
  ENDFUNC
  * -------------------------------------------------- *
  FUNCTION Save
    IF NOT THIS.lValidated
      IF THIS.lValidateOnSave && not preferred
        THIS.Valid()
      ELSE
        ERROR "Data has not been validated. Saving not allowed!"
      ENDIF
    ENDIF
    IF NOT THIS.lValid 
      ERROR "Validation errors occurred while attempting to save!"
      * Need a better approach here.
    ENDIF
    IF NOT THIS.lChanged
      THIS.AddResultMessage( "No changes were noted.")
    ELSE
      FOR EACH loControl IN THIS.Controls
        loControl.Save()
        IF NOT EMPTY(loControl.cResultMessage)
          THIS.AddResultMessage( loControl.cResultMessage)
        ENDIF
      ENDFOR
      ** THIS.AddResultMessage( "Changes were saved.")
    ENDIF
  ENDFUNC  && Save
  * -------------------------------------------------- *
ENDDEFINE  && L7CompositeBiz

#if .f.
01/22/2003 - fixed validateOnSave() bug
#endif
