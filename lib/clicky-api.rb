require 'rubygems'
require 'active_support'
require 'net/http'
class ClickyAPI
  BASE_URI  = "http://api.getclicky.com/api/stats/4"
  
  ## the list of acceptable API parameters -- unused at the moment
  @@PARAMS = %w{
    site_id     sitekey     type     output           limit       date    
    daily       hourly      item     visitor_details  time_offset     
    segments    ip_address  href     landing          exit     
    num_actions search      domain   link             browser     os
    resolution  country     city     language         hostname     
    org         source      shorturl        custom     session_id     
    title       href        action_type     filter     json_callback     
    json_var    null_values app
  }
  
  ## required API params -- unused at the moment
  @@REQUIRED_PARAMS = %w{ site_id sitekey type }
  
  ## params set to persist between calls.  keys are stringified.  this is
  ## a class variable -- global scope is in effect


  def initialize(param_hash=nil)
  @set_params = {}
    if !param_hash.nil?
      param_hash[:output] = "json"
      set_params!(param_hash)
    end
  end

  ## load_config_file! is called from the Rails initializer.  This code might
  ## need to be re-run if you're using the "development" environment, and
  ## the file gets reloaded.  Gross.
  def load_config_file!(file=nil)
    @set_params = {}
    if file.nil?
      if defined?(Rails)
        file = "#{Rails.root}/config/clicky-api.yml"
      else
        return nil ## perhaps this should throw here?
      end
    end
    config = YAML.load_file(file) || {}
    ClickyAPI.set_params!(config)
  end
  
  ## the 'set_params!' method is used to set params persistently, class-wide
  def set_params!(param_hash={})
    param_hash.each { |k,v| @set_params[k.to_s] = v }
  end
  
  ## get_params returns the hash of params set by #set_params!
  ## it returns the hash directly, so make a copy if you want to avoid
  ## affecting other nearby ClickyAPI calls.
  def get_params
    @set_params
  end
  
  ## the 'stats' method is used to obtain results.  I wanted to call it
  ## 'get' but the HTTParty module uses that method name.
  def stats(param_hash={})
    load_config_file! if @set_params.nil? # development mode only
    
    ## merge parameters, converting keys to strings
    params = {}
    @set_params.each { |k,v| params[k.to_s] = v }
    param_hash.each   { |k,v| params[k.to_s] = v }
    
    ## allow 'type' param to take arrays; join values with commas
    if params['type'].kind_of?(Array)
      params['type'] = params['type'].map{|v| v.to_s}.join(',')
    end
    
    query_string = params.collect{ |k,v| "#{k}=#{clicky_encode(v)}"}.join("&")
    url = URI.parse(BASE_URI)
    res = Net::HTTP.start(url.host, url.port) do |http|
      http.get(url.path + "?" + query_string)
    end
    
   return ActiveSupport::JSON.decode(res.body)
  end 
 

  private
    def clicky_encode(param)
      param.gsub(" ", '+').gsub('/', '%3B').gsub('+%3B+', '%3B').downcase
    end

end
