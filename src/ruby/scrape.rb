require 'rubygems'
require 'active_record'
require 'hpricot'
require 'date'
require 'open-uri'
require 'models/gig'
require 'models/venue'
require 'models/synonym'
require 'mysql'
require 'yaml'
#require 'config'
load 'config.rb'

class RippingScraper  
  def main
    tokens = []
		
    Hpricot.scan(open("http://www.rippingrecords.com/tickets01.html")) do |t|
      tokens << t
    end
   
    @iterator = HpricotIterator.new(tokens)    
    
    while find_month
      month = extract_month
			puts "Found #{month}"
			loop do
        break if !find_entry
				entry = extract_entry
				if entry.nil? 
					puts "Shitty html"
					break
				end # Shitty html
        if entry.length < 4 then 
					next 
				end
        extra = ''
        
        #Get the date            
        entry[0] =~ /(\d+)/
        if !julian = Date.valid_civil?(month.year, month.mon, $1.to_i)
          gig_date = month
          extra += " #{entry[0]}"
        else 
          gig_date = Date.new(month.year, month.mon, $1.to_i) 
        end          
        
        #Price matching
        if entry[3].match(/\d+\.\d+[:graph:]*/)
          price = entry[3].gsub(/£/, "&pound;")
					price.strip!
        else 
          extra += entry[3] 
					extra.strip!
        end
        
        begin
					venue = find_venue(entry[2]);
					artist = entry[1].strip;
          gig = Gig.create(	:artist => artist, 
											:date => gig_date, 
											:venue => venue, 
											:price => price, 
											:extra => extra	)
					gig.save
        rescue Exception => e
          puts "Failed to write gig (#{artist} @ #{entry[2]})"
					puts e
        end
      end
    end
		puts "Saved #{Gig.find(:all).size} gigs."
  end
    
  private
	def find_venue(synonym)
		venue = nil
		syn = Synonym.find_by_synonym(synonym)
		if syn && syn.venue
			venue = syn.venue
		else
			venue = Venue.find_or_create_by_name(:name => synonym, :city => "Unknown")
			puts "Synonym to be taken care of : #{synonym}"
		end
		return venue
	end

	def extract_entry
    gig_tokens = []

		@iterator.mark

		#while t = @iterator.next
		#	puts "extracted #{t}"
		#	if start_month?(t)
		#		puts "Whoops, misplaced start of the month, let's step back"
		#		@iterator.prev
		#		return nil
		#	elsif t[0] == :text 
		#		puts "A starting place - #{t[1]}"
		#		break
		#	end
		#end
    tokens = @iterator.collect_until do |t| 
      end_event?(t) or start_event?(t) 
    end
    tokens.each do |t|    
			if start_month?(t)
				@iterator.to_mark
				return nil
			end
      if t[0] == :text 
        content = t[1].gsub(/^\s+/, "").gsub(/\s+$/, $/)
        if content.length > 0 
					#puts "Adding token #{content}"
					gig_tokens << content 
				end
      end
    end
    return gig_tokens
	end

	def find_entry
		while (token = @iterator.next)
			if start_month?(token)
				@iterator.prev
				return false
			end
			return true if start_event?(token)
		end
	end

  def extract_month
    while(t = @iterator.next)
			p "Checking " + t[0].to_s + ", contents : " + t[1];
      if (t[0] == :text && t[1] =~ /^(\w+).*(\d{4}).*$/)
				p "Found a month : " + $1
        month = HpricotIterator::MONTHS[$1.downcase]
				year = nil
        if (Date.today.mon > month)
					year = Date.today.year + 1
				else
					year = Date.today.year
				end
        date = Date.parse(year.to_s + "-" + month.to_s + "-01")
        return date
			elsif (end_month?(t)) 
				p "ERROR! End of month line"
				return
			end
    end
  end
  
  def find_month
    @iterator.next_until {|t| 
			start_month?(t) 
		}
  end
  
  def start_month?(token)
    token[0] == :comment && token[1] =~ /\s*START OF MONTH LINE\s*/
  end
  
  def end_month?(token) 
    token[0] == :comment && token[1] =~ /\s*END OF MONTH LINE\s*/
  end

	def start_event?(token)
		token[0] == :comment && token[1] =~ /\s*START OF EVENT LINE\s*/
	end

	def end_event?(token)
		token[0] == :comment && token[1] =~ /\s*END OF EVENT LINE\s*/
	end
end  

class HpricotIterator  
  MONTHS = {
    'january'  => 1, 'february' => 2, 'march'    => 3, 'april'    => 4,
    'may'      => 5, 'june'     => 6, 'july'     => 7, 'august'   => 8,
    'september'=> 9, 'october'  =>10, 'november' =>11, 'december' =>12
  }  
  
  def initialize(tokens)
    @tokens = tokens
    @counter = 0
		@mark = 0
  end

	def mark
		@mark = @counter
	end

	def to_mark 
		@counter = @mark
	end

	def back
		@counter = @counter - 1
	end  

	def prev
		@counter = @counter - 2 
	end
 
  def next
    return nil if @counter == @tokens.size
    token = @tokens[@counter]
    @counter = @counter + 1
    token
  end
  
  def next_until
    while self.next
      if yield self.peek then return true; end
    end
    false
  end

	def peek 
    @tokens[@counter] 
  end
  
  def collect_until
    tokens = []
    while !yield self.next
      tokens << self.peek
    end
    tokens
  end
end

ActiveRecord::Base.connection.execute("truncate table gigs")

scraper = RippingScraper.new
scraper.main
