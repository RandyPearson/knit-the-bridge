* L7PageElement.PRG
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


#if .f.

PAGE ELEMENT INTRODUCTION

L7PageElement is the base class for creating classes that produce fragments of
HTML content, which can be combined by any end use application for inclusion in
larger HTML "pages" or server-created "responses".

A page element can be produced either by *streaming* text into it externally via
the Write()/WriteLn() methods, or by the use of various "template" techniques. This
option is either-or for any element (although elements of different types can be
easily combined into larger elements and eventually a complete page), and is 
specified via the setting of the boolean "lTextStream" property.

When not using streaming text, the various properties with prefix of "cSource"
are used to control the source HTML and how it is transformed to produce output.
For example, you can control whether the source of any template expansion comes
from (1) metadata, (2) file on disk, or (3) directly via a passed string.

Beyond the setting of these properties, the fundamental extensibility of the
page element is achieved via use of a standard "template method" design pattern.
Briefly, what happens is that page element objects provide their output when their
host objects call their high-level Render() method; whereas you develop subclasses
by creating a lower-level RenderImplementation() method. The Render() method takes 
care of calling this method for you, but it also evokes optional hooks such as
BeforeRender() and AfterRender(), which you can also use for powerful features, such
as performance-based caching or partial page content.

Some example subclasses are found in L7PageElements.PRG (note the plural!).

#endif

*** ========================================================= ***
DEFINE CLASS L7PageElement AS CONTAINER

  lTextStream    = .T.   && indicates whether content comes from async .Write() calls,
                         && or whether all is created in one expansion (template/script/plain)
  lUseMetaData   = .F.
  
  * See access methods for next 4 properties:
  cSourcePath          = NULL  && path to either source files or snippets table
  cSourceName          = NULL  && name or ID of source file to expand 
  cSourceExtension     = NULL  && file extension (defaults to Page.oApp.cPageExtension)
  cSourceAlias         = NULL  && for metadata approach -- default is Page.oApp.cApplication + "Snippets.DBF"
  cSource              = NULL  && actual source to expand [can set directly via SetSource()]
  cSourceType          = [textmerge] && {[plain], [textmerge], [template], [script]}
  cExpandTemplateClass = "L7ExpandTemplate"  && bridge
  lSafeTextmerge       = .F.   && cause "safe" textmerge (eval's) to be performed, avoiding recursion
  cTextMergeDelim1     = L7_TEXTMERGE_DELIM_1
  cTextMergeDelim2     = L7_TEXTMERGE_DELIM_2
                         
  * cTag applies, irrespective of lTextStream flag or cSourceType:
  cTag             = "div" && (optional) tag to wrap around rendered output (see ApplyTag method)
  
*[[RP: hate the fact that cTag defaults to "div", forcing pass in of "" for a plain element ...
*[[ ...wonder what would break if we changed it?
  
  cAttributes      = ""    && attributes for cTag
  cID              = null  && was "", which now means "no ID please", null means assigned from Page ID Service in this.INIT
  cTagLanguage     = ""    && allow tag-specific lang="" settings (when different from page)
  cCssClass        = ""    && used if cTag is specified
  cCssStyle        = ""    &&   - same -
  lApplyTagIfEmpty = .F.   && if no inner-text, should we provide the outer tag, or just render ""?
  nSubIDCount      = 0
  
  ** PROTECTED cText  && must use Render() to access this
  cText          = ""

  cPreText       = ""  && after opening tag, but before other rendered content
  cPostText      = ""  && before closing tag

  ** PROTECTED cResult
  cResult        = ""    && holding tank for PreRender() results
  lRendered      = .F.   && set by PreRender() 
  lCancelled     = .F.
  cAltReturnText = "" && override object rendering entirely 
  
  * Convenience properties. Only apply if used in your subclasses:
  cParseOnViewChainID = [L7ParseOnViewChain]   && key (usually class name) for parse manager to use for view parsing
  lSuppressParsing    = .T.                    && use this to call the parsing off (over rides on an element by element basis)
  lFinalOutput        = .F.                    && set to .t. for highest content object, used to trigger perf log links etc.
  lCacheContent       = .F.                    && if .t., content will be cached

  * Dummy properties - implemented with ACCESS or ASSIGN methods:
  Expires             = NULL  && see assign method (included for ASP-like syntax compatibility: Response.Expires)
  CurrentOutputObject = NULL  && see ACCESS method
  Generator           = NULL
  * --------------------------------------------------------- *
  FUNCTION CurrentOutputObject_ACCESS
    * This is provided mainly for body-level classes that might implement 2-3 nested
    * elements (say, a menu and content area), allowing the parent object to point
    * an external source to where "live" content should be directed. This is used to
    * repointer a PRIVATE Response variable, thus allowing Response.Write() to be 
    * used without worrying about the actual composition of the page objects. See
    * L7BodyElement.PRG for examples.
    RETURN THIS
    * Can override in subclass if you want output directed to a nested object.
  ENDFUNC  && CurrentOutputObject_ACCESS
  * --------------------------------------------------------- *
  FUNCTION Expires_ASSIGN(lvValue)
    Page.SetExpires( m.lvValue )
  ENDFUNC  && Expires_ASSIGN
  * --------------------------------------------------------- *
  function INIT(tcId, tcTag, tcClass)  && 2nd-3rd props new 02/13-16/2010
    if isnull(m.tcId)
      this.cId = null
    else
      if vartype(m.tcId) = "C"
        this.cId = m.tcId
      endif
    endif 
    if isnull(this.cId) && either set or by default
      this.setID()
    endif
    if vartype(m.tcTag) = "C"
      this.cTag = m.tcTag
    endif
    if vartype(m.tcClass) = "C"
      this.SetClass(m.tcClass)
    endif
      
    this.AfterInit() && accomodate object setup via scripting/metadata
    return 
  endfunc  && INIT
  * --------------------------------------------------------- *
  FUNCTION AfterInit
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION CreateElement(lcClass) && factory
    LOCAL loObj, lcId
    THIS.nSubIDCount = THIS.nSubIDCount + 1 
    if isnull(this.cID)
      lcId = null && if parent ID is null, don't try to force an ID on offspring
    else 
      lcId = THIS.cID + "_" + TRANSFORM(THIS.nSubIDCount)
    endif 
    loObj = CREATEOBJECT(m.lcClass, m.lcId)
    RETURN m.loObj
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetID(lcId)
    LOCAL llManual
    IF EMPTY(THIS.cID) 
      IF VARTYPE(m.Page) = "O"
        TRY  && to get ID assignment from Page service
          THIS.cID = m.Page.cNextID
        CATCH
          llManual = .T.
        ENDTRY
      ELSE
        llManual = .T.
      ENDIF
    ENDIF
    IF m.llManual
      THIS.cID = "pe" + SYS(2015)
    ENDIF    
    RETURN 
  ENDFUNC  && SetID
  * --------------------------------------------------------- *
  FUNCTION Release
    THIS.GarbageCollect()
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GarbageCollect
  ENDFUNC  && GarbageCollect
  * --------------------------------------------------------- *
  FUNCTION DESTROY
    THIS.GarbageCollect()
    RETURN 
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION lCancelled_ASSIGN(llCancel)
    THIS.lCancelled = m.llCancel
    IF m.llCancel
      THIS.CancelChildren()
    ENDIF
    RETURN 
  ENDFUNC  && lCancelled_ASSIGN
  * --------------------------------------------------------- *
  function SetClass(tcCls)
    if m.tcCls = "+" && augment
      this.cCssClass = ltrim(this.cCssClass + " ") + ltrim(substr(m.tcCls, 2))
    else
      this.cCssClass = m.tcCls
    endif
    return 
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION CancelChildren
    LOCAL loControl
    FOR EACH loControl IN THIS.Controls
      IF PEMSTATUS(loControl, "lCancelled", 5)
        loControl.lCancelled = .T.
      ENDIF
    ENDFOR
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Clear(llNoCancelChidren)
    THIS.cText = ""
    THIS.lRendered = .F.
    THIS.cResult = ""
    LOCAL loControl
    IF m.llNoCancelChidren  && just clear
      FOR EACH loControl IN THIS.Controls
        IF PEMSTATUS(loControl, "Clear", 5)
          loControl.Clear()
        ENDIF
      ENDFOR
    ELSE
      THIS.CancelChildren()
    ENDIF
    RETURN 
  ENDFUNC  && Clear
  * --------------------------------------------------------- *
  FUNCTION PreRender(llPreRenderChildren)
    * For debugging, or to adjust timing, or for items 
    * that are rendered more than once.
    IF m.llPreRenderChildren
      * If child objects need to be _separately_ pre-rendered (for debugging).
      LOCAL loControl
      FOR EACH loControl IN THIS.Controls
        loControl.PreRender(.T.)
      ENDFOR
    ENDIF
    * Normal behavior is just:
    THIS.cResult = THIS.Render()
    THIS.lRendered = .T. && so we don't need to render twice
    RETURN 
  ENDFUNC  && PreRender
  * --------------------------------------------------------- *
  FUNCTION Render
    IF THIS.lCancelled  && something cancelled me -- don't question authority!
      RETURN ""
    ENDIF
    IF THIS.lRendered = .T.
      RETURN THIS.cResult
    ENDIF
    IF NOT EMPTY(THIS.cAltReturnText)
      RETURN THIS.cAltReturnText
    ENDIF
    PRIVATE Element
    Element = THIS && allows templates to reference <<Element.something>>
    LOCAL lcText AS String
    ** lcText = THIS.cPreText && cannot do this, because it gets wrapped inside tag
    lcText = ""
    IF THIS.BeforeRender(@lcText)  && standard blocking hook pattern for text-returning methods
      THIS.RenderImplementation(@lcText) && bi-modal approach, based on streaming flag
      THIS.ApplyTag(@lcText)    && if this.cTag is empty, nothing happens here
      THIS.AfterRender(@lcText) && post-processing hook
    endif
    if not empty(this.cPreText)
      lcText = this.cPreText + m.lcText
    endif 
    RETURN m.lcText + THIS.cPostText
  ENDFUNC  && Render    
  * --------------------------------------------------------- *
  FUNCTION BeforeRender(lcText)  && Blocking hook.
    * Notes: 
    *  1. lcText is passed by reference (starts life as "").
    *  2. To add *beginning* text, but not affect other rendering,
    *     concatenate to lcText and then RETURN .T..
    *  3. To *replace* the role of normal rendering (blocking hook)
    *     set lcText as desired and RETURN .F.. (Also see next note.)
    *  4. If you implement AfterRender also, this is NOT always called,
    *     so if AfterRender applies when BeforeRender blocks, you need 
    *     to call it explicitly in BeforeRender before returning .F..
    *  5. To ignore anything in cPostText, set that to "" in Before or After.
    *  6. To ignore anything in cPreText, re-initialize lcText to "" in Before.
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    * You can:
    * a) Override RenderImplementation and still call DoDefault(@lcText).
    * b) Override and not call DoDefault.
    * c) Turn off the cTag property.
    * d) (Extreme) override Render() template entirely.
    IF THIS.lTextStream  && streaming output
      lcText = m.lcText + THIS.cText
    ELSE  && expand source content
      lcText = m.lcText + THIS.ExpandSource()
    ENDIF
    RETURN
  ENDFUNC  && RenderImplementation
  * --------------------------------------------------------- *
  FUNCTION ApplyTag(lcText)
    * Wrap with optional element tag.
    IF NOT EMPTY(THIS.cTag)
      IF THIS.lApplyTagIfEmpty OR NOT EMPTY(m.lcText) && only wrap with tag when there's any content
        lcText = ;
          [<] + THIS.cTag + ;
            IIF(EMPTY(THIS.cTagLanguage), [], [ lang="] + THIS.cTagLanguage + ["]) + ;
            IIF(EMPTY(nvl(THIS.cID,"")), [], [ id="] + THIS.cID + ["]) + ;
            IIF(EMPTY(THIS.cCssClass), [], [ class="] + THIS.cCssClass + ["]) + ;
            IIF(EMPTY(THIS.cCssStyle), [], [ style="] + THIS.cCssStyle + ["]) + ;
            IIF(EMPTY(THIS.cAttributes), [], [ ] + THIS.cAttributes ) + ;
          [>] + ;      && removed CRLF here - some tags may have bad "behavior"
          m.lcText + ; && removed CRLF here - some tags may have bad "behavior"
          [</] + THIS.cTag + [>] + CRLF 
      ENDIF
    ENDIF
    RETURN
  ENDFUNC  && ApplyTag
  * --------------------------------------------------------- *
  FUNCTION AfterRender(lcText)  && Post-processing hook.
    * Notes:
    * 1. See BeforeRender notes!
    * 2. You can call DODEFAULT, or completely override the
    *    following.
    *!*      IF NOT EMPTY(THIS.cEndText) AND NOT (Page.lError OR Page.lErrorMsg)
    *!*        lcText = m.lcText + THIS.cEndText
    *!*      ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ExpandSource
    LOCAL lcSource, lcSourceType
    lcSourceType = LOWER(THIS.cSourceType)
    lcSource = THIS.GetSource(@lcSourceType)  && hook, if needed
    DO CASE
    CASE m.lcSourceType == [textmerge]  && easiest
      IF THIS.lSafeTextmerge
        ** RETURN L7SafeMergeText(m.lcSource)
        RETURN SafeTextmerge(m.lcSource, THIS.cTextMergeDelim1, THIS.cTextMergeDelim2)
      ELSE
        RETURN TEXTMERGE(m.lcSource)
      ENDIF
    CASE m.lcSourceType == [template]  
      RETURN THIS.ExpandTemplateSnippet(m.lcSource, .F., .T.)
    CASE m.lcSourceType == [script]  
      RETURN THIS.ExpandScriptSnippet(m.lcSource, .F., .T.)
    CASE m.lcSourceType == [plain]  && straight content pass-thru
      RETURN m.lcSource
    OTHERWISE
      ERROR "Unknown element source type: " + TRANSFORM(THIS.cSourceType)
    ENDCASE
    RETURN
  ENDFUNC  && ExpandSource
  * --------------------------------------------------------- *
  FUNCTION cSourcePath_ACCESS
    * Get path from app, unless specified.
    * Note: if your PATH includes these files, set cSourcePath to "".
    IF ISNULL(THIS.cSourcePath) && not NVL(), 'cause we don't want alternative to be hit
      IF VARTYPE(m.Page) = "O"
        RETURN ADDBS(m.Page.oApp.oConfig.cHtmlPagePath)
      ELSE  && out of ideas
        RETURN ""
      ENDIF
    ENDIF
    RETURN ADDBS(THIS.cSourcePath)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cSourceName_ACCESS
    IF THIS.cSourceName == "[page]" && note brackets: meaning is "use whatever the page name is"
      * Useful when you have one template per page class with matching names.
      RETURN m.Page.oApp.cActivePage
    ELSE
      RETURN NVL(THIS.cSourceName, THIS.Name) && if we don't specify a file name, assume same as object name
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cSourceExtension_ACCESS
    * Get extension from app, unless specified.
    LOCAL lcExt
    lcExt = THIS.cSourceExtension
    IF ISNULL(m.lcExt)
      lcExt = m.Page.oApp.cPageExtension && see if app has but one
      IF EMPTY(m.lcExt)
        lcExt = m.Page.oApp.cActivePageExtension
      ENDIF 
    ENDIF
    RETURN m.lcExt
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cSourceAlias_ACCESS
    * Get metadata alias from app, unless specified.
    IF ISNULL(THIS.cSourceAlias)
      RETURN m.Page.oApp.cApplication + "Snippets"
    ENDIF
    RETURN THIS.cSourceAlias
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetSource(lcType AS String) AS String
    * Fetch template source (markup), optionally "adjusting" the 
    * type (which is passed by reference).
    IF NOT ISNULL(THIS.cSource)  && must have been set directly via SetSource()
      RETURN THIS.cSource
    ELSE
      IF THIS.lUseMetaData
        RETURN THIS.GetSourceFromMetaData(@lcType)
      ELSE  && actual file
        RETURN THIS.GetSourceFromFile(@lcType)
      ENDIF
    ENDIF
  ENDFUNC  && GetSource
  * --------------------------------------------------------- *
  FUNCTION SetSource(lcSource AS String) AS VOID
    THIS.lTextStream = .F.  && ensure source is used
    THIS.cSource     = m.lcSource
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetSourceFile( tcFile )
    * high-level function to set source file properties from a full path
    WITH THIS
      .lTextStream       = .F.  && ensure file is used
      .cSourcePath       = JUSTPATH(m.tcFile)
      .cSourceName       = JUSTSTEM(m.tcFile)
      .cSourceExtension  = JUSTEXT(m.tcFile)
    ENDWITH 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION GetSourceFromMetaData(lcType AS String) AS String
    LOCAL lcSource AS String
    lcSource = ""
    LOCAL lnSelect, lcName
    lnSelect = SELECT()
    IF NOT USED(THIS.cSourceAlias)
      * This really should be opened by the application object.
      SELECT 0
      USE (THIS.cSourcePath + THIS.cSourceAlias) AGAIN 
    ELSE
      SELECT (THIS.cSourceAlias)
    ENDIF
    lcName = UPPER(PADR(THIS.cSourceName, LEN(SourceName)))
    LOCATE FOR UPPER(SourceName) = m.lcName
    IF FOUND()
      lcSource = SourceText
    ELSE
      ERROR "Source record not found for " + m.lcName
    ENDIF
    SELECT (m.lnSelect)
    RETURN m.lcSource
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetSourceFromFile(lcType AS String) AS String
    LOCAL lcSource AS String
    lcSource = ""
    LOCAL lcFile
    lcFile = FORCEEXT( THIS.cSourcePath + THIS.cSourceName, THIS.cSourceExtension)
    IF FILE(m.lcFile)
      lcSource = FILETOSTR(m.lcFile)
    ELSE
      ERROR "Source file not found for " + THIS.cSourceName
    ENDIF
    RETURN m.lcSource
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Write(lcText)
    * CAUTION: See parallel function WriteLn. Be sure any changes
    * made here are also made there!
    
    DO CASE
    CASE VARTYPE( m.lcText ) = "C"
      THIS.cText = THIS.cText + m.lcText
    CASE VARTYPE( m.lcText ) = "O" AND PEMSTATUS(m.lcText, "RENDER", 5)
      THIS.cText = THIS.cText + m.lcText.Render()
    OTHERWISE
      THIS.cText = THIS.cText + TRANSFORM( m.lcText )
    ENDCASE
    RETURN
  ENDFUNC  && Write
  * --------------------------------------------------------- *
  FUNCTION WriteLn(lcText)
    * Same as Write but with a carriage return at the end.
    * So frequently-used that it modifies text directly, rather
    * than calling Write. Be sure we make any changes in both.
    DO CASE
    CASE VARTYPE( m.lcText ) = "C"
      THIS.cText = THIS.cText + m.lcText + CRLF
    CASE VARTYPE( m.lcText ) = "O" AND PEMSTATUS(m.lcText, "RENDER", 5)
      THIS.cText = THIS.cText + m.lcText.Render() + CRLF
    OTHERWISE
      THIS.cText = THIS.cText + TRANSFORM( m.lcText ) + CRLF
    ENDCASE
    RETURN
  ENDFUNC  && WriteLn
  * --------------------------------------------------------- *
  FUNCTION WriteTag(lcText, lcTag, lcClass, lcStyle, llSkipIfEmpty)
    IF EMPTY(m.lcTag) AND m.llSkipIfEmpty
      RETURN ""
    ENDIF
    WITH THIS
      .Write([<] + LOWER(m.lcTag) + ;
        IIF(EMPTY(m.lcClass), [], [ class="] + m.lcClass + ["]) + ;
        IIF(EMPTY(m.lcStyle), [], [ style="] + m.lcStyle + ["]) + ;
        [>])
      .Write(m.lcText)
      .Write([</] + LOWER(m.lcTag) + [>] + CRLF)
    ENDWITH
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION WriteMemo(lcText)
    * Like Write(), but translates CR's to <P>'s and <BR>'s as 
    * needed for formatting. 
    IF VARTYPE( m.lcText ) = "C"
      lcText = STRTRAN( m.lcText, CRLF + CRLF, [<p>] )
      lcText = STRTRAN( m.lcText, CRLF, L7BR )
    ENDIF
    THIS.Write( m.lcText)
    RETURN
  ENDFUNC  && WriteMemo
  * --------------------------------------------------------- *
  FUNCTION WriteComment( lcText )
    THIS.Write( [<!-- ] + m.lcText + [ -->] + CRLF)
    RETURN 
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION ExpandTemplateSnippet(lcScript, lcInFile, llReturnString)
    * Expands a template "snippet" -- a portion of a full page.
    * Extracts anything inside of BODY tags and discards balance,
    * placing result in current context object. 
    * [For full-page support, including options for <head>
    * section support, use Page.ExpandTemplate().]
    LOCAL loET
    IF VARTYPE( m.lcInFile) = "C" 
      IF FILE( m.lcInFile )
        lcScript = FILETOSTR(m.lcInFile)
      ELSE
        ERROR [Script file "] + m.lcInFile + [" was not found.]
        RETURN
      ENDIF
    ENDIF
    THIS.PreprocessSnippet(@lcScript)
    loET = CREATEOBJECT(THIS.cExpandTemplateClass)
    WITH loET
      .lSafeTextmerge = THIS.lSafeTextmerge
      .SetDelimiters(THIS.cTextMergeDelim1, THIS.cTextMergeDelim2)
      .MergeText(@lcScript)
      IF NOT m.llReturnString  && just stream to cText
        THIS.cText = THIS.cText + m.lcScript
        RETURN
      ELSE
        RETURN m.lcScript
      ENDIF
    ENDWITH
    RETURN 
  ENDFUNC  && ExpandTemplateSnippet
  * --------------------------------------------------------- *
  FUNCTION PreprocessSnippet(lcScript)
    LOCAL lnAt1, lnAt2, lnAt3
    lnAt1 = ATC("<body", m.lcScript)
    IF m.lnAt1 > 0
      * ... [strip]
      lnAt2 = AT('>',SUBSTR(m.lcScript,m.lnAt1))
      IF m.lnAt2 > 0
        lnAt3 = ATC("</body>",m.lcScript)
        IF m.lnAt3 > m.lnAt1
          lcScript = SUBSTR(m.lcScript, m.lnAt1 + m.lnAt2, lnAt3 - (m.lnAt1 + m.lnAt2))
        ELSE
          lcScript = SUBSTR(m.lcScript, m.lnAt1 + m.lnAt2)
        ENDIF
      ENDIF
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ExpandScriptSnippet(lcScript, lcInFile, llReturnString)
    * Runs a section of script through CodeBlock
    * and appends an evaluated string to cText property.
    LOCAL loCB, lcOutFile, loOldResponse, llExecute, lcResult
    llExecute = .T.
    IF VARTYPE( m.Response) = "U"
       PRIVATE Response
    ELSE
      loOldResponse = m.Response
    ENDIF
    Response = CREATEOBJECT( "L7CodeblockCompanion" )
    loCB = CREATEOBJECT( "L7CodeBlock" )
    lcOutFile = ADDBS( SYS(2023)) + SYS(3) + "_CodeBlock_Output.TMP"
    DO CASE
    CASE VARTYPE( m.lcScript) = "C"
      loCB.SetCodeBlock( m.lcScript )
    CASE VARTYPE( m.lcInFile) = "C" 
      IF FILE( m.lcInFile )
        loCB.SetCodeBlock( FILETOSTR( m.lcInFile ) )
      ELSE
        ERROR [Script file "] + m.lcInFile + [" was not found.]
        RETURN
      ENDIF
    OTHERWISE
      llExecute = .F.
    ENDCASE

    IF m.llExecute
      loCB.lScript = .T.

      SET TEXTMERGE TO ( m.lcOutFile ) ADDITIVE NOSHOW
      SET TEXTMERGE ON
      loCB.Execute()
      SET TEXTMERGE OFF
      SET TEXTMERGE TO

      IF loCB.lError
        **lcResult = loCB.GetErrorContext()
        lcResult = ;
          [<h2 align="center">Script Error</h2>] + ;
          [<p>No: ] + STR( loCB.nError ) + [</p>] + ;
          [<p>] + loCB.cErrorMessage + [</p>] 
      ELSE
        lcResult = FILETOSTR( m.lcOutFile )
      ENDIF
      ERASE ( m.lcOutFile )
    ENDIF
    Response = NULL
    Response = m.loOldResponse
    IF NOT m.llReturnString  && just stream to cText
      THIS.cText = THIS.cText + m.lcResult
      RETURN
    ELSE
      RETURN m.lcResult
    ENDIF
  ENDFUNC  && ExpandScriptSnippet
  * --------------------------------------------------------- *
  FUNCTION End
    * Included for ASP syntax compatability.
    * Causes immediate termination of script processing.
    * [[Could just set a flag so no more output is written, but allow other 
    *   script processing.  See what ASP does. No, this is correct, in
    *   ASP, no further script is processed.]]
    #IF L7_WC_FRAMEWORK
      RETURN TO ExecuteRequest
    #ENDIF
    RETURN
  ENDFUNC  && End
  * --------------------------------------------------------- *
  FUNCTION Redirect(lcUrl)
    * Included here to allow Response.Redirect() syntax.
    #IF L7_WC_FRAMEWORK
      Page.Redirect( m.lcUrl)
    #ENDIF
    RETURN
  ENDFUNC 

ENDDEFINE  && L7PageElement

#if .f.
01/14/2003 - added preRender(), renamed lTextSent to lRendered, adjusted purpose of that flag
01/18/2003 - changed cElement to cTag
           - removed RenderSimple() and put tag wrapping in ApplyTag()
           - changed Render() to call ApplyTag() directly
           - changed PreRender() to it also calls PreRender() on all children (for each)
01/19/2003 - fixed bug in ApplyTag that caused duplicate text
05/06/2003 - removed old code in AfterRender() and made it an empty hook
           - added cPreText and renamed cEndText to cPostText
           - revised Render() to use above
           - added cCssClass and cCssStyle
05/19/2003 - revised ExpandTemplateSnippet to utilize the L7ExpandTemplate class (w/ L7: namespace tag support)
05/23/2003 - removed usages of NVL() and made other changes to allow Command Window testing
           - added SetSource() method
09/01/2003 - added cTagLanguage property and used it in ApplyTag()
09/06/2003 - removed automatic CRLF inclusions in ApplyTag() -- some elements like IMG/TEXTAREA can be problems
10/21/2003 - revised ApplyTag so empty elements don't get wrapped at all; this allows
             element usage in templates that stay quiet when they have no content (eg, breadcrumbs)
11/02/2003 - added support for "safe" textmerging (see L7Utils and L7ExpandTemplate, also)
12/31/2003 - revised heading level default from 4 to 2 to improve chance of semantic correctness
           - RETIRED ContentRow() method in favor of using L7RecordElement objects
           - altered HR() to call UDF HTHR()
           - refactored INIT into template calling SetID() and AfterINIT()
           - removed option to pass oParent down via INIT
           - inserted some WWWC dependency protection via L7_WC_FRAMEWORK constant
             (page elements are intended to be standalone producers of HTML fragments)
01/25/2004 - RETIRED HR() and H(), plus nHeadingLevel and oParent.
           - cTag now defaults to "div" (90% use case; always specify explicitly in reused subclasses)
           - revised ExpandTemplateSnippet() to use pass-by-ref.
           - factored <body></body> parsing out of ExpandTemplateSnippet(); into PreprocessSnippet()
09/12/2006 - added SetSourceFile() high-level method
           - revised SetSource() to turn off streaming
02/13/2010 - revised init method to allow tag as 2nd param
           - revised cID so NULL means auto-assign and empty means no ID

02/18/2010 - fixed bug where cPreText got inside the tag and cPostText did not
              

#endif
