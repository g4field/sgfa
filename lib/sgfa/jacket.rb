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
require 'logger'

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
  private :_read_entry


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


  #####################################
  # Validate history chain
  #
  # @param opts [Hash] Option hash
  # @option opts [Boolean] :hash_entry Validate entries by checking their
  #   hash
  # @option opts [Boolean] :hash_attach Validate attachments by checking
  #   their hash
  # @option opts [Fixnum] :max_history History number to stop checking.
  #   Defaults to not stopping until missing history items stop the check.
  # @option opts [Fixnum] :min_history History number to start checking.
  #   Defaults to 1.
  # @option opts [Fixnum] :miss_history Number of allowable missing history
  #   items before checking stops.  Defaults to zero.
  # @option opts [String] :max_hash Known good hash for :max_history item
  # @option opts [Logger] :log The logger to use.  Defaults to STDERR log
  # @return [Boolean] true if valid history chain
  def check(opts={})
    raise Error::Sanity, 'Jacket is not open' if !@id_hash

    max = opts[:max_history] || 1000000000
    min = opts[:min_history] || 1
    stop = opts[:miss_history] || 0
    if opts[:log]
      log = opts[:log]
    else
      log = Logger.new(STDERR)
      log.level = Logger::WARN
    end

    log.info('Begin validate jacket %s at %d' % [@id_hash, min])

    miss = 0
    hnum = min-1
    prev = nil
    good = true
    while (hnum += 1) <= max
      
      # get history item
      begin
        hst = read_history(hnum)
      rescue Error::NonExistent
        miss += 1
        if miss <= stop
          next
        else
          hnum = hnum-miss+1
          break
        end
      rescue Error::Corrupt => exp
        log.error('History item corrupt %d' % hnum)
        miss += 1
        if miss <= stop
          next
        else
          num = hnum-miss+1
          break
        end
      end

      # missing history items
      if miss != 0
        good = false
        if miss == 1
          log.error('History item missing %d' % (hnum-1))
        else
          log.error('HIstory items missing %d-%d' % [hnum-miss, hnum-1])
        end
        miss = 0
        prev = nil
      end

      # check previous
      if prev
        if prev != hst.previous
          good = false
          log.error('History chain broken %d' % hnum)
        else
          log.debug('History chain matches %d' % hnum)
        end
      elsif hnum != min
        log.warn('History chain not checked %d' % hnum)
      end
      prev = hst.hash

      # entries
      if opts[:hash_entry]
        hst.entries.each do |enum, rnum, hash|
          begin
            ent = read_entry(enum, rnum)
          rescue Error::NonExistent
            log.info('Entry missing %d-%d' % [enum, rnum])
            next
          rescue Error::Corrupt
            log.error('Entry corrupt %d-%d' % [enum, rnum])
            good = false
            next
          end
          if ent.hash != hash
            log.error('Entry invalid %d-%d' % [enum, rnum])
            good = false
          else
            log.debug('Entry is valid %d-%d' % [enum, rnum])
          end
        end
      end

      # attachments
      if opts[:hash_attach]
        hst.attachments.each do |enum, anum, hash|
          begin
            fil = read_attach(enum, anum, hnum)
          rescue Error::NonExistent
            log.info('Attachment missing %d-%d-%d' % [enum, anum, hnum])
            next
          end
          begin
            calc = Digest::SHA256.file(fil.path).hexdigest
          ensure
            fil.close
          end
          if calc != hash
            log.error('Attachment invalid %d-%d-%d' % [enum, anum, hnum])
            good = false
          else
            log.debug('Attachment is valid %d-%d-%d' % [enum, anum, hnum])
          end
        end
      end

      # last history check known good hash
      if hnum == max && opts[:max_hash]
        if hst.hash != opts[:max_hash]
          log.error('Max history does not match known hash')
          good = false
        else
          log.debug('Max history matches known hash')
        end
      end

    end

    log.info('History chain validation max %d' % (hnum-1))

    if opts[:max_history] && hnum != opts[:max_history]
      return false
    else
      return good
    end

  end # def check()


  #####################################
  # Backup to an alternate store
  #
  # @param bsto [Store] Backup store
  # @param opts [Hash] Options
  # @option opts [Fixnum] :max_history Last history to backup.  Defaults
  #   to the current maximum history.
  # @option opts [Fixnum] :min_history First history to backup.  Defaults
  #   to 1.
  # @option opts [Boolean] :skip_history Do not push history items
  # @option opts [Boolean] :skip_entry Do not push entry items
  # @option opts [Boolean] :skip_attach Do not push attachments
  # @option opts [Boolean] :always Do not stat item, always push
  # @option opts [Logger] :log The log.  Defaults to STDERR at warn level.
  def backup(bsto, opts={})
    raise Error::Sanity, 'Jacket is not open' if !@id_hash

    max = opts[:max_history] || @lock.do_sh{ @state.get(0) }
    min = opts[:min_history] || 1
    do_h = !opts[:skip_history]
    do_e = !opts[:skip_entry]
    do_a = !opts[:skip_attach]
    stat = !opts[:always]
    if opts[:log]
      log = opts[:log]
    else
      log = Logger.new(STDERR)
      log.level = Logger::WARN
    end
    hst = History.new

    min.upto(max) do |hnum|

      # history items
      type, item = item_history(hnum)
      blob = @store.read(type, item)
      if !blob
        log.error('Backup history item missing %d' % hnum)
        next
      end
      begin
        hst.canonical = blob.read
        if stat
          size = bsto.size(type, item)
          if size
            log.info('Backup history item already exists %d' % hnum)
            next
          end
        end
        if do_h
          temp = bsto.temp
          blob.rewind
          IO.copy_stream(blob, temp)
          bsto.write(type, item, temp)
          log.info('Backup push history item %d' % hnum)
        end
      ensure 
        blob.close
      end

      # entries
      if do_e
        hst.entries.each do |enum, rnum, hash|
          type, item = item_entry(enum, rnum)
          blob = @store.read(type, item)
          if !blob
            log.info('Backup entry missing %d-%d' % [enum, rnum])
            next
          end
          begin
            temp = bsto.temp
            IO.copy_stream(blob, temp)
            bsto.write(type, item, temp)
            log.info('Backup push entry %d-%d' % [enum, rnum])
          ensure
            blob.close
          end
        end
      end

      # attachments
      if do_a
        hst.attachments.each do |enum, anum, hash|
          type, item = item_attach(enum, anum, hnum)
          blob = @store.read(type, item)
          if !blob
            log.info('Backup attachment missing %d-%d-%d' % [enum, anum, hnum])
            next
          end
          begin
            temp = bsto.temp
            IO.copy_stream(blob, temp)
            bsto.write(type, item, temp)
            log.info('Backup push attachment %d-%d-%d' % [enum, anum, hnum])
          ensure
            blob.close
          end
        end
      end

    end

  end # def backup()


  #####################################
  # Backup restore from an alternate store
  #
  # @param bsto [Store] The backup store
  # @param opts [Hash] Options
  # @option opts [Fixnum] :max_history Last history to restore.  Defaults to
  #   everything until a history item is not found.
  # @option opts [Fixnum] :min_history First history to restore.  Defaults to
  #   current maximum history plus one.
  # @option opts [Boolean] :skip_entry Do not pull entry items.
  # @option opts [Boolean] :skip_attach Do not pull attachments.
  # @option opts [Boolean] :always Do not stat local item, always pull.
  # @option opts [Logger] :log The log.  Defaults to STDERR at warn level.
  #
  # @todo Do locking.  Really restore is not going to occur with 
  #
  def restore(bsto, opts={})
    raise Error::Sanity, 'Jacket is not open' if !@id_hash

    max = opts[:max_history] || 1000000000
    min = opts[:min_history] || @lock.do_sh{ @state.get(0) } + 1
    do_e = !opts[:skip_entry]
    do_a = !opts[:skip_attach]
    stat = !opts[:always]
    if opts[:log]
      log = opts[:log]
    else
      log = Logger.new(STDERR)
      log.level = Logger::WARN
    end
    hst = History.new

    miss = 0
    hnum = min -1
    while (hnum += 1) <= max

      # history item
      type, item = item_history(hnum)
      if stat
        size = @store.size(type, item)
        if size
          log.info('Restore history item already exists %d' % hnum)
          next
        end
      end
      blob = bsto.read(type, item)
      if !blob
        if max == 1000000000
          break
        else
          log.error('Restore history item missing %d' % hnum)
          next
        end
      end
      begin
        hst.canonical = blob.read
        blob.rewind
        temp = @store.temp
        IO.copy_stream(blob, temp)
        @store.write(type, item, temp)
        log.info('Restore history item %d' % hnum)
      ensure
        blob.close
      end

      # entries
      if do_e
        hst.entries.each do |enum, rnum, hash|
          type, item = item_entry(enum, rnum)
          blob = bsto.read(type, item)
          if !blob
            log.info('Restore entry missing %d-%d' % [enum, rnum])
            next
          end
          begin
            temp = @store.temp
            IO.copy_stream(blob, temp)
            @store.write(type, item, temp)
            log.info('Restore entry %d-%d' % [enum, rnum])
          ensure
            blob.close
          end
        end
      end

      # attachments
      if do_a
        hst.attachments.each do |enum, anum, hash|
          type, item = item_attach(enum, anum, hnum)
          blob = bsto.read(type, item)
          if !blob
            log.info('Restore attach missing %d-%d-%d' % [enum, anum, hnum])
            next
          end
          begin
            temp = @store.temp
            IO.copy_stream(blob, temp)
            @store.write(type, item, temp)
            log.info('Restore attach %d-%d-%d' % [enum, anum, hnum])
          ensure
            blob.close
          end
        end
      end

    end

    # update state
    update(min, hnum-1)

  end # def restore()


  # Number of entries to process before doing a tag state update
  UpdateChunk = 250

  TagAll = '_all'

  #####################################
  # Update state
  #
  # @param [Fixnum] min History to start the update
  # @param [Fixnum] max History to stop the update
  #
  def update(min, max)
    raise Error::Sanity, 'Jacket is not open' if !@id_hash

    # blow away state entirely
    @state.reset if min <= 1

    tags = {}
    current = {}
    count = 0
    hst = History.new
    entry_max = nil
    max.downto(min) do |hnum|

      # history
      type, item = item_history(hnum)
      fi = @store.read(type, item)
      raise Error::Corrupt, 'Jacket history does not exist %d' % hnum if !fi
      begin
        hst.canonical = fi.read
      ensure
        fi.close
      end
      entry_max = hst.entry_max if !entry_max

      # entries
      hst.entries.each do |enum, rnum, hash|
        next if current[enum]
        current[enum] = true
        count += 1

        # get new entry
        type, item = item_entry(enum, rnum)
        ent = _read_entry(enum, rnum)
        if !ent
          raise Error::Corrupt, 'Jacket current entry not present'
        end

        # update from old entry
        if min > 1 && rnum >= 2
          oldr = @state.get(enum)
          olde = _read_entry(enum, oldr)
          if !olde
            raise Error::Corrupt, 'Jacket current entry not present'
          end
          tdel = olde.tags - ent.tags
          tdel.each do |tag|
            tags[tag] ||= {}
            tags[tag][enum] = nil
          end

        end
        @state.set(enum, rnum)

        # update tags
        tags[TagAll] ||= {}
        tags[TagAll][enum] = ent.time_str
        ent.tags.each do |tag|
          tags[tag] ||= {}
          tags[tag][enum] = ent.time_str
        end
      end

      # tag state update
      if count >= UpdateChunk || hnum == min
        @state.update(tags)
        tags = {}
        count = 0
      end
    end
    
    @state.set(0, entry_max)

  end # def update()


end # class Jacket

end # module Sgfa
