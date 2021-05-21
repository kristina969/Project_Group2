

*1)	download the required COMPUSTAT FUNDA data from WRDS;

libname homework 	"/home/u54560152/sasuser.v94/Homework";

*generate numbers from 1 to 9999;
Data homework.numbers;
	do i= 1 to 9999;
	i = i;
	OUTPUT;
	end;
run;


*match the sich codes to the FFI48-codes using the SAS-Macro, drop numbers that are not sich codes;
%include '/home/u54560152/sasuser.v94/Homework/Macro FFI48.sas';

Data homework.matching;
	set homework.numbers;
	%FFI48(i);
	if missing(FFI48) then delete;
	rename i = sich;
run;


  %let wrds=wrds.wharton.upenn.edu 4016;
  options comamid=TCP remote=WRDS netencryptalgorithm=" ";
  SIGNON user='***' password='****';      
  %SYSLPUT _ALL_; 
  RSUBMIT;
  


  
  /* Create a dataset in the work directory */
data funda (keep= GVKEY IID DATADATE FYEAR SICH CSHO PRCC_F IB SPI CEQ ACT CHE LCT DLC AT IVAO LT DLTT IVST PSTK SALE DVC HouDate HouYear);
    set compd.funda;
    
    
    where indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C';
     
    HouDate = intnx("month", datadate, +3, "E");
    
	if month(HouDate) >= 7 then HouYear = year(HouDate) + 1; else HouYear = year(HouDate);
	if mdy(07,01,1995) <= HouDate <= mdy(06,30,2019);
	*if 2999 <= sich <= 3510;
	*if 21 <= FFI48 <= 30;
	
	format HouDate DDMMYY10.;
	format DataDate DDMMYY10.; *give a proper format;

run;


 PROC DOWNLOAD data=funda out=funda;
 RUN;
  
  
  * Close remote connection            ;        
  ENDRSUBMIT;
  SIGNOFF;
  QUIT;
  
    *save dataset;
  Data homework.funda;
  	SET WORK.funda;
  run;
 
 *sort before matching;
 
 proc sort data = homework.funda;
	by gvkey datadate;
run;

 
  proc sql;
	create table homework.matched as
	select	a.*,
			b.FFI48

	from	homework.funda a
	join	homework.matching b

	on a.sich = b.sich;
quit; 


	
proc sort data = homework.matched;
	by gvkey datadate FFI48;
run;



* retain only the companies with industry Code 21:30;
data homework.funda;
	set homework.matched;
	if 21 <= FFI48 <= 30;
run;
  
   * Inspect dataset;
proc contents data = homework.funda order = varnum;
run;

*check for duplicates;
proc sort data = homework.funda out = temp nouniquekeys;
	by gvkey datadate;
run;

  
*2)	You need expected earnings, in order to calculate the profitability and growth measures 
in the above regression equation. 
o	To obtain expected earnings, compute one-year ahead earnings forecast for the years 2000 to 2018
 (HouYear), in line with the approach used in the tutorials. 
o	However, instead of using the model by HVZ (2012), use the RI model by Li and Mohanram (2014);

*******************************Create new variables:******************************************;
data homework.funda2;
    set homework.funda;
    
    Bkeq =ceq/csho; label Bkeq="Book Value of Equity per share";
    
    
    WC = ((ACT-CHE)-(LCT-DLC));label WC= "Working capital ";
    NCO= ((AT-ACT-IVAO)-(LT-LCT-DLTT)); label NCO= "Net non-current operating assets";
    FIN = ((IVST+IVAO)-(DLTT+DLC+PSTK)); label FIN= "Net Financial Assets";
    
    Earn = ib-spi; label Earn = "Firm level earnings";
    
run;	


* Lag variables needed for change-ratios to calculate total accrulals;

proc sql;
	create table homework.funda3 as
	select	a.*,
			b.WC as L1_WC label = " Lagged working capital",
			b.NCO as L1_NCO label = " Lagged Net non-current operating assets",
			b.FIN as L1_FIN label = " Net Financial Assets",
			b.Bkeq as L1_Bkeq label = "Lagged Book value of equity"

	from 		homework.funda2  as a
	left join 	homework.funda2  as b

	on a.gvkey = b.gvkey
	and a.HouYear = b.HouYear +1
	order by gvkey, houdate;
quit;

*calculate total accrulals;

Data homework.funda3;
	set homework.funda3;
	TACC = ((WC -L1_WC) + (NCO-L1_NCO) + (FIN-L1_FIN))/csho; 
	label TACC= "Total Accrulals per share";

run;


* Get forward earnings for regression;
proc sql;
	create table homework.funda4 as
	select	a.*,
			b.Earn as F1_Earn label = " Forward Firm level earnings"

	from 		homework.funda3 as a
	left join 	homework.funda3 as b

	on a.gvkey = b.gvkey
	and a.HouYear = b.HouYear - 1;
quit;

*per share earnings;

Data homework.funda5;
	set homework.funda4;
	F1_Earn_share = F1_Earn/csho;  label F1_Earn_share= "Forward earnings per share";
	Earn_share = Earn/csho; label Earn_share = "Earnings per share";
run;



* Winsorize variables annualy for Obs with complete data;

*first make sure that you only keep observations without missing variables;

data homework.funda6;
	set homework.funda5;

	if not(missing(F1_Earn_share));
	if not(missing(TACC));
	if not(missing(Bkeq));
	if not(missing(Earn_share));
run;

%MACRO Winsorize(var=,yearvar=, dataset=);
         
     PROC SORT DATA= &dataset;
        BY &yearvar.;
     RUN;
  
     PROC MEANS DATA=&dataset. P1 P99 NOPRINT;
        VAR &var.;
        BY &yearvar.;
        OUTPUT OUT=_1_win_ranges p1(&var)=&var._p1 p99(&var.)=&var._p99;
     RUN;
  
     DATA &dataset.;
        MERGE &dataset. _1_win_ranges (KEEP= &yearvar. &var._p1 &var._p99);
        BY &yearvar.;
     RUN;
  
     DATA &dataset. (DROP= &var._p1 &var._p99 );
        SET &dataset.;
  
        IF      not(missing(&var.)) AND &var. < &var._p1  THEN &var._w = &var._p1;
        ELSE IF not(missing(&var.)) AND &var. > &var._p99 THEN &var._w = &var._p99;
        ELSE    &var._w = &var.;
  
     RUN;

%MEND;  

*alternative: write the macro in a separate file and include it wit %INCLUDE path;

%Winsorize(var = F1_Earn_share, yearvar=houyear, dataset=homework.funda6);
%Winsorize(var = TACC, yearvar=houyear, dataset=homework.funda6);
%Winsorize(var = Bkeq, yearvar=houyear, dataset=homework.funda6);
%Winsorize(var = Earn_share, yearvar=houyear, dataset=homework.funda6);


* Create both dummy variable for  negative earnings;
data homework.funda6;
	set homework.funda6;
	
	if Earn_share< 0 then NegE = 1; else NegE = 0;
	if earn_share_w< 0 then NegE_w = 1; else NegE_w = 0;
run;

*Create interaction term;
data homework.funda6;
	set homework.funda6;
	INT = NegE*Earn_share; label INT_w = "Interaction term winsorized";
	INT_w = NegE_w*Earn_share_w; label INT_w = "Interaction term";	
run;



* Create a Macro to run a rolling regression. i.e. run yearly regressions from 2000 to 2018 using
the last ten years of data. Save the yearly coefficients in one dataset.;

%Macro RIRollReg;
	
	%do i = 2000 %to 2018;

		proc reg data = homework.funda6 outest = _1_reg_parms_&i. tableout noprint;
			where %eval(&i. - 8) <= HouYear <= &i.; 
			model F1_Earn_share_w = NegE_w Earn_share_w INT_w Bkeq_w TACC_w;
		quit;

		data _1_reg_parms_&i.;
			retain HouYear; 
			set _1_reg_parms_&i.;
			HouYear = %eval(&i. + 1);
		run;

	%end;
*create a combined dataset  --> by using the ":" she should combine all the datasets that 
start with _1_reg_parms_;
	data homework._1_reg_parms_;
		set _1_reg_parms_:;
	run;

%Mend;

%RIRollReg;

*Use coefficients obtained from rolling regression to generate earnings  forecasts;
  	
proc sql;
	create table homework.earnings_forecast as
	select	a.gvkey,
			a.iid,
			a.datadate,
			a.fyear,
			a.HouDate,
			a.HouYear,
			a.F1_Earn_share,
			b.intercept + a.NegE * b.NegE_w + a.Earn_share * b.Earn_share_w + a.INT * b.INT_w+ a.Bkeq* b.Bkeq_w+ a.TACC * b.TACC_w as earn_fc

	from 		homework.funda6 	as a
	join	    homework._1_reg_parms_		as b

	on a.HouYear = b.HouYear
	and b._TYPE_ = "PARMS";
quit;


*Compute descriptive statistics (N, mean, median, standard deviation) for the forecasts;

proc means data=homework.earnings_forecast N mean median std;
	var earn_fc;
	class HouYear;
	OUTPUT OUT= descriptive_statistics;
run;


*	Generate an output table (variable as row and statistics as columns) and export it to 
an XLSX-file named ‘EmpFin21_GroupNumber_Task1’;


PROC TRANSPOSE DATA=descriptive_statistics
	OUT=descriptive_statistics_trans;
BY HouYear;
id _stat_;
VAR earn_fc;
RUN;



  
proc export data = descriptive_statistics
			outfile = "/home/u54560152/sasuser.v94/Homework/EmpFin21_GroupNumber_Task1" 
			dbms= xlsx 
			replace;
run;
