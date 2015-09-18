#
# Simple Group of Filing Applications
# Demo of the web interface to Binder
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'rack'

require_relative '../binder_fs'
require_relative '../error'
require_relative '../web/binder'

module Sgfa
module Demo

#####################################################################
# Demo of the web interface to {Binder}s using {BinderFs} with the first
# part of the path being the Binder name.  The user is taken from the 
# REMOTE_USER with no groups.
#
class WebBinders

  #####################################
  # New web binder demo
  #
  # @param dir [String] The directory
  # @param css [String] URL for the style sheet
  #
  def initialize(dir, css)
   @path = dir
   @css = css
   @app = Sgfa::Web::Binder.new
  end # def initialize()


  #####################################
  # Rack call
  #
  # @param env [Hash] The rack environment
  # @return [Array] Response, Headers, Body
  #
  def call(env)
    bnd = Sgfa::BinderFs.new
    env['sgfa.user'] = env['REMOTE_USER'].dup
    env['sgfa.groups'] = []
    env['sgfa.css'] = @css

    # get binder name
    old_path = env['PATH_INFO']
    old_script = env['SCRIPT_NAME']
    path = old_path.split('/')
    return not_found if path.empty?
    bnam = Rack::Utils.unescape(path[1])
    return not_found if bnam[0] == '.' || bnam[0] == '_'

    # Adjust SCRIPT_NAME and PATH_INFO
    env['PATH_INFO'] = '/' + path[2..-1].join('/')
    new_script = old_script + path[0,2].join('/')
    env['SCRIPT_NAME'] = new_script.dup

    # Open binder
    begin
      bnd.open(File.join(@path, bnam))
    rescue Sgfa::Error::NonExistent => exp
      return not_found
    end

    # call app
    begin
      env['sgfa.binder'] = bnd
      env['sgfa.binder.url'] = new_script.dup
      env['sgfa.binder.name'] = bnam
      ret = @app.call(env)
    ensure
      bnd.close
      env['PATH_INFO'] = old_path
      env['SCRIPT_NAME'] = old_script
    end

    return ret
      
  rescue => exc
    err = []
    err.push "<html><head><title>error</title></head>\n<body>\n"
    err.push "<p>" + Rack::Utils.escape_html(exc.class.name) + "</p>\n"
    err.push "<p>" + Rack::Utils.escape_html(exc.message) + "</p>\n"
    exc.backtrace.each do |bt|
      err.push "<p>" + Rack::Utils.escape_html(bt) + "</p>\n"
    end
    err.push "</body>\n</html>\n"
    return ['404', {'Content-Type' => 'text/html'}, err]
  end # def call()


  #####################################
  # Generic not found error
  def not_found()
    [404, {'Content-Type' => 'text/plain'}, ['Not found.']]
  end # def not_found

end # def WebBinders

end # module Demo
end # module Sgfa


