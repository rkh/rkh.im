title: Strengths and Weaknesses of Seaside
date: 2010-08-04

*This is an excerpt from my bachelor thesis.*

## Core principles
[Seaside](http://seaside.st/)'s approach to web development differs from most other web
frameworks, such as Django or Ruby On Rails, by explicitly breaking
with common patterns and principals the web is built upon, such as
being stateless, having meaningful, maybe even restful URLs or using
template systems.

When doing web development you often have to work with the construct of a session, that
allows one to keep state in between requests made from the same
browser session. Usually the session is serialized and stored in a
cookie or a database. Seaside takes advantage of Smalltalk's image
based nature by simply keeping the session as an object in the
currently active process.

This eliminates the overhead of serializing
every object in the session and the need to keep the number of objects
kept by the session small. Seaside goes even further by storing
closures and continuations in the session.

While most other frameworks use the session as little as possible, in
Seaside it is used for nearly everything. It solely depends on the
state of your session what page is displayed. Usually every Seaside
application features a single entrance point, a so called root
component.

User navigation is realized by storing continuations and
callbacks (closures) for the currently displayed page. User
interaction will then trigger any associated callbacks, thereby
changing the session's state, and then re-render the possibly changed
content.

## Advantages over other web frameworks
This gives some advantages over classic web development. Applications,
though written for the web, are developed in a way rather similar to
desktop applications. Interactive websites, also known as Rich
Internet Applications, can rapidly be developed.

In the prototyping phase or when developing small sites, using the
image for storing data eliminates any need for implementing a
persistence layer, like an object-database-mapping mechanism. 

Working on such a high abstraction level compared to normal web
development encourages the developer to use object orientation and
decoupling on other levels than when working with other web
frameworks. Rather than thinking of constructs and working with object
representing requests, streams, cookies or URLs, websites are defined
by components, callbacks and canvases. This can also encourage a
creativity, since it requires developers to think outside of their
common patterns.

## Downsides of developing with Seaside
There are some downsides one has to be aware of when choosing
Seaside. Due to the session based nature and the close coupling of
"rendering", it is rather
complicated to implement public APIs. In many cases Smalltalk
developers fall back to other libraries and protocols to accomplish
this.

When developing software with Seaside, the commonly
used path is to write in Smalltalk whatever can be written in
Smalltalk. This is especially true as Seaside is able to generade some
JavaScript from Smalltalk, and tools like Glorp do the same for
SQL. This is rather cosy for the developer, who probably favors
Smalltalk over the other languages anyway. 

However, this poses the threat of doing computation in the Seaside
image, that could usually be done in the web browser or at database
level. Moreover, as this results in changes to the HTML output more
often than would be necessary when filling in content via JavaScript,
this also conflicts with established caching techniques. The latter is
not much of  an issue, since HTTP level caching is not feasible with
Seaside, as will be discussed in a moment.

Seaside applications usually also conflict with established usage
patterns. Tabbed browsing is imposible, so is storing bookmarks for
any page besides the entrance page. If a user shares a link with
another user, not only might that link not work when the current
session expires. This usually happens 10 minutes after the
last HTTP request.

If the session is not yet expired, the other
user opening the link will end up in the same session as the one
sharing the link with him or her. This will not only lead to
unexpected behavior, but represents a major security risk.

## Seaside and scalability - deployment issues to be aware of
There are also implications on the infrastructure level, especially
when using reverse proxies. At the server side two types of proxies are commonly
used: caches and load balancers.

HTTP caches are simply not
feasible with Seaside. Techniques like the ETag, Last-Modified
and Cache-Control HTTP headers are unusable, since they rely on
the same content being available under the same URI for multiple
requests. Only application layer caching is an option, but it lacks
general Seaside solutions and does not keep requests from reaching the
image in the first place.

Although it would be possible to cache a response, the same HTTP
request is extremely unlikely to reoccur and the cache would only
allocate additional system resources, increasing deployment costs
even more.

Load balancers are rather important when scaling web
applications. When running a web application you usually do not want
to start an application process for every incoming request. Therefore,
in a simple setup, one process, an application server, is started and
all incoming requests are handled by this process.

The Seaside equivalent is starting a Smalltalk image with Seaside. However,
increasing load might have a major performance impact on the
image. Therefore you often want to launch multiple images on the same
computer or even multiple computers each running at least one instance
of your application and distribute load equally among them.

This is where the load balancer comes in. The load balancer listens for any
incoming requests and forwards them as equally distributed as possible
to the different images. To reduce overhead the load balancer has to
be as fast as possible. Larger setups therefore use hardware load
balancers working on ethernet level.

For distribution, the proxy often
relies on round robin, and URI based sharding, as these algorithmes
are simple, efficient and can be implemented at a very low level. As
for the same reasons tabs and bookmarks are not usable, you cannot
rely on URI based sharding.

Load balancing is a major concern when deploying Seaside
applications, since most Smalltalk implementations rely on green threads
and most Seaside application are not thread-safe. A small number of
users accessing the application simultaneously will already result in
a noticeable increase of response time.

When having identical application servers, round robin is the simples
way one can imagine to distribute load among them: The first request
is forwarded to the first application server, the second to the
second, and so on. Until you reach the last app server and start with
the first server again. Without additional tools, this approach is not
usable with Seaside, as requests from a single browser session always
have to be forwarded to the same application server.

The common approach to address this issue is to use an object database, in
most cases the proprietary Gemstone/S system, to persist the current
session and thus share it over the network among all application
servers. While this works remarkably well, it comes with the large
overhead of synchronizing the session and all referenced objects
(including the closures and continuations) for each and every
request.

Advanced load balancers do not strictly rely on round robin, but track how
many outstanding requests the individual application servers have or
how low their response time is, and distribute incoming requests
accordingly.

An alternative approach is to always forward requests from the same
client to the same application server. While this approach works even
without sharing sessions among images, it needs additional overhead
and does not distribute load as equally as round robin or any similar
approach.

Imagine one user would be all a single image could
handle. In that case all users would have to be equally active to
distribute load perfectly among the servers. Moreover, if you have
six users on five application servers, the load balancer would have to
forward two users to the same server.

To solve the performance issues of those two users, a system
administrator could decide to start yet another application server and
hook it into the load balancer. However, unless a new user appears,
that application server will never be used, as users are always
forwarded to the same application servers. If one application server
crashes, the load balancer will no longer be able to serve to users
previously using that server.

In a real world example you would therefore configure the load
balancer to only forward to the same image in the most cases, with the
ability of switching images. Unless you are willing to risk losing the
session, that would mean sharing sessions again, but lower the
synchronization overhead.

By design, this overhead would still be larger than for any web
framework embracing web patterns like REST, and makes scaling Seaside
a hard task to accomplish. 

## Why Seaside?

Despite the scalability issues just discussed, we decided to use
Seaside. As a powerful web framework it allowed us to easily implement
the infrastructure described earlier.

Another important factor was that we should favor
technologies our external partners were using themselves. This largely
influenced our decision towards
[VisualWorks](http://www.cincomsmalltalk.com/main/products/visualworks/)
and [Glorp](http://www.glorp.org/).

The only remaining competitor in for this setup would have been the
[Iliad](http://www.iliadproject.org/) web framework, which is commonly
used with [Gnu Smalltalk](http://smalltalk.gnu.org/) rather
than VisualWorks. We therefore assumed better support for
Seaside. Moreover, our customer was also developing applications with
Seaside, which made it a perfect candidate for the project.

Fortunately, scalability was not a concern, as the system will
probably only have one or two users accessing it simultaneously.
