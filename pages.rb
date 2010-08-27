# Additional pages defined in here
Blog::Page.new(`coffee -p templates/blog.coffee`, "/blog.js", 200, false).header["Content-Type"] = "text/javascript"

Blog::Page.new(<<-JAVASCRIPT, "/articles.js", 200, false).header["Content-Type"] = "text/javascript"
var articles;
articles = #{JSON.pretty_generate Blog.articles.map(&:url)};
titles   = #{JSON.pretty_generate Blog.articles.inject({}) { |h,a| h.merge(a.url => a.title) }};
JAVASCRIPT

require 'compass'
Compass.configuration do |config|
  config.project_path = File.dirname(__FILE__)
  config.sass_dir = 'templates'
end

Blog::Page.new("templates/blog.sass", "/blog.css", 200, false, Compass.sass_engine_options).header["Content-Type"] = "text/css"
Blog::Page.new("templates/feed.builder", "/feed.xml", 200, false).header["Content-Type"] = "text/xml"
Blog::Page.new("User-agent: *\nDisallow: /\n", "/robots.txt", 200, false).header["Content-Type"] = "text/plain"
