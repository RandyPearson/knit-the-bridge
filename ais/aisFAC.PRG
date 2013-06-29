* AisFac.PRG  && facility pages

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* --------------------------------------------------------- *
function aisFacilityName(tvFac)
  local loData, loPreserve
  if vartype(m.tvFac) = "O"
    loData = m.tvFac
  else  && PK
    if isnull(m.tvFac) or empty(m.tvFac)
      return "--"
    endif
    loPreserve = createobject("L7PreserveSelect")
    select * from KtbAis!Facility ;
      where Fac_PK = m.tvFac ;
      into cursor aisFacilityName_
    if _tally < 1
      error "Facility " + m.tvFac + " was not found!"
    endif
    scatter memo name loData
    loPreserve = null 
  endif 
    
  return trim(evl(loData.Fac_Name, loData.Fac_ID))
endfunc  && aisFacilityName

*** ========================================================= ***
define class aisFacPage as aisPage 
  cFac = ""
  oFac = null
  lFacRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lFacRequired
      this.cFac = evl(this.cFac, this.StripUrl("fac", .f., .t.))
      if empty(this.cFac)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyFacility()
        if !isnull(this.oFac)
          * derived parent properties set here
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyFacility(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cFac)
    loData = createobject("AisFacData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cFac
        this.oFac = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
enddefine && AisFacPage

*** ========================================================= ***
define class ais_FacList as aisFacPage 
  lFacRequired = .f.
  cSubTitle = "Facilities N'At"
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    with this
      .AddSubMenu("This", "FACILITIES")
      .addMenuItem("main\This,page", "New Facility...", StuffUrl(this.cUrlA, 2, "FacNew"))
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisFacQuery")
    with loQry
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "FacHome"), "FacHome")
    urls.add(StuffUrl(this.cUrlA, 2, "FacForm"), "FacForm")

    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Fac_ID", "Facility ID", ;
        [HTLink(StuffUrl(urls.item("FacHome"), "Fac", Fac_PK), Fac_ID)], 'id-field facility')
      loCol = .addCursorColumn("Fac_Name", "Facility Name")
      loCol = .addCursorColumn("Fac_DropOff", "Drop-Off?", [iif(Fac_DropOff, "Drop-Off", "--")])
      loCol = .addCursorColumn("Fac_Storage", "Storage?", [iif(Fac_Storage, "Storage", "--")])
      loCol = .addCursorColumn("Fac_Address", "Address", [L7ParseOnView(Fac_Address)])
      loCol = .addCursorColumn("Fac_Address", "Comments", [L7ParseOnView(Fac_Comments)])
      loCol = .addCursorColumn("Fac_PK", "Edit Facility", ;
        'HTLink(StuffUrl(urls.item("FacForm"), "fac", Fac_PK), "[Edit Facility...]")')
      loCol = .addCursorColumn("Fac_Order", "Order")
      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_FacPanelMove as aisFacPage 
  cPage_Alias = "V_Facility_Panel_Set"
  cPage_Entity = "Panel" 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = StuffUrl(this.cUrlB, 2, "FacHome")
    local loForm, vp_cFac_PK, loOldRec, loNewRec, lcXml, lcFacName, lcFac_PK, lnMoves
    lnMoves = 0
    vp_cFac_PK = THIS.cFac
    use (this.cPage_Alias) in select(this.cPage_Alias)
    cursorsetprop("Buffering", 5, this.cPage_Alias)
    
    loForm = this.createForm('aisFacMoveForm', this.cUrlC)
    with loForm
      .cCustom_Entity = this.cPage_Entity
      .AddControls()
      .DoEvents()
      if .Valid() and this.page_Valid(m.loForm)
        lcFac_PK = .cboLoc_FK.vNewValue
        lcFacName = AisFacilityName(m.lcFac_PK)
        select (this.cPage_Alias)
        scan
          if request.form("chkMove_" + Pnl_PK) = "ON"
            replace Pnl_Fac_FK with m.lcFac_PK
            replace Pnl_History with Pnl_History + dtoc(date()) + " moved to: " + m.lcFacName + CRLF 
            StampRec( CurrentUser, THIS.tNow )
            lnMoves = m.lnMoves + 1 
          endif 
        endscan 
        lcXml = ''
        this.AssertTransaction(this.cPage_Alias, @lcXml)
        this.confirm(textmerge('<<m.lnMoves>> items moved'), this.cCancelUrl)
        return 
      endif
    endwith 
    
    * check all/none links:    
    text to lcStr noshow pretext 7 
      <a id="check-all" href="">[Check All/None]</a>
      <script> 
        $j(document).ready(function() {
          $j('#check-all').click( function() {
            // use state of first checkbox
            var isChecked = $j('form input:checkbox').prop('checked');
            // to set all checkboxes
            $j('form input:checkbox').each(function() {$j(this).prop('checked', !isChecked);});
            return false;
          });
        });
      </script>
    
    endtext
    response.write(m.lcStr)
    response.write(loForm.render())    
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_Valid(loForm)
    local llValid
    llValid = .t.
    if loForm.cboLoc_FK.vNewValue = this.cFac
      loForm.cboLoc_FK.addValidationMessage("Cannot move to same facility!")
      llValid = .f.
    endif
    return m.llValid
  endfunc 
  * ----------------------------------------------------- *  
enddefine && ais_FacPanelMove

*** ========================================================= ***
define class aisFacMoveForm as AisForm
  cTitle = "Facility Bulk <<this.cCustom_Entity>> Move"
  cCustom_Entity = null 
  cCustom_Alias = null
  cCustom_Prefix = null
  cSubmitCaption = "Move"
  * --------------------------------------------------------- *
  function  AddControls
    with this
      this.cTitle = textmerge(this.cTitle)
      this.cCustom_Alias = "V_Facility_" + this.cCustom_Entity + "_Set"
      this.cCustom_Prefix = iif(lower(this.cCustom_Entity) == "panel", "Pnl", "Pce")

      .AddObject("lblFrom", "L7Label")
      with .lblFrom
        .cFieldType = "C"
        .cLabel = "Move From Where?"
        .cShowExpression = [AisFacilityName(page.cFac)]
      endwith 

      .AddObject("cboLoc_FK", "L7Popup")
      with .cboLoc_FK
        .lRequired = .t.
        .cLabel = "Move Where?"
        .lAutoRender = .T.
        .nRowSourceType = L7_ROWSOURCETYPE_ALIAS
        .cRowSource = goL7App.cFacAlias  
        .cValueExpression = [Fac_PK]
        .cLabelExpression = [Fac_Name]
        .vFirstItemValue = space(32) && 0 for integer keys
        .cFirstItemLabel = "[ select from choices below ]"
      endwith 

      .AddObject('grdBrowse', 'L7Grid')
      with .grdBrowse
        .cChildAlias = this.cCustom_Alias
        .cChildKeyExpression = this.cCustom_Alias + "." + this.cCustom_Prefix + "_PK"
        .nExtraRows = 0 && don't permit adds 
        .cGridTableCssClass = "sortable " + .cGridTableCssClass 
        .cColumnHeaderCssClass = "nosort" && sortable doesn't work for live controls, so override on specific labels
      
        .AddObject("lblId", "L7Label")
        with .lblId
          .cFieldType = "C"
          .cControlSource = this.cCustom_Alias + "." + this.cCustom_Prefix + "_ID"
          .cLabel = "ID"
          .cColumnHeaderCssClass = "sort" 
        endwith 

        .AddObject("chkMove", "L7Checkbox")
        with .chkMove
          .cHtmlName = ""
          .cIDPrefix = ""
          .cLabel = "Move Which?"
          .cCaption = "Move"
          .SetValue(.t.)
        endwith 

        if this.cCustom_Entity = "Panel"
          .AddObject("lblImage", "L7Label")
          with .lblImage
            .cFieldType = "C"
            .cShowExpression = [AisPanelImage(Pnl_Id, "_h25")]
            .cLabel = "Image"
          endwith 
        endif 

        .AddObject("lblComments", "L7Label")
        with .lblComments
          .cFieldType = "C"
          .cControlSource = this.cCustom_Alias + "." + this.cCustom_Prefix + "_Comments"
          .cLabel = "Comments"
        endwith 
        
        .AddObject("lblNotes", "L7Label")
        with .lblNotes
          .cFieldType = "C"
          .cControlSource = this.cCustom_Alias + "." + this.cCustom_Prefix + "_Notes"
          .cLabel = "Notes"
        endwith 

      endwith && GRID
    endwith  && FORM
  endfunc
enddefine && aisFacMoveForm 

*** ========================================================= ***
define class ais_FacHome as aisFacPage 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.AddSubMenu("This", "This Facility")
    this.addMenuItem("main\This,page", "Edit Facility...", StuffUrl(this.cUrlA, 2, "FacForm", "Fac", this.cFac))
    this.addMenuItem("main\This,page", "Move All Panels...", StuffUrl(this.cUrlA, 2, "FacPanelMove", "Fac", this.cFac))
    this.addMenuItem("main\This,page", "List of Facilities", StuffUrl(this.cUrlA, 2, "FacList"))
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Facility " + HTWrap(this.oFac.Fac_ID, 'span',,'id-field facility') + " - " + trim(this.oFac.Fac_Name) 
    response.write(this.page_getMainRecord())

    if poContext.lAdmin
      *!*        response.write(HTWrap(L7ShowObject(this.oFac, , [class="record"]),'div','admin'))
    endif
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData
    lcRet = ""
    loData = this.oFac
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      .cCaption = this.cSubTitle
      .AddHeading('Key Information')
      
      .AddRow("Facility ID", loData.Fac_ID,, "id-field" )
      .AddRow("Name", loData.Fac_Name)
      .AddRow("Address", L7ParseOnView(loData.Fac_Address))
      .AddRow("Comments", L7ParseOnView(loData.Fac_Comments))

      .AddHeading('Logistical Information')
      .AddRow("Drop-Off Location?", loData.Fac_DropOff)
      .AddRow("Storage Location?", loData.Fac_Storage)

      .AddHeading('Panels Currently at Facility')
      .AddRow(null, this.page_getPanelInfo())

      if poContext.lCore
        .AddRow("Notes", L7ParseOnView(loData.fac_NOTES), .F., "private")
      endif

      if poContext.lCore
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.Fac_PK), .F., "private")
        .AddRow("Order", loData.Fac_Order, .F., "private")
        .AddRow("Deleted", loData.Fac_INACTIVE, .F., "private")
        .AddRow("Created", TRANSFORM(loData.Fac_ORIG_TIME) + [ by ] + AisArtistName(loData.Fac_Orig_Art_FK), .F., "private")
        .AddRow("Last Modified", TRANSFORM(loData.Fac_REV_TIME) + [ by ] + AisArtistName(loData.Fac_Rev_Art_FK), .F., "private")
      endif

      lcRet = m.lcRet + .Render()

    endwith 
    return m.lcRet
  endfunc && page_getMainRecord
  * ----------------------------------------------------- *  
  function page_getPanelInfo
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisPnlQuery")
    with loQry
      .cFac = this.cFac 
      .lJoinArtist = .t. 
      .execute()
      if .nTally = 0
        return "(none)"
      endif 
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "PnlHome"), "PnlHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PnlForm"), "PnlForm")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PnlFilNew", "return", this.cUrlC), "PnlFilNew")

    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pnl_ID", "Panel ID", ;
        [HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pnl_PK), AisFormatID(Pnl_ID))], "id-field panel")
      loCol = .addCursorColumn("Pnl_Single_Piece", "Single-Piece?")
      loCol = .addCursorColumn("Pnl_Dim_1", "Height")
      loCol = .addCursorColumn("Pnl_Dim_2", "Width")
      loCol = .addCursorColumn("Pnl_Special_Size", "Special<br>Size", [iif(Pnl_Special_Size,"Special Size","")])
      loCol = .addCursorColumn("Pnl_Design_Category", "Des<br>Cat")
      loCol = .addCursorColumn("Pnl_Comments", "Comments")
      loCol = .addCursorColumn("Pnl_ID", "Image", ;
        [AisPanelImage(Pnl_Id, "_h25", urls.item("PnlFilNew"), Pnl_PK, poContext.lAdmin)])
      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Pnl_Stitcher_Art_FK), aisArtistName(THISRECORD))], 'artist')
      if poContext.lAdmin
        loCol = .addCursorColumn("Pnl_Notes", "Notes",, "private")
        loCol = .addCursorColumn("Pnl_PK", "Edit Panel", ;
          'HTLink(StuffUrl(urls.item("PnlForm"), "pnl", Pnl_PK), "[Edit&nbsp;Panel...]")',"panel")
      endif 
      return .render()
    endwith 
    
    return 
  endfunc && page_getPanelInfo
enddefine && FacHome

*** ========================================================= ***
define class ais_FacNew as ais_FacForm
  lAdding = .t.
  lFacRequired = .f.
enddefine 

*** ========================================================= ***
define class ais_FacForm as aisFacPage 
  lAdding = .f.
  * ----------------------------------------------------- *  
  function ProcessRequest

    this.Assert(poContext.lCore)
    this.cCancelUrl = iif(this.lAdding, StuffURL(THIS.cUrlA, 2, "FacList"), ;
      StuffURL(THIS.cUrlB, 2, "FacHome"))

    local loForm, vp_cFac_PK, loOldRec, loNewRec
    vp_cFac_PK = IIF(THIS.lAdding, space(32), THIS.cFac)
    use V_Facility in select("V_Facility")
    if !this.lAdding
      select V_Facility
      scatter memo name loOldRec
    endif 
    cursorsetprop("Buffering", 5, "V_Facility")
    loForm = this.createForm('aisFacilityForm', this.cUrlC)
    with loForm
      .lNewRecord = THIS.lAdding
      .AddControls()
      .DoEvents() 

      if .Valid()
        select V_Facility
        if this.lAdding
          append blank
        endif 
        if empty(Fac_Id)
          replace Fac_ID with AisAssignID("FAC")
        endif
        .UpdateControlSources()
        select V_Facility  && UpdateControlSources can alter work area
        StampRec( CurrentUser, THIS.tNow )
        scatter memo name loNewRec 
        
        * Now save the record using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail
        llSendEmail = .f.  
        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor("V_Facility")

        if loTrans.Save()  
          select V_Facility
          Response.Redirect(StuffUrl(this.cUrlA, 2, "FacHome", "Fac", Fac_PK))
          return 
        else 
          this.ErrorMsg( "Database Failure Saving Record!", ;
            "Error " + TRANSFORM( loTrans.aFailures[1, 1]) + [ :] + ;
            loTrans.aFailures[1, 2] )
        endif  && Save()
      endif && Valid

    endwith && form
    response.write(loForm.render())
  endfunc && ProcessRequest 
enddefine && ais_FacForm

*** ========================================================= ***
define class aisFacilityForm as AisForm
  cTitle = "Facility Form"
  * --------------------------------------------------------- *
  function  AddControls
    with this
      if !this.lNewRecord
        .AddObject("txtId", "L7Textbox")
        with .txtId
          .cGroupID = "ID"
          .cFieldType = "C"
          .cControlSource = "V_Facility.Fac_Id"
          .cLabel = "Facility ID"
          .lDisabled = .t. 
        endwith
      endif 

      .AddObject("lblPk", "L7Label")
      with .lblPk
        .cGroupID = "ID"
        .cControlSource = "V_Facility.Fac_Pk"
        .cLabel = "Internal Key"
        .cCssClass = "FormControlPrivate"
      endwith 

      .AddObject("chkInactive", "L7Checkbox")
      with .chkInactive
        .cGroupID = "ID"
        .cControlSource = "V_Facility.Fac_Inactive"
        .cLabel = "Delete?"
        .lDisabled = !m.poContext.lAdmin
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("txtName", "L7Textbox")
      with .txtName
        .cFieldType = "C"
        .cControlSource = "V_Facility.Fac_Name"
        .lRequired = .t. 
        .cLabel = "Facility Name"
      endwith
      .AddObject("txtOrder", "L7Textbox")
      with .txtOrder
        .cFieldType = "N"
        .cControlSource = "V_Facility.Fac_Order"
        .lRequired = .f. 
        .cLabel = "Order"
        .cCssClass = "FormControlPrivate"
        if this.lNewRecord
          .SetValue(999)
        endif 
      endwith

      .AddObject("chkDropoff", "L7Checkbox")
      with .chkDropoff
        .cGroupID = "DIM"
        .cControlSource = "V_Facility.Fac_Dropoff"
        .cLabel = "Is this a drop-off Facility?"
        .nMode = L7_MULTI_RADIOBUTTON
        .nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
        .cCaption = "Yes, a Drop-Off Facility"
        .cFalseCaption = "No" 
        .lFalseBeforeTrue = .T.
        .cInterControlText = NULL 
      endwith 

      .AddObject("chkStorage", "L7Checkbox")
      with .chkStorage
        .cGroupID = "DIM"
        .cControlSource = "V_Facility.Fac_Storage"
        .cLabel = "Is this a Storage Facility?"
        .nMode = L7_MULTI_RADIOBUTTON
        .nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
        .cCaption = "Yes, a Storage Facility"
        .cFalseCaption = "No" 
        .lFalseBeforeTrue = .T.
        .cInterControlText = NULL 
      endwith 

      .AddObject("edtAddress", "L7Textarea")
      with .edtAddress
        .cGroupID  ="addr"
        .cControlSource = "V_Facility.Fac_Address"
        .nRows = 3
        .cLabel = "Address"
      endwith

      *!*        .AddObject("edtContact", "L7Textarea")
      *!*        with .edtContact
      *!*          * .cGroupID  ="addr"
      *!*          .cControlSource = "V_Facility.Fac_Contact"
      *!*          .nRows = 3
      *!*          .cLabel = "Contact"
      *!*        endwith

      *!*        .AddObject("txtEmail", "L7Textbox")
      *!*        with .txtEmail
      *!*          .cGroupID = "cont"
      *!*          .cFieldType = "C"
      *!*          .cControlSource = "V_Facility.Fac_Email"
      *!*          .cLabel = "Email"
      *!*          .cCssStyle = "width: 60%;"
      *!*          .nSize = 40
      *!*        endwith

      *!*        .AddObject("txtPhone", "L7Textbox")
      *!*        with .txtPhone
      *!*          .cGroupID = "cont"
      *!*          .cFieldType = "C"
      *!*          .cControlSource = "V_Facility.Fac_Phone"
      *!*          .cLabel = "Phone"
      *!*          .cCssStyle = "width: 40%;"
      *!*        endwith

      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cGroupID = "NOTES"
        .cControlSource = "V_Facility.Fac_Comments"
        .cLabel = "Comments about Facility"
        .nRows = 5
      endwith 

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cGroupID = "NOTES"
        .cControlSource = "V_Facility.Fac_Notes"
        .cLabel = "Internal KtB Notes"
        .nRows = 5
        .cCssClass = "FormControlPrivate"
      endwith
    endwith
  endfunc
enddefine  && FacilityForm

*** ===================================================== ***
define class AisFacQuery as L7Query
  cBaseTable = "Facility"
  cDefaultFieldList = ;
    "Fac_PK, Fac_ID, Fac_Name, Fac_Order, Fac_Storage, Fac_DropOff" + ;  
    ", Fac_Address, Fac_Contact, Fac_Comments" 

  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Fac_Order"

  lStorage = null
  lDropOff = null   
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Fac_Inactive = .F.] 
      if !isnull(.lStorage)
        .cWhereClause = .cWhereClause + [ and Fac_Storage = ] + iif(.lStorage, [.t.], [.f.])
      endif 
      if !isnull(.lDropOff)
        .cWhereClause = .cWhereClause + [ and Fac_DropOff = ] + iif(.lDropOff, [.t.], [.f.])
      endif 
    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisFacQuery

* end: FAC 

