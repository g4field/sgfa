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


  #####################################
  # info
  desc 'info', 'Get basic information about the binder'
  def info

    # open binder
    return if !(bnd = _open_binder)

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
  method_option :user, {
    type: :string,
    desc: 'User name.',
    default: Etc.getpwuid(Process.euid).name,
  }
  method_option :body, {
    type: :string,
    desc: 'Body of an entry.',
    default: '!! No body provided using CLI tool !!',
  }
  method_option :title, {
    type: :string,
    desc: 'Title of an entry.',
    default: '!! No title provided using CLI tool !!',
  }
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

  end # def web_demo()


  #####################################
  # Backup to AWS S3
  desc 'backup_s3', 'Backup to AWS S3'
  method_option :key, {
    type: :string,
    desc: 'Path of AWS credentials',
    required: true,
  }
  method_option :bucket, {
    type: :string,
    desc: 'S3 bucket name',
    required: true,
  }
  method_option :level, {
    type: :string,
    desc: 'Debug level, "debug", "info", "warn", "error"',
    default: 'error',
  }
  method_option :last, {
    desc: 'Last backup state file name',
    type: :string,
  }
  method_option :save, {
    desc: 'Save backup state to file name',
    type: :string,
  }
  def backup_s3()

    return if !(aws = _get_aws)
    return if !(bnd = _open_binder)
    log = _get_log
    last = _get_last
    s3 = ::Aws::S3::Client.new(aws)
    sto = ::Sgfa::StoreS3.new
    sto.open(s3, options[:bucket])
    last = bnd.backup_push(sto, prev: last, log: log)
    bnd.close
    sto.close
    _put_last(last)

  end # def backup_s3() 


  #####################################
  # Restore from AWS S3
  desc 'restore_s3 <id_text>', 'Restore from AWS S3'
  method_option :key, {
    type: :string,
    desc: 'Path of AWS credentials',
    required: true,
  }
  method_option :bucket, {
    type: :string,
    desc: 'S3 bucket name',
    required: true,
  }
  method_option :level, {
    type: :string,
    desc: 'Debug level, "debug", "info", "warn", "error"',
    default: 'error',
  }
  def restore_s3(id_text)
    if !options[:fs_path]
      puts 'Binder type and location required.'
     return
    end
    return if !(aws = _get_aws)
    log = _get_log
    s3 = ::Aws::S3::Client.new(aws)
    sto = ::Sgfa::StoreS3.new
    sto.open(s3, options[:bucket])
    bnd = ::Sgfa::BinderFs.new
    bnd.create_raw(options[:fs_path], id_text)
    bnd.open(options[:fs_path])
    bnd.backup_pull(sto, log: log)
    bnd.close
    sto.close
  end # def restore_s3() 


  #####################################
  # backup to filesystem
  desc 'backup_fs <dir>', 'Backup to file system'
  method_option :last, {
    desc: 'Last backup state file name',
    type: :string,
  }
  method_option :save, {
    desc: 'Save backup state to file name',
    type: :string,
  }
  method_option :level, {
    type: :string,
    desc: 'Debug level, "debug", "info", "warn", "error"',
    default: 'error',
  }
  def backup_fs(dest)
    return if !(bnd = _open_binder)
    log = _get_log
    last = _get_last
    sto = ::Sgfa::StoreFs.new
    sto.open(dest)
    last = bnd.backup_push(sto, prev: last, log: log)
    bnd.close
    sto.close
    _put_last(last)
  end # def backup_fs()

  
  #####################################
  # Restore from filesystem
  desc 'restore_fs <id_text> <backup_store>', 'Restore from file system'
  method_option :level, {
    type: :string,
    desc: 'Debug level, "debug", "info", "warn", "error"',
    default: 'error',
  }
  def restore_fs(id_text, bak)
    if !options[:fs_path]
      puts 'Binder type and location required.'
     return
    end
    sto = ::Sgfa::StoreFs.new
    sto.open(bak)
    log = _get_log
    bnd = ::Sgfa::BinderFs.new
    bnd.create_raw(options[:fs_path], id_text)
    bnd.open(options[:fs_path])
    bnd.backup_pull(sto, log: log)
    bnd.close
    sto.close
  end # def restore_fs()


  no_commands do


  # Open the binder
  def _open_binder()
    # open binder
    if !options[:fs_path]
      puts 'Binder type and location required.'
      return false
    end
    bnd = ::Sgfa::BinderFs.new
    begin
      bnd.open(options[:fs_path])
    rescue ::Sgfa::Error::Limits, ::Sgfa::Error::NonExistent => exp
      puts exp.message
      return false
    end
    return bnd
  end # def _open_binder()


  # get the log
  def _get_log
    log = Logger.new(STDOUT)
    case options[:level]
      when 'debug'
        log.level = Logger::DEBUG
      when 'info'
        log.level = Logger::INFO
      when 'warn'
        log.level = Logger::WARN
      else
        log.level = Logger::ERROR
    end
    return log
  end # def _get_log


  # Get AWS creds
  def _get_aws
    json = File.read(options[:key])
    creds = JSON.parse(json)
    opts = {
      region: creds['aws_region'],
      access_key_id: creds['aws_id'],
      secret_access_key: creds['aws_key'],
    }
    return opts

  rescue Errno::ENOENT
    puts 'AWS keys file not found'
    return false

  rescue Errno::EACCESS
    puts 'AWS key file permission denied'
    return false

  rescue JSON::JSONError
    puts 'AWS key file JSON parse error'
    return false
  end # def get_aws


  # Get last option
  def _get_last()
    return {} if !options[:last]
    json = File.read(options[:last])
    last = JSON.parse(json)
    return last
  rescue Errno::ENOENT
    puts "Last backup state file not found"
    exit
  rescue Errno::EACCESS
    puts "Access denied to last backup state file"
    exit
  rescue JSON::JSONError
    puts "Last backup state file parse failed"
    exit
  end # def _get_last()
  private :_get_last


  # Save last
  def _put_last(last)
    return if !options[:save]
    json = JSON.pretty_generate(last) + "\n"
    File.open(options[:save], 'w', :encoding => 'utf-8'){|fi| fi.write json}
  rescue Errno::EACCESS
    puts "Access denied to backup state file"
    exit
  end # def _put_last()
  private :_put_last

  end


end # class Binder

end # module Cli
end # module Sgfa
