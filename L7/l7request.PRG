#INCLUDE WCONNECT.H

* L7Request.PRG  

* Sub-class of wwRequest class to provide better support for
* multi-part forms, and to allow easier state capture in 
* error and debuging methods.

* Author: J. Randy Pearson (w/ input from Harold Chattaway)
* 
* Provided as "free-ware" to all developers who use the West Wind 
* Web Connection product. 
*
* To utilize with Web Connection (outside of L7 Framework):
*
*  1. Ensure classes are available by issuing the command
*
*     SET PROCEDURE TO L7Request ADDITIVE
*
*     somewhere in your main program 
*     (perhaps just after the "DO WCONNECT" line).
*
*  2. Create/modify your WCONNECT_OVERRIDE.H file to include:
*
*     #UNDEF WWC_REQUEST
*     #DEFINE WWC_REQUEST L7wwRequest
*
*** ========================================================= ***
DEFINE CLASS L7WwRequest AS wwRequest
  * Sub-class of Web Connection wwRequest.
  lMultiPart = NULL && see access method
  
  * Proxies for methods (see access methods):
  *
  * (These are provided so that the Request object has enough
  *  properties to describe itself in error messages, allowing
  *  use of ObjectToXML() or something similar.)
  *
  * CAUTION!
  * These properties must be reset on each hit, because
  * wwServer persists the Request object. See method
  * AfterInitializeRequest() for reset code!
  *
  cAuthenticatedUser = NULL
  cCurrentURL        = NULL
  cPreviousURL       = NULL
  cIPAddress         = NULL
  lIncludeNetworkInHash = .f.  && this isn't workable as people switch in and out of wireless situations
  cNetwork           = NULL
  cClientCRC         = NULL
  cBrowser           = NULL
  cServerName        = NULL
  cServerIPAddress   = NULL
  cPhysicalPathX     = NULL  && WWWC "protects" cPhysicalPath
  cLogicalPath       = NULL
  cVirtualPath       = NULL  && just the "path" part
  cMethod            = NULL
*!*    * --------------------------------------------------------- *
*!*    FUNCTION InitializeRequest( lcPostData, lcTempPath)
*!*      DODEFAULT( lcPostData, lcTempPath)
*!*      * Following are required to support object 
*!*      * re-use on each hit by wwServer:
*!*      THIS.lMultiPart         = NULL  
*!*      THIS.cAuthenticatedUser = NULL
*!*      THIS.cCurrentURL        = NULL
*!*      THIS.cPreviousURL       = NULL
*!*      THIS.cIPAddress         = NULL
*!*      THIS.cNetwork           = NULL
*!*      THIS.cBrowser           = NULL
*!*      THIS.cServerName        = NULL
*!*      THIS.cServerIPAddress   = NULL
*!*      THIS.cPhysicalPathX     = NULL
*!*      THIS.cLogicalPath       = NULL
*!*      THIS.cVirtualPath       = NULL
*!*      THIS.cMethod            = NULL
*!*      THIS.cClientCRC         = NULL
*!*    ENDFUNC  && InitializeRequest
  * --------------------------------------------------------- *
  FUNCTION InitializeRequest( lcPostData, lcTempPath)

    LOCAL lnSplit, lcTempLargeFile
    *** Locate the boundary that divides form and server vars
    lnSplit = AT( POST_BOUNDARY , lcPostData)

    If Len(lcPostData)<16000000 
      * no large file trouble, use WC default code:
      IF lnSplit = 0
         *** No boundary - no form vars
         THIS.cFormVars = ""
         THIS.cServerVars = "&" + lcPostData
      ELSE   
         THIS.cServerVars = "&" + SUBSTR(lcPostData,1,lnSplit-1)
         THIS.cFormvars = "&"+SUBSTR(lcPostData,lnSplit + LEN(POST_BOUNDARY))
      ENDIF
    ELSE 
      * 02/18/2008: experimental code from Simon White, augmented by Randy Pearson for file handling:
      lcTempLargeFile = ADDBS(m.lcTempPath) + "Large" + TRIM(SYS(2015)) + ".TMP"
      
       IF lnSplit = 0
          *** No boundary - no form vars
          THIS.cFormVars = ""
          =StrToFile("&", m.lcTempLargeFile)
          =StrToFile(lcPostData, m.lcTempLargeFile, 1) && appends post data to '&' using temp file
          THIS.cServerVars = FileToStr(m.lcTempLargeFile) && read file back
       ELSE   
          THIS.cServerVars = "&" + SUBSTR(lcPostData,1,lnSplit-1)
          =StrToFile("&", m.lcTempLargeFile)
          =StrToFile(SUBSTR(lcPostData,lnSplit + LEN(POST_BOUNDARY)), m.lcTempLargeFile, 1)    
          THIS.cFormVars = FileToStr(m.lcTempLargeFile)
       ENDIF
      
      DECLARE Sleep IN WIN32API Integer nMS
      Sleep(100)
      IF FILE(m.lcTempLargeFile)
        TRY 
          ERASE (m.lcTempLargeFile)
        CATCH
        ENDTRY
      ENDIF 
    ENDIF 

    *** Override the file to properly allow translation to
    *** a remote drive if passed. Otherwise use default drive/path
    *** as specified by THIS.cContentFile
    IF !EMPTY(lcTempPath)
       THIS.cPathOverride=lcTempPath
    ELSE
       THIS.cPathOverride=""
    ENDIF
    THIS.cOutputFile= ForcePath(THIS.ServerVariables("Output File"),THIS.cPathOverride)
    
    * Split off evrything that is needed when building a fake (scaffolded) Request.
    * Test code can omit initiazeRequest() and only call afterInitializeRequest()
    this.afterInitializeRequest()
    return  
  endfunc  && InitializeRequest
  * --------------------------------------------------------- *
  function afterInitializeRequest 
    * Called automatically from initializeRequest (template); however
    * can be called alone by test scaffolding code _after_ ServerVars and
    * FormVars have been set.
    with this 
      *** Clear out any WWWC cached property values
      .cQueryString= STRTRAN(.ServerVariables("QUERY_STRING"),"%7E","~")
      .cPhysicalPath = ""
      .cMultiPartBorder = ""
      .lUseXMLFormVars = .F.
      .lUtf8Encoding = .F.
      .lFilterUnsafeCommands = WWWC_FILTER_UNSAFECOMMANDS

      .ParseQueryString()
      .SetPostMode()  && use content_type to set nPostMode

      * Following are L7-added properties, required to support object 
      * re-use on each hit by wwServer:
      .lMultiPart         = NULL  
      .cAuthenticatedUser = NULL
      .cCurrentURL        = NULL
      .cPreviousURL       = NULL
      .cIPAddress         = NULL
      .cNetwork           = NULL
      .cBrowser           = NULL
      .cServerName        = NULL
      .cServerIPAddress   = NULL
      .cPhysicalPathX     = NULL
      .cLogicalPath       = NULL
      .cVirtualPath       = NULL
      .cMethod            = NULL
      .cClientCRC         = NULL
    endwith 
    return  
  endfunc   && afterInitializeRequest
  * --------------------------------------------------------- *
  function isAJAX
    return this.GetExtraHeader("HTTP_X_REQUESTED_WITH") = "XMLHttpRequest"
  endfunc 
  * --------------------------------------------------------- *
  function SetPostMode
    LOCAL lcContentType
    lcContentType = LOWER(this.ServerVariables("CONTENT_TYPE"))
    do case 
    case m.lcContentTYpe = "application/x-www-form-urlencoded"
      this.nPostMode = 1
    case m.lcContentType = "multipart"
      this.nPostMode = 2
    case m.lcContentType = "text/xml"
      this.nPostMode = 4

    * This CASE is L7 only, not part of WWWC:
    case m.lcContentType = "application/octet-stream"
      this.nPostMode = 5

    case empty(m.lcContentType)
      *** Some HTTP clients are sloppy and don't set the Content-Type
      *** so to make sure let's keep the legacy behavior
      this.nPostMode = 1  && seems this should be 0/1 depending on REQUEST_METHOD ?
    otherwise 
      this.nPostMode = 0  && wwRequest sets this to 1, not 0; hmmm, maybe REQUEST_METHOD should be used ?
    endcase 
    return  
  endfunc  && SetPostMode
  * --------------------------------------------------------- *
  FUNCTION lMultiPart_ACCESS
    * Uses initial NULL for tri-state logic using the
    * usual Access method deferral pattern.
    *
    * This property allows the request object to determine
    * for itself if the form was multi-part, so that the
    * developer doesn't have to change all their code, just
    * because a form gets switched to multi-part.
    *
    * To see this property in action, refer to overrides
    * of base Form(), GetFormMultiple() and IsFormVar()
    * further below.
    *
    IF ISNULL( THIS.lMultiPart) && not yet established
      LOCAL lcContent
      lcContent = THIS.ServerVariables("CONTENT_TYPE")
      SET EXACT OFF
      IF m.lcContent = "multipart/form-data"
        THIS.lMultiPart = .T.
        THIS.GetMultiPartBorder()
      ELSE
        THIS.lMultiPart = .F.
      ENDIF
    ENDIF
    RETURN THIS.lMultiPart
  ENDFUNC  && lMultiPart_ACCESS
  * --------------------------------------------------------- *
  FUNCTION cAuthenticatedUser_ACCESS
    IF ISNULL(THIS.cAuthenticatedUser)
      THIS.cAuthenticatedUser = THIS.GetAuthenticatedUser()
    ENDIF
    RETURN THIS.cAuthenticatedUser
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cCurrentURL_ACCESS
    IF ISNULL(THIS.cCurrentURL)
      THIS.cCurrentURL = THIS.GetCurrentURL()
    ENDIF
    RETURN THIS.cCurrentURL
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cPreviousURL_ACCESS
    IF ISNULL(THIS.cPreviousURL)
      THIS.cPreviousURL = THIS.GetPreviousURL()
    ENDIF
    RETURN THIS.cPreviousURL
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION IsSelfReferred
    * Is current request from same host?
    LOCAL lcCurr, lcPrev, llRet
    lcPrev = THIS.cPreviousUrl
    lcCurr = THIS.cCurrentUrl
    llRet = NOT EMPTY(m.lcPrev)
    llRet = m.llRet AND ;
      STREXTRACT(m.lcPrev,'//','/',1,3) == ;
      STREXTRACT(m.lcCurr,'//','/',1,3)
    RETURN m.llRet
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION cIPAddress_ACCESS
    IF ISNULL(THIS.cIPAddress)
      THIS.cIPAddress = THIS.GetIPAddress()
    ENDIF
    RETURN THIS.cIPAddress
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cNetwork_ACCESS
    IF ISNULL(THIS.cNetwork)
      THIS.cNetwork = THIS.GetNetwork()
    ENDIF
    RETURN THIS.cNetwork
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cClientCRC_ACCESS
    IF ISNULL(THIS.cClientCRC)
      THIS.cClientCRC = THIS.GetClientCRC()
    ENDIF
    RETURN THIS.cClientCRC
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cBrowser_ACCESS
    IF ISNULL(THIS.cBrowser)
      THIS.cBrowser = THIS.GetBrowser()
    ENDIF
    RETURN THIS.cBrowser
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cServerName_ACCESS
    IF ISNULL(THIS.cServerName)
      THIS.cServerName = THIS.GetServerName()
    ENDIF
    RETURN THIS.cServerName
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cServerIPAddress_ACCESS
    IF ISNULL(THIS.cServerIPAddress)
      THIS.cServerIPAddress = THIS.ServerVariables("LOCAL_ADDR")
    ENDIF
    RETURN THIS.cServerIPAddress
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cPhysicalPathX_ACCESS
    IF ISNULL(THIS.cPhysicalPathX)
      THIS.cPhysicalPath = "" && required to force WWWC method to work!
      THIS.cPhysicalPathX = THIS.GetPhysicalPath()
    ENDIF
    RETURN THIS.cPhysicalPathX
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cLogicalPath_ACCESS
    IF ISNULL(THIS.cLogicalPath)
      THIS.cLogicalPath = THIS.GetLogicalPath()
    ENDIF
    RETURN THIS.cLogicalPath
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cVirtualPath_ACCESS
    IF ISNULL(THIS.cVirtualPath)
      THIS.cVirtualPath = JUSTPATH(THIS.cLogicalPath)
    ENDIF
    RETURN THIS.cVirtualPath
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION cMethod_ACCESS
    IF ISNULL(THIS.cMethod)
      THIS.cMethod = THIS.ServerVariables("REQUEST_METHOD")
    ENDIF
    RETURN THIS.cMethod
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Form(lcVar)
    IF THIS.lMultiPart
      RETURN THIS.GetMultipartFormvar( m.lcVar)
    ELSE
      RETURN DODEFAULT( m.lcVar)
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  function GetFormMultipleCollection(tcVarname)
    * Use collection (vs array+count) for multi-valued formvars
    local loRet, lnCount, lnX, lcValue, lcPointer, lcFind, lnAt
    loRet = createobject("Collection")
    
    if this.lMultiPart

      lnCount = this.FormVarCount(m.tcVarName)
      for lnX = 1 to lnCount
        lcValue = this.GetMultipartFormVar(m.tcVarName, m.lnX)
        loRet.add(m.lcValue)
      endfor 

    else 

      lcPointer = this.cFormVars
      lcFind = "&" + strtran(m.tcVarname, " ", "+") + "="
      lnAt = ATC(m.lcFind, m.lcPointer)
      * if m.lnAt = 0, none--collection count remains 0
      do while m.lnAt > 0
        lcValue = GetUrlEncodedKey(m.lcPointer, m.tcVarName) 
        loRet.add(m.lcValue)
        lcPointer = substr(m.lcPointer, m.lnAt + len(m.lcFind))
        lnAt = atc(m.lcFind, m.lcPointer)
      enddo   

    endif
    return m.loRet
  endfunc && GetFormMultipleCollection
  * --------------------------------------------------------- *
  FUNCTION GetFormMultiple(laVars, lcVarname)
    IF THIS.lMultiPart
      RETURN THIS.GetMultipartFormMultiple( @laVars, m.lcVarname)
      * Method is below (not part of base WC framework).
    ELSE
      RETURN DODEFAULT( @laVars, m.lcVarname)
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetMultipartFormMultiple(taVars,tcVarName)
    * Don't call this method directly any longer! GetFormMultiple()
    * can be used for both types of forms.
    LOCAL lnIdx, lcValue, lnAt, lcFind, lcPointer
    lnIdx = 0
    lcPointer = THIS.cFormVars
    lcFind = [NAME="] + m.tcVarName + ["]
    lnAt = ATC(m.lcFind, m.lcPointer)
    IF m.lnAt = 0
      RETURN 0
    ENDIF

    IF EMPTY(THIS.cMultiPartBorder)
      THIS.GetMultiPartBorder()
    ENDIF   

    DO WHILE m.lnAt > 0
      lcValue = Extract(@lcPointer, ;
        m.tcVarName + ["] + CHR(13) + CHR(10) + CHR(13) + CHR(10), ;
        CHR(13) + CHR(10) + "--" + THIS.cMultipartBorder)
      
      lnIdx = m.lnIdx + 1
      DIMENSION taVars[m.lnIdx]
      taVars[m.lnIdx] = m.lcValue
      
      lcPointer = SUBSTR(m.lcPointer, m.lnAt + LEN(m.lcFind))
      lnAt = ATC(m.lcFind, m.lcPointer)
    ENDDO  

    RETURN m.lnIdx
  ENDFUNC  && GetMultipartFormMultiple
  * --------------------------------------------------------- *
  FUNCTION IsFormVar( lcVarname)
    IF THIS.lMultiPart
      RETURN THIS.IsMultipartFormvar( m.lcVarname)
      * Method is below (not part of base WC framework).
    ELSE
      RETURN DODEFAULT( m.lcVarname)
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION IsMultipartFormvar(lcKey)
    * Don't call this method directly any longer! IsFormvar()
    * can be used for both types of forms.
    * Created by Harold Chattaway.
    LOCAL lcMultiPart
    lcMultiPart = THIS.cFormVars   && THIS.GetFormVar('MultiPart')
    lnLoc = ATC([NAME='] + m.lcKey + ['], m.lcMultiPart)
    IF lnLoc=0
    	RETURN .F.
    ELSE
    	RETURN .T.
    ENDIF
  ENDFUNC  && IsMultipartFormvar
  * --------------------------------------------------------- *
  FUNCTION aFormVars(laVars, lcPrefix)
    IF THIS.lMultiPart
      ** ERROR "aFormVars method not supported for multi-part forms!"
      RETURN THIS.aMultipartFormVars(@laVars, m.lcPrefix)
      * If someone needs this support, please write the
      * supporting code and send it along!
    ELSE
      RETURN DODEFAULT(@laVars, m.lcPrefix)
    ENDIF
  ENDFUNC  && aFormVars
  * --------------------------------------------------------- *
  FUNCTION aMultipartFormVars(laVars, lcPrefix)
    LOCAL lnCount, lnOccurs, lcBorder, lnPtr, ;
      lcValue, lcName, lcSearchFor, lcSearchThrough, lcLinePrefix
    lnCount = 0
    lcBorder = THIS.GetMultipartBorder()
    lcLinePrefix = [Content-Disposition: form-data; name=]
    IF EMPTY(m.lcBorder)
      RETURN 0
    ENDIF
    lcSearchFor = m.lcBorder + CR + m.lcLinePrefix
    lcSearchThrough = CR + "--" + m.lcBorder
    lnOccurs = OCCURS(m.lcSearchFor, THIS.cFormVars)
    FOR lnPtr = 1 TO m.lnOccurs
      lcStr = STREXTRACT(THIS.cFormVars, m.lcSearchFor, m.lcSearchThrough, m.lnPtr)
      lcName = STREXTRACT(m.lcStr,["],["])
      lcValue = SUBSTR(m.lcStr,AT(["],m.lcStr,2) + 1 + LEN(CR+CR))
      lnCount = m.lnCount + 1
      DIMENSION laVars[m.lnCount,2]
      laVars[m.lnCount,1] = m.lcName
      laVars[m.lnCount,2] = m.lcValue
    ENDFOR
    RETURN m.lnCount
  ENDFUNC  && aMultipartFormVars
  * --------------------------------------------------------- *
  FUNCTION SetKey(lcKey, lcValue, lvReserved)
    IF THIS.lMultiPart
      ERROR "SetKey method not yet supported for multi-part forms!"
      * If someone needs this support, please write the
      * supporting code and send it along!
    ELSE
      RETURN DODEFAULT( m.lcKey, m.lcValue, m.lvReserved)
    ENDIF
  ENDFUNC  && SetKey
  * --------------------------------------------------------- *
  FUNCTION AlterQueryString( lcString, llAddOnly)
    * Make sure string is not encoded for output:
    lcString = STRTRAN(m.lcString, [&amp;], [&])
    IF NOT m.llAddOnly  && replace entire string
    	THIS.cQueryString = m.lcString
    ELSE  && add parameters to current string
    	IF NOT '~' $ THIS.cQueryString
    		THIS.cQueryString = THIS.cQueryString + '~'
    	ENDIF
    	IF NOT m.lcString = '&'
    		lcString = '&' + m.lcString
    	ENDIF
    	THIS.cQueryString = THIS.cQueryString + m.lcString
    ENDIF
    THIS.ParseQueryString()
    RETURN 
  ENDFUNC  && AlterQueryString
  * --------------------------------------------------------- *
  * 02/07/2005: added this
  FUNCTION ParseQueryString()
    * Cope with dumb crawlers that navigate without decode ampersands:
    IF AMPERSAND_ENCODED $ THIS.cQueryString
      THIS.cQueryString = STRTRAN(THIS.cQueryString, AMPERSAND_ENCODED, "&")
    ENDIF
    * Cope with URLs with redundant ? chars (otherwise .QueryString() fails to find 1st param):
    DO WHILE LEFT(THIS.cQueryString, 1) = "?"
      THIS.cQueryString = SUBSTR(THIS.cQueryString, 2)
    ENDDO
    RETURN DODEFAULT()
  ENDFUNC
  *!*    * --------------------------------------------------------- *
*[[   This didn't prove reliable on some servers, so we reverted to base WWWC behavior:
  *!*    FUNCTION IsLinkSecure(lcPort)
  *!*      * parameter retained in signature for backward compatibility
  *!*      RETURN THIS.ServerVariables("SERVER_PORT_SECURE") == "1"
  *!*    ENDFUNC

  * Re-factor and maybe add collection to request class:
  * --------------------------------------------------------- *
  FUNCTION GetFolder(tnLevel)
    LOCAL loFolders
    loFolders = this.GetFolders()
    IF m.tnLevel > loFolders.Count
      RETURN ""
    ELSE 
      RETURN loFolders.item(m.tnLevel)
    ENDIF 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION GetFolders()
    * Return a collection of folder names in the HTTP logical path.
    * Example URL: http://.../virtual/folderA/folderB/page.l7
    *   returns a 3-item collection with items ["virtual", "folderA", "folderB"]
    * Usage:
    *   For use where pathing provides application parameters or user/session info.
    *   In general, working backward from .Count is better practice, as that 
    *   accommodates virtuals starting at levels other than 1.
    * Example usage code:
    *   LOCAL loFolders as Collection, lcRightmostParm as String
    *   loFolders = Request.GetFolders()
    *   lcRightmostParm = loFolders[loFolders.Count]
    *
    LOCAL loRet as Collection, ii, lcPath
    loRet = CREATEOBJECT("Collection")
    lcPath = THIS.GetLogicalPath()
    lcPath = LEFT(m.lcPath, RAT("/", m.lcPath) - 1)
    FOR ii = 1 TO GETWORDCOUNT(m.lcPath, '/')
      loRet.Add(GETWORDNUM(m.lcPath, m.ii, '/')) && no key here, so legit dups don't break this
    NEXT 
    RETURN m.loRet
  ENDFUNC  && GetFolders()
  * --------------------------------------------------------- *
  FUNCTION GetUrlToVirtual(tnLevel)
    * gets URL to virtual directory (assumes current URL is in same)
    * intentionally obscure name to prevent collision with other fns
    LOCAL lnLevel, lcUrl, lnAt
    DO CASE
    CASE VARTYPE(tnLevel) = "N"
      lnLevel = m.tnLevel
    CASE TYPE("Config.nVirtualLevel") = "N"  && newer L7 apps should specify
      lnLevel = Config.nVirtualLevel
    OTHERWISE  && punt and assume typical
      lnLevel = 1  
    ENDCASE
    lcUrl = THIS.GetCurrentUrl()
    lnAt = AT("/", m.lcUrl, 2 + 1 + m.lnLevel) && // server : port / virtual / <- find that virgule
    IF m.lnAt > 0
      lcUrl = LEFT(m.lcUrl, m.lnAt)
    ELSE  && && this shouldn't happen?
      lcUrl = m.lcUrl + "/" 
    ENDIF 
    RETURN m.lcUrl
  ENDFUNC  && GetUrlToVirtual
  * --------------------------------------------------------- *
  FUNCTION GetRelativeSecureLink(lcLink, llNonSecure)
    LOCAL lcCurUrl
    * get a reference URL w/ proper protocol
    lcCurUrl = THIS.GetCurrentUrl(!m.llNonSecure)

    IF m.lcLink = "/"  && passed link 
      lcCurUrl = LEFT(m.lcCurUrl, AT("/", m.lcCurUrl, 3) - 1) && remove everything after server name
    ELSE && relative
      * Strip off the document and add the relative link 
      lcCurUrl = SUBSTR(m.lcCurUrl, 1, RAT("/", m.lcCurUrl))
    ENDIF
    RETURN m.lcCurUrl + m.lcLink
    
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetFilenameParameters(lcDelim)
    * Looking for things like "Articles_pk_32_pg_3.htm" 
    * (possibly to be converted to "Articles.htm?&pk=32~&pg=3").
    * Creates a collection.
    * Can be "pushed" into query string by calling 
    * FilenameToQueryString().
    LOCAL lcStr, lnNo, lcNo, loParms, lnWords, lnK, lcName, lcVal
    loParms = CREATEOBJECT("Collection")
    lcStr = JUSTSTEM(THIS.GetPhysicalPath())
    lcDelim = EVL(m.lcDelim, "_")
    lnWords = GETWORDCOUNT(m.lcStr, m.lcDelim)
    FOR lnK = 2 + MOD(1 + m.lnWords, 2) TO m.lnWords STEP 2
      lcName = GETWORDNUM(m.lcStr, m.lnK, m.lcDelim)
      lcVal = GETWORDNUM(m.lcStr, m.lnK + 1, m.lcDelim)
      TRY
        loParms.Add(m.lcVal, m.lcName)  
      CATCH && dup key? (e.g.: home_id_3_id_4.htm)
        * ignoring may be best guess
      ENDTRY
    ENDFOR
    RETURN m.loParms
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION FilenameToQueryString(lcDelim)
    LOCAL loColl AS Collection, lcQS AS String, lcOldQS AS String, lnK AS Integer
    loColl = THIS.GetFilenameParameters(lcDelim)
    lcOldQs = THIS.QueryString()  && for comparison below
    lcQS = "?" + m.lcOldQS
    FOR lnK = 1 TO loColl.Count && transfer each setting to QS
      lcVar = loColl.GetKey(m.lnK)
      lcValue = loColl.Item(m.lnK)
      lcQS = StuffUrl(m.lcQS, m.lcVar, m.lcValue)
    ENDFOR
    lcQS = STRTRAN(SUBSTR(m.lcQS, 2), AMPERSAND_ENCODED, "&")  && just in case...
    IF NOT m.lcQS == m.lcOldQS  && above changes QS
      THIS.AlterQueryString(m.lcQS)
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION IsAdministrator
    LOCAL lcAdmin, lcUser
    lcAdmin = LOWER(THIS.GetWcIniValue("AdminAccount"))
    IF EMPTY(m.lcAdmin) 
      RETURN .T.  && no admin specified
    ENDIF
    lcUser = LOWER(THIS.GetAuthenticatedUser())
    IF m.lcAdmin == "any"
      RETURN NOT EMPTY(m.lcUser) && any auth user is OK
    ENDIF
    IF EMPTY( m.lcUser)
      RETURN ""  && not auth'd
    ENDIF
    RETURN "," + m.lcUser + "," $ "," + m.lcAdmin + ","
  ENDFUNC  && IsAdministrator
  * --------------------------------------------------------- *
  FUNCTION GetNetwork
    LOCAL lcNet
    lcNet = THIS.cIpAddress
    lcNet = IpToNetwork(m.lcNet)
    RETURN m.lcNet
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetClientCRC
    * Returns CRC of hit-invariant request info, so that 
    * sessions can be tracked more reliably, particularly with
    * license plates.
    LOCAL lcStr
    lcStr = THIS.GetBrowser() 
    IF THIS.lIncludeNetworkInHash
      lcStr = m.lcStr + THIS.GetNetwork() 
    ENDIF
    
    * 3/13/2006: Following combination was not reliable with MSIE,
    *   possibly when downloading files. Something changed in ACCEPT, maybe?
    *!*      lcStr = THIS.GetBrowser() + ;
    *!*        THIS.ServerVariables("HTTP_ACCEPT") + ;
    *!*        THIS.ServerVariables("HTTP_ACCEPT_ENCODING") + ;
    *!*        THIS.ServerVariables("HTTP_ACCEPT_LANGUAGE") + ;
    *!*        THIS.ServerVariables("HTTP_ACCEPT_CHARSET") + ;
    *!*        THIS.ServerVariables("KEEP_ALIVE")
    
    RETURN SYS(2007, m.lcStr, -1, 1)
  endfunc  && getClientCRC
  * --------------------------------------------------------- *
  function GetDebugInfo(tcTitle, tlReturnObject)
    try
      local loOut, lcTxt, lvRet
      loOut = createobject("Empty")
      WITH THIS
        addproperty(loOut, "AuthUser", TRIM(.GetAuthenticatedUser()))
        addproperty(loOut, "User", "")
        addproperty(loOut, "User_Email", "")
        if vartype(m.Environ) = "O"
          loOut.User = Environ.item("app.currentUser.name")
          loOut.User_Email = Environ.item("app.currentUser.email")
          * emulate ID..?
        endif 
        IF empty(m.loOut.User) 
          if VARTYPE(m.CurrentUser) = "O"
            TRY
              loOut.User = CurrentUser.GetUserName()
              IF VARTYPE(m.TrueUser) = "O"
                TRY
                  lcTrueUser = TrueUser.GetUserName()
                  IF NOT m.lcTrueUser == loOut.User
                    loOut.User = m.lcTrueUser + " (emulating " + loOut.User + ")"
                  ENDIF
                CATCH
                  loOut.User = loOut.User + " (error checking emulation)"
                ENDTRY
              endif
              try
                loOut.User_Email = CurrentUser.GetEmailAddress()
              catch to loExc
                loOut.User_Email = "Error determining email: " + loExc.Message
              endtry
            catch to loExc
              loOut.User = "Error determining user: " + loExc.Message
              loOut.User_Email = ""
            endtry
          else
            loOut.User = "(not available--too high in process stack)"
            * note: instead, get this stored to Environ as it becomes known
          endif 
        endif
              
        addproperty(loOut, "Query_String", .QueryString())
        addproperty(loOut, "Ip_Address", .GetIPAddress())
        addproperty(loOut, "Http_Method", UPPER(.ServerVariables( "REQUEST_METHOD")))
        addproperty(loOut, "URL", ;
          IIF(.IsLinkSecure(), 'https', 'http') + "://" + ;
          .GetServerName() + ;
          .ServerVariables("Executable Path") + ;
          "?" + loOut.Query_String)

        addproperty(loOut, "Referrer", evl(.GetPreviousURL(), '--none--'))
        addproperty(loOut, "User_Agent", .GetBrowser())
        addproperty(loOut, "Physical_Path", .GetPhysicalPath())
        addproperty(loOut, "Logical_Path", .GetLogicalPath())
        addproperty(loOut, "CRC", .GetClientCRC())
        addproperty(loOut, "Server_IP", .cServerIPAddress)

        if loOut.Http_Method = "POST"
          addproperty(loOut, "Form_Variables", this.GetDebugInfo_formVars())
        endif 
      endwith 
      
      * Wrap in div for output:
      if m.tlReturnObject
        lvRet = m.loOut
      else
        lvRet = [<div class="DebugInfo">] + CRLF + ;
          l7ShowObject(m.loOut, evl(m.tcTitle, "Request Information")) + CRLF + [</div>] + CRLF
      endif

    catch to loExc
      = .f.
      lcTxt = [<div><strong>Error from Request.getDebugInfo:</strong>] + loExc.Message + [</div>]
      if m.tlReturnObject
        lvRet = createobject("Empty")
        addproperty(m.lvRet, "error", m.lcTxt)
      else
        lvRet = m.lcTxt
      endif
    endtry 

    return m.lvRet
  endfunc && GetDebugInfo
  * --------------------------------------------------------- *
  function GetDebugInfo_formVars
    local lcRet, lcTmp, la[1], kk, nn, lcName, lcLine
    
    lcTmp = LEFT(THIS.cFormVars,10000)
    lcTmp = URLDecode(m.lcTmp)
    lcTmp = STRTRAN(m.lcTmp, "&", CRLF) 
    nn = alines(la, m.lcTmp)
    lcRet = ""
    for kk = 1 to m.nn
      lcLine = la[m.kk]
      lcName = getwordnum(m.lcLine, 1, "=")
      if "password" $ lower(m.lcName)
        loop
      endif
      lcRet = m.lcRet + htWrap(strtran(m.lcLine, [=], [ = ]), "li") + CRLF
    next
    
    ** return m.lcRet + space(19) && no idea what drove space(19)...
    return HtWrap(m.lcRet, "ul")
  endfunc  
  * --------------------------------------------------------- *
  function SetFormVariable(lcKey, lcValue)
    * adapted from Rick's setServerVariable to allow test scaffolding
    local lcFullValue, lcValue, lcKey, lnLoc, lcRest, lnLength
    lcFullValue = WWC_NULLSTRING
    lcFormVars = "&" + THIS.cFormVars && formvars don't have 1st leading &
    lcValue = URLEncode(m.lcValue)
    lcKey = STRTRAN(m.lcKey," ","+")
    lnLoc = ATC("&" + m.lcKey + "=", m.lcFormVars)

    if m.lnLoc > 0  && key already present
       lcRest = SUBSTR(m.lcFormvars, m.lnLoc)
       lnLength = ATC("&", m.lcRest,2) 
       IF m.lnLength =< 1 
          *** No & at end - full string size
          lnLength = LEN(m.lcRest) + 1 && One to long to match &
       ENDIF
       lcFullValue = LEFT(m.lcRest, m.lnLength - 1)
       THIS.cFormVars = STRTRAN(m.lcFormvars, m.lcFullValue, ;
         "&" + m.lcKey + "=" + m.lcValue)
    else && new var
       THIS.cFormVars = THIS.cFormVars + "&" + m.lcKey + "=" + m.lcValue
    endif 
    return 
  endfunc && setFormVariable
  * --------------------------------------------------------- *
ENDDEFINE  && L7WwRequest

*** ========================================================= ***
DEFINE CLASS L7FakeRequest AS l7wwRequest
  * Class that supports (most of) the same interface as
  * wwRequest, but allows direct instantiation and use
  * oustide an ISAPI environment. Handy for testing components
  * that need to have a "Request" object in scope.
  
  lSecure = .F.

  * --------------------------------------------------------- *
  FUNCTION QueryString( lcVar )
    RETURN ""
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetLogicalPath
    RETURN ""
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetPhysicalPath
    RETURN ""
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetBrowser
    RETURN ""
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetAuthenticatedUser
    RETURN ""
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION IsAdministrator
    RETURN .T.    
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION IsLinkSecure(lcPort)
    RETURN THIS.lSecure
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION Cookies( lcVar )
    RETURN ""
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE  && L7FakeRequest

*** ========================================================= ***
* End: L7Request.PRG

#if .f.
* 11-26-2002
*  - Added aFormVars() support for multi-part forms.
01/20/2003 - changed AlterQueryString() to remove &amp; encoding, if any
04/22/2003 - added FilenameToQueryString(), GetClientCRC() and GetDebugInfo()
07/09/2003 - added cServerName and cClientCRC to standard pre-determined properties
11/03/2003 - added cVirtualPath property
01/25/2004 - overrode IsLinkSecure to use SERVER_PORT_SECURE
02/07/2005 - overrode ParseQueryString to deal with more &amp; stuff
03/29/2005 - removed override to IsLinkSecure()
02/07/2007 - added cServerIPAddress property and access method
03/26/2009 - added GetFolders() method
01/04/2010 - split initializeRequest into parts to support scaffolding 
#endif
