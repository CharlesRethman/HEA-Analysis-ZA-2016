#! /bin/bash

pg_dump -COF c -n zaf -T zaf.demog_eas -T 'zaf.frame*' -T zaf.grid -T 'zaf.hydro*' -T 'zaf.infra*' -T 'zaf.landcap*'  -T 'zaf.landcover*' -T zaf.landtenure_farms -T zaf.livezones_rural_old -T zaf.sas_affected_2015 -T zaf.tbl_assessments -T 'zaf.tbl_ind*' -T 'zaf.tbl_nisis*' -T zaf.tbl_sampled_villages -T 'zaf.tmp*' albers_ea | split -b 98m - db/zaf.dump
