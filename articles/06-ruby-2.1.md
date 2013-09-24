date: 2013-09-24 17:00:00 +0200
title: Ruby 2.1

Yesterday the first preview for Ruby 2.1 was [announced](https://www.ruby-lang.org/en/news/2013/09/23/ruby-2-1-0-preview1-is-released/). The release notes gave a first idea of what's new, but didn't go too much into detail. To find out more, you are pretty much left with diving through the Ruby issue tracker. Since I was already aware of most of these changes, I thought I'd write a quick overview post.

Site note: Obviously Ruby 2.1 includes all the juicy Ruby 2.0 features that I'm not going to repeat in this post.

### Refinements

Refinements were added in Ruby 2.0, but turned out to be highly controversial, so their functionality was reduced and the feature was marked experimental.

Refinements allowed you to apply certain monkey patches only to a single Ruby file:

    module Foo
      refine String do
        def foo
          self + "foo"
        end
      end
    end

    using Foo
    puts "bar".foo

Outside of the above file, Strings will not respond to the `foo` method.

In Ruby 2.1, refinements are no longer experimental and can also be applied within a module, without affecting the top level scope of a file.

    module Foo
      refine String do
        def foo
          self + "foo"
        end
      end
    end

    module Bar
      using Foo
      puts "bar".foo
    end

Please note that using refinements extensively can lead to very confusing code and that developers behind other Ruby implementations have already indicated they might not implement this feature at all.

### Decimal Literals

You might be aware that floats are far from ideal when doing calculations with fixed decimal points:

    irb(main):001:0> 0.1 * 3
    => 0.30000000000000004

A lot of Ruby developers fall back to using integers and only fixing it when displaying the result. However, this only works well if you have indeed have fixed decimal points. If not, you have to use rationals. Which isn't too bad, except there was no nice syntax for them (short of changing the return value of `Integer#/`).

Ruby 2.1 introduces the `r` suffix for decimal/rational literals to fix this:

    irb(main):001:0> 0.1r
    => (1/10)
    irb(main):002:0> 0.1r * 3
    => (3/10)

### Frozen String Literals

When you have a string literal in your code, Ruby will create a new string literal every time that line of code is executed. This has to happen, as strings in Ruby are mutable. This is also why symbols are more efficient in many cases. However, symbols are not strings. For instance, if you want to compare some user input to a symbol, you'll either have to convert the symbol to a string or the string to a symbol. This means you either open yourself up to a denial of service attack, as symbols are not garbage collected, or you again end up with an additional string creation.

Using symbols for string interpolation will also result in a new string creation, same is true when you want to write a symbol to a socket, the list goes on.

One way to combat this is to store a string in a constant and then use this constant instead:

    class Foo
      BAR = "bar"

      def bar?(input)
        input == BAR
      end
    end

Now, to deal with the issue of mutability, often times you also freeze the string (which prevents changes from Ruby land, but unfortunately does not give you a performance advantage):

    class Foo
      BAR = "bar".freeze

      def bar?(input)
        input == BAR
      end
    end

This can get tedious. Fortunately, Ruby 2.1 introduces a syntax doing something equivalent under the hood:

    class Foo
      def bar?(input)
        input == "bar"f
      end
    end

This will create a frozen string object once and then reuse it whenever the code is executed.

If your taste is somewhat like mine, you probably thing it looks very strange. The reasoning is that it works like the decimal suffix explained above.
Here's a trick I found to make it look more bearable:

    class Foo
      def bar?(input)
        input == %q{bar}f
      end
    end

There is [an open issue](https://bugs.ruby-lang.org/issues/8909) suggesting to add this suffix to arrays and hashes, too.

Hat tip to [Charlie Somerville](https://charlie.bz/) for this patch and suggesting a syntax I would have much preferred.

### Required Keyword Arguments

For some reason this wasn't even mentioned in the announcement.

Ruby 2.0 introduced keyword arguments:

    def foo(a: 10)
      puts a
    end
    
    foo(a: 20) # 20
    foo        # 10

However, this way keyword arguments always needed a default value. In Ruby 2.1 you can now have required keyword arguments:


    def foo(a:)
      puts a
    end
    
    foo(a: 20) # 20
    foo        # ArgumentError: missing keyword: a

### Method Definition returns Method Name

In previous Ruby versions, defining a method via `def` returned `nil`:

    def foo() end # => nil

In Ruby 2.1, it now returns the method name as a symbol:

    def foo() end # => :foo

This is useful for meta programming and other neat things. For instance, did you know that the `private` method also takes arguments?

    # only foo will be private
    class Foo
      def foo
      end

      private :foo

      # bar is not affected
      def bar
      end
    end

I use this style a lot in [mustermann](https://github.com/rkh/mustermann).

Now that `def` returns the name, this can be used to make a single method private:

    # only foo and bar will be private
    class Foo
      private def foo
      end

      private \
      def bar
      end

      def baz
      end
    end

I have created [an issue](https://bugs.ruby-lang.org/issues/8947) to expand this behavior to other ways of defining methods as well.

### Removing Garbage Bytes from Strings

Ruby now comes with a handy method to remove garbage bytes from strings:

    some_string.scrub("")

This has perviously such a pain to get working across Ruby implementations that I even wrote [a library](https://github.com/rkh/coder) for this.

### StringScanner supports Named Captures

`StringScanner` in the standard library is awesome. In fact, [Rails](https://github.com/rails/rails/search?q=strscan&ref=cmdform) is using it for parsing route patterns, and so will Sinatra 2.0. Check out Aaron's tutorial on [practicingruby.com](https://practicingruby.com/articles/parsing-json-the-hard-way?u=90296723ac).

Ruby 1.9 introduced named captures for regular expressions, however, StringScanner didn't support it:

    require 'strscan'
    s = StringScanner.new("foo")
    s.scan(/(?<bar>.*)/)
    puts s[:bar]

On Ruby 2.0 this will result in:

    TypeError: no implicit conversion of Symbol into Integer

And on Ruby 2.1:

    foo

This is actually a patch I added (and I used `goto`, oh my god).

### Accessing Network Interfaces

You can now access the network interfaces via `Socket.getifaddrs`:

    require 'socket'

    Socket.getifaddrs.each do |i|
      puts "#{i.name}: #{i.addr.ip_address}" if i.addr.ip?
    end

For me, the above prints:

    lo0: fe80::1%lo0
    lo0: 127.0.0.1
    lo0: ::1
    en0: fe80::1240:f3ff:fe7e:594e%en0
    en0: 192.168.178.30
    en2: fe80::3e07:54ff:fe6f:147a%en2

### Faster Numbers for Serious Math

Ruby 2.1 is now faster when it comes to large numbers, as it uses 128 bit integers for representing bignums internally now if available. They also got an additional speed boost by using the [GNU Multiple Precision Arithmetic Library](http://gmplib.org/).

### VM changes

The underlying virtual machine now doesn't solely rely on a global method cache, instead it also does call site caching. I gave [a talk about this topic](https://speakerdeck.com/rkh/aloha-ruby-conf-2012-message-in-a-bottle) if you're interested.

### RGenGC

Ruby now has a "partially" generational GC. This will speed up GC, which up until now was a conservative, stop the world, mark and sweep GC.

It basically still is. For some objects. This is hard to change due to Ruby's internal/external C API.

However, in Ruby 2.1, the VM will classify objects as sunny or as shady, depending on whether they need to have the normal treatment or not. There are different operations that will turn a sunny object into a shady one. For instance, handing them to a C extension. Other objects, like open files, are classified shady to begin with.

The sunny objects can be handled by a generational GC. Koichi Sasada gave a talk about this [at RubyKaigi](http://rubykaigi.org/2013/talk/S73) and [at Euruko](http://www.ustream.tv/recorded/35107339/highlight/377033).

### Updated RubyGems

RubyGems has been updated to 2.2.0, which comes with a few [minor enhancements](https://github.com/rubygems/rubygems/blob/master/History.txt).

### Just a Preview

Please be aware that yesterdays release is just a preview and all of the above is subject to change.
