# Hashify
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
      ::ActiveRecord::XmlSerializer.class_eval do
        include XmlSerializer
        alias_method_chain :serialize, :fu
        alias :to_s :serialize_with_fu
      end
    end  

    module ClassMethods
    end
    
    module InstanceMethods
      # Generate a relative path that represents self for use in href attributes.
      # Override in your model as required.
      def exrep_path
        polymorphic_path(self)
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
      
        # Unify specification of methods and attributes.
        def add_attributes_with_fu
          serializable_names_with_fu.each do |name|
            attribute_class = @record.attribute_names.include?(name) ? ::ActiveRecord::XmlSerializer::Attribute : ::ActiveRecord::XmlSerializer::MethodAttribute
            add_tag(attribute_class.new(name, @record))
          end
        end
      end
    end # module
  end # module
end # module