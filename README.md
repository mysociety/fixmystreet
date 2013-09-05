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

It was created in 2007 by [mySociety](http://www.mysociety.org/) for reporting
problems to UK councils and has been copied around the world. The FixMyStreet
Platform is now at version 1.2.4.

## Releases

* v1.2.4 (5th September 2013)
    - A fix for the long-standing issue where multiline strings were not being
      translated (reported at https://github.com/abw/Template2/pull/29 )
    - Better translation strings for "marked as" updates, fixes #391
    - Less noise when running the tests
* v1.2.3 (2nd September 2013)
    - Maintenance release to deal with failing installation
    - Improve reuse of make_css and shared CSS
    - Remove hardcoded UK URLs on couple of admin error emails
    - Mark couple of strings missing translation
    - mapquest URL update
* v1.2.2 (26th July 2013)
    - Maintenance release to deal with failing installation
    - Improve Google Maps plugin somewhat, though still needs work
* v1.2.1 (5th June 2013)
    - Maintenance release to deal with failing carton installation
    - Test and module fixes for installation on Debian wheezy
    - Module fixes for running on Travis
    - The install script adds gem environment variables to the user's .bashrc
      so that make_css can be run directly after installation
    - make_css automatically spots which cobrands use compass
    - Some missing states added to the admin report edit page
* v1.2 (3rd May 2013)
    - Add MAPIT_ID_WHITELIST to allow easier use of global MapIt
    - Add postfix to the install script/ AMI so emailing works out of the box
    - Add an extra zoom level to the OSM maps
    - Add the Catalyst gzip plugin so HTML pages are gzipped
    - Fix an issue with the All Reports summary statistics not including some
      open states, such as 'in progress'
* v1.1.2 (15th March 2013)
    - Include the 'cpanfile' now required by carton, the Perl package
      management program we use.
* v1.1.1 (22nd February 2013)
    - Hotfix to fix missed iPhone width bug
* v1.1 (22nd February 2013)
    - Addition of bodies so that the organisations that reports are sent to can
      cover multiple MapIt administrative areas, or multiple bodies can cover
      one area, and other related scenarios
    - Admin display improvements
    - Internationalisation improvements, especially with text in JavaScript
    - Various minor updates and fixes (e.g. a --debug option on send-reports,
      and coping if MapIt has its debug switched on)
* v1.0 (24th October 2012)
    - Official launch of the FixMyStreet platform

## Installation

We've been working hard to make FixMyStreet Platform easy to install and re-use
in other countries - please see our site at <http://code.fixmystreet.com/> for
help and documentation in installing FixMyStreet Platform.

## Examples

* <http://www.fixmystreet.com/>
* <http://www.fiksgatami.no/>
* <http://fixmystreet.ie/>
* <https://www.zueriwieneu.ch/>

