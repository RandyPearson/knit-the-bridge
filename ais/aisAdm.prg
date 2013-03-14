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
    loForm = this.createForm('AisSetPasswordForm')
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

