* AisPce.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H


*** ========================================================= ***
define class aisPcePage as aisPage 
  cPce = ""
  oPce = null
  lPceRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lPceRequired
      this.cPce = evl(this.cPce, this.StripUrl("pce", .f., .t.))
      if empty(this.cPce)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyPiece()
        if !isnull(this.oPce)
          this.cArt = this.oPce.Pce_Art_FK
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyPiece(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cPce)
    loData = createobject("AisPceData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cPce
        this.oPce = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
enddefine 

*** ========================================================= ***
define class ais_PceList as aisPcePage 
  lPceRequired = .f.
  lPage_Orphans = null
  lPage_Whole = null
  lPage_Shipped = null
  lPage_Received = null 
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr
    
    lcStr = this.ReadQueryString("Orphans", .t., .t.)
    this.lPage_Orphans = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')
    
    lcStr = this.ReadQueryString("Whole", .t., .t.)
    this.lPage_Whole = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')
    
    lcStr = this.ReadQueryString("Shipped", .t., .t.)
    this.lPage_Shipped = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')

    lcStr = this.ReadQueryString("Received", .t., .t.)
    this.lPage_Received = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')

    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function AddDefaultMenu
    with this
      .addMenuItem("main\This", "Available", StuffUrl(.cUrlC, "orphans", "1"),, !isnull(.lPage_Orphans) and .lPage_Orphans)
      .addMenuItem("main\This", "Assigned", StuffUrl(.cUrlC, "orphans", "0"),, !isnull(.lPage_Orphans) and !.lPage_Orphans)
      .addMenuItem("main\This", "Available and Assigned", StuffUrl(.cUrlC, "orphans", .f.),, isnull(.lPage_Orphans))

      .addMenuItem("main\This", "Whole-Panel", StuffUrl(.cUrlC, "whole", "1"),, !isnull(.lPage_Whole) and .lPage_Whole)
      .addMenuItem("main\This", "Non-Whole-Panel", StuffUrl(.cUrlC, "whole", "0"),, !isnull(.lPage_Whole) and !.lPage_Whole)
      .addMenuItem("main\This", "Whole- and Non-Whole-Panel", StuffUrl(.cUrlC, "whole", .f.),, isnull(.lPage_Whole))

      .addMenuItem("main\This", "Shipped", StuffUrl(.cUrlC, "Shipped", "1"),, !isnull(.lPage_Shipped) and .lPage_Shipped)
      .addMenuItem("main\This", "Not Shipped", StuffUrl(.cUrlC, "Shipped", "0"),, !isnull(.lPage_Shipped) and !.lPage_Shipped)
      .addMenuItem("main\This", "Shipped and Not Shipped", StuffUrl(.cUrlC, "Shipped", .f.),, isnull(.lPage_Shipped))

      .addMenuItem("main\This", "Received", StuffUrl(.cUrlC, "Received", "1"),, !isnull(.lPage_Received) and .lPage_Received)
      .addMenuItem("main\This", "Not Received", StuffUrl(.cUrlC, "Received", "0"),, !isnull(.lPage_Received) and !.lPage_Received)
      .addMenuItem("main\This", "Received and Not Received", StuffUrl(.cUrlC, "Received", .f.),, isnull(.lPage_Received))
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisPceQuery")
    with loQry
      .lJoinArtist = .t. 
      .lOrphans    = this.lPage_Orphans 
      .lWholePanel = this.lPage_Whole 
      .lShipped    = this.lPage_Shipped 
      .lReceived   = this.lPage_Received 
      
      .AddOrderBy('Pce_Rev_Time', .t.)
      .execute()
      
      this.cSubTitle = this.cSubTitle + .GetCaption()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "PceHome"), "PceHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PceForm"), "PceForm")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
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
      loCol = .addCursorColumn("Pce_Whole_Panel", "Whole Panel?")
      loCol = .addCursorColumn("Pce_Dim_1", "Dimension 1")
      loCol = .addCursorColumn("Pce_Dim_2", "Dimension 2")

      loCol = .AddCursorColumn('Pce_Shipped', 'Shipped')
      loCol = .AddCursorColumn('Pce_Received', 'Received')
      if poContext.lCore
        loCol = .addCursorColumn("Pce_PK", "Edit Piece", ;
          'HTLink(StuffUrl(urls.item("PceForm"), "pce", Pce_PK), "[Edit Piece...]")')
      endif 
      response.write(.render())
      
      if poContext.lCore
        Response.Write(HTWrap(loQry.cSqlStatement, 'div,p', 'admin,debug'))
      endif
    endwith 
    return 
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_PceHome as aisPcePage 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.addMenuItem("main\This,page", "Edit Piece...", StuffUrl(this.cUrlA, 2, "PceForm", "pce", this.cPce))
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    response.write(L7ShowObject(this.oPce, , [class="record"]))
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_PceNew as ais_PceForm
  lAdding = .t.
  lPceRequired = .f.
enddefine 

*** ========================================================= ***
define class ais_PceForm as aisPcePage 
  lAdding = .f.
  lArtRequired = .t.
  * ----------------------------------------------------- *  
  function ProcessRequest

    this.Assert(poContext.lCore)
    this.cCancelUrl = iif(this.lAdding, StuffURL(THIS.cUrlA, 2, "ArtHome", "art", this.cArt), ;
      StuffURL(THIS.cUrlB, 2, "PceHome"))

    local loForm, vp_cPce_PK, loOldRec, loNewRec, loPnl
    vp_cPce_PK = IIF(THIS.lAdding, space(32), THIS.cPce)
    use V_Piece in select("V_Piece")
    if !this.lAdding
      select V_Piece
      scatter memo name loOldRec
    endif 
    cursorsetprop("Buffering", 5, "V_Piece")
    loForm = this.createForm('aisPieceForm')
    with loForm
      .lNewRecord = THIS.lAdding
      .AddControls()
      .DoEvents() 

      if .Valid()
        select V_Piece
        if this.lAdding
          append blank
          replace Pce_Art_FK with this.cArt
        endif 
        if empty(Pce_Id)
          replace Pce_ID with AisAssignID("PCE")
        endif
        .UpdateControlSources()
        select V_Piece  && UpdateControlSources can alter work area
        StampRec( CurrentUser, THIS.tNow )
        scatter memo name loNewRec 
        
        * create Panel if indicated:
        if loNewRec.Pce_Whole_Panel and empty(loNewRec.Pce_Pnl_FK)
          loPnl = AisCreatePanel(m.loNewRec)
          select v_piece
          replace Pce_Pnl_FK with loPnl.Pnl_PK
          scatter memo name loNewRec && re-scatter needed 
        endif
        
        * Now save the piece using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail
        llSendEmail = .f.  
        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor("V_Piece")

        if loTrans.Save()  
          select V_Piece
          Response.Redirect(THIS.cCancelUrl)
          return 
        else 
          this.ErrorMsg( "Database Failure Saving Record!", ;
            "Error " + TRANSFORM( loTrans.aFailures[1, 1]) + [ :] + ;
            loTrans.aFailures[1, 2] )
        endif  && Save()
      endif && Valid
    endwith && form

    response.write(loForm.render())
    return 
  endfunc  && ProcessRequest 
enddefine && ais_PceForm

*** ========================================================= ***
define class aisPieceForm as AisForm
  cTitle = "Piece Form"
  * --------------------------------------------------------- *
  function  AddControls
    with this
      .AddObject("lblPk", "L7Label")
      with .lblPk
        .cGroupID = "ADMIN"
        .cControlSource = "V_piece.Pce_Pk"
        .cLabel = "Internal Key"
      endwith 
      .AddObject("chkInactive", "L7Checkbox")
      with .chkInactive
        .cGroupID = "ADMIN"
        .cControlSource = "V_piece.Pce_Inactive"
        .cLabel = "Delete?"
        .lDisabled = NOT m.poContext.lAdmin
      endwith
      if !this.lNewRecord
        .AddObject("txtId", "L7Textbox")
        with .txtId
          .cGroupID = "ID"
          .cFieldType = "C"
          .cControlSource = "V_piece.Pce_Id"
          .cLabel = "Piece ID"
          .lDisabled = .t. 
        endwith
      endif 
      
      .AddObject("txtArt_Fk", "L7Textbox")
      with .txtArt_Fk
        .cGroupID = "ID"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Art_Fk"
        .cLabel = "Artist"
        if this.lNewRecord
          .SetValue(Page.cArt)
        endif 
        .lDisabled = !m.poContext.lAdmin
      endwith 

      .AddObject("chkWhole_Panel", "L7Checkbox")
      with .chkWhole_Panel
        .cGroupID = "PANEL"
        .cControlSource = "V_piece.Pce_Whole_Panel"
        .cLabel = "Does the piece comprose a whole panel?"
        .nMode = L7_MULTI_RADIOBUTTON
        .nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
        .cCaption = "Yes - whole panel"
        .cFalseCaption = "No - partial panel" 
        .lFalseBeforeTrue = .T.
        .cInterControlText = NULL 
      endwith 
      
      .AddObject("txtPnl_Fk", "L7Textbox")
      with .txtPnl_Fk
        .cGroupID = "PANEL"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Pnl_Fk"
        .cLabel = "Panel Internal Key"
        .lDisabled = .t. 
      endwith 

      .AddObject("txtDim_1", "L7Textbox")
      with .txtDim_1
        .cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Dim_1"
        .cLabel = "Dimension 1 (inches)"
        .cInstructions = "If not same, please enter larger dimension here!"
      endwith
       
      .AddObject("txtDim_2", "L7Textbox")
      with .txtDim_2
        .cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Dim_2"
        .cLabel = "Dimension 2 (inches)"
      endwith 

      .AddObject("chkShipped", "L7Checkbox")
      with .chkShipped
        .cGroupID = "STATUS"
        .cControlSource = "V_piece.Pce_Shipped"
        .cLabel = "Shipped?"
      endwith 

      .AddObject("txtShip_Date", "L7Textbox")
      with .txtShip_Date
        .cGroupID = "STATUS"
        .cFieldType = "D"
        .cControlSource = "V_piece.Pce_Ship_Date"
        .cLabel = "Ship date (expected or actual)"
        .cInstructions = "MM/DD/YYYY"
      endwith 

      .AddObject("chkReceived", "L7Checkbox")
      with .chkReceived
        .cGroupID = "STATUS"
        .cControlSource = "V_piece.Pce_Received"
        .cLabel = "Received?"
      endwith 

      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cGroupID = "NOTES"
        .cControlSource = "V_piece.Pce_Comments"
        .cLabel = "Comments about Piece"
        .nRows = 5
      endwith 

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cGroupID = "NOTES"
        .cControlSource = "V_piece.Pce_Notes"
        .cLabel = "Internal KtB Notes"
        .nRows = 5
      endwith
    endwith
  endfunc
enddefine  && PieceForm

*** ===================================================== ***
define class AisPceQuery as L7Query
  cBaseTable = "Piece"
  cDefaultFieldList = ;
    "Pce_PK,Pce_ID,Pce_Art_FK,Pce_Pnl_FK,Pce_Whole_Panel" + ;  
    ",Pce_Dim_1,Pce_Dim_2,Pce_Type,Pce_Shipped,Pce_Ship_Date,Pce_Received" 

  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Pce_ID"

  cArt = null
  cPnl = null
  
  lOrphans    = null
  lWholePanel = null
  lShipped    = null
  lReceived   = null

  lJoinArtist = .f. 
  * --------------------------------------------------------- *
  function GetCaption 
    local lcRet
    lcRet = ""
    with this
      lcRet = m.lcRet + ;
        iif(isnull(.lOrphans), "", iif(.lOrphans, " Available", " Assigned")) + ;
        iif(isnull(.lWholePanel), "", iif(.lWholePanel, " Whole-Panel", " Non-Whole-Panel")) + ;
        " Pieces"
      if !isnull(.lShipped) or !isnull(.lReceived)
        lcRet = m.lcRet + ", w/ Status: " + substr( ;
          iif(isnull(.lShipped), "", " and " + iif(.lShipped, "Shipped", "not Shipped")) + ;
          iif(isnull(.lReceived), "", " and " + iif(.lReceived, "Received", "not Received")), ;
          1 + len(" and "))
        
      endif 
    endwith 
    return m.lcRet
  endfunc 
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr, lcCapt

    with this 
      .lWhereBuilt = .T.
      .cWhereClause = [WHERE Pce_Inactive = .F.] 

      if .lJoinArtist
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Artist"
        .aJoins[.nJoins, 2] = "Pce_Art_FK = Art_PK"
        .AddFields("Art_ID,Art_Last_Name,Art_First_Name")
      endif 

      if !isnull(.cArt)
        .cWhereClause = .cWhereClause + [ and Pce_Art_FK = '] + .cArt + [']
      endif 

      if !isnull(.cPnl)
        .cWhereClause = .cWhereClause + [ and Pce_Pnl_FK = '] + .cPnl + [']
      endif 
      if !isnull(.lOrphans)
        .cWhereClause = .cWhereClause + [ and ] + iif(.lOrphans, [], [!]) + [empty(Pce_Pnl_FK)]
      endif 
      if !isnull(.lWholePanel)
        .cWhereClause = .cWhereClause + [ and ] + iif(.lWholePanel, [], [!]) + [Pce_Whole_Panel]
      endif 
      if !isnull(.lShipped)
        .cWhereClause = .cWhereClause + [ and Pce_Shipped = ] + iif(.lShipped, [.t.], [.f.])
      endif 
      if !isnull(.lReceived)
        .cWhereClause = .cWhereClause + [ and Pce_Received = ] + iif(.lReceived, [.t.], [.f.])
      endif 
    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisPceQuery


* end 
