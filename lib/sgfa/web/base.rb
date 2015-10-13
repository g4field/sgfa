#
# Simple Group of Filing Applications
# Web interface common utilities
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'rack'
require 'time'

require_relative '../error'

module Sgfa


#####################################################################
# Web based interface to Sgfa
module Web


#####################################################################
# Shared utilities for Web classes to inherit
class Base

  HtmlPage =
    "<!DOCTYPE html>\n" +
    "<html>\n" +
    "<head>\n" +
    "<title>%s</title>\n" +
    "<link rel='stylesheet' type='text/css' href='%s'>\n" +
    "</head>\n" +
    "<body>\n" +
    "<div id='sgfa_web'>\n" +
    "<div class='title_bar'>" +
    "<div class='title'>%s</div><div class='user'>%s</div></div>\n" +
    "<div class='nav_bar'>\n%s</div>\n" +
    "%s%s</div>\n" +
    "</body>\n" +
    "</html>\n"  

  HtmlMessage = 
    "<div class='message'>%s</div>\n"

  HtmlBody = 
    "<div class='mainbody'>\n%s</div>\n"

  #####################################
  # Generate a response HTML page
  def response(env)
    
    # response code
    code = case env['sgfa.status']
      when :badreq; 400
      when :ok; 200
      when :notfound; 404
      when :deny; 402
      when :conflict; 409
      when :servererror; 500
      else; raise 'Response not set'
    end

    # returning a file
    if env['sgfa.file']
      return [code, env['sgfa.headers'], env['sgfa.file']]
    end

    # build the page and headers
    body = HtmlBody % env['sgfa.html']
    msg = env['sgfa.message'] ? (HtmlMessage % env['sgfa.message']) : ''
    html = HtmlPage % [
      env['sgfa.title'],
      env['sgfa.css'],
      env['sgfa.title'],
      _escape_html(env['sgfa.user']),
      env['sgfa.navbar'],
      msg, body
    ]
    head = {
      'Content-Type' => 'text/html; charset=utf-8',
      'Content-Length' => html.bytesize.to_s,
    }

    return [code, head, [html]]
  end # def response()


  PageNav =
    "<div class='pagenav'>%s</div>\n"

  PageNavNums = [-1000, -500, -100, -50, -10, -5, -4, -3, -2, -1, 0,
    1, 2, 3, 4, 5, 10, 50, 100, 500, 1000]

  ##########################################
  # Generate page navigation
  def _link_pages(cur, per, max, link, query)
    pages = (per-1 + max) / per
    txt = ''

    if query
      qs = '?'
      query.each{ |nam, val| qs << '%s=%s' %[_escape(nam), _escape(val)] }
    else
      qs = ''
    end

    # previous and first
    if cur > 1
      txt << "<a href='%s/%d%s'>Prev</a> &mdash; " % [link, cur-1, qs]
      txt << "<a href='%s/1%s'>First</a> &mdash; " % [link, qs]
    else
      txt << "Prev &mdash; First &mdash; "
    end

    # numbers
    PageNavNums.each do |num|
      val = cur + num
      next if val < 1 || val > pages
      if num == 0
        txt << "%d " % cur
      else
        txt << "<a href='%s/%d%s'>%d</a> " % [link, val, qs, val]
      end
    end

    # last & next
    if cur < pages
      txt << "&mdash; <a href='%s/%d%s'>Last</a> " % [link, pages, qs]
      txt << "&mdash; <a href='%s/%s%s'>Next</a>" % [link, cur+1, qs]
    else
      txt << "&mdash; Last &mdash; Next"
    end

    return PageNav % txt
  end # def _link_pages()


  #####################################
  # Generate a navbar
  def _navbar(env, act, tabs, base)
    txt = ''
    tabs.each do |name, url|
      cl = (name == act) ? 'active' : 'link'
      if url
        txt << "<div class='%s'><a href='%s/%s'>%s</a></div>\n" %
          [cl, base, url, name]
      else
        txt << "<div class='other'>%s</div>\n" % name
      end
    end
    return txt
  end # def _navbar()


  ##########################################
  # Escape HTML
  def _escape_html(txt)
    Rack::Utils.escape_html(txt)
  end # def _escape_html()


  ##########################################
  # Escape URL
  def _escape(txt)
    Rack::Utils.escape(txt)
  end # def _escape()


  #####################################
  # Escape URL using only percent encoding
  def _escape_path(txt)
    Rack::Utils.escape_path(txt)
  end # def _escape_path():


  ##########################################
  # Unescape URL
  def _escape_un(txt)
    Rack::Utils.unescape(txt)
  end # def _escape_un()
  

  #####################################
  # Create a binder transaction
  def _trans(env)
    tr = { :user => env['sgfa.user'], :groups => env['sgfa.groups'] }
    tr[:jacket] = env['sgfa.jacket.name'] if env['sgfa.jacket.name']
    return tr
  end # def _trans()


end # class Base


#####################################################################
# Provide the contents of a file in chunks. Designed to work with Rack
# response.
class FileBody

  # Size of the chunks provided by each
  ReadChunk = 256 * 1024

  # initialize new file response
  def initialize(file)
    @file = file
  end # def initialize()

  # provide the body of the file
  def each
    str = ''
    while @file.read(ReadChunk, str)
      yield str
    end
  end # def each

  # close
  def close
    if @file.respond_to?(:close!)
      @file.close!
    else
      @file.close
    end
  end # def close

end # class FileBody

end # module Web

end # module Sgfa
