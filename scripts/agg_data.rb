#! /usr/bin/env ruby
# Script that combines files

###########################
#LIBRARIES
##########################

require 'optparse'

###########################
#METHODS
##########################

def load_patient_mondo_file(file)
  patient_mondo_data = {}
  File.open(file).each do |line|
    line.chomp!
    patientID, mondoID, simVal = line.split("\t")
    query = patient_mondo_data[patientID]
    if query.nil?
      patient_mondo_data[patientID] = [mondoID]
    else
      query << mondoID
    end
  end
  return patient_mondo_data
end

def load_two_cols_file(file)
  storage = {}
  File.open(file).each do |line|
    line.chomp!
    col1, col2 = line.split("\t")
    query = storage[col1]
    if query.nil?
      storage[col1] = [col2]
    else
      query << col2
    end
  end
  return storage
end

def load_file_save_hash(file, mode)
  storage = {}
  File.open(file).each do |line|
    line.chomp!
    if mode == '1'
      col1, col2 = line.split("\t")
    else
      col2, col1 = line.split("\t")
    end
    query = storage[col1]
    if query.nil?
      storage[col1] = [col2]
    else
      query << col2
    end
  end
  storage
end

def load_patient_cluster_file(file)
  patient_cluster_data = {}
  File.open(file).each do |line|
    line.chomp!
    patientID, clusterID = line.split("\t")
    query = patient_cluster_data[patientID]
    patient_cluster_data[patientID] = clusterID
  end
  return patient_cluster_data
end

def join_mondo_cluster_by_patients(patient_mondo_data, patient_cluster_data)
    cluster_mondo_data = {} #cluster & mondos
    #puede un paciente estar en varios cluster?
    patient_mondo_data.each do |patientID, mondoIDs|
      clusterID = patient_cluster_data[patientID]
      query = cluster_mondo_data[clusterID]
      if query.nil?
        cluster_mondo_data[clusterID] = mondoIDs
      else
        mondoIDs.each do |mondoID|
          query << mondoID unless query.include?(mondoID)
        end
      end
    end
    return cluster_mondo_data
end

def write_hash(data_hash, output_file)
  File.open(output_file, 'w') do |f|
    data_hash.each do |id, elements|
      elements.each do |e|
        f.puts "#{id}\t#{e}"
      end
    end
  end
end

def join_three_cols(mondo_genes_data, cluster_mondo_data, output_file)
  File.open(output_file, 'w') do |f|
    cluster_mondo_data.each do |mondoID, clusterIDs|
      unless mondo_genes_data[mondoID].nil? #no genes for MONDOID
        geneIDs = mondo_genes_data[mondoID] 
        geneIDs.each do |geneID|
          clusterIDs.each do |clusterID|
            f.puts "#{clusterID}\t#{mondoID}\t#{geneID}"
          end
        end
      end
    end
  end
end

##########################
#OPT-PARSE
##########################

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"
  
  options[:input_patient_mondo_file] = nil
  opts.on("-a", "--input_patient_mondo_file PATH", "Input file with patient IDs and MONDO disease IDs") do |data|
    options[:input_patient_mondo_file] = data
  end

  options[:input_patient_cluster_file] = nil
  opts.on("-b", "--input_patient_cluster_file PATH", "Input file with patient IDs and cluster IDs") do |data|
    options[:input_patient_cluster_file] = data
  end

  options[:input_patient_gene_file] = nil #option not yet used.
  opts.on("-c", "--input_patient_gene_file PATH", "Input file with patient IDs and gene IDs") do |data|
    options[:input_patient_gene_file] = data
  end

  options[:input_mondo_gene_file] = nil
  opts.on("-d", "--input_mondo_gene_file PATH", "Input file with MONDO IDs and gene IDs") do |data|
    options[:input_mondo_gene_file] = data
  end

  options[:exec_mode] = 'duo'
  opts.on("-e", "--exec_mode PATH", "Aggregation execution mode. Please choose between: duo) Aggregate two elements; trio) Aggregate three elements") do |data|
    options[:exec_mode] = data
  end

  options[:input_cluster_mondo_file] = nil
  opts.on("-f", "--input_cluster_mondo_file PATH", "Input file with cluster IDs and MONDO IDs") do |data|
    options[:input_cluster_mondo_file] = data
  end

  options[:output_cluster_mondo] = 'mondos_by_cluster.txt'
  opts.on("-o", "--output_cluster_mondo PATH", "Output file with cluster IDs and MONDO IDs by cluster") do |data|
    options[:output_cluster_mondo] = data
  end

  options[:output_cluster_mondo_genes] = 'cluster_mondo_genes.txt'
  opts.on("-p", "--output_cluster_mondo_genes PATH", "Output file with cluster IDs, MONDO IDs and MONDO genes") do |data|
    options[:output_cluster_mondo_genes] = data
  end

  options[:output_cluster_patient_genes] = 'cluster_decipher_genes.txt'
  opts.on("-q", "--output_cluster_patient_genes PATH", "Output file with cluster IDs, DECIPHER patient IDs and MONDO genes") do |data|
    options[:output_cluster_patient_genes] = data
  end

end.parse!

##########################
#MAIN
##########################

if options[:exec_mode] == 'duo'
  patient_mondo_data = load_two_cols_file(options[:input_patient_mondo_file])
  patient_cluster_data = load_patient_cluster_file(options[:input_patient_cluster_file])
  cluster_mondo_data = join_mondo_cluster_by_patients(patient_mondo_data, patient_cluster_data)
  write_hash(cluster_mondo_data, options[:output_cluster_mondo])
elsif options[:exec_mode] == 'trio'
  cluster_mondo_data = load_file_save_hash(options[:input_cluster_mondo_file], '2')
  mondo_genes_data = load_file_save_hash(options[:input_mondo_gene_file], '1')
  join_three_cols(mondo_genes_data, cluster_mondo_data, options[:output_cluster_mondo_genes])
  
  patient_cluster_data = load_two_cols_file(options[:input_patient_cluster_file])
  patient_gene_data = load_two_cols_file(options[:input_patient_gene_file])
  join_three_cols(patient_gene_data, patient_cluster_data, options[:output_cluster_patient_genes])
else
  abort('Wrong execution mode. Please choose between 1 and 2')  
end