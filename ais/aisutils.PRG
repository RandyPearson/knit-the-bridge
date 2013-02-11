* AisUtils.prg

#INCLUDE L7.H 
#DEFINE L7_XLS_DRIVER "{Microsoft Excel Driver (*.xls)}"
* note: cannot use "{Microsoft Excel Driver (*.xls, *.xlsx, *.xlsm, *.xlsb)}" on 64-bit OS, thus cannot import from XLSX 
* 

* Test mode
if program(-1) = 1
  do AisUtils__main__
endif
return

function AisUtils__main__
  do AisImportFormGoogleSignUp 
  return 
endfunc 

function AisImportFormGoogleSignUp(tcFile, tcSheet)
  local lcAlias, lcXls, lcSqlConnString, lnSqlHandle, lcSqlCmd, lnSuccess
  lcAlias = "Import_"
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
  lcSqlCmd = [Select * FROM "] + evl(m.tcSheet, "SHEET1") + [$"]
  try
    lnSuccess = SQLEXEC(m.lnSQLHandle, m.lcSQLCmd, m.lcAlias)
  finally
    sqldisconnect(m.lnSQLHandle)
  endtry 
  if m.lnSuccess < 1
    messagebox("sqlexec() failed. You may or may not have just been told why. ")
  else
    select (m.lcALias)
    browse nowait 
  endif
  return 
endfunc 

* EOF: 
