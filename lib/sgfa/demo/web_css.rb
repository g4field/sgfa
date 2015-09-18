#
# Simple Group of Filing Applications
# Demo server for 
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'time'

module Sgfa
module Demo


#####################################################################
# Simple Rack app which serves a static CSS file and passes all other
# requests along to another app.
class WebCss

  #####################################
  # Initial setup
  #
  # @param css [String] The CSS to serve
  # @param path [String] Where to serve it
  # @param app [#call] The app which gets everything else
  #
  def initialize(css, path, app)
    @app = app
    @css = css
    @path = path
    @header = {
      'Content-Type' => 'text/css; charset=utf-8',
      'Content-Length' => @css.bytesize.to_s,
    }
  end


  #####################################
  # The Rack app
  #
  # @param env [Hash] The Rack environment
  # @return [Array] Rack return of status, headers, and body
  #
  def call(env)
    if env['PATH_INFO'] == @path && env['REQUEST_METHOD'] == 'GET'
      exp = (Time.now + 60*60).rfc2822
      @header['Expires'] = exp
      [200, @header, [@css]]
    else
      @app.call(env)
    end
  end

end # class WebCss

end # module Demo
end # module Sgfa
