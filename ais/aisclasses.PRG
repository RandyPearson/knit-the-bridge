* AisClasses.PRG

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* App Classes:
set procedure to AisApp     additive  && Application Object
set procedure to AisClasses additive  && THIS file
set procedure to AisUser    additive  && User class

* Page Classes:
set procedure to AisPages   additive   

return 


*** ========================================================= ***
* [[ all methods here need to defend against correct database not being current
* [[ same for IMDB, etc...
define class AisLookup AS Line
  * --------------------------------------------------------- *
  function GetSnippet(tcTitle, tlNoParse, tcDefault)
    local lcAlias, loEnv, lcRet
    loEnv = CREATEOBJECT("L7PreserveSelect")
    lcAlias = goL7App.oCacheManager.CacheCursor( ;
      [SELECT Snp_PK, Snp_Title, Snp_Textmerge, Snp_Parse, Snp_Text] + ;
      [ FROM ] + THISAPP_DATABASE + [!Snippet] + ;
      [ WHERE NOT Snp_Inactive])
    tcTitle = PADR(m.tcTitle, LEN(Snp_Title))
    locate for Snp_Title = m.tcTitle
    if !found()
      if vartype(m.tcDefault) = "C"  && a default is passed, even ""
        lcRet = m.tcDefault
      else   
        lcRet = "[" + TRIM(m.tcTitle) + "]" && decent placeholder for text not yet developed
      endif  
    else 
      lcRet = AllTrimX(Snp_Text)
      if Snp_Parse AND NOT m.tlNoParse
        L7ParseOnView(@lcRet)
      endif 
    endif 
    return m.lcRet
  endfunc 
  * --------------------------------------------------------- *
  function GetAlias(lcName)
    local lcAlias
    do case 
    *!*      case lcName == "RuleSections"
    *!*        lcAlias = goL7App.oCacheManager.CacheCursor( ;
    *!*          [SELECT Sec_PK, Sec_Name, Sec_Number, Sec_Parent_Sec_FK] + ;
    *!*          [ FROM ] + THISAPP_DATABASE + [!Section] + ;
    *!*          [ WHERE NOT Sec_Inactive] + ;
    *!*          [ ORDER BY Sec_Number])
    otherwise 
      error "Lookup.GetAlias(): " + "Alias not defined: " + m.lcName
    endcase 
    return  m.lcAlias
  endfunc 
enddefine 

*** ========================================================= ***
* Configuration class for the OQDB application:
define class AisConfig as L7AppConfig
  cFilePath = "" && for doc/pdf/etc.
  cHTMLPagePath = "c:\Inetpub\wwwroot\ktb-ais\"
  cDATAPath = "c:\vfpdata\ais\"
  cLogPath = "d:\VfpLogs\ktb-ais\"
  cMessagingPath = "d:\VfpMessaging\ktb-ais\"
  cTransactionPath = "d:\VfpTransaction\ktb-ais\"
  lReadOnly = .F.
  lDebugQueries = .F.
  lSendMailImmediately = .T.
  cPageExtension = "ktb"
enddefine 


*** ========================================================= ***
* End: AisClasses.PRG
