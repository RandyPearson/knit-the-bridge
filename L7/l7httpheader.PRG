* L7HttpHeader.PRG

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


*** ========================================================= ***
DEFINE CLASS L7HttpHeader AS L7PageElement
  cTag = ""  && no <div> wrapper for this!
  
  lAuthenticate       = .F.  && send authorization dialog?
  cAuthRealm          = ""
  cAuthFailureMessage = "<html><body><h1>Login Failure - Access Denied!</h1></body></html>"

  vLastModified  = {}   && if empty, omit Last-Modified: header, if NULL use default DATETIME()
  vDate          = NULL && if empty, omit Date: header, if NULL use default DATETIME()
  vExpires       = ""
  
  cRedirectURL   = ""
  cContentType   = "" && "text/html"
  nContentLength = NULL
  cContentDisposition = ""
  cContentFilename = ""
  
  ** cCharset       = "utf-8"  && was "ISO-8859-1"
  cCharset       = "ISO-8859-1"
  
  cHttpVersion   = "1.1"
  cStatus        = "200 OK"
  DIMENSION aHeaders[ 1, 2]
  nHeaders       = 0
  DIMENSION aCookies[ 1, 6]
  nCookies       = 0

  * --------------------------------------------------------- *
  FUNCTION ResetProperties  && enables starting over, such as when a sudden change is needed (error response maybe)
    WITH this 
      * NOTE: Some properties are skipped, because they are not state-oriented,
      * and may instead be set in subclasses, and thus clearing not desireable.
      .lAuthenticate = .F.
      .vLastModified  = {}   
      .vDate          = NULL 
      .vExpires       = ""
      
      .cRedirectURL   = ""
      .cContentType   = "" && "text/html"
      .nContentLength = NULL
      .cContentDisposition = ""
      .cContentFilename = ""

      .cStatus        = "200 OK"
      DIMENSION .aHeaders[ 1, 2]
      .nHeaders       = 0
      DIMENSION .aCookies[ 1, 4]
      .nCookies       = 0
    ENDWITH 
    RETURN 
  ENDFUNC  
  * --------------------------------------------------------- *
  FUNCTION Redirect(lcUrl)
    * allows object to be used without a Page
    THIS.cRedirectUrl = m.lcUrl
    THIS.cStatus = "302 Moved"
  ENDFUNC && Redirect
  * --------------------------------------------------------- *
  FUNCTION RenderImplementation(lcText)
    LOCAL lcContentType
    lcContentType = EVL(THIS.cContentType, "text/html")
    
    IF THIS.lAuthenticate
      * If authentication is indicated, supersede everything.
      lcText = THIS.GetAuthenticationHeader() && don't add anything else!
      RETURN
    ENDIF
    IF NOT EMPTY( THIS.cRedirectURL )
      * If redirection is indicated, supersede everything.
      lcText = THIS.GetRedirectionHeader() && don't add anything else!
      RETURN
    ENDIF

    lcText = m.lcText + "HTTP/" + THIS.cHttpVersion + ;
      " " + THIS.cStatus + CRLF
      
    * Content-type (and optional Charset):
    lcText = m.lcText + "Content-type: " + m.lcContentType
    IF m.lcContentType = "text/html" AND NOT EMPTY( THIS.cCharSet )
      lcText = m.lcText + "; charset=" + THIS.cCharset
    ENDIF
    lcText = m.lcText + CRLF

    IF NOT ISNULL(THIS.nContentLength)
      lcText = m.lcText + "Content-length: " + TRANSFORM(THIS.nContentLength) + CRLF
    ENDIF
    lcText = m.lcText + THIS.GetContentDisposition()
    ** lcText = m.lcText + THIS.GetDate()  && IIS adds a 2nd one anyway, plus GMT time isn't always correct here
    lcText = m.lcText + THIS.GetLastModified()
    lcText = m.lcText + THIS.GetExpires()
    lcText = m.lcText + THIS.GetCookies()
    lcText = m.lcText + THIS.GetHeaders()

    * A blank line is required before any content:
    lcText = m.lcText + CRLF
    RETURN 
  ENDFUNC  && RenderImplementation
  * --------------------------------------------------------- *
  FUNCTION GetAuthenticationHeader
    RETURN [HTTP/] + THIS.cHTTPVersion + ;
      [ 401 Not Authorized] + CRLF + ;
      [WWW-Authenticate: basic realm="] + THIS.cAuthRealm + ["] + CRLF + ;
      [Content-Type: text/html] + CRLF + ;
      CRLF + ;
      THIS.cAuthFailureMessage
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetRedirectionHeader
    RETURN "HTTP/" + THIS.cHTTPVersion + ;
      " 302 Moved" + CRLF + ;
      "Content-type: text/html" + CRLF + ;
      "Location: " + STRTRAN(THIS.cRedirectURL, "&amp;", "&") + ;
      CRLF + CRLF 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetContentDisposition
    IF EMPTY(THIS.cContentDisposition)
      RETURN ""
    ENDIF
    RETURN "Content-disposition: " + THIS.cContentDisposition + ;
      IIF(EMPTY(THIS.cContentFilename), "", "; filename=" + THIS.cContentFilename) + ;
      CRLF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetExpires(lvExpiry, llReplace)
    LOCAL lcType
    lcType = VARTYPE(THIS.vExpires)
    IF EMPTY(THIS.vExpires) OR m.llReplace OR m.lcType = "C" OR VARTYPE(m.lvExpiry) <> m.lcType
      THIS.vExpires = m.lvExpiry
    ELSE  && use earliest of the two:
      THIS.vExpires = MIN(THIS.vExpires, m.lvExpiry)
    ENDIF
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetDate
    LOCAL lcExp
    lcExp = NVL(THIS.vDate, DATETIME())  && NULL means use current
    DO CASE
    CASE EMPTY( m.lcExp)  && empty means no header
      RETURN ""
    CASE VARTYPE(m.lcExp) $ "TD"
      lcExp = GMTTime( m.lcExp )
    CASE VARTYPE(m.lcExp) = "C"  && assume already a valid GMT format
      * already OK
    CASE VARTYPE(m.lcExp) = "N"  && # minutes from now -- RARE (more used for expiry)
      lcExp = GMTTime( DATETIME() + 60 * m.lcExp)
    OTHERWISE
      RETURN ""
    ENDCASE
    RETURN "Date: " + m.lcExp + CRLF
  ENDFUNC  && GetDate
  * --------------------------------------------------------- *
  FUNCTION GetLastModified
    LOCAL lcExp
    lcExp = NVL(THIS.vLastModified, DATETIME())  && NULL means use current
    DO CASE
    CASE EMPTY( m.lcExp)  && empty means no header
      RETURN ""
    CASE VARTYPE(m.lcExp) $ "TD"
      lcExp = GMTTime( m.lcExp )
    CASE VARTYPE(m.lcExp) = "C"  && assume already a valid GMT format
      * already OK
    CASE VARTYPE(m.lcExp) = "N"  && # minutes from now -- RARE (more used for expiry)
      lcExp = GMTTime( DATETIME() + 60 * m.lcExp)
    OTHERWISE
      RETURN ""
    ENDCASE
    RETURN "Last-Modified: " + m.lcExp + CRLF
  ENDFUNC  && GetLastModified
  * --------------------------------------------------------- *
  FUNCTION GetExpires
    LOCAL lcExp, lcType
    lcType = VARTYPE( THIS.vExpires)
    DO CASE
    CASE EMPTY( THIS.vExpires)
      RETURN ""
    CASE m.lcType = "T" OR m.lcType = "D"
      lcExp = GMTTime( THIS.vExpires )
    CASE m.lcType = "N"  && # minutes from now
      lcExp = GMTTime( DATETIME() + 60 * THIS.vExpires)
    CASE m.lcType = "C"
      lcExp = THIS.vExpires
    OTHERWISE
      RETURN ""
    ENDCASE
    RETURN "Expires: " + m.lcExp + CRLF
  ENDFUNC  && GetExpires
  * --------------------------------------------------------- *
  function AddCookie(lcName, lcValue, lcPath, lvExpires, llSecure, llHttpOnly)
    * leave 4th parm blank for temp cookie
    local ii, llFound
    for ii = 1 TO THIS.nCookies
      IF THIS.aCookies[ m.ii, 1] == m.lcName
        * Already exists, replace!
        llFound = .T.
        exit 
      endif 
    endfor 
    if !m.llFound
      THIS.nCookies = THIS.nCookies + 1
      dimension THIS.aCookies[ THIS.nCookies, 6]
      THIS.aCookies[ THIS.nCookies, 1] = m.lcName
      ii = THIS.nCookies
    ENDIF
    THIS.aCookies[ m.ii, 2] = m.lcValue
    THIS.aCookies[ m.ii, 3] = IIF( EMPTY( m.lcPath), "/", m.lcPath )
    do case 
    case empty(m.lvExpires) && temporary (session) cookie
    case vartype( m.lvExpires) = "L"  && .T.
      THIS.aCookies[ m.ii, 4] = GMTTime( DATETIME() - 1440, 0 )
    case vartype( m.lvExpires) = "C"
      if upper( m.lvExpires) == "NEVER"
        THIS.aCookies[ m.ii, 4] = GMTTime( gomonth(date(), 60), 0 ) && 5 years out
        ** THIS.aCookies[ m.ii, 4] = GMTTime( {^2010-12-31}, 0 )
      else 
        THIS.aCookies[ m.ii, 4] = m.lvExpires
      endif 
    otherwise 
      THIS.aCookies[ m.ii, 4] = GMTTime( m.lvExpires )
    endcase
    THIS.aCookies[ m.ii, 5] = m.llSecure
    THIS.aCookies[ m.ii, 6] = m.llHttpOnly
    return 
  endfunc  && AddCookie
  * --------------------------------------------------------- *
  function GetCookies
    local ii, lcRet
    lcRet = ""
    for ii = 1 TO THIS.nCookies
      lcRet = m.lcRet + [Set-Cookie: ] + ;
        THIS.aCookies[ m.ii, 1] + [=] + ;
        transform(THIS.aCookies[ m.ii, 2]) + ;
        [; path=] + IIF( EMPTY( THIS.aCookies[ m.ii, 3]), [/], ;
          THIS.aCookies[ m.ii, 3]) + ;
        iif(empty(THIS.aCookies[ m.ii, 4]), [], [; expires=] + ;
        THIS.aCookies[ m.ii, 4]) + ;
        iif(this.aCookies[m.ii, 5], [; Secure], []) + ;
        iif(this.aCookies[m.ii, 6], [; HttpOnly], []) + ;
        CRLF
    endfor 
    return  m.lcRet
  endfunc   && GetCookies
  * --------------------------------------------------------- *
  FUNCTION AddHeader(lcName, lcValue, llAppend)
    LOCAL ii, llFound
    FOR ii = 1 TO THIS.nHeaders
       IF THIS.aHeaders[ m.ii, 1] == m.lcName
         llFound = .T.
         IF m.llAppend
            * Append to current
             THIS.aHeaders[ m.ii, 2] = THIS.aHeaders[ m.ii, 2] + ", " + m.lcValue
         ELSE
             * Already exists, replace!
             THIS.aHeaders[ m.ii, 2] = m.lcValue
         ENDIF m.llAppend
          EXIT
       ENDIF
    ENDFOR
    IF NOT m.llFound
       THIS.nHeaders = THIS.nHeaders + 1
       DIMENSION THIS.aHeaders[ THIS.nHeaders, 2]
       THIS.aHeaders[ THIS.nHeaders, 1] = m.lcName
       THIS.aHeaders[ THIS.nHeaders, 2] = m.lcValue
    ENDIF
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION GetHeaders()
    LOCAL ii, lcRet
    lcRet = ""
    FOR ii = 1 TO THIS.nHeaders
      lcRet = m.lcRet + THIS.aHeaders[m.ii, 1] + ": " + ;
        THIS.aHeaders[m.ii, 2] + CRLF
    ENDFOR
    RETURN m.lcret
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE  && L7HttpHeader
*** ========================================================= ***

#if .f.
12/31/2002 - renamed various "layer" classes to use term "element" instead
01/14/2002 - changed render() to renderImplementation to fit with new template methods in L7PageElement
01/24/2003 - added SetExpires() to force resolution of competing expirations
02/12/2003 - in redirection, replaced &amp; with &
03/30/2003 - added content-length support
04/15/2003 - added content-disposition and filename support
           - added AddHeader() and GetHeaders()
06/30/2003 - revised RenderImplementation code for authentication/redirection to
             accomodate pass-by-reference approach
08/08/2005 - removed GetDate from RenderImplementation template
09/18/2007 - fixed bug where charset was ignored if contentType wasn't explicitly set
             changed default charset from ISO-8859-1 to utf-8
12/28/2011 - support for Secure and HttpOnly cookies 
#endif
