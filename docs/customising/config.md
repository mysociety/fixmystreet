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

<div class="attention-box info">
You can look at a summary of the live configuration of your site by going to
the Configuration page of your administration interface, at
<code>/admin/config</code>.
</div>

The FixMyStreet code ships with an example configuration file:
`conf/general.yml-example`.

As part of the [installation process]({{ "/install " | relative_url }}), the example
file gets copied to `conf/general.yml`. You **must** edit this file to suit
your needs.

When you edit this file, remember it must be in the <a
href="http://yaml.org">YAML syntax</a>. It's not complicated but &mdash;
especially if you're editing a list &mdash; be careful to get the indentation
correct. If in doubt, look at the examples already in the file, and don't use
tabs.

## Config settings by topic

The following are all the configuration settings that you can change in `conf/general.yml`.

### Database config

* <code><a href="#fms_db_host">FMS_DB_HOST</a></code>,
<code><a href="#fms_db_port">FMS_DB_PORT</a></code>,
<code><a href="#fms_db_name">FMS_DB_NAME</a></code>,
<code><a href="#fms_db_user">FMS_DB_USER</a></code>, and
<code><a href="#fms_db_pass">FMS_DB_PASS</a></code>

### Site settings and behaviour

* <code><a href="#allowed_cobrands">ALLOWED_COBRANDS</a></code>
* <code><a href="#rss_limit">RSS_LIMIT</a></code>
* <code><a href="#open311_limit">OPEN311_LIMIT</a></code>
* <code><a href="#all_reports_per_page">ALL_REPORTS_PER_PAGE</a></code>
* <code><a href="#area_links_from_problems">AREA_LINKS_FROM_PROBLEMS</a></code>
* <code><a href="#cache_timeout">CACHE_TIMEOUT</a></code>

### URLs and directories

* <code><a href="#base_url">BASE_URL</a></code>
* <code><a href="#secure_proxy_ssl_header">SECURE_PROXY_SSL_HEADER</a></code>
* <code><a href="#geo_cache">GEO_CACHE</a></code>
* <code><a href="#admin_base_url">ADMIN_BASE_URL</a></code>

### Photo storage

* <code><a href="#photo_storage_backend">PHOTO_STORAGE_BACKEND</a></code>
* <code><a href="#photo_storage_options">PHOTO_STORAGE_OPTIONS</a></code>
  * For local filesystem storage:
    * <code><a href="#upload_dir">UPLOAD_DIR</a></code>
    * <code><a href="#symlink_full_size">SYMLINK_FULL_SIZE</a></code>
  * For Amazon S3 storage:
    * <code><a href="#bucket">BUCKET</a></code>
    * <code><a href="#access_key">ACCESS_KEY</a></code>
    * <code><a href="#secret_key">SECRET_KEY</a></code>
    * <code><a href="#prefix">PREFIX</a></code>
    * <code><a href="#create_bucket">CREATE_BUCKET</a></code>
    * <code><a href="#region">REGION</a></code>

### Emailing

* <code><a href="#email_domain">EMAIL_DOMAIN</a></code>
* <code><a href="#contact_email">CONTACT_EMAIL</a></code>
* <code><a href="#contact_name">CONTACT_NAME</a></code>
* <code><a href="#do_not_reply_email">DO_NOT_REPLY_EMAIL</a></code>
* SMTP server settings: <code><a href="#smtp_smarthost">SMTP_SMARTHOST</a></code>,
    <code><a href="#smtp_type">SMTP_TYPE</a></code>,
    <code><a href="#smtp_port">SMTP_PORT</a></code>,
    <code><a href="#smtp_username">SMTP_USERNAME</a></code>,
    and <code><a href="#smtp_password">SMTP_PASSWORD</a></code>

### Login methods, authentication

* Social login: <code><a href="#facebook_app_id">FACEBOOK_APP_ID</a></code>,
    <code><a href="#facebook_app_secret">FACEBOOK_APP_SECRET</a></code>,
    <code><a href="#twitter_key">TWITTER_KEY</a></code>, and
    <code><a href="#twitter_secret">TWITTER_SECRET</a></code>
* SMS text authentication: <code><a href="#sms_authentication">SMS_AUTHENTICATION</a></code>,
    <code><a href="#phone_country">PHONE_COUNTRY</a></code>,
    <code><a href="#twilio_account_sid">TWILIO_ACCOUNT_SID</a></code>,
    <code><a href="#twilio_auth_token">TWILIO_AUTH_TOKEN</a></code>, and
    <code><a href="#twilio_from_parameter">TWILIO_FROM_PARAMETER</a></code>
* <code><a href="#login_required">LOGIN_REQUIRED</a></code>
* <code><a href="#signups_disabled">SIGNUPS_DISABLED</a></code>

### Staging site (not production) behaviour

* <code><a href="#staging_site">STAGING_SITE</a></code>
* <code><a href="#staging_flags">STAGING_FLAGS</a></code>

### MapIt (admin boundary service)

* <code><a href="#mapit_url">MAPIT_URL</a></code>
* <code><a href="#mapit_types">MAPIT_TYPES</a></code>
* <code><a href="#mapit_api_key">MAPIT_API_KEY</a></code>
* <code><a href="#mapit_id_whitelist">MAPIT_ID_WHITELIST</a></code>
* <code><a href="#mapit_generation">MAPIT_GENERATION</a></code>
* <code><a href="#mapit_types_children">MAPIT_TYPES_CHILDREN</a></code>

### Localisation and maps

* <code><a href="#languages">LANGUAGES</a></code>
* <code><a href="#time_zone">TIME_ZONE</a></code>
* <code><a href="#geocoder">GEOCODER</a></code>
* <code><a href="#geocoding_disambiguation">GEOCODING_DISAMBIGUATION</a></code>
* <code><a href="#example_places">EXAMPLE_PLACES</a></code>
* <code><a href="#map_type">MAP_TYPE</a></code>
* <code><a href="#google_maps_api_key">GOOGLE_MAPS_API_KEY</a></code>
* <code><a href="#bing_maps_api_key">BING_MAPS_API_KEY</a></code>

### Sundry external services

* <code><a href="#gaze_url">GAZE_URL</a></code>
* <code><a href="#message_manager_url">MESSAGE_MANAGER_URL</a></code>

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
    <a name="secure_proxy_ssl_header"><code>SECURE_PROXY_SSL_HEADER</code></a>
  </dt>
  <dd>
    If you are behind a proxy that is performing SSL termination, and so
    FixMyStreet is e.g. responding locally on a non-HTTPS connection, then you
    need to make your proxy set a custom HTTP header saying that the request
    was via HTTPS, and then set this value to a two-element list containing the
    trusted HTTP header and the required value.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>SECURE_PROXY_SSL_HEADER: [ 'X-Forwarded-Proto', 'https' ]</code>
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
    Is this site a 
    <a href="{{ "/glossary/#staging" | relative_url }}" class="glossary__link">staging</a>
    (or <a href="{{ "/glossary/#development" | relative_url }}" class="glossary__link">development</a>)
    site?
    <p>
      On a staging site, templates/CSS modified times aren't cached. Staging
      sites also don't send reports to bodies unless explicitly configured to
      (see <code><a href="#staging_flags">STAGING_FLAGS</a></code>)
      &mdash; this means you can easily test your site without really sending
      emails to the bodies' contacts that may be in your database.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          If this is your live
          <a href="{{ "/glossary/#production" | relative_url }}" class="glossary__link">production</a>
          server:
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
    <a name="staging_flags"><code>STAGING_FLAGS</code></a>
  </dt>
  <dd>
    <p>
      A variety of flags that change the behaviour of a site when
      <code><a href="#staging_site">STAGING_SITE</a></code> is <code>1</code>.
      <code>send_reports</code> being set to 0 will
      <a href="{{ "/customising/send_reports" | relative_url }}">send
      reports</a> to the reporter <em>instead of</em> the relevant body's
      contact address; <code>skip_checks</code> will stop cobrands from
      performing some checks such as the map pin location being within their
      covered area, which makes testing multiple cobrands much easier;
      <code>enable_appcache</code> lets you say whether the appcache should be
      active or not.
    </p>
    <p>
      Note that this setting is only relevant on a
      <a href="{{ "/glossary/#staging" | relative_url }}" class="glossary__link">staging</a>
      server.
      On your
      <a href="{{ "/glossary/#production" | relative_url }}" class="glossary__link">production</a>
      server (where 
      <code><a href="#staging_site">STAGING_SITE</a></code> is <code>0</code>)
      it will be ignored.
    </p>
    <div class="more-info">
      <p>Example:</p>
<pre>
STAGING_FLAGS:
  send_reports: 0
  skip_checks: 1
  enable_appcache: 0
</pre>
    </div>
          <p>
            Any reports created will now be sent to the email of the reporter
            and <em>not</em> the body's; any location checks are skipped, and
            we won't ever use appcache. Great for testing!
          </p>
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
        Don't put any extra spaces in the strings (e.g., after the commas).
      </li>
      <li>
        Remember that if you want your site to run in languages other than
        English, you'll also need to check that the translations are 
        available, and your system supports the appropriate
        <a href="{{ "/glossary/#locale" | relative_url }}" class="glossary__link">locales</a>.
      </li>
    </ul>
    <p>
      Just adding a language here does not necessarily mean FixMyStreet will
      always use it (for example, a language coded subdomain name or browser preference may be considered). See this page about
      <a href="{{ "/customising/language" | relative_url }}">languages and FixMyStreet</a> for more information.
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
    <a name="geo_cache"><code>GEO_CACHE</code></a>
  </dt>
  <dd>
    The file location for cached geocoding results.
    Normally you don't need to change this setting from the example.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>
            GEO_CACHE: '../cache/'
          </code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <code><a name="facebook_app_id">FACEBOOK_APP_ID</a></code> &amp;
    <code><a name="facebook_app_secret">FACEBOOK_APP_SECRET</a></code>
  </dt>
  <dd>
    If these parameters are set to a Facebook App's ID and secret, then
    a user will be able to log in using their Facebook account when reporting,
    updating, or logging in. <a href="../login/">More details</a>
  </dd>

  <dt>
    <code><a name="twitter_key">TWITTER_KEY</a></code> &amp;
    <code><a name="twitter_secret">TWITTER_SECRET</a></code>
  </dt>
  <dd>
    If these parameters are set to a Twitter App's key and secret, then
    a user will be able to log in using their Twitter account when reporting,
    updating, or logging in. <a href="../login/">More details</a>
  </dd>

  <dt>
    <code><a name="sms_authentication">SMS_AUTHENTICATION</a></code>
  </dt>
  <dd>
    Set this to 1 if you wish people to be able to use their mobiles as login
    identifiers, receiving confirmation codes by text to report, update or
    login in a similar way to how they receive a link in a confirmation email.
    <a href="../login/">More details</a>
  </dd>

  <dt>
    <code><a name="phone_country">PHONE_COUNTRY</a></code>
  </dt>
  <dd>
    Set this to the country code of where you are operating the site, so that
    phone number parsing knows how to deal with national phone numbers entered.
  </dd>

  <dt>
    <a name="twilio_account_sid"><code>TWILIO_ACCOUNT_SID</code></a> &amp;
    <a name="twilio_auth_token"><code>TWILIO_AUTH_TOKEN</code></a>
  </dt>
  <dd>
    These are your Twilio account details to use for sending text messages for
    report and update verification.
    See the <a href="https://www.twilio.com/docs/usage/api">Twilio docs</a> for more information.
  </dd>

  <dt>
    <a name="twilio_from_parameter"><code>TWILIO_FROM_PARAMETER</code></a>
  </dt>
  <dd>
    This is the phone number or alphanumeric string to use as the From of any
    sent text messages.
    You must specify either this or <code>TWILIO_MESSAGING_SERVICE_SID</code>.
    See the <a href="https://www.twilio.com/docs/sms/send-messages">Twilio docs</a> for more information.
  </dd>

  <dt>
    <a name="twilio_from_parameter"><code>TWILIO_MESSAGING_SERVICE_SID</code></a>
  </dt>
  <dd>
    This is the unique id of the Twilio Messaging Service you want to associate with this message.
    You must specify either this or <code>TWILIO_FROM_PARAMETER</code>.
    See the <a href="https://www.twilio.com/docs/sms/send-messages">Twilio docs</a> for more information.
  </dd>

  <dt>
    <a name="login_required"><code>LOGIN_REQUIRED</code></a>
  </dt>
  <dd>
    If you're running an installation that should only be accessible to logged
    in people, set this variable.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>LOGIN_REQUIRED: 1</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="signups_disabled"><code>SIGNUPS_DISABLED</code></a>
  </dt>
  <dd>
    If you don't want any new people to be able to use the site, only the users
    you have already created, then set this variable.
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>SIGNUPS_DISABLED: 1</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="mapit_url"><code>MAPIT_URL</code></a>,
    <a name="mapit_types"><code>MAPIT_TYPES</code></a>,
    <a name="mapit_api_key"><code>MAPIT_API_KEY</code></a>
  </dt>
  <dd>
    FixMyStreet uses the external service MapIt to map locations (points) to
    administrative areas: see this
    <a href="{{ "/customising/fms_and_mapit" | relative_url }}">explanation of MapIt</a>.
    <!-- TODO link to explanation of boundaries -->
    <p>
      You must provide the URL of a MapIt server, and nominate what types of
      area from it you want to use. If you leave this blank, a default area
      will be used everywhere (a URL needs to be given for non-web things, like sending of reports, to function). <!-- TODO explain this: function? -->
      If the MapIt you are using requires an API key, you can provide one.
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
            MAPIT_URL: 'https://mapit.mysociety.org/'<br>
            MAPIT_API_KEY: '12345'<br>
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
      the type or types of each of these areas. And we recommend you set
      <code><a href="#mapit_generation">MAPIT_GENERATION</a></code> too.
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
    <a name="mapit_generation"><code>MAPIT_GENERATION</code></a>
  </dt>
  <dd>
    If you have set
    <code><a href="#mapit_id_whitelist">MAPIT_ID_WHITELIST</a></code>, then you
    should also specify the generation of MapIt data you are using, especially
    if you are using our global MapIt service.
    <p>
      Global MapIt uses <a href="{{ "/glossary/#osm" | relative_url }}"
      class="glossary__link">OpenStreetMap</a> data. From time to time we import the latest
      data in order to pull in newly-added boundaries, or reflect changes to existing
      ones. When this happens, the area IDs may change, which means the values in your
      <code><a href="#mapit_id_whitelist">MAPIT_ID_WHITELIST</a></code> might no longer
      be correct (because, by default, MapIt returns values from the <em>latest</em>
      generation of data). Use the <code>MAPIT_GENERATION</code> setting to lock
      the area IDs in your whitelist &mdash; and the geometry described by their boundary
      data &mdash; to the specific generation they belong to. MapIt's generations
      are numbered with an integer that we increment with each update.
    </p>
    <p>
      To determine the generation of the data you're using, when you initially
      identify the area IDs look at the <code>generation-high</code> and
      <code>generation-low</code> values MapIt is returning. For example,
      here's the global MapIt data for
      <a href="http://global.mapit.mysociety.org/point/4326/100.466667,13.75.html">a
      point within Thailand</a> &mdash; the national border for Thailand is the
      top level returned ("OSM Administrative Boundary Level 2"). Look on
      that page for "Exists in generations" (or "<code>generation-</code>" in the 
      JSON data, available by changing MapIt's <code>.html</code> URL to <code>.json</code>)
      to see the range of generations in which this area appears. You should
      probably use the highest number (that is, the most recent update).
    </p>
    <div class="more-info">
      <p>Examples:</p>
      <ul class="examples">
        <li>
          In this example, the whitelist contains a single area ID from global
          MapIt's generation <code>4</code> for 
          <a href="http://global.mapit.mysociety.org/area/507455.html?generation=4">Thailand's national border</a>
          (hence <code>507455</code> and
          <a href="{{ "/glossary/#area-type" | relative_url }}" class="glossary__link">area type</a> <code>O02</code>):
<pre>MAPIT_URL: http://global.mapit.mysociety.org/
MAPIT_TYPES: ['O02']
MAPIT_ID_WHITELIST: [507455]
MAPIT_ID_GENERATION: 4
</pre>
        </li>
        <li>
          If you're not using a <code>MAPIT_ID_WHITELIST</code>
          you usually don't need to specify a <code>MAPIT_ID_GENERATION</code>.
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
    Which <a href="{{ "/glossary/#geocoder" | relative_url }}" class="glossary__link">geocoder service</a> to use to look up results, for
    example, from front page "Enter your location" searches.
    <p>
    Possible choices are 
    <code>Google</code>, <code>Bing</code>, or <code>OSM</code>.
    By default, FixMyStreet will use <code>OSM</code>, the 
    <a href="{{ "/glossary/#osm" | relative_url }}" class="glossary__link">OpenStreetMap</a> 
    geocoder.
    </p>
    <p>
      For more information, see the
      <a href="{{ "/customising/geocoder" | relative_url }}">page about geocoding</a>.
    </p>
    <p>
      It's also possible to add a new geocoder (for example, if your
      jurisdiction provides a custom one). This requires some coding work, but
      you can see exampes of <a
      href="https://github.com/mysociety/fixmystreet/tree/master/perllib/FixMyStreet/Geocode">supported geocoders</a> in the FixMyStreet repo.
    </p>
    <p>
      Whichever geocoder you use, check the terms of use for it
      &mdash; there may be restrictions. You may also need to provide an API
      key to use it: see 
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
    <a href="{{ "/glossary/#geocoder" | relative_url }}" class="glossary__link">geocoding</a> requests, to hopefully
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
<pre>
  centre: "<em>&lt;lat&gt;&lt;lon&gt;</em>"
  bing_culture: <em>&lt;culture code: see <a href="http://msdn.microsoft.com/en-us/library/hh441729.aspx">Bing docs</a>&gt;</em>
  bing_country: <em>&lt;country name: only accept results that match this&gt;</em>
</pre>
    <p>
      If using Google, you can use:
    </p>
<pre>
  bounds: [ <em>&lt;min lat&gt;, &lt;min lon&gt;, &lt;max lat&gt;, &lt;max lon&gt;</em> ]
  google_country: <em>&lt;.ccTLD to restrict results to&gt;</em>
  lang: <em>&lt;language for results&gt;</em>
</pre>    
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          This limits geocoding requests to only return results in Mumbai, India:
<pre>          
GEOCODER: 'OSM'
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
    <a href="{{ "/glossary/#osm" | relative_url }}" class="glossary__link">OpenStreetMap</a>.
    Other options are <code>GoogleOL</code> for Google Open Layers,
    and other UK-specific values, including <code>FMS</code>
    for UK <a href="https://www.fixmystreet.com">FixMyStreet</a>.
    <p>
      Check the usage terms for the type of map you use &mdash; there may be
      restrictions.
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
    <a href="{{ "/glossary/#cobrand" | relative_url }}" class="glossary__link">cobrand</a>
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
      serve the Default cobrand on your 
      <a href="{{ "/glossary/#production" | relative_url }}" class="glossary__link">production</a>
      server, so make sure you've set ALLOWED_COBRANDS correctly.
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
    to the admin interface, and to make sure the admin can work through a
    proxy. It defaults to `/admin` in your installation.
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
    <a name="open311_limit"><code>OPEN311_LIMIT</code></a>
  </dt>
  <dd>
    How many items are returned by default in an Open311 response?
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>OPEN311_LIMIT: 100</code>
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
    The default SMTP smarthost is <code>localhost</code>, a mail server on the
    same machine you are running FixMyStreet. If you wish to send email through
    a SMTP server elsewhere, change this and the other SMTP settings.
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
    <a name="smtp_type"><code>SMTP_TYPE</code></a>
  </dt>
  <dd>
    If your SMTP server supports SSL or TLS, set this variable to 'ssl' or
    'tls', otherwise leave it as '' for unencrypted SMTP.
  </dd>
  <dt>
    <a name="smtp_port"><code>SMTP_PORT</code></a>
  </dt>
  <dd>
    The default SMTP port is 25 for unencrypted, 465 for SSL and 587 for TLS.
    Leave as '' to use the default, otherwise set to your SMTP server port.
  </dd>
  <dt>
    <a name="smtp_username"><code>SMTP_USERNAME</code></a>
  </dt>
  <dd>
    The username for authenticating with your SMTP server, if required.
  </dd>
  <dt>
    <a name="smtp_password"><code>SMTP_PASSWORD</code></a>
  </dt>
  <dd>
    The password for authenticating with your SMTP server, if required.
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
    <a name="cache_timeout"><code>CACHE_TIMEOUT</code></a>
  </dt>
  <dd>
    The time, in seconds, that the front page stats/recent list should be cached for.
    Also used for the max-age of <code>/reports</code>. Defaults to 3600s (1 hour).
  </dd>

  <dt>
    <a name="gaze_url"><code>GAZE_URL</code></a>
  </dt>
  <dd>
    Gaze is a world-wide service for population density lookups. You can leave
    this as is. It is used to provide the default radius for email/RSS alerts
    and to set the default zoom level on a map page (so in rural areas, you're
    more likely to get a slightly more zoomed out map).
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <code>GAZE_URL: 'https://gaze.mysociety.org/gaze'</code>
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
      href="{{ "/glossary/#cobrand" | relative_url }}" class="glossary__link">cobrand</a>
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

  <dt>
    <a name="photo_storage_backend"><code>PHOTO_STORAGE_BACKEND</code></a>
  </dt>
  <dd>
    The storage backend to use for uploaded photos.
    <p>
      Possible choices are <code>FileSystem</code> or <code>S3</code>.
      By default, FixMyStreet will use <code>FileSystem</code>.
    </p>
    <p>
      The chosen backend can be configured via the
      <code><a href="#photo_storage_options">PHOTO_STORAGE_OPTIONS</a></code>
      setting, see below.
    </p>
  </dd>

  <dt>
    <a name="photo_storage_options"><code>PHOTO_STORAGE_OPTIONS</code></a>
  </dt>
  <dd>
    <p>
      Contains backend-specific configuration options for photo storage.
    </p>
    <p>
      For the <code>FileSystem</code> backend, the following apply:
    </p>
    <ul>
      <li><code><a href="#upload_dir">UPLOAD_DIR</a></code></li>
      <li><code><a href="#symlink_full_size">SYMLINK_FULL_SIZE</a></code></li>
    </ul>
    <p>
      For the <code>S3</code> backend, the following apply:
    </p>
    <ul>
      <li><code><a href="#bucket">BUCKET</a></code></li>
      <li><code><a href="#access_key">ACCESS_KEY</a></code></li>
      <li><code><a href="#secret_key">SECRET_KEY</a></code></li>
      <li><code><a href="#prefix">PREFIX</a></code></li>
      <li><code><a href="#create_bucket">CREATE_BUCKET</a></code></li>
      <li><code><a href="#region">REGION</a></code></li>
    </ul>
  </dd>

  <dt>
    <a name="upload_dir"><code>UPLOAD_DIR</code></a>
  </dt>
  <dd>
    <p>
      The file location for uploaded photos.
      Normally you don't need to change this setting from the example.
    </p>
    <p>
      Only applies when <code>PHOTO_STORAGE_BACKEND</code> is <code>FileSystem</code>.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <pre>
PHOTO_STORAGE_OPTIONS:
  UPLOAD_DIR: '../upload/'
          </pre>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="upload_dir"><code>SYMLINK_FULL_SIZE</code></a>
  </dt>
  <dd>
    <p>
      Defaults to false; if this is true, then requests for full size images
      will be symlinked from the photo cache, not copied there. You can use this
      if static files are being served by your web server.
    </p>
    <p>
      Only applies when <code>PHOTO_STORAGE_BACKEND</code> is <code>FileSystem</code>.
    </p>
  </dd>

  <dt>
    <a name="bucket"><code>BUCKET</code></a>
  </dt>
  <dd>
    <p>
      The name of the S3 bucket to store photos in.
    </p>
    <p>
      <strong>Required</strong> when <code>PHOTO_STORAGE_BACKEND</code> is <code>S3</code>.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <pre>
PHOTO_STORAGE_OPTIONS:
  BUCKET: 'fixmystreet-photos'
          </pre>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="access_key"><code>ACCESS_KEY</code></a> &amp;
    <a name="secret_key"><code>SECRET_KEY</code></a>
  </dt>
  <dd>
    <p>
      The AWS access & secret keys to use when connecting to S3.
      You should use a role with minimal privileges to manage objects in a specific S3 bucket, not your root keys.
    </p>
    <p>
      <strong>Required</strong> when <code>PHOTO_STORAGE_BACKEND</code> is <code>S3</code>.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <pre>
PHOTO_STORAGE_OPTIONS:
  ACCESS_KEY: 'AKIAMYSUPERCOOLKEY'
  SECRET_KEY: '12345/AbCdEFgHIJ98765'
          </pre>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="prefix"><code>PREFIX</code></a>
  </dt>
  <dd>
    <p>
      An optional directory prefix to prepended to S3 filenames. Useful if, for example, you are using a bucket shared between other projects or FixMyStreet instances.
    </p>
    <p>
      <strong>Optional</strong>. Only applies when <code>PHOTO_STORAGE_BACKEND</code> is <code>S3</code>.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <pre>
PHOTO_STORAGE_OPTIONS:
  PREFIX: '/fixmystreet_photos/'
          </pre>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="create_bucket"><code>CREATE_BUCKET</code></a>
  </dt>
  <dd>
    <p>
      Set to <code>1</code> (or <code>true</code>) if FixMyStreet should create the S3 bucket specified in <code>BUCKET</code> if it doesn't already exist.
    </p>
    <p>
      <strong>Optional</strong>. Only applies when <code>PHOTO_STORAGE_BACKEND</code> is <code>S3</code>.
    </p>
  </dd>

  <dt>
    <a name="region"><code>REGION</code></a>
  </dt>
  <dd>
    <p>
      The AWS region to create the S3 bucket in.
    </p>
    <p>
      <strong>Optional</strong>. Only applies when <code>CREATE_BUCKET</code> is enabled.
    </p>
    <div class="more-info">
      <p>Example:</p>
      <ul class="examples">
        <li>
          <pre>
PHOTO_STORAGE_OPTIONS:
  CREATE_BUCKET: 1
  REGION: 'eu-west-2'
          </pre>
        </li>
      </ul>
    </div>
  </dd>

</dl>
