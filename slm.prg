lparameters tnSkipBack
do l7classes
do wconnect

use C:\vfpmessaging\ktb-ais\l7MessageQueue.DBF 
go bottom
if !empty(m.tnSkipBack)
  skip -abs(m.tnSkipBack)
endif 
showhtml(Details)
return 