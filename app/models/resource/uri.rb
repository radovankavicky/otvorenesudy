module Resource::URI
  extend ActiveSupport::Concern

  included do
    attr_accessible :uri

    belongs_to :source 
  end
end
