* AisArtPages.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

function AisArtQueryFlags()
  return L7JsonParse( ;
    '[' + ;
    '{"root": "core", "prompt": "Team"}' + ;
    ',{"root": "install", "field": "Art_Help_Install"}' + ;
    ',{"root": "outreach", "field": "Art_Help_Outreach"}' + ;
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
  function ProcessRequest
    response.write(L7ShowObject(this.oArt))
  endfunc 
enddefine 

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
