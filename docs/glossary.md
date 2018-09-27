---
layout: page
title: Glossary
---

FixMyStreet glossary
====================

<p class="lead">Glossary of terms for FixMyStreet, mySociety's geographic
problem reporting platform.</p>

The [FixMyStreet](https://www.fixmystreet.com/) Platform is an open source
project to help people run websites for reporting common street problems such
as potholes and broken street lights to an appropriate authority. For
technical information, see
[fixmystreet.org](https://fixmystreet.org/).

## Definitions

<ul class="definitions">
  <li><a href="#abuse-list">abuse list</a></li>
  <li><a href="#area">admin boundary</a></li>
  <li><a href="#administrator">administrator</a></li>
  <li><a href="#alert">alert</a></li>
  <li><a href="#area-type">area type</a></li>
  <li><a href="#abuse-list">banning</a></li>
  <li><a href="#body">body</a></li>
  <li><a href="#catalyst">Catalyst</a></li>
  <li><a href="#category">category</a></li>
  <li><a href="#cobrand">cobrand</a></li>
  <li><a href="#config-variable">config variable</a></li>
  <li><a href="#token">confirmation</a></li>
  <li><a href="#contact">contact</a></li>
  <li><a href="#council">council</a></li>
  <li><a href="#dashboard">dashboard</a></li>
  <li><a href="#development">development site</a></li>
  <li><a href="#devolve">devolved contacts</a></li>
  <li><a href="#flagged">flagged</a></li>
  <li><a href="#geocoder">geocoder</a></li>
  <li><a href="#gettext">gettext</a></li>
  <li><a href="#git">git</a></li>
  <li><a href="#kml">KML</a></li>
  <li><a href="#integration">integration</a></li>
  <li><a href="#latlong">lat-long</a></li>
  <li><a href="#locale">locale</a></li>
  <li><a href="#map">map</a></li>
  <li><a href="#mapit">MapIt</a></li>
  <li><a href="#message-manager">Message Manager</a></li>
  <li><a href="#open311">Open311</a></li>
  <li><a href="#partial">partial report</a></li>
  <li><a href="#production">production site</a></li>
  <li><a href="#report">problem report</a></li>
  <li><a href="#sms">SMS</a></li>
  <li><a href="#survey">questionnaire</a></li>
  <li><a href="#send-method">send method</a></li>
  <li><a href="#staff-user">staff users</a></li>
  <li><a href="#staging">staging site</a></li>
  <li><a href="#state">state</a></li>
  <li><a href="#survey">survey</a></li>
  <li><a href="#template">template</a></li>
  <li><a href="#token">token</a></li>
  <li><a href="#update">update</a></li>
  <li><a href="#user-account">user account</a></li>
</ul>

<dl class="glossary">

  <dt>
    <a name="abuse-list">abuse list</a> (also banning)
  </dt>
  <dd>
    The <strong>abuse list</strong> is a list of email addresses that are
    banned from using the site for misuse. In our experience, this is rare;
    but, for example, a user who repeatedly posts offensive or vexatious <a
    href="#report" class="glossary__link">problem reports</a> may be blocked in this
    way.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/running/users/" | relative_url }}">About users</a> for more about managing
          abusive users.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="administrator">administrator</a>
  </dt>
  <dd>
    An <strong>administrator</strong> is a user who has access to the back-end
    admin (so can do things like add or edit <a href="#body"
    class="glossary__link">bodies</a>, modify <a href="#report"
    class="glossary__link">problem reports</a>, and <a href="{{ "/running/users/" | relative_url }}">manage
    users</a>). An administrator should also have access to the email account
    to which user support emails are sent.
    <p>
      Depending on how the site has been configured, this may be a regular
      FixMyStreet <a href="#user-account" class="glossary__link">user</a>. However,
      often it's an <code>htauth</code> user instead (which is a user managed
      by the webserver, rather than the FixMyStreet application itself).
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See also <strong><a href="#staff-user" class="glossary__link">staff
          user</a></strong>, which is a FixMyStreet user who works for a <a
          href="#body" class="glossary__link">body</a>.
        </li>
        <li>
          See the <a href="{{ "/running/admin_manual/" | relative_url }}">Administrator's Manual</a> for
          details of what an administrator does.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="alert">alert</a>
  </dt>
  <dd>
    FixMyStreet users can subscribe to emails (or RSS feeds) which will notify
    them when reports or updates are made within a certain area. These notifications
    are called <strong>alerts</strong>.
    <p>
      Users can subscribe to various alerts - for example, all reports made
      within a body, or within a certain distance of their chosen location
    </p>
    <p>
      Alerts are available on the FixMyStreet site at <code>/alert</code>.
    </p>
  </dd>

  <dt>
    <a name="area">area</a> (also administrative boundary)
  </dt>
  <dd>
    FixMyStreet uses <strong>areas</strong> to determine which <a href="#body"
    class="glossary__link">bodies</a> are responsible for handling problems at a
    specific location. When a user clicks on the <a href="#map"
    class="glossary__link">map</a>, FixMyStreet finds all the bodies that are responsible
    for that area. Technically, an area comprises one or more polygons on a
    map &mdash; either those areas already exist (from <a href="#osm"
    class="glossary__link">OpenStreetMap</a>, for example) or you can provide your
    own. You can add your own areas to <a href="#mapit"
    class="glossary__link">MapIt</a> by drawing them on a map, or importing
    shapefiles from other mapping applications.
    <p>
      The
      <code><a href="{{ "/customising/config/#mapit_id_whitelist" | relative_url }}">MAPIT_ID_WHITELIST</a></code>
      config setting can explicitly list the <em>only</em>
      areas your installation will recognise &mdash; alternatively, you can
      limit them by <a href="#area-type" class="glossary__link">area type</a>
      instead.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/customising/boundaries/" | relative_url }}">more about boundaries</a>
          and the different ways to set them up.
        </li>
        <li>
          See <a href="{{ "/customising/fms_and_mapit/" | relative_url }}">How FixMyStreet uses
          MapIt</a> for more about how bodies relate to <a href="#area"
          class="glossary__link">areas</a>.
        </li>
        <li>
          See the <a href="http://global.mapit.mysociety.org/">global MapIt
          website</a> for more about the service.
        </li>
        <li>
          Every area has an <strong><a href="#area-type" class="glossary__link">area
          type</a></strong> which indicates what level of administration
          boundary it represents.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="area-type">area type</a>
  </dt>
  <dd>
    The <a href="#area" class="glossary__link">areas</a> that <a href="#mapit"
    class="glossary__link">MapIt</a> returns are administrative boundaries. In
    addition to each boundary's geometry (that is, its actual shape on the
    map), MapIt also identifies what <strong>area type</strong> it is. The
    area type indicates what level of administrative boundary that area
    represents &mdash; for example, a national border, or the boundary of a
    province, or a ward, and so on.
    <p>
      The
      <code><a href="{{ "/customising/config/#mapit_types" | relative_url }}">MAPIT_TYPES</a></code>
      config setting specifies the area types your installation uses.
    </p>
    <p>
      These types' actual values vary depending on the source of the data. For
      example, if you're using our global MapIt, these will look like
      <code>O02</code>, <code>O03</code>, <code>O04</code> and so on (because
      those are the values <a href="#osm" class="glossary__link">OpenStreetMap</a>
      uses, from where global MapIt gets its data). OpenStreetMap's codes get
      higher as the boundaries get more local: <code>O02</code> indicates a
      <em>national boundary</em>, codes <code>O03</code> and above are for
      subnational areas. The exact meaning of such boundaries varies according
      to the administrative hierarchy of the specific country.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/customising/boundaries/" | relative_url }}">more about boundaries</a>
          and the different ways to set them up.
        </li>
        <li>
          See <a href="{{ "/customising/fms_and_mapit/" | relative_url }}">How FixMyStreet uses
          MapIt</a> for more about how bodies relate to <a href="#area"
          class="glossary__link">areas</a>.
        </li>
        <li>
          See the <a href="http://global.mapit.mysociety.org/">global MapIt
          website</a> for more about the service.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="body">body</a>
  </dt>
  <dd>
    A <strong>body</strong> is the authority responsible for a problem. Bodies
    can be councils, local government departments (such as the Department of
    Public Works, or the Highways Department), or even private companies that
    are paid to fix particular problems.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/running/bodies_and_contacts/" | relative_url }}">Managing bodies and
          contacts</a> for how to set these up.
        </li>
        <li>
          See <a href="{{ "/customising/fms_and_mapit/" | relative_url }}">How FixMyStreet uses
          MapIt</a> for more about how bodies relate to <a href="#area"
          class="glossary__link">areas</a>.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="catalyst">Catalyst</a> (Perl framework)
  </dt>
  <dd>
    FixMyStreet is written in Perl, and uses the <strong>Catalyst</strong>
    framework. For basic customisation you don't need to write any Perl &mdash;
    you can get a site up and running with your own colours, logo, and location
    without needing to do any programming. But if you do need to look into the
    source code, you'll find the Catalyst framework helps, because it's a
    "Model-View-Controller" framework (which is common in web applications).
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See the <a href="{{ "/directory_structure/" | relative_url }}">FixMyStreet
          directory structure</a> explained.
        </li>
        <li>
          If you need to understand more about the framework, see the 
          <a href="http://www.catalystframework.org">Catayst project website</a>.
        </li>
        <li>
          More about  
          <a href="{{ "/customising/" | relative_url }}">customising FixMyStreet</a>.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="category">category</a>
  </dt>
  <dd>
    <strong>Categories</strong> describe the different types of problem that a
    user can report, for example, "Pothole", or "Graffiti". The names of these
    categories are displayed in the drop-down menu when the user reports a
    problem. FixMyStreet uses the category, together with the <a href="#area"
    class="glossary__link">area</a>, to determine which <a href="#contact"
    class="glossary__link">contact</a> will be sent the report.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/running/bodies_and_contacts/" | relative_url }}">Managing bodies and
          contacts</a> for how to set these up.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="cobrand">cobrand</a>
  </dt>
  <dd>
    FixMyStreet uses a system of cobranding to customise the
    way the site looks and behaves. This can be as simple as changing the
    colour scheme and logo, right through to overriding specific behaviour with
    custom Perl code. Each <strong>cobrand</strong> has a name which the FixMyStreet
    code uses when deciding which style and behaviour to apply.
    <p>
      For a live example of cobranding, consider two sites in the UK. Our <a
      href="https://www.fixmystreet.com/">FixMyStreet site</a> runs with the
      <code>fixmystreet</code> cobrand, which has a yellow-and-asphalt
      appearance, and has an example street from the city of Manchester in the
      "enter a street name" box. But the <a
      href="https://fixmystreet.oxfordshire.gov.uk/">Oxfordshire site</a> is
      running the <code>oxfordshire</code> cobrand, which makes the site green
      and suggests a street name from Oxfordshire.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          The cobrands that FixMyStreet will use are defined in the
          <code><a href="{{ "/customising/config/#allowed_cobrands" | relative_url }}">ALLOWED_COBRANDS</a></code>
          config setting, based on the URL of the incoming request.
        </li>
        <li>
          <a href="{{ "/customising/" | relative_url }}">more about customising</a>, including a
          <a href="{{ "/customising/checklist/" | relative_url }}">checklist</a> of the key things to consider.
        </li>
        <li>
          See <a href="{{ "/customising/cobrand-module/" | relative_url }}">Cobrand module</a> for
          information about the Perl class you can override.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="config-variable">config variable</a> (also config setting, or config option)
  </dt>
  <dd>
    A <strong>config variable</strong> is one of the settings in the
    configuration file <code>conf/general.yml</code>. Config variables affect
    the way your FixMyStreet installation behaves, and you must make sure they
    are correct when you install and customise your site.
    <p>
      Note that <code>conf/general.yml</code> is <em>not</em> in the <a
      href="#git" class="glossary__link">git repository</a> (it cannot be, because
      it would contain your own private config settings, such as your database
      password). Instead, there is an example file,
      <code>cong/general.yml-example</code> you can
      copy and edit. If you install using an automated method such as the 
       <a href="{{ "/install/install-script/" | relative_url }}">installation script</a>
       or <a href="{{ "/install/docker/" | relative_url }}">Docker</a>, this file will 
       automatically be created for you.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/customising/config" | relative_url }}">all the config settings</a>
          you need to get your site running.
        </li>
        <li>
          See <a href="http://www.yaml.org/">the YAML website</a> for
          everything about YAML, which is the format of the
          <code>general.yml</code> file
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="contact">contact</a>
  </dt>
  <dd>
    Each <a href="#body" class="glossary__link">body</a> has one or more
    <strong>contacts</strong> to which reports are sent. Typically these are
    email addresses (but if you have <a href="#integration"
    class="glossary__link">integrated</a> with the body's back-end, these may be
    codes or IDs used by that instead of email addresses). It's not uncommon
    for a body to have many contacts with the same email address, but with
    different <a href="#category" class="glossary__link">categories</a>.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/running/bodies_and_contacts/" | relative_url }}">Managing bodies and
          contacts</a> for how to set these up.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="council">council</a>
  </dt>
  <dd>
    A <strong>council</strong> is an example of a <a href="#body"
    class="glossary__link">body</a>. We sometimes use the term because in the UK,
    where we first launched FixMyStreet, the bodies to which the site sends
    its <a href="#report" class="glossary__link">problem reports</a> were all called
    councils.
  </dd>

  <dt>
    <a name="dashboard">dashboard</a>
  </dt>
  <dd>
    The <strong>dashboard</strong> shows a summary of statistics (numbers of
    <a href="#report" class="glossary__link">problem reports</a> by <a href="state"
    class="glossary__link">state</a>, and so on) for a single <a href="#body"
    class="glossary__link">body</a>.
    <p>
      The dashboard is shown on the FixMyStreet website at
      <code>/dashboard</code>, but can only be accessed by a <a
      href="#staff-user" class="glossary__link">staff user</a>.
    </p>
  </dd>

  <dt>
    <a name="development">development site</a> (also: dev, development server)
  </dt>
  <dd>
    A <strong>dev server</strong> is one that is running your FixMyStreet site
    so you can <a href="{{ "/customising/" | relative_url }}">customise it</a>, experiment
    with different settings, and test that it does what you expect.
    This is different from a
    <a href="#production" class="glossary__link">production server</a>, which is the one your
    users actually visit running with live data, or a
    <a href="#staging" class="glossary__link">staging server</a>,
    which is used for testing code before it goes live.
    <p>
      On your dev server, you should set
      <code><a href="{{ "/customising/config/#staging_site" | relative_url }}">STAGING_SITE</a></code>
      to <code>1</code>.
    </p>
  </dd>

  <dt>
    <a name="devolve">devolved contacts</a>
  </dt>
  <dd>
    Normally, you specifiy the
    <a href="#administrator" class="glossary__link">send method</a>
    for a whole <a href="#body" class="glossary__link">body</a>, so all
    its <a href="#report" class="glossary__link">problem reports</a>
    will be sent in that way. But you can <strong>devolve</strong>
    the decision of which send method to use to the body's
    <a href="#contact" class="glossary__link">contacts</a>
    instead. For example, this lets you mix both email addresses and
    <a href="#open311" class="glossary__link">Open311</a>
    service codes within the same body.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/running/bodies_and_contacts/" | relative_url }}">Managing
          bodies and contacts</a> for how to set these up.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="flagged">flagged</a>
  </dt>
  <dd>
    A report or a user can be <strong>flagged</strong> if an <a
    href="#administrator" class="glossary__link">administrator</a> wants to mark it
    as for special attention, typically because it may be abusive or
    inappropriate. Flagged items are shown in the admin on their own page
    (<code>/admim/flagged</code>) so can be more easily managed. This is
    especially useful if you have more than one administrator, as you can see
    whether other administrators have marked the user or report as
    problematic.
    <p>
      Flagging users is only advisory: it marks them for attention, but does
      not ban them. You can ban a user who persists in abusing your
      FixMyStreet site by adding them to the <a href="#abuse-list"
      class="glossary__link">abuse list</a>.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/running/users/" | relative_url }}">About users</a> for more about managing
          abusive users.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="geocoder">geocoder</a>
  </dt>
  <dd>
    The <strong>geocoder</strong> turns the name of a place into a <a
    href="#long-lat" style="glossary">long-lat</a> position. FixMyStreet then
    uses this to display the appropriate region on the <a href="#map"
    class="glossary__link">map</a>.
    <p>
      FixMyStreet can use the <a href="#osm"
      class="glossary__link">OpenStreetMap</a>, Google, or Bing geocoders, or a custom one.
      The 
      <code><a href="{{ "/customising/config/#geocoder" | relative_url }}">GEOCODER</a></code>
      setting controls which one your site uses.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/customising/fms_and_mapit/" | relative_url }}">How FixMyStreet uses
          MapIt</a> for more about how the geocoder is used.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="gettext">gettext</a>
  </dt>
  <dd>
    <strong>gettext</strong> is a set of utitlies provided by the GNU project
    to help get translations into software. We use it throughout FixMyStreet
    so that anywhere English text appears (the default), it can be replaced
    with an appropriate translation in a different language. This presupposes
    the text has been translated &mdash; the alternative translations are 
    storied in <code>.po</code> files.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          More about <a href="{{ "/customising/language/" | relative_url }}">translating
          FixMyStreet</a>.
        </li>
        <li>
          See the <a href="http://www.gnu.org/software/gettext/">GNU gettext page</a>
          for more about the project.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="git">git</a> (also GitHub, git repository, and git repo)
  </dt>
  <dd>
    We use a popular source code control system called <strong>git</strong>. This
    helps us track changes to the code, and also makes it easy for other people
    to duplicate and even contribute to our software.
    <p>
      The website <a href="https://github.com/mysociety">github.com</a> is a central, public
      place where we make our software available. Because it's Open Source, you can
      inspect the code there (FixMyStreet is mostly written in the programming language
      Perl), report bugs, suggest features and many other useful things.
    </p>
    <p>
      The entire set of files that form the FixMyStreet platform is called the
      <strong>git repository</strong> or <strong>repo</strong>. When you
      install FixMyStreet, you are effectively cloning our repository on your
      own machine.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See the <a href="{{ "/install/" | relative_url }}">installation instructions</a> which will
          clone the FixMyStreet repo.
        </li>
        <li>
          Everything about git from the <a
          href="http://git-scm.com/">official website</a>.
        </li>
        <li>
          See <a href="https://github.com/mysociety">the mySociety projects on
          GitHub</a>.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="integration">integration</a> with bodies' back-end systems
  </dt>
  <dd>
    By default, FixMyStreet sends <a href="#report" class="glossary__link">problem
    reports</a> by email. The disadvantage of using email is that many <a
    href="#body" class="glossary__link">bodies</a> then need to transfer the
    information in the email into their own back-end systems, such as their
    works database or customer management system. But FixMyStreet can be
    <strong>integrated</strong> with those back ends so the data is passed
    directly into them, instead of via email.
    <p>
      There are three levels of integration:
    </p>
    <ol>
      <li>
        problems reports are injected directly into the back end
      </li>
      <li>
        updates made in the back end are automatically passed back into
        FixMyStreet
      </li>
      <li>
        problem reports created in the back end (that is, not initiated on
        FixMyStreet) are passed into FixMyStreet
      </li>
    </ol>
    <p>
      Integration is often related to <a href="#cobrand"
      class="glossary__link">cobranding</a>, which is how you can customise the look
      and behaviour of your FixMyStreet installation.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          More about <a href="{{ "/customising/integration/" | relative_url }}">integrating FixMyStreet</a>
          with back-end systems (includes diagrams)
        </li>
        <li>
          See <a
          href="https://www.fixmystreet.com/council">FixMyStreet
          for Councils</a> for mySociety's commercial support for UK councils
        </li>
        <li>
          <a href="#open311" class="glossary__link">Open311</a> is the easiest form
          of integration.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="kml">KML</a> (Keyhole Markup Language)
  </dt>
  <dd>
    <strong>KML</strong> is an open standard XML format for geographic data.
    <a href="#mapit" class="glossary__link">MapIt</a> can read KML files. If you need
    to provide your own <a href="#area" class="glossary__link">admin boundary</a>
    data, you can use common GIS software (such as Google Earth) to create a
    KML "shape file" containing the boundaries, and then import them to MapIt.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          Article about <a
          href="http://en.wikipedia.org/wiki/Keyhole_Markup_Language">Keyhole
          Markup Language</a> on wikipedia.
        </li>
        <li>
          <a href="https://developers.google.com/kml/documentation/">KML documentation</a>
          at Google Developers.
        </li>
        <li>
          More about <a href="{{ "/customising/boundaries/" | relative_url }}">admin boundaries</a>
          and why you might need to create them yourself.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="latlong">lat-long</a>
  </dt>
  <dd>
    A <strong>lat-long</strong> is a pair of coordinates (latitude and
    longitude) that describe a location. FixMyStreet sends a lat-long to <a
    href="#mapit" class="glossary__link">MapIt</a> when the user clicks on the <a
    href="#map" class="glossary__link">map</a>.
    <p>
      Example lat-long for London, UK: <code>51.5072759,-0.1276597</code>
    </p>
  </dd>

  <dt>
    <a name="locale">locale</a>
  </dt>
  <dd>
    A <strong>locale</strong> defines the way things like language, date
    formats, and currency should be handled. Locales are identified by codes
    like <code>en_GB</code> or <code>hr_HR</code> (these are actually language
    and region codes). If you need your installation to present FixMyStreet
    using anything other than the default English translations, then the
    locale you want <em>must</em> be installed on your server (note &mdash;
    this is about your <em>server</em>'s configuration, not a FixMyStreet
    setting). It's common for servers to support many locales, but not all
    locales are installed by default.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See more about <a href="{{ "/customising/" | relative_url }}">customising</a> your
          installation, which includes language and translation considerations
        </li>
        <li>
          To see what locales your server currently supports, do <code>locale
          -a</code>. You can generate missing locales with
          <code>locale-gen</code> &mdash; for example, <code>sudo locale-gen
          fr_FR.UTF-8</code>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="map">map</a>
  </dt>
  <dd>
    FixMyStreet displays a <strong>map</strong> so users can easily pinpoint
    the location of the problem they are reporting. By default, these are <a
    href="#osm" class="glossary__link">OpenStreetMap</a> tiles displayed using
    OpenLayers, but you can configure your installation to use other maps,
    including your own custom tiles.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="http://openlayers.org/">OpenLayers</a>, the JavaScript map
          library FixMyStreet uses by default
        </li>
        <li>
          <a href="http://leafletjs.com/">Leaflet</a>, another JS map library
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="mapit">MapIt</a>
  </dt>
  <dd>
    <strong>MapIt</strong> is a web service that manages <a href="#area"
    class="glossary__link">administrative boundary areas</a>. More specifically,
    FixMyStreet uses this to determine which areas (and hence which <a
    href="#body" class="glossary__link">bodies</a>) cover any given location.
    <p>
      In a nutshell, MapIt accepts a <a href="#latlong"
      class="glossary__link">lat-long</a> position, and returns a list of areas.
    </p>
    <p>
      Like FixMyStreet, MapIt is a product by <a
      href="https://www.mysociety.org/">mySociety</a>.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="{{ "/customising/fms_and_mapit/" | relative_url }}">How FixMyStreet uses MapIt</a>
        </li>
        <li>
          <a
          href="http://global.mapit.mysociety.org/">global.mapit.mysociety.org</a>
          is the global MapIt service
        </li>
        <li>
          <a href="https://mapit.mysociety.org/">mapit.mysociety.org</a> is the
          UK MapIt service
        </li>
        <li>
          See <a
          href="http://mapit.poplus.org/">mapit.poplus.org</a>
          for technical information, including how to set up your own
          installation
        </li>
        <li>
          See <a href="{{ "/customising/boundaries/" | relative_url }}">more about boundaries</a>,
          which define the areas, and the different ways to set them up.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="message-manager">Message Manager</a>
  </dt>
  <dd>
    <strong>Message Manager</strong> is a mySociety web application that
    can integrate an <a href="#sms" class="glossary__link">SMS</a> gateway
    with FixMyStreet.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="https://github.com/mysociety/message-manager/">Message
          Manager on GitHub</a>.
        </li>
        <li>
          More about
          <a href="{{ "/install/fixmystreet-with-sms/" | relative_url }}">running
          FixMyStreet with SMS</a>, and the limitations of doing so.
        </li>
      </ul>
    </div>
  </dd>
  
  <dt>
    <a name="open311">Open311</a>
  </dt>
  <dd>
    <strong>Open311</strong> is an open standard for making online requests
    for a civic service (such as fixing a pothole). FixMyStreet implements
    Open311 so it's easy to <a href="#integration"
    class="glossary__link">integrate</a> with <a href="#body"
    class="glossary__link">bodies</a> whose back-ends also support it.
    <p>
      Open311 is effectively a more efficient alternative to email as a <a
      href="#send-method" class="glossary__link">send method</a>.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          More about <a href="{{ "/customising/integration/" | relative_url }}">integrating FixMyStreet</a>
          using Open311 (includes diagrams)
        </li>
        <li>
          mySociety blog post <a
          href="https://www.mysociety.org/2013/01/10/open311-introduced/">introducing
          Open311</a>
        </li>
        <li>
          mySociety blog post <a
          href="https://www.mysociety.org/2013/01/17/open311-explained//">explaining
          basic Open311 functionality</a>.
        </li>
        <li>
         <a href="http://www.open311.org/">open311.org</a>, the Open311
         project's own website
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="osm">OpenStreetMap (OSM)</a>
  </dt>
  <dd>
    <strong>OpenStreetMap</strong> is a project that creates and distributes
    free geographic data for the world, with an open license. By default,
    FixMyStreet's <a href="#map" class="glossary__link">map</a> uses OSM maps.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="http://www.openstreetmap.org/">www.openstreetmap.org</a>
        </li>
        <li>
          <a href="http://wiki.openstreetmap.org/wiki/Main_Page">OpenStreetMap
          wiki</a> for technical OSM documentation
        </li>
        <li>
          web interface to <a
          href="http://nominatim.openstreetmap.org/">OpenStreetMap's
          geocoder</a>
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="partial">partial report</a>
  </dt>
  <dd>
    Some external applications might create a report by first uploading a photograph
    and capturing a description, without identifying the location. This is a 
    <strong>partial report</strong> and is not shown until it has been completed.
    <p>
      <em>FixMyStreet itself does not create partial reports</em>, because all problem
      reports created within the application always include a location.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          Remember that FixMyStreet uses the location to
          <a href="{{ "/fms_and_mapit/" | relative_url }}">determine where to send reports</a>,
          so a partial report (having no location) effectively has no 
          <a href="#body" class="glossary__link">body</a> responsible for it.
        </li>
      </ul>
    </div>
  </dd>


  <dt>
    <a name="report">problem report</a>
  </dt>
  <dd>
    When a FixMyStreet user reports a problem (for example, a pothole or a
    broken streetlight), that <strong>problem report</strong> is sent to the
    <a href="#body" class="glossary__link">body</a> responsible. Problem reports
    remain unpublished until the user confirms them; they may also be hidden
    by an administrator. In both cases, the report is still stored in
    FixMyStreet's back-end database.
    <p>
      Users may choose to submit their report anonymously. This means that
      their name is not displayed on the website, although it is still sent to
      the body.
    </p>
    <p>
      A report may include a photograph.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="{{ "/customising/send_reports/" | relative_url }}">How FixMyStreet sends reports</a>.
        </li>
      </ul>
    </div>
  </dd>
  
  <dt>
    <a name="production">production site</a> (also: live, production server)
  </dt>
  <dd>
    A <strong>production server</strong> is one that is running your FixMyStreet site
    for real users, with live data. This is different from a
    <a href="#development" class="glossary__link">development server</a>, which you use make your
    customisation and environment changes and try to get them to all work OK, or a
    <a href="#staging" class="glossary__link">staging server</a>, which is used for testing code
    and configuration after it's been finished but before it goes live.
    <p>
      Your production site should be configured to run as efficiently as possible: for
      example, with caching disabled, and debugging switched off. Make sure you set
      <code><a href="{{ "/customising/config/#staging_site" | relative_url }}">STAGING_SITE</a></code>
      to <code>0</code>.
    </p>
    <p>
      If you have a staging server, the system environment of your staging and
      production servers should be identical.
    </p>
    <p>
      You should never need to edit code directly on your production server.
      We recommend you make any changes to the program code on your
      development server, add it to the appropriate branch, test it on a staging
      server, and then deploy it directly &mdash; that is, from the repo &mdash; on production.
    </p>
  </dd>

  <dt>
    <a name="send-method">send method</a>
  </dt>
  <dd>
    The <strong>send method</strong> is the way that a <a href="#report"
    class="glossary__link">problem report</a> is sent to the <a href="#body"
    class="glossary__link">body</a> responsible for fixing it. <em>By default, the
    send method is email.</em>
    <p>
      Alternatives to email are only available if some <a href="#integration"
      class="glossary__link">integration</a> with the target body's back-end is
      available (for example, if they are using <a href="#open311"
      class="glossary__link">Open311</a>).
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="{{ "/customising/send_reports/" | relative_url }}">How FixMyStreet sends
          reports</a>.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="staging">staging server</a> (also: staging site)
  </dt>
  <dd>
    A <strong>staging server</strong> is one that you use for testing code or configuration
    before it goes live. This is different from a <a href="#development"
    class="glossary__link">development server</a>, on which you change the code and settings to
    make everything work, or the
    <a href="#production" class="glossary__link">production server</a>, which is the
    site your users visit running with live data.
    <p>
      On your staging server, you should set
      <code><a href="{{ "/customising/config/#staging_site" | relative_url }}">STAGING_SITE</a></code>
      to <code>1</code>.
    </p>
    <p>
      If you have a staging server, the system environment of your staging and
      production servers should be identical.
    </p>
    <p>
      You should never need to edit code directly on your staging or production servers.
      We recommend you make any changes to the program code on your
      development server, add it to the appropriate branch, and then deploy it directly
      &mdash; that is, from the repo &mdash; on staging.
    </p>
  </dd>

  <dt>
    <a name="state">state</a>
  </dt>
  <dd>
    A <a href="#report" class="glossary__link">problem report</a> can go through several
    <strong>states</strong> in its lifetime. Problems typically start as
    <em>unconfirmed</em>, then <em>open</em>, then <em>fixed</em>. There are
    other states, including those that can only be allocated by a <a
    href="#staff-user" class="glossary__link">staff user</a> or an <a
    href="#administrator" class="glossary__link">administrator</a>.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See the <a href="{{ "/running/admin_manual/" | relative_url }}">Administrator's manual</a>
          for a more detailed list of problem states.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="staff-user">staff user</a>
  </dt>
  <dd>
    A <strong>staff user</strong> is someone on FixMyStreet who works for a <a
    href="#body" class="glossary__link">body</a>. This means their <a href=
    "#user-account" class="glossary__link">user account</a> is marked as belonging
    to that body. This differentiates such accounts from normal users, who are
    members of the public.
    <p>
      A staff user is <strong>not</strong> the same thing as an <a
      href="#administrator" class="glossary__link">administrator</a>. A staff user
      logs into the public website, like a normal user, but has additional
      powers over some reports. An administrator logs into the private admin
      and has access to how the whole FixMyStreet site is run.
    </p>
    <p>
      A staff user has additional powers that <em>only apply to <a
      href="#report" class="glossary__link">problem reports</a> for their own
      body</em>, such as:
    </p>
    <ul>
      <li>
        hiding reports
      </li>
      <li>
        setting state of reports to things other than just <em>fixed</em> and
        <em>not fixed</em>
      </li>
      <li>
        viewing a <a href="#dashboard" class="glossary__link">dashboard</a> showing
        the body's statistics
      </li>
    </ul>
    <p>
      Actually, the distinction between an administrator and a staff user, and
      the powers staff users have, can vary depending on your installation's <a
      href="#cobrand" class="glossary__link">cobrand</a>.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          compare <strong>staff user</strong> to <strong><a href="#administrator"
          class="glossary__link">administrator</a></strong>
        </li>
        <li>
          See <a href="{{ "/running/users/" | relative_url }}">About users</a> for more about managing
          users, including how to create a staff account.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="sms">SMS</a> (Short Message Service, or texting)
  </dt>
  <dd>
      <strong>SMS</strong> is the service for sending text messages across a
      phone network. FixMyStreet is primarily a web-based application, but
      it is possible to run it so that it can accept
      <a href="#report" class="glossary__link">problem reports</a>
      over SMS too.
      <p>
        An <strong>SMS gateway</strong> is a service that passes SMS messages
        between the phone network and the internet. This allows you to receive
        or send messages from a web application, such as FixMyStreet.
      </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          More about <a
          href="{{ "/install/fixmystreet-with-sms/" | relative_url }}">running FixMyStreet with SMS</a>, and the limitations of doing so.
        </li>
        <li>
          <a href="http://en.wikipedia.org/wiki/Short_Message_Service">More about SMS</a>
          on wikipedia.
        </li>
        <li>
          The <a href="#message-manager" class="glossary__link">Message Manager</a> web application can be used to integrate FixMyStreet
          with an SMS gateway.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="survey">survey</a> (or questionnaire)
  </dt>
  <dd>
      By default, FixMyStreet sends out <strong>surveys</strong> (also called
      <strong>questionnaires</strong>) to users four weeks after they reported a
      problem. The surveys encourage the users who reported each problem to
      indicate whether or not the problem has been fixed (if it hasn't already
      been marked as such). These surveys help you collect data on the performance
      of the <a href="#bodies" class="glossary__link">bodies</a>. 
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="{{ "/running/surveys" | relative_url }}">more about surveys</a>
        </li>
        <li>
          Survey data is available to <a href="#administrator"
          class="glossary__link">administrators</a> on the Survey page of the admin
        </li>
        <li>
          Survey <a href="#template" class="glossary__link">templates</a> are in
          <code>/templates/email/default/questionnaire.txt</code> and
          <code>/templates/web/base/questionnaire</code>
        </li>
        <li>
          If you don't want your FixMyStreet site to send out surveys, you can
          switch off this behaviour in a <a
          href="{{ "/customising/cobrand-module/" | relative_url }}">cobrand module</a>.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="template">template</a>
  </dt>
  <dd>
    FixMyStreet creates its web pages (and emails) using
    <strong>templates</strong>. If you want to customise your installation
    beyond just changing the colours and logo (that is, using CSS), you can
    add new templates for your own <a href="#cobrand"
    class="glossary__link">cobrand</a>. You only need to create templates that are
    different from the default ones.
    <p>
      Templates are in the <code>templates/web</code> and
      <code>templates/email</code> directories &mdash; themselves containing
      directories for every cobrand.
    </p>
    <p>
      The web templates use the popular Template Toolkit system. You can
      change the templates without needing to know how to write Perl (the
      programming language the rest of FixMyStreet is written in).
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See more about using templates to <a
          href="{{ "/customising/" | relative_url }}">customise</a> your installation.
        </li>
        <li>
          See the <a href="http://www.template-toolkit.org/">Template Toolkit
          website</a>, which is the system the FixMyStreet web templates use.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="token">token</a> (also confirmation link)
  </dt>
  <dd>
    By default, FixMyStreet uses confirmation emails containing links as
    authorisation where the user is not already logged in. The links
    contain unique <strong>tokens</strong> (these look like runs of random
    letters and numbers).
    <p>
    If text authentication is switched on, authentication can also be
    performed by text, sending a numeric code to enter in order to proceed.
    </p>
    <p>
      Tokens are typically used to confirm the final part (authorisation) of an
      action, and are therefore often related to a specific <a href="#report"
      class="glossary__link">report</a>. FixMyStreet generally doesn't delete tokens
      after they've been used because (as they often live on in email inboxes)
      people sometimes click on old confirmation links to access reports
      &mdash; so the mapping between token and report is still useful.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          Tokens are implemented using <code>AuthToken</code> from mySociety's
          <a href="https://github.com/mysociety/commonlib">commonlib</a>
          common library.
        </li>
        <li>
          For details about authorisation and how sessions work, see 
          <a href="{{ "/running/users/#sessions" | relative_url }}">more about users</a>.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="update">update</a>
  </dt>
  <dd>
    Anyone can add an <strong>update</strong> to an existing <a href="#report"
    class="glossary__link">problem report</a>. The update can contain a message, a
    picture, and even change the report's <a href="#state"
    class="glossary__link">state</a>.
    <p>
      For example, someone can leave an update on a pothole report to say, "I
      think the hole is getting bigger!", and add a photograph. Or they can
      mark the problem as fixed.
    </p>
    <p>
      <a href="#staff-user" class="glossary__link">Staff users</a> can add more
      specific states if they update a problem that belongs to the body they
      work for.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          FixMyStreet supports <strong><a href="#integration"
          class="glossary__link">integration</a></strong>, which can enable
          automatic updates whenever a body fixes a problem.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="user-account">user account</a>
  </dt>
  <dd>
    FixMyStreet creates a <strong>user account</strong> for every user,
    identified by the user's email address. An <a href="#administrator"
    class="glossary__link">administrator</a> can change the email address, and the
    name, of a user account. Optionally, a user account can have a password
    associated with it too.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="{{ "/running/users/" | relative_url }}">About users</a> for more about managing
          users.
        </li>
        <li>
          A <strong><a href="#staff-user" class="glossary__link">staff
          user</a></strong> is one whose user account is marked as belonging
          to a <a href="#body" class="glossary__link">body</a>.
        </li>
      </ul>
    </div>
  </dd>
</dl>
