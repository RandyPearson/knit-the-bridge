* AisArtPages.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

function AisArtQueryFlags()
  return L7JsonParse( ;
    '[' + ;
    '{"root": "core", "prompt": "Core Team"}' + ;
    ',{"root": "starred", "prompt": "Starred for KtB Follow-Up"}' + ;
    ',{"root": "install", "field": "Art_Help_Install", "prompt": "Help Install"}' + ;
    ',{"root": "deinstall", "field": "Art_Help_Deinstall", "prompt": "Help Deinstall"}' + ;
    ',{"root": "stitching", "field": "Art_Help_Stitching", "prompt": "Help Stitching"}' + ;
    ',{"root": "monitoring", "field": "Art_Help_Monitoring", "prompt": "Help Monitoring"}' + ;
    ',{"root": "outreach", "field": "Art_Help_Outreach"}' + ;
    ',{"root": "organizer", "prompt": "Community Organizer"}' + ;
    ',{"root": "towers", "prompt": "Machine Knit for Towers"}' + ;
    ',{"root": "money", "field": "Art_Help_Money", "prompt": "Donate Money"}' + ;
    ',{"root": "materials", "field": "Art_Help_Materials", "prompt": "Donate Materials"}' + ;
    ',{"root": "inactive", "prompt": "Deleted Artists"}' + ;
    ',{"root": "undeliverable"}' + ;
    ',{"root": "artist"}' + ;
    ',{"root": "admin", "menu": false}' + ;
    ']' )
endfunc 

* --------------------------------------------------------- *
function aisArtistName(tvArt, tlNoAlt)
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
    
  if !m.tlNoAlt and !empty(loData.Art_Full_Name) && alt. name provided
    return trim(loData.Art_Full_Name)
  else
    if empty(loData.Art_Last_Name )
      return trim(loData.Art_ID ) + iif(loData.Art_Anonymous, " (ANONYMOUS)", "")
    else 
      if empty(loData.Art_First_Name )
        return trim(loData.Art_Last_Name )
      else 
        return trim(loData.Art_First_Name ) + [ ] + trim(loData.Art_Last_Name )
      endif 
    endif 
  endif 
  return  
endfunc  && aisArtistName
* --------------------------------------------------------- *
function aisFormatContactInfo(toData)
  local loData, lcRet
  if vartype(m.toData) = 'O'
    loData = m.toData
  else
    scatter memo name loData
  endif
  lcRet = ;
    iif(empty(loData.Art_Email), "", HTEmailLink(trim(loData.Art_Email))) + ;
    iif(loData.Art_Undeliverable, " (UNDELIVERABLE)", "") + ;
    iif(empty(loData.Art_Phone), "", " " + trim(loData.Art_Phone))
  return ltrim(m.lcRet)
endfunc && aisFormatContactInfo
* --------------------------------------------------------- *
function aisFormatParticipation(toData)  
  * returns plain text--suitable for L7ParseOnView() or direct insertion into plain text 
  local loData, lcRet
  if vartype(m.toData) = 'O'
    loData = m.toData
  else
    scatter memo name loData
  endif
  lcRet = ;
    iif(loData.ART_PANEL_COUNT <= 0, "", ;
      iif(loData.ART_PANEL_COUNT = 1, "* Making a Full Panel", ;
      "* making " + transform(loData.ART_PANEL_COUNT) + " full panels") + crlf) + ;
    iif(!loData.ART_PARTIAL_PANEL, "", "* Making Partial Panel(s)" + crlf) + ;
    iif(loData.Art_Railing_1_Count <= 0, "", ;
      "* 9 x 105 Railing pieces: " + transform(loData.Art_Railing_1_Count) + crlf) + ;
    iif(loData.Art_Railing_2_Count <= 0, "", ;
      "* 15 x 80 Railing pieces: " + transform(loData.Art_Railing_2_Count) + crlf) + ;
    iif(loData.Art_Railing_3_Count <= 0, "", ;
      "* 9 x 80 Railing pieces: " + transform(loData.Art_Railing_3_Count) + crlf) + ;
    iif(!loData.ART_TOWERS, "", "* Machine Knitting for Towers" + crlf) + ;
    iif(!loData.ART_HELP_INSTALL, "", "* Helping with *Installation*" + crlf) + ;
    iif(!loData.ART_HELP_DEINSTALL, "", "* Helping with *Deinstallation*" + crlf) + ;
    iif(!loData.ART_HELP_Monitoring, "", "* Helping with *Monitoring*" + crlf) + ;
    iif(!loData.ART_HELP_Stitching, "", "* Helping with *Stitching*" + crlf) + ;
    iif(!loData.ART_HELP_MATERIALS, "", "* Donating Materials" + crlf) + ;
    iif(!loData.ART_HELP_Money, "", "* Donating Money" + crlf) + ;
    iif(!loData.ART_Organizer, "", "* Community Organizer" + crlf) + ;
    iif(!loData.ART_HELP_OUTREACH, "", "* Helping with Outreach" + crlf) + ;
    iif(empty(loData.ART_HELP_OTHER), "", "* " + loData.ART_HELP_OTHER)

  return m.lcRet
endfunc && aisFormatParticipation
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
define class aisMultiArtPage as aisArtPage 
  lArtRequired = .f.
  cPage_Fields = null
  oPage_Fields = null
  cPage_Order = null
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr, lbIdx, lcWord

    this.cPage_Order = this.ReadQueryString("order", .t., .t.)
    this.cPage_Fields = this.ReadQueryString("fields", .t., .t.)
    this.oPage_Fields = createobject("Collection")
    for lnIdx = 1 to getwordcount(this.cPage_Fields, ",")
      lcWord = alltrim(getwordnum(this.cPage_Fields, m.lnIdx, ","))
      if !empty(m.lcWord)
        this.oPage_Fields.add(m.lcWord, m.lcWord)
      endif
    next 
   
    dodefault()  && required bubble-up
    return    
  endfunc  
enddefine 

*** ========================================================= ***
define class ais_ArtList as aisMultiArtPage 
  lCoreRequired = .t.

  lPage_Approved = null
  lPage_Response = null
  lPage_DupName = null
  lPage_DupEmail = null
  cSubTitle = "Artists N'At"
  cPage_Srch1 = null
  
  lPage_OrTypes = .t. 
  add object oPage_flags as collection 
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr, loFlags
    with this
      .cPage_Srch1 = .ReadQueryString("srch1", .t., .t., .t., L7_QS_CHARACTERS + ['])
      .ReadQueryString("btn", .t., .t., .t.) && clear search button from URL

      * Read each flag:
      loFlags = .oArtQueryFlags
      for lnFlag = 1 to loFlags.count
        loFlag = loFlags.item[m.lnFlag]
        lcStr = .ReadQueryString(loFlag.root, .t., .t.)
        if !empty(m.lcStr)
          .oPage_flags.add(left(m.lcStr,1) $ '1yYtT', loFlag.root)
        endif       
      next 
      *!* .cPage_Flags = .ReadQueryString("flags", .t., .t.)

      lcStr = .ReadQueryString("approved", .t., .t.)
      .lPage_Approved = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')

      lcStr = .ReadQueryString("response", .t., .t.)
      .lPage_Response = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')

      lcStr = .ReadQueryString("dupname", .t., .t.)
      .lPage_DupName = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')

      lcStr = .ReadQueryString("dupemail", .t., .t.)
      .lPage_DupEmail = iif(empty(m.lcStr), null, left(m.lcStr,1) $ '1yYtT')
      
      .lPage_OrTypes = !.ReadQueryString("combine", .t., .t.) = "and"
    
    endwith 
    dodefault()  && required bubble-up

    return    
  endfunc  
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local loFlags, lnFlag, loFlag, lcPrompt
    with this
      .AddSubMenu("This", "PEOPLE")

      loFlags = .oArtQueryFlags
      for lnFlag = 1 to loFlags.count
        loFlag = loFlags.item[m.lnFlag]
        if pemstatus(loFlag, "menu", 5) and !loFlag.menu
          loop
        endif
        lcPrompt = iif(pemstatus(m.loFlag, "prompt", 5), m.loFlag.prompt, proper(m.loFlag.root))
        .addMenuItem("main\This", m.lcPrompt, StuffUrl(.cUrlB, loFlag.root, "1", "fields", "names,contact"))
      next 
      if poContext.lAdmin
        *!*          ** .addMenuItem("main\Approvals", "Approved", StuffUrl(.cUrlB, "Approved", "1"),, !isnull(.lPage_Approved) and .lPage_Approved)
        *!*          .addMenuItem("main\This", "Not Approved", StuffUrl(.cUrlB, "Approved", "0", "fields", "registry,contact"),, !isnull(.lPage_Approved) and !.lPage_Approved)
        *!*          .addMenuItem("main\This", "Approved and Not Approved", StuffUrl(.cUrlB, "Approved", .f.),, isnull(.lPage_Approved))

        *!*          .addMenuItem("main\This", "Process Approvals", StuffUrl(.cUrlB, 2, "BrowseUnapproved"))
        *!*          .addMenuItem("main\This", "Response Needed", StuffUrl(.cUrlB, "Response", "0", "fields", "registry,contact,part"),, !isnull(.lPage_Response))
        .addMenuItem("main\This", "New Sign-Up...", StuffUrl(.cUrlA, 2, "ArtNew"))
      endif 
      if poContext.lDeveloper
        .addMenuItem("main\This", "Duplicate Name Check", StuffUrl(.cUrlB, "dupname", "1", "fields", "contact,part"))
        .addMenuItem("main\This", "Duplicate Email Check", StuffUrl(.cUrlB, "dupemail", "1", "fields", "contact,part"))
        .addMenuItem("main\This", "Broadcast Email...", StuffUrl(.cUrlA, 2, "Broadcast"))
      endif 
      .addMenuItem("main\Reports", "Contact Listing", StuffUrl(.cUrlB, "order", "name", "fields", "names,contact"))
      .addMenuItem("main\Reports", "Neighborhood Listing", StuffUrl(.cUrlB, "order", "location", "fields", "contact,location"))
      if poContext.lAdmin
        .addMenuItem("main\Reports", "Age Demographics", StuffUrl(.cUrlA, 2, "AgeSumList"))
      endif 
      .addMenuItem("main\Reports", "Sign-Up Listing", StuffUrl(.cUrlB, "order", "reg_time", "fields", "names,contact,registry"))
            
      * Edit All.. needs to be linked to query conditions
      *!*        if poContext.lAdmin and empty(this.cPage_Srch1) && not a special query
      *!*          .addMenuItem("main\Reports", "Edit All...", StuffUrl(.cUrlB, 2, "ArtBrowse", "order", this.cPage_Order, "fields", this.cPage_Fields))
      *!*        endif       
    endwith
    dodefault()
    return 
  endfunc  && AddDefaultMenu
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loFlags, lnIdx, loItem, lcWord, lcProp, loFields, ;
      loTbl, loCol, loGrp, loRE, loMtchs, loMtch, lcEnt, loPceQ
    
    * do this late so url has been processed
    if !empty(this.cPage_Srch1)
      loRE = createobject("L7RegExp")
      loRE.pattern = '^(pnl|pce)(\d{1,5})$'
      loMtchs = loRE.execute(this.cPage_Srch1)
      if loMtchs.count = 1
        loMtch = loMtchs.item(1) 
        lcEnt = loMtch.submatches[1]
        this.redirect(stuffUrl(this.cUrlA, 2, m.lcEnt + "home", m.lcEnt, m.lcEnt + padl(loMtch.submatches[2], 5, "0")))
      endif
    endif
    
    loQry = createobject("AisArtQuery")
    with loQry
      .lOrTypes = this.lPage_OrTypes  && use AND instead of OR
      
      for lnIdx = 1 to this.oPage_flags.count 
        lcProp = "l" + this.oPage_flags.getkey(m.lnIdx)
        store this.oPage_flags.item(m.lnIdx) to loQry.&lcProp
      next
      
      .lKtbResponse = this.lPage_Response
      .lAccountInactive = this.lPage_Approved
      .cSrch1 = this.cPage_Srch1
      
      if this.oPage_Fields.getkey("location") > 0
        .addFields("Art_Neighborhood, Art_Address")
      endif 
      if this.oPage_Fields.getkey("part") > 0
        .addParticipationFields()
      endif 
      if this.oPage_Fields.getkey("registry") > 0
        .addFields("Art_Register_Time, Art_KTB_Response, Art_Participation, Art_Comments, Art_Notes")
      endif 
      if this.oPage_Fields.getkey("contact") > 0
        .addFields("Art_Email, Art_Phone, Art_Neighborhood, Art_Contact_Orig, Art_Comments, Art_Notes")
      endif 
      
      do case
      case !isnull(this.lPage_DupName)
        .lDupName = this.lPage_DupName
        .lNLN = .f. 
        .AddOrderBy("Art_Last_Name")
        .AddOrderBy("Art_First_Name", , .t.)
      case !isnull(this.lPage_DupEmail)
        .lDupEmail = this.lPage_DupEmail
        .AddOrderBy("Art_Email")
        .AddOrderBy("Art_Last_Name", , .t.)
        .AddOrderBy("Art_First_Name", , .t.)
      case this.cPage_Order = "location"
        .AddOrderBy("Art_Neighborhood")
      case this.cPage_Order = "reg_time"
        .AddOrderBy("Art_Register_Time")
      otherwise
        .AddOrderBy("Art_Last_Name")
      endcase
      
      .execute()
    endwith 

    loPceQ = createobject("AisPceQuery")
    with loPceQ
      .addOrderBy('Pce_Art_FK')
      .nGrouping = 1
      .clearFields()
      .addFields('Pce_Art_FK, count(*) as PieceCount')
      .execute()
      index on Pce_Art_Fk tag Art
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    urls.add(StuffUrl(this.cUrlA, 2, "ArtForm"), "ArtForm")

    select (loQry.cAlias)
    loTbl = createobject("AisTable")
    with loTbl
      do case
      case this.cPage_Order = "location"
        loGrp = .AddGroup("Art_Neighborhood",,.t.,["Neighborhood: " + trim(Art_Neighborhood)])
      otherwise
      endcase
      
      .cDataRowClass = .cDataRowClass + iif(empty(.cDataRowClass), [], [ + ]) + [iif(Art_Inactive, " deleted", "")]

      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Art_ID", "Artist ID", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Art_PK), Art_ID)], "id-field artist")

      loCol = .AddCursorColumn("Art_PK", 'Work', ;
        [iif(seek(Art_PK, '] + loPceQ.cAlias + [', 'Art'), ] + loPceQ.cAlias + [.PieceCount, 0)], , ,"N")
      
      if !isnull(this.lPage_DupName) or !isnull(this.lPage_DupEmail) && when dupe checking, be explicit
        loCol = .addCursorColumn("Art_First_Name", "First Name")
        loCol = .addCursorColumn("Art_Last_Name", "Last Name")
        loCol = .addCursorColumn("Art_Full_Name", "Alt Name")
        loCol = .addCursorColumn("Art_Group_Art_FK", "In Group?", [iif(empty(Art_Group_Art_FK),"","in group")])
      else && otherwise use standard name transform:
        loCol = .addCursorColumn("Art_Last_Name", "Name", ;
          [HTLink(StuffUrl(urls.item("ArtHome"), "art", Art_PK), aisArtistName(THISRECORD))])
      endif
      
      if this.oPage_Fields.getkey("contact") > 0
        loCol = .addCursorColumn("Art_Email", "Email/Phone", [aisFormatContactInfo(THISRECORD)])
      endif 

      if this.oPage_Fields.getkey("location") > 0 or this.oPage_Fields.getkey("contact") > 0
        loCol = .addCursorColumn("Art_Neighborhood", "Neighborhood")
      endif 

      if this.oPage_Fields.getkey("location") > 0
        loCol = .addCursorColumn("Art_Address", "Address")
      endif 

      if this.oPage_Fields.getkey("part") > 0
        loCol = .addCursorColumn("Art_Help_Other", "Participation", [L7ParseOnView(aisFormatParticipation(THISRECORD))])
      endif

      if this.oPage_Fields.getkey("registry") > 0
        loCol = .addCursorColumn("Art_Participation", "Participation (original from blog)")
        loCol = .addCursorColumn("Art_Register_Time", "Sign-Up Time", [ttoc(Art_Register_Time,3) + "<br>" + L7TimeDiff(Art_Register_Time)])
        loCol = .addCursorColumn("Art_KTB_Response", "Response")
      endif

      if poContext.lAdmin
        if this.oPage_Fields.getkey("registry") > 0 or this.oPage_Fields.getkey("contact") > 0
          loCol = .addCursorColumn("Art_Comments", "Comments")
          loCol = .addCursorColumn("Art_Notes", "KtB Notes")
        endif

        loCol = .addCursorColumn("Art_PK", "Edit Artist", ;
          'HTLink(StuffUrl(urls.item("ArtForm"), "art", Art_PK), "[Edit&nbsp;Artist...]")', 'no-print')
        loCol.cHeadingClass = "nosort no-print" 
      endif 
      response.write(.render())

      if poContext.lDeveloper
        Response.Write(HTWrap(loQry.cSqlStatement, 'div,p', 'admin,debug'))
      endif
    endwith 
    return 
  endfunc && ProcessRequest
enddefine && ais_ArtList 

*** ===================================================== ***
define class Ais_ArtBrowse as aisMultiArtPage 
  lAdminRequired = .t. 
  * --------------------------------------------------------- *
  function ProcessRequest
    this.cCancelUrl = StuffUrl(this.cUrlC, 2, "ArtList") && xfer order/fields back to ArtList, which supports same API
    local loForm, lcXml, lcAlias, lcFldState, lcStub
    lcAlias = icase( ;
      this.cPage_order == "location", "V_Artists_by_Location", ;
      this.cPage_order == "reg_time", "V_Artists_by_Reg_Time", ;
      "V_Artists_by_Name")
    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    select (m.lcAlias)
    loForm = this.CreateForm("AisArtBrowseForm", this.cUrlC)
    with loForm
      .lCustom_Location = this.oPage_Fields.getkey("location") > 0
      .lCustom_Names = this.oPage_Fields.getkey("names") > 0 
      .lCustom_Registry = this.oPage_Fields.getkey("registry") > 0
      .lCustom_Contact = this.oPage_Fields.getkey("contact") > 0
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
        Response.Redirect(this.cCancelUrl)
        return 
      endif 
      Response.Write(.Render())
    endwith 
    return   
  endfunc 
  
enddefine  && Ais_ArtBrowse 

*** ========================================================= ***
define class ais_NeighborhoodSumList as aisArtPage 
  lArtRequired = .f.
  cSubTitle = "Neighborhood Summary Report"
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisArtQuery")
    with loQry
      .lOldEngineBehavior = .t. 
      .lNoCount = .f. && exclude non-person "group" entries 
      .AddOrderBy("Art_Neighborhood",, .f.)
      .nGrouping = 1
      .ClearFields()
      .AddFields("Art_Neighborhood, count(*) as Count_")
      .execute()
    endwith 
    
    loTbl = createobject("AisTable")
    with loTbl
      .cTableCaption = this.cSubTitle 
      .cGrandRowClass      = "GrandRow sortbottom"  
      
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Art_Neighborhood", "Neighborhood")
      loCol = .addCursorColumn("Count_", "Count")
      loCol.nCalcType = L7_CALCTYPE_SUM
      
      response.write(.render())
    endwith 
    return 
  endfunc 
enddefine && ais_NeighborhoodSumList 

*** ========================================================= ***
define class ais_AgeSumList as aisArtPage 
  lArtRequired = .f.
  cSubTitle = "Age Demographics Report"
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisArtQuery")
    with loQry
      .lOldEngineBehavior = .t. 
      .lNoCount = .f. && exclude non-person "group" entries 
      .AddOrderBy("Art_Age_Range",, .f.)
      .nGrouping = 1
      .ClearFields()
      .AddFields("Art_Age_Range, count(*) as Count_")
      .execute()
    endwith 
    
    loTbl = createobject("AisTable")
    with loTbl
      .cTableCaption = this.cSubTitle 
      .cGrandRowClass      = "GrandRow sortbottom"  
      
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
      loCol = .addCursorColumn("Art_Age_Range", "Age Range")
      loCol = .addCursorColumn("Count_", "Count")
      loCol.nCalcType = L7_CALCTYPE_SUM
      
      response.write(.render())
    endwith 
    return 
  endfunc 
enddefine && ais_AgeSumList 

*** ========================================================= ***
define class ais_ArtHome as aisArtPage 
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    this.AddSubMenu("This", AisArtistName(this.oArt))

    this.addMenuItem("main\This,page", "Edit This Person...", StuffUrl(this.cUrlA, 2, "ArtForm", "art", this.cArt))
    if this.oArt.Art_Artist
      this.addMenuItem("main\This,page", "Submit WHOLE PANEL Piece...", ;
        StuffUrl(this.cUrlA, 2, "PceNew", "art", this.cArt, "type", "Panels", "dim_1", "34", "dim_2", "72", "whole", "1"))
      this.addMenuItem("main\This,page", "Submit Partial Panel Piece...", ;
        StuffUrl(this.cUrlA, 2, "PceNew", "art", this.cArt, "type", "Panels", "dim_1", "17", "dim_2", "17"))

      this.addMenuItem("main\This,page", "Submit 15x80 Railing Piece...", ;
        StuffUrl(this.cUrlA, 2, "PceNew", "art", this.cArt, "type", "Railings", "dim_1", "15", "dim_2", "80"))
      this.addMenuItem("main\This,page", "Submit 9x105 Railing Piece...", ;
        StuffUrl(this.cUrlA, 2, "PceNew", "art", this.cArt, "type", "Railings", "dim_1", "9", "dim_2", "105"))
      this.addMenuItem("main\This,page", "Submit 9x80 Railing Piece...", ;
        StuffUrl(this.cUrlA, 2, "PceNew", "art", this.cArt, "type", "Railings", "dim_1", "9", "dim_2", "80"))
    endif   
    if poContext.lAdmin and !empty(this.oArt.Art_ID)
      this.addMenuItem("main\This", "Set Password...", StuffUrl(this.cUrlA, 2, "SetPassword", "art", this.cArt))
    endif 

    if poContext.lDeveloper and !empty(this.oArt.Art_ID)
      this.addMenuItem("main\This", "Re-Assign ID...", StuffUrl(this.cUrlA, 2, "ReassignID", "art", this.cArt))
    endif 

    if poContext.lAdmin and empty(this.oArt.Art_Group_Art_FK)
      this.addMenuItem("main\This", "Add Contributing Artist...", StuffUrl(this.cUrlA, 2, "AddContributor", "art", this.cArt))
    endif 
    if poContext.lAdmin 
      this.addMenuItem("main\This", "Add Donation from Artist...", StuffUrl(this.cUrlA, 2, "DonNew", "art", this.cArt))
    endif 

    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cSubTitle = AisArtistName(this.oArt) + ;
      iif(this.oArt.Art_Approved, ", ID: " + HTWrap(this.oArt.Art_ID, 'span',, 'id-field artist'), ", No ID (still not approved)")
    
    response.write(this.page_getMainRecord())
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_getMainRecord()
    local loElem, loRow, lcRet, loData, lcStr, llDeleted
    lcRet = ""
    loData = this.oArt
    llDeleted = loData.Art_Inactive 
    loElem = createobject("aisRecordElement")
    with loElem
      loRow = .getRowObject()
      .cCaption = AisArtistName(m.loData) + " Data"
      if m.llDeleted
        .cCssClass = .cCssClass + " deleted"
        .cCaption = .cCaption + " [DELETED]"
      endif
      .AddHeading('Key Information')
      
      loRow.clear()
      loRow.cLabel = "Artist ID"
      loRow.vValue = HTWrap(loData.Art_ID, 'span',, "id-field panel" )
      if poContext.lAdmin
        loRow.Links.add(HTLink(StuffUrl(This.cUrlB, 2, "ArtForm", "art", this.cArt), "Edit This Person..."))
      endif
      .AddRowEx(m.loRow)

      .AddRow("Approved", loData.ART_APPROVED)

      .AddRow("Name", AisArtistName(m.loData, .t.))
      .AddRow("Alternative Full Name", TRIM(loData.ART_FULL_NAME), .t.)
      .AddRow("Name Release", iif(loData.ART_Release_NAME, "OK to Release Name", "DO NOT Release Name"))
      if loData.ART_Anonymous
        .AddRow("Anonymous", "ANONYMOUS", .F., "private")
      endif 
      .AddRow("Original Name (from blog)", loData.ART_NAME_ORIG, .t., "private")

      .AddRow("Email", HTEmailLink(TRIM(loData.ART_EMAIL) + iif(loData.Art_Undeliverable, " (UNDELIVERABLE)", ""), .f., .f., .f., .t.))
      .AddRow("Phone", TRIM(loData.ART_PHONE), .t.)
      .AddRow("Original Contact (from blog)", loData.ART_CONTACT_ORIG, .t., "private")
      .AddRow("Address (from blog)", L7ParseOnView(loData.ART_ADDRESS), .t., "private")
      
      if loData.Art_No_Count
        .AddRow("Grouping", iif(loData.Art_No_Count, "GROUP ONLY", ""), .t., "private")
      else
        .AddRow("Neighborhood", TRIM(loData.ART_NEIGHBORHOOD), .F.)
        .AddRow("Age Range", TRIM(loData.ART_AGE_RANGE))
      endif 

      lcStr = this.page_getContributors()
      if !empty(m.lcStr)
        .AddHeading('Contributing Artists')
        .AddRow(null, m.lcStr)
      endif   
      * part
      if !empty(m.loData.Art_Group_Art_FK)
        .AddRow("Group", HTLink(StuffUrl(this.cUrlA, "art", m.loData.Art_Group_Art_FK), aisArtistName(m.loData.Art_Group_Art_FK)))
      endif 

      if this.oArt.Art_Artist
        .AddHeading('Submitted Work and WIP')
        .AddRow(null, this.page_getPieceInfo())
      endif

      .AddHeading('Participation')
      .AddRow("Artist?", loData.ART_ARTIST)
      .AddRow("Participation", L7ParseOnView(aisFormatParticipation(loData)), .t.)
      
      .AddRow("Participation (from blog)", L7ParseOnView(loData.ART_PARTICIPATION), .t., "private")

      lcStr = this.page_getDonations()
      if !empty(m.lcStr)
        .AddHeading('Donations')
        .AddRow(null, m.lcStr)
      endif   

      .AddRow("Description and Comments", L7ParseOnView(loData.ART_COMMENTS))
      .AddRow("Register Time", loData.ART_REGISTER_TIME, .F.)
      .AddRow("Ktb Response", L7ParseOnView(loData.ART_KTB_RESPONSE))
      if poContext.lCore
        .AddRow("Internal KtB Notes", L7ParseOnView(loData.ART_NOTES), .t., "private")
      endif
      
      * Training Info:
      if loData.Art_Help_Install or loData.Art_Help_DeInstall or !empty(loData.Art_Installation_Trn_FK)
        .AddHeading('Training')
        .AddRow("Training Session", ;
           HTLink(StuffUrl(this.cUrlA, 2, "TrnHome", "trn", loData.Art_Installation_Trn_FK), AisTrainingName(loData.Art_Installation_Trn_FK)))

        .AddRow("Signed Waiver?", loData.Art_Waiver_Signed)
        .AddRow("Signed for Training?", loData.Art_Training_Signed)
      endif

      * Historical google doc tracking: 
      if !empty(loData.ART_PANEL_INFO) or !empty(loData.ART_BIT_INFO) or !empty(loData.ART_RECEIVED) or !empty(loData.ART_STORAGE_LOCATION)
        .AddHeading('Other Historical Info (from Google doc)')
        .AddRow("Panel Info", L7ParseOnView(loData.ART_PANEL_INFO), .t., "private")
        .AddRow("Bit Info", L7ParseOnView(loData.ART_BIT_INFO), .t., "private")
        .AddRow("Received", loData.ART_RECEIVED, .t., "private")
        .AddRow("Storage Location", L7ParseOnView(loData.ART_STORAGE_LOCATION), .t., "private")
      endif 
      
      if poContext.lAdmin
        .AddHeading('Administrative Information')
        .AddRow("Pk", TRIM(loData.ART_PK), .F., "private")
        .AddRow("Admin", loData.ART_ADMIN, .F., "admin")
        .AddRow("Core", loData.ART_CORE, .F.)
        .AddRow("Unknown", loData.ART_Unknown, .F., "private")
        .AddRow("DELETED", loData.ART_INACTIVE, .F., "private")
        .AddRow("Access Token", TRIM(loData.ART_ACCESS_TOKEN), .F., "private")
        .AddRow("Password Count", loData.ART_PASSWORD_COUNT, .F., "admin")
        .AddRow("Password Time", loData.ART_PASSWORD_TIME, .F., "admin")
        .AddRow("Password Expiry Time", loData.ART_PASSWORD_EXPIRY_TIME, .F., "admin")
        .AddRow("Account Lockout", loData.ART_ACCOUNT_LOCKOUT, .F., "admin")
        .AddRow("Account Revoked", loData.ART_ACCOUNT_REVOKED, .F., "admin")
        .AddRow("Created", TRANSFORM(loData.ART_ORIG_TIME) + [ by ] + AisArtistName(loData.ART_Orig_Art_FK), .F., "private")
        .AddRow("Last Modified", TRANSFORM(loData.ART_REV_TIME) + [ by ] + AisArtistName(loData.ART_Rev_Art_FK), .F., "private")
      endif
      
      lcRet = lcRet + .Render()
    endwith 
    return m.lcRet
  endfunc && page_getMainRecord

  * ----------------------------------------------------- *  
  function page_getPieceInfo()
    local lcRet, loQ, loTbl, loCol
    lcRet = ''
    ** lcRet = m.lcRet + HTWrap("Pieces from " + this.cSubTitle, 'h3')
    loQ = createobject("AisPceQuery")
    with loQ
      .cArt = this.cArt
      .lJoinFacility = .t.
      .lJoinPanel = .t. 
      if poContext.lAdmin
        .lInactive = null 
        .lExcluded = null
      endif
      .Execute()
    endwith 
    if loQ.nTally = 0
      lcRet = lcRet + HTWrap("No pieces yet submitted.", 'p')
    else
      urls.add(StuffUrl(this.cUrlA, 2, "PceHome"), "PceHome")
      urls.add(StuffUrl(this.cUrlA, 2, "PceForm"), "PceForm")
      urls.add(StuffUrl(this.cUrlA, 2, "FacHome"), "FacHome")
      urls.add(StuffUrl(this.cUrlA, 2, "PnlHome"), "PnlHome")
      urls.add(StuffUrl(this.cUrlA, 2, "PnlFilNew", "return", this.cUrlC), "PnlFilNew")
      
      select (loQ.cAlias)
      loTbl = createobject("AisTable")
      with loTbl
        .cDataRowClass = .cDataRowClass + ;
          iif(empty(.cDataRowClass), [], [ + ]) + [iif(Pce_Inactive, " deleted", "") + iif(Pce_Excluded, " excluded", "")] 
        
        loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
        loCol = .addCursorColumn("Pce_ID", "Piece ID", ;
          [HTLink(StuffUrl(urls.item("PceHome"), "pce", Pce_PK), Pce_ID)], "id-field piece")
        loCol = .addCursorColumn("Pce_Type", "Type")
        loCol = .addCursorColumn("Pnl_Id", "Panel", ;
          [HTLink(StuffUrl(urls.item("PnlHome"), "pnl", Pce_Pnl_FK), AisFormatID(Pnl_ID))], "id-field panel")

        loCol = .AddCursorColumn('Pce_Whole_Panel', 'Whole Panel?')
        loCol = .AddCursorColumn('Pce_Dim_1', 'Dim 1')
        loCol = .AddCursorColumn('Pce_Dim_2', 'Dim 2')
        loCol = .addCursorColumn("Pce_Comments", "Comments")
        loCol = .AddCursorColumn('Pce_Shipped', 'Shipped')
        loCol = .AddCursorColumn('Pce_Received', 'Received')

        loCol = .addCursorColumn("Fac_Name", "Current Storage Facility", ;  
          [iif(empty(Pce_Pnl_FK), ] + ;
          [HTLink(StuffUrl(urls.item('FacHome'), 'fac', Pce_Fac_FK), AisFacilityName(Pce_Fac_FK), "go to facility", "facility")] + [, ] + ;
          ["(panel) " + HTLink(StuffUrl(urls.item('FacHome'), 'fac', Pnl_Fac_FK), AisFacilityName(Pnl_Fac_FK), "go to facility", "facility")] + ;
          [)])

        loCol = .addCursorColumn('Pce_Pnl_FK', "Bridge<br>Location", ;
          [aisFormatPanelLocation(Pce_Pnl_FK)])
        loCol = .addCursorColumn("Pnl_ID", "Image", ;
          [AisPanelImage(Pnl_Id, "_h25", urls.item("PnlFilNew"), Pce_Pnl_FK, poContext.lAdmin)])
        
        if poContext.lAdmin
          loCol = .addCursorColumn("Pce_Notes", "Notes",, "private")
          *!*            loCol = .addCursorColumn("Pce_PK", "Edit Piece", ;
          *!*              'HTLink(StuffUrl(urls.item("PceForm"), "pce", Pce_PK), "[Edit&nbsp;Piece...]")')
        endif
        
        lcRet = m.lcRet + .Render()
      endwith 
    endif 
    
    return m.lcRet
  endfunc && page_getPieceInfo
  * ----------------------------------------------------- *  
  function page_getContributors()
    local lcRet, loQ, loTbl, loCol
    lcRet = ''
    loQ = createobject("AisArtQuery")
    with loQ
      .cGroupArt = this.cArt
      .Execute()
    endwith 
    if loQ.nTally = 0
    else
      urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
      
      select (loQ.cAlias)
      loTbl = createobject("AisTable")
      with loTbl
        loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")
        loCol = .addCursorColumn("Art_ID", "Artist ID", ;
          [HTLink(StuffUrl(urls.item("ArtHome"), "art", Art_PK), Art_ID)], "id-field piece")

        loCol = .addCursorColumn("Art_Last_Name", "Name", ;
          [HTLink(StuffUrl(urls.item("ArtHome"), "art", Art_PK), aisArtistName(THISRECORD))])

        loCol = .addCursorColumn("Art_Neighborhood", "Neighborhood")
        loCol = .addCursorColumn("Art_Age_Range", "Age Range")

        lcRet = m.lcRet + .Render()
      endwith 
    endif 
    
    return m.lcRet
  endfunc && page_getContributors

  * ----------------------------------------------------- *  
  function page_getDonations()
    local lcRet, loQ, loTbl, loCol
    lcRet = ''
    loQ = createobject("AisDonQuery")
    with loQ
      .cArt = this.cArt
      .Execute()
    endwith 
    if loQ.nTally = 0
    else
      urls.add(StuffUrl(this.cUrlA, 2, "DonHome"), "DonHome")
      
      select (loQ.cAlias)
      loTbl = createobject("AisTable")
      with loTbl
        .cDataRowClass = .cDataRowClass + iif(empty(.cDataRowClass), [], [ + ]) + [iif(Don_Inactive, " deleted", "")]

        loCol = .addCursorColumn("Don_How_Donated", "How Donated")
        loCol = .addCursorColumn("Don_Date_Donated", "Date Donated")
        loCol = .addCursorColumn("Don_Cash_Amount", "Cash Amount")
        loCol = .addCursorColumn("Don_In_Kind_Amount", "In-Kind Value")
        loCol = .addCursorColumn("Don_Comments", "Comments")
        loCol = .addCursorColumn("Don_Received", "Received?")
        loCol = .addCursorColumn("Don_Acknowledged", "Acknowledged?")
        loCol = .addCursorColumn("Don_Date_Acknowledged", "Date Acknowledged")
        loCol = .addCursorColumn("Don_Acknowledge_Ref", "Acknowledge Ref")

        if poContext.lAdmin
          loCol = .addCursorColumn("Don_Notes", "Notes",, "private")
          loCol = .addCursorColumn("Don_PK", "Donation Entry", ;
            'HTLink(StuffUrl(urls.item("DonHome"), "don", Don_PK), "[Donation Details...]")', 'no-print')
          loCol.cHeadingClass = "nosort no-print" 
        endif 

        lcRet = m.lcRet + .Render()
      endwith 
    endif 
    
    return m.lcRet
  endfunc && page_getDonations
enddefine && ArtHome

*** ========================================================= ***
define class ais_AddContributor as ais_ArtForm
  lAdding = .t.
  lArtRequired = .t.
  cPage_FormClass = "aisContributorForm"
  * ----------------------------------------------------- *  
  function page_setAdditionalFields(toForm)
    replace ;
      Art_Group_Art_FK with this.cArt ;
      Art_Artist with .t. 
    return 
  endfunc 
enddefine 

*** ========================================================= ***
define class ais_ArtNew as ais_ArtForm 
  lAdding = .t.
  lArtRequired = .f. 
  cPage_FormClass = "aisRegisterForm"
enddefine 

*** ========================================================= ***
define class ais_ArtForm as aisArtPage 
  lAdding = .f.
  lAdminRequired = .t.
  cPage_FormClass = "aisArtistForm"
  * ----------------------------------------------------- *  
  function page_setAdditionalFields(toForm)
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest

    this.Assert(poContext.lAdmin)
    this.cCancelUrl = iif(this.lAdding, StuffURL(THIS.cUrlA, 2, "ArtList"), ;
      StuffURL(THIS.cUrlB, 2, "ArtHome"))

    local loForm, vp_cArt_PK, lcStub
    vp_cArt_PK = IIF(THIS.lAdding, space(32), THIS.cArt)
    use V_Artist in select("V_Artist")
    this.assert(!V_Artist.Art_Developer or poContext.lDeveloper, "Cannot edit developer record.")
    
    cursorsetprop("Buffering", 5, "V_Artist")
    loForm = this.createForm(this.cPage_FormClass)
    with loForm
      .lNewRecord = THIS.lAdding
      .AddControls()
      .DoEvents() 

      if .Valid()
        select V_Artist
        if this.lAdding
          append blank
          replace Art_Artist with .f. && compensate for default .T. in structure...
          replace Art_Register_Time with this.tNow
          if poContext.lAdmin
            replace Art_Approved with .t. && if admin is adding, approve immediately
          endif
        endif 
        this.page_setAdditionalFields(m.loForm)
        .UpdateControlSources()
        select V_Artist && UpdateControlSources can alter work area
        * flag as Artist if making anything: 
        if !Art_Artist and (Art_Partial_Panel = .t. or Art_Panel_Count > 0 or Art_Railing_1_Count > 0 or Art_Railing_2_Count > 0 or Art_Railing_3_Count > 0)
          replace Art_Artist with .t.
        endif 
        * assign IDs and access tokens to approved people: 
        if Art_Approved and empty(Art_Id)
          lcStub = padr(alltrim(upper(evl(Art_Last_Name, "NLN"))), 5, 'X')
          replace Art_ID with AisAssignID(m.lcStub)
        endif
        if Art_Approved and empty(Art_Access_Token) 
          replace Art_Access_Token with GetGuidString(32)
        endif
        * default neighborhood to address: 
        if empty(Art_Neighborhood) and !empty(Art_Address)
          replace Art_Neighborhood with Art_Address
        endif 
        StampRec( CurrentUser, THIS.tNow )
        
        * Now save it using a transaction:
        local loTrans, loExc, lcMailMessage, lcExcMessage, llSendEmail, loNewRec
        llSendEmail = .f.  
        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor("V_Artist")

        if loTrans.Save()  
          select V_Artist
          if this.lAdding
            scatter memo name loNewRec
            if poContext.lAnonymous
              this.cCancelUrl = StuffURL(THIS.cUrlA, 2, "ThankYou")
            else
              if !empty(V_Artist.Art_Group_Art_FK)
                this.cCancelUrl = StuffURL(THIS.cUrlA, 2, "ArtHome", "art", V_Artist.Art_Group_Art_FK)
              else
                this.cCancelUrl = StuffURL(THIS.cUrlA, 2, "ArtHome", "art", V_Artist.Art_PK)
              endif 
            endif 
            if .chkAlert.vNewValue
              this.page_onNewArtist(m.loNewRec)
            endif
          endif
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
    return 
  endfunc && ProcessRequest
  * ----------------------------------------------------- *  
  function page_onNewArtist(loRec)
    local loExc, lcMailMessage, lcName, lcSubject, lcUrl, lcExcMessage
    if !empty(loRec.Art_Group_Art_FK)
      return  && no alerts for contributing artist additions 
    endif 
    try 
      * lcName = textmerge([<<TRIM(loRec.Art_First_Name)>> <<TRIM(loRec.Art_Last_Name)>>])
      lcName = aisArtistName(m.loRec)
      
      text to lcMailMessage noshow pretext 3
        Event........: Person Created by <<CurrentUser.getUserName()>>
        Entry Time...: <<datetime()>> GMT
        Name.........: <<m.lcName>>
        Artist ID....: <<loRec.Art_ID>> 
        Email........: <<trim(loRec.Art_Email)>> <<trim(loRec.Art_Phone)>>
        Neighborhood.: <<trim(loRec.Art_Neighborhood)>> 
        Participation: 
        <<aisFormatParticipation(m.loRec)>> 
        
        URL.........: 
        <<this.FullUrl(strtran(StuffUrl(this.cUrlA,2,'ArtHome','art',loRec.Art_PK),'&amp;','&'))>>
        
        Comments....:
        <<MemoToEmail(loRec.Art_Comments)>>
      endtext

      lcExcMessage = ""
      lcSubject = textmerge([New Person Added: <<m.lcName>> (ID: <<loRec.Art_ID>>)])
      lcMailMessage = textmerge(m.lcMailMessage)
      * Send the Email:
      this.oApp.QueueMessage( ;
        Config.cAdminEmail, ;
        m.lcSubject, ;
        m.lcMailMessage, ;
        "KtB Notification Service", ;
        Config.cAdminEmail, ;
        Config.cActionEmail, ;  && 
        "", ;
        "", "text/plain", .F.)
      
    CATCH TO loExc
      lcExcMessage = TEXTMERGE(' [Error: <<loExc.Message>>, <<loExc.LineNo>>, <<loExc.Procedure>>]')
    endtry
    if !empty(m.lcExcMessage)
      this.App_Log(L7_SEVERITY_WARNING, m.lcExcMessage) && impossible?
    endif
    return 
    
  endfunc 
enddefine && ais_ArtForm

*** ========================================================= ***
define class aisArtistForms AS AisForm
  cEntityAlias = "v_Artist"
  cEntityAbbr  = "Art"
  * --------------------------------------------------------- *
  function addTrainingControls()
    with this
      .AddObject("divTrn", "L7Divider")
      with .divTrn
        .cLabel = "Training Information"
      endwith

      .AddObject("cboTrn_FK", "L7Popup")
      with .cboTrn_FK
        .cControlSource = "V_artist.Art_Installation_Trn_FK"
        .lRequired = .f.
        .cLabel = "Training Session"
        .lAutoRender = .t.
        .nRowSourceType = L7_ROWSOURCETYPE_ALIAS
        .cRowSource = goL7App.cTrnAlias  
        *!* ex: .cFilterExpression = [Trn_Installation = .t.]
        .cValueExpression = [Trn_PK]
        .cLabelExpression = [cdow(Trn_Date) + ", " + dtoc(Trn_Date) + " " + stuff(Trn_Start_Time, 3, 0, ":")  + " to " + stuff(Trn_End_Time, 3, 0, ":")]
        .vFirstItemValue = space(32) && 0 for integer keys
        .cFirstItemLabel = "[ select from choices below ]"
      endwith 

      .AddObject("chkTraining_Signed", "L7Checkbox")
      with .chkTraining_Signed
        .cControlSource = "V_artist.Art_Training_Signed"
        .cCaption = "Signed as Reading Training"
        .cLabel = "Training"
      endwith

      .AddObject("chkWaiver_Signed", "L7Checkbox")
      with .chkWaiver_Signed
        .cControlSource = "V_artist.Art_Waiver_Signed"
        .cCaption = "Signed Waiver"
        .cLabel = "Waiver"
      endwith
    endwith 
    return
  endfunc 
  * --------------------------------------------------------- *
  function addParticipationControls()
    with this
      .AddObject("divPart", "L7Divider")
      with .divPart
        .cLabel = "Participation Information"
      endwith

      .AddObject("colArt", "L7CollectionControl")  && L7CheckboxCollection
      with .colArt
        .cGroupId = "part"
        .cCssStyle = "width: 40%;"
        .lAutoRender = .T.
        .cDefaultControlPattern = [(%l%s)%c(%s%i)(%b%v)]
        .cLabel = "Piece Submission Estimates (for planning purposes only)"
        .cInterControlText = L7BR  && CHR(38) + 'nbsp;'       && &nbsp
      endwith
      
      if !this.lNewRecord
        .colArt.AddObjectToParent("chkArtist", "L7Checkbox")
        with .chkArtist
          .cControlSource = "V_artist.Art_Artist"
          .cCaption = "Contributing Artist"
          .cLabel = "Artist"
          .cInstructions = "(Check this for anyone who may submit pieces.)"
        endwith
      endif 

      .colArt.AddObjectToParent("txtPanel_Count", "L7Textbox")
      with .txtPanel_Count
        .cFieldType = "I"
        .cControlSource = "V_artist.Art_Panel_Count"
        .nSize = 3
        .cLabel = "# of Whole Panels"
        .cInstructions = "(estimate only, if n/a, enter 0)"
      endwith

      .colArt.AddObjectToParent("chkPartial_Panel", "L7Checkbox")
      with .chkPartial_Panel
        .cControlSource = "V_artist.Art_Partial_Panel"
        .cCaption = "Making Partial Panel(s)"
        .cLabel = "Partial Panels"
      endwith

      .colArt.AddObjectToParent("txtRailing_1_Count", "L7Textbox")
      with .txtRailing_1_Count
        .cFieldType = "I"
        .cControlSource = "V_artist.Art_Railing_1_Count"
        .nSize = 3
        .cLabel = "# of 9x105 Railing pieces"
        .cInstructions = "(if none, enter 0)"
      endwith

      .colArt.AddObjectToParent("txtRailing_2_Count", "L7Textbox")
      with .txtRailing_2_Count
        .cFieldType = "I"
        .cControlSource = "V_artist.Art_Railing_2_Count"
        .nSize = 3
        .cLabel = "# of 15x80 Railing pieces"
        .cInstructions = "(if none, enter 0)"
      endwith

      #IF THISAPP_TYPE_3_RAILINGS
      .colArt.AddObjectToParent("txtRailing_3_Count", "L7Textbox")
      with .txtRailing_3_Count
        .cFieldType = "I"
        .cControlSource = "V_artist.Art_Railing_3_Count"
        .nSize = 3
        .cLabel = "# of 9x80 Railing pieces"
        .cInstructions = "(if none, enter 0)"
      endwith
      #ENDIF
      
      .AddObject("colPart", "L7CollectionControl")  && L7CheckboxCollection
      with .colPart
        .cGroupId = "part"
        .cCssStyle = "width: 30%;"
        .lAutoRender = .T.
        .cDefaultControlPattern = "%c(%s%i)"
        .cInterControlText = L7BR  && CHR(38) + 'nbsp;'       && &nbsp
        .cLabel = "Additional Participation"
      endwith
      
      .colPart.AddObjectToParent("chkTowers", "L7Checkbox")
      with .chkTowers
        .cControlSource = "V_artist.Art_Towers"
        .cCaption = "Machine Knitting for Towers"
      endwith
      
      .colPart.AddObjectToParent("chkHelp_Install", "L7Checkbox")
      with .chkHelp_Install
        .cControlSource = "V_artist.Art_Help_Install"
        .cCaption = "Help with Installation"
      endwith
      
      .colPart.AddObjectToParent("chkHelp_Deinstall", "L7Checkbox")
      with .chkHelp_Deinstall
        .cControlSource = "V_artist.Art_Help_Deinstall"
        .cCaption = "Help with Deinstallation"
      endwith

      .colPart.AddObjectToParent("chkHelp_Monitoring", "L7Checkbox")
      with .chkHelp_Monitoring
        .cControlSource = "V_artist.Art_Help_Monitoring"
        .cCaption = "Help with Monitoring"
      endwith

      .colPart.AddObjectToParent("chkHelp_Stitching", "L7Checkbox")
      with .chkHelp_Stitching
        .cControlSource = "V_artist.Art_Help_Stitching"
        .cCaption = "Help with Stitching"
      endwith

      .colPart.AddObjectToParent("chkHelp_Materials", "L7Checkbox")
      with .chkHelp_Materials
        .cControlSource = "V_artist.Art_Help_Materials"
        .cCaption = "Donating Materials"
      endwith
      
      .colPart.AddObjectToParent("chkHelp_Money", "L7Checkbox")
      with .chkHelp_Money
        .cControlSource = "V_artist.Art_Help_Money"
        .cCaption = "Donating Money to the Project"
      endwith
      
      .colPart.AddObjectToParent("chkOrganizer", "L7Checkbox")
      with .chkOrganizer
        .cControlSource = "V_artist.Art_Organizer"
        .cCaption = "Community Organizer"
      endwith
      
      .colPart.AddObjectToParent("chkHelp_Outreach", "L7Checkbox")
      with .chkHelp_Outreach
        .cControlSource = "V_artist.Art_Help_Outreach"
        .cCaption = "Help with Outreach"
      endwith

      .colPart.AddObjectToParent("edtHelp_Other", "L7Textarea")
      with .edtHelp_Other
        .cGroupId = "part"
        .cControlSource = "V_artist.Art_Help_Other"
        .cLabel = "Other ways you want to help"
        .cPattern = [(%l%s)%c(%s%i)(%b%v)]
        .nRows = 3
      endwith

      if poContext.lAdmin 
        if !this.lNewRecord
          .AddObject("edtParticipation", "L7Textarea")
          with .edtParticipation
            .cGroupId = "part"
            .cControlSource = "V_artist.Art_Participation"
            .cLabel = "Original Participation answers (e.g., from blog)"
            .nRows = 3
            .cCssClass = "FormControlPrivate"
          endwith

          .AddObject("lblRegister_Time", "L7Label")
          with .lblRegister_Time
            .cGroupID = "Register"
            .cControlSource = "V_artist.Art_Register_Time"
            .cLabel = "Registered"
            .cShowExpression = [L7TimeDiff(V_artist.Art_Register_Time)]
          endwith
        endif 

        .AddObject("edtKtb_Response", "L7Textarea")
        with .edtKtb_Response
          .cGroupID = "Register"
          .cControlSource = "V_artist.Art_Ktb_Response"
          .cLabel = "KtB Response"
          .cInstructions = "To be completed after response has been sent. If no response needed, enter: n/a"
          .nRows = 2
          .cCssClass = "FormControlPrivate"
        endwith
      endif 
    endwith
    return 
  endfunc  && addParticipationControls
enddefine 

*** ========================================================= ***
define class aisContributorForm AS aisRegisterForm
  cTitle = "New Contributing Artist Form"
  lCustom_Participation = .f. 
  lCustom_Contributing = .t. 
enddefine 

*** ========================================================= ***
define class aisRegisterForm AS aisArtistForms
  cTitle = "New Sign-Up Form"
  lCustom_Participation = .t. 
  lCustom_Contributing = .f. 
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject("txtFirst_Name", "L7Textbox")
      with .txtFirst_Name
        .cGroupID = "name"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_First_Name"
        .cLabel = "First Name"
        .cCssStyle = "width: 30%;"
      endwith
      .AddObject("txtLast_Name", "L7Textbox")
      with .txtLast_Name
        .cGroupID = "name"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Last_Name"
        .lRequired = .t.
        .cLabel = "Last Name"
        .cInstructions = "Required. Enter NLN if not providing your last name."
        .cCssStyle = "width: 30%;"
      endwith
      .AddObject("chkRelease_Name", "AisRadioCheckbox")
      with .chkRelease_Name
        .cGroupID = "name"
        .cControlSource = "V_artist.Art_Release_Name"
        .cLabel = "Release Name?"
        .cCaption = "OK to Release Name"
        .cFalseCaption = "DO NOT Release Name"
      endwith

      if !this.lCustom_Contributing 
        .AddObject("txtFull_Name", "L7Textbox")
        with .txtFull_Name
          .cGroupID = "name2"
          .cFieldType = "C"
          .cControlSource = "V_artist.Art_Full_Name"
          .cLabel = "Alternative Full Name"
          .cInstructions = "(leave blank unless this entry needs to override First/Last name in listings)"
        endwith
      endif 
      
      .AddObject("txtEmail", "L7Textbox")
      with .txtEmail
        .cGroupID = "cont"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Email"
        .cLabel = "Email"
        .cInstructions = "Not required, but very helpful for KtB to communicate with you."
        .cCssStyle = "width: 30%;"
        .nSize = 40
      endwith
      .AddObject("txtPhone", "L7Textbox")
      with .txtPhone
        .cGroupID = "cont"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Phone"
        .cLabel = "Phone"
        .cInstructions = "Optional, but if not providing email, very helpful for KtB to communicate with you."
        .cCssStyle = "width: 30%;"
      endwith

      .AddObject("divDemo", "L7Divider")
      with .divDemo
        .cLabel = "Demograhic Information"
      endwith
      .AddObject("cboAge_Range", "L7Popup")
      with .cboAge_Range
        .cGroupID  ="demo"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Age_Range"
        .cLabel = "Age Range"
        .nStyle = L7_MULTISTYLE_VERTICAL
        .nRowSourceType = L7_ROWSOURCETYPE_VALUE
        .cRowSource = THISAPP_AGE_RANGES
      endwith
      if !this.lCustom_Contributing 
        * on Registration form, allow full address to be entered
        .AddObject("edtAddress", "L7Textarea")
        with .edtAddress
          .cGroupID  ="demo"
          .cControlSource = "V_artist.Art_Address"
          .nRows = 2
          .cLabel = "Neighborhood or Township"
        endwith
      else
        .AddObject("txtNeighborhood", "L7Textbox")
        with .txtNeighborhood
          .cGroupID  ="demo"
          .cFieldType = "C"
          .cControlSource = "V_artist.Art_Neighborhood"
          .cLabel = "Neighborhood"
          if this.lNewRecord
            .setValue(page.oArt.Art_Neighborhood)
          endif
        endwith
      endif 
      
      if this.lCustom_Participation
        .addParticipationControls()
      endif 
      
      if this.lNewRecord
        .AddObject("chkAlert", "AisRadioCheckbox")
        with .chkAlert
          .cGroupID = "comments"
          .cLabel = "Email Alert?"
          .cCaption = "Yes - notify KtB leadership"
          .cFalseCaption = "No - do not send alert"
          .SetValue(poContext.lDeveloper) && others likely adding following actual contact 
          .cCssClass = "FormControlPrivate"
        endwith
      endif 
      if !this.lCustom_Contributing 
        .AddObject("edtComments", "L7Textarea")
        with .edtComments
          .cGroupID = "comments"
          .cControlSource = "V_artist.Art_Comments"
          .cLabel = "Description and Comments"
          .nRows = 2
        endwith
      endif 
      
    endwith
    return 
  endfunc  && addControls
enddefine  && aisRegisterForm

*** ========================================================= ***
define class aisArtistForm AS aisArtistForms
  cTitle = "Artist Form"
  cCssStyle = "width: 100%;"
  * --------------------------------------------------------- *
  function AddControls
    with this

      .AddObject("txtId", "L7Label")
      with .txtId
        .lDisabled = .T.
        .cGroupID = "PK"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Id"
        .cLabel = "Artist ID"
        ** .cControlCssStyle = [font-weight: bold; font-size: 16px;]
        .cControlCssClass = "id-field" 
      endwith
      .AddObject("chkApproved", "L7Checkbox")
      with .chkApproved
        .cGroupID = "PK"
        .cControlSource = "V_artist.Art_Approved"
        .cLabel = "Approved?"
        .cCssClass = "FormControlPrivate"
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
      .AddObject("chkRelease_Name", "L7Checkbox")
      with .chkRelease_Name
        .cGroupID = "name"
        .cControlSource = "V_artist.Art_Release_Name"
        .cLabel = "Release Name?"
        .nMode = L7_MULTI_RADIOBUTTON
        .nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
        .cCaption = "OK to Release Name"
        .cFalseCaption = "DO NOT Release Name"
      endwith
      .AddObject("chkAnonymous", "L7Checkbox")
      with .chkAnonymous
        .cGroupID = "name"
        .cControlSource = "V_artist.Art_Anonymous"
        .cLabel = "Anonymous?"
        .cCaption = "Anonymous"
      endwith
      if poContext.lDeveloper
        .AddObject("chkUnknown", "L7Checkbox")
        with .chkUnknown
          .cGroupID = "name"
          .cControlSource = "V_artist.Art_Unknown"
          .cLabel = "Unknown?"
          .cCaption = "Unknown Person"
          .cCssClass = "FormControlPrivate"
        endwith
      endif
      
      .AddObject("txtFull_Name", "L7Textbox")
      with .txtFull_Name
        .cGroupID = "name2"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Full_Name"
        .cLabel = "Alternative Full Name"
        .cInstructions = "(leave blank unless this entry needs to override First/Last name in listings)"
      endwith
      .AddObject("chkNo_Count", "L7Checkbox")
      with .chkNo_Count
        .cGroupID = "name2"
        .cControlSource = "V_artist.Art_No_Count"
        .cLabel = "Group Only?"
        .nMode = L7_MULTI_RADIOBUTTON
        .nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
        .cCaption = "Group Only (don't count in demographics)"
        .cFalseCaption = "Individual (include in demographics)"
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
      .AddObject("chkUndeliverable", "L7Checkbox")
      with .chkUndeliverable
        .cGroupID = "cont"
        .cControlSource = "V_artist.Art_Undeliverable"
        .cLabel = "Undeliverable?"
        .lDisabled = !m.poContext.lAdmin
        .cCssClass = "FormControlPrivate"
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

      .AddObject("divDemo", "L7Divider")
      with .divDemo
        .cLabel = "Demograhic Information"
      endwith
      .AddObject("cboAge_Range", "L7Popup")
      with .cboAge_Range
        .cGroupID  ="demo"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Age_Range"
        .cLabel = "Age Range"
        .nStyle = L7_MULTISTYLE_VERTICAL
        .nRowSourceType = L7_ROWSOURCETYPE_VALUE
        .cRowSource = THISAPP_AGE_RANGES
      endwith
      .AddObject("txtNeighborhood", "L7Textbox")
      with .txtNeighborhood
        .cGroupID  ="demo"
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Neighborhood"
        .cLabel = "Neighborhood"
      endwith
      .AddObject("edtAddress", "L7Textarea")
      with .edtAddress
        .cGroupID  ="demo"
        .cControlSource = "V_artist.Art_Address"
        .nRows = 2
        .cLabel = "Original Neighborhood (e.g., from blog)"
        .cCssClass = "FormControlPrivate"
      endwith

      .AddParticipationControls()
      
      .AddObject("edtComments", "L7Textarea")
      with .edtComments
        .cGroupID = "notes"
        .cControlSource = "V_artist.Art_Comments"
        .cLabel = "Description and Comments"
        .nRows = 3
      endwith

      .AddObject("chkStarred", "L7Checkbox")
      with .chkStarred
        .cGroupID = "notes"
        .nMode = L7_MULTI_RADIOBUTTON
        .nStyle = L7_MULTISTYLE_VERTICAL  && only applies to radio-button transforms
        .cControlSource = "V_artist.Art_Starred"
        .cLabel = "Starred?"
        .cCaption = "Starred"
        .cFalseCaption = "Not Starred"
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("edtNotes", "L7Textarea")
      with .edtNotes
        .cGroupID = "notes"
        .cControlSource = "V_artist.Art_Notes"
        .cLabel = "Internal KtB Notes"
        .nRows = 3
        .cCssClass = "FormControlPrivate"
      endwith

      .addTrainingControls()
      .addAdditionalControls()
      
      .addSecurityControls()
      
    endwith
  endfunc  && AddControls
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
        .nRows = 2
        .cCssClass = "FormControlPrivate"
      endwith

      .AddObject("edtBit_Info", "L7Textarea")
      with .edtBit_Info
        .cGroupId = "ss"
        .cControlSource = "V_artist.Art_Bit_Info"
        .cLabel = "Bit Info"
        .nRows = 2
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
        .cCssClass = "FormControlPrivate"
      endwith
      .colSec.AddObjectToParent("chkCore", "L7Checkbox")
      with .chkCore
        .cControlSource = "V_artist.Art_Core"
        .cCaption = "Core"
        .cCssClass = "FormControlPrivate"
      endwith
      .colSec.AddObjectToParent("chkAccount_Lockout", "L7Checkbox")
      with .chkAccount_Lockout
        .cControlSource = "V_artist.Art_Account_Lockout"
        .cCaption = "Account Lockout"
        .cCssClass = "FormControlPrivate"
      endwith
      .colSec.AddObjectToParent("chkAccount_Revoked", "L7Checkbox")
      with .chkAccount_Revoked
        .cControlSource = "V_artist.Art_Account_Revoked"
        .cCaption = "Account Revoked"
        .cCssClass = "FormControlPrivate"
      endwith

      if poContext.lDeveloper
        .AddObject("txtGroup_Art_FK", "L7Textbox")
        with .txtGroup_Art_FK
          .cFieldType = "C"
          .cControlSource = "V_artist.Art_Group_Art_FK"
          .cLabel = "Group Artist FK"
        endwith
      endif 
      
      .AddObject("txtAccess_Token", "L7Textbox")
      with .txtAccess_Token
        .cGroupId = "sec"
        .lDISABLED = .t. 
        .cFieldType = "C"
        .cControlSource = "V_artist.Art_Access_Token"
        .cLabel = "Access Token"
      endwith

      .addTimeStampControls()

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
    lcAlias = "V_Unapproved_Artists"
    *lcAlias = "V_Artists_by_Location"
    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    select (m.lcAlias)
    loForm = this.CreateForm("AisArtBrowseForm", this.cUrlC)
    with loForm
      .lCustom_Registry = .t. 
      .lCustom_Names = .t. 
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
  cCssStyle = "width: 100%;"
  lCustom_Names = .f.
  lCustom_Location = .f.
  lCustom_Registry = .f.
  lCustom_Contact = .f.
  lCustom_Part = .f. 
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject('grdBrowse', 'L7Grid')
      with .grdBrowse
        .cChildAlias = this.cAlias
        .cChildKeyExpression = this.cAlias + ".Art_PK"
        .nExtraRows = 0 && don't permit adds 
        .cGridTableCssClass = "sortable " + .cGridTableCssClass 
        .cColumnHeaderCssClass = "nosort" && sortable doesn't work for live controls, so override on specific labels
      
        .AddObject("lblID", "L7Label")
        with .lblID
          .cFieldType = "C"
          .cControlSource = this.cAlias + ".Art_ID"
          .cLabel = "ID"
          .cColumnHeaderCssClass = "sort" 
        endwith 

        if !this.lCustom_Names
          .AddObject("lblName_", "L7Label")
          with .lblName_
            .cFieldType = "C"
            .cControlSource = this.cAlias + ".Art_PK"
            .cLabel = "Name"
            .cShowExpression = [aisArtistName(] + this.cAlias + [.Art_PK)]
            .cColumnHeaderCssClass = "sort" 
          endwith 
        else
          .AddObject("edtName_Orig", "L7Textarea")
          with .edtName_Orig
            .cControlSource = this.cAlias + ".Art_Name_Orig"
            .cLabel = "Name Orig (from blog)"
            .nRows = 2
            .lDisabled = .t.
            .cColumnHeaderCssClass = "sort" 
          endwith

          .AddObject("txtFirst_Name", "L7Textbox")
          with .txtFirst_Name
            .cGroupId = "NAMES"
            .cControlSource = this.cAlias + ".Art_First_Name"
            .cLabel = "First Name"
          endwith

          .AddObject("txtLast_Name", "L7Textbox")
          with .txtLast_Name
            .cGroupId = "NAMES"
            .cControlSource = this.cAlias + ".Art_Last_Name"
            .cLabel = "Last Name"
          endwith

          .AddObject("txtFull_Name", "L7Textbox")
          with .txtFull_Name
            .cControlSource = this.cAlias + ".Art_Full_Name"
            .cLabel = "Alternative Full Name"
            .nSize = 30
          endwith
        endif

        if this.lCustom_Contact
          .AddObject("txtEmail", "L7Textbox")
          with .txtEmail
            .cGroupId = "CONTACT"
            .cControlSource = this.cAlias + ".Art_Email"
            .cLabel = "Email"
            .nSize = 25
          endwith
          .AddObject("txtPhone", "L7Textbox")
          with .txtPhone
            .cGroupId = "CONTACT"
            .cControlSource = this.cAlias + ".Art_Phone"
            .cLabel = "Phone"
            .nSize = 15
          endwith
        endif
        
        if this.lCustom_Registry

          .AddObject("lblRegister_Time", "L7Label")
          with .lblRegister_Time
            .cFieldType = "T"
            .cControlSource = this.cAlias + ".Art_Register_Time"
            .cLabel = "Sign-Up Time"
            .cShowExpression = [ttoc(] + this.cAlias + ".Art_Register_Time" + [, 3)] && sortable
            .cColumnHeaderCssClass = "sort" 
          endwith 

          .AddObject("lblParticipation", "L7Label")
          with .lblParticipation
            .cFieldType = "C"
            .cControlSource = this.cAlias + ".Art_Participation"
            .cLabel = "Participation"
          endwith 

          .AddObject("chkApproved", "L7Checkbox")
          with .chkApproved
            .cControlSource = this.cAlias + ".Art_Approved"
            .cLabel = "Approved"
            .cCaption = "Approved"
            .cCssClass = "FormControlPrivate"
          endwith

          .AddObject("edtKtb_Response", "L7Textarea")
          with .edtKtb_Response
            .cControlSource = this.cAlias + ".Art_Ktb_Response"
            .cLabel = "KtB Response"
            .nRows = 2
            .cCssClass = "FormControlPrivate"
          endwith

          .AddObject("lblNotes", "L7Label")
          with .lblNotes
            .cFieldType = "C"
            .cControlSource = this.cAlias + ".Art_Notes"
            .cLabel = "Internal KtB Notes"
          endwith 

          .AddObject("chkInactive", "L7Checkbox")
          with .chkInactive
            .cGroupID = "PK"
            .cControlSource = this.cAlias + ".Art_Inactive"
            .cLabel = "Delete?"
            .lDisabled = !m.poContext.lAdmin
            .cCaption = "DELETE"
            .cCssClass = "FormControlPrivate"
          endwith
        endif 
        
        if this.lCustom_Location 
          .AddObject("txtNeighborhood", "L7Textbox")
          with .txtNeighborhood
            .cControlSource = this.cAlias + ".Art_Neighborhood"
            .cLabel = "Neighborhood"
          endwith
          .AddObject("lblAddress", "L7Label")
          with .lblAddress
            .cFieldType = "C"
            .cControlSource = this.cAlias + ".Art_Address"
            .cLabel = "Original Neighborhood (e.g., froom blog)"
            .cColumnHeaderCssClass = "sort" 
          endwith 
        endif
      
      endwith && grid 
    endwith && form
  endfunc  && AddControls
enddefine && AisArtBrowseForm 

*** ========================================================= ***
define class Ais_Broadcast AS AisPage
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = stuffUrl(this.cUrlA, 2, "ArtList", "core", "1")
    local loForm, loQry
    local lcMsg, lcIndividualMsg, llSend, lnCount, llTesting, ;
      lcSentToMsg, lcBadEmailMsg, lcName, loArt, lcSubject, lcExtraHeaders, llHtml
    llHtml = .t. 
    store "" to lcSentToMsg, lcBadEmailMsg
    
    loForm = this.createForm("AisBroadcastForm")
    with loForm
      .addControls() 
      .doEvents()
      if .Valid()

        loQry = createobject("AisArtQuery")
        with loQry
          if loForm.chkAdmin.vNewValue
            .lAdmin = .t. 
          endif
          if loForm.chkCore.vNewValue
            .lCore = .t.
          endif
          if loForm.chkArtist.vNewValue
            .lArtist = .t.
          endif
          if loForm.chkNoShow.vNewValue
            .lPanelSignup = .t.
            .lBitsOrPanelsSubmitted = .f.
          endif
          if loForm.chkInstall.vNewValue
            .lInstall = .t.
          endif
          .execute()
        endwith
        
        lcIndividualMsg = ""
        lcSubject = .txtSubject.vNewValue
        lcExtraHeaders = alltrim(.txtReplyTo.vNewValue)
        if !empty(m.lcExtraHeaders) AND IsValidEmail(m.lcExtraHeaders)
          lcExtraHeaders = "Reply-To: " + m.lcExtraHeaders + CRLF
        endif 
        text to lcMsg PRETEXT 3
          <<loForm.edtMessage.vNewValue>>
        
        endtext 
        if .chkMainLink.vNewValue
          text to m.lcMsg additive pretext 3
            
            Follow this link for KtB information:
            <<THIS.FullURL("/")>>

          endtext 
        endif 
        lcMsg = strtran(textmerge(m.lcMsg), "&amp;", "&")
        if m.llHtml
          lcMsg = L7ParseOnView(m.lcMsg)
        endif 
        lnCount = 0
        llTesting = .chkTesting.vNewValue && OR .T.  && remove OR .T. later
        select (loQry.cAlias)
        scan 
          scatter memo name loArt
          llSend = .T.

          if m.llSend
            lcToEmail = trim(Art_Email)
            lcName = AisArtistName(m.loArt)
            llSend = !empty(m.lcToEmail) and IsValidEmail(m.lcToEmail)
            if !m.llSend
              lcBadEmailMsg = lcBadEmailMsg + m.lcName + ' [' + trim(Art_Phone) + ']'+ CRLF
            else 
              lcSentToMsg = lcSentToMsg + m.lcName + ' <' + m.lcToEmail + '>' + CRLF
            endif 
          endif 
          if !m.llSend
            loop 
          endif 
          lnCount = m.lnCount + 1
          if m.llTesting 
          else 
            this.oApp.QueueMessage( ;
              m.lcToEmail, ;
              m.lcSubject, ;
              m.lcMsg, ;
              trim(.txtFromName.vNewValue), ;
              trim(.txtFromEmail.vNewValue), ;
              "", ;
              "", ;
              "", ;
              iif(m.llHtml, "text/html", "text/plain"), ;
              .F., ;
              m.lcExtraHeaders)
            
          endif 
        endscan 
        this.Confirm(transform(m.lnCount) + " messages " + ;
          IIF(m.llTesting, "would have been", "were") + " sent." + ;
          [<div style="clear: both;"></div>] + ;
          [<div style="width: 50%; float: left;">] + ;
            [<em>Recipients:</em><br /><textarea style="width: 90%;" rows="20">] + ;
            m.lcSentToMsg + [</textarea></div>] + ;
          [<div style="width: 50%; float: left;">] + ;
            [<em>Not sent to (missing/bad email addresses):</em><br /><textarea style="width: 90%;" rows="12">] + ;
            m.lcBadEmailMsg + [</textarea></div>] + ;
          [<div style="clear: both;"></div>] )
        return .F.  && allows meeting page to show

      endif 
    endwith
    response.write(loForm.render())
    return 
  endfunc 

enddefine && Ais_Broadcast 

*** ========================================================= ***
define class AisBroadcastForm AS AisForm
  cTitle = "Broadcast Email"
  cHtmlName = "NtfEmail"
  cSubmitCaption = "Broadcast"
  lPreventMultipleSubmissions = .F.  && allow re-submit (to handle blocks of names, testing, etc.)
  * ----------------------------------------------------- *  
  function AddControls
    with this
      .AddObject("colWhom", "L7CheckboxCollection")  
      with .colWhom
        .cGroupId = "top"
        .cCssStyle = "width: 40%;"
        .lAutoRender = .T.
        .cDefaultControlPattern = [(%l%s)%c(%s%i)(%b%v)]
        .cLabel = "Limit Sending to Whom"
        .cInstructions = "If nothing checked, message goes to EVERYBODY!"
        .cInterControlText = L7BR  && CHR(38) + 'nbsp;'       && &nbsp
      endwith
      
      .colWhom.AddObjectToParent("chkArtist", "L7Checkbox")
      with .chkArtist
        .cCaption = "Send to all Artists"
        .cLabel = "Artists"
      endwith

      .colWhom.AddObjectToParent("chkInstall", "L7Checkbox")
      with .chkInstall
        .cCaption = "Send to all Installers"
        .cLabel = "Installers"
      endwith

      .colWhom.AddObjectToParent("chkNoShow", "L7Checkbox")
      with .chkNoShow
        .cCaption = "Promised Panel, Delivered Nothing"
        .cLabel = "Panel No-Shows"
      endwith

      .colWhom.AddObjectToParent("chkCore", "L7Checkbox")
      with .chkCore
        .cCaption = "Send to Core Team"
        .cLabel = "Core Team"
      endwith

      .colWhom.AddObjectToParent("chkAdmin", "L7Checkbox")
      with .chkAdmin
        .cCaption = "Send to Admins"
        .cLabel = "AIS Admins"
      endwith

      * From info:
      .AddObject("txtFromName", "L7Textbox")
      WITH .txtFromName
        *.cGroupID = "FROM"
        .cLabel = "From"
        .lRequired = .t. 
        .nSize = 30
        .SetValue(Config.cActionFrom)
        *!* .SetValue(CurrentUser.GetUserName())
      ENDWITH
      .AddObject("txtReplyTo", "L7Textbox")
      with .txtReplyTo
        *.cGroupID = "FROM"
        .cLabel = "Reply-To"
        .nSize = 30
        .cInstructions = "Optional reply email address. Use this in conjunction with From field to appear to come from someone else! "
        *!* .SetValue(TRIM(CurrentUser.oData.Art_Email))
        .SetValue(Config.cActionEmail)
      endwith 

      .AddObject("txtFromEmail", "L7Textbox")
      WITH .txtFromEmail
        *.cGroupID = "FROM"
        .cLabel = "From Email *"
        .lRequired = .t. 
        .cInstructions = "* MUST be a Cycla.com address to survive anti-SPAM measures! Use reply-to to specify a different client address if necessary."
        .nSize = 30
        .SetValue(Config.cAdminEmail) && TRIM(CurrentUser.oData.Par_Email))
      ENDWITH

      *!*        .AddObject("chkBCC", "L7Checkbox")
      *!*        WITH .chkBCC
      *!*          .cGroupID = "FROM"
      *!*          .cLabel = ""
      *!*          .lNoLabel = .T.
      *!*          .cCaption= "bcc: to myself"
      *!*          .SetValue(.f.)
      *!*        ENDWITH

      .AddObject("txtSubject", "L7Textbox")
      WITH .txtSubject
        .cGroupID = "SUBJECT"
        .lRequired = .t. 
        .cLabel = "Email Subject (required)"
        .nSize = 80
      endwith 
      
      .AddObject("edtMessage", "L7Textarea")
      WITH .edtMessage
        .cLabel = "Body of Message"
        .nRows = 10
        .lRequired = .T.
      ENDWITH
      
      * Link checkboxes.
      .AddObject("chkMainLink", "L7Checkbox")
      WITH .chkMainLink
        .cGroupID = "LINKS"
        .cCssStyle = "width: 50%;"
        .cLabel = ""
        .lNoLabel = .T.
        .vOldValue = .T.
        .cCaption= "Include Hyperlink to AIS"
        .SetValue(.f.)
      endwith 

      * TESTING-ONLY: 
      .AddObject("chkTesting", "L7Checkbox")
      WITH .chkTesting
        .cGroupID = "TESTING"
        .cCssStyle = "width: 50%;"
        .cLabel = ""
        .lNoLabel = .T.
        .vOldValue = .F.
        .cCaption= "Don't Broadcast -- Just Testing"
      endwith
    endwith
    return 
  endfunc 
enddefine && AisBroadcastForm 

*** ========================================================= ***
define class AisArtQuery AS L7Query
  cBaseTable = "Artist"
  cDefaultFieldList = ;
    "Art_PK, Art_ID, Art_Inactive, Art_Access_Token, Art_Approved, Art_Group_Art_FK, Art_No_Count, Art_Starred, Art_Artist, Art_Anonymous, Art_Unknown, Art_Hidden" + ;
    ", Art_Full_Name, Art_Last_Name, Art_First_Name, Art_Title, Art_Release_Name, Art_Name_Orig" + ; 
    ", Art_Email, Art_Undeliverable, Art_Phone, Art_Neighborhood, Art_Age_Range" + ;
    ", Art_Register_Time, Art_KTB_Response" 

  cID = null 
  cTrn = null 
  
  * Account-based params:
  lInactive = .f.  && whole record deleted
  lUser = NULL
  lAccountInactive = null && surrogate is "approved"
  lDupName = null
  lDupEmail = null
  
  lPanelSignup = null
  lRailingSignup = null   
  lBitsSubmitted = null 
  lPanelsSubmitted = null 
  lBitsOrPanelsSubmitted = null
  lRailingsSubmitted = null 
 
  lKtbResponse = null
  lNoCount = null 
  cGroupArt = null 
  lNLN = null
  
  * Types of people:
  lORTypes = .t.  && if .f. use AND 
  
  lAdmin = .F.
  lCore = .F.
  lHidden = .F. 
  lUndeliverable = null
  lArtist = .F.
  lStarred = null
  lInstall = .F.
  lDeinstall = .f.
  lMonitoring = .f. 
  lStitching = .f.

  lOrganizer = .F.
  lOutreach = .f. 
  lTowers = .F.
  lMoney = .F.
  lMaterials = .f. 

  * Name Search
  cName = ""
  cUser_Id = ""
  cSrch1 = ""

  nOrderBy = 1
  DIMENSION aOrderBy[ 1, 2]
  *aOrderBy[ 1, 1] = "UPPER(Par_Name)"
  aOrderBy[ 1, 1] = "Art_Last_Name"

  * --------------------------------------------------------- *
  function addParticipationFields
    this.addFields("Art_Towers, Art_Help_Install, Art_Help_Materials, Art_Help_Money, Art_Organizer, Art_Help_Outreach, Art_Help_Other" + ;
      ", Art_Help_Deinstall, Art_Help_Monitoring, Art_Help_Stitching" + ;
      ", Art_Partial_Panel, Art_Panel_Info, Art_Panel_Count, Art_Railing_1_Count, Art_Railing_2_Count, Art_Railing_3_Count")
    return 
  endfunc
  * --------------------------------------------------------- *
  function addTrainingFields
    this.addFields("Art_Waiver_Signed, Art_Training_Signed, Art_Installation_Trn_FK")
    return 
  endfunc
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr, lcInnerWhere, loFlags, lnFlag, loFlag, lcField, lnWords, lcWord1, lcWord2, lcSearchFields, lcTypeCombine
    with this 
      store "" to lcInnerWhere
      lcTypeCombine = iif(.lOrTypes, [ or ], [ and ])
  
      .lWhereBuilt = .T.
      if isnull(.lInactive)
        .cWhereClause = [WHERE .t.]
      else
        .cWhereClause = [WHERE Art_Inactive = ] + IIF(.lInactive, [.T.], [.F.])
      endif 
      
      if !isnull(.cID)
        .cWhereClause = .cWhereClause + [ and Art_Id = '] + .cId + [']
      endif

      if !isnull(.cTrn)
        .cWhereClause = .cWhereClause + [ and Art_Installation_Trn_FK = '] + .cTrn + [']
      endif
      
      * NOTE: next few use double quotes on purpose to allow searching stuff like "O'Brien"
      if !empty(.cSrch1)
        lcSearchFields = "Art_Last_Name + Art_First_Name + Art_Full_Name + Art_Email + Art_ID + Art_Comments + Art_Notes + Art_Participation"

        lcStr = lower(.cSrch1)
        lnWords = getwordcount(m.lcStr)
        if m.lnWords = 2
          lcWord1 = alltrim(getwordnum(m.lcStr, 1))
          lcWord2 = alltrim(getwordnum(m.lcStr, 2))
          .cWhereClause = .cWhereClause + [ AND ("] + m.lcWord1 + [" $ lower(] + m.lcSearchFields + [)] + ;
            [ OR "] + m.lcWord2 + [" $ lower(] + m.lcSearchFields + [)] + [)]
        else
          lcWord1 = m.lcStr
          .cWhereClause = .cWhereClause + [ AND "] + m.lcWord1 + [" $ lower(] + m.lcSearchFields + [)]
        endif
      endif 

      if !empty(.cName)
        .cWhereClause = .cWhereClause + [ AND Art_Last_Name LIKE "] + .cName + ["]
      endif 
      if !isnull(.lNLN)
        .cWhereClause = .cWhereClause + [ AND ] + iif(.lNLN, [], [!]) + [Art_Last_Name = "NLN "]
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

      if !isnull( .lHidden)
        .cWhereClause = .cWhereClause + [ AND Art_Hidden = ] + IIF(.lHidden, [.T.], [.F.])
      endif 

      if !isnull( .lUndeliverable)
        .cWhereClause = .cWhereClause + [ AND Art_Undeliverable = ] + IIF(.lUndeliverable, [.T.], [.F.])
      endif 

      if !isnull( .lKtbResponse)
        .cWhereClause = .cWhereClause + [ AND ] + IIF(.lKtbResponse, [!], []) + [empty(Art_KTB_Response)]
      endif 

      if !isnull(.lDupName)
        .cWhereClause = .cWhereClause + [ and art_first_name + art_last_name] + iif(.lDupName, [ in ], [ not in ]) + ;
          [(select art_first_name + art_last_name from artist where !art_inactive and !art_no_count group by 1 having count(*) >= 2)]
      endif 
      
      if !isnull(.lDupEmail)
        .cWhereClause = .cWhereClause + [ and art_email] + iif(.lDupEmail, [ in ], [ not in ]) + ;
          [(select art_email from artist where !art_inactive and !empty(art_Email) and !art_no_count group by 1 having count(*) >= 2)]
      endif 

      if !isnull(.lPanelSignup)
        .cWhereClause = .cWhereClause + [ and Art_Panel_Count] + iif(.lPanelSignup, [ > 0], [ = 0])
      endif

      if !isnull(.lRailingSignup)
        .cWhereClause = .cWhereClause + [ and Art_Railing_1_Count + Art_Railing_2_Count] + iif(.lRailingSignup, [ > 0], [ = 0])
      endif

      if !isnull(.lBitsOrPanelsSubmitted)
        .cWhereClause = .cWhereClause + [ and Art_PK] + iif(.lBitsOrPanelsSubmitted, [ in ], [ not in ]) + ;
          [(select Pce_Art_FK from Piece where !Pce_Inactive and Pce_Type = 'Panels')]
      endif 
      
      if !isnull(.lPanelsSubmitted)
        .cWhereClause = .cWhereClause + [ and Art_PK] + iif(.lPanelsSubmitted, [ in ], [ not in ]) + ;
          [(select Pce_Art_FK from Piece where !Pce_Inactive and Pce_Type = 'Panels' and Pce_Whole_Panel)]
      endif 

      if !isnull(.lBitsSubmitted)
        .cWhereClause = .cWhereClause + [ and Art_PK] + iif(.lBitsSubmitted, [ in ], [ not in ]) + ;
          [(select Pce_Art_FK from Piece where !Pce_Inactive and Pce_Type = 'Panels' and !Pce_Whole_Panel)]
      endif 

      if !isnull(.lRailingsSubmitted)
        .cWhereClause = .cWhereClause + [ and Art_PK] + iif(.lRailingsSubmitted, [ in ], [ not in ]) + ;
          [(select Pce_Art_FK from Piece where !Pce_Inactive and Pce_Type = 'Railings')]
      endif 

      if !isnull( .lNoCount)
        .cWhereClause = .cWhereClause + [ AND Art_No_Count = ] + IIF(.lNoCount, [.T.], [.F.])
      endif 

      if !isnull(.cGroupArt)
        .cWhereClause = .cWhereClause + [ and Art_Group_Art_FK = '] + .cGroupArt + [']
      endif 

      *!*        if !isnull( .lStarred) && this is in flags 
      *!*          lcInnerWhere = m.lcInnerWhere + m.lcTypeCombine + [Art_Starred = ] + IIF(.lStarred, [.T.], [.F.])
      *!*        endif 

      loFlags = AisArtQueryFlags()
      for lnFlag = 1 to loFlags.count
        loFlag = loFlags.item[m.lnFlag]
        if evaluate("this.l" + loFlag.root)
          lcField = iif(pemstatus(loFlag, "field", 5), loFlag.field, "Art_" + proper(loFlag.root))
          lcInnerWhere = m.lcInnerWhere + m.lcTypeCombine + m.lcField + [ = .T.]
        endif
      next 
      
      * Combine inner-WHERE with WHERE clauses:
      if !empty( m.lcInnerWhere) 
        .cWhereClause = .cWhereClause + [ and (] + substr(m.lcInnerWhere, 1 + len(m.lcTypeCombine)) + [)]
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisArtQuery

#if .f.
  <div class="ss-item ss-item-required ss-text"><div class="ss-form-entry"><label class="ss-q-title" for="entry_0">Name
  <span class="ss-required-asterisk">*</span></label>
  <label class="ss-q-help" for="entry_0"></label>
  <input type="text" name="entry.0.single" value="" class="ss-q-short" id="entry_0"></div></div></div>
  <br> <div class="errorbox-good">
  <div class="ss-item ss-item-required ss-text"><div class="ss-form-entry"><label class="ss-q-title" for="entry_1">Contact Information
  <span class="ss-required-asterisk">*</span></label>
  <label class="ss-q-help" for="entry_1">Email or Phone</label>
  <input type="text" name="entry.1.single" value="" class="ss-q-short" id="entry_1"></div></div></div>
  <br> <div class="errorbox-good">
  <div class="ss-item ss-item-required ss-checkbox"><div class="ss-form-entry"><label class="ss-q-title" for="entry_3">I want to participate in Knit the Bridge by...
  <span class="ss-required-asterisk">*</span></label>
  <label class="ss-q-help" for="entry_3">Choose all that apply</label>

  <ul class="ss-choices"><li class="ss-choice-item"><label class="ss-choice-label"><input type="checkbox" name="entry.3.group" value="Making a Full Panel (34&quot; x72&quot;)" class="ss-q-checkbox" id="group_3_1">

  Making a Full Panel (34&quot; x72&quot;)</label></li> <li class="ss-choice-item"><label class="ss-choice-label"><input type="checkbox" name="entry.3.group" value="Making a Partial Panel (14&quot; x 14&quot;)" class="ss-q-checkbox" id="group_3_2">
  Making a Partial Panel (14&quot; x 14&quot;)</label></li> <li class="ss-choice-item"><label class="ss-choice-label"><input type="checkbox" name="entry.3.group" value="Machine Knitting for Towers (Template provided)" class="ss-q-checkbox" id="group_3_3">
  Machine Knitting for Towers (Template provided)</label></li> <li class="ss-choice-item"><label class="ss-choice-label"><input type="checkbox" name="entry.3.group" value="Organizing a Knit and/or Crochet Meet Up" class="ss-q-checkbox" id="group_3_4">
  Organizing a Knit and/or Crochet Meet Up</label></li> <li class="ss-choice-item"><label class="ss-choice-label"><input type="checkbox" name="entry.3.group" value="Visiting a School, Senior Center, or Other Community Center in my Community" class="ss-q-checkbox" id="group_3_5">
  Visiting a School, Senior Center, or Other Community Center in my Community</label></li> <li class="ss-choice-item"><label class="ss-choice-label"><input type="checkbox" name="entry.3.group" value="Donating Materials (Knitting Needles, Crochet Hooks, Acrylic Yarn)" class="ss-q-checkbox" id="group_3_6">
  Donating Materials (Knitting Needles, Crochet Hooks, Acrylic Yarn)</label></li> <li class="ss-choice-item"><label class="ss-choice-label"><input type="checkbox" name="entry.3.group" value="Helping with the Installation" class="ss-q-checkbox" id="group_3_7">
  Helping with the Installation</label></li>

  <li class="ss-choice-item"><input type="checkbox" name="entry.3.group" value="__option__" class="ss-q-checkbox" id="other_option:3">
  <label for="other_option:3">Other:</label>
  <input type="text" name="entry.3.group.other_option_" value="" class="ss-q-other"></li></ul></div></div></div>
  <br> <div class="errorbox-good">
  <div class="ss-item ss-item-required ss-text"><div class="ss-form-entry"><label class="ss-q-title" for="entry_4">Neighborhood or Township
  <span class="ss-required-asterisk">*</span></label>
  <label class="ss-q-help" for="entry_4"></label>
  <input type="text" name="entry.4.single" value="" class="ss-q-short" id="entry_4"></div></div></div>
  <br>
  <input type="hidden" name="pageNumber" value="0">
  <input type="hidden" name="backupCache" value="">
#endif 


* end 
