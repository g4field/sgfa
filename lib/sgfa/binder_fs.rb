#
# Simple Group of Filing Applications
# Binder implemented using filesystem storage and locking
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'json'
require 'tempfile'

require_relative 'error'
require_relative 'binder'
require_relative 'jacket_fs'
require_relative 'lock_fs'

module Sgfa


#####################################################################
# An implementation of {Binder} using file system storage, {LockFs},
# and {JacketFs}.
class BinderFs < Binder

  #####################################
  # Create a new binder
  #
  # @param path [String] Path to the binder
  # @param tr (see Binder#jacket_create)
  # @param init [Hash] The binder initialization options
  # @return [String] The hash ID of the new binder
  def create(path, tr, init)
    raise Error::Sanity, 'Binder already open' if @path
    Binder.limits_create(init)

    # create directory
    begin
      Dir.mkdir(path)
    rescue Errno::EEXIST
      raise Error::Conflict, 'Binder path already exists'
    end

    # create control binder
    dn_ctrl = File.join(path, '0')
    id_hash = JacketFs.create(dn_ctrl, init[:id_text])
    jck = JacketFs.new(dn_ctrl)

    # do the common creation
    @path = path
    @id_hash = id_hash
    @jackets = {}
    @users = {}
    @values = {}
    _create(jck, tr, init)
    jck.close
    _cache_write
    @path = nil
    @id_hash = nil

    # write info
    info = {
      'sgfa_binder_ver' => 1,
      'id_hash' => id_hash,
      'id_text' => init[:id_text],
    }
    json = JSON.pretty_generate(info) + "\n"
    fn_info = File.join(path, 'sgfa_binder.json')
    File.open(fn_info, 'w', :encoding => 'utf-8'){|fi| fi.write json }
    
    return id_hash
  end # def create()


  #####################################
  # Open a binder
  # 
  # @param path [String] Path to the binder
  # @return [BinderFs] self
  def open(path)
    raise Error::Sanity, 'Binder already open' if @path

    @lock = LockFs.new
    begin
      json = @lock.open(File.join(path, 'sgfa_binder.json'))
    rescue Errno::ENOENT
      raise Error::NonExistent, 'Binder does not exist'
    end
    begin
      info = JSON.parse(json, :symbolize_names => true)
    rescue JSON::NestingError, JSON::ParserError
      @lock.close
      @lock = nil
      raise Error::Corrupt, 'Binder info corrupt'
    end

    @id_hash = info[:id_hash]
    @id_text = info[:id_text]
    @path = path.dup
    
    return self
  end # def open()


  #####################################
  # Close the binder
  #
  # @return [BinderFs] self
  def close()
    raise Error::Sanity, 'Binder not open' if !@path
    @lock.close
    @lock = nil
    @id_hash = nil
    @id_text = nil
    @path = nil
    return self
  end # def close()


  #####################################
  # Temporary file to write attachments to
  #
  # @return [Tempfile] Temporary file
  def temp()
    raise Error::Sanity, 'Binder not open' if !@path
    Tempfile.new('blob', @path, :encoding => 'utf-8')
  end # def temp()


  private


  #####################################
  # Create a jacket
  def _jacket_create(num)
    jp = File.join(@path, num.to_s)
    id_text = 'binder %s jacket %d %s' % 
      [@id_hash, num, Time.now.utc.strftime('%F %T')]
    id_hash = JacketFs.create(jp, id_text)
    [id_text, id_hash]
  end # def _jacket_create()


  #####################################
  # Open a jacket
  def _jacket_open(num)
    jck = JacketFs.new
    jck.open(File.join(@path, num.to_s))
    return jck
  end # def _jacket_open()


  #####################################
  # Write cache
  def _cache_write
    jck = []
    @jackets.each{|nam, hash| jck.push hash}
    vals = []
    @values.each{|val, sta| vals.push [val, sta]}
    usrs = []
    @users.each{|un, pl| usrs.push({name: un, perms: pl}) }
    info = {
      jackets: jck,
      values: vals,
      users: usrs,
    }
    json = JSON.pretty_generate(info) + "\n"
    
    fnc = File.join(@path, 'cache.json')
    File.open(fnc, 'w', :encoding => 'utf-8'){|fi| fi.write json}
  end # def _cache_write


  #####################################
  # Read cache
  def _cache_read
    fnc = File.join(@path, 'cache.json')
    json = nil
    info = nil
    
    begin
      json = File.read(fnc, :encoding => 'utf-8')
      info = JSON.parse(json, :symbolize_names => true)
    rescue Error::ENOENT
      raise Error::Corrupt, 'Binder cache does not exist'
    rescue JSON::NestingError, JSON::ParserError
      raise Error::Corrupt, 'Binder cache does not parse'
    end

    @jackets = {}
    info[:jackets].each{|hash| @jackets[hash[:name]] = hash }
    @users = {}
    info[:users].each{|ha| @users[ha[:name]] = ha[:perms] }
    @values = {}
    info[:values].each{|val, sta| @values[val] = sta }
  end # def _cache_read


end # class BinderFS

end # module Sgfa
