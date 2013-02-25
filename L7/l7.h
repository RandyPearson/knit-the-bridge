* L7.H

#DEFINE L7_SHAREWARE    .F.
#DEFINE L7_RELEASE_ID   "1.03.04"
#DEFINE L7_WC_FRAMEWORK .T.  && set .F. in override file if not using Web Connection (i.e., only using controls and elements)

#DEFINE L7_DOCTYPE_SIMPLE [<!DOCTYPE HTML>]
#DEFINE L7_DOCTYPE_LOOSE [<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">]
#DEFINE L7_XML_FIRSTLINE [<?xml version="1.0" ?>]

#IFNDEF XML_XMLDOM_PROGID
  #DEFINE XML_XMLDOM_PROGID "MSXML2.DOMDocument"
#ENDIF
#DEFINE L7_DEFAULT_JAVASCRIPT_VERSION "1.2"
#UNDEF  L7_REGEXP_CLASS
#DEFINE L7_REGEXP_CLASS    "VBScript.RegExp"

#DEFINE L7_CUSTOMERROR_ERRORMSG 17701

* Major Functionality "Switches":   (turn these on/off in l7_override.h)
#DEFINE L7_MONITOR_PROCESS       .F.  

* Security Constants:
#DEFINE L7_ENABLE_AUTHENTICATION .T.
#DEFINE L7_ENABLE_COOKIES        .T.

#DEFINE L7_NONE    0

#DEFINE L7_IDENTIFICATION_NONE              0
#DEFINE L7_IDENTIFICATION_LICENSE_PLATE     1
#DEFINE L7_IDENTIFICATION_TEMPORARY_COOKIE  2
#DEFINE L7_IDENTIFICATION_PERSISTENT_COOKIE 3
#DEFINE L7_IDENTIFICATION_AUTHENTICATION    5

#DEFINE L7_LOGIN_NONE        0
#DEFINE L7_LOGIN_IDENTIFIED  1
#DEFINE L7_LOGIN_LOGGED_IN   2

#DEFINE L7_ANONYMOUS_USERID "ANONYMOUS"

* Special debugging constants:
#DEFINE L7_TABLE_DEBUG             .F.

#DEFINE L7_FORM_DEBUG_OBJECTS      .F.
#DEFINE L7_TABLE_ERROR_HANDLING    .F.
#DEFINE L7_QUERY_ERROR_HANDLING    .F.
#DEFINE L7_ENGINE_ERROR_HANDLING   .F.
#DEFINE L7_SECURITY_DEBUG_LEVEL    0   && 0=none, 1=hints, 2=verbose

* Add these values up to set Page.nErrorPageInfo
* and Page.nErrorEmailInfo properties:
*
#DEFINE L7_ERRORINFO_PROGRAM_STACK         1
#DEFINE L7_ERRORINFO_WORKAREAS             2
#DEFINE L7_ERRORINFO_REQUEST_OBJECT        4
#DEFINE L7_ERRORINFO_USER_OBJECT           8
#DEFINE L7_ERRORINFO_LIST_MEMORY          16
#DEFINE L7_ERRORINFO_SERVER_VARIABLES     32
#DEFINE L7_ERRORINFO_CONFIG_OBJECT        64
#DEFINE L7_ERRORINFO_APP_OBJECT          128
#DEFINE L7_ERRORINFO_PAGE_OBJECT         256
#DEFINE L7_ERRORINFO_EXCEPTION_INFO      512
#DEFINE L7_ERRORINFO_SESSION_OBJECT     1024
#DEFINE L7_ERRORINFO_APPMANAGER_OBJECT  2048
#DEFINE L7_ERRORINFO_ENVIRON_OBJECT     4096
#DEFINE L7_ERRORINFO_LOG_OBJECT         8192
#DEFINE L7_ERRORINFO_ALL               16384-1
#DEFINE L7_ERRORINFO_NONE                  0
#DEFINE L7_ERRORINFO_TYPICAL               1 + 2 + 4 + 8 + 512 + 2048 + 4096 + 8192

* Allowed techniques for application class instantiation (additive):
#DEFINE L7_APPCREATION_DIRECT    1
#DEFINE L7_APPCREATION_FACTORY   2

* Allowed techniques for page class instantiation (additive):
#DEFINE L7_PAGECREATION_DIRECT    1
#DEFINE L7_PAGECREATION_FACTORY   2

#IF L7_WC_FRAMEWORK
  * Override Web Connection settings.
  * Mandatory - Server class override:
  #UNDEF  WWC_SERVER
  #DEFINE WWC_SERVER               L7wwServer

  * Mandatory - Request class override:
  #UNDEF  WWC_REQUEST
  #DEFINE WWC_REQUEST              L7wwRequest

  * Optional - provide ability to alter info dislayed in server status form:
  #UNDEF  WWC_SERVERFORM 			
  #DEFINE WWC_SERVERFORM           L7wwServerForm

  #UNDEF  WWC_SERVERFORM_VFPFRAME 
  #DEFINE WWC_SERVERFORM_VFPFRAME  L7wwServerFormVFPFrame
#ENDIF

#UNDEF DEBUGMODE
#DEFINE DEBUGMODE .F.  && can be overridden for *some* debugging situations

#DEFINE L7_INI_FILENAME "wcmain.ini"

#DEFINE L7BR   [<br />]  && gives option to switch to <br /> or <br/> in the future (XHTML-compliant)

#UNDEF  CR
#DEFINE CR     CHR(13)+CHR(10)

#UNDEF  CRLF
#DEFINE CRLF   CHR(13)+CHR(10)

#UNDEF  MAX_DWORD
#DEFINE MAX_DWORD         4294967296    && 0xffffffff + 1 

#DEFINE SP     "&nbsp;"
#DEFINE BULLET "&#149;"  && highly discouraged for actual lists! (not semantic/parseable)

#UNDEF  AMPERSAND_ENCODED 
#DEFINE AMPERSAND_ENCODED "&amp;"

* character lists for Validation:
#DEFINE L7_INVALID_FILENAME_CHARACTERS "\/:;*?<>|"  && cause conflicts with backup programs
#DEFINE L7_ALPHA_CHARACTERS "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
#DEFINE L7_NUMBER_CHARACTERS "0123456789"
#DEFINE L7_DATETIME_CHARACTERS L7_NUMBER_CHARACTERS + "-T:.Z" && assume ttoc(t, 3) format
* like \w in regex:
#DEFINE L7_WORD_CHARACTERS L7_ALPHA_CHARACTERS + L7_NUMBER_CHARACTERS + "_"

#DEFINE L7_PUNCTUATION_CHARACTERS " ,/@!?#*&-+=$%.<>;:'" + '"'
#DEFINE L7_URL_PUNCTUATION_CHARACTERS "%/?=&;" + "\"
#DEFINE L7_BRACKET_CHARACTERS "[](){}"
* good starter for common data entry:
#DEFINE L7_FIELD_CHARACTERS L7_WORD_CHARACTERS + L7_PUNCTUATION_CHARACTERS + L7_BRACKET_CHARACTERS
* good starter for query forms: 
#DEFINE L7_QUERY_CHARACTERS L7_WORD_CHARACTERS + " ,-.+"
* default for request.queryString validating: 
#DEFINE L7_QS_CHARACTERS L7_WORD_CHARACTERS + " ,-.+"

* passwords: (following previously had ?=.<>;: too, which were outside policy)
#DEFINE L7_PASSWORD_SPECIAL_CHARACTERS "!@#$%^&*_-+" 
#DEFINE L7_PASSWORD_CHARACTERS L7_WORD_CHARACTERS + L7_PASSWORD_SPECIAL_CHARACTERS

#DEFINE L7_TEXTMERGE_DELIM_1  "<<"  && can use "<%=" for ASP
#DEFINE L7_TEXTMERGE_DELIM_2  ">>"  && can use "%>" for ASP

#DEFINE L7_TRANSLATE_LINKS_DELIMITER ":"

* DEPRECATED (if ever used) -- Business Object Change State:
#DEFINE L7_RECORDSTATE_UNCHANGED    0
#DEFINE L7_RECORDSTATE_MODIFIED     1
#DEFINE L7_RECORDSTATE_ADDED        2
#DEFINE L7_RECORDSTATE_DELETED      4

* Login Methods:
#DEFINE L7_LOGIN_ANON   0
#DEFINE L7_LOGIN_SCREEN 1
#DEFINE L7_LOGIN_COOKIE 1
#DEFINE L7_LOGIN_AUTH   2

* Auth Success/Failure classes:
#DEFINE L7_AUTH_SUCCESS          "L7AuthSuccess"
#DEFINE L7_AUTH_NO_ATTEMPT       "L7AuthNoAttempt"
#DEFINE L7_AUTH_BAD_FORM         "L7AuthBadForm"
#DEFINE L7_AUTH_NO_USER          "L7AuthNoUser"
#DEFINE L7_AUTH_BAD_USER         "L7AuthBadUser"
#DEFINE L7_AUTH_AMBIGUOUS_USER   "L7AuthAmbiguousUser"
#DEFINE L7_AUTH_DELETED_USER     "L7AuthDeletedUser"
#DEFINE L7_AUTH_NO_PASSWORD      "L7AuthNoPassword"
#DEFINE L7_AUTH_BAD_PASSWORD     "L7AuthBadPassword"
#DEFINE L7_AUTH_IP_UNALLOWED     "L7AuthIPUnallowed"
#DEFINE L7_AUTH_ACCOUNT_REVOKED  "L7AuthAccountRevoked"
#DEFINE L7_AUTH_ACCOUNT_DISABLED "L7AuthAccountDisabled"
#DEFINE L7_AUTH_ACCOUNT_INACTIVE "L7AuthAccountInactive"
#DEFINE L7_AUTH_PASSWORD_EXPIRED "L7AuthPasswordExpired"
#DEFINE L7_AUTH_ACCOUNT_LOCKOUT  "L7AuthAccountLockout"
#DEFINE L7_AUTH_ACCOUNT_EXPIRED  "L7AuthAccountExpired"
#DEFINE L7_AUTH_OTHER            "L7AuthOther"

* Auth POLICIES:
#DEFINE L7_AUTH_LOCKOUT_ATTEMPTS  5
#DEFINE L7_AUTH_LOCKOUT_WINDOW   15
#DEFINE L7_AUTH_LOCKOUT_CLEAR    60 

#DEFINE L6_VISIBILITY_NONE   0
#DEFINE L6_VISIBILITY_SHOW   2
#DEFINE L6_VISIBILITY_EDIT   4

#DEFINE L6_VALIDATION_UNCHANGED 0
#DEFINE L6_VALIDATION_VALID     2
#DEFINE L6_VALIDATION_INVALID   4
#DEFINE L6_VALIDATION_OVERWRITE 6

#DEFINE L6_SAVE_OK     0
#DEFINE L6_SAVE_FAIL   2
#DEFINE L6_SAVE_NOLOCK 4

** Tables: element/column types:
#DEFINE L7_ELEMENTTYPE_RECCOUNT         -3
#DEFINE L7_ELEMENTTYPE_ABSOLUTE_RECNO   -2
#DEFINE L7_ELEMENTTYPE_RELATIVE_RECNO   -1
#DEFINE L7_ELEMENTTYPE_FIXED_TEXT        0
#DEFINE L7_ELEMENTTYPE_FIELD             1
#DEFINE L7_ELEMENTTYPE_STATIC_HYPERLINK  2
#DEFINE L7_ELEMENTTYPE_DYNAMIC_HYPERLINK 3

** Tables: Calculation Types:
#DEFINE L7_CALCTYPE_NONE  1
#DEFINE L7_CALCTYPE_COUNT 2
#DEFINE L7_CALCTYPE_SUM   3
#DEFINE L7_CALCTYPE_AVG   4
#DEFINE L7_CALCTYPE_MIN   5
#DEFINE L7_CALCTYPE_MAX   6
#DEFINE L7_CALCTYPE_STDDV 7
#DEFINE L7_CALCTYPE_VAR   8

** Tables: Which columns to display:
#DEFINE L7_DISPLAYTYPE_NONE   0 && show nothing
#DEFINE L7_DISPLAYTYPE_BASE   1 && show the field value (DEFAULT)
#DEFINE L7_DISPLAYTYPE_CALC   2 && show the running calculation

** Tables: Special Row Constants:
#DEFINE L7_TABLEROWLOCATION_BEFORE_TITLE         0x0001
#DEFINE L7_TABLEROWLOCATION_AFTER_TITLE          0x0002
#DEFINE L7_TABLEROWLOCATION_AFTER_HEADING        0x0004
#DEFINE L7_TABLEROWLOCATION_BEFORE_FIRST_RECORD  0x0008
#DEFINE L7_TABLEROWLOCATION_AFTER_EACH_RECORD    0x0010
#DEFINE L7_TABLEROWLOCATION_ON_ZERO_RECORDS      0x0020
#DEFINE L7_TABLEROWLOCATION_AFTER_LAST_RECORD    0x0040
#DEFINE L7_TABLEROWLOCATION_BEFORE_GROUP_HEADER  0x0080
#DEFINE L7_TABLEROWLOCATION_AFTER_GROUP_HEADER   0x0100
#DEFINE L7_TABLEROWLOCATION_BEFORE_GROUP_FOOTER  0x0200
#DEFINE L7_TABLEROWLOCATION_AFTER_GROUP_FOOTER   0x0400
#DEFINE L7_TABLEROWLOCATION_BEFORE_GRAND_TOTALS  0x0800
#DEFINE L7_TABLEROWLOCATION_AFTER_GRAND_TOTALS   0x1000
#DEFINE L7_TABLEROWLOCATION_AFTER_EVERYTHING     0x2000

** Group Offset constant:
#DEFINE L7_GROUP_OFFSET   2 && Add this to the group number for ResetLevels

*-- MessageBox parameters
#IFNDEF MB_OK  && assume none of the rest are either
  #DEFINE MB_OK                   0       && OK button only
  #DEFINE MB_OKCANCEL             1       && OK and Cancel buttons
  #DEFINE MB_ABORTRETRYIGNORE     2       && Abort, Retry, and Ignore buttons
  #DEFINE MB_YESNOCANCEL          3       && Yes, No, and Cancel buttons
  #DEFINE MB_YESNO                4       && Yes and No buttons
  #DEFINE MB_RETRYCANCEL          5       && Retry and Cancel buttons

  #DEFINE MB_ICONSTOP             16      && Critical message
  #DEFINE MB_ICONQUESTION         32      && Warning query
  #DEFINE MB_ICONEXCLAMATION      48      && Warning message
  #DEFINE MB_ICONINFORMATION      64      && Information message
#ENDIF

*-- MsgBox return values
#IFNDEF IDOK  && assume none of the rest are either
  #DEFINE IDOK            1       && OK button pressed
  #DEFINE IDCANCEL        2       && Cancel button pressed
  #DEFINE IDABORT         3       && Abort button pressed
  #DEFINE IDRETRY         4       && Retry button pressed
  #DEFINE IDIGNORE        5       && Ignore button pressed
  #DEFINE IDYES           6       && Yes button pressed
  #DEFINE IDNO            7       && No button pressed
#ENDIF

*--- Form and Control Constants:

* Base control class from which specific controls are derived:
#DEFINE L7_CONTROL_CLASS  "L7Control"

* "nStyle" property for L7MultiControls
#DEFINE L7_MULTISTYLE_NONE          0
#DEFINE L7_MULTISTYLE_HORIZONTAL    1
#DEFINE L7_MULTISTYLE_VERTICAL      2
#DEFINE L7_MULTISTYLE_FORMATTED     3  && Wrap in a TABLE.

* "nRowSourceType" property
#DEFINE L7_ROWSOURCETYPE_NONE        0 && None (use AddItem)
#DEFINE L7_ROWSOURCETYPE_VALUE       1 && Value (comma-delimited)
#DEFINE L7_ROWSOURCETYPE_ALIAS       2 && Specify Alias 
#DEFINE L7_ROWSOURCETYPE_SQL         3 && SQL Statement 
#DEFINE L7_ROWSOURCETYPE_ARRAY       5 && Array (must be in scope)
#DEFINE L7_ROWSOURCETYPE_FIELDS      6 && Comma Delimited List
#DEFINE L7_ROWSOURCETYPE_FILES       7 && Files (specify skeleton)
#DEFINE L7_ROWSOURCETYPE_STRUCTURE   8 && Structure 
#DEFINE L7_ROWSOURCETYPE_COLLECTION 10 && Collection (must be in scope)

* "nMode" morphing settings (multi and checkbox):
#DEFINE L7_MULTI_POPUP        1
#DEFINE L7_MULTI_RADIOBUTTON  2
#DEFINE L7_MULTI_CHECKBOX     3
#DEFINE L7_MULTI_TEXTBOX      4  && just an experiment

* Flyweight values used for push/pop in Grid:
#DEFINE L7_BASECONTROL_PROPCOUNT  8

#DEFINE L7_CONTROLPROP_OLDVALUE          1
#DEFINE L7_CONTROLPROP_NEWVALUE          2
#DEFINE L7_CONTROLPROP_DISABLED          3
#DEFINE L7_CONTROLPROP_UPDATED           4
#DEFINE L7_CONTROLPROP_INVALIDCOUNT      5
#DEFINE L7_CONTROLPROP_VALIDATIONMESSAGE 6
#DEFINE L7_CONTROLPROP_DISPLAYVALUE      7
#DEFINE L7_CONTROLPROP_VISIBLE           8
#DEFINE L7_CONTROLPROP_FIRSTITEM         9

* Grid zero-row output:
#DEFINE L7_GRID_ZEROROW_NONE       0  && omit
#DEFINE L7_GRID_ZEROROW_LABEL      1  && Label only
#DEFINE L7_GRID_ZEROROW_HEADINGROW 2  && table with column headings
#DEFINE L7_GRID_ZEROROW_BLANKROW   3  && plus a row of &nbsp; 's

* SYSLOG-like severity: (actual Syslog values start at 0)
#DEFINE L7_SEVERITY_EMERGENCY 1  && system unusable (email + page)
#DEFINE L7_SEVERITY_ALERT     2  && immediate action needed (email + page)
#DEFINE L7_SEVERITY_CRITICAL  3  && critical conditions
#DEFINE L7_SEVERITY_ERROR     4  && 
#DEFINE L7_SEVERITY_WARNING   5  && 
#DEFINE L7_SEVERITY_NOTICE    6  && normal but significant 
#DEFINE L7_SEVERITY_INFO      7  && info-only
#DEFINE L7_SEVERITY_DEBUG     8  && debug-level messages
#DEFINE L7_SEVERITY_NONE      9  && state of log before anything added 
* special values:
#DEFINE L7_SEVERITY_DEFAULT       L7_SEVERITY_INFO
#DEFINE L7_SEVERITY_DEFAULT_NAME  "INFO"
#DEFINE L7_SEVERITY_MOST      L7_SEVERITY_EMERGENCY 
#DEFINE L7_SEVERITY_LEAST     L7_SEVERITY_DEBUG
* validate: between( <nVar>, L7_SEVERITY_MOST, L7_SEVERITY_LEAST )
*-- Standard user "override" approach. Keep this last!!
#IF FILE( "L7_OVERRIDE.H")
  #INCLUDE L7_OVERRIDE.H
#ENDIF


* History:
* 01/18/2003 - added L7BR.
*            - added L7_RELEASE_ID (as 1.03.03)
* 03/07/2003 - added L7_ROWSOURCETYPE_COLLECTION
* 06/15/2003 - removed some retired settings
* 11/21/2003 - moved form stuff to bottom (easier to find)
*            - added XMLDOM definition 
* 12/31/2003 - moved HTML colors to (new) L7_DEPRECATED.H
*            - added L7_WC_FRAMEWORK flag to differentiate framework use vs. just controls 
*            - added some IFNDEF blocks to improve chances of working with other libraries
* 09/06/2004 - added L7_DEFAULT_JAVASCRIPT_VERSION as "1.2"