require 'active_record'

class Synonym < ActiveRecord::Base
	belongs_to :venue
end
