* L7ShowData.PRG
*
* Includes:
*
*    FUNCTION L7ShowRecord()
*    FUNCTION L7ShowObject()
*    FUNCTION L7ShowProgramStack()
*    FUNCTION L7Memory()
*    FUNCTION L7WorkAreas()

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


#UNDEF CRLF
#DEFINE CRLF CHR(13) + CHR(10)
#DEFINE L7_IS_VFP_7 7 <= VAL( SUBSTR( VERSION(),ATC("FoxPro", VERSION()) + 7, 2))

** #IF NOT L7_IS_VFP_7
EXTERNAL ARRAY ASTACKINFO, ASESSIONS
** #ENDIF

* --------------------------------------------------------- *
FUNCTION L7ShowException(loExc, lcTitle)
  * TO DO: Customize later.
  RETURN L7ShowObject(m.loExc, EVL(m.lcTitle, "Exception Object"))
ENDFUNC
* --------------------------------------------------------- *
FUNCTION L7ShowRecord
  *    Author: J. Randy Pearson, Cycla Corp.
  * Copyright: 2002 by Cycla Corp.
  *   License: Free-ware. Sale or publication prohibited.
  LPARAMETERS lcTitle, lcAlias, lcAttributes
  * Pass a .T. for no title, a string for a specific title, 
  * and no parameter or .F. for self-generated title.
  IF EMPTY( m.lcAlias)
    lcALias = ALIAS()
  ENDIF
  IF VARTYPE( lcTitle) = "L"
  	IF m.lcTitle
  		lcTitle = ""
  	ELSE
  		lcTitle = m.lcALias + " Record " + TRANSFORM( RECNO(m.lcAlias)) + ;
  			" of " + TRANSFORM( RECCOUNT(m.lcALias))
  	ENDIF
  ENDIF
  lcAttributes = IIF( EMPTY( m.lcAttributes), "", m.lcAttributes)
  LOCAL lcText, lcFieldText, lnFields, ii
  lnFields = FCOUNT(m.lcAlias)
  IF m.lnFields = 0
  	RETURN "<P><B>No data table selected [L7ShowRecord].</B>"
  ENDIF
  lcText = []
  lcText = m.lcText + ;
    [<a name="] + m.lcAlias + [Table] + TRANSFORM( RECNO(m.lcAlias)) + ["></a>] + ;
    [<table align=center] + ;
    IIF( [class=] $ LOWER( m.lcAttributes), [], [ class="DebugInfo"]) + ;
    IIF( EMPTY( m.lcAttributes), [], [ ] + m.lcAttributes) + [>] + CHR(13) + CHR(10)
  IF NOT EMPTY( m.lcTitle)
  	lcText = m.lcText + [<tr><th class="DebugInfoSectionHeading" colspan="2" align=center>] + ;
  		m.lcTitle + [</th></tr>] + CHR(13) + CHR(10)
  ENDIF
  FOR ii = 1 TO m.lnFields
  	lcFieldText = [<tr valign=top><th width="25%" align=right>] + ;
  		PROPER( STRTRAN( FIELD( m.ii, m.lcAlias), "_", " ")) + [:</th>] + ;
  		[<TD>] + ;
  		TRANSFORM( EVAL( m.lcALias + "." + FIELD( m.ii, m.lcALias))) + [</td></tr>]
  	lcText = m.lcText + m.lcFieldText  + CHR(13) + CHR(10)
  ENDFOR
  lcText = m.lcText + [</table>] + CHR(13) + CHR(10)
  RETURN m.lcText
ENDFUNC  && L7ShowRecord

* --------------------------------------------------------- *
FUNCTION L7ShowArray
  *    Author: J. Randy Pearson, Cycla Corp.
  * Copyright: 2002 by Cycla Corp.
  *   License: Free-ware. Sale or publication prohibited.
  LPARAMETERS laArray, lcTitle, lcAttributes
  EXTERNAL ARRAY laArray 
  IF TYPE("laArray[1]") = 'U'
    RETURN "<P><B>No array passed [L7ShowArray].</B>"
  ENDIF
  lcAttributes = IIF( EMPTY( m.lcAttributes), "", m.lcAttributes)

  LOCAL lnRows, lnCols, ii, jj
  lnRows = ALEN( laArray, 1)
  lnCols = ALEN( laArray, 2)

  LOCAL lcText, lcRowText, lcItemText, lcItemType
  lcText = []
  lcText = m.lcText + [<table border=1 align=center] + ;
    IIF( [class=] $ LOWER( m.lcAttributes), [], [ class="DebugInfo"]) + ;
    IIF( EMPTY( m.lcAttributes), [], [ ] + m.lcAttributes) + [>] + CHR(13) + CHR(10)
  IF NOT EMPTY( m.lcTitle)
    lcText = m.lcText + [<tr><th colspan=2 class="DebugInfoSectionHeading">] + ;
      m.lcTitle + [</td></th>] + CHR(13) + CHR(10)
  ENDIF
  FOR ii = 1 TO m.lnRows
    lcRowText = [<tr>] + CHR(13) + CHR(10)
    FOR jj = 1 TO m.lnCols
      lvVal = laArray[m.ii, m.jj]
      lcItemType = VARTYPE(m.lvVal)
      DO CASE
      CASE m.lcItemType = "C"
        lcItemText = [<pre>] + m.lvVal + [</pre>]
      CASE m.lcItemType $ "NIYBD"
        lcItemText = ALLTRIM(PADR(m.lvVal,40))
      OTHERWISE
        lcItemText = TRANSFORM( m.lvVal)
      ENDCASE
      lcRowText = lcRowText + [<td>] + m.lcItemText + [</td>] + CHR(13) + CHR(10)
    ENDFOR
    lcText = m.lcText + m.lcRowText + [</tr>] + CHR(13) + CHR(10)
  ENDFOR
  lcText = m.lcText + [</table>] + CHR(13) + CHR(10)
  RETURN m.lcText
ENDFUNC  && L7ShowArray

* --------------------------------------------------------- *
FUNCTION L7ShowCollection
  *    Author: J. Randy Pearson, Cycla Corp.
  * Copyright: 2010 by Cycla Corp.
  *   License: Free-ware. Sale or publication prohibited.
  LPARAMETERS loCol, lcTitle, lcAttributes
  lcAttributes = IIF( EMPTY( m.lcAttributes), "", m.lcAttributes)

  LOCAL lcText, ii, lcKey, lvVal, lcRowText
  lcText = []
  lcText = m.lcText + [<table border=1 align=center] + ;
    IIF( [class=] $ LOWER( m.lcAttributes), [], [ class="DebugInfo"]) + ;
    IIF( EMPTY( m.lcAttributes), [], [ ] + m.lcAttributes) + [>] + CHR(13) + CHR(10)
  IF NOT EMPTY( m.lcTitle)
    lcText = m.lcText + [<tr><th colspan=2 class="DebugInfoSectionHeading">] + ;
      m.lcTitle + [</td></th>] + CHR(13) + CHR(10)
  ENDIF
  FOR ii = 1 TO loCol.Count
    lcKey = loCol.getkey(m.ii)
    lvVal = loCol.item[m.ii]
    do case
    case isnull(m.lvVal)
      lcVal = ".NULL."
    case vartype(m.lvVal) = "O"
      lcVal = "(Object)" + iif(pemstatus(m.lvVal, "Class", 5), m.lvVal.Class, "")
    otherwise
      lcVal = left(transform(m.lvVal), 255)
      lcVal = chrtran(m.lcVal, '@!$#%&()[]{}', '____________')
    endcase
    lcRowText = textmerge([<tr><td><<m.lcKey>>:</td><td><<m.lcVal>></td></tr>]) + CHR(13) + CHR(10)
    lcText = m.lcText + m.lcRowText 
  ENDFOR
  lcText = m.lcText + [</table>] + CHR(13) + CHR(10)
  RETURN m.lcText
ENDFUNC  && L7ShowCollection

* --------------------------------------------------------- *
function L7ShowCOMPOBJ(toObj1, toObj2, tcTitle, toOptions)
  * Show 2 objects compared.
  local loDelta, loComp, loRender, lcRet, lcComp
  loDelta = createobject("L7ShowCOMPOBJ_Comparer")
  loComp = loDelta.Compare(m.toObj1, m.toObj2, m.toOptions)
  loRender = createobject("L7ShowCOMPOBJ_HTMLRenderer")
  lcComp = loRender.Render(m.loComp, m.toOptions)

  if empty(m.lcComp)
    lcRet = [<div class="DebugInfo"><p>Objects property values all match.</p></div>] + CRLF
  else
    lcRet = ;
      [<table border="1" align="center" class="DebugInfo">] + CRLF + ;
      [<tr><th colspan="3" class="DebugInfoSectionHeading">] + evl(m.tcTitle, "Object Comparison") + [</td></th>] + CRLF 

    lcRet = lcRet + ;
      [<tr><th>Property</th>] + ;
      [<th>] + iif(vartype(toOptions) = "O" and pemstatus(toOptions, "Heading1", 5), toOptions.Heading1, "Object 1") + [</th>] + CRLF + ;
      [<th>] + iif(vartype(toOptions) = "O" and pemstatus(toOptions, "Heading2", 5), toOptions.Heading2, "Object 2") + [</th>] + CRLF + ;
      [</tr>] + CRLF      

    lcRet = lcRet + m.lcComp + CRLF + [</table>] + CRLF
  endif 

  return m.lcRet
endfunc && L7ShowCOMPOBJ
* --------------------------------------------------------- *
function L7ShowCOMPOBJ_GetObject
  local loRet
  loRet = createobject("Empty")
  addproperty(loRet, "Name", null)
  addproperty(loRet, "Type1", null)
  addproperty(loRet, "Type2", null)
  addproperty(loRet, "Value1", null)
  addproperty(loRet, "Value2", null)
  addproperty(loRet, "Equal", .f.)
  return m.loRet
endfunc 

*** ===================================================== ***
define class L7ShowCOMPOBJ_Comparer as Custom
  * --------------------------------------------------------- *
  function compare(toObj1, toObj2, toOptions)
    local laProps[1], lnProps, lcName, ii, loRet, loItem, lnLen, laArr[1], lnArrItem, lvArrItem
    loRet = createobject("Collection")  && return a collection of prop-level comparison data
    
    * Process 1st object:
    lnProps = amembers(laProps, m.toObj1, 0) && 0 = properties only in 1-D array
    for ii = 1 to m.lnProps
      lcName = laProps[m.ii]
      loItem = L7ShowCOMPOBJ_GetObject()
      loRet.add(m.loItem, m.lcName)
      loItem.Name = laProps[m.ii]
      loItem.Type1 = type('m.toObj1.' + m.lcName, 1) && A = array, C = collection, else U
      do case
      case loItem.Type1 = "U"  && plain property
        loItem.Value1 = evaluate('m.toObj1.' + m.lcName) 
        if vartype(loItem.Value1) = "O" and !pemstatus(loItem.value1, 'class', 5) && an object based on Empty, expand it
          loItem.Value1 = L7JsonSerialize(loItem.Value1)
        endif

      case loItem.Type1 = "A"  && array 
        lnLen = alen(m.toObj1.&lcName)
        loItem.Value1 = []
        for lnArrItem = 1 to m.lnLen
          lvArrItem = m.toObj1.&lcName[m.lnArrItem]
          loItem.Value1 = loItem.Value1 + transform(m.lvArrItem) + [<br/>]
        next
          
        *!*          acopy(m.toObj1.&lcName, laArr)
        *!*          loItem.Value1 = L7JsonSerialize(@laArr)  && '(Array with ' + transform(m.lnLen) + ' items)'

      case loItem.Type1 = "C"  && collection - not compared for now
        lnLen = eval("m.toObj1." + m.lcName + ".count")
        loItem.Value1 = L7JsonSerialize(m.toObj1.&lcName)  && '(Collection with ' + transform(m.lnLen) + ' items)'

      endcase 
    next 

    * Process 2nd object (more complex):
    dimension laProps[1]  && truncate
    lnProps = amembers(laProps, m.toObj2, 0)
    for ii = 1 to m.lnProps
      lcName = laProps[m.ii]
      llFound = loRet.getkey(m.lcName) > 0 
      if m.llFound && prop existed in 1st object
        loItem = loRet.item(m.lcName)
      else  && prop only in 2nd object, need to add an item
        loItem = L7ShowCOMPOBJ_GetObject()
        loItem.Name = m.lcName
        loRet.add(m.loItem, m.lcName)
      endif 
      ** loItem.Value2 = evaluate('m.toObj2.' + m.lcName) 

* [DRY issues introduced. Resolve if updated to compare arrays and collections...]
      loItem.Type2 = type('m.toObj2.' + m.lcName, 1) && A = array, C = collection, else U
      do case
      case loItem.Type2 = "U"  && plain property
        loItem.Value2 = evaluate('m.toObj2.' + m.lcName) 
        if vartype(loItem.Value2) = "O" and !pemstatus(loItem.value2, 'class', 5) && an object based on Empty, expand it
          loItem.Value2 = L7JsonSerialize(loItem.Value2)
        endif

      case loItem.Type2 = "A"  && array - not compared for now
        lnLen = alen(m.toObj2.&lcName)
        loItem.Value2 = []
        for lnArrItem = 1 to m.lnLen
          lvArrItem = m.toObj2.&lcName[m.lnArrItem]
          loItem.Value2 = loItem.Value2 + transform(m.lvArrItem) + [<br/>]
        next

      case loItem.Type2 = "C"  && collection - not compared for now
        lnLen = eval("m.toObj2." + m.lcName + ".count")
        loItem.Value2 = L7JsonSerialize(m.toObj2.&lcName) && '(Collection with ' + transform(m.lnLen) + ' items, not compared)'
      endcase 

      loItem.Equal = ;
        (isnull(loItem.Value1) and isnull(loItem.Value2)) ; && for this purpose, null == null
        or ;
        (!isnull(loItem.Value1) and !isnull(loItem.Value2) ;
          and loItem.Type1 $ "UAC" and loItem.Type2 $ "UAC" ;  
          and vartype(loItem.Value1) = vartype(loItem.Value2) ;
          and vartype(loItem.Value1) <> 'O' ;
          and loItem.Value1 == loItem.Value2 )
    next 
    
    return m.loRet && something else will decide use (render, etc.)
  endfunc 
enddefine && L7ShowCOMPOBJ_Comparer 

*** ===================================================== ***
define class L7ShowCOMPOBJ_HTMLRenderer as Custom
  * --------------------------------------------------------- *
  function render(toComp, toOptions)
    local lcRet, loItem, lcStr, lcStyle, lcTHStyle, lcValue1, lcValue2
    lcRet = ""
    for each loItem in m.toComp
      if loItem.Equal
        * loop && could do something here to simplify output -- note some items (keys, timestamps) may benefit from being shown
        * even if equal. This argues for passing in various options, making this more complex...
      endif 
      * 06/01/2010: occasional "Data type mismatch" error on this line:
      * lcStr = textmerge([<tr style="<<iif(m.loItem.Equal,'color: #333; background-color: #ccc;','color: #000; background-color: #fff;')>>"><th><<m.loItem.Name>></th><td><<m.loItem.Value1>></td><td><<m.loItem.Value2>></td></tr>])
      lcStyle = iif(m.loItem.Equal,'color: #333; background-color: #ccc;','color: #000; background-color: #fff;')
      lcTHStyle = 'font-weight: normal; font-variant: small-caps; font-size: x-small;'
      lcValue1 = iif(vartype(m.loItem.Value1) = 'O', '(Object)', m.loItem.Value1)
      lcValue2 = iif(vartype(m.loItem.Value2) = 'O', '(Object)', m.loItem.Value2)
      lcStr = textmerge([<tr style="<<m.lcStyle>>"><th style="<<m.lcTHStyle>>"><<m.loItem.Name>></th><td><<m.lcValue1>></td><td><<m.lcValue2>></td></tr>])
      lcRet = m.lcRet + m.lcStr
    next loItem
    return m.lcRet
  endfunc
enddefine  && L7ShowCOMPOBJ_HTMLRenderer 

* --------------------------------------------------------- *
FUNCTION L7ShowObject(loObject, lcTitle, lcAttributes, lcExcludeProps, llExcludeNulls)
  *    Author: J. Randy Pearson, Cycla Corp.
  * Copyright: 2002 by Cycla Corp.
  *   License: Free-ware. Sale or publication prohibited.
  IF VARTYPE( m.loObject) <> 'O'
  	RETURN "<p><b>No object passed [L7ShowObject].</b>"
  ENDIF
  lcAttributes = IIF( EMPTY( m.lcAttributes), "", m.lcAttributes)
  lcExcludeProps = IIF( EMPTY( m.lcExcludeProps), "", ;
    [,] + LOWER( STRTRAN( m.lcExcludeProps, [ ])) + [,])

  LOCAL lcObjName
  lcObjName = SYS(1272, m.loObject)

  * Pass a .T. for no title, a string for a specific title, 
  * and no parameter or .F. for self-generated title.
  IF VARTYPE( lcTitle) = "L"
  	IF m.lcTitle
  		lcTitle = ""
  	ELSE
  		lcTitle = IIF( m.lcObjName = "empty", "Data Object Properties", ;
  			"Object " + m.lcObjName + " Properties" )
  	ENDIF
  ENDIF
  LOCAL loExc, lcText, lcFieldText, lvValue, lnProps, ii, lcType, lcType1, lcProp, llIsArray, llIsNull, lnArrayRows, lnArrayCols
TRY
  LOCAL ARRAY laProps[1]
  lnProps = AMEMBERS( laProps, m.loObject, 0 )
  lcText = []
  IF VARTYPE( loObject.Name) = "C"
    lcText = m.lcText + [<a name="] + loObject.Name + [Object"></a>]
  ELSE  && scatter name objects don't have a name
    lcText = m.lcText + [<a name="] + m.lcObjName + [Object"></a>]
  ENDIF
  lcText = m.lcText + [<table] + ;
    IIF( [border=] $ LOWER( m.lcAttributes), [], [ border="1"]) + ;
    IIF( [class=] $ LOWER( m.lcAttributes), [], [ class="DebugInfo"]) + ;
    IIF( EMPTY( m.lcAttributes), [], [ ] + m.lcAttributes) + [>] + CHR(13) + CHR(10)
  IF NOT EMPTY( m.lcTitle)
  	lcText = m.lcText + [<tr><th colspan="2" class="DebugInfoSectionHeading">] + ;
  		m.lcTitle + [</td></th>] + CHR(13) + CHR(10)
  ENDIF
  FOR ii = 1 TO m.lnProps
    llIsNull = .F.
    lcType1 = ""
    lcProp = laProps[ m.ii]
    IF [,] + lower(m.lcProp) + [,] $ m.lcExcludeProps
      LOOP
    ENDIF
  	lcType = TYPE( 'loObject.' + m.lcProp )
    if !m.lcType = 'U'
      lcType1 = type('m.loObject.' + m.lcProp, 1)  && A = array, C = collection, else U
      do case
      case m.lcType1 = 'U'
        lvValue = evaluate('m.loObject.' + m.lcProp) 
        llIsNull = isnull(m.lvValue)
      
      case m.lcType1 = "A"  && array
        lnLen = alen(m.loObject.&lcProp)
        lvValue = []
        for lnArrItem = 1 to m.lnLen
          lvArrItem = m.loObject.&lcProp[m.lnArrItem]
          lvValue = m.lvValue + transform(m.lvArrItem) + [<br/>]
        next

      case m.lcType1 = "C"  && collection 
        lvValue = L7JsonSerialize(m.loObject.&lcProp) 
      
      endcase
      
        *!*        llIsArray = m.lcType1 = 'A'  && TYPE('ALEN(loObject.' + laProps[ m.ii] + ')') = "N"
        *!*        IF m.llIsArray
        *!*          lnArrayRows = EVALUATE('ALEN(loObject.' + laProps[ m.ii] + ',1)')
        *!*          lnArrayCols = EVALUATE('ALEN(loObject.' + laProps[ m.ii] + ',2)')
        *!*        ELSE
        *!*          lvValue = EVALUATE('loObject.' + m.lcProp )
        *!*          llIsNull = ISNULL(m.lvValue)
        *!*        ENDIF
    endif   
    if m.llIsNull and m.llExcludeNulls
      loop
    endif 
  	do case 
    case m.lcType = "U"
      lcFieldText = [(not defined)]

    case m.llIsNull
      lcFieldText = [.NULL.]

  	case inlist(m.lcType1, 'A', 'C')  && serialized array or collection 
      lcFieldText = m.lvValue
      
    case m.lcType = "O" && object, so serialize it
  		lcFieldText = L7JsonSerialize(m.lvValue)

    case m.lcType = "L"
      lcFieldText = IIF(m.lvValue, "YES", "no") && IIF(m.lvValue, ".TRUE.", ".FALSE.")

    case m.lcType = "C"
      lcFieldText = m.lvValue

      * Strip HTML tags: [[why???
      
      lcFieldText = STRTRAN( m.lcFieldText, "<", "&lt;")
      lcFieldText = STRTRAN( m.lcFieldText, ">", "&gt;")
      lcFieldText = STRTRAN( m.lcFieldText, '"', "&quot;")

  	otherwise && other types like numeric or date
  		lcFieldText = TRANSFORM(m.lvValue)
      
  	endcase 
    
  	lcFieldText = [<tr valign=top><th style="font: normal small-caps medium xx-small; width: 25%; text-align: right;">] + ;
  		proper(chrtran(m.lcProp, "_", " ")) + ;
      [:</th>] + ;
      [<td style="font-size: small;">] + ;
  		m.lcFieldText + [</td></tr>]
  		
  	lcText = m.lcText + m.lcFieldText + CHR(13) + CHR(10)
  ENDFOR
  lcText = m.lcText + [</table>] + CHR(13) + CHR(10)
CATCH TO loExc
  lcText = '<h2>Error: ' + loExc.Message + ;
    ' [function L7ShowObject + line ' + TRANSFORM(loExc.LineNo) + ']</h2>' + ;
    L7ShowStackInfo()
ENDTRY

  RETURN m.lcText
ENDFUNC  && L7ShowObject

* --------------------------------------------------------- *
FUNCTION L7ShowStackInfo( llNoHTML, lcAttributes, lnTruncate)
  *    Author: J. Randy Pearson, Cycla Corp.
  * Copyright: 2002 by Cycla Corp.
  *   License: Free-ware. Sale or publication prohibited.
  LOCAL lcProgStack, lnPointer, lnLevel, lcVarValue
  LOCAL ARRAY laStack[1, 5]
  lnLevel = ASTACKINFO( laStack)
  DO CASE
  CASE EMPTY(m.lnTruncate)
  CASE m.lnTruncate < 0  && -number means levels to truncate
    lnLevel = m.lnLevel + m.lnTruncate
  CASE m.lnTruncate > 0  && +number means level to show
    lnLevel = MIN(m.lnLevel, m.lnTruncate)
  ENDCASE
  lcAttributes = IIF( EMPTY( m.lcAttributes), "", m.lcAttributes)
  IF m.llNoHtml
    lcProgStack = "Program Stack:" + CRLF + CRLF
  ELSE
    lcProgStack = [<a name="ProgramStack"></a>] + ;
      [<table border=1 align=center] + ;
      IIF( [class=] $ LOWER( m.lcAttributes), [], [ class="DebugInfo"]) + ;
      IIF( EMPTY( m.lcAttributes), [], [ ] + m.lcAttributes) + [>] + ;
      [<tr><th colspan=5 class="DebugInfoSectionHeading">] + ;
      [Program Stack</th></tr>] 

    lcProgStack = m.lcProgStack + [<tr>] + ;
      [<th>No.</th>] + ;
      [<th>Object</th>] + ;
      [<th>Module</th>] + ;
      [<th>Line</th>] + ;
      [<th>Code</th>] + ;
      [</tr>] + CRLF
  ENDIF
  FOR lnPointer = 1 TO lnLevel - 1
    IF m.llNoHtml
       lcProgStack = m.lcProgStack + ;
         TRANSFORM(laStack[ m.lnPointer, 1]) + [. ] + ;
         laStack[ m.lnPointer, 3] + ;
         [ (] + TRANSFORM(laStack[ m.lnPointer, 4]) + [)] + CRLF + ;
         [   Line ] + TRANSFORM(laStack[ m.lnPointer, 5]) + [: ] + ;
         ALLTRIM( laStack[ m.lnPointer, 6]) + CRLF
    ELSE
      * Strip HTML tags:
      lcVarValue = laStack[ m.lnPointer, 6]
      lcVarValue = STRTRAN( m.lcVarValue, "<", "&lt;")
      lcVarValue = STRTRAN( m.lcVarValue, ">", "&gt;")
      lcVarValue = STRTRAN( m.lcVarValue, '"', "&quot;")
      lcProgStack = m.lcProgStack + [<tr>] + ;
         [<th>] + TRANSFORM(laStack[ m.lnPointer, 1]) + [. ] + [</th>] + ;
         [<td>] + laStack[ m.lnPointer, 3] + [</td>] + CRLF + ;
         [<td>] + JUSTFNAME( laStack[ m.lnPointer, 4]) + [</td>] + CRLF + ;
         [<td align=right>] + TRANSFORM(laStack[ m.lnPointer, 5]) + [</td>] + CRLF + ;
         [<td>] + m.lcVarValue + [</td>] + CRLF + ;
         [</tr>] + CRLF
    ENDIF
  ENDFOR
  IF NOT m.llNoHtml
    lcProgStack = m.lcProgStack + [</table>] + CRLF
  ENDIF

  RETURN m.lcProgStack
ENDFUNC  && L7ShowStackInfo
* --------------------------------------------------------- *
FUNCTION L7ShowMemory( llNoHTML, llUseFORM)
  *    Author: J. Randy Pearson, Cycla Corp.
  * Copyright: 2002 by Cycla Corp.
  *   License: Free-ware. Sale or publication prohibited.
  LOCAL lcMemory, lcFile, lcStyle, lnAt
  lcFile = ADDBS( SYS(2023)) + FORCEEXT( SYS(3), "TXT")
  LIST MEMORY TO FILE ( m.lcFile) NOCONSOLE
  lcMemory = FILETOSTR( m.lcFile)
  ERASE ( m.lcFile)
  lnAt = AT( "variables defined,", m.lcMemory)
  IF m.lnAt > 6
    lcMemory = LEFT( m.lcMemory, m.lnAt - 6)
  ENDIF
  *!*    lnAt = AT( "Print System Memory Variables", m.lcMemory)
  *!*    IF m.lnAt > 4
  *!*      lcMemory = LEFT( m.lcMemory, m.lnAt - 4)
  *!*    ENDIF
  lcNewShowMemory = L7ParseShowMemory( m.lcMemory )
  RETURN m.lcNewShowMemory
ENDFUNC  && L7ShowMemory
* --------------------------------------------------------- *
FUNCTION L7ParseShowMemory( lcMemory)
  LOCAL laMem[1], lnMem, lcOut, lcStyle, lcLine, lcModule, ;
    lcModOut, lnModCount, lcNewModule, lcModCell, lcVar, lnAt, lnRat, ;
    lcVarScope, lcVarType, lcVarValue, lnLine, lnDelLines
  lcStyle = [ style="font-size: x-small; font-family: monospace;"]
  STORE "" TO lcModule, lcVar
  lnModCount = 0
  * Table Heading:
  lcOut = [<a name="ListMemory"></a>] + ;
    [<table border=1 align=center class="DebugInfo">] + ;
    [<tr><th colspan="5" class="DebugInfoSectionHeading">List Memory</th></tr>] + ;
    CHR(13) + CHR(10) + ;
    [<tr class="DebugInfoShowMemory">] + ;
    [<th>Module</th><th>Variable</th><th>Scope</th><th>Type</th><th>Value</th></tr>] + ;
    CHR(13) + CHR(10)
    
  * Parse to array:
  lnMem = ALINES( laMem, lcMemory)
  
  * Pre-process array, looking for odd line breaks:
  lnOrigLine = -1
  lcLine = ""
  lnDelLines = 0
  lnLine = 1
  DO WHILE lnLine <= m.lnMem - m.lnDelLines
    lcNext = laMem[m.lnLine]
    IF NOT EMPTY(m.lcNext) AND NOT EMPTY(m.lcLine) AND LEFT(m.lcNext, 1) = " "
      lcLine = m.lcLine + " " + ALLTRIM(m.lcNext)
      laMem[m.lnLine - 1] = m.lcLine
      lnDelLines = m.lnDelLines + 1 
      ADEL(laMem, m.lnLine)
    ELSE
      lnLine = m.lnLine + 1
      lcLine = m.lcNext
    ENDIF
  ENDDO
  IF m.lnDelLines > 0
    DIMENSION laMem[m.lnMem - m.lnDelLines]
  ENDIF

  * Actual parsing:
  FOR EACH lcLine IN laMem
    lnAt = AT( " ", m.lcLine)
    IF lnAt <= 1 
      LOOP
    ELSE
      lcVar = LEFT( m.lcLine, m.lnAt - 1)
      lcLine = LTRIM( SUBSTR( m.lcLine, m.lnAt))
    ENDIF
    lnAt = AT( " ", m.lcLine)
    IF lnAt <= 1 
      LOOP
    ELSE
      lcVarScope = LEFT( m.lcLine, m.lnAt - 1)
      IF m.lcVarScope = "Pub"
        lcNewModule = "PUBLIC"
      ENDIF
      lcLine = LTRIM( SUBSTR( m.lcLine, m.lnAt))
    ENDIF
    lcVarType = LEFT( m.lcLine, 1)
    lcLine = SUBSTR( m.lcLine, 3)
    lnRat = RAT( " ", m.lcLine)
    IF m.lcVarScope <> "Pub"
      lcNewModule = SUBSTR( m.lcLine, m.lnRat + 1)
      lcLine = TRIM( LEFT( m.lcLine, m.lnRat))
    ENDIF
    lcVarValue = ALLTRIM( m.lcLine)
    IF NOT m.lcNewModule == m.lcModule
      IF NOT EMPTY( m.lcModule)
        lcModCell = [<td rowspan="] + TRANSFORM( m.lnModCount) + ;
          ["><strong>] + m.lcModule + [</strong></td>] + CHR(13) + CHR(10)
        lcOut = m.lcOut + STUFF( m.lcModOut, AT( ">", m.lcModOut) + 1, 0, m.lcModCell)
      ENDIF
      lcModule = m.lcNewModule 
      lnModCount = 0
      lcModOut = ""
    ENDIF
    lnModCount = m.lnModCount + 1

    * Strip HTML tags:
    lcVarValue = STRTRAN( m.lcVarValue, "<", "&lt;")
    lcVarValue = STRTRAN( m.lcVarValue, ">", "&gt;")
    lcVarValue = STRTRAN( m.lcVarValue, '"', "&quot;")

    lcModOut = m.lcModOut + [<tr class="DebugInfoShowMemory"><td>] + m.lcVar + [</td><td>] + m.lcVarScope + ;
      [</td><td>] + m.lcVarType + [</td><td>] + CHR(13) + CHR(10) + ;
      m.lcVarValue + [</td></tr>] + CHR(13) + CHR(10)
  ENDFOR
  IF NOT EMPTY( m.lcModule)  && get the last one
    lcModCell = [<td rowspan="] + TRANSFORM( m.lnModCount) + ;
      ["><strong>] + m.lcModule + [</strong></td>]
    lcOut = m.lcOut + STUFF( m.lcModOut, AT( ">", m.lcModOut) + 1, 0, m.lcModCell)
  ENDIF
  lcOut = m.lcOut + [</table>] + CHR(13) + CHR(10)
  RETURN m.lcOut
ENDFUNC  && L7ParseShowMemory( lcMemory)
* --------------------------------------------------------- *
FUNCTION L7ShowWorkAreas
  *    Author: J. Randy Pearson, Cycla Corp.
  * Copyright: 2002 by Cycla Corp.
  *   License: Free-ware. Sale or publication prohibited.
  LOCAL lcWA
  lcWA = ""
  IF L7_IS_VFP_7
    LOCAL ARRAY laSess[1]
    LOCAL lnSess, lnSessCount, lnCurrSess, lcSets
    lcWA = [<a name="DataSessions"></a>] + ;
      [<table class="DebugInfo" align="center" border=1 bgcolor="#cccccc">] + ;
      CHR(13) + CHR(10) + ;
      [<tr><th colspan=3 class="DebugInfoSectionHeading">] + ;
      [Data Sessions</th></tr>] + ;
      CHR(13) + CHR(10) + ;
      [<tr bgcolor="#ffcccc"><th>DS</th><th>Env</th><th>Data Session Open Workarea Information</th></tr>] + ;
      CHR(13) + CHR(10)

    lnCurrSess = SET( "DATASESSION")
    lnSessCount = ASESSIONS( laSess)
    FOR lnSess = 1 TO m.lnSessCount
      SET DATASESSION TO laSess[ m.lnSess]
      lcSets = ;
        "REPROCESS&nbsp;=&nbsp;" + TRANSFORM(SET("REPROCESS")) + "<br />" + ; && added 9/1/09
        IIF(SET("EXACT") = "ON", "EXACT&nbsp;is&nbsp;ON!<br />", "") + ;
        IIF(SET("EXCLUSIVE") = "ON", "EXCLUSIVE&nbsp;is&nbsp;ON!<br />", "") + ;
        IIF(SET("ANSI") = "ON", "ANSI&nbsp;is&nbsp;ON!<br />", "") + ;
        IIF(SET("DELETED") = "OFF", "DELETED&nbsp;is&nbsp;OFF.<br />", "") + ;
        IIF(SET("UNIQUE") = "ON", "UNIQUE&nbsp;is&nbsp;ON!<br />", "")
      lcWA = m.lcWA + ;
        [<tr] + IIF( m.lnCurrSess = laSess[ m.lnSess], ;
          [ bgcolor="#ffff99"], []) + [>] + ;
        [<th>] + TRANSFORM( laSess[ m.lnSess]) + [</th>] + CHR(13) + CHR(10) + ;
        [<td>] + m.lcSets + [&nbsp;</td>] + CHR(13) + CHR(10) + ;
        [<td>] + CHR(13) + CHR(10) + ;
        L7ShowWorkAreas_ShowCurrentDataSession() + [</td></tr>] + ;
        CHR(13) + CHR(10)
    ENDFOR
    SET DATASESSION TO m.lnCurrSess
    lcWA = m.lcWA + [</table>] + CHR(13) + CHR(10)

  ELSE  && VFP 6 or earlier
    lcWA = m.lcWA + L7ShowWorkAreas_ShowCurrentDataSession()
  ENDIF
  RETURN m.lcWA
ENDFUNC && L7ShowWorkAreas
* --------------------------------------------------------- *
FUNCTION L7ShowWorkAreas_ShowCurrentDataSession
  LOCAL lcWA, lnTbl, lnTblCount, lcFld1, lnRecno, lnReccount, llRO, lcLockStat, lcAlias, lnArea, llEOF
  lcWA = ""
  LOCAL ARRAY laUsed[1]
  lnTblCount = AUSED( laUsed)
  FOR lnTbl = 1 TO m.lnTblCount
    lcAlias = laUsed[ m.lnTbl, 1] 
    lnArea = laUsed[ m.lnTbl, 2]
    lnRecno = RECNO(m.lcAlias)
    lnReccount = RECCOUNT(m.lcAlias)
    lcFld1 = FIELD(1, m.lcAlias)
    llEOF = m.lnRecno > m.lnReccount
    llRO = ISREADONLY(m.lcAlias)
    IF m.llRO
      lcLockStat = "R-O"
    ELSE
      lcLockStat = IIF(ISFLOCKED(m.lcAlias), "File Locked", ;
        IIF(NOT m.llEOF AND ISRLOCKED(m.lnRecno, m.lcAlias), "Record Locked", "&nbsp;"))
    ENDIF
    IF ISEXCLUSIVE(m.lcAlias)
      lcLockStat = "Exclusive " + m.lcLockStat
    ENDIF
    lcWA = m.lcWA + ;
      [<tr] + ;
        IIF( m.lnArea = SELECT(), [ bgcolor="white"], []) + ;
        [>] + ;
      [<td>] + TRANSFORM(m.lnArea) + [</td>] + ;
      [<td>] + m.lcFld1 + [</td>] + ;
      [<td>] + m.lcAlias + [</td>] + ;
      [<td>] + DBF(m.lcAlias) + [</td>] + ;
      [<td>] + m.lcLockStat + [</td>] + ;
      [<td align="right">] + ;
        IIF(m.llEOF, [EOF()], ;
          TRANSFORM(m.lnRecno, "9,999,999,999") + [</td>]) + ;
      [<td align="right">] + TRANSFORM(m.lnReccount, "9,999,999,999") + [</td>] + ;
      [</tr>] + CHR(13) + CHR(10)
  ENDFOR
  RETURN IIF( EMPTY( m.lcWA), [<p align=center><em>No open work areas.</p>], ;
    [<table border=1>] + ;
    CHR(13) + CHR(10) + ;
    [<tr><th>No</th><th>Alias</th><th>Field #1</th><th>Table</th><th>Lock?</th><th>Record No.</th><th>Record Count</th></tr>] + ;
    CHR(13) + CHR(10) + ;
    m.lcWA + ;
    [</table>] + CHR(13) + CHR(10) )

ENDFUNC && L7ShowWorkAreas_ShowCurrentDataSession
* --------------------------------------------------------- *
FUNCTION L7ShowServerVariables(loRequest)
  * WC request server variables.
  * Parser written by Thomas Gehrke, Paducah, KY.

  IF VARTYPE( loRequest) <> "O" OR VARTYPE( loRequest.cServerVars) <> "C"
    ERROR "Request object was not passed to ShowServerVariables."
  ENDIF
  LOCAL lcLine, lnLines, lcServerVars, lnOldMemo, lnLine, lcLogString
  lcLogString = ""
  lcServerVars = STRTRAN( STRTRAN( URLDecode( m.loRequest.cServerVars), ;
    "HTTP_", CRLF+"HTTP_"), "&", CRLF )
  lnOldMemo = SET( "MEMOWIDTH" )
  SET MEMOWIDTH TO 250
  lnLines = MEMLINES( m.lcServerVars )
  _MLINE = 0
    
  lcLogString = lcLogString + [<A NAME="ServerVariables"></A>] + ;
    [<table border=1 align=center class="DebugInfo">] + ;
    [<tr><th colspan="2" class="DebugInfoSectionHeading">Server Variables</th></tr>] + ;
    CRLF

  LOCAL lcThisLine, lcDelimeter, lcServerVariableRow
  FOR lnLine = 1 TO m.lnLines
    lcThisLine = MLINE( m.lcServerVars, 1, _MLINE )

    IF m.lcThisLine = "ALL_HTTP"
      lcLogString = lcLogString + ;
        [<tr><td colspan="2"><B>ALL_HTTP</B> (Variables previously displayed will not be shown below)</td></tr>]
      lcThisLine  = SUBSTR( lcThisLine, 10 )
    ENDIF
      
    IF NOT EMPTY( m.lcThisLine )
      lcDelimeter = "|"
      DO CASE
      CASE AT( "=" , m.lcThisLine ) + AT( ":" , m.lcThisLine ) = AT( "=" , m.lcThisLine )
        lcDelimeter = "="
      CASE AT( "=" , m.lcThisLine ) + AT( ":" , m.lcThisLine ) = AT( ":" , m.lcThisLine )
        lcDelimeter = ":"
      CASE AT( "=" , m.lcThisLine ) < AT( ":" , m.lcThisLine )
        lcDelimeter = "="
      CASE AT( "=" , m.lcThisLine ) > AT( ":" , m.lcThisLine )
        lcDelimeter = ":"
      ENDCASE
      lcServerVariableRow = [<tr><td><B>] + ;
        STRTRAN( m.lcThisLine, m.lcDelimeter, [</B></td><td>], 1, 1 ) + ;
        [</td></tr>] + CRLF
      IF NOT m.lcServerVariableRow $ m.lcLogString
        lcLogString = lcLogString + [<tr><td><B>] + ;
          STRTRAN( m.lcThisLine, m.lcDelimeter, [</B></td><td>], 1, 1 ) + ;
          [</td></tr>] + CRLF
      ENDIF
    ENDIF
  ENDFOR
  SET MEMOWIDTH TO m.lnOldMemo
  lcLogString = lcLogString + [</table>] 
  RETURN m.lcLogString
ENDFUNC  && L7ShowServerVariables

#if .f.
04/10/2003 - added L7ShowException()
           - renamed L7ShowProgramStack() to L7ShowStackInfo()
#endif
