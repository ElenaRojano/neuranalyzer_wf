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

def load_two_cols_file(file, mode)
  storage = {}
  File.open(file).each do |line|
    line.chomp!
    if mode == '1'
      col1, col2 = line.split("\t")
    elsif mode == '2'
      col2, col1 = line.split("\t")
    end
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

def get_cluster_gene_stats(cluster_patients, patient_gene)
  cluster_gene_stats = []
  cluster_patients.each do |clusterID, patients|
    gene_stat = Hash.new(0)
    patients.each do |patientID|
      genes = patient_gene[patientID]
      unless genes.nil?
        genes.each do |g| 
          gene_stat[g] +=1
        end
      end
    end
    gene_stat.each do |gene, count|
      cluster_gene_stats << [gene, (count.fdiv(patients.length) * 100).round(3), clusterID]
    end
  end
  return cluster_gene_stats
end

def save_file(path, content, header)
  File.open(path, 'w') do |f|
    f.puts header
    content.each do |c|
      f.puts c.join("\t")
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

  options[:input_patient_gene_file] = nil
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


  options[:output_cluster_gene_stats] = 'cluster_gene_stats.txt'
  opts.on("-r", "--output_cluster_gene_stats PATH", "Output file with cluster IDs, genes and percentage of patients within cluster with that gene") do |data|
    options[:output_cluster_gene_stats] = data
  end



end.parse!

##########################
#MAIN
##########################

if options[:exec_mode] == 'duo'
  patient_mondo_data = load_two_cols_file(options[:input_patient_mondo_file], '1')
  patient_cluster = load_patient_cluster_file(options[:input_patient_cluster_file])
  cluster_disease = join_mondo_cluster_by_patients(patient_mondo_data, patient_cluster_data)
  write_hash(cluster_disease, options[:output_cluster_mondo])
elsif options[:exec_mode] == 'trio'
  cluster_disease = load_file_save_hash(options[:input_cluster_mondo_file], '2')
  disease_genes = load_file_save_hash(options[:input_mondo_gene_file], '1')
  join_three_cols(disease_genes, cluster_disease, options[:output_cluster_mondo_genes])
  
  patient_cluster = load_two_cols_file(options[:input_patient_cluster_file], '1')
  cluster_patients = load_two_cols_file(options[:input_patient_cluster_file], '2')
  patient_gene = load_two_cols_file(options[:input_patient_gene_file], '1')
  cluster_gene_stats = get_cluster_gene_stats(cluster_patients, patient_gene)

  join_three_cols(patient_gene, patient_cluster, options[:output_cluster_patient_genes])
  header = "geneID\tpercentage\tcluster"
  save_file(options[:output_cluster_gene_stats], cluster_gene_stats, header)

else
  abort("Wrong #{options[:exec_mode]} execution mode. Please choose between duo and trio")  
end