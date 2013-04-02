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
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    with this
      .AddSubMenu("This", "BRIDGE LOCATIONS")
      .addMenuItem("main\This", 'Bridge Locations', StuffUrl(.cUrlA, 2, "LocList"))
      .addMenuItem("main\This", 'Panel Requirements', StuffUrl(.cUrlA, 2, "LocSumList"))
    endwith 
    dodefault()
    return 
  endfunc 
enddefine && AisLocPage

*** ========================================================= ***
define class ais_LocList as aisLocPage 
  lLocRequired = .f.
  cSubTitle = "Bridge Locations"
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loLocQry, loPlcQry, loTbl, loCol, loGrp
       
    loPlcQry = createobject("AisPlcQuery")
    with loPlcQry
      .cAlias = "PlcQuery_"
      .lJoinPanel = .t.
      .lJoinLocation = .t.
      .execute()
      index on Plc_Loc_FK + Plc_Orientation tag LocOrient 
    endwith 

    loLocQry = createobject("AisLocQuery")
    with loLocQry
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
      loCol = .addCursorColumn("Loc_PK", "Inner<br>Panel", ;
        [iif(seek(Loc_PK + "Inner", "PlcQuery_"), PlcQuery_.Pnl_ID, null)])
      loCol = .addCursorColumn("Loc_PK", "Outer<br>Panel", ;
        [iif(seek(Loc_PK + "Outer", "PlcQuery_"), PlcQuery_.Pnl_ID, null)])
      loCol = .addCursorColumn("Loc_Notes", "Notes", [L7ParseOnView(Loc_Notes)])
      loCol = .addCursorColumn("Loc_Marker", "Marker")
      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine && LocList

*** ========================================================= ***
define class ais_LocSumList as aisLocPage 
  lLocRequired = .f.
  cSubTitle = "Panel Quantities"
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
      .lSkip = .f. && don't count spaces we're skipping 
      
      .lOldEngineBehavior = .t. 
      .AddOrderBy("Loc_W1",, .f.)
      .AddOrderBy("Loc_H1",, .t.)
      .AddOrderBy("Loc_H2",, .t.)
      .nGrouping = 3
      .ClearFields()
      
      .AddFields("Loc_H1, Loc_W1, Loc_H2, count(*) as Count_")
      
      .execute()
    endwith 
    
    loTbl = createobject("AisTable")
    with loTbl
      .cGrandRowClass      = "GrandRow sortbottom"  
      
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")

      loCol = .addCursorColumn("Loc_H1", "Height-L")
      loCol = .addCursorColumn("Loc_W1", "Width")

      loCol = .addCursorColumn("Loc_H2", "Height-R")
      * loCol.cHeadingClass = "nosort" 

      loCol = .addCursorColumn("Count_", "Location<br>Count")
      loCol.nCalcType = L7_CALCTYPE_SUM
      
      loCol = .addCursorColumn("2*Count_", "Panels<br>Needed", [2*Count_])
      loCol.nCalcType = L7_CALCTYPE_SUM
      
      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine && LocSumList

*** ===================================================== ***
define class AisPlcQuery as L7Query
  cBaseTable = "PanelLocation"
  cDefaultFieldList = "Plc_Pnl_FK, Plc_Loc_FK, Plc_Orientation"

  cSide = null
  cOrient = null 

  lJoinPanel = .f. 
  lJoinLocation = .f. 

  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Plc_Inactive = .F.] 

      if .lJoinLocation or !isnull(.cSide)
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Location"
        .aJoins[.nJoins, 2] = "Plc_Loc_FK = Loc_PK"
        .AddFields("Loc_Side, Loc_No")
      endif 

      if .lJoinPanel
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Panel"
        .aJoins[.nJoins, 2] = "Plc_Pnl_FK = Pnl_PK"
        .AddFields("Pnl_ID, Pnl_Stitcher_Art_FK, Pnl_Single_Piece")
      endif 

      if !isnull(.cSide)
        .cWhereClause = .cWhereClause + [ and Loc_Side = '] + padr(this.cSide, THISAPP_LENGTH_SIDE) + [']
      endif 
      if !isnull(.cOrient)
        .cWhereClause = .cWhereClause + [ Plc_Orientation = '] + padr(.cOrient, THISAPP_LENGTH_ORIENTATION ) + [']
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisPlcQuery

*** ===================================================== ***
define class AisLocQuery as L7Query
  cBaseTable = "Location"
  cDefaultFieldList = ;
    "Loc_PK, Loc_ID, Loc_Side, Loc_No, Loc_Old_ID, Loc_Rev_Art_FK, Loc_Rev_Time" ;
      + ", Loc_H1, Loc_W1, Loc_H2, Loc_Skip, Loc_Marker, Loc_Comments, Loc_Notes"

  lSkip = null 
  cSide = null
  
  cOrient = null 
  lHasPanel = null 
  
  nOrderBy = 2
  dimension aOrderBy[ 2, 2]
  aOrderBy[ 1, 1] = "Loc_Side"
  aOrderBy[ 2, 1] = "Loc_No"
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Loc_Inactive = .F.] 

      if !isnull(.lSkip)
        .cWhereClause = .cWhereClause + [ and Loc_Skip = ] + iif(.lSkip, [.t.], [.f.])
      endif 
      if !isnull(.cSide)
        .cWhereClause = .cWhereClause + [ and Loc_Side = '] + padr(.cSide, THISAPP_LENGTH_SIDE) + [']
      endif 
      if !isnull(.lHasPanel)
        .cWhereClause = .cWhereClause + [ and Loc_PK] + iif(.lHasPanel, [ in ], [ not in ]) + ;
          [(select Plc_Loc_FK from PanelLocation] + ;
            [ where !plc_Inactive] + ;
            iif(isnull(.cOrient), [], [ and Plc_Orientation = '] + padr(.cOrient, THISAPP_LENGTH_ORIENTATION ) + [']) + ;
          [)]
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisLocQuery

* end: LOC 

