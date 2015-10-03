#
# Simple Group of Filing Applications
# Web interface to Binder
#
# Copyright (C) 2015 by Graham A. Field.
#
# See LICENSE.txt for licensing information.
#
# This program is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

require 'rack'
require 'time'

require_relative 'base'
require_relative '../error'

module Sgfa
module Web


#####################################################################
# Binder web interface
#
# @todo Add a docket view 
class Binder < Base

  #####################################
  # Request
  #
  # @param env [Hash] The Rack environment for this request, with app
  #   specific options
  # @option env [String] 'sgfa.binder.url' URL encoded binder name
  # @option env [String] 'sgfa.binder.name' The name of the binder
  # @option env [Binder] 'sgfa.binder' The binder
  # @option env [String] 'sgfa.user' The user name
  # @option env [Array] 'sgfa.groups' Array of groups the user belongs to
  #
  def call(env)
    _call(env)
    return response(env)

  rescue Error::Permission => exp
    env['sgfa.status'] = :deny
    env['sgfa.html'] = _escape_html(exp.message)
    return response(env)

  rescue Error::Conflict => exp
    env['sgfa.status'] = :conflict
    env['sgfa.html'] = _escape_html(exp.message)
    return response(env)

  rescue Error::NonExistent => exp
    env['sgfa.status'] = :notfound
    env['sgfa.html'] = _escape_html(exp.message)
    return response(env)
  
  rescue Error::Limits => exp
    env['sgfa.status'] = :badreq
    env['sgfa.html'] = _escape_html(exp.message)
    return response(env)

  rescue Error::Corrupt => exp
    env['sgfa.status'] = :servererror
    env['sgfa.html'] = _escape_html(exp.message)
    return response(env)

  end # def request()


  #####################################
  # Process the request
  #
  # This is a seperate method to simplify the flow control by using return.
  def _call(env)

    # defaults
    env['sgfa.status'] = :badreq
    env['sgfa.title'] = 'SFGA Error'
    env['sfga.navbar'] = ''
    env['sgfa.html'] = 'Invalid request'

    path = env['PATH_INFO'].split('/')
    if path.empty?
      jacket = nil
    else
      path.shift if path[0].empty?
      jacket = path.shift
    end

    # just the binder
    if !jacket
      case env['REQUEST_METHOD']
        when 'GET'; return _get_jackets(env, path)
        when 'POST'; return _post_binder(env)
        else; return
      end
    end

    # special binder pages
    if jacket[0] == '_'
      return if env['REQUEST_METHOD'] != 'GET'
      case jacket
      when '_jackets'
        return _get_jackets(env, path)
      when '_users'
        return _get_users(env, path)
      when '_values'
        return _get_values(env, path)
      when '_info'
        return _get_binder(env, path)
      else
        return
      end
    end

    # jacket info stored
    env['sgfa.jacket.url'] = jacket
    env['sgfa.jacket.name'] = _escape_un(jacket)
    cmd = path.shift

    # just the jacket
    if !cmd
      case env['REQUEST_METHOD']
        when 'GET'; return _get_tag(env, path)
        when 'POST'; return _post_jacket(env)
        else; return
      end
    end

    # jacket stuff
    return if env['REQUEST_METHOD'] != 'GET'
    case cmd
      when '_edit'; return _get_edit(env, path)
      when '_entry';  return _get_entry(env, path)
      when '_history'; return _get_history(env, path)
      when '_attach'; return _get_attach(env, path)
      when '_tag'; return _get_tag(env, path)
      when '_log'; return _get_log(env, path)
      when '_list'; return _get_list(env, path)
      when '_info'; return _get_info(env, path)
      else; return
    end

  end # def _call()


  NavBarBinder = [
    ['Jackets', '_jackets'],
    ['Users', '_users'],
    ['Values', '_values'],
    ['Binder', '_info'],
  ]


  #####################################
  # Generate navigation bar for a binder
  def _navbar_binder(env, act)
    env['sgfa.title'] = 'SGFA Binder %s &mdash; %s' % 
      [act, _escape_html(env['sgfa.binder.name'])]
    base = env['SCRIPT_NAME']
    txt = _navbar(env, act, NavBarBinder, base)
    if env['sgfa.cabinet.url']
      txt << "<div class='link'><a href='%s'>Cabinet</a></div>\n" %
        env['sgfa.cabinet.url']
    end
    env['sgfa.navbar'] = txt
  end # def _navbar_binder()


  NavBarJacket = [
    ['Tag', '_tag'],
    ['List', '_list'],
    ['Entry', nil],
    ['Edit', '_edit'],
    ['History', nil],
    ['Attachment', nil],
    ['Jacket', '_info'],
    ['Log', '_log'],
  ]

  #####################################
  # Generate navbar for a jacket
  def _navbar_jacket(env, act)
    env['sgfa.title'] = 'SGFA Jacket %s &mdash; %s : %s' % [
      act,
      _escape_html(env['sgfa.binder.name']),
      _escape_html(env['sgfa.jacket.name'])
    ]
    base = env['SCRIPT_NAME'] + '/' + env['sgfa.jacket.url']
    txt = _navbar(env, act, NavBarJacket, base)
    txt << "<div class='link'><a href='%s'>Binder</a></div>\n" %
      env['SCRIPT_NAME']
    env['sgfa.navbar'] = txt
  end # def _navbar_jacket()


  #####################################
  # Link to a jacket
  def _link_jacket(env, jnam, disp)
    "<a href='%s/%s'>%s</a>" % [env['SCRIPT_NAME'], _escape(jnam), disp]
  end # def _link_jacket()


  #####################################
  # Link to edit entry
  def _link_edit(env, enum, disp)
    "<a href='%s/%s/_edit/%d'>%s</a>" % [
      env['SCRIPT_NAME'], 
      env['sgfa.jacket.url'],
      enum,
      disp
    ]
  end # def _link_edit()


  #####################################
  # Link to display an entry
  def _link_entry(env, enum, disp)
    "<a href='%s/%s/_entry/%d'>%s</a>" % [
      env['SCRIPT_NAME'],
      env['sgfa.jacket.url'],
      enum,
      disp
    ]
  end # def _link_entry()


  #####################################
  # Link to a specific revision
  def _link_revision(env, enum, rnum, disp)
    "<a href='%s/%s/_entry/%d/%d'>%s</a>" % [
      env['SCRIPT_NAME'],
      env['sgfa.jacket.url'],
      enum,
      rnum,
      disp
    ]
  end # def _link_revision()


  #####################################
  # Link to a history item
  def _link_history(env, hnum, disp)
    "<a href='%s/%s/_history/%d'>%s</a>" % [
      env['SCRIPT_NAME'],
      env['sgfa.jacket.url'],
      hnum, disp
    ]
  end # def _link_history()


  #####################################
  # Link to a tag
  def _link_tag(env, tag, disp)
    "<a href='%s/%s/_tag/%s'>%s</a>" % [
      env['SCRIPT_NAME'],
      env['sgfa.jacket.url'],
      _escape(tag),
      disp
    ]
  end # def _link_tag()


  #####################################
  # Link to a tag prefix
  def _link_prefix(env, pre, disp)
    "<a href='%s/%s/_list/%s'>%s</a>" % [
      env['SCRIPT_NAME'],
      env['sgfa.jacket.url'],
      _escape(pre),
      disp
    ]
  end # def _link_prefix()
  

  #####################################
  # Link to an attachments
  def _link_attach(env, enum, anum, hnum, name, disp)
    "<a href='%s/%s/_attach/%d-%d-%d/%s'>%s</a>" % [
      env['SCRIPT_NAME'],
      env['sgfa.jacket.url'],
      enum,
      anum,
      hnum,
      _escape(name),
      disp
    ]
  end # def _link_attach()

  
  JacketsTable = 
    "<table class='list'>" +
    "<tr><th>Jacket</th><th>Title</th><th>Perms</th></tr>\n" +
    "%s</table>"

  JacketsRow = 
    "<tr><td class='name'>%s</td>" +
    "<td class='title'>%s</td><td class='perms'>%s</td></tr>\n"

  JacketsForm =
    "\n<hr>\n<form class='edit' method='post' action='%s' " +
    "enctype='multipart/form-data'>\n" +
    "<fieldset><legend>Create or Edit Jacket</legend>\n" +
    "<label for='jacket'>Name:</label>" +
    "<input class='jacket' name='jacket' type='text'><br>\n" +
    "<label for='newname'>Rename:</label>" +
    "<input class='jacket' name='newname' type='text'><br>\n" +
    "<label for='title'>Title:</label>" +
    "<input class='title' name='title' type='text'><br>\n" +
    "<label for='perms'>Perms:</label>" +
    "<input class='perms' name='perms' type='text'><br>\n" +
    "</fieldset>\n" +
    "<input type='submit' name='create' value='Create/Edit'>\n" +
    "</form>\n"

  #####################################
  # Get jacket list
  def _get_jackets(env, path)
    _navbar_binder(env, 'Jackets')

    if !path.empty?
      env['sgfa.status'] = :badreq
      env['sgfa.html'] = 'Invalid URL requested'
      return
    end

    tr = _trans(env)
    info = env['sgfa.binder'].binder_info(tr)

    env['sgfa.status'] = :ok
    env['sgfa.html'] = _disp_jackets(env, info[:jackets], tr)
  end # def _get_jackets()


  #####################################
  # Display jacket list
  def _disp_jackets(env, jackets, tr)

    rows = ''
    jackets.each do |jnam, jinfo|
      perms = jinfo[:perms]
      ps = perms.empty? ? '-' : _escape_html(perms.join(', '))
      rows << JacketsRow % [_link_jacket(env, jnam, _escape_html(jnam)),
        _escape_html(jinfo[:title]), ps]  
    end
    html = JacketsTable % rows
    html << JacketsForm % env['SCRIPT_NAME'] if tr[:perms].include?('manage')

    return html
  end # def _disp_jackets()

  
  BinderTable = 
    "<table>\n" +
    "<tr><td>Hash ID:</td><td>%s</td></tr>\n" +
    "<tr><td>Text ID:</td><td>%s</td></tr>\n" +
    "<tr><td>Jackets:</td><td>%d</td></tr>\n" +
    "<tr><td>Users:</td><td>%d</td></tr>\n" +
    "<tr><td>Values:</td><td>%d</td></tr>\n" +
    "<tr><td>User Permissions:</td><td>%s</td></tr>\n" +
    "</table>\n"

  #####################################
  # Get binder info
  def _get_binder(env, path)
    _navbar_binder(env, 'Binder')
    return if !path.empty?

    tr = _trans(env)
    info = env['sgfa.binder'].binder_info(tr)
    
    env['sgfa.status'] = :ok
    env['sgfa.html'] = BinderTable % [
      info[:id_hash], _escape_html(info[:id_text]),
      info[:jackets].size, info[:users].size, info[:values].size,
      _escape_html(tr[:perms].join(', '))
    ]
  end # def _get_binder()


  UsersTable =
    "<table class='list'>\n" +
    "<tr><th>User</th><th>Permissions</th></tr>\n" +
    "%s</table>\n"

  UsersRow =
    "<tr><td>%s</td><td>%s</td></tr>\n"

  UsersForm = 
    "\n<hr>\n<form class='edit' method='post' action='%s' " +
    "enctype='multipart/form-data'>\n" +
    "<fieldset><legend>Set User or Group Permissions</legend>\n" +
    "<label for='user'>Name:</label>" +
    "<input class='user' name='user' type='text'><br>\n" +
    "<label for='perms'>Perms:</label>" +
    "<input class='perms' name='perms' type='text'><br>\n" +
    "</fieldset>\n" +
    "<input type='submit' name='set' value='Set'>\n" +
    "</form>\n"

  #####################################
  # Get users
  def _get_users(env, path)
    _navbar_binder(env, 'Users')

    if !path.empty?
      env['sgfa.status'] = :badreq
      env['sgfa.html'] = 'Invalid URL requested'
      return
    end

    tr = _trans(env)
    info = env['sgfa.binder'].binder_info(tr)

    env['sgfa.status'] = :ok
    env['sgfa.html'] = _disp_users(env, info[:users], tr)
  end # def _get_users()


  #####################################
  # Display users
  def _disp_users(env, users, tr)
    rows = ''
    users.each do |unam, pl|
      perms = pl.empty? ? '-' : pl.join(', ')
      rows << UsersRow % [
        _escape_html(unam), _escape_html(perms)
      ]
    end
    html = UsersTable % rows 
    html << (UsersForm % env['SCRIPT_NAME']) if tr[:perms].include?('manage')
    return html
  end # def _disp_users()


  ValuesTable = 
    "<table class='list'>\n" +
    "<tr><th>Value</th><th>State</th></tr>\n" +
    "%s\n</table>\n"

  ValuesRow =
    "<tr><td>%s</td><td>%s</td></tr>\n"

  ValuesForm = 
    "\n<hr>\n<form class='edit' method='post' action='%s' " +
    "enctype='multipart/form-data'>\n" +
    "<fieldset><legend>Assign Binder Values</legend>\n" +
    "<label for='value'>Value:</label>" +
    "<input class='value' name='value' type='text'><br>\n" +
    "<label for='state'>State:</label>" +
    "<input class='state' name='state' type='text'><br>\n" +
    "</fieldset>\n" +
    "<input type='submit' name='assign' value='Assign'>\n" +
    "</form>\n"

  #####################################
  # Get values
  def _get_values(env, path)
    _navbar_binder(env, 'Values')
    
    if !path.empty?
      env['sgfa.status'] = :badreq
      env['sgfa.html'] = 'Invalid URL requested'
      return
    end

    tr = _trans(env)
    info = env['sgfa.binder'].binder_info(tr)
    
    env['sgfa.status'] = :ok
    env['sgfa.html'] = _disp_values(env, info[:values], tr)
  end # def _get_values()


  #####################################
  # Display values
  def _disp_values(env, values, tr)
    rows = ''
    values.each do |vnam, vset|
      rows << ValuesRow % [
        _escape_html(vnam), _escape_html(vset)
      ]
    end
    html = ValuesTable % rows
    html << (ValuesForm % env['SCRIPT_NAME']) if tr[:perms].include?('manage')
    
    return html
  end # def _disp_values()


  TagTable = 
    "<div class='title'>Tag: %s</div>\n" +
    "<table class='list'>\n<tr>" +
    "<th>Time</th><th>Title</th><th>Files</th><th>Tags</th><th>Edit</th>" +
    "</tr>\n%s</table>\n"

  TagRow = 
    "<tr><td class='time'>%s</td><td class='title'>%s</td>" +
    "<td class='num'>%d</td><td class='num'>%d</td>" +
    "<td class='act'>%s</td></tr>\n"

  PageSize = 25
  PageSizeMax = 100

  #####################################
  # Get a tag
  def _get_tag(env, path)
    _navbar_jacket(env, 'Tag')

    if path.empty?
      tag = '_all'
    else
      tag = _escape_un(path.shift)
    end
    page = path.empty? ? 1 : path.shift.to_i
    page = 1 if page == 0
    rck = Rack::Request.new(env)
    params = rck.GET
    per = params['perpage'] ? params['perpage'].to_i : 0
    if per == 0 || per > PageSizeMax
      per = PageSize
    end

    tr = _trans(env)
    size, ents = env['sgfa.binder'].read_tag(tr, tag, (page-1)*per, per)
    if ents.size == 0
      html = 'No entries'
    else
      rows = ''
      ents.reverse_each do |enum, rnum, time, title, tcnt, acnt|
        rows << TagRow % [
          time.localtime.strftime("%F %T %z"),
          _link_entry(env, enum, _escape_html(title)),
          acnt, tcnt,
          _link_edit(env, enum, 'edit')
        ]
      end
      html = TagTable % [_escape_html(tag), rows]
    end

    link = '%s/%s/_tag/%s' % [
      env['SCRIPT_NAME'],
      env['sgfa.jacket.url'],
      _escape(tag)
    ]
    query = (per != PageSize) ? { 'perpage' => per.to_s } : nil
    pages = _link_pages(page, per, size, link, query)

    env['sgfa.status'] = :ok
    env['sgfa.html'] = html + pages
  end # def _get_tag()


  LogTable = 
    "<table class='list'>\n<tr>" +
    "<th>History</th><th>Date/Time</th><th>User</th><th>Entries</th>" +
    "<th>Attachs</th></tr>\n%s</table>\n"

  LogRow = 
    "<tr><td class='hnum'>%d</td><td class='time'>%s</td>" +
    "<td class='user'>%s</td><td>%d</td><td>%d</td></tr>\n"

  #####################################
  # Get the log
  def _get_log(env, path)
    _navbar_jacket(env, 'Log')

    page = path.empty? ? 1 : path.shift.to_i
    page = 1 if page == 0
    return if !path.empty?
    rck = Rack::Request.new(env)
    params = rck.GET
    per = params['perpage'] ? params['perpage'].to_i : 0
    if per == 0 || per > PageSizeMax
      per = PageSize
    end

    tr = _trans(env)
    size, hsts = env['sgfa.binder'].read_log(tr, (page-1)*per, per)
    if hsts.size == 0
      env['sgfa.html'] = 'No history'
      env['sgfa.status'] = :notfound
    else
      rows = ''
      hsts.each do |hnum, time, user, ecnt, acnt|
        rows << LogRow % [
          hnum,
          _link_history(env, hnum, time.localtime.strftime('%F %T %z')),
          _escape_html(user),
          ecnt, acnt
        ]
      end
      link = '%s/%s/_log' % [env['SCRIPT_NAME'], env['sgfa.jacket.url']]
      query = (per != PageSize) ? { 'perpage' => per.to_s } : nil
      env['sgfa.status'] = :ok
      env['sgfa.html'] = (LogTable % rows) +
        _link_pages(page, per, size, link, query)
    end

  end # def _get_log()

  
  #####################################
  # Get an entry
  def _get_entry(env, path)
    _navbar_jacket(env, 'Entry')

    return if path.empty?
    enum = path.shift.to_i
    rnum = path.empty? ? 0 : path.shift.to_i
    return if enum == 0

    tr = _trans(env)
    ent = env['sgfa.binder'].read_entry(tr, enum, rnum)

    env['sgfa.status'] = :ok
    env['sgfa.html'] = _disp_entry(env, ent)
  end # def _get_entry()


  EntryDisp = 
    "<div class='title'>%s</div>\n" +
    "<div class='body'><pre>%s</pre></div>\n" +
    "<div class='sidebar'>\n" +
    "<div class='time'>%s</div>\n" +
    "<div class='history'>Revision: %d %s %s<br>History: %s %s</div>\n" +
    "<div class='tags'>%s</div>\n" +
    "<div class='attach'>%s</div>\n" + 
    "</div>\n" +
    "<div class='hash'>Hash: %s<br>Jacket: %s</div>\n"

  #####################################
  # Display an entry
  def _disp_entry(env, ent)

    enum = ent.entry
    rnum = ent.revision
    hnum = ent.history

    tl = ent.tags
    tags = "Tags:<br>\n"
    if tl.empty?
      tags << "none\n"
    else
      tl.sort.each do |tag|
        tags << _link_tag(env, tag, _escape_html(tag)) + "<br>\n"
      end
    end

    al = ent.attachments
    att = "Attachments:<br>\n"
    if al.empty?
      att << "none\n"
    else
      al.each do |anum, hnum, name|
        att << _link_attach(env, enum, anum, hnum, name, _escape_html(name)) +
          "<br>\n"
      end
    end
    if rnum == 1
      prev = 'previous'
    else
      prev = _link_revision(env, enum, rnum-1, 'previous')
    end
    curr = _link_entry(env, enum, 'current')
    edit = _link_edit(env, enum, 'edit')

    body = EntryDisp % [
      _escape_html(ent.title),
      _escape_html(ent.body),
      ent.time.localtime.strftime('%F %T %z'),
      rnum, prev, curr, _link_history(env, hnum, hnum.to_s), edit,
      tags,
      att,
      ent.hash, ent.jacket
    ]

    return body
  end # def _disp_entry()


  HistoryDisp =
    "<div class='title'>History %d</div>\n" +
    "<div class='body'>%s</div>" +
    "<div class='sidebar'>\n" +
    "<div class='time'>%s</div>\n" +
    "<div class='user'>%s</div>\n" +
    "<div class='nav'>%s %s</div>\n" +
    "</div>\n<div class='hash'>Hash: %s<br>Jacket: %s</div>\n"

  HistoryTable =
    "<table class='list'>\n<tr><th>Item</th><th>Hash</th></tr>\n" +
    "%s</table>\n"

  HistoryItem =
    "<tr><td>%s</td><td class='hash'>%s</td></tr>\n"

  #####################################
  # Display a history item
  def _get_history(env, path)
    _navbar_jacket(env, 'History')

    return if path.empty?
    hnum = path.shift.to_i
    return if hnum == 0

    tr = _trans(env)
    hst = env['sgfa.binder'].read_history(tr, hnum)
    hnum = hst.history
    plnk = (hnum == 1) ? 'Previous' : _link_history(env, hnum-1, 'Previous')
    nlnk = _link_history(env, hnum+1, 'Next')

    rows = ""
    hst.entries.each do |enum, rnum, hash|
      disp = "Entry %d-%d" % [enum, rnum]
      rows << (HistoryItem % [_link_revision(env, enum, rnum, disp), hash])
    end
    hst.attachments.each do |enum, anum, hash|
      disp = "Attach %d-%d-%d" % [enum, anum, hnum]
      rows << HistoryItem %
        [_link_attach(env, enum, anum, hnum, hash + '.bin', disp), hash]
    end
    tab = HistoryTable % rows

    body = HistoryDisp % [
      hnum, tab, hst.time.localtime.strftime('%F %T %z'),
      _escape_html(hst.user), plnk, nlnk, hst.hash, hst.jacket
    ]

    env['sgfa.status'] = :ok
    env['sgfa.html'] = body
  end # def _get_history()


  ListTable = 
    "<table class='list'>\n<tr>" +
    "<th>Tag</th><th>Number</th></tr>\n" +
    "%s\n</table>\n"

  ListPrefix =
    "<tr><td class='prefix'>%s: prefix</td><td>%d tags</td></tr>\n"

  ListTag =
    "<tr><td class='tag'>%s</td><td>%d entries</td></tr>\n"

  #####################################
  # Get list of tags
  def _get_list(env, path)
    _navbar_jacket(env, 'List')

    bnd = env['sgfa.binder']
    tr = _trans(env)
    lst = bnd.read_list(tr)

    # sort into prefixed & regular
    prefix = {}
    regular = []
    lst.each do |tag|
      idx = tag.index(':')
      if !idx
        regular.push tag
        next
      end
      pre = tag[0,idx].strip
      if prefix[pre]
        prefix[pre].push tag
      else
        prefix[pre] = [tag]
      end
    end

    # regular & prefix list
    rows = ''
    if path.empty?
      prefix.keys.sort.each do |pre|
        size = prefix[pre].size
        rows << ListPrefix % 
          [_link_prefix(env, pre, _escape_html(pre)), size]
      end
      regular.sort.each do |tag|
        size, ents = bnd.read_tag(tr, tag, 0, 0)
        rows << ListTag %
          [_link_tag(env, tag, _escape_html(tag)), size]
      end

    # list entire prefix
    else
      pre = _escape_un(path.shift)
      return if !path.empty?
      if !prefix[pre]
        env['sgfa.status'] = :notfound
        env['sgfa.html'] = 'Tag prefix not found'
        return
      end

      prefix[pre].sort.each do |tag|
        size, ents = bnd.read_tag(tr, tag, 0, 0)
        rows << ListTag %
          [_link_tag(env, tag, _escape_html(tag)), size]
      end
    end

    env['sgfa.status'] = :ok
    env['sgfa.html'] = ListTable % rows
  end # def _get_list


  InfoTable = 
    "<table>\n" +
    "<tr><td>Text ID:</td><td>%s</td></tr>\n" +
    "<tr><td>Hash ID:</td><td>%s</td></tr>\n" +
    "<tr><td>Last Edit:</td><td>%s</td></tr>\n" +
    "<tr><td>History:</td><td>%d</td></tr>\n" +
    "<tr><td>Entries:</td><td>%d</td></tr>\n" +
    "</table>\n"

  #####################################
  # Get jacket info
  def _get_info(env, path)
    _navbar_jacket(env, 'Jacket')
    return if !path.empty?
    tr = _trans(env)

    info = env['sgfa.binder'].binder_info(tr)
    hst = env['sgfa.binder'].read_history(tr, 0)
    if hst
      hmax = hst.history
      emax = hst.entry_max
      time = hst.time.localtime.strftime('%F %T %z')
    else
      hmax = 0
      emax = 0
      time = 'none'
    end

    jinf = info[:jackets][env['sgfa.jacket.name']]
    env['sgfa.status'] = :ok
    env['sgfa.html'] = InfoTable % [
      jinf[:id_text], jinf[:id_hash],
      time, hmax, emax
    ]
  end # def _get_info()


  #####################################
  # Get an attachment
  def _get_attach(env, path)
    _navbar_jacket(env, 'Attachment')

    spec = path.shift
    return if !spec
    ma = /^(\d+)-(\d+)-(\d+)$/.match(spec)
    return if !ma
    name = path.shift
    return if !name
    return if !path.empty?
    enum, anum, hnum = ma[1,3].map{|st| st.to_i}
    name = _escape_un(name)
    
    ext = name.rpartition('.')[2]
    if ext.empty?
      mime = 'application/octet-stream'
    else
      mime = Rack::Mime.mime_type('.' + ext)
    end

    tr = _trans(env)
    file = env['sgfa.binder'].read_attach(tr, enum, anum, hnum)
   
    env['sgfa.status'] = :ok
    env['sgfa.headers'] = {
      'Content-Length' => file.size.to_s,
      'Content-Type' => mime,
      'Content-Disposition' => 'attachment',
    }
    env['sgfa.file'] = FileBody.new(file)

  end # def _get_attach()


  EditForm = 
    "<form class='edit' method='post' action='%s/%s' " +
    "enctype='multipart/form-data'>\n" +
    "<input name='entry' type='hidden' value='%d'>\n" +
    "<input name='revision' type='hidden' value='%d'>\n" +

    "<div class='edit'>\n" +

    "<fieldset><legend>Basic Info</legend>\n" +

    "<label for='title'>Title:</label>" +
    "<input class='title' name='title' type='text' value='%s'><br>\n" +

    "<label for='time'>Time:</label>" +
    "<input name='time' type='text' value='%s'><br>\n" +

    "<label for='body'>Body:</label>" +
    "<textarea class='body' name='body'>%s</textarea>\n" +

    "</fieldset>\n" +
    "<fieldset><legend>Attachments</legend>\n%s</fieldset>\n" +
    "<fieldset><legend>Tags</legend>\n%s</fieldset>\n" +

    "<input type='submit' name='save' value='Save Changes'>\n" +
    "</div></form>\n"

  EditFilePre = 
    "<table class='edit_file'>\n" +
    "<tr><th>Name</th><th>Upload/Replace</th></tr>\n"

  EditFileEach =
    "<tr><td><input name='attname%d' type='text' value='%s'>" +
    "<input name='attnumb%d' type='hidden' value='%d'></td>" +
    "<td><input name='attfile%d' type='file'></td></tr>\n"

  EditFileCnt =
    "</table>\n<input name='attcnt' type='hidden' value='%d'>\n"

  EditTagOld =
    "<input name='tag%d' type='text' value='%s'><br>\n"

  EditTagNew =
    "<input name='tag%d' type='text'><br>\n"

  EditTagSel =
    "%s: <select name='tag%d'>" +
    "<option value='' selected></option>%s</select><br>\n"

  EditTagOpt =
    "<option value='%s: %s'>%s</option>"

  EditTagCnt = 
    "<input name='tagcnt' type='hidden' value='%d'>\n"

  #####################################
  # Get edit form
  def _get_edit(env, path)
    _navbar_jacket(env, 'Edit')

    tr = _trans(env)

    if path.empty?
      enum = 0
      rnum = 0
      ent = Entry.new
      ent.title = 'Title'
      ent.body = 'Body'
      ent.time = Time.now
    else
      enum = path.shift.to_i
      return if enum == 0 || !path.empty?
      ent = env['sgfa.binder'].read_entry(tr, enum)
      rnum = ent.revision
    end

    lst = env['sgfa.binder'].read_list(tr)
    prefix = {}
    lst.each do |tag|
      idx = tag.index(':')
      next unless idx
      pre = tag[0,idx].strip
      post = tag[idx+1..-1].strip
      if prefix[pre]
        prefix[pre].push post
      else
        prefix[pre] = [post]
      end
    end

    tags = ''
    cnt = 0
    ent.tags.sort.each do |tag|
      tags << EditTagOld % [cnt, _escape_html(tag)]
      cnt += 1
    end
    prefix.keys.sort.each do |pre|
      lst = prefix[pre]
      px = _escape_html(pre)
      opts = ''
      lst.sort.each do |post|
        ex = _escape_html(post)
        opts << EditTagOpt % [px, ex, ex]
      end
      tags << EditTagSel % [px, cnt, opts]
      cnt += 1
    end
    5.times do |tg|
      tags << EditTagNew % cnt
      cnt += 1
    end
    tags << EditTagCnt % cnt

    atts = "Attachments go here\n"
    atts = EditFilePre.dup
    cnt = 0
    ent.attachments.each do |anum, hnum, name|
      atts << EditFileEach % [cnt, _escape_html(name), cnt, anum, cnt]
      cnt += 1
    end
    5.times do |ix|
      atts << EditFileEach % [cnt, '', cnt, 0, cnt]
      cnt += 1
    end
    atts << EditFileCnt % cnt

    html = EditForm % [
      env['SCRIPT_NAME'], env['sgfa.jacket.url'], enum, rnum, 
      _escape_html(ent.title), ent.time.localtime.strftime('%F %T %z'),
      _escape_html(ent.body), atts, tags,
    ]
    
    env['sgfa.status'] = :ok
    env['sgfa.html'] = html
  end # def _get_edit
 
  JacketPost = [
    'entry',
    'revision',
    'time',
    'tagcnt',
    'attcnt',
  ]

  #####################################
  # Handle jacket post
  def _post_jacket(env)
    _navbar_jacket(env, 'Edit')

    rck = Rack::Request.new(env)
    params = rck.POST

    # validate fields present
    JacketPost.each do |fn|
      next if params[fn]
      raise Error::Limits, 'Bad form submission'
    end
    tagcnt = params['tagcnt'].to_i
    attcnt = params['attcnt'].to_i
    tagcnt.times do |ix|
      next if params['tag%d' % ix]
      raise Error::Limits, 'Bad form submission'
    end
    attcnt.times do |ix|
      next if params['attnumb%d' % ix]
      raise Error::Limits, 'Bad form submission'
    end
    
    # get the entry being edited
    enum = params['entry'].to_i
    rnum = params['revision'].to_i
    tr = _trans(env)
    if enum != 0
      ent = env['sgfa.binder'].read_entry(tr, enum, rnum)
    else
      ent = Entry.new
    end

    # tags
    oldt = ent.tags
    newt = []
    tagcnt.times do |ix|
      tx = 'tag%d' % ix
      if !params[tx].empty?
        newt.push params[tx]
      end
    end

    # attachments
    attcnt.times do |ix|
      anum = params['attnumb%d' % ix].to_i
      name = params['attname%d' % ix]
      file = params['attfile%d' % ix]

      # copy uploaded file
      if file && file != ''
        ftmp = env['sgfa.binder'].temp
        IO::copy_stream(file[:tempfile], ftmp)
        file[:tempfile].close!
      else
        ftmp = nil
      end

      # new file
      if anum == 0
        next if !ftmp
        name = file[:filename] if name == ''
        ent.attach(name, ftmp)
        
      # old file
      else
        ent.rename(anum, name) if name != ''
        ent.replace(anum, ftmp) if ftmp
      end     

    end

    # general
    ent.title = params['title']
    ent.body = params['body']
    begin
      time = Time.parse(params['time'])
      ent.time = time
    rescue ArgumentError
    end
    oldt.each{|tag| ent.untag(tag) if !newt.include?(tag) }
    newt.each{|tag| ent.tag(tag) if !oldt.include?(tag) }
    env['sgfa.binder'].write(tr, [ent])

    env['sgfa.status'] = :ok
    env['sgfa.message'] = 'Entry edited.'
    env['sgfa.html'] = _disp_entry(env, ent)

  end # def _post_jacket()
  
  
  #####################################
  # Handle binder post
  def _post_binder(env)
    _navbar_binder(env, 'Edit')

    rck = Rack::Request.new(env)
    params = rck.POST

    tr = _trans(env)
    tr[:title] = 'Test title'
    tr[:body] = 'Test description of action'

    bnd = env['sgfa.binder']

    # jacket
    if params['create']
      _navbar_binder(env, 'Jackets')
      ['jacket', 'newname', 'title', 'perms'].each do |fn|
        next if params[fn]
        raise Error::Limits, 'Bad form submission'
      end
      perms = params['perms'].split(',').map{|it| it.strip }
      title = params['title']
      newname = params['newname']
      jacket = params['jacket']
      tr[:jacket] = jacket

      info = bnd.binder_info(tr)
      oj = info[:jackets][jacket]
      if oj
        newname ||= jacket
        title = oj['title'] if title.empty?
        jck = bnd.jacket_edit(tr, newname, title, perms)
        env['sgfa.message'] = 'Jacket edited.'
      else
        jck = bnd.jacket_create(tr, title, perms)
        env['sgfa.message'] = 'Jacket created.'
      end
      env['sgfa.status'] = :ok
      env['sgfa.html'] = _disp_jackets(env, jck, tr)

    # user
    elsif params['set']
      _navbar_binder(env, 'Users')
      ['user', 'perms'].each do |fn|
        next if params[fn]
        raise Error::Limits, 'Bad form submission'
      end
      perms = params['perms'].split(',').map{|it| it.strip }
      users = bnd.binder_user(tr, params['user'], perms)
      env['sgfa.status']  = :ok
      env['sgfa.message'] = 'User edited.'
      env['sgfa.html'] = _disp_users(env, users, tr)

    # binder
    elsif params['assign']
      _navbar_binder(env, 'Values')
      ['value', 'state'].each do |fn|
        next if params[fn]
        raise Error::Limits, 'Bad form submission'
      end
      vals = { params['value'] => params['state'] }
      values = bnd.binder_values(tr, vals)
      env['sgfa.status'] = :ok
      env['sgfa.message'] = 'Values assigned.'
      env['sgfa.html'] = _disp_values(env, values, tr)

    end

  end # def _post_binder()

end # class Binder

end # module Web
end # module Sgfa
