date: 2010-08-30 19:06:04
title: Reloading Ruby Code

As the core of my [Ruby Summer Of Code](http://www.rubysoc.org) project, I have partly rewritten `ActiveSupport::Dependencies`. I will give an introduction to common reloading strategies and their implementation and discuss my changes to `Dependencies`. Even though this part of ActiveSupport is hidden away and not well known, all Rails developers rely on its proper functioning, as it is responsible for autoloading and reloading Ruby code. It is also responsible for producing error messages like "A copy of Something has been removed from the module tree but is still active!" or "Object is not missing constant Something!". But before focusing on `Dependencies`, let's talk about the topic in general.

In this article I will focus on reloading code, since autoloading code is rather simple: You define a `const_missing` hook, which is triggered whenever an undefined constant is used. Map the constant name to a path (with `Dependencies`, `Foo::BarBlah` will be mapped to `foo/bar_blah`) and search for that file inside a list of directories, in that case `Dependencies.autoload_paths` and, for files that should be autoloaded but not reloaded, `Dependencies.autoload_once_paths`. Some other implementations use Ruby's `$LOAD_PATHS`, which has the advantage of simply trying to `require 'foo/bar_blah'` instead of having to search for a matching file by hand. That way autoloading constants from gems or other formats (i.e. `foo.so` instead of `foo.rb`) just works. On the other hand this may easily lead to loading other files than intended and reloading files that should not be reloaded.

[simple\_autoloader.rb](http://gist.github.com/533770)

You might have already noticed that such an autoloading approach is working on two different levels: Constants and files. The artificial mapping from constants to files is present in most Ruby project, but it is not a low-level Ruby feature. Neither is code reloading. However, especially in Rails-land, reloading is assumed to just work. That is impossible by design. But there are a couple of different approaches trying to get you as close as possible. The key design decisions are *when* to reload *what* code and *how* to do that. Of these decisions, when to reload is the easiest one, as it does not bring any implications for the code that is reloaded. The reloader can be triggered on any file changes or on specified points/events in your program flow, or a combination of the two. In a web app, you probably only want to reload code on a new request. What code you should reload heavily depends on how you are reloading code.

In the following I will mainly focus on reloading [Rack](http://rack.rubyforge.org/) applications. I will avoid going into how Rack works. I don't think you have to understand every juicy detail, but if you have no clue what Rack does, now would be a good time to check it out. A lot of the strategies and libraries described here should also be usable for other applications. However, if you're level of interest in Ruby and Rails has brought you as far as this blog post, you *really* should get to know Rack.

## Abusing Open Classes

[open\_class.rb](http://gist.github.com/544919)

The concept of Ruby's [open classes](http://rubylearning.com/satishtalim/ruby_open_classes.html) is demonstrated in the above example. You might already know this technique, especially either from [monkey-patching](http://www.infoq.com/articles/ruby-open-classes-monkeypatching) other modules/classes or from using modules as [namespaces](http://ruby-doc.org/docs/ProgrammingRuby/html/tut_modules.html). It can also be used for reloading. About anything that can be defined in Ruby, can also be redefined at runtime.

Imagine you have a Rack application called `Foo` in `foo.rb`. If you load `foo.rb` twice, then the definition of `Foo` monkey-patches itself. If one method was changed in-between the first and the second loading of `foo.rb`, the second version will override the first. If a method did not change, it will be overridden with an unchanged version, which is about the same as not overriding it. Well, except for the fact that it will invalidate any method caches and revert any inlining which might have occurred thus far. But the method's implementation will remain the same. This is not only extremely simple, but as it turns out also rather fast. If you want to reload `foo.rb` on every request you could set up a simple middleware for that:

[reload\_foo.ru](http://gist.github.com/544921)

However, this is not `require`-friendly. Even if `foo.rb` requires `bar.rb`, only `foo.rb` will be reloaded. One solution would be to use `load` instead of `require`. However, we want to keep the reloader as invisible as possible. Moreover, this would make reloading `bar` only if it changed impossible, as it will be reloaded whenever `foo` is reloaded. One option we could use for now is to remove `bar` from `$LOADED_FEATURES`. That way `require 'bar'` would load it again. But now `bar` will not be reloaded unless `foo` is reloaded. A better way would be to actively reload `bar`. The example below reloads any files that where loaded and have changed. We can use `mtime` for checking if I file changed

[reload\_world.ru](http://gist.github.com/549533)

Note however, that this really includes *any* files that have been loaded, even if those are in a gem or the standard library. However, those files usually do not change. Still, this approach might not be useful for bigger apps, as there are files you might not want to reload even if they changed (think initializers). In case this approach is exactly what you want, there is a Rack middleware doing exactly this: [Rack::Reloader](http://github.com/rack/rack/blob/master/lib/rack/reloader.rb). Not only does it also include error handling and has some nifty features like the ability to set a cool down phase, you probably have it already installed, as it ships with Rack. Combine it with the autoloader code from above and you got Dependencies Lite™.

For smaller or well written applications this will work perfectly fine, but you will not be able to use it for a Rails or even a Sinatra app. First, instance and class variables don't get invalidated:

[old\_vars.rb](http://gist.github.com/549586)

The body gets reevaluated:

[double\_alias.rb](http://gist.github.com/549586)

Inheritance cannot be changed:

[superclass\_mismatch.rb](http://gist.github.com/549586)

Methods and constants cannot be removed (at least not by removing them):

[remove_method.rb](http://gist.github.com/549586)

While the last one is usually not a big issue, the other two make it unusable for Rails. Sinatra will keep the old routes and append the modified ones on a reload. To solve this, you can call `Sinatra::Application.reset!`. This will only work if you always reload all files. If you want to have partial reloading, try [Sinatra::Reloader](http://github.com/rkh/sinatra-reloader). But still, for your own code you should be aware of these issues. A rule of thumb: Using open classes should work just fine if you are willing to manually restart your application in case one of the above issues should occur and if you favor inheritance and mixins over `alias_method_chain`, write your files so that executing them twice does not do any harm and you avoid black magic. You probably don't if you are developing a Rails app. You probably do if you are developing a Sinatra or Rack app.

## Actually restarting your application

OK, so apparently relying on open classes is not usable without constrains. One solution that should work without restrictions would be to actually restart the application instead of reloading just some files. Think about it: It's what you would probably do manually if you're application has no reloading baked in. The implementations usually rely on [fork](http://www.kernel.org/doc/man-pages/online/pages/man2/fork.2.html). The strategy is simple: Load everything that should not be reloaded, fork and load everything that should be reloaded. Answer requests from that fork. For reloading: Kill the fork, fork away and again, load everything that should be reloaded. The main issue is watching for changes.

As reloading is triggered from the outside, you have no clue what files are loaded. One strategy would be to again simply reload on every request. [Shotgun](http://github.com/rtomayko/shotgun) does this. Another option would be to simply watch the current directory for any changes. A general purpose implementation would be [rerun](http://github.com/alexch/rerun). Since rerun is intended to be usable with any application, not just Rack apps, it does lack the preloading feature. Therefor reloading probably occurs a lot less than with shotgun, but takes longer.

My favorite implementation of this strategy is ["Magical Reloading Sparkles"](http://namelessjon.posterous.com/magical-reloading-sparkles) by Jonathan D. Stott (aka namelessjon). Unicorn has a signal-based redeployment mechanism. Jonathan's code will trigger it on any code change and cause unicorn to kill and refork all workers. In contrast to shotgun it is also easily possible to specify exactly which code should be preloaded.

So, why not use this approach? As it does a lot more work under the hood (besides reloading more code than the other approaches, it also fires a new system process) and eats more resources, it is generally slower. I would still recommend it for complex applications, if it only reloads on changes or for really small apps that fire up instantly. Under no circumstances would I recommend using shotgun for a Rails app, but for small Sinatra apps it should be acceptably fast. The main issue, however, is portability: Unix forking is not available on Windows nor JRuby, neither is Unicorn. Offering it as default strategy for Rails would limit official support to Unix and MRI. Note that it [would probably be possible](http://github.com/rtomayko/shotgun/issues/closed#issue/13/comment/171837) to implement something similar for Windows.

## Replacing Constants

We can do something similar to restarting the app: Remove the old constants before reloading. That way, the old code does not survive: No old instance variables or methods lying around, aliasing works as the body will only be reloaded once per constant incarnation, and since the constant will be redefined instead of reopened on every reload, we can even change its superclass:

[remove\_const.rb](http://gist.github.com/555026)

Let's try to use that:

[remove\_const.ru](http://gist.github.com/555031)

The above gist also points to one of the main issues of this approach: Invalidating references. When using open classes, `Foo` always referenced the same object, it just evolved. Now `Foo` is a different object before and after each reload.

If you pass `Foo` to `run`, `Rack::Builder` will use the object passed, which would remain unchanged on the next reload. By wrapping it a new constant lookup will be triggered on every request and thus changes will be picked up. It gets even worse as soon as you realize that the same goes for instances:

[surviving_instances.rb](http://gist.github.com/555145)

This cannot be fixed entirely. However, it is possible to alleviate these problems.

## The Rails Way

Imagine you where able to remove everything and load all from scratch. That way no old references would survive and no constants could be kept alive. In a nutshell, this is what Rails is trying to do, except, not really. As mentioned above, reloading everything might not be what you want. You might lose state or you even might execute files twice that should not be run twice otherwise. Therefore ActiveSupports divides all constants into two groups: The part that should be reloaded and the part that should not be reloaded. As a rule of thumb the reloadable constants are your app code (models, controllers, extra, etc) and the rest is kept (lib, initializers, external dependencies, etc).

Everything works fine if you only reference reloadable constants from other reloadable constants (at least if the references would otherwise survive to the next request and would be reused). In order to achieve this, it might be necessary to add constants explicitly to the reloadable pool. This is possible by calling `Module#unloadable` on the constant. Note however that marking a constant as reloadable will essentially cause the constants' source file to be reloadable, so if it has any side-effects besides defining the constants, those will reoccur on any request.

The hard thing is to track which constants belong to what pool. ActiveSupport creates a watch stack for that. It tracks which constants are already known and is able to return a list of new constants for a block of code. It then hooks this mechanism into the autoloading code, require and load. Autoloaded constants will automatically be added to the reloadable pool. However, if the file defining the constant requires other files, ActiveSupport has to be careful to only add the autoloaded constant to the pool, not necessarily its dependencies. Another threat is accidentally loading a file twice before removing its constant, as in that case you would have the issues of the open class approach you were trying to get rid off. ActiveSupport therefore juggles with multiple lists besides the watch stack to track all files that have ever been autoloaded, all files that have been loaded since the last reload ("ActiveSupport::Dependencies.clear", btw), all automatically loaded constants since the last reload and all constants explicitly marked for reload. Also, combinations of those lists are used extensively.

ActiveSupport removes all reloadable constants after each request and relies on the autoloading hook to reload any required constants. That way on reach request only the constants needed to serve the page should be loaded. In production mode, constants will simply not be removed and autoloading will happen in an eager manner (before the app starts serving), since autoloading is not thread-safe. If loading a file defining a constant raises an error, ActiveSupport also takes care of removing that constant again, thus avoiding "broken" constants.

## The Rails Way, reloaded

ActiveSupport 3.0, even though a lot less than 2.3.5 did, either blows up in your face or does not even mind if anything went wrong. This was the initial motivation for my project proposal. My goal was to reduce error messages. In order to do that, I changed the inner architecture of `ActiveSupport::Dependencies` away from a procedural, list juggling to an object oriented approach where every constant has a wrapper knowing whether it is already activated, it is reloadable, and how and when to reload it. At the end of each request still all constants are removed, but the wrappers are kept. Now, the wrapper can decide whether to restore the wrapped constant or to reload it from source.

In order to do so the developer can choose a reloading strategy. This is probably only relevant for plugin or middleware developers (due to extensive reference keeping, the constant removing approach is rather annoying when writing Rack middleware). The default strategy is the world reloader. The world reload will all cause all constants to be reloaded if a single file referencing a constant with this strategy was changed. This is essentially the same as the current Rails strategy plus checking for changes. ActiveSupport can also pretend a change occurred on every request and skip the `mtime` checking. This is an advantage if you have a setup where loading files is rather cheap and checking `mtimes` is expensive. Another strategy best set on per constant level, is the open class strategy. It is activated via `unloadable :monkey_patching`. If you do so, changing that file will only reload the constant defined in it and restore the constant before reloading it, thus using the open class and keeping all references to that class intact. A third strategy, that is rather experimental, tries to divide the reloadable pool into smaller sub-pools, reloading only the pools affected by file changes. As Yehuda Katz pointed out, this almost always works in demo scenarios but probably fails when tried for real world cases. It is of course also possible to change the default strategy. Such sub-pools are created by associations, `require`, `require_dependency` and explicitly by `Module#associate_with`. I therefore named it sloppy reloading. Since every strategy is just a mixin, plugin developers doing a lot of rails core work, or developers of other frameworks using ActiveSupport (think Padrino) could easily apply their own strategy (`unloadable MyLib::MyStrategy`).

But how does this help with reducing errors? The wrapper approach allows easier tracking of what is happening to a constant. The wrapper has hooks to whenever a constant is added or updated, which reduces the likelihood of a "is already activated" or "is not missing constant" error. Moreover, it shifts errors from the autoloading point to the moment old references are actually used. A old reference no one is touching anymore does no harm. My branch therefore modifies the old constant to be a proxy for the new one as soon as it is replaced by another version. In most cases this will not cause an error but redirect the methods and result in the behavior expected if you would not be aware of the reloading that's going on under the hood. This even works when including modules, as Ruby relies on `append_features`, which will also be delegated to the new constant.

Another issue dealt with is using require on reloadable files. Usually, developers are told to simply avoid `require` and use `require_dependency` instead. If you require a file containing an explicitly reloadable constant without referencing that constant, it will only be loaded the first time. At that point Ruby adds the file to `$LOADED_FEATURES` and will not load it again on a require. After the request finished, ActiveSupport will remove the constant. On a reload you might expect require to load the file or the constant to be defined and then try to access the constant implicitly. In that case you will not be able to reach the constant. The patched version of ActiveSupport therefore takes care of removing files from the `$LOADED_FEATURES` if the constant is removed. Tracking such events based on the list architecture would have been a nightmare.

One last, technically minor issue, is offering an alias for `unloadable`. A lot of developers I know initially seem rather confused by `unloadable`, sometimes even assuming it does the exact opposite (as the constant it "not loadable"). I therefore added an alias I rather prefer: `reloadable`, especially when used with a strategy: `reloadable :sloppy`.

## Numbers, please

Lies, damned lies, and statistics, so here we go. In a simple Sinatra application, I get the following numbers:

<table>
  <thead>
    <th> </th>
    <th>no changes</th>
    <th>file changed</th>
  </thead>
  <tbody>
    <tr>
      <th>No Reloader</th>
      <td>0.0044671058654</td>
      <td>-</td>
    </tr>
    <tr>
      <th>Rack::Reloader</th>
      <td>0.0231933116912</td>
      <td>0.0236261129379</td>
    </tr>
    <tr>
      <th>Sinatra::Reloader</th>
      <td>0.0088394482930</td>
      <td>0.0090538899103</td>
    </tr>
    <tr>
      <th>ActiveSupport</th>
      <td>0.0207427183787</td>
      <td>0.0207780686060</td>
    </tr>
    <tr>
      <th>ActiveSupport Reloaded</th>
      <td>0.0147878090540</td>
      <td>0.0208899911244</td>
    </tr>
    <tr>
      <th>Shotgun</th>
      <td>0.9925425291061</td>
      <td>1.0038710657755</td>
    </tr>
    <tr>
      <th>Magical Reloading Sparkles</th>
      <td>0.0044739915830</td>
      <td>0.9384773521974</td>
    </tr>
  </tbody>
</table>

In a simple Rails 3.0 app serving a page took 0.00793675 seconds, while with my RSoC branch it took 0.00379425 seconds.
Note that you might want to disable `mtime` checking on JRuby, as it is about 10 times slower than on MRI and 5 times slower than on Rubinius. If it is worth checking the `mtime` on JRuby really depends on how long your files take to load. If you do a lot of instance variable caching and such you might still prefer checking for changes.
