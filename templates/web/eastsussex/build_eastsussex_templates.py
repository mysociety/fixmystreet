#!/usr/bin/env python
import urllib2
import os
import sys
import argparse
import time

try:
    from fsevents import Stream, Observer
    WATCH_AVAILABLE = True
except ImportError:
    WATCH_AVAILABLE = False

TEMPLATES = {
    "header.html.template": (
        "HtmlTag",
        "MetadataDesktop",
        (
            "HeaderDesktop",
            (
                ("<header>", '<header class="eastsussex">'),
            )
        ),
    ),
    "footer.html.template": (
        "FooterDesktop",
    )
}

BASE_URL = "https://www.eastsussex.gov.uk/masterpages/remote/control.aspx?control={fragment}&host=mysociety.org"


def patch_fragment(fragment, patches):
    if not patches:
        return fragment
    for search, replacement in patches:
        fragment = fragment.replace(search, replacement)
    return fragment


def update_templates():
    for template_path, fragment_names in TEMPLATES.items():
        template = open(template_path).read()
        fragments = {}
        for name in fragment_names:
            if isinstance(name, tuple):
                name, patches = name
            else:
                patches = None
            url = BASE_URL.format(fragment=name)
            content = urllib2.urlopen(url).read().replace("\r", "")
            fragments[name] = patch_fragment(content, patches)
            open("{0}.html".format(name), "wb").write(fragments[name])
        with open(template_path[:-9], "wb") as outfile:
            outfile.write(template.format(**fragments))


def event_callback(event):
    filename = os.path.basename(event.name)
    if filename in TEMPLATES.keys():
        print "{} has changed, updating templates...".format(filename)
        update_templates()
        print "done."

def watch_local_files():
    print "Watching for changes to: {}".format(", ".join(TEMPLATES.keys()))
    observer = Observer()
    stream = Stream(event_callback, os.getcwd(), file_events=True)
    observer.schedule(stream)
    try:
        observer.start()
        while True:
            time.sleep(86400)
    except KeyboardInterrupt:
        observer.stop()


def main():
    os.chdir(os.path.dirname(__file__))

    parser = argparse.ArgumentParser(description="Build header.html and footer.html from online East Sussex template fragments.")
    parser.add_argument("-w", "--watch", action="store_true")

    args = parser.parse_args()

    if args.watch:
        if not WATCH_AVAILABLE:
            print "Watch functionality not available. This currently needs OS X and the macfsevents Python package."
            sys.exit(1)
        watch_local_files()
    else:
        update_templates()


if __name__ == '__main__':
    main()
