# Hashify
# Copyright 2007, Chris Hapgood
# Derived from earlier work represented by the tree_map method in MemoryMiner.  Repackaged as a library for 
# portability across projects in the Summer of 2007.
# Updated March 2008 to work nicely with Edge Rails.
module GroupSmarts
  module ExRep
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        include InstanceMethods
      end
      ::ActiveRecord::Serialization::Serializer.class_eval do
        include Serializer
        alias_method_chain :serializable_names, :fu
        alias_method_chain :serializable_record, :fu
      end
      ::ActiveRecord::XmlSerializer.class_eval do
        include XmlSerializer
        alias_method_chain :serialize, :fu
        alias :to_s :serialize_with_fu
      end
    end  

    module ClassMethods
      # Enumerate the instance methods that collectively generate the external representation of self.
      # Override in your model.
      def exrep_methods
        [primary_key] + (content_columns.map(&:name) - protected_attributes().to_a).sort
      end
    end
    
    module InstanceMethods
      # Generate a relative path that represents self for use in href attributes.
      # Override in your model as required.
      def exrep_path
        polymorphic_path(self)
      end
    end
    
    # Enhance methods applicable to all AR serialization (to_json and to_xml)
    module Serializer
      # Add support for finding default methods/attributes in an enumerator and using
      # non-propogating :with and :without options.  Baseline attributes are determined by 
      # the enumerator, and the :with and :without options add and subtract attributes from 
      # that baseline.  Contrast this with the behavior of :only, which specifies an exclusive
      # list of attributes. 
      def serializable_names_with_fu
        names = serializable_names_without_fu if (options[:only] || options[:except])
        names ||= options[:enumerator] && @record.class.send(options[:enumerator]) 
        names ||= @record.class.respond_to?(:exrep_methods) && @record.class.exrep_methods
        names ||= @record.attribute_names - [@record.class.inheritance_column]
        
        names = names + Array(options[:with]).map(&:to_s)
        names = names - Array(options[:without]).map(&:to_s)
        
        Array(names).map(&:to_s).uniq
      end

      # Ensure the :only and :except options do not propogate (because they dominate/mask the exrep enumerator).  
      def serializable_record_with_fu
        returning(serializable_record = {}) do
          serializable_names.each { |name| serializable_record[name] = @record.send(name) }
          add_includes do |association, records, opts|
            # Ensure the :only, :except options do not propogate 
            opts.delete(:only); opts.delete(:except)
            opts.delete(:with); opts.delete(:without)
            if records.is_a?(Enumerable)
              serializable_record[association] = records.collect { |r| self.class.new(r, opts).serializable_record }
            else
              serializable_record[association] = self.class.new(records, opts).serializable_record
            end
          end
        end
      end
      
      # Convert to a simple ruby hash -not really serialization but rather a step on the way.
      def to_hash(options = {})
        ActiveRecord::Serialization::Serializer.new(self, options).serializable_record
      end      
    end
    
    module XmlSerializer
      # Add support for an href attribute of the root node via url method on serialzed object.  Call
      # customized add_attributes.  Note that the original serialize bypasses the conventional 
      # serializable_record method in favor of some custom trickery for the proc enhancement.
      def serialize_with_fu
        args = [root]
        
        args << {:xmlns=>options[:namespace]} if options[:namespace]
        args << {:type=>options[:type]} if options[:type]
        args << {:href => @record.exrep_path} if options[:href]

        builder.tag!(*args) do
          add_attributes_with_fu
          # Ensure the :with, :without and :href options do not propogate (by design)
          options.delete(:with); options.delete(:without); options.delete(:href)
          # Ensure the :only, :except options do not propogate either, because they dominate our enumerator. 
          options.delete(:only); options.delete(:except)
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
  end # module
end # module