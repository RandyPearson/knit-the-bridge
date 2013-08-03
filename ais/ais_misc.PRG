
scan
  loArt = createobject('empty')
  addproperty(loArt, 'name', iif(art_release_name, AisArtistName(), 'Anonymous'))
  pnl.artist_set.add(loArt)
endscan


#if .f.
open database ktbais

* cdow(trn_date) as DOW, cmonth(trn_date) as Month, day(trn_date) as Day, trn_start_time as time, 
select trn_date as date, ;
    padr(trim(art_first_name) + " " + trim(art_last_name), 44) as Name, ;
    iif(art_release_name, 'Yes', '   ') as Rel, ; 
    art_email as email, ;
    art_phone as phone, ;
    art_neighborhood as Neighborhood, ;
    art_id ;
  from training join artist on trn_pk = art_installation_trn_fk ;
  where !trn_inactive and !art_inactive and art_help_install ;
  order by trn_date, art_last_name ;
  into cursor Training_Roster_ 

copy to .\Files\Ktb_Training_Roster_r2a.xls type xl5 
#endif 



*!*  set enginebehavior 70
*!*  select Art_PK, Art_Last_Name, Art_First_Name, Art_Full_Name ;
*!*      , count(*) as Count_ ;
*!*      , sum(iif(!pce_whole_panel, 1, 0)) as Piece_ ;
*!*      , sum(iif(!pce_whole_panel and !isnull(pnl_pk), 1, 0)) as In_Panel_ ;
*!*      , sum(iif(!pce_whole_panel and !isnull(pnl_pk) and !isnull(plc_pk), 1, 0)) as Pce_on_Bridge_ ;
*!*      , sum(iif(pce_whole_panel, 1, 0)) as Whole_ ;
*!*      , sum(iif(pce_whole_panel and !isnull(pnl_pk) and !isnull(plc_pk), 1, 0)) as Pnl_On_Bridge_ ;
*!*    from Artist ;
*!*      join Piece on Art_PK = Pce_Art_FK ;
*!*      left join panel on Pce_Pnl_FK = Pnl_PK ;
*!*      left join panelLocation on pnl_pk = Plc_Pnl_FK ;    
*!*    where art_inactive = .f. and pce_inactive = .f. ;
*!*    group by 1
*!*      
*!*  set enginebehavior 90

    