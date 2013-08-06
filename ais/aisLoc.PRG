* AisLoc.PRG  && Location pages

#INCLUDE WCONNECT.H
#INCLUDE AIS.H

* --------------------------------------------------------- *
function AisDescribeLocation(tvItem)
  local loData, loPreserve, lcRet, loLocater
  do case 
  case vartype(m.tvItem) = "O" && object passed
    loData = m.tvItem

  case !isnull(m.tvItem) and vartype(m.tvItem) = "L" && nothing passed--"assume" current record applies
    if type("Loc_FK") = "C"
      scatter memo name loData
    else
      return "--"
    endif

  case isnull(m.tvItem) or empty(m.tvItem)
    return "--"

  otherwise  && PK alone passed
    loData = AisGetPanelLocation(m.tvItem)
  endcase

  loLocater = createobject("AisLocater")
  
  lcRet = loLocater.DescribeLocation(m.loData)
  return m.lcRet
endfunc 

*** ========================================================= ***
define class aisLocater as custom
  cAlias = "AisLocater_Locations_"
  * --------------------------------------------------------- *
  function queryLocations(loLoc)
    local loQ
    loQ = createobject("AisLocQuery")
    with loQ
      .cSide = loLoc.Loc_Side
      .cAlias = this.cAlias
      .AddOrderBy("Loc_No")
      .Execute()
    endwith
  endfunc 
  * --------------------------------------------------------- *
  function DescribeLocation(loLoc)
    local lcItems, loSelect
    loSelect = createobject("L7PreserveSelect")
    this.queryLocations(m.loLoc)
    lcItems = ""
    lcItems = m.lcItems + "* " + this.DescribeID(m.loLoc) + crlf 
    lcItems = m.lcItems + "* " + this.DescribeOrientation(m.loLoc) + crlf 
    lcItems = m.lcItems + "* " + this.DescribeSide(m.loLoc) + crlf
    lcItems = m.lcItems + "* " + this.DescribeHowFar(m.loLoc) + crlf
    lcItems = m.lcItems + "* " + this.ListMarkers(m.loLoc) + crlf
    lcItems = m.lcItems + "* " + this.ListComments(m.loLoc) + crlf
    lcItems = L7ParseOnView(m.lcItems)
    return m.lcItems
  endfunc && DescribeLocation
  * --------------------------------------------------------- *
  function DescribeID(loLoc)
    local lcRet
    lcRet = "KtB Location ID: *" + aisFormatPanelLocation(m.loLoc) + "*"
    return m.lcRet
  endfunc && DescribeLocation
  * --------------------------------------------------------- *
  function DescribeSide(loLoc)
    local lcRet
    lcRet = iif(loLoc.Loc_Side = "Up", ;
      "on the *up-river* side of the bridge (the side facing 9th street)", ;
      "on the *down-river* side of the bridge (the side facing 6th street and PNC Park)")
    return m.lcRet
  endfunc && DescribeLocation
  * --------------------------------------------------------- *
  function DescribeOrientation(loLoc)
    local lcRet
    lcRet = iif(loLoc.Plc_Orientation = "Inner", ;
      "oriented to the *inside*, meaning best viewed from the Warhol bridge pedestrian walkway ", ;
      "oriented to the *outside*, meaning best viewed from " + ;
        iif(loLoc.Loc_Side = "Up", ;
          "the Rachel Carson (9th Street) Bridge", ;
          "the Clemente (6th Street) Bridge"))
    return m.lcRet
  endfunc && DescribeOrientation
  * --------------------------------------------------------- *
  function DescribeHowFar(loLoc)
    select (this.cAlias)
    go bottom
    lcRet = textmerge([<<loLoc.Loc_No>>/<<Loc_No>> (*<<round(100 * loLoc.Loc_No/Loc_No, 0)>>%*) of the way across the bridge (starting from the Downtown end)])
    return m.lcRet 
  endfunc 
  * --------------------------------------------------------- *
  function ListMarkers(loLoc)
    local lcRet, lnLocNo, lcRel
    lnLocNo = loLoc.Loc_No
    select abs(Loc_No - m.lnLocNo) as _Dist_ , * from (this.cAlias) where !empty(Loc_Marker) order by 1 into cursor this.cAlias + "Markers_"
    lcRel = icase(;
      loLoc.Loc_No = Loc_No, "right at this panel location", ;
      loLoc.Loc_No > Loc_No, "<<loLoc.Loc_No - Loc_No>> panels closer to Downtown", ;
      "<<Loc_No - loLoc.Loc_No>> spaces closer to North Shore")

    lcRet = "closest marker: *" + trim(Loc_Marker) + "*, which is " + textmerge(m.lcRel)
    return m.lcRet
  endfunc 
  * --------------------------------------------------------- *
  function ListComments(loLoc)
    local lcRet, lnLocNo, lcRel
    lnLocNo = loLoc.Loc_No
    select abs(Loc_No - m.lnLocNo) as _Dist_ , * from (this.cAlias) where !empty(Loc_Comments) order by 1 into cursor this.cAlias + "Comments_"
    lcRel = icase(;
      loLoc.Loc_No = Loc_No, "right at this panel location", ;
      loLoc.Loc_No > Loc_No, "<<loLoc.Loc_No - Loc_No>> panels closer to Downtown", ;
      "<<Loc_No - loLoc.Loc_No>> spaces closer to North Shore")

    lcRet = "closest landmark: *" + Loc_Comments + "*, which is " + textmerge(m.lcRel) 
    return m.lcRet
  endfunc 
enddefine && AisLocater 

*** ========================================================= ***
define class aisLocPage as aisPage 
  cLoc = ""
  oLoc = null
  lLocRequired = .t.
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    if this.lLocRequired
      this.cLoc = evl(this.cLoc, this.StripUrl("loc", .f., .t.))
      if empty(this.cLoc)  && Item required, but not found in URL.
        this.NotFound()
      else 
        this.VerifyLocation()
        if !isnull(this.oLoc)
          * derived parent properties set here
        endif
      endif 
    endif 
    dodefault()  && required bubble-up
    return    
  endfunc  
  * --------------------------------------------------------- *
  function VerifyLocation(tcKey)
    local loData
    lcKey = evl(m.tcKey, this.cLoc)
    loData = createobject("AisLocData")
    if loData.FindRecord(m.lcKey)
      if m.lcKey = this.cLoc
        this.oLoc = loData.GetRecord()
      endif 
    else 
      this.NotFound()
    endif 
    return  
  endfunc   
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    local lcMenu
    lcMenu = "main\This"
    with this
      .AddSubMenu("This", "BRIDGE LOCATIONS")
      .addMenuItem(m.lcMenu, 'Special Size Locations', StuffUrl(this.cUrlA, 2, "LocList", "special", "1"))
      .addMenuItem(m.lcMenu, 'Trapezoids', StuffUrl(this.cUrlA, 2, "LocList", "trapezoid", "1"))
      .addMenuItem(m.lcMenu, 'Down-River Locations', StuffUrl(this.cUrlA, 2, "LocList", "side", "Down"))
      .addMenuItem(m.lcMenu, 'Up-River Locations', StuffUrl(this.cUrlA, 2, "LocList", "side", "Up"))
      .addMenuItem(m.lcMenu, 'All Bridge Locations', StuffUrl(.cUrlA, 2, "LocList"))
      if poContext.lDeveloper
        .addMenuItem(m.lcMenu, "Edit Location Metadata...", StuffUrl(.cUrlB, 2, "LocBrowse"))
      endif
      .addMenuItem(m.lcMenu, 'Panel Requirements', StuffUrl(.cUrlA, 2, "LocSumList"))
      .addMenuItem(m.lcMenu, 'Picture Panels on Bridge!', StuffUrl(.cUrlA, 2, "LocDisplay"))
    endwith 
    dodefault()
    return 
  endfunc 
enddefine && AisLocPage

*** ========================================================= ***
define class ais_InstalledPanels as aisPage 
  nMinLoginLevel = L7_NONE  
  lPage_Cacheable = .t.
  * --------------------------------------------------------- *
  function beforeProcessRequest
    local loState
    loState = Environ.item("page.processState") 
    addproperty(m.loState, "output", "")
    addproperty(m.loState, 'cache_hit', .f.)
    if this.lPage_Cacheable
      addproperty(m.loState, 'refresh_cache', this.readQueryString('refresh', .t., .t.) = "1")
    endif 
    dodefault()
    return 
  endfunc && before..
  * --------------------------------------------------------- *
  function page_checkCache(loState)
    local loObj, loMgr
    addproperty(m.loState, 'cache_time', 60 * 30) && 30 min--change this to customized...
    addproperty(m.loState, 'cache_id', null)
    loObj = createobject('empty')
    addproperty(m.loObj, "class_name", this.class) && use as part of key
    addproperty(m.loObj, "response_type", this.cResponseType) 
    addproperty(m.loObj, "version", 4) && increment w/ design change to force cache clear
    * ... more distinguishing props here if needed (e.g., QS param vals)
    loState.cache_id = L7JsonSerialize(m.loObj)
    if !loState.refresh_cache
      loMgr = goL7App.helpers.item("CacheManager")
      loState.output = loMgr.GetCachedString(loState.cache_id, loState.cache_time)
      loState.cache_hit = !empty(m.loState.output)
    endif
    return 
  endfunc 
  * --------------------------------------------------------- *
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp, loPnl, loOut, loState
    loState = Environ.item("page.processState") 
    
    if this.lPage_Cacheable 
      this.page_checkCache(m.loState)
    endif
    if !loState.cache_hit

      this.app_runPiecePanelArtistQuery()
      loQry = createobject("AisPlcQuery")
      with loQry
        .AddOrderBy("Loc_Side",, .f.)
        .AddOrderBy("Loc_No",, .t.)
        .AddOrderBy("Plc_Orientation",, .t.)

        .lJoinPanel = .t.
        .lJoinLocation = .t.

        .ClearFields()
        .AddFields("Loc_Side, Loc_No, left(Loc_Side, 1) + padr(transform(Loc_No),3) as Loc_ID, Plc_Orientation as Orientation, Pnl_Id, Pnl_PK")
        .BuildFieldList() && prevents more columns being added
        .execute()
      endwith 
    
      select (loQry.cAlias)
      if this.cResponseType = "json"
        loOut = createobject("Empty")
        addproperty(loOut, "generate_time", datetime())
        addproperty(loOut, "installed_panel_set", createobject("JsonArray"))
        scan
          scatter memo name loPnl
          * addproperty(m.loPnl, "artist_set", AisGetPanelArtists(loPnl.Pnl_PK))
          addproperty(m.loPnl, "artist_set", this.app_GetPanelArtists(loPnl.Pnl_PK))
          loOut.installed_panel_set.add(m.loPnl)
        endscan
        loState.output = L7JsonSerialize(m.loOut) && serialize now, so it can also be cached
      else
        loState.output = L7Table()
      endif
    endif   

    if this.cResponseType = "json"
      this.oJsonContents = loState.Output
    else
      response.write(loState.Output)
    endif

    if m.loState.cache_hit
      goL7App.app_log(L7_SEVERITY_DEBUG, "Hit serviced from cache")
    else
      if this.lPage_Cacheable
        goL7App.helpers.item("CacheManager").SetCachedString(loState.Output, loState.Cache_ID, loState.Cache_Time)
        goL7App.app_log(L7_SEVERITY_DEBUG, "Output cached")
      endif
    endif  
    return 
  endfunc 
enddefine && ais_InstalledPanels 

*** ========================================================= ***
define class ais_Tour as aisPage 
  nMinLoginLevel = L7_NONE  
  lPage_Cacheable = .t.
  cSubTitle = "Panel Walking Tour"
  cPage_Side = null
  cPage_Orient = null
  cPage_Dir = null
  * ----------------------------------------------------- *  
  function BeforeProcessRequest
    local loState
    loState = Environ.item("page.processState") 
    this.cPage_Side   = this.readQueryString("side",   .t., .t.)
    this.cPage_Orient = this.readQueryString("orient", .t., .t.)
    this.cPage_Dir    = this.readQueryString("dir",    .t., .t.)
    addproperty(m.loState, 'cache_hit', .f.)
    addproperty(m.loState, 'segment_output', '')
    if this.lPage_Cacheable
      addproperty(m.loState, 'refresh_cache', this.readQueryString('refresh', .t., .t.) = "1")
    endif 
    dodefault()
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loState, lcSeg
    loState = Environ.item("page.processState") 
    addproperty(loState, 'page_config', this.page_getConfig())
    if !empty(this.cPage_Dir)
      if !this.page_validateOptions(loState)
        this.badRequest("invalid option")
        return
      endif 
      this.cSubTitle = this.cSubTitle + ": " + this.page_getOptionDescription(m.loState)
      this.page_loadSegment(m.loState)
      response.write(m.loState.segment_output)
    endif
    response.write(this.page_getSegmentOptions(m.loState))
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_loadSegment(loState)
    
    local lcItem, lcRet, loLocQry, loPlcQry, loLoc, loPlc, loArts, lnArt, loArt, lcArt, lcLoc, lcImg, lcPnlUrl

    if this.lPage_Cacheable 
      this.page_checkSegmentCache(m.loState)
    endif
    if !m.loState.cache_hit
      this.app_runPiecePanelArtistQuery()

      lcRet = ""
      lcPnlUrl = StuffUrl(this.cUrlA, 2, "LocateByPanelId")
      lcRet = m.lcRet + '<div class="clear"></div>' + crlf && prep for floats 

      loLocQry = createobject("AisLocQuery")
      with loLocQry
        .cSide = this.cPage_Side
        .addOrderBy('Loc_No', this.cPage_Dir = "back")
        .execute()
      endwith

      * Secondary query of Panel Assignments: 
      loPlcQry = createobject("AisPlcQuery")
      with loPlcQry
        .cAlias = "PlcQuery_"
        .lJoinPanel = .t.
        .lJoinLocation = .t.
        .execute()
      endwith 

      select (loLocQry.cAlias)
      scan
        scatter memo name loLoc
        lcLoc = textmerge([<<left(loLoc.Loc_Side, 1)>>-<<loLoc.Loc_No>>])
        
        select (loPlcQry.cAlias)
        locate for Plc_Loc_FK = m.loLoc.Loc_PK and Plc_Orientation = this.cPage_Orient
        if found()
          scatter memo name loPlc
          lcImg = AisPanelImage(loPlc.Pnl_Id, "_h50")
          
          loArts = this.app_GetPanelArtists(loPlc.Plc_Pnl_FK)
          lcArt = ""
          for lnArt = 1 to loArts.count
            loArt = loArts.item[m.lnArt]
            lcArt = lcArt + ", " + trim(loArt.name) + iif(loArt.count = 1, [], [ (] + transform(loArt.count) + [)])
          next
          lcArt = HtWrap(m.lcLoc, "strong") + ". Panel " + ;
            HtLink(stuffUrl(m.lcPnlUrl, "pnl_id", loPlc.Pnl_Id), loPlc.Pnl_Id) + " by " + substr(m.lcArt, len(", ") + 1)
          lcItem = HtWrap(m.lcImg, 'div',,'tour-image') + HtWrap(m.lcArt, 'p', , 'tour-info')
        else  
          lcItem = htWrap(m.lcLoc, 'p')
          lcArt = ""
        endif 
        lcRet = m.lcRet + htWrap(m.lcItem, 'div', , 'tour-panel') + crlf 
      endscan
      lcRet = m.lcRet + '<div class="clear"></div>' + crlf && prep for floats 
      loState.Segment_Output = m.lcRet
    endif 

    if m.loState.cache_hit
      goL7App.app_log(L7_SEVERITY_DEBUG, "Hit serviced from cache")
    else
      if this.lPage_Cacheable
        goL7App.helpers.item("CacheManager").SetCachedString(loState.Segment_Output, loState.Cache_ID, loState.Cache_Time)
        goL7App.app_log(L7_SEVERITY_DEBUG, "Output cached")
      endif
    endif  
    
    return 
  endfunc && page_showSegment
  * ----------------------------------------------------- *  
  function page_getSegmentOptions(loState)
    local lcRet, lcTemp, loConfig, loDir, lnDir, loSeg, lnSeg, lcUrl
    loConfig = loState.page_config
    lcRet = ""
    lcRet = m.lcRet + HTWrap("Choose Your Next Crossing", 'h2')
    for lnDir = 1 to loConfig.direction_set.count
      loDir = loConfig.direction_set.item[m.lnDir]
      lcRet = m.lcRet + HTWrap(loDir.desc, 'h3')

      lcTemp = ""
      lcUrl = stuffUrl(this.cUrlB, "dir", loDir.direction)
      for lnSeg = 1 to loConfig.segment_set.count
        loSeg = loConfig.segment_set.item[m.lnSeg]
        lcTemp = m.lcTemp + HTWrap(;
          HTLink(StuffUrl(m.lcUrl, "orient", loSeg.orientation, "side", loSeg.side), loSeg.desc), ;
          'li')        
      next 
      lcRet = m.lcRet + HtWrap(m.lcTemp, 'ol')
    next
    
    return m.lcRet
  endfunc && page_getSegmentOptions
  * --------------------------------------------------------- *
  function page_checkSegmentCache(loState)
    local loObj, loMgr
    addproperty(m.loState, 'cache_time', 60 * 30) && 30 min--change this to customized...
    addproperty(m.loState, 'cache_id', null)
    loObj = createobject('empty')
    addproperty(m.loObj, "class_name", this.class) && use as part of key
    addproperty(m.loObj, "side", this.cPage_Side) 
    addproperty(m.loObj, "orient", this.cPage_Orient) 
    addproperty(m.loObj, "dir", this.cPage_Dir) 
    addproperty(m.loObj, "version", 8) && increment w/ design change to force cache clear
    addproperty(m.loObj, "response_type", this.cResponseType) 
    
    loState.cache_id = L7JsonSerialize(m.loObj)
    if !loState.refresh_cache
      loMgr = goL7App.helpers.item("CacheManager")
      loState.segment_output = loMgr.GetCachedString(loState.cache_id, loState.cache_time)
      loState.cache_hit = !empty(m.loState.segment_output)
    endif
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_validateOptions(loState)
    return inlist(lower(this.cPage_Side), "down", "up") ;
      and inlist(lower(this.cPage_Orient), "outer", "inner") ;
      and inlist(lower(this.cPage_Dir), "out", "back")
  endfunc 
  * ----------------------------------------------------- *  
  function page_getOptionDescription(m.loState)
    return proper(this.cPage_Side) + "-River" + ;
      ", " + proper(this.cPage_Orient) + " Panels" + ; 
      ", " + iif(lower(this.cPage_Dir) = "out", "from Downtown to North Side", "from North Side to Downtown")
  endfunc 
  * ----------------------------------------------------- *  
  function page_getConfig()
    local lcConf, loRet
    text to lcConf noshow pretext 7
      {
        "direction_set":
        [
          {"direction": "out", "desc": "Crossing from Downtown to North Side"},
          {"direction": "back", "desc": "Crossing from North Side to Downtown"}
        ],
        "segment_set": 
        [
          {"side": "Down", "orientation": "Outer", "desc": "Clemente (6th Street) Bridge"},
          {"side": "Down", "orientation": "Inner", "desc": "Warhol (7th Street) Bridge, Down-River Side"},
          {"side": "Up", "orientation": "Inner", "desc": "Warhol (7th Street) Bridge, Up-River Side"},
          {"side": "Up", "orientation": "Outer", "desc": "Rachel Carson (9th Street) Bridge"}
        ]
      }
    endtext 
    loRet = L7JsonParse(m.lcConf) 
    return m.loRet
  endfunc 
enddefine

*** ========================================================= ***
define class ais_LocDisplay as aisLocPage 
  lLocRequired = .f.
  cSubTitle = "Panels Displayed by Locations"
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loLocQry, loPlcQry, loHandler
       
    loHandler = createobject("aisLocDisplayHandler")
    bindevent(this, "page_onLocation", m.loHandler, "onLocation", 2)
    bindevent(this, "page_onPanelLocation", m.loHandler, "onPanelLocation", 2)
    
    * Secondary query of Panel Assignments: 
    loPlcQry = createobject("AisPlcQuery")
    with loPlcQry
      .cAlias = "PlcQuery_"
      .lJoinPanel = .t.
      .lJoinLocation = .t.
      .execute()
    endwith 

    * Main Location query:
    loLocQry = createobject("AisLocQuery")
    with loLocQry
      .execute()
    endwith 
    
    select (loLocQry.cAlias)
    scan
      scatter memo name loLoc
      raiseevent(this, "page_onLocation", m.loLoc)
      
      select (loPlcQry.cAlias)
      scan for Plc_Loc_FK = m.loLoc.Loc_PK
        scatter memo name loPlc
        raiseevent(this, "page_onPanelLocation", m.loLoc, m.loPlc)
      endscan
    endscan
    response.write(this.page_getDisplay(loHandler))
    unbindevents(m.loHandler)
    loHandler = null 
    return 
  endfunc 

  * ----------------------------------------------------- *  
  function page_getDisplay(loHandler)
    local llVert, lcRet, lnCols, loCatQ, lnSide, loColl, lcSide, laCells[1], lnItem, loLoc, lnOrient, lcOrient, lnCol, lcUrl, loPlc, lcCell, lcOut, lcRow 
    llVert = .t. 
    store "" to lcRet
    lnCols = 5
    loCatQ = createobject("AisPnlQuery")
    with loCatQ
      .lDistinct = .t.
      .ClearFields()
      .AddFields("Pnl_Design_Category")
      .AddOrderBy("Pnl_Design_Category")
      .execute()
    endwith
    
    urls.add(StuffUrl(this.cUrlA, 2, "LocUnassign"), "LocUnassign") && see aisPnl 
    urls.add(StuffUrl(this.cUrlA, 2, "LocAssign"), "LocAssign")
    urls.add(StuffUrl(this.cUrlA, 2, "PnlHome"), "PnlHome")

    for lnSide = 1 to 2  && separate table for each side of bridge (asymetrical)
      lcSide = iif(m.lnSide = 1, "Down", "Up")
      loColl = loHandler.&lcSide
      dimension laCells[loColl.count, m.lnCols]
      laCells = ""
      for lnItem = 1 to loColl.count
        loLoc = m.loColl.item(m.lnItem)

        * Middle column showing Location info:
        laCells[m.lnItem, 3] = textmerge('<td class="loc-id"><div style="min-height: <<int(loLoc.Loc_W1)>>px;">' + ;
          '<span class="id-field location"><<left(loLoc.Loc_Side, 1)>><<padl(transform(loLoc.Loc_No), 3, "0")>></span>' + ;
          '<br>(<<int(loLoc.Loc_H1)>>x<<int(loLoc.Loc_W1)>><<iif(loLoc.Loc_H2 = 0,"", "x" + transform(loLoc.Loc_H2))>>)' + ;
          '<<iif(empty(loLoc.Loc_Marker), "", "<br>" + trim(m.loLoc.Loc_Marker))>>' + ;
          '<<iif(empty(loLoc.Loc_Comments), "", "<br>" + m.loLoc.Loc_Comments)>>' + ;
          '</div></td>') + crlf
          
        for lnOrient = 1 to 2 && iterate between Inner/Outer orientations, creating left 2 and right 2 columns: 
          lcOrient = iif(m.lnOrient = 1, "Outer", "Inner")
          loPlc = loLoc.&lcOrient
          
          * Show IMAGE if there's a Panel:
          lnCol = iif(m.lcSide = "Down", iif(m.lcOrient = "Outer", 2, 4), iif(m.lcOrient = "Outer", 4, 2))
          * (trick to make sides of bridge flipped, so Outer is left for Down and Right for Up)
          if isnull(m.loPlc) && no Panel here
            lcCell = '<td class="loc-pnl"><div class="loc-img">' + ;
              iif(m.loLoc.Loc_Skip, '<span class="skipped">Skipped (Unusable Space)</span>', '') + ;
              '</div></td>' + crlf
          else 
            lcCell = '<td class="loc-pnl">' + ;
              '<div id="' + loPlc.Plc_Pnl_FK + '" class="loc-img">' + AisPanelImage(loPlc.Pnl_Id, "_h50r") + ;
              '</div></td>' + crlf 
          endif
          laCells[m.lnItem, m.lnCol] = m.lcCell

          * Show PANEL INFO or links to ASSIGN a panel:
          lnCol = iif(m.lcSide = "Down", iif(m.lcOrient = "Outer", 1, 5), iif(m.lcOrient = "Outer", 5, 1))
          if isnull(m.loPlc)  && no panel 
            if m.loLoc.Loc_Skip
              lcCell = '<td class="loc-link"></td>' + crlf 
            else
              lcUrl = StuffUrl(urls.item("LocAssign"), "loc", loLoc.Loc_PK, "orient", m.lcOrient)
              lcCell = '<td class="loc-link">' + crlf
              lcCell = m.lcCell + HTLink(m.lcUrl, "any...")
              if !(loLoc.Loc_H1 = 36 and loLoc.Loc_W1 = 75 and loLoc.Loc_H2 = 0)
                lcCell = m.lcCell + L7BR + HTLink(StuffUrl(m.lcUrl, "special", .t.), "special...")
              endif
*!*                select (loCatQ.cAlias)
*!*                scan for !empty(Pnl_Design_Category)
*!*                  lcCell = m.lcCell + L7BR + HTLink(StuffUrl(m.lcUrl, "categ", trim(Pnl_Design_Category)), trim(Pnl_Design_Category) + "...")
*!*                endscan 
              lcCell = m.lcCell + '</td>' + crlf 
            endif 
          else
            lcCell = '<td class="loc-link' + iif(loPlc.Pnl_Excluded, ' excluded', iif(loPlc.Pnl_Completed, '', ' incomplete')) + '">' + ;
              iif(loPlc.Pnl_Excluded, '<span class="excluded">EXCLUDED</span><br>', '') + ;
              '<span class="id-field panel">' + HtLink(stuffUrl(urls.item("PnlHome"), "pnl", loPlc.Pnl_Id), AisFormatID(loPlc.Pnl_Id)) + '</span>' + ;
              '<br>(' + trim(loPlc.Pnl_Dim_1) + 'x' + trim(loPlc.Pnl_Dim_2) + ', ' + trim(loPlc.Pnl_Design_Category) + ')' + ;
              L7BR + HTLink(StuffUrl(urls.item("LocUnassign"), "plc", loPlc.Plc_PK), "Remove...", "Detach panel from location") + ;
              '</td>' + crlf 
          endif
          laCells[m.lnItem, m.lnCol] = m.lcCell
        next && orient
      next && loLoc

      lcOut = ""
      ** lcOut = m.lcOut + '<div class="clear"></div>' + crlf && prep for floats 
      
      lcOut = m.lcOut + textmerge('<div class="loc-display" id="side-<<m.lcSide>>"><table><tbody>') + CRLF
      lcOut = m.lcOut + textmerge('<tr><th colspan="<<m.lnCols>>"><<upper(m.lcSide)>>-RIVER, NORTH SIDE</th></tr>') + crlf
      for lnRow = loColl.count to 1 step -1 && backward to show North Side at top 
        lcRow = '<tr>' + crlf
        for lnCol = 1 to m.lnCols
          lcRow = m.lcRow + laCells[m.lnRow, m.lnCol]
        next  && col
        lcRow = m.lcRow + '</tr>' + crlf
        lcOut = m.lcOut + m.lcRow + CRLF
      next && row
      lcOut = m.lcOut + textmerge('<tr><th colspan="<<m.lnCols>>"><<upper(m.lcSide)>>-RIVER, DOWNTOWN PITTSBURGH</th></tr>') + crlf
      lcOut = m.lcOut + '</tbody></table></div>' + CRLF
      lcRet = m.lcRet + HtWrap(m.lcSide + "-River Side of Bridge", 'div,strong') + m.lcOut
    next && side
    return m.lcRet
  endfunc 
  * ----------------------------------------------------- *  
  function page_onLocation(loLoc)
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function page_onPanelLocation(loLoc, loPlc)
    return 
  endfunc 
  * ----------------------------------------------------- *  
enddefine  && ais_LocDisplay 

*** ========================================================= ***
define class aisLocDisplayHandler as custom
  add object Up as collection
  add object Down as collection
  * ----------------------------------------------------- *  
  function onLocation(loLoc)
    local loColl
    addproperty(m.loLoc, "Inner", null)
    addproperty(m.loLoc, "Outer", null)
    loColl = iif(loLoc.Loc_Side = "Up", this.Up, this.Down)
    loColl.add(m.loLoc, m.loLoc.Loc_PK)
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function onPanelLocation(loLoc, loPlc)
    * parent guaranteed to exist
    local lcProp
    lcProp = trim(loPlc.Plc_Orientation) && Inner/Outer
    loLoc.&lcProp = m.loPlc
    return 
  endfunc 
  * ----------------------------------------------------- *  
enddefine && aisLocDisplayHandler 

*** ========================================================= ***
define class ais_LocList as aisLocPage 
  lLocRequired = .f.
  cSubTitle = "Bridge Locations"
  cPage_Side = ""
  lPage_Trapezoid = null
  lPage_Special = null 
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    local lcStr
    lcStr = this.readQueryString("special", .t., .t.)
    this.lPage_Special = iif(empty(m.lcStr), null, m.lcStr $ "1yYtT")
    lcStr = this.readQueryString("trapezoid", .t., .t.)
    this.lPage_Trapezoid = iif(empty(m.lcStr), null, m.lcStr $ "1yYtT")
    this.cPage_Side = this.readQueryString("side", .t., .t.)
    dodefault()
    return 
  endfunc   
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loLocQry, loPlcQry, loTbl, loCol, loGrp, lnOrient, lcOrient
       
    * Secondary query of Panel Assignments: 
    loPlcQry = createobject("AisPlcQuery")
    with loPlcQry
      .cAlias = "PlcQuery_"
      .lJoinPanel = .t.
      .lJoinLocation = .t.
      .execute()
      index on Plc_Loc_FK + Plc_Orientation tag LocOrient 
    endwith 

    * Main Location query:
    loLocQry = createobject("AisLocQuery")
    with loLocQry
      .lTrapezoid = this.lPage_Trapezoid
      .lSpecial = this.lPage_Special 
      .execute()
    endwith 
    
    urls.add(StuffUrl(this.cUrlA, 2, "PnlHome"), "PnlHome")
    urls.add(StuffUrl(this.cUrlA, 2, "LocAssign", "side", this.cPage_Side), "LocAssign")

    loTbl = createobject("AisTable")
    with loTbl
      loCol = .addCursorColumn("Loc_No", "Side-No", [HtWrap(left(Loc_Side,1) + padl(transform(Loc_No), 3, "0"), 'span', , 'id-field location')] )
      
      loCol = .addCursorColumn("Loc_H1", "Height-L")
      loCol = .addCursorColumn("Loc_W1", "Width")
      loCol = .addCursorColumn("Loc_H2", "Height-R")
      for lnOrient = 1 to 2
        lcOrient = iif(m.lnOrient = 1, "Inner", "Outer")
        loCol = .addCursorColumn("Loc_PK", m.lcOrient + "<br>Panel", ;
          [iif(Loc_Skip, "skip", (] + ;
            [iif(seek(Loc_PK + "] + m.lcOrient + [", "PlcQuery_"),] + ;
              [ HTLink(StuffUrl(Urls.item("PnlHome"), "pnl", PlcQuery_.Plc_Pnl_FK), AisFormatID(PlcQuery_.Pnl_ID), 'title="go to panel" id="' + PlcQuery_.Plc_Pnl_FK + '"', "id-field panel" + iif(PlcQuery_.Pnl_Excluded, " excluded", ""))] + [, ] + ;
              [ HTLink(StuffUrl(Urls.item("LocAssign"), "loc", Loc_PK, "orient", "] + m.lcOrient + ["), "unassigned", "assign panel...")] + ;
            [)))])

        loCol = .addCursorColumn("Loc_PK", m.lcOrient + "<br>Panel", ;
          [iif(Loc_Skip, "", (] + ;
            [iif(seek(Loc_PK + "] + m.lcOrient + [", "PlcQuery_"),] + ;
              [ HTLink(StuffUrl(Urls.item("PnlHome"), "pnl", PlcQuery_.Plc_Pnl_FK), AisPanelImage(PlcQuery_.Pnl_ID, "_h25"))] + [, ] + ;
              [""] + ;
            [)))])

      next 

      loCol = .addCursorColumn("Loc_Marker", "Marker")
      loCol = .addCursorColumn("Loc_Notes", "Description", [L7ParseOnView(Loc_Comments)])
      loCol = .addCursorColumn("Loc_Notes", "Notes", [L7ParseOnView(Loc_Notes)])
      
      * repeat for convenience: 
      loCol = .addCursorColumn("Loc_No", "Side-No", [HtWrap(left(Loc_Side,1) + padl(transform(Loc_No), 3, "0"), 'span', , 'id-field location')] )

      if empty(this.cPage_Side) or "Down" $ this.cPage_Side
        .cFilter = [Loc_Side = "Down"]
        .cTableCaption = "Down-River Side (toward 6th St and The Point)"
        response.write(.render())
        .Reset()
      endif
      if empty(this.cPage_Side) or "Up" $ this.cPage_Side
        .cFilter = [Loc_Side = "Up  "]
        .cTableCaption = "Up-River Side (toward 9th St and The Strip)"
        response.write(.render())
        .Reset()
      endif
    endwith 
    
    return 
  endfunc 
enddefine && LocList

*** ========================================================= ***
define class ais_LocSumList as aisLocPage 
  lLocRequired = .f.
  cSubTitle = "Panel Summary Quantities"
  * ----------------------------------------------------- *  
  function AddDefaultMenu
    with this
      .AddSubMenu("This", "BRIDGE LOCATIONS")
    endwith 
    dodefault()
    return 
  endfunc 
  * ----------------------------------------------------- *  
  function ProcessRequest
    local loQry, loTbl, loCol, loGrp
       
    loQry = createobject("AisLocQuery")
    with loQry
      .lSkip = .f. && don't count spaces we're skipping 
      
      .lOldEngineBehavior = .t. 
      .AddOrderBy("Loc_W1",, .f.)
      .AddOrderBy("Loc_H1",, .t.)
      .AddOrderBy("Loc_H2",, .t.)
      .nGrouping = 3
      .ClearFields()
      
      .AddFields("Loc_H1, Loc_W1, Loc_H2, count(*) as Count_")
      
      .execute()
    endwith 
    
    loTbl = createobject("AisTable")
    with loTbl
      .cTableCaption = this.cSubTitle 
      .cGrandRowClass      = "GrandRow sortbottom"  
      
      loCol = .AddColumn(L7_ELEMENTTYPE_RELATIVE_RECNO, "Seq")

      loCol = .addCursorColumn("Loc_H1", "Height-L")
      loCol = .addCursorColumn("Loc_W1", "Width")

      loCol = .addCursorColumn("Loc_H2", "Height-R")
      * loCol.cHeadingClass = "nosort" 

      loCol = .addCursorColumn("Count_", "Location<br>Count")
      loCol.nCalcType = L7_CALCTYPE_SUM
      
      loCol = .addCursorColumn("2*Count_", "Panels<br>Needed", [2*Count_])
      loCol.nCalcType = L7_CALCTYPE_SUM
      
      response.write(.render())
    endwith 
    
    return 
  endfunc 
enddefine && LocSumList

*!*  *** ========================================================= ***
*!*  define class ais_LocUnassign as aisLocPage 
*!*    lLocRequired = .f.
*!*    cPlc = null
*!*    * --------------------------------------------------------- *
*!*    function BeforeProcessRequest
*!*      this.cPlc = this.readQueryString("plc", .t., .t.)
*!*      dodefault()
*!*      return 
*!*    endfunc   
*!*    * ----------------------------------------------------- *  
*!*    function ProcessRequest
*!*      this.Assert(poContext.lAdmin)
*!*      local vp_cPlc_PK, lcXml
*!*      vp_cPlc_PK = this.cPlc
*!*      use V_PanelLocation in select("V_PanelLocation")
*!*      cursorsetprop("Buffering", 5, "V_PanelLocation")
*!*      select V_PanelLocation
*!*      this.Assert(!eof(), "PLC not found")
*!*      this.cCancelUrl = stuffUrl(this.cUrlA, 2, "LocDisplay")
*!*      this.Assert(!Plc_Inactive, "PLC already removed")
*!*      
*!*      replace Plc_Inactive with .t.
*!*      StampRec( CurrentUser, THIS.tNow )
*!*      
*!*      lcXml = ''
*!*      this.AssertTransaction("V_PanelLocation", @lcXml)
*!*      this.confirm(textmerge('Link from Panel to Location removed'), this.cCancelUrl)
*!*      return
*!*    endfunc
*!*  enddefine  && ais_LocUnassign 
    
*** ========================================================= ***
define class ais_LocAssign as aisLocPage 
  cPage_Orient = null 
  cPage_Side = null
  cPage_Special = null
  cPage_Categ = null
  cPage_PnlSel = null 
  * --------------------------------------------------------- *
  function BeforeProcessRequest
    this.cPage_Orient = this.readQueryString("orient", .t., .t.)
    this.cPage_Side = this.readQueryString("side", .t., .t.)
    this.cPage_Categ = this.readQueryString("categ", .t., .t.)
    this.cPage_Special = this.readQueryString("special", .t., .t.)
    this.cPage_PnlSel = this.readQueryString("pnlsel", .t., .t.) && selected panel
    dodefault()
    return 
  endfunc   
  * ----------------------------------------------------- *  
  function ProcessRequest
    this.cCancelUrl = iif(empty(this.cPage_Side), StuffUrl(this.cUrlA, 2, "LocDisplay"), ;
      StuffURL(this.cUrlB, 2, "LocList", "side", this.cPage_Side))
    this.Assert(poContext.lAdmin)
    this.assert(inlist(this.cPage_Orient, "Outer", "Inner"), "invalid orientation")

    this.cSubTitle = textmerge([Set Panel Location for <<this.oLoc.Loc_Side>>-<<this.oLoc.Loc_No>> (<<this.cPage_Orient>>)])
    local vp_cPlc_PK, loQ, lcXml

    * Query available panels:
    loQ = createobject("AisPnlQuery") 
    with loQ
      .cAlias = "Available_Panels_"
      .lHasLocation = .f.
      if !empty(this.cPage_Categ)
        .cDesign_Category = this.cPage_Categ
      endif
      if !empty(this.cPage_Special)
        .lSpecialSize = left(this.cPage_Special, 1) $ 'yYtT1'
      endif
      .Execute()
    endwith 
    this.assert(loQ.nTally > 0, "No available panels remain.")
    
    if empty(this.cPage_PnlSel) && panel not selected
      Response.Write(HTWrap(;
        "Select Panel for Location " + left(Page.oLoc.Loc_Side,1) + padl(transform(Page.oLoc.Loc_No), 3, "0") + "-" + Page.cPage_Orient, ;
        "p"))
      Response.Write(this.page_SelectPanel(m.loQ))
      Response.Write(HTWrap(HTLink(this.cCancelUrl, "Cancel Panel Selection"), "p"))
      return
    endif 
    
    select (loQ.cAlias)
    locate for Pnl_PK == this.cPage_PnlSel
    this.assert(found(), "Invalid panel selection, or panel no longer unassigned.")

    vp_cPlc_PK = space(32)
    use V_PanelLocation in select("V_PanelLocation")
    cursorsetprop("Buffering", 5, "V_PanelLocation")
    select V_PanelLocation
    append blank
    replace Plc_Loc_FK with this.cLoc ;
      Plc_Orientation with this.cPage_Orient ;
      Plc_Pnl_FK with this.cPage_PnlSel
    StampRec( CurrentUser, THIS.tNow )
    lcXml = ''
    this.AssertTransaction("V_PanelLocation", @lcXml)
    Response.Redirect(this.cCancelUrl)
    return 
  endfunc && processRequest
  * --------------------------------------------------------- *
  function page_SelectPanel(loQ)
    local lcTmp, lcItem, lcSel, lcRet, lcClass, lcArt, lcLinks
    lcRet = ""
    lcSel = ""
    text to lcTmp noshow pretext 3
      <span class="panel-data">Choose <<Pnl_ID>> <<iif(Pnl_Completed,'','INCOMPLETE!')>>
       (<<trim(Pnl_Dim_1)>> x <<trim(Pnl_Dim_2)>>, 
       <<trim(Pnl_Design_Category)>>,
       <<iif(Pnl_Single_Piece, "1-piece", "bits")>>)
      </span> 
      <<AisPanelImage(Pnl_Id, "_h50")>>
      
    endtext 
    select (loQ.cAlias)
    scan
      lcClass = iif(Pnl_Excluded, "excluded", iif(Pnl_Completed, "", "incomplete"))
      lcArt = iif(empty(Pnl_Stitcher_Art_FK), "multi-artist", HtWrap(AisArtistName(Pnl_Stitcher_Art_FK), 'strong'))
      lcItem = textmerge(m.lcTmp)
      lcLinks = HTLink(StuffUrl(this.cUrlA, 2, "PnlHome", "pnl", Pnl_PK), "[Panel...]")
      if !empty(Pnl_Stitcher_Art_FK)
        lcLinks = m.lcLinks + " " + HTLink(StuffUrl(this.cUrlA, 2, "ArtHome", "art", Pnl_Stitcher_Art_FK), "[Artist...]")
      endif
      lcSel = m.lcSel + HTWrap( ; 
        HTLink(StuffUrl(this.cUrlC, "pnlsel", Pnl_PK), m.lcItem) + m.lcArt + " " + m.lcLinks, ;
        'div', , m.lcClass)

    endscan
    lcRet = HTWrap(m.lcSel, 'div', , 'panel-select')
    return m.lcRet
  endfunc 
enddefine 

*!*  *** ========================================================= ***
*!*  define class aisLocAssignForm as AisForm
*!*    cTitle = "Assign Panel to Location Form"
*!*    * --------------------------------------------------------- *
*!*    function AddControls
*!*      with this
*!*        .AddObject("lblLoc_Side", "L7Label")
*!*        with .lblLoc_Side
*!*          .cFieldType = "C"
*!*          .cShowExpression = [left(Page.oLoc.Loc_Side,1) + padl(transform(Page.oLoc.Loc_No), 3, "0")]
*!*          .cLabel = "Location"
*!*        endwith 

*!*        .AddObject("lblLoc_Orient", "L7Label")
*!*        with .lblLoc_Orient
*!*          .cFieldType = "C"
*!*          .cShowExpression = [Page.cPage_Orient]
*!*          .cLabel = "Orientation"
*!*        endwith 
*!*        
*!*        .AddObject("lblDimensions", "L7Label")
*!*        with .lblDimensions
*!*          .cFieldType = "C"
*!*          .cShowExpression = [transform(Page.oLoc.Loc_H1) + "x" + transform(Page.oLoc.Loc_W1)]
*!*          if Page.oLoc.Loc_H2 > 0
*!*            .cShowExpression = .cShowExpression + [ + "x" + transform(Page.oLoc.Loc_H2)]
*!*          endif
*!*          .cLabel = "Location Dimensions"
*!*        endwith 

*!*        .AddObject("cboPnl_FK", "L7Popup")
*!*        with .cboPnl_FK
*!*          .cControlSource = "V_PanelLocation.Plc_Pnl_FK"
*!*          .lRequired = .t.
*!*          .cLabel = "Select Panel"
*!*          .lAutoRender = .T.
*!*          .nRowSourceType = L7_ROWSOURCETYPE_ALIAS
*!*          .cRowSource = "Available_Panels_"
*!*          *!* ex: .cFilterExpression = [Fac_Storage = .t.]
*!*          .cValueExpression = [Pnl_PK]
*!*          .cLabelExpression = [Pnl_ID + " (" + trim(Pnl_Dim_1) + "x" + trim(Pnl_Dim_2) + ", " + trim(Pnl_Design_Category) + ")"]
*!*          .vFirstItemValue = space(32) && 0 for integer keys
*!*          .cFirstItemLabel = "[ select from choices below ]"
*!*          .SetValue(page.cPage_PnlSel)
*!*        endwith 
*!*      endwith
*!*      return 
*!*    endfunc 
*!*  enddefine 

*** ===================================================== ***
define class Ais_LocBrowse as AisLocPage
  lLocRequired = .f.
  * --------------------------------------------------------- *
  function ProcessRequest
    this.cCancelUrl = StuffUrl(this.cUrlA, 2, "LocList")
    local loForm, lcXml, lcAlias, lcFldState, lcStub
    lcAlias = "V_All_Locations"
    use (m.lcAlias) in select(m.lcAlias)
    cursorsetprop("Buffering", 5, m.lcAlias)
    select (m.lcAlias)
    loForm = this.CreateForm("AisLocBrowseForm", this.cUrlC)
    with loForm
      .cAlias = m.lcAlias
      .AddControls()
      .DoEvents()
      if .Valid()
        .UpdateControlSources()
        select (m.lcAlias)
        scan   
          lcFldState = getfldstate(-1)
          if empty( strtran( m.lcFldState, "1"))  && no change
            loop 
          endif 
          StampRec( CurrentUser, THIS.tNow )
        endscan 
        lcXml = ''
        this.AssertTransaction(m.lcAlias, @lcXml)
        Response.Redirect(this.cCancelUrl)
        return 
      endif 
      Response.Write(.Render())
    endwith 
    return   
  endfunc 
  
enddefine  && Ais_LocBrowse

*** ========================================================= ***
define class AisLocBrowseForm AS AisForm
  cTitle = "Location Edit Form"
  cAlias = null && client should set 
  cCssStyle = "width: 100%;"
  * --------------------------------------------------------- *
  function AddControls
    with this
      .AddObject('grdBrowse', 'L7Grid')
      with .grdBrowse
        .cChildAlias = this.cAlias
        .cChildKeyExpression = this.cAlias + ".Loc_PK"
        .nExtraRows = 0 && don't permit adds 
        .cGridTableCssClass = "sortable " + .cGridTableCssClass 
        .cColumnHeaderCssClass = "nosort" && sortable doesn't work for live controls, so override on specific labels
      
        .AddObject("lblId", "L7Label")
        with .lblId
          .cFieldType = "C"
          .cControlSource = this.cAlias + ".Loc_Side"
          .cShowExpression = this.cAlias + [.Loc_Side + transform(] + this.cAlias + [.Loc_No)]
          .cLabel = "Side"
          .cColumnHeaderCssClass = "sort" 
        endwith 

        .AddObject("txtH1", "L7Textbox")
        with .txtH1
          .cControlSource = this.cAlias + ".Loc_H1"
          .cFieldType = "N"
          .cLabel = "Height-L"
        endwith

        .AddObject("txtW1", "L7Textbox")
        with .txtW1
          .cControlSource = this.cAlias + ".Loc_W1"
          .cFieldType = "N"
          .cLabel = "Width"
        endwith

        .AddObject("txtH2", "L7Textbox")
        with .txtH2
          .cControlSource = this.cAlias + ".Loc_H2"
          .cFieldType = "N"
          .cLabel = "Height-R"
          .cInstructions = "Leave blank (0) for rectangles!"
        endwith

        .AddObject("txtMarker", "L7Textbox")
        with .txtMarker 
          .cControlSource = this.cAlias + ".Loc_Marker"
          .cLabel = "Marker"
        endwith

        .AddObject("edtComments", "L7Textarea")
        with .edtComments
          .cControlSource = this.cAlias + ".Loc_Comments"
          .cLabel = "Description and Comments"
          .nRows = 2
        endwith

        .AddObject("edtNotes", "L7Textarea")
        with .edtNotes 
          .cControlSource = this.cAlias + ".Loc_Notes"
          .cLabel = "Internal KtB Notes"
          .nRows = 2
          .cCssClass = "FormControlPrivate"
        endwith

        .AddObject("lblId2", "L7Label") && << -- REPEATED FOR CONVENIENCE
        with .lblId2
          .cFieldType = "C"
          .cControlSource = this.cAlias + ".Loc_Side"
          .cShowExpression = this.cAlias + [.Loc_Side + transform(] + this.cAlias + [.Loc_No)]
          .cLabel = "Side"
          .cColumnHeaderCssClass = "sort" 
        endwith 

        .AddObject("chkSkip", "L7Checkbox")
        with .chkSkip
          .cControlSource = this.cAlias + ".Loc_Skip"
          .cLabel = "Skip?"
          .lDisabled = !m.poContext.lAdmin
          .cCaption = "SKIPPED"
          .cCssClass = "FormControlPrivate"
          .cInstructions = "Check locations where panels will NOT be installed."
        endwith

        .AddObject("chkInactive", "L7Checkbox")
        with .chkInactive
          .cControlSource = this.cAlias + ".Loc_Inactive"
          .cLabel = "Delete?"
          .lDisabled = !m.poContext.lDeveloper
          .cCaption = "DELETE"
          .cCssClass = "FormControlPrivate"
        endwith

      endwith && grid 
    endwith && form
    return 
  endfunc  && AddControls
enddefine && LocBrowseForm 

*** ===================================================== ***
define class AisPlcQuery as L7Query
  cBaseTable = "PanelLocation"
  cDefaultFieldList = "Plc_PK, Plc_Pnl_FK, Plc_Loc_FK, Plc_Orientation"

  cSide = null
  cOrient = null 
  lTrapezoid = null
  lSpecial = null 

  lJoinPanel = .f. 
  lJoinLocation = .f. 

  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Plc_Inactive = .F.] 

      if .lJoinLocation or !isnull(.cSide)
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Location"
        .aJoins[.nJoins, 2] = "Plc_Loc_FK = Loc_PK"
        .AddFields("Loc_Side, Loc_No")
      endif 

      if .lJoinPanel
        .nJoins = .nJoins + 1
        dimension .aJoins[.nJoins, 3]
        .aJoins[.nJoins, 1] = "Panel"
        .aJoins[.nJoins, 2] = "Plc_Pnl_FK = Pnl_PK"
        .AddFields("Pnl_ID, Pnl_Stitcher_Art_FK, Pnl_Single_Piece, Pnl_Dim_1, Pnl_Dim_2, Pnl_Design_Category, Pnl_Completed, Pnl_Excluded")
      endif 

      if !isnull(.cSide)
        .cWhereClause = .cWhereClause + [ and Loc_Side = '] + padr(this.cSide, THISAPP_LENGTH_SIDE) + [']
      endif 
      if !isnull(.lTrapezoid)
        .cWhereClause = .cWhereClause + [ and Loc_H2 ] + iif(.lTrapezoid, [> 0], [= 0])
      endif 
      if !isnull(.lSpecial)
        .cWhereClause = .cWhereClause + [ and ] + iif(.lSpecial, [!], []) + ;
          [(Loc_H1 = 36 and Loc_W1 = 75 and Loc_H2 = 0)]
      endif 
      if !isnull(.cOrient)
        .cWhereClause = .cWhereClause + [ Plc_Orientation = '] + padr(.cOrient, THISAPP_LENGTH_ORIENTATION ) + [']
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisPlcQuery

*** ===================================================== ***
define class AisLocQuery as L7Query
  cBaseTable = "Location"
  cDefaultFieldList = ;
    "Loc_PK, Loc_ID, Loc_Side, Loc_No, Loc_Old_ID, Loc_Rev_Art_FK, Loc_Rev_Time" ;
      + ", Loc_H1, Loc_W1, Loc_H2, Loc_Skip, Loc_Marker, Loc_Comments, Loc_Notes"

  lSkip = null 
  cSide = null
  lTrapezoid = null
  lSpecial = null 
    
  cOrient = null 
  lHasPanel = null 
  
  nOrderBy = 2
  dimension aOrderBy[ 2, 2]
  aOrderBy[ 1, 1] = "Loc_Side"
  aOrderBy[ 2, 1] = "Loc_No"
  * --------------------------------------------------------- *
  function BuildWhereClause
    local lcStr

    with this 
      .lWhereBuilt = .t.
      .cWhereClause = [WHERE Loc_Inactive = .F.] 

      if !isnull(.lSkip)
        .cWhereClause = .cWhereClause + [ and Loc_Skip = ] + iif(.lSkip, [.t.], [.f.])
      endif 
      if !isnull(.cSide)
        .cWhereClause = .cWhereClause + [ and Loc_Side = '] + padr(.cSide, THISAPP_LENGTH_SIDE) + [']
      endif 
      if !isnull(.lTrapezoid)
        .cWhereClause = .cWhereClause + [ and Loc_H2 ] + iif(.lTrapezoid, [> 0], [= 0])
      endif 
      if !isnull(.lSpecial)
        .cWhereClause = .cWhereClause + [ and ] + iif(.lSpecial, [!], []) + ;
          [(Loc_H1 = 36 and Loc_W1 = 75 and Loc_H2 = 0)]
      endif 
      if !isnull(.lHasPanel)
        .cWhereClause = .cWhereClause + [ and Loc_PK] + iif(.lHasPanel, [ in ], [ not in ]) + ;
          [(select Plc_Loc_FK from PanelLocation] + ;
            [ where !plc_Inactive] + ;
            iif(isnull(.cOrient), [], [ and Plc_Orientation = '] + padr(.cOrient, THISAPP_LENGTH_ORIENTATION ) + [']) + ;
          [)]
      endif 

    endwith   
    return  
  endfunc   && BuildWhereClause
enddefine  && AisLocQuery

* end: LOC 

