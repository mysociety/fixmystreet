---
layout: page
title: Customising checklist
---

#  Customising checklist

<p class="lead">
  Every time we help set up a new, custom FixMyStreet site, we follow the same
  basic process to make sure all the key things get done. We've listed the
  steps here so you can follow them too.
</p>

## Checklist: 13 things to do

To create a custom FixMyStreet installation, these are the key things you need
to do. You don't have to do them *exactly* in this order -- some can be done
at the same time as others -- but if you're not sure then just work through the list.


<dl class="reveal-on-click" data-reveal-noun="steps">
  <dt>
    <h3>Pick a name</h3>
  </dt>
  <dd>
    You need a name for your
    <a href="{{ "/glossary/#cobrand" | relative_url }}" class="glossary__link">cobrand</a>
    right at the start because that's the name you'll use for the directories
    where your own resources and templates go.
    <p>
      Your name needs to be unique (that is, no other FixMyStreet cobrands are
      already using it), suitable as a directory name (so no punctuation), and
      ideally related to the domain name you're going to use for it (although
      this isn't 100% obligatory).
    </p>
    <p>
      For example, if your project is called FixMyPark, the cobrand name will
      be <code>fixmypark</code>.
    </p>
  </dd>
  <dt>
    <h3>Set up the domain name
</h3>
  </dt>
  <dd>
    If you already own the domain name,
    you're good to go. But if this is a new project and you don't have the
    domain set up already, don't leave it too late to register the domain
    and point it at your server.
  </dd>
  <dt>
    <h3>Translate into language(s) you need</h3>
  </dt>
  <dd>
    If FixMyStreet doesn't already have translations for the language(s) you
    need, you can start work on that right away &mdash; see 
    <a href="{{ "/customising/language/" | relative_url }}">more about languages</a>.
  </dd>
  <dt>
    <h3>Install the software on the server</h3>
  </dt>
  <dd>
    There are several different ways of doing this &mdash; see 
    <a href="{{ "/install/" | relative_url }}">installation instructions</a>.
    <p>
      Even if you're not hosting the site yourself, you might want to install
      the software in order to see how your customisation looks before putting
      it live.
    </p>
  </dd>
  <dt>
    <h3>Secure access to the admin</h3>
  </dt>
  <dd>
    Make sure you're being challenged to provide a username and password when
    accessing the admin at <code>/admin</code>.
    <p>
      Typically this means using creating a superuser. If you've
      not already done so, run the `bin/createsuperuser` script to create a user
      that has access to the admin.
    </p>
  </dd>
  <dt>
    <h3>Change the colour scheme</h3>
  </dt>
  <dd>
    See <a href="{{ "/customising/css/" | relative_url }}">changing colour and CSS</a>
    for detailed instructions.
    <p>
      You can just change the colour variables without needing to touch any other
      CSS.
    </p>
  </dd>
  <dt>
    <h3>Change the logo</h3>
  </dt>
  <dd>
    You'll need an understanding of CSS in order to change the logo &mdash;
    it's optimised in the FixMyStreet design for good perfomance on old or
    narrow clients, which makes it a little bit more difficult than just
    dropping in a graphics file.
    <p>
      We'll be adding instructions later, but meanwhile see the page
      <a href="{{ "/customising/css/" | relative_url }}">about changing the CSS</a>.    
    </p>
  </dd>
  <dt>
    <h3>Write your own FAQ</h3>
  </dt>
  <dd>
    You almost certainly need to re-write the FAQ and other information pages
    to match your project.
    <p>
      To do this, copy the template files into your own cobrand's directory and
      rewrite them. The generic base FAQ can be found at
      <code>templates/web/base/about/faq-en-gb.html</code>
    </p>
    <p>
      See <a href="{{ "/customising/templates/" | relative_url }}">more about templates</a>.
    </p>
  </dd>
  <dt>
    <h3>Limit geocoder lookups to your area <!-- NEW --></h3>
  </dt>
  <dd>
    When someone enters a place name, you only want your FixMyStreet to look
    for it in the place your site covers. This is controlled by the
    <code><a href="{{ "/customising/config/#geocoding_disambiguation" | relative_url }}">GEOCODING_DISAMBIGUATION</a></code>
    setting.
    See <a href="{{ "/customising/geocoder/" | relative_url }}">more about the geocoder</a>.
    <p>
      We've listed this separately from the other config settings because it
      may take a little bit of testing to see what options work best &mdash;
      this depends on which geocoder you are using.
    </p>
  </dd>
  <dt>
    <h3>Configure your admin boundaries (MapIt)</h3>
  </dt>
  <dd>
    You need to decide what kind of boundary data you'll be using &mdash; see
    <a href="{{ "/customising/boundaries/" | relative_url }}">more about boundaries</a>.
    <p>
      As part of that work, you'll need to set 
      <code><a href="{{ "/customising/config/#mapit_url" | relative_url }}">MAPIT_URL</a></code>
      and the other MapIt config settings to match the service you're using.
    </p>
  </dd>
  <dt>
    <h3>Set non-default config settings</h3>
  </dt>
  <dd>
    Many of the  
    <a href="{{ "/customising/config/" | relative_url }}">configuration settings</a>
    can be left with their defaults, but some you <em>must</em> change. 
    <p>
      As well as system settings (for example, 
      <code><a href="{{ "/customising/config/#fms_db_name" | relative_url }}">FMS_DB_NAME</a></code>),
      every new site needs custom
      <code><a href="{{ "/customising/config/#email_domain" | relative_url }}">EMAIL_DOMAIN</a></code>
      and
      <code><a href="{{ "/customising/config/#example_places" | relative_url }}">EXAMPLE_PLACES</a></code>
      settings. Make sure the example places you choose really do work if you enter them 
      as the location on the front page.
    </p>
    <p>
      Even though your site might work with other settings left as defaults, you should go
      through the <em>whole</em> <code>cong/general.yml</code> file to check everything is how
      you want it.
    </p>
  </dd>
  <dt>
    <h3>Create the bodies (authorities, councils)</h3>
  </dt>
  <dd>
    Once your site is running log into the admin and 
    <a href="{{ "/running/bodies_and_contacts/" | relative_url }}">add the bodies</a>.
    <p>
      You should have set up the
      <a href="{{ "/customising/boundaries/" | relative_url }}">admin boundaries</a>
      by this stage, because you need to associate each body with the area it covers.
      For more information, see
      <a href="{{ "/customising/fms_and_mapit/" | relative_url }}">how FixMyStreet uses MapIt</a>.
    </p>
  </dd>
  <dt>
    <h3>Add category names &amp; contact emails</h3>
  </dt>
  <dd>
    Once you've created the bodies to whom reports will be sent, you can add
    their problem categories (for example, "Potholes", "Streetlights"). At the
    same time, add the contact email addresses for each one &mdash; see <a
    href="{{ "/running/bodies_and_contacts/" | relative_url }}">more about
    contacts and categories</a>.
  </dd>
</dl>


## Further customisation

Remember that this just covers the key parts of a custom installation. There's
a lot more you can change &mdash; for example, you can write custom Perl code
for the <a href="{{ "/customising/cobrand-module/" | relative_url }}">Cobrand
module</a> if you want to override specific behaviour not covered by config
variables.

