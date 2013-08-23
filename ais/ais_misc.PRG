
open database ktbais

select a1.Art_PK, a1.Art_Last_Name, a1.Art_First_Name, a1.Art_Release_Name, a1.Art_Full_Name, a1.Art_ID, Pce_Id, Pce_Pnl_FK ;
  from Artist a1 ;
  join Piece on a1.Art_PK = Pce_Art_FK ;
  where !A1.Art_Inactive and !Pce_Inactive ;
      and !Pce_Excluded and Pce_Type = "Panels" ;
union ;
select a1.Art_PK, a1.Art_Last_Name, a1.Art_First_Name, a1.Art_Release_Name, a1.Art_Full_Name, a1.Art_ID, Pce_Id, Pce_Pnl_FK  ;
  from Artist a1 ;
    join Artist a2 on a1.Art_Group_Art_FK = a2.Art_PK ;
    join Piece on a2.Art_PK = Pce_Art_FK ;
  where !a1.Art_Inactive and !a2.Art_Inactive and !Pce_Inactive ;
      and !Pce_Excluded and Pce_Type = "Panels" ;
order by 2, 3 ;
into cursor Art_Pce_ 

select Art_Pce_.*, Pnl_PK, Pnl_ID, Plc_Orientation, Loc_Side, Loc_No ;
  from Art_Pce_ ;
    left join Panel on Pce_Pnl_FK = Pnl_PK ;
    left join PanelLocation on Pnl_Pk = Plc_Pnl_FK ;
    left join Location on Plc_Loc_FK = Loc_PK ;
  into cursor Combo_

* browse fields Art_Last_Name, Art_First_Name, Art_Release_Name, Art_Full_Name, Pce_Id, Pnl_Id, Loc_Side, Loc_No, Plc_Orientation

select ;
  Art_Id, iif(Art_Release_Name, "Release", space(7)) as Release, Art_Last_Name as Last, Art_First_Name as First, Art_Full_Name as Alt, ;
  nvl(pnl_Id, "n.i.p.  ") as Panel_Id, ;
  padr(iif(isnull(Plc_Orientation), iif(isnull(Pnl_Id), "", "n.o.b."), left(Loc_Side, 1) + transform(Loc_No) + "-" + Plc_Orientation), 12) as Location ;
  from Combo_ ;
  into cursor Work_On_Bridge_
copy to .\Files\ArtworkOnBridge.xls type xl5 

#if .f.

select cdow(Sft_Date) as Day, Sft_Start_Time as Start, ;
    iif(Art_Waiver_Signed, "Waiver", space(6)) as Waiver, iif(Art_Training_Signed, "Trained", space(7)) as Trained, ;
    padr(trim(Art_Last_Name) + ", " + trim(Art_First_Name), 40) as name,  ;
    space(5) as In, space(5) as Out, ;  
    Ars_Team as Team, Ars_Role as Role, ;
    Art_Email as email, Art_Phone as phone ;
  from Artist A1 ; 
    join ArtistShift on A1.Art_PK = Ars_Art_FK ;
    join Shift on Ars_Sft_FK = Sft_PK ;
  where A1.Art_Inactive = .f. and Ars_Inactive = .f. and Sft_Inactive = .f. ;
    and Sft_Installation ;
  order by Sft_Date, Sft_Start_Time, Art_Last_Name ;
  into cursor Shift_SignIn 
copy to .\Files\SignIn.xls type xl5 

select cdow(Sft_Date) as Day, Sft_Start_Time as Start, ;
    iif(Art_Waiver_Signed, "Waiver", space(6)) as Waiver, iif(Art_Training_Signed, "Trained", space(7)) as Trained, ;
    padr(trim(Art_Last_Name) + ", " + trim(Art_First_Name), 40) as name,  ;
    Ars_Team as Team, Ars_Role as Role, Ars_Job as Job, ;
    Art_Email as email, Art_Phone as phone ;
  from Artist A1 ; 
    join ArtistShift on A1.Art_PK = Ars_Art_FK ;
    join Shift on Ars_Sft_FK = Sft_PK ;
  where A1.Art_Inactive = .f. and Ars_Inactive = .f. and Sft_Inactive = .f. ;
    and Sft_Installation ;
  order by Sft_Date, Sft_Start_Time, Ars_Team, Ars_Role, Ars_Job, Art_Last_Name ;
  into cursor Shift_Manage
copy to .\Files\ShiftManagement.xls type xl5 

return


select iif(Art_Waiver_Signed, "Waiver", space(6)) as Waiver, iif(Art_Training_Signed, "Trained", space(7)) as Trained, padr(trim(Art_Last_Name) + ", " + trim(Art_First_Name), 40) as name, ;
    Art_Email as Email, Art_Phone as Phone, left(Art_Emergency_Contact, 100) as Emergency, left(Art_Neighborhood, 50) as Neighborhood ;
  from Artist ;
  where !Art_Inactive and ;
    (!Art_Waiver_Signed or !Art_Training_Signed) and ;
    Art_PK in (select Ars_Art_FK from ArtistShift where !Ars_Inactive) ;
  order by Art_Last_Name, Art_First_Name ;
  into cursor NoWaiver_ 
copy to .\Files\NoWaiver.xls type xl5 

select iif(Art_Waiver_Signed, "Waiver", space(6)) as Waiver, iif(Art_Training_Signed, "Trained", space(7)) as Trained, padr(trim(Art_Last_Name) + ", " + trim(Art_First_Name), 40) as name, ;
    Art_Email as Email, Art_Phone as Phone, left(Art_Emergency_Contact, 100) as Emergency, left(Art_Neighborhood, 50) as Neighborhood ;
  from Artist ;
  where !Art_Inactive and ( ;
    !empty(Art_Installation_Trn_FK) or ;
    Art_Waiver_Signed or ;
    Art_Training_Signed or ;
    Art_PK in (select Ars_Art_FK from ArtistShift where !Ars_Inactive) ;
    ) ;
  order by Art_Last_Name, Art_First_Name ;
  into cursor Emergency_ 
copy to .\Files\EmergencyContact.xls type xl5 
#endif


*!*  select Ars_Art_FK, count(*) ;
*!*    from ArtistShift join Shift on Ars_Sft_FK = Sft_PK  ;
*!*    where Ars_Inactive = .f. and Sft_Installation ;  && and Ars_Role = "Captain" 
*!*    group by 1 ;
*!*    having count(*) >= 2 ;
*!*    into cursor _Multi_Captain_
*!*          
*!*  select Art_ID, padr(trim(Art_First_Name) + " " + trim(Art_Last_Name), 40), Ars_Role, cdow(Sft_Date), Sft_Start_Time ;
*!*    from Artist A1 ; 
*!*      join ArtistShift on A1.Art_PK = Ars_Art_FK ;
*!*      join Shift on Ars_Sft_FK = Sft_PK ;
*!*    where A1.Art_Inactive = .f. and Ars_Inactive = .f. and Sft_Inactive = .f. ;
*!*      and Sft_Installation ;
*!*      and Ars_Art_FK in ;
*!*      ( select Ars_Art_FK from _Multi_Captain_ ) ;
*!*    order by Art_ID, Sft_Date, Sft_Start_Time

#if .f.
open database ktbais

select ;
    padr(iif(!art_release_name, "Anonymous", evl(art_full_name, trim(art_first_name) + ' ' + iif(art_last_name = 'NLN', '', trim(art_last_name)))), 60) as Name_, ;
    pnl_pk, art_pk ;
  from piece ;
    join panel on pce_pnl_fk = pnl_pk ;
    join artist on pce_art_fk = art_pk ;
  where !pce_inactive and !pnl_inactive and !art_inactive ;
union ;
select ;
    padr(iif(!Art2.art_release_name, "Anonymous", evl(Art2.art_full_name, trim(Art2.art_first_name) + ' ' + iif(art2.art_last_name = 'NLN', '', trim(art2.art_last_name)))), 60) as Name_, ;
    pnl_pk, art2.art_pk ;
  from piece ;
    join panel on pce_pnl_fk = pnl_pk ;
    join artist Art1 on pce_art_fk = art_pk ;
    join artist Art2 on art1.Art_pk = Art2.Art_group_art_fk ;
  where !pce_inactive and !pnl_inactive and !Art1.art_inactive and !Art2.Art_Inactive ;
into cursor temp_

select Name_, count(*) ;
  from Temp_ ;
  where pnl_pk=[BE0B3ED997054C47981C686D78F19848] ;
  group by 1

#endif
  


#if .f.
select art_pk, padr(iif(!art_release_name, "Anonymous", evl(art_full_name, trim(art_first_name) + ' ' + trim(art_last_name))), 60) as Name_, ;
    art_id ;
  from artist ;
  where !Art_Inactive and (Art_Group_Art_FK in (select pce_art_fk from Piece where !pce_inactive and pce_pnl_fk=[BE0B3ED997054C47981C686D78F19848]) ;
    or art_pk in (select pce_art_fk from Piece where !pce_inactive and pce_pnl_fk=[BE0B3ED997054C47981C686D78F19848])) ;
  into cursor Temp_

select Name_, count(*) ;
  from Temp_ ;
  where pnl_pk=[BE0B3ED997054C47981C686D78F19848];
  group by 1

#endif 

*!*  scan
*!*    loArt = createobject('empty')
*!*    addproperty(loArt, 'name', iif(art_release_name, AisArtistName(), 'Anonymous'))
*!*    pnl.artist_set.add(loArt)
*!*  endscan


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

    