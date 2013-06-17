fireauth
========

Use firebase authentication as your SSO source.

*Warning: WIP* This was written to simplify login process for liquid feedback, using a user system built with firebase.  This can probably be generalized for other applications that want to use firebase as SSO source.

Flow:

* When a service wants to authentication users, push an item to /authz in firebase, and redirect to authz_url with the new entry's id as token.  the entry should contain return url and other request meta data
* If the user authorizes the request, it updates the /authz/:token entry with login name.  firebase security rules should be carefully written to ensure the user can claims login name / auth info to be written.
* Once auth info is written to /authz/:token, it should no longer be readable.
* the user is then redirected back to the service's return url specified in the original request.
* the url is processed by fireauth, session is authenticated and/or new user is created, then redirected to the

Todo:

* currently service needs full firebase access.  we can maintain an app collection and add rules to allow apps writing authz requests with appkey granted.
* make this a middleware
* [lqfb] the authz entry should only contain info that can be confirmed by security rules.  things like friends etc should be extracted by the auth client from firebase, rather than pulled from the authz response.

## liquid feedback module

Currently requires secret key access to the firebase instance

In your nginx.conf:

    location /lf/auth {
        proxy_pass  http://127.0.0.1:8090;
        proxy_set_header Host $host;
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
    }

Configure config.json and run:

    % lsc bin/cmd.ls  --module lqfb --port 8090

License: MIT
