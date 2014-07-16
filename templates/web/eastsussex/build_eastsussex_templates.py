#!/usr/bin/env python
import urllib2
import os

TEMPLATES = {
    "header.html.template": (
        "HtmlTag",
        "MetadataDesktop",
        (
            "HeaderDesktop",
            (
                ("<header>", '<header id="site-header" class="eastsussex">'),
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


def main():
    os.chdir(os.path.dirname(__file__))
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

if __name__ == '__main__':
    main()