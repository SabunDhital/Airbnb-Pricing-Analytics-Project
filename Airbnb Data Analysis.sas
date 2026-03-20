/*Airbnb Salem Oregon Analysis*/
/*Sabun Dhital*/

/*Importing required data*/
FILENAME REFFILE '/home/u64128365/DSCI_519/listings.xlsx';

PROC IMPORT DATAFILE=REFFILE
    DBMS=xlsx
    OUT=WORK.Listings;  
    GETNAMES=YES;
RUN;

/* Analyzing the data content overview */
PROC CONTENTS DATA=WORK.LISTINGS;
RUN;

/*Creating geographical map for seeing the location wise distribution of Airbnb in Salem*/
ODS GRAPHICS / RESET WIDTH=6.4in HEIGHT=4.8in;

PROC SGMAP plotdata=WORK.Listings;
    openstreetmap;
    scatter x=longitude y=latitude / 
markerattrs=(size=3 symbol=circle);
RUN;

ODS GRAPHICS / RESET;

/* Larger map with better legend */
ODS GRAPHICS / RESET WIDTH=6.4in HEIGHT=4.8in;
PROC SGMAP plotdata=WORK.Listings;
    TITLE "Airbnb Listings Distribution Across Wards";
    openstreetmap;
    scatter x=longitude y=latitude / 
    group=neighbourhood_cleansed
    name="scatterPlot" 
    markerattrs=(size=5 symbol=circle);
    keylegend "scatterPlot" /
    title='Ward';
RUN;

ODS GRAPHICS / RESET;


/* Target Variable Price distribution analysis*/
DATA WORK.Listings_Clean;
    SET WORK.Listings;
    price_numeric = INPUTN(price, 'DOLLAR12.2');
    DROP price;
    RENAME price_numeric = price;
RUN;


/*Performing statistical analysis and plotting histogram for distribution analysis*/
PROC UNIVARIATE DATA=WORK.Listings_Clean;
    VAR price;
    HISTOGRAM;
    TITLE "Price Distribution";
RUN;

/* Performing log transformation since the data was highly skewed */
DATA WORK.Listings_Clean;
    SET WORK.Listings_Clean;
    WHERE 30 <= price <= 475;
    log_price = LOG(price);
RUN;


/* Performing further statistical analysis and plotiing histogram after log transformation */
PROC UNIVARIATE DATA=WORK.Listings_Clean;
    VAR log_price;
    HISTOGRAM log_price;
    TITLE "Log-Transformed Price Distribution";
RUN;

/*Checking distribution of host_listings_count*/
PROC UNIVARIATE DATA=WORK.Listings_Clean;
    VAR host_listings_count;
    HISTOGRAM;
    TITLE "Skewness Analysis for Host Listings Count";
RUN;


DATA WORK.Listings_Clean;
   SET WORK.Listings_Clean;
    poly_accom = accommodates**2;
    
    poly_min = minimum_nights**2;
    
   
    poly_max = maximum_nights**2;
    
    poly_avail = availability_365**2;
    
    log_host_listings = LOG(host_total_listings_count + 1);
    
RUN;


/* Verify new featured varaibles */
TITLE "Summary Statistics of NEW Engineered Features";
PROC MEANS DATA=WORK.Listings_Clean N NMISS MEAN STD MIN MAX;
    VAR beds_per_accom bath_per_accom
        poly_accom poly_min poly_max poly_avail 
        log_host_listings;
RUN;

/*Investigating Numeric data with PROC MEANS*/
PROC MEANS DATA=WORK.Listings_Clean (KEEP=_NUMERIC_) 
           N NMISS MIN MAX MEAN MEDIAN STD;
    TITLE "Summary Statistics of all numerical variables";
RUN;

/*Investigating Character variables*/
PROC FREQ DATA=WORK.Listings_Clean;
    TABLES neighbourhood_cleansed room_type property_type
           host_is_superhost instant_bookable has_availability ;
    TITLE "Missing Values - Categorical Variables";
RUN;

DATA WORK.Listings_Clean;
    SET WORK.Listings_Clean;
    
    /* Create bedroom groups */
    IF bedrooms <= 1 THEN bedroom_group = '0-1 Bedroom';
    ELSE IF bedrooms <= 3 THEN bedroom_group = '2-3 Bedrooms';
    ELSE IF bedrooms <= 5 THEN bedroom_group = '4-5 Bedrooms';
    ELSE bedroom_group = '6+ Bedrooms';
    
    /* Create bathroom groups */
    IF bathrooms <= 1 THEN bathroom_group = '0-1 Bath';
    ELSE IF bathrooms <= 3 THEN bathroom_group = '2-3 Baths';
    ELSE bathroom_group = '4+ Baths';
    
    /* Create bed groups */
    IF beds <= 1 THEN beds_group = '0-1 Beds';
    ELSE IF beds <= 2 THEN beds_group = '2 Beds';
    ELSE IF beds <= 4 THEN beds_group = '3-4 Beds';
    ELSE beds_group = '5+ Beds';
    
    /* Clean and group property types */
    property_type_clean = STRIP(LOWCASE(property_type));

    IF property_type_clean IN ('entire home', 'entire rental unit', 
                               'entire guest suite', 'entire guesthouse',
                               'entire condo', 'entire townhouse',
                               'entire loft', 'entire cottage',
                               'entire bungalow', 'entire place',
                               'entire vacation home') THEN 
        property_cat = 'Entire_Place';
    ELSE IF property_type_clean IN ('private room in home',
                                    'private room in rental unit',
                                    'private room in townhouse',
                                    'private room') THEN 
        property_cat = 'Private_Room';
    ELSE IF property_type_clean IN ('room in hotel', 'hotel room') THEN 
        property_cat = 'Hotel_Commercial';
    ELSE IF property_type_clean IN ('tiny home', 'camper/rv', 'yurt', 'tent') THEN 
        property_cat = 'Specialty_Stay';
    ELSE IF MISSING(property_type_clean) THEN 
        property_cat = 'Unknown';
    ELSE 
        property_cat = 'Other';

    DROP property_type_clean;
RUN;

/* Beds per accommodation */
DATA WORK.Listings_Clean;
    SET WORK.Listings_Clean;

    IF beds NOT IN (., 0) THEN
        beds_per_accom = accommodates / beds;
    ELSE beds_per_accom = 0;
    
    /* Bathrooms per accommodation - key feature from rubric */
    IF bathrooms NOT IN (., 0) THEN
        bath_per_accom = accommodates / bathrooms;
    ELSE bath_per_accom = 0;


DATA WORK.Listings_Clean;
    SET WORK.Listings_Clean; 
    IF neighbourhood_cleansed IN ('Ward 1', 'Ward 2') 
        THEN ward_type = 'Urban';
    
    ELSE IF neighbourhood_cleansed IN ('Ward 7', 'Ward 8') 
        THEN ward_type = 'Residential';
    
    ELSE IF neighbourhood_cleansed IN ('Ward 3', 'Ward 4', 'Ward 5', 'Ward 6') 
        THEN ward_type = 'Sub-Urban';
RUN;


/* Verify grouped categories */
PROC FREQ DATA=WORK.Listings_Clean;
    TABLES bedroom_group bathroom_group beds_group property_cat ward_type ;
    TITLE "Frequency of Engineered Features";
RUN;

/* Define model variables */
%let model_vars = availability_365
                  log_host_listings 
                  beds_per_accom bath_per_accom
                  poly_accom poly_min poly_max ;
                  

%PUT &model_vars;

/* Correlation Matrix */
TITLE "Correlation Matrix - Model Variables Only";
ODS GRAPHICS ON / WIDTH=10in HEIGHT=10in;

PROC CORR DATA=WORK.Listings_Clean PLOTS=matrix(histogram);
    VAR &model_vars.;
RUN;

/* VIF Analysis */
PROC REG DATA=WORK.Listings_Clean PLOTS=ALL;
    MODEL log_price = &model_vars. / 
          SELECTION=FORWARD VIF COLLIN;
RUN;
QUIT;

/* VIF with Categorical Variables */
TITLE "VIF Analysis - Full Model with Categorical Variables";

PROC GLMSELECT DATA=WORK.Listings_Clean 
    OUTDESIGN(ADDINPUTVARS)=Work.design_matrix;
    CLASS ward_type property_cat room_type bedroom_group bathroom_group
          host_is_superhost / PARAM=GLM;
    MODEL log_price = ward_type property_cat room_type bedroom_group bathroom_group
                      &model_vars. host_is_superhost / 
          selection=none;
RUN;

PROC REG DATA=Work.design_matrix;
    MODEL log_price = &_GLSMOD. / VIF COLLIN TOL;
RUN;
QUIT;

ODS GRAPHICS OFF;

/*Train and Test Split*/
PROC SURVEYSELECT DATA=WORK.Listings_Clean 
    SAMPRATE=0.80 
    SEED=42
    OUT=WORK.Full_Data 
    OUTALL 
    METHOD=SRS;
RUN;

DATA WORK.Train WORK.Test;
    SET WORK.Full_Data;
    IF Selected=1 THEN OUTPUT WORK.Train;
    ELSE OUTPUT WORK.Test;
RUN;

/* Verify split */
PROC FREQ DATA=WORK.Train;
    TABLES Selected;
    TITLE "Training Sample Verification";
RUN;

PROC FREQ DATA=WORK.Test;
    TABLES Selected;
    TITLE "Test Sample Verification";
RUN;


/* LASSO MODEL*/
%let lasso_var = ward_type property_cat room_type bedroom_group bathroom_group
                 accommodates minimum_nights maximum_nights availability_365
                 log_host_listings beds_per_accom bath_per_accom poly_accom poly_min poly_max poly_avail;

/* Macro to try different stopping points */
%macro doglm;
%do k=3 %to 5;
PROC GLMSELECT DATA=WORK.Train OUTDESIGN(ADDINPUTVARS)=Work.reg_design 
    PLOTS(stepaxis=normb)=all;
    CLASS ward_type property_cat room_type bedroom_group bathroom_group
          host_is_superhost / PARAM=GLM;
    MODEL log_price=&lasso_var. / selection=lasso(stop=&k choose=SBC);
    OUTPUT OUT=train_score;
    SCORE DATA=WORK.Test PREDICTED RESIDUAL OUT=test_score;
RUN;
%end;
%mend;
%doglm

/* Final LASSO model */
ODS GRAPHICS ON;

PROC GLMSELECT DATA=WORK.Train OUTDESIGN(ADDINPUTVARS)=Work.reg_design 
    PLOTS(stepaxis=normb)=all;
    CLASS ward_type property_cat room_type bedroom_group bathroom_group
          host_is_superhost / PARAM=GLM;
    MODEL log_price=&lasso_var. / selection=lasso(stop=none choose=sbc);
    OUTPUT OUT=train_score;
    SCORE DATA=WORK.Test PREDICTED RESIDUAL OUT=test_score;
RUN;

/* Calculate performance metrics for TRAIN */
DATA train_measure;
    SET train_score;  
    residual_error = log_price - p_log_price;
    squared_error = residual_error*residual_error;
    trans_price = EXP(log_price);
    trans_error = EXP(residual_error);
    squared_prediction = p_log_price*p_log_price;
    trans_predicted_price = EXP(p_log_price);  
    true_error = trans_price - trans_predicted_price;
    KEEP residual_error squared_error trans_price trans_error 
         squared_prediction trans_predicted_price true_error;  
RUN;

PROC SUMMARY DATA=train_measure;
    VAR squared_error trans_error true_error;
    OUTPUT OUT=train_sum_out SUM=;
RUN;

DATA train_rmse_sum;
    SET train_sum_out;
    RMSE = SQRT(squared_error/_FREQ_);
    trans_RMSE = SQRT(trans_error/_FREQ_);  
    true_RMSE = (true_error/_FREQ_);
RUN;

PROC PRINT DATA=train_rmse_sum; 
RUN;

/* Calculate performance metrics for TEST */
DATA measure;
    SET test_score;  
    residual_error = log_price - p_log_price;
    squared_error = residual_error*residual_error;
    trans_price = EXP(log_price);
    trans_error = EXP(residual_error);
    squared_prediction = p_log_price*p_log_price;
    trans_predicted_price = EXP(p_log_price);  
    true_error = trans_price - trans_predicted_price;
    KEEP residual_error squared_error trans_price trans_error 
         squared_prediction trans_predicted_price true_error;  
RUN;

PROC SUMMARY DATA=measure;
    VAR squared_error trans_error true_error;
    OUTPUT OUT=sum_out SUM=;
RUN;

DATA test_rmse_sum;
    SET sum_out;
    RMSE = SQRT(squared_error/_FREQ_);
    trans_RMSE = SQRT(trans_error/_FREQ_);  
    true_RMSE = (true_error/_FREQ_);
RUN;

PROC PRINT DATA=test_rmse_sum; 
RUN;

ODS GRAPHICS ON;

PROC REG DATA=Work.reg_design PLOTS(MAXPOINTS=50000);
    MODEL log_price = &_GLSMOD / SELECTION=FORWARD VIF COLLIN;
QUIT;



/* Create residual variable */
DATA train_score_diag;
    SET train_score;
    residual = log_price - p_log_price;
RUN;

/* Plot residuals histogram */
PROC SGPLOT DATA=train_score_diag;
    HISTOGRAM residual / BINWIDTH=0.1;
    DENSITY residual / TYPE=KERNEL;
    TITLE 'Normality Check: Histogram of Residuals';
RUN;

/* Plot residuals vs predicted */
PROC SGPLOT DATA=train_score_diag;
    SCATTER X=p_log_price Y=residual;
    REFLINE 0 / AXIS=Y LINEATTRS=(color=red pattern=dash);
    XAXIS LABEL='Predicted Values';
    YAXIS LABEL='Residuals';
    TITLE 'Homoscedasticity: Residuals vs Predicted';
RUN;

/* INDEPENDENCE OF RESIDUALS: Standardized Residuals */
PROC SGPLOT DATA=train_score_diag;
    SCATTER X=p_log_price Y=residual;
    REFLINE -1 / AXIS=Y LINEATTRS=(color=black);
    REFLINE 1 / AXIS=Y LINEATTRS=(color=black);
    REFLINE 0 / AXIS=Y LINEATTRS=(color=red pattern=dash);
    XAXIS LABEL='Predicted Values';
    YAXIS LABEL='Residuals (Standardized)';
    TITLE 'Checking Independence: Residuals by Predicted';
RUN;

PROC UNIVARIATE DATA=train_score_diag PLOTS;
    VAR residual;
    QQPLOT / NORMAL(MU=est SIGMA=est);
    TITLE 'Q-Q Plot for Normality';
RUN;


/* Calculate R-Squared using PROC REG */
PROC REG DATA=train_score;
    MODEL log_price = p_log_price;
    TITLE "LASSO Model - R-Squared Training Data";
RUN;
QUIT;

/* Calculate R-Squared using PROC REG */
PROC REG DATA=test_score;
    MODEL log_price = p_log_price;
    TITLE "LASSO Model - R-Squared Test Data";
RUN;
QUIT;

/* DECISION TREE AND RANDOM FOREST - TRAINED ON FULL TRAINING SET            */
/* Create macro variables for numeric predictors */
PROC CONTENTS NOPRINT DATA=WORK.Train
    (KEEP=accommodates minimum_nights maximum_nights availability_365
          number_of_reviews log_host_listings beds_per_accom bath_per_accom
          poly_accom poly_min poly_max poly_avail)
    OUT=VAR_NUM (KEEP=name);
RUN;

PROC SQL NOPRINT;
    SELECT name INTO :num_vars SEPARATED BY " "
    FROM VAR_NUM;
QUIT;

/* Create macro variables for categorical predictors */
PROC CONTENTS NOPRINT DATA=WORK.Train
    (KEEP=ward_type property_cat room_type bedroom_group bathroom_group host_is_superhost)
    OUT=VAR_CAT (KEEP=name);
RUN;

PROC SQL NOPRINT;
    SELECT name INTO :cat_vars SEPARATED BY " "
    FROM VAR_CAT;
QUIT;

%PUT ========================================;
%PUT Numeric Variables: &num_vars;
%PUT Categorical Variables: &cat_vars;
%PUT ========================================;

%let path = /home/u64128365/DSCI_519;

/*=============================================================================*/
/* DECISION TREE - FULL TRAINING SET (NO INTERNAL VALIDATION)                */
/*=============================================================================*/

TITLE "Decision Tree Model - Full Training Set";
ODS GRAPHICS ON;

PROC HPSPLIT DATA=WORK.Train SEED=786;
    CLASS &cat_vars;
    MODEL log_price = &num_vars &cat_vars;
    /* REMOVED: PARTITION FRACTION - Using full training set */
    OUTPUT OUT=tree_train_scored;
    CODE FILE="&path./hpsplexc.sas";
RUN;

/* Score TRAINING data */
DATA tree_train_eval;
    SET tree_train_scored;
    residual_sq = (P_log_price - log_price)**2;
RUN;

/* Score TEST data */
DATA tree_test_scored;
    SET WORK.Test;
    %INCLUDE "&path./hpsplexc.sas";
RUN;

DATA tree_test_eval;
    SET tree_test_scored;
    residual_sq = (P_log_price - log_price)**2;
RUN;

/* Calculate RMSE */
PROC SQL NOPRINT;
    SELECT SQRT(MEAN(residual_sq)) AS RMSE_train
    INTO :RMSE_train_tree
    FROM tree_train_eval;
    
    SELECT SQRT(MEAN(residual_sq)) AS RMSE_test
    INTO :RMSE_test_tree
    FROM tree_test_eval;
QUIT;


%PUT Decision Tree;
%PUT   Training RMSE: &RMSE_train_tree;
%PUT   Test RMSE:     &RMSE_test_tree;


/* RANDOM FOREST - FULL TRAINING SET   */

TITLE "Random Forest Model - Full Training Set";

PROC HPFOREST DATA=WORK.Train
    MAXTREES=300 VARS_TO_TRY=7
    SEED=42
    /* REMOVED: TRAINFRACTION - Using full training set */
    MAXDEPTH=15 LEAFSIZE=10;
    TARGET log_price / LEVEL=INTERVAL;
    INPUT &num_vars / LEVEL=INTERVAL;
    INPUT &cat_vars / LEVEL=NOMINAL;
    ODS OUTPUT FITSTATISTICS=rf_train_fit;
    SAVE FILE="&path./rfmodel_fit.bin";
RUN;

/* Score TRAINING data */
PROC HP4SCORE DATA=WORK.Train;
    ID log_price;
    SCORE FILE="&path./rfmodel_fit.bin" OUT=rf_train_scored;
RUN;

/* Score TEST data */
PROC HP4SCORE DATA=WORK.Test;
    ID log_price;
    SCORE FILE="&path./rfmodel_fit.bin" OUT=rf_test_scored;
RUN;

/* Calculate RMSE */
PROC SQL NOPRINT;
    /* Training RMSE */
    SELECT SQRT(MEAN((log_price - P_log_price)**2)) AS RMSE_train
    INTO :RMSE_train_rf
    FROM rf_train_scored;
    
    /* Test RMSE */
    SELECT SQRT(MEAN((log_price - P_log_price)**2)) AS RMSE_test
    INTO :RMSE_test_rf
    FROM rf_test_scored;
QUIT;


%PUT Random Forest (Full Training):;
%PUT   Training RMSE: &RMSE_train_rf;
%PUT   Test RMSE:     &RMSE_test_rf;



PROC SQL NOPRINT;
    SELECT SQRT(MEAN((P_log_price - log_price)**2)) AS RMSE_test
    INTO :RMSE_test_tree
    FROM tree_test_scored;
QUIT;

%PUT Test RMSE: &RMSE_test_tree;
