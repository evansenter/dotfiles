require "active_support"
require "awesome_print"
require "logger"
require "wirble"
require "wrnap"
require "rbfam"
require "rbfam_bridge"

Wirble.init
Wirble.colorize

logger                      = Logger.new(STDOUT)
ActiveRecord::Base.logger   = logger if defined?(ActiveRecord)
ActiveResource::Base.logger = logger if defined?(ActiveResource)
puts "Logging ActiveRecord::Base and ActiveResource::Base inline."

Rbfam.db.connect
Rbfam::Family.connection
Rbfam::Rna.connection
