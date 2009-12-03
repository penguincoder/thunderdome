# monkey patch plugin for subdomain restrictions
class ActiveRecord::Base
  def self.use_for_restricted_subdomains
    true
  end
end

# load up all of my prerequisites
require File.join(File.dirname(__FILE__), '..', 'lib', 'date_tools')
require File.join(File.dirname(__FILE__), '..', 'lib', 'american_date_monkey_patch')
require File.join(File.dirname(__FILE__), '..', 'lib', 'specialty_strings')

# directories containing my rails models
mdir = File.join(File.dirname(__FILE__), '..', 'app', 'models')
edir = File.join(File.dirname(__FILE__), '..', 'app', 'errands')

# base superclass, all of my models descend from this.
require File.join(mdir, 'consolo_constant.rb')

# custom async job processing engine
require File.join(mdir, 'errand.rb')
require File.join(edir, 'errand_new_site.rb')
require File.join(edir, 'errand_destroy_agency.rb')

# load every class that descends from my superclass
Dir.glob(File.join(mdir, '*.rb')).each do |fname|
  next if fname =~ /consolo_constant/i
  cmdstr = "grep -E '^class' #{fname} | grep ConsoloConstant"
  if system("#{cmdstr} > /dev/null 2>&1")
    require fname
    @@constants << File.basename(fname, ".rb").capitalize.gsub(/_(.)/) do |s|
      $1.capitalize
    end
  end
end

# sort tables on any of these columns, if they are in the table
@@sortable_columns = %w(code description name category action controller city county state year)

