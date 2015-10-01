#
# Simple Group of Filing Applications
# Command line interface for Jackets
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'aws-sdk'
require 'thor'

require_relative '../jacket_fs'
require_relative '../store_s3'

module Sgfa
module Cli

#####################################################################
# Command line interface for {Sgfa::Jacket}.  Currently it just supports
# {Sgfa::JacketFs}.
# 
# @todo Needs to be fully implemented.  Currently just a shell.
class Jacket < Thor

  class_option :fs_path, {
    type: :string,
    desc: 'Path to the jacket',
  }

  #####################################
  # info
  desc 'info', 'Get basic information about the jacket'
  def info

    # open jacket
    jck = _open_jacket
    return if !jck

    # print info
    hst = jck.read_history
    puts 'Text ID: %s' % jck.id_text
    puts 'Hash ID: %s' % jck.id_hash
    if hst
      puts 'Entries: %d' % hst.entry_max
      puts 'History: %d' % hst.history
      puts 'Last edit: %s' % hst.time_str
    else
      puts 'No history.'
    end
    jck.close

  end # def info


  #####################################
  # Print Entry
  desc 'entry <e-spec>', 'Print entry'
  method_option :hash, {
    type: :boolean,
    desc: 'Display the entry hash or not',
    default: false,
  }
  def entry(spec)

    # get entry and revision nums
    ma = /^\s*(\d+)(-(\d+))?\s*$/.match(spec)
    if !ma
      puts "Entry e-spec must be match format x[-y]\n" +
        "Where x is the entry number and y is the optional revision number."
      return
    end
    enum = ma[1].to_i
    rnum = (ma.length == 4) ? ma[3].to_i : 0

    # open jacket
    jck = _open_jacket
    return if !jck

    # read
    begin
      ent = jck.read_entry(enum, rnum)
    rescue ::Sgfa::Error::NonExistent => exp
      puts exp.message
      return
    end
    jck.close

    # display
    tags = ent.tags.join("\n           ")
    atts = ent.attachments.map{|anum, hnum, hash|
      '%d-%d-%d %s' % [enum, anum, hnum, hash]}.join("\n           ")
    if options[:hash]
      puts "Hash     : %s" % ent.hash
    end
    puts "Title    : %s" % ent.title
    puts "Date/Time: %s" % ent.time.localtime.strftime("%F %T %z")
    puts "Revision : %d" % ent.revision
    puts "History  : %d" % ent.history
    puts "Tags     : %s" % tags
    puts "Files    : %s" % atts
    puts "Body     :\n%s" % ent.body

  end # def entry()


  #####################################
  # Display History
  desc 'history [<hnum>]', 'Display the current or specified History'
  method_option :hash, {
    type: :boolean,
    desc: 'Display the entry hash or not',
    default: false,
  }
  def history(hspec='0')

    # get history num
    ma = /^\s*(\d+)\s*$/.match(hspec)
    if !ma
      hnum = 0
    else
      hnum = ma[1].to_i
    end

    # open jacket
    jck = _open_jacket
    return if !jck

    # read history
    begin
      hst = jck.read_history(hnum)
    rescue ::Sgfa::Error::NonExistent => exp
      puts exp.message
      return
    end
    jck.close

    # display
    hnum = hst.history
    puts "Hash      : %s" % hst.hash if options[:hash]
    puts "Previous  : %s" % hst.previous if options[:hash]
    puts "History   : %d" % hnum
    puts "Date/Time : %s" % hst.time.localtime.strftime("%F %T %z")
    puts "User      : %s" % hst.user
    hst.entries.each do |enum, rnum, hash|
      puts "Entry     : %d-%d %s" % [enum, rnum, hash]
    end
    hst.attachments.each do |enum, anum, hash|
      puts "Attachment: %d-%d-%d %s" % [enum, anum, hnum, hash]
    end

  end # def history()


  #####################################
  # Output attachment
  desc 'attach <a-spec>', 'Output attachment'
  method_option :output, {
    type: :string,
    desc: 'Output file',
    required: true
  }
  def attach(aspec)

    # get attachment spec
    ma = /^\s*(\d+)-(\d+)-(\d+)\s*$/.match(aspec)
    if !ma
      puts "Attachment specification is x-y-z\n" +
        "x = entry number\ny = attachment number\nz = history number"
      return
    end
    enum, anum, hnum = ma[1,3].map{|st| st.to_i }

    # open jacket
    jck = _open_jacket
    return if !jck

    # read attachment
    begin
      fi = jck.read_attach(enum, anum, hnum)
    rescue ::Sgfa::Error::NonExistent => exp
      puts exp.message
      return
    end
    jck.close

    # output
    begin
      out = File.open(options[:output], 'wb')
    rescue
      fi.close
      puts "Unable to open output file"
      return
    end

    # copy
    IO.copy_stream(fi, out)
    fi.close
    out.close

  end # def attach()


  #####################################
  # Check jacket
  desc 'check', 'Checks jacket history chain'
  method_option :max, {
    type: :numeric,
    desc: 'Maximum history to check',
  }
  method_option :min, {
    type: :numeric,
    desc: 'Minimum history to check',
  }
  method_option :hash, {
    type: :string,
    desc: 'Known good hash of maximum history',
  }
  method_option :entry, {
    type: :boolean,
    desc: 'Hash entries and validate',
    default: true,
  }
  method_option :attach, {
    type: :boolean,
    desc: 'Hash attachments and validate',
    default: false,
  }
  method_option :missing, {
    type: :numeric,
    desc: 'Number of missing history items to check',
    default: 0,
  }
  method_option :level, {
    type: :string,
    desc: 'Debug level, "debug", "info", "warn", "error"',
    default: 'error',
  }
  def check

    # open jacket
    jck = _open_jacket
    return if !jck

    # options
    opts = {}
    log = Logger.new(STDOUT)
    opts[:log] = log
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
    opts[:hash_entry] = options[:entry]
    opts[:hash_attach] = options[:attach]
    opts[:miss_history] = options[:missing]
    opts[:max_history] = options[:max] if options[:max]
    opts[:min_history] = options[:min] if options[:min]
    opts[:max_hash] = options[:hash] if options[:hash]

    # check
    jck.check(opts)
    jck.close

  end # def check()


  #####################################
  # Backup to aws
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
  def backup_s3()
    # open jacket
    jck = _open_jacket
    return if !jck

    # read in JSON config
    json = File.read(options[:key])
    creds = JSON.parse(json)
    opts = {
      region: creds['aws_region'],
      access_key_id: creds['aws_id'],
      secret_access_key: creds['aws_key'],
    }
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

    puts 'id: %s' % creds['aws_id']
    puts 'secret: %s' % creds['aws_key']
    puts 'bucket: %s' % options[:bucket]
    
    # client
    s3 = ::Aws::S3::Client.new(opts)
    sto = ::Sgfa::StoreS3.new
    sto.open(s3, options[:bucket])
    
    # backup
    jck.backup(sto, log: log)
    jck.close

  end # def backup_s3()


  private


  #####################################
  # Open the jacket
  def _open_jacket()
    if !options[:fs_path]
      puts 'Jacket type and location required.'
      return false
    end

    begin
      jck = ::Sgfa::JacketFs.new(options[:fs_path])
    rescue ::Sgfa::Error::NonExistent, ::Sgfa::Error::Limits => exp
      puts exp.message
      return false
    end

    return jck
  end # def _open_jacket


end # class Jacket

end # module Cli
end # module Sgfa
