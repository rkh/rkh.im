xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title 'rkh.im'
  xml.id 'http://rkh.im'
  xml.updated Time.now.httpdate
  xml.author { xml.name 'Konstantin Haase' }

  @articles.each do |slug, title, date, content|
    xml.entry do
      xml.title title
      xml.link "rel" => "alternate", "href" => "http://rkh.im#{slug}"
      xml.id slug
      xml.published date.iso8601
      xml.updated date.iso8601
      xml.author { xml.name 'Konstantin Haase' }
      xml.content content, "type" => "html"
    end
  end
end
