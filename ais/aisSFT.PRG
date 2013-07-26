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
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Sft_Inactive = .F.] 

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

* end: Sft

