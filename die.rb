#!/usr/bin/ruby

# @todo 

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'
require 'date'

# I'm sure there's a nicer way to provide default args than if stmts 
if !ARGV[0]
  puts "Please provide the project name as an argument, eg 'die.rb views'"
  exit
else 
  project = ARGV[0].downcase
end

if !ARGV[1]
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

until issues.length == previous_length # stop when we run out of issues
  # if the URL params were a hash it would be easier to tweak defaults than this long string 
  url = "http://drupal.org/project/issues/#{project}?text=&status=#{status}&priorities=All&categories=All&version=All&component=All&order=last_comment_timestamp&sort=desc&page=#{i.to_s}"
  doc = Nokogiri::HTML(open(url).read)
  previous_length = issues.length
  (doc/'tr').each do |item|
    if (item/'td.views-field-title').inner_html.strip != ''
      nid = '' # this shouldn't be important. I think it's here for voodoo.
      (item/'td.views-field-title a').map { |link|
        nid = link['href'].gsub('/node/','').to_s
      }
      # I want to tell it HOW to extract this information,
      # this just tells it WHAT to do, that's not smart. 
      issues[nid.to_s] = {
        'nid' => nid,
        'status' => (item/'td.views-field-sid').inner_text.strip,
        'title' => (item/'td.views-field-title').inner_text.strip,
        'priority' => (item/'td.views-field-priority').inner_text.strip,
        'category' => (item/'td.views-field-category').inner_text.strip,
        'version' => (item/'td.views-field-version').inner_text.strip,
        'component' => (item/'td.views-field-component').inner_text.strip,
        'comments' => (item/'td.views-field-comment-count').inner_text.strip,
        'updated' => (item/'td.views-field-last-comment-timestamp').inner_text.strip,
        'assigned' => (item/'td.views-field-name').inner_text.strip,
      }
    end 
  end
  if issues.length > previous_length # could lose the until and just break out here anyway.
    puts " Page #{i.to_s}, #{issues.length} issues."
  else
    puts " No more issues found."
  end
  i += 1
end

CSV::Writer.generate(outfile) do |csv|
  # again - I'd like to be saying, these are the values, this
  # is how to extract them, go do it ... Need to join the 
  # three blocks (extract info from table, csv headers,
  # csv rows) into something coherent.
  csv << [
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
  issues.each do |issue|
    csv << [ 
            issue[0],
            'http://drupal.org/node/' + issue[0],
            issue[1]['status'],
            issue[1]['title'],
            issue[1]['priority'],
            issue[1]['category'],
            issue[1]['version'],
            issue[1]['component'],
            issue[1]['comments'],
            issue[1]['updated'],
            issue[1]['assigned'],
           ]
  end
end

puts "Exported #{issues.length} issues to #{csvfilename}"
