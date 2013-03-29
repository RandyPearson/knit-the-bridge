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
          if !empty(this.oPce.Pce_Pnl_FK)
            this.cPnl = this.oPce.Pce_Pnl_FK
            this.verifyPanel()
          endif
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  && BeforeProcessRequest
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
  endfunc  && VerifyPiece 
enddefine && aisPcePage 

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
      .AddSubMenu("This", "PIECES")

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
      .lJoinFacility = .t.
      .lJoinPanel = .t. 
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
    urls.add(StuffUrl(this.cUrlA, 2, "FacHome"), "FacHome")

    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pce_ID", "Piece ID", ;
        [HTLink(StuffUrl(urls.item("PceHome"), "pce", Pce_PK), Pce_ID)])
      loCol = .addCursorColumn("Pce_Type", "Type")
      loCol = .addCursorColumn("Art_ID", "Artist ID", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pce_Art_FK), Art_ID)],"id-field")
      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pce_Art_FK), aisArtistName(THISRECORD))])
      ** loCol = .addCursorColumn("Art_First_Name", "First Name")
      loCol = .addCursorColumn("Pnl_Id", "Panel",, "id-field")
      loCol = .addCursorColumn("Pce_Whole_Panel", "Whole Panel?")
      loCol = .addCursorColumn("Pce_Dim_1", "Dimension 1")
      loCol = .addCursorColumn("Pce_Dim_2", "Dimension 2")

      loCol = .AddCursorColumn('Pce_Shipped', 'Shipped')
      loCol = .AddCursorColumn('Pce_Received', 'Received')
      loCol = .addCursorColumn("Fac_Name", "Current Storage Facility", ;
        [HTLink(StuffUrl(urls.item("FacHome"), "fac", Pce_Fac_FK), trim(Fac_Name))])
      if poContext.lCore
        loCol = .addCursorColumn("Pce_PK", "Edit Piece", ;
          'HTLink(StuffUrl(urls.item("PceForm"), "pce", Pce_PK), "[Edit Piece...]")')
      endif 
      response.write(.render())
      
      if poContext.lCore
        Response.Write(HTWrap(loQry.cSqlStatement, 'div,p',, 'admin,debug'))
      endif
    endwith 
    return 
  endfunc 
enddefine && ais_PceList 

*** ========================================================= ***
define class ais_PceHome as aisPcePage 
  lArtRequired = .t.
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.AddSubMenu("This", "This Piece")
    this.addMenuItem("main\This,page", "Edit Piece...", StuffUrl(this.cUrlA, 2, "PceForm", "pce", this.cPce))
    this.addMenuItem("main\This,page", "Artist's Page", StuffUrl(this.cUrlA, 2, "ArtHome", "art", this.cArt))
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Piece " + this.oPce.Pce_ID + " from " + AisArtistName(Page.oArt.Art_PK) 
    response.write(this.page_getMainRecord())

    if poContext.lAdmin
      response.write(HTWrap(L7ShowObject(this.oPce, , [class="record"]),'div','admin'))
    endif
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData
    lcRet = ""
    loData = this.oPce
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      .cCaption = this.cSubTitle
      .AddHeading('Key Information')
      
      .AddRow("Piece ID", loData.Pce_ID,, "id-field" )
      .AddRow("Artist ID", this.oArt.ART_ID,, "id-field" )
      .AddRow("Artist's Name", HtLink(StuffUrl(this.cUrlA, 2, "ArtHome", "art", this.oArt.ART_PK), AisArtistName(this.oArt.ART_PK)))
      .AddRow("Type", loData.Pce_Type)
      .AddRow("Dimension 1", loData.Pce_Dim_1)
      .AddRow("Dimension 2", loData.Pce_Dim_2)
      if m.loData.Pce_Type = "Panels"
        .AddRow("Whole-Panel Piece?", loData.Pce_Whole_Panel)
        .AddRow("Assigned to Panel?", iif(empty(m.loData.Pce_Pnl_FK), ;
          "No. " + "(assign now function goes here...)", ;
          "Yes: " + HtWrap(this.oPnl.Pnl_Id, 'span', ,'id-field') + SP + HTLink(StuffUrl(this.cUrlA, 2, "PnlHome", "pnl", loData.Pce_Pnl_FK), "View Panel Page...")))
      endif
      .AddRow("Comments", L7ParseOnView(loData.Pce_COMMENTS))

      .AddHeading('Logistical Information')
      .AddRow("Shipped/Delivered", loData.Pce_Shipped)
      .AddRow("Ship/Delivery Date", loData.Pce_Ship_Date)
      .AddRow("Received", loData.Pce_RECEIVED)
      .AddRow("Current Storage Facility", AisFacilityName(loData.Pce_Fac_FK))
      if poContext.lCore
        .AddRow("Notes", L7ParseOnView(loData.Pce_NOTES), .F., "private")
      endif

      if poContext.lCore
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.Pce_PK), .F., "private")
        .AddRow("Deleted", loData.Pce_INACTIVE, .F., "private")
        .AddRow("Created", TRANSFORM(loData.Pce_ORIG_TIME) + [ by ] + AisArtistName(loData.Pce_Orig_Art_FK), .F., "private")
        .AddRow("Last Modified", TRANSFORM(loData.Pce_REV_TIME) + [ by ] + AisArtistName(loData.Pce_Rev_Art_FK), .F., "private")
      endif

      lcRet = lcRet + .Render()

    endwith 
    return m.lcRet
  endfunc && page_getMainRecord
enddefine 

*** ========================================================= ***
define class ais_PceNew as ais_PceForm
  lAdding = .t.
  lPceRequired = .f.
  cPage_Dim_1 = null
  cPage_Dim_2 = null
  lPage_Whole = null
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr
    
    lcStr = this.ReadQueryString("type", .t., .t.)
    this.cPage_Type = m.lcStr
    
    this.cPage_Dim_1 = this.ReadQueryString("dim_1", .t., .t.)
    this.cPage_Dim_2 = this.ReadQueryString("dim_2", .t., .t.)
    this.lPage_Whole = this.ReadQueryString("whole", .t., .t.) == "1" && ignored for Railings

    dodefault()  && required bubble-up
    return    
  endfunc  
enddefine 

*** ========================================================= ***
define class ais_PceForm as aisPcePage 
  lAdding = .f.
  lArtRequired = .t.
  cPage_Type = null
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
      this.cPage_Type = trim(Pce_Type)
      scatter memo name loOldRec
    endif 
    this.assert(inlist(this.cPage_Type, "Railings", "Panels"), "Unknown piece type: " + this.cPage_Type)
    cursorsetprop("Buffering", 5, "V_Piece")
    loForm = this.createForm('aisPieceForm', this.cUrlC)
    with loForm
      .cCustom_Type = this.cPage_Type
      .lNewRecord = THIS.lAdding
      .AddControls()
      .DoEvents() 

      if .Valid()
        select V_Piece
        if this.lAdding
          append blank
          replace Pce_Art_FK with this.cArt ;
            Pce_Type with this.cPage_Type 
        endif 
        if empty(Pce_Id)
          replace Pce_ID with AisAssignID(icase(Pce_Type = "Railings", "RLG", "PCE"))
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
  cCustom_Type = null 
  * --------------------------------------------------------- *
  function  AddControls
    with this
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
      
      .AddObject("txtArt_Fk", "L7Label")
      with .txtArt_Fk
        .cGroupID = "ID"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Art_Fk"
        .cLabel = "Artist"
        if this.lNewRecord
          .SetValue(Page.cArt)
        endif 
        .lDisabled = .t.  && !m.poContext.lAdmin
        .cShowExpression = [aisArtistName(Page.cArt)]
      endwith 

      .AddObject("lblPk", "L7Label")
      with .lblPk
        .cGroupID = "ID"
        .cControlSource = "V_piece.Pce_Pk"
        .cLabel = "Internal Key"
        .cCssClass = "FormControlPrivate"
      endwith 

      .AddObject("chkInactive", "L7Checkbox")
      with .chkInactive
        .cGroupID = "ID"
        .cControlSource = "V_piece.Pce_Inactive"
        .cLabel = "Delete?"
        .lDisabled = !m.poContext.lAdmin
        .cCssClass = "FormControlPrivate"
      endwith

      if this.cCustom_Type = "Panels"
        .AddObject("chkWhole_Panel", "L7Checkbox")
        with .chkWhole_Panel
          .cGroupID = "PANEL"
          .cControlSource = "V_piece.Pce_Whole_Panel"
          if this.lNewRecord
            .SetValue(Page.lPage_Whole)
          endif 
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
          .cCssClass = "FormControlPrivate"
        endwith 
      endif
      
      .AddObject("txtDim_1", "L7Textbox")
      with .txtDim_1
        .cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Dim_1"
        if this.lNewRecord
          .SetValue(Page.cPage_Dim_1)
        endif 
        .cLabel = "Dimension 1 (inches)"
        .cInstructions = "If not equal, please enter SMALLER dimension first!"
      endwith
       
      .AddObject("txtDim_2", "L7Textbox")
      with .txtDim_2
        .cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Dim_2"
        if this.lNewRecord
          .SetValue(Page.cPage_Dim_2)
        endif 
        .cLabel = "Dimension 2 (inches)"
        .cInstructions = "If not equal, please enter LARGER dimension second!"
      endwith 

      .AddObject("chkShipped", "L7Checkbox")
      with .chkShipped
        .cGroupID = "STATUS"
        .cControlSource = "V_piece.Pce_Shipped"
        .cLabel = "Shipped/Delivered?"
      endwith 

      .AddObject("txtShip_Date", "L7Textbox")
      with .txtShip_Date
        .cGroupID = "STATUS"
        .cFieldType = "D"
        .cControlSource = "V_Piece.Pce_Ship_Date"
        .cLabel = "Ship/delivery date (expected or actual)"
        .cInstructions = "MM/DD/YYYY"
      endwith 

      .AddObject("chkReceived", "L7Checkbox")
      with .chkReceived
        .cGroupID = "STATUS"
        .cControlSource = "V_piece.Pce_Received"
        .cLabel = "Received?"
        .cCssClass = "FormControlPrivate"
      endwith 

      .AddObject("cboLoc_FK", "L7Popup")
      with .cboLoc_FK
        .cControlSource = "V_Piece.Pce_Fac_FK"
        .lRequired = .F.
        .cLabel = "Current Location"
        .lAutoRender = .T.
        .nRowSourceType = L7_ROWSOURCETYPE_ALIAS
        .cRowSource = goL7App.cFacAlias  
        *!* ex: .cFilterExpression = [Fac_Storage = .t.]
        .cValueExpression = [Fac_PK]
        .cLabelExpression = [Fac_Name]
        .vFirstItemValue = space(32) && 0 for integer keys
        .cFirstItemLabel = "[ select from choices below ]"
        if this.lNewRecord
          *!* .SetValue(something from Page context....)
        endif 
      endwith 

      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cGroupID = "NOTES"
        .cControlSource = "V_piece.Pce_Comments"
        .cLabel = "Comments about Piece"
        .nRows = 3
      endwith 

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cGroupID = "NOTES"
        .cControlSource = "V_piece.Pce_Notes"
        .cLabel = "Internal KtB Notes"
        .nRows = 3
        .cCssClass = "FormControlPrivate"
      endwith
    endwith
    return 
  endfunc && AddControls 
enddefine  && PieceForm

*** ===================================================== ***
define class AisPceQuery as L7Query
  cBaseTable = "Piece"
  cDefaultFieldList = ;
    "Pce_PK, Pce_ID, Pce_Art_FK, Pce_Pnl_FK, Pce_Fac_FK, Pce_Whole_Panel" + ;  
    ", Pce_Dim_1, Pce_Dim_2, Pce_Type, Pce_Shipped, Pce_Ship_Date, Pce_Received" 

  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Pce_ID"

  cArt = null
  cPnl = null
  cFac = null
  
  cType = null

  lOrphans    = null
  lWholePanel = null
  lShipped    = null
  lReceived   = null
  
  lJoinArtist = .f. 
  lJoinFacility = .f.
  lJoinPanel = .f. 
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
        .AddFields("Art_ID,Art_Last_Name,Art_First_Name,Art_Anonymous,Art_Full_Name")
      endif 

      if .lJoinFacility
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Facility"
        .aJoins[.nJoins, 2] = "Pce_Fac_FK = Fac_PK"
        .aJoins[.nJoins, 3] = "LEFT OUTER"
        .AddFields("Fac_ID, Fac_Name")
      endif 

      if .lJoinPanel
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Panel"
        .aJoins[.nJoins, 2] = "Pce_Pnl_FK = Pnl_PK"
        .aJoins[.nJoins, 3] = "LEFT OUTER"
        .AddFields("Pnl_ID")
      endif 

      if !isnull(.cArt)
        .cWhereClause = .cWhereClause + [ and Pce_Art_FK = '] + .cArt + [']
      endif 

      if !isnull(.cType)
        .cWhereClause = .cWhereClause + [ and Pce_Type = '] + padr(.cType, THISAPP_LENGTH_PIECE_TYPE) + [']
      endif 

      if !isnull(.cPnl)
        .cWhereClause = .cWhereClause + [ and Pce_Pnl_FK = '] + .cPnl + [']
      endif 
      if !isnull(.cFac)
        .cWhereClause = .cWhereClause + [ and Pce_Fac_FK = '] + .cFac + [']
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
