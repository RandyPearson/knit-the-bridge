* AisTRN.PRG  && Training Classes

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ========================================================= ***
define class aisTrnPage as aisPage
  cTrn = ""
  oTrn = null
  lTrnRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lTrnRequired
      this.cTrn = evl(this.cTrn, this.StripUrl("trn", .f., .t.))
      if empty(this.cTrn)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyTraining()
        if !isnull(this.oTrn)
          * derived parent properties set here
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyTraining(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cTrn)
    loData = createobject("AisTrnData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cTrn
        this.oTrn = loData.GetRecord()
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
      .AddSubMenu("This", "TRAINING")
      if poContext.lDeveloper
        .addMenuItem(m.lcMenu, "Edit Training Metadata...", StuffUrl(.cUrlB, 2, "TrnBrowse"))
      endif
    endwith 
    dodefault()
    return 
  endfunc 
enddefine && AisTrnPage

*** ========================================================= ***
define class ais_TrnList as aisTrnPage 
  lTrnRequired = .f.
  cSubTitle = "Training Sessions"
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loTrnQry, loTbl, loCol, loGrp
       
    * Main query:
    loTrnQry = createobject("AisTrnQuery")
    with loTrnQry
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "TrnHome"), "TrnHome")

    loTbl = createobject("AisTable")
    with loTbl
      loCol = .addCursorColumn("Trn_Date", "Training Date")
      loCol = .addCursorColumn("Trn_Start_Time", "Start Time")
      loCol = .addCursorColumn("Trn_End_Time", "End Time")
    endwith 
    
    response.write(loTbl.render())    
    return 
  endfunc 
enddefine && TrnList

*** ===================================================== ***
define class Ais_TrnBrowse as AisTrnPage
  lTrnRequired = .f.
enddefine 

*** ===================================================== ***
define class Ais_TrnBrowse as AisTrnPage
  lTrnRequired = .f.
  * --------------------------------------------------------- *
  function ProcessRequest
    this.cCancelUrl = StuffUrl(this.cUrlA, 2, "TrnList")
    local loForm, lcXml, lcAlias, lcFldState, lcStub
    lcAlias = "V_All_Training"
    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    select (m.lcAlias)
    loForm = this.CreateForm("AisTrnBrowseForm", this.cUrlC)
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
  
enddefine  && Ais_TrnBrowse

*** ========================================================= ***
define class AisTrnBrowseForm AS AisForm
  cTitle = "Training Edit Form"
  cAlias = null && client should set 
  cCssStyle = "width: 100%;"
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject('grdBrowse', 'L7Grid')
      with .grdBrowse
        .cChildAlias = this.cAlias
        .cChildKeyExpression = this.cAlias + ".Trn_PK"
        .nExtraRows = 2 && don't permit adds 
        .cGridTableCssClass = "sortable " + .cGridTableCssClass 
        .cColumnHeaderCssClass = "nosort" && sortable doesn't work for live controls, so override on specific labels

        .AddObject("txtDate", "L7Textbox")
        with .txtDate
          .cControlSource = this.cAlias + ".Trn_Date"
          .cFieldType = "D"
          .cLabel = "Training Date"
          .cInstructions = "mm/dd/yyyy"
        endwith

        .AddObject("txtStart_Time", "L7Textbox")
        with .txtStart_Time
          .cControlSource = this.cAlias + ".Trn_Start_Time"
          .cLabel = "Start Time"
          .cInstructions = "enter as military time (e.g., 0800)"
        endwith

        .AddObject("txtEnd_Time", "L7Textbox")
        with .txtEnd_Time
          .cControlSource = this.cAlias + ".Trn_End_Time"
          .cLabel = "End Time"
          .cInstructions = "enter as military time (e.g., 0800)"
        endwith

        .AddObject("chkInstallation", "L7Checkbox")
        with .chkInstallation
          .cControlSource = this.cAlias + ".Trn_Installation"
          .cLabel = "Installation?"
          .lDisabled = !m.poContext.lAdmin
          .cCaption = "Installation Training"
          if this.lNewRecord
            .SetValue(.t.)
          endif 
        endwith

        .AddObject("edtComments", "L7Textarea")
        with .edtComments
          .cControlSource = this.cAlias + ".Trn_Comments"
          .cLabel = "Description and Comments"
          .nRows = 2
        endwith

        .AddObject("edtNotes", "L7Textarea")
        with .edtNotes 
          .cControlSource = this.cAlias + ".Trn_Notes"
          .cLabel = "Internal KtB Notes"
          .nRows = 2
          .cCssClass = "FormControlPrivate"
        endwith

        .AddObject("chkInactive", "L7Checkbox")
        with .chkInactive
          .cControlSource = this.cAlias + ".Trn_Inactive"
          .cLabel = "Delete?"
          .lDisabled = !m.poContext.lDeveloper
          .cCaption = "DELETE"
          .cCssClass = "FormControlPrivate"
        endwith

      endwith && grid 
    endwith && form
    return 
  endfunc  && AddControls
enddefine && TrnBrowseForm 

*** ===================================================== ***
define class AisTrnQuery as L7Query
  cBaseTable = "Training"
  cDefaultFieldList = ;
    "Trn_PK, Trn_Date, Trn_Start_Time, Trn_End_Time, Trn_Installation, Trn_Rev_Art_FK, Trn_Rev_Time" ;
      + ", Trn_Comments, Trn_Notes"

  lInstallation = null 
    
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Trn_Inactive = .F.] 

      if !isnull(.lInstallation)
        .cWhereClause = .cWhereClause + [ and Trn_Installation = ] + iif(.lInstallation, [.t.], [.f.])
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisTrnQuery

* end: TRN

