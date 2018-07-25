class PrivateController < ApplicationController
  include Secured
    
  def hello
    render json: { message: 'Hello from a private endpoint! You need to be authenticated to see this.' }
  end
end
