## Description
This software aims to create rss feeds from serialised website content. By
serialized content, we mean content with a first one, and every content has a
next one, except for the last one, obviously. We give the software the url of
the first one and a set of scripts, and every time run it creates an rss feed
with the 10 last contents.

## How to use
### Content list
The script will look for the content list at `$CDG_CONFIG_HOME/rss_feeds` or,
in a second time, at `$HOME/.rss_feeds`. The file must contain a list of items,
one per line, of the form :
    `platform feed_name url`
`platform` is the platform name (see next paragraph), `feed_name` is the name
of the file the feed will be written to (a `.xml` will be added). Finally,
`url` is the url to the first content.

### Platforms
A platform is a directory with two scripts inside. The platforms are looked in
the `rss_platforms` directories of `$XDG_DATA_DIRS` or, if not set,
`/usr/local/share:/use/share`. All directories will be scanned, with platforms
added on the way. If a platform is present in two directories, the first one
has priority (thus the order of directories in `$XDG_DATA_DIRS` matters).
The two scripts it must contain are `desc` and `next`. `desc` will be executed
with the first url as its argument. Its first line output will be interpreted
as the title of the feed, and the following lines as the description. `next`
will be executed with the url of a content as only argument. The first line of
its output must be the url of the next content, or be empty if its the last.
The second line must contain the title of the actual content. The following
lines will be interpreted as the description of the actual content.

