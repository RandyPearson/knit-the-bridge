* L7Zip.PRG
*
* Encapsulate basic DynaZip zip/unzip ActiveX functions in VFP classes.
*
* Author: J. Randy Pearson, Cycla Corp
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

* For additional constants, see .\Docs\common\DZipMsg.TXT (Zip) and
* .\Docs\common\DUnZMsg.TXT (UnZip) in DynaZip NX installation folder.

*-- DynaZip ZIP ActionDZ constants
#DEFINE NO_ACTION     0  && older shared name

#DEFINE ZIP_NOACTION  0
#DEFINE ZIP_FRESHEN   1
#DEFINE ZIP_DELETE    2
#DEFINE ZIP_UPDATE    3
#DEFINE ZIP_ADD       4
#DEFINE ZIP_MEMTOFILE 5

*-- DynaZip UNZIP ActionDZ constants
#DEFINE UNZIP_NOACTION                 0
#DEFINE UNZIP_COUNTALLZIPMEMBERS       1
#DEFINE UNZIP_GETNEXTZIPINFO           2
#DEFINE UNZIP_COUNTALLNAMEDZIPMEMBERS  3
#DEFINE UNZIP_GETNEXTNAMEDZIPINFO      4
#DEFINE UNZIP_GETCOMMENTSIZE           5
#DEFINE UNZIP_GETCOMMENT               6
#DEFINE UNZIP_GETINDEXEDZIPINFO        7
#DEFINE UNZIP_EXTRACT                  8
#DEFINE UNZIP_FILETOMEM                9
#DEFINE UNZIP_MEMTOMEM                10
#DEFINE UNZIP_FILETOMEM_STREAM        11

*-- DynaZip ZipSubOptions constants
#DEFINE ZSO_RELATIVEPATHFLAG 1
#DEFINE ZSO_SHOWSTATUS       4
#DEFINE ZSO_MINORCANCEL      2
#DEFINE ZSO_EXTPROGCANCEL    8
#DEFINE ZSO_SKIPLOCKEDFILES  64
#DEFINE ZSO_LOGZIPRESULTS    256
#DEFINE ZSO_JUST_ARCHIVED    512
#DEFINE ZSO_RESET_ARCHIVED   1024

*-- DynaZip UnZipSubOptions constants
#DEFINE USO_OVERWRITE_RO       1
#DEFINE USO_MINORCANCEL        2
#DEFINE USO_EXTERNALPROGCANCEL 8    && caution: name slightly different from Zip component
#DEFINE USO_LOGZIPRESULTS      256
* ... there are others, add as needed

* DZ Error messages:
#DEFINE UE_BORED               11

* found this error list online but don't know pedigree (real source is dzipmsg.txt ?)
*!*    UE_OK = 0                ' success
*!*    UE_EOF = 2               ' unexpected end of zip file
*!*    UE_STRUCT = 3            ' structure error in zip file
*!*    UE_MEM1 = 4              ' out of memory
*!*    UE_MEM2 = 5              ' out of memory
*!*    UE_NOFILE = 9            ' file not found error
*!*    UE_BORED = 11            ' nothing to do
*!*    UE_SAMEVOL = 12          ' nothing to do
*!*    UE_INDEX = 25            ' index out of bounds
*!*    UE_OUTPUT = 28           ' error creating output file
*!*    UE_OPEN = 29             ' error opening output file
*!*    UE_BADCRC = 39           ' crc error
*!*    UE_ENCRYPT = 41          ' file skipped, encrypted
*!*    UE_UNKNOWN = 42          ' unknown compression method
*!*    UE_NOVOL = 46            ' can't unzip a volume item
*!*    UE_CMDERR = 47           ' bad command structure
*!*    UE_CANCEL = 48           ' user cancelled this operation
*!*    UE_SKIP = 49             ' user skipped this operation
*!*    UE_DISKFULL = 50         ' disk full

*** DEMO CODE SHOWING UNZIPPING a TREE of ZIPs to TREE of FILES
*** Use at your own risk!!
*** Only updates tree--does not synchronize (remove target mismatches).
*** To sync from "authoritative" ZIP source, delete existing files first,
***   or use software meant for that task, like Beyond Compare.

* ------------------------------------------------- *  
FUNCTION L7Demo_UnzipTree(lcZipRoot, lcTargetRoot, llTestOnly, llRecursed)

  LOCAL llRoot, lcFolderName, lnRet, llRet, loExc, ;
    ii, lnFiles, lnDirs, laFiles[1], laDirs[1], lcDir, ;
    ltNow, lcZipFile
  LOCAL loUZ as L7Unzip
  
  IF NOT m.llRecursed
    CLEAR
  ENDIF
  ? m.lcZipRoot
  
  ltNow = DATETIME()
  
  * Strategy:
  * 1. For each ZIP file in folder:
  *    a. Create/verify folder in target with same name as STEM of ZIP.
  *    b. Unzip with Update action.
  * 2. For each subfolder in folder, call this recursively.

  lnFiles = ADIR(laFiles, ADDBS(m.lcZipRoot) + [*.zip])
  FOR ii = 1 TO lnFiles
    loUZ = CREATEOBJECT("L7Unzip")
    lcZipFile = ADDBS(m.lcZipRoot) + laFiles[m.ii, 1]
    loUZ.SetZipFileName(m.lcZipFile)
    ? m.lcZipFile
    lcDir = ADDBS(m.lcTargetRoot) + JUSTSTEM(laFiles[m.ii, 1])
    IF NOT DIRECTORY(m.lcDir)
      MKDIR (m.lcDir)
    ENDIF
    loUZ.SetDestinationFolder(ADDBS(m.lcDir))
    loUZ.SetFileSpec("*.*") && if it's in the Zip, assume we want it
    loUZ.lTestFlag = m.llTestOnly
    lnRet = loUZ.UpdateFiles()
    IF NOT INLIST(m.lnRet, 0, UE_BORED)
      ERROR TRANSFORM(m.lnRet) + " returned bv UnZip component for file " + ;
        laFiles[m.ii, 1]
    ENDIF
    loUZ = NULL
  ENDFOR 
  
  lnDirs = ADIR(laDirs,  ADDBS(m.lcZipRoot) + [*.*], [D])
  FOR ii = 1 TO lnDirs
    lcDir = laDirs[m.ii, 1]
    IF NOT [D] $ laDirs[m.ii, 5]
      LOOP 
    ENDIF
    IF NOT INLIST(m.lcDir, ".", "..")
      * recursive call back to this method
      lcFolderName = ADDBS(m.lcTargetRoot) + m.lcDir
      IF NOT DIRECTORY(m.lcFolderName)
        MKDIR (m.lcFolderName)
      ENDIF
      L7Demo_UnzipTree(ADDBS(m.lcZipRoot) + m.lcDir, ;
        m.lcFolderName, m.llTestOnly, .T.)
    ENDIF
  ENDFOR

  RETURN m.llRet
ENDFUNC  && Ex_Zip

**** END DEMO CODE


*** ======================================================== ***
DEFINE CLASS L7UnZipS AS L7UnZip
  * Subclass for Max Secure with AES encryption.
  cControl = "DuzsActxCtrl.DuzsActxCtrl.1"  && DynaZip Max Secure (File: duzSactx.dll)
  * NOTE: Nothing extra needed on Unzip side--just use right control class
  *  and call SetPassword before unzipping.
ENDDEFINE 

*** ======================================================== ***
DEFINE CLASS L7UnZip AS CUSTOM

  PROTECTED oControl, cControl, lGarbageCollected 
  oControl = NULL
  cControl = "DuzActxCtrl.DuzActxCtrl.1"  && as of DynaZip-NX, v.5 (File: DUZActX.DLL)
  lGarbageCollected = .F.
  lRecurse          = .T.  && See assign method
  lNoDirectoryNames = .F.  && set TRUE to disable use of names
  lNoDirectoryItems = .F.  && set TRUE to ignore subfolder items
  lUpdateFlag       = .F.  && can set manually, or call high-level UpdateFiles method
  lFreshenFlag      = .F.  && can set manually, or call high-level FreshenFiles method
  lTestFlag         = .F.  && tests without physical unzipping

  lExtProgCancel    = .F.
  lMinorCancel      = .F.  && Displays the cancel button in progress window

  lLogZipResults    = .F.
  cLogFilepath      = "c:\windows\dziplog.txt"  && Default
  
  lValidZip  = NULL && don't know
  nZipItems  = 0
  nErrorCode = 0

  ADD OBJECT ZipInfos as Collection
  *-------------------------------------------------------
  function getResultsLog()
  *-------------------------------------------------------
  *-- there doesn't seem to be an easy way to change the filepath
  *-- so grabbing it the source is an alternative
    local lcString
    if file( this.cLogFilepath )
      lcString = filetostr( this.cLogFilepath )
    endif
    return m.lcString
  endfunc

  *-------------------------------------------------------
  function lLogZipResults_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lLogZipResults = m.llFlag
  lnConstantName      = USO_LOGZIPRESULTS

  *-- Want a clean log file each time
  if this.lLogZipResults and file( this.cLogfilepath )
    erase (this.cLogfilepath)
  endif

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.UnZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.UnZipSubOptions = BITXOR( ;
        THIS.oControl.UnZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  *-------------------------------------------------------
  function lExtProgCancel_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lExtProgCancel = m.llFlag
  lnConstantName      = USO_EXTERNALPROGCANCEL

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.UnZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.UnZipSubOptions = BITXOR( ;
        THIS.oControl.UnZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  *-------------------------------------------------------
  function lMinorCancel_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lMinorCancel = m.llFlag
  lnConstantName      = USO_MINORCANCEL

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.UnZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.UnZipSubOptions = BITXOR( ;
        THIS.oControl.UnZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  * ------------------------------------------------------------ *
  FUNCTION lFreshenFlag_ASSIGN( llFlag)
    THIS.lFreshenFlag = m.llFlag
    THIS.oControl.FreshenFlag = THIS.lFreshenFlag
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION lUpdateFlag_ASSIGN( llFlag)
    THIS.lUpdateFlag = m.llFlag
    THIS.oControl.UpdateFlag = THIS.lUpdateFlag
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION lTestFlag_ASSIGN( llFlag)
    THIS.lTestFlag = m.llFlag
    THIS.oControl.TestFlag = THIS.lTestFlag
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION lRecurse_ASSIGN( llFlag)
    THIS.lRecurse = m.llFlag
    THIS.oControl.RecurseFlag = THIS.lRecurse
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION lNoDirectoryNames_ASSIGN( llFlag)
    THIS.lNoDirectoryNames = m.llFlag
    THIS.oControl.NoDirectoryNamesFlag = THIS.lNoDirectoryNames
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION lNoDirectoryItems_ASSIGN( llFlag)
    THIS.lNoDirectoryItems = m.llFlag
    THIS.oControl.NoDirectoryItemsFlag = THIS.lNoDirectoryItems
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION INIT
    THIS.oControl = CREATEOBJECT( THIS.cControl)
    * Set some reasonable defaults for a VFP server environment:
    WITH THIS.oControl
      .BackgroundProcessFlag = .T.
      .QuietFlag             = .T.
      .AllQuiet              = .T.  && added for testing 01/17/2007
      .MessageCallbackFlag   = .T.                   && [[ verify this is proper (*)
      * (*) Not only proper, but required to prevent server "hang" with msgbox 
      *    "Zip read error" 
      
      * Following commands all force assign method to be called, which covers
      * situations where these "properties" are subclassed:
      .RecurseFlag          = THIS.lRecurse          && finds files in subfolders
      .NoDirectoryNamesFlag = THIS.lNoDirectoryNames && 
      .NoDirectoryItemsFlag = THIS.lNoDirectoryItems && 
      .UnZipSubOptions      = 0
      THIS.lExtProgCancel   = THIS.lExtProgCancel    && 
      THIS.lMinorCancel     = THIS.lMinorCancel      && 
      THIS.lUpdateFlag      = THIS.lUpdateFlag
      THIS.lFreshenFlag     = THIS.lFreshenFlag
      THIS.lTestFlag        = THIS.lTestFlag
      
    ENDWITH
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION DESTROY
    IF NOT THIS.lGarbageCollected
      THIS.GarbageCollect()
    ENDIF
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION GarbageCollect
    IF NOT THIS.lGarbageCollected
      THIS.oControl = NULL
      THIS.lGarbageCollected = .T.
    ENDIF
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION NoAction
    this.oControl.ActionDZ = UNZIP_NOACTION
    RETURN
  ENDFUNC 
  * ------------------------------------------------------------ *
  FUNCTION ValidateZipFile(tlNoLoad)
    WITH this
      .oControl.ActionDZ = UNZIP_COUNTALLZIPMEMBERS && also confirms validitiy? (*)
      * (*) Not completely true. We've found cases where you don't find error until
      *     loading individual zip items.
      IF .oControl.ErrorCode = 0
        .lValidZip = .T.
        .nZipItems = .oControl.ReturnCount
        IF NOT m.tlNoLoad
          IF NOT .LoadZipInfoObjects()
            .lValidZip = .F.
            .nZipItems = 0
          ENDIF 
        ENDIF 
      ELSE
        .lValidZip = .F.
        .nZipItems = 0
        .nErrorCode = .oControl.ErrorCode
      ENDIF 
    ENDWITH 
    RETURN THIS.lValidZip
  ENDFUNC 
  * ------------------------------------------------------------ *
  FUNCTION LoadZipInfoObjects()
    LOCAL llRet, ii, loObj
    llRet = .T.
    WITH this.oControl 
      FOR ii = 1 TO this.nZipItems
        .ActionDZ = 2  && UNZIP_GETNEXTZIPINFO 
        IF .ErrorCode <> 0
          llRet = .F.
          EXIT
        ENDIF 
        loObj = CREATEOBJECT("Empty")
        ADDPROPERTY(loObj, "zi_FileName",      .zi_FileName)
        ADDPROPERTY(loObj, "zi_DateTimeEx",    .zi_DateTimeEx)
        ADDPROPERTY(loObj, "zi_cSize",         .zi_cSize)
        ADDPROPERTY(loObj, "zi_cSizeHighPart", .zi_cSizeHighPart)
        ADDPROPERTY(loObj, "zi_index",         .zi_index)
        ADDPROPERTY(loObj, "zi_oSize",         .zi_oSize)
        ADDPROPERTY(loObj, "zi_oSizeHighPart", .zi_oSizeHighPart)
        
        THIS.ZipInfos.Add(m.loObj, .zi_FileName)
      NEXT 
    ENDWITH
    RETURN m.llRet 
  ENDFUNC  
  * ------------------------------------------------------------ *
  FUNCTION SetPassword( lcPass)
    * Pass empty string to clear password.
    * NOTE Names are Decrypt here, and Encrypt in Zip component.
    IF ISNULL( m.lcPass) OR EMPTY( m.lcPass)
      THIS.oControl.DecryptFlag = .F.
      THIS.oControl.DecryptCode = ""
    ELSE
      THIS.oControl.DecryptFlag = .T.
      THIS.oControl.DecryptCode = m.lcPass
    ENDIF
    RETURN 
  ENDFUNC  && SetPassword
  * ------------------------------------------------------------ *
  FUNCTION SetZipFileName( lcFile)
    * MUST include full path.
    * Separate items with **spaces NOT commas**!!
    * For long file names with embedded spaces, use double quotes.
    THIS.oControl.ZipFile = m.lcFile
    THIS.lValidZip = NULL
    THIS.nZipItems = 0
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION SetFileSpec( lcList)
    * Separate items with spaces.
    * For long file names with embedded spaces, use double quotes.
    THIS.oControl.FileSpec = m.lcList
    RETURN  
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION SetDestinationFolder( lcFolder)
    * MUST include full path.
    * For paths with embedded spaces, use double quotes.
    THIS.oControl.Destination = m.lcFolder
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION UnzipFiles(lcZipFile, lcFileSpec, lcDestination)
    * Immediately unzips files from the Zip. You do not need to send 
    * any parameters here, if you have already called SetFileSpec,
    * SetZipFileName, and SetDestinationFolder.
    IF NOT EMPTY( m.lcZipFile)
      THIS.SetZipFileName( m.lcZipFile)
    ENDIF
    IF NOT EMPTY(m.lcFileSpec)
      THIS.SetFileSpec( m.lcFileSpec)  && set to '*.*' for all
    ENDIF 
    IF NOT EMPTY( m.lcDestination)
      THIS.SetDestinationFolder( m.lcDestination)
    ENDIF
    IF ISNULL(THIS.lValidZip)
      THIS.ValidateZipFile()
    ENDIF
    IF THIS.lValidZip
      THIS.oControl.ActionDZ = UNZIP_EXTRACT  && attempt UNZIP
    ENDIF
    RETURN THIS.oControl.ErrorCode
    * 0 means no problem
    * 11 (UE_BORED) is also usually OK
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION FreshenFiles(lcZipFile, lcFileSpec, lcDestination)
    * Immediately freshens files to the Zip. 
    THIS.lUpdateFlag  = .F.  && careful not to set both
    THIS.lFreshenFlag = .T.
    RETURN THIS.UnzipFiles(m.lcZipFile, m.lcFileSpec, m.lcDestination)
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION UpdateFiles(lcZipFile, lcFileSpec, lcDestination)
    * Immediately updates files to the Zip. 
    THIS.lFreshenFlag = .F.  && careful not to set both
    THIS.lUpdateFlag  = .T.
    RETURN THIS.UnzipFiles(m.lcZipFile, m.lcFileSpec, m.lcDestination)
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION CountMatchingFiles()
    THIS.oControl.ActionDZ = UNZIP_COUNTALLNAMEDZIPMEMBERS
    RETURN THIS.oControl.ReturnCount
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION SetZipInfo(tvObj)
    * Sets filespec to a single item in prep for unzip.
    LOCAL lcSpec, llRet
    llRet = .T.
    this.NoAction()  && good to turn off action
    IF VARTYPE(m.tvObj) = "C"  && passed file name instead of object
      tvObj = this.ZipInfos(m.tvObj)
    ENDIF 
    lcSpec = tvObj.zi_FileName
    IF SPACE(1) $ m.lcSpec AND LEFT(m.lcSpec, 1) <> ["] 
      lcSpec = ["] + m.lcSpec + ["]  && fn's with spaces muct be quoted
    ENDIF 
    this.SetFileSpec(m.lcSpec)  && [[do we need quotes??]]
    ** this.oControl.ActionDZ = UNZIP_GETNEXTNAMEDZIPINFO  &&    4
    llRet = this.oControl.ErrorCode = 0
    RETURN m.llRet
  ENDFUNC 
  * ------------------------------------------------------------ *
  FUNCTION UnzipToString(tvObj)
    LOCAL lcRet, loControl
    lcRet = ""
    loControl = THIS.oControl
    this.NoAction()  && good to turn off action
    IF VARTYPE(m.tvObj) = "C"  && passed file name instead of object
      tvObj = this.ZipInfos(m.tvObj)
    ENDIF 
    WITH m.loControl
      .FileSpec = tvObj.zi_FileName
      .UnZIPStringOffset = 0
      .UnZIPStringSize = tvObj.zi_oSize
      .ActionDZ = UNZIP_FILETOMEM  && 9
      lcRet = .UnZIPString
    ENDWITH 
    IF loControl.ErrorCode <> 0
      ERROR TEXTMERGE("Error unzipping to string [<<this.oControl.ErrorCode>>]")
    ENDIF 
    
    RETURN m.lcRet
  ENDFUNC 
  * ------------------------------------------------------------ *
ENDDEFINE  && CLASS L7UnZip

*** ======================================================== ***
DEFINE CLASS L7ZipS AS L7Zip
  * Subclass for Max Secure with AES encryption.
  cControl = "DzsActxCtrl.DzsActxCtrl.1"  && DynaZip Max Secure (File: dzSactx.dll)
  * ------------------------------------------------------------ *
  FUNCTION SetPassword(lcPass)
    * Pass empty string to clear password.
    * OVEERIDE of L7Zip to include AES encryption.
    WITH THIS.oControl
      IF ISNULL( m.lcPass) OR EMPTY( m.lcPass)
        .EncryptFlag = .F.
        .EncryptCode = ""
      ELSE
        .EncryptFlag = .T.
        .EncryptCode = m.lcPass
        * Next 2 lines added:
        .SEInfo = 3 && AES-256
        .ZipSubOptions2 = BITXOR(.ZipSubOptions2, 4)  && 4 = ZSO2_PK_AES
      ENDIF
    ENDWITH 
    RETURN 
  ENDFUNC  && SetPassword
ENDDEFINE 

*** ======================================================== ***
DEFINE CLASS L7Zip AS CUSTOM

  PROTECTED oControl, cControl, lGarbageCollected 
  oControl = NULL
  ** cControl = "DzOcx1.DzOcx1Ctrl.1"
  cControl = "DzActxCtrl.DzActxCtrl.1"  && as of DynaZip-NX, v.5 (File: DZActX.DLL)
  lGarbageCollected = .F.
  lRecurse          = .F.  && See assign method
  lRelativePaths    = .F.    && See assign method (n/a if directory names disabled)
  lNoDirectoryNames = .F. && set TRUE to disable names

  lDeleteOriginal   = .F.  && Use caution
  lJust_Archived    = .F.  && Only ZIP files marked for archiving
  lReset_Archived   = .F.  && Reset archive bit
  lskipLockedFiles  = .F.
  lExtProgCancel    = .F.
  lShowStatus       = .F.  && Displays zipping progress
  lMinorCancel      = .F.  && Displays the cancel button in progress window

  lLogZipResults    = .F.
  cLogFilepath      = "c:\windows\dziplog.txt"  && Default

  *-------------------------------------------------------
  function getResultsLog()
  *-------------------------------------------------------
  *-- there doesn't seem to be an easy way to change the filepath
  *-- so grabbing it the source is an alternative
    local lcString
    if file( this.cLogFilepath )
      lcString = filetostr( this.cLogFilepath )
    endif
    return m.lcString
  endfunc

  *-------------------------------------------------------
  function lLogZipResults_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lLogZipResults = m.llFlag
  lnConstantName      = ZSO_LOGZIPRESULTS

  *-- Want a clean log file each time
  if this.lLogZipResults and file( this.cLogfilepath )
    erase (this.cLogfilepath)
  endif

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.ZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.ZipSubOptions = BITXOR( ;
        THIS.oControl.ZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  *-------------------------------------------------------
  function lJust_Archived_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lJust_Archived = m.llFlag
  lnConstantName      = ZSO_JUST_ARCHIVED

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.ZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.ZipSubOptions = BITXOR( ;
        THIS.oControl.ZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  *-------------------------------------------------------
  function lReset_Archived_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lReset_Archived = m.llFlag
  lnConstantName      = ZSO_RESET_ARCHIVED

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.ZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.ZipSubOptions = BITXOR( ;
        THIS.oControl.ZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  *-------------------------------------------------------
  function lskipLockedFiles_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lskipLockedFiles = m.llFlag
  lnConstantName      = ZSO_RESET_ARCHIVED

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.ZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.ZipSubOptions = BITXOR( ;
        THIS.oControl.ZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  *-------------------------------------------------------
  function lExtProgCancel_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lExtProgCancel = m.llFlag
  lnConstantName      = ZSO_EXTPROGCANCEL

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.ZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.ZipSubOptions = BITXOR( ;
        THIS.oControl.ZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  *-------------------------------------------------------
  function lMinorCancel_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lMinorCancel = m.llFlag
  lnConstantName      = ZSO_MINORCANCEL

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.ZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.ZipSubOptions = BITXOR( ;
        THIS.oControl.ZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc

  *-------------------------------------------------------
  function lShowStatus_ASSIGN ( llFlag )
  *-------------------------------------------------------
  this.lMinorCancel = m.llFlag
  lnConstantName      = ZSO_SHOWSTATUS

  IF IIF( m.llFlag, m.lnConstantName, 0) <> ;
      BITAND( THIS.oControl.ZipSubOptions, m.lnConstantName)
      *
      THIS.oControl.ZipSubOptions = BITXOR( ;
        THIS.oControl.ZipSubOptions, ;
        m.lnConstantName )
    ENDIF
  endfunc
  * ------------------------------------------------------------ *
  FUNCTION lDeleteOriginal_ASSIGN( llFlag)
  	THIS.lDeleteOriginal = m.llFlag
  	THIS.oControl.deleteOriginalFlag = THIS.lRecurse
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION lRecurse_ASSIGN( llFlag)
  	THIS.lRecurse = m.llFlag
  	THIS.oControl.RecurseFlag = THIS.lRecurse
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION lNoDirectoryNames_ASSIGN( llFlag)
    THIS.lNoDirectoryNames = m.llFlag
    THIS.oControl.NoDirectoryNamesFlag = THIS.lNoDirectoryNames
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION lRelativePaths_ASSIGN( llFlag)
  	THIS.lRelativePaths = m.llFlag
  	IF IIF( m.llFlag, ZSO_RELATIVEPATHFLAG, 0) <> ;
  		BITAND( THIS.oControl.ZipSubOptions, ZSO_RELATIVEPATHFLAG)
  		*
  		THIS.oControl.ZipSubOptions = BITXOR( ;
  			THIS.oControl.ZipSubOptions, ;
  			ZSO_RELATIVEPATHFLAG )
  	ENDIF
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION INIT
  	THIS.oControl = CREATEOBJECT( THIS.cControl)
  	* Set some reasonable defaults for a VFP server environment:
  	WITH THIS.oControl
  		.BackgroundProcessFlag = .T.
  		.QuietFlag             = .T.
  		.CompressionFactor     = 2                     && good performance, OK compression
  		.MessageCallbackFlag   = .T.                   && [[ verify this is proper??
  		.RecurseFlag           = THIS.lRecurse         && in case sub-classed
      .NoDirectoryNamesFlag = ;
        THIS.lNoDirectoryNames      && in case sub-classed
  		.ZipSubOptions         = 0
      THIS.lRelativePaths    = THIS.lRelativePaths   && in case sub-classed
      THIS.lDeleteOriginal   = THIS.lDeleteOriginal  && in case sub-classed
      THIS.lJust_Archived    = THIS.lJust_Archived   && in case sub-classed
      THIS.lReset_Archived   = THIS.lReset_Archived  && in case sub-classed
      THIS.lskipLockedFiles  = THIS.lskipLockedFiles && in case sub-classed
      THIS.lExtProgCancel    = THIS.lExtProgCancel   && in case sub-classed
      THIS.lMinorCancel      = THIS.lMinorCancel     && in case sub-classed
      THIS.lShowStatus       = THIS.lShowStatus      && in case sub-classed
  		
  	ENDWITH
    RETURN 
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION DESTROY
  	IF NOT THIS.lGarbageCollected
  		THIS.GarbageCollect()
  	ENDIF
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION GarbageCollect
  	IF NOT THIS.lGarbageCollected
  		THIS.oControl = NULL
  		THIS.lGarbageCollected = .T.
  	ENDIF
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION SetPassword( lcPass)
  * Pass empty string to clear password.
  	IF ISNULL( m.lcPass) OR EMPTY( m.lcPass)
  		THIS.oControl.EncryptFlag = .F.
  		THIS.oControl.EncryptCode = ""
  	ELSE
  		THIS.oControl.EncryptFlag = .T.
  		THIS.oControl.EncryptCode = m.lcPass
  	ENDIF
  ENDFUNC  && SetPassword
  * ------------------------------------------------------------ *
  FUNCTION SetItemList( lcList)
  	* Separate items with spaces.
  	* For long file names with embedded spaces, use double quotes.
  	THIS.oControl.ItemList = m.lcList
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION SetExcludeFiles( lcList)
  	* Separate items with **spaces NOT commas**!!
  	* For long file names with embedded spaces, use double quotes.
  	THIS.oControl.ExcludeFollowing = m.lcList
  	THIS.oControl.ExcludeFollowingFlag = .T.
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION SetZipFileName( lcFile)
  	* MUST include full path.
    * Separate items with **spaces NOT commas**!!
    * For long file names with embedded spaces, use double quotes.
  	THIS.oControl.ZipFile = m.lcFile
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION AddString( lcString, lcAsFile, lcZipFile)
  	* Immediately adds the string to the Zip. You can send
  	* the AsFile parameter here, or you can set it previously 
  	* via SetItemList.
  	THIS.oControl.ZipString = m.lcString
  	IF NOT EMPTY( m.lcAsFile)
  		THIS.SetItemList( m.lcAsFile)
  	ENDIF
  	IF NOT EMPTY( m.lcZipFile)
  		THIS.SetZipFileName( m.lcZipFile)
  	ENDIF
  	THIS.oControl.ActionDZ = ZIP_MEMTOFILE
  	RETURN THIS.oControl.ErrorCode
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION AddFiles( lcFiles, lcZipFile)
  	* Immediately adds files to the Zip. You do not need to send 
  	* any parameters here, if you have already called SetItemList
  	* and SetZipFileName.
  	IF NOT EMPTY( lcFiles)
  		THIS.SetItemList( m.lcFiles)
  	ENDIF
  	IF NOT EMPTY( m.lcZipFile)
  		THIS.SetZipFileName( m.lcZipFile)
  	ENDIF
  	THIS.oControl.ActionDZ = ZIP_ADD
  	RETURN THIS.oControl.ErrorCode
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION FreshenFiles( lcFiles, lcZipFile)
  	* Immediately freshens files to the Zip. You do not need to send 
  	* any parameters here, if you have already called SetItemList
  	* and SetZipFileName.
  	IF NOT EMPTY( lcFiles)
  		THIS.SetItemList( m.lcFiles)
  	ENDIF
  	IF NOT EMPTY( m.lcZipFile)
  		THIS.SetZipFileName( m.lcZipFile)
  	ENDIF
  	THIS.oControl.ActionDZ = ZIP_FRESHEN
  	RETURN THIS.oControl.ErrorCode
  ENDFUNC
  * ------------------------------------------------------------ *
  FUNCTION UpdateFiles( lcFiles, lcZipFile)
  	* Immediately updates files to the Zip. You do not need to send 
  	* any parameters here, if you have already called SetItemList
  	* and SetZipFileName.
  	IF NOT EMPTY( lcFiles)
  		THIS.SetItemList( m.lcFiles)
  	ENDIF
  	IF NOT EMPTY( m.lcZipFile)
  		THIS.SetZipFileName( m.lcZipFile)
  	ENDIF
  	THIS.oControl.ActionDZ = ZIP_UPDATE
  	RETURN THIS.oControl.ErrorCode
  ENDFUNC 
  * ------------------------------------------------------------ *
ENDDEFINE  && CLASS L7Zip


*** ======================================================== ***
#if .f.
11/26/2003 - added support for archive and other DZ ZipSubOptions flags (changes courtesy: John Clarke)
03/11/2005 - added support for NoDirectoryNamesFlag
04/23/2006 - added UNZIP half
#endif