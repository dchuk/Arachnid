# encoding: utf-8

require 'typhoeus'
require 'bloomfilter-rb'
require 'nokogiri'
require 'domainatrix'
require 'uri'

class Arachnid

	def initialize(url, options = {})
		@start_url = url
		@domain = parse_domain(url)

		@split_url_at_hash = options[:split_url_at_hash] ? options[:split_url_at_hash] : false
		@exclude_urls_with_hash = options[:exclude_urls_with_hash] ? options[:exclude_urls_with_hash] : false
		@exclude_urls_with_images = options[:exclude_urls_with_images] ? options[:exclude_urls_with_images] : false
		
		@debug = options[:debug] ? options[:debug] : false
	end

	def crawl(options = {})

		threads = options[:threads] ? options[:threads] : 1

		@hydra = Typhoeus::Hydra.new(:max_concurrency => threads)
		@global_visited = BloomFilter::Native.new(:size => 1000000, :hashes => 5, :seed => 1, :bucket => 8, :raise => false)
		@global_queue = []

		@global_queue << @start_url
		
		while(@global_queue.size > 0)
			temp_queue = @global_queue

			temp_queue.each do |q|

				begin
					request = Typhoeus::Request.new(q, :timeout => 10000)

					request.on_complete do |response|

						yield response

						links = Nokogiri::HTML.parse(response.body).xpath('.//a/@href')

						links.each do |link|
							if(internal_link?(link) && !@global_visited.include?(split_url_at_hash(link)) && no_hash_in_url?(link) && no_image_in_url?(link))
								
								sanitized_link = sanitize_link(split_url_at_hash(link))
								if(sanitized_link)

									absolute_link = make_absolute(sanitized_link, response.effective_url)
									if(absolute_link)
										@global_queue << absolute_link
									end
								end
							end
						end

					end

					@hydra.queue request

				rescue URI::InvalidURIError, NoMethodError => e
					puts "Exception caught: #{e}" if @debug == true
				end

				@global_visited.insert(q)
				@global_queue.delete(q)
			end

			@hydra.run

		end

	end

	def parse_domain(url)
		puts "Parsing URL: #{url}" if @debug == true

		begin
			parsed_domain = Domainatrix.parse(url)
			parsed_domain.subdomain + '.' + parsed_domain.domain + '.' + parsed_domain.public_suffix
		rescue NoMethodError, Addressable::URI::InvalidURIError => e
			puts "URL Parsing Exception (#{url}): #{e}" if @debug == true
			return nil
		end
	end

	def internal_link?(url)
		parsed_url = parse_domain(url)
		if(@domain == parsed_url)
			return true
		else
			return false
		end
	end

	def split_url_at_hash(url)
		return url.to_s unless @split_url_at_hash

		return url.to_s.split('#')[0]

	end

	def no_hash_in_url?(url)
		return true unless @exclude_urls_with_hash

		if(url.to_s.scan(/#/).size > 0)
			return false
		else
			return true
		end
	end

	def no_image_in_url?(url)
		return true unless @exclude_urls_with_images

		extensions = ['.jpg', '.gif', '.png', '.jpeg']
		not_found = true

		extensions.each do |e|
			if(url.to_s[-e.size .. -1].downcase == e.to_s.downcase)
				not_found = false
			end
		end

		return not_found
	end

	def sanitize_link(url)
		begin
			return url.gsub(/\s+/, "%20")
		rescue
			return false
		end
	end

	def make_absolute( href, root )
		begin
	  		URI.parse(root).merge(URI.parse(href)).to_s
	  	rescue URI::InvalidURIError, URI::InvalidComponentError => e
	  		return false
	  	end
	end

end