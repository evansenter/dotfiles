Pry.config.pager    = false
ENV["ENTREZ_EMAIL"] = "evansenter@gmail.com"

require "awesome_print"
require "benchmark"
require "wrnap"
require "csv"

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
  alias_method :fact, def factorial
    self > 2 ? (2..self).inject(&:*) : (self.zero? ? 1 : self)
  end

  alias_method :c, def choose(number)
    fact.to_f / ((self - number).fact * number.fact)
  end
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

  alias_method :first_moment, def expected_value
    # Assumes x = index, p(x) = array[index]
    graphify.map { |array| array.inject(&:*) }.sum
  end

  def second_moment
    # Assumes x = index, p(x) = array[index]
    graphify.map { |x, p_x| x ** 2 * p_x }.sum
  end

  alias_method :mean, def avg
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

  def stats
    {
      avg:   avg,
      stdev: stdev_sample,
      min:   min,
      max:   max,
      n:     size
    }
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

  def gaussian_pdf(x, mu, sigma)
    (1 / (sigma * Math.sqrt(2 * Math::PI))) * (Math::E ** (-0.5 * ((x - mu) / sigma) ** 2))
  end

  def inline_rails
    require "logger"

    logger                      = Logger.new(STDOUT)
    ActiveRecord::Base.logger   = logger if defined?(ActiveRecord)
    ActiveResource::Base.logger = logger if defined?(ActiveResource)
    puts "Logging ActiveRecord::Base and ActiveResource::Base inline."
  end
end

include PryHelperMethods

if File.basename(ENV["_"]) == "rails"
  inline_rails
end
