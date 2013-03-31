* AisLoc.PRG  && Location pages

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ========================================================= ***
define class aisLocPage as aisPage 
  cLoc = ""
  oLoc = null
  lLocRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lLocRequired
      this.cLoc = evl(this.cLoc, this.StripUrl("loc", .f., .t.))
      if empty(this.cLoc)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyLocation()
        if !isnull(this.oLoc)
          * derived parent properties set here
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyLocation(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cFac)
    loData = createobject("AisLocData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cLoc
        this.oLoc = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
enddefine && AisLocPage

*** ========================================================= ***
define class ais_LocList as aisLocPage 
  lLocRequired = .f.
  cSubTitle = "Bridge Locations"
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    with this
      .AddSubMenu("This", "BRIDGE LOCATIONS")
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisLocQuery")
    with loQry
      .execute()
    endwith 
    
    loTbl = createobject("AisTable")
    with loTbl
      loGrp = .AddGroup('Loc_Side', 'Side: ', .t., ["Side: " + Loc_Side])
      
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")

      loCol = .addCursorColumn("Loc_Side", "Side")
      loCol = .addCursorColumn("Loc_No", "No")
      loCol = .addCursorColumn("Loc_H1", "Height-L")
      loCol = .addCursorColumn("Loc_W1", "Width")
      loCol = .addCursorColumn("Loc_H2", "Height-R")
      loCol = .addCursorColumn("Loc_Notes", "Notes", [L7ParseOnView(Loc_Notes)])
      loCol = .addCursorColumn("Loc_Marker", "Marker")
      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine && LocList


*** ===================================================== ***
define class AisLocQuery as L7Query
  cBaseTable = "Location"
  cDefaultFieldList = ;
    "*" 
  nOrderBy = 1
  dimension aOrderBy[ 2, 2]
  aOrderBy[ 1, 1] = "Loc_Side"
  aOrderBy[ 2, 1] = "Loc_No"

  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Loc_Inactive = .F.] 
    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisLocQuery

* end: FAC 

