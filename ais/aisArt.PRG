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
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lArtRequired
      this.cArt = evl(this.cArt, this.StripUrl("art", .f., .t.))
      if empty(this.cArt)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyArtist()
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyArtist(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cArt)
    loData = createobject("AisArtData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cArt
        this.oArt = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
enddefine 

*** ========================================================= ***
define class ais_ArtList as aisArtPage 
  lArtRequired = .f.
  cPage_Flags = null
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    this.cPage_Flags = this.ReadQueryString("flags", .t., .t.)
    dodefault()  && required bubble-up
    return    
  endfunc  
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local loFlags, lnFlag, loFlag 
    loFlags = this.oArtQueryFlags
    for lnFlag = 1 to loFlags.count
      loFlag = loFlags.item[m.lnFlag]
      if pemstatus(loFlag, "menu", 5) and !loFlag.menu
        loop
      endif
      this.addMenuItem("main\This", proper(loFlag.root), StuffUrl(this.cUrlB, "flags", loFlag.root))
    next 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loFlags, lnFlag, loFlag, lcProp, ;
       loTbl, loCol, loGrp
       
    loQry = createobject("AisArtQuery")
    with loQry
      ** .cSearch = 'gross'

      loFlags = this.oArtQueryFlags
      for lnFlag = 1 to loFlags.count
        loFlag = loFlags.item[m.lnFlag]
        if "," + loFlag.root + "," $ "," + this.cPage_Flags + ","
          lcProp = "l" + loFlag.root
          store .t. to loQry.&lcProp
        endif 
      next 
      
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    loTbl = createobject("AisTable")
    with loTbl
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Art_Last_Name", "Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Art_PK), trim(Art_Last_Name) + ", " + trim(Art_First_Name))])
      loCol = .addCursorColumn("Art_Email", "Email")
      loCol = .addCursorColumn("Art_Phone", "Phone")
      loCol = .addCursorColumn("Art_Register_Time", "Sign-Up Time", [L7TimeDiff(Art_Register_Time)])
      loCol = .addCursorColumn("Art_KTB_Response", "Respose")
      loCol = .addCursorColumn("Art_ID")
      response.write(.render())
    endwith 
    
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_ArtHome as aisArtPage 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.addMenuItem("main\This", "Modify...", StuffUrl(this.cUrlA, 2, "ArtForm", "art", this.cArt))
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    response.write(L7ShowObject(this.oArt))
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_ArtNew as aisArtPage 
  lAdding = .t.
enddefine 

*** ========================================================= ***
define class ais_ArtForm as aisArtPage 
  lAdding = .f.
  * ----------------------------------------------------- *  
  function ProcessRequest

    this.Assert(poContext.lCore)
    this.cCancelUrl = iif(this.lAdding, StuffURL(THIS.cUrlA, 1, "ArtList"), ;
      StuffURL(THIS.cUrlB, 2, "ArtHome"))

    local loForm, vp_cArt_PK
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
        StampRec( CurrentUser, THIS.tNow )
        
        * Now save it using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail
        llSendEmail = .f.  
        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor("V_Artist")

        if loTrans.Save()  
          
          select V_Artist
        
*!*            lcExcMessage = ""
*!*            IF m.llSendEmail
*!*  error "not done..."
*!*              TEXT TO lcMailMessage NOSHOW PRETEXT 3
*!*                System..: OQDB
*!*                Event...: Snippet <<IIF(THIS.lAdding, "Created", "Revised")>> (Snippet <<V_Snippet.Snp_PK>>)
*!*                Actor...: <<CurrentUser.GetUserName()>>
*!*                Snippet.: <<TRIM(V_Snippet.Snp_Title)>>
*!*                URL.....:
*!*                <<THIS.FullUrl(STRTRAN(THIS.cCancelUrl,'&amp;','&'))>>
*!*                
*!*                  (UNPARSED) SNIPPET TEXT
*!*                  -----------------------
*!*                  <<MemoToEmail(V_Snippet.Snp_Text)>>
*!*              ENDTEXT
*!*              TRY
*!*                THIS.oApp.NotifyAdmin("Snippet Record Edited", TEXTMERGE(m.lcMailMessage))
*!*              CATCH TO loExc
*!*                lcExcMessage = TEXTMERGE(' [Error: <<loExc.Message>>, <<loExc.LineNo>>, <<loExc.Procedure>>]')
*!*              ENDTRY
*!*            ENDIF

          Response.Redirect(THIS.cCancelUrl)
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
enddefine && ais_ArtForm

*** ========================================================= ***
define class aisArtistForm AS AisForm
  cTitle = "Artist Form"
  * --------------------------------------------------------- *
  function AddControls
    with this

      .AddObject("txtId", "L7Textbox")
      with .txtId
        .cGroupID = "PK"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Id"
        .cLabel = "Id"
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
        .cLabel = "ID"
      endwith
      .AddObject("chkInactive", "L7Checkbox")
      with .chkInactive
        .cGroupID = "PK"
        .cControlSource = "V_artist.Art_Inactive"
        .cLabel = "Delete?"
        .lDisabled = !m.poContext.lAdmin
      endwith

      .addTimeStampControls()

      .AddObject("txtFull_Name", "L7Textbox")
      with .txtFull_Name
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Full_Name"
        .cLabel = "Full Name"
      endwith
      .AddObject("txtLast_Name", "L7Textbox")
      with .txtLast_Name
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Last_Name"
        .cLabel = "Last Name"
      endwith
      .AddObject("txtFirst_Name", "L7Textbox")
      with .txtFirst_Name
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_First_Name"
        .cLabel = "First Name"
      endwith
      .AddObject("edtName_Orig", "L7Textarea")
      with .edtName_Orig
        .cControlSource = "V_artist.Art_Name_Orig"
        .cLabel = "Name Orig"
        .nRows = 5
      endwith

      .AddObject("chkUnknown", "L7Checkbox")
      with .chkUnknown
        .cControlSource = "V_artist.Art_Unknown"
        .cLabel = "Unknown"
      endwith

      .AddObject("txtEmail", "L7Textbox")
      with .txtEmail
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Email"
        .cLabel = "Email"
      endwith
      .AddObject("txtPhone", "L7Textbox")
      with .txtPhone
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Phone"
        .cLabel = "Phone"
      endwith
      .AddObject("edtContact_Orig", "L7Textarea")
      with .edtContact_Orig
        .cControlSource = "V_artist.Art_Contact_Orig"
        .cLabel = "Contact Orig"
        .nRows = 5
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
        .nRows = 5
      endwith
      .AddObject("txtAge_Range", "L7Textbox")
      with .txtAge_Range
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Age_Range"
        .cLabel = "Age Range"
      endwith

      .AddParticipationControls()
      

      .AddObject("edtBit_Info", "L7Textarea")
      with .edtBit_Info
        .cControlSource = "V_artist.Art_Bit_Info"
        .cLabel = "Bit Info"
        .nRows = 5
      endwith
      .AddObject("edtPanel_Info", "L7Textarea")
      with .edtPanel_Info
        .cControlSource = "V_artist.Art_Panel_Info"
        .cLabel = "Panel Info"
        .nRows = 5
      endwith
      .AddObject("chkReceived", "L7Checkbox")
      with .chkReceived
        .cControlSource = "V_artist.Art_Received"
        .cLabel = "Received"
      endwith
      .AddObject("edtStorage_Location", "L7Textarea")
      with .edtStorage_Location
        .cControlSource = "V_artist.Art_Storage_Location"
        .cLabel = "Storage Location"
        .nRows = 5
      endwith
      .AddObject("edtHelp_Other", "L7Textarea")
      with .edtHelp_Other
        .cControlSource = "V_artist.Art_Help_Other"
        .cLabel = "Help Other"
        .nRows = 5
      endwith
      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cControlSource = "V_artist.Art_Comments"
        .cLabel = "Comments"
        .nRows = 5
      endwith
      .AddObject("edtKtb_Response", "L7Textarea")
      with .edtKtb_Response
        .cControlSource = "V_artist.Art_Ktb_Response"
        .cLabel = "Ktb Response"
        .nRows = 5
      endwith

      .addSecurityControls()
      
      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cControlSource = "V_artist.Art_Notes"
        .cLabel = "Notes"
        .nRows = 5
      endwith
    endwith
  endfunc  && AddControls
      
  * --------------------------------------------------------- *
  function addParticipationControls()
    with this
      .AddObject("colPart", "L7CheckboxCollection")
      with .colPart
        .cGroupId = "part"
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

      .AddObject("edtParticipation", "L7Textarea")
      with .edtParticipation
        .cGroupId = "part"
        .cControlSource = "V_artist.Art_Participation"
        .cLabel = "Participation"
        .nRows = 5
      endwith

    endwith
    return 
  endfunc  && addParticipationControls
  * --------------------------------------------------------- *
  * --------------------------------------------------------- *
  function addSecurityControls()
    with this

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
      .colSec.AddObjectToParent("chkArtist", "L7Checkbox")
      with .chkArtist
        .cControlSource = "V_artist.Art_Artist"
        .cCaption = "Artist"
      endwith
      .colSec.AddObjectToParent("chkAnonymous", "L7Checkbox")
      with .chkAnonymous
        .cControlSource = "V_artist.Art_Anonymous"
        .cCaption = "Anonymous"
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
  * --------------------------------------------------------- *
  function addTimeStampControls()
    with this
      .AddObject("lblOrig_Time", "L7Label")
      with .lblOrig_Time
        .cGroupId = 'created'
        .cControlSource = "V_artist.Art_Orig_Time"
        .cLabel = "Created"
      endwith
      .AddObject("lblOrig_Art_Fk", "L7Label")
      with .lblOrig_Art_Fk
        .cGroupId = 'created'
        .cControlSource = "V_artist.Art_Orig_Art_Fk"
        .cLabel = "Created By"
      endwith
      .AddObject("lblRev_Time", "L7Label")
      with .lblRev_Time
        .cGroupId = 'revised'
        .cControlSource = "V_artist.Art_Rev_Time"
        .cLabel = "Last Revised"
      endwith
      .AddObject("lblRev_Art_Fk", "L7Label")
      with .lblRev_Art_Fk
        .cGroupId = 'revised'
        .cControlSource = "V_artist.Art_Rev_Art_Fk"
        .cLabel = "Revised By"
      endwith
    endwith
    return 
  endfunc  && addTimeStampControls
enddefine  && ArtistForm


*** ===================================================== ***
DEFINE CLASS AisArtQuery AS L7Query
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
  lAccountInactive = null 

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
  cSearch = ""

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

      if !empty(.cSearch)
        lcStr = lower(.cSearch)
        .cWhereClause = .cWhereClause + [ AND '] + m.lcStr + [' $ lower(Art_Last_Name + Art_User_Id + Art_Email + Art_Access_Token + Art_PK)]
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
      ENDIF

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
