#!/usr/bin/env ruby
# frozen_string_literal: true

# Game Off 2025 Screenshot Downloader
# Downloads all game screenshots from the itch.io Game Off 2025 results page.

require 'net/http'
require 'uri'
require 'nokogiri'
require 'fileutils'
require 'openssl'

BASE_URL = 'https://itch.io/jam/game-off-2025/results'
OUTPUT_DIR = 'screenshots'
USER_AGENT = 'GameOff2025ScreenshotDownloader/1.0 (https://github.com/leereilly; polite bot)'
REQUEST_DELAY = 1.5 # seconds between page requests
DOWNLOAD_DELAY = 0.5 # seconds between image downloads

def fetch_page(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.open_timeout = 10
  http.read_timeout = 30

  request = Net::HTTP::Get.new(uri.request_uri)
  request['User-Agent'] = USER_AGENT
  request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'

  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    response.body
  else
    puts "  ⚠️  Failed to fetch #{url}: #{response.code} #{response.message}"
    nil
  end
rescue StandardError => e
  puts "  ⚠️  Error fetching #{url}: #{e.message}"
  nil
end

def download_image(url, filepath)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == 'https')
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.open_timeout = 10
  http.read_timeout = 30

  request = Net::HTTP::Get.new(uri.request_uri)
  request['User-Agent'] = USER_AGENT

  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    File.open(filepath, 'wb') { |f| f.write(response.body) }
    true
  else
    puts "    ⚠️  Failed to download image: #{response.code}"
    false
  end
rescue StandardError => e
  puts "    ⚠️  Error downloading image: #{e.message}"
  false
end

def sanitize_filename(name)
  # Convert to lowercase
  filename = name.downcase
  # Replace spaces and punctuation with hyphens
  filename = filename.gsub(/[\s\p{P}]+/, '-')
  # Strip non-alphanumeric characters except hyphens
  filename = filename.gsub(/[^a-z0-9\-]/, '')
  # Collapse multiple hyphens into one
  filename = filename.gsub(/-+/, '-')
  # Remove leading/trailing hyphens
  filename = filename.gsub(/^-|-$/, '')
  filename
end

def extract_extension(url)
  # Get the path part of the URL and extract extension
  path = URI.parse(url).path
  ext = File.extname(path).downcase
  # Clean up any query params that might be attached
  ext = ext.split('?').first
  # Default to .png if no valid extension found
  valid_extensions = %w[.png .jpg .jpeg .gif .webp]
  valid_extensions.include?(ext) ? ext : '.png'
end

def find_next_page(doc, current_url)
  # Look for pagination links
  next_link = doc.at_css('a.next_page, a[rel="next"], .pager a.next')
  
  # Also try finding by text content
  next_link ||= doc.css('.pager a, .pagination a').find { |a| a.text.strip =~ /next|›|»/i }
  
  return nil unless next_link
  
  href = next_link['href']
  return nil if href.nil? || href.empty?
  
  # Make absolute URL if relative
  if href.start_with?('/')
    uri = URI.parse(current_url)
    "#{uri.scheme}://#{uri.host}#{href}"
  elsif href.start_with?('http')
    href
  else
    # Relative path
    base_uri = URI.parse(current_url)
    base_uri.merge(href).to_s
  end
end

def extract_games(doc)
  games = []
  
  # itch.io jam results typically have game entries with rank info
  # Look for ranked game entries
  doc.css('.game_rank, .ranked_game, [data-game_id]').each do |entry|
    game = extract_game_from_entry(entry)
    games << game if game
  end
  
  # Alternative: look for game cells in jam results
  if games.empty?
    doc.css('.jam_game, .game_cell, .game_thumb').each_with_index do |entry, idx|
      game = extract_game_from_cell(entry, idx + 1)
      games << game if game
    end
  end
  
  # Another pattern: look for results with explicit ranks
  if games.empty?
    doc.css('.result, .entry').each do |entry|
      game = extract_game_from_result(entry)
      games << game if game
    end
  end
  
  games
end

def extract_game_from_entry(entry)
  # Try to find rank/placement
  rank_el = entry.at_css('.rank, .placement, .game_rank_number, .rank_value')
  rank = rank_el&.text&.strip&.gsub(/[^\d]/, '')&.to_i
  
  # Find game title
  title_el = entry.at_css('.title, .game_title, .name a, h3 a, h2 a, a.title')
  title = title_el&.text&.strip
  
  # Find screenshot/thumbnail
  img = entry.at_css('img.thumb, img.game_thumb, .thumb img, .screenshot img, img')
  img_url = img&.[]('data-lazy_src') || img&.[]('data-src') || img&.[]('src')
  
  return nil unless rank && rank > 0 && title && !title.empty? && img_url
  
  { rank: rank, title: title, image_url: make_absolute_url(img_url) }
end

def extract_game_from_cell(entry, fallback_rank)
  # Find game title
  title_el = entry.at_css('.title, .game_title, .name, a.title, a.game_link')
  title = title_el&.text&.strip
  
  # Try to get rank from parent or sibling
  rank_el = entry.at_css('.rank, .placement') || entry.parent&.at_css('.rank')
  rank = rank_el&.text&.strip&.gsub(/[^\d]/, '')&.to_i || fallback_rank
  
  # Find screenshot
  img = entry.at_css('img')
  img_url = img&.[]('data-lazy_src') || img&.[]('data-src') || img&.[]('src')
  
  return nil unless title && !title.empty? && img_url
  
  { rank: rank, title: title, image_url: make_absolute_url(img_url) }
end

def extract_game_from_result(entry)
  # Look for rank number in text or attribute
  rank_text = entry.at_css('.rank, .place, [class*="rank"]')&.text
  rank = rank_text&.gsub(/[^\d]/, '')&.to_i if rank_text
  
  # Get title
  title = entry.at_css('.title, .name, h3, h2')&.text&.strip
  
  # Get image
  img = entry.at_css('img')
  img_url = img&.[]('data-lazy_src') || img&.[]('data-src') || img&.[]('src')
  
  return nil unless rank && rank > 0 && title && img_url
  
  { rank: rank, title: title, image_url: make_absolute_url(img_url) }
end

def make_absolute_url(url)
  return url if url.start_with?('http')
  return "https:#{url}" if url.start_with?('//')
  "https://itch.io#{url}"
end

def process_page(doc, page_num)
  games = []
  
  # The itch.io jam results page structure
  # Each game entry in results has a rank and game info
  doc.css('.game_cell_wrapper, .jam_game_cell').each do |wrapper|
    # Get the rank from the ranked_game_cell or similar parent
    rank_container = wrapper.at_css('.rank_column, .game_rank')
    rank_text = rank_container&.text&.strip
    rank = rank_text&.scan(/\d+/)&.first&.to_i if rank_text
    
    # Get game info
    game_cell = wrapper.at_css('.game_cell, .game_thumb')
    next unless game_cell
    
    title_el = game_cell.at_css('.title, .game_title, a.title')
    title = title_el&.text&.strip
    
    # Get the cover/screenshot image
    img = game_cell.at_css('.game_thumb img, img.thumb, .lazy_loaded, img')
    img_url = img&.[]('data-lazy_src') || img&.[]('data-background_image') || img&.[]('src')
    
    if rank && title && img_url
      games << { rank: rank, title: title, image_url: make_absolute_url(img_url) }
    end
  end
  
  # Alternative structure: look for individual ranked entries
  if games.empty?
    doc.css('[class*="ranked"]').each do |entry|
      rank_match = entry.text.match(/^#?(\d+)/)
      rank = rank_match[1].to_i if rank_match
      
      title = entry.at_css('.title, a')&.text&.strip
      img = entry.at_css('img')
      img_url = img&.[]('src') if img
      
      if rank && title && img_url
        games << { rank: rank, title: title, image_url: make_absolute_url(img_url) }
      end
    end
  end
  
  # Try a more generic approach for itch.io
  if games.empty?
    # Look for game entries with explicit structure
    doc.css('.game_grid_widget .game_cell, .game_browser .game_cell').each_with_index do |cell, idx|
      title = cell.at_css('.title')&.text&.strip
      img = cell.at_css('img, .thumb')
      img_url = img&.[]('data-background_image') || img&.[]('src')
      
      # Calculate rank based on page
      rank = ((page_num - 1) * 20) + idx + 1
      
      if title && img_url
        games << { rank: rank, title: title, image_url: make_absolute_url(img_url) }
      end
    end
  end
  
  games
end

def parse_itch_results(doc, page_num)
  games = []
  
  # itch.io jam results page - games are wrapped in div.game_rank
  doc.css('div.game_rank').each do |wrapper|
    # Get the game_summary inside
    summary = wrapper.at_css('.game_summary')
    next unless summary
    
    # Get the title from h2 > a
    title_el = summary.at_css('h2 a')
    title = title_el&.text&.strip
    
    # Get the rank from "Ranked Xst/nd/rd/th" - it's in strong.ordinal_rank
    rank_el = summary.at_css('strong.ordinal_rank')
    rank_text = rank_el&.text&.strip
    rank = rank_text&.gsub(/[^\d]/, '')&.to_i if rank_text
    
    # If not found, try regex on the whole text
    if !rank || rank == 0
      rank_match = summary.text.match(/Ranked\s+(\d+)(?:st|nd|rd|th)/i)
      rank = rank_match[1].to_i if rank_match
    end
    
    # The image is in img.game_thumb with src or data-lazy_src
    img_url = nil
    
    # Look for img.game_thumb
    img = wrapper.at_css('img.game_thumb')
    if img
      img_url = img['src'] || img['data-lazy_src']
    end
    
    # Fallback: any img in the wrapper
    if !img_url
      img = wrapper.at_css('img')
      img_url = img&.[]('src') || img&.[]('data-lazy_src')
    end
    
    if rank && rank > 0 && title && img_url
      games << { rank: rank, title: title, image_url: make_absolute_url(img_url) }
    elsif rank && rank > 0 && title
      puts "    ⚠️  No image found for #{title} (rank #{rank})"
    end
  end
  
  games
end

def main
  puts "🎮 Game Off 2025 Screenshot Downloader"
  puts "=" * 50
  
  # Create output directory
  FileUtils.mkdir_p(OUTPUT_DIR)
  puts "📁 Output directory: #{OUTPUT_DIR}/"
  puts
  
  current_url = BASE_URL
  page_num = 1
  total_downloaded = 0
  total_skipped = 0
  total_failed = 0
  all_games = []
  
  loop do
    puts "📄 Fetching page #{page_num}: #{current_url}"
    
    html = fetch_page(current_url)
    break unless html
    
    doc = Nokogiri::HTML(html)
    
    # Parse games from this page
    games = parse_itch_results(doc, page_num)
    games = process_page(doc, page_num) if games.empty?
    games = extract_games(doc) if games.empty?
    
    if games.empty?
      puts "  ℹ️  No games found on this page"
      puts "  Debug: Page title = #{doc.at_css('title')&.text}"
    else
      puts "  ✅ Found #{games.length} games on page #{page_num}"
    end
    
    games.each do |game|
      rank = game[:rank]
      title = game[:title]
      img_url = game[:image_url]
      
      # Create filename
      safe_name = sanitize_filename(title)
      extension = extract_extension(img_url)
      filename = "#{rank}-#{safe_name}#{extension}"
      filepath = File.join(OUTPUT_DIR, filename)
      
      print "  #{rank}. #{title} -> #{filename}"
      
      if File.exist?(filepath)
        puts " [SKIPPED - exists]"
        total_skipped += 1
      else
        sleep(DOWNLOAD_DELAY)
        if download_image(img_url, filepath)
          puts " [OK]"
          total_downloaded += 1
        else
          puts " [FAILED]"
          total_failed += 1
        end
      end
      
      all_games << game
    end
    
    # Find next page
    next_url = find_next_page(doc, current_url)
    
    if next_url && next_url != current_url
      current_url = next_url
      page_num += 1
      puts
      sleep(REQUEST_DELAY)
    else
      puts
      puts "📑 No more pages found."
      break
    end
  end
  
  puts
  puts "=" * 50
  puts "📊 Summary:"
  puts "   Total games found: #{all_games.length}"
  puts "   Downloaded: #{total_downloaded}"
  puts "   Skipped (existing): #{total_skipped}"
  puts "   Failed: #{total_failed}"
  puts "🎉 Done!"
end

# Run the script
main if __FILE__ == $PROGRAM_NAME
