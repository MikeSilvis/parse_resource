require "active_support/hash_with_indifferent_access"
require "parse_resource/query"
require "parse_resource/error"
require "parse_resource/exceptions"

module ParseResource
  

  class Base
    # ParseResource::Base provides an easy way to use Ruby to interace with a Parse.com backend
    # Usage:
    #  class Post < ParseResource::Base
    #    fields :title, :author, :body
    #  end

    include ActiveModel::Validations
    include ActiveModel::Conversion
    include ActiveModel::AttributeMethods
    extend ActiveModel::Naming
    extend ActiveModel::Callbacks
    HashWithIndifferentAccess = ActiveSupport::HashWithIndifferentAccess

    define_model_callbacks :save, :create, :update, :destroy
    
    # Instantiates a ParseResource::Base object
    #
    # @params [Hash], [Boolean] a `Hash` of attributes and a `Boolean` that should be false only if the object already exists
    # @return [ParseResource::Base] an object that subclasses `Parseresource::Base`
    def initialize(attributes = {}, new=true)
      #attributes = HashWithIndifferentAccess.new(attributes)
      
      if new
        @unsaved_attributes = attributes
      else
        @unsaved_attributes = {}
      end
      self.attributes = {}
            
      self.attributes.merge!(attributes)
      self.attributes unless self.attributes.empty?
      create_setters_and_getters!
    end

    # Find a ParseResource::Base object by ID
    #
    # @param [String] id the ID of the Parse object you want to find.
    # @return [ParseResource] an object that subclasses ParseResource.
    def self.find(id)
			raise RecordNotFound if id.blank?
      where(:objectId => id).first
    end

    # Find a ParseResource::Base object by chaining #where method calls.
    #
    def self.where(*args)
      Query.new(self).where(*args)
    end
    
    # Include the attributes of a parent object in the results
    # Similar to ActiveRecord eager loading
    #
    def self.include_object(parent)
      Query.new(self).include_object(parent)
    end

    # Add this at the end of a method chain to get the count of objects, instead of an Array of objects
    def self.count
      #https://www.parse.com/docs/rest#queries-counting
      Query.new(self).count(1)
    end

    # Find all ParseResource::Base objects for that model.
    #
    # @return [Array] an `Array` of objects that subclass `ParseResource`.
    def self.all
      Query.new(self).all
    end

    # Find the first object. Fairly random, not based on any specific condition.
    #
    def self.first
      Query.new(self).limit(1).first
    end

    # Limits the number of objects returned
    #
    def self.limit(n)
      Query.new(self).limit(n)
    end
    
    def self.order(attribute)
      Query.new(self).order(attribute)
    end

    # Create a ParseResource::Base object.
    #
    # @param [Hash] attributes a `Hash` of attributes
    # @return [ParseResource] an object that subclasses `ParseResource`. Or returns `false` if object fails to save.
    def self.create(attributes = {})
      attributes = HashWithIndifferentAccess.new(attributes)
      new(attributes).save
    end

    def self.destroy_all
      all.each do |object|
        object.destroy
      end
    end

    def self.class_attributes
      @class_attributes ||= {}
    end

    def persisted?
      if id
        true
      else
        false
      end
    end

    def new?
      !persisted?
    end

    # delegate from Class method
    def resource
      self.class.resource
    end

    # create RESTful resource for the specific Parse object
    # sends requests to [base_uri]/[classname]/[objectId]
    def instance_resource
      self.class.resource["#{self.id}"]
    end

    def create
      opts = {:content_type => "application/json"}
      attrs = @unsaved_attributes.to_json
      result = self.resource.post(attrs, opts) do |resp, req, res, &block|
        
        case resp.code 
        when 400
          
          # https://www.parse.com/docs/ios/api/Classes/PFConstants.html
          error_response = JSON.parse(resp)
          pe = ParseError.new(error_response["code"]).to_array
          self.errors.add(pe[0], pe[1])
        
        else
          @attributes.merge!(JSON.parse(resp))
          @attributes.merge!(@unsaved_attributes)
          attributes = HashWithIndifferentAccess.new(attributes)
          @unsaved_attributes = {}
          create_setters_and_getters!
        end
        
        self
      end
    
      result
    end

    def save
      if valid?
        run_callbacks :save do
          new? ? create : update
        end
      else
        false
      end
      rescue false
    end


    def destroy
      self.instance_resource.delete
      @attributes = {}
      @unsaved_attributes = {}
      nil
    end

    # provides access to @attributes for getting and setting
    def attributes
      @attributes ||= self.class.class_attributes
      @attributes
    end

    def attributes=(n)
      @attributes = n
      @attributes
    end

    # aliasing for idiomatic Ruby
    def id; self.objectId rescue nil; end

    def created_at; self.createdAt; end

    def updated_at; self.updatedAt rescue nil; end

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end
