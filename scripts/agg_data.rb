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

  options[:output_cluster_mondo] = 'mondos_by_cluster.txt'
  opts.on("-o", "--output_cluster_mondo PATH", "Output file with cluster IDs and MONDO IDs by cluster") do |data|
    options[:output_cluster_mondo] = data
  end

end.parse!

##########################
#MAIN
##########################

patient_mondo_data = load_patient_mondo_file(options[:input_patient_mondo_file])
patient_cluster_data = load_patient_cluster_file(options[:input_patient_cluster_file])
cluster_mondo_data = join_mondo_cluster_by_patients(patient_mondo_data, patient_cluster_data)
write_hash(cluster_mondo_data, options[:output_cluster_mondo])
