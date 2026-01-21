<img
  src="animation.gif"
  alt="Game Off screenshots downloader animation"
  align="right"
  width="160"
  style="margin: 10px;"
/>

These script pulls down all of the cover images for submissions to the [2025 Game Off](https://itch.io/jam/game-off-2025) and creates (1) a wallpaper montage and (2) animated GIF of them.

Written with GitHub Copilot Agent + Claude Opus 4.5. Original prompts below for posterity / learning `<3`

 ❯ [Original GitHub Copilot Prompts to download images](#-original-github-copilot-prompts-to-download-images-copilot) · [script](download_screenshots.rb)<br>
 ❯ [Original GitHub Copilot Prompts to create a montage wallpaper](#-original-github-copilot-prompts-to-create-a-montage-wallpaper-copilot) · [script](create_wallpaper.rb)<br>
 ❯ [Original GitHub Copilot Prompts to make an animated GIF](#-original-github-copilot-prompts-to-make-an-animated-gif-copilot) · [script](create_animation.rb)

<br clear="all"/>

![](wallpaper.png)

#### ❯ Original GitHub Copilot Prompts to download images :copilot:

Write a script in Ruby that downloads all game screenshots from
https://itch.io/jam/game-off-2025/results, which is a paginated results page.

**Requirements:**

- Crawl all pages of the results (follow pagination links until exhausted)
- For each game entry:
  - Extract the *overall* placement/rank (e.g. 1, 2, 3, 10, etc.)
  - Extract the game name as displayed on the page
  - Find the primary screenshot image shown for the game
- Download the image and save it locally using this filename format:<br>
    `<placement>-<game-name-lowercase-hyphenated>.<original_extension>`

 **Examples filenames:**

```
1-evaw.png
10-where-the-water-flows.gif
27-wave-length.jpeg
```

**Filename rules:**

 - Convert the game name to lowercase
- Replace spaces and punctuation with single hyphens
- Strip non-alphanumeric characters except hyphens
- Preserve the original image extension (png, jpg, jpeg, gif)

**Implementation details:**

- Respect polite scraping practices:
  - Set a clear User-Agent
  - Add a small delay between page requests
- Create an output directory called screenshots/
- Skip downloads if the file already exists
- Print progress logs (page number, game name, filename)
- Handle missing images gracefully; skip 'em

#### ❯ Original GitHub Copilot Prompts to create a montage wallpaper :copilot:

Create a Ruby script that generates a wallpaper montage from game screenshots.

**Requirements:**

- Read all images from a screenshots directory (png, jpg, jpeg, gif, webp)
- Create a 3840×2160 pixel wallpaper
- Use ALL images - calculate the optimal tile size to fit every image
- Maintain the original aspect ratio (315:250) when scaling tiles
- Only repeat images if needed to fill the final row/column
- Output to wallpaper.png

**Implementation details:**

- Use ImageMagick (montage and convert commands)
- Calculate tile dimensions dynamically based on image count
- Center-crop the final montage to exact wallpaper dimensions
- Print progress info (image count, grid size, tile dimensions)
- Clean up temporary files after completion

#### ❯ Original GitHub Copilot Prompts to make an animated GIF :copilot:

Create a Ruby script that generates a wallpaper montage from game screenshots.

**Requirements:**

- Read all images from a screenshots directory (png, jpg, jpeg, gif, webp)
- Create a 3840×2160 pixel wallpaper
- Use ALL images - calculate the optimal tile size to fit every image
- Maintain the original aspect ratio (315:250) when scaling tiles
- Only repeat images if needed to fill the final row/column
- Output to wallpaper.png

**Implementation details:**

- Use ImageMagick (montage and convert commands)
- Calculate tile dimensions dynamically based on image count
- Center-crop the final montage to exact wallpaper dimensions
- Print progress info (image count, grid size, tile dimensions)
- Clean up temporary files after completion
