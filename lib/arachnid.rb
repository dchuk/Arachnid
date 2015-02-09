# encoding: utf-8

require 'tempfile'
require 'typhoeus'
require 'bloomfilter-rb'
require 'nokogiri'
require 'domainatrix'
require 'addressable/uri'

class Arachnid

  def initialize(urls, options = {})
    @start_urls = urls.is_a?(Array) ? urls : [urls]
    @debug = options[:debug]
    @domain = Arachnid.parse_domain(@start_urls[0])
    @split_url_at_hash = options[:split_url_at_hash]
    @exclude_urls_with_hash = options[:exclude_urls_with_hash]
    @exclude_urls_with_extensions = options[:exclude_urls_with_extensions]
    @proxy_list = options[:proxy_list]
    @cookies_enabled = options[:enable_cookies]
  end

  def crawl(options = {})
    threads = options[:threads] || 1
    max_urls = options[:max_urls]
    filter = options[:filter]

    @hydra = Typhoeus::Hydra.new(:max_concurrency => threads)
    @global_visited = BloomFilter::Native.new(:size => 1000000, :hashes => 5, :seed => 1, :bucket => 8, :raise => false)
    @global_queue = []

    @global_queue.concat @start_urls

    while not @global_queue.empty?

      @global_queue.size.times do
        q = @global_queue.shift

        if !max_urls.nil? && @global_visited.size >= max_urls
          @global_queue = []
          break
        end

        if filter
          next unless filter.call(q)
        end

        @global_visited.insert(q)
        puts "Processing link: #{q}" if @debug

        ip,port,user,pass = grab_proxy

        options = {timeout: 10000, followlocation:true}
        options[:proxy] = "#{ip}:#{port}" unless ip.nil?
        options[:proxy_username] = user unless user.nil?
        options[:proxy_password] = pass unless pass.nil?
        if @cookies_enabled
          cookie_file = Tempfile.new 'cookies'
          options[:cookiefile] = cookie_file
          options[:cookiejar] = cookie_file
        end

        request = Typhoeus::Request.new(q, options)

        request.on_complete do |response|

          next unless Arachnid.parse_domain(response.effective_url) == @domain

          yield response

          links = Nokogiri::HTML.parse(response.body).xpath('.//a/@href').map(&:to_s)
          links.each do |link|
            next if link.match(/^\(|^javascript:|^mailto:|^#|^\s*$|^about:/)
            begin

              if internal_link?(link, response.effective_url) && 
                !@global_visited.include?(make_absolute(link, response.effective_url)) &&
                no_hash_in_url?(link) &&
                extension_not_ignored?(link)

                absolute_link = make_absolute(split_url_at_hash(link), response.effective_url)
                @global_queue << absolute_link unless @global_queue.include?(absolute_link)
              end

            rescue Addressable::URI::InvalidURIError => e
              $stderr.puts "#{e.class}: Ignored link #{link} (#{e.message}) on page #{q}" if @debug
            end
          end

        end

        @hydra.queue request

      end
      puts "Running the hydra" if @debug
      @hydra.run
    end

  end

  def grab_proxy
    return nil unless @proxy_list

    @proxy_list.sample.split(':')
  end

  def self.parse_domain(url)
    parsed_domain = Domainatrix.parse(url)

    if(parsed_domain.subdomain != "")
      parsed_domain.subdomain + '.' + parsed_domain.domain + '.' + parsed_domain.public_suffix
    else
      parsed_domain.domain + '.' + parsed_domain.public_suffix
    end
  end

  def internal_link?(url, effective_url)
    absolute_url = make_absolute(url, effective_url)
    parsed_url = Arachnid.parse_domain(absolute_url)
    @domain == parsed_url
  end

  def split_url_at_hash(url)
    return url unless @split_url_at_hash

    url.split('#')[0]
  end

  def no_hash_in_url?(url)
    !@exclude_urls_with_hash || url.scan(/#/).empty?
  end

  def extension_not_ignored?(url)
    return true if url.empty?
    return true unless @exclude_urls_with_extensions

    @exclude_urls_with_extensions.find { |e| url.downcase.end_with? e.downcase }.nil?
  end

  def make_absolute(href, root)
    Addressable::URI.parse(root).join(Addressable::URI.parse(href)).to_s
  end

end


