********************************************
********************Task 3 *****************   									
********************************************;


 
 libname homework "/home/u54560152/sasuser.v94/Homework";
 

* Merge the earnings forecasts and the risk measure (beta);
* we use the beta coefficients as of 30.06 for the respective HouYear;
 proc sql;
	create table homework.model_variables as
	select	a.*,
			b.beta
			

	from 		homework.earnings_forecast	as a
	join	    homework.betas		as b

	on a.gvkey = b.gvkey
	and a.iid = b.iid
	and a.houyear = year(b.datadate)
	and a.houdate <= mdy(06,30,b.datadate)
	and month(b.datadate) = 6
	
	group by a.gvkey, a.HouYear
	having a.houdate = max(a.houdate); 
quit;

*delete the duplicates;

proc sort data = homework.model_variables out = homework.model_variables NODUPKEY;
	by gvkey iid datadate;
run;





*Merge the other required funda data;

 proc sql;
	create table homework.model_variables_2 as
	select	a.*,
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
	and a.houyear = year(b.datadate);
quit;





*Prepare your dataset in line with the approach used in the tutorials and calculate the 
regression variables for the years 2000 to 2018 (HouYear);



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


*sort;

proc sort data = homework.model_variables_2;
	by gvkey houyear;
run;




 /*Define outlier treatment rules*/

*We use the the interquartile range as statistical criterium to detect and correct 
(not delete) mild outliers annually.;

*Mild outlier definition: observat
ions that fall outside of [P25-1.5*IQR, P75+1.5*IQR];


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
  
        IF &var. < &var._p25-1.5 * IQR THEN &var._m = &var._p25-1.5*IQR;
		ELSE IF &var. > &var._p75+1.5 * IQR THEN &var._m = &var._p75+1.5*IQR;
		ELSE &var._m = &var.; 
     RUN;

%MEND;  

/*Macro execution*/
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


*Create the new regression variables;

data homework.model_variables_2;
	SET homework.model_variables_2;
	Profit_m = earn_fc_m/at_m; label Profit_m = "Profitability";
	Payout_m =dvc_m/at_m; label payout_m = "Payout";
	Growth_m = (earn_fc_m-earn_m)/earn_m;label growth_m = "Growth";
	EV_Sales_m =(csho_m*prcc_f_m+lt_m)/sale_m;label EV_Sales_m = "Enterprice value sales multipe";
	Risk_m = beta_m; label Risk_m = "Risk";
run;


*Keep only observations for which EV_Sales-valriable is not missing, e.g. sale_m > 0,
EV_Sales_M is missing for observations where sale_m =0;

data homework.model_variables_2;
	set homework.model_variables_2;
	if not(missing(EV_Sales_m));
run;

*Compute descriptive statistics (N, mean, median, standard deviation) for all regression 
variables, generate an output table (variables as rows and statistics as columns) and export 
it as an XLSX-file named ‘EmpFin21_GroupNumber_Task3’.;

proc means data=homework.model_variables_2 N mean median std min p25 p75 max ;
	var EV_Sales_m Profit_m Payout_m Growth_m Risk_m;
	OUTPUT OUT= descriptive_statistics_Task3;
run;



PROC TRANSPOSE DATA=descriptive_statistics_Task3
	OUT=descriptive_statistics_Task3_t;
    id _stat_;
	VAR EV_Sales_m Profit_m Payout_m Growth_m Risk_m;
RUN;


proc export data = descriptive_statistics_Task3_t
			outfile = "/home/u54560152/sasuser.v94/Homework/EmpFin21_Group2_Task3" 
			dbms= xlsx 
			replace;
run;



