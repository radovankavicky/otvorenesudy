class API::ApplicationController < ActionController::Base
  include API::Authorizable

  protect_from_forgery with: :null_session

  respond_to :json

  def serialization_scope
    self
  end
end
