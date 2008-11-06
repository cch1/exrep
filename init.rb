require 'hapgood/exrep'
require 'hapgood/csv_serializer'
ActiveRecord::Base.send(:include, Hapgood::ExRep)