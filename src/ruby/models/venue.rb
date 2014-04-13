require 'active_record'

class Venue < ActiveRecord::Base
	has_many :gigs
end
