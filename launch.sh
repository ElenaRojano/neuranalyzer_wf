#! /usr/bin/env bash

#MODULES LOAD:
hostname
CODE_PATH=`pwd`

. ~soft_bio_267/initializes/init_pets
. ~soft_bio_267/initializes/init_autoflow
export PATH="~elenarojano/dev_gem/pets/bin":$PATH
export PATH=$CODE_PATH/aux_scripts:$PATH
mode=$1 
af_add_options=$2 #AutoFlow Additional options

cohorts_path=$CODE_PATH"/tmp_files"

#PATHS TO FILES:
decipher_file="/mnt/home/users/bio_267_uma/jperkins/data/DECIPHER/decipher-cnvs-grch38-2022-05-15.txt"
cohorts='decipher'

#PROCEDURE:
#1. Select DECIPHER patients

if [ "$mode" == "1" ]; then
	mkdir tmp_files
	mkdir results
	tail -n +2 $decipher_file | sed 's/# //g' > tmp_files/decipher_file_no_header.txt
	paco_translator.rb -P tmp_files/decipher_file_no_header.txt -s start -e end -c chr -d patient_id -p hpo_accessions --n_phens 4 -o tmp_files/filtered_decipher.txt
	awk '{print $1"\t"$3"\t"$4"\t"$5"\t"$2}' tmp_files/filtered_decipher.txt > tmp_files/decipher.txt
	sed -i "1i patient_id\tchr\tstart\tstop\tphenotypes" tmp_files/decipher.txt
	rm tmp_files/decipher_file_no_header.txt tmp_files/filtered_decipher.txt #Delete to avoid its analysis in workflow

#2. Launch Autoflow:

elif [ "$mode" == "2" ]; then
    AF_VARS=`echo -e "
        \\$all_cohorts=$cohorts,
        \\$cohorts_path=$cohorts_path" | tr -d [:space:]`
    AutoFlow -e -w $CODE_PATH/templates/neuroanalysis_template.af -V $AF_VARS -o $CODE_PATH/results -c 1 -m 5gb -t '03:00:00' $af_add_options
fi