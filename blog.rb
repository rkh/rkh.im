ENV['RACK_ENV'] ||= 'production' if `hostname` == "rkh.im\n"
%w[sinatra slim sass rdiscount yaml date compass].each { |l| require(l) }

Compass.configuration do |config|
  config.project_path = settings.root
  config.sass_dir = 'views'
end

set :slim, :pretty => true, :layout => :blog
set :sass, Compass.sass_engine_options
set :projects, YAML.load_file('projects.yml')

configure :production do
  sha1, date = `git log HEAD~1..HEAD --pretty=format:%h^%ci`.strip.split('^')

  before do
    etag sha1
    last_modified date
  end
end

articles = []
Dir.glob "articles/*.md" do |file|
  meta, text  = File.read(file, encoding: 'utf-8').split("\n\n", 2)
  title, date = YAML.load(meta).values_at "title", "date"
  date, slug  = Date.parse(date.to_s), "/#{file[12..-4]}"
  content     = Tilt.new(file, meta.lines.count + 2) { text }.render
  articles.unshift [slug, title, date, content]

  get slug do
    @title, @date, @content = title, date, content
    slim :post
  end
end

before { @title, @articles = "My Humble Blog", articles }

get('/') { slim :index }
get('/feed.xml') { builder :feed }
get('/style.css') { sass :style }
get('/:year/:month/:slug') { redirect to("/#{params[:slug]}") }
