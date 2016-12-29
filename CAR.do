clear all
set mem 3g
* library
gl rawdata "C:\Users\yling\Desktop\Webrequest" 
gl cleandata "C:\Users\yling\Desktop\Webrequest_r"
* home
gl crspd "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest\CrspDaily" 
gl rawdata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest"
gl cleandata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest_r"
gl holdingdata "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest\Holdings"
gl log "C:\yling$ (msbfile)\Study\Spring 2012\GSBA 790\Datawork\Webrequest\logs"
* office

*====================================================================================================================================
*
*                                                   Estimation has been done by calling sas program
*													"$clearndata\CAR.sas" and the downloaded sas file is "$crspd\est.sas7bdt"
*
*====================================================================================================================================

* d=0
use "$crspd\est", clear
drop if _model_==""
encode _model_, g(model)
drop _model_
sort permno date model
order permno date model
merge n:n permno date using "$crspd\crspdaily"
sort permno date model
keep if model~=.
drop _merge
merge n:n date using "$crspd\ff"
sort permno date model
keep if _merge==3
drop _merge
gen ret_est0 = rf+mktrf_c*mktrf if model==1
gen ret_est = intercept+rf+mktrf_c*mktrf if model==1
replace ret_est0 = rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml if model==2
replace ret_est = intercept+rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml if model==2
replace ret_est0 = rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml+umd_c*umd if model==3
replace ret_est = intercept+rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml+umd_c*umd if model==3
gen abr0 = retx-ret_est0
gen abr = retx-ret_est
keep permno date model abr0 abr
g annouce = 1
save "$crspd\abr", replace

* d>0
loc d1=1 // from -d1 day
forvalues i=1/`d1' {
	use "$crspd\est", clear
	drop if _model_==""
	encode _model_, g(model)
	drop _model_
	sort permno date model
	order permno date model
	replace date=date-2 if (1<=dow(date) & dow(date)<=`i')
	replace date=date-`i'
	merge n:n permno date using "$crspd\crspdaily"
	sort permno date model
	keep if _merge==3
	drop _merge
	merge n:n date using "$crspd\ff"
	sort permno date model
	keep if _merge==3
	drop _merge
	gen ret_est0 = rf+mktrf_c*mktrf if model==1
	gen ret_est = intercept+rf+mktrf_c*mktrf if model==1
	replace ret_est0 = rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml if model==2
	replace ret_est = intercept+rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml if model==2
	replace ret_est0 = rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml+umd_c*umd if model==3
	replace ret_est = intercept+rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml+umd_c*umd if model==3
	gen abr0 = retx-ret_est0
	gen abr = retx-ret_est
	keep permno date model abr0 abr
	append using "$crspd\abr"
	save "$crspd\abr", replace
}

* d<0
loc d2=1 // to +d2 day
forvalues i=1/`d2' {
	use "$crspd\est", clear
	drop if _model_==""
	encode _model_, g(model)
	drop _model_
	sort permno date model
	order permno date model
	replace date=date+2 if (1<=6-dow(date) & 6-dow(date)<=`i')
	replace date=date+`i'	
	merge n:n permno date using "$crspd\crspdaily"
	sort permno date model
	keep if model~=.
	drop _merge
	merge n:n date using "$crspd\ff"
	sort permno date model
	keep if _merge==3
	drop _merge
	gen ret_est0 = rf+mktrf_c*mktrf if model==1
	gen ret_est = intercept+rf+mktrf_c*mktrf if model==1
	replace ret_est0 = rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml if model==2
	replace ret_est = intercept+rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml if model==2
	replace ret_est0 = rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml+umd_c*umd if model==3
	replace ret_est = intercept+rf+mktrf_c*mktrf+smb_c*smb+hml_c*hml+umd_c*umd if model==3
	gen abr0 = retx-ret_est0
	gen abr = retx-ret_est
	keep permno date model abr0 abr
	append using "$crspd\abr"
	save "$crspd\abr", replace
}

use "$crspd\abr", clear
sort permno date model
drop if (model==model[_n-1] & permno==permno[_n-1] & date==date[_n-1])
duplicates drop
save "$crspd\abr", replace

******

use "$crspd\abr", clear
sort model permno date
replace abr0 = abs(abr0)
replace abr = abs(abr)
g q = yq(year(date),quarter(date))
* model 1
preserve
keep if model==1
xtset permno date
egen car0= mean(abr0), by(permno q)
egen car= mean(abr), by(permno q)
drop if annouce==.
save "$cleandata\car2", replace
restore
* model 2
preserve
keep if model==2
xtset permno date
egen car0= mean(abr0), by(permno q)
egen car= mean(abr), by(permno q)
drop if annouce==.
append using "$cleandata\car2"
save "$cleandata\car2", replace
restore
* model 3
preserve
keep if model==3
xtset permno date
egen car0= mean(abr0), by(permno q)
egen car= mean(abr), by(permno q)
drop if annouce==.
append using "$cleandata\car2"
save "$cleandata\car2", replace
restore

use "$cleandata\car2", clear
sort permno date model
ren abr abrx
ren car carx
ren abr0 abr
ren car0 car
reshape wide abrx abr carx car, i(permno date) j(model)
label var car1 "CAPM-adjusted [-1,+1] CAR w/ substracting intercept" 
label var carx1 "CAPM-adjusted [-1,+1] CAR w/o substracting intercept" 
label var abr1 "CAPM-adjusted ABR w/ substracting intercept" 
label var abrx1 "CAPM-adjusted ABR w/o substracting intercept" 
label var car2 "FF-adjusted [-1,+1] CAR w/ substracting intercept" 
label var carx2 "FF-adjusted [-1,+1] CAR w/o substracting intercept" 
label var abr2 "FF-adjusted ABR w/ substracting intercept" 
label var abrx2 "FF-adjusted ABR w/o substracting intercept" 
label var car3 "CS-adjusted [-1,+1] CAR w/ substracting intercept" 
label var carx3 "CS-adjusted [-1,+1] CAR w/o substracting intercept" 
label var abr3 "CS-adjusted ABR w/ substracting intercept" 
label var abrx3 "CS-adjusted ABR w/o substracting intercept" 
ren date anndats
save "$cleandata\car3", replace


