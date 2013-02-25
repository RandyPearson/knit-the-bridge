* L7Api.PRG

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

#DEFINE MAX_DWORD         4294967296    && 0xffffffff + 1 
#DEFINE TIME_ZONE_INFORMATION REPL( CHR(0), 172)

* ------------------------------------------------ *
FUNCTION L7Beep(lnFreq, lnDur)
  lnFreq = EVL(m.lnFreq, 300)
  lnDur = EVL(m.lnDur, 50)
  DECLARE Integer Beep IN WIN32API ;
    Integer frequency, Integer duration
  Beep(m.lnFreq, m.lnDur)
ENDFUNC
* ------------------------------------------------ *
function GetTimeZoneOffset
  * Returns time sone offset in *minutes*.
  * Divide by 60 in your app for Hours!.
  DECLARE INTEGER GetTimeZoneInformation ;
  	IN Kernel32.DLL ;
  	STRING @lpTimeZoneInformation
  local lpTimeZoneInformation, lnBias, lnRet
  lpTimeZoneInformation = TIME_ZONE_INFORMATION
  lnBias = GetTimeZoneInformation( @lpTimeZoneInformation )
  lnRet = LongToInt( LEFT( m.lpTimeZoneInformation, 4) ) 
  if m.lnBias = 2 && daylight in effect
    lnRet = m.lnRet - 60 
  endif 
  return m.lnRet 
endfunc && GetTimeZoneOffset 
* ------------------------------------------------ *
function LongToInt(tcLong)
  local lnInt, ii, lnDigit
  lnInt = 0
  if vartype(m.tcLong) <> "C" OR len(m.tcLong) <> 4
  	lnInt = 0
  else 
  	for ii = 4 to 1 step -1  && longs are backward
  		lnDigit = asc(substr(m.tcLong, m.ii, 1))
  		lnInt = m.lnInt + m.lnDigit
  		if m.ii > 1
  			lnInt = m.lnInt * 256
  		endif 
  	next  
  	if m.lnInt > 2147483647  && Longs are signed.
  		lnInt = m.lnInt - 0x100000000
  	endif 
  endif 
  return  m.lnInt
endfunc  && LongToInt

*---------------------------------------------------------- 
function L7GetPerfCounter() 
  local lcBuf
  DECLARE INTEGER QueryPerformanceCounter IN kernel32; 
          STRING @lpPerformanceCount 
  lcBuf = replicate(chr(0), 8)
  QueryPerformanceCounter(@lcBuf)
  return Large2Num(m.lcBuf) && divide by frequency to get units of time 
endfunc 
*---------------------------------------------------------- 
function L7GetPerfFrequency() 
  local lcBuf
  DECLARE INTEGER QueryPerformanceFrequency IN kernel32; 
          STRING @lpFrequency 
  lcBuf = replicate(chr(0), 8)
  QueryPerformanceFrequency(@lcBuf)
  return Large2Num(m.lcBuf)
endfunc 
*---------------------------------------------------------- 
* From LC article on performance. 
function   large2num ( tcLarge ) 
  return str2dword( substr( m.tcLarge, 1, 4 ) ) + ; 
         str2dword( substr( m.tcLarge, 5, 4 ) ) * MAX_DWORD  && MAX_DWORD is 256 ^ 4
endfunc
*---------------------------------------------------------- 
* From LC article on performance. 
function  str2dword ( tcStr ) 
  return asc( substr( m.tcStr, 1, 1 ) )             + ; 
         asc( substr( m.tcStr, 2, 1 ) )  * 256      + ; 
         asc( substr( m.tcStr, 3, 1 ) )  * 65536    + ; 
         asc( substr( m.tcStr, 4, 1 ) )  * 16777216 
endfunc
* ------------------------------------------------ *
function GetIniSetting(lcIniFile, lcSection, lcSetting)
  local lcValue, lnLength
  lcValue = space(254)

  lnLength = GetPrivateProfileString( ;
  	lcSection, lcSetting, "*None*", ;
  	@lcValue, LEN( m.lcValue), m.lcIniFile)

  * Remove null terminator:
  lcValue = SUBSTR( m.lcValue, 1, m.lnLength )

  if m.lcValue == "*None*"
     lcValue = ""
  endif 
  return lcValue
endfunc  && GetIniSetting
* ------------------------------------------------ *
* End: L7Api.PRG
