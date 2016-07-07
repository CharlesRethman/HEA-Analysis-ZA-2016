# HEA Analysis South Africa 2016

## What is in this repo

This is the repo: HEA-Analysis-ZA-2016, and the folder with the repo is `~/Documents/hea_analysis/south_africa/2016.04` on my disk.

Collection of directories:
* [./db](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/db): A dump of all the relevant files you need to recreate this analysis.
* [./economy](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/economy): Data and analysis on general economic issues, such as GDP, labour, etc. Prices and crop production have their own directories (see below).
* [./extra_baselines](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/extra_baselines): Extra baselines information:
  * Rural farmworkers.
  * Urban dwellers. Their baseline and analysis sheet is largely built up out of NIDS data.
  * Synthesis-zones for the remaining open access livelihood zones aggregated from the 14 exsiting baselines.
* [./graphics](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/graphics): set of maps and images feeding into and resulting from the analysis;
* [./met](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/met): NDVI and other images on drought spatial distribution, as well as set of shape files for trimming all the junk off the edges of the NDVI image;
* [./maps](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/maps): QGIS map files for analysis of drought extent, affected populations, livelihood zones;
* [./pop](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/pop): various Excel and and CSV files with population and affected numbers analsyis. The Excel files (especially `outcomes.xlsx`) contain valuable pivot tables of outcomes and affected population/deficit calculations.
* [./crops](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/crops): Crop Estimates Committee (CEC) data and various agricultural census documents from BFAP and DAFF.
* [./prices](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/prices): data (mostly sourced from Statistics SA), opinion pieces on commodity prices and analysis of price time series for forecasting price problem specs.
* [./reports](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/reports): The report and presentations, as well as planning documents
* [./spreadsheets](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/spreadsheets): Baseline Storage Spreadsheets (BSSs) and Outcome Analysis Spreadsheets (OASs) used in this 2016 National Outcome Forecast Analysis (_April-May 2016_). **Note**: there are additional spreadsheets that enable anaylsis of the urban poor, farm workers and people living in open access tenure livelihood zones for which there are not yet proper baselines;
* [./sql](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/tree/master/sql): The SQL files perform functional processes on the spatial and tabular data sets. In particular, SQL queries are used to determine affected population census Small Areas ans the portions of livelihood zones under diffrent problem specifications, as well as generating population data and enabling mapping functionality with Postgres/PostGIS.

## How to use the files in this repo

### Prerequisites

This documents assumes you have the following installed on your system:
* PostgreSQL with the PostGIS extension (>= v 9.3). This can be found at
* QGIS (>= v 2.8)
Alternatively, PostgreSQL, PostGIS and QGIS all come bundled in a single package by Boundless, which can be obtained [here](http://boundlessgeo.com/products/).
* NodeJS (>= v 4.2). Node Package Manager (NPM) is also needed but this usually comes bundled with any installion of NodeJS.

### Building the Database

[more to be added here]

### File Structure

By clicking "Download zip file"

### The Remote Sensing Images

Georeferencing, obtaining a sliding scale reading for each pixel  [more to be added here later]

### Running the Problem Spec Queries



## More ...

For instructions on how to use GitHub and Git with these spreadsheets, see [INSTRUCTIONS.md](https://github.com/CharlesRethman/HEA-Analysis-ZA-2016/blob/master/INSTRUCTIONS.md).
