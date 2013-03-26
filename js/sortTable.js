// SortTable.js -- Prototype-dependent version

//RP: following line was: addEvent(window, "load", sortables_init);
Event.observe(window, 'load', sortables_init);

var SORT_COLUMN_INDEX;

// Find all tables with class sortable and make them sortable
function sortables_init() {
    $$("table").each(function(table)
    {
		if (table.hasClassName("sortable"))
			ts_makeSortable(table);
    });
}

function ts_makeSortable(table) {
    if (!table.rows || table.rows.length == 0)
		return;

    // We have a first row: assume it's the header, and make its contents clickable links
    var coltrack = 0;
    $A(table.rows[0].cells).each(function(cell)
    {
        if (!cell.hasClassName("nosort"))
        {
            cell.innerHTML = '<a href="#" class="sortheader" onclick="ts_resortTable(this, ' + coltrack + ');return false;">' + ts_getInnerText(cell) +'</a>';
        }
        // Track the colspan issue so the index is correct for spanned cols -- we will only sort on the first col of a spanned set of columns
        coltrack = coltrack + (cell.getAttribute('colspan') > 0 ? parseInt(cell.getAttribute('colspan'), 10) : 1);
    });
}

function ts_getInnerText(el) {
	if (typeof el == "string") return el;
	if (typeof el == "undefined") { return el };
	if (el.innerText) return el.innerText;	// Not needed but it is faster
	var str = "";
	
	var cs = el.childNodes;
	var l = cs.length;
	for (var i = 0; i < l; i++) {
		switch (cs[i].nodeType) {
			case 1: // ELEMENT_NODE
				str += ts_getInnerText(cs[i]);
				break;
			case 3:	// TEXT_NODE
				str += cs[i].nodeValue;
				break;
		}
	}
	return str;
}

function ts_resortTable(lnk,clid) {
    var th = $(lnk.parentNode);
    var column = clid || th.cellIndex;
    
	// Work out a type for the column
    var table = getParent(th, 'TABLE');
    if (table.rows.length <= 1) return;
    
	var itm = ts_getInnerText(table.rows[1].cells[column]);
	itm= itm.replace(/^\s*|\s*$/g, ""); //lc: trim leading spaces if any

	// choose a sort function
    var sortfn = ts_sort_caseinsensitive;
    // first pass, sniff the content of the first cell
    ts_routines.values().each(function(routine) { routine.patterns.each(function(pattern) { if (itm.match(pattern)) sortfn = routine.fn; }); });
    // second pass, override if we have any special type indicators in the class attribute of the header
    ts_routines.each(function(pair) { if (th.hasClassName(pair.key)) sortfn = pair.value.fn; });
    
    SORT_COLUMN_INDEX = column;
    var firstRow = $A(table.rows[0]);
    // partition remainder into sortable and non-sortable rows, based on class="sortbottom":
    var restRows = $A(table.rows).without(table.rows[0]).partition(function(objRow){return $(objRow).hasClassName('sortbottom')});
    var bottomRows = restRows[0];
    var newRows = restRows[1];
    newRows.sort(sortfn);

	if (th.hasClassName("sortdown")) {
		newRows.reverse();
		th.removeClassName("sortdown");
		th.addClassName("sortup");
	} else {
		th.removeClassName("sortup");
		th.addClassName("sortdown");
	}
    
    // AppendChild rows that already exist to the tbody, so it moves them rather than creating new ones - and leave sortbottom ones for the bottom
    newRows.each(function(row) {table.tBodies[0].appendChild(row);});
    bottomRows.each(function(row) {table.tBodies[0].appendChild(row)});
    // newRows.each(function(row) { if (! $(row).hasClassName('sortbottom')) table.tBodies[0].appendChild(row); });
    // newRows.each(function(row) { if ($(row).hasClassName('sortbottom')) table.tBodies[0].appendChild(row); });
    
    // Delete any other arrows there may be showing
    var siblingTHs = th.siblings().each(function (th) {
		if (th.hasClassName("sortdown")) th.removeClassName("sortdown")
		else if (th.hasClassName("sortup")) th.removeClassName("sortup");
    });
}

function getParent(el, pTagName) {
	if (el == null) return null;
	else if (el.nodeType == 1 && el.tagName.toLowerCase() == pTagName.toLowerCase())	// Gecko bug, supposed to be uppercase
		return el;
	else
		return getParent(el.parentNode, pTagName);
}

// SORTING ROUTINES
var ts_routines = $H({
	currency: { fn: ts_sort_currency, patterns: [/^[£$]/] },
	date: { fn: ts_sort_date, patterns: [/^\d\d[\/-]\d\d[\/-]\d\d\d\d$/, /^\d\d[\/-]\d\d[\/-]\d\d$/] },
	datetime: { fn: ts_sort_datetime, patterns: [/^\d\d[\/-]\d\d[\/-]\d\d\d\d\s\d\d:\d\d\s(AM|PM)$/] }, //rp: added this routine
	numeric: { fn: ts_sort_numeric, patterns: [/^[\d\.,]+$/] }, //lc: added , 
	caseinsensitive: { fn: ts_sort_caseinsensitive, patterns: [] }
});
	
function ts_sort_date(a,b) {
    // y2k notes: two digit years less than 50 are treated as 20XX, greater than 50 are treated as 19XX
    
    //rp: handle null cells (colspan's at bottom)
    //if (!a.cells[SORT_COLUMN_INDEX]) return 1;
    //if (!b.cells[SORT_COLUMN_INDEX]) return -1;
    
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]);
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]);
    //lc: trim leading spaces if any
    aa= aa.replace(/^\s*|\s*$/g, ""); 
    bb= bb.replace(/^\s*|\s*$/g, ""); 
    if (aa.length == 10) {
        dt1 = aa.substr(6,4)+aa.substr(0,2)+aa.substr(3,2);
    } else {
        yr = aa.substr(6,2);
        if (parseInt(yr) < 50) { yr = '20'+yr; } else { yr = '19'+yr; }
        dt1 = yr+aa.substr(0,2)+aa.substr(3,2);
    }
    if (bb.length == 10) {
        dt2 = bb.substr(6,4)+bb.substr(0,2)+bb.substr(3,2);
    } else {
        yr = bb.substr(6,2);
        if (parseInt(yr) < 50) { yr = '20'+yr; } else { yr = '19'+yr; }
        dt2 = yr+bb.substr(0,2)+bb.substr(3,2);
    }

    if (dt1==dt2) return 0;
    if (dt1<dt2) return -1;
    return 1;
}

//rp: added function ts_sort_datetime
function ts_sort_datetime(a,b) {
    // y2k notes: two digit years less than 50 are treated as 20XX, greater than 50 are treated as 19XX
    var aa, bb, yr, dt1, dt2
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]);
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]);
    aa= aa.replace(/^\s*|\s*$/g, ""); 
    bb= bb.replace(/^\s*|\s*$/g, ""); 
    if (aa.length == 19) {
        dt1 = aa.substr(6,4)+aa.substr(0,2)+aa.substr(3,2)+aa.substr(11,8);
    } else {
        yr = aa.substr(6,2);
        if (parseInt(yr) < 50) { yr = '20'+yr; } else { yr = '19'+yr; }
        dt1 = yr+aa.substr(0,2)+aa.substr(3,2)+aa.substr(9,8);
    } 
    if (bb.length == 19) {
        dt2 = bb.substr(6,4)+bb.substr(0,2)+bb.substr(3,2)+bb.substr(11,8);
    } else {
        yr = bb.substr(6,2);
        if (parseInt(yr) < 50) { yr = '20'+yr; } else { yr = '19'+yr; }
        dt2 = yr+bb.substr(0,2)+bb.substr(3,2)+bb.substr(9,8);
    }

    if (dt1==dt2) return 0;
    if (dt1<dt2) return -1;
    return 1;
}

function ts_sort_currency(a,b) { 
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).replace(/[^0-9.]/g,'');
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).replace(/[^0-9.]/g,'');
    return parseFloat(aa) - parseFloat(bb);
}

function ts_sort_numeric(a,b) { 
	  //LC: Adding non-digit cleanup here as well so footnotes etc do not throw off sorting
    aa = parseFloat(ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).replace(/[^0-9.]/g,''));
    if (isNaN(aa)) aa = 0;
    bb = parseFloat(ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).replace(/[^0-9.]/g,'')); 
    if (isNaN(bb)) bb = 0;
    return aa-bb;
}

function ts_sort_caseinsensitive(a,b) {
    aa = ts_getInnerText(a.cells[SORT_COLUMN_INDEX]).toLowerCase();
    bb = ts_getInnerText(b.cells[SORT_COLUMN_INDEX]).toLowerCase();
    if (aa==bb) return 0;
    if (aa<bb) return -1;
    return 1;
}

function addEvent(elm, evType, fn, useCapture)
// addEvent and removeEvent
// cross-browser event handling for IE5+,  NS6 and Mozilla
// By Scott Andrew
{
  if (elm.addEventListener){
    elm.addEventListener(evType, fn, useCapture);
    return true;
  } else if (elm.attachEvent){
    var r = elm.attachEvent("on"+evType, fn);
    return r;
  } else {
    alert("Handler could not be removed");
  }
} 