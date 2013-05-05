* AisAdm.PRG  && admin pages

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ========================================================= ***
define class aisAdminPage as aisPage 
  lAdminRequired = .f.
enddefine 

*** ========================================================= ***
define class ais_RefreshContent as aisAdminPage 
  * --------------------------------------------------------- *
  function processRequest
    goL7App.DeployContent()
    response.write("DeployContent was run.")
    return

  endfunc
enddefine 

*** ========================================================= ***
define class ais_ReassignID as aisAdminPage 
  lArtRequired = .t.
  * --------------------------------------------------------- *
  function processRequest

    this.cCancelUrl = StuffURL(THIS.cUrlB, 2, "ArtHome")
    local vp_cArt_PK, lcXml, lcAlias, lcStub, lnAns, lcOldId, lcNewID
    
    lcAlias = "V_Artist"
    vp_cArt_PK = THIS.cArt
    use (m.lcAlias) in select(m.lcAlias)
    lcOldId = V_Artist.Art_ID

    lnAns = THIS.MessageBox(TEXTMERGE("CAUTION: You will lose the ability to search for the previous ID <<m.lcOldID>>. OK to re-assign ID?"))
    if m.lnAns = IDYES
      cursorsetprop("Buffering", 5, m.lcAlias)
      select (m.lcAlias)
      lcStub = padr(alltrim(upper(evl(Art_Last_Name, "NLN"))), 5, 'X')
      lcNewID = AisAssignID(m.lcStub)
      replace Art_ID with m.lcNewId ;
        Art_Notes with textmerge([<<date()>> ID changed from <<m.lcOldID>> to <<m.lcNewID>> by <<CurrentUser.getUserName()>>]) + CRLF + Art_Notes 
      
      StampRec( CurrentUser, THIS.tNow )
      lcXml = ''
      this.AssertTransaction(m.lcAlias, @lcXml)
    endif 
    Response.Redirect(this.cCancelUrl)
    return
  endfunc
enddefine 

*** ========================================================= ***
define class ais_SetPassword as aisAdminPage 
  lArtRequired = .t.
  * --------------------------------------------------------- *
  function processRequest

    this.cCancelUrl = StuffURL(THIS.cUrlB, 2, "ArtHome")
    local loForm, vp_cArt_PK, lcXml, lcAlias
    lcAlias = "V_Artist"
    vp_cArt_PK = THIS.cArt

    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    loForm = this.createForm('AisSetPasswordForm', this.cUrlC)
    with loForm
      .AddControls()
      .DoEvents() 
      if .Valid()
        if !.txtPW1.vNewValue == .txtPW2.vNewValue
          .txtPW2.addValidationMessage("Passwords did not match.")
        else
          select (m.lcAlias)
          replace Art_Password_Hash with ;
            AisPasswordHash(.txtPW1.vNewValue, Art_Id)
          StampRec( CurrentUser, THIS.tNow )
          lcXml = ''
          this.AssertTransaction(m.lcAlias, @lcXml)
          Response.Redirect(this.cCancelUrl)
          return 
        endif 
      endif 
    endwith && form
    
    response.write(loForm.render())
    return
  endfunc
enddefine 


*** ========================================================= ***
define class AisSetPasswordForm AS AisForm
  cTitle = "Set Password Form"
  * --------------------------------------------------------- *
  function AddControls
    with this
      .addObject("txtPW1", "AisPasswordTextbox")
      with .txtPW1
        .cLabel = "Enter New Password"
      endwith
      .addObject("txtPW2", "AisPasswordTextbox")
      with .txtPW2
        .cLabel = "Re-Enter New Password"
      endwith
    endwith
    return  
  endfunc
enddefine 

* end: AisAdm 

