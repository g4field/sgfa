#
# Simple Group of Filing Applications
# Jacket
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'digest/sha2'

require_relative 'error'
require_relative 'history'
require_relative 'entry'

module Sgfa


#####################################################################
# A basic filing container which holds {Entry} items with attachments
# and maintains a record of changes made in the form of a linked chain
# of {History} items.
#
# This class provides the shared services in common to all
# implementations, which are provided by child classes.
#
# To be functional, a child class must provide:
# * @lock - a lock to protect access to the Jacket
# * @state - keep track of current history and entry revisions and 
#   track all tags active in the Jacket.
# * @store - actually keeps all the items in the Jacket.
# * implementations for open, close, create, etc.
#
class Jacket

  # Max length of text ID
  TextIdMax = 128

  # Invalid characters in text ID
  TextIdChars = /[[:cntrl:]]/

  private_constant :TextIdMax, :TextIdChars 


  #####################################
  # Limits on Text ID
  def self.limits_id(txt)
    Error.limits(txt, 1, TextIdMax, TextIdChars, 'Jacket text ID')
  end # def self.limits_id()


  ##########################################
  # Initialize new jacket
  def initialize
    @id_hash = nil
    @item_hash = Digest::SHA256.new
  end # def initialize


  ##########################################
  # Get Hash ID
  #
  # @return [String] Hash ID of the jacket
  # @raise [Error::Sanity] if jacket not open
  def id_hash
    raise Error::Sanity, 'Jacket not open' if !@id_hash
    return @id_hash.dup
  end # def id_hash


  ##########################################
  # Get Text ID
  #
  # @return [String] Text ID of the jacket
  # @raise [Error::Sanity] if jacket not open
  def id_text
    raise Error::Sanity, 'Jacket not open' if !@id_hash
    return @id_text.dup
  end # def id_text



  ##########################################
  # History item
  #
  # @param [Fixnum] hnum History number
  # @return [Array] [:history, item]
  #
  # @raise [Error::Sanity] if jacket not open
  def item_history(hnum)
    raise Error::Sanity, 'Jacket not open' if !@id_hash
    txt = "%s history %d\n" % [@id_hash, hnum]
    [:history, @item_hash.reset.update(txt).hexdigest]
  end # def item_history()


  ##########################################
  # Entry item
  #
  # @param [Fixnum] enum Entry number
  # @param [Fixnum] rnum Revision number
  # @return [Array] [:entry, item]
  #
  # @raise [Error::Sanity] if jacket not open
  def item_entry(enum, rnum)
    raise Error::Sanity, 'Jacket not open' if !@id_hash
    txt = "%s entry %d %d\n" % [@id_hash, enum, rnum]
    [:entry, @item_hash.reset.update(txt).hexdigest]
  end


  ##########################################
  # Attach item
  #
  # @param [Fixnum] enum Entry number
  # @param [Fixnum] anum Attach number
  # @param [Fixnum] hnum History number
  # @return [Array] [:file, item]
  #
  # @raise [Error::Sanity] if jacket not open
  def item_attach(enum, anum, hnum)
    raise Error::Sanity, 'Jacket not open' if !@id_hash
    txt = "%s attach %d %d %d\n" % [@id_hash, enum, anum, hnum]
    [:file, @item_hash.reset.update(txt).hexdigest]
  end # def item_attach()


  #####################################
  # Read an entry
  #
  # @param enum [Integer] The entry number to read
  # @param rnum [Integer] The revision number, defaults to current
  # @raise [Error::Sanity] if Jacket is not open
  # @raise [Error::Corrupt] if the current Entry is missing
  # @raise [Error::NonExistent] if the Entry is missing
  # @raise (see Entry#canonical=)
  # @return [Entry] the {Entry} item
  def read_entry(enum, rnum=0)
    raise Error::Sanity, 'Jacket is not open' if !@id_hash

    # current entry
    if rnum == 0
      rnum = @lock.do_sh{ @state.get(enum) }
      current = true
    else
      current = false
    end

    # read, process, and close
    ent = _read_entry(enum, rnum)
    if !ent
      if current
        raise Error::Corrupt, 'Jacket current entry not present'
      else
        raise Error::NonExistent, 'Jacket entry does not exist'
      end
    end

    return ent
  end # def read_entry()


  #####################################
  # Read an array of current entries
  #
  # @param enums [Array] Entry number list
  # @return [Array] of {Entry} items
  # @raise [Error::Corrupt] if current entries not present
  # @raise [Error::NonExistent] if entry does not exist
  def read_array(enums)
    raise Error::Sanity, 'Jacket is not open' if !@id_hash

    # get current entries
    rnums = @lock.do_sh{ enums.map{|enum| @state.get(enum) } }

    # get entries
    ents = []
    enums.each_index do |idx|
      ent = _read_entry(enums[idx], rnums[idx])
      raise Error::Corrupt, 'Jacket current entry not present' if !ent
      ents.push ent
    end

    return ents
  end # def read_array()


  #####################################
  # Read individual entry
  def _read_entry(enum, rnum)
    ent = Entry.new
    type, item = item_entry(enum, rnum)
    fi = @store.read(type, item)
    return nil if !fi
    begin
      ent.canonical = fi.read
    ensure
      fi.close
    end
    return ent
  end # def _read_entry()


  #####################################
  # Read history item
  #
  # @param hnum [Integer] the history number to read, defaults to most recent
  # @raise [Error::Sanity] if Jacket is not open
  # @raise [Error::NonExistent] if the history does not exist
  # @raise (see History#canonical=)
  # @return [History] the {History} item
  def read_history(hnum=0)
    raise Error::Sanity, 'Jacket is not open' if !@id_hash
    
    hst = History.new
    hnum = @lock.do_sh{ @state.get(0) } if hnum == 0
    return nil if hnum == 0
    type, item = item_history(hnum)
    fi = @store.read(type, item)
    raise Error::NonExistent, 'Jacket history does not exist' if !fi
    begin
      hst.canonical = fi.read
    ensure
      fi.close
    end

    return hst
  end # def read_history()


  #####################################
  # Read attachment
  #
  # @note Remember to close the returned file
  #
  # @param enum [Integer] the entry number
  # @param anum [Integer] the attachemnt number
  # @param hnum [Integer] the history number
  # @return [File] the attachment opened read only
  # @raise [Error::Sanity] if Jacket is not open
  # @raise [Error::NonExistent] if attachment does not exist
  def read_attach(enum, anum, hnum)
    raise Error::Sanity, 'Jacket is not open' if !@id_hash

    type, item = item_attach(enum, anum, hnum)
    fi = @store.read(type, item)
    raise Error::NonExistent, 'Jacket attachment does not exist' if !fi
    return fi
  end # def read_attach()


  #####################################
  # Read a tag, just getting the list of entry numbers
  #
  # @note You probably want to use {#read_tag} instead of this method.
  #
  # @param tag [String] Tag name
  # @param offs [Integer] Offset to begin reading
  # @param max [Integer] Maximum entries to return
  # @return [Array] Total number of entries in the tag, and possibly empty
  #   array of entry numbers
  # @raise [Error::Sanity] if Jacket is not open
  # @raise [Error::NonExistent] if tag does not exist
  # @raise [Error::Corrupt] if file format for tag is bad  #
  def read_tag_raw(tag, offs, max)
    raise Error::Sanity, 'Jacket is not open' if !@id_hash
    return @lock.do_sh{ @state.tag(tag, offs, max) }
  end # def read_tag_raw()


  #####################################
  # Read a tag
  #
  # @param (see #read_tag_raw)
  # @return [Array] Total number of entries in the tag, possibly empty
  #   array of {Entry} items
  # @raise (see #read_tag_raw)
  # @raise [Error::Corrupt] if current entry is not available
  def read_tag(tag, offs, max)
    raise Error::Sanity, 'Jacket is not open' if !@id_hash
    ents = []
    size = nil
    @lock.do_sh do
      size, elst = @state.tag(tag, offs, max)

      elst.each do |enum|
        rnum = @state.get(enum)
        type, item = item_entry(enum, rnum)
        fi = @store.read(type, item)
        raise Error::Corrupt, 'Jacket current entry not present' if !fi
        ent = Entry.new
        begin
          ent.canonical = fi.read
        ensure
          fi.close
        end
        ents.push ent         
      end
    end
    return size, ents
  end # def read_tag()


  #####################################
  # Read list of all tags
  #
  # @return [Array] list of tag names
  # @raise [Error::Sanity] if Jacket is not open
  # @raise [Error::Corrupt] if tag list is missing
  def read_list
    raise Error::Sanity, 'Jacket is not open' if !@id_hash
    return @lock.do_sh{ @state.list }
  end # def read_list


  #####################################
  # Write entires to a Jacket 
  # 
  # @param user [String] User
  # @param ents [Array] {Entry}s to write
  # @param tme [Time] Time of the write
  # @return [History] The history item just created
  # @raise [Error::Sanity] if Jacket is not open
  # @raise [Error::Conflict] if entry revision is not one up from current
  # @raise (see History#process)
  def write(user, ents, tme=nil)
    raise Error::Sanity, 'Jacket is not open' if !@id_hash

    hst = nil

    @lock.do_ex do
      # Check entries to ensure they don't conflict
      ents.each do |ent|
        next if !ent.entry
        if ent.revision != @state.get(ent.entry) + 1
          raise Error::Conflict, 'Entry revision conflict'
        end
      end

      # Update history
      hnum = @state.get(0)
      if hnum == 0
        hst = History.new(@id_hash)
        cng = hst.process(1, '00000000'*8, 0, user, ents, tme)
      else
        prv = History.new
        type, item = item_history(hnum)
        fi = @store.read(type, item)
        raise Error::Corrupt, 'Missing history' if !fi
        begin
          prv.canonical = fi.read
        ensure
          fi.close
        end
        hst, cng = prv.next(user, ents, tme)
      end
      hnum = hst.history

      # store entries
      hle = []
      cng[:entry].each do |ent|
        type, item = item_entry(ent.entry, ent.revision)
        hle.push [item, ent]
        fi = @store.temp
        begin
          fi.write ent.canonical
        rescue
          fi.close!
          raise
        end
        @store.write(type, item, fi)
        @state.set(ent.entry, ent.revision)
      end

      # store attachments
      hla = []
      cng[:attach].each do |enum, anum, file|
        type, item = item_attach(enum, anum, hnum)
        hla.push [item, enum, anum, hnum]
        @store.write(type, item, file)
      end
      
      # tags
      @state.update(cng[:tag])

      # store history and set state
      type, item = item_history(hnum)
      fi = @store.temp
      fi.write hst.canonical
      @store.write(type, item, fi)
      @state.set(0, hnum)

    end

    return hst
  end # def write()


end # class Jacket

end # module Sgfa
