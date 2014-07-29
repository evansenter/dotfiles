Pry.config.pager    = false
ENV["ENTREZ_EMAIL"] = "evansenter@gmail.com"

require "awesome_print"
require "benchmark"
require "wrnap"
require "diverge"
require "fileutils"
require "csv"
require "open-uri"
require "nokogiri"

$LOAD_PATH << "."

class Object
  def _ident
    self
  end

  def as(&block)
    yield self
  end
end

class File
  def self.temp(&block)
    Tempfile.new("").tap do |file|
      yield file
      file.close
    end.path
  end
end

module Enumerable
  def graphify
    each_with_index.to_a.map(&:reverse)
  end

  def inner_inject(default = :not_used, &block)
    # [[1, 2], [3, 4]].inner_map(&:to_f).inner_inject(&:/)
    #=> [0.5, 0.75]
    # [[1, 2], [3, 4]].inner_map(&:to_f).inner_inject(10, &:+)
    #=> [13.0, 17.0]
    map { |object| default == :not_used ? object.inject(&block) : object.inject(default, &block) }
  end

  def inner_map(&block)
    # [[1, 2], [3, 4]].inner_map { |i| i + 1 }
    #=> [[2, 3], [4, 5]]
    map { |object| object.map(&block) }
  end

  def chain_map(*args)
    args.inject(self) { |collection, action| collection.map(&action) }
  end
end

class Integer
  def factorial
    self > 2 ? (2..self).inject(&:*) : (self.zero? ? 1 : self)
  end

  alias :fact :factorial

  def choose(number)
    fact.to_f / ((self - number).fact * number.fact)
  end

  alias :c :choose
end

class Array
  def self.wrap(object)
    object.kind_of?(Array) ? self : [object]
  end

  def at_indexes(*list)
    # (?a..?e).to_a.at_indexes(1, 3)
    #=> ["b", "d"]
    list.flatten.map { |i| self[i] }
  end

  def select_rand(number = 1)
    # Alexa helped / independently came up with this technique!
    if number >= length
      shuffle
    elsif number >= 1
      [].tap do |list|
        while list.size < number
          list.push((rand * length).floor).uniq!
        end
      end.map(&method(:[]))
    else
      raise ArgumentError.new("select_rand(number) must be gteq. 1")
    end
  end

  def expected_value
    # Assumes x = index, p(x) = array[index]
    graphify.map { |array| array.inject(&:*) }.sum
  end
  alias :first_moment :expected_value

  def second_moment
    # Assumes x = index, p(x) = array[index]
    graphify.map { |x, p_x| x ** 2 * p_x }.sum
  end

  def avg
    inject(&:+) / length.to_f
  end

  def stdev_sample
    mean = avg
    Math.sqrt(inject(0.0) { |sum, i| sum + (mean - i) ** 2 } / (length - 1))
  end

  def stdev_population
    mean = avg
    Math.sqrt(inject(0.0) { |sum, i| sum + (mean - i) ** 2 } / length)
  end

  def stdev_frequencies
    Math.sqrt(second_moment - first_moment ** 2)
  end

  def z_score
    mean, sigma = avg, stdev_population
    map { |i| (i - mean) / sigma }
  end
end

class Hash
  def -@
    OpenStruct.new(self)
  end
end

module PryHelperMethods
  def self.included(base)
    public_instance_methods.each do |method_name|
      puts "Method available: #{method_name}"
    end
  end

  def inline_rails
    require "logger"

    logger                      = Logger.new(STDOUT)
    ActiveRecord::Base.logger   = logger if defined?(ActiveRecord)
    ActiveResource::Base.logger = logger if defined?(ActiveResource)
    puts "Logging ActiveRecord::Base and ActiveResource::Base inline."
  end

  def autobot_helper(name)
    require "/Users/evansenter/Source/autobot/lib/autobot/helpers/#{name}"
  end

  def distribution_connect
     inline_rails
     autobot_helper("data_loader_mysql_config")
  end

  def run_pbs_job(action = nil, pbs_script_name = nil, nodes = "1:clotelabsub:ppn=8")
    unless action && pbs_script_name
      puts "run_pbs_job(action = nil, pbs_script_name = nil, nodes = '1:clotelabsub:ppn=8')"
      return
    end

    write_pbs_file(action, pbs_script_name, nodes)

    puts "Submitting job #{pbs_script_name}: #{action}"

    print %x|qsub "pbs_#{pbs_script_name}.sh"|
  end

  def write_pbs_file(commands, output_name, nodes = "1:clotelabsub:ppn=8")
    File.open("pbs_#{output_name}.sh", "w") do |file|
      file.write(pbs_string(commands, output_name, nodes))
    end
  end

  def pbs_string(commands, output_name, nodes = "1:clotelabsub:ppn=8")
    action = case commands
    when Array  then commands.join("\n")
    else commands
    end

    content = <<-SH
        #!/bin/sh
        #PBS -l nodes=#{nodes}
        #PBS -o pbs_#{output_name}.log
        #PBS -e pbs_#{output_name}.err
        #PBS -q stage
        #PBS -l walltime=24:00:00
        cd $PBS_O_WORKDIR
        #{action}
      SH

      content.gsub(/^\s*/, "")
  end

  def merge_gaussian(distributions)
    distributions.map(&:length).max.times.map { |i| distributions.map { |distribution| distribution[i] || 0 } }.map(&:avg)
  end

  def gaussian_pdf(x, mu, sigma)
    (1 / (sigma * Math.sqrt(2 * Math::PI))) * (Math::E ** (-0.5 * ((x - mu) / sigma) ** 2))
  end

  def fasta_map
    Dir["*.fa"].map do |file|
      yield Bio::FlatFile.open(file).first, File.basename(file, ".fa")
    end
  end

  def group_map(*lists)
    lists.inject { |a, b| a.zip(b).map(&:flatten) }
  end
end

include PryHelperMethods

if File.basename(ENV["_"]) == "rails"
  inline_rails
end
