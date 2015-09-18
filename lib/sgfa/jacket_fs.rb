#
# Simple Group of Filing Applications
# Jacket implemented using filesystem storage and locking
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'json'

require_relative 'error'
require_relative 'jacket'
require_relative 'lock_fs'
require_relative 'state_fs'
require_relative 'store_fs'

module Sgfa


#####################################################################
# An implementation of {Jacket} using file system storage and locking
# provided by {LockFs}, {StoreFs}, and {StateFs}
class JacketFs < Jacket


  #####################################
  # Create a new jacket
  #
  # @param path [String] Path to create the jacket
  # @param id_text [String] Text ID of the jacket
  # @return [String] Hash ID of the jacket
  # @raise [Error::Limits] if id_text exceeds allowed limits
  # @raise [Error::Conflict] if path already exists
  def self.create(path, id_text)
    Jacket.limits_id(id_text)

    # info
    id_hash = Digest::SHA256.new.update(id_text).hexdigest
    info = {
      'sgfa_jacket_ver' => 1,
      'id_hash' => id_hash,
      'id_text' => id_text,
    }
    json = JSON.pretty_generate(info) + "\n"

    # create
    begin
      Dir.mkdir(path)
    rescue Errno::EEXIST
      raise Error::Conflict, 'Jacket path already exists'
    end
    fn_info = File.join(path, 'sgfa_jacket.json')
    File.open(fn_info, 'w', :encoding => 'utf-8'){|fi| fi.write json }
 
    # create state and store
    StateFs.create(File.join(path, 'state'))
    StoreFs.create(File.join(path, 'store'))

    return id_hash
  end # def self.create()


  #####################################
  # Initialize new Jacket, optionally opening
  #
  # @param path [String] path Path to the jacket
  # @raise (see #open)
  def initialize(path=nil)
    super()
    @path = nil
    @state = nil
    @store = nil
    @lock = nil
    open(path) if path
  end # def initialize


  #####################################
  # Open a jacket
  #
  # @param path [String] Path to the jacket
  # @return [JacketFs] self
  # @raise [Error::Sanity] if jacket already open
  # @raise [Error::Corrupt] if Jacket info is corrupt
  # @raise [Error::NonExistent] if path does not exist and contain a valid
  #   jacket info file
  def open(path)
    raise Error::Sanity, 'Jacket already open' if @path

    @lock = LockFs.new
    begin
      json = @lock.open(File.join(path, 'sgfa_jacket.json'))
      info = JSON.parse(json, :symbolize_names => true)
    rescue Errno::ENOENT
      raise Error::NonExistent, 'Jacket does not exist'
    rescue JSON::NestingError, JSON::ParserError
      @lock.close
      @lock = nil
      raise Error::Corrupt, 'Jacket info corrupt'
    end

    @store = StoreFs.new(File.join(path, 'store'))
    @state = StateFs.new(File.join(path, 'state'))

    @id_text = info[:id_text]
    @id_hash = info[:id_hash]
    @path = path.dup

    return self
  end # def open()


  #####################################
  # Close a jacket
  #
  # @raise [Error::Sanity] if jacket not open
  def close
    raise Error::Sanity, 'Jacket not open' if !@path
    @lock.close
    @lock = nil
    @state.close
    @state = nil
    @store.close
    @store = nil
    @id_hash = nil
    @id_text = nil
    @path = nil
  end # def close


end # class JacketFs

end # module Sgfa
