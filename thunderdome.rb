#!/usr/bin/env ruby

%w{ rubygems sinatra mysql active_record yaml haml sass }.each do |lib|
  require lib
end

configure do
  # add your models into this variable in your initialization file
  @@constants = []
  # add the columns you want to search on into this variable
  @@sortable_columns = []
  
  # load up what you want to do in the app
  init_file = File.join(File.dirname(__FILE__), 'one_man.rb')
  require init_file if File.exists?(init_file)
  
  # connect to the database
  begin
    dbf = File.join(File.dirname(__FILE__), 'config', 'database.yml')
    dbconfig = YAML::load_file(dbf)[Sinatra::Application.environment.to_s]
    ActiveRecord::Base.establish_connection(dbconfig)
  rescue => exception
    $stderr.puts "There was a problem connecting to the database:"
    $stderr.puts "* #{exception.message}"
    exception.backtrace.each do |msg|
      $stderr.puts "-> #{msg}"
    end
    exit 1
  end
  
  @@constants.sort!
end

configure :development do
  set :logging, true
  ActiveRecord::Base.logger = Logger.new($stderr)
end

configure :production do
  log = File.new(File.join(File.dirname(__FILE__), "thunderdome.log"), "a")
  $stdout.reopen(log)
  $stderr.reopen(log)
  ActiveRecord::Base.logger = Logger.new(log)
end

get '/' do
  haml :index
end

get '/stylesheet.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :stylesheet
end

before do
  if params[:klass] and !@@constants.include? params[:klass]
    raise "Bad Constant!"
  else
    true
  end
end

helpers do
  def constant_form
    haml :constant_form
  end
  def constant_url(pagenum)
    "/#{params[:klass]}/#{pagenum.to_i}?q=#{params[:q]}"
  end
end

def all_booleans_to_false
  @constant.attributes.keys.each do |key|
    col = @constant.column_for_attribute(key)
    next unless col.type == :boolean
    @constant.send("#{key}=", false)
  end
end

get '/:klass/edit/:id' do
  @klass = params[:klass].constantize
  @constant = @klass.find params[:id]
  haml :edit
end

put '/:klass/edit/:id' do
  @klass = params[:klass].constantize
  @constant = @klass.find params[:id]
  all_booleans_to_false
  params[:constant].each do |name, value| 
    params[:constant][name] = value.to_date if name =~ /_date$/
  end
  
  @constant.attributes = params[:constant]
  if @constant.save
    redirect "/#{params[:klass]}/#{params[:page].to_i}?q=#{params[:q]}"
  else
    haml :edit
  end
end

get '/:klass/new' do
  @klass = params[:klass].constantize
  @constant = @klass.new
  haml :edit
end

post '/:klass/new' do
  @klass = params[:klass].constantize
  @constant = @klass.new
  all_booleans_to_false
  @constant.attributes = params[:constant]
  if @constant.save
    redirect "/#{params[:klass]}/#{params[:page].to_i}?q=#{params[:q]}"
  else
    haml :edit
  end
end

get '/:klass/:page' do
  @klass = params[:klass].constantize
  conds, vars = [], {}
  if params[:q] and !params[:q].to_s.empty?
    vars[:q] = "%#{params[:q]}%"
    cols = @klass.columns.collect(&:name)
    @@sortable_columns.each do |col|
      conds << "#{col} LIKE :q" if cols.include? col
    end
  end
  @max_pages = (@klass.count(:conditions => [ conds.join(' OR '), vars ]) / 100).ceil
  page_order = @klass.respond_to?(:custom_order) ? @klass.custom_order : 'id ASC'
  @constants = @klass.find :all,
    :limit => 100,
    :order => page_order,
    :offset => (params[:page].to_i * 100),
    :conditions => [ conds.join(' OR '), vars ]
  haml :show
end

delete '/:klass/:id' do
  @klass = params[:klass].constantize
  @constant = @klass.find params[:id]
  @constant.destroy
  redirect "/#{params[:klass]}/#{params[:page].to_i}?q=#{params[:q]}"
end

use_in_file_templates!

__END__

@@ layout
%html
  %head
    %title ThunderDome
    %link{ :rel => 'stylesheet', :href => '/stylesheet.css' }
  %body
    = yield

@@ index
#header
  %h1
    Welcome to the ThunderDome!
    %span.version== The Dos!

#content
  %ol
    - @@constants.each do |c|
      %li
        %a{ :href => "/#{c}/0" }
          = c

@@ show
#header
  %h1= params[:klass].pluralize

#content
  %div#navigation
    %a{ :href => '/', :title => 'Home' } Home
    |
    %a{ :href => "new?page=#{params[:page].to_i}&q=#{params[:q]}" }== New #{params[:klass]}
    - if @max_pages > 0
      |
      Jump to page:
      - if params[:page].to_i > 0
        %a{ :href => constant_url(0) } First
        |
      - if params[:page].to_i > 1
        %a{ :href => constant_url(params[:page].to_i - 1) } Previous
        |
      %select{ :id => 'pagenum' }
        - (0..@max_pages).each do |page_num|
          - if page_num == params[:page].to_i
            %option{ :value => page_num, :selected => 'selected' }= page_num
          - else
            %option{ :value => page_num }= page_num
      %form{ :method => 'GET' }
        %input{ :type => 'hidden', :name => 'q', :value => params[:q] }
        %button{ :onclick => 'this.form.action = "/' + params[:klass] + '/" + document.getElementById("pagenum").value; this.form.submit(); return false' } Go
      - if params[:page].to_i < @max_pages - 1
        |
        %a{ :href => constant_url(params[:page].to_i + 1) } Next
      - if params[:page].to_i < @max_pages
        |
        %a{ :href => constant_url(@max_pages) } Last
    |
    %form{ :method => 'GET', :action => "/#{params[:klass]}/#{params[:page]}" }
      %input{ :type => 'text', :name => 'q', :value => params[:q] }
      %button{ :onclick => 'this.form.submit(); return false' } Filter
    %form{ :method => 'GET', :action => "/#{params[:klass]}/0" }
      %button{ :onclick => 'this.form.submit(); return false' } Reset
  
  - unless @constants.nil? or @constants.empty?
    - join_keys = []
    - parents = {}
    - @constants.first.class.reflect_on_all_associations.select { |x| x.macro == :belongs_to }.each { |x| join_keys << [(x.options[:foreign_key] || "#{x.name}_id"), (x.options[:class_name] || x.name.to_s.camelize)] ; parents[join_keys.last.last] = [] }
    - join_keys = join_keys.sort_by { |x| x.first }
    - sorted_keys = (@constants.first.attributes.keys.sort rescue []).reject! { |x| x == 'id' or join_keys.any? { |y| y.first == x } }
    %table.collectionList{ :cellspacing => 0 }
      %tr
        %th{ :width => "45px" } &nbsp;
        - join_keys.each do |jk|
          %th= jk.first
        - sorted_keys.each do |field|
          %th= field
      - @constants.each_with_index do |c, idx|
        %tr{ :class => (idx % 2 == 0 ? 'even' : 'odd') }
          %td
            %a{ :href => "/#{params[:klass]}/edit/#{c.id}?page=#{params[:page].to_i}&q=#{params[:q]}" }
              %img{ :src => '/images/document-save.png' }
            %a{ :onclick => "if (confirm('Are you sure you want to delete this entry?')) { var f = document.createElement('form'); f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href;var m = document.createElement('input'); m.setAttribute('type', 'hidden'); m.setAttribute('name', '_method'); m.setAttribute('value', 'delete'); f.appendChild(m);f.submit(); };return false;", :href => "/#{params[:klass]}/#{c.id}?page=#{params[:page]}&q=#{params[:q]}" }
              %img{ :src => '/images/user-trash.png' }
          - join_keys.each do |jk|
            %td
              - id = c.send(jk[0])
              %abbr{ :title => ((parents[jk[1]][id] ||= jk[1].constantize.find(id)) rescue 'NOTFOUND') }= id
          - sorted_keys.each do |field|
            %td= c.send(field)

@@ edit
- unless @constant.errors.empty?
  #errorExplanation
    %p The model could not be saved:
    %ul
      - @constant.errors.each_full do |msg|
        %li= msg

#header
  %h1== #{@constant.new_record? ? 'Creating' : 'Editing'} #{@klass}

#content
  #navigation
    %a{ :href => '/' } Home
    |
    %a{ :href => constant_url(params[:page]) }= params[:klass].pluralize
  
  - if @constant.new_record?
    %form{ :action => "/#{params[:klass]}/new", :method => 'POST' }
      = constant_form
  - else
    %form{ :action => "/#{params[:klass]}/edit/#{@constant.id}", :method => 'pOST' }
      %input{ :type => 'hidden', :name => '_method', :value => 'PUT' }
      = constant_form

@@ constant_form
%input{ :type => 'hidden', :name => 'page', :value => params[:page].to_i }
%input{ :type => 'hidden', :name => 'q', :value => params[:q] }
%table{ :cellspacing => 0 }
  - join_keys = []
  - @constant.class.reflect_on_all_associations.select{|x| x.macro == :belongs_to}.each do |association|
    - column = association.options[:foreign_key] || "#{association.name}_id"
    - join_keys << column
    - kls = (association.options[:class_name] || association.name.to_s.camelize).constantize
    %tr
      %td{ :width => '25%', :align => 'right' }
        %label{ :for => "constant[#{column}]" }= kls
      %td
        %select{ :name => "constant[#{column}]", :id => "constant[#{column}]" }
          - (kls.for_select(true) rescue kls.for_select).each do |fkname, fkid|
            - if @constant.send(column).to_s == fkid
              %option{ :value => fkid, :selected => 'selected' }= fkname
            - else
              %option{ :value => fkid }= fkname
  - @constant.attributes.keys.sort.each do |key|
    - next if key == 'id' or join_keys.include? key
    %tr
      %td{ :width => '25%', :align => 'right' }
        %label{ :for => "constant[#{key}]" }= key
      %td
        - col = @constant.column_for_attribute(key)
        - if col.type == :boolean
          %input{ :type => 'checkbox', :name => "constant[#{key}]", :id => "constant[#{key}]", :checked => @constant.send("#{key}?"), :value => '1' }
        - elsif col.type == :date
          %input{ :type => 'date', :name => "constant[#{key}]", :id => "constant[#{key}]", :value => @constant.send(key) }
        - elsif col.type == :text
          %textarea{ :name => "constant[#{key}]", :id => "constant[#{key}]", :rows => 10, :cols => 50 }= @constant.send(key)
        - else
          - flen = col.limit.nil? ? 30 : col.limit
          %input{ :type => 'text', :size => (flen > 50 ? 50 : flen), :maxsize => flen, :name => "constant[#{key}]", :id => "constant[#{key}]", :value => @constant.send(key) }
%input{ :type => 'submit', :value => 'Save' }

@@ stylesheet
body
  margin: 0
  margin-bottom: 25px
  padding: 0
  background-color: #f0f0f0
  font:
    family: "Lucida Grande", "Bitstream Vera Sans", "Verdana"
    size: 12px
  color: #333

#content
  background-color: white
  border: 3px solid #aaa
  border-top: none
  width: 90%
  margin-left: auto
  margin-right: auto
  margin-top: 15px
  padding: 5px

#navigation
  margin: 10px 25px
  form
    display: inline

ol
  margin-left: 25px

li
  &:selected
    background: #FCC

a
  color: #03c
  &:hover
    background-color: #03c
    color: white
    text-decoration: none
  img
    text-decoration: none
    border: none
    vertical-align: text-bottom

#header
  margin-top: 10px
  padding-left: 75px
  padding-right: 30px
  h1
    margin: 0
  .version
    color: #888
    font-size: 16px

.even
  background-color: #bbbbbb

.odd
  background-color: #dddddd

.collectionList
  padding: 2px
  width: 100%
  font-size: 12px
  th
    text-align: center
    border-bottom: 2px solid #aaa
  td
    padding: 5px
  tr:hover
    background-color: #fcffa2

#errorExplanation {
  padding: 10px
  margin: 10px 0px
  border: 2px solid #aaa
  font-style: italic
  background-color: #d28f8f
  color: #8b0000
