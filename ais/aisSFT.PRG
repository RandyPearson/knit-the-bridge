* AisSFT.PRG  && Shift Classes

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* --------------------------------------------------------- *
function aisShiftName(tvSft)
  local loData, loPreserve
  if vartype(m.tvSft) = "O"
    loData = m.tvSft
  else  && PK
    if isnull(m.tvSft) or empty(m.tvSft)
      return "--"
    endif
    loPreserve = createobject("L7PreserveSelect")
    select * from KtbAis!Shift ;
      where Sft_PK = m.tvSft ;
      into cursor aisShiftName_
    if _tally < 1
      error "Shift " + m.tvSft + " was not found!"
    endif
    scatter memo name loData
    loPreserve = null 
  endif 
    
  return cdow(loData.Sft_Date) + ", " + dtoc(loData.Sft_Date) + " " + stuff(loData.Sft_Start_Time, 3, 0, ":") + " to " + stuff(loData.Sft_End_Time, 3, 0, ":")
endfunc  && aisShiftName

*** ========================================================= ***
define class aisSftPage as aisPage
  cSft = ""
  oSft = null
  lSftRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lSftRequired
      this.cSft = evl(this.cSft, this.StripUrl("Sft", .f., .t.))
      if empty(this.cSft)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyShift()
        if !isnull(this.oSft)
          * derived parent properties set here
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyShift(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cSft)
    loData = createobject("AisSftData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cSft
        this.oSft = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local lcMenu
    lcMenu = "main\This"
    with this
      .AddSubMenu("This", "SHIFTS")
      if poContext.lAdmin
        .addMenuItem(m.lcMenu, "Edit Shift Metadata...", StuffUrl(.cUrlB, 2, "SftBrowse"))
      endif
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function module_listShifts()
    local lcRet, loQry, loTbl, loCol, loGrp
       
    * Main query:
    loQry = createobject("AisSftQuery")
    with loQry
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "SftHome"), "SftHome")

    loTbl = createobject("AisTable")
    with loTbl
      .cTableCaption = "All Shifts" 
      
      loCol = .addCursorColumn("Sft_PK", "Shift", ;
        [HTLink(StuffUrl(urls.item("SftHome"), "sft", Sft_PK), AisShiftName(Sft_PK))])
      loCol = .addCursorColumn("Sft_Date", "Shift Date")
      loCol = .addCursorColumn("Sft_Start_Time", "Start Time")
      loCol = .addCursorColumn("Sft_End_Time", "End Time")
      loCol = .addCursorColumn("Sft_Installation", "Installation", ;
        [iif(Sft_Installation, "Installation", "") + iif(Sft_DeInstallation, "De-Installation", "")] )
      loCol = .addCursorColumn("Sft_Notes", "Notes")
      lcRet = .render()
    endwith 
    return m.lcRet  
  endfunc 
enddefine && AisSftPage

*** ========================================================= ***
define class ais_SftList as aisSftPage 
  lSftRequired = .f.
  cSubTitle = "Shifts"
  * ----------------------------------------------------- *  
  function ProcessRequest
    response.write(this.module_listShifts())
    return 
  endfunc 
enddefine && SftList

*** ========================================================= ***
define class ais_SftHome as aisSftPage 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.AddSubMenu("This", "This Shift")
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Shift: " + AisShiftName(this.oSft)
    response.write(this.page_getMainRecord())
    response.write(this.module_listShifts())
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData
    lcRet = ""
    loData = this.oSft
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      .cCaption = this.cSubTitle
      .AddHeading('Key Information')
      
      .AddRow("Date", loData.Sft_Date)
      .AddRow("Installation?", loData.Sft_Installation)
      .AddRow("De-Installation?", loData.Sft_DeInstallation)

      .AddHeading('People Signed Up for This Shift')
      .AddRow(null, this.page_getRoleInfo())

      if poContext.lCore
        .AddRow("Notes", L7ParseOnView(loData.Sft_Notes), .F., "private")
      endif

      if poContext.lAdmin
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.Sft_PK), .F., "private")
        .AddRow("Deleted", loData.Sft_INACTIVE, .F., "private")
        .AddRow("Created", TRANSFORM(loData.Sft_ORIG_TIME) + [ by ] + AisArtistName(loData.Sft_Orig_Art_FK), .F., "private")
        .AddRow("Last Modified", TRANSFORM(loData.Sft_REV_TIME) + [ by ] + AisArtistName(loData.Sft_Rev_Art_FK), .F., "private")
      endif

      lcRet = m.lcRet + .Render()
    endwith 
    return m.lcRet
  endfunc && page_getMainRecord
  * ----------------------------------------------------- *  
  function page_getRoleInfo
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisArtQuery")
    with loQry
      .lJoinArs = .t. 
      .cSft = this.cSft
      .addShiftFields()
      .addTrainingFields()

      .AddOrderBy("Ars_Role")
      .AddOrderBy("Art_ID", , .T.)
      .execute()
      if .nTally = 0
        return "(none)"
      endif 
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtForm", "return", this.cUrlC), "ArtForm")

    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Art_PK), aisArtistName(THISRECORD))], 'artist')
      loCol = .addCursorColumn("Ars_Role", "Role")
      loCol = .addCursorColumn("Art_Email", "Email")
      loCol = .addCursorColumn("Art_Phone", "Phone")
      loCol = .addCursorColumn("Art_Neighborhood", "Neighborhood")
      loCol = .addCursorColumn("Art_Waiver_Signed", "Acc<br>Waiver")
      loCol.cDisplayExpression = [iif(Art_Waiver_Signed, "Yes", "--")]
      
      loCol = .addCursorColumn("Art_Training_Signed", "Training<br>Waiver")
      loCol.cDisplayExpression = [iif(Art_Training_Signed, "Yes", "--")]

      if poContext.lAdmin
        loCol = .addCursorColumn("Art_PK", "Edit Artist", ;
          'HTLink(StuffUrl(urls.item("ArtForm"), "art", Art_PK), Art_ID + "...")', 'no-print')
        loCol.cHeadingClass = "nosort no-print" 
      endif 

      return .render()
    endwith 
    
    return 
  endfunc && page_getPanelInfo
enddefine && SftHome

*** ===================================================== ***
define class Ais_ArsNew as AisArtPage
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = StuffURL(THIS.cUrlB, 2, "ArtHome")
    this.Assert(poContext.lAdmin)
    this.cSubTitle = "Add Shift for " + AisArtistName(this.oArt)

    local loForm, vp_cArs_PK, loQ, lcAlias
    loQ = createobject("AisSftQuery")
    with loQ
      .cAlias = "Available_Shifts_"
      .Execute()
    endwith 
    this.assert(loQ.nTally > 0, "No shifts.")

    lcAlias = "V_ArtistShift"
    vp_cArs_PK = space(32)
    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    loForm = this.createForm('aisArsForm', this.cUrlC)
    with loForm
      .AddControls()
      .DoEvents() 

      if .Valid()
        select (m.lcAlias)
        append blank
        replace Ars_Art_FK with this.cArt

        .UpdateControlSources()
        select (m.lcAlias) && UpdateControlSources can alter work area
        StampRec( CurrentUser, THIS.tNow )
        scatter memo name loNewRec 
        
        * Now save the record using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail
        llSendEmail = .f.  
        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor(m.lcAlias)

        if loTrans.Save()  
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
enddefine && ArsNew 

*** ========================================================= ***
define class aisArsForm as AisForm
  cTitle = "Assign Shift Form"
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject("cboSft_FK", "L7Popup")
      with .cboSft_FK
        .cControlSource = "V_ArtistShift.Ars_Sft_FK"
        .lRequired = .t.
        .cLabel = "Shift"
        .lAutoRender = .T.
        .nRowSourceType = L7_ROWSOURCETYPE_ALIAS
        .cRowSource = "Available_Shifts_"
        .cValueExpression = [Sft_PK]
        .cLabelExpression = [dtoc(Sft_Date) + ", " + Sft_Start_Time + "-" + Sft_End_Time]
        .vFirstItemValue = space(32) && 0 for integer keys
        .cFirstItemLabel = "[ select shift ]"
      endwith 

      .AddObject("cboRole", "L7RadioButton")
      with .cboRole
        .cControlSource = "V_ArtistShift.Ars_Role"
        .lRequired = .t.
        .cFieldType = "C"
        .cLabel = "Role"
        .nStyle = L7_MULTISTYLE_VERTICAL
        .nRowSourceType = L7_ROWSOURCETYPE_VALUE
        .cRowSource = THISAPP_ROLE_ENUM
      endwith 

    endwith
    return 
  endfunc 
enddefine 

*** ===================================================== ***
define class Ais_SftBrowse as AisSftPage
  lSftRequired = .f.
  * --------------------------------------------------------- *
  function ProcessRequest
    this.cCancelUrl = StuffUrl(this.cUrlA, 2, "SftList")
    local loForm, lcXml, lcAlias, lcFldState, lcStub
    lcAlias = "V_All_Shift"
    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    select (m.lcAlias)
    loForm = this.CreateForm("AisSftBrowseForm", this.cUrlC)
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
    endwith 
    return   
  endfunc 
  
enddefine  && Ais_SftBrowse

*** ========================================================= ***
define class AisSftBrowseForm AS AisForm
  cTitle = "Shift Edit Form"
  cAlias = null && client should set 
  cCssStyle = "width: 100%;"
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject('grdBrowse', 'L7Grid')
      with .grdBrowse
        .cChildAlias = this.cAlias
        .cChildKeyExpression = this.cAlias + ".Sft_PK"
        .nExtraRows = 5
        .cGridTableCssClass = "sortable " + .cGridTableCssClass 
        .cColumnHeaderCssClass = "nosort" && sortable doesn't work for live controls, so override on specific labels

        .AddObject("txtDate", "L7Textbox")
        with .txtDate
          .cControlSource = this.cAlias + ".Sft_Date"
          .cFieldType = "D"
          .cLabel = "Training Date"
          .cInstructions = "mm/dd/yyyy"
        endwith

        .AddObject("txtStart_Time", "L7Textbox")
        with .txtStart_Time
          .cControlSource = this.cAlias + ".Sft_Start_Time"
          .cLabel = "Start Time"
          .cInstructions = "enter as military time (e.g., 0800)"
        endwith

        .AddObject("txtEnd_Time", "L7Textbox")
        with .txtEnd_Time
          .cControlSource = this.cAlias + ".Sft_End_Time"
          .cLabel = "End Time"
          .cInstructions = "enter as military time (e.g., 0800)"
        endwith

        .AddObject("chkInstallation", "L7Checkbox")
        with .chkInstallation
          .cControlSource = this.cAlias + ".Sft_Installation"
          .cLabel = "Installation?"
          .lDisabled = !m.poContext.lAdmin
          .cCaption = "Installation"
          if this.lNewRecord
            .SetValue(.t.)
          endif 
        endwith

        .AddObject("chkDeInstallation", "L7Checkbox")
        with .chkDeInstallation
          .cControlSource = this.cAlias + ".Sft_DeInstallation"
          .cLabel = "De-Installation?"
          .lDisabled = !m.poContext.lAdmin
          .cCaption = "De-Installation"
          if this.lNewRecord
            .SetValue(.t.)
          endif 
        endwith

        .AddObject("edtNotes", "L7Textarea")
        with .edtNotes 
          .cControlSource = this.cAlias + ".Sft_Notes"
          .cLabel = "Internal KtB Notes"
          .nRows = 2
          .cCssClass = "FormControlPrivate"
        endwith

        .AddObject("chkInactive", "L7Checkbox")
        with .chkInactive
          .cControlSource = this.cAlias + ".Sft_Inactive"
          .cLabel = "Delete?"
          .lDisabled = !m.poContext.lDeveloper
          .cCaption = "DELETE"
          .cCssClass = "FormControlPrivate"
        endwith

      endwith && grid 
    endwith && form
    return 
  endfunc  && AddControls
enddefine && SftBrowseForm 

*** ===================================================== ***
define class AisSftQuery as L7Query
  cBaseTable = "Shift"
  cDefaultFieldList = ;
    "Sft_PK, Sft_Date, Sft_Start_Time, Sft_End_Time, Sft_Installation, Sft_DeInstallation, Sft_Rev_Art_FK, Sft_Rev_Time" ;
      + ", Sft_Notes"

  lInstallation = null 
  lDeInstallation = null
  
  lJoinArs = .f.
  
  cArt = null 
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 

      if .lJoinArs
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "ArtistShift"
        .aJoins[.nJoins, 2] = "Sft_PK = Ars_Sft_FK"
        .aJoins[.nJoins, 3] = "INNER"
        .AddFields("Ars_Role")
      endif 

      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Sft_Inactive = .F.] 

      if !isnull(.cArt)
        .cWhereClause = .cWhereClause + [ and Sft_PK in ] + ;
          [(select Ars_Sft_FK from ArtistShift where !Ars_inactive and Ars_Art_FK = '] + .cArt + [')]
      endif 
      
      if !isnull(.lInstallation)
        .cWhereClause = .cWhereClause + [ and Sft_Installation = ] + iif(.lInstallation, [.t.], [.f.])
      endif 
      if !isnull(.lDeInstallation)
        .cWhereClause = .cWhereClause + [ and Sft_DeInstallation = ] + iif(.lDeInstallation, [.t.], [.f.])
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisSftQuery

*** ===================================================== ***
define class AisArsQuery as L7Query
  cBaseTable = "ArtistShift"
  
  cDefaultFieldList = "Ars_PK, Ars_Role"

  lJoinArt = .f. 
  lJoinSft = .f. 
  
  cSft = null
  cArt = null

  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Ars_Inactive = .F.] 

      if .lJoinArt
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Artist"
        .aJoins[.nJoins, 2] = "Ars_Art_FK = Art_PK"
        .AddFields("Art_ID")
      endif 

      if .lJoinSft
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Shift"
        .aJoins[.nJoins, 2] = "Ars_Sft_FK = Sft_PK"
        .AddFields("Sft_PK, Sft_Date, Sft_Start_Time, Sft_End_Time, Sft_Installation, Sft_DeInstallation, Sft_Notes")
      endif 

      if !isnull(.cArt)
        .cWhereClause = .cWhereClause + [ and Ars_Art_FK = '] + .cArt + ['] 
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisArsQuery

* end: Sft

