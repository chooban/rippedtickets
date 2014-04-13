#!/usr/bin/env ruby 

require "cgi"
require "erb"

# This cgi object is available in your RHTML files
cgi = CGI.new

# Optionally, enable using gems you've installed per 
# http://forum.dreamhosters.com/programming/43221-gem-install-broken.htm#Post43228
ENV['GEM_PATH'] = "#{ENV['GEM_PATH']}:/home/XXX/.gems"

# Optionally, require stuff here so you don't need to do this in each RHTML file
require "rubygems"

# Load my rb files
ENV['RUBYLIB'] = "#{ENV['RUBYLIB']}:/home/XXX/ruby"
$:.unshift("/home/XXX/ruby")

begin
  path = nil
	  if (ENV['PATH_TRANSLATED'])
	    path = ENV['PATH_TRANSLATED']
	  else
	    file_path = ENV['REDIRECT_URL'].include?(File.basename(__FILE__)) ? ENV['SCRIPT_URL'] : ENV['REDIRECT_URL']
	    path = File.expand_path(ENV['DOCUMENT_ROOT'] + '/' + file_path)
	    raise "Attempt to access invalid path: #{path}" unless path.index(ENV['DOCUMENT_ROOT']) == 0
	  end

	  # So that working directory is not here but where the .rhtml is:
	  Dir.chdir(File.dirname(path))

	  erb = File.open(path) { |f| ERB.new(f.read) }
	  print cgi.header + erb.result(binding)

	rescue Exception => e
	  print "Content-Type: text/html\n\n"
	  print "<h1>ERB errors</h1><p>#{e}</p>"
		print "<pre>#{ $1 }</pre>"
end
