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

* end: AisAdm 

