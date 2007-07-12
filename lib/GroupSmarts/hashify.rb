# Hashify
# Copyright 2007, Chris Hapgood
# Derived from earlier work represented by the tree_map method in MemoryMiner.  Repackaged as a library for 
# portability across project in the Summer of 2007.
module GroupSmarts
  module Hashify
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        include InstanceMethods
      end
    end  
    
    module ClassMethods
      def hash_methods
        content_columns.map(&:name)
      end
    end
    
    module InstanceMethods
      def to_hash(options = {})
        hash = {}
    
        hash.merge!(self.direct(options))
        hash.merge!(self.associations(options))
    
        hash
      end
    
      # Returns (key,value) pairs from methods called on the top-level object.
      def direct(options)
        method_names = options[:methods] || (options[:enumerator] && self.class.send(options[:enumerator])) || self.class.respond_to?(:hash_methods) && self.class.hash_methods|| self.attribute_names
        method_names = Array(method_names).map(&:to_s)
    
        if options[:only]
          options.delete(:except)
          method_names = method_names & Array(options[:only]).map(&:to_s)
        elsif options[:except]
          method_names = method_names - Array(options[:except]).map(&:to_s)
        end
    
        method_names.inject({}) do |h, m|
          h.merge!({m.to_s => self.send(m)}) if self.respond_to?(m.to_s)
        end
      end
    
      # Recursively invokes to_hash on named associations, passing in appropriate options.
      def associations(options)
        hash = {}
        # Convert include to nested hash of options.
        associations_hash = options[:include].is_a?(Hash) ? options[:include] : Array(options[:include]).inject({}){|h,a| h[a] = {};h}
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