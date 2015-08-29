#!/usr/bin/ruby
require 'pp'

# $outdir = "#{ENV["HOME"]}/feeds/"
$outdir = "feeds/"

# Path to platform scripts dirs
if ENV["XDG_DATA_DIRS"].nil?
    $scripts = [
        "/usr/local/share/rss_platforms",
        "/usr/share/rss_platforms"
    ]
else
    $scripts = ENV["XDG_DATA_DIRS"].split(":").map! do |str|
        str += "rss_platforms"
    end
end

# Find the supported platforms
$platforms = Hash.new
$scripts.each do |dir|
    if not File.directory? dir
        next
    end
    Dir.foreach(dir) do |platform|
        path = "#{dir}/#{platform}"
        if not File.directory? path or platform[0] == "."
            next
        end
        if not $platforms.has_key? platform
            $platforms[platform] = path
        end
    end
end

# Get the list of feeds
# It is a simple text file with a feed per line :
# `platform feed_name url`
# The platform is the set of scripts used,
# The feed_name is the name of the file to which the rss feed will be written
# The urls is the url to the first item
Content = Struct.new(:platform, :feed_name, :url, :cached)
$contents = Array.new
begin
    path = "#{ENV["XDG_CONFIG_HOME"]}/rss_feeds"
    if not File.file? path
        path = "#{ENV["HOME"]}/.rss_feeds"
    end
    file = File.new path
    while (line = file.gets)
        match = /^[[:blank:]]*([[:graph:]]+)[[:blank:]]*([[:graph:]]+)[[:blank:]]*([[:graph:]]+)/.match line
        if not match.nil?
            cnt = Content.new(match[1], match[2], match[3], match[3])
            if $platforms.has_key? cnt.platform
                $contents += [cnt]
            else
                puts "Warning, no platform for #{cnt.feed_name} (#{cnt.url}) : #{cnt.platform}"
            end
        end
    end
    file.close
rescue => err
    puts "Couldn't read rss feeds file : #{err}"
    exit
end

# Read the cached urls
begin
    if not ENV["XDG_CACHE_HOME"].nil?
        $cache = "#{ENV["XDG_CACHE_HOME"]}/rss_feeds"
    else
        $cache = "#{ENV["HOME"]}/.rss_feeds_cache"
    end
    File.open $cache do |infile|
        while (line = infile.gets)
            match = /^[[:blank:]]*([[:graph:]]+)[[:blank:]]*([[:graph:]]+)/.match line
            if not match.nil?
                id = $contents.index do |s| s.url == match[1] end
                if not id.nil?
                    $contents[id].cached = match[2]
                end
            end
        end
    end
rescue
    # Absence of cached file is not fatal
end

# Utility functions
Item = Struct.new(:url, :title, :description)

def nxt(platform, url)
    # Returns an item with the url of the next item and the title and description of this one
    output = `#{$platforms[platform]}/next "#{url}"`
    if output.empty?
        return Item.new(nil, "No Title", "No Description")
    end
    lines = output.split("\n", 3)
    if lines[0].empty?
        lines[0] = nil
    end
    case lines.size
    when 1
        return Item.new(lines[0], "No Title", "No Description")
    when 2
        return Item.new(lines[0], lines[1], "No Description")
    when 3
        return Item.new(lines[0], lines[1], lines[2])
    end
    return nil
end

def desc(cnt)
    # Returns the title and description of the content
    output = `#{$platforms[cnt.platform]}/desc "#{cnt.url}"`
    if output.empty?
        return ["No Title", "No Description"]
    end
    lines = output.split("\n", 2)
    if lines.size == 1
        return [lines[0], "No description"]
    else
        return lines
    end
end

# Main loop
$contents.each do |cnt|
    path = "#{$outdir}/#{cnt.feed_name}.xml"
    begin
        file = File.new(path, "w")
        ds = desc(cnt)
        file.puts <<END_OF_STRING
<rss version="2.0">
<channel>
<title>#{ds[0]}</title>
<link>#{cnt.url}</link>
<description>#{ds[1]}</description>

END_OF_STRING

        items = Array.new
        url = cnt.cached
        it = Item.new(cnt.cached, "Np title", "No Description")
        while not it.url.nil?
            items += [it]
            it = nxt(cnt.platform, it.url)
            items.last.title = it.title
            items.last.description = it.description
        end
        items = items.last 10
        if items.empty?
            raise "no items"
        end

        if items.size == 10
            cnt.cached = items.first.url
        end
        items.each do |item|
        file.puts <<END_OF_STRING
<item>
    <title>#{item.title}</title>
    <link>#{item.url}</link>
    <description>#{item.description}\nLink: #{item.url}</description>
</item>

END_OF_STRING
        end

        file.puts <<END_OF_STRING
</channel>
</rss>
END_OF_STRING
        file.close
    rescue => err
        puts "Warning, could not write feed for #{cnt.url} : #{err}"
    end
end

# Save new cache
begin
    file = File.new($cache, "w")
    $contents.each do |cnt|
        file.puts "#{cnt.url} #{cnt.cached}"
    end
    file.close
rescue
    # Error are not fatal
end
