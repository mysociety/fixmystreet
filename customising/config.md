---
layout: page
title: Configuration settings
---

# Configuration settings

<p class="lead">
    You can control much of how FixMyStreet looks and behaves just by 
    changing the config settings.
</p>

## The general configuration file

The FixMyStreet code ships with an example configuration file:
`config/general.yml-example`.

As part of the [installation process]({{ site.baseurl }}install ), the example
file gets copied to `config/general.yml`. You **must** edit this file to suit
your needs.

When you edit this file, remember it must be in the <a
href="http://yaml.org">YAML syntax</a>. It's not complicated but &mdash;
especially if you're editing a list &mdash; be careful to get the indentation
correct. If in doubt, look at the examples already in the file, and don't use
tabs.


## Config settings by topic

The following are all the configuration settings that you can change in `config/general.yml`.

### Database config

<code><a href="#fms_db_host">FMS_DB_HOST</a></code><br>
<code><a href="#fms_db_port">FMS_DB_PORT</a></code><br>
<code><a href="#fms_db_name">FMS_DB_NAME</a></code><br>
<code><a href="#fms_db_user">FMS_DB_USER</a></code><br>
<code><a href="#fms_db_pass">FMS_DB_PASS</a></code>

### Site settings and behaviour

<code><a href="#allowed_cobrands">ALLOWED_COBRANDS</a></code><br>
<code><a href="#rss_limit">RSS_LIMIT</a></code><br>
<code><a href="#all_reports_per_page">ALL_REPORTS_PER_PAGE</a></code><br>
<code><a href="#area_links_from_problems">AREA_LINKS_FROM_PROBLEMS</a></code>

### URLs and directories

<code><a href="#base_url">BASE_URL</a></code><br>
<code><a href="#upload_dir">UPLOAD_DIR</a></code><br>
<code><a href="#geo_cache">GEO_CACHE</a></code><br>
<code><a href="#admin_base_url">ADMIN_BASE_URL</a></code>

### Emailing

<code><a href="#email_domain">EMAIL_DOMAIN</a></code><br>
<code><a href="#contact_email">CONTACT_EMAIL</a></code><br>
<code><a href="#contact_name">CONTACT_NAME</a></code><br>
<code><a href="#do_not_reply_email">DO_NOT_REPLY_EMAIL</a></code><br>
<code><a href="#smtp_smarthost">SMTP_SMARTHOST</a></code>

### Staging site (not production) behaviour

<code><a href="#staging_site">STAGING_SITE</a></code><br>
<code><a href="#send_reports_on_staging">SEND_REPORTS_ON_STAGING</a></code>

### MapIt (admin boundary service)

<code><a href="#mapit_url">MAPIT_URL</a></code><br>
<code><a href="#mapit_types">MAPIT_TYPES</a></code><br>
<code><a href="#mapit_id_whitelist">MAPIT_ID_WHITELIST</a></code><br>
<code><a href="#mapit_types_children">MAPIT_TYPES_CHILDREN</a></code>

### Localisation and maps

<code><a href="#languages">LANGUAGES</a></code><br>
<code><a href="#time_zone">TIME_ZONE</a></code><br>
<code><a href="#geocoder">GEOCODER</a></code><br>
<code><a href="#geocoding_disambiguation">GEOCODING_DISAMBIGUATION</a></code><br>
<code><a href="#example_places">EXAMPLE_PLACES</a></code><br>
<code><a href="#map_type">MAP_TYPE</a></code><br>
<code><a href="#google_maps_api_key">GOOGLE_MAPS_API_KEY</a></code><br>
<code><a href="#bing_maps_api_key">BING_MAPS_API_KEY</a></code>


### Sundry external services

<code><a href="#gaze_url">GAZE_URL</a></code><br>
<code><a href="#message_manager_url">MESSAGE_MANAGER_URL</a></code>

---

## All the general settings

<dl class="glossary">

  <dt>
    <a name="fms_db_host"><code>FMS_DB_HOST</code></a>,
    <a name="fms_db_port"><code>FMS_DB_PORT</code></a>,
    <a name="fms_db_name"><code>FMS_DB_NAME</code></a>,
    <a name="fms_db_user"><code>FMS_DB_USER</code></a> &amp;
    <a name="fms_db_pass"><code>FMS_DB_PASS</code></a>
  </dt>
  <dd>
    These are the PostgreSQL database details for FixMyStreet.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
            <code>
            FMS_DB_HOST: 'localhost'<br>
            FMS_DB_PORT: '5432'<br>
            FMS_DB_NAME: 'fms'<br>
            FMS_DB_USER: 'fmsuser'<br>
            FMS_DB_PASS: 'aSecretWord'
            </code>
        </li>
      </ul>
    </div>
  </dd>
    
  <dt>
    <a name="base_url"><code>BASE_URL</code></a>
  </dt>
  <dd>
    The base URL of your site.
    <div class="more-info">
      <p>Examples:</p>
      <ul class="examples">
        <li>
          <code>BASE_URL: 'http://www.example.org'</code>
        </li>
        <li>
          <p>
            Use this if you're using the Catalyst development server:
          </p>
          <code>BASE_URL: 'http://localhost:3000'</code>
        </li>
      </ul>
    </div>
  </dd>


  <dt>
    <a name="email_domain"><code>EMAIL_DOMAIN</code></a>, 
    <a name="contact_email"><code>CONTACT_EMAIL</code></a> &amp;
    <a name="contact_name"><code>CONTACT_NAME</code></a>
  </dt>
  <dd>
    The email domain used for emails, and the contact name and email
    for admin use.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>
          EMAIL_DOMAIN: 'example.org'<br>
          CONTACT_EMAIL: 'team@example.org'<br>
          CONTACT_NAME: 'FixMyStreet team'
          </code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="do_not_reply_email"><code>DO_NOT_REPLY_EMAIL</code></a>
  </dt>
  <dd>
    The address used for emails you don't expect a reply to (for example,
    confirmation emails). This can be the same as 
    <code><a href="#contact_email">CONTACT_EMAIL</a></code>, of course, if you don't have a special address.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>DO_NOT_REPLY_EMAIL: 'do-not-reply@example.org'</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="staging_site"><code>STAGING_SITE</code></a>
  </dt>
  <dd>
    Is this site a staging (development) site?
    <p>
      On a staging site, templates/CSS modified times aren't cached. Staging
      sites also don't send reports to bodies unless explicitly configured to
      (see <code><a href="#send_reports_on_staging">SEND_REPORTS_ON_STAGING</a></code>)
      &mdash; this means you can easily test your site without really sending
      emails to the bodies' contacts that may be in your database.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          If this is your live, production server:
          <p>
            <code>STAGING_SITE: 0</code>
          </p>
        </li>
        <li>
          If this is a development or staging server:
          <p>
            <code>STAGING_SITE: 1</code>
          </p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="send_reports_on_staging"><code>SEND_REPORTS_ON_STAGING</code></a>
  </dt>
  <dd>
    There is a safety mechanism on staging sites (where
    <code><a href="#staging_site">STAGING_SITE</a>&nbsp;=&nbsp;1</code>):
    your staging site will <a href="{{ site.baseurl }}customising/send_reports">send reports</a> to your
    <code><a href="#contact_email">CONTACT_EMAIL</a></code> instead of
    the relevant body's contact address.
    This guards against sending test reports to live places.
    <p>
      Use this <code>SEND_REPORTS_ON_STAGING</code> setting to override this
      behaviour. Set it to 1 if you do want your staging site to route reports
      to the bodies' contact addresses.
    </p>
    <p>
      Note that this setting is only relevant on a staging server.
      On your production server (where 
      <code><a href="#staging_site">STAGING_SITE</a>&nbsp;=&nbsp;0</code>)
      it will be ignored.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>SEND_REPORTS_ON_STAGING: 0</code>
          <p>
            Any reports created will now be sent to
            the site's <code><a href="#contact_email">CONTACT_EMAIL</a></code>
            and <em>not</em> the body's. Great for testing!
          </p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="example_places"><code>EXAMPLE_PLACES</code></a>
  </dt>
  <dd>
    The suggested input for a place name or names. By default, this appears
    as a placeholder in the text input on FixMyStreet's front page, and in
    alert emails. It defaults to displaying "High Street, Main Street".
    <p>
      You should ensure that the example places do return clear,
      relevant results if they're entered in the font page text input
      &mdash; this will probably depend on how you've set
      <code><a href="#geocoding_disambiguation">GEOCODING_DISAMBIGUATION</a></code>.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          The default behaviour is this, which you should certainly change:
          <p>
            <code>EXAMPLE_PLACES: [ 'High Street', 'Main Street' ]</code>
          </p>
        </li>
        <li>
            <code>EXAMPLE_PLACES: [ 'Iffley Road', 'Park St, Woodstock' ]</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="languages"><code>LANGUAGES</code></a>
  </dt>
  <dd>
    An array of languages the site supports, each in the following format:
    <p>
    <em>&lt;language code&gt;,&lt;pretty name&gt;,&lt;locale&gt;</em>
    </p>
    <p>
      Some important things to note:
    </p>
    <ul>
      <li>
        Put the default language as the first entry in the list.
      </li>
      <li>
        Do not remove the <code>en-gb</code> line because it is needed for correct operation, even if your site isn't running in English
        (so, typically, you'll put it as the last language in the list).
      </li>
      <li>
        Don't put any extra spaces in the strings (e.g., after the commas).
      </li>
      <li>
        Remember that if you want your site to run in languages other than
        English, you'll also need to check that the translations are 
        available, and your system supports the appropriate
        <a href="{{ site.baseurl }}glossary/#locale" class="glossary">locales</a>.
      </li>
    </ul>
    <p>
      Just adding a language here does not necessarily mean FixMyStreet will
      always use it (for example, a language coded subdomain name or browser preference may be considered). See this page about
      <a href="{{ site.baseurl }}customising/language">languages and FixMyStreet</a> for more information.      
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
<pre>
LANGUAGES:
  - 'en-gb,English,en_GB'
</pre>
        </li>
        <li>
<pre>
LANGUAGES:
  - 'de,German,de_DE'
  - 'en-gb,English,en_GB'
</pre>
          <p>
            Remember that you must always include <code>en-gb,English,en_GB</code>
            in the list.
          </p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="time_zone"><code>TIME_ZONE</code></a>
  </dt>
  <dd>
    If you're running an installation that is being used in a different time zone
    from the server, set the time zone here. Use a 
    <a href="http://en.wikipedia.org/wiki/List_of_tz_database_time_zones">standard time zone (TZ) string</a>.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>TIME_ZONE: 'Asia/Manila'</code>
        </li>
        <li>
          Leave the setting blank to use your server's default:
          <p><code>TIME_ZONE: ''</code></p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="upload_dir"><code>UPLOAD_DIR</code></a> &amp;
    <a name="geo_cache"><code>GEO_CACHE</code></a>
  </dt>
  <dd>
    The file locations for uploaded photos and cached geocoding results.
    Normally you don't need to change these settings from the examples.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>
            UPLOAD_DIR: '../upload/'<br>
            GEO_CACHE: '../cache/'
          </code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="mapit_url"><code>MAPIT_URL</code></a> &amp;
    <a name="mapit_types"><code>MAPIT_TYPES</code></a>
  </dt>
  <dd>
    FixMyStreet uses the external service MapIt to map locations (points) to
    administrative areas: see this
    <a href="{{ site.baseurl }}customising/fms_and_mapit">explanation of MapIt</a>.
    <!-- TODO link to explanation of boundaries -->
    <p>
      You must provide the URL of a MapIt server, and nominate what types of
      area from it you want to use. If you leave this blank, a default area
      will be used everywhere (a URL needs to be given for non-web things, like sending of reports, to function). <!-- TODO explain this: function? -->
    </p>
    <p>
      See also <code><a href="#mapit_id_whitelist">MAPIT_ID_WHITELIST</a></code> to 
      efficiently limit the areas you need (especially if you're using
      global MapIt).
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          If using the Catalyst development server, set to:
          <p><code>
           MAPIT_URL: 'http://localhost:3000/fakemapit/'<br>
           MAPIT_TYPES: [ 'ZZZ' ]
          </code></p>
        </li>
        <li>
          In the UK, you probably want, to cover all councils:
          <p><code>
            MAPIT_URL: 'http://mapit.mysociety.org/'<br>
            MAPIT_TYPES: [ 'DIS', 'LBO', 'MTD', 'UTA', 'CTY', 'COI', 'LGD' ]
          </code></p>
          <p>
            ...but perhaps <code>MAPIT_TYPES: [ 'WMC' ]</code>
            if you want to report on a per-constituency basis?
          </p>
        </li>
        <li>
          If our global MapIt (which is loaded with OpenStreetMap data)
          contains boundaries you can use:
          <p><code>
            MAPIT_URL: 'http://global.mapit.mysociety.org/'
          </code></p>
          <p>
          And then specify whichever type code have the boundaries you want:
          </p>
          <p><code>MAPIT_TYPES: [ 'O06' ]</code></p>
          <p>
            OSM type codes consist of the letter O followed by two digits
            indicating the type of boundary. Typically, the higher the number,
            the more specfic (localised) the boundary type.
          </p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="mapit_id_whitelist"><code>MAPIT_ID_WHITELIST</code></a>
  </dt>
  <dd>
    If you are using global MapIt (see
    <code><a href="#mapit_url">MAPIT_URL</a></code>),
    you might want to restrict FixMyStreet usage
    to only one or more areas, rather than <em>all</em> areas of the
    specified type (afer all, there are a lot of <code>O04</code> boundaries
    in the whole world, for example). Provide a list of all the MapIt
    IDs that your FixMyStreet should recognise. 
    <p>
      Note that you must still set <code><a href="#mapit_types">MAPIT_TYPES</a></code> to match
      the type or types of each of these areas.
    </p>
    <p>
      We recommend you use this setting, because doing so can improves the efficiency of your site's calls to MapIt considerably.
    </p>
    <div class="more-info">
      <p>Examples:</p>
      <ul class="examples">
        <li>
          If you don't specify a whitelist, all results (of the given area
          type) will be considered. This may be OK if you're using a MapIt
          server which is already only returning relevant results.
          <p><code>MAPIT_ID_WHITELIST: []</code></p>
        </li>
        <li>
          Otherwise, explicitly list the IDs (from the MapIt server you're
          using) of the areas you're interested in:
          <p>
          <code>MAPIT_ID_WHITELIST: [ 240838, 246176, 246733 ]</code>
          </p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="mapit_types_children"><code>MAPIT_TYPES_CHILDREN</code></a>
  </dt>
  <dd>
    If your MapIt has the concept of council wards (subareas of councils, where
    people can sign up for alerts, but not report things), then you can give the
    MapIt type codes for them here.
    <p>
    You can leave this blank if your jurisidction doesn't use subareas.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          It's OK to leave this setting blank:
          <p><code>MAPIT_TYPES_CHILDREN: ''</code></p>
        </li>
        <li>
          In the UK we use something like:
          <p><code>
            MAPIT_TYPES_CHILDREN: [ 'DIW', 'LBW', 'MTW', 'UTE', 'UTW', 'CED', 'COP', 'LGW' ]
          </code></p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="geocoder"><code>GEOCODER</code></a>
  </dt>
  <dd>
    Which <a href="{{ site.baseurl }}glossary/#geocoder" class="glossary">geocoder service</a> to use to look up results, for
    example, from front page "Enter your location" searches.
    <p>
    Possible choices are 
    <code>Google</code>, <code>Bing</code>, or <code>OSM</code>.
    By default, FixMyStreet will use OSM, the 
    <a href="{{ site.baseurl }}glossary/#osm" class="glossary">OpenStreetMap</a> 
    geocoder.
    </p>
    <p>
      For more information, see the
      <a href="{{ site.baseurl }}customising/geocoder">page about geocoding</a>.
    </p>
    <p>
    <p>
      It's also possible to add a new geocoder (for example, if your
      jurisdiction provides a custom one). This requires some coding work, but
      you can see exampes of <a
      href="https://github.com/mysociety/fixmystreet/tree/master/perllib/FixMySt
      reet/Geocode">suported geocoders</a> in the FixMyStreet repo.
    </p>
    <p>
      Whichever geocoder you use, check the terms of use for it
      &mdash; there may be restrictions on how you can use it. You may
      also need to provide an API key to use them: see 
      <code><a href="#google_maps_api_key">GOOGLE_MAPS_API_KEY</a></code>
      and 
      <code><a href="#bing_maps_api_key">BING_MAPS_API_KEY</a></code>.
    </p>
    <p>
      See also <code><a href="#geocoding_disambiguation">GEOCODING_DISAMBIGUATION</a></code>
      for restricting geocoder service to specific places.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          FixMyStreet defaults to <code>OSM</code> if you don't specify
          a geocoder:
          <p><code>GEOCODER: ''</code></p>
        </li>
        <li>
          <code>GEOCODER: 'Bing'</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="google_maps_api_key"><code>GOOGLE_MAPS_API_KEY</code></a> &amp;
    <a name="bing_maps_api_key"><code>BING_MAPS_API_KEY</code></a>
  </dt>
  <dd>
    If you wish to use Google Maps or Bing Maps Geocoding, get the
    relevant key and set it here. See also the 
    <code><a href="#geocoder">GEOCODER</a></code> setting.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>
            GOOGLE_MAPS_API_KEY: ''<br>
            BING_MAPS_API_KEY: ''
          </code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="geocoding_disambiguation"><code>GEOCODING_DISAMBIGUATION</code></a>
  </dt>
  <dd>
    This setting provides parameters that are included in 
    <a href="{{ site.baseurl}}glossary/#geocoder" class="glossary">geocoding</a> requests, to hopefully
    return more useful results. The options that will be applied vary depending
    on which geocoder you are using (although unwanted options will be ignored,
    so you can specify all of them, which might be convenient if you change
    geocoder).
    <p>
      Remember that you specify which geocoder you are using with the
      <code><a href="#geocoder">GEOCODER</a></code> setting.
    </p>
    <p>
      For OSM, which is the default, you can use:
    </p>
<pre>
GEOCODING_DISAMBIGUATION:
  bounds: [ <em>&lt;min lat&gt;, &lt;min lon&gt;, &lt;max lat&gt;, &lt;max lon&gt;</em> ]
  country: <em>&lt;country code to restrict results to&gt;</em>
  town: <em>&lt;string added to geocoding requests if not already there&gt;</em>
</pre>
    <p>
      If using Bing, you can use <code>town</code> and <code>bounds</code>, plus any of:
    </p>
<!-- TODO check that Bing and Google don't really spell "centre" as "center" -->
<pre>
  centre: "<em>&lt;lat&gt;&lt;lon&gt;</em>"
  bing_culture: <em>&lt;culture code: see <a href="http://msdn.microsoft.com/en-us/library/hh441729.aspx">Bing docs</a>&gt;</em>
  bing_country: <em>&lt;country name: only accept results that match this&gt;</em>
</pre>
    <p>
      If using Google, you can use:
    </p>
    <!-- TODO not sure Google does support centre -->
<pre>
  centre: "<em>&lt;lat&gt;&lt;lon&gt;</em>"
  span: "<em>&lt;lat span&gt;,&lt;lon span&gt;</em>"
  google_country: <em>&lt;.ccTLD to restrict results to&gt;</em>
  lang: <em>&lt;language for results&gt;</em>
</pre>    
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          This limits geocoding requests to only return results in Mumbai, India:
<pre>          
GEOCODER:
  type: 'OSM'
GEOCODING_DISAMBIGUATION:
  country: 'in'
  town: 'Mumbai'
</pre>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="map_type"><code>MAP_TYPE</code></a>
  </dt>
  <dd>
    The type of map you want to use. If left blank, the default is 
    <code>OSM</code> for 
    <a href="{{ site.baseurl }}glossary/#osm" class="glossary">OpenStreetMap</a>.
    Other options are <code>GoogleOL</code> for Google Open Layers,
    and other UK-specific values, including <code>FMS</code>
    for UK <a href="http://www.fixmystreet.com">FixMyStreet</a>.
    <p>
      Check the useage terms for the type of map you use &mdash; there may be
      restrictions on how you can use them.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>MAP_TYPE: 'OSM'</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="allowed_cobrands"><code>ALLOWED_COBRANDS</code></a>
  </dt>
  <dd>
    FixMyStreet uses a templating 
    <a href="{{ site.baseurl }}glossary/#cobrand" class="glossary">cobrand</a>
    system to provide different looks (and behaviour) for
    different installations. For example, if you create a cobrand
    called <code>moon</code>, then FixMyStreet will look for templates in the
    <code>templates/web/moon</code> directory and CSS in <code>web/cobrands/moon</code>. To make this work, set:
<pre>
ALLOWED_COBRANDS:
  - moon
</pre>
    <p>
      If you specify <em>only one</em> cobrand in this way, your FixMyStreet site will simply run using that cobrand (so that would be <code>moon</code> in the example above). This is probably all you need!
    </p>
    <p>
      However, it is possible for a FixMyStreet site to support <em>more than
      one cobrand at the same time</em>. <strong>Most installations don't need
      this</strong>, but if yours does, it's very useful: the server decides
      which cobrand to use by inspecting the hostname of the incoming request.
    </p>
    <p>
      If you wish to use multiple cobrands, specify them in a list, optionally
      with hostname-matching regular expressions if the name of the cobrand is
      not enough. If the hostname of the current request does not match with
      any in the list, FixMyStreet will use the Default cobrand. For example:
    </p>
<pre>
ALLOWED_COBRANDS:
  - moon
  - venus
</pre>
    <p>
      Any hostname with "<code>moon</code>" in it will use the moon cobrand
      (for example, <code>fixmymoon.org</code>), any with "<code>venus</code>"
      will use the venus cobrand. Anything else (such as
      <code>www.example.com</code>, which contains neither "<code>moon</code>"
      nor "<code>venus</code>") will use the Default cobrand.
    </p>
    <p>
      Instead of using the cobrand's name as the matching string, you can
      specify an alternative string to match on (in fact, the string can be a
      regular expression):
    </p>
<pre>
ALLOWED_COBRANDS:
  - moon: 'orbital'
  - venus
</pre>
    <p>
      Here, any hostname with "<code>orbital</code>" in it will use the moon
      cobrand. Conversely, a request to <code>www.fixmymoon.org</code> won't
      match anything, so it would be served with the Default cobrand instead.
      This also allows development servers to map to different cobrands if
      needed, using DNS subdomains, for example.
    </p>
    <p>
      If you're running a site with multiple cobrands, you'll never want to
      serve the Default cobrand on your production server, so make sure you've
      set ALLOWED_COBRANDS correctly.
    </p>
    <div class="more-info">
      <p>Examples:</p>
      <ul class="examples">
        <li>
          <p>
            Note that specifying <em>a single allowed cobrand</em> is a
            special, simple case: FixMyStreet will always use the
            <code>mycobrand</code>. This is probably all you need!
          </p>
<pre>
ALLOWED_COBRANDS:
  - mycobrand
</pre>
        </li>
        <li>
          <p>
            If there's more than one allowed cobrand, FixMyStreet uses string
            matching (described above) on the hostname to determine which one
            to use:
          </p>
<pre>
ALLOWED_COBRANDS:
  - cobrand1
  - cobrand2: 'hostname_substring2'
  - cobrand3
</pre>
          <p>
            Make sure you've covered everything, because any requests to a
            hostname that don't match will be served using the Default cobrand,
            which isn't what you want.
          </p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="admin_base_url"><code>ADMIN_BASE_URL</code></a>
  </dt>
  <dd>
    This is used in "offensive report" emails to provide a link directly
    to the admin interface. If you want this, set to the full URL of your admin
    interface.
    <!-- TODO: check this, I think it also helps in resource URLs in templates
               but that may only be relevant to mySoc-hosted sites that proxy
               admin through a different domain -->
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>ADMIN_BASE_URL: ''</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="rss_limit"><code>RSS_LIMIT</code></a>
  </dt>
  <dd>
    How many items are returned in the GeoRSS feeds?
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>RSS_LIMIT: '20'</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="all_reports_per_page"><code>ALL_REPORTS_PER_PAGE</code></a>
  </dt>
  <dd>
    How many reports to show per page on the <em>All Reports</em> pages?
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>ALL_REPORTS_PER_PAGE: 100</code>
        </li>
      </ul>
    </div>
  </dd>  

  <dt>
    <a name="smtp_smarthost"><code>SMTP_SMARTHOST</code></a>
  </dt>
  <dd>
    The recommended SMTP smarthost is <code>localhost</code>.
    If you wish to send email through a SMTP server elsewhere, change this
    setting.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>SMTP_SMARTHOST: 'localhost'</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="area_links_from_problems"><code>AREA_LINKS_FROM_PROBLEMS</code></a>
  </dt>
  <dd>
    Should problem reports link to the council summary pages? Set to <code>0</code> to disable, or <code>1</code> to enable.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          Disable links to the summary page:
          <p><code>AREA_LINKS_FROM_PROBLEMS: '0'</code></p>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="gaze_url"><code>GAZE_URL</code></a>
  </dt>
  <dd>
    Gaze is a world-wide service for population density lookups. You can leave
    this as is.
    <!-- TODO used to determine pop density and hence urban/rural map 
              choices? RSS radius? Research this! -->
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>GAZE_URL: 'http://gaze.mysociety.org/gaze'</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="message_manager_url"><code>MESSAGE_MANAGER_URL</code></a>
  </dt>
  <dd>
    If you're using <a href="https://github.com/mysociety/message-manager/">Message Manager</a>,
    integrated with an SMS gateway, include the URL here. FixMyStreet does
    not usually use this, so you can leave it blank.    
    <p>
      Providing a URL does not automatically enable the service &mdash; your <a
      href="{{ site.baseurl }}glossary/#cobrand" class="glossary">cobrand</a>
      must be explicitly coded to use it. Contact us if you need to use Message
      Manager with your FixMyStreet site.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>MESSAGE_MANAGER_URL: ''</code>
        </li>
      </ul>
    </div>
  </dd>
    
</dl>
