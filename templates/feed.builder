xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title 'rkh.im'
  xml.id 'http://rkh.im'
  xml.updated Blog.last_modified
  xml.author { xml.name 'Konstantin Haase' }

  articles.each do |article|
    xml.entry do
      xml.title article.title
      xml.link "rel" => "alternate", "href" => "http://rkh.im/#{article.url}"
      xml.id article.url
      xml.published article.date.iso8601
      xml.updated article.date.iso8601
      xml.author { xml.name 'Konstantin Haase' }
      xml.content article.source, "type" => "html"
    end
  end
end
