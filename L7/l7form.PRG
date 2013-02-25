* L7Form.PRG
*
* HTML-based entry forms (see also: L7Grid, L7FormRender, 
*    L7BaseControls, L7Controls, L7MultiControls)
*
#INCLUDE L7.H

#IF .F.
***** BEGIN LICENSE BLOCK *****
Version: MPL 1.1

The contents of this file are subject to the Mozilla Public License Version 
1.1 (the "License"); you may not use this file except in compliance with 
the License. You may obtain a copy of the License at 
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is "Level 7 Framework for Web Connection" and 
"Level 7 Toolkit" (collectively referred to as "L7").

The Initial Developer of the Original Code is Randy Pearson of 
Cycla Corporation.

Portions created by the Initial Developer are Copyright (C) 2004 by
the Initial Developer. All Rights Reserved.

***** END LICENSE BLOCK *****
#ENDIF


* ==================================================================== *
DEFINE CLASS L7Form AS L7ContainerControl
  * Container for Html form objects.
  lForm         = .T.
  
  cFormName     = "" 
  lInputRead    = .F.
  lPosted       = .F.    && was any POST made?
  lPostChecked  = .F.    && did we check posting yet?
  lDisabled     = .F.    && read-only
  cMethod       = "post"
  cOnSubmit     = ""     && optional client-side JS
  cOnReset      = ""     && optional client-side JS
  lPreventMultipleSubmissions = .T.
  lMultiPart        = .F.
  lMultiPartChecked = .F.  && flag to prevent duplicate checks. See CheckMultiPart().
  lObjectIDsSet     = .F.
  lObjectsPrepared  = .F.
  
  cAction       = ""     && Required! Form will attempt to determine if not specified.
  cTarget       = ""     && optional frame/window name for results
  lNoFormname   = .F.
  
  cCancelURL    = ""     && See ASSIGN method.
  lCancelled    = .F.
  lRedisplay    = .F.    && see ReDisplay() and the PreviewButton class.
  lSelfValidate = .T.    && DOEVENTS should call Valid directly
  lValidated    = .F.
  
  lFocusFirst   = .T.    && cause first element to get focus (only if form created from L7Page.CreateForm)

  * Form title:
  cTitle          = ""
  cTitleCssClass  = "FormTitle"
  cTitleBgColor   = ""           && deprecated (in favor of CSS)
  cTitleFontColor = ""           && deprecated (in favor of CSS)

  *!*    * Sub-title is for extra stuff to appear in a row below the title:
  *!*    cSubTitle          = ""
  *!*    cSubTitleCssClass  = "FormSubTitle"

  * Footnotes:
  cFootnoteText     = ""
  cFootnoteCssClass = "FormFootnotes"

  cValidationCssClass = "FormValidation"
  cValidationHeading  = "Invalid or Missing Entries -- See Below" && used by L7FormRender

  cXML          = ""

  * Toolbar properties:
  lToolbarAtTop    = .F.  && DEPRECATED (in favor of L7ControlProxy)
  lToolbarAtBottom = .T.  && DEPRECATED (in favor of L7ControlProxy)
  ** oToolbar         = NULL
  cToolbarClass    = "L7Toolbar"
  

  * Form renderer class:
  cRenderClass     = "L7FormRenderOverUnder"  && see L7FormRender.PRG
  nLayoutStyle     = 1  && DEPRECATED (use cRenderClass)

  cWrapperTag      = "div"       && div or table
  cCssClass        = "FormTable" && used by rendered in conjunction with cWrapperTag
  cFormCssClass    = ""          && affects <form> vs. outer <div>, not typically used (see FormOpen method)
  cFormCssStyle    = ""          &&  " (ditto)

  nBorder         = NULL         && deprecated (in favor of CSS)
  nCellSpacing    = NULL         && no good CSS alternative yet
  cAlign          = "CENTER"     
  cBgColor        = ""           && deprecated (in favor of CSS)
  cBackground     = ""           && deprecated (in favor of CSS)

  * Used in some 2-column formats:
  nTextareaColThreshhold = 60  && point above which COLSPAN is used

  * Data Information:
  cControlSourceType           = "Record"  && or "Object"

  * Member event handling:
  nMemberEvents = 0
  DIMENSION aMemberEvents[1,2]
  cDefaultEventMember = ""  && e.g., "btnSubmit"
  cDefaultEventMethod = ""  && e.g., "Click"
  
  * Add Submit, Preview, Reset and Cancel buttons:
  *
  * Flags that affect whether certain default buttons are in use. Note that
  * these are for convenience. If you use a custom toolbar class, you can use
  * or ignore these flags, and the default member buttons as well:
  lSubmitButton  = .T.
  cSubmitCaption = "Submit"
  lResetButton   = .T.
  lPreviewButton = .F.    && button to force re-display, even if all is valid
  lCancelButton  = .T.
  * ------------------------------------------------------------------- *
  FUNCTION Form_ACCESS
    RETURN THIS
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION lMultiPart_ACCESS
    * Don't invoke default container's access method:
    RETURN THIS.lMultiPart
  ENDFUNC  && lMultiPart_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION CheckMultiPart
    IF THIS.lMultiPartChecked
      RETURN .T.
    ENDIF
    THIS.lMultiPartChecked = .T.  && so we don't check again
    
    * If the form is multipart, no need to check further:
    IF NOT THIS.lMultiPart
      * Not yet. So check each control's needs.
      LOCAL loObj
      FOR EACH loObj IN THIS.Controls
        IF NOT loObj.lVisible OR loObj.lDisabled OR NOT loObj.lAutoReadInput
          LOOP  && n/a
        ENDIF
        IF loObj.lMultiPart
          THIS.lMultiPart = .T.
          EXIT  && stop looking
        ENDIF
      ENDFOR
      *!*        IF NOT THIS.lMultiPart AND VARTYPE( THIS.oToolbar) = "O"
      *!*          *[[[ Refactor!
      *!*          THIS.lMultiPart = THIS.oToolbar.lMultiPart 
      *!*        ENDIF
    ENDIF
    IF THIS.lMultiPart
      * Need to tell all objects to use multi-part read.
      FOR EACH ii IN THIS.Controls
        THIS.SetAll( "lMultiPart", .T. ) && didn't work for CUSTOM non-container
      ENDFOR
      *!*        IF VARTYPE( THIS.oToolbar) = "O"
      *!*          *[[[ Refactor!
      *!*          THIS.oToolbar.lMultiPart = .T.
      *!*        ENDIF
    ENDIF
  ENDFUNC  && CheckMultiPart
  * ------------------------------------------------------------------- *
  FUNCTION Cancel(lcUrl)
    THIS.lCancelled = .T.
    IF VARTYPE(m.lcUrl) = "C"
      THIS.cCancelUrl = m.lcUrl
    ENDIF
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION ReDisplay
    THIS.lRedisplay = .T.
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION ResetProperties
    THIS.lInvalidControls = .F.
    THIS.nInvalidCount = 0
    THIS.cValidationMessage = ""
    THIS.lPosted = .F.
    THIS.lInputRead = .F.
  ENDFUNC  && ResetProperties
  * ------------------------------------------------------------------- *
  FUNCTION cHtmlName_ACCESS
    * Used for name= attribute of <form> tag.
    IF EMPTY( THIS.cHtmlName)
      THIS.cHtmlName = THIS.cFormName  && defaults to this.name
    ENDIF
    RETURN THIS.cHtmlName
  ENDFUNC  && cHtmlName_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION cFormName_ACCESS
    * Used for hidden FormName variable.
    IF EMPTY( THIS.cFormName)
      THIS.cFormName = LOWER( THIS.Name)
    ENDIF
    RETURN THIS.cFormName
  ENDFUNC  && cFormName_ACCESS
  * ------------------------------------------------------------------- *
  FUNCTION cCancelURL_ASSIGN
    LPARAMETER lcURL
    THIS.cCancelURL = m.lcURL
    *!*      * Send action to special "cancel" button.
    *!*      IF VARTYPE(THIS.btnCancel) = "O"
    *!*        IF EMPTY( m.lcUrl)
    *!*          THIS.btnCancel.cClickUrl = ""
    *!*        ELSE
    *!*          THIS.btnCancel.cClickUrl = THIS.cCancelURL
    *!*        ENDIF
    *!*      ENDIF
  ENDFUNC  && cCancelURL_ASSIGN
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION GarbageCollect
  *!*      DODEFAULT()
  *!*      THIS.oToolbar = NULL
  *!*    ENDFUNC  && GarbageCollect
  * ------------------------------------------------------------------- *
  FUNCTION DoEvents
    IF THIS.WasPosted()
      IF THIS.lCancelled
        IF EMPTY( THIS.cCancelURL)
          ERROR "No URL specified for Cancel action!"
        ELSE
          Response.Redirect( THIS.cCancelUrl)
          RETURN
        ENDIF
      ENDIF
    ELSE
      RAISEEVENT(THIS, "NoPostback")
    ENDIF
  ENDFUNC  && DoEvents
  * ------------------------------------------------------------------- *
  FUNCTION NoPostback
    * Raised by DoEvents() when determined that no postback occurs.
    * Controls can bind to this, if needed.
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION WasPosted(llNoRead)
    * "llNoRead": Optional flag to request check of posting without reading 
    * all form variables. Good for checking if we're processing a
    * submittal in order to decide what controls to use or what session
    * variables to load.
    IF m.llNoRead
      RETURN THIS.PostCheck()
    ENDIF
    * Normal action, which also reads all input:
    IF NOT THIS.lInputRead
      THIS.ReadInput()
      IF THIS.lPosted 
        * Now call any events noted by member objects. These are noted
        * during ReadInput stage.
        *[[ To Do: Should this come before Valid() call or after?
        THIS.DoMemberEvents()
        IF THIS.lSelfValidate AND NOT THIS.lCancelled
          THIS.Valid()
        ENDIF
      ENDIF
    ENDIF
    RETURN THIS.lPosted
  ENDFUNC && WasPosted
  * ------------------------------------------------------------------- *
  PROTECTED FUNCTION PostCheck
    LOCAL lcFormName
    THIS.CheckMultiPart()
    IF THIS.lMultiPart
      lcFormName = Request.GetMultipartFormVar( 'Formname') 
    ELSE
      lcFormName = Request.Form( 'Formname') 
    ENDIF
    THIS.lPostChecked = .T.
    RETURN ( m.lcFormName == THIS.cFormname )
  ENDFUNC  && PostCheck
  * ------------------------------------------------------------------- *
  PROTECTED FUNCTION DoMemberEvents
    IF THIS.nMemberEvents = 0
      * No events noted, so assume default submit event occurred.
      IF NOT EMPTY(THIS.cDefaultEventMember)
        EVALUATE("THIS." + THIS.cDefaultEventMember + ;
          "." + THIS.cDefaultEventMethod + "()")
      ENDIF
    ELSE
      FOR ii = 1 TO THIS.nMemberEvents
        EVALUATE("THIS." + THIS.aMemberEvents[m.ii,1] + ;
          "." + THIS.aMemberEvents[m.ii,2] + "()")
        IF THIS.lCancelled
          EXIT
        ENDIF
      NEXT ii
    ENDIF
  ENDFUNC  && DoMemberEvents
  * ------------------------------------------------------------------- *
  FUNCTION AddMemberEvent(lcMember, lcEvent)
    * Called by controls during the ReadInput stage, when 
    * they detect that the control was the triggering event for the post.
    THIS.nMemberEvents = THIS.nMemberEvents + 1 
    DIMENSION THIS.aMemberEvents[THIS.nMemberEvents,2]
    IF VARTYPE(m.lcMember) = "O"
      THIS.aMemberEvents[THIS.nMemberEvents,1] = m.lcMember.Name
    ELSE
      THIS.aMemberEvents[THIS.nMemberEvents,1] = m.lcMember
    ENDIF
    THIS.aMemberEvents[THIS.nMemberEvents,2] = m.lcEvent
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION WasCancelled
    IF NOT THIS.lInputRead
      THIS.ReadInput()
    ENDIF
    RETURN THIS.lCancelled
  ENDFUNC && WasCancelled
  * ------------------------------------------------------------------- *
  function SetObjectIDs
    IF NOT THIS.lObjectIDsSet
      THIS.lObjectIDsSet = .T.
      LOCAL loControl, lcPrefix
      lcPrefix = THIS.cHtmlName + "_"
      FOR EACH loControl IN THIS.Controls
        if isnull(loControl.cIDPrefix)  && if not null, already explicitly set 
          loControl.cIDPrefix = m.lcPrefix
        endif 
        * Can't use SetAll() becuase containers need to do their own thing.
        * 03/31/2011: noted potential issue with collection controls that don't do this (R&D proposal review bug)
      ENDFOR
    endif
    return 
  endfunc && SetObjectIDs
  * ------------------------------------------------------------------- *
  FUNCTION SetObjectValues
    LOCAL loControl
    FOR EACH loControl IN THIS.Controls
      IF loControl.lVisible = .F.
        LOOP
      ENDIF
      loControl.SetValueIfNeeded()  && Note: grids don't pass-down until under iteration
    ENDFOR
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION CheckDisabling
    LOCAL loControl
    THIS.SetDisabledFlag()
    FOR EACH loControl IN THIS.Controls
      IF THIS.lDisabled && entire form as read-only
        loControl.lDisabled = .T.  && pass-down
        loControl.cDisabledExpression = ""  && prevent control from coming alive
      ELSE
        loControl.SetDisabledFlag()  && Note: grids don't pass-down until under iteration
      ENDIF  
    ENDFOR
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION PrepareObjects()
    IF THIS.lObjectsPrepared = .F.
      * IMPORTANT: Any methods called here may require propagation methods in lower containers.

      THIS.BeforePrepareObjects()  && Good place to override and addobject's().
      
      ** LOCAL loControl
      ** FOR EACH loControl IN THIS.Controls
      **   loControl.BeforePrepareObjects  && possible place to add further objects (in collections or containers)
      ** ENDFOR
      THIS.InitializeToolbar()
      THIS.SetObjectIDs()      && sends prefix down the chain
      THIS.SetObjectValues()   && needed here so context-based disabling works
      THIS.CheckDisabling()
      THIS.CheckMultiPart()
      
      THIS.AfterPrepareObjects()  && should propagate
      ** FOR EACH loControl IN THIS.Controls
      **   loControl.AfterPrepareObjects  && for anything other than adding objects
      ** ENDFOR
      
      THIS.lObjectsPrepared = .T.
    ENDIF
  ENDFUNC  && PrepareObjects( llRead)
  * ------------------------------------------------------------------- *
  FUNCTION ReadInput
    LOCAL ii, lcFormName
    WITH THIS
      .PrepareObjects()
      .lInputRead = .T.
      IF .PostCheck()
        .lPosted = .T.
        FOR EACH ii IN THIS.Controls
          IF m.ii.lDisabled OR NOT m.ii.lVisible
            LOOP
          ENDIF
          m.ii.ReadInput()
          IF m.ii.lUpdated
            .lUpdated = .T.
          ENDIF
        ENDFOR
        .AfterReadInput()  && added
      ELSE
        .lPosted = .F.
      ENDIF
    ENDWITH
  ENDFUNC  && ReadInput
  * ------------------------------------------------------------------- *
  FUNCTION WasChanged
    * This should not be used, since ReadInput() now
    * calculates the lUpdated flag along the way!
    LOCAL llReturn, ii
    FOR EACH ii IN THIS.Controls
      IF NOT ii.lAutoReadInput OR NOT m.ii.lHasContent
        LOOP  && don't count button clicks, etc., as changes!
      ENDIF
      IF ii.lVisible = .T. AND ii.WasChanged()
        llReturn = .T.
        EXIT
      ENDIF
    ENDFOR
    RETURN m.llReturn
  ENDFUNC  && WasChanged
  * ------------------------------------------------------------------- *
  FUNCTION Valid
    IF NOT THIS.lPostChecked
      ERROR "Valid method cannot be called before DoEvents or WasPosted!"
    ENDIF
    IF NOT THIS.lPosted 
      RETURN .F.
    ENDIF
    IF THIS.lCancelled
      RETURN .F.
    ENDIF
    IF NOT THIS.lValidated  && not already called (when lSelfValidate is .F.)
      LOCAL llValid  && , llToolbarValid 
      RAISEEVENT(THIS, "WouldValidate", THIS)
      llValid = DODEFAULT()  && call container's method
      *!*        llToolbarValid = .T.
      *!*        IF VARTYPE( THIS.oToolbar) = "O"
      *!*          *[[[ Refactor!
      *!*          llToolbarValid = THIS.oToolbar.VALID()
      *!*        ENDIF
      IF NOT m.llValid  && OR NOT m.llToolbarValid 
        THIS.lInvalidControls = .T.
      ENDIF
      RAISEEVENT(THIS, "DidValidate", THIS)
      THIS.lValidated = .T.
    ENDIF
    RETURN THIS.lPosted AND NOT THIS.lCancelled AND NOT THIS.lRedisplay AND ;
      THIS.nInvalidCount = 0 AND NOT THIS.lInvalidControls
  ENDFUNC  && Valid
  * ------------------------------------------------------------------- *
  FUNCTION WouldValidate(loSelf)
    RETURN 
  ENDFUNC
  FUNCTION DidValidate(loSelf)
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION UpdateControlSources
    IF THIS.lCancelled
      ERROR "Attempt to update control sources after form was cancelled!"
      RETURN .F.
    ENDIF
    IF NOT THIS.lValidated
      ERROR "Cannot update data source without validating input!"
    ENDIF
    LOCAL llRetVal
    llRetVal = .T.
    * Set control source type for all controls:    
    THIS.SetAll( "cControlSourceType", THIS.cControlSourceType)
    IF VARTYPE( THIS.oToolbar) = "O"
      THIS.oToolbar.cControlSourceType = THIS.cControlSourceType
      * (We really need to tell the Toolbar also, because some people
      * want to throw some actual controls on the toolbar.)
      *
      * [[[ Why can't the toolbar handle this in the SetAll? OIC, because the 
      * toolbar isn't in Form.Controls as a member. Hmmm....
    ENDIF
    
    llRetVal = m.llRetVal AND DODEFAULT()  && call container
    IF VARTYPE( THIS.oToolbar) = "O"
      *[[[ Refactor!
      llRetVal = m.llRetVal AND THIS.oToolbar.UpdateControlSources()
    ENDIF

    RETURN m.llRetVal
  ENDFUNC  && UpdateControlSources
  * ------------------------------------------------------------------- *
  FUNCTION ShowOutput
    * Command window debugging option do see actual HTML rendered.
    LOCAL lcText, lnSelect, lcAlias
    lcText = THIS.GetOutput()
    lnSelect = SELECT()
    lcAlias = "C" + SYS(3)
    SELECT 0
    CREATE CURSOR &lcAlias ( Html_Output M )
    APPEND BLANK 
    REPLACE Html_Output WITH m.lcText
    MODIFY MEMO Html_Output NOWAIT NOEDIT
    SELECT ( m.lnSelect )
  ENDFUNC  && ShowOutput
  * ------------------------------------------------------------------- *
  FUNCTION RenderOrphanOutput
    * Convenience method to get any output of "forgotten" objects.
    * Handy when using visual design tools and rendering controls
    * individually, to ensure you have not 
    * forgotten to display any controls.
    LOCAL lcText
    lcText = ""
    FOR EACH ii IN THIS.Controls
      IF m.ii.lAutoRender = .F.
        * Control not designated to render itself automatically.
        LOOP
      ENDIF
      IF VARTYPE( m.ii.lOutputCreated) <> "L"  && not one of ours
        LOOP
      ENDIF
      IF m.ii.lOutputCreated  && A-OK
        LOOP
      ENDIF
      IF NOT m.ii.lVisible OR m.ii.lDisabled
        LOOP
      ENDIF
      lcText = m.lcText + L7BR + m.ii.Render() + L7BR + CR
    ENDFOR 
    RETURN m.lcText
  ENDFUNC  && RenderOrphanOutput
  * ------------------------------------------------------------------- *
  FUNCTION InitializeToolbar
    IF VARTYPE(THIS.Toolbar) <> "O" AND NOT EMPTY(THIS.cToolbarClass)
      THIS.AddObject("Toolbar", THIS.cToolbarClass)
      THIS.AfterInitializeToolbar()
    ENDIF
    RETURN .T.
  ENDFUNC && InitializeToolbar
  * ------------------------------------------------------------------- *
  FUNCTION AfterInitializeToolbar
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION AddDefaultJavaScript
    LOCAL lcTxt
    IF THIS.lPreventMultipleSubmissions
      *!*        TEXT TO lcTxt NOSHOW
      *!*        function L7singleSubmit(loForm)
      *!*        { if (loForm.nSubmitCount) 
      *!*          {  alert("Already submitted!"); 
      *!*             return false;
      *!*          }
      *!*          else 
      *!*          { loForm.nSubmitCount = 1; 
      *!*            return true; 
      *!*          }
      *!*        }
      *!*        ENDTEXT
      *!*        THIS.AddJavaScript(m.lcTxt)
      IF EMPTY(THIS.cOnSubmit)
        THIS.cOnSubmit = "L7singleSubmit(this)"
      ELSE  && combine it with existing function
        IF RIGHT(THIS.cOnSubmit,1) = ";"
          THIS.cOnSubmit = THIS.cOnSubmit + ;
            [if (L7singleSubmit(this) == false) return false;]
        ELSE
          THIS.cOnSubmit = THIS.cOnSubmit + CHR(38) + CHR(38) + ;
            [L7singleSubmit(this)]
        ENDIF
      ENDIF
    ENDIF
  ENDFUNC  && AddDefaultJavaScript
  * ------------------------------------------------------------------- *
  FUNCTION Render    && L7Form
    THIS.PrepareObjects()
    THIS.AddDefaultJavaScript()
    IF EMPTY( THIS.cRenderClass)
      THIS.cRenderClass = "L7FormRenderOverUnder"
    ENDIF
    RETURN DODEFAULT()
  ENDFUNC  && Render
  *!*    * ------------------------------------------------------------------- *
  *!*    FUNCTION GetOutput
  *!*      RETURN THIS.Render()
  *!*    ENDFUNC  && GetOutput
  * ------------------------------------------------------------------- *
  FUNCTION FormOpen()
    LOCAL lcText
    lcText = ""
    lcText = m.lcText + CR + [<!-- BEGIN: HTML Form       -->] + CR
    lcText = m.lcText + [<form]
    lcText = m.lcText + ;
      IIF( EMPTY( THIS.cFormCssClass), [], [ class="] + THIS.cFormCssClass + ["] ) + ;
      IIF( EMPTY( THIS.cFormCssStyle), [], [ style="] + THIS.cFormCssStyle + ["] )

    lcText = m.lcText + [ name="] + THIS.cFormName + ["]
    lcText = m.lcText + [ id="] + THIS.GetID() + ["]
    lcText = m.lcText + [ method="] + THIS.cMethod + ["]
    IF NOT EMPTY(THIS.cOnSubmit)
      lcText = m.lcText + [ onSubmit="] + THIS.cOnSubmit + ["]
    ENDIF
    IF NOT EMPTY(THIS.cOnReset)
      lcText = m.lcText + [ onReset="] + THIS.cOnReset + ["]
    ENDIF
    IF THIS.lMultiPart
      lcText = m.lcText + [ enctype="multipart/form-data"]
    ENDIF
    lcText = m.lcText + THIS.GetAction() && action="form_action" clause
    IF NOT EMPTY( THIS.cTarget )
      * Allow submission to a different frame/window.
      lcText = m.lcText + [ target="] + THIS.cTarget + ["]
    ENDIF
    lcText = m.lcText + [>] + CR
    IF NOT THIS.lNoFormname
      lcText = m.lcText + [<input type="hidden" name="FormName"] + ;
        [ value="] + THIS.cFormName + [" />] + CR
    ENDIF
    RETURN m.lcText
  ENDFUNC  && FormOpen
  * ------------------------------------------------------------------- *
  FUNCTION GetAction
    * Note action="" is needed to validate. 
    * Also, Netscape 4.x (and others) generate 405 error if left blank, so
    *   we need to guess from the Page info, if not provided.
    IF EMPTY(THIS.cAction)
      IF VARTYPE(m.Page) = "O"
        THIS.cAction = Page.cUrlB
      ENDIF
    ENDIF
    RETURN [ action="] + THIS.cAction + ["]
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION FormClose()
    RETURN [</form>] + ;
      CR + [<!-- END: HTML Form       -->] + CR
  ENDFUNC  && FormClose
  * ------------------------------------------------------------------- *
  FUNCTION OpenWrapperTag
    RETURN [<] + THIS.cWrapperTag + ;
      IIF(EMPTY(THIS.cCssClass), [], [ class="] + THIS.cCssClass + ["]) + ;
      IIF(EMPTY(THIS.cCssStyle), [], [ style="] + THIS.cCssStyle + ["]) + ;
      IIF(EMPTY(THIS.cAlign), [], [ align="] + THIS.cAlign + ["]) + ;
      IIF(ISNULL(THIS.nCellSpacing), [], [ cellspacing="] + TRANSFORM(THIS.nCellSpacing) + ["]) + ;
      IIF(ISNULL(THIS.nBorder), [], [ border="] + TRANSFORM(THIS.nBorder) + ["]) + ;
      [>] + CR
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION CloseWrapperTag
    RETURN [</] + THIS.cWrapperTag + [>] + CR
  ENDFUNC
  * ------------------------------------------------------------------- *
  FUNCTION XMLToFormVars
    LPARAMETERS lcXml
    
    ERROR "All XML functionality temporarily suspended pending a rewrite."
    THIS.cXml = m.lcXml
    LOCAL ii
    FOR EACH ii IN THIS.Controls
      IF NOT m.ii.lVisible OR NOT m.ii.lAutoReadInput
        LOOP
      ENDIF
      = m.ii.XMLInput( m.lcXml)
    ENDFOR
  ENDFUNC  && XMLToFormVars
  * ------------------------------------------------------------------- *
  FUNCTION FormVarsToXML

    ERROR "All XML functionality temporarily suspended pending a rewrite."
    LOCAL lcXml
    lcXml = [<FormVars>] + CR
    FOR EACH ii IN THIS.Controls
      IF NOT m.ii.lVisible OR NOT m.ii.lAutoReadInput
        LOOP
      ENDIF
      lcXml = m.lcXml + [  ] + m.ii.XMLOutput() + CR
    ENDFOR

    RETURN m.lcXml + [</FormVars>] + CR
  ENDFUNC  && FormVarsToXML
  * ------------------------------------------------------------------- *
ENDDEFINE  && Class L7Form

#if .f.
04/22/2003 - included action="" in <form> even when empty
05/06/2003 - deleted GetOutput() method -- looked potentially circular if called
05/10/2003 - removed JS code for L7singleSubmit, which is now in file "L7Core.js"
08/04/2003 - added cValidationHeading property
10/02/2003 - Revised FormOpen() to call GetAction(), which defaults the action= setting if empty.
12/14/2003 - Revised ReadInput() to call AfterReadInput() for the form itself.
#endif


* ==================================================================== *
* FILE END: L7Form.PRG
