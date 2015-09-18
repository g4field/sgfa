#
# Simple Group of Filing Applications
# History item
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'digest/sha2'

require_relative 'error'

module Sgfa


#####################################################################
# The history item provides a cryptographic chain of changes made to a
# {Jacket}.
#
# The History has attributes:
# * hash - SHA256 hash of the canonical encoding
# * canonical - the canonical encoded string
# * jacket - The {Jacket} hash ID the history belongs to
# * previous - Previous history number
# * history - History number
# * entry_max - Number of entries present in the Jacket
# * time - Date and time of the change
# * user - User name who made the change
# * entries - List of entries changed \[entry_num, revision_num, hash\]
# * attachments - List of attachments made \[entry_num, attach_num, hash\]
#
class History

  #########################################################
  # @!group Limits checks
  
  # Max chars in user name
  LimUserMax = 64

  # Invalid character in user name
  LimUserInv = /[[:cntrl:]]/
  
  #####################################
  # Limit check, user name
  def self.limits_user(str)
    Error.limits(str, 1, LimUserMax, LimUserInv, 'User name')
  end # def self.limits_user()


  #########################################################
  # @!group Read attributes


  #####################################
  # Get history item hash
  #
  # @return [String] The hash of the history
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
  # @raise [Error::Sanity] if the history is not complete
  def canonical
    if !@canon
      raise Error::Sanity, 'History not complete' if !@history

      txt =  "jckt %s\n" % @jacket
      txt << "hist %d\n" % @history
      txt << "emax %d\n" % @entry_max
      txt << "time %s\n" % time_str
      txt << "prev %s\n" % @previous
      txt << "user %s\n" % @user
      @entries.each{|ary| txt << "entr %d %d %s\n" % ary }
      @attach.each{|ary| txt << "atch %d %d %s\n" % ary }
      @canon = txt
    end
    return @canon.dup
  end # def canonical


  #####################################
  # Get jacket
  #
  # @return [String, Boolean] The jacket hash ID or false if not set
  def jacket
    if @jacket
      return @jacket.dup
    else
      return false
    end
  end # def jacket


  #####################################
  # Get previous history hash
  #
  # @return [String, Boolean] The hash of the previous history item,
  #   or false if not set
  def previous
    if @previous
      return @previous.dup
    else
      return false
    end
  end # def previous
  
  
  #####################################
  # Get history number
  # 
  # @return [Integer, Boolean] History number, or false if not set
  def history
    return @history
  end # def history
  

  #####################################
  # Get maximum entry
  #
  # @return [Integer, Boolean] Maximum entry in a Jacket, or false if not set
  def entry_max
    return @entry_max
  end # def entry_max
  

  # Regex to parse time string
  TimeStrReg = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/
  private_constant :TimeStrReg


  #####################################
  # Get time
  #
  # @return [Time, Boolean] The time, or false if not set
  def time
    if !@time
      return false if !@time_str
      ma = TimeStrReg.match(@time_str)
      ary = ma[1,6].map{|str| str.to_i}
      @time = Time.utc(*ary)
    end
    return @time.dup
  end # def time


  #####################################
  # Get time string
  #
  # @return [String, Boolean] Encoded time string of the history, or false
  #   if time not set
  def time_str
    if !@time_str
      return false if !@time
      @time_str = @time.strftime('%F %T')
    end
    return @time_str.dup
  end # def time_str
 

  #####################################
  # Get user
  #
  # @return [String, Boolean] The user string, or false if not set
  def user
    if @user
      return @user.dup
    else
      return false
    end
  end # def user
  

  #####################################
  # Get entries
  #
  # @return [Array] of Entry information \[entry_num, revision_num, hash\]
  def entries
    return @entries.map{|enum, rnum, hash| [enum, rnum, hash.dup] }
  end # def entries


  #####################################
  # Get attachments
  #
  # @return [Array] of Attachment information \[entry_num, attach_num, hash\]
  def attachments
    return @attach.map{|enum, anum, hash| [enum, anum, hash.dup] }
  end # def attachments


  
  #########################################################
  # @!group General interface

  #####################################
  # Create a new History item
  #
  # @param (see #jacket=)
  # @raise (see #jacket=)
  def initialize(jck=nil)
    reset
    if jck
      self.jacket = jck
    end
  end # def initialize()

  
  #####################################
  # Reset to blank History item
  #
  # @return [History] self
  def reset
    @hash = nil
    @canon = nil
    @jacket = nil
    @history = nil
    @entry_max = 0
    @time = nil
    @time_str = nil
    @previous = nil
    @user = nil
    @entries = []
    @attach = []
    
    @change_entry = nil
    @change_tag = nil
    @change_attach = nil
  end # def reset


  #####################################
  # Set History using canonical encoding
  # 
  # @param str [String] Canonical encoded History
  # @raise [Error::Corrupt] if encoding does not follow canonical rules
  def canonical=(str)
    @hash = nil
    @canon = str.dup
    lines = str.lines

    ma = /^jckt ([0-9a-f]{64})$/.match lines.shift
    raise(Error::Corrupt, 'Canonical history jacket error') if !ma
    @jacket = ma[1]

    ma = /^hist (\d+)$/.match lines.shift
    raise(Error::Corrupt, 'Canonical history history error') if !ma
    @history = ma[1].to_i

    ma = /^emax (\d+)$/.match lines.shift
    raise(Error::Corrupt, 'Canonical history entry_max error') if !ma
    @entry_max = ma[1].to_i

    ma = /^time (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})$/.match lines.shift
    raise(Error::Corrupt, 'Canonical history time error') if !ma
    @time_str = ma[1]

    ma = /^prev ([0-9a-f]{64})$/.match lines.shift
    raise(Error::Corrupt, 'Canonical history previous error') if !ma
    @previous = ma[1]

    ma = /^user (.+)$/.match lines.shift
    raise(Error::Corrupt, 'Canonical history user error') if !ma
    @user = ma[1]

    li = lines.shift
    @entries = []
    while(li && ma = /^entr (\d+) (\d+) (.+)$/.match(li) )
      @entries.push [ma[1].to_i, ma[2].to_i, ma[3]]
      li = lines.shift
    end

    @attach = []
    while(li && ma = /^atch (\d+) (\d+) ([0-9a-f]{64})$/.match(li) )
      @attach.push [ma[1].to_i, ma[2].to_i, ma[3]]
      li = lines.shift
    end

    if li
      raise Error::Corrupt, 'Canonical history error'
    end

  rescue
    reset
    raise
  end # def canonical=()
  
  
  #####################################
  # Set jacket
  #
  # @param [String] jck The jacket hash ID
  # @raise [Error::Limits] if jck is not a valid hash
  # @raise [Error::Sanity] if changing an already set jacket hash ID
  def jacket=(jck)
    ma = /^([0-9a-f]{64})$/.match jck
    raise(Error::Limits, 'Jacket hash not valid') if !ma
    if @jacket
      raise(Error::Sanity, 'Jacket already set') if @jacket != jck
    else
      @jacket = jck.dup
    end
  end # def jacket=()


  # Tag added to every entry
  TagAll = '_all'
  private_constant :TagAll


  #####################################
  # Generate next history
  #
  # @param [String] user User making the change
  # @param [Array] ents Entries to update
  # @param [Time] tme Time to use for the history
  # @return [Array] the next history item, and the changes hash
  # @raise (see #hash)
  # @raise (see #process)
  def next(user, ents, tme=nil)
    raise Error::Sanity, 'History not complete' if !@history
    nxt = History.new(@jacket)
    cng = nxt.process(@history + 1, hash, @entry_max, user, ents, tme)
    return [nxt, cng]
  end # def next


  #####################################
  # Process entries
  #
  # @note Entries without a jacket set are automatically set to the correct
  #   value
  # @note If time is not supplied, current time is used
  #
  # The changes returned consist of:
  # * :entry - Array of entries provided in ents
  # * :tag - Hash of tag => Hash of Entry => time_str or nil
  # * :attach - Attached files \[entry_num, attach_num, file\]
  #
  # @param [Integer] hnum History number
  # @param [String] prev Hash of previous item
  # @param [Integer] emax Maximum previous entry number
  # @param [String] user User making the change
  # @param [Array] ents Entries to update
  # @param [Time] tme Time to use for the history
  # @return [Hash] Record of changes made
  # @raise [Error::Sanity] if entry does not belong to the same jacket
  # @raise (see Entry#update) 
  def process(hnum, prev, emax, user, ents, tme=nil)

    cng = {}
    add = []

    # initial values
    @hash = nil
    @canon = nil
    @previous = prev
    @history = hnum
    @entry_max = emax
    if tme
      @time = tme.utc
    else
      @time = Time.now.utc
    end
    @user = user.dup
    @entries = []
    @attach = []

    # process the entries
    ents.each do |entry|
      # set/check jacket
      if !entry.jacket
        entry.jacket = @jacket
      elsif entry.jacket != @jacket
        raise Error::Sanity, 'Entry belongs to different jacket'
      end

      # set entry for new entries
      if !entry.entry
        @entry_max += 1
        entry.entry = @entry_max 
      end

      # update the entry
      ecng = entry.update(@history)
      enum = entry.entry
      ts = entry.time_str

      # time changed, all tags update
      if ecng[:time]
        cng[TagAll] = {} if !cng[TagAll]
        cng[TagAll][enum] = ts
        entry.tags.each do |tag|
          cng[tag] = {} if !cng[tag]
          cng[tag][enum] = ts
        end

      # just new tags
      else
        ecng[:tags_add].each do |tag|
          cng[tag] = {} if !cng[tag]
          cng[tag][enum] = ts
        end
      end

      # deleted tags
      ecng[:tags_del].each do |tag|
        cng[tag] = {} if !cng[tag]
        cng[tag][enum] = nil
      end
 
      # record entry and attachments
      @entries.push [enum, entry.revision, entry.hash]
      ecng[:files].each do |anum, ary|
        file, hash = ary
        @attach.push [enum, anum, hash]
        add.push [enum, anum, file]
      end

    end

    ret = {
      :entry => ents,
      :tag => cng,
      :attach => add,
    }

    return ret
  end # def process()


end # class History

end # module Sgfa
