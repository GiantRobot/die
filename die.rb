#!/usr/bin/ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'

module DrupalOrg

  attr_accessor :nid, :pageurl

  @baseurl = 'http://drupal.org/'
  
  # could this just be :pageurl as a custom accessor?
  def get_url(loc)
    @pageurl = 'http://drupal.org/' + loc
    return @pageurl
  end

  # @todo: cache this
  def get_page(loc)
    return Nokogiri::HTML(open(self.get_url(loc)).read)
  end
  
end

# module Drupal_Node
#
#   include Drupal_Org
#
#  def get_path
#    @path = 'node/' + @nid
#  end
#  
# end

# Issue stores details about a specific Drupal node of type Issue
class Issue

  include DrupalOrg

  attr_accessor :nid, :status, :title, :priority, :category, :version, :component, :comments, :comment_count, :last_updated, :assigned_username
  
  def initialize(parameters)
    # i'd like to either be able to throw 
    # an ID *or* a set of details at this
    @nid = parameters['nid']
  end 

  def get_url
    super(self.get_path)
  end

  # As Issue is a subclass of Drupal Nodes, this could probably be moved
  # to Drupal_Node class. Not doing that for now because I need to look at
  # how super behaves when there are multiple parent classes
  def get_path
    @path = 'node/' + @nid
  end
  
  def load_page
    @page = self.get_page('node/'+@nid)
  end 
  
  def self.from_project_issues_row(row)
    if (row/'td.views-field-title').inner_html.strip != ''
      (row/'td.views-field-title a').map { |link|
        issue        = Issue.new(link['href'].gsub('/node/','').to_s)
        # p link['href'].gsub('/node/','').to_s
        # p issue
        # but issue.nid is not set in Issue.new("123")? 
        # so i have to set it :(
        issue.nid               = link['href'].gsub('/node/','').to_s
        issue.status            = (row/'td.views-field-sid').inner_text.strip
        issue.title             = (row/'td.views-field-title').inner_text.strip
        issue.priority          = (row/'td.views-field-priority').inner_text.strip
        issue.category          = (row/'td.views-field-category').inner_text.strip
        issue.version           = (row/'td.views-field-version').inner_text.strip
        issue.component         = (row/'td.views-field-component').inner_text.strip
        issue.comment_count     = (row/'td.views-field-comment-count').inner_text.strip
        issue.last_updated      = (row/'td.views-field-last-comment-timestamp').inner_text.strip
        issue.assigned_username = (row/'td.views-field-name').inner_text.strip
        return issue
      }
    end
  end
  
  def self.csv_details_header
    [
      'Node ID',
      'URL',
      'Status',
      'Title',
      'Priority',
      'Category',
      'Version',
      'Component',
      'Comments',
      'Updated',
      'Assigned',          
     ]
  end
  
  def csv_details_row
    [
      @nid,
      self.get_url,
      @status,
      @title,
      @priority,
      @category,
      @version,
      @component,
      @comment_count,
      @last_updated,
      @assigned_username,    
    ]
  end
  
end  

# I'm sure there's a nicer way to provide default args than if stmts?
unless ARGV[0]
  puts "Please provide the project name as an argument, eg 'die.rb views'"
  exit
else 
  project = ARGV[0].downcase
end

unless ARGV[1]
  puts "Defaulting to Open issues only. (Options are: Open, All, work_it_out)"
  status = "Open"
else
  status = ARGV[1].capitalize
end

date = Date.today.strftime "%Y-%m-%d"
csvfilename = "#{project}-#{status}-issues-#{date}.csv".downcase
puts "Exporting #{status} issues for project '#{project}' to #{csvfilename}"

outfile = File.open(csvfilename, 'wb')
issues  = { } # can i lazy init a hash with first reference?
i = 0 # required?
previous_length = -1 # just needs to not match ... So could be nil here?

100.times do |i|
  # if the URL params were a hash it would be easier to tweak defaults than this long string 
  url = "http://drupal.org/project/issues/#{project}?text=&status=#{status}&priorities=All&categories=All&version=All&component=All&order=last_comment_timestamp&sort=desc&page=#{i.to_s}"
  doc = Nokogiri::HTML(open(url).read)
  previous_length = issues.length
  (doc/'tr').each do |item|
    if (item/'td.views-field-title').inner_html.strip != ''
      issue = Issue.from_project_issues_row(item)
      issues[issue.nid.to_s] = issue
    end 
  end
  if issues.length > previous_length # could lose the until and just break out here anyway.
    puts " Page #{i.to_s}, #{issues.length} issues."
  else
    puts " No more issues found."
    break
  end
end

# write the CSV out
require "csv"
if CSV.const_defined? :Reader
  # old CSV::writer style pre ruby 1.9
  CSV::Writer.generate(outfile) do |csv|
    csv << Issue.csv_details_header
    issues.each do |issue|
      csv << issue[1].csv_details_row
    end
  end
else
  # it's ruby 1.9.x
  CSV.open(outfile, 'wb') do |csv|
    csv << Issue.csv_details_header
    issues.each do |issue|
      # p issue
      csv << issue[1].csv_details_row
    end
  end
end

puts "Exported #{issues.length} issues to #{csvfilename}"
