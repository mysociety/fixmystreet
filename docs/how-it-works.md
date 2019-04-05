---
layout: page
title: How to FixMyStreet
---

# How does FixMyStreet work?

<p class="lead">
  FixMyStreet sends problem reports to the people who can fix them!
</p>

##  How it works

FixMyStreet makes it easy for anyone to report a problem without worrying about
the correct authority to send it to. FixMyStreet takes care of that using the
problem's location and <a href="{{ "/glossary/#category" | relative_url }}"
class="glossary__link">category</a>, and sends a
<a href="{{ "/glossary/#report" | relative_url }}" class="glossary__link">report</a>, 
by email or using a web service such as <a href="{{ "/glossary/#open311" | relative_url }}"
class="glossary__link">Open311</a>, to the department or body responsible for fixing
it.

But FixMyStreet doesn't just send problem reports &mdash; it makes the reports
visible to everyone. Anyone can see what's already been reported, leave <a
href="{{ "/glossary/#update" | relative_url }}" class="glossary__link">updates</a>, or
subscribe to <a href="{{ "/glossary/#alert" | relative_url }}"
class="glossary__link">alerts</a>. We help prevent duplicate reports and offer
additional features for <a href="{{ "/glossary/#staff-user" | relative_url }}"
class="glossary__link">staff users</a> working for the authorities who are actually
fixing problems.


## Want to run FixMyStreet in your area?

If you want to get FixMyStreet up and running, this is what you need to do:

<dl class="reveal-on-click" data-reveal-noun="steps">
  <dt>
    <h3 id="gather_a_team">1. Gather a team</h3>
  </dt>
  <dd>
    <p>
      To begin with, we think this is the <em>minimum</em>:
    </p>
    <ul>
      <li>
        <strong>an administrator</strong> who can 
        <a href="{{ "/running" | relative_url }}">run the site</a> and the project
      </li>
      <li>
        <strong>a developer</strong> who can 
        <a href="{{ "/install" | relative_url }}">do the tech</a> and 
        <a href="{{ "/customising" | relative_url }}">customise the code</a>
      </li>
      <li>
        <strong>a translator</strong> (unless you'll be using a 
        <a href="{{ "/customising/language" | relative_url }}">language</a>
        we already support)
      </li>
    </ul>
    <p>
      This describes a tiny team of three &mdash; if you can get more, great!
      Admins can share the work, translators can work on different texts at the
      same time, and devs can work on code and design customisations.
    </p>
  </dd>
  <dt>
    <h3 id="install_the_software">2. Install the software</h3>
  </dt>
  <dd>
    <p>See the <a href="{{ "/install/" | relative_url }}">various ways to install</a> the software.</p>
  </dd>  
  <dt>
    <h3 id="get_the_data_for_the_areas_you_want_to_cover">3. Get the data for the areas you want to cover</h3>
  </dt>
  <dd>
    <p>
      We know from experience it's a good idea to start small and expand later (for
      example, maybe start with one city and go national when that's running well):
    </p>
    <ul>
      <li>
        you'll need to get the 
        <a href="{{ "/customising/boundaries" | relative_url }}">boundary data</a>
        for the area you're covering (and the borders of any authorities within it)
      </li>
      <li>
        you must find 
        <a href="{{ "/running/bodies_and_contacts" | relative_url }}">email addresses</a>
         for each of the departments responsible for each category of problem,
         in each of the bodies responsible for the areas you're covering
      </li>
    </ul>
  </dd>
  <dt>
    <h3 id="customise_the_site">4. Customise the site</h3>
  </dt>
  <dd>
    There's lots you can do to 
    <a href="{{ "/customising" | relative_url }}">customise the site</a>:
    <ul>
      <li>
        <a href="{{ "/customising/config" | relative_url }}">configure the site</a>
        so it does what you want
      </li>
      <li>
        make simple <a href="{{ "/customising/css" | relative_url }}">colour scheme</a> changes, 
        logo, and wording changes 
      </li>
      <li>
        optionally make more complex design or 
        <a href="{{ "/customising/cobrand-module" | relative_url }}">behaviour changes</a>
        &mdash; this will require dev skills (you can do this, or ask us to)
      </li>
      <li>
        <a href="{{ "/customising/language" | relative_url }}">translate</a>
        it into the language(s) you need. We use a service called
        Transifex so your translators don't need to be programmers.
      </li>
      <li>
        change the about/privacy/FAQ pages by 
        <a href="{{ "/customising/templates" | relative_url }}">writing your own</a>
      </li>
    </ul>
    
  </dd>
  <dt>
    <h3 id="go_live">5.  Go live!</h3>
  </dt>
  <dd>
    <p>
      Actually setting up a FixMyStreet project is just the beginning &mdash;
      you need to be committed for the long term to see the site grow and
      succeed. There will be
      <a href="{{ "/running/admin_manual" | relative_url }}">user support</a>
      to do, marketing and press to handle, liaison with the authorities you're
      sending the reports to, and perhaps even 
      <a href="{{ "/customising/integration" | relative_url }}">integration</a>
      (because email is the easiest, but not necessarily the best, way to send
      those reports).
    </p>
  </dd>
</dl>

<!-- NB duplicated from /overview -->
We've written a clear guide for anyone who's thinking about [setting up and
running FixMyStreet]({{ "/The-FixMyStreet-Platform-DIY-Guide-v1.1.pdf" | relative_url }}). 
If you're thinking of running such a project, you **must** read it first -- it
explains why these sites work, and what you need to think about before you start.

If you still want to be involved, we welcome questions about how it works
[on our mailing list]({{ "/community/" | relative_url }}).

There's also the [FixMyStreet blog]({{ "/blog/" | relative_url }}) where we post version release
information and other progress reports. And we often post FixMyStreet news on
the <a href="https://www.mysociety.org/blog/">mySociety blog</a> too.
