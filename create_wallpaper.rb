#!/usr/bin/env ruby
# frozen_string_literal: true

# Game Off 2025 Wallpaper Generator
# Creates a montage wallpaper from all downloaded game screenshots.

require 'fileutils'

INPUT_DIR = 'screenshots'
OUTPUT_FILE = 'wallpaper.png'
WALLPAPER_WIDTH = 3840
WALLPAPER_HEIGHT = 2160
ORIGINAL_TILE_WIDTH = 315
ORIGINAL_TILE_HEIGHT = 250

def main
  puts "🎨 Game Off 2025 Wallpaper Generator"
  puts "=" * 50

  # Get all image files
  image_files = Dir.glob(File.join(INPUT_DIR, '*.{png,jpg,jpeg,gif,webp}')).sort
  
  if image_files.empty?
    puts "❌ No images found in #{INPUT_DIR}/"
    exit 1
  end
  
  num_images = image_files.length
  puts "📁 Found #{num_images} images in #{INPUT_DIR}/"
  
  # Calculate optimal tile size to fit ALL images
  # Maintain original aspect ratio (315:250 = 1.26)
  aspect_ratio = ORIGINAL_TILE_WIDTH.to_f / ORIGINAL_TILE_HEIGHT
  
  # Find the tile size that fits all images
  # We need: cols * rows >= num_images
  # cols = wallpaper_width / tile_width
  # rows = wallpaper_height / tile_height
  # tile_width = aspect_ratio * tile_height
  
  # Solve for tile_height:
  # (wallpaper_width / (aspect_ratio * h)) * (wallpaper_height / h) >= num_images
  # (wallpaper_width * wallpaper_height) / (aspect_ratio * h^2) >= num_images
  # h^2 <= (wallpaper_width * wallpaper_height) / (aspect_ratio * num_images)
  
  max_tile_height = Math.sqrt((WALLPAPER_WIDTH * WALLPAPER_HEIGHT) / (aspect_ratio * num_images))
  tile_height = max_tile_height.floor
  tile_width = (tile_height * aspect_ratio).floor
  
  # Calculate grid dimensions
  cols = (WALLPAPER_WIDTH.to_f / tile_width).ceil
  rows = (WALLPAPER_HEIGHT.to_f / tile_height).ceil
  total_tiles = cols * rows
  
  # Make sure we have enough tiles for all images
  while total_tiles < num_images
    tile_height -= 1
    tile_width = (tile_height * aspect_ratio).floor
    cols = (WALLPAPER_WIDTH.to_f / tile_width).ceil
    rows = (WALLPAPER_HEIGHT.to_f / tile_height).ceil
    total_tiles = cols * rows
  end
  
  puts "📐 Tile size: #{tile_width}x#{tile_height} (scaled from #{ORIGINAL_TILE_WIDTH}x#{ORIGINAL_TILE_HEIGHT})"
  puts "📐 Grid: #{cols} columns x #{rows} rows = #{total_tiles} tiles"
  puts "📐 Output size: #{WALLPAPER_WIDTH}x#{WALLPAPER_HEIGHT}"
  
  # Create list of images, repeating only if necessary to fill remaining tiles
  tiles = image_files.dup
  remaining = total_tiles - num_images
  if remaining > 0
    remaining.times do |i|
      tiles << image_files[i % num_images]
    end
    puts "🔄 Using all #{num_images} images + repeating #{remaining} to fill grid"
  else
    puts "✅ All #{num_images} images will be used"
  end
  
  # Write tile list to temp file for ImageMagick
  tile_list_file = 'tile_list.txt'
  File.write(tile_list_file, tiles.join("\n"))
  
  puts
  puts "🔧 Creating montage with ImageMagick..."
  
  # Use ImageMagick montage command
  montage_cmd = [
    'montage',
    '@' + tile_list_file,
    '-tile', "#{cols}x#{rows}",
    '-geometry', "#{tile_width}x#{tile_height}+0+0",
    '-background', 'black',
    'temp_montage.png'
  ]
  
  puts "   Running: #{montage_cmd.join(' ')}"
  system(*montage_cmd)
  
  unless File.exist?('temp_montage.png')
    puts "❌ Montage creation failed!"
    File.delete(tile_list_file) if File.exist?(tile_list_file)
    exit 1
  end
  
  # Crop to exact wallpaper dimensions (center crop)
  crop_cmd = [
    'convert',
    'temp_montage.png',
    '-gravity', 'center',
    '-crop', "#{WALLPAPER_WIDTH}x#{WALLPAPER_HEIGHT}+0+0",
    '+repage',
    OUTPUT_FILE
  ]
  
  puts "   Running: #{crop_cmd.join(' ')}"
  system(*crop_cmd)
  
  # Cleanup
  File.delete(tile_list_file) if File.exist?(tile_list_file)
  File.delete('temp_montage.png') if File.exist?('temp_montage.png')
  
  if File.exist?(OUTPUT_FILE)
    file_size = (File.size(OUTPUT_FILE) / 1024.0 / 1024.0).round(2)
    puts
    puts "=" * 50
    puts "✅ Wallpaper created: #{OUTPUT_FILE}"
    puts "   Size: #{file_size} MB"
    puts "🎉 Done!"
  else
    puts "❌ Failed to create wallpaper"
    exit 1
  end
end

# Check for ImageMagick
def check_dependencies
  unless system('which montage > /dev/null 2>&1')
    puts "❌ ImageMagick is required but not installed."
    puts "   Install with: brew install imagemagick"
    exit 1
  end
end

check_dependencies
main
