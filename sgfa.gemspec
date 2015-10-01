Gem::Specification.new do |gs|

  gs.name = 'sgfa'
  gs.version = '0.1.0'
  gs.license = 'GPL-3.0'
  gs.summary = 'Simple Group of Filing Applications'
  gs.description =
    "Group of related tools to manage filing of data in a structured " +
    "fashion.  This is very much an initial release of a development " +
    "effort."
  gs.authors = ["Graham A. Field"]
  gs.email = 'gfield@retr.org'
  gs.homepage = 'https://github.com/g4field/sgfa'
  gs.files = [
    'LICENSE.txt',
    'README.txt',

    'lib/sgfa.rb',
    'lib/sgfa/binder.rb',
    'lib/sgfa/error.rb',
    'lib/sgfa/entry.rb',
    'lib/sgfa/history.rb',
    'lib/sgfa/jacket.rb',

    'lib/sgfa/binder_fs.rb',
    'lib/sgfa/state_fs.rb',
    'lib/sgfa/store_fs.rb',
    'lib/sgfa/lock_fs.rb',
    'lib/sgfa/jacket_fs.rb',

    'lib/sgfa/web/base.rb',
    'lib/sgfa/web/binder.rb',
  
    'lib/sgfa/cli.rb',
    'lib/sgfa/cli/binder.rb',
    'lib/sgfa/cli/jacket.rb',

    'lib/sgfa/demo/web_css.rb',
    'lib/sgfa/demo/web_binders.rb',
  
    'data/sgfa_web.css',

    'bin/sgfa',
]

gs.bindir = 'bin'
gs.executables << 'sgfa'

end
