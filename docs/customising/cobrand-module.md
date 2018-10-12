---
layout: page
title: Customising with a Cobrand module
---

# Cobrand module

If you need customistation beyond what templates, configuration variables, and
translations can offer, then you will have to have a Cobrand module. These are
automatically loaded according to the current Cobrand and can be found in
`perllib/FixMyStreet/Cobrand/`. There is a default Cobrand (`Default.pm`)
which all Cobrands should inherit from. A Cobrand module can then override any
of the methods from the default Cobrand.

Many of the functions in the Cobrand module are used by FixMyStreet in the UK
to allow the site to offer versions localised to a single authority and should
not be needed for most installs. Listed below are some of the options that
can be changed:

* language_override

    Return a language code string from this function if you wish your cobrand
to always be in a particular language, rather than try and work it out from the
domain name or the browser’s settings.

* add_response_headers

    Any extra headers you wish to send with your HTTP responses. For example,
    fixmystreet.com uses this to send a Content-Security-Policy header.

* on_map_default_max_pin_age

    How far back to go by default showing pins on your around map.

* areas_on_around

    If you would like to plot the boundaries of MapIt IDs on an around page
(not just reports page), you specify them here.

* pin_colour

    This can be used if you wish to specify different pin colours depending upon
some aspect of the report - its state, category, and so on.

* pin_new_report_colour

    What colour to use for the pin when reporting a new issue.

* geocode_postcode

    This function is used to convert postcodes (zip codes, etc.) entered into a
latitude and longitude, if there's a different way from your geocoder of doing so
(e.g. a MapIt install). If the text passed is not a valid postcode then an
error should be returned. If you do not want to use postcodes, just do not define
this function.

    If the postcode is valid and can be converted then the return value should
look like this:

        return { latitude => $latitude, longitude => $longitude };

    If there is an error it should look like this:

        return { error => $error_message };

* find_closest and find_closest_address_for_rss

    These are used to provide information on the closest street to the point of
the address in reports and RSS feeds or alerts.

* allow_photo_upload

    Return 0 to disable the photo upload field.

* allow_photo_display

    Return 0 to disable the display of uploaded photos.

* remove_redundant_areas

    This is used to filter out any overlapping jurisdictions from MapIt results
where only one of the authorities actually has responsibility for the events
reported by the site. An example would be a report in a city where MapIt
has an ID for the city council and the state council (and they are both the
same MapIt area type) but problems are only reported to the state. In this case
you could remove the ID for the city council from the results.

    With the new bodies handling, a better way to handle this would be to simply
have a body that only covered the state council administrative area.

* short_name

    This is used to turn the full authority name returned by MapIt into a short
name.

* send_questionnaires

    By default, FixMyStreet [sends questionnaires]({{ "/running/surveys" | relative_url }})
    (sometimes called _surveys_) four weeks after a user submitted a report. The
    questionnaire encourages them to update the 
    <a href="{{ "/glossary/#state" | relative_url }}" class="glossary__link">state</a>
    of the report. Return 0 to disable this feature so that surveys are never
    sent.

* abuse_reports_only

    Limit the contact page to only accepting abuse reports for comments
    and updates. This can be useful if you have another contact form and
    want to prevent people using this.

