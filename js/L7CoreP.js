/*
L7CoreP.JS - core JavaScript for L7 Framework -- PROTOTYPE VERSION!!
Location: http://www.cycla.com/software/l7/L7CoreP.js
Author: Randy Pearson, Cycla Corp

Thanks to Jason Cranford Teague for his excellent book, "DHTML and CSS" (ISBN 0-201-73084-7)!
Postions of the cross-browser DOM strategy based on material and concepts presented in that work.
*/
// user agent (browser) vars:
var L7uaVersion = parseInt(navigator.appVersion);
var L7uaName = navigator.appName;


// which DOM models apply?:
var L7hasDOM = 0;         // W3C DOM: getElementById, getElementsByName, etc
var L7hasLayers = 0;      // old NN 4 DOM
var L7hasAll = 0;         // old MSIE 4 DOM
var L7hasDHTML = 0;       // absolute positioning and dynamic CSS support

if (document.all) {L7hasAll = 1; L7HasDHTML = 1;}  //we may want to know this, even if W3C DOM supported
if (document.getElementById) {L7hasDOM = 1; L7hasDHTML = 1;}
else { 
  if ((L7hasAll == 0) && (L7uaName.indexOf('Netscape') != -1) && (L7uaVersion == 4)) 
  {L7hasLayers = 1; L7hasDHTML = 1;}
  // we don't "feature sense" for layers, because of NN bug on first hit in browser window
}
  
function L7getObjRef(lcId) // DEPRECATED: use $(lcId) directly
/* NOTE: instead of refactoring in Prototype, we should just replace calls to this function with $() */
{ // Given an id="" value, return an object reference using the DOM.
  if (L7hasDOM >= 1) {return (document.getElementById(lcId));}
  else { 
    if (L7hasAll >= 1) {return (document.all[lcId]);}
    else {
      if (L7hasLayers >= 1) {return (document.layers[lcId]);}
    }
  }
} // end: L7getObjRef(lcId)

function L7getStyleObjRef(lcId)
{ // Given an id="" value, return an object reference to the element's *STYLE* object
  var loObj = null;
  if (L7hasDOM >= 1) {loObj = document.getElementById(lcId).style;}
  else { 
    if (L7hasAll >= 1) {loObj = document.all[lcId].style;}
    else {
      if (L7hasLayers >= 1) {loObj = document.layers[lcId];} // with NN4, style was not a separate object!
    }
  }
  return loObj;
} // end: L7getObjRef(lcId)

function L7toggleDisplay(lcId) // toggle hidden status (compare: L7toggleVisibility)
{ $(lcId).toggle(); }

function L7toggleVisibility(lcId) // toggle visibility status (compare: L7toggleDisplay)
{ var loStyle;
  if (typeof(lcId) == "string"){loStyle = L7getStyleObjRef(lcId);}
  else {loStyle = lcId.style}
  if (loStyle){
    if (loStyle.visibility == "hidden" || loStyle.visibility == "hide"){loStyle.visibility = "visible";}
    else {loStyle.visibility = "hidden";}
  }
}

function L7setDisplay(loObj, llSet) // set display status from Boolean
{ return (llSet) ? $(loObj).show() : $(loObj).hide() ; }

function L7setVisibility(loObj, llSet) // set visibility status from Boolean
{ var loStyle = $(loObj).style;
  loStyle.visibility = (llSet) ? "visible" : "hidden";
}

function L7cbShowHide(loObj, lcTargId, llHide)
{ loObj = $(loObj);
  lcTargId = (lcTargId) ? lcTargId : loObj.getAttribute('id') + "_dep";
  var loTarg = $(lcTargId);
  if (loTarg) {L7setDisplay(loTarg, (llHide) ? !loObj.checked : loObj.checked)}
  else {alert('No target!');}
  /* 7/31/07: changed to set Display vs. Visibility */
}

function L7popShowHide(loObj, lcShowVal, lcTargId, llHide)
{ loObj = $(loObj);
  lcTargId = (lcTargId) ? lcTargId : loObj.getAttribute('id') + "_dep";
  var loTarg = $(lcTargId);
  /* to do: change Visibility to Display */
  if (loTarg) {L7setVisibility(loTarg, (llHide) ? loObj.value !== lcShowVal : loObj.value == lcShowVal)}
  else {alert('No target!');}
}

function L7checkIfRadioChecked(loObj, lcValue, lcTargId, llUncheck) // if object checked, check other object
{ loObj = $(loObj);
  lcTargId = (lcTargId) ? lcTargId : loObj.getAttribute('id') + "_dep";
  var loTarg = $(lcTargId);
  if (loTarg) {if (loObj.value == lcValue) {loTarg.checked = (llUncheck) ? false : true;}}
  else {alert('No target!');}
}

function L7setDisabled(loObj, llSet) // set Disabled status from Boolean
{ loObj = $(loObj);
	if (typeof loObj.disabled == "boolean"){loObj.disabled = (llSet) ? false : true ;}
}

function L7setReadonly(loObj, llSet) // set Readonly status from Boolean
{ loObj = $(loObj);
	if (typeof loObj.readOnly == "boolean"){
    loObj.readOnly = (llSet) ? false : true ;
    if (llSet){
     var loStyle = loObj.style;
     if (loObj.parentNode)
     {loStyle = loObj.parentNode.style;}
     loStyle.borderWidth = '10px';
     loStyle.borderColor = 'red';
     loStyle.borderStyle = 'dotted';
    }
  }
  else
  {alert('Object does not support readonly!')}
}

function L7setInputHidden(loObj, llSet) // set HIDDEN type from Boolean
{ loObj = $(loObj);
	if (typeof loObj.type == "string"){loObj.type = (llSet) ? 'hidden' : 'text' ;}
  else {alert('Object does not support hidden!')}
}

function L7setClass(lcId, lcClass) /* Old Function: see multitude of Prototype classname handling functions */
{ var loObj = $(lcId);
  if (loObj) {loObj.className = lcClass;}
}

function L7setStyleAttribute(lcId, lcAtt, lcValue)
{ var loStyle = L7getStyleObjRef(lcId);
  if (loStyle){loStyle[lcAtt] = lcValue;}
}

function L7singleSubmit(loForm)
{ if (loForm.nSubmitCount) 
  { alert("Already submitted!"); 
    return false; 
  }
  else 
  { loForm.nSubmitCount = 1; // impute a property
    return true; 
  }
}

function L7checkAll(lcForm, lcPrefix, llCheck) 
/* 
Check or uncheck all checkboxes on a named form that have
names matching a given prefix. 
*/
{ var loForm = document.forms[lcForm];
  var lnPrefLen = (lcPrefix == null) ? 0 : lcPrefix.length;
  for (ii = 0; ii < loForm.length; ii++)
  { if (loForm.elements[ii].type == "checkbox")
      { lcField = loForm.elements[ii].name;
        if ( lnPrefLen == 0 || lcPrefix == lcField.substr(0,lnPrefLen) )
         { loForm.elements[ii].checked = llCheck };
      }
   }
} //end: L7checkAll


function L7augmentAllQueryStrings(lcStr)
{
  var loLink
  for (lnLink = 0; lnLink < doc.links.length; lnLink++)
  {
   loLink = doc.links[lnLink];
   lcCur = loLink.search;
   if (lcCur == null || lcCur == "")
   { lcNew = "?" + lcStr; }
   else
   { lcNew = lcCur + lcStr; }
   loLink.search = lcNew;
  }
} //end: L7augmentAllQueryStrings

function L7writeLinks(lcCaption)
{var doc = document;
 if (doc.links.length > 0)
 {doc.write('<table bgcolor="#fefefe" border="1">');
 if (lcCaption){doc.write('<tr bgcolor="#cccccc"><th colspan="10" align="left">' + lcCaption + '</th></tr>');}
   doc.write('<tr valign="top">');
   doc.write('<th align="right">No.</th>');
   doc.write('<th>href</th>');
   doc.write('<th>protocol</th>');
   doc.write('<th>host</th>');
   doc.write('<th>hostname</th>');
   doc.write('<th>port</th>');
   doc.write('<th>pathname</th>');
   doc.write('<th>search</th>');
   doc.write('<th>hash</th>');
   doc.write('<th>target</th>');
   doc.write('</tr>');
   for (lnLink = 0; lnLink < doc.links.length; lnLink++)
   {
     doc.write('<tr valign="top">');
     doc.write('<td align="right">' + (lnLink + 1) + '.</td>');
     doc.write('<td>' + doc.links[lnLink].href	 + '&nbsp;</td>');
     doc.write('<td>' + doc.links[lnLink].protocol + '&nbsp;</td>');
     doc.write('<td>' + doc.links[lnLink].host + '&nbsp;</td>');
     doc.write('<td>' + doc.links[lnLink].hostname + '&nbsp;</td>');
     doc.write('<td>' + doc.links[lnLink].port + '&nbsp;</td>');
     doc.write('<td>' + doc.links[lnLink].pathname + '&nbsp;</td>');
     doc.write('<td>' + doc.links[lnLink].search + '&nbsp;</td>');
     doc.write('<td>' + doc.links[lnLink].hash + '&nbsp;</td>');
     doc.write('<td>' + doc.links[lnLink].target + '&nbsp;</td>');
     doc.write('</tr>');
   }
   doc.write('</table>');
 }
} //end: L7writeLinks

function focusFirst()
{
  if (document.forms[0])
  {
    if ( document.forms[0].elements.length ) {
       // JS 1.1 needed for form.elements.length property
       var lnElems = document.forms[0].elements.length ;
     }
     else {
       var lnElems = 2 ;
     }
     var lnElem = 0 ;
     var lcType = '' ;
     while ( lnElem < lnElems ) {
       lcType = document.forms[0].elements[lnElem].type ;
       if ( lcType == 'text' || lcType == 'textarea' || lcType == 'select-one' ) {
           document.forms[0].elements[lnElem].focus() ;
           break ;
       }
       if ( lcType == 'radio' || lcType == 'checkbox' || lcType == 'select-multiple' ) {
           // break, so we don't give focus to a later textbox
           break ;
       }
       lnElem++ ;
     }
  }
}
function checkAll( lcForm, lcMatch, llChecked )
{
  for ( ii = 0; ii < document.forms[lcForm].length; ii++)
    {
      if ( document.forms[lcForm].elements[ii].type == "checkbox")
        { 
          lcField = document.forms[lcForm].elements[ii].name;
		  if ( lcField.length > lcMatch.length )
		    {
              lcPrefix = lcField.substr(0,lcMatch.length);
              if ( lcPrefix == lcMatch )
               { document.forms[lcForm].elements[ii].checked = llChecked };
			};
        };
    }
}
