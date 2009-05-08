# Hashify -> ExRep
# Copyright 2007, Chris Hapgood
# Derived from earlier work represented by the tree_map method in MemoryMiner.  Repackaged as a library for 
# portability across projects in the Summer of 2007.
# Updated March 2008 to work nicely with Edge Rails.
# Updated November 2008 to be more modular and work with Edge Rails (2.2 and later).
module Hapgood
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
    end  

    module ClassMethods
      # Enumerate the instance methods that collectively generate the external representation of self.
      # Override in your model.
      def exrep_methods
        acc = (content_columns.map(&:name) & accessible_attributes.to_a) - protected_attributes().to_a
        [primary_key] + acc.sort        
      end
    end
    
    module InstanceMethods
    end
    
    # Enhance methods applicable to all AR serialization
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
          # Ensure the :with, :without and :href options do not propogate (by design)
          options.delete(:with); options.delete(:without)
          # Ensure the :only, :except options do not propogate either, because they dominate our enumerator. 
          options.delete(:only); options.delete(:except)
          add_includes do |association, records, opts|
            if records.is_a?(Enumerable)
              serializable_record[association] = records.collect { |r| self.class.new(r, opts).serializable_record }
            else
              serializable_record[association] = self.class.new(records, opts).serializable_record
            end
          end
        end
      end
    end # module
  end # module
end # module