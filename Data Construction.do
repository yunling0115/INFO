* 1986-2010
clear all
set mem 4g
* library
gl rawdata "C:\Users\yling\Desktop\Webrequest" 
gl cleandata "C:\Users\yling\Desktop\Webrequest_r"
* home 
gl rawdata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest"
gl cleandata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest_r"
gl holdingdata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest\Holdings"
gl log "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest\logs"
* laptop
gl rawdata "E:\1 Ling\Info\Datawork\Webrequest"
gl cleandata "E:\1 Ling\Info\Datawork\Webrequest_r"
gl holdingdata "E:\1 Ling\Info\Datawork\Webrequest\Holdings"
gl log "E:\1 Ling\Info\Datawork\Webrequest\logs"

*====================================================================================================================================
*
*                                                   Collapse Holdings Data - NO RERUN
*
*====================================================================================================================================

* 1. mf_holdings
use "$rawdata\mf_holdings", clear
sort cusip fdate 
collapse (sum) shares (count) fundnoN=fundno, by(cusip fdate)
order cusip fdate 
duplicates drop
save "$holdingdata\mf_holdingsc", replace

* 2. mf_Dholdings
use "$rawdata\mf_Dholdings", clear
sort cusip fdate
collapse (sum) change (count) fundnoN=fundno, by(cusip fdate)
order cusip fdate 
duplicates drop
save "$holdingdata\mf_Dholdingsc", replace

* 3. mgr_holdings
use "$rawdata\mgr_holdings", clear
sort cusip fdate
collapse (sum) shares (count) mgrnoN=mgrno, by(cusip fdate)
order cusip fdate 
duplicates drop
save "$holdingdata\mgr_holdingsc", replace

* 4. mgr_Dholdings
use "$rawdata\mgr_Dholdings", clear
sort cusip fdate
collapse (sum) change (count) mgrnoN=mgrno, by(cusip fdate)
order cusip fdate 
duplicates drop 
save "$holdingdata\mgr_Dholdingsc", replace

*====================================================================================================================================
*
*                                                   Insider! - NO RERUN
*
*====================================================================================================================================

* using "SAS_Data_Extraction.sas, Part (IV)" to extract
* need cusip6 list, generated from ccm link
use "$cleandata\ccm_r", clear
g cusip6 = substr(cusip,1,6)
keep cusip6
duplicates drop
outsheet cusip6 using "$rawdata\cusip6.txt", nonames noquote replace

* Get holding.sas7bdat data
use "$rawdata\iholdings", clear
g qt=yq(year(trandate),quarter(trandate))
sort cusip6 personid qt trandate
drop if (cusip6==cusip6[_n+1] & personid==personid[_n+1] & qt==qt[_n+1]) 
collapse (sum) shares (sum) direct_sharesheld (sum) check_shares (sum) total_holdings, by(cusip qt)
sort cusip6 qt
drop if cusip6==""
save "$cleandata\iholdings", replace

*====================================================================================================================================
*
*                                                   Data Clean - RERUN
*
*====================================================================================================================================

*------------------------------------------------------------------------------------------------------------------------------------
* 1. ccm
*------------------------------------------------------------------------------------------------------------------------------------

use "$rawdata\ccm", clear
keep if usedflag==1
keep gvkey lpermno cusip tic sic linkdt linkenddt
order gvkey lpermno cusip tic sic linkdt linkenddt
rename lpermno permno
duplicates drop
save "$cleandata\ccm_r", replace

*------------------------------------------------------------------------------------------------------------------------------------
* 2. comp
*------------------------------------------------------------------------------------------------------------------------------------

use "$rawdata\comp", clear
drop indfmt consol popsrc datafmt
drop if (at==. | lt==. | ceq==. | che==.)
order gvkey cusip tic sic fyear datadate
duplicates drop
compress
save "$cleandata\comp_r", replace

* merge with ccm
use "$cleandata\comp_r", clear
merge n:n gvkey tic using "$cleandata\ccm_r" // same as not using tic
keep if _merge==3
keep if ((linkdt<=datadate | linkdt==.) & (datadate<=linkenddt | linkenddt==.))
drop linkdt linkenddt _merge
order gvkey permno
sort permno fyear
compress
save "$cleandata\comp_r", replace

*------------------------------------------------------------------------------------------------------------------------------------
* 3. crsp
*------------------------------------------------------------------------------------------------------------------------------------

use "$rawdata\crsp", clear
keep if (10<=shrcd & shrcd<=11) & (1<=exchcd & exchcd<=3)
drop if prc==.
drop dlstcd shrflg exchcd shrcd
order permno ticker siccd date 
duplicates drop
compress
save "$cleandata\crsp_r", replace

* merge with ccm
merge n:n permno using "$cleandata\ccm_r"
keep if _merge==3
keep if ((linkdt<=date | linkdt==.) & (date<=linkenddt | linkenddt==.))
drop linkdt linkenddt _merge ticker siccd
order gvkey permno cusip sic tic
sort permno date
compress
save "$cleandata\crsp_r", replace

*------------------------------------------------------------------------------------------------------------------------------------
* 4. ibes
*------------------------------------------------------------------------------------------------------------------------------------

use "$rawdata\ibes", clear
keep if measure=="EPS"
keep if usfirm==1
drop if (cusip=="" & oftic=="")
drop if (actual==. | anndats_act==.)
drop if anndats_act<=fpedats
keep if fpi=="6"
order cusip ticker oftic anndats_act fpedats
drop measure usfirm fpi 
rename oftic tic

* merge with ccm
preserve 
use "$cleandata\ccm_r", clear
gen cusip8 = substr(cusip,1,8)
rename cusip temp
rename cusip8 cusip
tempfile ccm
save "`ccm'", replace
restore
merge n:n tic cusip using "`ccm'"
keep if _merge==3
drop cusip
rename temp cusip
keep if ((linkdt<=fpedats | linkdt==.) & (anndats_act<=linkenddt | linkenddt==.))
drop linkdt linkenddt _merge ticker
order gvkey permno cusip sic tic
sort gvkey permno tic fpedats anndats_act 
duplicates drop

* collapse numest medest meanest stdev for same cusip ticker oftic anndats_act fpedats actual
sort gvkey permno tic cusip anndats_act fpedats actual 
collapse (sum) numest (mean) medest (mean) meanest (mean) stdev ///
	[fweight=numest], by(gvkey permno tic cusip anndats_act fpedats actual)
order gvkey permno cusip tic anndats_act fpedats numest 
duplicates drop
duplicates r gvkey permno tic anndats_act fpedats
duplicates r permno anndats_act fpedats
// duplicates r cusip oftic anndats_act fpedats
save "$cleandata\ibes_r", replace

*------------------------------------------------------------------------------------------------------------------------------------
* 5. sue
*------------------------------------------------------------------------------------------------------------------------------------

use "$rawdata\sue", clear
drop if oftic==""
keep if usfirm==1
keep if measure=="EPS"
order ticker oftic anndats
drop measure usfirm
format actual %8.0g
format surpmean %8.0g
format surpstdev %8.0g
format suescore %8.0g
drop if fiscalp=="ANN"
drop fiscalp 
sort ticker oftic anndats
duplicates drop
duplicates drop 
// collapse duplicates in terms of oftic, anndats, actual
collapse (mean) surpmean (mean) surpstdev (mean) suescore, ///
	by(ticker oftic anndats actual)
collapse (median) surpmean (median) surpstdev (median) suescore (median) actual, ///
	by(ticker oftic anndats)
// drop multiple ticker corresponds to one oftic
encode ticker, g(t)
egen max = max(t), by(oftic)
egen min = min(t), by(oftic)
drop if max~=min
drop max min t
duplicates r oftic anndats
save "$cleandata\sue_r", replace

* merge with ccm
rename oftic tic
merge n:n tic using "$cleandata\ccm_r"
keep if _merge==3
keep if ((linkdt<=anndats | linkdt==.) & (anndats<=linkenddt | linkenddt==.))
drop linkdt linkenddt _merge ticker
order gvkey permno cusip sic tic
sort permno anndats
save "$cleandata\sue_r", replace

* also export list for eventus
format anndats %tdCYND
outsheet permno anndats using "$rawdata\Eventus_input.txt", nonames replace
format anndats %td

*------------------------------------------------------------------------------------------------------------------------------------
* 6. holdings
*------------------------------------------------------------------------------------------------------------------------------------

use "$holdingdata\mf_holdingsc", clear
rename shares mfshares
rename fundnoN N_mfshares
sort cusip fdate
duplicates drop
merge n:n cusip fdate using "$holdingdata\mf_Dholdingsc"
drop _merge
rename change mfchange
rename fundnoN N_mfchange
sort cusip fdate
duplicates drop
merge n:n cusip fdate using "$holdingdata\mgr_holdingsc"
drop _merge
rename shares mgrshares
rename mgrnoN N_mgrshares
sort cusip fdate
duplicates drop
merge n:n cusip fdate using "$holdingdata\mgr_Dholdingsc"
drop _merge
rename change mgrchange
rename mgrnoN N_mgrchange
sort cusip fdate
duplicates drop
compress
save "$cleandata\holdings_r", replace

* merge with ccm
preserve 
use "$cleandata\ccm_r", clear
gen cusip8 = substr(cusip,1,8)
rename cusip temp
rename cusip8 cusip
tempfile ccm
save "`ccm'", replace
restore
merge n:n cusip using "`ccm'"
keep if _merge==3
keep if ((linkdt<=fdate | linkdt==.) & (fdate<=linkenddt | linkenddt==.))
drop linkdt linkenddt _merge cusip
rename temp cusip
order gvkey permno cusip sic tic
sort permno fdate
compress
save "$cleandata\holdings_r", replace

*------------------------------------------------------------------------------------------------------------------------------------
* 7. (new) MA - adding on 10/29/2012
*------------------------------------------------------------------------------------------------------------------------------------

/*
use "$cleandata\ccm_r", clear
g cusip6 = substr(cusip,1,6)
save "$cleandata\ccm_r", replace
*/
* Combine files
use "$rawdata\MA (5mil up) 1979-2011", clear
duplicates t dateannounced acquirorcusip targetcusip, g(dup)
keep if dup==0
preserve
use "$rawdata\MA (5mil up) 1979-2011 (more)", clear
duplicates t dateannounced acquirorcusip targetcusip, g(dup)
keep if dup==0
tempfile more
save "`more'"
restore
merge 1:1 dateannounced acquirorcusip targetcusip using "`more'"
keep if _merge==3
drop _merge
preserve
use "$rawdata\MA (5mil up) 1979-2011 (more) 2", clear
duplicates t dateannounced acquirorcusip targetcusip, g(dup)
keep if dup==0
tempfile more2
save "`more2'"
restore 
merge 1:1 dateannounced acquirorcusip targetcusip using "`more2'"
keep if _merge==3
drop _merge
drop m d y
drop dup
* Merge target
preserve 
use "$cleandata\ccm_r", clear
ren cusip6 targetcusip
tempfile ccm
save "`ccm'"
restore
merge m:m targetcusip using "`ccm'"
ren gvkey gvkey_t
ren permno permno_t
ren cusip cusip_t
ren tic tic_t
ren sic sic_t
keep if linkdt<=dateannounced & dateannounced<=linkenddt
keep if linkdt<=dateeffective & dateeffective<=linkenddt
keep if linkdt<=datewithdrawn & datewithdrawn<=linkenddt
drop if _merge~=3
drop _merge
drop linkdt linkenddt
* Merge acquirer
preserve
use "$cleandata\ccm_r", clear
ren cusip6 acquirorcusip
tempfile ccm
save "`ccm'"
restore
merge m:m acquirorcusip using "`ccm'"
drop acquirorcusip
ren gvkey gvkey_a
ren permno permno_a
ren cusip cusip_a
ren tic tic_a
ren sic sic_a
keep if linkdt<=dateannounced & dateannounced<=linkenddt
keep if linkdt<=dateeffective & dateeffective<=linkenddt
keep if linkdt<=datewithdrawn & datewithdrawn<=linkenddt
drop if _merge~=3
drop _merge 
drop linkdt linkenddt
* renames
ren pctofcash pct_cash
ren pctofstock pct_stk
ren valueoftransactionmil deal
label var deal "value of transaction (mil)"
ren targettotalassetsmil ta_t
label var ta_t "target total assets (mil)"
ren dateannounced date
label var date "date announced"
drop targetprimarysic* acquirorprimarysic*
drop pctofsharesacq dateeffective datewithdrawn
drop if date==.
sort date permno_a permno_t
drop if (pct_cash==. & pct_stk==.)
ren pctownedaftertransaction pct_own
label var pct_own "Percentage owned after transaction"
ren pctsought pct_sought
label var pct_sought "Percentage sought before transaction"
ren valuecashmil deal_cash
label var deal_cash "Value of cash paid (mil)"
drop analystestimatedvaluemil_r 
ren analystestimatedvaluemil value_est
label var value_est "Analyst estimated value (mil)"
ren firmvaluemil value_firm
label var value_firm "Target firm value (mil)"
ren impliedvalueofdealmil deal_implied
label var deal_implied "Implied value of deal"
ren valueofalternativeoffermil offer_atn
label var offer_atn "Value of alternative offer (mil)"
ren targetnetassetsmil na_t
label var na_t "Target net assets"
ren targetbookvaluepershareltmus be_t
label var be_t "Target book value per share"
ren targetcommonequitymil ceq_t
label var ceq_t "Target common equity (mil)"
* generate implied deal by pct_sought*value_firm
cap drop deal_implied1
g deal_implied1 = deal_implied
cap drop deal_implied2
g deal_implied2 = pct_sought*ceq_t/100
cap drop deal_implied3
g deal_implied3 = pct_sought*ta_t/100
cap drop deal implied4
g deal_implied4 = pct_sought*value_firm/100
g deal_implied5 = offer_atn
g deal_implied6 = value
g deal_implied7 = value_est
forvalues i=1/7 {
	g spread`i' = abs(deal-deal_implied`i')
}
cap drop deal_esterr
egen deal_esterr = rowmin(spread1-spread7)
cap drop spread* deal_implied1-deal_implied7
count if deal_esterr~=. & year(date)>=1986

* focus on undiversified merger
count if sic_t==sic_a
* drop all hybrid merger
keep if pct_stk==100 | pct_cash==100

save "$cleandata\MA", replace

* using SAS to import and hand over to SAS

*------------------------------------------------------------------------------------------------------------------------------------
* 8. (new) MA's sue - adding on 10/30/2012
*------------------------------------------------------------------------------------------------------------------------------------

* Merge with MA (5mil up) 1979-2011
use "$rawdata\MA_SUE", clear
foreach i in a t {
	g mktcap_`i' = shrout_`i'*p_`i'
	g sue_`i'_before = abs(ret_t-hret_t) if evtdate<-1
	g sue_`i' = abs(ret_t-hret_t) if -1<=evtdate & evtdate<=1
	g p_`i'_before = p_`i' if evtdate<0
	g p_`i'_after = p_`i' if evtdate>0
	g turnover_`i'_before = vol_`i'/shrout_`i' if evtdate<0
	g turnover_`i'_after = vol_`i'/shrout_`i' if evtdate>0
}
g sue_c_before = sue_t_before+sue_a_before
g sue_c = sue_t+sue_a
forvalues i=1/4 {
	replace model="`i'" if model=="MODEL`i'"
}
destring model, replace
duplicates drop
* mean of turnover and price
preserve
keep if model==1
collapse turnover_*_before turnover_*_after p_*_before p_*_after, by(date permno_t permno_a)
tempfile 1
save "`1'"
restore
* std of turnover
preserve
keep if model==1
collapse (sd) turnover_*_before turnover_*_after, by(date permno_t permno_a)
renames turnover_*_before turnover_*_after, s(_sd)
tempfile 2
save "`2'"
restore
* sues
preserve
collapse sue_t sue_a sue_c sue_t_before sue_a_before sue_c_before, by(date permno_t permno_a model)
reshape wide sue*, i(date permno_t permno_a) j(model)
d
tempfile 3
save "`3'"
restore
* comebine
use "`1'", clear
forvalues i=2/3 {
	merge 1:1 date permno_t permno_a using "``i''"
	tab _merge
	drop _merge
}

save "$cleandata\MA_SUE", replace

/*
use "$rawdata\MA_crspdaily", clear
keep if (10<=shrcd & shrcd<=11) & (1<=exchcd & exchcd<=3)
drop if prc==.
drop shrcd exchcd
drop ticker
ren permno permno_t
ren ret ret_t
ren vol vol_t 
ren shrout shrout_t
ren prc prc_t 

* merge with factors
merge m:m date using "$rawdata\ff_daily"
keep if _merge==3
drop _merge
drop dlstcd

* merge with MA
merge m:m permno_t date using "$cleandata\MA (5mil up) 1979-2011"
sort permno_t date
g retrf_t = ret_t-rf
g date_announced = date if dow~=.
format date_announced %td
drop _merge
keep permno_t date retrf_t mktrf smb hml umd date_announced
order date_announced
sort date_announced permno_t date
duplicates drop
save "$cleandata\MA_crspdaily", replace

* risk-adjusted estimated return
use "$cleandata\MA_crspdaily", clear
count if date_announced~=. 
loc n=r(N)
di `n'
cap drop a_capm a_cs
g a_capm=.
g a_cs=.
forvalues i=1/`n' {
	di `i'
	loc d = date_announced in `i'
	loc p = permno_t in `i'
	// di `d'
	// di `p'
	cap qui reg retrf mktrf if permno_t ==`p' & date-`d'>=-90 & date-`d'<=-7
	cap predict a_capm_temp if permno_t ==`p' & date-`d'>-7 & date-`d'<7, resid
	cap replace a_capm = c_capm_temp if permno_t ==`p' & date-`d'>-7 & date-`d'<7, resid
	cap qui reg retrf mktrf smb hml umd if permno_t ==`p' & date-`d'>=-90 & date-`d'<=-7
	cap predict a_cs if permno_t ==`p' & date-`d'>-7 & date-`d'<7, resid
	cap replace a_cs = c_cs_temp if permno_t ==`p' & date-`d'>-7 & date-`d'<7, resid
	cap drop *temp
}
save "$cleandata\MA_crspdaily_risk"
*/ 

* upload to wrds to do;

*====================================================================================================================================
*
*                                                   Merge - Earnings Surprise
*
*====================================================================================================================================

* sort by gvkey permno

log using "$cleandata\log1", replace
use "$cleandata\ibes_r", clear
d // permno fpedats anndats
use "$cleandata\sue_r", clear
d // permno anndats
use "$cleandata\holdings_r", clear
d // permno fdate
use "$cleandata\crsp_r", clear
d // permno date (month)
use "$cleandata\comp_r", clear
d // permno fyear (annual)
log close


* (1) crsp + comp
use "$cleandata\crsp_r", clear
drop naics distcd divamt
gen ym = ym(year(date),month(date))
format ym %tm
drop date
order gvkey permno cusip sic tic ym
sort permno ym
gen fyear=year(dofm(ym))
merge n:n permno gvkey cusip fyear using "$cleandata\comp_r"
keep if _merge==3
drop _merge
drop datadate fyear
sort permno ym
duplicates drop
order permno gvkey cusip tic sic naics ym 
duplicates r permno ym
// permno ym

* (2) + holdings
preserve
use "$cleandata\holdings_r", clear
duplicates r  permno fdate
gen ym = ym(year(fdate),month(fdate))
format ym %tm
tempfile holdings
save "`holdings'", replace
duplicates r permno ym
restore
// permno ym

merge n:n permno gvkey cusip tic ym using "`holdings'"
drop if _merge==2
drop _merge
sort permno gvkey cusip tic ym 
// holdings: mar, jun, sep, dec

* (3) ibes + sue
preserve
use "$cleandata\ibes_r", clear
rename anndats_act anndats
merge n:n permno gvkey cusip tic anndats using "$cleandata\sue_r" 
keep if _merge==3
drop _merge
count if anndats<= fpedats
renvars numest-stdev, postf(_pre)
renvars surpmean-suescore, postf(_post)
duplicates drop
compress
// for merge fpedats
gen yq = yq(year(fpedats),quarter(fpedats))
gen day = dofq(yq+1)-1
replace day = dofq(yq)-1 if day~=fpedats
gen ym = ym(year(day),month(day))
format ym %tm
drop yq
* drop if fpedats~=day
tempfile ibes_sue
save "`ibes_sue'", replace
duplicates r permno anndats fpedats
duplicates r permno fpedats
restore
// permno ym

merge n:n permno gvkey cusip tic ym using "`ibes_sue'"
drop if _merge==2
drop _merge
sort permno gvkey cusip tic ym anndats fpedats
drop if (permno==permno[_n-1] & ym==ym[_n-1])
xtset permno ym

save "$cleandata\MergedData_1", replace

*====================================================================================================================================
*
*                                                   Adjustment to quarter - Earnings Suprise
*
*====================================================================================================================================

use "$cleandata\MergedData_1", clear
xtset permno ym

* collapse to quarter
gen qret = (1+ret)*(1+L.ret)*(1+L2.ret)-1
gen  qvol = vol+L.vol+L2.vol
gen m = month(dofm(ym))
keep if (m==3 | m==6 | m==9 | m==12)
order permno ym anndats fpedats sic naics
replace ret = qret
replace vol = qvol
drop qret qvol m
keep if anndats ~=.
duplicates r permno ym
destring gvkey, g(gvkey2)
drop gvkey
ren gvkey2 gvkey
save "$cleandata\MergedData_2", replace

* note: go on to Analysis


*====================================================================================================================================
*
*                                                  (new) Merge - MA - adding on 10/30/2012
*
*====================================================================================================================================

* sort by gvkey permno

log using "$cleandata\log2", replace
use "$cleandata\MA", clear
d // date permno_t permno_a
use "$cleandata\MA_SUE", clear /* new - replacing ibes_r */
d // date permno_t permno_a
use "$cleandata\holdings_r", clear /* new - replacing sue_r */
d // permno fdate
use "$cleandata\crsp_r", clear /* no need */
// permno date (month)
use "$cleandata\comp_r", clear
d // permno fyear (annual)
log close

* (1) MA + MA_SUE
use "$cleandata\MA", clear
merge 1:1 date permno_t permno_a using "$cleandata\MA_SUE"
keep if _merge==3
drop _merge
drop tic_a tic_t deal_implied offer_atn targetcusip value value_firm value value_firm
g method = "c" if pct_cash==100
replace method = "s" if method==""
drop pct_stk pct_cash deal_cash
order date permno_t permno_a pct_sought pct_own deal method ///
	deal_esterr turnover* sue* p* gvkey* cusip* sic*

* (2) + comp

use "$cleandata\comp_r", clear
drop tic sic

* (3) + holdings

* (1) crsp + comp
use "$cleandata\crsp_r", clear
drop naics distcd divamt
gen ym = ym(year(date),month(date))
format ym %tm
drop date
order gvkey permno cusip sic tic ym
sort permno ym
gen fyear=year(dofm(ym))
merge n:n permno gvkey cusip fyear using "$cleandata\comp_r"
keep if _merge==3
drop _merge
drop datadate fyear
sort permno ym
duplicates drop
order permno gvkey cusip tic sic naics ym 
duplicates r permno ym
// permno ym

* (2) + holdings
preserve
use "$cleandata\holdings_r", clear
duplicates r  permno fdate
gen ym = ym(year(fdate),month(fdate))
format ym %tm
tempfile holdings
save "`holdings'", replace
duplicates r permno ym
restore
// permno ym

* note: go on to Analysis
