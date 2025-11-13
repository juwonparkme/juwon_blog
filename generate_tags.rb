#!/usr/bin/env ruby
# Jekyll tag page auto-generator
# Usage: ruby generate_tags.rb

require 'fileutils'

tags_dir = File.join(Dir.pwd, 'tags')
FileUtils.mkdir_p(tags_dir) unless File.directory?(tags_dir)

all_tags = []

Dir.glob('_posts/**/*.{md,markdown}').each do |post_file|
  begin
    content = File.read(post_file)
    if content =~ /\A---\s*\n(.*?)\n---\s*\n(.*)/m
      front_matter_text = $1
      # Match tags line - can span multiple lines
      tags_match = front_matter_text.match(/^tags:\s*(.+?)(?=\n\w+:|$)/m)
      if tags_match
        tags_content = tags_match[1]
        
        # Check if it's array format: [tag1, tag2]
        if tags_content.strip.start_with?('[')
          tags_content.gsub(/^\[|\]$/, '').split(',').each do |tag_str|
            tag = tag_str.strip.gsub(/^['"]|['"]$/, '')
            all_tags << tag unless tag.empty?
          end
        # Check if it's YAML list format: - tag1\n- tag2
        elsif tags_content.include?("\n") && tags_content.strip.start_with?('-')
          tags_content.split("\n").each do |line|
            if line =~ /^[\s-]*-\s*(.+)$/
              tag = $1.strip.gsub(/^['"]|['"]$/, '')
              all_tags << tag unless tag.empty?
            end
          end
        else
          # Space-separated format (original windows-95 theme style): tag1 tag2 tag3
          tags_content.split(/\s+/).each do |tag|
            tag = tag.strip
            all_tags << tag unless tag.empty?
          end
        end
      end
    end
  rescue StandardError => e
    puts "Error processing #{post_file}: #{e.message}"
  end
end

all_tags.uniq!

puts "Found tags: #{all_tags.inspect}"

all_tags.each do |tag|
  tag_slug = tag.downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9\-]/, '')
  tag_file = File.join(tags_dir, "#{tag_slug}.html")
  
  unless File.exist?(tag_file)
    File.open(tag_file, 'w') do |f|
      f.puts "---"
      f.puts "layout: tag"
      f.puts "tag: #{tag}"
      f.puts "permalink: /tag/#{tag_slug}/"
      f.puts "---"
    end
    puts "Created: #{tag_file}"
  else
    puts "Already exists: #{tag_file}"
  end
end

puts "Tag pages generation complete!"
