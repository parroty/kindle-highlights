require 'rubygems'
require 'mechanize'

class KindleHighlight
  attr_accessor :highlights, :books
	
  def initialize(email_address, password)
    @agent = Mechanize.new
    page = @agent.get("https://www.amazon.com/ap/signin?openid.return_to=https%3A%2F%2Fkindle.amazon.com%3A443%2Fauthenticate%2Flogin_callback%3Fwctx%3D%252F&pageId=amzn_kindle&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.pape.max_auth_age=0&openid.assoc_handle=amzn_kindle&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select")
    @amazon_form = page.form('signIn')
    @amazon_form.email = email_address
    @amazon_form.password = password
    scrape_highlights
  end

  def scrape_highlights
    signin_submission = @agent.submit(@amazon_form)
    highlights_page = @agent.click(signin_submission.link_with(:text => /Your Highlights/))

    self.books      = collect_book(highlights_page)
    self.highlights = collect_highlight(highlights_page)
  end

private
  def collect_book(page)
    page.search(".//div[@class='bookMain yourHighlightsHeader']").map { |b| Book.new(b) }
  end

  def collect_highlight(page)
    page.search(".//div[@class='highlightRow yourHighlight']").map { |h| Highlight.new(h) }
  end
end

class KindleHighlight::Book
  attr_accessor :asin, :author, :title

  @@amazon_items = Hash.new

  def initialize(item)
    self.asin = item.attribute("id").value.gsub(/_[0-9]+$/, "")
    self.author = item.xpath("span[@class='author']").text.gsub("\n", "").gsub(" by ", "").strip
    self.title  = item.xpath("span/a").text

    @@amazon_items[self.asin] = {:author => author, :title => title}
  end

  def self.find(asin)
    @@amazon_items[asin] || {:author => "", :title => ""}
  end
end

class KindleHighlight::Highlight

  attr_accessor :annotation_id, :asin, :author, :title, :content

  @@amazon_items = Hash.new

  def initialize(highlight)
    self.annotation_id = highlight.xpath("form/input[@id='annotation_id']").attribute("value").value 
    self.asin = highlight.xpath("p/span[@class='hidden asin']").text
    self.content = highlight.xpath("span[@class='highlight']").text

    book = KindleHighlight::Book.find(self.asin)
    self.author = book[:author]
    self.title = book[:title]
  end
end