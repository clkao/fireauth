require! <[express request pg firebase qs]>

{FIREBASE, FIREBASE_SECRET, AUTHZ_URL} = process.env
root = new firebase FIREBASE

pg-client = new require \pg .native.Client 'tcp://lf_g0v:lqg0v@localhost/lf_g0v'

err <- pg-client.connect
throw err if err
err, {rows}? <- pg-client.query "SELECT id, name from unit";
console.log rows

err <- root.auth FIREBASE_SECRET
throw err if err

app = express!
app.use express.cookieParser!

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

session-map = {}

app.get '/g0v/auth/:request' (req, res) ->
    session = req.cookies.liquid_feedback_session
    return res.send 401 \bye unless session and session-map[req.params.request]
    delete session-map[req.params.request]
    request = root.child "authz/#{ req.params.request }"
    <- request.on \value
    info = it.val!
    unless info
        request.off \value
        return res.send 401 \bye
    return unless info?username
    request.off \value
    request.remove!
    console.log info
    member_id, isnew, lang <- ensure-member info
    err, r <- pg-client.query "insert into privilege (select unit_id, $1, 't', 't' from unit as t(unit_id, member_id)  where name in ('Public', 'g0v.tw'))" [member_id]

    err, r <- pg-client.query "UPDATE session SET member_id = $1 WHERE ident = $2", [member_id, session]
    if lang
        pg-client.query "UPDATE session SET lang = $1 WHERE ident = $2", [lang, session] ->
    err, r <- pg-client.query "UPDATE member SET last_login = NOW(), last_activity = NOW(), active = 't' WHERE id = $1", [member_id]
    console.log r
    console.log err if err

    request = require \request
    console.log \setupep
    uri = 'http://localhost:9001/api/1/createAuthorIfNotExistsFor?'
    uri += qs.stringify do
      apikey: 'QZ0jk5eLvelQxGpCbejzpZ6QuxcJrh7p'
      name: info.displayName
      authorMapper: member_id
    console.log uri
    err, response, body <- request.get uri

    console.log body, author
    author = try JSON.parse body

    uri = 'http://localhost:9001/api/1/createSession?'
    uri += qs.stringify do
      apikey: 'QZ0jk5eLvelQxGpCbejzpZ6QuxcJrh7p'
      groupID: 'g.WAxOOPAIpMS0Da8j'
      authorID: author.data.authorID
      validUntil: parseInt(new Date!getTime!/1000 + 24 * 60 * 60)
    err, response, body <- request.get uri
    session = try JSON.parse body
    console.log session

    res.setHeader \Set-Cookie "sessionID=#{session.data.sessionID}; Path=/"

    return res.redirect if isnew
        'http://lqfb-test.g0v.tw/g0v/member/edit.html'
    else
        'http://lqfb-test.g0v.tw/g0v/'

app.get '/g0v/auth' (req, res) ->
    session = req.cookies.liquid_feedback_session
    return res.send 401 \bye unless session
    z = root.child 'authz' .push()
    z.set req: \user, uri: \http://lqfb-test.g0v.tw/g0v/auth

    session-map[ z.name! ] = session
    res.redirect "#AUTHZ_URL/#{ z.name! }"
    cleanup = setTimeout (-> z.off \value; z.remove!), 30s * 1000ms
    z.on \value ->
        if it.val! is null
            clearTimeout cleanup

app.listen 8090
