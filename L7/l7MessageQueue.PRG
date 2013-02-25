* L7MessageQueue.PRG
#INCLUDE wconnect.H
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


*** =================================================== ***
DEFINE CLASS L7MessageQueue AS Line
  DataSourceType  = "Native"
  DataSource      = ""
  cPath           = NULL
  cTable          = "L7MessageQueue"
  cDefaultEmail   = NULL
  cDefaultSubject = "(No Subject)"
  cAppName        = "NOAPP"
  cMailServer     = NULL
  * --------------------------------------------------- *
  FUNCTION cPath_ACCESS
    IF ISNULL(THIS.cPath)
      IF VARTYPE(m.goL7App) = "O" AND VARTYPE(goL7App.oConfig.cMessagingPath) = "C"
        RETURN ADDBS(goL7App.oConfig.cMessagingPath)
      ELSE
        RETURN ADDBS(CURDIR()) + "Messaging\"
      ENDIF
    ELSE
      RETURN ADDBS(THIS.cPath)
    ENDIF
  ENDFUNC
  * --------------------------------------------------- *
  FUNCTION SetPath(lcVal)
    THIS.cPath = m.lcVal
  ENDFUNC 
  * --------------------------------------------------- *
  FUNCTION SetDefaultEmail(lcVal)
    THIS.cDefaultEmail = m.lcVal
  ENDFUNC 
  * --------------------------------------------------- *
  FUNCTION SetDefaultSubject(lcVal)
    THIS.cDefaultSubject = m.lcVal
  ENDFUNC 
  * --------------------------------------------------- *
  FUNCTION SetAppName(lcVal)
    THIS.cAppName = m.lcVal
  ENDFUNC 
  * --------------------------------------------------- *
  FUNCTION SetMailServer(lcVal)
    THIS.cMailServer = m.lcVal
  ENDFUNC 
  * --------------------------------------------------- *
  FUNCTION ConfigFromApp(loApp, loServer)
    WITH THIS
      .SetPath(loApp.oConfig.cMessagingPath)
      .SetDefaultEmail(EVL(loApp.oConfig.cAdminEmail, loServer.oConfig.cAdminEmail))
      .SetDefaultSubject(loApp.cTitle)
      .SetAppName(loApp.cApplication)
      .cMailServer = loServer.oConfig.cAdminMailServer
    ENDWITH
    RETURN
  ENDFUNC 
  * --------------------------------------------------- *
  function Queue(loMsg, llAttemptSend)
    LOCAL lnSelect, llSent, loMail, loState, loQueueRecord, loExc, ;
      lcCc, lcBcc, lcTo, lcFromEmail, lcFromName, ;
      lcContentType, lcAttachment, lcSubject, lcMessage, ltTime, lcExtraHeaders
    loState = createobject("L7MessageState")

    IF NOT loMsg.lSend  && what was block this for?????? (testing maybe)
      RETURN loState
    ENDIF

    lnSelect = SELECT()
    SELECT 0
    THIS.OpenTable()
    
    * Massage the message:
    loQueueRecord = createobject("L7MailQueueRecord")  && defined below

    *!*    AppName = ""
    *!*    T_Posted = {//:}
    *!*    T_Sent = {//:}
    *!*    T_LastTry = {//:}
    *!*    Attempts = 0
    *!*    History = ""
    *!*    Inactive = .f.
    *!*    ServerName = ""
    *!*    FromName = ""
    *!*    FromEmail = ""
    *!*    ToEmail = ""
    *!*    CcEmail = ""
    *!*    BccEmail = ""
    *!*    Priority = "Normal"
    *!*    Subject = ""
    *!*    Details = ""
    *!*    Attachment = ""
    *!*    Content = "text/plain"
    *!*    ExtraHdrs = ""

    with loQueueRecord 
      .AppName = UPPER(THIS.cAppName)
      .CcEmail = IIF(VARTYPE(loMsg.cCc) = "C", loMsg.cCc, "")
      .BccEmail = IIF(VARTYPE(loMsg.cBcc) = "C", loMsg.cBcc, "")
      .ToEmail = IIF(!EMPTY( loMsg.cTo), loMsg.cTo, evl(.CcEmail, .BccEmail))

      .FromEmail = IIF(EMPTY(loMsg.cFromEmail), THIS.cDefaultEmail, loMsg.cFromEmail)
      .FromName = IIF(EMPTY(loMsg.cFromName), .FromEmail, loMsg.cFromName)

      .Content = IIF(EMPTY(loMsg.cContentType), "text/plain", loMsg.cContentType)
      .Priority = IIF(!empty(loMsg.cPriority), loMsg.cPriority, "Normal")
      * Note: if priority doesn't "work" for an app, the field is missing form the queue table
      * -> alter table l7MessageQueue add column Priority C(6)
      
      .Attachment = IIF(TYPE("loMsg.cAttachment") = "C", loMsg.cAttachment, "")
      .Subject = IIF(EMPTY(loMsg.cSubject), THIS.cDefaultSubject, loMsg.cSubject)
      .Details = IIF(EMPTY(loMsg.cMessage), .Subject, loMsg.cMessage)
      .T_Posted = DATETIME()
      .ExtraHdrs = EVL(loMsg.cExtraHeaders, "")
    endwith
    
    * Queue the message, whether attempting a send now or not:
    try  
      insert into MailMessageQueue_ from name loQueueRecord
      * (Using INSERT FROM NAME insulates us from old queue tables lacking Priority field, for example)
      
      *!*        INSERT INTO MailMessageQueue_ ( ;
      *!*            AppName, ;
      *!*            T_Posted, ;
      *!*            FromName, ;
      *!*            FromEmail, ;
      *!*            ToEmail, ;
      *!*            CcEmail, ;
      *!*            BccEmail, ;
      *!*            Subject, ;
      *!*            Details, ;
      *!*            Attachment, ;
      *!*            Content, ;
      *!*            ExtraHdrs ;
      *!*          ) VALUES ( ;
      *!*            UPPER(THIS.cAppName), ;
      *!*            m.ltTime, ;
      *!*            m.lcFromName, ;
      *!*            m.lcFromEmail, ;
      *!*            m.lcTo, ;
      *!*            m.lcCc, ;
      *!*            m.lcBcc, ;
      *!*            m.lcSubject, ;
      *!*            m.lcMessage, ;
      *!*            m.lcAttachment, ;
      *!*            m.lcContentType, ;
      *!*            m.lcExtraHeaders ;
      *!*          )
      loState.tQueued = DATETIME()
      loState.lQueued = .T.
  
    catch to loExc
      with loState
        .lError = .T.
        .cErrorMessage  = loExc.Message 
        .nErrorLine     = loExc.LineNo
        .cErrorModule   = loExc.Procedure 
      endwith 
    endtry  

    if  !loState.lError AND m.llAttemptSend
      if rlock("MailMessageQueue_")
        this.SendCurrentMessage(m.loState)
        unlock in MailMessageQueue_ 
      endif
    endif  && send immediate

    use in select("MailMessageQueue_")
    select (m.lnSelect)
    return m.loState  && calling component can look at .lSent, etc.
  endfunc  && Queue

  * --------------------------------------------------- *
  function SendCurrentMessage(loState)
    * assume something else has record pointer right
    * * caller should lock before calling!
    * Called by either:
    *  - this.queue() when send immediate flag is on
    *  - TSTS CheckMailQueues 
    LOCAL loMail, loExc, llSent
    
    loState.lSendAttempted = .T.
    loState.tSendAttempted = DATETIME()
    TRY
      #if WWVERSION_NUMBER <= 5.50
        loMail = CREATEOBJECT("wwIpStuff") 
      #else
        loMail = CREATEOBJECT("wwSMTP") && wwIpStuff deprecated as of 5.51
        loMail.nMailMode = 2
      #endif
      WITH loMail
        .cMailServer = NVL(THIS.cMailServer, "")
        .cSenderEmail = TRIM( MailMessageQueue_.FromEmail )
        .cSenderName  = TRIM( MailMessageQueue_.FromName )
        .cRecipient   = IIF( EMPTY( MailMessageQueue_.ToEmail), ;
          MailMessageQueue_.CcEmail, MailMessageQueue_.ToEmail)
        .cCCList      = MailMessageQueue_.CcEmail
        .cBCCList     = MailMessageQueue_.BccEmail
        if type('MailMessageQueue_.Priority') = 'C' and !empty(MailMessageQueue_.Priority)
          .cPriority = trim(MailMessageQueue_.Priority) && {"Normal", "High", "Low"}
        endif
        .cSubject     = TRIM( MailMessageQueue_.Subject )
        .cMessage     = MailMessageQueue_.Details
        .cContentType = MailMessageQueue_.Content
        
        .cAttachment  = MailMessageQueue_.Attachment
        .cExtraHeaders = MailMessageQueue_.ExtraHdrs
        
      
        IF NOT ISNULL(loState.cRecipientOverride)  && allows testing w/o spamming real people
          THIS.RedirectMessage(loMail, loState.cRecipientOverride)
        ENDIF
        IF EMPTY(.cMailServer)  && avoid API call slated to fail
          ERROR "Mail server not specified."
        ENDIF 
        llSent = .SendMail()
      ENDWITH 
    CATCH TO loExc
      WITH loState
        .lError = .T.
        .cErrorMessage  = loExc.Message 
        .nErrorLine     = loExc.LineNo
        .cErrorModule   = loExc.Procedure 
      ENDWITH 
    ENDTRY

    IF m.llSent
      * Success!
      loState.lSent = .T.
      loState.tSent = DATETIME()
      REPLACE ;
          T_Sent WITH loState.tSent ;
          ServerName WITH loMail.cMailServer ;
        IN MailMessageQueue_
    ELSE
      loState.lSent = .F.  && host component can decide whether to continue
      * Problem.
      IF loState.lError && app issue
        REPLACE ;
            T_LastTry WITH loState.tSendAttempted ;
            Attempts WITH Attempts + 1 ;
            ServerName WITH loMail.cMailServer ;
            History WITH '[' + ;
              TTOC( loState.tSendAttempted) + '] ' + ;
              loState.cErrorMessage ;
          IN MailMessageQueue_
      ELSE  && problem from mailing component
        loState.cErrorMessage = loMail.cErrorMsg
        REPLACE ;
            T_LastTry WITH loState.tSendAttempted ;
            Attempts WITH Attempts + 1 ;
            ServerName WITH loMail.cMailServer ;
            History WITH '[' + ;
              TTOC( loState.tSendAttempted) + '] ' + ;
              loMail.cErrorMsg ;
          IN MailMessageQueue_
      ENDIF && state error
    ENDIF && sent
    return m.loState 
  endfunc  && SendCurrentMessage
  * --------------------------------------------------- *
  FUNCTION RedirectMessage(loMsg, lcNewRecip)
    LOCAL lcOrigRecip, lnAt
    WITH loMsg
      lcOrigRecip = "INTENDED RECIPIENT(S): " + .cRecipient 
      .cRecipient = m.lcNewRecip
      IF !EMPTY(.cCCList)
        lcOrigRecip = m.lcOrigRecip + "; cc: " + .cCCList
        .cCCList = ""
      ENDIF 
      IF !EMPTY(.cBccList)
        lcOrigRecip = m.lcOrigRecip + "; Bcc: " + .cBccList
        .cBccList = ""
      ENDIF 
      .cSubject = .cSubject + ' [REDIRECTED]'
      IF .cContentType = "text/html"
        lnAt = ATC("<body", .cMessage)
        IF m.lnAt > 0
          lnAt = m.lnAt + AT(">", SUBSTR(.cMessage, m.lnAt))
        ENDIF
        .cMessage = STUFF(.cMessage, m.lnAt, 0, CRLF + [<h1>] + m.lcOrigRecip + [</h1>] + CRLF)
      ELSE
        .cMessage = m.lcOrigRecip + CRLF + .cMessage
      ENDIF
    ENDWITH
    RETURN 
  ENDFUNC 
  * --------------------------------------------------- *
  FUNCTION OpenTable
    IF NOT DIRECTORY(THIS.cPath)
      MKDIR (THIS.cPath)
    ENDIF 
    IF NOT FILE(THIS.cPath + THIS.cTable + ".DBF")
      SELECT 0
      CREATE TABLE (THIS.cPath + THIS.cTable) FREE ;
        ( ;
          AppName C(8), ;
          T_Posted T, ;
          T_Sent T, ;
          T_LastTry T, ;
          Attempts I, ;
          History M, ;
          Inactive L, ;
          ServerName C(50), ;
          FromName C(50), ;
          FromEmail C(50), ;
          ToEmail M, ;
          CcEmail M, ;
          BccEmail M, ;
          Priority C(6), ; && new 04/2010 {"Normal", "High", "Low"}
          Subject C(150), ;
          Details M, ;
          Attachment M, ;
          Content C(30), ;
          ExtraHdrs M;
        ) 
      INDEX ON AppName TAG AppName
      INDEX ON T_Sent TAG T_Sent
      INDEX ON DELETED() TAG Deleted
      USE
    ENDIF
    USE (THIS.cPath + THIS.cTable) AGAIN ALIAS MailMessageQueue_ ;
      IN SELECT("MailMessageQueue_")
    SELECT MailMessageQueue_
  ENDFUNC  && OpenTable
  * --------------------------------------------------- *
  FUNCTION CloseTable
    USE IN SELECT("MailMessageQueue_")
    RETURN 
  ENDFUNC 
ENDDEFINE

*** =================================================== ***
DEFINE CLASS L7MultiMailer as L7MessageQueue && Custom
  * --------------------------------------------------- *
  FUNCTION QueueMultiple(loTmp, loIter)
    LOCAL loRec, loMsg, loState
    loIter.moveFirst()
    DO WHILE NOT loIter.eof
      loRec = loIter.getRecord()
      loMsg = CREATEOBJECT("L7MailMessage")
      THIS.BuildMessage(loMsg, loTmp, loRec)
      IF loMsg.lSend
        loState = this.Queue(loMsg)
      ENDIF
      loIter.moveNext()
    ENDDO 
    RETURN 
  ENDFUNC
  * --------------------------------------------------- *
  FUNCTION BuildMessage(loMsg, loTmp, loRec)
    WITH loRec && allow leading dot expressions
      loMsg.cFromEmail = IIF(L7_TEXTMERGE_DELIM_1 $ loTmp.cFromEmail, ;
        TEXTMERGE(loTmp.cFromEmail), loTmp.cFromEmail)
      loMsg.cFromName = IIF(L7_TEXTMERGE_DELIM_1 $ loTmp.cFromName, ;
        TEXTMERGE(loTmp.cFromName), loTmp.cFromName)
      loMsg.cTo = IIF(L7_TEXTMERGE_DELIM_1 $ loTmp.cTo, ;
        TEXTMERGE(loTmp.cTo), loTmp.cTo)
      loMsg.cCc = IIF(L7_TEXTMERGE_DELIM_1 $ loTmp.cCc, ;
        TEXTMERGE(loTmp.cCc), loTmp.cCc)
      loMsg.cSubject = IIF(L7_TEXTMERGE_DELIM_1 $ loTmp.cSubject, ;
        TEXTMERGE(loTmp.cSubject), loTmp.cSubject)
      loMsg.cContentType = loTmp.cContentType
      IF VARTYPE(loTmp.lSend) = "L"
        loMsg.lSend = loTmp.lSend
      ELSE
        loMsg.lSend = EVALUATE(loTmp.lSend)
      ENDIF
      IF loMsg.lSend
        loMsg.cMessage = IIF(L7_TEXTMERGE_DELIM_1 $ loTmp.cMessage, ;
          TEXTMERGE(loTmp.cMessage), loTmp.cMessage)
      ELSE
        * If we're not sending, don't bother with expensive
        * message building.
      ENDIF
    ENDWITH 
    RETURN 
  ENDFUNC
ENDDEFINE

*** =================================================== ***
DEFINE CLASS L7mailTester as Custom
  lValidateRecipient = .T.
  lNoSend = .F.
  cRedirectTo = ""
  lBreakLines = .T.  && enable fixing messages per RFC requirements
  ADD OBJECT Report as Collection
  * --------------------------------------------------- *
  FUNCTION bindTo(loMailer)
    BINDEVENT(loMailer, "buildMessage", THIS, "CheckMessage", 1)
    BINDEVENT(loMailer, "buildMessage", THIS, "NoteMessage", 1)
  ENDFUNC
  * --------------------------------------------------- *
  FUNCTION CheckMessage(loMsg, loTmp, loRec)
    * Swap To: and CC: if To: is empty
    IF EMPTY(loMsg.cTo) AND NOT EMPTY(loMsg.cCc)
      loMsg.cTo = loMsg.cCc
      loMsg.cCc = ""
    ENDIF
    * Validate To:
    IF THIS.lValidateRecipient
      IF EMPTY(loMsg.cTo) OR NOT IsValidEmail(TRIM(loMsg.cTo), .T.)
        THIS.Report.Add("Killed message to: " + loMsg.cTo + " (invalid address)")
        loMsg.lSend = .F.
      ENDIF
    ENDIF
    * Fix message line length
    IF THIS.lBreakLines AND NOT EMPTY(loMsg.cMessage)
      loMsg.cMessage = MemoToEmail(loMsg.cMessage)
    ENDIF
    * Optional kill/reroute of all messages.
    IF THIS.lNoSend
      loMsg.lSend = .F.
    ELSE
      IF NOT EMPTY(THIS.cRedirectTo)
        THIS.Report.Add("Redirected message to " + loMsg.cTo + " to " + THIS.cRedirectTo)
        loMsg.cTo = THIS.cRedirectTo
      ENDIF
    ENDIF
    RETURN 
  ENDFUNC
  * --------------------------------------------------- *
  FUNCTION NoteMessage(loMsg, loTmp, loRec)
    THIS.Report.Add(["] + loMsg.cSubject + [" to ] + loMsg.cTo + [: ] + ;
      IIF(loMsg.lSend, "email message queued", "email message NOT queued"))
  ENDFUNC
  * --------------------------------------------------- *
  FUNCTION GetReport
    LOCAL lcStr, lcItem
    lcStr = ""
    FOR EACH lcItem IN this.report
      lcStr = m.lcStr + m.lcItem + CRLF
    ENDFOR 
    RETURN m.lcStr
  ENDFUNC
ENDDEFINE

*** =================================================== ***
define class L7MailQueueRecord as Line
  * used internally--matches structure of L7MessageQueue.DBF
  * * Use L7MailMessage class (below) to pass ingedients of a mail message around.
  AppName = ""
  T_Posted = {//:}
  T_Sent = {//:}
  T_LastTry = {//:}
  Attempts = 0
  History = ""
  Inactive = .f.
  ServerName = ""
  FromName = ""
  FromEmail = ""
  ToEmail = ""
  CcEmail = ""
  BccEmail = ""
  Priority = "Normal"
  Subject = ""
  Details = ""
  Attachment = ""
  Content = "text/plain"
  ExtraHdrs = ""
enddefine 

*** =================================================== ***
define class L7MailMessage AS Line
  * Use this to populate a messages and send to queue.
  cTo           = ""
  cSubject      = ""
  cMessage      = ""
  cFromName     = ""
  cFromEmail    = ""
  cCC           = ""
  cBCC          = ""
  cAttachment   = ""
  cContentType  = "text/plain"
  cExtraHeaders = ""
  cPriority     = "Normal"  && "High", "Low"
  lSend         = .T.
enddefine

*** =================================================== ***
DEFINE CLASS L7MessageState AS Line
  * Used internally for queue processing.
  cRecipientOverride = NULL
  lQueued        = .F.
  tQueued        = {:}
  lSendAttempted = .F.
  tSendAttempted = {:}
  lSent          = .F.
  tSent          = {:}
  lError         = .F.
  cErrorMessage  = ""
  nErrorLine     = 0
  cErrorModule   = ""
ENDDEFINE   

#IF .F.
RECORD OF REVISIONS
12/14/2002 - Class created. (Refactored from L7App.QueueMessage.)
10/22/2004 - Added support for extra headers (Reply-To, etc)
08/04/2007 - Refactored to reduce coupling from App/Server to allow TSTS usage.
#ENDIF
