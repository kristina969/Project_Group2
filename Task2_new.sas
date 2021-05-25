libname homework "/home/u37603408/sasuser.v94/Homework";

  %let wrds=wrds.wharton.upenn.edu 4016;
  options comamid=TCP remote=WRDS netencryptalgorithm=" ";
  SIGNON user='azellner' password='Wimeovdc1337wrds';      
  %SYSLPUT _ALL_; 
  RSUBMIT;
  
  

                                           * Define your own macro to calculate BETA;
                                                                           * (based on CAPM model);

     %MACRO CAPM_BETA (START=,END=,WINDOW=,MINWIN=,OUTSET=);

                                                                   * retrieve data from compd.secm;
                                                                          * and ff.factors_monthly;   

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

     %CAPM_BETA ( START=01JAN2000, 
                    END=31DEC2018,
                 WINDOW=60,
                 MINWIN=36,
                 OUTSET=__capm_beta_compustat);
                 
 PROC DOWNLOAD data=__capm_beta_compustat out=__capm_beta_compustat;
 RUN;

 ENDRSUBMIT;
 SIGNOFF;
 QUIT;
 
 
 Data homework.__capm_beta_compustat;
 set work.__capm_beta_compustat;
 run;
 
 
 
 Data homework.numbers_task2;
	do i= 1 to 9999;
	i = i;
	OUTPUT;
	end;
run;


%include '/home/u37603408/sasuser.v94/Homework/Macro_FFI48.sas';

Data homework.matching_task2;
	set homework.numbers_task2;
	%FFI48(i);
	if missing(FFI48) then delete;
	rename i = sic;
run;




*sic_codes datei  voeher manuell aus WRDS herunterladen!!!;

data homework.sic_codes;
set homework.sic_codes;
sic_num = input(sic, 8.);
run;

proc sort data = homework.sic_codes;
	by gvkey datadate;
run;



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


data homework.betas;
	set homework.betas;
	if 21 <= FFI48 <= 30;
run;


*Compute descriptive statistics (N, mean, median, standard deviation) for the CAPM betas 
in your industry, generate an output table (variable as row and statistics as columns) and 
export it to an XLSX-file named ‘EmpFin21_GroupNumber_Task2’.;





 



 
 
 
 
 

 
