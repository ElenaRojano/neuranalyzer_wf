#! /usr/bin/env bash

#MODULES LOAD:
hostname
CODE_PATH=`pwd`

. ~soft_bio_267/initializes/init_pets
. ~soft_bio_267/initializes/init_autoflow

mode=$1 
af_add_options=$2 #AutoFlow Additional options

mkdir results
mkdir cohorts
scripts_path=$CODE_PATH"/scripts"
cohort_path=$CODE_PATH"/cohorts/decipher.txt"

#PATHS TO FILES:
decipher_file="/mnt/home/users/bio_267_uma/jperkins/data/DECIPHER/decipher-cnvs-grch38-2022-05-15.txt"
cohorts='decipher'
kernel_matrix_bin="/mnt/home/users/bio_267_uma/josecordoba/proyectos/phenotypes/ComRelOverIntNet/kernel/kernel_matrix_bin"
diseases='gpn_pro;gpn_nopro;omim;orpha' #gpn == genetic peripheral neuropathies. defined as autoflow variable.

#PROCEDURE:
	
if [ "$mode" == "D" ]; then
	echo 'Downloading files...'
	mkdir downloaded_files
	# 1. Download genes and MONDO file.
	wget "https://data.monarchinitiative.org/latest/tsv/all_associations/gene_disease.all.tsv.gz" -O downloaded_files/gene_disease.all.tsv.gz
	gzip -d downloaded_files/gene_disease.all.tsv.gz
	# 2. Download MONDO and HPO file.
	wget "https://data.monarchinitiative.org/latest/tsv/all_associations/disease_phenotype.all.tsv.gz" -O downloaded_files/disease_phenotype.all.tsv.gz
	gzip -d downloaded_files/disease_phenotype.all.tsv.gz
	# 3. Download DECIPHER population CNVs file.
	wget "https://www.deciphergenomics.org/files/downloads/population_cnv_grch38.txt.gz" -O downloaded_files/population_cnv_grch38.txt.gz
	gzip -d downloaded_files/population_cnv_grch38.txt.gz
	# 4. Download phenotype.hpoa file 
	wget 'http://purl.obolibrary.org/obo/hp/hpoa/phenotype.hpoa' -O downloaded_files/phenotype.hpoa

elif [ "$mode" == "C" ]; then
	tail -n +2 $decipher_file | sed 's/# //g' > cohorts/decipher_file_no_header.txt
	paco_translator.rb -P cohorts/decipher_file_no_header.txt -s start -e end -c chr -d patient_id -p hpo_accessions --n_phens 4 -o cohorts/filtered_decipher.txt
	awk '{print $1"\t"$3"\t"$4"\t"$5"\t"$2}' cohorts/filtered_decipher.txt > cohorts/decipher.txt
	sed -i "1i patient_id\tchr\tstart\tstop\tphenotypes" cohorts/decipher.txt
	

elif [ "$mode" == "S" ]; then
	########## Launching Semtools:

	#Peripheral neuropathy #MONDO:0005244
	#Inherited #MONDO:0021152
	# MONDO:0005244 -> Peripheral neuropathy
	# MONDO:0020127 -> genetic peripheral neuropathy
	
	rm -rf diseases_list	
	mkdir diseases_list
	mkdir hpo_files
	mkdir mondo_files
	mkdir tmp_files
	
	# STAGE 1: Prepare MONDO diseases data for analysis: with and without propagation.
	# ----------

	awk '{FS="\t"}{print $5"\t"$1}' downloaded_files/gene_disease.all.tsv | tail -n +2 > downloaded_files/disease_gene.tsv
	awk '{FS="\t"}{print $1"\t"$5}' downloaded_files/disease_phenotype.all.tsv | tail -n +2 > downloaded_files/disease_phenotype_nofilt.tsv
	table_header.rb -t downloaded_files/disease_phenotype_nofilt.tsv -c 0,1 -f 1 -k 'HP:' > downloaded_files/disease_phenotype.tsv

	# Find MONDO:0005244 children
	semtools.rb -C MONDO:0020127 -O MONDO > mondo_files/neuropathies_codes.txt
	echo 'MONDO:0020127' >> mondo_files/neuropathies_codes.txt 
	
	#semtools.rb -C MONDO:0005244 -O MONDO > mondo_files/neuropathies_codes.txt
	#echo 'MONDO:0005244' >> mondo_files/neuropathies_codes.txt 
	
	# Add MONDO names to file with codes
	semtools.rb -i mondo_files/neuropathies_codes.txt -O MONDO -l names > mondo_files/neuropathies_names.txt
	# Find MONDO codes in MONDO-HPO file:
	grep -F -f mondo_files/neuropathies_codes.txt downloaded_files/disease_phenotype.tsv > tmp_files/neuropathies_hpo.txt
	aggregate_column_data.rb -i tmp_files/neuropathies_hpo.txt -x 0 -a 1 -s ',' > tmp_files/neuropathies_hpo_agg.txt
	aggregate_column_data.rb -i tmp_files/neuropathies_hpo.txt -x 1 -a 0 -s ';' > tmp_files/neuropathies_hpo_agg_inv.txt
	# Expandir listas por propagación:
	# Use MONDO:0005244 as root
	semtools.rb -i tmp_files/neuropathies_hpo_agg_inv.txt -O MONDO -e propagate -R 'MONDO:0005244' -o tmp_files/neuropathies_hpo_agg_prop.txt 
	#mondo -> hpo
	desaggregate_column_data.rb -i tmp_files/neuropathies_hpo_agg_prop.txt -x 1 -s '|' | aggregate_column_data.rb -i - -x 1 -a 0 -s ',' > tmp_files/neuro_mondo_hpo_agg_exp.txt
	#añade las cohortes de mondo en otro path:
	ln -s ../tmp_files/neuropathies_hpo_agg.txt diseases_list/gpn_nopro.txt #before prop
	ln -s ../tmp_files/neuro_mondo_hpo_agg_exp.txt diseases_list/gpn_pro.txt #after prop

	# STAGE 2: Prepare OMIM and Orpha diseases data for analysis from HP:0009830.
	# ----------
	#Prepare list of HPOs from HP:0009830

	semtools.rb -C HP:0009830 -O HPO > hpo_files/perineuro_hpo_codes.txt
	echo 'HP:0009830' >> hpo_files/perineuro_hpo_codes.txt
	
	# Get OMIM/ORPHA diseases described with neuropathies-related HPOs:
	aggregate_column_data.rb -i downloaded_files/phenotype.hpoa -x 0 -a 3 -s ',' | grep -v '#' > tmp_files/filtered_phenotype.hpoa
	grep -F -f hpo_files/perineuro_hpo_codes.txt tmp_files/filtered_phenotype.hpoa | sort -u > tmp_files/perineuro_diseases.txt
	
	# Get ORPHA codes and aggregate HPOs:
	grep 'ORPHA:' tmp_files/perineuro_diseases.txt > tmp_files/perineuro_orpha_hpos.txt
	
	# Get OMIM codes and aggregate HPOs:
	grep 'OMIM:' tmp_files/perineuro_diseases.txt > tmp_files/perineuro_omim_hpos.txt

	ln -s ../tmp_files/perineuro_omim_hpos.txt diseases_list/omim.txt
	ln -s ../tmp_files/perineuro_orpha_hpos.txt diseases_list/orpha.txt


elif [ "$mode" == "A" ]; then
	#3. Launch Autoflow:
    AF_VARS=`echo -e "
        \\$sim_thr=0.4,
        \\$scripts_path=$scripts_path,
        \\$disease_gene_list=$CODE_PATH'/downloaded_files/disease_gene.tsv',
        \\$annot_path=~pedro/references/hsGRc38/annotation.gtf,
        \\$erb_template=$CODE_PATH'/templates/report_template.erb',
        \\$kernel_matrix_bin=$kernel_matrix_bin,
        \\$path_to_disease_files=$CODE_PATH'/diseases_list',
        \\$diseases=$diseases,
        \\$cohort_path=$cohort_path" | tr -d [:space:]`
    AutoFlow -e -w $CODE_PATH/templates/neuroanalysis_template.af -V $AF_VARS -o $CODE_PATH/results -c 1 -m 60gb -t '2-00:00:00' $af_add_options
fi

#\\$mondo_hpo_file=$CODE_PATH'/tmp_files/neuropathies_hpo_agg.txt',
#\\$mondo_hpo_file_exp=$CODE_PATH'/tmp_files/neuro_mondo_hpo_agg_exp.txt',

