* AisPnl.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* --------------------------------------------------------- *
function aisCreatePanel(toPce)
  * Create a panel from a "starter" piece. 
  * NOTE: no piece data resides with the panel, instead
  * pieces are connected to their parent panel by FK. 
  local vp_cPnl_PK, loNewRec, loTrans
  vp_cPnl_PK = space(32)
  use V_Panel in select("V_Panel")
  cursorsetprop("Buffering", 5, "V_Panel")
  select V_Panel
  append blank
  replace ;
    Pnl_Single_Piece with toPce.Pce_Whole_Panel ;
    Pnl_Dim_1 with toPce.Pce_Dim_1 ; && initial approx, can free-wheel 
    Pnl_Dim_2 with toPce.Pce_Dim_2 ; &&  ''
    Pnl_Type with toPce.Pce_Type 

  select V_Panel  && UpdateControlSources can alter work area
  StampRec( CurrentUser, Environ.item("appManager.startTime") )
      
  * Now save using a transaction:
  local loTrans, loExc
  
  loTrans = goL7App.CreateTransaction()
  loTrans.AddCursor("V_Panel")

  if !loTrans.Save()  
    error "Error saving panel: " + loTrans.GetErrorInfo()
  endif 
  select V_Panel
  scatter memo name loNewRec 
  return m.loNewRec
endfunc  && aisCreatePanel 

* end 


*** ========================================================= ***
define class aisPnlPage as aisPage 
  cPnl = ""
  oPnl = null
  lPnlRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lPnlRequired
      this.cPnl = evl(this.cPnl, this.StripUrl("pnl", .f., .t.))
      if empty(this.cPnl)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyPanel()
        if !isnull(this.oPnl)
          * derived parent properties set here
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyPanel(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cPnl)
    loData = createobject("AisPnlData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cPnl
        this.oPnl = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
enddefine && AisPnlPage

*** ========================================================= ***
define class ais_PnlList as aisPnlPage 
  lPnlRequired = .f.
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisPnlQuery")
    with loQry
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "PnlHome"), "PnlHome")
    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pnl_ID", "Panel ID", ;
        [HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pnl_PK), Pnl_ID)])
      loCol = .addCursorColumn("Pnl_Single_Piece", "Single-Piece?")
      loCol = .addCursorColumn("Pnl_Dim_1", "Dimension 1")
      loCol = .addCursorColumn("Pnl_Dim_2", "Dimension 2")
      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine 


*** ===================================================== ***
define class AisPnlQuery as L7Query
  cBaseTable = "Panel"
  cDefaultFieldList = ;
    "Pnl_PK,Pnl_ID,Pnl_Stitcher_Art_FK,Pnl_Asm_FK,Pnl_Single_Piece" + ;  
    ",Pnl_Dim_1,Pnl_Dim_2,Pnl_Type" 

  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Pnl_ID"

  cAsm = null
  
  cArtPiece = null
  cArtStitcher = null 
  
  lSinglePiece = null
  
  lJoinPiece = .f. 
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .T.
      .cWhereClause = [WHERE Pnl_Inactive = .F.] 
      if !isnull(.cArtPiece) or .lJoinPiece
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Piece"
        .aJoins[.nJoins, 2] = "Pnl_Pce_FK = Pce_PK"
        if !isnull(.cArtPiece) 
          .cWhereClause = .cWhereClause + [ and Pce_Art_FK = '] + .cArtPiece + [']
        endif 
      endif 
      if !isnull(.cArtStitcher) 
        .cWhereClause = .cWhereClause + [ and Pnl_Stitcher_Art_FK = '] + .cArtStitcher + [']
      endif 
      if !isnull(.cAsm)
        .cWhereClause = .cWhereClause + [ and Pnl_Asm_FK = '] + .cAsm + [']
      endif 
      if !isnull(.lSinglePiece)
        .cWhereClause = .cWhereClause + [ and Pnl_Single_Piece = ] + iif(.lSinglePiece, [.t.], [.f.])
      endif 
    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisPnlQuery
