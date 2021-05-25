*3)	 You now have all data needed to calculate the regression variables. 

o	Merge the earnings forecasts and the risk measure with the required FUNDA data for
 your respective industry. 
 

o	Compute descriptive statistics (N, mean, median, standard deviation) for all regression
 variables, generate an output table (variables as rows and statistics as columns) and export
 it as an XLSX-file named ‘EmpFin21_GroupNumber_Task3’.;
 
 *HouYear :30.06 --> take the stock price data also from June the same year;
 
 libname homework "/home/u54560152/sasuser.v94/Homework";

* Merge the earnings forecasts and the risk measure (beta);
 proc sql;
	create table homework.model_variables as
	select	a.*,
			b.beta,
			b.gvkey,
			b.datadate,
			b.year,
			b.iid,
			b.tic
			

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
			b.Earn,
			b.lt,
			b.csho,
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

*o	Keep only firm-years with complete data for all variables.;

data homework.model_variables_2;
	set homework.model_variables_2;

	if not(missing(at));
	if not(missing(dvc));
	if not(missing(Earn));
	if not(missing(lt));
	if not(missing(csho));
	if not(missing(PRCC_F));
	if not(missing(sale));
	if not(missing(earn_fc));
	if not(missing(beta));
	
run;

data homework.model_variables_2;
	set homework.model_variables_2;
	earn_share = earn/chso; label= "Earnings per share";
run;

 
*Further, use statistical criteria, i.e., the interquartile range, to detect and correct 
(i.e., not delete) mild outliers annually. -
Mild outlier: if observation falls outside [Q1 – 1.5 ∙ IQR, Q3 + 1.5 ∙ IQR];

%MACRO Outliers(var=,yearvar=, dataset=);
         
     PROC SORT DATA= &dataset;
        BY &yearvar.;
     RUN;
  
     PROC MEANS DATA=&dataset. NOPRINT;
        VAR &var.;
        BY &yearvar.;
        OUTPUT OUT=_1_out_ranges p25(&var)=&var._p25 p75(&var.)=&var._p75;
     RUN;
  
     DATA &dataset.;
        MERGE &dataset. _1_out_ranges (KEEP= &yearvar. &var._p25 &var._p75);
        BY &yearvar.;
     RUN;
  
     DATA &dataset. (DROP= &var._p25 &var._p75 );
        SET &dataset.;
        IQR = &var._p25-&var._p75;
  
        IF &var. < &var._p25 – 1.5 * IQR THEN &var._m = .;
		ELSE IF &var. > &var._p75 + 1.5 * IQR THEN &var._m = .;
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



***************Task4***************************************************************
*4)	Next, you want to verify the hypothesis for the firms in your industry using a rolling regression approach. 
o	Run the regressions annually for years 2009 to 2018 (HouYear) with a rolling 10-year window. 
o	Save the yearly coefficients and t-statistics in a dataset.
o	To assess the regressions, generate a table with the mean coefficient and t-statistic for each variable 
(variables as rows and coefficient/t-statistic as columns) and export it as an XLSX-file named 
‘EmpFin21_GroupNumber_Task4’.;


* Create a Macro to run a rolling regression. i.e. run yearly regressions from 2009 to 2018 using
the last ten years of data. Save the yearly coefficients in one dataset.;

%Macro RIRollReg2;
	
	%do i = 2009 %to 2018;

		proc reg data = homework.model_variables_2 outest = _2_reg_parms_&i. tableout noprint;
			where %eval(&i. - 8) <= HouYear <= &i.; 
			model F1_Earn_share_w = NegE_w Earn_share_w INT_w Bkeq_w TACC_w;
		quit;

		data _2_reg_parms_&i.;
			retain HouYear; 
			set _2_reg_parms_&i.;
			HouYear = %eval(&i. + 1);
		run;

	%end;
*create a combined dataset  --> by using the ":" she should combine all the datasets that 
start with _1_reg_parms_;
	data homework._2_reg_parms_;
		set _2_reg_parms_:;
	run;

%Mend;

%RIRollReg;









