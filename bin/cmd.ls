require! <[optimist firebase express]>

config = require \../config.json

port = optimist.argv.port ? config.port ? process.env.PORT
prefix = optimist.argv.prefix ? config.prefix ? process.env.PREFIX
module = optimist.argv.module or throw 'module required'

m = require "../lib/#module"

auth <- m.authenticate config[module]

root = new firebase config.firebase.url
err <- root.auth config.firebase.secret
throw err if err

app = express!
app.use express.cookieParser!

session-map = {}

app.get "/#{prefix}/auth/:request" (req, res) ->
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

    auth.auth info, session, req, res

app.get "/#{prefix}/auth" (req, res) ->
    session = req.cookies.liquid_feedback_session
    return res.send 401 \bye unless session
    z = root.child 'authz' .push()
    z.set req: \user, uri: config[module].auth_url + "/auth"

    session-map[ z.name! ] = session
    res.redirect "#{ config.authz_url }/#{ z.name! }"
    cleanup = setTimeout (-> z.off \value; z.remove!), 30s * 1000ms
    z.on \value ->
        if it.val! is null
            clearTimeout cleanup

app.listen PORT ? 8090
