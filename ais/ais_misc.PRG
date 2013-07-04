open database ktbais
set enginebehavior 70
select Art_PK, Art_Last_Name, Art_First_Name, Art_Full_Name ;
    , count(*) as Count_ ;
    , sum(iif(!pce_whole_panel, 1, 0)) as Piece_ ;
    , sum(iif(!pce_whole_panel and !isnull(pnl_pk), 1, 0)) as In_Panel_ ;
    , sum(iif(!pce_whole_panel and !isnull(pnl_pk) and !isnull(plc_pk), 1, 0)) as Pce_on_Bridge_ ;
    , sum(iif(pce_whole_panel, 1, 0)) as Whole_ ;
    , sum(iif(pce_whole_panel and !isnull(pnl_pk) and !isnull(plc_pk), 1, 0)) as Pnl_On_Bridge_ ;
  from Artist ;
    join Piece on Art_PK = Pce_Art_FK ;
    left join panel on Pce_Pnl_FK = Pnl_PK ;
    left join panelLocation on pnl_pk = Plc_Pnl_FK ;    
  where art_inactive = .f. and pce_inactive = .f. ;
  group by 1
    
set enginebehavior 90

    