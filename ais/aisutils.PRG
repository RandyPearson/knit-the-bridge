* AisUtils.prg

#INCLUDE L7.H 
#include ais.h 
#DEFINE L7_XLS_DRIVER "{Microsoft Excel Driver (*.xls)}"
* note: cannot use "{Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)}" on 64-bit OS, thus cannot import from XLSX 
* 

* Test mode
if program(-1) = 1
  do AisUtils__main__
endif
return

function AisUtils__main__
  loImp = createobject("AisImport")
  loImp.Import()
  return 
endfunc 

define class AisImport as Custom 
  cAlias = "Import_"
  function Import(tcFile, tcSheet)
    this._ImportFromGoogleSignUp(m.tcFile, m.tcSheet)
    this._TransferToDatabase()
  endfunc 

  function _TransferToDatabase
    local loImp, loXfer
    use KtbAis!Artist again alias Artist in select("Artist")
    select (this.cAlias)
    scan
      scatter memo name loImp
      loXfer = null 
      loXfer = createobject("Empty")
      if !this._transform(m.loImp, m.loXfer)
        loop
      endif 
      select Artist
      locate for Art_Register_Time = loXfer.Art_Register_Time and ;
        Art_Name_Orig == loXfer.Art_Name_Orig 
      if found()  && assume already imported
        loop
      endif
      append blank && PK should get assigned
      gather name loXfer memo
      * replace Art_ID with AisGetID("Art_ID", ) ...
      
          
    endscan
    select artist
    browse last nowait     
  endfunc 

  function _transform(toImp, toXfer)    
    local lcTemp, ltTime 
    ltTime = datetime()
    
    addproperty(toXfer, "Art_Register_Time", nvl(toImp.timestamp, datetime(2013, 01, 01, 0, 0, 0)))
    addproperty(toXfer, "Art_Name_Orig", nvl(toImp.name, ""))
    if empty(toXfer.Art_Name_Orig)
      return .f.
    endif
    lcTemp = nvl(toImp.lastname, "")
    addproperty(toXfer, "Art_Last_Name", "")
    addproperty(toXfer, "Art_First_Name", "")
    if !"," $ m.lcTemp
      toXfer.Art_Last_Name = alltrim(m.lcTemp)
    else
      toXfer.Art_Last_Name = alltrim(getwordnum(m.lcTemp, 1, ","))
      toXfer.Art_First_Name = alltrim(getwordnum(m.lcTemp, 2, ","))
    endif
    
    addproperty(toXfer, "Art_Age_Range", nvl(toImp.age_range, ""))
    addproperty(toXfer, "Art_Bit_Info", nvl(toImp.bit_info, ""))
    * ...
    addproperty(toXfer, "Art_Contact_Orig", nvl(toImp.contact_information, ""))
    if '@' $ toXfer.Art_Contact_Orig
      lcTemp = chrtran(toXfer.Art_Contact_Orig, ',', ';')
      addproperty(toXfer, "Art_Email", alltrim(getwordnum(m.lcTemp, 1, ";")))
      addproperty(toXfer, "Art_Phone", alltrim(getwordnum(m.lcTemp, 2, ";")))
    else
      addproperty(toXfer, "Art_Phone", alltrim(toXfer.Art_Contact_Orig))
    endif 
    
    addproperty(toXfer, "Art_Artist", .f.)
    addproperty(toXfer, "Art_Panel_Count", 0)
        
    addproperty(toXfer, "Art_Panel_Info", nvl(toImp.full_panel_and_count, ""))
    * ...
    addproperty(toXfer, "Art_Participation", nvl(toImp.I_want_to_participate_in_Knit_the_Bridge_by___, ""))
    if "making a partial panel" $ lower(toXfer.Art_Participation)
      addproperty(toXfer, "Art_Partial_Panel", .t.)
      toXfer.Art_Artist = .t.
    endif 
    if "making a full panel" $ lower(toXfer.Art_Participation) or ;
        "making a panel" $ lower(toXfer.Art_Participation) 
      toXfer.Art_Panel_Count = 1
      toXfer.Art_Artist = .t.
    endif 
    if "machine" $ lower(toXfer.Art_Participation)
      addproperty(toXfer, "Art_Towers", .t.)
    endif 
    if "meet up" $ lower(toXfer.Art_Participation)
      addproperty(toXfer, "Art_Help_Meet_Up", .t.)
    endif 
    if "install" $ lower(toXfer.Art_Participation)
      addproperty(toXfer, "Art_Help_Install", .t.)
    endif 
    if "school" $ lower(toXfer.Art_Participation)
      addproperty(toXfer, "Art_Help_Outreach", .t.)
    endif 
    
    addproperty(toXfer, "Art_KTB_Response", nvl(toImp.KTB_email_response, ""))
    
    addproperty(toXfer, "Art_Address", nvl(toImp.Neighborhood_or_Township, ""))
    addproperty(toXfer, "Art_Neighborhood", toXfer.Art_Address) && default start point 
    
    addproperty(toXfer, "Art_Notes", nvl(toImp.notes, ""))
    addproperty(toXfer, "Art_Received", !isnull(toImp.received) and "Y" $ upper(toImp.received))
    
    addproperty(toXfer, "Art_Storage_Location", nvl(toImp.storage_location, ""))

    addproperty(toXfer, "Art_Orig_Art_FK", THISAPP_ADMIN_PK)
    addproperty(toXfer, "Art_Orig_Time", m.ltTime)
    addproperty(toXfer, "Art_Rev_Art_FK", THISAPP_ADMIN_PK)
    addproperty(toXfer, "Art_Rev_Time", m.ltTime)

    return .t. 
  endfunc 

  function _ImportFromGoogleSignUp(tcFile, tcSheet)
    local lcAlias, lcXls, lcSqlConnString, lnSqlHandle, lcSqlCmd, lnSuccess
    lcAlias = this.cAlias 
    use in select(m.lcAlias)
    lcXls = iif(!empty(m.tcFile), m.tcFile, getfile("xls","Select spreadsheet file to import.", "Import", IDOK, "KtB Sign-Up Import"))
    if empty(m.lcXls)  && cancel
      return
    endif 
    lcSqlConnString = [Driver=] + L7_XLS_DRIVER + [;] + [DBQ=] + m.lcXls
    lnSqlHandle = sqlstringconnect(m.lcSqlConnString)
    if m.lnSqlHandle <= 0
      messagebox("sqlstringconnect() did not yield a handle. You may or may not have just been told why. ")
      return
    endif
    lcSqlCmd = [select * from "] + evl(m.tcSheet, "SHEET1") + [$"]
    try
      lnSuccess = sqlexec(m.lnSQLHandle, m.lcSQLCmd, m.lcAlias)
    finally
      sqldisconnect(m.lnSQLHandle)
    endtry 
    if m.lnSuccess < 1
      messagebox("sqlexec() failed. You may or may not have just been told why. ")
    else
      select (m.lcAlias)
      * browse nowait 
    endif
    return 
  endfunc 
enddefine && AisImport 

* EOF: 
