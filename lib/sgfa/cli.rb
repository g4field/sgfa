#
# Simple Group of Filing Applications
# Command line interface tool
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'thor'

require_relative 'cli/jacket'
require_relative 'cli/binder'

module Sgfa

#####################################################################
# Command line interface for Sgfa tools
module Cli

#####################################################################
# Top level CLI
class Sgfa < Thor

  desc 'jacket ...', 'Jacket CLI tools'
  subcommand 'jacket', Jacket

  desc 'binder ...', 'Binder CLI tools'
  subcommand 'binder', Binder

end # class Sgfa

end # module Cli
end # module Sgfa
