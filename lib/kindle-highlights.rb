require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'erb'
require 'ostruct'

class KindleHighlight
  attr_accessor :highlights, :books

  DEFAULT_WAIT_TIME = 5

  def initialize(email_address, password, options = {}, &block)
    @agent = Mechanize.new
    page = @agent.get("https://www.amazon.com/ap/signin?openid.return_to=https%3A%2F%2Fkindle.amazon.com%3A443%2Fauthenticate%2Flogin_callback%3Fwctx%3D%252F&pageId=amzn_kindle&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.pape.max_auth_age=0&openid.assoc_handle=amzn_kindle&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select")
    @amazon_form = page.form('signIn')
    @amazon_form.email = email_address
    @amazon_form.password = password
    @page_limit = options[:page_limit] || 1
    @wait_time  = options[:wait_time]  || DEFAULT_WAIT_TIME
    @block = block

    scrape_highlights
  end

  def scrape_highlights
    signin_submission = @agent.submit(@amazon_form)
    highlights_page = @agent.click(signin_submission.link_with(:text => /Your Highlights/))

    self.books      = Array.new
    self.highlights = Array.new
    @page_limit.times do | cnt |
      self.books      += collect_book(highlights_page)
      self.highlights += collect_highlight(highlights_page)

      highlights_page = get_next_page(highlights_page)
      break unless highlights_page
      sleep(@wait_time) if cnt != 0

      @block.call(self) if @block
    end
  end

  def merge!(list)
    list.books.each do | b |
      self.books.delete_if { |x| x.asin == b.asin }
      self.books << b
    end

    list.highlights.each do | h |
      self.highlights.delete_if { |x| x.annotation_id == h.annotation_id }
      self.highlights << h
    end
  end

  def list
    List.new(self.books, self.highlights)
  end

private
  def collect_book(page)
    page.search(".//div[@class='bookMain yourHighlightsHeader']").map { |b| Book.new(b) }
  end

  def collect_highlight(page)
    page.search(".//div[@class='highlightRow yourHighlight']").map { |h| Highlight.new(h) }
  end

  def get_next_page(page)
    ret = page.search(".//a[@id='nextBookLink']").first
    if ret and ret.attribute("href")
      @agent.get("https://kindle.amazon.com" + ret.attribute("href").value)
    else
      nil
    end
  end
end

class KindleHighlight::List
  attr_accessor :books, :highlights, :highlights_hash

  def initialize(books, highlights)
    self.books = books
    self.highlights = highlights
    self.highlights_hash = get_highlights_hash
  end

private
  def get_highlights_hash
    hash = Hash.new([].freeze)
    self.highlights.each do | h |
      hash[h.asin] += [h]
    end
    hash
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


class KindleHighlight::BaseFormat
  def initialize(options)
    @file_name   = options[:file_name] || "output"
    @output_path = options[:output_path] || "."
    @list        = options[:list] || []
  end

  def save(str)
    File.open(@file_name, "w") do | f |
      f.puts str
    end
  end
end

class KindleHighlight::XML < KindleHighlight::BaseFormat
  def output
    builder = Nokogiri::XML::Builder.new do | xml |
      xml.books {
        @list.books.each do | b |
          xml.book {
            xml.asin b.asin
            xml.title b.title
            xml.author b.author

            @list.highlights_hash[b.asin].each do | h |
              xml.highlights {
                xml.annotation_id h.annotation_id
                xml.content h.content
              }
            end
          }
        end
      }
    end

    save(builder.to_xml)
  end
end

class KindleHighlight::HTML < KindleHighlight::BaseFormat
  def output
    output_html
    copy_styles
  end

private
  def output_html
    file_name = File.dirname(__FILE__) + "/template/kindle.html.erb"
    namespace = OpenStruct.new(:books => @list.books, :highlights => @list.highlights_hash)
    template = ERB.new(File.read(file_name)).result(namespace.instance_eval { binding })
    save(template)
  end

  def copy_styles
    src = File.dirname(__FILE__) + "/template/bootstrap"
    FileUtils.cp_r(src, @output_path)
  end
end
