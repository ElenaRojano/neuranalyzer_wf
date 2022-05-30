#! /usr/bin/env bash

#MODULES LOAD:
hostname
CODE_PATH=`pwd`

. ~soft_bio_267/initializes/init_pets
. ~soft_bio_267/initializes/init_autoflow

mode=$1 
af_add_options=$2 #AutoFlow Additional options

mkdir tmp_files
mkdir results
mkdir cohorts
cohorts_path=$CODE_PATH"/cohorts"
scripts_path=$CODE_PATH"/scripts"

#PATHS TO FILES:
decipher_file="/mnt/home/users/bio_267_uma/jperkins/data/DECIPHER/decipher-cnvs-grch38-2022-05-15.txt"
cohorts='decipher'

#PROCEDURE:
#1. Select DECIPHER patients
if [ "$mode" == "1" ]; then
	mkdir downloaded_files
	# 1. Download genes and MONDO file.
	wget "https://data.monarchinitiative.org/latest/tsv/all_associations/gene_disease.all.tsv.gz" -O downloaded_files/gene_disease.all.tsv.gz
	gzip -d downloaded_files/gene_disease.all.tsv.gz
	# 2. Download MONDO and HPO file.
	wget "https://data.monarchinitiative.org/latest/tsv/all_associations/disease_phenotype.all.tsv.gz" -O downloaded_files/disease_phenotype.all.tsv.gz
	gzip -d downloaded_files/disease_phenotype.all.tsv.gz

elif [ "$mode" == "2" ]; then
	tail -n +2 $decipher_file | sed 's/# //g' > cohorts/decipher_file_no_header.txt
	paco_translator.rb -P cohorts/decipher_file_no_header.txt -s start -e end -c chr -d patient_id -p hpo_accessions --n_phens 4 -o cohorts/filtered_decipher.txt
	awk '{print $1"\t"$3"\t"$4"\t"$5"\t"$2}' cohorts/filtered_decipher.txt > cohorts/decipher.txt
	sed -i "1i patient_id\tchr\tstart\tstop\tphenotypes" cohorts/decipher.txt
	rm cohorts/decipher_file_no_header.txt cohorts/filtered_decipher.txt #Delete to avoid its analysis in workflow


elif [ "$mode" == "S" ]; then
	#2. Launch Semtools:
	#Peripheral neuropathy #MONDO:0005244
	#Inherited #MONDO:0021152
	mkdir mondo_files
	awk '{FS="\t"}{print $5"\t"$1}' downloaded_files/gene_disease.all.tsv | tail -n +2 > downloaded_files/gene_disease.tsv
	awk '{FS="\t"}{print $1"\t"$5}' downloaded_files/disease_phenotype.all.tsv | tail -n +2 > downloaded_files/disease_phenotype.tsv
	# Find MONDO:0005244 children
	semtools.rb -C MONDO:0005244 -O MONDO > mondo_files/neuropathies_codes.txt
	# Add MONDO names to file with codes
	semtools.rb -i mondo_files/neuropathies_codes.txt -O MONDO -l names > mondo_files/neuropathies_names.txt
	# Find MONDO codes in MONDO-HPO file:
	grep -F -f mondo_files/neuropathies_codes.txt downloaded_files/disease_phenotype.tsv > tmp_files/neuropathies_hpo.txt
	aggregate_column_data.rb -i tmp_files/neuropathies_hpo.txt -x 0 -a 1 -s ',' > tmp_files/neuropathies_hpo_agg.txt
	aggregate_column_data.rb -i tmp_files/neuropathies_hpo.txt -x 1 -a 0 -s ',' > tmp_files/neuropathies_hpo_agg_inv.txt
	# Expandir listas por propagación:
	semtools.rb -i tmp_files/neuropathies_hpo_agg_inv.txt -O MONDO -e propagate -o tmp_files/neuropathies_hpo_agg_prop.txt


elif [ "$mode" == "A" ]; then
	#3. Launch Autoflow:
    AF_VARS=`echo -e "
        \\$all_cohorts=$cohorts,
        \\$mondo_hpo_file=$CODE_PATH'/tmp_files/neuropathies_hpo_agg.txt',
        \\$sim_thr=0.4,
        \\$scripts_path=$scripts_path,
        \\$cohorts_path=$cohorts_path" | tr -d [:space:]`
    AutoFlow -e -w $CODE_PATH/templates/neuroanalysis_template.af -V $AF_VARS -o $CODE_PATH/results -c 1 -m 5gb -t '03:00:00' $af_add_options
fi

