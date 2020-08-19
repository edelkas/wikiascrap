# Modules
require 'net/http'
# Gems
require 'nokogiri'

NAME = 'n'
SITE = "https://#{NAME}.fandom.com"

def parse(url)
  Nokogiri::HTML(Net::HTTP.get(URI.parse(url)))
end

# Retrieve full list of pages
doc = parse("#{SITE}/wiki/Special:AllPages")
pages = doc.at('table[class="allpageslist"]').children.map{ |c| SITE + c.at('a')['href'] }.map{ |page|
  page_doc = parse(page)
  page_doc.at('table[class="mw-allpages-table-chunk"]').children.map{ |row|
    row.search('a').map{ |p|
      URI.unescape(p['href'].gsub('/wiki/', ''))
    }
  }
}.flatten.join("\n")

# Export all pages to XML using the built-in feature
File.write("#{NAME}.xml", Net::HTTP.post_form(URI.parse("#{SITE}/wiki/Special:Export?action=submit"), pages: pages ).body)
puts "Done"
