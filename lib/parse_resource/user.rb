require 'parse_resource/user_validator'

class ParseUser < ParseResource::Base
  fields :username, :password
  
  attr_accessor :app_id, :master_key
  validates_presence_of :username
  validates_presence_of :password
  #validates_with ParseUserValidator, :on => :create, :on => :save
  def app_id
    @app_id ||= settings['app_id']
  end

  def master_key
    @master_key ||= settings['master_key']
  end

  def self.authenticate(username, password)
    base_uri   = "https://api.parse.com/1/login"
    resource = RestClient::Resource.new(base_uri, app_id, master_key)
    
    begin
      resp = resource.get(:params => {:username => username, :password => password})
      model_name.constantize.new(JSON.parse(resp), false)
    rescue 
      false
    end
    
  end
  
  def self.authenticate_with_facebook(user_id, access_token, expires)
    base_uri   = "https://api.parse.com/1/users"
    resource = RestClient::Resource.new(base_uri, app_id, master_key)

    begin
      resp = resource.post(
          { "authData" =>
                            { "facebook" =>
                                  {
                                      "id" => user_id,
                                      "access_token" => access_token,
                                      "expiration_date" => Time.now + expires.to_i
                                  }
                            }
                      }.to_json,
                     :content_type => 'application/json', :accept => :json)
      model_name.constantize.new(JSON.parse(resp), false)
    rescue
      false
    end
  end
  
  def self.reset_password(email)
      base_uri   = "https://api.parse.com/1/requestPasswordReset"
      resource = RestClient::Resource.new(base_uri, app_id, master_key)

      begin
        resp = resource.post(:email => email)
        true
      rescue
        false
      end
  end
end
