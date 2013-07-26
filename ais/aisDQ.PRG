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

*** ============================================== ***
define class AisPceData AS AisViewData 
  cTable = "Piece"
  cPrefix = "PCE"
enddefine    

*** ============================================== ***
define class AisPnlData AS AisViewData 
  cTable = "Panel"
  cPrefix = "PNL"
enddefine    

*** ============================================== ***
define class AisPlcData AS AisViewData 
  cTable = "PanelLocation"
  cPrefix = "PLC"
enddefine    

*** ============================================== ***
define class AisFacData AS AisViewData 
  cTable = "Facility"
  cPrefix = "FAC"
enddefine    

*** ============================================== ***
define class AisFilData AS AisViewData 
  cTable = "Files"
  cPrefix = "FIL"
enddefine    

*** ============================================== ***
define class AisLocData AS AisViewData 
  cTable = "Location"
  cPrefix = "LOC"
enddefine    

*** ============================================== ***
define class AisDonData AS AisViewData 
  cTable = "Donation"
  cPrefix = "DON"
enddefine    

*** ============================================== ***
define class AisTrnData AS AisViewData 
  cTable = "Training"
  cPrefix = "TRN"
enddefine    

*** ============================================== ***
define class AisSftData AS AisViewData 
  cTable = "Shift"
  cPrefix = "SFT"
enddefine    

*** ============================================== ***
define class AisArsData AS AisViewData 
  cTable = "ArtistShift"
  cPrefix = "ARS"
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

* end

