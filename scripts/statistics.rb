#! /usr/bin/env ruby
#
# Tool to calculate statistics using data from execution nodes

###########################
#LIBRARIES
##########################

require 'optparse'

###########################
#METHODS
##########################

def load_paths(file)
	path_to_files = {}
	File.open(file).each do |line|
		line.chomp!
		filename, path = line.split("\t")
		path_to_files[filename] = path
	end
	return path_to_files
end

def	load_file(path)
	cohort_data = {}
	File.open(path).each do |line|
		line.chomp!
		next if line.include?('patient_id')
		patientID, chr, start, stop, hpos = line.split("\t")
		hpo_list = hpos.split('|')
		patient_metadata = [chr, start, stop, hpo_list]
		query = cohort_data[patientID]
		if query.nil?
			cohort_data[patientID] = [patient_metadata]
		else
			query << patient_metadata
		end
	end
	return cohort_data
end 

def load_ref(ref_file)
	mondo_refs = {}
	File.open(ref_file).each do |line|
		line.chomp!
		mondoID, hpos = line.split("\t")
		mondo_refs[mondoID] = hpos.split(',')
	end
	return mondo_refs
end

def calculate_cohort_statistics(cohort_data)
	metrics = {}
	metrics['Total patients'] = cohort_data.keys.length
	all_chrs = Hash.new(0)
	hpos_per_patient = []
	cohort_data.each do |patientID, patient_records|
		patient_records.each do |patient_metadata|
			chr_id = patient_metadata.first
			all_chrs[chr_id] += 1
			hpos_per_patient << patient_metadata.last.length
		end
	end
	sorted_chr = []
	all_chrs.each do |chr_id, value|
		if sorted_chr.empty?
			sorted_chr = [chr_id, value]
		else
			if sorted_chr[1] < value
				sorted_chr = [chr_id, value]
			end
		end
	end
	metrics['HPOs average per patient'] = hpos_per_patient.inject{|sum, e| sum + e }.fdiv(hpos_per_patient.length).round(3)
	metrics['Most frequent affected chromosome'] =  sorted_chr[0]
	return metrics
end

def save_file(output_file, metrics)
	File.open(output_file, 'w') do |f|
		metrics.each do |name, value|
			f.puts "#{name}\t#{value}"
		end
	end
end

def load_two_cols_file(filename)
	storage = {}
	File.open(filename).each do |line|
		line.chomp!
		col1, col2 = line.split("\t")
		storage[col1] = col2
	end
	return storage
end

def load_ranked_genes_file(filename)
	ranked_genes_data = {}
	File.open(filename).each do |line|
		line.chomp!
		col1, col2, col3, col4, col5 = line.split("\t")
		ranked_genes_data[col1] = [col2, col3, col4, col5]
	end	
	return ranked_genes_data
end


##########################
#OPT-PARSE
##########################

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"
  
  options[:input_paths] = nil
  opts.on("-i", "--input_paths PATH", "Input table with a list of paths to files") do |data|
    options[:input_paths] = data
  end

  options[:output_file] = 'statistics.txt'
  opts.on("-o", "--output_file PATH", "Output file with statistics") do |data|
    options[:output_file] = data
  end

  options[:input_ref] = nil
  opts.on("-r", "--input_ref PATH", "Input reference file with MONDO genes") do |data|
    options[:input_ref] = data
  end 

end.parse!

##########################
#MAIN
##########################

path_to_files = load_paths(options[:input_paths])

all_metrics = {}
path_to_files.each do |filename, path|
	if filename == "cohort"
		cohort_data = load_file(path)
		all_metrics.merge!(calculate_cohort_statistics(cohort_data))
	elsif filename == "cohort_without_ref"

	elsif filename == "cohort_with_ref"
		mondo_refs = load_ref(options[:input_ref])
		mondo_clusters = load_two_cols_file(File.join(path, 'temp', 'lin_clusters_cols.txt'))
		patient_clusters = load_two_cols_file(File.join(path, 'temp', 'lin_clusters_rows.txt'))
		all_metrics['Number of MONDOs before clustering'] = mondo_refs.keys.length
		all_metrics['Number of MONDOs after clustering'] = mondo_clusters.keys.length
		all_metrics['Total of clusters in cohort with reference'] = mondo_clusters.values.uniq.length
		all_metrics['Total of patients clustered'] = patient_clusters.keys.uniq.length
	elsif filename == "ranked_cohort"
		ranked_genes = load_ranked_genes_file(File.join(path, 'ranked_genes_all_candidates'))
		#see if this info could be valuable to print or use in the summary table
	else
		abort("Wrong file name")
	end

end
save_file(options[:output_file], all_metrics)