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

