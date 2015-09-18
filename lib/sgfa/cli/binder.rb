#
# Simple Group of Filing Applications
# Command line interface for Binders
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'thor'
require 'json'

require_relative '../binder_fs'
require_relative '../demo/web_binders'
require_relative '../demo/web_css'

module Sgfa
module Cli

#####################################################################
# Command line interface for {Sgfa::Binder}.  Currently it just supports
# {Sgfa::BinderFs}.
# 
# @todo Needs to be fully implemented.  Currently just a shell.
class Binder < Thor

  class_option :fs_path, {
    type: :string,
    desc: 'Path to the binder',
  }

  class_option :user, {
    type: :string,
    desc: 'User name.',
    default: Etc.getpwuid(Process.euid).name,
  }

  class_option :body, {
    type: :string,
    desc: 'Body of an entry.',
    default: '!! No body provided using CLI tool !!',
  }

  class_option :title, {
    type: :string,
    desc: 'Title of an entry.',
    default: '!! No title provided using CLI tool !!',
  }



  #####################################
  # info
  desc 'info', 'Get basic information about the binder'
  def info

    # open binder
    if !options[:fs_path]
      puts 'Binder type and location required.'
      return
    end
    bnd = ::Sgfa::BinderFs.new
    begin
      bnd.open(options[:fs_path])
    rescue ::Sgfa::Error::Limits, ::Sgfa::Error::NonExistent => exp
      puts exp.message
      return
    end

    # print info 
    tr = {
      perms: ['info']
    }
    info = bnd.binder_info(tr)
    puts 'Text ID: %s' % info[:id_text]
    puts 'Hash ID: %s' % info[:id_hash]
    puts 'Values: %d' % info[:values].size
    puts 'Jackets: %d' % info[:jackets].size
    puts 'Users: %d' % info[:users].size

    bnd.close
  end # def info


  #####################################
  # create
  desc 'create <id_text> <type_json>', 'Create a new Binder'
  def create(id_text, init_json)

    if !options[:fs_path]
      puts 'Binder type and location required.'
      return
    end
    bnd = ::Sgfa::BinderFs.new
    tr = {
      user: options[:user],
      title: options[:title],
      body: options[:body],
    }
    begin
      init = JSON.parse(File.read(init_json), :symbolize_names => true)
      init[:id_text] = id_text
      bnd.create(options[:fs_path], tr, init)
    rescue Errno::ENOENT
      puts 'Binder type JSON file not found'
      return
    rescue JSON::JSONError
      puts 'Binder type JSON file did not parse'
      return
    rescue ::Sgfa::Error::NonExistent, ::Sgfa::Error::Limits => exp
      puts exp.message
      return
    end

  end # def create()


  #####################################
  # web_demo
  desc 'web_demo <css>', 'Run a demo web server'
  method_option :addr, {
    type: :string,
    desc: 'Address to bind to',
    default: 'localhost',
  }
  method_option :port, {
    type: :numeric,
    desc: 'Port to bind to',
    default: '8888',
  }
  method_option :dir, {
    type: :string,
    desc: 'Path to the directory containing binders',
    default: '.',
  }
  def web_demo(css)
    begin
      css_str = File.read(css)
    rescue Errno::ENOENT
      puts 'CSS file not found'
      return
    end

    app_bnd = ::Sgfa::Demo::WebBinders.new(options[:dir], '/sgfa.css')
    app_auth = Rack::Auth::Basic.new(app_bnd, 'Sgfa Demo'){|name, pass| true}
    app_css = ::Sgfa::Demo::WebCss.new(css_str, '/sgfa.css', app_auth)

    Rack::Handler::WEBrick.run(app_css, {
      :Port => options[:port],
      :BindAddress => options[:addr],
      })

  end # def web()

end # class Binder

end # module Cli
end # module Sgfa
