date: 2013-03-09 22:10:00 +0100
title: What's new in Sinatra 1.4?

<figure class="small right first">
  ![](https://raw.github.com/sinatra/resources/master/logo/come-fly-with-me-500.png)
</figure>

I'm about to release Sinatra 1.4.0.

A few house-keeping jobs are still outstanding, like bringing the website up to speed and running it on a few more apps in production (though we've been running it in production for [Travis CI](https://travis-ci.org) for quite a while without issues) and then we're good to go.

If you want to give it a try right now, you can install the prerelease via `gem install sinatra --pre`. For more infos, check out [*The Bleeding Edge*](https://github.com/sinatra/sinatra#the-bleeding-edge) from the official Sinatra documentation.

Sinatra follows [Semantic Versioning](http://semver.org/), meaning that this is the first release bringing new features since 1.3.0, released in 2011. Let's take a look at these new features.

### New HTTP Methods

With 1.3.0, we added support for `PATCH`. 1.4.0 will include `LINK` and `UNLINK`.

Like `PATCH`, they were originally included in [RFC 2068](http://tools.ietf.org/html/rfc2068) and have now been [proposed again](http://tools.ietf.org/html/draft-snell-link-method-00).

    link '/resource/:id' do |id|
      resource = Resource.find(id)
      resource.links << env['X_LINK']
      resource.save

      "link established"
    end
    
    unlink '/resource/:id' do |id|
      resource = Resource.find(id)
      resource.links.delete env['X_LINK']
      resource.save

      "link removed"
    end

See [RFC 5988](http://tools.ietf.org/html/rfc5988) for more infos on resource linking.

### Template Updates

This release adds support for [Yajl](https://github.com/sinatra/sinatra#yajl-templates), [Rabl](https://github.com/nesquena/rabl#readme), [Wlang](http://blambeau.github.com/wlang/) and [Stylus](http://learnboost.github.com/stylus/) templates.

    get '/style.css' do
      stylus :style
    end

    get '/list.json' do
      yajl :list
    end

Moreover, ERb, Haml, Slim, Liquid and Wlang templates can now be nested using blocks:

    get '/' do
      slim(:outer) { slim :inner }
    end
    
    __END__
    
    @@ outer
    html
      body
        == yield
    
    @@ inner
    p Hello World

You can now configure the default layout on a per engine basis, and passing in `nil` as layout is now treated the same as passing in `false` rather than using the default layout. Also, we've solved a caching issue when using multiple view directories.

### Play Nice in Classic Mode

Up until this release, using Sinatra in [classic mode](https://github.com/sinatra/sinatra#modular-vs-classic-style) would add certain private methods to `Object`:

    require 'sinatra'

    ["some_object"].instance_eval do
      get '/example' do
        "this works in Sinatra 1.3"
      end
    end

The above example will now raise a `NameError`.

This is important for objects implementing `method_missing` without implementing a corresponding `respond_to?`.

In 1.4, instead of including `Sinatra::Delegator` in `Object`, it will only extend the `main` object.

### Better Routes Parsing

1.4 has a more robust route parsing. For instance, given the following code:

    get '/:name.?:format?' do |name|
      name
    end

Running the above with Sinatra 1.3 and requesting `/foo.bar` will return `foo.bar`, on 1.4 it will now return `foo`.

Plus signs in the URL (not in query params) will now once again be matched as plus signs, not as spaces.

### Mime-Type Parameters

The `request` object now exposes Mime-Type parameters when parsing the `Accept` header:

    get '/', provides: :jpeg do
      compression = request.preferred_type('image/jpeg').
                      params['compress']
      generate_image(compression)
    end

The above example will take the `compress` parameter into account, including multiple entries with weight:

    $ curl -H 'Accept: image/jpeg; compress=0.25; q=0.1,
        image/jpeg; compress=0.5; q=0.8' http://localhost:4567

### New Servers

<figure class="small right first">
  ![](http://puma.io/images/logos/downloads/standard-logo.png)
</figure>

In addition to [WebRick](http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick.html), [Thin](http://code.macournoyer.com/thin/) or [Mongrel](http://rubyforge.org/projects/mongrel/), Sinatra will now automatically pick up [Puma](http://puma.io/), [Trinidad](https://github.com/trinidad/trinidad#readme), [ControlTower](https://github.com/MacRuby/ControlTower#readme) or [Net HTTP Server](https://github.com/postmodern/net-http-server#readme) when installed. The logic for picking the server has been improved and now depends on the Ruby implementation used.

### Other Changes

* Exception handling has been improved a lot.
* The `register` method (for registering extensions) is now also delegated in *classic* mode.
* You can now `redirect` to `URI` and `Addressable::URI` instances.
* Generated `Content-Disposition` values now include the file name even for `inline`, not just `attachment`.
* You can now pass a `status` option to `send_file` for setting the status code.
* The `provides` condition now honors an already set `Content-Type` (for instance, in a `before filter`).
* Status, headers and body will be set before running after filters. This is very useful if your after filter is modifying the body.
* When calling `new` on your modular application (or `Sinatra::Application`), it will now return a wrapper object that exposes a few methods, like `settings`, instead of the middleware stack directly.
* Sinatra will now respect the `$PORT` environment variable, which is for instance set by [Heroku](http://www.heroku.com/).
* Improved compatibility with Rack 1.5, RDoc 4.0 and RubyGems 2.0.
* By default, Sinatra will now only serve `localhost` in development mode. You should not be running your production system in development mode.
* The documentation has been largely improved and converted from RDoc to Markdown.
* The [chat example](https://github.com/sinatra/sinatra/blob/master/examples/chat.rb) has been fixed to work with the latest jQuery.

### New Configuration Options

* The `protection` setting now takes a `session` option to explicitly enable/disable session based protection modes. This is useful if you set up a custom session implementation, which Sinatra will otherwise miss.

* You can now `disable :x_cascade` to avoid sending the `X-Cascade: pass` header if no route matches.

### What's next?

Currently there are three fully maintained branches in the Sinatra repository: master is where the main development is happening, but both 1.2.x and 1.3.x currently receive bug fixes and improvements. With the release of 1.4.0, this will change.

From that point on, 1.3.x will only receive major bug fixes and security fixes, no more general improvements, unless they can easily be backported from 1.4.

The 1.2.x branch (which is the branch for Ruby 1.8.6 compatibility) will be discontinued. This includes security fixes. You are very much urged to upgrade if you are still running on Sinatra 1.2.

Once the first new feature makes it into master, it will move on to 1.5 and I will create a 1.4.x branch. However, there is currently no roadmap whatsoever for a 1.5 release.

I do have some plans for Sinatra 2.0, though. I have had the urge to rewrite large parts of Sinatra for a while and I have a few prototypes lying around. Goal is to end up with a simpler, more flexible and performant code base. It will fully leverage the new [Rack stream hijacking](https://github.com/rack/rack/pull/481) or the Rack successor (Rack 2.0, Ponies or whatever it will be called) should we have one by then.

It will probably be Ruby 2.0 only. Before you freak out: It's still a long way until then, there won't be a release any time soon and even once there is a release, there will be a maintained 1.x branch at least until Sinatra 2.1 has been released.
