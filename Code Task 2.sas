********************************************
********************Task 2 *****************   									
********************************************;



libname homework "/home/u54560152/sasuser.v94/Homework";



/*Risk Measure computation*/

* We define macro to calculate BETA based on CAPM model using the  data from compd.secm and 
ff.factors_monthly;

  %let wrds=wrds.wharton.upenn.edu 4016;
  options comamid=TCP remote=WRDS netencryptalgorithm=" ";
  SIGNON user='kzhupuno' password='!Milena20152015';      
  %SYSLPUT _ALL_; 
  RSUBMIT;
  

  

     %MACRO CAPM_BETA (START=,END=,WINDOW=,MINWIN=,OUTSET=);

                                                                    

        PROC SQL;
           CREATE TABLE __comp1
           AS SELECT a.gvkey, 
                     a.iid, 
                     a.tic,
                     a.datadate,
                     f.rf                                                  "Monthly risk free return", 
                     f.mktrf                                 AS xRm        "Monthly market excess return", 
                     a.trt1m/100                             AS ret        "Monthly stock return",
                     (a.trt1m/100-f.rf)                      AS xRi        "Monthly stock excess return",   
                     (abs((a.trt1m/100-f.rf)*(f.mktrf))>=0)  AS non_miss   "non-missing indicator"

           FROM      compd.secm         (WHERE = (intnx('month',"&START."D,-&WINDOW.,'E')<=datadate<="&END."D))   AS a 

           LEFT JOIN ff.FACTORS_Monthly (WHERE = (intnx('month',"&START."D,-&WINDOW.,'E')<=date    <="&END."D))   AS f
             ON intnx('month',a.datadate,0,'E') = intnx('month',f.date,0,'E')

           ORDER BY  a.gvkey, a.iid, a.datadate;
        QUIT;

                                                                   * Delete duplicate observations;
        PROC SORT DATA=__comp1 NODUPKEYS;
           BY gvkey iid datadate;
        RUN;
        
        


                                                               * Apply rolling window to calculate;
                                                                       * variances and covariances;

        PROC SQL; 
          CREATE TABLE __comp2
          AS SELECT a.*,
                    AVG(b.xRm**2)    - AVG(b.xRm)**2           AS Var_xRm,
                    AVG(b.xRm*b.xRi) - AVG(b.xRm)*AVG(b.xRi)   AS CoVar_xRm_xRi,
                    sum(b.non_miss)                            AS n_obs

          FROM       __comp1 AS a

          LEFT JOIN  __comp1 AS b
            ON    a.gvkey = b.gvkey
        	  AND a.iid   = b.iid
        	  AND intnx('month',a.datadate,-(&WINDOW.-1),'E') <= intnx('month',b.datadate,0,'E') <= intnx('month',a.datadate,0,'E')

          GROUP BY a.gvkey, a.iid, a.datadate
          HAVING b.datadate = a.datadate;
        QUIT; 
                                                         
                                                                                 * Calculate Betas;   
        DATA &OUTSET. (DROP= non_miss);
           SET __comp2;
           WHERE "&START."D <= datadate <= "&END."D;

           IF n_obs >= &MINWIN. THEN beta = CoVar_xRm_xRi / Var_xRm;

           FORMAT beta: comma8.2 ret rf xR: percentn9.3;
        RUN;

  
     %MEND;
     
     *Execute the macro for the months between January 2000 and December 2018, using a window of 60 months (minimum of 36 months).;

     %CAPM_BETA (START=01JAN2000, 
                 END=31DEC2018,
                 WINDOW=60,
                 MINWIN=36,
                 OUTSET=__capm_beta_compustat);
                 
 PROC DOWNLOAD data=__capm_beta_compustat out=__capm_beta_compustat;
 RUN;

 ENDRSUBMIT;
 SIGNOFF;
 QUIT;
 
 

 
 *Save the dataset in the homework folder;
 Data homework.__capm_beta_compustat;
 set work.__capm_beta_compustat;
 run;
 
 
 
 *Keep only observation were beta was calculated successfully (for some  observations we don't 
 have  both the market-return and the stock return and we cant't calculate beta);
 data homework.__capm_beta_compustat;
			set homework.__capm_beta_compustat;
			if not(missing(beta));
run;


 *We want to retain only the betas for the industreies 21-30;
 
 *We generate a dummy table containing the numbers from 1 to 9999 that will account for the sic-codes;
Data homework.numbers_task2;
	do i= 1 to 9999;
	i = i;
	OUTPUT;
	end;
run;

 * we match the sich codes to the FFI48-codes using the SAS-Macro, drop numbers that don't represent sic codes;
 
%include '/home/u54560152/sasuser.v94/Homework/Macro FFI48.sas';



Data homework.matching_task2;
	set homework.numbers_task2;
	%FFI48(i);
	if missing(FFI48) then delete;
	rename i = sic;
run;

*convert the sic-codes into numerical variables;

data homework.sic_codes;
set homework.sic_codes;
sic_num = input(sic, 8.);
run;

*sort before matching;
proc sort data = homework.sic_codes;
	by gvkey datadate;
run;




*sic_codes is a table that we manually downloaded from the WRDS compd.secm-database, because 
using the remote conenction we were not able to include the sic-codes to the dataset;

*match the FFI48-codes to the sic-codes;

 proc sql;
	create table homework.matched_betas as
	select	a.*,
			b.FFI48

	from	homework.sic_codes a
	join	homework.matching_task2 b
    
	on a.sic_num = b.sic;
quit; 



proc sort data = homework.matched_betas;
	by gvkey datadate FFI48;
run;

*match the FFI48 codes to the dataset containing the betas;
proc sql;
	create table homework.betas as
	select	a.*,
		    b.SIC,
            b.FFI48

	from		homework.__capm_beta_compustat as a
	left join	homework.matched_betas as b

	on a.gvkey = b.gvkey
	and a.iid = b.iid
	and a.datadate = b.datadate;
quit; 



proc sort data = homework.betas;
	by gvkey datadate;
run;

*retain only the stocks with Fama French industry identifiers 21-30;

data homework.betas;
	set homework.betas;
	if 21 <= FFI48 <= 30;
	month = month(datadate);
	year = year(datadate);
run;


*Compute descriptive statistics (N, mean, median, standard deviation) for the CAPM betas 
in your industry;


proc means data=homework.betas N mean median std;
	var beta;
	class year;
	OUTPUT OUT= descriptive_statistics_betas;
run;

*transpose to obtain the variables as row ans statistics as columns;

PROC TRANSPOSE DATA=descriptive_statistics_betas
	OUT=descriptive_statistics_betas_t;
	BY year;
	id _stat_;
	VAR beta;
RUN;

*export the descriptive statistics to an XLSX-file;

proc export data = descriptive_statistics_betas_t
			outfile = "/home/u54560152/sasuser.v94/Homework/EmpFin21_Group2_Task2" 
			dbms= xlsx 
			replace;
run;




 



 
 
 
 
 

 