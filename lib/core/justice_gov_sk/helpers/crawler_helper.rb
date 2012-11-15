# encoding: utf-8

module JusticeGovSk
  module Helpers
    module CrawlerHelper
      def self.crawl_resources(args)
        type   = args[:type].camelcase
        offset = args[:offset].blank? ? 1 : args[:offset].to_i
        limit  = args[:limit].blank? ? nil : args[:limit].to_i
        
        persistor = Persistor.new
        
        agent = JusticeGovSk::Agents::ListAgent.new
        
        agent.cache_load_and_store = false

        request = "JusticeGovSk::Requests::#{type}ListRequest".constantize.new
        
        if type == 'Judge'
          lister = JusticeGovSk::Crawlers::JudgeListCrawler.new agent, persistor

          lister.crawl_and_process(request, offset, limit)
        else
          lister = JusticeGovSk::Crawlers::ListCrawler.new agent
  
          downloader = Downloader.new
  
          downloader.headers              = JusticeGovSk::Requests::URL.headers
          downloader.data                 = {}
          downloader.cache_load_and_store = true
          downloader.cache_file_extension = :html
          downloader.cache_uri_to_path    = JusticeGovSk::Requests::URL.uri_to_path_lambda
  
          crawler = "JusticeGovSk::Crawlers::#{type}Crawler".constantize.new downloader, persistor
          
          lister.crawl_and_process(request, offset, limit) do |url|
            begin
              crawler.crawl url
            rescue Exception => e
              _, code = *e.to_s.match(/response code (\d+)/i)
              
              case code.to_i
              when 302 
                puts "Redirect returned for #{url}, rejected."
              when 500
                puts "Internal server error for #{url}, rejected."
              else
                raise e
              end
            end
          end
        end
      end
    end
  end
end
