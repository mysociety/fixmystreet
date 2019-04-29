## Releases

* Unreleased

* v2.6 (3rd May 2019)
    - New features:
        - (Optional) auto-suggestion of similar nearby problems,
          while reporting, to discourage duplicate reports. #2386
    - Front end improvements:
        - Track map state in URL to make sharing links easier. #2242
        - Default to unchecked for show name checkbox. #347
    - Email improvements:
        - Header image file name can be customised
    - Admin improvements:
        - Include moderation history in report updates. #2379
        - Allow moderation to potentially change state. #2381
        - Spot moderation conflicts and raise an error. #2384
        - Allow searching for <email> in admin.
        - Make staff JavaScript more self-contained.
        - Alow staff user to be associated with multiple areas.
        - Improvements to admin checkbox display.
    - Bugfixes:
        - Check cached reports do still have photos before being shown. #2374
        - Delete cache photos upon photo moderation. #2374
        - Remove any use of `my $x if $foo`. #2377
        - Fix saving of inspect form data offline.
        - Add CSRF and time to contact form. #2388
        - Make sure admin metadata dropdown index numbers are updated too. #2369
        - Fix issue with Open311 codes starting with ‘_’. #2391
        - Add parameter to URL when “Show older” clicked. #2397
        - Don't ask for email on alert signup if logged in. #2402
        - Filter out hidden reports from top 5 list. #1957
        - Add space below "map page" contents on narrow screens.
        - Use relative report links where possible. #1995
        - Improve inline checkbox spacing. #2411
        - Prevent duplicate contact history creation with Unicode data.
        - Show all Open311 extra fields in edit admin.
        - Proper bodies check for sending updates.
        - Check better if extra question has values.
        - Stop filter category overriding chosen category.
        - Allow things to reset if "Pick a category" picked.
        - Stop category_change firing more than it should.
        - Fix extra question display when only one category.
        - Fix superusers creating anonymous reports. #2435
        - Ensure non_public reports aren't exposed at /open311 endpoint.
        - Escape body name in admin title.
        - Use REQUEST_URI, not PATH_INFO, to infer path.
    - Development improvements:
        - Make front page cache time configurable.
        - Better working of /fakemapit/ under https.
        - Improve Open311 error output on failing GET requests.
    - Backwards incompatible changes:
        - If you wish the default for the showname checkbox to be checked,
          add `sub default_show_name { 1 }` to your cobrand file.
        - The admin body and user sections have been refactored – if you have
          custom templates/code, you may need to update links to those.

* v2.5 (21st December 2018)
    - Front end improvements:
        - Simplify new report/update sign in flow. #642
        - Simplify /auth sign in page. #2208
        - Clearer relocation options while you’re reporting a problem #2238
        - Enforce maximum photo size server side, strip EXIF data. #2326 #2134
        - Don't require two taps on reports list on touchscreens. #2294
        - Allow moderation to work without JavaScript. #2339
        - More prominent display of "state" on report page #2350
        - Improved report/update display on contact form. #2351
        - Can limit /reports to non-public reports. #2363
    - Admin improvements:
        - Allow moderation to potentially change category. #2320
        - Add Mark/View private reports permission #2306
        - Store more original stuff on moderation. #2325
        - Sort user updates in reverse date order.
        - Improve update display on admin report edit page.
        - Keep all moderation history, and show in report/update admin. #2329
    - Bugfixes:
        - Restore map zoom out when navigating to /around from /report. #1649
        - Don’t escape HTML entities in report titles pulled in by ajax. #2346
        - Show reopening/fixed questionnaire responses lacking updates. #2357
    - Open311 improvements:
        - Fix bug in contact group handling. #2323
        - Improve validation of fetched reports timestamps. #2327
        - Fetched reports can be marked non_public #2356
    - Development improvements:
        - Add option to symlink full size photos. #2326
        - default_to_body/report_prefill permissions to control default
          report as/prefill behaviour. #2316

* v2.4.2 (6th November 2018)
    - New features:
        - Dashboard now has update CSV export. #2249
        - Allow cobrands to override searching by reference #2271
        - Allow cobrands to limit contact form to abuse reports only
    - Admin improvements:
        - List number of alerts on report page #669
        - viewing and managing of user alerts in admin #676
        - Allow moderation to potentially change photos/extra info. #2291 #2307
    - Bugfixes:
        - Add perl 5.26/5.28 support.
        - Fix subcategory issues when visiting /report/new directly #2276
        - Give superusers access to update staff dropdowns. #2286
        - Update report areas when moving its location. #2181
        - Don't send questionnaires for closed reports. #2310
        - Make sure Open311 send_method always recorded/spotted. #2121
    - Development improvements:
        - Add cobrand hook for dashboard viewing permission. #2285
        - Have body.url work in hashref lookup. #2284
        - OSM based map types can now override zoom levels #2288
        - Clearer name for navigation colours in SCSS. #2080
        - `script/setup` now creates `conf/general.yml` for Vagrant when needed.
    - Internal things:
        - Move send-comments code to package for testing. #2109 #2170
    - Open311 improvements:
        - Set contact group only if handling cobrand has groups enabled. #2312

* v2.4.1 (2nd October 2018)
    - New features:
        - Support for storing photos in AWS S3. #2253
    - Front end improvements:
        - Import end point can optionally return a web page #2225
        - Clicking the "Report" header links on the homepage now focusses
          the #pc search input #2237
        - Speed up fetching lists of bodies. #2248
        - Improve vertical alignment of navigation menu in Internet Explorer 9–11.
        - Mobile menu button no longer uses -9999px text-indent hack.
        - HTML email template for confirming "partial" reports #2263
    - Bugfixes:
        - Fix display of area/pins on body page when using Bing or TonerLite map.
        - Do not scan through all problems to show /_dev pages.
        - Say “Set password”, not Change, if no password set.
        - Do not lose from_body field when edited by non-superuser admin.
        - Fix history API bug with category/state selection.
    - Development improvements:
        - Cobrand hook for disabling updates on individual problems.
        - Cobrand hook for disallowing title moderation. #2228
        - Cobrand hook for per-questionnaire sending. #2231
        - Add option for configuring memcache server.
        - Add Blackhole send method. #2246
        - Add script to list/diff template changes in core that
          might need applying to a cobrand.
        - Move away from FastCGI in sample conf/sysvinit config.
        - Customised Vagrant box available, with an override option.
        - Add Dockerfile and example Docker Compose setup.
        - Add a sample systemd unit file for the Catalyst application server.

* v2.4 (6th September 2018)
    - Security
        - Update user object before attempting sign-in,
          to prevent leak of user account phone number.
    - Front end improvements:
        - Simplify footer CSS. #2107
        - Keep commas in geocode lookups. #2162
        - Show message on reports closed to updates. #2163
        - Only display last 6 months of reports on around page by default #2098
        - Always show all reports by default on /my.
        - Much less reliance on input placeholders, for better accessibility #2180
        - “Report another problem here” button on report confirmation page #2198 #393
        - Button in nav bar now makes it easier to report again in the same location #2195
        - Shrink OpenLayers library a bit. #2217
        - Remove need for separate per-category ajax call. #1201
    - Admin improvements:
        - Mandatory defect type selection if defect raised. #2173
        - Send login email button on user edit page #2041
        - Use do-not-reply address for sent report email.
        - Category group can be edited.
        - Trim spaces from user/report search input.
    - Bugfixes:
        - Don't remove automated fields when editing contacts #2163
        - Remove small border to left of Fixed banner. #2156
        - Fix issue displaying admin timeline. #2159
        - Send details of unresponsive bodies to mobile app #2164
        - Fix issue with category filter when category contains comma #2166
        - Inspectors can unset priority. #2171
        - Defect type is recorded if category change made. #2172
        - [UK] Store body ID on council/ward alerts. #2175
        - Show all fixed issues when staff user uses map page filter #2176
        - Allow any user who can see private checkbox to use it. #2182
        - Prevent duplicate category listing on /my.
        - Hide password help field along with other similar. #2185
        - Allow questionnaire link to be revisited in quick succession. #2123
        - Update Google Maps directions link.
        - Fix inspector pin dragging. #2073.
        - Maintain all single newlines in text output, not only the first.
        - Make sure Home clickable with Try again overlay.
        - Check all contacts for metadata and non-public.
    - Open311 improvements:
        - CLOSED status maps to 'closed' state if extended statuses are enabled.
        - Don't generate template comment text on move between fixed states. #2199
    - Development improvements:
        - Cobrand hook for presenting custom search results. #2183
        - Cobrand hook to allow extra login conditions #2092
        - Add ability for client to set bodies not to be sent to. #2179
        - Make it easier to prevent a form_detail_placeholder being printed. #2212
        - Include user agent in contact form emails. #2206
        - Use site name in contact email subject line.
        - Add /_dev endpoints for previewing confirmation/submission pages. #2218
        - Allow cobrand to add extra ability to moderate. #2216

* v2.3.4 (7th June 2018)
    - Bugfixes:
        - Fix pin clicking on non-/around pages, broken in 2.3.3.
        - Fix issue displaying anonymous account email.

* v2.3.3 (6th June 2018)
    - Front end improvements:
        - Extra help text on contact form #2149
    - Admin improvements:
        - Improve inspect form position and configurability.
    - Bugfixes:
        - Prevent contact form leaking information about updates #2149
        - Fix pointer event issue selecting pin on map. #2130
        - Fix admin navigation links in multi-language installs.
        - Fix map display issue clicking back from report page as inspector.

* v2.3.2 (31st May 2018)
    - Front end improvements:
        - Improve questionnaire process. #1939 #1998
        - Increase size of "sub map links" (hide pins, permalink, etc) #2003 #2056
        - Edge-to-edge email layout on narrow screens #2010
        - Add default placeholder to report extra fields. #2027
        - Clicking the "Click map" instruction banner now begins a new report #2033
        - Homepage postcode input is now marked up as a required input #2037
        - Improved cursor/display of the new report pin. #2038
        - Asset layers can be attached to more than one category each. #2049
        - Cobrands hook to remove phone number field. #2049
        - Check recent reports for any hidden since cached. #2053
        - Asset layer attribution automatically shown. #2061
        - The .internal-link-fixed-header positioning is now much simpler. #2117
        - Added UI to view multiple wards at once on /reports. #2120
    - Bugfixes:
        - Stop asset layers obscuring marker layer. #1999
        - Don't delete hidden field values when inspecting reports. #1999
        - Fix text layout issues in /reports/…/summary dashboard charts.
        - Fix post-edit issues on admin report edit page.
        - Truncate dates in Open311 output to the second. #2023
        - Fix check for visible sub map links after 'Try again'.
        - Stop race condition when making a new report quickly.
        - Set a session timezone in case database server is set differently.
        - Fix SQL error on update edit admin page in cobrands. #2049
        - Improve chart display in old IE versions. #2005
        - Improve handling of Open311 state changes. #2069
        - Don't strip whitespace from user passwords. #2111
        - Make OpenGraph description translatable.
        - Stop double-escaping title in alert-update email.
        - Use inspection states in response template admin.
        - Fixed CSS padding/overflow bug during sidebar "drawer" animations. #2132
        - Response template containing double quote now works.
        - A few small display issues with RTL text display.
        - Improve handling of loading spinner display. #2059
        - Ignore non-interactive layers for asset message.
    - Admin improvements:
        - Inspectors can set non_public status of reports. #1992
        - Default start date is shown on the dashboard.
        - Users with 'user_edit' permission can search for users/reports. #2027
        - Don't send sent-report emails to as-body/as-anonymous reports.
        - Show Open311 service code as tooltip on admin category checkboxes. #2049
        - Bulk user import admin page. #2057
        - Add link to admin edit page for reports. #2071
        - Deleted body categories now hidden by default #1962
        - Display contents of report's extra field #1809
        - Store user creation and last active times.
        - Add scripts to anonymize inactive users and reports,
          email inactive users, or to close reports to new updates.
        - Admin ability to close reports to new updates. #43
    - Open311 improvements:
        - Fetch problems over Open311 #1986 #2067
        - Option to send multiple photos over Open311 #1986
        - Allow Open311 service definitions to include automated attributes #1986
        - Optionally supress blank Open311 update errors #1986
        - Fetch/store external status code with Open311 updates. #2048
        - Response templates can be triggered by external status code. #2048
        - Enable conversion from EPSG:27700 when fetching over Open311 #2028
        - Add CORS header to Open311 output. #2022
        - Nicer Open311 errors. #2078
    - Development improvements:
        - Cobrand hook for adding extra areas to MAPIT_WHITELIST/_TYPES. #2049
        - send-comments warns about errors when called with --verbose #2091
        - Add HTML email previewer.
        - Add some Cypress browser-based testing.
        - Upgrade Vagrantfile to use Ubuntu Xenial. #2093
        - Add validation to cobrand-specific custom reporting fields.
        - Drop support for IE7, improve IE8 support. #2114
        - Add ability to have category extra help text.
        - Cobrand hook for showing all states in filter.

* v2.3.1 (12th February 2018)
    - Front end improvements:
        - Zoom out as much as necessary on body map page, even on mobile. #1958
        - Show loading message on initial /around map load #1976
        - Ask for current password/send email on password change. #1974
        - Add minimum password length and common password checking. #1981
        - Nicer display of national phone numbers. #1982
        - 'Report as another user' allows phone number without email. #1978
        - Display loading spinner on map when asset layers are loading. #1991
    - Bugfixes:
        - Fix bug specifying category in URL on /around. #1950
        - Fix bug with multiple select-multiples on a page. #1951
        - Make sure dashboard filters all fit onto one line. #1938
        - Fix issue with red bars on bar graph of many categories. #1938
        - Prefetch translations in /reports list of bodies. #1941
        - Ignore deleted/area-less bodies in dashboard list. #1941
        - Add missing CSS class from final questionnaire question. #1953
        - Fix JavaScript error on /my calculating bounds #1954
        - Change text on /reports to match lower down (fix translation).
        - Ensure all reports graph can't dip downward. #1956
        - Fix error sending `requires_inspection` reports. #1961
        - Fix timezone related test failure. #1984
        - Restore display of extra fields on inspector form. #1994
    - Admin improvements:
        - Admin can anonymize/hide all a user's reports. #1942 #1943
        - Admin can log a user out. #1975
        - Admin can remove a user's account details. #1944
        - Superusers can have optional two-factor authentication. #1973
    - Development improvements:
        - Add script to remove expired sessions. #1987
        - 'components' parameter can be passed to Google geocoder. #1994
    - UK:
        - Lazy load images in the footer.

* v2.3 (18th December 2017)
    - New features:
        - Optional verification of reports and updates, and logging in,
          using confirmation by phone text. #1856 #1872
        - Improved email/phone management in your profile.
        - Don't cover whole map with pin loading indicator. #1874
        - Add Expand map toggle to more mobile maps. #1875
        - Allow multiple wards to be shown on reports page. #1870
        - Add functionality to have per-body /reports page. #1880
        - Open311 category group support. #1923
    - Front end improvements:
        - Paginate reports on `/around`. #1805 #1577 #525
        - Improve performance of various pages, especially front. #1901 #1903
        - More prominent "Hide pins" link on map pages, to aid reporting in busy areas. #525
        - Optimised sprite file down from 97 KB to 36 KB. #1852
        - SVG assets for core elements like button icons and map controls #1888
        - Remove unneeded 2x PNG fallback images.
        - Improve location disambiguation page on small screens. #1918
        - Don't show geolocation link on non-HTTPS pages. #1915
        - Public report page shows state changes made in admin interface #1846
    - Bugfixes
        - Shortlist menu item always remains a link #1855
        - Fix encoded entities in RSS output. #1859
        - Only save category changes if staff user update valid #1857
        - Only create one update when staff user updating category #1857
        - Do not include blank updates in email alerts #1857
        - Redirect inspectors correctly on creation in two-tier. #1877
        - Report status filter All option works for body users #1845
        - Always allow reports to be removed from shortlist #1882
        - Remove shortlist form from inspect duplicate list. #1889
        - Fix pin size when JavaScript unavailable.
        - Fix display of text only body contacts #1895
        - Prevent text overflow bug on homepage stats #1722
        - Stop page jumping too far down on inspect form. #1863
        - Prevent multiple 'Expand map' links appearing. #1909
        - Superusers without a from_body can make reports again. #1913
        - Fix crash when viewing /around in certain locales. #1916
        - Fix back bug, from report after using list filters. #1920
        - Fix issues with send method category change. #1933
    - Admin improvements:
        - Character length limit can be placed on report detailed information #1848
        - Inspector panel shows nearest address if available #1850
        - Return a 200 rather than 404 for ref ID lookup. #1867
        - Remove hidden from default staff state dropdown. #1878
        - Marking an item as a duplicate enforces providing ID/update. #1873
        - Report field pre-filling for inspectors configurable #1854
        - Admins can now unban users #1881
        - More JavaScript-enhanced `<select multiple>` elements. #1589 #1892
        - 'Auto-response' flag on response templates is honoured for fetched
          Open311 updates. #1924
        - Individual cobrands can disable social login #1890
        - Cobrands can disable sending of moderation emails. #1910
        - Store all successful send methods. #1933
    - Dashboard/statistics:
        - Improve/consolidate various admin summary statistics pages,
          all now under /dashboard. #1834 #1919
        - Add date range for report generation #1885
        - CSV export now has token based authentication. #1911
        - And uses machine-readable dates. #1929
    - Development improvements:
        - Add hook for pre-wrapper content.
        - Include JSON representation of extra fields in category_extras output
        - send-reports will never skip failed reports when using --debug
    - UK:
        - Use SVG logo, inlined on front page. #1887
        - Inline critical CSS on front page. #1893

* v2.2 (13th September 2017)
    - New features:
        - Body and category names can now be translated in the admin. #1244
        - Report states can be edited and translated in the admin. #1826
        - Extra fields can be added to the report form site-wide. #1743
        - Staff users can now create reports as an anonymous user. #1796
        - Staff users can filter reports by all states. #1790
        - `LOGIN_REQUIRED` config key to limit site access to logged-in users.
        - `SIGNUPS_DISABLED` config key to prevent new user registrations.
    - Front end improvements:
        - Always show pagination figures even if only one page. #1787
        - Report pages list more updates to a report. #1806
        - Clearer wording and more prominent email input on alert page. #1829
        - Cobrands can implement `hide_areas_on_reports` to hide outline on map.
        - Templates to allow extra messages through problem confirmation. #1837
    - Admin improvements:
        - Highlight current shortlisted user in list tooltip. #1788
        - Extra fields on contacts can be edited. #1743
        - Clearer highlight for selected duplicate on inspect form. #1798
        - Include MapIt API key on admin config page. #1778
        - Redirect to same map view after inspection. #1820
        - A default response priority can now be set. #1838
        - Dashboard CSV export includes Northing, Easting and Ward.
          It also now orders fields by report confirmed time. #1832 #1835
    - Bugfixes:
        - Set up action scheduled field when report loaded. #1789
        - Fix display of thumbnail images on page reload. #1815
        - Fix sidebar hover behaviour being lost. #1808
        - Stop errors from JS validator due to form in form.
        - Stop update form toggle causing report submission.
        - Update map size if an extra column has appeared.
        - Improve performance of various pages. #1799
        - Duplicate list not loading when phone number present. #1803
        - Don't list multiple fixed states all as Fixed in dropdown. #1824
        - Disable email field for logged in people. #1840
    - Development improvements:
        - Debug toolbar added. #1823
        - `switch-site` script to automate switching config.yml files. #1741
        - `make_css --watch` can run custom script after each compilation.
        - Upgrade comonlib to get nicer MapIt error message.

* v2.1.1 (3rd August 2017)
    - Email improvements:
        - Clicking on the map in an email links to the report #1596
    - Admin improvements:
        - Resend report if changing category changes send_method. #1772
        - Do not replace deleted text with [...] when moderating. #1774
        - Show reporter's phone number on inspector form. #1773
        - Redirect to /around after inspecting a report.
    - Bugfixes:
        - Cache template paths in About.pm with lang_code. #1765
        - Resize pin image before compositing onto static map.
    - Development improvements:
        - Use standard JavaScript translation for show/hide pins. #1752
        - Allow update-schema to run on empty database. #1755
        - Update MapIt URL to https in example webserver configs.
        - Option to redirect to custom URL from Contact form.

* v2.1 (8th July 2017)
    - New features:
        - Allow users to hide their name on reports/updates. #658
        - New /reports page. #1630 #1726 #1753
    - Front end improvements:
        - Resize photos client-side before uploading. #1734
        - CSS header/content/navigation refactoring/simplification. #1719 #1718
        - Consolidate state dropdowns, make sure existing state is included. #1707
        - Simplify `footer-marketing.html` for most cobrands. #1709
        - Change the contact form Post button label to Send. #1750
        - Add an optional phone field to the contact form. #1750
        - Double resolution pin icons in core. #1713
    - Admin improvements:
        - Don't resend if category change subsets body. #1725
        - Fix styling of 'remove from site' button. #1700
        - Add inactive state to categories. #1757
        - Inspect form:
            - Make more visually distinct, better on medium screens. #1700 #1701
            - Populate defect types dropdown on category change. #1698
            - Update templates when category/state changed. #1729
            - Fix bug when switching state to duplicate and back. #1729
            - Don't preselect inspector template on page load. #1747
        - Allow inspectors to shortlist all reports in view. #1652
        - Subscribe inspectors to updates when state changes. #1694
        - Streamline new reports for inspectors. #1636
    - Bugfixes:
        - Make three strings translatable. #1744 #1735
        - Reinstate geolocation on alert page. #1726
        - Fix clickable spaces on inspect form/ward page. #1724
        - Make sure segmented control input not offscreen. #1749
        - Remove superfluous quote in HTML script element. #1705
        - Add missing closing </dl> to base FAQ.
    - Development improvements:
        - Allow static home page template override. #1745
        - Add Debian stretch/perl 5.24 support. #1746
        - Add scripts to rule them all. #1740
        - Update submodule on any Vagrant provisioning. #1702
        - Fix imbalanced paragraph tags in glossary. #1737
        - Spot badly configured SMTP type. #1758.
        - Add MAPIT_API_KEY support
        - Hooks:
            - Add hook for post-title field content in report form. #1735
            - Add hook so cobrands can change pin hover title. #1713
            - Allow cobrands to define pin colour for new reports. #1713
        - Testing:
            - Run each test file in a transaction. #1721
            - Test script should run 't' when other args given. #1721
            - Auto-add strict/warnings/Test::More with TestMech. #1554
            - Fix test that would not run offline. #1712
            - Fix timing edge case test failure.
    - Backwards incompatible changes:
        - The `nav-wrapper-2` class has been removed. If you have a
          custom footer template, replace that class with 'container'. #1718
        - The `/reports` page now uses different generated data. If you
          have a custom `reports/index.html` template, you may need to
          call `update-all-reports` with the `--table` argument.
    - Internal things:
        - Move third party libraries into vendor directories. #1704
        - Stop using sudo on Travis, improve locale support. #1712
        - Add CodeCov coverage testing. #1759
    - UK:
        - Add fixture script. #1720
        - Add Borsetshire demo cobrand. #1717
        - Remove requirement for fixed body IDs. #1721
        - Show all pins on two-tier councils only. #1733
        - Stop nearest request with scientific notation. #1695

* v2.0.4 (13th April 2017)
    - Front end improvements:
        - On /reports maps, only include reports in view. #1689
    - Admin improvements:
        - Allow comma-separated contact emails in the admin. #1683
    - Bugfixes:
        - Upgrade Facebook 3rd party library to fix Facebook login. #1681
        - Don't error when devolved body, blank send methods. #1374
        - Fix issue with categories with regex characters. #1688

* v2.0.3 (31st March 2017)
    - Front end improvements:
        - Add ability to make map full screen on mobile report pages. #1655
        - Move staff-only JavaScript to separate file. #1666
        - Show loading indicator when loading pins. #1669
        - Allow users to reopen closed reports. #1607
    - Admin improvements:
        - Redirect to category-filtered /reports on login if present. #1622
        - Follow redirect to /admin after login if allowed. #1622
        - Include /admin link on top-level nav for admin users.
        - Add shortlist filters. #1629
        - Add submit buttons to admin index search forms. #1551
        - Store user object when deleting report. #1661
        - Use name at time of moderation, include superusers. #1660
        - Add customisable defect types. #1674
    - Bugfixes:
        - Fix crash on reports with empty `bodies_str`. #1635
        - Only output appcache/manifest for shortlist users. #1653
        - Fix placeholder typo in French translation.
        - Make sure report Ajax call is not cached by IE11. #1638
        - Check cobrand users list when admin merging users. #1662
        - Make sure emails are lowercased in admin. #1662
        - Specify options in 'all' status filter. #1664
        - Be clearer if no states selected is not all states. #1664
        - Set up correct environment in cobrand PO script. #1616
        - Allow superuser to leave update when inspecting. #1640
        - Remove duplicate <> around envelope senders. #1663
        - Fix invisible segmented controls in old Webkit. #1670
        - Remove superfluous lists from Open311 JSON output. #1672
        - Upgrade to using Email::Sender. #1639
        - Fix bug if test run c. 55 hours before BST starts.
        - Use lat/lon on inspection form if no local coordinates. #1676
        - Improve translatability of various pages.
    - Development improvements:
        - Send open reports regardless of current state. #1334
        - Clarify ‘inspected’ behaviour. #1614
        - Reduce disk stats. #1647
        - Refactor main navigation into reusable blocks.
        - Add Problem->time_ago for pretty-printed duration.
        - Add `external_id` field to ResponsePriority.
        - Forward on all bounces as bounces.
        - Use sender in From if From and To domains match. #1651
        - Refactor SendReport::Open311 to use cobrand hooks. #792
        - Do upload_dir check on start up, not each report. #1668
        - Make sure all tests can run offline. #1675
        - Add ability to override Google Maps road style. #1676

* v2.0.2 (3rd February 2017)
    - Front end changes:
        - Add an offline fallback page with appcache. #1588
        - Improve print layout for report list pages. #1548
        - Rename ‘unable to fix’ as ‘no further action’.
    - Bugfixes:
        - Mark two missing strings for translation. #1604
        - Make sure email is lowercase when signing in. #1623
        - Make sure language included in calls to base_url_for_report. #1617
        - Small CSS homepage fixes.
        - Admin:
            - Fix filtering on shortlist page. #1620
            - Fix 'save with public update' toggle. #1615
    - Admin improvements:
        - Add offline report inspection for inspectors. #1588 #1602 #1608
        - Admin with appropriate permission can see body user who left
          contribute_as_body report or update. #1601 #1603
        - Include ‘Add user’ link on admin user search results page. #1606
        - Redirect to new user after user creation/edit. #1606
        - Redirect to shortlist after inspection if user has permission. #1612
        - Allow response templates to be associated with a state, and default
          to that template if report state changed to match. #1587
        - Disable show name checkbox when reporting as someone else. #1597
        - Show response priorities in report list items. #1582
        - Shortlist add/remove icons in report lists and report page. #1582
        - Reordering shortlist buttons in report lists. #1582
        - Default inspect form to save with public update.
        - Drop unneeded Cancel button on inspect form.
        - Use ‘*’ on admin page to signify superuser.
    - Development improvements:
        - Update has_body_permission_to to allow superusers. #1600
        - Move staging flags to their own config variable. #1600
        - Only warn of Open311 failure after a couple, in case it's transient.
        - Only load user body permissions once per request.
        - Return 400/500 for some client/server errors.
        - Fix bad cross-year test.

* v2.0.1 (16th December 2016)
    - Bugfixes:
        - Fix issue in dragging map in Chrome 55. openlayers/ol2#1510
        - Don't double-decode strftime output, to fix date/time display.
        - Filter category should always carry through to form.
        - Don't fix height of admin multiple selects. #1589
    - Admin improvements:
        - Add duplicate management to inspector view. #1581
        - Open inspect Navigate link in new tab. #1583
        - Scroll to report inspect form if present. #1583
        - Update problem lastupdate column on inspect save. #1584
        - Update priorities in inspect form on category change. #1590
    - Development improvements:
        - Pass test if NXDOMAINs are intercepted.
        - Better path for showing config git version. #1586

* v2.0 (15th November 2016)
    - Front end improvements:
        - Add HTML emails. #1281 #1103
        - Stop map being underneath content sidebar/header. #1350 #361
        - Use Ajax/HTML5 history to pull in reports and improve map views.
          #1351 #1450 #1457 #1173
        - Allow multiple states and categories to be filtered. #1547
        - Add sort order options to list pages. #308
        - Invert area highlight on body pages. #1564
        - Allow users to change their own email. #360 #1440
        - Improve change password form/success page. #1503
        - Allow scroll wheel to zoom map. #1326
        - Rename "Your reports" in main navigation to "Your account".
        - Centre map on pin location when creating a report.
        - Zoom into map after second click on marker.
        - Maintain single newlines in text output. #306
        - JavaScript performance improvements. #1490 #1491
        - Allow searching for reports with ref: prefix in postcode field. #1495
        - Improve report form, with public, private, category sections. #1528
        - Only show relevant bodies after category selection.
        - Add update form name validation. #1493 #503 #1526
        - Add CORS header to RSS output. #1540
        - Switch MapQuest to HTTPS. #1505
        - Better 403/404 pages.
    - Admin improvements:
        - Greatly improve report edit page, including map. #1347
        - Improve category edit form, and display extra data. #1557 #1524
        - Hide confirmed column on body page if all categories confirmed. #1565
        - Show any waiting reports on admin index page. #1382
        - Allow user's phone number to be edited, and a report's category. #400
        - Resend report if changing category changes body. #1560.
        - Leave a public update if an admin changes a report's category. #1544
        - New user system:
            - /admin requires a user with the `is_superuser` flag. #1463
            - `createsuperuser` command for creating superusers.
            - Feature to create report as body/other user. #1473
            - Add user permissions system. #1486
            - Allow user to have an area assigned in admin. #1488
            - Allow user to have categories assigned in admin. #1563
            - Add inspector report detail view. #1470
            - Add user shortlists. #1482
            - Add response templates and priorities. #1500 #1517
            - Add user reputation and trusted users. #1533
    - Bugfixes:
        - Front end:
            - Fix photo preview display after submission. #1511
            - Update list of TLDs for email checking. #1504
            - Fix form validation issue with multiple IDs. #1513
            - Don't show deleted bodies on /reports. #1545
            - Stop using collapse filter in category template.
            - Use default link zoom for all map types.
            - Don't reload /reports or /my pages when filter updated.
            - Don't show alert email box if signed in.
        - Do not send alerts for hidden reports. #1461
        - Admin:
            - Fix contact editing of Open311 categories. #1535
            - Show 'Remove from site' button based on report. #1508
            - Improve moderation display and email. #855
            - Fix invalid SQL being generated by moderation lookup. #1489
            - Show user edit errors (e.g. blank name/email). #1510
            - Disallow empty name when creating/editing bodies.
            - Fix a crash on /admin/timeline.
    - Development improvements:
        - CSS:
            - make_css: Add output style option.
            - make_css: Follow symlinks.
            - Remove some unused CSS, and simplify full-width. #1423
            - Add generic .form-control and .btn classes.
        - Open311:
            - Tidy up/harden some handling. #1428
            - Add config for request limit, default 1000. #1313
            - Automatically spot co-ord/ID attributes. #1499
            - Make sure passed coordinate is decimal.
        - JavaScript:
            - Use static validation_rules.js file. #1451
            - Remove need to customise OpenLayers built script. #1448
            - Refactor and tidy all the JavaScript. #913
            - Prefer using an auto.min.js file if present/newer. #1491
        - Testing:
            - Speed up tests by stubbing out calls to Gaze.
            - Tests can run multiple times simultaneously. #1477
            - run-tests with no arguments runs all tests.
        - Don’t cache geocoder results when STAGING_SITE is 1. #1447
        - Make UPLOAD_DIR/GEO_CACHE relative to project root. #1474
        - Change add_links from a function to a filter. #1487
        - Optionally skip some cobrand restrictions. #1529
        - Allow contact form recipient override and extra fields.
        - Add server-side MapIt proxy.
    - Vagrant installation improvements:
        - Improve error handling.
        - Don't add a symlink if it is to the same place.
    - Backwards incompatible changes:
        - Drop support for IE6. #1356
    - UK
        - Better handling of two-tier reports. #1381
        - Allow limited admin access to body users on their own cobrands.
        - Add Content-Security-Policy header.

The Open311 adapter code has been moved to its own repository at
<https://github.com/mysociety/open311-adapter>.

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

* v1.7.2 (6th July 2016)
    - Security:
        - Fix XSS vulnerability in OpenGraph header and hide/all pins links.

* v1.7.1 (3rd May 2016)
    - Security:
        - Fix vulnerability in image upload that allowed external
          command execution.

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

* v1.6.3 (6th July 2016)
    - Security:
        - Fix XSS vulnerability in OpenGraph header and hide/all pins links.

* v1.6.2 (3rd May 2016)
    - Security:
        - Fix vulnerability in image upload that allowed external
          command execution.

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
