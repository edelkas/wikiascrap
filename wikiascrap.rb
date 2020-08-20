# Modules
require 'net/http'
# Gems
require 'nokogiri'

NAME  = 'nplusplus'
SITE  = "https://#{NAME}.fandom.com"
FULL  = false # Include all revisions
FILES = false # Also download files, requires token (read README)
TOKEN = nil

def parse(url)
  Nokogiri::HTML(Net::HTTP.get(URI.parse(url)))
end

def retrieve_file(foldername, filename)
  # We need to be authenticated to be able to retrieve files from Wikia.
  # To do this, authenticate on your browser, then browse the generated
  # cookies and copy the "access_token" one to the TOKEN variable.
  return 0 if File.file?(foldername + "/" + filename)

  # Retrieve page
  uri = URI.parse(SITE)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")
  req = Net::HTTP::Get.new("/wiki/#{filename}")
  req['cookie'] = "access_token=#{TOKEN}"
  res = http.request(req)
  if res.code != "200" then raise end

  # Retrieve file
  doc = Nokogiri::HTML(res.body)
  url = doc.at('div[class="fullMedia"]').at('a')['href'] + "&format=original"
  file = Net::HTTP.get(URI.parse(url))
  if filename[0..4].downcase == "file:" then filename = filename[5..-1] end
  File.binwrite(foldername + "/" + filename, file)
  return 0
rescue
  return 1
end

def parse_page(doc)
  doc.at('table[class="mw-allpages-table-chunk"]').children.map{ |row|
    row.search('a').map{ |p|
      URI.unescape(p['href'].gsub('/wiki/', ''))
    }
  }.flatten
end

# Retrieves full list of pages or files of the Wikia
def list(files = false)
  doc = parse("#{SITE}/wiki/Special:AllPages#{files ? "?namespace=6" : ""}")
  if !doc.at('table[class="allpageslist"]').nil?
    doc.at('table[class="allpageslist"]').children.map{ |c| SITE + c.at('a')['href'] }.map{ |page|
      page_doc = parse(page)
      parse_page(page)
    }.flatten  
  else
    parse_page(doc)
  end
end

# Exports files
def export(content, files = false)
  t = Time.now
  if files
    error = false
    foldername = NAME + (FULL ? "_full" : "") + "_files"
    Dir.mkdir(foldername) if !Dir.exist?(foldername)
    content.each_with_index{ |f, i|
      print("Downloading file #{i} / #{content.size}...".ljust(80, " ") + "\r")
      ret = retrieve_file(foldername, f)
      if ret != 0
        puts("Error downloading file #{i}.")
        error = true
      end
    }
    puts "Exported to folder #{foldername} in #{"%.3f" % (Time.now - t)} seconds."
    if error
      puts("Looks like some files failed to download. Possible reasons:")
      puts("  * Authentication failure (read README).")
      puts("  * Timeout, e.g. if one file was too big.")
      puts("  * Internet connection issues.")
      puts("Note: You can run the scraper again to download the missing files,")
      puts("      the already downloaded ones will be skipped.")
    end
  else
    opt = {pages: content}
    if !FULL then opt[:curonly] = 1 end
    ret = Net::HTTP.post_form(
      URI.parse("#{SITE}/wiki/Special:Export?action=submit"),
      **opt
    ).body
    filename = NAME + (FULL ? "_full" : "") + ".xml"
    File.write(filename, ret)
    puts "Exported to #{filename} in #{"%.3f" % (Time.now - t)} seconds."
  end
end

def main
  puts "Wikia scrapper initialized."
  puts "* Including revisions: #{FULL ? "Yes" : "No"}"
  puts "* Including files:     #{FILES ? "Yes" : "No"}"
  t = Time.now
  puts "Retrieving full list of pages from #{NAME} Wikia..."
  pages = list(false)
  puts "Exporting #{pages.size} pages from #{NAME} Wikia..."
  export(pages.join("\n"), false)
  if FILES
    if TOKEN.nil?
      puts "Files couldn't be exported, you need to be authenticated, read README."
    else
      puts "Retrieving full list of files from #{NAME} Wikia..."
      files = list(true)
      puts "Exporting #{files.size} files from #{NAME} Wikia..."
      export(files, true)
    end
  puts "Finished in #{"%.3f" % (Time.now - t)} seconds."
  end
end

main
