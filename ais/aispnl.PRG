* AisPnl.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H


* --------------------------------------------------------- *
function AisPanelImage(lcId, lcSuff, lcUrl, lcPK, llCanUpload)
  if isnull(m.lcId) or empty(m.lcId)
    return ""
  endif
  local lcFileName, lcRet
  lcFileName = forceext(m.lcId + m.lcSuff, "jpeg")
  if file(aisPanelFilePath(m.lcId) + m.lcFileName)
    lcRet = HTImage(aisPanelWebFilePath(m.lcId) + m.lcFileName, "Panel " + m.lcId)
    if !empty(m.lcPK)
      lcRet = HTLink(StuffUrl(page.cUrlA, 2, "PnlHome", "pnl", m.lcPK), m.lcRet)
    endif 
  else
    if m.llCanUpload and !empty(m.lcUrl) and !empty(m.lcPK)
      lcRet = HTLink(StuffUrl(m.lcUrl, "pnl", m.lcPK), "Upload...")
    else
      lcRet = "" 
    endif
  endif
  return m.lcRet
endfunc 
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
    Pnl_Dim_1 with toPce.Pce_Dim_1 ;   && initial approx, can free-wheel 
    Pnl_Dim_2 with toPce.Pce_Dim_2 ;   &&  ''
    Pnl_Fac_FK with toPce.Pce_Fac_FK ; && panel starts where piece was
    Pnl_ID with AisAssignID("PNL")

  if toPce.Pce_Whole_Panel
    replace ; 
      Pnl_Stitcher_Art_FK with toPce.Pce_Art_FK ; && panel attributed to piece artist
      Pnl_Completed with .t.                      && single-piece panel are complete by def'n 
    replace ;
      Pnl_Notes with toPce.Pce_Notes ;
      Pnl_Comments with toPce.Pce_Comments 
  endif 

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

* --------------------------------------------------------- *
function aisGetPanelLocation(tcPnl)
  local loRet, loSelect
  loRet = null
  loSelect = createobject("L7PreserveSelect")
  select Plc_PK, Plc_Orientation, Loc_Side, Loc_No, Loc_PK ;
    from PanelLocation join Location on Plc_Loc_FK = Loc_PK ;
    where Plc_Pnl_FK = m.tcPnl ;
    into cursor GetPanelLocation_ 
  if _tally > 0
    scatter memo name loRet 
  endif 
  use in select("GetPanelLocation_")
  return m.loRet
endfunc && aisGetPanelLocation

* --------------------------------------------------------- *
function aisFormatPanelLocation(tvPnl) && object or key
  if isnull(m.tvPnl) or (vartype(m.tvPnl) = 'C' and empty(m.tvPnl))
    return null
  endif 
  local loPlc, lcRet
  lcRet = null 
  loPlc = iif(vartype(m.tvPnl) = "O", m.tvPnl, aisGetPanelLocation(m.tvPnl))
  if !isnull(m.loPlc)
    lcRet = textmerge([<<trim(loPlc.Loc_Side)>>-<<loPlc.Loc_No>> (<<loPlc.Plc_Orientation>>)])
  endif 
  return m.lcRet
endfunc 

*** ========================================================= ***
define class aisPnlPage as aisPage 
  cPnl = ""
  oPnl = null
  lPnlRequired = .t.
enddefine && AisPnlPage

*** ========================================================= ***
define class ais_PnlList as aisPnlPage 
  lPnlRequired = .f.
  cSubTitle = "Panel List"

  lPage_Location = null
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr

    lcStr = this.ReadQueryString("location", .t., .t.)
    this.lPage_Location = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')
    
    dodefault()  && required bubble-up
    return    
  endfunc  
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local lcMenu
    with this
      .AddSubMenu("This", "PANELS")
      lcMenu = "main\This"
      .addMenuItem(m.lcMenu, 'Panel w/Bridge Locations', StuffUrl(this.cUrlA, 2, "PnlList", "location", "1"))
      .addMenuItem(m.lcMenu, 'Panels Still Available', StuffUrl(this.cUrlA, 2, "PnlList", "location", "0"))
      .addMenuItem(m.lcMenu, 'ALL Panels', StuffUrl(this.cUrlA, 2, "PnlList", "location", .f.))
      
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisPnlQuery")
    with loQry
      .lHasLocation = this.lPage_Location 
      .lJoinFacility = .t.
      .lJoinLocation = .t. 
      .lJoinArtist = .t. 
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "PnlHome"), "PnlHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PnlForm"), "PnlForm")
    urls.add(StuffUrl(this.cUrlA, 2, "FacHome"), "FacHome")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PnlFilNew", "return", this.cUrlC), "PnlFilNew")

    loTbl = createobject("AisTable")
    with loTbl
      .cTableCaption = this.cSubTitle 
      
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pnl_ID", "Panel ID", ;
        [HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pnl_PK), Pnl_ID)], 'id-field panel')
      loCol = .addCursorColumn("Pnl_Single_Piece", "Single-Piece?")

      loCol = .addCursorColumn("Pnl_Dim_1", "Dimension 1")
      loCol = .addCursorColumn("Pnl_Dim_2", "Dimension 2")
      loCol = .addCursorColumn("Pnl_Comments", "Comments")
      loCol = .addCursorColumn("Pnl_ID", "Image", ;
        [AisPanelImage(Pnl_Id, "_h25", urls.item("PnlFilNew"), Pnl_PK, poContext.lAdmin)])

      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pnl_Stitcher_Art_FK), aisArtistName(THISRECORD))], 'artist')
      loCol = .addCursorColumn("Pnl_Completed", "Completed?")
      loCol = .addCursorColumn("Fac_Name", "Current Storage Facility", ;
        [HTLink(StuffUrl(urls.item("FacHome"), "fac", Pnl_Fac_FK), trim(Fac_Name))], 'facility')
      loCol = .addCursorColumn("Plc_Orientation", "Bridge<br>Location", ;
        [<<trim(Loc_Side)>>-<<Loc_No>> (<<Plc_Orientation>>)], 'location')
      loCol.lDisplayTextmerge = .t. 

      if poContext.lAdmin
        loCol = .addCursorColumn("Pnl_Notes", "Notes",, "private")
        loCol = .addCursorColumn("Pnl_PK", "Edit Panel", ;
          'HTLink(StuffUrl(urls.item("PnlForm"), "pnl", Pnl_PK), "[Edit&nbsp;Panel...]")', 'panel', "no-print")
        loCol.cHeadingClass = "nosort no-print" 
      endif 

      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine && ais_PnlList 

*** ========================================================= ***
define class ais_PnlAddPiece as aisPnlPage 
  cPage_Pce_PK = null
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    this.cPage_Pce_PK = this.readQueryString("pce", .t., .t.)
    dodefault()
    return 
  endfunc   
  * ----------------------------------------------------- *  
  function page_selectPiece
    local loQ, loTbl, loCol, loGrp

    loQ = createobject("AisPceQuery")
    with loQ
      .cType = "Panels"
      .lOrphans = .t. 
      .lJoinArtist = .t. 
      .lJoinFacility = .t.
      .Execute()
    endwith 

    urls.add(this.cUrlB, "Select")
    
    select (loQ.cAlias)
    loTbl = createobject("AisTable")
    with loTbl
      loCol = .addCursorColumn("Pce_ID", "Add Piece", ;
        [HTLink(StuffUrl(urls.item("Select"), "pce", Pce_PK), "Choose&nbsp;piece...")])

      loCol = .addCursorColumn("Pce_ID", "Piece ID")
      loCol = .addCursorColumn("Art_ID", "Artist ID")
      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", [aisArtistName(THISRECORD)])
      loCol = .AddCursorColumn('Pce_Whole_Panel', 'Whole Panel?')
      loCol = .AddCursorColumn('Pce_Dim_1', 'Dim 1')
      loCol = .AddCursorColumn('Pce_Dim_2', 'Dim 2')
      loCol = .AddCursorColumn('Pce_Comments', 'Comments')
      loCol = .addCursorColumn("Fac_Name", "Current Storage Facility")

    endwith 
    response.Write(loTbl.Render())    
    return 
    
  endfunc  && page_selectPiece 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = StuffURL(THIS.cUrlB, 2, "PnlHome")
    this.Assert(poContext.lAdmin)

    if empty(this.cPage_Pce_PK)
      this.page_selectPiece()
      return
    endif

    local vp_cPce_PK
    vp_cPce_PK = THIS.cPage_Pce_PK
    use V_Piece in select("V_Piece")
    cursorsetprop("Buffering", 5, "V_Piece")

    this.assert(inlist(V_Piece.Pce_Type, "Panels"), "Function only applies to panel piece type. ")

    select V_Piece  
    replace Pce_Pnl_FK with this.cPnl
    StampRec( CurrentUser, THIS.tNow )
        
    * Now save the piece using a transaction:
    local loTrans, loExc
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
    return
  endfunc && ProcessRequest 
enddefine  && ais_PnlAddPiece 

*** ========================================================= ***
define class ais_PnlRemLoc as aisPnlPage 
  cPage_Plc = null 
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    this.cPage_Plc = this.readQueryString("plc", .t., .t.)
    dodefault()
    return 
  endfunc   
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = StuffURL(THIS.cUrlB, 2, "PnlHome")
    
    this.Assert(poContext.lAdmin)
    this.cSubTitle = "Remove Panel Location for " + this.oPnl.Pnl_ID

    local loForm, vp_cPlc_PK, lcAlias, lcXml
    lcAlias = "V_PanelLocation"
    vp_cPlc_PK = this.cPage_Plc && [[ validate........
    use (m.lcAlias) in select()
    cursorsetprop("Buffering", 5, m.lcAlias)
    select (m.lcAlias)
    replace Plc_Inactive with .t. ;
      Plc_Pnl_FK with "" ;
      Plc_Loc_FK with "" ;
      Plc_Orientation with ""

    StampRec( CurrentUser, THIS.tNow )
    lcXml = ""
    this.AssertTransaction(m.lcAlias, @lcXml)
    Response.Redirect(this.cCancelUrl)
    return 
  endfunc 
enddefine && ais_PnlRemLoc 

*** ========================================================= ***
define class ais_PnlSetLoc as aisPnlPage 
  cPage_Side = null
  cPage_Orient = null 
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    this.cPage_Side = this.readQueryString("side", .t., .t.)
    this.cPage_Orient = this.readQueryString("orient", .t., .t.)
    dodefault()
    return 
  endfunc   
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = StuffURL(THIS.cUrlB, 2, "PnlHome")
    
    this.Assert(poContext.lAdmin)
    this.assert(inlist(this.cPage_Orient, "Outer", "Inner"), "invalid orientation")
    this.assert(inlist(this.cPage_Side, "Up", "Down"), "invalid side")

    this.cSubTitle = "Set Panel Location for " + this.oPnl.Pnl_ID
    local loForm, vp_cPlc_PK, loQ
    loQ = createobject("AisLocQuery")
    with loQ
      .cAlias = "Available_Locations_"
      .lHasPanel = .f.
      .cSide = this.cPage_Side
      .cOrient = this.cPage_Orient 
      .lSkip = .f. 
      .Execute()
    endwith 
    this.assert(loQ.nTally > 0, "No open slots remain.")

    vp_cPlc_PK = space(32)
    use V_PanelLocation in select("V_PanelLocation")
    cursorsetprop("Buffering", 5, "V_PanelLocation")
    loForm = this.createForm('aisPanelSetLocForm', this.cUrlC)
    with loForm
      .AddControls()
      .DoEvents() 

      if .Valid()
        select V_PanelLocation
        append blank
        replace Plc_Pnl_FK with this.cPnl ;
          Plc_Orientation with this.cPage_Orient 

        .UpdateControlSources()
        select V_PanelLocation  && UpdateControlSources can alter work area
        StampRec( CurrentUser, THIS.tNow )
        scatter memo name loNewRec 
        
        * Now save the record using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail
        llSendEmail = .f.  
        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor("V_PanelLocation")

        if loTrans.Save()  
          select V_PanelLocation 
          Response.Redirect(this.cCancelUrl)
          return 
        else 
          this.ErrorMsg( "Database Failure Saving Record!", ;
            "Error " + TRANSFORM( loTrans.aFailures[1, 1]) + [ :] + ;
            loTrans.aFailures[1, 2] )
          ** this.ServerError(textmerge('Database Failure Saving Record. Error <<loTrans.aFailures[1, 1]>>: <<loTrans.aFailures[1, 2]>>'))
          return  
        endif  && Save()
        
      endif 
    endwith 
    response.write(loForm.render())
  endfunc 
enddefine 

*** ========================================================= ***
define class aisPanelSetLocForm as AisForm
  cTitle = "Set Panel Location Form"
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject("cboLoc_FK", "L7Popup")
      with .cboLoc_FK
        .cControlSource = "V_PanelLocation.Plc_Loc_FK"
        .lRequired = .t.
        .cLabel = "Bridge Location"
        .lAutoRender = .T.
        .nRowSourceType = L7_ROWSOURCETYPE_ALIAS
        .cRowSource = "Available_Locations_"
        *!* ex: .cFilterExpression = [Fac_Storage = .t.]
        .cValueExpression = [Loc_PK]
        .cLabelExpression = [Loc_Side + "-" + str(loc_no)]
        .vFirstItemValue = space(32) && 0 for integer keys
        .cFirstItemLabel = "[ select from choices below ]"
      endwith 
    endwith
    return 
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_PnlHome as aisPnlPage 
  oPage_Location = null 
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    dodefault()
    this.oPage_Location = aisGetPanelLocation(this.cPnl)
    return 
  endfunc   
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local lcUrl
    with this
      .AddSubMenu("This", "This Panel")

      if poContext.lAdmin
        .addMenuItem("main\This,page", "Edit Panel...", StuffUrl(.cUrlA, 2, "PnlForm", "pnl", .cPnl))

        .addMenuItem("main\This,page", "Upload Panel File...", StuffUrl(.cUrlA, 2, "PnlFilNew", "pnl", .cPnl))

        if .oPnl.Pnl_Single_Piece = .f. and !.oPnl.Pnl_Completed 
          .addMenuItem("main\This,page", "Add Piece to Panel...", ;
            StuffUrl(.cUrlA, 2, "PnlAddPiece", "pnl", .cPnl))
        endif
        lcUrl = StuffUrl(.cUrlB, 2, "PnlSetLoc")
        if isnull(this.oPage_Location)
          .AddMenuItem("main\This,page", "Assign Up-River Inner Location...", ;
            StuffUrl(m.lcUrl, "side", "Up", "orient", "Inner"))
          .AddMenuItem("main\This,page", "Assign Up-River Outer Location...", ;
            StuffUrl(m.lcUrl, "side", "Up", "orient", "Outer"))
          .AddMenuItem("main\This,page", "Assign Down-River Inner Location...", ;
            StuffUrl(m.lcUrl, "side", "Down", "orient", "Inner"))
          .AddMenuItem("main\This,page", "Assign Down-River Outer Location...", ;
            StuffUrl(m.lcUrl, "side", "Down", "orient", "Outer"))
        else 
          .addMenuItem("main\This,page", "Remove Panel Location...", ;
            StuffUrl(.cUrlB, 2, "PnlRemLoc", "plc", this.oPage_Location.plc_pk))
        endif 
      endif 
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Panel " + htWrap(this.oPnl.Pnl_ID, 'span',, 'id-field panel')
    response.write(this.page_getMainRecord())

    if poContext.lAdmin
      response.write(HTWrap(L7ShowObject(this.oPnl, , [class="record"]),'div','admin'))
    endif
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData, loPlc, lcFileName
    lcRet = ""
    loData = this.oPnl
    loPlc = this.oPage_Location 
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      .cCaption = this.cSubTitle
      .AddHeading('Key Information')
      
      .AddRow("Panel ID", loData.Pnl_ID,, "id-field panel" )

      .AddRow("Single-Piece?", loData.Pnl_Single_Piece)

      lcFileName = forceext(loData.Pnl_ID + "_main", "jpeg")
      if file(aisPanelFilePath(loData.Pnl_ID) + m.lcFileName)
        .AddRow("Image", HTImage(aisPanelWebFilePath(loData.Pnl_ID) + m.lcFileName, "Panel " + loData.Pnl_ID))
      else
        if poContext.lAdmin
          .addRow("Image", HTLink(StuffUrl(this.cUrlA, 2, "PnlFilNew", "pnl", this.cPnl), "Upload Panel File..."))
        endif 
      endif
      
      .AddRow("Dimension 1", loData.Pnl_Dim_1)
      .AddRow("Dimension 2", loData.Pnl_Dim_2)
      .AddRow("Description and Comments", L7ParseOnView(loData.Pnl_COMMENTS), .t.)

      .AddRow("Completed?", loData.Pnl_Completed)
      .AddRow("Artist Name", ;
        HTLink(StuffUrl(this.cUrlA, 2, "ArtHome", "art", loData.Pnl_Stitcher_Art_FK), aisArtistName(loData.Pnl_Stitcher_Art_FK)))
      .AddRow("Current Storage Facility", ;
        HTLink(StuffUrl(this.cUrlA, 2, "FacHome", "fac", loData.Pnl_Fac_FK), aisFacilityName(loData.Pnl_Fac_FK)),,'facility')
            
      loRow.clear()
      loRow.cLabel = "Bridge Location"
      loRow.vValue = aisFormatPanelLocation(this.oPage_Location)
      .AddRowEx(m.loRow)
      
      .AddHeading('Pieces Comprising Panel')
      .AddRow(null, this.page_getPieceInfo())

      if poContext.lCore
        .AddRow("Internal KtB Notes", L7ParseOnView(loData.Pnl_NOTES), .t., "private")
      endif

      if poContext.lCore
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.Pnl_PK), .F., "private")
        .AddRow("Deleted", loData.Pnl_INACTIVE, .t., "private")
        .AddRow("Created", TRANSFORM(loData.Pnl_ORIG_TIME) + [ by ] + AisArtistName(loData.Pnl_Orig_Art_FK), .F., "private")
        .AddRow("Last Modified", TRANSFORM(loData.Pnl_REV_TIME) + [ by ] + AisArtistName(loData.Pnl_Rev_Art_FK), .F., "private")
      endif

      lcRet = m.lcRet + .Render()

    endwith 
    return m.lcRet
  endfunc && page_getMainRecord
  * ----------------------------------------------------- *  
  function page_getPieceInfo()
    local lcRet, loQ, loTbl, loCol
    lcRet = ''
    *!* lcRet = m.lcRet + HTWrap("Pieces from " + this.cSubTitle, 'h3')
    loQ = createobject("AisPceQuery")
    with loQ
      .cPnl = this.cPnl
      .lJoinArtist = .t. 
      .lJoinFacility = .t.
      .Execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "PceHome"), "PceHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PceForm"), "PceForm")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    urls.add(StuffUrl(this.cUrlA, 2, "FacHome"), "FacHome")

    select (loQ.cAlias)
    loTbl = createobject("AisTable")
    with loTbl
      ** loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pce_ID", "Piece ID", ;
        [HTLink(StuffUrl(urls.item("PceHome"), "pce", Pce_PK), Pce_ID)], "id-field piece")
      loCol = .addCursorColumn("Art_ID", "Artist ID", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pce_Art_FK), Art_ID)], "id-field artist")
      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pce_Art_FK), aisArtistName(THISRECORD))])
      loCol = .AddCursorColumn('Pce_Whole_Panel', 'Whole Panel?')
      loCol = .AddCursorColumn('Pce_Dim_1', 'Dim 1')
      loCol = .AddCursorColumn('Pce_Dim_2', 'Dim 2')
      loCol = .addCursorColumn("Pce_Comments", "Comments")
      loCol = .AddCursorColumn('Pce_Shipped', 'Shipped')
      loCol = .AddCursorColumn('Pce_Received', 'Received')

      if poContext.lAdmin
        loCol = .addCursorColumn("Pce_Notes", "Notes",, "private")
        loCol = .addCursorColumn("Pce_PK", "Edit Piece", ;
          'HTLink(StuffUrl(urls.item("PceForm"), "pce", Pce_PK), "[Edit&nbsp;Piece...]")')
      endif
      lcRet = m.lcRet + .Render()
    endwith 
    
    return m.lcRet
  endfunc && page_getPieceInfo
enddefine && PnlHome

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
    loForm = this.createForm('aisPanelForm', this.cUrlC)
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
    return 
  endfunc 
enddefine && ais_PnlForm

*** ========================================================= ***
define class aisPanelForm as AisForm
  cTitle = "Panel Form"
  * --------------------------------------------------------- *
  function  AddControls
    with this
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

      .AddObject("lblPk", "L7Label")
      with .lblPk
        .cGroupID = "ID"
        .cControlSource = "V_Panel.Pnl_Pk"
        .cLabel = "Internal Key"
        .cCssClass = "FormControlPrivate"
      endwith 

      .AddObject("chkInactive", "L7Checkbox")
      with .chkInactive
        .cGroupID = "ID"
        .cControlSource = "V_Panel.Pnl_Inactive"
        .cLabel = "Delete?"
        .lDisabled = !m.poContext.lAdmin
        .cCssClass = "FormControlPrivate"
      endwith
      
      .AddObject("cboLoc_FK", "L7Popup")
      with .cboLoc_FK
        .cControlSource = "V_Panel.Pnl_Fac_FK"
        .lRequired = .t.
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

      .AddObject("chkCompleted", "L7Checkbox")
      with .chkCompleted
        .cGroupID = "DIM"
        .cControlSource = "V_Panel.Pnl_Completed"
        .cLabel = "Completed?"
      endwith
      
      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cGroupID = "NOTES"
        .cControlSource = "V_Panel.Pnl_Comments"
        .cLabel = "Description and Comments"
        .nRows = 3
      endwith 

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cGroupID = "NOTES"
        .cControlSource = "V_Panel.Pnl_Notes"
        .cLabel = "Internal KtB Notes"
        .nRows = 3
        .cCssClass = "FormControlPrivate"
      endwith
    endwith
  endfunc
enddefine  && PanelForm

*** ===================================================== ***
define class AisPnlQuery as L7Query
  cBaseTable = "Panel"
  cDefaultFieldList = ;
    "Pnl_PK, Pnl_ID, Pnl_Stitcher_Art_FK, Pnl_Asm_FK, Pnl_Fac_FK, Pnl_Single_Piece" + ;  
    ", Pnl_Dim_1, Pnl_Dim_2, Pnl_Completed, Pnl_Comments, Pnl_Notes" 

  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Pnl_ID"

  cID = null 
  
  cAsm = null
  cFac = null
  
  cArtPiece = null
  cArtStitcher = null 
  
  lHasLocation = null

  lCompleted = null
  lSinglePiece = null
  
  lJoinArtist = .f. 
  lJoinPiece = .f. 
  lJoinFacility = .f.
  lJoinLocation = .f. 
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .T.
      .cWhereClause = [WHERE Pnl_Inactive = .F.] 

      if !isnull(.cID)
        .cWhereClause = .cWhereClause + [ and Pnl_Id = '] + .cId + [']
      endif
      
      if !isnull(.cArtPiece) or .lJoinPiece
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Piece"
        .aJoins[.nJoins, 2] = "Pnl_Pce_FK = Pce_PK"
        if !isnull(.cArtPiece) 
          .cWhereClause = .cWhereClause + [ and Pce_Art_FK = '] + .cArtPiece + [']
        endif 
      endif 

      if .lJoinFacility
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Facility"
        .aJoins[.nJoins, 2] = "Pnl_Fac_FK = Fac_PK"
        .aJoins[.nJoins, 3] = "LEFT OUTER"
        .AddFields("Fac_ID, Fac_Name")
      endif 

      if .lJoinLocation
        .nJoins = .nJoins + 2
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins - 1, 1] = "PanelLocation"
        .aJoins[.nJoins - 1, 2] = "Pnl_PK = Plc_Pnl_FK"
        .aJoins[.nJoins - 1, 3] = "LEFT OUTER"

        .aJoins[.nJoins, 1] = "Location"
        .aJoins[.nJoins, 2] = "Plc_Loc_FK = Loc_PK"
        .aJoins[.nJoins, 3] = "LEFT OUTER"

        .AddFields("Plc_Orientation, Loc_Side, Loc_No")
      endif 

      if .lJoinArtist
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Artist"
        .aJoins[.nJoins, 2] = "Pnl_Stitcher_Art_FK = Art_PK"
        .aJoins[.nJoins, 3] = "LEFT OUTER"
        .AddFields("Art_ID,Art_Last_Name,Art_First_Name,Art_Anonymous,Art_Full_Name")
      endif 

      if !isnull(.cArtStitcher) 
        .cWhereClause = .cWhereClause + [ and Pnl_Stitcher_Art_FK = '] + .cArtStitcher + [']
      endif 
      if !isnull(.cAsm)
        .cWhereClause = .cWhereClause + [ and Pnl_Asm_FK = '] + .cAsm + [']
      endif 
      if !isnull(.cFac)
        .cWhereClause = .cWhereClause + [ and Pnl_Fac_FK = '] + .cFac + [']
      endif 
      if !isnull(.lSinglePiece)
        .cWhereClause = .cWhereClause + [ and Pnl_Single_Piece = ] + iif(.lSinglePiece, [.t.], [.f.])
      endif 
      if !isnull(.lCompleted)
        .cWhereClause = .cWhereClause + [ and Pnl_Completed = ] + iif(.lCompleted, [.t.], [.f.])
      endif 

      if !isnull(.lHasLocation)
        .cWhereClause = .cWhereClause + [ and Pnl_PK] + iif(.lHasLocation, [ in ], [ not in ]) + ;
          [(select Plc_Pnl_FK from PanelLocation where !plc_Inactive)]
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisPnlQuery

* end: PNL 
