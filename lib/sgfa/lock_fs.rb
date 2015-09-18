#
# Simple Group of Filing Applications
# Locking using filesystem locks
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require_relative 'error'

module Sgfa


##########################################################################
# Lock based on file locks
class LockFs


  ################################
  # Lock state
  #
  # @return [Symbol] :closed, :unlocked, :shared, or :exclusive
  attr_reader :state


  ################################
  # Initialize
  def initialize
    @file = nil
    @state = :closed
  end # def initialize


  ################################
  # Open lock file
  #
  # @todo Handle exceptions from File.open()
  #
  # @param fnam [String] File name of lock file
  # @return [String] Contents of the lock file
  # @raise [Error::Sanity] if lock already open
  def open(fnam)
    raise Error::Sanity, 'Lock file already open' if @file
    @file = File.open(fnam, 'r', :encoding => 'utf-8')
    @state = :unlocked
    return @file.read
  end # def open()


  ################################
  # Close lock file
  #
  # @raise [Error::Sanity] if lock not open
  def close
    raise Error::Sanity, 'Lock file not open' if !@file
    @file.close
    @file = nil
    @state = :closed
  end # def close


  ################################
  # Take exclusive lock
  #
  # @raise [Error::Sanity] if lock not open
  def exclusive
    raise Error::Sanity, 'Lock file not open' if !@file

    if @state == :exclusive
      return
    elsif @state == :shared
      @file.flock(File::LOCK_UN)
    end

    @file.flock(File::LOCK_EX)
    @state = :exclusive
  end # def exclusive


  ################################
  # Take shared lock
  #
  # @raise [Error::Sanity] if lock not open
  def shared
    raise Error::Sanity, 'Lock file not open' if !@file
    return if @state == :shared
    @file.flock(File::LOCK_SH)
    @state = :shared
  end # def shared


  ################################
  # Release lock
  #
  # @raise [Error::Sanity] if lock not open
  def unlock
    raise Error::Sanity, 'Lock file not open' if !@file
    return if @state == :unlocked
    @file.flock(File::LOCK_UN)
    @state = :unlocked
  end # def unlock


  ################################
  # Run block while holding exclusive lock
  #
  # @param rel [Boolean] Release lock on return
  # @raise (see #exclusive)
  def do_ex(rel=true)
    exclusive
    begin
      ret = yield
    ensure
      unlock if rel
    end
    return ret
  end # def do_ex


  ################################
  # Run block while holding shared lock
  #
  # @param rel [Boolean] Release lock on return
  # @riase (see #shared)
  def do_sh(rel=true)
    shared
    begin
      ret = yield
    ensure
      unlock if rel
    end
    return ret
  end # def do_sh


end # class LockFs

end # module Sgfa
