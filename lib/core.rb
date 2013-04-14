require 'active_support/core_ext/hash/deep_merge'
require 'active_support/inflector'
require 'active_support/json'
require 'active_support/multibyte'

require 'ruby/string'

require 'docsplit'
require 'mechanize'
require 'murmurhash3'
require 'nokogiri'
require 'settingslogic'

require 'core/configuration'
require 'core/output'
require 'core/identify'
require 'core/pluralize'
require 'core/storage/binary'
require 'core/storage/textual'
require 'core/storage'
require 'core/storage/cache'
require 'core/storage/distributed'
require 'core/storage/utils'
require 'core/extractor'
require 'core/extractor/cache'
require 'core/extractor/image'
require 'core/extractor/text'
require 'core/request'
require 'core/request/list'
require 'core/downloader'
require 'core/agent'
require 'core/factory'
require 'core/factory/supplier'
require 'core/factories'
require 'core/parser'
require 'core/parser/helper'
require 'core/parser/html'
require 'core/parser/html/helper'
require 'core/parser/json'
require 'core/parser/json/helper'
require 'core/persistor'
require 'core/crawler'
require 'core/crawler/helper'
require 'core/crawler/list'
require 'core/injector'
require 'core/base'
require 'core/version'

module Core
  extend Core::Base
end
