#
# Simple Group of Filing Applications
# Binder
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
require_relative 'entry'
require_relative 'history'

module Sgfa

#####################################################################
# The basic administrative unit in the Sgfa system.  A binder provides
# access control for a collection of {Jacket}s.  In addition it allows
# values to be set for the Binder itself, to use in managing a collection
# of Binders.
class Binder


  #########################################################
  # @!group Limit checks
  
  # Maximum characters in jacket name
  LimJacketMax = 64

  # Invalid chars in jacket name
  LimJacketInv = /[[:cntrl:]]|[\/\\\*\?]|(^_)/

  private_constant :LimJacketMax, :LimJacketInv


  #####################################
  # Limits checks, jacket name
  def self.limits_jacket(str)
    Error.limits(str, 1, LimJacketMax, LimJacketInv, 'Jacket name')
  end # def self.limits_jacket()


  # Max characters in jacket title
  LimTitleMax = 128

  # Invalid chars in jacket title
  LimTitleInv = /[[:cntrl:]]/
  
  private_constant :LimTitleMax, :LimTitleInv
  
  #####################################
  # Limits checks, jacket title
  def self.limits_title(str)
    Error.limits(str, 1, LimTitleMax, LimTitleInv, 'Jacket title')
  end # def self.limits_title()


  # Max chars in permission
  LimPermMax = 64

  # Invalid chars in permission
  LimPermInv = /[[:cntrl:]\/\\\*\?,]|(^_)/

  private_constant :LimPermMax, :LimPermInv

  #####################################
  # Limits checks, permission array
  def self.limits_perms(ary)
    if !ary.is_a?(Array)
      raise Error::Limits, 'Permission array required' 
    end
    ary.each do |prm|
      Error.limits(prm, 1, LimPermMax, LimPermInv, 'Permission')
    end
  end # def self.limits_perms()


  # Max chars in value name
  LimValueMax = 64

  # Invalid chars in value name
  LimValueInv = /[[:cntrl:]]/

  private_constant :LimValueMax, :LimValueInv

  #####################################
  # Limits checks, value name
  def self.limits_value(str)
    stc = str.is_a?(Symbol) ? str.to_s : str
    Error.limits(stc, 1, LimValueMax, LimValueInv, 'Value name')
  end # def self.limits_value()


  # Max chars in value setting
  LimSettingMax = 128

  # Invalid chars in value setting
  LimSettingInv = /[[:cntrl:]]/

  private_constant :LimSettingMax, :LimSettingInv


  #####################################
  # Limits checks, value setting
  def self.limits_setting(str)
    Error.limits(str, 1, LimSettingMax, LimSettingInv, 'Value setting')
  end # def self.limits_setting()


  #####################################
  # Limits check, create values
  def self.limits_create(info)
    if !info.is_a?(Hash)
      raise Error::Limits, 'Binder create info is not a hash'
    end

    if !info[:jackets].is_a?(Array)
      raise Error::Limits, 'Binder create info :jackets is not an array'
    end
    info[:jackets].each do |jin|
      if !jin.is_a?(Hash)
        raise Error::Limits, 'Binder create info jacket not a hash'
      end      
      Binder.limits_jacket(jin[:name])
      Binder.limits_title(jin[:title])
      Binder.limits_perms(jin[:perms])
    end

    if !info[:users].is_a?(Array)
      raise Error::Limits, 'Binder create info :users is not an array'
    end
    info[:users].each do |uin|
      if !uin.is_a?(Hash)
        raise Error::Limits, 'Binder create info user not a hash'
      end      
      History.limits_user(uin[:name])
      Binder.limits_perms(uin[:perms])
    end
    
    if !info[:values].is_a?(Array)
      raise Error::Limits, 'Binder create info :values is not an array'
    end
    info[:values].each do |ary|
      if !ary.is_a?(Array)
        raise Error::Limits, 'Binder create info :value items are not arrays'
      end
      vn, vs = ary
      Binder.limits_value(vn)
      Binder.limits_setting(vs)
    end

    Jacket.limits_id(info[:id_text]) if info[:id_text]
  end # def limits_create()


  #########################################################
  # @!group Binder
  

  #####################################
  # Create a jacket
  #
  # @param tr [Hash] Common transaction info
  # @option tr [String] :jacket Jacket name
  # @option tr [String] :user User name
  # @option tr [Array] :groups List of groups to which :user belongs
  # @option tr [String] :title Title of the entry
  # @option tr [String] :body Body of the entry
  # @param title [String] Title of the jacket
  # @param perms [Array] Permissions for the jacket
  def jacket_create(tr, title, perms)
    Binder.limits_title(title)
    Binder.limits_perms(perms)
    _control(tr) do |jck|
      _perms(tr, ['manage'])
      num = @jackets.size + 1
      id_text, id_hash = _jacket_create(num)
      ent = _control_jacket(tr, num, tr[:jacket], id_hash, id_text,
        title, perms)
      jck.write(tr[:user], [ent])
      @jackets
    end
  end # def jacket_create()


  #####################################
  # Edit a jacket
  #
  # @param tr (see #jacket_create)
  # @param name [String] New jacket name
  # @param title [String] New jacket title
  # @param perms [Array] New jacket permissions
  def jacket_edit(tr, name, title, perms)
    Binder.limits_jacket(name)
    Binder.limits_title(title)
    Binder.limits_perms(perms)
    _control(tr) do |jck|
      jnam = tr[:jacket]
      raise Error::NonExistent, 'Jacket does not exist' if !@jackets[jnam]
      jacket = @jackets[jnam]
      num = jacket['num']
      ent = _control_jacket(tr, num, name, jacket['id_hash'],
        jacket['id_text'], title, perms)
      jck.write(tr[:user], [ent])
      @jackets
    end
  end # def jacket_edit()


  #####################################
  # Set user or group permissions
  #
  # @param tr (see #jacket_create)
  # @param perms [Array] New user/group permissions
  def binder_user(tr, user, perms)
    History.limits_user(user)
    Binder.limits_perms(perms)
    _control(tr) do |jck|
      ent = _control_user(tr, user, perms)
      jck.write(tr[:user], [ent])
      @users
    end
  end # def binder_user()

  
  #####################################
  # Set values
  #
  # @param tr (see #jacket_create)
  # @param vals [Hash] New values
  def binder_values(tr, vals)
    vals.each do |vn, vs|
      Binder.limits_value(vn)
      Binder.limits_setting(vs)
    end
    _control(tr) do |jck|
      ent = _control_values(tr, vals)
      jck.write(tr[:user], [ent])
      @values
    end
  end # def binder_values()


  #####################################
  # Get info
  #
  # @param tr (see #jacket_create)
  # @return [Hash] Containing :id_hash, :id_text, :jackets, :values, :users
  def binder_info(tr)
    _shared do
      _perms(tr, ['info'])    
      {
        :id_hash => @id_hash.dup,
        :id_text => @id_text.dup,
        :values => @values,
        :jackets => @jackets,
        :users => @users,
      }
    end
  end # def binder_info()


  #########################################################
  # @!group Jacket


  #####################################
  # Read list of tags
  #
  # @param tr (see #jacket_create)
  def read_list(tr)
    _jacket(tr, 'info'){|jck| jck.read_list }
  end # def read_list()


  #####################################
  # Read a tag
  #
  # @param tr (see #jacket_create)
  # @param tag [String] Tag name
  # @param offs [Integer] Offset to begin reading
  # @param max [Integer] Maximum number of entries to read
  def read_tag(tr, tag, offs, max)
    _jacket(tr, 'read') do |jck|
      size, ents = jck.read_tag(tag, offs, max)
      lst = ents.map do |ent|
        [ent.entry, ent.revision, ent.time, ent.title, ent.tags.size,
          ent.attachments.size]
      end
      [size, lst]
    end
  end # def read_tag()


  #####################################
  # Read history log
  #
  # @param tr (see #jacket_create)
  # @param offs [Integer] Offset to begin reading
  # @param max [Integer] Maximum number of histories to read
  def read_log(tr, offs, max)
    _jacket(tr, 'info') do |jck|
      cur = jck.read_history()
      hmax = cur ? cur.history : 0
      start = (offs <= hmax) ? hmax - offs : 0
      stop = (start - max > 0) ? (start - (max-1)) : 1
      ary = []
      if start != 0
        start.downto(stop) do |hnum|
          hst = jck.read_history(hnum)
          ary.push [hst.history, hst.time, hst.user, hst.entries.size,
            hst.attachments.size]
        end
      end
      [hmax, ary]
    end
  end # def read_log()


  #####################################
  # Read an entry
  #
  # @param tr (see #jacket_create)
  # @param enum [Integer] Entry number
  # @param rnum [Integer] Revision number
  # @return [Entry] the Requested entry
  def read_entry(tr, enum, rnum=0)
    _jacket(tr, 'read') do |jck|
      cur = jck.read_entry(enum, 0)
      pl = cur.perms
      _perms(tr, pl) if !pl.empty?
      if rnum == 0
        cur
      else
        jck.read_entry(enum, rnum)
      end
    end
  end # def read_entry()


  #####################################
  # Read a history item
  #
  # @param tr (see #jacket_create)
  # @param hnum [Integer] History number
  # @return [History] History item requested
  def read_history(tr, hnum)
    _jacket(tr, 'info'){|jck| jck.read_history(hnum) }
  end # def read_history()


  #####################################
  # Read an attachment
  #
  # @param tr (see #jacket_create)
  # @param enum [Integer] Entry number
  # @param anum [Integer] Attachment number
  # @param hnum [Integer] History number
  # @return [File] Attachment
  def read_attach(tr, enum, anum, hnum)
    _jacket(tr, 'read') do |jck|
      cur = jck.read_entry(enum, 0)
      pl = cur.perms
      _perms(tr, pl) if !pl.empty?
      jck.read_attach(enum, anum, hnum)
    end
  end # def read_attach()

  
  #####################################
  # Write entries
  #
  # @param tr (see #jacket_create)
  # @param ents [Array] List of entries to write
  # @return (see Jacket#write)
  # @raise [Error::Permission] if user lacks require permissions
  # @raise [Error::Conflict] if entry revision is not one up from current
  def write(tr, ents)
    olde = ents.select{|ent| ent.entry }
    enums = olde.map{|ent| ent.entry }
    _jacket(tr, 'write') do |jck|
      cur = jck.read_array(enums)
      pl = []
      cur.each{|ent| pl.concat ent.perms }
      _perms(tr, pl) if !pl.empty?
      enums.each_index do |idx|
        if cur[idx].revision + 1 != olde[idx].revision
          raise Error::Conflict, 'Entry revision conflict'
        end
      end
      jck.write(tr[:user], ents)
    end
  end # def write()


  #########################################################
  # @!group Backup


  #####################################
  # Push to a backup store
  #
  # @param bsto [Store] Backup store
  # @param prev [Hash] Jacket id_hash to previously pushed max history
  # @return [Hash] Jacket id_hash to max history backed up
  def backup_push(bsto, prev)

    stat = {}
    
    # control jacket push
    jcks = nil
    _shared do
      ctl = _jacket_open(0)
      begin
        min = prev[@id_hash] || 1
        stat[@id_hash] = ctl.backup(bsto, min_history: min)
      ensure
        ctl.close
      end
      jcks = @jackets.values
    end

    # all other jackets
    jcks.each do |info|
      jck = _jacket_open(info[:num])
      begin
        id = info[:id_hash]
        min = prev[id] || 1
        stat[id] = jck.backup(bsto, min_history: min)
      ensure
        jck.close
      end
    end

    return stat
  end # def backup_push()


  #####################################
  # Pull from backup store
  def backup_pull(bsto)
    
    @lock.do_ex do

      # control jacket
      ctl = _jacket_open(0)
      begin
        ctl.restore(bsto)
        _update(ctl)
      ensure
        ctl.close()
      end
      _cache_write()

      # all other jackets
      @jackets.values.each do |info|
        begin
          jck = _jacket_open(info[:num])
        rescue Error::NonExistent
          _jacket_create_raw(info)
          jck = _jacket_open(info[:num])
        end
        begin
          jck.restore(bsto)
        ensure
          jck.close
        end
      end

    end 

  end # def backup_pull()


  private


  #####################################
  # Update cache
  def _update(ctl)

    values = {}
    users = {}
    jackets = {}

    ctl.read_list.each do |tag|

      # values
      if tag == 'values'

        # process all values entries
        offs = 0
        while true
          size, ary = ctl.read_tag(tag, offs, 2)
          break if ary.empty?
          ary.each do |ent|
            info = _get_json(ent)
            info.each do |val, sta|
              next if values.has_key?(val)
              values[val] = sta
            end
          end
          offs += 2
        end

        # clear unset values
        values.delete_if{ |val, sta| !sta.is_a?(String) }

      # jacket
      elsif /^jacket:/.match(tag)
        size, ary = ctl.read_tag(tag, 0, 1)
        info = _get_json(ary.first)
        jackets[info['name']] = {
          num: info['num'],
          name: info['name'],
          id_hash: info['id_hash'],
          id_text: info['id_text'],
          title: info['title'],
          perms: info['perms'],
        }

      # user
      elsif /^user:/.match(tag)
        size, ary = ctl.read_tag(tag, 0, 1)
        info = _get_json(ary.first)
        name = info['name']
        perms = info['perms']
        users[name] = perms

      end
    end

    @users = users
    @values = values
    @jackets = jackets

  end # def _update()


  #####################################
  # Get json from a body
  def _get_json(ent)
    lines = ent.body.lines
    st = lines.index{|li| li[0] == '{' || li[0] == '[' }
    if !st || (lines[-1][0] != '}' && lines[-1][0] != ']')
      puts ent.body.inspect
      raise Error::Corrupt, 'Control jacket entry does not contain JSON'
    end 
    json = lines[st..-1].join

    info = nil
    begin
      info = JSON.parse(json)
    rescue
      raise Error::Corrupt, 'Control jacket entry JSON parse error'
    end
    return info
  end # def _get_json()


  #####################################
  # Shared creation stuff
  #
  # @param ctl [Jacket] Control jacket
  # @param tr (see #jacket_create)
  # @param info [Hash] New binder creation options
  # @option info [Array] :jackets List of jackets [name, title, perms]
  # @option info [Array] :users List of users [name, perms]
  # @option info [Hash] :values List of values name => setting
  def _create(ctl, tr, info)

    # check all the values are okay
    History.limits_user(tr[:user])
    Entry.limits_title(tr[:title])
    Entry.limits_body(tr[:body])
    Binder.limits_create(info)
    
    ents = []

    # jackets
    num = 0
    info[:jackets].each do |jin|
      num += 1
      trj = {
        :title => 'Create binder initial jacket \'%s\'' % jin[:name],
        :jacket => jin[:name],
        :body => "Create binder initial jacket\n\n",
      }
      id_text, id_hash = _jacket_create(num)
      ents.push _control_jacket(trj, num, jin[:name], id_hash, id_text,
        jin[:title], jin[:perms])
    end

    # users
    info[:users].each do |uin|
      tru = {
        :title => 'Create binder initial user \'%s\'' % uin[:name],
        :body => "Create binder initial user\n\n",
      }
      ents.push _control_user(tr, uin[:name], uin[:perms])
    end

    # values
    ents.push _control_values(tr, info[:values])
    ctl.write(tr[:user], ents)
  end # def _create()


  #####################################
  # Permission check
  #
  # @param tr (see #jacket_create)
  # @param plst [Array] Permissions required
  # @raise [Error::Permissions] if require permissions not met
  def _perms(tr, plst)
    if tr[:perms]
      usr_has = tr[:perms]
    else
      usr = tr[:user]
      grp = tr[:groups]
      usr_has = []
      usr_has.concat(@users[usr]) if @users[usr]
      grp.each{|gr| usr_has.concat(@users[gr]) if @users[gr] }
      if usr_has.include?('write')
        usr_has.concat ['read', 'info']
      elsif usr_has.include?('read') || usr_has.include?('manage')
        usr_has.push 'info'
      end
      usr_has.uniq!
      tr[:perms] = usr_has
    end

    miss = []
    plst.each{|pr| miss.push(pr) if !usr_has.include?(pr) }

    if !miss.empty?
      raise Error::Permission, 'User lacks permission(s): ' + miss.join(', ')
    end
  end # def _perms()


  #####################################
  # Access a jacket
  #
  # @param tr (see #jacket_create)
  # @param perm [String] Basic permission needed (write, read, info)
  def _jacket(tr, perm)
    ret = nil
    _shared do
      jnam = tr[:jacket]
      raise Error::NonExistent, 'Jacket does not exist' if !@jackets[jnam]
      pl = [perm].concat @jackets[jnam][:perms]
      _perms(tr, pl)
      jck = _jacket_open(@jackets[jnam][:num])
      begin
        ret = yield(jck)
      ensure
        jck.close
      end
    end
    return ret
  end # def _jacket()


  #####################################
  # Edit control jacket
  #
  # @param tr (see #jacket_create)
  def _control(tr)
    ret = nil
    @lock.do_ex do
      _cache_read()
      _perms(tr, ['manage'])
      begin
        ctl = _jacket_open(0)
        begin
          ret = yield(ctl)
        ensure
          ctl.close()
        end
        _cache_write()
      ensure
        _cache_clear()
      end
    end # @lock_do
    return ret
  end # def _control()


  #####################################
  # Shared access to the binder
  def _shared
    ret = nil
    @lock.do_sh do
      _cache_read()
      begin
        ret = yield
      ensure
        _cache_clear()
      end
    end # @lock.do_sh
    return ret
  end # def _shared


  #####################################
  # Set jacket info
  def _control_jacket(tr, num, name, id_hash, id_text, title, perms)
    info = {
      num: num,
      name: name,
      id_hash: id_hash,
      id_text: id_text,
      title: title,
      perms: perms,
    }
    json = JSON.pretty_generate(info)

    ent = Entry.new
    ent.tag( 'jacket: %d' % num )
    ent.title = tr[:title]
    ent.body = tr[:body] + "\n" + json + "\n"

    @jackets.delete(tr[:jacket])
    @jackets[name] = info
    
    return ent
  end # def _control_jacket()


  #####################################
  # Set user permissions in the control jacket
  def _control_user(tr, user, perms)
    info = {
      name: user,
      perms: perms,
    }
    json = JSON.pretty_generate(info)

    ent = Entry.new
    ent.tag( 'user: %s' % user )
    ent.title = tr[:title]
    ent.body = tr[:body] + "\n" + json + "\n"

    @users[user.dup] = perms.map{|pr| pr.dup }

    return ent
  end # def _control_user()


  #####################################
  # Set binder values in the control jacket
  def _control_values(tr, vals)
    json = JSON.pretty_generate(vals)

    ent = Entry.new
    ent.tag( 'values' )
    ent.title = tr[:title]
    ent.body = tr[:body] + "\n" + json + "\n"

    vals.each do |val, sta|
      vas = val.is_a?(Symbol) ? val : val.to_s
      if sta
        @values[val] = sta
      else
        @values.delete(val)
      end
    end

    return ent
  end # def _control_values()
 

  #####################################
  # Clear cache
  def _cache_clear
    @jackets = nil
    @users = nil
    @values = nil
  end # def _cache_clear

end # class Binder

end # module Sgfa
