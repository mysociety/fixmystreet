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
Platform is now at version 1.6.1.

## Installation

We've been working hard to make the FixMyStreet Platform easy to install and
re-use in other countries - please see our site at <http://fixmystreet.org/>
for help and documentation in installing the FixMyStreet Platform.

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

## Releases

* v1.8.4 (6th July 2016)
    - Security:
        - Fix XSS vulnerability in OpenGraph header and hide/all pins links.
    - Front end improvements:
        - Wrap emails better for differing screen sizes. #1393
        - Fix annoying jump when "Get updates" drawer opened. #1425
        - Improve auth flow taken when return key used. #1433
        - Add and improve more CSRF tokens. #1433
        - Remove default box-shadow. #1419
        - Fix missing margin before reporting form email input. #1418
    - Bugfixes:
        - Redirect correctly if filter used without JavaScript. #1422
        - Remove race condition when starting new report. #1434
        - Fix a couple of display bugs in IE7. #1356
        - Correctly orient preview images. #1378

* v1.8.3 (3rd June 2016)
    - Admin improvements
        - Add search boxes to admin index page, and move stats. #1295
        - Allow change of email in admin to existing entry. #1207
        - Speed up photo removal. #1400
        - Improve in-place moderation UI. #1388
    - Front end improvements:
        - Improve printing of report page in Firefox. #1394
        - Fallback if request to Gaze fails. #1286
    - Bugfixes:
        - Fix non-working Google Maps layer. #1215
        - Fix map tap sensitivity on some devices. #911 and openlayers/ol2#1418
        - Fix lack of removal of cached update photos. #1405
        - Handle reports/updates by logged in abuse entries.
        - Fix size of grey chevrons.
    - Development improvements:
        - Massive speed increase to CSS compilation. #1414
        - Use only one templating system for emails. #1410
        - Move summary string function to template. #694
        - Consolidate CSS clearfix handling. #1414
        - Disable auto-CRLF conversion on git checkout.
        - Support for Debian Jessie/Ubuntu Xenial.
    - UK only
        - Add standard mySociety footer. #1385

* v1.8.2 (3rd May 2016)
    - Security:
        - Fix vulnerability in image upload that allowed external
          command execution.
    - New features
        - Twitter social login. #1377
        - PNG image upload support. #1302 #1361
    - Front end improvements:
        - Switch list item heading from h4 to h3. #1348
        - Preserve category when clicking elsewhere on map.
        - Optimize store logo PNGs.
    - Admin improvements
        - Default new category creation to confirmed. #1266
        - Use better link to reports on admin body page.
    - Bugfixes:
        - Show right body user form value for fixed reports. #1369
        - Cope with a '/' in body name slug. #574
        - Ignore empty entries in the image upload IDs.
        - Use transparent border in tips/change_location. #1380
    - Development improvements:
        - Allow cobrands to control front page number colours.
        - Refactor email handling to use Email::MIME alone. #1366
        - Improve testing on Mac OS X.
        - Prevent dev sites auto-creating session.
        - Display used send method in debug line.
        - Remove unused cobrands. #1383
        - Finally combine remaining base/fixmystreet templates.
        - Don't warn on bad photo hashes.
        - Skip fetched updates if they're out of date range. #1390
        - Store Open311 error in report on failure. #1391

* v1.8.1 (23rd March 2016)
    - Front end improvements:
          - Remember user's last anonymous state. #150
          - Remove auto-scrolling of sidebar on pin hover. #1344
          - Better multiple image display for reports/updates. #1325
          - Improve accessibility of pretty radio buttons and photo inputs.
    - Bugfixes:
          - Make sure preview image doesn't hide error. #1361
          - Don't double-decode geocoded addresses. #1359
          - Ensure top of reporting form is shown. #787
          - Other updates for Perl 5.20/5.22. #1358
    - Development improvements:
          - Add cobrand-specific custom reporting fields. #1352

* v1.8 (2nd March 2016)
    - New features:
        - Facebook login. #1146
        - Multiple photo upload support, with new UI. #190 #825 #1300
    - Front end improvements:
        - Pad internal update links so they are in view. #1308
        - Move alert page "recent photos" out of sidebar. #1168
        - Clearer relationship between map pins/list items. #1094
        - Consistent styling for updates on /report and /my pages. #1312
        - Stop a top banner overlapping header contents/improve CSS. #1306
        - Improve design of some error pages.
    - Performance improvements:
        - Reduce memory usage. #1285
    - Bugfixes:
        - Default the Google map view to hybrid. #1293
        - Prevent SVG chevron being stretched in Firefox. #1256
        - Better display/internationalisation of numbers. #1297
        - Fix cobrand restriction of My/Nearby. #1289
        - If app user logged in, perform alert signup. #1321
        - Spot media_url in Open311 GetServiceRequestUpdate. #1315
        - Improve disabled input behaviour (no hover, ensure faded).
        - Fix co-ordinate swapping bug in Google geocoder.
        - Exclude update alerts from summary alert counts.
        - Skip sending if any body marks it for skipping.
        - Upgrade Net::SMTP::SSL to fix email sending issue.
    - Development improvements:
        - Add generic static route handler. #1235
        - Store reports summary data by cobrand. #1290
        - Better handling replies to bounce addresses. #85
        - Combine more base/fixmystreet templates.
        - Add OpenStreetMap URL to report email.
    - Admin improvements:
        - Don't allow blank email/name to be submitted. #1294
        - Handle multiple photo rotation/removal in admin. #1300
        - Fix typo in admin body form checked status.
    - UK only
        - Make sure front page error is visible. #1336
        - Don't show app next step if used app. #1305
        - House Rules. #890 #1311

* v1.7 (23rd October 2015)
    - Front end improvements:
        - Add right-to-left design option. #1209
        - Add state/category filters to list pages. #1141
        - Include last update time in around/my page lists. #1245
        - Show report details more nicely on a questionnaire page. #1104
        - Improve email confirmation page (now matches success pages). #577
        - Update URL hash when mobile menu navigation clicked. #1211
        - Add public status page showing stats and version. #1251
        - Accessibility improvements to map pages. #1217
        - New default OpenGraph image. #1184
        - Turkish translation.
    - Performance improvements:
        - A number of database speed improvements. #1017
    - Bugfixes:
        - Translate report states in admin index. #1179
        - Improve translation string on alert page. #348
        - Fix location bug fetching category extras.
        - Workaround DMARC problems. #1070
        - Fix padding of alert form box. #1211
        - Pin Google Maps API version to keep it working. #1215
        - Upgrade Google geocoder to version 3. #1194
        - Fix script running when CDPATH is set. #1250
        - Fix retina image size on front page. #838
        - Process update left as part of questionnaire, to catch empty ones. #1234
        - Make sure explicit sign in button clicks are honoured. #1091
        - Adjust email confirmation text when report not being sent. #1210
        - Fix footer links in admin if behind a proxy. #1206
        - Use base URL in a cobrand alert for a report without a body. #1198
        - Fix potential graph script failure in perl 5.16+. #1262
    - Development improvements:
        - Error logging should now work consistently. #404
        - CSS
            - Streamline navigation menu CSS. #1191
            - Streamline list item CSS. #1141
            - make_css now follows symlinks. #1181
            - Use a sass variable for hamburger menu. #1186
            - Write progress of make_css_watch to terminal title. #1211
        - Templates:
            - Remove final hardcoded "FixMyStreet" from templates. #1205
            - Combine a number of base/fixmystreet templates. #1245
        - Installation:
            - Make sure submodules are checked out by Vagrant. #1197
            - Remove Module::Pluggable warning in newer perls. #1254
            - Bundle carton to ease installation step. #1208
        - Translation:
            - Improve ease of running gettext-extract. #1202
        - Add standard app.psgi file.
        - Add link to volunteer tickets in README. #1259
        - Use Modernizr to decide whether to show mobile map. #1192
        - Prevent potential session cookie recursion. #1077
        - Allow underscore in cobrand name/data. #1236
        - Add a development URL to see check email pages. #1211

* v1.6.1 (31st July 2015)
    - Bugfixes:
        - Fix bug introduced in last release when setting multiple areas
          for a body in the admin. #1158
        - Don't have default "name >= 5 characters"/"must have space" checks,
          as Latin-centric #805
    - New features:
        - Danish translation.
    - Front end improvements:
        - Fix “All Reports” table headers on scroll. #50
        - Add time tooltips to All Reports table headings. #983
        - Fix sidebar running over the footer on alerts page. #1168
    - Admin improvements:
        - Add mark as sent button. #601
        - Add link to comment user ID from body form if present. #580
        - Add MapIt links from body page/ report co-ordinates. #638
        - Show any category extra data. #517 #920
        - Mark users who have moderate permission. #990
        - Allow editing of body external URL.
        - List a report’s bodies more nicely.
    - UK specific improvements:
        - Explain gone Northern Ireland councils. #1151
        - Better messaging for councils refusing messages. #968

* v1.5.5 / v1.6 (10th July 2015)
    - Security:
        - Fix vulnerability in login email sending that could allow an account
          to be hijacked by a third party.
        - Time out email authentication tokens.
        - Update dependency to fix issue with Unicode characters in passwords.
    - New features:
        - Chinese translation.
    - Front end improvements:
        - Add “Report” button in default mobile header. #931
        - Use ‘hamburger’ menu icon in mobile header. #931
        - Resize map pins based on zoom level. #1041
        - Improve report meta information display. #1080
        - Display message on body page when reports list is empty.
    - Bugfixes:
        - Fix issue with shrunken update photos. #424
        - Fix typo in footer role="contentinfo".
        - Default Google maps to satellite view. #1133
        - Update Bing Maps parameter ID.
    - Development improvements:
        - Add ability for map pages to filter by category/state. #1134
          (this is currently on a couple of cobrands, to add to base soon)
        - Allow cobrands to specify ordering on all reports page.
        - Use mocked Nominatim in tests to cope with bad connections.
        - Add Extra role to ease use of the {extra} database field. #1018
    - UK specific improvements:
        - Add dog poop poster. #1028

* v1.5.4 (25th February 2015)
    - New features:
        - Stamen toner-lite and Bing Maps tiles.
        - Czech and part-done Lithuanian translations.
    - Front end improvements:
        - Nicer confirmation pages, with next steps template example. #972
        - Always show report/update confirmation page, even if logged in. #1003
        - Expire cached geolocations after a week. #684
    - Bugfixes:
        - Make sure all co-ordinates are stringified/truncated. #1009
        - Correct "Open Street Map" to "OpenStreetMap". #1021
        - Only create timezone objects once, at startup.
    - Development improvements:
        - Remove need to specify en-gb in LANGUAGES. #1015
        - Mac installation improvements. #1014
        - Make use of jhead and Math::BigInt::GMP optional. #1016
        - Link from admin config page to MapIt. #1022
        - Test URLs for confirmation pages.
        - New configuration variable for setting up behind a secure proxy.
    - UK specific improvements:
        - Output easting/northing on one line. #997
        - Output Irish easting/northing in Northern Ireland. #822

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
