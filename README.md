# Welcome to FixMyStreet Platform

FixMyStreet Platform is an open source project to help people run websites for
reporting common street problems such as potholes and broken street lights to
the appropriate authority.

Users locate problems using a combination of address and sticking a pin
in a map without worrying about the correct authority to report it to.
FixMyStreet then works out the correct authority using the problem location and
type and sends a report, by email or using a web service such as Open311.
Reported problems are visible to everyone so they can see if something has
already been reported and leave updates. Users can also subscribe to email or
RSS alerts of problems in their area.

It was created in 2007 by [mySociety](https://www.mysociety.org/) for reporting
problems to UK councils and has been copied around the world. The FixMyStreet
Platform is now at version 3.0.1; see CHANGELOG.md for a version history.

## Installation

We've been working hard to make the FixMyStreet Platform easy to install and
re-use in other countries - please see our site at <https://fixmystreet.org/>
for help and documentation in installing the FixMyStreet Platform.

For development, if you have Vagrant installed, you can clone the repo and run
'vagrant up'. We use [Scripts to Rule Them All](https://githubengineering.com/scripts-to-rule-them-all/)
so `script/update` will update your checkout, `script/server` will run a dev
server, and `script/test` will run the tests.

## Contribution Guidelines

Whilst many contributions come as part of people setting up their own
installation for their area, we of course welcome stand-alone contributions as
well. The [*Suitable for
Volunteers*](https://github.com/mysociety/fixmystreet/labels/Suitable%20for%20Volunteers)
label in our GitHub issues hopefully labels some potential tasks that might be
suitable for that situation, though please do search through the other issues
to see if what you're after has been suggested or discussed - or feel free to
add your own issue if not.

## Mobile apps

We've extracted all of the mobile apps from this repository into the
[fixmystreet-mobile repository](https://github.com/mysociety/fixmystreet-mobile).

## Acknowledgements

Thanks to [Browserstack](https://www.browserstack.com/) who let us use their
web-based cross-browser testing tools for this project.

## Examples

* <https://www.fixmystreet.com/>
* <http://www.fiksgatami.no/>
* <http://fixmystreet.ie/>
* <https://www.zueriwieneu.ch/>
