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
      ::ActiveRecord::Serialization::Serializer.class_eval do
        include Serializer
        alias_method_chain :serializable_names, :fu
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
    
    # Enhance methods applicable to all AR serialization (to_json and to_xml)
    module Serializer
      # Add support for finding default methods/attributes in an enumerator and using
      # non-propogating :with and :without options.  Baseline attributes are determined by 
      # the enumerator, and the with and without options add and subtract attributes from 
      # that baseline.  Contrast this with the behavior of :only, which specifies the only
      # attributes to appear. 
      def serializable_names_with_fu
        # TODO Add backwards compatibility with existing RoR :only and :except options.
#        names = serializable_names_without_fu if (options[:only] || options[:except])
        names ||= options[:enumerator] && @record.class.send(options[:enumerator]) 
        names ||= @record.class.respond_to?(:exrep_methods) && @record.class.exrep_methods
        names ||= @record.attribute_names - [@record.class.inheritance_column]
        
        names = names + Array(options[:with]).map(&:to_s)
        names = names - Array(options[:without]).map(&:to_s)
        
        Array(names).map(&:to_s).uniq
      end
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
          # Ensure the with and without options do not propogate
          options.delete(:with); options.delete(:without)
          procs = options.delete(:procs)
          add_includes { |association, records, opts| add_associations(association, records, opts) }
          options[:procs] = procs
          add_procs
          yield builder if block_given?
        end
      end
      
      # Unify specification of methods and attributes.
      def add_attributes_with_fu
        serializable_names_with_fu.each do |name|
          attribute_class = @record.attribute_names.include?(name) ? ::ActiveRecord::XmlSerializer::Attribute : ::ActiveRecord::XmlSerializer::MethodAttribute
          add_tag(attribute_class.new(name, @record))
        end
      end
    end # module
    
    module SmartHash
      # Convert to a simple ruby hash -not really serialization but rather a step on the way.
      def to_hash(options = {})
        ActiveRecord::Serialization::Serializer.new(self, options).serializable_record
      end
    end # module
  end # module
end # module