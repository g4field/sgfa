#
# Simple Group of Filing Applications
# Jacket state using filesystem storage.
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'fileutils'
require 'tempfile'

require_relative 'error'

module Sgfa


#####################################################################
# Maintains {Jacket} state using filesystem storage.
#
# This stores the current {History} number for a {Jacket} as well as
# the current revision numbers for each {Entry}.  It also maintains
# for each tag, a date/time ordered list of all {Entry} items where
# the current revision contains that tag.  Finally, it keeps a list of
# all tags which are present in the {Jacket}.
#
# The current revision of each entry is stored in a file named
# "_state" with each line consisting of a 9-digit current
# revision (zero padded) followed by newline.  The current {History}
# number is stored on line zero, with each {Entry} on the corresponding
# line.
#
# The list of tags is in a file named "_list" and consists of
# each tag followed by a newline.
#
# Each tag is kept in a seperate file, named with the tag name.  Each
# line consists of a UTC date/time in "YYYY-MM-DD HH:MM:SS" format, 
# followed by a space, and the 9-digit (zero padded) {Entry} number,
# with a newline.  A "_all" tag tracks all {Entry}s.
#
class StateFs


  # Tag which has all {Entry} items in a {Jacket}
  TagAll = '_all'

  # File name to store list of all tags
  TagList = '_list'

  # File name used to store the current {History} and {Entry} revision
  # numbers
  TagState = '_state'

  # Size (bytes) of each entry revision
  EntrySize = 10

  # Size (bytes) of each tag date/time and entry listing
  TagSize = 30

  # Regular expression to get date/time string and entry number
  # from a tag file
  TagReg = /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) (\d{9})$/

  private_constant :TagAll, :TagList, :TagState, :EntrySize, :TagSize,
    :TagReg


  #####################################
  # Create a new state
  #
  # @param path [String] Path to the directory containing the state
  # @raise [Error::Conflict] if path already exists
  def self.create(path)
    begin
      Dir.mkdir(path)
    rescue Errno::EEXIST
      raise Error::Conflict, 'State path already exists'
    end
    FileUtils.touch(File.join(path, TagList))
    File.open(File.join(path, TagState), 'wb'){|fi| fi.write "000000000\n"}
  end # def self.create()


  #####################################
  # Initialize new state, optionally opening
  #
  # @param path [String] Path to the directory containing the state
  # @raise (see #open)
  def initialize(path=nil)
    open(path) if path
  end # def initialize()


  #####################################
  # Open the state
  #
  # @param path [String] Path to the directory containing the state
  # @raise [Error::NonExistent] if path does not exist
  # @return [StateFs] self
  def open(path)
    fn = File.join(path, TagState)
    begin
      @file = File.open(fn, 'r+b')
    rescue Errno::ENOENT
      raise Error::NonExistent, 'State path does not exist'
    end
    @path = path.dup
    return self
  end # def open()


  #####################################
  # Close the state
  #
  # @raise [Error::Sanity] if state is not open
  # @return [StateFs] self
  def close
    raise Error::Sanity, 'State not open' if !@path
    @file.close
    @path = nil
    return self
  end # def close


  #####################################
  # Reset to empty state
  #
  # @raise [Error::Sanity] if state is not open
  # @return (see #open)
  def reset
    raise Error::Sanity, 'State not open' if !@path

    path = @path
    self.close

    FileUtils.remove_dir(path)
    Dir.mkdir(path)
    FileUtils.touch(File.join(path, TagList))
    File.open(File.join(path, TagState), 'wb'){|fi| fi.write "000000000\n"}
    
    return open(path)
  end # def reset


  #####################################
  # Set current revision number for an entry
  #
  # @param enum [Integer] Entry number
  # @param rnum [Integer] Current revision number
  # @raise [Error::Sanity] if state is not open
  # @raise [ArgumentError] if enum or rnum is negative
  # @return [StateFs] self
  def set(enum, rnum)
    raise Error::Sanity, 'State not open' if !@path
    if enum < 0 || rnum < 0
      raise ArgumentError, 'Invalid entry/revision numbers'
    end

    @file.seek(enum*EntrySize, IO::SEEK_SET)
    @file.write("%09d\n" % rnum)
    return self
  end # def set


  #####################################
  # Get current revision number for an entry
  #
  # @param enum [Integer] Entry number
  # @return [Integer] Current revision number
  # @raise [Error::Sanity] if state not open
  # @raise [ArgumentError] if enum is negative
  # @raise [Error::NonExistent] if entry number does not exist
  def get(enum)
    raise Error::Sanity, 'State not open' if !@path
    raise ArgumentError, 'Invalid entry number' if enum < 0
    
    @file.seek(enum*EntrySize, IO::SEEK_SET)
    res = @file.read(EntrySize)
    raise Error::NonExistent, 'Entry does not exist' if !res || res[0] == "\x00"
    return res.to_i
  end # def get()


  #####################################
  # Read list of tags
  #
  # @return [Array] List of strings containing tag names
  # @raise [Error::Sanity] if state not open
  # @raise [Error::Corrupt] if tag list is missing
  def list
    tagh, max = _list
    return tagh.keys
  end # def list


  #####################################
  # Read raw tag list
  # return [Array] \[max_tagn, tag_hash\]
  def _list
    raise Error::Sanity, 'State not open' if !@path

    ftn = File.join(@path, TagList)
    begin
      txt = File.read(ftn)
    rescue Errno::ENOENT
      raise Error::Corrupt, 'Unable to read tag list'
    end

    tagh = {}
    max = 0
    txt.lines.each do |ln|
      ma = /^(\d{9}) (.*)$/.match(ln)
      raise Error::Corrupt, 'Tag list format incorrect' if !ma
      num = ma[1].to_i
      tagh[ma[2]] = num
      max = num if num > max
    end

    return tagh, max
  end # _list
  private :_list


  #####################################
  # Read entry numbers from a tag
  #
  # @param name [String] Tag name
  # @param offs [Integer] Offset to begin reading
  # @param max [Integer] Maximum number of entries to return
  # @raise [Error::Sanity] if state not open
  # @raise [Error::NonExistent] if tag does not exist
  # @raise [Error::Corrupt] if file format is bad
  # @return [Array] Total number of entries in the tag, and possibly empty
  #   array of entry numbers.
  def tag(name, offs, max)
    raise Error::Sanity, 'State not open' if !@path

    tagh, max = _list
    raise Error::NonExistent, 'Tag does not exist' if !tagh[name]
    fn = File.join(@path, tagh[name].to_s)
    begin
      fi = File.open(fn, 'rb')
    rescue Errno::ENOENT
      raise Error::Corrupt, 'Tag file missing'
    end

    ents = []
    size = nil
    begin
      size = fi.size / TagSize
      return [size, ents] if( offs > size || max == 0 )
      num = (offs+max > size) ? (size - offs) : max
      fi.seek(((size-offs-num)*TagSize), IO::SEEK_SET)
      num.times do
        ln = fi.read(TagSize)
        ma = TagReg.match(ln)
        raise Error::Corrupt, 'Bad tag format' unless ma
        ents.push( ma[2].to_i )
      end
    ensure
      fi.close
    end

    return [size, ents]
  end # def tag()


  #####################################
  # Update tags based on new {History}
  #
  # @param cng [Hash] Changes in the format returned by {History#next}
  # @raise [Error::Sanity] if state not open
  # @raise [Error::Corrupt] if file format is bad
  # @raise [Error::Corrupt] if list of tags is missing
  # @raise [Error::Corrupt] if existing tag is missing
  # @return [StateFs] self
  def update(cng)

    # read list of tags
    changed = false
    thash, max = _list
#    self.list.each{|tag| thash[tag] = true }

    cng.each do |tag, hc|
      cnt = 0

      # sorted changes
      se = hc.to_a.select{|en, ti| ti }.sort{|aa, bb| aa[1] <=> bb[1] }

      # files
      if thash[tag]
        fn = File.join(@path, thash[tag].to_s)
        begin
          oldf = File.open(fn, 'rb')
        rescue Errno::ENOENT
          raise Error::Corrupt, 'Existing tag is missing'
        end
      else
        fn = File.join(@path, (max + 1).to_s)
        oldf = nil
      end
      newf = Tempfile.new('state', @path, :encoding => 'ASCII-8BIT')

      # merge new into old file
      while oldf && ln = oldf.read(TagSize)
        unless ma = TagReg.match(ln)
          newf.close!
          raise Error::Corrupt, 'Bad tag format'
        end

        tme = ma[1]
        enum = ma[2].to_i

        next if hc.has_key?(enum)

        while se.size > 0 && tme > se[0][1]
          ne, nt = se.shift
          newf.write("%s %09d\n" % [nt, ne])
          cnt += 1
        end

        newf.write(ln)
        cnt += 1
      end
      oldf.close() if oldf

      # write out any remaining new
      while ary = se.shift
        ne, nt = ary
        newf.write("%s %09d\n" % [nt, ne])
        cnt += 1
      end

      # adjust files
      if cnt == 0
        if oldf
          File.unlink(fn)
          thash.delete(tag)
          changed = true
        end
      else
        FileUtils.ln(newf.path, fn, :force => true)
        if !oldf
          max += 1
          thash[tag] = max
          changed = true
        end
      end
      newf.close!
    end

    # write list of tags
    if changed
      fnl = File.join(@path, TagList)
      File.open(fnl, 'w', :encoding => 'utf-8') do |fi|
        thash.each{|tag, num| fi.puts '%09d %s' % [num, tag] }
      end
    end

    return self
  end # def update()

end # class StateFs

end # module Sgfa
