* AisPce.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* --------------------------------------------------------- *
function aisReleasePieces(toPnl)
  * Create a panel from a "starter" piece. 
  * NOTE: no piece data resides with the panel, instead
  * pieces are connected to their parent panel by FK. 
  local vp_cPnl_PK, loNewRec, loTrans
  vp_cPnl_PK = toPnl.Pnl_PK
  
  use V_Panel_Piece_Set in select("V_Panel_Piece_Set")
  cursorsetprop("Buffering", 5, "V_Panel_Piece_Set")
  select V_Panel_Piece_Set
  scan
    if toPnl.Pnl_Single_Piece && assume they should both be deleted
      replace Pce_Inactive with .t. ;
        Pce_Notes with "Deleted along with Panel." + CRLF + Pce_Notes
        
    else
      replace Pce_Pnl_FK with "" ;
        Pce_Notes with "Released from Panel upon deletion." + CRLF + Pce_Notes

    endif 
    StampRec( CurrentUser, Environ.item("appManager.startTime") )
  endscan 
  
  * Now save using a transaction:
  local loTrans, loExc
  
  loTrans = goL7App.CreateTransaction()
  loTrans.AddCursor("V_Panel_Piece_Set")

  if !loTrans.Save()  
    error "Error saving panel: " + loTrans.GetErrorInfo()
  endif 
  return 
endfunc  && aisReleasePieces

*** ========================================================= ***
define class aisPcePage as aisPage 
  cPce = ""
  oPce = null
  lPceRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr, loQ, llBad
    with this
      if .lPceRequired
        .cPce = evl(.cPce, .StripUrl("pce", .f., .t.))
        if empty(.cPce)  && Item required, but not found in URL.
          .NotFound()
          llBad = .t. 
        else 
          do case
          case len(.cPce) = 32
          case len(.cPce) <= THISAPP_LENGTH_ID_FIELDS 
            lcStr = "PCE" + padl(strtran(.cPce, "pce", "", 1, 1, 1), 5, "0")
            
            loQ = createobject("AisPceQuery")
            loQ.cID = m.lcStr 
            loQ.execute()
            if loQ.nTally = 1
              .cPce = Pce_PK
            else
              .NotFound()
              llBad = .t.
            endif
          otherwise
            .BadRequest("Invalid Piece ID length")
            llBad = .t.
          endcase
          
          = !m.llBad and .VerifyPiece()
          if !isnull(.oPce)
            .cArt = .oPce.Pce_Art_FK
            if !empty(.oPce.Pce_Pnl_FK)
              .cPnl = .oPce.Pce_Pnl_FK
              .verifyPanel()
            endif
          endif
        endif 
      endif 
    endwith 
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
  cPage_Type = null
  cPage_Order = null
  cPage_Flags = null
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

    this.cPage_Type = this.ReadQueryString("type", .t., .t.)
    this.cPage_Flags = this.ReadQueryString("flags", .t., .t.)
    this.cPage_Order = this.ReadQueryString("order", .t., .t.)

    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function AddDefaultMenu
    local lcMenu
    with this
      .AddSubMenu("This", "PIECES and RAILINGS")
      lcMenu = "main\This"

      .addMenuItem(m.lcMenu, "Whole-Panel Pieces",   StuffUrl(.cUrlB, "order", "fac", "type", "Panels", "whole", "1"))
      .addMenuItem(m.lcMenu, "Available Bits",       StuffUrl(.cUrlB, "order", "fac", "type", "Panels", "whole", "0", "orphans", "1"))
      .addMenuItem(m.lcMenu, "Consumed Bits",        StuffUrl(.cUrlB, "order", "pnl", "type", "Panels", "whole", "0", "orphans", "0"))
      
      .addMenuItem(m.lcMenu, "Railings by Size",     StuffUrl(.cUrlB, "order", "size", "type", "Railings"))
      .addMenuItem(m.lcMenu, "Railings by ID",       StuffUrl(.cUrlB, "type", "Railings"))

      .addMenuItem(m.lcMenu, 'Deleted Pieces',       StuffUrl(.cUrlA, 2, "PceList", "flags", "inactive"))
      .addMenuItem(m.lcMenu, 'Excluded Pieces',       StuffUrl(.cUrlA, 2, "PceList", "flags", "excluded"))

    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.page_setupUrls()
    this.page_runQueries()
    response.write(this.page_getSummaryTable())
    response.write(this.page_getDetailTable())
    return 
  endfunc && processRequest
  * ----------------------------------------------------- *  
  function page_setupUrls()
    urls.add(StuffUrl(this.cUrlA, 2, "PceHome"), "PceHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PceForm"), "PceForm")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    urls.add(StuffUrl(this.cUrlA, 2, "FacHome"), "FacHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PnlHome"), "PnlHome")
    return
  endfunc 
  * ----------------------------------------------------- *  
  function page_runQueries
    local loQry
    loQry = createobject("AisPceQuery")
    with loQry
      .lJoinArtist = .t. 
      .lJoinFacility = .t.
      .lJoinPanel = .t. 

      if "," + "inactive" + "," $ "," + this.cPage_Flags + ","
        .lInactive = .t. 
      endif 
      if "," + "excluded" + "," $ "," + this.cPage_Flags + ","
        .lExcluded = .t. 
      endif 
      .lOrphans    = this.lPage_Orphans 
      .lWholePanel = this.lPage_Whole 
      .lShipped    = this.lPage_Shipped 
      .lReceived   = this.lPage_Received 
      .cType       = evl(this.cPage_Type, null)
      
      do case
      case this.cPage_Order = "size" 
        .AddOrderBy('Pce_Dim_1',  .f., .f.)
        .AddOrderBy('Pce_Dim_2',  .f., .t.)
        .AddOrderBy('Pce_ID', .f., .t.)
      case this.cPage_Order = "fac"
        .AddOrderBy('Fac_Order', .f., .f.)
        .AddOrderBy('Pce_Fac_FK', .f., .t.)
        .AddOrderBy('Pce_ID',  .f., .t.)
      case this.cPage_Order = "pnl"
        .AddOrderBy('Pnl_ID', .f., .f.)
        .AddOrderBy('Pce_ID',  .f., .t.)
      otherwise 
        .AddOrderBy('Pce_ID',  .f., .f.)
      endcase
      .execute()
      
      this.cSubTitle = this.cSubTitle + .GetCaption()
    endwith 
    Artifacts.Add(m.loQry, "PieceQuery")
    return
  endfunc 
  * ----------------------------------------------------- *  
  function page_getSummaryTable()
    if !inlist(this.cPage_Order, "fac", "size")
      return ""
    endif

    local loTbl, loCol, loGrp, loQry
    loQry = Artifacts.item("PieceQuery")
    do case
    case this.cPage_Order = "size" 
      select Pce_Dim_1, Pce_Dim_2, count(*) as Count_, sum(iif(Pce_Received, 1, 0)) as Received_ ;
        from (loQry.cAlias) ;
        group by 1, 2 ;
        into cursor PceList_Summary_
    case this.cPage_Order = "fac" 
      select Fac_Order, Pce_Fac_FK, Fac_Name, count(*) as Count_, sum(iif(Pce_Received, 1, 0)) as Received_ ;
        from (loQry.cAlias) ;
        group by 1, 2, 3 ;
        into cursor PceList_Summary_
    endcase
    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      do case
      case this.cPage_Order = "size" 
        .cTableCaption = "Summary Counts by Size"
        loCol = .addCursorColumn("Pce_Dim_1", "Dim 1", [trim(Pce_Dim_1) + " x " + trim(Pce_Dim_2)])
        ** loCol = .addCursorColumn("Pce_Dim_2", "Dim 2")
      case this.cPage_Order = "fac" 
        .cTableCaption = "Summary Counts by Facility"
        loCol = .addCursorColumn("Fac_Name", "Current Storage Facility", ;  
          [HTLink(StuffUrl(urls.item('FacHome'), 'fac', Pce_Fac_FK), AisFacilityName(Pce_Fac_FK))])
      endcase
      loCol = .addCursorColumn("Count_", "Total")
      loCol = .addCursorColumn("Received_", "Received")
      loCol = .addCursorColumn("Count_ - Received_", "Not Received")
    endwith
    return loTbl.render()
  endfunc 
  * ----------------------------------------------------- *  
  function page_getDetailTable()
    local loTbl, loCol, loGrp, loQry
    loQry = Artifacts.item("PieceQuery")
    select (loQry.cAlias)
    loTbl = createobject("AisTable")
    with loTbl
      .cTableCaption = this.cSubTitle 

      .cDataRowClass = .cDataRowClass + iif(empty(.cDataRowClass), [], [ + ]) + [iif(Pce_Inactive, " deleted", "")]

      do case
      case this.cPage_Order = "size" 
        .addGroup('Pce_Dim_1 + Pce_Dim_2', 'Size: ', .t., ["Size: " + Pce_Dim_1 + " x " + Pce_Dim_2])
      case this.cPage_Order = "fac"
        .addGroup('Pce_Fac_FK', 'Facility: ', .t., ["Facility: " + Fac_Name])
      case this.cPage_Order = "pnl"
        .addGroup('Pnl_ID', 'Panel: ', .t., ["Panel: " + HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pce_Pnl_FK), AisFormatID(Pnl_ID), "go to panel", "id-field panel")])
      otherwise 
        = .f. && no grouping
      endcase

      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pce_ID", "Piece ID", ;
        [HTLink(StuffUrl(urls.item("PceHome"), "pce", Pce_PK), Pce_ID)], "id-field piece")
      loCol = .addCursorColumn("Pce_Type", "Type")
      loCol = .addCursorColumn("Art_ID", "Artist ID", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pce_Art_FK), Art_ID)], "id-field artist")
      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pce_Art_FK), aisArtistName(THISRECORD))], "artist")
      ** loCol = .addCursorColumn("Art_First_Name", "First Name")
      loCol = .addCursorColumn("Pnl_Id", "Panel", ;
        [HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pce_Pnl_FK), AisFormatID(Pnl_ID))], "id-field panel")
      loCol = .addCursorColumn("Pce_Whole_Panel", "Whole Panel?")
      loCol = .addCursorColumn("Pce_Dim_1", "Dim 1")
      loCol = .addCursorColumn("Pce_Dim_2", "Dim 2")
      loCol = .addCursorColumn("Pce_Comments", "Comments")

      if isnull(loQry.lOrphans) or loQry.lOrphans
        *!*          loCol = .AddCursorColumn('Pce_Shipped', 'Shipped')
        loCol = .AddCursorColumn('Pce_Received', 'Received')

        *!*          loCol = .addCursorColumn("Fac_Name", "Current Storage Facility", ;
        *!*            [HTLink(StuffUrl(urls.item("FacHome"), "fac", Pce_Fac_FK), trim(Fac_Name))])

        loCol = .addCursorColumn("Fac_Name", "Current Storage Facility", ;  
          [iif(empty(Pce_Pnl_FK), ] + ;
          [HTLink(StuffUrl(urls.item('FacHome'), 'fac', Pce_Fac_FK), AisFacilityName(Pce_Fac_FK))] + [, ] + ;
          ["(panel) " + HTLink(StuffUrl(urls.item('FacHome'), 'fac', Pnl_Fac_FK), AisFacilityName(Pnl_Fac_FK), "go to facility", "facility")] + ;
          [)])
        
      endif 
      if poContext.lAdmin
        loCol = .addCursorColumn("Pce_Notes", "Notes",, "private")
        loCol = .addCursorColumn("Pce_PK", "Edit Piece", ;
          'HTLink(StuffUrl(urls.item("PceForm"), "pce", Pce_PK), "[Edit&nbsp;Piece...]")', 'no-print')
        loCol.cHeadingClass = "nosort no-print" 
      endif 
    endwith 
    return loTbl.render()
  endfunc 
enddefine && ais_PceList 

*** ========================================================= ***
define class ais_PceToPanel as aisPcePage 
  lPceRequired = .t.
  * ----------------------------------------------------- *  
  function ProcessRequest

    this.Assert(poContext.lCore)
    this.cCancelUrl = StuffURL(THIS.cUrlB, 2, "PceHome")

    local vp_cPce_PK, loPnl
    vp_cPce_PK = THIS.cPce
    use V_Piece in select("V_Piece")
    this.assert(inlist(this.oPce.Pce_Type, "Panels"), "Function only applies to panel piece type. ")
    cursorsetprop("Buffering", 5, "V_Piece")

    loPnl = AisCreatePanel(this.oPce)
    this.cCancelUrl = StuffURL(THIS.cUrlB, 2, "PnlHome", "pnl", loPnl.Pnl_PK)
    select V_Piece  
    replace Pce_Pnl_FK with loPnl.Pnl_PK
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
enddefine  && ais_PceToPanel 

*** ========================================================= ***
define class ais_PceHome as aisPcePage 
  lArtRequired = .t.
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.AddSubMenu("This", "This Piece")
    if this.oPce.Pce_Type = "Panels" and empty(this.oPce.Pce_Pnl_FK) and !this.oPce.Pce_Excluded
      this.addMenuItem("main\This,page", "Start Panel from This Piece...", ;
        StuffUrl(this.cUrlA, 2, "PceToPanel", "pce", this.cPce))
    endif 
    
    this.addMenuItem("main\This,page", "Edit Piece...", StuffUrl(this.cUrlA, 2, "PceForm", "pce", this.cPce))
    this.addMenuItem("main\This,page", "Artist's Page", StuffUrl(this.cUrlA, 2, "ArtHome", "art", this.cArt))
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Piece " + HTWrap(this.oPce.Pce_ID, 'span',, 'id-field piece') + " from " + AisArtistName(Page.oArt.Art_PK) 
    response.write(this.page_getMainRecord())

    if poContext.lAdmin
    *!*        response.write(HTWrap(L7ShowObject(this.oPce, , [class="record"]),'div','admin'))
    endif
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData, llPanel, lcFileName, llDeleted
    lcRet = ""
    loData = this.oPce
    llDeleted = loData.Pce_Inactive 
    llPanel = !empty(loData.Pce_Pnl_FK)
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      .cCaption = this.cSubTitle
      if m.llDeleted
        .cCssClass = .cCssClass + " deleted"
        .cCaption = .cCaption + " [DELETED]"
      endif
      .AddHeading('Key Information')
      
      .AddRow("Piece ID", loData.Pce_ID,, "id-field piece" )
      .AddRow("Artist ID", HtLink(StuffUrl(this.cUrlA, 2, "ArtHome", "art", this.oArt.ART_PK), this.oArt.ART_ID),, "id-field artist" )
      .AddRow("Artist's Name", HtLink(StuffUrl(this.cUrlA, 2, "ArtHome", "art", this.oArt.ART_PK), AisArtistName(this.oArt.ART_PK)))
      .AddRow("Type", loData.Pce_Type)
      .AddRow("Dimension 1", loData.Pce_Dim_1)
      .AddRow("Dimension 2", loData.Pce_Dim_2)
      if m.loData.Pce_Type = "Panels"
        .AddRow("Whole-Panel Piece?", loData.Pce_Whole_Panel)
        
        * Panel FK and options:
        loRow.clear()
        loRow.cLabel = "Assigned to Panel?"
        if empty(m.loData.Pce_Pnl_FK)
          loRow.vValue = "No (see menu options)"
        else
          loRow.vValue = HtWrap( ;
            HTLink(StuffUrl(this.cUrlA, 2, "PnlHome", "pnl", loData.Pce_Pnl_FK), AisFormatID(this.oPnl.Pnl_Id)), ;
            'span', ,'id-field panel')
          if poContext.lAdmin and !this.oPce.Pce_Whole_Panel
            loRow.links.add(HTLink(StuffUrl(this.cUrlB, 2, "PceUnlink"), "Remove piece from panel"))
          endif 
        endif
        .addRowEx(m.loRow)

        * Panel image:
        if !empty(m.loData.Pce_Pnl_FK) 
          lcFileName = forceext(this.oPnl.Pnl_Id + "_main", "jpeg")
          if file(aisPanelFilePath(this.oPnl.Pnl_ID) + m.lcFileName)
            .AddRow("Panel Image", HTImage(aisPanelWebFilePath(this.oPnl.Pnl_ID) + m.lcFileName, "Panel " + this.oPnl.Pnl_ID))
          endif
        endif 
      else

      endif
      .AddRow("Description and Comments", L7ParseOnView(loData.Pce_COMMENTS))
      if poContext.lCore
        .AddRow("Internal KtB Notes", L7ParseOnView(loData.Pce_NOTES), .F., "private")
      endif

      .AddHeading('Logistical Information')
      *!*        .AddRow("Shipped/Delivered?", loData.Pce_Shipped)
      *!*        .AddRow("Ship/Delivery Date", loData.Pce_Ship_Date)
      .AddRow("Received?", loData.Pce_RECEIVED)
      .AddRow("Acknowledged?", loData.Pce_Acknowledged)
      .AddRow("Current Storage Facility", iif(m.llPanel, "(panel) " + AisFacilityName(this.oPnl.Pnl_Fac_FK), AisFacilityName(loData.Pce_Fac_FK)))

      if poContext.lCore
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.Pce_PK), .F., "private")
        .AddRow("Deleted", loData.Pce_INACTIVE, .F., "private")
        .AddRow("Created", TRANSFORM(loData.Pce_ORIG_TIME) + [ by ] + AisArtistName(loData.Pce_Orig_Art_FK), .F., "private")
        .AddRow("Last Modified", TRANSFORM(loData.Pce_REV_TIME) + [ by ] + AisArtistName(loData.Pce_Rev_Art_FK), .F., "private")
      endif

      lcRet = m.lcRet + .Render()

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
define class ais_PceUnlink as aisPcePage 
  lAdding = .f.
  lPceRequired = .t.
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = stuffUrl(this.cUrlB, 2, "PceHome")
    this.Assert(poContext.lAdmin)
    this.Assert(!empty(this.oPce.Pce_Pnl_FK), "Piece is not assigned to any panel.")
    * return to the Panel where the piece used to be:
    this.cCancelUrl = stuffUrl(this.cUrlA, 2, "PnlHome", "pnl", this.oPce.Pce_Pnl_FK)

    local vp_cPce_PK, lcXml
    vp_cPce_PK = this.cPce
    use V_Piece in select("V_Piece")
    cursorsetprop("Buffering", 5, "V_Piece")
    select V_Piece
    replace Pce_Pnl_FK with ""  && clear the FK panel link
    StampRec( CurrentUser, THIS.tNow )
    
    lcXml = ''
    this.AssertTransaction("V_Piece", @lcXml)
    this.confirm(textmerge('Piece <<this.oPce.Pce_ID>> removed from Panel, and is available for re-assignment'), this.cCancelUrl)
    return
  endfunc 
enddefine && ais_PceUnlink 

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

    local loForm, vp_cPce_PK, loOldRec, loNewRec, loPnl, loConfirmMsgs 
    loConfirmMsgs = createobject("Collection")
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
          loConfirmMsgs.add("PIECE ID assigned: " + Pce_ID) 
        endif

        .UpdateControlSources()
        select V_Piece  && UpdateControlSources can alter work area
        StampRec( CurrentUser, THIS.tNow )
        scatter memo name loNewRec 
        
        * create Panel if indicated:
        if loNewRec.Pce_Whole_Panel and empty(loNewRec.Pce_Pnl_FK)
          loPnl = AisCreatePanel(m.loNewRec)
          loConfirmMsgs.add("PANEL ID assigned: " + loPnl.Pnl_ID) 
          select v_Piece
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
          *!* Response.Redirect(THIS.cCancelUrl)
          this.ConfirmOrRedirect(m.loConfirmMsgs, this.cCancelUrl)
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
  * --------------------------------------------------------- *
  function ConfirmOrRedirect(toMsgs, tcUrl)
    local lcMsg, lcMsgs
    if toMsgs.count = 0
      response.redirect(m.tcUrl)
    else
      lcMsgs = "<ul>"
      for each lcMsg in toMsgs
        lcMsgs = m.lcMsgs + HtWrap(m.lcMsg, "li")
      next 
      lcMsgs = m.lcMsgs + "</ul>"
      this.confirm(m.lcMsgs, m.tcUrl)
    endif
    return 
  endfunc && ConfirmOrRedirect
enddefine && ais_PceForm

*** ========================================================= ***
define class aisPieceForm as AisForm
  cTitle = "Piece Form"
  cCustom_Type = null 
  * --------------------------------------------------------- *
  function AddControls
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
      
      .AddObject("lblArt_Fk", "L7Label")
      with .lblArt_Fk
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
      
      if poContext.lDeveloper and !this.lNewRecord
        .AddObject("txtArt_Fk", "L7Textbox")
        with .txtArt_Fk
          .cGroupID = "ID"
          .cFieldType = "C"
          .cControlSource = "V_piece.Pce_Art_Fk"
          .cLabel = "Artist Internal Key"
          .lDisabled = !poContext.lDeveloper
          .cCssClass = "FormControlPrivate"
        endwith 
      endif 

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

      .AddObject("chkExcluded", "L7Checkbox")
      with .chkExcluded
        .cGroupID = "ID"
        .cControlSource = "V_Piece.Pce_Excluded"
        .cLabel = "Exclude?"
        .cCaption = "Excluded"
        .cInstructions = "Excluding makes piece unavailable for inclusion in panels."
        .lDisabled = !m.poContext.lAdmin
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("cboLoc_FK", "L7Popup")
      with .cboLoc_FK
        .cControlSource = "V_Piece.Pce_Fac_FK"
        .lRequired = .T.
        .cLabel = "Current Storage Facility"
        .cInstructions = "Not applicable once panel exists. Track panel location instead." 
        .lAutoRender = .T.
        .nRowSourceType = L7_ROWSOURCETYPE_ALIAS
        .cRowSource = goL7App.cFacAlias  
        *!* ex: .cFilterExpression = [Fac_Storage = .t.]
        .cValueExpression = [Fac_PK]
        .cLabelExpression = [Fac_Name]
        .vFirstItemValue = space(32) && 0 for integer keys
        .cFirstItemLabel = "[ select from choices below ]"
        if this.lNewRecord
          .SetValue(THISAPP_DEFAULT_FACILITY) 
        endif 
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
        
        if !this.lNewRecord
          .AddObject("txtPnl_Fk", "L7Textbox")
          with .txtPnl_Fk
            .cGroupID = "PANEL"
            .cFieldType = "C"
            .cControlSource = "V_piece.Pce_Pnl_Fk"
            .cLabel = "Panel Internal Key"
            .lDisabled = !poContext.lDeveloper
            .cCssClass = "FormControlPrivate"
          endwith 
        endif 
      endif
      
      .AddObject("txtDim_1", "L7Textbox")
      with .txtDim_1
        *.cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Dim_1"
        if this.lNewRecord
          .lAutoMaxLength = .f. && without this, next line constrains the input
          .SetValue(Page.cPage_Dim_1)
        endif 
        if this.lNewRecord and Page.lPage_Whole
          .cLabel = "Height"
        else
          .cLabel = "Dimension 1 (inches)"
          .cInstructions = "If not equal, please enter SMALLER dimension first!"
        endif 
      endwith
       
      .AddObject("txtDim_2", "L7Textbox")
      with .txtDim_2
        *.cGroupID = "DIM"
        .cFieldType = "C"
        .cControlSource = "V_piece.Pce_Dim_2"
        if this.lNewRecord
          .lAutoMaxLength = .f. && without this, next line constrains the input
          .SetValue(Page.cPage_Dim_2)
        endif 
        if this.lNewRecord and Page.lPage_Whole
          .cLabel = "Width"
        else
          .cLabel = "Dimension 2 (inches)"
          .cInstructions = "If not equal, please enter LARGER dimension second!"
        endif 
      endwith 

      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cGroupID = "NOTES"
        .cControlSource = "V_piece.Pce_Comments"
        .cLabel = "Description and Comments"
        .nRows = 2
      endwith 

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cGroupID = "NOTES"
        .cControlSource = "V_piece.Pce_Notes"
        .cLabel = "Internal KtB Notes"
        .nRows = 2
        .cCssClass = "FormControlPrivate"
      endwith

    *!*        .AddObject("chkShipped", "L7Checkbox")
    *!*        with .chkShipped
    *!*          *.cGroupID = "STATUS"
    *!*          .cControlSource = "V_piece.Pce_Shipped"
    *!*          .cLabel = "Shipped/Delivered?"
    *!*        endwith 

    *!*        .AddObject("txtShip_Date", "L7Textbox")
    *!*        with .txtShip_Date
    *!*          *.cGroupID = "STATUS"
    *!*          .cFieldType = "D"
    *!*          .cControlSource = "V_Piece.Pce_Ship_Date"
    *!*          .cLabel = "Ship/delivery date (expected or actual)"
    *!*          .cInstructions = "MM/DD/YYYY"
    *!*        endwith 

      .AddObject("chkReceived", "L7Checkbox")
      with .chkReceived
        *.cGroupID = "STATUS"
        .cControlSource = "V_piece.Pce_Received"
        .cLabel = "Received?"
        .cCssClass = "FormControlPrivate"
        if this.lNewRecord
          .SetValue(.t.)
        endif 
      endwith 

    endwith
    return 
  endfunc && AddControls 
enddefine  && PieceForm

*** ===================================================== ***
define class AisPceQuery as L7Query
  cBaseTable = "Piece"
  cDefaultFieldList = ;
    "Pce_PK, Pce_ID, Pce_Inactive, Pce_Excluded, Pce_Art_FK, Pce_Pnl_FK, Pce_Fac_FK, Pce_Whole_Panel" + ;  
    ", Pce_Dim_1, Pce_Dim_2, Pce_Comments, Pce_Notes, Pce_Type, Pce_Shipped, Pce_Ship_Date, Pce_Received, Pce_Acknowledged"

  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Pce_ID"

  cID = null 

  lInactive = .f.  && whole record deleted
  lExcluded = .f.  && by default, omit excluded panels

  cArt = null
  cPnl = null
  cFac = null
  
  cType = null

  lOrphans    = null
  lWholePanel = null
  lShipped    = null
  lReceived   = null
  lAcknowledged = null
  
  lJoinArtist = .f. 
  lJoinFacility = .f.
  lJoinPanel = .f. 
  lJoinPanelLocation = .f. 
  * --------------------------------------------------------- *
  function GetCaption 
    local lcRet
    lcRet = ""
    with this
      lcRet = m.lcRet + ;
        iif(isnull(.lAcknowledged), "", iif(.lAcknowledged, " Acknowledged", " Un-Acknowledged")) + ;
        iif(isnull(.lOrphans), "", iif(.lOrphans, " Available", " Assigned")) + ;
        iif(isnull(.lWholePanel), "", iif(.lWholePanel, " Whole-Panel", " Non-Whole-Panel")) 
      lcRet = m.lcRet + " Pieces"
      if !isnull(.cType)
        lcRet = m.lcRet + " for " + .cType
      endif
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
      if isnull(.lInactive)
        .cWhereClause = [WHERE .t.]
      else
        .cWhereClause = [WHERE Pce_Inactive = ] + IIF(.lInactive, [.T.], [.F.])
      endif 
      if !isnull(.lExcluded)
        .cWhereClause = .cWhereClause + [ and Pce_Excluded = ] + iif(.lExcluded, [.t.], [.f.])
      endif 

      if !isnull(.cID)
        .cWhereClause = .cWhereClause + [ and Pce_Id = '] + .cId + [']
      endif

      if .lJoinArtist
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Artist"
        .aJoins[.nJoins, 2] = "Pce_Art_FK = Art_PK"
        .AddFields("Art_ID, Art_Last_Name, Art_First_Name, Art_Anonymous, Art_Full_Name, Art_Release_Name")
      endif 

      if .lJoinFacility
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Facility"
        .aJoins[.nJoins, 2] = "Pce_Fac_FK = Fac_PK"
        .aJoins[.nJoins, 3] = "LEFT OUTER"
        .AddFields("Fac_ID, Fac_Name, Fac_Order")
      endif 

      if .lJoinPanel
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Panel"
        .aJoins[.nJoins, 2] = "Pce_Pnl_FK = Pnl_PK"
        .aJoins[.nJoins, 3] = "LEFT OUTER"
        .AddFields("Pnl_ID, Pnl_Fac_FK, Pnl_Excluded")
      endif 

      if .lJoinPanelLocation
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "PanelLocation"
        .aJoins[.nJoins, 2] = "Pnl_PK = Plc_Pnl_FK"
        .aJoins[.nJoins, 3] = "LEFT OUTER"
        .cWhereClause = .cWhereClause + [ and nvl(Plc_Inactive, .f.) = .f.] 
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
      if !isnull(.lAcknowledged)
        .cWhereClause = .cWhereClause + [ and Pce_Acknowledged = ] + iif(.lAcknowledged, [.t.], [.f.])
      endif 
    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisPceQuery


* end 
