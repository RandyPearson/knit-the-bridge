* AisFac.PRG  && facility pages

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

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
        [HTLink(StuffUrl(urls.item("FacHome"), "Fac", Fac_PK), Fac_ID)])
      loCol = .addCursorColumn("Fac_Name", "Facility Name")
      loCol = .addCursorColumn("Fac_DropOff", "Drop-Off?")
      loCol = .addCursorColumn("Fac_Storage", "Storage?")
      loCol = .addCursorColumn("Fac_Address", "Address", [L7ParseOnView(Fac_Address)])
      loCol = .addCursorColumn("Fac_PK", "Edit Facility", ;
        'HTLink(StuffUrl(urls.item("FacForm"), "fac", Fac_PK), "[Edit Facility...]")')
      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_FacHome as aisFacPage 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.AddSubMenu("This", "This Facility")
    this.addMenuItem("main\This,page", "Edit Facility...", StuffUrl(this.cUrlA, 2, "FacForm", "Fac", this.cFac))
    this.addMenuItem("main\This,page", "List of Facilities", StuffUrl(this.cUrlA, 2, "FacList"))
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Facility " + this.oFac.Fac_ID + " - " + trim(this.oFac.Fac_Name) 
    response.write(this.page_getMainRecord())

    if poContext.lAdmin
      response.write(HTWrap(L7ShowObject(this.oFac, , [class="record"]),'div','admin'))
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
      .AddRow("Contact", loData.Fac_Contact)
      .AddRow("Email", loData.Fac_Email)
      .AddRow("Phone", loData.Fac_Phone)
      .AddRow("Address", L7ParseOnView(loData.Fac_Address))
      .AddRow("Comments", L7ParseOnView(loData.Fac_Comments))

      .AddHeading('Logistical Information')
      .AddRow("Drop-Off Location?", loData.Fac_DropOff)
      .AddRow("Storage Location?", loData.Fac_Storage)
      if poContext.lCore
        .AddRow("Notes", L7ParseOnView(loData.fac_NOTES), .F., "private")
      endif

      if poContext.lCore
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.Fac_PK), .F., "private")
        .AddRow("Deleted", loData.Fac_INACTIVE, .F., "private")
        .AddRow("Created", TRANSFORM(loData.Fac_ORIG_TIME) + [ by ] + AisArtistName(loData.Fac_Orig_Art_FK), .F., "private")
        .AddRow("Last Modified", TRANSFORM(loData.Fac_REV_TIME) + [ by ] + AisArtistName(loData.Fac_Rev_Art_FK), .F., "private")
      endif

      lcRet = lcRet + .Render()

    endwith 
    return m.lcRet
  endfunc && page_getMainRecord
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
    loForm = this.createForm('aisFacilityForm')
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
        
      endif 

    endwith 
    response.write(loForm.render())
  endfunc 
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
          .cLabel = "Pacel ID"
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

      .AddObject("edtAddress", "L7Textarea")
      with .edtAddress
        .cGroupID  ="addr"
        .cControlSource = "V_Facility.Fac_Address"
        .nRows = 3
        .cLabel = "Address"
      endwith

      .AddObject("edtContact", "L7Textarea")
      with .edtContact
        * .cGroupID  ="addr"
        .cControlSource = "V_Facility.Fac_Contact"
        .nRows = 3
        .cLabel = "Contact"
      endwith

      .AddObject("txtEmail", "L7Textbox")
      with .txtEmail
        .cGroupID = "cont"
        .cFieldType = "C"
        .cControlSource = "V_Facility.Fac_Email"
        .cLabel = "Email"
        .cCssStyle = "width: 60%;"
        .nSize = 40
      endwith

      .AddObject("txtPhone", "L7Textbox")
      with .txtPhone
        .cGroupID = "cont"
        .cFieldType = "C"
        .cControlSource = "V_Facility.Fac_Phone"
        .cLabel = "Phone"
        .cCssStyle = "width: 40%;"
      endwith

      .AddObject("chkDropoff", "L7Checkbox")
      with .chkDropoff
        .cGroupID = "DIM"
        .cControlSource = "V_Facility.Fac_Dropoff"
        .cLabel = "Is this a drop-off Facility?"
        .nMode = L7_MULTI_RADIOBUTTON
        .nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
        .cCaption = "Yes"
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
        .cCaption = "Yes"
        .cFalseCaption = "No" 
        .lFalseBeforeTrue = .T.
        .cInterControlText = NULL 
      endwith 

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
    "Fac_PK, Fac_ID, Fac_Name, Fac_Storage, Fac_DropOff" + ;  
    ", Fac_Address, Fac_Contact, Fac_Email, Fac_Phone, Fac_Comments" 

  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Fac_Name"

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

