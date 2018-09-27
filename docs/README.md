fixmystreet.org
===============

This directory is [fixmystreet.org](https://fixmystreet.org), the Jekyll-based
static site running on GitHub Pages that is the documentation for setting up /
running the FixMyStreet platform.

## Installation

The site is built by Jekyll. We manage our Ruby gem dependencies via
[bundler](https://bundler.io/) so you’ll need to install that if you don’t
already have it. Then you need to…

```
git clone --recursive https://github.com/mysociety/fixmystreet
cd fixmystreet/docs
bundle install --deployment
```

To preview the site locally, run:

```
bundle exec jekyll serve --incremental
```

And then visit <http://127.0.0.1:4000>.

Jekyll automatically compiles the HTML/Markdown and Sass files as you go.
And [livereload](https://github.com/RobertDeRose/jekyll-livereload)
automatically reloads your web browser window when the site is recompiled.
