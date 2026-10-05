# 9to5mac-magazine
An unofficial, Newsstand reader for the 9to5Mac RSS feed, written for iOS 6
and built with Xcode 4.6.x (Objective-C, ARC, deployment target 6.0).

> Not affiliated with or endorsed by 9to5Mac / 9to5 LLC. Names, logos and artwork belong to their
> respective owners. Intended for personal use.

## Features

* **Articles** - newest first, thumbnail on the left, older articles load as you scroll, pull to refresh.
* **Search** - searches the site; falls back to already loaded and saved articles when offline.
* **Saved** - save articles for offline reading, swipe left to delete.
* **Settings** - how external links open (in the reader, in Safari or ask every time), text size,
  theme (light / sepia / dark), font and an image cache reset.
* **In-app browser** for external links; 9to5Mac article links open in the reader itself.

## Known limitations

* iOS 6 cannot decode WebP, so articles whose picture is a `.webp` file have no thumbnail.

## License

GPL-3.0, see `LICENSE`.
