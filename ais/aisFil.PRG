* AisFIL.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

*** ========================================================= ***
define class ais_PnlFilNew as aisPage
  lPnlRequired = .t.
  lAdding = .t. 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.Assert(poContext.lCore)
    this.cCancelUrl = stuffUrl(this.cUrlB, 2, "PnlHome")

    local loForm, vp_cPnl_PK, lcAlias
    lcAlias = "v_Panel_File_Set"
    vp_cPnl_PK = this.cPnl
    use (m.lcAlias) again in select(m.lcAlias)

    cursorsetprop("Buffering", 5, m.lcAlias)
    loForm = this.createForm('aisFilForm', this.cUrlC)
    with loForm
      .cAlias = m.lcAlias
      .lNewRecord = THIS.lAdding
      .AddControls()
      .DoEvents()
      response.write(.render()) 
    endwith 
    return 
  endfunc 
enddefine 

*** ========================================================= ***
define class aisFilForm as AisForm
  cTitle = "File Upload Form"
  cAlias = null && client should set 
  * --------------------------------------------------------- *
  function  AddControls
    with this
      .AddObject("fil1", "L7FileUpload")
      with .fil1
        .cLabel = "Choose file to upload"
      endwith

      .AddObject("chkMain", "L7Checkbox")
      with .chkMain
        .cControlSource = this.cAlias + ".Fil_Main"
        .cLabel = "Main File?"
        .cInstructions = "Check if file is the primary image for this item."
        if this.lNewRecord
          .setValue(.t.)
        endif
      endwith

      if  !this.lNewRecord
        .AddObject("chkInactive", "L7Checkbox")
        with .chkInactive
          .cGroupID = "ID"
          .cControlSource = this.cAlias + ".Fil_Inactive"
          .cLabel = "Delete?"
          .lDisabled = !poContext.lDeveloper
          .cCssClass = "FormControlPrivate"
        endwith
      endif 
    endwith 
    return
  endfunc  && AddControls
enddefine && aisFilForm


* end: FIL 
