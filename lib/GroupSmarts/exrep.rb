# Hashify
# Copyright 2007, Chris Hapgood
# Derived from earlier work represented by the tree_map method in MemoryMiner.  Repackaged as a library for 
# portability across projects in the Summer of 2007.
module GroupSmarts
  module ExRep
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        include InstanceMethods
        include SmartHash
        include SmartXML
      end
      ::ActiveRecord::XmlSerializer.class_eval do
        include XmlSerializer
        alias_method_chain :serialize, :fu
        alias :to_s :serialize_with_fu
      end
    end  

    module ClassMethods
      # enumerate the instance methods that collectively generate the external representation of self.
      def exrep_methods
        [primary_key] + (content_columns.map(&:name) - protected_attributes().to_a).sort
      end
    end
    
    module InstanceMethods
      # Generate a URL that represents self.
      def exrep_url
        method = self.class.to_s.underscore + '_url'
        self.send(method, self)
      end
    end
    
    module SmartXML
    end
    
    module XmlSerializer
      # Add support for an href attribute of the root node via url method on serialzed object.  Call
      # customized add_attributes.
      def serialize_with_fu
        args = [root]
        
        args << {:xmlns=>options[:namespace]} if options[:namespace]
        args << {:type=>options[:type]} if options[:type]
        args << {:href => @record.exrep_url} if options[:href] and @record.respond_to?(:exrep_url)

        builder.tag!(*args) do
          add_attributes_with_fu
          procs = options.delete(:procs)
          add_includes { |association, records, opts| add_associations(association, records, opts) }
          options[:procs] = procs
          add_procs
        end
      end
      
      # Add support for non-propogating :with and :without options (in lieu of goofy half propogating :only 
      # and :except), and unify treatment of methods and attributes.  Find default attributes in an 
      # enumerator.
      def add_attributes_with_fu
        attribute_names = options[:methods] || (options[:enumerator] && @record.class.send(options[:enumerator])) || @record.class.respond_to?(:exrep_methods) && @record.class.exrep_methods|| @record.attribute_names
        attribute_names = Array(attribute_names).map(&:to_s)
        
        attribute_names = attribute_names + Array(options[:with]).map(&:to_s)
        attribute_names = attribute_names - Array(options[:without]).map(&:to_s)
    
        attribute_names.each do |name|
          attribute_class = @record.attribute_names.include?(name) ? ::ActiveRecord::XmlSerializer::Attribute : ::ActiveRecord::XmlSerializer::MethodAttribute
          add_tag(attribute_class.new(name, @record))
        end
      end
    end # module
    
    # Due to problems with the ActiveRecord::Base.to_xml and to_json methods' handling of collections, this 
    # module allows one to create a hash from an association collection and then apply the conversion method.
    module SmartHash
      def to_hash(options = {})
        hash = {}
    
        hash.merge!(self.direct(options))
        hash.merge!(self.associations(options))
    
        hash
      end
    
      # Returns (key,value) pairs from methods called on the top-level object.
      def direct(options = {})
        method_names = options[:methods] || (options[:enumerator] && self.class.send(options[:enumerator])) || self.class.respond_to?(:exrep_methods) && self.class.exrep_methods|| self.attribute_names
        method_names = Array(method_names).map(&:to_s)
        
        method_names = method_names + Array(options[:with]).map(&:to_s)
        method_names = method_names - Array(options[:without]).map(&:to_s)
    
        method_names.inject({}) do |h, m|
          h.merge!({m.to_s => self.send(m)}) if self.respond_to?(m.to_s)
        end
      end
    
      # Recursively invokes to_hash on named associations, passing in appropriate options.
      def associations(options = {})
        hash = {}
        # Convert include to nested hash of options.
        associations_hash = options[:include].is_a?(::Hash) ? options[:include] : Array(options[:include]).inject({}){|h,a| h[a] = {};h}
        # Iterate over associations, calling to_hash.
        associations_hash.keys.each do |association|
          opts = associations_hash[association]
          case self.class.reflect_on_association(association).macro
          when :has_many, :has_and_belongs_to_many
            hash[association] = self.send(association).map { |r| r.to_hash(opts) }
          when :has_one, :belongs_to
            hash[association] = self.send(association).to_hash(opts)
          end
        end  
        hash
      end
    end
  end # module
end # module