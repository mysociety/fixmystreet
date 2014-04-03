fixmystreet.org
===============

The gh-pages branch is [fixmystreet.org](http://fixmystreet.org), the
Jekyll-based static site running on GitHub Pages that is the documentation for
setting up / running the FixMyStreet platform.

## Installation

In the below you could of course run `sudo gem install` or `npm install -g` but
I personally never think that's a good idea. You must already have gem and git
installed (you probably do).

```
gem install --no-document --user-install github-pages
# Add ~/.gem/ruby/2.0.0/bin/ or similar to your $PATH
# Check you can run "jekyll"
git clone --recursive -b gh-pages https://github.com/mysociety/fixmystreet fixmystreet-pages
cd fixmystreet-pages
```

If you only want to edit the *text* of the site, this is all you need. Run
`jekyll serve --watch` to run a webserver of the static site, and make changes
to the text you want.

If you want to edit the CSS or JS, or you'd like live reloading of changes in
your web browser, you might as well set up the thing that monitors it all for
you. You will need npm already installed.

```
gem install --no-document --user-install sass
npm install grunt-cli
npm install
node_modules/.bin/grunt
```

This will start up a watcher that monitors the files and automatically compiles
SASS, JavaScript, and runs `jekyll build` when necessary. It also live reloads
your web pages.

Lastly, if you'd like to add more JavaScript *libraries* than the ones already,
you'll additionally need to install bower and use it to fetch the libraries
used:

```
npm install bower
node_modules/.bin/bower install
```

Then use bower to install a new library and add it to the Gruntfile.js.
