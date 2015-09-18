#
# Simple Group of Filing Applications
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require_relative 'sgfa/binder_fs'

#####################################################################
# Simple Group of Filing Applications
#
# This is a collection of software which implements a filing system.
# It was originally designed around the needs of an investigative case
# management system, although care was taken to ensure that it provides a
# generic filing utility that should support multiple other uses.
#
# The elementary building block for the system is an {Entry} which consists
# of a time and date, a short title, a text body, attached files, and
# tags.  Entries are made in {Jacket}s which serve two functions.
# First, they are an organizational unit which allows grouping of related
# entries.  Second, they provide a permanent history of all changes made to
# the jacket in the form of a chain of {History} change entries.
#
# All {Jacket}s are stored in a {Binder} which is the basic administrative
# unit in the system.  Access control is applied at the Binder level by
# assigning permissions to users or groups.  There are several basic
# permissions which control of read, write, and general information for the
# entire binder.  In addition, Binder specific permissions can be created and
# applied to specific Jackets or Entries.  The Binder can be assigned state
# values which are used to manage a collection of Binders.
#
module Sgfa; end

