var qs, q, out$ = typeof exports != 'undefined' && exports || this;
qs = require('qs');
q = function(it){
  return "'" + (it + "").replace(/'/g, "''") + "'";
};
out$.authenticate = authenticate;
function authenticate(config, cb){
  var pgClient;
  pgClient = new require('pg').native.Client(config.db);
  return pgClient.connect(function(err){
    if (err) {
      throw err;
    }
    return pgClient.query("SELECT id, name from unit", function(err, arg$){
      var rows, ensureMember, ensureAvatar, ensureEtherpad;
      if (arg$ != null) {
        rows = arg$.rows;
      }
      ensureMember = function(info, cb){
        return pgClient.query("SELECT id, lang from member where login = $1", [info.username], function(err, arg$){
          var rows;
          if (arg$ != null) {
            rows = arg$.rows;
          }
          if (rows.length) {
            return cb(rows[0].id, false, rows[0].lang);
          } else {
            return pgClient.query("insert into member (login, name, notify_email, email, active, last_activity, activated) values($1, $2, $3, $3, 'f', NOW(), NOW()) RETURNING id", [info['username'], info['displayName'], info['email']], function(err, r){
              if (err) {
                console.log(err);
              }
              console.log(r);
              return cb(r.rows[0].id, true);
            });
          }
        });
      };
      ensureAvatar = function(member_id, avatar, cb){
        return pgClient.query("SELECT count(*) as count from member_image where image_type = 'avatar' and member_id = $1", [member_id], function(err, arg$){
          var rows, ref$;
          if (arg$ != null) {
            rows = arg$.rows;
          }
          if (err) {
            console.log(err);
          }
          if (rows != null && ((ref$ = rows[0]) != null && ref$.count)) {
            return cb();
          }
          return pgClient.query("insert into member_image (member_id , image_type, scaled  , content_type , data   ) values ($1, 'avatar', 't', 'text/x-url', $2)", [member_id, avatar], function(err, r){
            if (err) {
              console.log(err);
            }
            return cb();
          });
        });
      };
      ensureEtherpad = function(member_id, info, res, cb){
        var request, uri;
        request = require('request');
        if (!config.etherpad) {
          return cb();
        }
        uri = config.etherpad.url + "/api/1/createAuthorIfNotExistsFor?";
        uri += qs.stringify({
          apikey: config.etherpad.apikey,
          name: info.displayName,
          authorMapper: member_id
        });
        return request.get(uri, function(err, response, body){
          var author, uri;
          console.log(body, author);
          author = (function(){
            try {
              return JSON.parse(body);
            } catch (e$) {}
          }());
          uri = config.etherpad.url + "/api/1/createSession?";
          uri += qs.stringify({
            apikey: config.etherpad.apikey,
            groupID: config.etherpad.group,
            authorID: author.data.authorID,
            validUntil: parseInt(new Date().getTime() / 1000 + 24 * 60 * 60)
          });
          return request.get(uri, function(err, response, body){
            var session;
            session = (function(){
              try {
                return JSON.parse(body);
              } catch (e$) {}
            }());
            console.log(session);
            res.setHeader('Set-Cookie', "sessionID=" + session.data.sessionID + "; Path=/");
            return cb();
          });
        });
      };
      return cb({
        auth: function(info, session, req, res){
          return ensureMember(info, function(member_id, isnew, lang){
            var that, groups, contact;
            if (that = config.default_units) {
              groups = that.map(q);
              pgClient.query("INSERT into privilege\n  (select unit_id, $1, 't', 't' from unit AS t(unit_id, member_id) WHERE\n    name IN (" + groups.join(',') + ") AND name NOT IN\n      (SELECT name FROM unit JOIN privilege ON( unit_id = unit.id) WHERE\n       member_id = $1))", [member_id], function(err, r){
                if (err) {
                  return console.log(err);
                }
              });
            }
            if (that = info.following) {
              contact = that.map(function(it){
                return "'" + it + "'";
              });
              pgClient.query("insert into contact (member_id, other_member_id, public) select $1, member_id,   't' from member as t(member_id, other_member_id, public) where login in (" + contact.join(',') + ") and member_id not in (select other_member_id from contact where member_id = $1)", [member_id], function(err, r){
                if (err) {
                  return console.log(err);
                }
              });
            }
            return pgClient.query("UPDATE session SET member_id = $1 WHERE ident = $2", [member_id, session], function(err, r){
              if (lang) {
                pgClient.query("UPDATE session SET lang = $1 WHERE ident = $2", [lang, session], function(){});
              }
              return pgClient.query("UPDATE member SET last_login = NOW(), last_activity = NOW(), active = 't' WHERE id = $1", [member_id], function(err, r){
                if (err) {
                  console.log(err);
                }
                return ensureAvatar(member_id, info.avatar, function(){
                  return ensureEtherpad(member_id, info, res, function(){
                    return res.redirect(isnew
                      ? config.url + "/member/edit.html"
                      : config.url + '/');
                  });
                });
              });
            });
          });
        }
      });
    });
  });
}