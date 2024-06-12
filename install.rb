#!/usr/bin/env ruby

require 'rbconfig'
require 'fileutils'

include RbConfig
sitedir = File.join(CONFIG["sitedir"], CONFIG["ruby_version"])

begin
  FileUtils.cp "nanogems.rb", sitedir
rescue Errno::EACCES
  abort "User #{ENV["USER"]} do not have access to #{sitedir}.  You may need to run `sudo ruby install.rb`"
end

puts "nanogems.rb was successfully installed into #{sitedir}."

puts "Do not forget to add `--disable=gems -rnanogems` to your command-line."
