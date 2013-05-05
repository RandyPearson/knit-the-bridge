* AisFIL.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* --------------------------------------------------------- *
function aisPanelFilePath(tvKey)
  local lcPath, lcKey
  lcKey = iif(vartype(m.tvKey) = 'O', tvKey.Pnl_ID, m.tvKey)
  lcPath = addbs(config.cFilePath) + ; && start at top 
    "Panels\" + substr(m.lcKey, len("PNL") + 1, 1) + "\" + m.lcKey + "\" 
  return m.lcPath
endfunc 
* --------------------------------------------------------- *
function aisPanelWebFilePath(tvKey)
  local lcPath, lcKey
  lcKey = iif(vartype(m.tvKey) = 'O', tvKey.Pnl_ID, m.tvKey)
  lcPath = "/ktb-photos/Panels/" + substr(m.lcKey, len("PNL") + 1, 1) + "/" + m.lcKey + "/" 
  return m.lcPath
endfunc 

*** ========================================================= ***
define class ais_PnlFilNew as aisPage
  lPnlRequired = .t.
  lAdding = .t. 
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.Assert(poContext.lCore)
    this.cCancelUrl = stuffUrl(this.cUrlB, 2, "PnlHome")

    local loForm, vp_cPnl_PK, lcAlias, loTrans, loImg, loNewRec
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

      if .Valid()
        select (m.lcAlias)
        append blank
        replace Fil_Pnl_FK with this.cPnl ;
          Fil_Upload_Name with .fil1.cFileName ;
          Fil_Size with .fil1.nFileSize ;
          Fil_Upload_Time with this.tNow 
        .UpdateControlSources()        
        StampRec( CurrentUser, THIS.tNow )

        with .fil1
          .cSaveAsFolder = aisPanelFilePath(this.oPnl)
          .cSaveAsName = forceext(Fil_PK, justext(.cFileName)) && pk w/ original extension
          
          if !directory(.cSaveAsFolder)
            mkdir(.cSaveAsFolder)
          endif 
        
          .lOverwriteProtection = .T.                  && [[ correct policy?
          if !.SaveAs()
            error "failed to save file" 
          endif
          loImg = createobject("L7ImageInfo")
          loImg.cPath = .cSaveAsFolder
          loImg.cFileName = .cSaveAsName
          loImg.GetInfo()
          replace Fil_Height with loImg.nHeight ;
            Fil_Width with loImg.nWidth ;
            Fil_Resolution with loImg.nResolution 
        endwith        
        select (m.lcAlias)
        scatter memo name loNewRec
        
        if Fil_Main && if now main, uncheck any previous files 
          scan for Fil_Main and !Fil_PK = loNewRec.Fil_PK
            replace Fil_Main with .f.
            StampRec( CurrentUser, THIS.tNow )
          endscan 
        endif

        loTrans = THIS.CreateTransaction()
        loTrans.AddCursor(m.lcAlias)

        if loTrans.Save()  
          this.page_onFileSave(m.loImg, m.loNewRec)
          Response.Redirect(this.cCancelUrl)
          return 
        endif 
      endif 

      response.write(.render()) 
    endwith 
    return 
  endfunc 
  * --------------------------------------------------------- *
  function page_onFileSave(loImg, loNewRec)  
    local lcXforms, loXforms, loXform, loImgT, lcFileName
    if !loNewRec.Fil_Main
      return 
    endif 
    text to lcXforms noshow pretext 15
      [{"suffix": "_main", "width": 320, "height": 0, "rotate": 0}, 
       {"suffix": "_H50", "width": 0, "height": 50, "rotate": 0}, ;
       {"suffix": "_H50R", "width": 0, "height": 50, "rotate": 1}, ;
       {"suffix": "_H25", "width": 0, "height": 25, "rotate": 0}]
    endtext 
    loXforms = L7JsonParse(m.lcXforms)
    for lnXform = 1 to loXforms.count
      loXform = loXforms.item[m.lnXform]
      lcFileName = forceext(this.oPnl.Pnl_ID + m.loXform.suffix, "jpeg")
      loImgT = loImg.CreateThumbnail(loXform.width, loXform.height, m.lcFileName)
      if loXform.rotate > 0
        loImgT.RotateImage(loXform.rotate)
      endif 
    next 
    return 
  endfunc 
  
enddefine  && ais_PnlFilNew 

*** ========================================================= ***
define class aisFilForm as AisForm
  cTitle = "File Upload Form"
  cAlias = null && client should set 
  * --------------------------------------------------------- *
  function  AddControls
    with this
      .AddObject("fil1", "L7FileUpload")
      with .fil1
        .lRequired = .t. && fail if nothing arrives 
        .cLabel = "Choose file to upload"
        .cAllowExtensions = THISAPP_VALID_LIBRARY_FILETYPES 
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
