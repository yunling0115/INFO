clear all
set mem 2g
* library
gl rawdata "C:\Users\yling\Desktop\Webrequest" 
gl cleandata "C:\Users\yling\Desktop\Webrequest_r"
* home 
gl rawdata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest"
gl cleandata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest_r"
gl holdingdata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest\Holdings"
gl hpdata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Phillips Dataset"
gl log "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest\logs"
gl hist "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest\histgram"
* office
gl rawdata "C:\Users\yling\Documents\LOCDATA\Webrequest"
gl cleandata "C:\Users\yling\Documents\LOCDATA\Webrequest_r"
gl holdingdata "C:\Users\yling\Documents\LOCDATA\Webrequest\Holdings"
gl hpdata "C:\Users\yling\Documents\LOCDATA\Phillips Dataset"
gl log "C:\Users\yling\Documents\LOCDATA\Webrequest\logs"
gl crspd "C:\Users\yling\Documents\LOCDATA\Webrequest\CrspDaily"

*====================================================================================================================================
*
*                                                   Variable construct
*
*====================================================================================================================================

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Merge in Turnover sd (not rerun)
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

use "$crspd\crspdaily", clear
g ym = ym(year(date),month(date))
g qt = yq(year(date),quarter(date))
format qt %tq
g turnover = log(vol/shrout/1000)
collapse (sd) turnover=turnover, by(permno qt)
ren turnover turnover_sd
keep permno qt turnover_sd
duplicates drop
save "$cleandata\turnover_sd", replace

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Start & Merge in Phillip's Dataset
*--------------------------------------------------------------------------------------------------------------------------------------------------------------------- 

use "$cleandata\MergedData_2", clear
xtset permno ym
duplicates r permno ym
gen year = year(day)
format year %ty
merge n:n gvkey year using "$hpdata\fic_data"
drop _merge

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Export permno for crsp extraction
* Export permno and anndats for crsp extraction
* rolling regression needs to be done in SAS remotely
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

preserve
keep permno
duplicates drop
outsheet permno using "$cleandata\CAR.txt", delimiter(",") replace
restore

preserve
keep permno anndats
duplicates drop
format anndats %tdCYND
outsheet permno anndats using "$cleandata\ANNDATS.txt", delimiter(",") replace
restore

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* 1. Perform SAS program: "$rawdata\CAR.sas" - first part of transform txt to sas
* 2. Upload SAS dataset: "$cleandata\car.sas7bdt" and "$cleandata\anndats.sas7bdt" 
* 3. Running SAS program: "$rawdata\CAR.sas" - second part to run rolling regression to get estimation betas
* 4. Download SAS dataset: INFO.est to "$crspd\est.sas"
* 5. Running stata program "$rawdata\CAR.do" 
* 	 do "$rawdata\CAR.do"
* 6. Getting dataset "$cleandata\car3"
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

merge n:n permno anndats using "$cleandata\car3"
keep if _merge==3
drop _merge
forvalues i=1/3 {
	replace car`i' = abs(car`i')
	replace carx`i' = abs(carx`i')
	replace abr`i' = abs(abr`i')
	replace abrx`i' = abs(abrx`i')
}

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Merge in insider's holdings
*--------------------------------------------------------------------------------------------------------------------------------------------------------------------- 

ren q qt
gen cusip6 = substr(cusip,1,6)
merge n:n cusip6 qt using "$cleandata\iholdings"
drop _merge

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Usual screening
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

drop anndats fpedats fdate day
drop N_mfshares N_mfchange N_mgrshares N_mgrchange
drop if curcd~="USD"
drop curcd

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Exclude utilities and financials:
* Eisfeldt Muir (SIC start with 9)
* Matvos Seru (SIC codes 4900-4949), financial firms (6000-6999) 
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

drop if sic == ""
destring sic, gen(dnum)
drop if (dnum >=4900 & dnum <=4949)
drop if (dnum >=6000 & dnum <=6999)

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Count 3 digit naics code and 3 digit sic code
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

g sic3 = substr(sic,1,3)
g naics3 = substr(naics,1,3)
bysort sic3 ym: egen sic3_N = count(permno)
bysort naics3 ym: egen naics3_N = count(permno)
bysort icode100 ym: egen icode100_N = count(permno)
bysort icode200 ym: egen icode200_N = count(permno) 
bysort icode300 ym: egen icode300_N = count(permno) 
bysort icode400 ym: egen icode400_N = count(permno) 
bysort icode500 ym: egen icode500_N = count(permno) 

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Variable Construction1: crsp
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

replace prc = abs(prc)
g turnover = log(vol/shrout)
g mv = prc*shrout

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Variable Construction2: comp 
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

format qt %tq
sort permno qt
drop if (permno==permno[_n+1] & qt==qt[_n+1])
xtset permno qt, q
sort permno qt
g quarter = quarter(dofm(ym))
g Lat=at[_n-1] if (quarter==1 & permno==permno[_n-1])
replace Lat=Lat[_n-1] if (quarter==2 & permno==permno[_n-1])
replace Lat=Lat[_n-1] if (quarter==3 & permno==permno[_n-1])
replace Lat=Lat[_n-1] if (quarter==4 & permno==permno[_n-1])

g equity = seq
replace equity = ceq+pstk if equity ==.
replace equity = at-lt
g prestk = pstkrv
replace prestk = pstkl if prestk ==.
replace prestk = pstk if prestk ==.
g be = equity+txditc-prestk
g bm = be*1000/mv
drop if bm<0

g size = log(Lat)
g inv = (ppegt + invt)/Lat
g che_at = che/Lat
g lt_at = lt/Lat
g equity_at = ceq/Lat
g capx_at = capx/Lat
g ch_at = ch/Lat
g intan_at = intan/Lat
g invt_at = invt/Lat
g ppegt_at = ppegt/Lat
g sale_at = sale/Lat
g pcm = (sale-cogs)/sale
g roa = ebitda/Lat
g leverage = lt/at
drop if pcm<0

foreach var of varlist sic3 naics3 icode100 icode200 icode300 icode400 icode500 {
	egen pcmind_`var' = mean(pcm), by(qt `var')
	g pcm_adj_`var' = pcm-pcmind_`var'
	g log_pcm_adj_`var' = log(pcm_adj_`var')
}

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Year dummy and month dummy
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

/*
qui tab qt, g(qdum)
qui tab year, g(ydum)
qui tab $indvar, g(idum)
*/

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Variable Construction3: insider proportion and information precision
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

* proportion of insider and outsider
g i_shrout = (mfshares+mgrshares)/(shrout*1000)
* insider information (1)
g i_change = (mfchange+mgrchange)/vol
g change_diff = i_change/(1-i_change)
g log_change_diff = log(change_diff)
* insider information (2)
g o_turnover = log((vol-mfchange-mgrchange)/(shrout*1000))
g i_turnover = log((mfchange+mgrchange)/(shrout*1000))
g vol_diff = log((abs(mfchange)+abs(mgrchange))/abs(vol))

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Variable Construction4: information disclosure precision
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

g sue_ret = surpmean_post

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Variable Construction5: prior information precision 
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

g diff_earnings = abs(actual_pre-medest_pre)+1
g log_diff_earnings = log(diff_earnings)

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Variable Construction6: demand mean and precision
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

foreach var of varlist sic3 naics3 icode100 icode200 icode300 icode400 icode500 {
	egen sales_mean_`var' = mean(log(sale_at)), by(qt `var')
	egen sales_sd_`var' = sd(log(sale_at)), by(qt `var')
}

* Lsales_sd
foreach var of varlist sic3 naics3 icode100 icode200 icode300 icode400 icode500 {
	g Lsales_sd_`var' =sales_sd_`var'[_n-1] if (quarter==1 & permno==permno[_n-1])
	replace Lsales_sd_`var' =Lsales_sd_`var'[_n-1] if (quarter==2 & permno==permno[_n-1])
	replace Lsales_sd_`var' =Lsales_sd_`var'[_n-1] if (quarter==3 & permno==permno[_n-1])
	replace Lsales_sd_`var' =Lsales_sd_`var'[_n-1] if (quarter==4 & permno==permno[_n-1])
}

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Variable Construction7: Herfindahl index
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

foreach var of varlist sic3 naics3 icode100 icode200 icode300 icode400 icode500 {
	egen sale_ind_`var' = sum(sale), by(qt `var')
	g sale_share2_`var' = (sale/sale_ind_`var')^2
	egen H_sale_`var' = sum(sale_share2_`var'), by(qt `var')
}

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Order variables and save
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

order permno qt
xtset permno qt

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Merge in turnover sd
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

merge n:n permno qt using "$cleandata\turnover_sd"
keep if _merge==3
drop _merge

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Merge in sales estimates
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

preserve
use "$cleandata\ibes_sales_r", clear
renvars numest-stdev, postf(_pre_sales)
g diff_sales = abs(actual_pre_sales-medest_pre_sales)+1
gen qt = yq(year(fpedats),quarter(fpedats))
format qt %tq
replace qt = qt+1
sort gvkey qt 
drop if (gvkey==gvkey[_n-1] & qt==qt[_n-1])
duplicates r gvkey qt
destring gvkey, g(gvkey2)
drop gvkey
ren gvkey2 gvkey
tempfile ibes_sales
save "`ibes_sales'"
restore
merge n:n gvkey qt using "`ibes_sales'"
drop if _merge==2
drop _merge
* sales precision at the industry level
g log_diff_sales = log(diff_sales)
foreach var of varlist sic3 naics3 icode100 icode200 icode300 icode400 icode500 {
	egen ind_diff_sales_`var' = sum(diff_sales), by(qt `var')
	egen ind_log_diff_sales_`var' = mean(log_diff_sales), by(qt `var')
	g log_ind_diff_sales_`var' = log(ind_diff_sales_`var')
}


*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Merge in illiquidity
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

preserve
use "$cleandata\illiq", clear
gen qt = yq(year(date),quarter(date))
replace illiq=illiq*10^6
tempfile illiq
save "`illiq'"
restore
merge n:n permno qt using "`illiq'"
drop if _merge==2
drop _merge
sort permno qt
drop if (permno==permno[_n+1] & qt==qt[_n+1])
duplicates r permno qt

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Merge in recession
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

preserve
clear 
freduse USRECQM
g qt = yq(year(daten),quarter(daten))
ren USRECQM rec
keep rec qt
tempfile rec
save "`rec'"
restore
merge n:n qt using "`rec'"
drop if _merge==2
drop _merge

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Save
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

xtset permno qt
save "$cleandata\MergedData_3", replace

*====================================================================================================================================
*
*                                                   Summary Statistics
*
*====================================================================================================================================
 
use "$cleandata\MergedData_3", clear
gl cars car1 carx1 car2 carx2 car3 carx3
gl abrs abr1 abrx1 abr2 abrx2 abr3 abrx3

* naics3
gl indvar naics3
gl allvar $cars shrout turnover i_shrout i_turnover log_diff_earnings log_ind_diff_sales_$indvar $indvar_N pcm pcm_adj_$indvar sales_mean_$indvar H_sale_$indvar che_at capx_at lt_at roa bm size leverage
log using "$log\sum_new_$indvar", replace
univar $allvar, dec(4)
log close

* icode100
gl indvar icode100
gl allvar $cars shrout turnover i_shrout i_turnover log_diff_earnings log_ind_diff_sales_$indvar $indvar_N pcm pcm_adj_$indvar sales_mean_$indvar H_sale_$indvar che_at capx_at lt_at roa bm size leverage
log using "$log\sum_new_$indvar", replace
univar $allvar, dec(4)
log close

* histgrams
gl indvar naics3
gl indN="$indvar"+"_N"
gl indep turnover turnover_sd i_shrout vol_diff log_diff_earnings sales_mean_$indvar ind_log_diff_sales_$indvar H_sale_$indvar $indN rec
foreach var of varlist $indep {
	qui hist `var'
	graph save `var', replace
}
gl indvar icode100
gl indN="$indvar"+"_N"
gl indep turnover turnover_sd i_shrout vol_diff log_diff_earnings sales_mean_$indvar ind_log_diff_sales_$indvar H_sale_$indvar $indN rec
foreach var of varlist $indep {
	qui hist `var'
	graph save `var', replace
}
qui hist w_log_diff_earnings
graph combine turnover.gph turnover_sd.gph i_shrout.gph vol_diff.gph w_log_diff_earnings.gph sales_mean_icode100.gph ind_log_diff_sales_icode100.gph H_sale_icode100.gph icode100_N.gph rec.gph ///
	sales_mean_naics3.gph ind_log_diff_sales_naics3.gph H_sale_naics3.gph naics3_N.gph

*====================================================================================================================================
*
*                                                   Analysis and Tables
*
*====================================================================================================================================

set more off
gl logno s1

* naics3
use "$cleandata\MergedData_3", clear
gl indvar naics3
do "$rawdata\Tables_new.do"
* icode100
use "$cleandata\MergedData_3", clear
gl indvar icode100
do "$rawdata\Tables_new.do"

* rec
use "$cleandata\MergedData_3", clear
gl indvar icode100
do "$rawdata\Tables_rec.do"



*====================================================================================================================================
*
*                                                   size group? capx-che group? (capx-che/turnover)
*
*====================================================================================================================================

use "$cleandata\MergedData_3", clear
* (lagged) size class
egen Lat25 = pctile(Lat), p(25) by(qt)
egen Lat50 = pctile(Lat), p(50) by(qt)
egen Lat75 = pctile(Lat), p(75) by(qt)
egen Lat90 = pctile(Lat), p(90) by(qt)
egen Lat95 = pctile(Lat), p(95) by(qt)
egen Lat99 = pctile(Lat), p(99) by(qt)
gen sz_class = .
replace sz_class = 1 if Lat<=Lat25
replace sz_class = 2 if (Lat25<Lat & Lat<=Lat50)
replace sz_class = 3 if (Lat50<Lat & Lat<=Lat75)
replace sz_class = 4 if (Lat75<Lat & Lat<=Lat90)
replace sz_class = 5 if (Lat90<Lat & Lat<=Lat95)
replace sz_class = 6 if (Lat95<Lat & Lat<=Lat99)
tab sz_class, gen(sz_c)
drop sz_class
* (lagged) financial need (capx-che)/at class
g fn = inv-che_at
g Lfn = fn
/*
g Lfn =fn[_n-1] if (quarter==1 & permno==permno[_n-1])
replace Lfn =Lfn[_n-1] if (quarter==2 & permno==permno[_n-1])
replace Lfn =Lfn[_n-1] if (quarter==3 & permno==permno[_n-1])
replace Lfn =Lfn[_n-1] if (quarter==4 & permno==permno[_n-1])
*/
egen Lfn25 = pctile(Lfn), p(25) by(qt)
egen Lfn50 = pctile(Lfn), p(50) by(qt)
egen Lfn75 = pctile(Lfn), p(75) by(qt)
egen Lfn90 = pctile(Lfn), p(90) by(qt)
egen Lfn95 = pctile(Lfn), p(95) by(qt)
egen Lfn99 = pctile(Lfn), p(99) by(qt)
gen fn_class = .
replace fn_class = 1 if Lfn<=Lfn25
replace fn_class = 2 if (Lfn25<Lfn & Lfn<=Lfn50)
replace fn_class = 3 if (Lfn50<Lfn & Lfn<=Lfn75)
replace fn_class = 4 if (Lfn75<Lfn & Lfn<=Lfn90)
replace fn_class = 5 if (Lfn90<Lfn & Lfn<=Lfn95)
replace fn_class = 6 if (Lfn95<Lfn & Lfn<=Lfn99)
tab fn_class, gen(fn_c)
drop fn_class
save "$cleandata\MergedData_3", replace

forvalues i=1/6 {
	univar car3 if fn_c`i'==1, dec(4)
}
forvalues i=1/6 {
	univar car3 if sz_c`i'==1, dec(4)
}


*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Size
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

set more off
gl logno s2

gl group sz
* naics3
use "$cleandata\MergedData_3", clear
gl indvar naics3
do "$rawdata\Tables_group.do"
* icode100
use "$cleandata\MergedData_3", clear
gl indvar icode100
do "$rawdata\Tables_group.do"


*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Financing Needs
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

set more off
gl logno s2

gl group fn
* naics3
use "$cleandata\MergedData_3", clear
gl indvar naics3
do "$rawdata\Tables_group.do"
* icode100
use "$cleandata\MergedData_3", clear
gl indvar icode100
do "$rawdata\Tables_group.do"

