*3)	 You now have all data needed to calculate the regression variables. 

- Merge the earnings forecasts and the risk measure with the required FUNDA data for
 your respective industry. 
 
- Compute descriptive statistics (N, mean, median, standard deviation) for all regression
 variables, generate an output table (variables as rows and statistics as columns) and export
 it as an XLSX-file named ‘EmpFin21_GroupNumber_Task3’.;
 
 *HouYear :30.06 --> take the stock price data also from June the same year;
 
 libname homework "/home/u54560152/sasuser.v94/Homework";

* Merge the earnings forecasts and the risk measure (beta);
 proc sql;
	create table homework.model_variables as
	select	a.*,
			b.beta
			

	from 		homework.earnings_forecast	as a
	join	    homework.betas		as b

	on a.gvkey = b.gvkey
	and a.iid = b.iid
	and a.houyear = year(b.datadate)
	and month(b.datadate) = 6;
quit;



*Merge the other required funda variables;

 proc sql;
	create table homework.model_variables_2 as
	select	a.*,
	 		b.gvkey,
	 		b.iid,
	 		b.datadate,
	 		b.houyear,
	 		b.houdate,
			b.at,
			b.dvc,
			b.Earn_share,
			b.Earn,
			b.lt,
			b.csho,
			b.CHE,
			b.PRCC_F,
			b.sale
				
			

	from 		homework.model_variables	as a
	join	    homework.funda2		as b

	on a.gvkey = b.gvkey
	and a.iid = b.iid
	and a.houyear = year(b.datadate)
	and month(b.datadate) = 6;
quit;

*o	Prepare your dataset in line with the approach used in the tutorials and calculate the 
regression variables for the years 2000 to 2018 (HouYear).;



*Keep only firm-years with complete data for all variables.;

data homework.model_variables_2;
	set homework.model_variables_2;

	if not(missing(at));
	if not(missing(dvc));
	if not(missing(Earn));
	if not(missing(Earn_share));
	if not(missing(lt));
	if not(missing(csho));
	if not(missing(PRCC_F));
	if not(missing(sale));
	if not(missing(earn_fc));
	if not(missing(beta));
	if not(missing(che));
	
run;



proc sort data = homework.model_variables_2;
	by gvkey houyear;
run;



 
*Further, use statistical criteria, i.e., the interquartile range, to detect and correct 
(i.e., not delete) mild outliers annually. -
Mild outlier: if observation falls outside [Q1 – 1.5 ∙ IQR, Q3 + 1.5 ∙ IQR];

*don't delete --> set the smaller ones equal to p25-1.5 and the larger to p75+1.5;

%MACRO Outliers(var=,yearvar=, dataset=);



	  DATA &dataset;
     	SET &dataset;
	 RUN;
         
     PROC SORT DATA= &dataset;
        BY &yearvar.;
     RUN;
  
     PROC MEANS DATA=&dataset. NOPRINT;
        VAR &var.;
        BY &yearvar.;
        OUTPUT OUT=_1_out_ranges p25(&var.)=&var._p25 p75(&var.)=&var._p75;
     RUN;
  
     DATA &dataset.;
        MERGE &dataset. _1_out_ranges (KEEP= &yearvar. &var._p25 &var._p75);
        BY &yearvar.;
     RUN;
     

  
     DATA &dataset. (DROP= &var._p25 &var._p75);
        SET &dataset.;
        IQR = &var._p75-&var._p25;
  
        IF &var. < &var._p25-1.5 * IQR THEN &var._m = &var._p25-1.5;
		ELSE IF &var. > &var._p75+1.5 * IQR THEN &var._m = &var._p75+1.5;
		ELSE &var._m = &var.; 
     RUN;

%MEND;  


%Outliers(var = at, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = dvc, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = Earn, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = Earn_share, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = lt, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = csho, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = prcc_f, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = sale, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = earn_fc, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = beta, yearvar=houyear, dataset=homework.model_variables_2);
%Outliers(var = che, yearvar=houyear, dataset=homework.model_variables_2);




*create the new regression variables;



data homework.model_variables_2;
	SET homework.model_variables_2;
	Profit_m = earn_fc_m/at_m; label Profit_m = "Profitability";
	Payout_m =dvc_m/at_m; label payout_m = "Payout";
	Growth_m = (earn_fc_m-earn_m)/earn_m;label growth_m = "Growth";
	EV_Sales_m =(csho_m*prcc_f_m+lt_m-che_m)/sale_m;label EV_Sales_m = "Enterprice value sales multipe";
	EV_Sales = (csho*prcc_f+lt-che)/sale;label EV_Sales = "Enterprice value sales multipe with outliers";
	Risk_m = Beta_m; label Risk_m = "Risk";
run;



*keep only observations for which EV_Sales exists;

data homework.model_variables_2;
	set homework.model_variables_2;

	if not(missing(EV_Sales_m));
run;
*Compute descriptive statistics (N, mean, median, standard deviation) for all regression 
variables, generate an output table (variables as rows and statistics as columns) and export 
it as an XLSX-file named ‘EmpFin21_GroupNumber_Task3’.;

proc means data=homework.model_variables_2 N mean median std;
	var EV_Sales_m Profit_m Payout_m Growth_m Risk_m;
	OUTPUT OUT= descriptive_statistics_Task3;
run;



PROC TRANSPOSE DATA=descriptive_statistics_Task3
	OUT=descriptive_statistics_Task3_t;
id _stat_;
VAR EV_Sales_m Profit_m Payout_m Growth_m Risk_m;
RUN;


proc export data = descriptive_statistics_Task3_t
			outfile = "/home/u54560152/sasuser.v94/Homework/EmpFin21_GroupNumber_Task3" 
			dbms= xlsx 
			replace;
run;



***************Task4***************************************************************
*4)	Next, you want to verify the hypothesis for the firms in your industry using a rolling 
regression approach. 
o	Run the regressions annually for years 2009 to 2018 (HouYear) with a rolling 10-year window. 
o	Save the yearly coefficients and t-statistics in a dataset.



* Create a Macro to run a rolling regression. i.e. run yearly regressions from 2009 to 2018 using
the last ten years of data. Save the yearly coefficients in one dataset.;

%Macro RIRollReg2;
	
	%do i = 2009 %to 2018;

		proc reg data = homework.model_variables_2 outest = _2_reg_parms_&i. tableout noprint;
			where %eval(&i. - 8) <= HouYear <= &i.; 
			model EV_Sales_m = Profit_m Payout_m Growth_m Risk_m;
		quit;

		data _2_reg_parms_&i.;
			retain HouYear; 
			set _2_reg_parms_&i.;
			HouYear = %eval(&i. + 1);
		run;

	%end;
*create a combined dataset  --> by using the ":" she should combine all the datasets that 
start with _2_reg_parms_;

	data homework._2_reg_parms_;
		set _2_reg_parms_:;
	run;

%Mend;

%RIRollReg2;


*To assess the regressions, generate a table with the mean coefficient and t-statistic for each 
variable (variables as rows and coefficient/t-statistic as columns) and export it as an 
XLSX-file named ‘EmpFin21_GroupNumber_Task4’.;


proc means data = homework._2_reg_parms_;
	where _type_ = "PARMS";
	var Intercept Profit_m Payout_m Growth_m Risk_m;
	output out = parms mean= /autoname;
run;

data parms (drop = _type_ _freq_);
	retain statistic;
	set parms;
	statistic = "coefficient";
run;


proc means data = homework._2_reg_parms_;
	where _type_ = "T";
	var Intercept Profit_m Payout_m Growth_m Risk_m;
	output out = tstat mean= /autoname;
run;

data tstat (drop = _type_ _freq_);
	retain statistic;
	set tstat;
	statistic = "t-statistic";
run;

data comparison;
	set parms tstat;
run;


PROC TRANSPOSE DATA=comparison
	OUT=comparison_Task4_t;
id Intercept Profit_m Payout_m Growth_m Risk_m;
VAR params tstat;
RUN;


proc export data = descriptive_statistics_Task4_t
			outfile = "/home/u54560152/sasuser.v94/Homework/EmpFin21_GroupNumber_Task4" 
			dbms= xlsx 
			replace;
run;






