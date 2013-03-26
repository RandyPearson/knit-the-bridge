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
    Pnl_ID with AisAssignID("PNL")

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
  cSubTitle = "Panels"
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    with this
      .AddSubMenu("This", "PANELS")
    endwith 
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
    urls.add(StuffUrl(this.cUrlA, 2, "PnlForm"), "PnlForm")

    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pnl_ID", "Panel ID", ;
        [HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pnl_PK), Pnl_ID)])
      loCol = .addCursorColumn("Pnl_Single_Piece", "Single-Piece?")
      loCol = .addCursorColumn("Pnl_Dim_1", "Dimension 1")
      loCol = .addCursorColumn("Pnl_Dim_2", "Dimension 2")
      loCol = .addCursorColumn("Pnl_PK", "Edit Panel", ;
        'HTLink(StuffUrl(urls.item("PnlForm"), "pnl", Pnl_PK), "[Edit Panel...]")')
      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_PnlHome as aisPnlPage 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.addMenuItem("main\This,page", "Edit Piece...", StuffUrl(this.cUrlA, 2, "PnlForm", "pnl", this.cPnl))
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Panel " + this.oPnl.Pnl_ID
    response.write(this.page_getPieceInfo())

    response.write(HTWrap("Raw Data for " + this.cSubTitle, 'h3'))
    response.write(L7ShowObject(this.oPnl, this.cSubTitle, [class="record"]))
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getPieceInfo()
    local lcRet, loQ, loTbl, loCol
    lcRet = ''
    lcRet = m.lcRet + HTWrap("Pieces from " + this.cSubTitle, 'h3')
    loQ = createobject("AisPceQuery")
    with loQ
      .cPnl = this.cPnl
      .lJoinArtist = .t. 
      .Execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "PceHome"), "PceHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PceForm"), "PceForm")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")

    select (loQ.cAlias)
    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pce_ID", "Piece ID", ;
        [HTLink(StuffUrl(urls.item("PceHome"), "pce", Pce_PK), Pce_ID)])
      loCol = .addCursorColumn("Art_ID", "Artist ID", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pce_Art_FK), Art_ID)])
      loCol = .addCursorColumn("Art_Last_Name", "Last Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pce_Art_FK), Art_Last_Name)])
      loCol = .addCursorColumn("Art_First_Name", "First Name")
      loCol = .AddCursorColumn('Pce_Whole_Panel', 'Whole Panel?')
      loCol = .AddCursorColumn('Pce_Dim_1', 'Dim 1')
      loCol = .AddCursorColumn('Pce_Dim_2', 'Dim 2')
      loCol = .AddCursorColumn('Pce_Shipped', 'Shipped')
      loCol = .AddCursorColumn('Pce_Received', 'Received')
      loCol = .addCursorColumn("Pce_PK", "Edit Piece", ;
        'HTLink(StuffUrl(urls.item("PceForm"), "pce", Pce_PK), "[Edit Piece...]")')

      lcRet = m.lcRet + .Render()
    endwith 
    
    return m.lcRet
  endfunc && page_getPieceInfo
enddefine && ArtHome

*** ========================================================= ***
define class ais_PnlNew as ais_PnlForm
  lAdding = .t.
  lPnlRequired = .f.
enddefine 

*** ========================================================= ***
define class ais_PnlForm as aisPnlPage 
  lAdding = .f.
  * ----------------------------------------------------- *  
  function ProcessRequest

    this.Assert(poContext.lCore)
    this.cCancelUrl = iif(this.lAdding, StuffURL(THIS.cUrlA, 2, "PnlList"), ;
      StuffURL(THIS.cUrlB, 2, "PnlHome"))

    local loForm, vp_cPnl_PK, loOldRec, loNewRec
    vp_cPnl_PK = IIF(THIS.lAdding, space(32), THIS.cPnl)
    use V_Panel in select("V_Panel")
    if !this.lAdding
      select V_Panel
      scatter memo name loOldRec
    endif 
    cursorsetprop("Buffering", 5, "V_Panel")
    loForm = this.createForm('aisPanelForm')
    with loForm
      .lNewRecord = THIS.lAdding
      .AddControls()
      .DoEvents() 

      if .Valid()
        select V_Panel
        if this.lAdding
          append blank
        endif 
        if empty(Pnl_Id)
          replace Pnl_ID with AisAssignID("PNL")
        endif
        .UpdateControlSources()
        select V_Panel  && UpdateControlSources can alter work area
        StampRec( CurrentUser, THIS.tNow )
        scatter memo name loNewRec 
        
        * Now save the record using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail
        llSendEmail = .f.  
        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor("V_Panel")

        if loTrans.Save()  
          select V_Panel
          Response.Redirect(StuffUrl(this.cUrlA, 2, "PnlHome", "pnl", Pnl_PK))
          return 
        else 
          this.ErrorMsg( "Database Failure Saving Record!", ;
            "Error " + TRANSFORM( loTrans.aFailures[1, 1]) + [ :] + ;
            loTrans.aFailures[1, 2] )
        endif  && Save()
        
      endif 

    endwith 
    response.write(loForm.render())
  endfunc 
enddefine && ais_PnlForm

*** ========================================================= ***
define class aisPanelForm as AisForm
  cTitle = "Panel Form"
  * --------------------------------------------------------- *
  function  AddControls
    with this
      .AddObject("lblPk", "L7Label")
      with .lblPk
        .cGroupID = "ADMIN"
        .cControlSource = "V_Panel.Pnl_Pk"
        .cLabel = "Internal Key"
      endwith 
      .AddObject("chkInactive", "L7Checkbox")
      with .chkInactive
        .cGroupID = "ADMIN"
        .cControlSource = "V_Panel.Pnl_Inactive"
        .cLabel = "Delete?"
        .lDisabled = !m.poContext.lAdmin
      endwith
      if !this.lNewRecord
        .AddObject("txtId", "L7Textbox")
        with .txtId
          .cGroupID = "ID"
          .cFieldType = "C"
          .cControlSource = "V_Panel.Pnl_Id"
          .cLabel = "Pacel ID"
          .lDisabled = .t. 
        endwith
      endif 
      
      .AddObject("chkSingle_Piece", "L7Checkbox")
      with .chkSingle_Piece
        .cGroupID = "DIM"
        .cControlSource = "V_Panel.Pnl_Single_Piece"
        .cLabel = "Is this a single-piece panel?"
        .nMode = L7_MULTI_RADIOBUTTON
        .nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
        .cCaption = "Yes - single piece"
        .cFalseCaption = "No - multiple pieces" 
        .lFalseBeforeTrue = .T.
        .cInterControlText = NULL 
      endwith 
      
      .AddObject("txtDim_1", "L7Textbox")
      with .txtDim_1
        .cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_Panel.Pnl_Dim_1"
        .cLabel = "Dimension 1 (inches)"
        .cInstructions = "If not equal, please enter SMALLER dimension first!"
      endwith
       
      .AddObject("txtDim_2", "L7Textbox")
      with .txtDim_2
        .cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_Panel.Pnl_Dim_2"
        .cLabel = "Dimension 2 (inches)"
        .cInstructions = "If not equal, please enter LARGER dimension second!"
      endwith 

      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cGroupID = "NOTES"
        .cControlSource = "V_Panel.Pnl_Comments"
        .cLabel = "Comments about Panel"
        .nRows = 5
      endwith 

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cGroupID = "NOTES"
        .cControlSource = "V_Panel.Pnl_Notes"
        .cLabel = "Internal KtB Notes"
        .nRows = 5
      endwith
    endwith
  endfunc
enddefine  && PanelForm

*** ===================================================== ***
define class AisPnlQuery as L7Query
  cBaseTable = "Panel"
  cDefaultFieldList = ;
    "Pnl_PK,Pnl_ID,Pnl_Stitcher_Art_FK,Pnl_Asm_FK,Pnl_Single_Piece" + ;  
    ",Pnl_Dim_1,Pnl_Dim_2" 

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
