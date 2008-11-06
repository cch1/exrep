require 'csv'

module ActiveRecord #:nodoc:
  module Serialization
    # Builds an CSV document to represent the model. Some configuration is
    # available through +options+. However more complicated cases should
    # override ActiveRecord::Base#to_csv.
    def to_csv(options = {}, &block)
      CsvSerializer.new(self, options).to_s
    end
  end

  class CsvSerializer < ActiveRecord::Serialization::Serializer #:nodoc:
    def serialize
      buffer = options[:buffer] || String.new
      # We can't just grab serializable_record.values because ordering must match header
      src = serializable_names.inject([]) {|memo, a| memo << serializable_record[a]}
      CSV.generate_row(src, src.size, buffer)
      buffer
    end
  end  
end

class Array
  def to_csv(options = {})
    raise "Not all elements respond to to_csv" unless all? { |e| e.respond_to? :to_csv }
    raise "Array is not homogeneous" unless all? {|e| e.kind_of? first.class }
    
    options[:buffer] ||= String.new
    CSV::Writer.generate(options[:buffer]) do |csv|
      unless options[:skip_header]
        if first.kind_of?(ActiveRecord::Base)
          keys = ActiveRecord::CsvSerializer.new(first, options).serializable_names
        else
          keys = first.keys
        end
        csv << keys
      end
      each do |element|
        element.to_csv(options)
      end
    end
    options[:buffer]
  end
end