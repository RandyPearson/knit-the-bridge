* AisArtPages.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

function AisArtQueryFlags()
  return L7JsonParse( ;
    '[' + ;
    '{"root": "core", "prompt": "Team"}' + ;
    ',{"root": "install", "field": "Art_Help_Install"}' + ;
    ',{"root": "outreach", "field": "Art_Help_Outreach"}' + ;
    ',{"root": "towers"}' + ;
    ',{"root": "artist"}' + ;
    ',{"root": "admin", "menu": false}' + ;
    ']' )
endfunc 

* --------------------------------------------------------- *
function aisArtistName(tvArt)
  local loData, loPreserve
  if vartype(m.tvArt) = "O"
    loData = m.tvArt
  else  && PK
    if isnull(m.tvArt) or empty(m.tvArt)
      return "--"
    endif
    loPreserve = createobject("L7PreserveSelect")
    select * from KtbAis!Artist ;
      where Art_PK = m.tvArt ;
      into cursor aisArtistName_
    if _tally < 1
      error "Artist " + m.tvArt + " was not found!"
    endif
    scatter memo name loData
    loPreserve = null 
  endif 
    
  if empty(loData.Art_Last_Name )
    return trim(loData.Art_User_ID )
  else 
    if empty(loData.Art_First_Name )
      return trim(loData.Art_Last_Name )
    else 
      return trim(loData.Art_First_Name ) + [ ] + trim(loData.Art_Last_Name )
    endif 
  endif 
  return  
endfunc  && aisArtistName

*** ========================================================= ***
define class aisArtPage as aisPage 
  cArt = ""
  oArt = null
  lArtRequired = .t.
  oArtQueryFlags = null && _ACCESS
  * --------------------------------------------------------- *
  function oArtQueryFlags_ACCESS
    if isnull(this.oArtQueryFlags)
      this.oArtQueryFlags = AisArtQueryFlags()
    endif
    return this.oArtQueryFlags 
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_ArtList as aisArtPage 
  lArtRequired = .f.
  cPage_Flags = null
  lPage_Approved = null
  cSubTitle = "Artists N'At"
  cPage_Srch1 = null
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr

    this.cPage_Srch1 = this.ReadQueryString("srch1", .t., .t., .t.)
    this.cPage_Flags = this.ReadQueryString("flags", .t., .t.)

    lcStr = this.ReadQueryString("approved", .t., .t.)
    this.lPage_Approved = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')
    
    dodefault()  && required bubble-up
    return    
  endfunc  
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local loFlags, lnFlag, loFlag 
    with this
      loFlags = .oArtQueryFlags
      for lnFlag = 1 to loFlags.count
        loFlag = loFlags.item[m.lnFlag]
        if pemstatus(loFlag, "menu", 5) and !loFlag.menu
          loop
        endif
        .addMenuItem("main\This", proper(loFlag.root), StuffUrl(.cUrlB, "flags", loFlag.root))
      next 
      if poContext.lAdmin
        .addMenuItem("main\This", "Approved", StuffUrl(.cUrlB, "Approved", "1"),, !isnull(.lPage_Approved) and .lPage_Approved)
        .addMenuItem("main\This", "Not Approved", StuffUrl(.cUrlB, "Approved", "0"),, !isnull(.lPage_Approved) and !.lPage_Approved)
        .addMenuItem("main\This", "Approved and Not Approved", StuffUrl(.cUrlB, "Approved", .f.),, isnull(.lPage_Approved))

        .addMenuItem("main\This", "Process Approvals", StuffUrl(.cUrlB, 2, "BrowseUnapproved"))
      endif 
      .addMenuItem("main\This", "ALL", StuffUrl(.cUrlB))
    endwith
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loFlags, lnFlag, loFlag, lcProp, ;
       loTbl, loCol, loGrp
       
    loQry = createobject("AisArtQuery")
    with loQry
      loFlags = this.oArtQueryFlags
      for lnFlag = 1 to loFlags.count
        loFlag = loFlags.item[m.lnFlag]
        if "," + loFlag.root + "," $ "," + this.cPage_Flags + ","
          lcProp = "l" + loFlag.root
          store .t. to loQry.&lcProp
        endif 
      next 
      .lAccountInactive = this.lPage_Approved
      .cSrch1 = this.cPage_Srch1
      
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtForm"), "ArtForm")

    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Art_Last_Name", "Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Art_PK), trim(Art_Last_Name) + ", " + trim(Art_First_Name))])
      loCol = .addCursorColumn("Art_Email", "Email")
      loCol = .addCursorColumn("Art_Phone", "Phone")
      loCol = .addCursorColumn("Art_Register_Time", "Sign-Up Time", [L7TimeDiff(Art_Register_Time)])
      loCol = .addCursorColumn("Art_KTB_Response", "Respose")
      loCol = .addCursorColumn("Art_Approved", "Approved?")
      loCol = .addCursorColumn("Art_ID", "Artist ID")
      if poContext.lCore
        loCol = .addCursorColumn("Art_PK", "Edit Artist", ;
          'HTLink(StuffUrl(urls.item("ArtForm"), "art", Art_PK), "[Edit Artist...]")')
      endif 
      response.write(.render())

      if poContext.lCore
        Response.Write(HTWrap(loQry.cSqlStatement, 'div,p', 'admin,debug'))
      endif
    endwith 
    
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_ArtHome as aisArtPage 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.addMenuItem("main\This,page", "Modify Artist...", StuffUrl(this.cUrlA, 2, "ArtForm", "art", this.cArt))
    if this.oArt.Art_Artist
      this.addMenuItem("main\This,page", "New Piece from this artist...", StuffUrl(this.cUrlA, 2, "PceNew", "art", this.cArt))
    endif   
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = AisArtistName(this.oArt) + ;
      iif(this.oArt.Art_Approved, ", ID: " + this.oArt.Art_ID, ", No ID (still not approved)")
    
    if this.oArt.Art_Artist
      response.write(this.page_getPieceInfo())
    endif

    response.write(this.page_getMainRecord())
    
    if poContext.lCore
      response.write(HTWrap("Core Info" + this.cSubTitle, 'h3'))
      *!* response.write(L7ShowObject(this.oArt, this.cSubTitle, [class="record"]))
    endif 
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData
    lcRet = ""
    loData = this.oArt
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      .cCaption = AisArtistName(m.loData) + " Data"
      .AddHeading('Key Information')
      
      .AddRow("Approved", loData.ART_APPROVED)
      .AddRow("ID", loData.ART_ID)

      .AddRow("Last Name", TRIM(loData.ART_LAST_NAME), .F.)
      .AddRow("First Name", TRIM(loData.ART_FIRST_NAME), .F.)
      .AddRow("Alternative Full Name", TRIM(loData.ART_FULL_NAME), .t.)
      .AddRow("Original Name (from blog)", loData.ART_NAME_ORIG, .t., "private")
      .AddRow("Anonymous", loData.ART_ANONYMOUS, .F.)
      .AddRow("Unknown", loData.ART_UNKNOWN, .F.)

      .AddRow("Email", HTEmailLink(TRIM(loData.ART_EMAIL), .f., .f., .f., .t.))
      .AddRow("Phone", TRIM(loData.ART_PHONE))
      .AddRow("Original Contact (from blog)", loData.ART_CONTACT_ORIG, .F.)
      .AddRow("Neighborhood", TRIM(loData.ART_NEIGHBORHOOD), .F.)
      .AddRow("Address (from blog)", L7ParseOnView(loData.ART_ADDRESS), .F.)
      .AddRow("Age Range", TRIM(loData.ART_AGE_RANGE), .F.)

      .AddHeading('Participation')
      .AddRow("Artist?", loData.ART_ARTIST)
      .AddRow("Partial Panel", loData.ART_PARTIAL_PANEL)
      .AddRow("Panel Info", L7ParseOnView(loData.ART_PANEL_INFO))
      .AddRow("Panel Count", loData.ART_PANEL_COUNT)
      .AddRow("Towers", loData.ART_TOWERS)
      .AddRow("Help Install", loData.ART_HELP_INSTALL)
      .AddRow("Help Materials", loData.ART_HELP_MATERIALS)
      .AddRow("Help Meet Up", loData.ART_HELP_MEET_UP)
      .AddRow("Help Outreach", loData.ART_HELP_OUTREACH)
      .AddRow("Help Other", L7ParseOnView(loData.ART_HELP_OTHER))
      .AddRow("Comments", L7ParseOnView(loData.ART_COMMENTS))
      .AddRow("Participation (from blog)", L7ParseOnView(loData.ART_PARTICIPATION))

      .AddHeading('Other Info and Characteristics')
      .AddRow("Register Time", loData.ART_REGISTER_TIME, .F.)
      .AddRow("Ktb Response", L7ParseOnView(loData.ART_KTB_RESPONSE))
      .AddRow("Bit Info", L7ParseOnView(loData.ART_BIT_INFO), .F.)
      .AddRow("Received", loData.ART_RECEIVED, .F.)
      .AddRow("Storage Location", L7ParseOnView(loData.ART_STORAGE_LOCATION), .F.)

      if poContext.lCore
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.ART_PK), .F., "Private")
        .AddRow("Admin", loData.ART_ADMIN, .F.)
        .AddRow("Core", loData.ART_CORE, .F.)
        .AddRow("Inactive", loData.ART_INACTIVE, .F., "Private")
        .AddRow("Access Token", TRIM(loData.ART_ACCESS_TOKEN), .F.)
        .AddRow("User Id", TRIM(loData.ART_USER_ID), .F.)
        .AddRow("Password Count", loData.ART_PASSWORD_COUNT, .F.)
        .AddRow("Password Time", loData.ART_PASSWORD_TIME, .F.)
        .AddRow("Password Expiry Time", loData.ART_PASSWORD_EXPIRY_TIME, .F.)
        .AddRow("Account Lockout", loData.ART_ACCOUNT_LOCKOUT, .F.)
        .AddRow("Account Revoked", loData.ART_ACCOUNT_REVOKED, .F.)
        .AddRow("Notes", L7ParseOnView(loData.ART_NOTES), .F., "Private")
        .AddRow("Created", TRANSFORM(loData.ART_ORIG_TIME) + [ by ] + AisArtistName(loData.ART_Orig_Art_FK), .F., "Private")
        .AddRow("Last Modified", TRANSFORM(loData.ART_REV_TIME) + [ by ] + AisArtistName(loData.ART_Rev_Art_FK), .F., "Private")
      endif
      
      lcRet = lcRet + .Render()
    endwith 
    return m.lcRet
  endfunc && page_getMainRecord

  * ----------------------------------------------------- *  
  function page_getPieceInfo()
    local lcRet, loQ, loTbl, loCol
    lcRet = ''
    lcRet = m.lcRet + HTWrap("Pieces from " + this.cSubTitle, 'h3')
    loQ = createobject("AisPceQuery")
    with loQ
      .cArt = this.cArt
      .Execute()
    endwith 

    urls.add(StuffUrl(this.cUrlA, 2, "PceHome"), "PceHome")
    urls.add(StuffUrl(this.cUrlA, 2, "PceForm"), "PceForm")
    
    select (loQ.cAlias)
    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Pce_ID", "Piece ID", ;
        [HTLink(StuffUrl(urls.item("PceHome"), "pce", Pce_PK), Pce_ID)])
      loCol = .AddCursorColumn('Pce_Whole_Panel', 'Whole Panel?')
      loCol = .AddCursorColumn('Pce_Dim_1', 'Dim 1')
      loCol = .AddCursorColumn('Pce_Dim_2', 'Dim 2')
      loCol = .AddCursorColumn('Pce_Shipped', 'Shipped')
      loCol = .AddCursorColumn('Pce_Received', 'Received')
      loCol = .addCursorColumn("Pce_PK", "Edit Piece", ;
        'HTLink(StuffUrl(urls.item("PceForm"), "pce", Pce_PK), "[Edit Piece...]")')

      lcRet = m.lcRet + .Render()
    endwith 
    
    return m.lcRet
  endfunc && page_getPieceInfo
enddefine && ArtHome

*** ========================================================= ***
define class ais_ArtNew as ais_ArtForm 
  lAdding = .t.
  lArtRequired = .f. 
enddefine 

*** ========================================================= ***
define class ais_ArtForm as aisArtPage 
  lAdding = .f.
  * ----------------------------------------------------- *  
  function ProcessRequest

    this.Assert(poContext.lCore)
    this.cCancelUrl = iif(this.lAdding, StuffURL(THIS.cUrlA, 2, "ArtList"), ;
      StuffURL(THIS.cUrlB, 2, "ArtHome"))

    local loForm, vp_cArt_PK, lcStub
    vp_cArt_PK = IIF(THIS.lAdding, space(32), THIS.cArt)
    use V_Artist in select("V_Artist")
    cursorsetprop("Buffering", 5, "V_Artist")
    loForm = this.createForm('aisArtistForm')
    with loForm
      .lNewRecord = THIS.lAdding
      .AddControls()
      .DoEvents() 

      if .Valid()
        select V_Artist
        if this.lAdding
          append blank
        endif 
        .UpdateControlSources()
        select V_Artist && UpdateControlSources can alter work area
        if Art_Approved and empty(Art_Id)
          lcStub = padr(alltrim(upper(evl(Art_Last_Name, "NLN"))), 5, 'X')
          replace Art_ID with AisAssignID(m.lcStub)
        endif
        if Art_Approved and empty(Art_Id) 
          replace Art_Access_Token with GetGuidString(32)
        endif
        StampRec( CurrentUser, THIS.tNow )
        
        * Now save it using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail
        llSendEmail = .f.  
        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor("V_Artist")

        if loTrans.Save()  
          
          select V_Artist
        
          Response.Redirect(THIS.cCancelUrl)
          return 
        else 
          this.ErrorMsg( "Database Failure Saving Record!", ;
            "Error " + TRANSFORM( loTrans.aFailures[1, 1]) + [ :] + ;
            loTrans.aFailures[1, 2] )
        endif  && Save()
        
      endif && Valid

    endwith 
    response.write(loForm.render())
  endfunc 
enddefine && ais_ArtForm

*** ========================================================= ***
define class aisArtistForm AS AisForm
  cTitle = "Artist Form"
  cEntityAlias = "v_Artist"
  cEntityAbbr  = "Art"
  * --------------------------------------------------------- *
  function AddControls
    with this

      .AddObject("txtId", "L7Textbox")
      with .txtId
        .lDisabled = .T.
        .cGroupID = "PK"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Id"
        .cLabel = "Artist ID"
        .cControlCssStyle = [font-weight: bold; font-size: 16px;]
      endwith
      .AddObject("chkApproved", "L7Checkbox")
      with .chkApproved
        .cGroupID = "PK"
        .cControlSource = "V_artist.Art_Approved"
        .cLabel = "Approved?"
      endwith
      .AddObject("lblPk", "L7Label")
      with .lblPk
        .cGroupID = "PK"
        .cControlSource = "V_artist.Art_Pk"
        .cLabel = "Internal System Key"
        .cCssClass = "FormControlPrivate"
      endwith
      .AddObject("chkInactive", "L7Checkbox")
      with .chkInactive
        .cGroupID = "PK"
        .cControlSource = "V_artist.Art_Inactive"
        .cLabel = "Delete?"
        .lDisabled = !m.poContext.lAdmin
        .cCssClass = "FormControlPrivate"
      endwith

      .addTimeStampControls()

      .AddObject("divContact", "L7Divider")
      with .divContact
        .cLabel = "Name and Contact Information"
      endwith

      .AddObject("txtFirst_Name", "L7Textbox")
      with .txtFirst_Name
        .cGroupID = "name"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_First_Name"
        .cLabel = "First Name"
        .cCssStyle = "width: 20%;"
      endwith
      .AddObject("txtLast_Name", "L7Textbox")
      with .txtLast_Name
        .cGroupID = "name"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Last_Name"
        .cLabel = "Last Name"
        .cCssStyle = "width: 20%;"
      endwith
      .AddObject("chkAnonymous", "L7Checkbox")
      with .chkAnonymous
        .cGroupID = "name"
        .cControlSource = "V_artist.Art_Anonymous"
        .cLabel = "Anonymous?"
        .cCaption = "Anonymous"
      endwith
      .AddObject("chkUnknown", "L7Checkbox")
      with .chkUnknown
        .cGroupID = "name"
        .cControlSource = "V_artist.Art_Unknown"
        .cLabel = "Unknown?"
        .cCaption = "Unknown Person"
      endwith

      .AddObject("txtFull_Name", "L7Textbox")
      with .txtFull_Name
        .cGroupID = "name2"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Full_Name"
        .cLabel = "Alternative Full Name"
        .cInstructions = "(leave blank unless this entry needs to override First/Last name in listings)"
      endwith

      .AddObject("txtEmail", "L7Textbox")
      with .txtEmail
        .cGroupID = "cont"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Email"
        .cLabel = "Email"
        .cCssStyle = "width: 60%;"
        .nSize = 60
      endwith
      .AddObject("txtPhone", "L7Textbox")
      with .txtPhone
        .cGroupID = "cont"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Phone"
        .cLabel = "Phone"
        .cCssStyle = "width: 40%;"
      endwith

      .AddObject("edtName_Orig", "L7Textarea")
      with .edtName_Orig
        .cGroupID = "orig1"
        .cControlSource = "V_artist.Art_Name_Orig"
        .nRows = 2
        .cLabel = "Original Name (e.g., from blog)"
        .cCssClass = "FormControlPrivate"
      endwith
      .AddObject("edtContact_Orig", "L7Textarea")
      with .edtContact_Orig
        .cGroupID = "orig1"
        .cControlSource = "V_artist.Art_Contact_Orig"
        .nRows = 2
        .cLabel = "Original Contact (e.g., from blog)"
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("txtNeighborhood", "L7Textbox")
      with .txtNeighborhood
        .cGroupID  ="addr"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Neighborhood"
        .cLabel = "Neighborhood"
      endwith
      .AddObject("edtAddress", "L7Textarea")
      with .edtAddress
        .cGroupID  ="addr"
        .cControlSource = "V_artist.Art_Address"
        .cLabel = "Address"
        .nRows = 2
        .cLabel = "Original Neighborhood (e.g., from blog)"
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("cboAge_Range", "L7Popup")
      with .cboAge_Range
        .cGroupID  ="addr"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Age_Range"
        .cLabel = "Age Range"
        .nStyle = L7_MULTISTYLE_VERTICAL
        .nRowSourceType = L7_ROWSOURCETYPE_VALUE
        .cRowSource = THISAPP_AGE_RANGES
      endwith

      .AddParticipationControls()
      
      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cGroupID = "notes"
        .cControlSource = "V_artist.Art_Comments"
        .cLabel = "Comments"
        .nRows = 3
      endwith

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cGroupID = "notes"
        .cControlSource = "V_artist.Art_Notes"
        .cLabel = "KtB Internal Notes"
        .nRows = 3
        .cCssClass = "FormControlPrivate"
      endwith

      .addAdditionalControls()
      
      .addSecurityControls()
      
    endwith
  endfunc  && AddControls
      
  * --------------------------------------------------------- *
  function addParticipationControls()
    with this

      .AddObject("divPart", "L7Divider")
      with .divPart
        .cLabel = "Participation Information"
      endwith

      .AddObject("colPart", "L7CheckboxCollection")
      with .colPart
        .cGroupId = "part"
      endwith
      
      .colPart.AddObjectToParent("chkArtist", "L7Checkbox")
      with .chkArtist
        .cControlSource = "V_artist.Art_Artist"
        .cCaption = "Artist"
      endwith

      .colPart.AddObjectToParent("txtPanel_Count", "L7Textbox")
      with .txtPanel_Count
        .cFieldType = "I"
        .cControlSource = "V_artist.Art_Panel_Count"
        .cLabel = "Whole Panel Count"
        .cInstructions = "(whole panel estimate only, if n/a, enter 0)"
      endwith

      .colPart.AddObjectToParent("chkPartial_Panel", "L7Checkbox")
      with .chkPartial_Panel
        .cControlSource = "V_artist.Art_Partial_Panel"
        .cCaption = "Partial Panel"
      endwith
      .colPart.AddObjectToParent("chkTowers", "L7Checkbox")
      with .chkTowers
        .cControlSource = "V_artist.Art_Towers"
        .cCaption = "Towers"
      endwith
      .colPart.AddObjectToParent("chkHelp_Install", "L7Checkbox")
      with .chkHelp_Install
        .cControlSource = "V_artist.Art_Help_Install"
        .cCaption = "Help Install"
      endwith
      .colPart.AddObjectToParent("chkHelp_Materials", "L7Checkbox")
      with .chkHelp_Materials
        .cControlSource = "V_artist.Art_Help_Materials"
        .cCaption = "Help Materials"
      endwith
      .colPart.AddObjectToParent("chkHelp_Meet_Up", "L7Checkbox")
      with .chkHelp_Meet_Up
        .cControlSource = "V_artist.Art_Help_Meet_Up"
        .cCaption = "Help Meet Up"
      endwith
      .colPart.AddObjectToParent("chkHelp_Outreach", "L7Checkbox")
      with .chkHelp_Outreach
        .cControlSource = "V_artist.Art_Help_Outreach"
        .cCaption = "Help Outreach"
      endwith

      .AddObject("edtHelp_Other", "L7Textarea")
      with .edtHelp_Other
        .cGroupId = "part"
        .cControlSource = "V_artist.Art_Help_Other"
        .cLabel = "Help Other"
        .nRows = 3
      endwith
      .AddObject("edtParticipation", "L7Textarea")
      with .edtParticipation
        .cGroupId = "part"
        .cControlSource = "V_artist.Art_Participation"
        .cLabel = "Original Participation answers (e.g., from blog)"
        .nRows = 3
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("edtKtb_Response", "L7Textarea")
      with .edtKtb_Response
        .cControlSource = "V_artist.Art_Ktb_Response"
        .cLabel = "Ktb Response"
        .nRows = 3
      endwith
    endwith
    return 
  endfunc  && addParticipationControls

  * --------------------------------------------------------- *
  function addAdditionalControls()
    with this

      .AddObject("divSS", "L7Divider")
      with .divSS
        .cLabel = "Additional Spreadsheet Columns"
      endwith

      .AddObject("chkReceived", "L7Checkbox")
      with .chkReceived
        .cGroupId = "ss"
        .cControlSource = "V_artist.Art_Received"
        .cLabel = "Received"
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("edtPanel_Info", "L7Textarea")
      with .edtPanel_Info
        .cGroupId = "ss"
        .cControlSource = "V_artist.Art_Panel_Info"
        .cLabel = "Panel Info"
        .nRows = 3
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("edtBit_Info", "L7Textarea")
      with .edtBit_Info
        .cGroupId = "ss"
        .cControlSource = "V_artist.Art_Bit_Info"
        .cLabel = "Bit Info"
        .nRows = 3
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("edtStorage_Location", "L7Textarea")
      with .edtStorage_Location
        .cGroupId = "ss"
        .cControlSource = "V_artist.Art_Storage_Location"
        .cLabel = "Storage Location"
        .nRows = 2
        .cCssClass = "FormControlPrivate"
      endwith
    endwith
    return 
  endfunc  && addAdditionalControls

  * --------------------------------------------------------- *
  function addSecurityControls()
    with this

      .AddObject("divSec", "L7Divider")
      with .divSec
        .cLabel = "Administrative Controls"
      endwith

      .AddObject("colSec", "L7CheckboxCollection")
      with .colSec
        .cGroupId = "sec"
      endwith
      
      .colSec.AddObjectToParent("chkAdmin", "L7Checkbox")
      with .chkAdmin
        .cControlSource = "V_artist.Art_Admin"
        .cCaption = "Admin"
      endwith
      .colSec.AddObjectToParent("chkCore", "L7Checkbox")
      with .chkCore
        .cControlSource = "V_artist.Art_Core"
        .cCaption = "Core"
      endwith
      .colSec.AddObjectToParent("chkAccount_Lockout", "L7Checkbox")
      with .chkAccount_Lockout
        .cControlSource = "V_artist.Art_Account_Lockout"
        .cCaption = "Account Lockout"
      endwith
      .colSec.AddObjectToParent("chkAccount_Revoked", "L7Checkbox")
      with .chkAccount_Revoked
        .cControlSource = "V_artist.Art_Account_Revoked"
        .cCaption = "Account Revoked"
      endwith

      .AddObject("txtAccess_Token", "L7Textbox")
      with .txtAccess_Token
        .cGroupId = "sec"
        .lDISABLED = .t. 
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Access_Token"
        .cLabel = "Access Token"
      endwith
      .AddObject("txtUser_Id", "L7Textbox")
      with .txtUser_Id
        .cGroupId = "sec"
        .lDISABLED = .t. 
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_User_Id"
        .cLabel = "User Id"
      endwith
    endwith
    return 
  endfunc  && addSecurityControls
enddefine  && ArtistForm

*** ===================================================== ***
define class Ais_BrowseUnapproved as AisArtPage
  lArtRequired = .f.
  * --------------------------------------------------------- *
  function ProcessRequest
    this.cCancelUrl = StuffUrl(this.cUrlA, 2, "ArtList")
    local loForm, lcXml, lcAlias, lcFldState, lcStub
    lcAlias = "V_Unapproved_Artist_Set"
    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    select (m.lcAlias)
    loForm = this.CreateForm("AisArtBrowseForm")
    with loForm
      .cAlias = m.lcAlias
      .AddControls()
      .DoEvents()
      if .Valid()
        .UpdateControlSources()
        select (m.lcAlias)
        scan   
          if Art_Approved and empty(Art_Id) 
            lcStub = padr(alltrim(upper(evl(Art_Last_Name, "NLN"))), 5, 'X')
            replace Art_ID with AisAssignID(m.lcStub)
          endif
          if Art_Approved and empty(Art_Id) 
            replace Art_Access_Token with GetGuidString(32)
          endif
          lcFldState = getfldstate(-1)
          if empty( strtran( m.lcFldState, "1"))  && no change
            loop 
          endif 
          StampRec( CurrentUser, THIS.tNow )
        endscan 
        lcXml = ''
        this.AssertTransaction(m.lcAlias, @lcXml)
        *!* this.oApp.NotifyAdmin("Project Multi-File Update by " + CurrentUser.GetUserName(), HTWrap(m.lcXml, 'pre'))
        Response.Redirect(this.cCancelUrl)
        return 
      endif 
      Response.Write(.Render())
    endwith 
    return   
  endfunc 
  
enddefine  && Ais_BrowseUnapproved 

*** ========================================================= ***
define class AisArtBrowseForm AS AisForm
  cTitle = "Artist Form"
  cAlias = null && client should set 
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject('grdBrowse', 'L7Grid')
      with .grdBrowse
        .cChildAlias = this.cAlias
        .cChildKeyExpression = this.cAlias + ".Art_PK"
        .nExtraRows = 0 && don't permit adds 
        .cGridTableCssClass = "sortable " + .cGridTableCssClass
      
        .AddObject("txtFirst_Name", "L7Textbox")
        with .txtFirst_Name
          .cControlSource = this.cAlias + ".Art_First_Name"
          .cLabel = "First Name"
        endwith

        .AddObject("txtLast_Name", "L7Textbox")
        with .txtLast_Name
          .cControlSource = this.cAlias + ".Art_Last_Name"
          .cLabel = "Last Name"
        endwith

        .AddObject("chkApproved", "L7Checkbox")
        with .chkApproved
          .cControlSource = this.cAlias + ".Art_Approved"
          .cLabel = "Approved"
          .cCaption = "Approved"
          .cCssClass = "FormControlPrivate"
        endwith

        .AddObject("edtName_Orig", "L7Textarea")
        with .edtName_Orig
          .cControlSource = this.cAlias + ".Art_Name_Orig"
          .cLabel = "Name Orig (from blog)"
          .nRows = 2
        endwith

        .AddObject("lblID", "L7Label")
        with .lblID
          .cFieldType = "C"
          .cControlSource = this.cAlias + ".Art_ID"
          .cLabel = "ID"
        endwith 

        .AddObject("chkInactive", "L7Checkbox")
        with .chkInactive
          .cGroupID = "PK"
          .cControlSource = this.cAlias + ".Art_Inactive"
          .cLabel = "Delete?"
          .lDisabled = !m.poContext.lAdmin
        endwith
      
      endwith && grid 
    endwith && form
  endfunc  && AddControls
enddefine && AisArtBrowseForm 

*** ===================================================== ***
define class AisArtQuery AS L7Query
  cBaseTable = "Artist"
  cDefaultFieldList = ;
    "Art_PK,Art_ID,Art_Approved,Art_Artist,Art_Anonymous,Art_Unknown" + ;
    ",Art_Full_Name,Art_Last_Name,Art_First_Name,Art_Name_Orig" + ; 
    ",Art_Email,Art_Phone,Art_Contact_Orig,Art_Address,Art_Neighborhood" + ;
    ",Art_Age_Range,Art_Participation,Art_Partial_Panel,Art_Panel_Info,Art_Panel_Count" + ;
    ",Art_Towers,Art_Help_Install,Art_Help_Materials,Art_Help_Meet_Up,Art_Help_Outreach,Art_Help_Other" + ;
    ",Art_Comments,Art_Register_Time,Art_KTB_Response" + ;
    ",Art_Access_Token,Art_User_ID" 

  * Account-based params:
  lUser = NULL
  lAccountInactive = null && surrogate is "approved"

  * Types of people:
  lAdmin = .F.
  lCore = .F.
  lArtist = .F.
  lInstall = .F.
  lTowers = .F.
  lOutreach = .F.


  * Name Search
  cName = ""
  cUser_Id = ""
  cSrch1 = ""

  nOrderBy = 1
  DIMENSION aOrderBy[ 1, 2]
  *aOrderBy[ 1, 1] = "UPPER(Par_Name)"
  aOrderBy[ 1, 1] = "Art_Last_Name"

  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr, lcInnerWhere, loFlags, lnFlag, loFlag, lcField
    store "" to lcInnerWhere

    WITH this 
      .lWhereBuilt = .T.
      .cWhereClause = [WHERE Art_Inactive = .F.] 
      
      if !empty(.cName)
        .cWhereClause = .cWhereClause + [ AND Art_Last_Name LIKE '] + .cName + [']
      endif 

      if !empty(.cSrch1)
        lcStr = lower(.cSrch1)
        .cWhereClause = .cWhereClause + [ AND '] + m.lcStr + [' $ lower(Art_Last_Name + Art_First_Name + Art_User_Id + Art_Email + Art_Access_Token + Art_PK + Art_ID)]
      endif 
      if !empty(.cUser_Id)
        .cWhereClause = .cWhereClause + ;
          [ AND lower(Art_User_Id) = '] + lower(padr(.cUser_ID, THISAPP_LENGTH_USER_ID)) + [']
      endif 

      * People with accounts:
      if !isnull( .lUser)
        .cWhereClause = .cWhereClause + [ AND Art_User_Id ] + IIF(.lUser, [<> ' '], [= ' '])
      endif 
      if !isnull( .lAccountInactive)
        .cWhereClause = .cWhereClause + [ AND Art_Approved = ] + IIF(.lAccountInactive, [.T.], [.F.])
      endif 

*!*        * Build "inner" WHERE clause that is used to control security, etc.
*!*        if !( .lCore or .lArtist OR .lAdmin ;
*!*          or .lInstall or .lTowers or .lOutreach )
*!*          * If none checked, assume no people should be listed.
*!*        else 
*!*          lcInnerWhere = m.lcInnerWhere + ;
*!*            iif( .lCore, [ OR Art_Core = .T.], []) + ;
*!*            iif( .lArtist, [ OR Art_Artist = .T.], []) + ;
*!*            iif( .lAdmin, [ OR Art_Admin = .T.], [])
*!*            iif( .lInstall, [ OR Art_Help_Install = .T.], [])
*!*            iif( .lTowers, [ OR Art_Towers = .T.], [])
*!*            iif( .lOutreach, [ OR Art_Help_Outreach = .T.], [])
*!*        endif 

      loFlags = AisArtQueryFlags()
      for lnFlag = 1 to loFlags.count
        loFlag = loFlags.item[m.lnFlag]
        if evaluate("this.l" + loFlag.root)
          lcField = iif(pemstatus(loFlag, "field", 5), loFlag.field, "Art_" + proper(loFlag.root))
          lcInnerWhere = m.lcInnerWhere + [ or ] + m.lcField + [ = .T.]
        endif
      next 
      
      * Combine inner-WHERE with WHERE clauses:
      if !empty( m.lcInnerWhere) 
        .cWhereClause = .cWhereClause + [ and (] + substr(m.lcInnerWhere, 1 + len([ or ])) + [)]
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisArtQuery


* end 
