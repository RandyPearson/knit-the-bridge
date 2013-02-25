* AisArtPages.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ========================================================= ***
define class aisArtPage as aisPage 
  cArt = ""
  oArt = null
  lArtRequired = .t.
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
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
    loQry = createobject("AisArtQuery")
    with loQry
      .cSearch = 'gross'
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "ArtHome"), "ArtHome")
    loTbl = createobject("AisTable")
    with loTbl
      loCol = .addCursorColumn("Art_Last_Name", "Name", ;
        [HTLink(StuffUrl(urls.item("ArtHome"), "art", Art_PK), trim(Art_Last_Name) + ", " + trim(Art_First_Name))])
      loCol = .addCursorColumn("Art_Email")
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
    local lcStr, lcInnerWhere, lcGroupWhere, ii
    store "" to lcInnerWhere, lcGroupWhere

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
        .cWhereClause = .cWhereClause + [ AND Art_User_Id ] + IIF(.lUser, [<> ' '], [= ' '])
      endif 
      if !isnull( .lAccountInactive)
        .cWhereClause = .cWhereClause + [ AND Art_Approved = ] + IIF(.lAccountInactive, [.T.], [.F.])
      ENDIF

      * Build "inner" WHERE clause that is used to control
      * security, etc.
      if !( .lCore or .lArtist OR .lAdmin)
        * If none checked, assume no people should be listed.
      else 
        lcInnerWhere = m.lcInnerWhere + ;
          IIF( .lCore, [ OR Art_Core = .T.], []) + ;
          IIF( .lArtist, [ OR Art_Artist = .T.], []) + ;
          IIF( .lAdmin, [ OR Art_Admin = .T.], [])
      endif 
      
      * Build "outer" or "group" WHERE based on query conditions:
      
      * Now combine inner-WHERE with group-WHERE clauses:
      DO CASE
      CASE EMPTY( m.lcInnerWhere) AND EMPTY( m.lcGroupWhere)
        = .F.
        
      CASE NOT EMPTY( m.lcInnerWhere) AND EMPTY( m.lcGroupWhere)
        .cWhereClause = .cWhereClause + [ AND (] + ;
          SUBSTR( m.lcInnerWhere, 5) + [)]

      CASE EMPTY( m.lcInnerWhere) AND NOT EMPTY( m.lcGroupWhere)
        .cWhereClause = .cWhereClause + [ AND ] + m.lcGroupWhere
        
      CASE NOT EMPTY( m.lcInnerWhere) AND NOT EMPTY( m.lcGroupWhere)
        .cWhereClause = .cWhereClause + [ AND ] + ;
          [((] + ;
          SUBSTR( m.lcInnerWhere, 5) + [)] + ;
          IIF( .lOrGroups, [ OR ], [ AND ]) + ;
          m.lcGroupWhere + ;
          [)]
      ENDCASE
    ENDWITH 
    RETURN 
  ENDFUNC  && BuildWhereClause
enddefine  && AisArtQuery


* end 
