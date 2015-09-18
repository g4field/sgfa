#
# Simple Group of Filing Applications
# Entry item
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'digest/sha2'
require 'json'

require_relative 'error'

module Sgfa


#####################################################################
# The Entry is the basic item which is being filed in a {Jacket}.
# 
# The Entry has attributes:
# * hash - SHA256 hash of the canonical encoding
# * canonical - the canonical encoded string
# * jacket - the {Jacket} hash ID the entry belongs to
# * entry - the entry number
# * revision - the revision number
# * history - the history number where the entry was recorded
# * title - one line description
# * time - date/time used to sort within a tag
# * time_str - encoded version of the time in UTC
# * body - multiple line text of the entry
# * tags - list of all associated tags (may be empty)
# * attachments - list of attached files with names (may be empty)
# * max_attach - the maximum number of attachments ever belonging to
#   the entry
# 
class Entry


  #########################################################
  # @!group Limits checks
  
  # Max chars in title
  LimTitleMax = 128

  # Invalid chars in title
  LimTitleInv = /[[:cntrl:]]/

  #####################################
  # Limit check, title
  def self.limits_title(str)
    Error.limits(str, 1, LimTitleMax, LimTitleInv, 'Entry title')
  end # def self.limits_title()


  # Max chars in body
  LimBodyMax = 1024 * 8

  # Invalid chars in body
  LimBodyInv = /[^[:print:][:space:]]/

  #####################################
  # Limit check, body
  def self.limits_body(str)
    Error.limits(str, 1, LimBodyMax, LimBodyInv, 'Entry body')
  end # def self.limits_body()


  # Max chars in a tag
  LimTagMax = 128

  # Invalid chars in a tag
  LimTagInv = /[[:cntrl:]\/\\\*\?]|^_/

  #####################################
  # Limit check, tag
  def self.limits_tag(str)
    Error.limits(str, 1, LimTagMax, LimTagInv, 'Tag')
  end # def self.limits_tag()
  

  # Maximum attachment name
  LimAttachMax = 255

  # Invalid attachment name characters
  LimAttachInv = /[[:cntrl:]\/\\\*\?]/

  #####################################
  # Limit check, attachment name
  def self.limits_attach(str)
    Error.limits(str, 1, LimAttachMax, LimAttachInv, 'Attachment name')
  end # def self.limits_attach()


  #########################################################
  # @!group Read attributes


  #####################################
  # Get entry item hash
  #
  # @return [String] The hash of the entry
  # @raise (see #canonical)
  def hash
    if !@hash
      @hash = Digest::SHA256.new.update(canonical).hexdigest
    end
    return @hash.dup
  end # def hash


  #####################################
  # Generate canonical encoded string
  #
  # @return [String] Canonical output
  # @raise [Error::Sanity] if the entry is not complete enought to
  #   generate canonical output.
  def canonical
    if !@canon
      raise Error::Sanity, 'Entry not complete' if !@history

      txt =  "jckt %s\n" % @jacket
      txt << "entr %d\n" % @entry
      txt << "revn %d\n" % @revision
      txt << "hist %d\n" % @history
      txt << "amax %d\n" % @attach_max
      txt << "time %s\n" % @time_str
      txt << "titl %s\n" % @title
      @tags.sort.each{ |tag| txt << "tags %s\n" % tag }
      @attach.to_a.sort{|aa, bb| aa[0] <=> bb[0] }.each do |anum, ary|
        txt << "atch %d %d %s\n" % [anum, ary[0], ary[1]]
      end
      txt << "\n"
      txt << @body
      @canon = txt
    end
    return @canon.dup
  end # def canonical()


  #####################################
  # Generate JSON encoded string
  #
  # @return [String] JSON output
  # @raise [Error::Sanity] if the entry is not complete enought to
  #   generate canonical output.
  def json
    if !@json
      enc = {
        'hash' => hash,
        'jacket' => @jacket,
        'entry' => @entry,
        'revision' => @revision,
        'history' => @history,
        'max_attach' => @attach_max,
        'time' => @time_str,
        'title' => @title,
        'tags' => @tags.sort,
        'attachments' => @attach,
        'body' => @body,
      }
      @json = JSON.generate(enc)
    end
    return @json.dup
  end # def json


  #####################################
  # Get jacket
  # @return [String, Boolean] The jacket hash ID or false if not set
  def jacket
    if @jacket
      return @jacket.dup
    else
      return false
    end
  end # def jacket


  #####################################
  # Get entry number
  #
  # @return [Integer, Boolean] The entry number, or false if not set
  def entry
    if @entry
      return @entry
    else 
      return false
    end
  end # def entry


  #####################################
  # Get revision number
  #
  # @return [Integer, Boolean] The revision number, or false if not set
  def revision
    if @revision
      return @revision
    else
      return false
    end
  end # def revision


  #####################################
  # Get history number
  #
  # @return [Integer, Boolean] The history number, or false if not set
  def history
    if @history
      return @history
    else
      return false
    end
  end # def history
  
  
  #####################################
  # Get title
  #
  # @return [String, Boolean] Title of the entry, or false if not set
  def title
    if @title
      return @title.dup
    else
      return false
    end
  end # def title

 
  # Regex to parse time string
  TimeStrReg = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/
  private_constant :TimeStrReg


  #####################################
  # Get time
  #
  # @return [Time, Boolean] Time of the entry, or false if not set
  def time
    if !@time
      return false if !@time_str
      ma = TimeStrReg.match(@time_str)
      raise Error::Limits, 'Invalid time string' if !ma
      ary = ma[1,6].map{|str| str.to_i}
      begin
        @time = Time.utc(*ary)
      rescue
        raise Error::Limits, 'Invalid time string'
      end
    end
    return @time.dup
  end # def time


  #####################################
  # Get time string
  #
  # @return [String, Boolean] Encoded time string of the entry, or false
  #   if time not set
  def time_str
    if !@time_str
      return false if !@time
      @time_str = @time.strftime('%F %T')
    end
    return @time_str.dup
  end # def time_str
  
  
  #####################################
  # Get body
  #
  # @return [String, Boolean] Entry body, or false if not set
  def body
    if @body
      return @body.dup
    else
      return false
    end
  end # def body
  

  #####################################
  # Get tags
  #
  # @return [Array] of tag names
  def tags
    @tags = @tags.uniq
    @tags.map{|tag| tag.dup }
  end # def tags


  #####################################
  # Get permissions
  def perms
    @tags = @tags.uniq
    @tags.select{|tag| tag.start_with?('perm: ')}.map{|tag| tag[6..-1]}
  end # def perms
  
  
  #####################################
  # Get attached files
  #
  # @return [Array] of attachment information.  Each entry is an array of
  #   \[attach_num, history_num, name\]
  def attachments
    res = []
    @attach.each do |anum, ary|
      res.push [anum, ary[0], ary[1].dup]
    end
    return res
  end # def attach_each
  

  #####################################
  # Get max attachment
  #
  # @return [Integer, Boolean] The maximum attachment number, or false
  #   if not set
  def attach_max
    if @attach_max
      return @attach_max
    else
      return false
    end
  end # def attach_max



  #########################################################
  # @!group Set attributes


  #####################################
  # Set entry using canonical encoding
  #
  # @param str [String] Canonical encoded entry
  # @raise [Error::Corrupt] if encoding does not follow canonical rules
  def canonical=(str)
    @hash = nil
    @canon = str.dup
    lines = str.lines

    ma = /^jckt ([0-9a-f]{64})$/.match lines.shift
    raise(Error::Corrupt, 'Canonical entry jacket error') if !ma
    @jacket = ma[1]

    ma = /^entr (\d+)$/.match lines.shift
    raise(Error::Corrupt, 'Canonical entry entry error') if !ma
    @entry = ma[1].to_i
    
    ma = /^revn (\d+)$/.match lines.shift
    raise(Error::Corrupt, 'Canonical entry revision error') if !ma
    @revision = ma[1].to_i

    ma = /^hist (\d+)$/.match lines.shift
    raise(Error::Corrupt, 'Canonical entry history error') if !ma
    @history = ma[1].to_i

    ma = /^amax (\d+)$/.match lines.shift
    raise(Error::Corrupt, 'Caononical entry attach_max error') if !ma
    @attach_max = ma[1].to_i

    ma = /^time (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})$/.match lines.shift
    raise(Error::Corrupt, 'Canonical entry time error') if !ma
    @time_str = ma[1]
    @time = nil

    ma = /^titl (.*)$/.match lines.shift
    raise(Error::Corrupt, 'Canonical entry title error') if !ma
    Entry.limits_title(ma[1])
    @title = ma[1]

    li = lines.shift
    @tags = []
    while( li && ma = /^tags (.+)$/.match(li) )
      Entry.limits_tag(ma[1])
      @tags.push ma[1]
      li = lines.shift
    end

    @attach = {}
    while( li && ma = /^atch (\d+) (\d+) (.+)$/.match(li) )
      Entry.limits_attach(ma[3])
      @attach[ma[1].to_i] = [ma[2].to_i, ma[3]]
      li = lines.shift
    end

    unless li && li.strip.empty?
      raise Error::Corrupt, 'Canonical entry body error'
    end

    txt = ''
    lines.each{ |li| txt << li }
    Entry.limits_body(txt)
    @body = txt

    _final

  rescue
    reset
    raise
  end # def canonical=()


  #####################################
  # Set jacket
  #
  # @param jck [String] The jacket hash ID
  # @raise [Error::Limits] if jck is not a valid hash
  # @raise [Error::Sanity] if changing an already set jacket hash ID
  def jacket=(jck)
    ma = /^([0-9a-f]{64})$/.match jck
    raise(Error::Limits, 'Jacket hash not valid') if !ma
    if @jacket
      raise(Error::Sanity, 'Jacket already set') if @jacket != jck
    else
      @jacket = jck.dup
      _change
    end
  end # def jacket=()

  
  #####################################
  # Set entry number
  # @param enum [Integer] The entry number
  # @raise [ArgumentError] if enum is negative
  # @raise [Error::Sanity] if changing an already set entry number
  def entry=(enum)
    raise(ArgumentError, 'Entry number invalid') if enum < 0
    if @entry
      raise(Error::Sanity, 'Changing entry number') if @entry != enum
    else
      @entry = enum
      _change
    end
  end # def entry=()


  #####################################
  # Set title
  #
  # @param ttl [String] Title of the entry
  # @raise [Error::Limits] if ttl exceeds allowed values
  def title=(ttl)
    Entry.limits_title(ttl)
    @title = ttl.dup
    _change
  end # def title=()


  #####################################
  # Set time
  #
  # @param tme [Time] Time of the entry
  def time=(tme)
    @time = tme.utc
    @time_str = nil
  end # def time=()


  #####################################
  # Set encoded time string
  #
  # @param tme [String] Encoded time string
  # @raise [Error::Limits] if tme is not properly written
  def time_str=(tme)
    @time = nil
    @time_str = tme.dup
    time
  end # def time_str=()


  #####################################
  # Set body
  #
  # @param bdy [String] Entry body
  # @raise [Error::Limits] if bdy exceeds allowed values
  def body=(bdy)
    Entry.limits_body(bdy)
    @body = bdy.dup
    _change
  end # def body=()


  #########################################################
  # @!group General interface

  
  #####################################
  # Create a new entry
  def initialize
    reset
  end # def initialize
  

  #####################################
  # Reset to blank entry
  #
  # @return [Entry] self
  def reset()
    @hash = nil
    @canon = nil
    @jacket = nil
    @entry = nil
    @revision = 1
    @history = nil
    @title = nil
    @time = nil
    @time_str = nil
    @body = nil
    @tags = []
    @attach = {}
    @attach_file = {}
    @attach_max = 0

    @time_old = nil
    @tags_old = []

    return self
  end # def reset()


  #####################################
  # Update an entry
  #
  # @note If time has not been set, it defaults to the current time
  #
  # The changes returned include:
  # * :time - true if time changed
  # * :tags_add - list of new tags
  # * :tags_del - list of tags deleted
  # * :files - hash of attachment number => \[file, hash\]
  #
  # @param hnum [Integer] History number
  # @raise [Error::Sanity] if no changes have been made to an entry
  # @raise [Error::Sanity] if entry does not have at least jacket,
  #   entry, title, and body set
  # @return [Hash] Describing changes
  def update(hnum)
    raise Error::Sanity, 'Update entry with no changes' if @history
    if !@jacket && !@entry && !@title && !@body
      raise Error::Sanity, 'Update incomplete entry'
    end

    @history = hnum
    change = {}

    if !@time_str
      @time = Time.new.utc if !@time
      @time_str = @time.strftime('%F %T')
    end
    change[:time] = @time_str != @time_old

    @tags = @tags.uniq
    change[:tags_add] = @tags - @tags_old
    change[:tags_del] = @tags_old - @tags

    @attach.each{ |anum, ary| ary[0] = hnum if ary[0] == 0 }
    change[:files] = @attach_file
    
    _final()
    return change
  end # def update()


  #########################################################
  # @!group Edit tags and attached files
  

  #####################################
  # Rename an attachment
  #
  # @param anum [Integer] Attachment number to rename
  # @param name [String]  New attachment name
  # @raise [Error::Sanity] if attachment does not exist
  # @raise [Error::Limits] if name exceeds allowed values
  def rename(anum, name)
    raise(Error::Sanity, 'Non-existent attachment') if !@attach[anum]
    Entry.limits_attach(name)
    @attach[anum][1] = name.dup
    _change()
  end # def rename()


  #####################################
  # Delete an attachment
  #
  # @param anum [Integer] anum Attachment number to delete
  # @raise [Error::Sanity] if attachment does not exist
  def delete(anum)
    raise(Error::Sanity, 'Non-existent attachment') if !@attach[anum]
    @attach.delete(anum)
    _change()
  end # def delete()


  #####################################
  # Replace an attachment
  #
  # @note If hash is not provided, it will be calculated.  This can take
  #   a long time for large files.
  #
  # @param anum [Integer] Attachment number to replace
  # @param file [File] Temporary file to attach
  # @param hash [String] The SHA256 hash of the file
  # @raise [Error::Sanity] if attachment does not exist
  def replace(anum, file, hash=nil)
    raise(Error::Sanity, 'Non-existent attachment') if !@attach[anum]
    hsto = hash ? hash.dup : Digest::SHA256.file(file.path).hexdigest
    @attach[anum][0] = 0
    @attach_file[anum] = [file, hsto]
    _change()
  end # def replace()


  #####################################
  # Add an attachment
  #
  # @note (see #replace)
  #
  # @param name [String] Attachment name
  # @param file [File] Temporary file to attach
  # @param hash [String] The SHA256 hash of the file
  # @raise [Error::Limits] if name exceeds allowed values
  def attach(name, file, hash=nil)
    Entry.limits_attach(name)
    hsto = hash ? hash.dup : Digest::SHA256.file(file.path).hexdigest
    @attach_max += 1
    @attach[@attach_max] = [0, name.dup]
    @attach_file[@attach_max] = [file, hsto]
    _change()
  end # def attach()

  
  #####################################
  # Set tag
  #
  # @param tnam [String] Tag name to set
  # @raise [Error::Limits] if tnam exceeds allowed values
  def tag(tnam)
    name = _tag_normalize(tnam)
    @tags.push name
    _change()
  end # def tag()


  #####################################
  # Clear tag
  #
  # @param tnam [String] tnam Tag name to clear
  # @raise [Error::Limits] if tnam exceeds allowed values
  def untag(tnam)
    name = _tag_normalize(tnam)
    @tags.delete name
    _change()
  end # def untag()


  private

  # Change to entry
  def _change()
    @revision = @revision + 1 if @history
    @history = nil
    @hash = nil
    @canon = nil
  end # def _change()


  # Finalize entry
  def _final
    @time_old = @time_str ? @time_str.dup : nil
    @tags_old = @tags.map{|tg| tg.dup }
    @attach_file = {}
  end # def _final()


  # Normalize tag name
  def _tag_normalize(tnam)
    idx = tnam.index(':')
    if idx
      pre = tnam[0, idx].strip
      post = tnam[idx+1..-1].strip
      return pre + ': ' + post
    else
      return tnam.strip
    end
  end # def _tag_normalize()


end # class Entry

end # module Sgfa
