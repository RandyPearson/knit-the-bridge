* AisDon.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ========================================================= ***
define class aisDonPage as aisPage 
  cDon = ""
  oDon = null
  lDonRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lDonRequired
      this.cDon = evl(this.cDon, this.StripUrl("don", .f., .t.))
      if empty(this.cDon)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyDonation()
        if !isnull(this.oDon)
          * derived parent properties set here
          this.cArt = this.oDon.Don_Art_FK
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyDonation(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cDon)
    loData = createobject("AisDonData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cDon
        this.oDon = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc  && VerifyPiece 
enddefine && aisDonPage 

*** ========================================================= ***
define class ais_DonList as aisDonPage 
  lDonRequired = .f.

  lPage_Acknowledged = null
  lPage_Received = null 
  cPage_Order = null
  cPage_Flags = null
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr
    
    lcStr = this.ReadQueryString("Acknowledged", .t., .t.)
    this.lPage_Acknowledged = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')

    lcStr = this.ReadQueryString("Received", .t., .t.)
    this.lPage_Received = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')

    this.cPage_Flags = this.ReadQueryString("flags", .t., .t.)
    this.cPage_Order = this.ReadQueryString("order", .t., .t.)

    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function AddDefaultMenu
    local lcMenu
    with this
      .AddSubMenu("This", "DONATIONS")
      lcMenu = "main\This"

      .addMenuItem(m.lcMenu, "Acknowledged",     StuffUrl(.cUrlB, "Acknowledged", "1"))
      .addMenuItem(m.lcMenu, "Not Acknowledged", StuffUrl(.cUrlB, "Acknowledged", "0"))
      .addMenuItem(m.lcMenu, "All Donations",    StuffUrl(.cUrlB, "Acknowledged", .f.))

      .addMenuItem(m.lcMenu, 'Deleted Entries',  StuffUrl(.cUrlB, "flags", "inactive"))

    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisDonQuery")
    with loQry
      .lJoinArtist = .t. 

      if "," + "inactive" + "," $ "," + this.cPage_Flags + ","
        .lInactive = .t. 
      endif 
      .lAcknowledged = this.lPage_Acknowledged
      .lReceived     = this.lPage_Received
      
      .execute()
      
      this.cSubTitle = this.cSubTitle + .GetCaption()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "DonHome"), "DonHome")
    urls.add(StuffUrl(this.cUrlA, 2, "DonForm"), "DonForm")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")

    loTbl = createobject("AisTable")
    with loTbl
      .cTableCaption = this.cSubTitle 

      .cDataRowClass = .cDataRowClass + iif(empty(.cDataRowClass), [], [ + ]) + [iif(Don_Inactive, " deleted", "")]

      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Art_ID", "Artist ID", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Don_Art_FK), Art_ID)], "id-field artist")
      loCol = .addCursorColumn("Art_Last_Name", "Artist Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Don_Art_FK), aisArtistName(THISRECORD))], "artist")

      loCol = .addCursorColumn("Don_How_Donated", "How Donated")
      loCol = .addCursorColumn("Don_Date_Donated", "Date Donated")
      loCol = .addCursorColumn("Don_Cash_Amount", "Cash Amount")
      loCol.nCalcType = L7_CALCTYPE_SUM
      
      loCol = .addCursorColumn("Don_In_Kind_Amount", "In-Kind Value")
      loCol.nCalcType = L7_CALCTYPE_SUM

      loCol = .addCursorColumn("Don_Received", "Received?")
      loCol = .addCursorColumn("Don_Comments", "Comments")
      loCol = .addCursorColumn("Don_Acknowledged", "Acknowledged?")
      loCol = .addCursorColumn("Don_Date_Acknowledged", "Date Acknowledged")

      if poContext.lAdmin
        loCol = .addCursorColumn("Don_Notes", "Notes",, "private")
        loCol = .addCursorColumn("Don_PK", "Edit Entry", ;
          'HTLink(StuffUrl(urls.item("DonForm"), "don", Don_PK), "[Edit&nbsp;Donation...]")', 'no-print')
        loCol.cHeadingClass = "nosort no-print" 
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
define class ais_DonHome as aisDonPage 
  lArtRequired = .t. && for now, all Donations require a parent Artist
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.AddSubMenu("This", "This Donation")
    
    this.addMenuItem("main\This,page", "Edit Donation...", StuffUrl(this.cUrlA, 2, "DonForm", "don", this.cDon))
    this.addMenuItem("main\This,page", "Artist's Page", StuffUrl(this.cUrlA, 2, "ArtHome", "art", this.cArt))
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = "Donation from " + AisArtistName(Page.oArt.Art_PK) 
    response.write(this.page_getMainRecord())

    if poContext.lAdmin
      response.write(HTWrap(L7ShowObject(this.oDon, , [class="record"]),'div','admin'))
    endif
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData, llDeleted
    lcRet = ""
    loData = this.oDon
    llDeleted = loData.Don_Inactive 
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      .cCaption = this.cSubTitle
      if m.llDeleted
        .cCssClass = .cCssClass + " deleted"
        .cCaption = .cCaption + " [DELETED]"
      endif
      .AddHeading('Key Information')
      
      .AddRow("Artist ID", HtLink(StuffUrl(this.cUrlA, 2, "ArtHome", "art", this.oArt.ART_PK), this.oArt.ART_ID),, "id-field artist" )
      .AddRow("Artist's Name", HtLink(StuffUrl(this.cUrlA, 2, "ArtHome", "art", this.oArt.ART_PK), AisArtistName(this.oArt.ART_PK)))
      .AddRow("How Donated", loData.Don_How_Donated)
      .AddRow("Date Donated", loData.Don_Date_Donated)
      .AddRow("Cash Amount", loData.Don_Cash_Amount)
      .AddRow("In Kind Amount", loData.Don_In_Kind_Amount)
      .AddRow("Description and Comments", L7ParseOnView(loData.Don_COMMENTS))

      .AddHeading('Logistical Information')
      .AddRow("Received?", loData.Don_Received)
      .AddRow("Acknowledged?", loData.Don_Acknowledged)
      .AddRow("Date Acknowledged", loData.Don_Date_Acknowledged)
      .AddRow("Acknowledgement Ref", loData.Don_Acknowledge_Ref)
      if poContext.lCore
        .AddRow("Internal KtB Notes", L7ParseOnView(loData.Don_NOTES), .F., "private")
      endif

      if poContext.lCore
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.Don_PK), .F., "private")
        .AddRow("Deleted", loData.Don_INACTIVE, .F., "private")
        .AddRow("Created", TRANSFORM(loData.Don_ORIG_TIME) + [ by ] + AisArtistName(loData.Don_Orig_Art_FK), .F., "private")
        .AddRow("Last Modified", TRANSFORM(loData.Don_REV_TIME) + [ by ] + AisArtistName(loData.Don_Rev_Art_FK), .F., "private")
      endif

      lcRet = m.lcRet + .Render()

    endwith 
    return m.lcRet
  endfunc && page_getMainRecord
enddefine 

*** ========================================================= ***
define class ais_DonNew as ais_DonForm
  lAdding = .t.
  lDonRequired = .f.
enddefine 

*** ========================================================= ***
define class ais_DonForm as aisDonPage 
  lAdding = .f.
  lArtRequired = .t.
  * ----------------------------------------------------- *  
  function ProcessRequest

    this.Assert(poContext.lCore)
    this.cCancelUrl = iif(this.lAdding, StuffURL(THIS.cUrlA, 2, "ArtHome", "art", this.cArt), ;
      StuffURL(THIS.cUrlB, 2, "DonHome"))

    local loForm, vp_cDon_PK, loOldRec, loNewRec
    vp_cDon_PK = IIF(THIS.lAdding, space(32), THIS.cDon)
    use V_Donation in select("V_Donation")
    if !this.lAdding
      select V_Donation
      scatter memo name loOldRec
    endif 
    cursorsetprop("Buffering", 5, "V_Donation")
    loForm = this.createForm('aisDonationForm', this.cUrlC)
    with loForm
      .lNewRecord = THIS.lAdding
      .AddControls()
      .DoEvents() 

      if .Valid()
        select V_Donation
        if this.lAdding
          append blank
          replace Don_Art_FK with this.cArt 
        endif 
        .UpdateControlSources()
        select V_Donation  && UpdateControlSources can alter work area
        StampRec( CurrentUser, THIS.tNow )
        scatter memo name loNewRec 
        
        * Now save the Donation using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail
        llSendEmail = .f.  
        loTrans = this.CreateTransaction()
        loTrans.AddCursor("V_Donation")

        if loTrans.Save()  
          select V_Donation
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
enddefine && ais_DonForm

*** ========================================================= ***
define class aisDonationForm as AisForm
  cTitle = "Donation Form"
  cCustom_Type = null 
  cCssStyle = "width: 80em;"
  * --------------------------------------------------------- *
  function  AddControls
    with this
      
      .AddObject("txtArt_Fk", "L7Label")
      with .txtArt_Fk
        .cGroupID = "ID"
        .cFieldType = "C"
        .cControlSource = "V_Donation.Don_Art_Fk"
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
        .cControlSource = "V_Donation.Don_Pk"
        .cLabel = "Internal Key"
        .cCssClass = "FormControlPrivate"
      endwith 

      .AddObject("chkInactive", "L7Checkbox")
      with .chkInactive
        .cGroupID = "ID"
        .cControlSource = "V_Donation.Don_Inactive"
        .cLabel = "Delete?"
        .lDisabled = !m.poContext.lAdmin
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("cboHow_Donated", "L7Popup")
      with .cboHow_Donated
        *.cGroupID = "INPUT"
        .cControlSource = "V_Donation.Don_How_Donated"
        .cFieldType = "C"
        .cLabel = "How Donated"
        .nStyle = L7_MULTISTYLE_VERTICAL
        .nRowSourceType = L7_ROWSOURCETYPE_VALUE
        .cRowSource = THISAPP_HOW_DONATED_ENUM
      endwith 

      .AddObject("txtDate_Donated", "L7Textbox")
      with .txtDate_Donated
        *.cGroupID = "INPUT"
        .cFieldType = "D"
        .cControlSource = "V_Donation.Don_Date_Donated"
        .cLabel = "Date Donated"
        .cInstructions = "MM/DD/YYYY"
      endwith 

      .AddObject("txtCash_Amount", "L7Textbox")
      with .txtCash_Amount
        *.cGroupID = "INPUT"
        .cFieldType = "Y"
        .cControlSource = "V_Donation.Don_Cash_Amount"
        .cLabel = "Cash Amount"
        .cInstructions = "DO NOT enter $ signs or commas! (Ex: 50.00)"
      endwith 

      .AddObject("txtIn_Kind_Amount", "L7Textbox")
      with .txtIn_Kind_Amount
        *.cGroupID = "INPUT"
        .cFieldType = "Y"
        .cControlSource = "V_Donation.Don_In_Kind_Amount"
        .cLabel = "In-Kind Amount"
        .cInstructions = "DO NOT enter $ signs or commas! (Ex: 50.00)"
      endwith 

      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        * .cGroupID = "NOTES"
        .cControlSource = "V_Donation.Don_Comments"
        .cLabel = "Description and Comments"
        .nRows = 2
      endwith 

      .AddObject("chkReceived", "L7Checkbox")
      with .chkReceived
        *.cGroupID = "STATUS"
        .cControlSource = "V_Donation.Don_Received"
        .cLabel = "Received?"
        .cCssClass = "FormControlPrivate"
      endwith 

      .AddObject("chkAcknowledged", "L7Checkbox")
      with .chkAcknowledged
        *.cGroupID = "STATUS"
        .cControlSource = "V_Donation.Don_Acknowledged"
        .cLabel = "Acknowledged?"
      endwith 

      .AddObject("txtDate_Acknowledged", "L7Textbox")
      with .txtDate_Acknowledged
        *.cGroupID = "STATUS"
        .cFieldType = "D"
        .cControlSource = "V_Donation.Don_Date_Acknowledged"
        .cLabel = "Date Acknowledged"
        .cInstructions = "MM/DD/YYYY"
      endwith 

      .AddObject("edtAcknowledge_Ref", "L7Textarea")
      with .edtAcknowledge_Ref
        *.cGroupID = "STATUS"
        .cControlSource = "V_Donation.Don_Acknowledge_Ref"
        .cLabel = "Acknowledgement Ref"
        .nRows = 2
      endwith 

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        *.cGroupID = "NOTES"
        .cControlSource = "V_Donation.Don_Notes"
        .cLabel = "Internal KtB Notes"
        .nRows = 3
        .cCssClass = "FormControlPrivate"
      endwith
    endwith
    return 
  endfunc && AddControls 
enddefine  && DonationForm

*** ===================================================== ***
define class AisDonQuery as L7Query
  cBaseTable = "Donation"
  cDefaultFieldList = "Don_PK, Don_Inactive, Don_Rev_Time, Don_Art_FK, Don_Cash_Amount, Don_In_Kind_Amount, Don_Date_Donated, Don_How_Donated" + ;
    ", Don_Received, Don_List_Name, Don_Acknowledged, Don_Date_Acknowledged, Don_Acknowledge_Ref, Don_Comments, Don_Notes"
      
  nOrderBy = 1
  dimension aOrderBy[ 1, 2]
  aOrderBy[ 1, 1] = "Don_Date_Donated"

  cID = null 

  lInactive = .f.  && whole record deleted

  cArt = null
  
  lReceived   = null
  lAcknowledged = null
  
  lJoinArtist = .f. 
  * --------------------------------------------------------- *
  function GetCaption 
    local lcRet
    lcRet = ""
    with this
      lcRet = m.lcRet + ;
        iif(isnull(.lAcknowledged), "", iif(.lAcknowledged, " Acknowledged", " Un-Acknowledged")) 
      lcRet = m.lcRet + " Donations"
      if !isnull(.lReceived)
        lcRet = m.lcRet + ", w/ Status: " + substr( ;
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
        .cWhereClause = [WHERE Don_Inactive = ] + IIF(.lInactive, [.T.], [.F.])
      endif 

      if .lJoinArtist
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Artist"
        .aJoins[.nJoins, 2] = "Don_Art_FK = Art_PK"
        .AddFields("Art_ID,Art_Last_Name,Art_First_Name,Art_Anonymous,Art_Full_Name")
      endif 

      if !isnull(.cArt)
        .cWhereClause = .cWhereClause + [ and Don_Art_FK = '] + .cArt + [']
      endif 

      if !isnull(.lReceived)
        .cWhereClause = .cWhereClause + [ and Don_Received = ] + iif(.lReceived, [.t.], [.f.])
      endif 
      if !isnull(.lAcknowledged)
        .cWhereClause = .cWhereClause + [ and Don_Acknowledged = ] + iif(.lAcknowledged, [.t.], [.f.])
      endif 
    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisDonQuery


* end 
