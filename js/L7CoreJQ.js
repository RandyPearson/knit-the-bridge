/*
L7CoreJQ.JS - core JavaScript for L7 Framework -- jQuery VERSION!!
Location: ??
Author: Randy Pearson, Cycla Corp
*/

function L7toggleDisplay(lcId) { // toggle hidden status (compare: L7toggleVisibility)
  var lvItem = typeof(lcId)=="string" ? '#'+lcId : lcId ;
  $j(lvItem).toggle();
}

function L7toggleVisibility(lcId){ // toggle visibility status (compare: L7toggleDisplay)
 var $lvItem = $j( (typeof(lcId)=="string") ? '#'+lcId : lcId) ;
 return $lvItem.css('visibility', ($lvItem.css('visibility')=="hidden") ? "visible" : "hidden") 
}

function L7setDisplay(loObj, llSet) { // set display status from Boolean
 return (llSet) ? $j(loObj).show() : $j(loObj).hide() ; 
}

function L7setVisibility(loObj, llSet) // set visibility status from Boolean
{ return $j(loObj).css('visibility', (llSet) ? "visible" : "hidden") }

function L7cbShowHide(loObj, lcTargId, llHide)
{ var $loSrc = $j(typeof(loObj)=="string" ? '#'+loObj : loObj) ;
  lcTargId = (lcTargId) ? lcTargId : loSrc.attr('id') + "_dep"; // if no target, assume special dependent object
  var $loTarg = $j('#' + lcTargId);
  if ($loTarg.length) {L7setDisplay($loTarg, (llHide) ? !$loSrc.attr('checked') : $loSrc.attr('checked'))}
  else {alert('No target!');}
  /* 7/31/07: changed to set Display vs. Visibility */
}

function L7popShowHide(loObj, lcShowVal, lcTargId, llHide)
{ // P: loObj = $(loObj);
	var $loSrc = $j(typeof(loObj)=="string" ? '#'+loObj : loObj) ;
  lcTargId = (lcTargId) ? lcTargId : loSrc.attr('id') + "_dep"; // if no target, assume special dependent object
  var loTarg = $j('#' + lcTargId);
  /* to do: change Visibility to Display */
  if (loTarg.length) {L7setVisibility(loTarg, (llHide) ? loSrc.value !== lcShowVal : loSrc.value == lcShowVal)}
  else {alert('No target!');}
}

function L7checkIfRadioChecked(loObj, lcValue, lcTargId, llUncheck) // if object checked, check other object
{ // Protoype version used: loObj = $(loObj);
  var $loSrc = $j(typeof(loObj)=="string" ? '#'+loObj : loObj) ;
  lcTargId = (lcTargId) ? lcTargId : loSrc.attr('id') + "_dep"; // if no target, assume special dependent object
  var loTarg = $j('#' + lcTargId);
  if (loTarg) {
   	if (loObj.value == lcValue) {
      loTarg.attr('checked', (llUncheck) ? '' : 'checked');}
 		}
  else {alert('No such JQuery target: ' + lcTargId);}
}

function L7setDisabled(loObj, llSet) // set Disabled status from Boolean
{ // P: loObj = $(loObj);
	var $loSrc = $j(typeof(loObj)=="string" ? '#'+loObj : loObj) ;
	loSrc.attr('disabled', (llSet) ? false : true) ;
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
{ var $loObj = $j(typeof(lcId)=="string" ? '#'+lcId : lcId);
  $loObj.AddClass(lcClass);
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
