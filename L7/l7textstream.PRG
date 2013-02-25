* L7TextStream.PRG

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

*** ========================================================== ***
DEFINE CLASS L7TextStream AS RELATION
  nHandle = -1
  cFileName = ""

  nInitialThreshhold = 25000     && bytes before file is created
  nIncrementalThreshhold = 1000  && bytes once file has been created

  cBuffer = ""
  lFileOpened = .F.
  lFileCreationFailed = .F.
  * ---------------------------------------------------------- *
  FUNCTION DESTROY
    IF THIS.lFileOpened
    	= FCLOSE( THIS.nHandle)
    	ERASE ( THIS.cFileName)
    ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION Write
    LPARAMETERS lcText
    THIS.cBuffer = THIS.cBuffer + m.lcText
    IF NOT THIS.lFileCreationFailed
    	LOCAL lnLen
    	lnLen = LEN( THIS.cBuffer)
    	IF m.lnLen > THIS.nIncrementalThreshhold
    		IF NOT THIS.lFileOpened
    			IF m.lnLen > THIS.nInitialThreshhold
    				= THIS.CreateFile( THIS.cBuffer)
    				IF THIS.lFileOpened = .T.
    					THIS.cBuffer = ""
    				ENDIF
    			ENDIF
    		ELSE
    			= FWRITE( THIS.nHandle, THIS.cBuffer )
    			THIS.cBuffer = ""
    		ENDIF
    	ENDIF
    ENDIF
  ENDFUNC  && Write
  * ---------------------------------------------------------- *
  FUNCTION Clear
    THIS.cBuffer = ""
    IF THIS.lFileOpened
    	= FCLOSE( THIS.nHandle)
    	ERASE ( THIS.cFileName)
    	THIS.lFileOpened = .F.
    	THIS.nHandle = -1
    ENDIF
  ENDFUNC
  * ---------------------------------------------------------- *
  FUNCTION Render
    RETURN THIS.GetOutput()
  ENDFUNC  && Render
  * ---------------------------------------------------------- *
  FUNCTION GetOutput
    IF THIS.lFileOpened
    	LOCAL lcText
    	= FCLOSE( THIS.nHandle)
    	lcText = FILETOSTR( THIS.cFileName )
    	ERASE ( THIS.cFileName)
    	THIS.lFileOpened = .F.
    	THIS.nHandle = -1
    	RETURN m.lcText + THIS.cBuffer
    ELSE
    	RETURN THIS.cBuffer
    ENDIF
  ENDFUNC  && GetOutput
  * ---------------------------------------------------------- *
  FUNCTION CreateFile
    LPARAMETERS lcStartText
    LOCAL lcName, lnHandle
    lcName = SYS( 2023) + "L7TextStream" + ALLTRIM( SYS( 3)) + ;
    	"_" + TRANS( INT( 1000 * RAND())) + ".TMP"
    lnHandle = FCREATE( m.lcName )
    IF m.lnHandle >= 0
    	THIS.nHandle = m.lnHandle
    	THIS.cFileName = m.lcName
    	THIS.lFileOpened = .T.
    	= FWRITE( m.lnHandle, m.lcStartText )
    ELSE
    	THIS.nHandle = m.lnHandle
    	THIS.lFileOpened = .F.
    	THIS.lFileCreationFailed = .T.  && don't keep trying
    ENDIF
  ENDFUNC  && CreateFile
  * ---------------------------------------------------------- *
ENDDEFINE  && L7TextStream
*** ========================================================== ***
