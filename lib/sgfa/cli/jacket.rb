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

require 'thor'

require_relative '../jacket_fs'

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
    if !options[:fs_path]
      puts 'Jacket type and location required.'
      return
    end
    begin
      jck = ::Sgfa::JacketFs.new(options[:fs_path])
    rescue ::Sgfa::Error::NonExistent, ::Sgfa::Error::Limits => exp
      puts exp.message
      return
    end

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

end # class Jacket

end # module Cli
end # module Sgfa
