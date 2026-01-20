This script pulls down all of the cover images for submissions to the [2025 Game Off](https://itch.io/jam/game-off-2025).

Written with GitHub Copilot Agent + Claude Opus 4.5 `<3`

# Original prompt

Write a script in Ruby that downloads all game screenshots from
https://itch.io/jam/game-off-2025/results, which is a paginated results page.

**Requirements:**

- Crawl all pages of the results (follow pagination links until exhausted).
- For each game entry:
  - Extract the *overall* placement/rank (e.g. 1, 2, 3, 10, etc.).
  - Extract the game name as displayed on the page.
  - Find the primary screenshot image shown for the game.
- Download the image and save it locally using this filename format:

  `<placement>-<game-name-lowercase-hyphenated>.<original_extension>`

 **Examples:**

```
1-evaw.png
10-where-the-water-flows.gif
27-wave-length.jpeg
```

**Filename rules:**

 - Convert the game name to lowercase.
- Replace spaces and punctuation with single hyphens.
- Strip non-alphanumeric characters except hyphens.
- Preserve the original image extension (png, jpg, jpeg, gif).

**Implementation details:**

- Respect polite scraping practices:
  - Set a clear User-Agent.
  - Add a small delay between page requests
- Create an output directory called screenshots/.
- Skip downloads if the file already exists.
- Print progress logs (page number, game name, filename).
- Handle missing images gracefully; skip 'em.

