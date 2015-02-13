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
Platform is now at version 1.5.2.

## Installation

We've been working hard to make the FixMyStreet Platform easy to install and
re-use in other countries - please see our site at <http://fixmystreet.org/>
for help and documentation in installing the FixMyStreet Platform.

## Contribution Guidelines

Whilst many contributions come as part of people setting up their own
installation for their area, we of course welcome stand-alone contributions as
well. The *Suitable for Volunteers* label in our GitHub issues hopefully labels
some potential tasks that might be suitable for that situation, though please
do search through the other issues to see if what you're after has been
suggested or discussed - or feel free to add your own issue if not.

## Mobile apps

We've extracted all of the mobile apps from this repository into the
[fixmystreet-mobile repository](https://github.com/mysociety/fixmystreet-mobile).

## Releases

* v1.5.3 (21st January 2015)
    - New features:
        - Satellite map toggle option on Google Maps view. #1002
        - Greek translation.
    - Bugfixes:
        - Fix cron-based email to use configured SMTP settings. #988
        - Update UNIX_USER variable on installation setup of crontab. #974
        - Improve make_css finding of bundled compass when in symlink. #978
        - Remove hard-coded site name from submit email template.
        - Allow forked repository pull requests to run on Travis.
        - Fix title of Privacy page, and other minor text fixes.
        - CSS: add some bottom content padding and fix a tiny map links issue.
    - Development improvements:
        - Replace site_title cobrand function with site-name web template. #979
        - Remove need for 'cron-wrapper' to run scripts. #852
        - Rename 'test-wrapper' to 'run-tests'. #999
        - Add client_max_body_size nginx config option. #995
        - Tidy up bin directory and #! lines.
    - Admin improvements:
        - Add staging email warning on admin body pages if needed. #982
        - Add admin navigation link to Configuration page. #1005
        - Better URL for body category editing.

* v1.5.2 (17th December 2014)
    - Hide unneeded heading on default footer.
    - Suppress 'Argument "" isn't numeric' warning on admin report edit page.
    - [UK] Don't show topic form field when reporting abuse.
    - Use token in moderation response URL to prevent hidden report leak.

* v1.5.1 (12th December 2014)
    - Bugfixes
        - Use correct cobrand signature in SendReport emails. #960
        - Fix double encoding of non-ASCII signature in emails. #961
        - Use area-based alerts by default, as they function correctly. #959
        - Set DefaultLocale appropriately when language set, for date display.
    - Open311
        - Better error if Open311 server returns a nil service list.
        - Cope better with Open311 server not liking a blank jurisdiction_id.
    - Installation/developer improvements:
        - Add a script to use a test database for running tests. #786
        - Make base FAQ more generic, move out UK-specific parts. #753 #935
        - Provide guidance at top of example config file.
        - Don't install open311-endpoint feature by default.

* v1.5 (19th November 2014)
    - Installation/developer improvements:
        - Support for Ubuntu Trusty Tahr 14.04 LTS. #921
        - Install bundler for more stable gem installation. #923
        - Rewritten graph generation programs in Perl. #924
        - Front end report moderation code. #809
    - Admin improvements:
        - Pagination of admin search results. #909
        - Validation of category details. #556
        - Removed overhang in body categories table. #738
        - Add encouraging message about support. #929
        - Tweak summary output on bodies page. #516
        - Move diligency table to bottom of page. #739
    - Front end:
        - Map page sidebar now flush with edges of window. #381
        - Simplify z-index usage, with other tidying. #673
        - Filtering of All Reports by category in URL. #254
        - More template generalisation, moving UK-specific stuff away. #344
    - Bugfixes:
        - Fixed JavaScript-disabled submission in Chrome/Firefox. #932
        - Show logged in message as success, not error. #357
        - Remove opacity from map controls on mobile.
        - Escape category in RSS feeds.
    - Internationalisation:
        - Add Albanian, Bulgarian, Hebrew, and Ukranian .po files.

* v1.4.2 (14th July 2014)
    - Maintenance release to deal with failing package installation. #832
    - User additions/improvements:
        - New links from `/reports` to open/fixed reports. #798
        - Better detection of signing in on `/auth` form. #816
    - Installation/developer improvements:
        - Allow SMTP username/password to be specified. #406
        - Correct GitHub link in `Vagrantfile`.
        - Error correctly if `cron-wrapper` fails to run.
        - Rename `default` web templates directory to `base`.
        - Move UK-specific text to separate templates. #344
        - Upgrade bundled `cpanm`. #807

* v1.4.1 (23rd May 2014)
    - Don't run some cron scripts by default, and rejig timings, to alleviate
      memory problems on EC2 micro instances. #640

* v1.4 (16th May 2014)
    - User improvements:
        - Adds some guidance on an empty `/my` page. #671
        - Auto-selects the category when reporting if there is only one. #690
        - Stops indenting emails a few spaces. #715
        - Email template updates. #700
    - Installation/developer improvements:
        - Makes it easier to change the pin icons. #721
        - Sends reports on staging sites to the reporter. #653
        - Adds a no-op send method to suspend report sending. #507
        - Improves the example Apache config. #733
        - Includes a nicer crontab example. #621
        - New developer scripts:
            - `make_css_watch`. #680
            - `geocode`. #758
        - Adds `external_url` field to Bodies. #710
        - Reinstates Open311 original update fetching code. #710 #755
        - Pins sass/compass versions. #585
        - Adds new `MAPIT_GENERATION` variable. #784
    - Bugfixes:
        - Fixes MapQuest and OSM attribution. #710 #687
        - Remove cached photos when deleted from admin.
        - Tiny bugfixes processing Open311 updates. #677
        - Correctly sets language in email alert loop. #542
        - Cron emails use `EMAIL_DOMAIN` in Message-ID. #678
        - Minor fixes for Debian wheezy.
        - Graph display of fixed states.
        - Slight CSS simplification. #609
    - Internal things:
        - Improves the robustness of Carton installation. #675
        - Doubles the speed of running tests on Travis.

* v1.3 (12th November 2013)
    - Changes cobrand behaviour so if only one is specified, always use it. #598
    - Allows multiple email addresses to be given for a contact.
    - Bugfixes to pan icon placement, and bottom navbar in Chrome. #597
    - Admin improvements
        - Search by external ID. #389
        - Date picker in stats. #514
        - Mark external links. #579
        - Fix for bug when changing report state from 'unconfirmed'. #527
        - Improve lists of report updates.
        - Add marking of bodies as deleted.
        - Show version number of code on config page.
    - Test suite runs regardless of config file contents. #596

* v1.2.6 (11th October 2013)
    - Upgrades OpenLayers to 2.13.1, for e.g. animated zooming.
    - Adds facility for using Google Maps via OpenLayers. #587
    - Swaps installation order of Perl modules/database, more robust. #573
    - Renames default FakeMapIt "Default Area" to "Everywhere". #566
    - Adds a "current configuration" admin page. #561

* v1.2.5 (13th September 2013)
    - Adds various useful hints and notices to the admin interface. #184
    - Improves the install script, including an example `Vagrantfile`
    - It is now easier for tests to override particular configuration
      variables should they need to.

* v1.2.4 (5th September 2013)
    - A fix for the long-standing issue where multiline strings were not being
      translated (reported at https://github.com/abw/Template2/pull/29 )
    - Better translation strings for "marked as" updates, fixes #391
    - Less noise when running the tests

* v1.2.3 (2nd September 2013)
    - Maintenance release to deal with failing installation
    - Improves reuse of `make_css` and shared CSS
    - Removes hardcoded UK URLs on a couple of admin error emails
    - Marks a couple of strings missing translation
    - Updates mapquest URLs

* v1.2.2 (26th July 2013)
    - Maintenance release to deal with failing installation
    - Improves the Google Maps plugin somewhat, though still needs work

* v1.2.1 (5th June 2013)
    - Maintenance release to deal with failing carton installation
    - Test and module fixes for installation on Debian wheezy
    - Module fixes for running on Travis
    - The install script adds gem environment variables to the user's .bashrc
      so that `make_css` can be run directly after installation
    - `make_css` automatically spots which cobrands use compass
    - Adds some missing states to the admin report edit page

* v1.2 (3rd May 2013)
    - Adds `MAPIT_ID_WHITELIST` to allow easier use of global MapIt
    - Adds postfix to the install script/ AMI so emailing works out of the box
    - Adds an extra zoom level to the OSM maps
    - Adds the Catalyst gzip plugin so HTML pages are gzipped
    - Fixes an issue with the All Reports summary statistics not including some
      open states, such as 'in progress'

* v1.1.2 (15th March 2013)
    - Includes the `cpanfile` now required by carton, the Perl package
      management program we use.

* v1.1.1 (22nd February 2013)
    - Hotfix to fix missed iPhone width bug

* v1.1 (22nd February 2013)
    - Adds bodies, so that the organisations that reports are sent to can cover
      multiple MapIt administrative areas, or multiple bodies can cover one
      area, and other related scenarios
    - Admin display improvements
    - Internationalisation improvements, especially with text in JavaScript
    - Various minor updates and fixes (e.g. a `--debug` option on `send-reports`,
      and coping if MapIt has its debug switched on)

* v1.0 (24th October 2012)
    - Official launch of the FixMyStreet platform

## Examples

* <https://www.fixmystreet.com/>
* <http://www.fiksgatami.no/>
* <http://fixmystreet.ie/>
* <https://www.zueriwieneu.ch/>
