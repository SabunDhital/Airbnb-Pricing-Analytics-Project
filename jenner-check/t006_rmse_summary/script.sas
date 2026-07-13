/* Mock WORK.Listings matching the column shape the pipeline reads.
   price is a $ character string because the script does INPUTN(price,'DOLLAR12.2'). */
DATA WORK.Listings;
    LENGTH price $12 neighbourhood_cleansed $12 room_type $20 property_type $30
           host_is_superhost $2 instant_bookable $2 has_availability $2;
    INFILE DATALINES DSD TRUNCOVER;
    INPUT price $ longitude latitude neighbourhood_cleansed $ room_type $
          property_type $ host_is_superhost $ instant_bookable $ has_availability $
          accommodates minimum_nights maximum_nights availability_365
          host_listings_count host_total_listings_count bedrooms bathrooms beds
          number_of_reviews;
DATALINES;
$120.00,-123.041,44.941,Ward 1,Entire home/apt,Entire rental unit,t,f,t,4,2,365,120,3,4,2,1,2,15
$85.00,-123.028,44.939,Ward 2,Private room,Private room in home,f,t,t,2,1,90,300,1,1,1,1,1,42
$210.00,-123.061,44.955,Ward 3,Entire home/apt,Entire home,t,t,t,6,3,180,60,5,7,3,2,3,8
$95.00,-123.011,44.928,Ward 4,Private room,Private room in rental unit,f,f,t,2,1,120,45,2,2,1,1,1,23
$300.00,-123.075,44.962,Ward 5,Entire home/apt,Entire condo,t,f,t,8,2,365,90,2,4,4,3,5,3
$65.00,-123.019,44.931,Ward 6,Private room,Private room in townhouse,f,t,t,1,1,60,30,1,1,1,1,1,67
$175.00,-123.052,44.948,Ward 7,Entire home/apt,Entire townhouse,t,t,t,5,2,300,150,3,3,2,2,3,12
$140.00,-123.037,44.944,Ward 8,Entire home/apt,Entire guest suite,f,f,t,4,1,200,75,2,2,2,1,2,29
$50.00,-123.005,44.922,Ward 1,Private room,Private room,f,f,t,1,1,30,20,1,1,1,1,1,88
$260.00,-123.068,44.958,Ward 2,Entire home/apt,Entire loft,t,t,t,7,3,365,110,4,5,3,2,4,5
$110.00,-123.024,44.936,Ward 3,Entire home/apt,Entire cottage,f,t,t,3,2,150,55,2,3,1,1,2,34
$400.00,-123.081,44.966,Ward 4,Entire home/apt,Entire vacation home,t,f,t,10,4,365,200,6,8,5,4,6,2
$78.00,-123.014,44.926,Ward 5,Private room,Private room in home,f,f,t,2,1,45,25,1,1,1,1,1,51
$190.00,-123.057,44.951,Ward 6,Entire home/apt,Entire bungalow,t,t,t,5,2,270,95,3,4,2,2,3,17
$155.00,-123.033,44.942,Ward 7,Entire home/apt,Entire place,f,t,t,4,1,220,80,2,3,2,1,2,26
$28.00,-123.002,44.919,Ward 8,Private room,Room in hotel,f,f,t,1,1,25,15,1,1,1,1,1,95
$500.00,-123.088,44.971,Ward 1,Entire home/apt,Tiny home,t,t,t,12,5,365,180,7,9,6,4,7,1
$132.00,-123.041,44.945,Ward 2,Entire home/apt,Entire rental unit,f,t,t,4,2,180,70,2,3,2,1,2,31
$88.00,-123.021,44.933,Ward 3,Private room,Private room in rental unit,f,f,t,2,1,80,40,2,2,1,1,1,44
$225.00,-123.064,44.954,Ward 4,Entire home/apt,Entire home,t,f,t,6,3,320,130,4,5,3,2,4,9
;
RUN;

/* base cleaning identical to the upstream pipeline, so the slice below runs on the same data shape */
DATA WORK.Listings_Clean;
    SET WORK.Listings;
    price_numeric = INPUTN(price, 'DOLLAR12.2');
    DROP price;
    RENAME price_numeric = price;
RUN;
DATA WORK.Listings_Clean;
    SET WORK.Listings_Clean;
    WHERE 30 <= price <= 475;
    log_price = LOG(price);
RUN;

/* --- RMSE performance-metric computation on scored predictions (from Airbnb Data Analysis.sas) --- */
/* Build a small scored dataset (log_price + model prediction p_log_price) to exercise the
   metric-computation logic exactly as written in the pipeline. */
DATA test_score;
    SET WORK.Listings_Clean;
    /* stand-in prediction: model would supply p_log_price; here derived deterministically */
    p_log_price = log_price - 0.10 + 0.05*MOD(_N_,3);
RUN;

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
    TITLE "Test-Set RMSE Summary";
RUN;
