* AisDQ.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ============================================== ***
define class AisViewData AS L7ViewData 
  lIntegerKeys     = .F. && set .F, for GUID/char keys
enddefine    

*** ============================================== ***
define class AisArtData AS AisViewData 
  cTable = "Artist"
  cPrefix = "ART"
enddefine    

*** ===================================================== ***
define class AisQuery AS L7Query
  * Abstract application-wide subclass that includes some 
  * standard abilities to add permission checks into queries.
  *
  * Implemented classes can be derived either from this or
  * directly from L7Query if these extra methods are not needed.

  * Status code array (not applicable to all subclasses):
  nStatusCount = 0
  DIMENSION aStatus[1]
  lNegateStatus = .F.   && make .T. to force NOT
  nStatusFieldLength = THISAPP_LENGTH_STATUS  && can override for non-standard entities

  * --------------------------------------------------------- *
  function init
    dodefault()
    if !dbused( this.cDatabase)
      open database (this.cDataPath + this.cDatabase)
    endif 
    set database to ( this.cDatabase )
  endfunc  && INIT
  
  * --------------------------------------------------------- *
  function AddStatusCondition(lcField, llNoAdd, lcCaption)
    * 2nd param is flag to return the condition as a string
    LOCAL lcStr, lcStrCap, lcStat, ii, llCapt
    llCapt = VARTYPE(m.lcCaption) = "C" && pass by reference
    lcStr = ""
    lcStrCap = ""
    IF THIS.nStatusCount > 0
      lcStat = []
      FOR ii = 1 TO THIS.nStatusCount
        lcStat = m.lcStat + [,'] + THIS.aStatus[ m.ii] + [']
        IF m.llCapt
          lcStrCap = m.lcStrCap + "/" + TRIM(THIS.aStatus[ m.ii])
        ENDIF
      ENDFOR
      lcStr = m.lcField + ;
        IIF( THIS.lNegateStatus, [ NOT], []) + ;
        [ IN (] + SUBSTR( m.lcStat, 2) + [)]
      IF m.llCapt
        lcCaption = ;
          IIF( THIS.lNegateStatus, [NOT ], []) + ;
          SUBSTR( m.lcStrCap, 2) + " " + m.lcCaption
      ENDIF
      IF NOT m.llNoAdd
        THIS.cWhereClause = THIS.cWhereClause + [ AND ] + m.lcStr
      ENDIF
    ENDIF
    RETURN m.lcStr
  ENDFUNC  && AddStatusCondition
  * --------------------------------------------------------- *
  FUNCTION AddStatus( lcStat)
    LOCAL ii
    lcStat = PADR( m.lcStat, THIS.nStatusFieldLength )
    FOR ii = 1 TO THIS.nStatusCount
      IF THIS.aStatus[ m.ii] = m.lcStat
        EXIT  && duplicate request
      ENDIF
    ENDFOR
    IF m.ii > THIS.nStatusCount  && not found
      THIS.nStatusCount = THIS.nStatusCount + 1
      DIMENSION THIS.aStatus[ THIS.nStatusCount ]
      THIS.aStatus[ THIS.nStatusCount ] = m.lcStat
    ENDIF
  ENDFUNC  && AddStatus
  * --------------------------------------------------------- *
enddefine  && AisQuery


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







