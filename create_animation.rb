#!/usr/bin/env ruby
# frozen_string_literal: true

# Game Off 2025 Animation Generator
# Creates an animated GIF from all downloaded game screenshots.

require 'fileutils'

INPUT_DIR = 'screenshots'
OUTPUT_FILE = 'animation.gif'
FRAME_DELAY = 66 # ImageMagick uses centiseconds (66 = 660ms ≈ 666ms)

def main
  puts "🎬 Game Off 2025 Animation Generator"
  puts "=" * 50

  # Get all image files, sorted by rank
  image_files = Dir.glob(File.join(INPUT_DIR, '*.{png,jpg,jpeg,gif,webp}')).sort_by do |f|
    # Extract rank number from filename (e.g., "1-evaw.png" -> 1)
    File.basename(f).split('-').first.to_i
  end
  
  if image_files.empty?
    puts "❌ No images found in #{INPUT_DIR}/"
    exit 1
  end
  
  num_images = image_files.length
  puts "📁 Found #{num_images} images in #{INPUT_DIR}/"
  puts "⏱️  Frame delay: #{FRAME_DELAY * 10}ms per frame"
  puts "⏱️  Total duration: ~#{(num_images * FRAME_DELAY * 10 / 1000.0).round(1)} seconds"
  
  # Write image list to temp file
  image_list_file = 'image_list.txt'
  File.write(image_list_file, image_files.join("\n"))
  
  puts
  puts "🔧 Creating animated GIF with ImageMagick..."
  puts "   This may take a while..."
  
  # Use ImageMagick convert command
  # -delay: time between frames in centiseconds (1/100th of a second)
  # -loop: 0 = infinite loop
  # -resize: optional, to reduce file size
  convert_cmd = [
    'convert',
    '-delay', FRAME_DELAY.to_s,
    '-loop', '0',
    '@' + image_list_file,
    '-coalesce',
    OUTPUT_FILE
  ]
  
  puts "   Running: #{convert_cmd.join(' ')}"
  system(*convert_cmd)
  
  # Cleanup
  File.delete(image_list_file) if File.exist?(image_list_file)
  
  if File.exist?(OUTPUT_FILE)
    file_size = (File.size(OUTPUT_FILE) / 1024.0 / 1024.0).round(2)
    puts
    puts "=" * 50
    puts "✅ Animation created: #{OUTPUT_FILE}"
    puts "   Size: #{file_size} MB"
    puts "   Frames: #{num_images}"
    puts "🎉 Done!"
  else
    puts "❌ Failed to create animation"
    exit 1
  end
end

# Check for ImageMagick
def check_dependencies
  unless system('which convert > /dev/null 2>&1')
    puts "❌ ImageMagick is required but not installed."
    puts "   Install with: brew install imagemagick"
    exit 1
  end
end

check_dependencies
main
