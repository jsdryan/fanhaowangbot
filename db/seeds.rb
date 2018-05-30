require "open-uri"
require 'nokogiri'


Genre.destroy_all
Genre.create(name: "ALL")
puts "created ALL"
url = "https://www.javhoo.com/genre"
html_data = open(url).read
dom = Nokogiri::HTML(html_data)
dom.css(".genre-col").each do |genre|
  Genre.create(name: genre.text)
  puts "created #{genre.text}"
end

