#
# Simple Group of Filing Applications
# Jacket store using filesystem storage.
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'tempfile'
require 'fileutils'

require_relative 'error'

module Sgfa


#####################################################################
# Stores copies of {History}, {Entry}, and attached files that are
# in a {Jacket} using filesystem storage.
#
# Storage and retrieval are based on type (i.e. History, Entry, or
# attached file) and the item hash.  The item hash is generated from
# the {Jacket} id_hash, the type, and the specific number.  This allows
# for a single store to serve as the repository of multiple {Jacket}s
# if desired (e.g. using a cloud permanent object store).
#
# Each item is stored in a file, organized into directories based on the
# first two characters of the item hash, a file name consisting of the
# remaining item hash, dash, and a character indicating the type.
#
class StoreFs


  #####################################
  # Initialize a new store object, optionally opening
  #
  # @param (see #open)
  # @raise (see #open)
  def initialize(path=nil)
    open(path) if path
  end # def initialize()


  #####################################
  # Create a new store
  # @param path [String] Path to the directory containing the store
  # @raise [Error::Conflict] if path already exists
  def self.create(path)
    begin
      Dir.mkdir(path)
    rescue Errno::EEXIST
      raise Error::Conflict, 'Store already exists'
    end
  end # def self.create()


  #####################################
  # Open the store
  #
  # @param path [String] Path to the directory containing the store
  # @raise [Error::NonExistent] if path does not exist
  # @return [StoreFs] self
  def open(path)
    raise Error::NonExistent, 'Store does not exist' if !File.directory?(path)
    @path = path
    return self
  end # open()


  #####################################
  # Close the store
  #
  # @raise [Error::Sanity] if store is not open
  # @return [StoreFs] self
  def close
    raise Error::Sanity, 'Store is not open' if !@path
    @path = nil
    return self
  end # def close


  #####################################
  # File name for an item
  #
  # @param type [Symbol] Type of the item
  # @param item [String] Item hash identifier
  # @raise [NotImplementedError] if type is not valid
  # @return [String] the file name
  def _fn(type, item)
    case type
      when :entry then ext = 'e'
      when :history then ext = 'h'
      when :file then ext = 'f'
      else raise NotImplementedError, 'Invalid item type'
    end

    return '%s/%s/%s-%s' % [@path, item[0,2], item[2..-1], ext]
  end # def _fn()
  private :_fn


  #####################################
  # Get a temp file to use to create an item for storage
  #
  # @note Encoding on the file is set to 'utf-8' by default
  # @raise [Error::Sanity] if store not open
  # @return [Tempfile] the temporary file
  def temp
    raise Error::Sanity, 'Store not open' if !@path
    Tempfile.new('blob', @path, :encoding => 'utf-8')
  end # def temp


  #####################################
  # Read an item
  #
  # @param (see #_fn)
  # @raise [NotImplementedError] if type is not valid
  # @raise [Error::Sanity] if store not open
  # @return [File] Item opened in read only format or false if not found
  def read(type, item)
    raise Error::Sanity, 'Store not open' if !@path

    fn = _fn(type, item)
    begin
      fi = File.open(fn, 'r', :encoding => 'utf-8')
    rescue Errno::ENOENT
      return false
    end
    return fi
  end # def read()


  #####################################
  # Write an item
  #
  # If content is a string, it will be written to a file and saved.
  # If content is a file it will be deleted from it's current location.
  #
  # @param (see #_fn)
  # @param cont [File, String] Content to store
  # @raise [Error::Sanity] if store not open
  # @raise [NotImplementedError] if type is not valid
  def write(type, item, cont)
    raise Error::Sanity, 'Store not open' if !@path
    fn = _fn(type, item)

    if cont.is_a?(String)
      tf = temp
      tf.write cont
      cont = tf
    end

    begin
      FileUtils.ln(cont.path, fn, :force => true)
    rescue Errno::ENOENT
      Dir.mkdir(File.dirname(fn))
      FileUtils.ln(cont.path, fn)
    end
    if cont.respond_to?( :close! )
      cont.close!
    else
      File.unlink(cont, path)
      cont.close
    end

    return self
  end # def write()


  #####################################
  # Delete an item
  #
  # @param (see #_fn)
  # @raise [NotImplementedError] if type is not valid
  # @raise [Error::Sanity] if store not open
  # @return [Boolean] if item deleted
  def delete(type, item)
    raise Error::Sanity, 'Store not open' if !@path
    fn = _fn(type, item)

    begin
      File.unlink(fn)
    rescue Errno::ENOENT
      return false
    end
    return true
  end # def delete()


  #####################################
  # Get size of an item in bytes
  #
  # @param (see #_fn)
  # @raise [NotImplementedError] if type is not valid
  # @raise [Error::Sanity] if store not open
  # @return [Integer, Boolean] Item size, or false if item does not exist
  def size(type, item)
    fn = _fn(type, item)
    begin
      size = File.size(fn)
    rescue Errno::ENOENT
      return false
    end
    return size
  end # def size()


end # class StoreFs

end # module Sgfa
