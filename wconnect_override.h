* WCONNECT_OVERRIDE.h

* Mandatory - add framework constants:
#INCLUDE L7.H

* #UNDEF DEBUGMODE 
* #DEFINE DEBUGMODE .F.

* All of the following are in L7.H:
*
*!*  * Mandatory - Server class override:
*!*  #UNDEF  WWC_SERVER
*!*  #DEFINE WWC_SERVER               L7wwServer

*!*  * Mandatory - Request class override:
*!*  #UNDEF  WWC_REQUEST
*!*  #DEFINE WWC_REQUEST              L7wwRequest

*!*  * Optional - provide ability to alter info dislayed in server status form:
*!*  #UNDEF  WWC_SERVERFORM 			
*!*  #DEFINE WWC_SERVERFORM           L7wwServerForm

*!*  #UNDEF  WWC_SERVERFORM_VFPFRAME 
*!*  #DEFINE WWC_SERVERFORM_VFPFRAME  L7wwServerFormVFPFrame


