#!/usr/bin/ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'csv'

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

date = "#{Time.now.year}-#{Time.now.month}-#{Time.now.day}"

csvfilename = "#{project}-#{status}-issues-#{date}.csv".downcase
puts "Exporting #{status} issues for project '#{project}' to #{csvfilename}"

outfile = File.open(csvfilename, 'wb')
issues  = { } # can i lazy init a hash with first reference?
i = 0 # not required?
previous_length = -1

until issues.length == previous_length
  url = "http://drupal.org/project/issues/#{project}?text=&status=#{status}&priorities=All&categories=All&version=All&component=All&order=last_comment_timestamp&sort=desc&page=#{i.to_s}"
  doc = Nokogiri::HTML(open(url).read)
  previous_length = issues.length
  (doc/'tr').each do |item|
    if (item/'td.views-field-title').inner_html.strip != ''
      nid = ''
      (item/'td.views-field-title a').map { |link|
        nid = link['href'].gsub('/node/','').to_s
      }
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
  if issues.length > previous_length 
    puts " Page #{i.to_s}, #{issues.length} issues."
  else
    puts " No more issues found."
  end
  i += 1
end

CSV::Writer.generate(outfile) do |csv|
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
