require! qs

q = -> """
  '#{ "#it".replace /'/g "''" }'
"""

export function authenticate(config, cb)
  pg-client = new require \pg .native.Client config.db
  err <- pg-client.connect
  throw err if err
  err, {rows}? <- pg-client.query "SELECT id, name from unit";

  ensure-member = (info, cb) ->
    err, {rows}? <- pg-client.query "SELECT id, lang from member where login = $1", [info.username]
    if rows.length
      cb rows.0.id, false, rows.0.lang
    else
      err, r <- pg-client.query """
      insert into member (login, name, notify_email, email, active, last_activity, activated) values($1, $2, $3, $3, 'f', NOW(), NOW()) RETURNING id
      """ info<[username displayName email]>
      console.log err if err
      console.log r
      cb r.rows.0.id, true

  ensure-avatar = (member_id, avatar, cb) ->
    err, {rows}? <- pg-client.query "SELECT count(*) as count from member_image where image_type = 'avatar' and member_id = $1" [member_id]
    console.log err if err
    return cb! if rows?0?count

    err, r <- pg-client.query "insert into member_image (member_id , image_type, scaled  , content_type , data   ) values ($1, 'avatar', 't', 'text/x-url', $2)" [member_id, avatar]
    console.log err if err
    cb!
  ensure-etherpad = (member_id, info, res, cb) ->
    request = require \request
    return cb! unless config.etherpad
    uri = "#{config.etherpad.url}/api/1/createAuthorIfNotExistsFor?"
    uri += qs.stringify do
      apikey: config.etherpad.apikey
      name: info.displayName
      authorMapper: member_id
    err, response, body <- request.get uri

    console.log body, author
    author = try JSON.parse body

    uri = "#{config.etherpad.url}/api/1/createSession?"
    uri += qs.stringify do
      apikey: config.etherpad.apikey
      groupID: config.etherpad.group
      authorID: author.data.authorID
      validUntil: parseInt(new Date!getTime!/1000 + 24 * 60 * 60)
    err, response, body <- request.get uri
    session = try JSON.parse body
    console.log session

    res.setHeader \Set-Cookie "sessionID=#{session.data.sessionID}; Path=/"
    cb!

  cb do
    auth: (info, session, req, res) ->
      member_id, isnew, lang <- ensure-member info
      if config.default_units
        groups = that.map q
        err, r <- pg-client.query """
          INSERT into privilege
            (select unit_id, $1, 't', 't' from unit AS t(unit_id, member_id) WHERE
              name IN (#{groups.join \,}) AND name NOT IN
                (SELECT name FROM unit JOIN privilege ON( unit_id = unit.id) WHERE
                 member_id = $1))
        """ [member_id]
        console.log err if err
      if info.following
        contact = that.map -> "'#it'"
        err, r <- pg-client.query "insert into contact (member_id, other_member_id, public) select $1, member_id,   't' from member as t(member_id, other_member_id, public) where login in (#{contact.join \,}) and member_id not in (select other_member_id from contact where member_id = $1)", [member_id]
        console.log err if err

      err, r <- pg-client.query "UPDATE session SET member_id = $1 WHERE ident = $2", [member_id, session]

      if lang
          pg-client.query "UPDATE session SET lang = $1 WHERE ident = $2", [lang, session] ->
      err, r <- pg-client.query "UPDATE member SET last_login = NOW(), last_activity = NOW(), active = 't' WHERE id = $1", [member_id]
      console.log err if err

      <- ensure-avatar member_id, info.avatar
      <- ensure-etherpad member_id, info, res

      return res.redirect if isnew
        "#{config.url}/member/edit.html"
      else
        config.url + '/'

