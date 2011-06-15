source :rubygems unless ENV['QUICK']

%w[tilt sinatra rack].each { |d| gem(d, :git => "git://github.com/rkh/#{d}.git") }
%w[slim sass rdiscount compass coffee-script thin builder].each { |d| gem(d) }
