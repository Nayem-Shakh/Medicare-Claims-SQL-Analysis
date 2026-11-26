#!/bin/bash
cd "$(dirname "$0")"
B=https://www.cms.gov/research-statistics-data-and-systems/downloadable-public-use-files/synpufs/downloads
for f in de1_0_2008_beneficiary_summary_file_sample_1 de1_0_2009_beneficiary_summary_file_sample_1 \
         de1_0_2008_to_2010_inpatient_claims_sample_1 de1_0_2008_to_2010_outpatient_claims_sample_1; do
  curl -fL -o "$f.zip" "$B/$f.zip" && unzip -oq "$f.zip" && rm "$f.zip"
done
ls -lh *.csv
