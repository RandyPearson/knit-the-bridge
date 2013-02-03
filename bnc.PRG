* IIServer Version

*!*  LPARAMETERS uid, pwd, nobuild, llUseNetwork, llNoInstall, lcFtpPwd
*!*  * DO bnc WITH ,, .F., .F., .T.  && build and copy to update folder, but don't install

#DEFINE BNC_EXENAME "iiL7"

LPARAMETERS tcLoc, tvAltFile, tlNoBuild, tcFtpPwd, tlInstallAlso, tcHttpPwd

** SET CLASSLIB TO wwIpStuff ADDITIVE   && deprecated
set procedure to wwFTP additive

IF m.tlInstallAlso AND EMPTY(m.tcHttpPwd)  && escaped from GetPass dialog
  RETURN
ENDIF

LOCAL loIp, loFtp, lnResult, lcText, lnBuff, lcMsg, ;
  llWasSafe, llFailed, loExc, llUseFtp, loLocRec, lcFile, ltStart

BncOpenTable()
SELECT BncConfig
IF NOT EMPTY(m.tcLoc)
  LOCATE FOR Inactive = .F. AND upper(Location) = PADR(upper(m.tcLoc), LEN(Location))
  IF NOT FOUND()
    ERROR "Location record not found: " + m.tcLoc
  ELSE
    SCATTER NAME loLocRec
  ENDIF
ELSE
  LOCATE FOR Inactive = .F. AND Default = .T.
  IF NOT FOUND()
    ERROR "No default Location."   
  ELSE
    SCATTER NAME loLocRec
  ENDIF
ENDIF 
lcMsg = ""  
llWasSafe = SET( "SAFETY") == "ON"
llUseFTP = .T.  && NOT m.llUseNetwork
IF m.llUseFtp AND EMPTY(m.tcFtpPwd)
  tcFtpPwd = GetPass("Enter FTP Password")  && get this right away
ENDIF 
if not empty(m.tvAltFile)
  if vartype(m.tvALtFile) = "L"
    lcFile = getfile("", "Select file to send", "Send")
  else
    lcFile = m.tvALtFile  && nm passed
  endif
else
  lcFile = (BNC_EXENAME + ".EXE")
  if NOT m.tlNoBuild
    ? "Building EXE..."
    BUILD EXE (m.lcFile) FROM BNC_EXENAME RECOMPILE 
  endif 
endif 
  
if !empty(m.lcFile) and m.llUseFtp
  ltStart = datetime()
  loFtp = CREATEOBJECT( "bncFTP")
  ? "Copying " + m.lcFile + " via FTP to " + TRIM(loLocRec.Descript) + " at " + TRIM(loLocRec.HostName) + "..."
  loFtp.FtpConnect(TRIM(loLocRec.HostName), TRIM(loLocRec.FtpUserID), m.tcFtpPwd)
  lnResult = loFtp.FtpSendFileEx(m.lcFile, TRIM(loLocRec.FtpFolder) + justfname(m.lcFile))

  IF m.lnResult <> 0
    llFailed = .T.
    lcMsg = "WININET Error Code " + TRANSFORM(m.lnResult) + " on FTP attempt"
  ELSE 
    ? "FTP copy complete. Duration:", ltrim(transform(datetime() - m.ltStart)), "sec"
  ENDIF
  loFtp.FtpClose()
ENDIF 

IF m.tlInstallAlso AND NOT m.llFailed
  ERROR "This code section out of date..."
  loIP = NEWOBJECT( "wwIpStuff", "wwIpStuff" )
  ? "Requesting EXE update via HTTP..."
  loIP.HTTPConnect( TRIM(loLocRec.HostName), TRIM(loLocRec.HttpUserID), m.tcPwd)
  lcText = ""
  lnBuff = 0
  oIP.HttpGetEx( "/iiDocs/ii.json?_maintain~UpdateExe", @lcText, @lnBuff)
  IF NOT "exe updated" $ LOWER( m.lcText)
    lcMsg = "Did not update the EXE."
    MESSAGEBOX(m.lcMsg)
  ELSE
    lcMsg = "EXE was updated."
    MESSAGEBOX(m.lcMsg, 0, "Result", 500)
  ENDIF
ENDIF
? DATETIME(), lcMsg
?
* close:
USE IN SELECT("bncconfig")

RETURN  && end main BNC routine

* ------------------------------------------ *
FUNCTION BncOpenTable
  IF NOT FILE('.\bncconfig.dbf')
    CREATE TABLE BncConfig FREE ( ;
      Location C(16), ;
      DEFAULT L, ;
      Inactive L, ;
      HostName C(30), ;
      FtpUserId C(16), ;
      FtpFolder C(60), ;
      HttpUserId C(16), ;
      Descript C(60))
  ENDIF 
  USE BNCConfig IN SELECT("bncconfig")
  RETURN
ENDFUNC 
*** ========================================================= ***
DEFINE CLASS BncFtp as wwFTP OF wwIpStuff.vcx
  FUNCTION OnFTPBufferUpdate(lnBytesDownloaded, lnBufferReads, lcCurrentChunk, lnFileSize, loFtp)
    DO CASE
      CASE m.lnBufferReads > 0
         wait window "Uploaded: " + TRANSFORM(100 * m.lnBytesDownloaded / m.lnFileSize) + "%" NOWAIT && + " bytes (Alt-X to cancel)" nowait

  *** Error
  CASE lnBufferReads = -1 and this.nError # 0
  wait window "An error occurred: " + this.cErrorMsg

  *** Cancelled
  CASE lnBufferReads = -1 AND this.lCancelDownload
        wait window "Upload aborted..." timeout 2

  *** Completed
  CASE lnBufferReads = -1 
     WAIT WINDOW "Upload Completed." TIMEOUT 2
     OTHERWISE
  wait window "Not sure what happened!" 
     

    ENDCASE
    RETURN
  ENDFUNC 
ENDDEFINE
