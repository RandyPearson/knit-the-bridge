* L7Environ.prg
*
*  - trying to be like a WSGI Environ object
*  - [[ unclear if this is good (collection w/ keys vs. pure object)

#include L7.H
*** ========================================================= ***
DEFINE CLASS L7Environ as L7DictCollection  && in L7Utils.prg

  cOnCollision = "Replace" && choose from {Error, Ignore, Replace}
  vDefault = ""            && on item() lookup failure, add object w/ empty string

  oWwwcRequest = NULL
  * --------------------------------------------------------- *
  FUNCTION init  && ?? if override, say why 
  ENDFUNC 
  * --------------------------------------------------------- *
  function getDebugInfo()
    return L7ShowCollection(this, "Environ Object")
  endfunc  
  * --------------------------------------------------------- *
  function debugOutput()
    local ii, lcKey, lvVal 
    debugout "** ENVIRON OBJECT **"
    for ii = 1 to this.Count
      lcKey = this.getkey(m.ii)
      lvVal = this.item[m.ii]
      debugout lcKey, "=", lvVal
    endfor 
    debugout "****"
    return  
  endfunc   && debugOutput
  * --------------------------------------------------------- *
  function Seed_WWWC(toRequest) 
    with this
      .oWwwcRequest = m.toRequest
      .Add(toRequest.cMethod, "REQUEST_METHOD")
      
      .Add(toRequest.cLogicalPath, "SCRIPT_NAME")
      .Add(toRequest.cLogicalPath, "PATH_INFO") && these are same in IIS, not like WSGI!!
      .Add(toRequest.cLogicalPath, "LOGICAL_PATH")  && same as SCRIPT_NAME
      .Add(toRequest.cPhysicalPathX, "PHYSICAL_PATH")

      .Add(toRequest.QueryString(), "QUERY_STRING")
      .Add(toRequest.ServerVariables("CONTENT_TYPE"), "CONTENT_TYPE")
      .Add(toRequest.ServerVariables("CONTENT_LENGTH"), "CONTENT_LENGTH")
      .Add(toRequest.cServerName, "SERVER_NAME")
      .Add(toRequest.ServerVariables("SERVER_PORT"), "SERVER_PORT")
      .Add(toRequest.ServerVariables("SERVER_PORT_SECURE"), "SERVER_PORT_SECURE")
      .Add(toRequest.ServerVariables("SERVER_PROTOCOL"), "SERVER_PROTOCOL")

      .Add(toRequest.cAuthenticatedUser, "AUTHENTICATED_USER")
      .Add(toRequest.cIpAddress, "REMOTE_ADDR")
      
      .Add(toRequest.cClientCRC, "L7.CLIENT_CRC")

      * Establish early, populate as soon as known, enable App_Log events to report as much as possible.
      .Add("",            "app.session_id")
      .Add("--unknown--", "app.user_id")
      .Add("--unknown--", "app.currentUser.name")
      .Add("",            "app.currentUser.email")
      .Add("--n/a--",     "app.trueUser.name")

      .Add(L7_NONE, "aaa.nIdentificationActual")
    endwith 
    return  
  endfunc   && Seed_WWWC(toRequest) 
  * --------------------------------------------------------- *
enddefine  
*** ========================================================= ***

#if .f.
REQUEST_METHOD
    The HTTP request method, such as "GET" or "POST". This cannot ever be an empty string, and so is always required.
SCRIPT_NAME
    The initial portion of the request URL's "path" that corresponds to the application object, so that the application knows its virtual "location". This may be an empty string, if the application corresponds to the "root" of the server.
PATH_INFO
    The remainder of the request URL's "path", designating the virtual "location" of the request's target within the application. This may be an empty string, if the request URL targets the application root and does not have a trailing slash.
QUERY_STRING
    The portion of the request URL that follows the "?", if any. May be empty or absent.
CONTENT_TYPE
    The contents of any Content-Type fields in the HTTP request. May be empty or absent.
CONTENT_LENGTH
    The contents of any Content-Length fields in the HTTP request. May be empty or absent.
SERVER_NAME, SERVER_PORT
    When combined with SCRIPT_NAME and PATH_INFO, these variables can be used to complete the URL. Note, however, that HTTP_HOST, if present, should be used in preference to SERVER_NAME for reconstructing the request URL. See the URL Reconstruction section below for more detail. SERVER_NAME and SERVER_PORT can never be empty strings, and so are always required.
SERVER_PROTOCOL
    The version of the protocol the client used to send the request. Typically this will be something like "HTTP/1.0" or "HTTP/1.1" and may be used by the application to determine how to treat any HTTP request headers. (This variable should probably be called REQUEST_PROTOCOL, since it denotes the protocol used in the request, and is not necessarily the protocol that will be used in the server's response. However, for compatibility with CGI we have to keep the existing name.)
HTTP_
#endif

* end: L7Environ.prg
