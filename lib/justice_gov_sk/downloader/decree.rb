module JusticeGovSk
  class Downloader
    class Decree < JusticeGovSk::Downloader
      def storage
        @storage ||= JusticeGovSk::Storage::DecreePage
      end
    end
  end
end
