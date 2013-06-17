var optimist, firebase, express, config, port, ref$, prefix, module, m;
optimist = require('optimist');
firebase = require('firebase');
express = require('express');
config = require('../config.json');
port = (ref$ = optimist.argv.port) != null
  ? ref$
  : (ref$ = config.port) != null
    ? ref$
    : process.env.PORT;
prefix = (ref$ = optimist.argv.prefix) != null
  ? ref$
  : (ref$ = config.prefix) != null
    ? ref$
    : process.env.PREFIX;
module = optimist.argv.module || (function(){
  throw 'module required';
}());
m = require("../lib/" + module);
m.authenticate(config[module], function(auth){
  var root;
  root = new firebase(config.firebase.url);
  return root.auth(config.firebase.secret, function(err){
    var app, sessionMap;
    if (err) {
      throw err;
    }
    app = express();
    app.use(express.cookieParser());
    sessionMap = {};
    app.get("/" + prefix + "/auth/:request", function(req, res){
      var session, request;
      session = req.cookies.liquid_feedback_session;
      if (!(session && sessionMap[req.params.request])) {
        return res.send(401, 'bye');
      }
      delete sessionMap[req.params.request];
      request = root.child("authz/" + req.params.request);
      return request.on('value', function(it){
        var info;
        info = it.val();
        if (!info) {
          request.off('value');
          return res.send(401, 'bye');
        }
        if (!(info != null && info.username)) {
          return;
        }
        request.off('value');
        request.remove();
        return auth.auth(info, session, req, res);
      });
    });
    app.get("/" + prefix + "/auth", function(req, res){
      var session, z, cleanup;
      session = req.cookies.liquid_feedback_session;
      if (!session) {
        return res.send(401, 'bye');
      }
      z = root.child('authz').push();
      z.set({
        req: 'user',
        uri: config[module].auth_url
      });
      sessionMap[z.name()] = session;
      res.redirect(config.authz_url + "/" + z.name());
      cleanup = setTimeout(function(){
        z.off('value');
        return z.remove();
      }, 30 * 1000);
      return z.on('value', function(it){
        if (it.val() === null) {
          return clearTimeout(cleanup);
        }
      });
    });
    return app.listen(port);
  });
});