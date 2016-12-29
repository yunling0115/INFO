
*====================================================================================================================================
*
*                                                   Analysis and Tables
*
*====================================================================================================================================

use "$cleandata\MergedData_3", clear

g prior_prec = 1/diff_pre
g sales_prec = 1/sales_sd
g supply_prec = 1/turnover_sd
g priv_prec = vol_diff

gl dep $car
gl indN="$indvar"+"_N"
gl indep turnover i_shrout diff_pre pcm sales_mean diff_sales H_sale turnover_sd vol_diff $indN 
gl indep turnover i_shrout log_diff_pre $indN pcm_adj sales_mean log_ind_pre_sales H_sale turnover_sd vol_diff 

gl control che_at capx_at leverage bm size roa
gl nv_dep: word count $dep
gl nv_indep: word count $indep 
gl nv_control: word count $control

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Further lag (endo) independent variables and controls for one quarter
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

/*
foreach var of varlist turnover i_shrout i_turnover diff_pre {
	replace `var' = `var'[_n-1] if (permno==permno[_n-1] & qt-qt[_n-1]==1)
}
*/

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* 1. Raw regression
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

egen long i = group(qt $indvar)

* (1) Panel Regression - FE of time, cluster industry
qui xtreg $dep $indep $control, fe vce(r)
est store FE_CL_raw_$car
/*
if "$indvar"=="naics3" {
qui xtreg $dep $indep $control, fe vce(cl $indvar)
est store FE_CL_raw_$car
}
else {
qui xtreg $dep $indep $control, fe vce(r)
est store FE_CL_raw_$car
}
*/

* (2) OLS with time dummy - time dummy, cluster industry
qui areg $dep $indep $control qdum*, absorb(qt) vce(cl $indvar)
est store QD_CL_raw_$car

/*
* (3) OLS with time dummy - time dummy, industry dummy
qui areg $dep $indep $control, absorb(i) vce(robust)
est store QD_ID_raw_$car
*/

* (4) Fama Macbeth - FM
qui xtfmb $dep $indep $control
est store FM_raw_$car

/*
* (5) Fama Macbeth with Newey West lag4 (1y) - FM4
qui xtfmb $dep $indep $control, lag(4)
est store FM4_raw_$car
*/

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* 2. Winsorize
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

gl allvar="$dep $indep $control"
foreach var of varlist $allvar {
	egen x = pctile(`var'), by(qt) p(1)
	egen y = pctile(`var'), by(qt) p(99)
	gen w_`var' = `var'
	replace w_`var'=x if w_`var'<x
	replace w_`var'=y if w_`var'>y
	drop x y
}

macro drop wdep windep wcontrol
gl wdep=""
gl windep=""
gl wcontrol=""
forvalues i=1/$nv_dep {
	token $dep
	//di "``i''"
	gl wdep="$wdep w_``i''"
}
macro list wdep
forvalues i=1/$nv_indep {
	token $indep
	//di "``i''"
	gl windep="$windep w_``i''"
}
macro list windep
forvalues i=1/$nv_control {
	token $control
	gl wcontrol="$wcontrol w_``i''"
}
macro list wcontrol

* (1) Panel Regression - FE of time, cluster industry
qui xtreg $wdep $windep $wcontrol, fe vce(r)
est store FE_CL_win_$car
/*
if "$indvar"=="naics3" {
qui xtreg $wdep $windep $wcontrol, fe vce(cl $indvar)
est store FE_CL_win_$car
}
else {
qui xtreg $wdep $windep $wcontrol, fe vce(r)
est store FE_CL_raw_$car
}
*/

* (2) OLS with time dummy - time dummy, cluster industry
qui areg $wdep $windep $wcontrol qdum*, absorb(qt) vce(cl $indvar)
est store QD_CL_win_$car

/*
* (3) OLS with time dummy - time dummy, industry dummy
qui areg $wdep $windep $wcontrol, absorb(i) vce(robust)
est store QD_ID_win_$car
*/

* (4) Fama Macbeth - FM
qui xtfmb $wdep $windep $wcontrol
est store FM_win_$car

/*
* (5) Fama Macbeth with Newey West lag4 (1y) - FM4
qui xtfmb $wdep $windep $wcontrol, lag(4)
est store FM4_win_$car
*/

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* 3. Normalize
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

foreach var of varlist $allvar {
	egen m`var' = mean(`var'), by(qt)
	g n`var' = `var'-m`var'
	drop m`var'

	egen x = pctile(`var'), by(qt) p(1)
	egen y = pctile(`var'), by(qt) p(99)
	gen wn_`var' = n`var'
	replace wn_`var'=x if wn_`var'<x
	replace wn_`var'=y if wn_`var'>y
	drop x y
	
	gen n_`var' = wn_`var'
	drop wn_`var' n`var'
}

macro drop ndep nindep ncontrol
gl ndep=""
gl nindep=""
gl ncontrol=""
forvalues i=1/$nv_dep {
	token $dep
	//di "``i''"
	gl ndep="$ndep n_``i''"
}
macro list ndep
forvalues i=1/$nv_indep {
	token $indep
	//di "``i''"
	gl nindep="$nindep n_``i''"
}
macro list nindep
forvalues i=1/$nv_control {
	token $control
	gl ncontrol="$ncontrol n_``i''"
}
macro list wcontrol

* (1) Panel Regression - FE of time, cluster industry
if "$indvar"=="naics3" {
qui xtreg $ndep $nindep $ncontrol, fe vce(cl $indvar)
est store FE_CL_nor_$car
}

* (2) OLS with time dummy - time dummy, cluster industry
qui areg $ndep $nindep $ncontrol qdum*, absorb(qt) vce(cl $indvar)
est store QD_CL_nor_$car

* (3) OLS with time dummy - time dummy, industry dummy
qui areg $ndep $nindep $ncontrol, absorb(i) vce(robust)
est store QD_ID_nor_$car

* (4) Fama Macbeth - FM
qui xtfmb $ndep $nindep $ncontrol
est store FM_nor_$car

* (5) Fama Macbeth with Newey West lag4 (1y) - FM4
qui xtfmb $ndep $nindep $ncontrol, lag(4)
est store FM4_nor_$car

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* List Table of Estimates
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

drop _est*
est table *_raw_$car, star(.05 .01 .001) sty(columns) keep($indep)
est table *_win_$car, star(.05 .01 .001) sty(columns) keep($windep)
* est table *_nor_$car, star(.05 .01 .001) sty(columns) keep($nindep)

*---------------------------------------------------------------------------------------------------------------------------------------------------------------------
* Cross-sectional for each year
*---------------------------------------------------------------------------------------------------------------------------------------------------------------------

/*
* Raw TS of CSR
sum year
loc begyear = r(min)
loc endyear = r(max)
forvalues i=`begyear'/`endyear' {
	di `i'
	cap qui reg $dep $indep $control if (year==`i'), vce(cl $indvar)
	cap est store Raw_`i'
	cap qui reg $wdep $windep $wcontrol if (year==`i'), vce(cl $indvar)
	cap est store Win_`i'
	cap qui reg $ndep $nindep $ncontrol if (year==`i'), vce(cl $indvar)
	cap est store Nor_`i'
}
log using "$log\$indvar", append
est table Raw_*, star(.05 .01 .001) keep($indep)
est table Win_*, star(.05 .01 .001) keep($windep)
est table Nor_*, star(.05 .01 .001) keep($nindep)
log close
*/
