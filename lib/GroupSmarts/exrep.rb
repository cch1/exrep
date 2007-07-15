# Hashify
# Copyright 2007, Chris Hapgood
# Derived from earlier work represented by the tree_map method in MemoryMiner.  Repackaged as a library for 
# portability across project in the Summer of 2007.
module GroupSmarts
  module ExRep
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        include Hash
        include XML
      end
      ::ActiveRecord::XmlSerializer.class_eval do
        include XmlSerializer
        alias_method_chain :serialize, :fu
        alias :to_s :serialize_with_fu
      end
    end  

    module ClassMethods
      def exrep_methods
        [primary_key] + content_columns.map(&:name).sort
      end
    end
    
    module XML
      def xto_xml(options)
        serializer = XmlSerializer.new(self, options)
        serializer.builder.tag!(self.class.to_s.underscore, root_tag_options) do
          serializer.add_attributes
          serializer.add_includes
          serializer.add_procs
          yield serializer.builder if block_given?
        end
      end
    end
    
    module XmlSerializer
      def serialize_with_fu
        print "serialize"
        args = [root]
        
        args << {:xmlns=>options[:namespace]} if options[:namespace]
        args << {:type=>options[:type]} if options[:type]
        args << {:href => @record.url} if options[:href] and @record.respond_to?(:url)
        print args
  
        builder.tag!(*args) do
          add_attributes
          add_includes
          add_procs
          yield builder if block_given?
        end
#        serialize_without_fu
      end
    end
    
    module Hash
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