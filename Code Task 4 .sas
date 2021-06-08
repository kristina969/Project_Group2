********************************************
********************Task 4 *****************   									
********************************************;

 libname homework "/home/u54560152/sasuser.v94/Homework";
 
*We want to verify the hypothesis for the firms in your industry using a rolling 
regression approach. 

* We create a Macro to run a rolling regression. i.e. run yearly regressions from 2009 to 2018 using
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
	
	*create a combined dataset ;

	data homework._2_reg_parms_;
		set _2_reg_parms_:;
	run;

%Mend;

%RIRollReg2;


*To assess the regressions, generate a table with the mean coefficient and t-statistic for each 
variable; 

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

*Save the yearly coefficients and t-statistics in a dataset;
data comparison;
	set parms tstat;
run;

*Transpose to get variables as rows and coefficient/t-statistic as columns; 

PROC TRANSPOSE DATA=comparison
	OUT=comparison_Task4_t;
    id statistic;
    VAR Intercept_Mean Profit_m_Mean Payout_m_Mean Growth_m_Mean Risk_m_Mean ;
RUN;

Data comparison_Task4_t;
	set comparison_Task4_t;
	drop _LABEL_;
run;

*Export it as an XLSX-file;


proc export data = comparison_Task4_t
			outfile = "/home/u54560152/sasuser.v94/Homework/EmpFin21_Group2_Task4" 
			dbms= xlsx 
			replace;
run;