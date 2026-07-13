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

/* --- Engineered categorical groupings + frequency verification (from Airbnb Data Analysis.sas) --- */
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
                               'entire guest suite', 'entire condo',
                               'entire townhouse', 'entire loft',
                               'entire cottage', 'entire bungalow',
                               'entire place', 'entire vacation home') THEN
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
    ELSE IF MISSING(property_type_clean) THEN property_cat = 'Unknown';
    ELSE property_cat = 'Other';
    DROP property_type_clean;
RUN;

DATA WORK.Listings_Clean;
    SET WORK.Listings_Clean;
    IF neighbourhood_cleansed IN ('Ward 1', 'Ward 2') THEN ward_type = 'Urban';
    ELSE IF neighbourhood_cleansed IN ('Ward 7', 'Ward 8') THEN ward_type = 'Residential';
    ELSE IF neighbourhood_cleansed IN ('Ward 3', 'Ward 4', 'Ward 5', 'Ward 6') THEN ward_type = 'Sub-Urban';
RUN;

PROC FREQ DATA=WORK.Listings_Clean;
    TABLES bedroom_group bathroom_group beds_group property_cat ward_type;
    TITLE "Frequency of Engineered Features";
RUN;
