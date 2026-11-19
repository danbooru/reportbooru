class ApplicationController < ActionController::Base
protected

  def enable_cors
    response.headers["Access-Control-Allow-Origin"] = "*"
  end
end
