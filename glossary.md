---
layout: default
title: Glossary
---

FixMyStreet glossary
====================

<p class="lead">Glossary of terms for FixMyStreet, mySociety's geographic problem reporting platform.</p>

The [FixMyStreet](http://www.fixmystreet.com/) Platform is an open source project
to help people run websites for reporting common street problems such as
potholes and broken street lights to an appropriate authority. For technical
information, see [code.fixmystreet.com](http://code.fixmystreet.com).

Definitions
-----------

[abuse list](#abuse-list) |
[area](#area) |
[body](#body) |
[category](#category) |
[cobrand](#cobrand) |
[contact](#contact) |
[flagged](#flagged) |
[geocoder](#geocoder) |
[integration](#integration) |
[lat-long](#latlong) |
[map](#map) |
[MapIt](#mapit) |
[Open311](#open311) |
[OpenStreetMap](#osm) |
[problem report](#report) |
[send method](#send-method)

---

<dl class="glossary">

<!--
  <dt>
    <a name="example">example</a>
  </dt>
  <dd>
    An <strong>example</strong> is something that is explained here.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="customising/fms_and_mapit">how FixMyStreet uses MapIt</a> for more about examples.
        </li>
      </ul>
    </div>
  </dd>
-->
  <dt>
    <a name="abuse-list">abuse list</a>
  </dt>
  <dd>
    The <strong>abuse list</strong> is a list of email addresses that are banned from using the site
    for misuse. In our experience, this is rare; but, for example, a user who repeatedly posts offensive or vexatious
    <a href="#report" class="glossary">problem reports</a> may be blocked in this way.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="/running/users">About users</a> for more about managing abusive users.
        </li>
      </ul>
    </div>
  </dd>
  
  
  <dt>
    <a name="area">area</a>
  </dt>
  <dd>
    FixMyStreet uses <strong>areas</strong> to determine which <a href="#body" class="glossary">bodies</a> are responsible for handling
    problems at a specific location. For example, when a user clicks on the <a href="#map" class="glossary">map</a>, FixMyStreet
    finds all the bodies which cover that area.  Technically, an area comprises one or more polygons on a map --
    either those areas already exist (from <a href="#osm" class="glossary">OpenStreetMap</a>, for example) or you can draw your own.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="customising/fms_and_mapit">How FixMyStreet uses MapIt</a> for more about how bodies relate to
          <a href="#areas" class="glossary">areas</a>.
        </li>
        <li>
          See the <a href="http://global.mapit.mysociety.org">global MapIt website</a> for more about the service.
        </li>
      </ul>
    </div>
  </dd>
  
  <dt>
    <a name="body">body</a>
  </dt>
  <dd>
    A <strong>body</strong> is the authority responsible for a problem. Bodies can be councils, local government
    departments (such as the Department of Public Works, or the Highways Department), or even private companies
    that are paid to fix particular problems.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="/running/bodies_and_contacts">Managing bodies and contacts</a> for how to set
          these up.
        </li>
        <li>
          See <a href="/customising/fms_and_mapit">How FixMyStreet uses MapIt</a> for more about how bodies relate
          to <a href="#areas" class="glossary">areas</a>.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="category">category</a>
  </dt>
  <dd>
    <strong>Categories</strong> describe the different types of problem that a user can report, for example,
    "Pothole", or "Graffiti". The names of these categories are displayed in the drop-down menu 
    when the user reports a problem. FixMyStreet uses the category, together with the 
    <a href="#area" class="glossary">area</a>, to determine which <a href="#contact" class="glossary">contact</a>
    will be sent the report.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="/running/bodies_and_contacts">Managing bodies and contacts</a> for how to set
          these up.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="cobrand">cobrand</a>
  </dt>
  <dd>
    FixMyStreet uses a system of <strong>cobranding</strong> to customise the way the site looks and behaves.
    This can be as simple as changing the colourscheme and logo, right through to overriding specific
    behaviour with custom Perl code.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="customising/">more about customising</a>
        </li>
        <li>
          See <a href="customising/cobrand-module">Cobrand module</a> for information about the Perl class your
          can override.
        </li>
      </ul>
    </div>
  </dd>
  
  <dt>
    <a name="contact">contact</a>
  </dt>
  <dd>
    Each <a href="#body" class="glossary">body</a> has one or more <strong>contacts</strong> to which reports are
    sent. Typically these are email addresses (but if you have <a href="#integration" class="glossary">integrated</a>
    with the body's back-end, these may be codes or IDs used by that instead of email addresses). It's not uncommon
    for a body to have many contacts with the same email address, but with different 
    <a href="#category" class="glossary">categories</a>. 
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="/running/bodies_and_contacts">Managing bodies and contacts</a> for how to set
          these up.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="flagged">flagged</a>
  </dt>
  <dd>
    A report or a user can be <strong>flagged</strong> if you, or any administrator, wants to mark it as
    for special attention, typically because it may be abusive or inappropriate. Flagged items are shown
    in the admin on their own page (`flagged`) so can be more easily managed. This is especially useful if
    you have a team of administrators, and want to monitor troublesome users.
    <p>
      A user who persists in abusing your FixMyStreet site can be added to the <a href="#abuse-list" class="glossary">abuse
      list</a>.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="/running/users">About users</a> for more about managing abusive users.
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="geocoder">geocoder</a>
  </dt>
  <dd>
    The <strong>geocoder</strong> turns the name of a place into a <a href="#long-lat" style="glossary">long-lat</a> position.
    FixMyStreet then uses this to display the appropriate region on the <a href="#map" class="glossary">map</a>.
    <p>
      FixMyStreet can use the <a href="#osm" class="glossary">OpenStreetMap</a>, Google, or Bing geocoders, or can
      use a custom one.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="customising/fms_and_mapit">How FixMyStreet uses MapIt</a> for more about how the geocoder is used.
        </li>
      </ul>
    </div>
  </dd>
  
  <dt>
    <a name="integration">integration</a> with bodies' back-end systems
  </dt>
  <dd>
    By default, FixMyStreet sends problem reports by email. The disadvantage of using email is that many
    <a href="#body" class="glossary">bodies</a> then need to transfer the information in the email into 
    their own back-end systems, such as their works database or customer management system. But 
    FixMyStreet can be <strong>integrated</strong> with those back ends so the data is passed directly
    into them, instead of via email.
    <p>
      There are three levels of integration:
    </p>
    <ol>
      <li>problems reports are injected directly into the back end</li>
      <li>updates made in the back end are automatically passed back into FixMyStreet</li>
      <li>problem reports created in the back end (that is, not initiated on FixMyStreet) are passed into FixMyStreet</li>
    </ol>
    <p>
      Integration is often related to <a href="#cobrand" class="glossary">cobranding</a>, which is how you can customise the look
      and behaviour of your FixMyStreet installation.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          See <a href="http://www.mysociety.org/for-councils/fixmystreet/">FixMyStreet for Councils</a> for 
          mySociety's commercial support for UK councils
        </li>
        <li>
          <a href="#open311" class="glossary">Open311</a> is the easiest form of integration.
        </li>
      </ul>
    </div>
  </dd>
  
  <dt>
    <a name="latlong">lat-long</a>
  </dt>
  <dd>
    A <strong>lat-long</strong> is a pair of coordinates (latitude and longitude) that describe a location.
    FixMyStreet sends a lat-long to <a href="#mapit" class="glossary">MapIt</a> when the user clicks on
    the <a href="#map" class="glossary">map</a>.
    <p>
      Example lat-long for London, UK: <code>51.5072759,-0.1276597</code> 
    </p>
  </dd>
  
  <dt>
    <a name="map">map</a>
  </dt>
  <dd>
    FixMyStreet displays a <strong>map</strong> so users can easily pin-point the location of the problem
    they are reporting. By default, these are OpenStreetMap tiles displayed using OpenLayers, but you can 
    configure your installation to use other maps, including your own custom tiles.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="http://openlayers.org">OpenLayers</a>, the JavaScript map library FixMyStreet uses by default
        </li>
        <li>
          <a href="http://leafletjs.com">Leaflet</a>, another JS map library
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="mapit">MapIt</a>
  </dt>
  <dd>
    <strong>MapIt</strong> is a web service that manages administrative boundary areas. More specifically,
    FixMyStreet uses this to determine which <a href="#area" class="glossary">areas</a> (and hence which
    <a href="#body" class="glossary">bodies</a>) cover any given location.
    <p>
      In a nutshell, MapIt accepts a <a href="#latlong" class="glossary">lat-long</a> position, and returns a list of areas.
    </p>
    <p>
      Like FixMyStreet, MapIt is a product by <a href="http://www.mysociety.org">mySociety</a>.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="customising/fms_and_mapit">How FixMyStreet uses MapIt</a>
        </li>
        <li>
          <a href="http://global.mapit.mysociety.org">global.mapit.mysociety.org</a> is the global MapIt service
        </li>
        <li>
          <a href="http://mapit.mysociety.org">mapit.mysociety.org</a> is the UK MapIt service
        </li>
        <li>
          See <a href="http://code.mapit.mysociety.org">code.mapit.mysociety.org</a> for technical information,
          including how to set up your own installation
        </li>
      </ul>
    </div>
  </dd>
  
  <dt>
    <a name="open311">Open311</a>
  </dt>
  <dd>
    <strong>Open311</strong> is an open standard for making online requests for a civic service (such as
    fixing a pothole). FixMyStreet implements Open311 so it's easy to <a href="#integration" class="glossary">integrate</a>
    with <a href="#body" class="glossary">bodies</a> whose back-ends also support it.
    <p>
      Open311 is effectively a more efficient alternative to email as a <a href="#send-method" class="glossary">send method</a>.
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          mySociety blog post <a href="http://www.mysociety.org/2013/01/10/open311-introduced/">introducing Open311</a>
        </li>
        <li>
          mySociety blog post <a href="http://www.mysociety.org/2013/01/17/open311-explained//">explaining basic Open311 functionality</a>.
        </li>
        <li>
         <a href="http://www.open311.org">open311.org</a>, the Open311 project's own website
        </li>
      </ul>
    </div>
  </dd>

  <dt>
    <a name="osm">OpenStreetMap (OSM)</a>
  </dt>
  <dd>
    <strong>OpenStreetMap</strong> is a project that creates and distributes free geographic data for the world, with
    an open license. By default, FixMyStreet's <a href="#map" class="glossary">map</a> uses OSM maps.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="http://www.openstreetmap.org">www.openstreetmap.org</a>
        </li>
        <li>
          <a href="http://wiki.openstreetmap.org/wiki/Main_Page">OpenStreetMap wiki</a> for technical OSM documentation
        </li>
        <li>
          web interface to <a href="http://nominatim.openstreetmap.org">OpenStreetMap's geocoder</a>
        </li>
      </ul>
    </div>
  </dd>
  
  <dt>
    <a name="report">problem report</a>
  </dt>
  <dd>
    When a FixMyStreet user reports a pothole or a broken streetlight, that <strong>problem report</strong> 
    is sent to the <a href="#body" class="glossary">body</a> responsible. It's also stored on the 
    FixMyStreet website. Problem reports can be hidden, or anonymous (that is, the user's name is not
    shown on the web). The report includes the description entered by the user and, optionally, a photograph.
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="customising/send_reports">How FixMyStreet sends reports</a>.
        </li>
      </ul>
    </div>
  </dd>  
  
  <dt>
    <a name="send-method">send method</a>
  </dt>
  <dd>
    The <strong>send method</strong> is the way that a <a href="#report" class="glossary">problem report</a> is sent
    to the <a href="#body" class="glossary">body</a> responsible for fixing it. <em>By default, the send method is email.</em>
    <p>
      Alternatives to email are only available if some <a href="integration" class="glossary">integration</a> with
      the target body's back-end is available (for example, if they are using <a href="#open311" class="glossary">Open311</a>).
    </p>
    <div class="more-info">
      <p>More information:</p>
      <ul>
        <li>
          <a href="customising/send_reports">How FixMyStreet sends reports</a>.
        </li>
      </ul>
    </div>
  </dd>
  
</dl>