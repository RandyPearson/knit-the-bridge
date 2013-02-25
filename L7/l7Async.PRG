#INCLUDE L7.H

DEFINE CLASS L7Async AS Line
  cStatusTemplate = ""
  
  FUNCTION EnQueue(loRequest)
  FUNCTION Locate(lcId)
  FUNCTION GetStatus()
  FUNCTION Cancel()
  
  
ENDDEFINE && L7Async
