
/* MA SUE */
%let wrds = wrds.wharton.upenn.edu 4016;
options comamid=TCP remote=WRDS;
signon username=_prompt_;
options linesize=max nocenter nodate;

libname home "/home/usc/yling/" server=wrds;
rsubmit;
libname home "/home/usc/yling/";

%let estbeg = -182;
%let estend = -7;
%let evtbeg = -6;
%let evtend = 14;

/* import */
proc import out=home.MA datafile= "/home/usc/yling/MA (5mil up) 1979-2011.dta" dbms=stata replace;
run;

*-------------------------------------------------- Target --------------------------------------------------;

rsubmit;
data MA;
	set home.MA;
	format date date9.;
	keep date permno_t permno_a;
run;

/* attaching crsp dse: select common stocks */
proc sql;
	create table MA
	as select distinct a.* 
	from MA as a, crsp.dse as b
	where a.permno_t=b.permno and 1<=b.exchcd<=3 and 10<=b.shrcd<=11;
run;

/* attching crsp dsf */
proc sql;
	create table MA
	as select distinct a.*, b.date-a.date as evtdate, b.date as mvdate, b.ret as ret_t, b.vol as vol_t,
		b.shrout as shrout_t, b.prc/b.cfacpr as p_t
	from MA as a, crsp.dsf as b
	where a.permno_t = b.permno and &estbeg<=b.date-a.date<=&evtend
	group by a.permno_t, a.date
	order by permno_t, date, mvdate;
quit;

/* attching ff_factors */
proc sql;
	create table MA
	as select distinct a.*, b.rf, b.mktrf, b.smb, b.hml, b.umd 
	from MA as a, ff.factors_daily as b
	where a.mvdate=b.date;
quit;

/* run regression on the estimation period to get beta and predict (residuals) on event dates */
data MA;
	set MA;
	retrf_t = ret_t-rf;
	retmkt_t = retrf_t-rf-mktrf;
run;
proc sort data=MA; 
	by permno_t date mvdate;
run;
proc reg noprint data=MA outest=oreg (rename=(_MODEL_=model _RMSE_=vol Intercept=alpha) drop=_TYPE_) noprint;
	where &estbeg<=evtdate<=&estend;
	model retmkt_t =;
	model retrf_t = mktrf; 
	model retrf_t = mktrf smb hml;
	model retrf_t = mktrf smb hml umd;
	by permno_t date;
run;
proc sql;
	create table MA_SUE
	as select distinct a.*, b.model, b.alpha as a, b.mktrf as b_mkt, b.smb as b_smb, b.hml as b_hml, b.umd as b_umd
	from MA as a, oreg as b
	where a.permno_t = b.permno_t and a.date=b.date
	order by permno_t, date, mvdate, model;
run;
data MA_SUE;
	set MA_SUE;
	if &evtbeg<=evtdate<=&evtend;
	/* assuming alpha=0 */
	if model="MODEL1" then hret_t = rf+mktrf;
	if model="MODEL2" then hret_t = rf+mktrf*b_mkt;
	if model="MODEL3" then hret_t = rf+mktrf*b_mkt+smb*b_smb+hml*b_hml;
	if model="MODEL4" then hret_t = rf+mktrf*b_mkt+smb*b_smb+hml*b_hml+umd*b_umd;
run;

/* writing to lib */
data MA_SUE_t;
	set MA_SUE (keep=date permno_t permno_a evtdate ret_t hret_t vol_t shrout_t p_t model a);
	rename a=alpha_t;
run; 

*-------------------------------------------------- Acquiror --------------------------------------------------;

rsubmit;
data MA;
	set home.MA;
	format date date9.;
	keep date permno_t permno_a;
run;

/* attaching crsp dse: select common stocks */
proc sql;
	create table MA
	as select distinct a.* 
	from MA as a, crsp.dse as b
	where a.permno_a=b.permno and 1<=b.exchcd<=3 and 10<=b.shrcd<=11;
run;

/* attching crsp dsf */
proc sql;
	create table MA
	as select distinct a.*, b.date-a.date as evtdate, b.date as mvdate, b.ret as ret_a, b.vol as vol_a,
		b.shrout as shrout_a, b.prc/b.cfacpr as p_a
	from MA as a, crsp.dsf as b
	where a.permno_a = b.permno and &estbeg<=b.date-a.date<=&evtend
	group by a.permno_a, a.date
	order by permno_a, date, mvdate;
quit;

/* attching ff_factors */
proc sql;
	create table MA
	as select distinct a.*, b.rf, b.mktrf, b.smb, b.hml, b.umd 
	from MA as a, ff.factors_daily as b
	where a.mvdate=b.date;
quit;

/* run regression on the estimation period to get beta and predict (residuals) on event dates */
data MA;
	set MA;
	retrf_a = ret_a-rf;
	retmkt_a = retrf_a-rf-mktrf;
run;
proc sort data=MA; 
	by permno_a date mvdate;
run;
proc reg noprint data=MA outest=oreg (rename=(_MODEL_=model _RMSE_=vol Intercept=alpha) drop=_TYPE_) noprint;
	where &estbeg<=evtdate<=&estend;
	model retmkt_a =;
	model retrf_a = mktrf; 
	model retrf_a = mktrf smb hml;
	model retrf_a = mktrf smb hml umd;
	by permno_a date;
run;
proc sql;
	create table MA_SUE
	as select distinct a.*, b.model, b.alpha as a, b.mktrf as b_mkt, b.smb as b_smb, b.hml as b_hml, b.umd as b_umd
	from MA as a, oreg as b
	where a.permno_a = b.permno_a and a.date=b.date
	order by permno_a, date, mvdate, model;
run;
data MA_SUE;
	set MA_SUE;
	if &evtbeg<=evtdate<=&evtend;
	/* assuming alpha=0 */
	if model="MODEL1" then hret_a = rf+mktrf;
	if model="MODEL2" then hret_a = rf+mktrf*b_mkt;
	if model="MODEL3" then hret_a = rf+mktrf*b_mkt+smb*b_smb+hml*b_hml;
	if model="MODEL4" then hret_a = rf+mktrf*b_mkt+smb*b_smb+hml*b_hml+umd*b_umd;
run;

/* writing to lib */
data MA_SUE_a;
	set MA_SUE (keep=date permno_t permno_a evtdate ret_a hret_a vol_a shrout_a p_a model a);
	rename a=alpha_a;
run; 


*-------------------------------------------------- Combine --------------------------------------------------;

rsubmit;
proc sort data=MA_SUE_t;
	by date permno_a permno_t evtdate model;
proc sort data=MA_SUE_a;
	by date permno_a permno_t evtdate model;
data home.MA_SUE;
	merge MA_SUE_t MA_SUE_a;
	by date permno_a permno_t evtdate model;
run;

