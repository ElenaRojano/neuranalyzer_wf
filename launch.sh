#! /usr/bin/env bash

#MODULES LOAD:
hostname
. ~soft_bio_267/initializes/init_pets
. ~soft_bio_267/initializes/init_autoflow
PATH="~elenarojano/dev_gem/pets/bin":$PATH
export PATH

CODE_PATH=`pwd`
export PATH=$CODE_PATH/aux_scripts:$PATH
mode=$1 
af_add_options=$2 #AutoFlow Additional options

ln -s /mnt/home/users/bio_267_uma/josecordoba/software/cohortAnalyzer_wf/custom_opt ext_files/custom_opt
custom_opt=$CODE_PATH'/ext_files/custom_opt'
cohorts_path=$CODE_PATH"/tmp_files"

#PATHS TO FILES:
decipher_file="/mnt/home/users/bio_267_uma/jperkins/data/DECIPHER/decipher-cnvs-grch38-2022-05-15.txt"
path_to_hpo='/mnt/home/users/bio_267_uma/elenarojano/dev_gem/pets/external_data/hp.obo'

#SET INPUTS:

cohorts='decipher'
ln -s /mnt/home/users/bio_267_uma/josecordoba/software/cohortAnalyzer_wf/go-basic.obo ext_files/go-basic.obo
path_to_GO=$CODE_PATH/ext_files/go-basic.obo  #define path to GO file in OBO format. Available at /mnt/home/users/bio_267_uma/josecordoba/software/cohortAnalyzer_wf
path_to_annotations='/mnt/home/users/pab_001_uma/pedro/references' #define path to genome_version folder (must be configured in custom_opt file) that includes an annotation.gtf file

#PROCEDURE:
#1. Select DECIPHER patients

if [ "$mode" == "1" ]; then
	mkdir tmp_files
	mkdir results
	tail -n +2 $decipher_file | sed 's/# //g' > tmp_files/decipher_file_no_header.txt
	paco_translator.rb -P tmp_files/decipher_file_no_header.txt -s start -e end -c chr -d patient_id -p hpo_accessions --n_phens 4 -o tmp_files/filtered_decipher.txt
	sed -i "1i patient_id\tphenotypes\tchr\tstart\tend" tmp_files/filtered_decipher.txt
	rm tmp_files/decipher_file_no_header.txt #Delete to avoid its analysis in workflow

#2. Launch Autoflow:

elif [ "$mode" == "2" ]; then
    AF_VARS=`echo -e "
        \\$all_cohorts=$cohorts,
        \\$custom_options=$custom_opt,
        \\$HPO=$path_to_hpo,
        \\$annotation_path=$path_to_annotations,
        \\$cohorts_path=$cohorts_path,
        \\$GO=$path_to_GO" | tr -d [:space:]`
    AutoFlow -e -w $CODE_PATH/templates/neuroanalysis_template.af -V $AF_VARS -o $CODE_PATH/results -c 2 -m 5gb -t '03:00:00' $af_add_options
fi