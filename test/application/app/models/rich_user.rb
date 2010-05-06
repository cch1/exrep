class RichUser < ActiveRecord::Base
  set_table_name 'users'

  def self.exrep_methods
    [primary_key] + (content_columns.map(&:name) - %w(security_token)).sort
  end
end