* L7LogParser.PRG
#include L7.H

*--- TEST CODE:

#DEFINE test_input_folder [.\Test\]

#define test_maxfiles 0
#define test_start_date {^2010-11-06}
#define test_end_date {^2010-11-06}

LPARAMETERS ldStart, ldEnd, lcInputPath

set procedure to L7Table, L7TableRender, L7Utils, L7Textstream, L7PageElement, L7PageElements, L7Iterator, L7Parsers, L7HtmlLib additive 
set procedure to wwUtils, wwAPI, wwSmtp additive 

ldStart = EVL(m.ldStart, TEST_START_DATE)
ldEnd = EVL(m.ldEnd, TEST_END_DATE)
lcInputPath = EVL(m.lcInputPath, TEST_INPUT_FOLDER)
CLEAR

LOCAL lcObs, loObservers, laObs[1], loProc, lcObsClass, lcObsKey
loObservers = CREATEOBJECT('Collection')

* Match Morning Report:
WITH loObservers

  .Add(CREATEOBJECT('L7TalkLogObserver'), 'Talk')

  .Add(CREATEOBJECT('L7UnparseablePathLogObserver'), 'UnparseablePath')

  lcObsKey = 'Watched IPs'
  .Add(CREATEOBJECT('L7GenericLogObserver'), m.lcObsKey)
    .item(m.lcObsKey).lNoteVirtual = .T.
    .item(m.lcObsKey).cIPs = "204.68.195.14"
    .item(m.lcObsKey).lNoteIP = .T.
    .item(m.lcObsKey).lNoteOutputSize = .T.
    .item(m.lcObsKey).lConsumeHits = .T.
    .item(m.lcObsKey).lGroupHits = .T.
    .item(m.lcObsKey).cReportOrder = "IPAddress, OutputSize DESCENDING"

    
*!*        <observer vfpClass="L7GenericLogObserver" active="1">
*!*          <param name="cName" value="Watched IPs" />
*!*          <param name="cIPs" value="204.68.195.14" />
*!*          <param name="lNoteIP" value=".T." />
*!*          <param name="lNoteVirtual" value=".T." />
*!*          <param name="lNoteOutputSize" value=".T." />
*!*          <param name="lConsumeHits" value=".F." />
*!*          <param name="lGroupHits" value=".T." />
*!*          <param name="cReportOrder" value="IPAddress, OutputSize DESCENDING" />
*!*        </observer>

  .Add(CREATEOBJECT('L7UnhandledLogObserver'), 'Unhandled')
    .item('Unhandled').cName = 'Hits Not "Claimed" By Above Observers'

endwith 

*!*  * Stakeholder site totals:
*!*  WITH loObservers

*!*    .Add(CREATEOBJECT('L7TalkLogObserver'), 'Talk')

*!*    .Add(CREATEOBJECT('L7UnparseablePathLogObserver'), 'UnparseablePath')

*!*    .Add(CREATEOBJECT('L7GenericLogObserver'), 'IgnoreStems')
*!*      .item('IgnoreStems').cStatuses = '200'
*!*      .item('IgnoreStems').cFilenames = 'robots.txt, favicon.ico'
*!*      .item('IgnoreStems').lNoteFilename = .T.
*!*      .item('IgnoreStems').lNoteVirtual = .F.
*!*      .item('IgnoreStems').lNoteStatus = .F.
*!*      .item('IgnoreStems').cName = 'Ignore Specific File Names'

*!*    ** .Add(CREATEOBJECT('L7IgnoreStemsLogObserver'),     'OldIgnoreStems')

*!*    .Add(CREATEOBJECT('L7GenericLogObserver'), '404Status')
*!*      .item('404Status').cStatuses = '404'
*!*      .item('404Status').lNoteVirtual = .T.
*!*      .item('404Status').lNoteFilename = .T.
*!*      .item('404Status').lNoteStatus = .F.
*!*      .item('404Status').lNoteFileType = .F.
*!*      .item('404Status').cName = '404 Responses'
*!*      .item('404Status').lGroupHits = .T.
*!*      
*!*    .Add(CREATEOBJECT('L7GenericLogObserver'), '400Status')
*!*      .item('400Status').cStatuses = '40*, 50*'
*!*      .item('400Status').lNoteVirtual = .T.
*!*      .item('400Status').lNoteStatus = .T.
*!*      .item('400Status').lNoteFileType = .F.
*!*      .item('400Status').cName = '400 and 500 Status Responses'


*!*    .Add(CREATEOBJECT('L7GenericLogObserver'), 'IgnoreStatuses')
*!*      .item('IgnoreStatuses').cStatuses = '206,302,304,307'
*!*      .item('IgnoreStatuses').lNoteVirtual = .F.
*!*      .item('IgnoreStatuses').lNoteStatus = .T.
*!*      .item('IgnoreStatuses').cName = 'Ignore Specific HTTP Status Responses'


*!*    .Add(CREATEOBJECT('L7GenericLogObserver'), 'IgnoreFileTypes')
*!*      .item('IgnoreFileTypes').cStatuses = '200'
*!*      .item('IgnoreFileTypes').cFileTypes = 'jpg,gif,png,jpeg,css,js'
*!*      .item('IgnoreFileTypes').lNoteFileType = .T.
*!*      .item('IgnoreFileTypes').lNoteVirtual = .F.
*!*      .item('IgnoreFileTypes').lNoteStatus = .T.
*!*      .item('IgnoreFileTypes').cName = 'Ignore Specific File Types'



*!*  *!*    .Add(CREATEOBJECT('L7DayAndPageStatsLogObserver'), 'PageStats')
*!*  *!*      .item('PageStats').cVirtuals = ',comm,'
*!*  *!*      .item('PageStats').cName = 'Stakeholder Site Page Counts'

*!*    .Add(CREATEOBJECT('L7GenericLogObserver'), 'OtherVirtuals')
*!*      .item('OtherVirtuals').cStatuses = '200'
*!*      .item('OtherVirtuals').cVirtuals = NULL
*!*      .item('OtherVirtuals').lNoteVirtual = .T.
*!*      .item('OtherVirtuals').cName = 'Other Unhandled Virtual Paths'

*!*    .Add(CREATEOBJECT('L7GenericLogObserver'), 'OtherHits')
*!*      .item('OtherHits').lNoteStatus = .T.
*!*      .item('OtherHits').lNoteVirtual = .T.
*!*      .item('OtherHits').cName = 'Other Hits'

*!*    .Add(CREATEOBJECT('L7UnhandledLogObserver'), 'Unhandled')
*!*      ** .item('Unhandled').cName = 'Hits Not "Claimed" By Above Observers'

*!*  ENDWITH  

loProc = CREATEOBJECT('L7LogParser')
WITH loProc
  .SetObservers(m.loObservers)
  .SetLogFilePath(m.lcInputPath)
  .nMaxFiles = test_maxfiles
  .dStartDate = m.ldStart
  .dEndDate = m.ldEnd
  .Parse()
  SET MEMOWIDTH TO 100
  ? .cReport + .cWarnings
  _CLIPTEXT = .cReport
  
ENDWITH
RELEASE loProc
SET PROCEDURE TO 
CLEAR PROGRAM 
CLEAR ALL
RETURN

*--- end: TEST CODE.

*** ========================================================= ***
DEFINE CLASS L7LogParser as Custom

  cContentType = "text/html"
  lHTML = null && access mthd

  cLogFilePath = NULL       && where to look for web server logs
  nMaxFiles = 0             && if >0, ceases processing after N files
  nFilesProcessed = 0
  
  * Date range of files to process:
  dStartDate = NULL         && if not NULL, restricts date range
  dEndDate = NULL           && same; suggest setting to avoid active log file!

  * Overall counts and status properties:
  nDirectives = 0
  cDirectives = ''
  nHits = 0                 && hits processed current file
  nTotalHits = 0            && total hits processed; observers can also maintain their own counts
  cSummary = ""
  cReport = ""
  cWarnings = ""
  nWarnings = 0
  
  * Current file being processed:
  cCurrentFile = ''
  dCurrentDate = {}
  cCurrentFields = ''
  lFileBlocked = .F.        && observer can block a file in response to WouldProcessFile event
  *
  cFieldPattern = ''
  *
  lLineConsumed = .F.       && observer sets this to "eat" (claim) the hit
  cCurrentLine = ''
  cPreviousLine = ''
  
  * Members and other objects:
  oCurrentHit = NULL
  oPreviousHit = NULL  
  ADD OBJECT Fields as Collection
  ADD OBJECT RegExps AS Collection
  * --------------------------------------------------------- *
  function lHTML_ACCESS
    return this.cContentType == "text/html"
  endfunc 
  * --------------------------------------------------------- *
  FUNCTION init 
    DECLARE Integer Sleep IN WIN32API
    LOCAL loRE
    loRE = CREATEOBJECT(L7_REGEXP_CLASS)
    loRE.global = .T.
    loRE.Pattern = '([^\s]+)(?:\s|$)'
    THIS.RegExps.Add(m.loRE, "FieldList")
    THIS.RegExps.Add(CREATEOBJECT(L7_REGEXP_CLASS), "SingleHit")
    * hit pattern is created each time field directives are found
    THIS.CreateHitObjects()
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION CreateHitObjects()
    THIS.oCurrentHit = CREATEOBJECT('L7LogParserHit')
    THIS.oPreviousHit = CREATEOBJECT('L7LogParserHit')
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetLogFilePath(lcPath)
    THIS.cLogFilePath = ADDBS(m.lcPath)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION SetObservers(loColl)
    LOCAL loObs, lnItem
    ** FOR EACH loObs IN loColl  && cannot use because of FOXOBJECT bug!!
    FOR lnItem = 1 TO loColl.Count
      loObs = loColl.item(m.lnItem)
      loObs.Setup(this)
    ENDFOR
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION Parse
    RAISEEVENT(this, 'WouldProcessFiles', this)
    LOCAL lnFiles, laFiles[1], lcFile, ldDate
    THIS.nFilesProcessed = 0
    lnFiles = ADIR(laFiles, this.cLogFilePath + [*.log])
    ? lnFiles, "total files in path"
    FOR lnFile = 1 TO m.lnFiles
      lcFile = laFiles(m.lnFile, 1)
      TRY
      	ldDate = DATE(2000 + VAL(SUBSTR(lcFile,3,2)), VAL(SUBSTR(lcFile,5,2)), VAL(SUBSTR(lcFile,7,2)))
      CATCH
      	ldDate = NULL
      ENDTRY
      IF ISNULL(m.ldDate) OR EMPTY(m.ldDate)
      	LOOP
      ENDIF
      IF (NOT ISNULL(this.dStartDate) AND m.ldDate < this.dStartDate) OR ;
          (NOT ISNULL(this.dEndDate) AND m.ldDate > this.dEndDate)
        LOOP
      ENDIF
      THIS.dCurrentDate = m.ldDate
      THIS.nFilesProcessed = THIS.nFilesProcessed + 1  
      this.cCurrentFile = m.lcFile
      this.lFileBlocked = .F. && clear from any previous setting
      RAISEEVENT(this, 'WouldProcessFile', this)
      IF NOT THIS.lFileBlocked  && allows an observer to block a file
        this.ProcessFile(m.lcFile)
        this.nTotalHits = this.nTotalHits + THIS.nHits  && add file hits to total hits
        RAISEEVENT(THIS, 'DidProcessFile', this)
        
      ENDIF
      IF this.nMaxFiles > 0 AND THIS.nFilesProcessed >= this.nMaxFiles
        EXIT
      ENDIF
      TRY
        Sleep(500)  && ms between files
      CATCH
      ENDTRY
    ENDFOR
    RAISEEVENT(this, 'DidProcessFiles', this)
    THIS.cReport = THIS.cReport + CRLF + ;
      TEXTMERGE([<<TRANSFORM(THIS.nTotalHits, "999,999,999")>> TOTAL HITS PROCESSED.]) + CRLF + ;
      TEXTMERGE([<<TRANSFORM(THIS.nFilesProcessed, "999,999,999")>> DAILY LOG FILES PROCESSED.]) + CRLF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION AddWarning(lcMsg)
    THIS.nWarnings = THIS.nWarnings + 1 
    THIS.cWarnings = THIS.cWarnings + m.lcMsg + CRLF 
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION WouldProcessFiles(loSelf)
  ENDFUNC
  FUNCTION DidProcessFiles(loSelf)
  ENDFUNC
  FUNCTION OnFileOpenFailure(loSelf)
    WITH loSelf
      THIS.AddWarning("Could not open file for processing: " + .cCurrentFile)
    ENDWITH 
    RETURN 
  ENDFUNC
  FUNCTION WouldProcessFile(loSelf)
  ENDFUNC
  FUNCTION DidProcessFile(loSelf)
  ENDFUNC
  FUNCTION WouldProcessDirectives(loSelf)
  ENDFUNC
  FUNCTION DidProcessDirectives(loSelf)
  ENDFUNC
  FUNCTION WouldParseFields(loSelf)
  ENDFUNC
  FUNCTION WouldProcessHits(loSelf)
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ProcessFile(lcFile)
    LOCAL nn, hh, ss, llDirecs, llInDirecs
    STORE 0 TO THIS.nHits, THIS.nDirectives
    nn = 0
    hh = FOPEN(this.cLogFilePath + m.lcFile, 0)
    IF m.hh > 0
      DO WHILE NOT FEOF(m.hh)
        ss = FGETS(m.hh, 8192)
        nn = m.nn + 1 
        IF m.nn % 100 = 0
          TRY
            Sleep(20)  && ms every 100 lines [[PARAMETERIZE THIS]]
          CATCH
          ENDTRY
        ENDIF

        IF EMPTY(m.ss)  && are blank lines allowed per spec? assume yes...
          LOOP
        ENDIF 
        IF m.ss = "#"  && directive, rather than hit
          llDirecs = .T.
          IF NOT m.llInDirecs
            RAISEEVENT(this, 'WouldProcessDirectives', this)
            this.cDirectives = ""
            llInDirecs = .T. && flag indicates we're in the middle of
            * processing directives, which occur over several lines
          ENDIF 
          THIS.nDirectives = THIS.nDirectives + 1 
          this.cDirectives = this.cDirectives + m.ss + CRLF
          IF LOWER(ALLTRIM(GETWORDNUM(m.ss, 1, ":"))) == "#fields"
            this.cCurrentFields = GETWORDNUM(m.ss, 2, ":")
            RAISEEVENT(this, 'WouldParseFields', this)
            this.ParseFields()
          ENDIF 
        ELSE
          IF NOT m.llDirecs
            ERROR "No log file directive lines in file: " + m.lcFile
          ENDIF 
          IF m.llInDirecs  && last line was a directive, this is first hit
            RAISEEVENT(this, 'DidProcessDirectives', this)
            this.WouldProcessHits(this)
            llInDirecs = .F.
          ENDIF 
          this.cCurrentLine = m.ss
          this.lLineConsumed = .F.
          RAISEEVENT(this, 'readHit', this)
          THIS.nHits = THIS.nHits + 1 
        ENDIF
        
      ENDDO
      FCLOSE(m.hh)
      ? lcFile, nn, "lines in file"
    ELSE
      RAISEEVENT(this, 'OnFileOpenFailure', this) 
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION ParseFields()
    LOCAL loRE, lnMatches, loMatches, loMatch, lcField, lcFldPattern
    lcFldPattern = ""
    this.Fields.Remove(-1)
    loRE = THIS.RegExps("FieldList")
    
    loMatches = loRE.Execute(this.cCurrentFields)
    lnMatches = loMatches.Count
    FOR EACH loMatch IN loMatches
      **loMatch = loMatches.item(0)
      lcField = ALLTRIM(loMatch.value)
      this.Fields.add(m.lcField, m.lcField)
      ** ? m.lcField
      lcFldPattern = m.lcFldPattern + "\s*([^\s]+)"
    ENDFOR
    IF NOT m.lcFldPattern == THIS.RegExps("SingleHit").Pattern
      THIS.RegExps("SingleHit").Pattern = m.lcFldPattern
      ** ? this.cCurrentFields
      ** ? m.lcFldPattern
      THIS.cFieldPattern = m.lcFldPattern
    ENDIF
    ** ? lnMatches, loMatch.Value
    RETURN .T.
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION ReadHit(loSelf)
    EXTERNAL ARRAY loFlds
    LOCAL loFlds, lnField, lcField, lcVal, loRE, loMatches, loTemp, loExc
    loFlds = this.Fields
    loRE = THIS.RegExps('SingleHit')
    loMatches = loRE.Execute(THIS.cCurrentLine)
    IF loMatches.Count <> 1
      RAISEEVENT(this, "onBadLine", this, "noMatch")
    ELSE
      loMatch = loMatches.item(0)
      IF loMatch.Submatches.Count <> THIS.Fields.Count
        RAISEEVENT(this, "onBadLine", this, "badFieldCount")
      ELSE
        * swap objects, in case an observer wants to see previous hit
        loTemp = this.oPreviousHit
        this.oPreviousHit = this.oCurrentHit
        this.oCurrentHit = m.loTemp  
        WITH this.oCurrentHit
          .Reset()
          FOR lnField = 1 TO loFlds.Count
            lcField = loFlds[m.lnField]
            lcVal = loMatch.Submatches(m.lnField - 1)
            DO CASE
            CASE m.lcField == "date"  && yyyy-mm-dd
              .dDate = CTOD([^] + m.lcVal)
            CASE m.lcField == "time"  && nn:nn:nn
              .cTime = m.lcVal  
              .nHour = VAL(LEFT(.cTime, 2))
            CASE m.lcField == "sc-status"
              .nStatus = VAL(m.lcVal)
            CASE m.lcField == "c-ip"
              .cClientIp = m.lcVal
              TRY
                .cNetwork = IpToNetwork(.cClientIp)
              CATCH
              ENDTRY 
            CASE m.lcField == "cs(Referer)"
              .cReferer = IIF(m.lcVal == "-", "", m.lcVal)
            CASE m.lcField == "cs-method"
              .cMethod = m.lcVal
            CASE m.lcField == "time-taken"
              .nDuration = VAL(m.lcVal) / 1E+3  && store in seconds, not ms
            CASE m.lcField == "sc-bytes"
              .nOutputSize = VAL(m.lcVal)
            CASE m.lcField == "cs-bytes"
              .nInputSize = VAL(m.lcVal)
            CASE m.lcField == "cs-uri-stem"
            	* NOTE: Need a general review of where LOWER() is used (throughout this module),
            	* and whether there is need for a case-sensitive switch.
              .cLogicalPath = m.lcVal
              TRY
                .cExtension = LOWER(JUSTEXT(m.lcVal))
                .cStem = LOWER(JUSTSTEM(m.lcVal))
                .cPath = LOWER(JUSTPATH(m.lcVal))
              CATCH
                * some hacks create strings that cause errors in path functions
                * ex: <script> embedded in URL
              ENDTRY
            CASE m.lcField == "cs-uri-query"
              .cQueryString = m.lcVal
            CASE m.lcField == "cs(User-Agent)"
              .cUserAgent = m.lcVal
            CASE m.lcField == "cs(Cookie)"
              .cCookie = m.lcVal
            CASE m.lcField == "cs-username"
              .cUserName = m.lcVal
            ENDCASE
          ENDFOR
          
        ENDWITH 
      ENDIF
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------------- *
  FUNCTION onBadLine(loSelf, lcReason)
    RETURN 
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION statusMessage(loObs, lcMessage, llVerbose)
    RETURN
  ENDFUNC
  * --------------------------------------------------------- *
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7LogParserHit as Line
	*
	* CAUTION: When adding any property here, BE CERTAIN to 
	*   add a mathcing line to the Reset() method (object reuse).
	*
  dDate = NULL
  cTime = NULL
  nHour = NULL
  nStatus = NULL
  cReferer = NULL
  cClientIp = NULL
  cNetwork = NULL  && calc from IP
  nDuration = NULL
  nOutputSize = NULL
  nInputSize = NULL
  cMethod = NULL
  cLogicalPath = NULL  
  cExtension = NULL  && calc
  cStem = NULL  && calc
  cPath = NULL  && calc
  cQueryString = NULL
  cUserAgent = NULL
  cUserName = NULL
  cCookie = NULL
  * ---------------------------------------- *
  FUNCTION Reset
    WITH this
      .dDate = NULL
      .cTime = NULL
      .nHour = NULL
      .nStatus = NULL
      .cReferer = NULL
      .cClientIp = NULL
      .cNetwork = NULL
      .nDuration = NULL
      .nOutputSize = NULL
      .nInputSize = NULL
      .cMethod = NULL
      .cLogicalPath = NULL
      .cExtension = NULL
      .cStem = NULL
      .cPath = NULL
      .cQueryString = NULL
      .cUserAgent = NULL
      .cUserName = NULL
      .cCookie = NULL
    ENDWITH 
  ENDFUNC 
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7TalkLogObserver AS L7LogObserver
  * "TALK" observer relays status messages to screen. Used
  * when running from an IDE during development/testing.
  * Place anywhere in chain.
  lCountHits        = .F.
  lConsumeHits      = .F.
  * --------------------------------------------------------- *
  FUNCTION setup(loParser)
    BINDEVENT(m.loParser, 'StatusMessage', THIS, 'echoStatusMessage')
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION echoStatusMessage(loObs, lcMessage, llVerbose)
    ? loObs.Class + ":", m.lcMessage
  ENDFUNC 
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7UnparseablePathLogObserver as L7LogObserver
  nReportHitThreshhold = 1  && don't report if no hits
  * --------------------------------------------------------- *
  FUNCTION setup(loParser)
    BINDEVENT(m.loParser, 'ReadHit', THIS, 'CheckStatus', 3)
    BINDEVENT(m.loParser, 'DidProcessFiles', THIS, 'NoteFilesEnd')
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION CheckStatus(loParser)
    WITH loParser
      IF .lLineConsumed = .T.
        RETURN
      ENDIF
      IF ISNULL(.oCurrentHit.cExtension) OR ISNULL(.oCurrentHit.cPath) OR ISNULL(.oCurrentHit.cStem)
        * Error parsing out uri-stem (hack!): most other parsers would fail.
        .lLineConsumed = .T. && claim hit and eat
        this.nHits = this.nHits + 1 
      ENDIF
    ENDWITH
  ENDFUNC
ENDDEFINE  && L7UnparseablePathLogObserver

*** ========================================================= ***
DEFINE CLASS L7UnhandledLogObserver as L7LogObserver
  * "Unhandled Hit" observer: operates on all hits that aren't
  * consumed by anything else; can optionally consume the 
  * hit, or just count things going by.
  * Typically placed at end of observer chain.
  cName = 'Hits Not "Claimed" By Above Observers'
  lConsumeHits      = .F.  && if .T., also consumes the hit
  lCountHits        = .T.  && if .T. (default), counts the hit
  lNoteLogicalPaths = .F.  && if .T., records distinct logical paths
  * --------------------------------------------------------- *
  FUNCTION setup(loParser)
    BINDEVENT(m.loParser, 'ReadHit', THIS, 'CheckStatus', 3)
    BINDEVENT(m.loParser, 'DidProcessFiles', THIS, 'NoteFilesEnd')
    THIS.cAlias = THIS.Class + [_] + SYS(2015)
    SELECT 0
    CREATE CURSOR (THIS.cAlias) (PageCRC C(10), Hits I, Page C(150))
    INDEX ON PageCRC TAG PageCRC
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION CheckStatus(loParser)
    IF loParser.lLineConsumed = .F.
      IF THIS.lConsumeHits
        loParser.lLineConsumed = .T. 
      ENDIF 
      IF THIS.lCountHits
        THIS.nHits = THIS.nHits + 1 
        IF THIS.lNoteLogicalPaths
          LOCAL lcVirtual, loHit, lcCrc
          loHit = loParser.oCurrentHit
          lcCRC = SYS(2007, loHit.cLogicalPath, -1, 1)

          SELECT (THIS.cAlias)
          LOCATE FOR PageCRC = m.lcCRC
          IF NOT FOUND()
            APPEND BLANK
            REPLACE PageCRC WITH m.lcCRC, Page WITH loHit.cLogicalPath
          ENDIF
          REPLACE Hits WITH Hits + 1
        ENDIF 
      ENDIF 
      ** INSERT INTO (THIS.cAlias) VALUES (loParser.oCurrentHit.cLogicalPath)
    ENDIF
  ENDFUNC
ENDDEFINE

*** ========================================================= ***
DEFINE CLASS L7CountLogObserver as L7LogObserver
  * --------------------------------------------------------- *
  FUNCTION setup(loParser)
    BINDEVENT(m.loParser, 'WouldProcessFile', THIS, 'NoteFileStart')
    BINDEVENT(m.loParser, 'DidProcessFile', THIS, 'NoteFileEnd')
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION NoteFileStart(loParser)
    ** ? loParser.cCurrentFile, loParser.dCurrentDate
    RAISEEVENT(loParser, "StatusMessage", THIS, ;
      TRANSFORM(loParser.cCurrentFile) + ' ' + TRANSFORM(loParser.dCurrentDate))
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION NoteFileEnd(loParser)
    ** ? loParser.nDirectives, loParser.nHits
    RAISEEVENT(loParser, "StatusMessage", THIS, TRANSFORM(loParser.nHits))
  ENDFUNC 
ENDDEFINE

*** Next few classes are property-only subclasses of L7GenericLogObserver.
*** These are included to allow easy insertion of "standard" observer needs
*** from XML config, without needing to specify lots of property overrides.
*** ========================================================= ***
DEFINE CLASS L7BrokenLinksLogObserver AS L7GenericLogObserver 
  cName = "Broken Links Observer (Refered 400-Status Hits)"
  lConsumeHits = .T.  && subsequent observers should ignore hits
  cStatuses = "404"
  lNoteLogicalPath = .T.  && this instead, so we see path/directory issues
  lNoteReferer = .T.
  lRefererEmpty = .F.
  lGroupHits = .T.  && .F. to list hits individually
  cReportOrder = "LogicPath"
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7IgnoreForbiddenLogObserver AS L7GenericLogObserver 
  cName = 'FILTER Forbidden Requests (403 Status)'
  lConsumeHits = .T.  && subsequent observers should ignore hits
  cStatuses = '403'
  lNoteIP = .T.
  lNoteDate = .T.
  lNoteMethod = .T.
  lGroupHits = .T.  && counts hits by IP
  cReportOrder = "IPAddress, HitDate, Method"
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7ServerErrorsLogObserver AS L7GenericLogObserver 
  cName = "FILTER Server Errors (500-series HTTP Status) Hits"
  lConsumeHits = .T.
  cStatuses = "50*"
  lNoteStatus = .T.
  lNoteMethod = .T.
  lNoteVirtual = .T.
  lNoteFilename = .T.
  lGroupHits = .T. 
  cReportOrder = "Virtual, Status, Method, Filename"
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7BadStatusFilenamesLogObserver AS L7GenericLogObserver 
  cName = "FILTER 400-500 Status Hits"
  lConsumeHits = .T.
  cStatuses = "40*,50*"
  lNoteStatus = .T.
  lNoteMethod = .T.
  lNoteVirtual = .T.
  lNoteFilename = .T.
  lGroupHits = .T. 
  cReportOrder = "Virtual, Status, Method, Filename"
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7CountByFilenamesLogObserver AS L7GenericLogObserver 
  cName = "Hit Counts by Filename"
  lConsumeHits = .F.  && can override
  cStatuses = "200"
  lNoteStatus = .F.
  lNoteLogicalPath = .T.
  lGroupHits = .T. 
  cReportOrder = "LogicPath"
  * To use this as an observer for a *single* virtual, change to:
  *   cVirtuals = "/myVirtual"  (example)
  *   cReportOrder = "Hits DESCENDING"
  *   nReportHitThreshhold = 10 (optional, example)
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7IgnoreCommonTypesLogObserver AS L7GenericLogObserver 
  cName = 'FILTER Specific File Extensions'
  lConsumeHits = .T.  && subsequent observers should ignore hits
  cStatuses = '200,304'  && OK or Not Modified
  cFileTypes = 'jpg,gif,png,jpeg,css,js'
  lNoteFileType = .T.
  lNoteVirtual = .F.
  lNoteStatus = .F.
  lGroupHits = .T.  && counts hits by type
  cReportOrder = "FileType"
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7IgnoreFilesLogObserver AS L7GenericLogObserver 
  cName = 'FILTER Specific Generic Files'
  lConsumeHits = .T.  && subsequent observers should ignore hits
  cFilenames = 'robots.txt, favicon.ico'
  lNoteFilename = .T.
  lNoteVirtual = .F.
  lNoteStatus = .F. && status-neutral to cover policies against robots.txt that produce 403's
  lGroupHits = .T.  && counts hits by filename
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7CountByVirtualLogObserver AS L7GenericLogObserver 
  cName = "Hit Counts by Virtual Directory"
  lConsumeHits = .F.  && subsequent observers also will examine hit
  lNoteStatus = .F.
  cStatuses = "200"   && only count delivered responses (OK)
  lNoteVirtual = .T.
  cReportOrder = "Virtual, Hits DESCENDING"
  lGroupHits = .T.
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7BrowserDistributionLogObserver AS L7GenericLogObserver 
  cName = "Browser Distribution (>= 50 hits)"
  lConsumeHits = .F.  && subsequent observers also will examine hit
  lNoteStatus = .F.
  * cStatuses = "200"   && only count delivered responses (OK)
  lNoteUA = .T.
  cReportOrder = "Hits DESCENDING"
  nReportHitThreshhold = 50
  lGroupHits = .T.
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7CountByStatusLogObserver AS L7GenericLogObserver 
  cName = "Hit Counts by HTTP Status"
  lConsumeHits = .F.  && subsequent observers also will examine hit
  lNoteStatus = .T.
  cReportOrder = "Status"
  lGroupHits = .T.
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7CountByNetworkLogObserver AS L7GenericLogObserver 
  cName = "Hit Counts by Client Network (>= 10 hits)"
  lConsumeHits = .F.  && subsequent observers also will examine hit
  lNoteNetwork = .T.
  lNoteStatus = .F.
  cReportOrder = "Hits DESCENDING"
  lGroupHits = .T.
  nReportHitThreshhold = 10 
ENDDEFINE 

*** ========================================================= ***
DEFINE CLASS L7GenericLogObserver AS L7LogObserver

  lNoteHour = .F.
  lNoteDate = .F.
  lNoteTime = .F.
  cTimeStart = NULL
  cTimeEnd = NULL
  
  cVirtuals = NULL  && comma-delim list to request specific virtuals
  lNoteVirtual = .F.
  
  cStatuses = NULL  && often you'll want to set at "200"
  lNegateStatuses = .F.
  lNoteStatus = .F. && had been .T. by default, changed for consistency
  
  cNetworks = NULL  
  lNoteNetwork = .F.
  
  cIPs = NULL  
  lNoteIP = .F.
  
  cUAs = NULL  
  lNoteUA = .F.

  cMethods = NULL
  lNegateMethods = .F.
  lNoteMethod = .F.
  
  cFileTypes = NULL  
  lNoteFileType = .F.
  
  cStems = NULL  
  lNoteStem = .F.

  cFilenames = NULL  
  lNoteFilename = .F.
  
  cPaths = NULL
  lNegatePaths = .F.  && if T, all *but* cPaths chosen
  lNotePath = .F.

  cLogicalPaths = NULL
  lNoteLogicalPath = .F.

  lNoteReferer = .F.
  lRefererEmpty = NULL && .T. for empty, .F. for not empty
  cReferers = NULL
  
  nMinDuration = NULL  && filter for long requests
  lNoteDuration = .F.
  
  nMinInputSize = NULL  && filter for large requests
  lNoteInputSize = .F.

  nMinOutputSize = NULL  && filter for large responses
  lNoteOutputSize = .F.

  cReportOrder = NULL  && if not null, order results by this
  nReportTopN = NULL  && if not null, report only TOP n hits
  nReportHitThreshhold = NULL  && if not null, report all grouped items with N+ hits
  *[[ need threshhold for output size too
  
  lNoteHits = .T.  && .F. to record each hit
  lGroupHits = .T.  && .T. for grouping / .F. to list hits individually (applies only if lNoteHits is true)
  lGraphHits = .F.  && (applies only if lNoteHits *and* lGraphHits are true)

  lCountHits        = .T.  && if .T., counts the hit
  lConsumeHits      = .T.  && if .T., also consumes the hit
  * --------------------------------------------------------- *
  function setup(loParser)
    BINDEVENT(m.loParser, 'ReadHit', THIS, 'CheckStatus', 3)
    BINDEVENT(m.loParser, 'DidProcessFiles', THIS, 'NoteFilesEnd')
    local lcStr
    with this
      * if this observer notes hits, build a CURSOR for recording temp data
      if .lNoteHits 
        THIS.cAlias = THIS.Class + "_" + SYS(2015)
        lcStr = ""
        IF .lGroupHits
          lcStr = m.lcStr + [, Hits I]
        ENDIF 
        IF .lNoteDuration
          lcStr = m.lcStr + [, Duration N(12,3)]
        ENDIF 
        IF .lNoteInputSize
          lcStr = m.lcStr + [, InputSize N(12,0)]
        ENDIF 
        IF .lNoteOutputSize
          lcStr = m.lcStr + [, OutputSize N(12,0)]
        ENDIF 
        IF .lNoteDate
          lcStr = m.lcStr + [, HitDate D]
        ENDIF 
        IF .lNoteTime
          lcStr = m.lcStr + [, HitTime C(8)]
        ENDIF 
        IF .lNoteHour
          lcStr = m.lcStr + [, HitHour N(2,0)]
        ENDIF 
        IF .lNoteStatus
          lcStr = m.lcStr + [, Status N(3, 0)]
        ENDIF 
        IF .lNoteNetwork
          lcStr = m.lcStr + [, Network C(15)]
        ENDIF 
        IF .lNoteIP
          lcStr = m.lcStr + [, IPAddress C(15)]
        ENDIF 
        IF .lNoteUA
          lcStr = m.lcStr + [, UserAgent C(80)]
        ENDIF 
        IF .lNoteMethod
          lcStr = m.lcStr + [, Method C(6)]
        ENDIF 
        IF .lNoteVirtual
          lcStr = m.lcStr + [, Virtual C(24)]
        ENDIF 
        IF .lNoteStem
          lcStr = m.lcStr + [, Stem C(120)]
        ENDIF 
        IF .lNoteLogicalPath
          lcStr = m.lcStr + [, LogicPath C(150)]
        ENDIF 
        IF .lNotePath
          lcStr = m.lcStr + [, Path C(60)]
        ENDIF 
        IF .lNoteFileType
          lcStr = m.lcStr + [, FileType C(8)]
        ENDIF 
        IF .lNoteFilename
          lcStr = m.lcStr + [, Filename C(120)]
        ENDIF 
        IF .lNoteReferer
          lcStr = m.lcStr + [, Referer C(150)]
        ENDIF 

        lcStr = SUBSTR(m.lcStr, 1 + LEN([, ]))
        CREATE CURSOR (THIS.cAlias) (&lcStr)
      endif 
    endwith  
    return  
  endfunc  && Setup

*!*	FIELD     TYPE   FILTERING                           CAPTURE FLAG
*!*	========= =====  ==================================  ================
*!*	Hits      I      lCountHits lConsumeHits 
*!*	                 lGroupHits lUniqueHits
*!*	HitDate   D                                          lNoteDate
*!*	HitTime   C(8)   cTimeStart/cTimeEnd                 lNoteTime
*!*	HitHour   N(2)                                       lNoteHour
*!*	Status    N(3)   cStatuses                           lNoteStatus
*!*	Network   C(15)  cNetworks                           lNoteNetwork
*!*	IPAddress C(15)  cIPs                                lNoteIP
*!*	UserAgent C(80)  cUAs                                lNoteUA
*!*	Method    C(6)   cMethods                            lNoteMethod
*!*	Virtual   C(24)  cVirtuals                           lNoteVirtual
*!*	Stem      C(120) cStems                              lNoteStem
*!*	LogicPath C(15)  cLogicalPaths                       lNoteLogicalPath
*!*	Path      C(60)  cPaths                              lNotePath
*!*	FileType  C(8)   cFileTypes                          lNoteFileType
*!*	FileName  C(120) cFileNames                          lNoteFilename
*!*	Referer   C(150) lRefererEmpty                       lNoteReferer

  * --------------------------------------------------------- *
  FUNCTION CheckStatus(loParser)
    WITH loParser
      IF .lLineConsumed = .T.
        RETURN
      ENDIF
      LOCAL lcLike, llMine, lcLocate, loHit, ;
        lcNetwork, lcIp, lcUA, lcMethod, ;
        lcLogicalPath, lcPath, lcVirtual, ;
        ldHitDate, lcHitTime, lnHitHour, lnStatus, ;
        lcFileType, lcStem, lcFilename, lcReferer, ;
        lnDuration, lnInputSize, lnOutputSize, ;
        llInsertFailed, lcInsertFlds, lcInsertVals, lcGroupReplace, ;
        lcCmd, lnWord, loExc, loExc2, llDebug, lcErrMsg
        
      llMine = .T.  && flag to consume hit: defaults to true (consume) unless contra-indicated
      loHit = .oCurrentHit

* --- Load/interpret hit information into variables:

* [[This looks like a service the parser should provide, otherwise each observer is repeating the
* [[cleaning steps below for every hit. 

			* For the next 3 items, we'll use -1 if not logged. This avoids type mismatches
			* or need to store NULLs in data structures. Analysis routines will need
			* to recognize meaning of -1.
			lnDuration = NVL(loHit.nDuration, -1)
			lnInputSize = NVL(loHit.nInputSize, -1)
			lnOutputSize = NVL(loHit.nOutputSize, -1)

      lnStatus = loHit.nStatus
      ldHitDate = loHit.dDate
      lcHitTime = loHit.cTime
      lnHitHour = loHit.nHour
      lcIP = loHit.cClientIp

      lcUA = NVL(loHit.cUserAgent, "(user-agent not logged)")
      lcUA = CHRTRAN(m.lcUA, ['"], [||])  && avoid issues with INSERT
      IF LEN(m.lcUA) > 150
        lcUA = LEFT(m.lcUA, 147) + "..."
      ENDIF 
      
      lcNetwork = loHit.cNetwork
      lcMethod = loHit.cMethod
      lcLogicalPath = loHit.cLogicalPath
      lcLogicalPath = CHRTRAN(m.lcLogicalPath, ['"], [||])  && avoid issues with INSERT
      
      lcPath = loHit.cPath
      lcPath = CHRTRAN(m.lcPath, ['"], [||])  && avoid issues with INSERT
      
      lcFileType = LOWER(loHit.cExtension)
      
      lcStem = LOWER(loHit.cStem)
      lcStem = CHRTRAN(m.lcStem, ['"], [||])  && avoid issues with INSERT
      lcFileName = FORCEEXT(m.lcStem, m.lcFileType)
      ** lcFileName = CHRTRAN(m.lcFileName, ['"], [||])  && avoid issues with INSERT
      IF LEN(m.lcFileName) > 120
        lcFileName = LEFT(m.lcFileName, 117) + "..."
      ENDIF 
      
      lcReferer = LOWER(NVL(loHit.cReferer, "(referer not logged)"))
      lcReferer = CHRTRAN(m.lcReferer, ['"], [||])  && avoid issues with INSERT
      IF LEN(m.lcReferer) > 150
        lcReferer = LEFT(m.lcReferer, 147) + "..."
      ENDIF 
      
      lcVirtual = m.lcPath
      IF OCCURS("/", m.lcVirtual) > 1
        lcVirtual = LEFT(m.lcVirtual, -1 + AT("/", m.lcVirtual, 2))
      ENDIF 

* --- Determine of hit is of interest ("mine"):

      IF m.llMine AND NOT ISNULL(THIS.nMinDuration)  && long-running filter
				llMine = m.lnDuration >= THIS.nMinDuration
			ENDIF 
      IF m.llMine AND NOT ISNULL(THIS.nMinInputSize)  && large request
				llMine = m.lnInputSize >= THIS.nMinInputSize
			ENDIF 
      IF m.llMine AND NOT ISNULL(THIS.nMinOutputSize)  && large response
				llMine = m.lnOutputSize >= THIS.nMinOutputSize
			ENDIF 

      IF m.llMine AND NOT ISNULL(THIS.cStatuses) && HTTP status filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cStatuses, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cStatuses, m.lnWord, ","))
          IF LIKE(m.lcLike, TRANSFORM(m.lnStatus))
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check others
          ENDIF
        ENDFOR
        IF THIS.lNegateStatuses  && we want hits *not* matching 
        	llMine = NOT m.llMine
        ENDIF 
      ENDIF 
      
      IF m.llMine AND NOT ISNULL(THIS.cNetworks) && client network filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cNetworks, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cNetworks, m.lnWord, ","))
          IF LIKE(m.lcLike, m.lcNetwork)
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 
      
      IF m.llMine AND NOT ISNULL(THIS.cIPs) && client IP filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cIPs, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cIPs, m.lnWord, ","))
          IF LIKE(m.lcLike, m.lcIP)
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 
      
      IF m.llMine AND NOT ISNULL(THIS.cUAs)  && browser type filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cUAs, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cUAs, m.lnWord, ","))
          IF LIKE(m.lcLike, m.lcUA)
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 
      
      IF m.llMine AND NOT ISNULL(THIS.cMethods) && HTTP method filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cMethods, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cMethods, m.lnWord, ","))
          IF LIKE(m.lcLike, m.lcMethod)
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
        IF THIS.lNegateMethods  && we want hits *not* matching 
        	llMine = NOT m.llMine
        ENDIF 
      ENDIF 
      
      IF m.llMine AND NOT ISNULL(THIS.cVirtuals) && virtual (1st-level) filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cVirtuals, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cVirtuals, m.lnWord, ","))
          IF LIKE(m.lcLike, m.lcVirtual)
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 

      IF m.llMine AND NOT ISNULL(THIS.cFileTypes)  && file type (extension) filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cFileTypes, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cFileTypes, m.lnWord, ","))
          IF LIKE(m.lcLike, m.lcFileType)
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 

      IF m.llMine AND NOT ISNULL(THIS.cLogicalPaths)  && logical path filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cLogicalPaths, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cLogicalPaths, m.lnWord, ","))
          IF LIKE(m.lcLike, LOWER(m.lcLogicalPath))  && 8/12/07: added LOWER()
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 

      IF m.llMine AND NOT ISNULL(THIS.cPaths)  && path filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cPaths, ",")
          lcLike = LTRIM(GETWORDNUM(THIS.cPaths, m.lnWord, ","))
          IF LIKE(m.lcLike, m.lcPath)
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
        IF THIS.lNegatePaths  && we want hits *not* matching 
        	llMine = NOT m.llMine
        ENDIF 
      ENDIF 

      IF m.llMine AND NOT ISNULL(THIS.cFilenames)  && file name filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cFilenames, ",")
          lcLike = LOWER(LTRIM(GETWORDNUM(THIS.cFilenames, m.lnWord, ",")))
          IF LIKE(m.lcLike, m.lcFilename)
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 

      IF m.llMine AND NOT ISNULL(THIS.cStems)  && file stem filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cStems, ",")
          lcLike = LOWER(LTRIM(GETWORDNUM(THIS.cStems, m.lnWord, ",")))
          IF LIKE(m.lcLike, LOWER(m.lcStem))
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 
      
      * Optional time range filters:
      IF m.llMine AND NOT ISNULL(THIS.cTimeStart) && start time filter
      	IF m.lcHitTime < THIS.cTimeStart  && hit before time-range start
	        llMine = .F.
	      ENDIF 
      ENDIF 
      IF m.llMine AND NOT ISNULL(THIS.cTimeEnd) && start time filter
      	IF m.lcHitTime > THIS.cTimeEnd  && hit after time-range end
	        llMine = .F.
	      ENDIF 
      ENDIF 

      IF m.llMine AND NOT ISNULL(THIS.lRefererEmpty) && empty referer filters
        IF THIS.lRefererEmpty
          llMine = EMPTY(m.lcReferer)
        ELSE
          llMine = NOT EMPTY(m.lcReferer)
        ENDIF
      ENDIF 

      IF m.llMine AND NOT ISNULL(THIS.cReferers)  && specific referer filter
        llMine = .F.
        FOR lnWord = 1 TO GETWORDCOUNT(THIS.cReferers, ",")
          lcLike = LOWER(LTRIM(GETWORDNUM(THIS.cReferers, m.lnWord, ",")))
          IF LIKE(m.lcLike, LOWER(m.lcReferer))
            llMine = .T.  && claim hit and exit
            EXIT  && no need to check other words
          ENDIF
        ENDFOR
      ENDIF 

* --- For hits of interest ("mine"), store in this observer's cursor(s):

      IF m.llMine  && our hit (to note or consume)
        STORE "" TO lcLocate, lcInsertFlds, lcInsertVals, lcGroupReplace
        IF this.lCountHits
          this.nHits = this.nHits + 1 
        ENDIF 
        IF this.lConsumeHits
          .lLineConsumed = .T.
        ENDIF   
        IF this.lNoteHits
          SELECT (THIS.cAlias)
          
          IF this.lNoteDuration
            IF this .lGroupHits
              * pass on inserts: duration summed or averaged / not a group determinant
              lcGroupReplace = m.lcGroupReplace + [Duration WITH Duration + m.lnDuration ]
            ELSE 
	            lcInsertFlds = lcInsertFlds + [, Duration]
	            lcInsertVals = lcInsertVals + [, ] + TRANSFORM(m.lnDuration) 
            ENDIF 
          ENDIF 

          IF this.lNoteInputSize
            IF this .lGroupHits
              * pass on inserts: size summed or averaged / not a group determinant
              lcGroupReplace = m.lcGroupReplace + [InputSize WITH InputSize + m.lnInputSize ]
            ELSE 
	            lcInsertFlds = lcInsertFlds + [, InputSize]
	            lcInsertVals = lcInsertVals + [, ] + TRANSFORM(m.lnInputSize) 
            ENDIF 
          ENDIF 

          IF this.lNoteOutputSize
            IF this .lGroupHits
              * pass on inserts: size summed or averaged / not a group determinant
              lcGroupReplace = m.lcGroupReplace + [OutputSize WITH OutputSize + m.lnOutputSize ]
            ELSE 
	            lcInsertFlds = lcInsertFlds + [, OutputSize]
	            lcInsertVals = lcInsertVals + [, ] + TRANSFORM(m.lnOutputSize) 
            ENDIF 
          ENDIF 

          IF this.lNoteDate
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [HitDate = {] + TRANSFORM(m.ldHitDate) + [}]
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, HitDate]
            lcInsertVals = lcInsertVals + [, ] + [{] + TRANSFORM(m.ldHitDate) + [}]
          ENDIF 
          IF this.lNoteTime
          	* NOTE: No grouping option for specific time value.
            lcInsertFlds = lcInsertFlds + [, HitTime]
            lcInsertVals = lcInsertVals + [, '] + m.lcHitTime + [']
          ENDIF 
          IF this.lNoteHour
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [HitHour = ] + TRANSFORM(m.lnHitHour, "99")
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, HitHour]
            lcInsertVals = lcInsertVals + [, ] + TRANSFORM(m.lnHitHour,"99") 
          ENDIF 

          IF this.lNoteStatus
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [Status = ] + TRANSFORM(m.lnStatus)
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, Status]
            lcInsertVals = lcInsertVals + [, ] + TRANSFORM(m.lnStatus)
          ENDIF 
          
          IF this.lNoteNetwork
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [Network ='] + PADR(LOWER(m.lcNetwork), LEN(Network)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, Network]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcNetwork) + [']
          ENDIF 
          
          IF this.lNoteIP
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [IPAddress ='] + PADR(LOWER(m.lcIP), LEN(IPAddress)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, IPAddress]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcIP) + [']
          ENDIF 
          
          * 12/11/2006: Temporary fix test. Changed ' to " in both locate and insert code,
          *    to cope with ' character found in rogue (?) user-agent string.
          * Later... also found examples of ", so resorted to CHRTRAN() up above.
          IF this.lNoteUA
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [UserAgent ="] + PADR(m.lcUA, LEN(UserAgent)) + ["]
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, UserAgent]
            lcInsertVals = lcInsertVals + [, "] + m.lcUA + ["]
          ENDIF 
          
          IF this.lNoteMethod
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [Method ='] + PADR(UPPER(m.lcMethod), LEN(Method)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, Method]
            lcInsertVals = lcInsertVals + [, '] + UPPER(m.lcMethod) + [']
          ENDIF 

          IF this.lNoteVirtual
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [Virtual ='] + PADR(LOWER(m.lcVirtual), LEN(Virtual)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, Virtual]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcVirtual) + [']
          ENDIF 
          
          IF this.lNoteLogicalPath
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [LogicPath ='] + PADR(LOWER(m.lcLogicalPath), LEN(LogicPath)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, LogicPath]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcLogicalPath) + [']
          ENDIF 
          
          IF this.lNotePath
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [Path ='] + PADR(LOWER(m.lcPath), LEN(Path)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, Path]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcPath) + [']
          ENDIF 
          
          IF this.lNoteFilename
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [Filename ='] + PADR(LOWER(m.lcFilename), LEN(Filename)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, Filename]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcFilename) + [']
          ENDIF 

          IF this.lNoteFileType
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [FileType ='] + PADR(LOWER(m.lcFileType), LEN(FileType)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, FileType]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcFileType) + [']
          ENDIF 

          IF this.lNoteStem
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [Stem ='] + PADR(LOWER(m.lcStem), LEN(Stem)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, Stem]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcStem) + [']
          ENDIF 
          
          IF this.lNoteReferer
            IF this .lGroupHits
              lcLocate = m.lcLocate + [ AND ] + [Referer ='] + PADR(LOWER(m.lcReferer), LEN(Referer)) + [']
            ENDIF 
            lcInsertFlds = lcInsertFlds + [, Referer]
            lcInsertVals = lcInsertVals + [, '] + LOWER(m.lcReferer) + [']
          ENDIF 

          * Generic process code:
          TRY
            IF this .lGroupHits
              IF EMPTY(m.lcInsertFlds)  && no groupings, must be a single site-wide total, kludge:
              	lcInsertFlds = [Hits]
              	lcInsertVals = [0]
              ELSE 
	              lcInsertFlds = SUBSTR( m.lcInsertFlds, LEN( [, ]))
	              lcInsertVals = SUBSTR( m.lcInsertVals, LEN( [, ]))
              ENDIF 
              IF EMPTY(m.lcLocate)  && same as above
              	lcLocate = [.T.]
              ELSE 
	              lcLocate = SUBSTR(m.lcLocate, 1 + LEN( [ AND ] ))  && remove leading AND
              ENDIF 
              LOCATE FOR &lcLocate
              IF NOT FOUND()
                ** TRY   
	              lcCmd = [INSERT INTO ] + THIS.cAlias + [ (] + m.lcInsertFlds + [) VALUES (] + m.lcInsertVals + [)]
	              &lcCmd
                ** INSERT INTO (THIS.cAlias) (&lcInsertFlds) VALUES (&lcInsertVals)
                ** CATCH TO loExc
                **   ? loExc.Message, loExc.Details
                ** ENDTRY 
              ENDIF 
              REPLACE Hits WITH Hits + 1
              IF NOT EMPTY(m.lcGroupReplace)  && statistical fields noted (duration, size)
              	lcCmd = [REPLACE ] + m.lcGroupReplace
              	&lcCmd
              ENDIF 
            ELSE
              lcInsertFlds = SUBSTR( m.lcInsertFlds, LEN( [, ]))
              lcInsertVals = SUBSTR( m.lcInsertVals, LEN( [, ]))
              ** TRY
              lcCmd = [INSERT INTO ] + THIS.cAlias + [ (] + m.lcInsertFlds + [) VALUES (] + m.lcInsertVals + [)]
              &lcCmd
              ** CATCH TO loExc
              **  llDebug = .T.
              ** ENDTRY 
              ** IF m.llDebug
              **   SET STEP ON
              ** ENDIF 
            ENDIF 
          CATCH TO loExc
            llInsertFailed = .T.
            TRY 
	            lcErrMsg = "Insert failed (error: " + loExc.Message + ;
	            	", line: " + TRANSFORM(loExc.LineNo) + ;
	            	") in " + TEXTMERGE([<<THIS.cName>>, (<<loParser.cCurrentFile>>)]) + ", Field #1: " + FIELD(1, THIS.cAlias) + "."
	            IF VARTYPE(m.lcCmd) = "C"
	            	lcErrMsg = lcErrMsg + " Command: " + m.lcCmd
	            ELSE
	            	IF VARTYPE(lcLocate) = "C"
		            	lcErrMsg = lcErrMsg + " Locate FOR: " + m.lcLocate
	            	ENDIF
	            ENDIF
	          CATCH TO loExc2
	          	lcErrMsg = TEXTMERGE("Error: <<loExc2.Message>>, while reporting error: <<loExc.Message>>.")
	          ENDTRY 
          ENDTRY 
          IF m.llInsertFailed
            ERROR m.lcErrMsg
          ENDIF 
        ENDIF 
      ENDIF && llMine

    ENDWITH  && loParser
    RETURN 
  ENDFUNC  && CheckStatus
  * --------------------------------------------------------- *
  FUNCTION NoteFilesEnd(loParser)
    local lcTmp, lcTmpX, loExc, llReportFailed, llSqlFailed, lcSql, ;
    	lnMaxHits, lnGraphDivs, lcGraphChar, lcHitsFmt, lcRecFmt, llHtml, loTbl, loCol
    with this 
      if .lNoteHits
        llHtml = loParser.lHTML

        SELECT (.cAlias)
        lcSql = [SELECT]
        IF NOT ISNULL(.nReportTopN)
          lcSql = m.lcSql + [ TOP ] + TRANSFORM(.nReportTopN)
        ENDIF
        lcSql = m.lcSql + [ *] + [ FROM ] + .cAlias 
        IF .lGroupHits AND NOT ISNULL(.nReportHitThreshhold)
          lcSql = m.lcSql + [ WHERE Hits >= ] + TRANSFORM(.nReportHitThreshhold)
        ENDIF
        IF NOT ISNULL(.cReportOrder)
          lcSql = m.lcSql + [ ORDER BY ] + .cReportOrder
        ENDIF
        lcSql = m.lcSql + [ INTO CURSOR ] + THIS.cAlias + "_Output_"
        TRY 
          &lcSql
        CATCH TO loExc
          llSqlFailed = .T.
        ENDTRY 
        IF m.llSqlFailed
          ERROR "SELECT failed (error " + TRANSFORM(loExc.ErrorNo) + ") in " + THIS.cName + ;
            ", " + loExc.Message + ", command: " + TRANSFORM(m.lcSql)
        ENDIF 

        if m.llHTML
          loTbl = createobject("L7Table")
        else
          lcTmp = ""
        endif
        lcRecFmt = REPLICATE("9", CEILING(LOG10(MAX(2,RECCOUNT()))))
        
        if .lGroupHits
        	CALCULATE MAX(Hits) TO lnMaxHits
        	lnMaxHits = MAX(m.lnMaxHits, 1)  && avoid Div0
        	lcHitsFmt = REPLICATE("9", CEILING(LOG10(MAX(2,m.lnMaxHits))))
        	IF .lGraphHits
        		lcGraphChar = ">"
        		lnGraphDivs = 20
          ENDIF 
        endif
        
        if m.llHtml 
          loCol = loTbl.addColumn(L7_ELEMENTTYPE_ABSOLUTE_RECNO)
        else
          lcTmp = m.lcTmp + [#<<TRANSFORM(RECNO(), m.lcRecFmt)>>]
        endif
        
        if .lGroupHits
          if m.llHtml
            loCol = loTbl.addCursorColumn("Hits")
            loCol.cTransform = m.lcHitsFmt
          else
            lcTmp = m.lcTmp + [, <<TRANSFORM(Hits, m.lcHitsFmt)>> Hits]
          endif

          IF .lGraphHits
            if m.llHtml
              * [[ ?
            else
              lcTmp = m.lcTmp + ;
    						[ <<PADR(REPLICATE(m.lcGraphChar, CEILING(m.lnGraphDivs * Hits/m.lnMaxHits)), m.lnGraphDivs)>>]
            endif
          endif  
        endif && group hits 

        if .lNoteDuration
          if .lGroupHits  && when grouping, provide Average duration [run non-grouping analysis w/ threshhold to find long hits]
            if m.llHtml
              loCol = loTbl.addCursorColumn("Duration", "Average<br />Duration", 'TRANSFORM(Duration/EVL(Hits, 1), "999.999")')
            else
              lcTmp = m.lcTmp + [, <<TRANSFORM(Duration/EVL(Hits, 1), "999.999")>> sec (avg)]
            endif
          else 
            if m.llHtml
              loCol = loTbl.addCursorColumn("Duration", "Duration", 'TRANSFORM(Duration, "999.999")')
            else
              lcTmp = m.lcTmp + [, <<TRANSFORM(Duration, "999.999")>> sec]
            endif  
          endif
        endif
          
        if .lNoteInputSize
          if m.llHtml
            loCol = loTbl.addCursorColumn("InputSize", "Bytes In")
          else
            lcTmp = m.lcTmp + [, <<TRANSFORM(InputSize, "9,999,999,999")>>  bytes in]
          endif 
        endif  

        if .lNoteOutputSize 
          if m.llHtml
            loCol = loTbl.addCursorColumn("OutputSize", "Bytes Out", 'TRANSFORM(OutputSize, "999,999,999,999")')
          else
            lcTmp = m.lcTmp + [, <<TRANSFORM(OutputSize, "999,999,999,999")>> bytes out]
          endif 
        endif  

        IF .lNoteDate
          if m.llHtml
            loCol = loTbl.addCursorColumn("HitDate", "Date of Hit")
          else
            lcTmp = m.lcTmp + [, <<TRANSFORM(HitDate)>>]
          endif
        endif 
         
        if .lNoteTime
          if m.llHtml
            loCol = loTbl.addCursorColumn("HitTime", "Time of Hit")
          else
            lcTmp = m.lcTmp + [, <<HitTime>>]
          endif
        endif
          
        if .lNoteHour
          if m.llHtml
            loCol = loTbl.addCursorColumn("HitHour", "Hour of Hit")
          else
            lcTmp = m.lcTmp + [, Hour <<TRANSFORM(HitHour,"99")>>]
          endif
        endif  
        
        if .lNoteStatus
          if m.llHtml
            loCol = loTbl.addCursorColumn("Status", "Status")
          else
            lcTmp = m.lcTmp + [, Status <<TRANSFORM(Status)>>]
          endif 
        endif 
         
        if .lNoteNetwork
          if m.llHtml
            loCol = loTbl.addCursorColumn("Network", "Network")
          else
            lcTmp = m.lcTmp + [, Network <<IPv4PAD(Network)>>]
          endif 
        endif
          
        if .lNoteIP
          if m.llHtml
            loCol = loTbl.addCursorColumn("IPAddress", "Host")
          else
            lcTmp = m.lcTmp + [, Host <<IPv4PAD(IPAddress)>>]
          endif
        endif
          
        if .lNoteMethod
          if m.llHtml
            loCol = loTbl.addCursorColumn("Method", "Method")
          else
            lcTmp = m.lcTmp + [, Method <<TRIM(Method)>>]
          endif
        endif  

        if .lNoteVirtual
          if m.llHtml
            loCol = loTbl.addCursorColumn("Virtual", "Virtual")
          else
            lcTmp = m.lcTmp + [, Virtual <<IIF(LEN(TRIM(Virtual))>14,LEFT(Virtual,14)+"..",LEFT(Virtual,14))>>]
          endif
        endif  

        if .lNotePath
          if m.llHtml
            loCol = loTbl.addCursorColumn("Path", "Path", "TRIM(Path)")
          else
            lcTmp = m.lcTmp + [, Path <<TRIM(Path)>>]
          endif
        endif  

        if .lNoteLogicalPath
          if m.llHtml
            loCol = loTbl.addCursorColumn("LogicPath", "Logical Path", "TRIM(LogicPath)")
          else
            lcTmp = m.lcTmp + [, Logical <<TRIM(LogicPath)>>]
          endif 
        endif  
        
        if .lNoteStem
          if m.llHtml
            loCol = loTbl.addCursorColumn("Stem", "Stem", "TRIM(Stem)")
          else
            lcTmp = m.lcTmp + [, Stem <<TRIM(Stem)>>]
          endif 
        endif  

        if .lNoteFileType && FILE TYPE
          if m.llHtml
            loCol = loTbl.addCursorColumn("FileType", "Type", "UPPER(TRIM(FileType))")
          else
            lcTmp = m.lcTmp + [, Type <<UPPER(TRIM(FileType))>>]
          endif
        endif  

        IF .lNoteFilename
          if m.llHtml
            loCol = loTbl.addCursorColumn("Filename", "File Name", "TRIM(FileName)")
          else
            lcTmp = m.lcTmp + [, <<TRIM(Filename)>>]
          endif 
        endif 
         
        if .lNoteReferer  && referer is long and needs 2nd line per hit
          if m.llHtml
            loCol = loTbl.addCursorColumn("Referer")
          else
            lcTmp = m.lcTmp + CRLF + SPACE(7) + [Referer: <<TRIM(Referer)>>] + CRLF
          endif
        endif  
        
        if .lNoteUA
          if m.llHtml
            loCol = loTbl.addCursorColumn("UserAgent", "UA")
          else
            lcTmp = m.lcTmp + [, UA "<<TRIM(UserAgent)>>"]
          endif
        endif  
        
        if m.llHtml
          try 
            lcTmpX = loTbl.Render()
            .cReport = .cReport + m.lcTmpX + CRLF
          catch to loExc
            llReportFailed = .T.
          endtry 
          if m.llReportFailed
            error "REPORT failed (rendering error " + TRANSFORM(loExc.ErrorNo) + ") in " + nvl(THIS.cName, this.class) + ;
              ", " + loExc.Message 
          endif 
          
        else
          scan 
            try 
            	lcTmpX = TEXTMERGE(m.lcTmp)
            	.cReport = .cReport + m.lcTmpX + CRLF
              ** .cReport = .cReport + TEXTMERGE(m.lcTmp) + CRLF
            catch to loExc
            	llReportFailed = .T.
            endtry 
            if m.llReportFailed
              error "REPORT failed (TEXTMERGE error " + TRANSFORM(loExc.ErrorNo) + ") in " + nvl(THIS.cName, this.class) + ;
                ", " + loExc.Message + ", expr: " + m.lcTmp
            ENDIF
          endscan
        endif
      endif 
    endwith  

    dodefault(m.loParser)
    return  
  endfunc && NoteFilesEnd
enddefine  && L7GenericLogObserver 

*** ========================================================= ***
DEFINE CLASS L7LogObserver as Custom
	* See major subclass: L7GenericLogObserver for basic report/filter functions.
  cName = NULL
  nHits = 0
  cReport = ""
  cSummary = ""
  cReportComment = ""
  
  cAlias = ""
  * flags used in most subclasses:
  nReportHitThreshhold = 1  && don't report if no hits (change to 0 for ubiquitous reporting)
  lCountHits        = .T.  && if .T., counts the hit
  lConsumeHits      = .T.  && if .T., also consumes the hit
  * --------------------------------------------------------- *
  FUNCTION cName_Access
    RETURN NVL(THIS.cName, THIS.Class)  && if not named, use class name as stand-in
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION setup(loParser)
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION NoteFilesEnd(loParser)
    local llHtml, lcStr
    llHtml = loParser.lHtml
    IF THIS.nHits >= NVL(THIS.nReportHitThreshhold, -1)
      if m.llHtml
        THIS.cSummary = THIS.cSummary + CRLF + HTWrap(THIS.cName, 'h4') + CRLF + TEXTMERGE( ;
          [<p><<TRANSFORM(THIS.nHits,"999,999,999")>> hits <<IIF(THIS.lConsumeHits, "consumed", "noted")>></p>]) + ;
          CRLF
        
        IF NOT EMPTY(THIS.cReportComment)
        	THIS.cSummary = htwrap(THIS.cReportComment, 'div') + CRLF + THIS.cSummary
        ENDIF 
      else
        THIS.cSummary = THIS.cSummary + CRLF + THIS.cName + CRLF + TEXTMERGE( ;
          [<<TRANSFORM(THIS.nHits,"999,999,999")>> hits <<IIF(THIS.lConsumeHits, "consumed", "noted")>>]) + ;
          CRLF
        
        IF NOT EMPTY(THIS.cReportComment)
          THIS.cSummary = THIS.cReportComment + CRLF + THIS.cSummary
        ENDIF 
      endif
      * Add this observer's summary and report to overall parser: 
      loParser.cSummary = loParser.cSummary + THIS.cSummary 
      loParser.cReport = loParser.cReport + THIS.cSummary + THIS.cReport 
    ENDIF 
    RETURN 
  ENDFUNC 
enddefine && LogObserver

*** ========================================================= ***
DEFINE CLASS L7DayAndPageStatsLogObserver as L7LogObserver
  cVirtuals = NULL
  cDateAlias = ""
  cPageAlias = ""
  * --------------------------------------------------------- *
  FUNCTION setup(loParser)
    BINDEVENT(m.loParser, 'ReadHit', THIS, 'CheckStatus', 3)
    BINDEVENT(m.loParser, 'DidProcessFiles', THIS, 'NoteFilesEnd')

    SELECT 0
    THIS.cDateAlias = THIS.Class + [_Day_] + SYS(2015)
    CREATE CURSOR (THIS.cDateAlias) (Date D, Hits I)

    SELECT 0
    THIS.cPageAlias = THIS.Class + [_Page_] + SYS(2015)
    CREATE CURSOR (THIS.cPageAlias) (PageCRC C(10), Hits I, Page C(150))
    INDEX ON LOWER(Page) TAG Page_L
    INDEX ON PageCRC TAG PageCRC
  ENDFUNC 
  * --------------------------------------------------------- *
  FUNCTION CheckStatus(loParser)
    WITH loParser
      IF .lLineConsumed = .T.
        RETURN
      ENDIF
      LOCAL lcVirtual, loHit, lcCrc, ldDate
      loHit = loParser.oCurrentHit
      IF loHit.nStatus <> 200
        RETURN
      ENDIF
      lcVirtual = GETWORDNUM(loHit.cPath, 1, '/')
      IF ISNULL(THIS.cVirtuals) OR "," + m.lcVirtual + "," $ THIS.cVirtuals
        .lLineConsumed = .T. && claim hit and eat
        THIS.nHits = THIS.nHits + 1 
        
        lcCRC = SYS(2007, loHit.cLogicalPath, -1, 1)
        SELECT (THIS.cPageAlias)
        LOCATE FOR PageCRC = m.lcCRC
        IF NOT FOUND()
          APPEND BLANK
          REPLACE PageCRC WITH m.lcCRC, Page WITH loHit.cLogicalPath
        ENDIF
        REPLACE Hits WITH Hits + 1
        
        ldDate = loHit.dDate
        SELECT (THIS.cDateAlias)
        LOCATE FOR Date = m.ldDate
        IF NOT FOUND()
          APPEND BLANK
          REPLACE Date WITH m.ldDate
        ENDIF
        REPLACE Hits WITH Hits + 1
      ENDIF
    endwith
    return 
  endfunc && CheckStatus
  * --------------------------------------------------------- *
  FUNCTION NoteFilesEnd(loParser)
    SELECT (THIS.cPageAlias)
    SET ORDER to Page_L
    SCAN
      this.cReport = this.cReport + TEXTMERGE( ;
        [<<TRANSFORM(Hits, "999,999")>> Hits on Page: <<TRIM(Page)>>]) + ;
        CRLF
    ENDSCAN

    DODEFAULT(m.loParser)
    RETURN 
  endfunc  
  * --------------------------------------------------------- *
enddefine  && L7DayAndPageStatsLogObserver 

* end: L7LogParser.PRG
