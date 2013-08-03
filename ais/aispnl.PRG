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
    where Plc_Pnl_FK = m.tcPnl and !Plc_Inactive ;
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
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local lcMenu
    with this
      lcMenu = "main\This"
      if !.lPnlRequired  && general lists/pages
        .AddSubMenu("This", "PANELS")

        .addMenuItem(m.lcMenu, 'Panel w/Bridge Locations', StuffUrl(this.cUrlB, 2, "PnlList", "location", "1"))
        .addMenuItem(m.lcMenu, 'Panels Still Available', StuffUrl(this.cUrlB, 2, "PnlList", "location", "0"))
        .addMenuItem(m.lcMenu, 'ALL Active Panels', StuffUrl(this.cUrlB, 2, "PnlList", "location", .f.))

        .addMenuItem(m.lcMenu, 'Special-Size Panels', StuffUrl(this.cUrlB, 2, "PnlList", "flags", "special"))
        .addMenuItem(m.lcMenu, 'Incomplete Panels', StuffUrl(this.cUrlB, 2, "PnlList", "complete", "0"))
        .addMenuItem(m.lcMenu, 'Excluded Panels', StuffUrl(this.cUrlB, 2, "PnlList", "flags", "excluded"))
        .addMenuItem(m.lcMenu, 'Deleted Panels', StuffUrl(this.cUrlB, 2, "PnlList", "flags", "inactive"))

      endif
      .addMenuItem(m.lcMenu, 'Edit ALL Panel Metadata', StuffUrl(this.cUrlA, 2, "PnlBrowse"))
    endwith 
    dodefault()
    return 
  endfunc 
enddefine && AisPnlPage

*** ========================================================= ***
define class ais_PnlSummary as aisPnlPage 
  lPnlRequired = .f.
  cSubTitle = "Panel Summary"
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisPnlQuery")
    with loQry
      .lJoinFacility = .t.
      
      .ClearFields()  && remove default fields
      .AddField([Fac_Order])
      .AddField([Pnl_Fac_FK])
      .AddField([Fac_Name])
      .AddField([SUM(iif(Pnl_Completed, 1, 0))], "Cmpl_")
      .AddField([COUNT(*)], "Total_")
      .BuildFieldList() && stops AddFields in BuildWhereClause from injecting
      
      .AddOrderBy([Fac_Order])
      .AddOrderBy([Pnl_Fac_FK], , .t.)
      .AddOrderBy([Fac_Name], , .t.)
      .nGrouping = 3
      
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "FacHome"), "FacHome")
    select (loQry.cAlias)
    loTbl = createobject("AisTable")
    with loTbl
      loCol = .addCursorColumn("Fac_Name", "Storage Facility", ;
        [HTLink(StuffUrl(urls.item("FacHome"), "fac", Pnl_Fac_FK), trim(Fac_Name))], 'facility')

      loCol = .addCursorColumn("Total_ - Cmpl_", "Incomplete<br>Panels")
      loCol.nCalcType = L7_CALCTYPE_SUM

      loCol = .addCursorColumn("Cmpl_", "Completed<br>Panels")
      loCol.nCalcType = L7_CALCTYPE_SUM

      loCol = .addCursorColumn("Total_", "Total<br>Panel Count")
      loCol.nCalcType = L7_CALCTYPE_SUM
    endwith
        
    response.Write(loTbl.Render())    
    response.write(HTWrap(loQry.cSqlStatement, 'div', 'admin'))
    return 
  endfunc 
  * ----------------------------------------------------- *  
enddefine && PnlSummary

*** ========================================================= ***
define class ais_PnlList as aisPnlPage 
  lPnlRequired = .f.
  cSubTitle = "Panel List"

  lPage_Location = null
  lPage_Complete = null
  cPage_Style = null 
  cPage_Flags = null
  cPage_Order = null
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr

    lcStr = this.ReadQueryString("location", .t., .t.)
    this.lPage_Location = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')
    
    lcStr = this.ReadQueryString("complete", .t., .t.)
    this.lPage_Complete = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')

    this.cPage_Style = evl(this.ReadQueryString("style", .t., .F.), "table") && note: left in urlB to style transcends menu selections
    this.cPage_Flags = this.ReadQueryString("flags", .t., .t.)

    this.cPage_Order = evl(this.ReadQueryString("order", .t., .t.), "id")

    dodefault()  && required bubble-up
    return    
  endfunc  
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local lcMenu
    with this
      lcMenu = "main\This"
      if this.cPage_Style = "table"
        .addMenuItem(m.lcMenu, 'Show as Gallery', StuffUrl(this.cUrlC, "style", "gallery"))
      else
        .addMenuItem(m.lcMenu, 'Show as Table', StuffUrl(this.cUrlC, "style", "table"))
      endif 
      
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry
       
    loQry = createobject("AisPnlQuery")
    with loQry
      .lHasLocation = this.lPage_Location 
      .lCompleted = this.lPage_Complete
      .lJoinFacility = .t.
      .lJoinLocation = .t. 
      .lJoinArtist = .t. 
      if "," + "special" + "," $ "," + this.cPage_Flags + ","
        .lSpecialSize = .t. 
      endif 
      if "," + "excluded" + "," $ "," + this.cPage_Flags + ","
        .lExcluded = .t. 
      endif 
      if "," + "inactive" + "," $ "," + this.cPage_Flags + ","
        .lInactive = .t. 
      endif 
      do case
      case empty(this.cPage_Order) or lower(this.cPage_Order) == "id"
        .AddOrderBy("Pnl_Id")
      case lower(this.cPage_Order) == "categ"
        .AddOrderBy("Pnl_Design_Category")
        .AddOrderBy("Pnl_Id", .f., .t.)
      endcase
      .execute()

      this.cSubTitle = this.cSubTitle + ": " + .GetCaption()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "PnlHome"), "PnlHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PnlForm"), "PnlForm")
    urls.add(StuffUrl(this.cUrlA, 2, "FacHome"), "FacHome")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PnlFilNew", "return", this.cUrlC), "PnlFilNew")
    
    if this.cPage_Style = "table"
      response.write(this.page_getTableDisplay(m.loQry))
    else
      response.write(this.page_getGalleryDisplay(m.loQry))
    endif

    if poContext.lDeveloper
      Response.Write(HTWrap(loQry.cSqlStatement, 'div,p', 'admin,debug'))
    endif
    
    return 
  endfunc 

  * ----------------------------------------------------- *  
  function page_getGalleryDisplay(loQry)
    local lcTmp, lcItem, lcRet, lcTOC, lcCat, llIsCat
    lcRet = ""
    lcTOC = ""
    lcCat = null
    llIsCat = lower(this.cPage_Order) == "categ"
    text to lcTmp noshow 
      <div class="gallery-item<<iif(Pnl_Completed,'',' incomplete')>>">
       <<AisPanelImage(Pnl_Id, "_h50", urls.item("PnlFilNew"), Pnl_PK, poContext.lAdmin)>>
       <div class="gallery-item-info">
        <<HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pnl_PK), AisFormatID(Pnl_ID))>>
        <br/><<transform(Pnl_Dim_1)>>x<<transform(Pnl_Dim_2)>>
        <<iif(Pnl_Special_Size, " (special)","")>> 
        (<<trim(evl(Pnl_Design_Category,"n/a"))>>)
       </div>
      </div>
      
    endtext 
    select (loQry.cAlias)
    scan
      if m.llIsCat and (isnull(m.lcCat) or !m.lcCat == Pnl_Design_Category)
        lcCat = Pnl_Design_Category
        lcRet = m.lcRet + textmerge('<div id="grp-<<trim(m.lcCat)>>" class="gallery-group">Design Category: <<evl(m.lcCat, "n/a")>></div>') + crlf
        lcToc = m.lcToc + textmerge('<span><a href="#grp-<<trim(m.lcCat)>>"><<evl(m.lcCat, "n/a")>></a></span>') + crlf
      endif
      lcItem = textmerge(m.lcTmp)
      lcRet = m.lcRet + m.lcItem
    endscan
    if m.llIsCat 
      lcToc = HTWrap("Design Categories:&nbsp;" + m.lcToc, "div", , "gallery-toc")
    endif
    return m.lcToc + m.lcRet + [<div class="clear"></div>] + crlf
  endfunc && page_getGalleryDisplay
    
  * ----------------------------------------------------- *  
  function page_getTableDisplay(loQry)
    local loTbl, loCol, loGrp

    select (loQry.cAlias)
    loTbl = createobject("AisTable")
    with loTbl
      .cTableCaption = this.cSubTitle 

      .cDataRowClass = .cDataRowClass + iif(empty(.cDataRowClass), [], [ + ]) + [iif(Pnl_Inactive, " deleted", "")]
      
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pnl_ID", "Panel ID", ;
        [HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pnl_PK), AisFormatID(Pnl_ID))], 'id-field panel')
      loCol = .addCursorColumn("Pnl_Single_Piece", "Single-Piece?")

      loCol = .addCursorColumn("Pnl_Dim_1", "Height")
      loCol = .addCursorColumn("Pnl_Dim_2", "Width")
      loCol = .addCursorColumn("Pnl_Special_Size", "Special<br>Size", [iif(Pnl_Special_Size,"Special Size","")])
      loCol = .addCursorColumn("Pnl_Design_Category", "Des<br>Cat")
      loCol = .addCursorColumn("Pnl_Comments", "Comments")
      loCol = .addCursorColumn("Pnl_ID", "Image", ;
        [AisPanelImage(Pnl_Id, "_h25", urls.item("PnlFilNew"), Pnl_PK, poContext.lAdmin)])

      loCol = .addCursorColumn("Pnl_Notes", "Notes",, "private")
      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pnl_Stitcher_Art_FK), aisArtistName(THISRECORD))], 'artist')
      loCol = .addCursorColumn("Pnl_Completed", "Completed?")
      loCol = .addCursorColumn("Fac_Name", "Current Storage Facility", ;
        [HTLink(StuffUrl(urls.item("FacHome"), "fac", Pnl_Fac_FK), trim(Fac_Name))], 'facility')
      loCol = .addCursorColumn("Plc_Orientation", "Bridge<br>Location", ;
        [<<trim(Loc_Side)>>-<<Loc_No>> (<<Plc_Orientation>>)], 'location')
      loCol.lDisplayTextmerge = .t. 

      if poContext.lAdmin
        loCol = .addCursorColumn("Pnl_PK", "Edit Panel", ;
          'HTLink(StuffUrl(urls.item("PnlForm"), "pnl", Pnl_PK), "[Edit&nbsp;Panel...]")', 'panel', "no-print")
        loCol.cHeadingClass = "nosort no-print" 
      endif 
    endwith 
    
    return loTbl.render() 
  endfunc && page_getTableDisplay 
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
* sub-class for arriving via LocDisplay: 
define class ais_LocUnassign as ais_PnlRemLoc 
  lPnlRequired = .f.
  * ----------------------------------------------------- *  
  function page_getCancelUrl()
    return StuffURL(THIS.cUrlA, 2, "LocDisplay")
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_PnlRemLoc as aisPnlPage 
  cPage_Plc = null 
  cSubTitle = "Remove Panel Location" 
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    this.cPage_Plc = this.readQueryString("plc", .t., .t.)
    dodefault()
    return 
  endfunc   
  * ----------------------------------------------------- *  
  function page_getCancelUrl()
    return StuffURL(THIS.cUrlB, 2, "PnlHome")
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = this.page_getCancelUrl()
    this.Assert(poContext.lAdmin)

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

    this.cSubTitle = "Set Panel Location for " + AisFormatID(this.oPnl.Pnl_ID)
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
    return 
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

*** ===================================================== ***
define class Ais_PnlBrowse as AisPnlPage
  lPnlRequired = .f.
  * --------------------------------------------------------- *
  function ProcessRequest
    this.cCancelUrl = StuffUrl(this.cUrlA, 2, "PnlList")
    local loForm, lcXml, lcAlias, lcFldState, lcStub
    lcAlias = "V_Active_Panel_Set"
    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    select (m.lcAlias)
    loForm = this.CreateForm("AisPnlBrowseForm", this.cUrlC)
    with loForm
      .cAlias = m.lcAlias
      .AddControls()
      .DoEvents()
      if .Valid()
        .UpdateControlSources()
        select (m.lcAlias)
        scan   
          lcFldState = getfldstate(-1)
          if empty( strtran( m.lcFldState, "1"))  && no change
            loop 
          endif 
          StampRec( CurrentUser, THIS.tNow )
        endscan 
        lcXml = ''
        this.AssertTransaction(m.lcAlias, @lcXml)
        Response.Redirect(this.cCancelUrl)
        return 
      endif 
      Response.Write(.Render())
      this.page_upperCaseScript('_TXTCAT')

    endwith 
    return   
  endfunc 
enddefine  && Ais_PnlBrowse

*** ========================================================= ***
define class AisPnlBrowseForm AS AisForm
  cTitle = "Panel Metadata Form"
  cAlias = null && client should set 
  cCssStyle = "width: 100%;"
  cID = "frmPnlBrow"
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject('grd1', 'L7Grid')
      with .grd1
        .cChildAlias = this.cAlias
        .cChildKeyExpression = this.cAlias + ".Pnl_PK"
        .nExtraRows = 0 && don't permit adds 
        .cGridTableCssClass = "sortable " + .cGridTableCssClass 
        .cColumnHeaderCssClass = "nosort" && sortable doesn't work for live controls, so override on specific labels
      
        .AddObject("lblId", "L7Label")
        with .lblId
          .cFieldType = "C"
          .cControlSource = this.cAlias + ".Pnl_Id"
          .cLabel = "ID"
          .cColumnHeaderCssClass = "sort" 
        endwith 

        .AddObject("txtDim_1", "L7Textbox")
        with .txtDim_1
          .cControlSource = this.cAlias + ".Pnl_Dim_1"
          .cFieldType = "C"
          .cLabel = "Width"
          .lDisabled = .t.
        endwith

        .AddObject("txtDim_2", "L7Textbox")
        with .txtDim_2
          .cControlSource = this.cAlias + ".Pnl_Dim_2"
          .cFieldType = "C"
          .cLabel = "Width"
          .lDisabled = .t.
        endwith

        .AddObject("chkSp", "L7Checkbox")
        with .chkSp
          .cControlSource = this.cAlias + ".Pnl_Special_Size"
          .cLabel = "Special Size?"
          .cCaption = "SPECIAL"
          .lDisabled = .t.
        endwith

        .AddObject("txtCat", "L7Textbox")
        with .txtCat
          .cControlSource = this.cAlias + ".Pnl_Design_Category"
          .cLabel = "Design Cat"
        endwith

        .AddObject("lblImage", "L7Label")
        with .lblImage
          .cFieldType = "C"
          .cShowExpression = [AisPanelImage(] + this.cAlias + [.Pnl_Id, "_h25")]
          .cLabel = "Image"
        endwith 

        .AddObject("lblComments", "L7Label")
        with .lblComments
          .cControlSource = this.cAlias + ".Pnl_Comments"
          .cLabel = "Comments"
        endwith

        .AddObject("chkCmpl", "L7Checkbox")
        with .chkCmpl
          .cControlSource = this.cAlias + ".Pnl_Completed"
          .cLabel = "Complete?"
          .cCaption = "COMPLETE"
          .cCssClass = "FormControlPrivate"
        endwith

        .AddObject("lblId2", "L7Label") && << -- REPEATED FOR CONVENIENCE
        with .lblId2
          .cFieldType = "C"
          .cControlSource = this.cAlias + ".Pnl_Id"
          .cLabel = "ID"
          .cColumnHeaderCssClass = "sort" 
        endwith 

        *!*          .AddObject("chkExcl", "L7Checkbox")
        *!*          with .chkExcl
        *!*            .cControlSource = this.cAlias + ".Pnl_Excluded"
        *!*            .cLabel = "Exclude?"
        *!*            .cCaption = "EXCLUDED"
        *!*            .cCssClass = "FormControlPrivate"
        *!*          endwith

      endwith && grid 
    endwith && form
    return 
  endfunc  && AddControls
enddefine && PnlBrowseForm 

*** ========================================================= ***
define class ais_PanelInfo as ais_PnlHome
  nMinLoginLevel = L7_NONE  && PUBLIC 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    if poContext.lCore
      this.addMenuItem("main\This,page", "Panel Page", StuffUrl(this.cUrlA, 2, "PnlHome", "pnl", this.cPnl), , "PnlHome")
    endif
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loOut
    this.oJsonContents = createobject("Empty")
    loOut = this.oJsonContents
    addproperty(loOut, "pnl_id", this.oPnl.Pnl_ID)
    addproperty(loOut, "pnl_pk", this.oPnl.Pnl_PK)
    addproperty(loOut, "single_piece", this.oPnl.Pnl_Single_Piece)
    addproperty(loOut, "loc_id", AisFormatPanelLocation(this.oPage_Location))
    addproperty(loOut, "loc_info", "")
    do case
    case this.oPnl.Pnl_Excluded
      loOut.loc_info = HtWrap([Panel was not able to be installed on the bridge.], 'p')
    case isnull(this.oPage_Location)
      loOut.loc_info = HtWrap([Panel does not yet have a location on the bridge.], 'p')
    otherwise      
      loOut.loc_info = AisDescribeLocation(this.oPage_Location)
    endcase 
    addproperty(loOut, "created_by", this.page_getCreatedBy())
    if !empty(this.oPnl.Pnl_Story)
      addproperty(loOut, "story", this.oPnl.Pnl_Story)
    endif
    if !empty(this.oPnl.Pnl_URL)
      addproperty(loOut, "url", this.oPnl.Pnl_URL)
    endif

    if this.cResponseType = "json"
    else
      response.write(L7ShowObject(m.loOut))
    endif
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getCreatedBy
    local loQ, lcRet, loPnl, loArt, lcName
    loPnl = this.oPnl
    lcRet = ""
    loQ = createobject("AisPceQuery")
    with loQ
      .lJoinArtist = .t.
      .cPnl = this.cPnl
      .execute()
    endwith
    
    select (loQ.cAlias)
    scan
      if Art_Release_Name
        scatter memo name loArt
        lcName = HtWrap(AisArtistName(m.loArt), 'strong')
      else
        lcName = "Anonymous"
      endif 
      if loPnl.Pnl_Single_Piece
        lcRet = m.lcRet + HtWrap("Panel created by: " + m.lcName, "p")
      else
        lcRet = m.lcRet + HtWrap(m.lcName, "li")
      endif
    endscan
    if !loPnl.Pnl_Single_Piece
      lcRet = HTWrap("Pieces created by:", "p") + HTWrap(m.lcRet, "ul")
    endif
    return m.lcRet
  endfunc && page_getCreatedBy
enddefine && ais_PanelInfo 

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
      endif

      use v_Active_Panel_Set again in select("v_Active_Panel_Set")
      select v_Active_Panel_Set
      locate for Pnl_Id = this.oPnl.Pnl_Id
      if found()
        skip
        if !eof()
          .addMenuItem("main\This,page", "NEXT Panel (" + Pnl_Id + ")", StuffUrl(.cUrlA, "pnl", Pnl_PK))
        endif
        locate for Pnl_Id = this.oPnl.Pnl_Id
        skip -1
        if !bof()
          .addMenuItem("main\This,page", "PREVIOUS Panel (" + Pnl_Id + ")", StuffUrl(.cUrlA, "pnl", Pnl_PK))
        endif
      endif
      use in select("v_Active_Panel_Set")
      
      .addMenuItem("main\This,page", "Find Panel (public)", ;
        StuffUrl(.cUrlA, 2, "LocateByPanelID", "pnl_id", .oPnl.Pnl_ID))

      if poContext.lAdmin
        .addMenuItem("main\This,page", "PanelInfo.json (public)", ;
          StuffUrl(.cUrlB, 1, "json", 2, "PanelInfo"))
        .addMenuItem("main\This,page", "Upload Panel File...", StuffUrl(.cUrlA, 2, "PnlFilNew", "pnl", .cPnl))

        if .oPnl.Pnl_Single_Piece = .f. and !.oPnl.Pnl_Completed 
          .addMenuItem("main\This,page", "Add Piece to Panel...", ;
            StuffUrl(.cUrlA, 2, "PnlAddPiece", "pnl", .cPnl))
        endif
      endif 
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Panel " + HtWrap(AisFormatID(this.oPnl.Pnl_ID), 'span',, 'id-field panel')
    response.write(this.page_getMainRecord())

    if poContext.lAdmin
    *!*        response.write(HTWrap(L7ShowObject(this.oPnl, , [class="record"]),'div','admin'))
    endif
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData, loPlc, lcFileName, llDeleted
    lcRet = ""
    loData = this.oPnl
    llDeleted = loData.Pnl_Inactive 
    loPlc = this.oPage_Location 
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      if m.llDeleted
        .cCssClass = .cCssClass + " deleted"
        this.cSubTitle = this.cSubTitle + " [DELETED]"
      endif
      if this.oPnl.Pnl_Excluded
        .cCssClass = .cCssClass + " excluded"
        this.cSubTitle = this.cSubTitle + " [EXCLUDED]"
      endif
      .cCaption = this.cSubTitle
      .AddHeading('Key Information')
      
      loRow.clear()
      loRow.cLabel = "Panel ID"
      loRow.vValue = HTWrap(AisFormatID(loData.Pnl_ID), 'span',, "id-field panel" )
      if poContext.lAdmin
        loRow.Links.add(HTLink(StuffUrl(This.cUrlB, 2, "PnlForm", "pnl", this.cPnl), "Edit Panel..."))
      endif
      .AddRowEx(m.loRow)

      .AddRow("Single-Piece?", loData.Pnl_Single_Piece)

      lcFileName = forceext(loData.Pnl_ID + "_main", "jpeg")
      if file(aisPanelFilePath(loData.Pnl_ID) + m.lcFileName)
        .AddRow("Image", HTImage(aisPanelWebFilePath(loData.Pnl_ID) + m.lcFileName, "Panel " + loData.Pnl_ID))
      else
        if poContext.lAdmin
          .addRow("Image", HTLink(StuffUrl(this.cUrlA, 2, "PnlFilNew", "pnl", this.cPnl), "Upload Panel File..."))
        endif 
      endif
      
      .AddRow("Height", loData.Pnl_Dim_1)
      .AddRow("Width", loData.Pnl_Dim_2)
      .AddRow("Special Size?", iif(loData.Pnl_Special_Size, "Special Size", "no"))
      .AddRow("Design Category", loData.Pnl_Design_Category)
      .AddRow("Description and Comments", L7ParseOnView(loData.Pnl_COMMENTS), .t.)
      if poContext.lCore
        .AddRow("Internal KtB Notes", L7ParseOnView(loData.Pnl_NOTES), .t., "private")
      endif

      .AddRow("Completed?", loData.Pnl_Completed)
      .AddRow("Artist Name", ;
        HTLink(StuffUrl(this.cUrlA, 2, "ArtHome", "art", loData.Pnl_Stitcher_Art_FK), aisArtistName(loData.Pnl_Stitcher_Art_FK)))

      .AddRow("Artist's Story", L7ParseOnView(loData.Pnl_Story), .t.)
      .AddRow("URL", L7ParseOnView(loData.Pnl_Url), .t.)
            
      .AddHeading("Bridge Location")
      loRow.clear()
      loRow.cLabel = "Location ID and Orientation"
      if isnull(this.oPage_Location)
        do case
        case loData.Pnl_Inactive
          loRow.vValue = "N/A: Panel has been DELETED."
        case loData.Pnl_Excluded
          loRow.vValue = "N/A: Panel has been EXCLUDED."
        otherwise 
          loRow.vValue = "Panel location not yet assigned."
          lcUrl = StuffUrl(this.cUrlB, 2, "PnlSetLoc")
          loRow.links.add(HTLink(StuffUrl(m.lcUrl, "side", "Up", "orient", "Inner"), "Assign Up-River Inner Location..."))
          loRow.links.add(HTLink(StuffUrl(m.lcUrl, "side", "Up", "orient", "Outer"), "Assign Up-River Outer Location..."))
          loRow.links.add(HTLink(StuffUrl(m.lcUrl, "side", "Down", "orient", "Inner"), "Assign Down-River Inner Location..."))
          loRow.links.add(HTLink(StuffUrl(m.lcUrl, "side", "Down", "orient", "Outer"), "Assign Down-River Outer Location..."))
        endcase

      else
        loRow.vValue = HTWrap(aisFormatPanelLocation(this.oPage_Location), 'span',, 'id-field location')
        loRow.links.add(HTLink(StuffUrl(this.cUrlA, 2, "LocDisplay") + "#" + loData.Pnl_PK, "View on Bridge"))
        loRow.links.add(HTLink(StuffUrl(this.cUrlB, 2, "PnlRemLoc", "plc", this.oPage_Location.plc_pk), "Remove Panel Location"))

      endif 
      .AddRowEx(m.loRow)
      
      if !isnull(this.oPage_Location)
        .AddRow("How to Find", AisDescribeLocation(this.oPage_Location))
      endif
      
      .AddHeading('Pieces Comprising Panel')
      .AddRow(null, this.page_getPieceInfo())

      if poContext.lCore
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.Pnl_PK), .F., "private")
        .AddRow("Deleted", loData.Pnl_INACTIVE, .t., "private")
        .AddRow("Current Storage Facility", ;
          HTLink(StuffUrl(this.cUrlA, 2, "FacHome", "fac", loData.Pnl_Fac_FK), aisFacilityName(loData.Pnl_Fac_FK)),,'facility')
        .AddRow("History", L7ParseOnView(loData.Pnl_History))
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
      .lExcluded = null
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
      *!*        loCol = .AddCursorColumn('Pce_Shipped', 'Shipped')
      loCol = .AddCursorColumn('Pce_Received', 'Received')

      if poContext.lAdmin
        loCol = .addCursorColumn("Pce_Notes", "Notes",, "private")
        * This was encouraging people to edit the piece, not the panel:
        *!*          loCol = .addCursorColumn("Pce_PK", "Edit Piece", ;
        *!*            'HTLink(StuffUrl(urls.item("PceForm"), "pce", Pce_PK), "[Edit&nbsp;Piece...]")')
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
        if this.lAdding
          replace Pnl_History with Pnl_History + dtoc(date()) + " initial location: " + AisFacilityName(Pnl_Fac_FK) + CRLF 
        else
          if !loOldRec.Pnl_Fac_FK == Pnl_Fac_FK
            replace Pnl_History with Pnl_History + dtoc(date()) + " moved to: " + AisFacilityName(Pnl_Fac_FK) + CRLF 
          endif
        endif 
        StampRec( CurrentUser, THIS.tNow )
        scatter memo name loNewRec 
        
        * delete/free Pieces if deleted:
        if !this.lAdding and loNewRec.Pnl_Inactive and !loOldRec.Pnl_Inactive && just deleted
          aisReleasePieces(m.loNewRec)
        endif

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
    this.page_upperCaseScript('TXTDESIGN_CATEGORY')
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
          .cLabel = "Panel ID"
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

      .AddObject("chkExcluded", "L7Checkbox")
      with .chkExcluded
        .cGroupID = "ID"
        .cControlSource = "V_Panel.Pnl_Excluded"
        .cLabel = "Exclude?"
        .cCaption = "Excluded"
        .cInstructions = "Excluding makes panel unavailable for installation."
        .lDisabled = !m.poContext.lAdmin
        .cCssClass = "FormControlPrivate"
      endwith
      
      .AddObject("chkSingle_Piece", "AisRadioCheckbox")
      with .chkSingle_Piece
        * .cGroupID = "LOG"
        .cControlSource = "V_Panel.Pnl_Single_Piece"
        .cLabel = "Is this a single-piece panel?"
        .cCaption = "Yes - single piece"
        .cFalseCaption = "No - multiple pieces" 
      endwith 
      
      .AddObject("txtDim_1", "L7Textbox")
      with .txtDim_1
        *.cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_Panel.Pnl_Dim_1"
        .cLabel = "Height" && "Dimension 1 (inches)"
        * .cInstructions = "If not equal, please enter SMALLER dimension first!"
      endwith
       
      .AddObject("txtDim_2", "L7Textbox")
      with .txtDim_2
        *.cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_Panel.Pnl_Dim_2"
        .cLabel = "Width" && "Dimension 2 (inches)"
        * .cInstructions = "If not equal, please enter LARGER dimension second!"
      endwith 

      .AddObject("chkSpecial_Size", "AisRadioCheckbox")
      with .chkSpecial_Size
        *.cGroupID = "DIM"
        .cControlSource = "V_Panel.Pnl_Special_Size"
        .cLabel = "Special Size?"
        .cCaption = "Special Size"
        .cFalseCaption = "Normal Size"
      endwith

      .AddObject("txtDesign_Category", "L7Textbox")
      with .txtDesign_Category
        .cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_Panel.Pnl_Design_Category"
        .cLabel = "Design Category" 
      endwith 

      .AddObject("lblImage", "L7Label")
      with .lblImage
        .cFieldType = "C"
        .cShowExpression = [AisPanelImage(V_Panel.Pnl_Id, "_main")]
        .lNoLabel = .t. 
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

      .AddObject("edtStory", "L7Textarea")
      with .edtStory
        .cGroupID = "STORY"
        .cControlSource = "V_Panel.Pnl_Story"
        .cLabel = "Artist's Story"
        .nRows = 3
      endwith 

      .AddObject("edtURL", "L7Textarea")
      with .edtURL
        .cGroupID = "STORY"
        .cControlSource = "V_Panel.Pnl_URL"
        .cLabel = "URL"
        .cInstructions = "e.g., a YouTube post"
        .nRows = 2
      endwith 

      .AddObject("chkCompleted", "AisRadioCheckbox")
      with .chkCompleted
        .cGroupID = "LOGISTICS"
        .cControlSource = "V_Panel.Pnl_Completed"
        .cLabel = "Completed?"
        .cCaption = "Yes - Complete"
        .cFalseCaption = "No - Still Incomplete" 
      endwith
      
      .AddObject("cboLoc_FK", "L7Popup")
      with .cboLoc_FK
        .cGroupID = "LOGISTICS"
        .cControlSource = "V_Panel.Pnl_Fac_FK"
        .lRequired = .t.
        .cLabel = "Current Storage Facility"
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

    endwith
  endfunc
enddefine  && PanelForm

*** ===================================================== ***
define class AisPnlQuery as L7Query
  cBaseTable = "Panel"
  cDefaultFieldList = ;
    "Pnl_PK, Pnl_ID, Pnl_Inactive, Pnl_Stitcher_Art_FK, Pnl_Asm_FK, Pnl_Fac_FK, Pnl_Single_Piece" + ;  
    ", Pnl_Dim_1, Pnl_Dim_2, Pnl_Special_Size, Pnl_Design_Category, Pnl_Completed, Pnl_Excluded" + ;
    ", Pnl_Comments, Pnl_Notes, Pnl_Story_Pnl_URL" 

  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Pnl_ID"

  cID = null 
  
  lInactive = .f.  && whole record deleted
  lExcluded = .f.  && by default, omit excluded panels

  cAsm = null
  cFac = null
  
  cDesign_Category = null
  
  cArtPiece = null
  cArtStitcher = null 
  
  lHasLocation = null

  lCompleted = null
  lSinglePiece = null
  lSpecialSize = null
  
  lJoinArtist = .f. 
  lJoinPiece = .f. 
  lJoinFacility = .f.
  lJoinLocation = .f. 
  * --------------------------------------------------------- *
  function GetCaption 
    local lcRet
    lcRet = ""
    with this
      lcRet = m.lcRet + ;
        iif(isnull(.lInactive), " DELETED and NON-DELETED", iif(.lInactive, " DELETED", "")) + ;
        iif(isnull(.lExcluded), " Excluded and Non-Excluded", iif(.lExcluded, " Excluded", " Non-Excluded")) + ;
        iif(isnull(.lHasLocation), "", iif(.lHasLocation, " Assigned", " Un-Assigned")) + ;
        iif(isnull(.lSpecialSize), "", iif(.lSpecialSize, " Special-Size", " Normal-Size")) + ;
        iif(isnull(.lSinglePiece), "", iif(.lSinglePiece, " Single-Piece", " Multiple-Piece")) 
      lcRet = m.lcRet + " Panels"
      if !isnull(.lCompleted) 
        lcRet = m.lcRet + ", w/ Status: " + substr( ;
          iif(isnull(.lCompleted), "", " and " + iif(.lCompleted, "Completed", "not Completed")), ;
          1 + len(" and "))
        
      endif 
    endwith 
    return m.lcRet
  endfunc 
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .T.
      if isnull(.lInactive)
        .cWhereClause = [WHERE .t.]
      else
        .cWhereClause = [WHERE Pnl_Inactive = ] + IIF(.lInactive, [.T.], [.F.])
      endif 
      if !isnull(.lExcluded)
        .cWhereClause = .cWhereClause + [ and Pnl_Excluded = ] + iif(.lExcluded, [.t.], [.f.])
      endif 

      if !isnull(.cID)
        .cWhereClause = .cWhereClause + [ and Pnl_Id = '] + .cId + [']
      endif
      
      if !isnull(.cDesign_Category)
        .cWhereClause = .cWhereClause + [ and Pnl_Design_Category = '] + .cDesign_Category + [']
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
        .cWhereClause = .cWhereClause + [ and nvl(Plc_Inactive, .f.) = .f.]
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
      if !isnull(.lSpecialSize)
        .cWhereClause = .cWhereClause + [ and Pnl_Special_Size= ] + iif(.lSpecialSize, [.t.], [.f.])
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
