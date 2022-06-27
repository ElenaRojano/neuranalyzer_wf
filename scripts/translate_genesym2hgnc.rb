#! /usr/bin/env ruby
#
#Code to translate Gene Symbol to HGNC.
#
###########################
#LIBRARIES
##########################

require 'optparse'

###########################
#METHODS
##########################

def load_dictionary(file)
	dictionary = {}
	File.open(file).each do |line|
		line.chomp!
		translation, term2translate = line.split("\t")
		dictionary[term2translate] = translation
	end
	return dictionary
end

def load_and_translate(file2translate, dictionary)
	translated_terms = {}
	File.open(file2translate).each do |line|
		line.chomp!
		id, term2translate = line.split("\t")
		translation = dictionary[term2translate]
		translated_terms[id] = translation
	end
	return translated_terms
end

def save_file(translated_terms, output_file)
	File.open(output_file, 'w') do |f|
		translated_terms.each do |id, term|
			f.puts "#{id}\t#{term}"
		end
	end
end

##########################
#OPT-PARSE
##########################

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"
  
  options[:input_dictionary] = nil
  opts.on("-d", "--input_dictionary PATH", "Input dictionary file") do |data|
    options[:input_dictionary] = data
  end

  options[:input_file2translate] = nil
  opts.on("-f", "--input_file2translate PATH", "Input file to translate") do |data|
    options[:input_file2translate] = data
  end

  options[:output_file] = nil 
  opts.on("-o", "--output_file PATH", "Output file") do |data|
    options[:output_file] = data
  end

end.parse!

##########################
#MAIN
##########################


dictionary = load_dictionary(options[:input_dictionary])
translated_terms = load_and_translate(options[:input_file2translate], dictionary)
save_file(translated_terms, options[:output_file])