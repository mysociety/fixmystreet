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
problem's location and <a href="{{ site.baseurl }}/glossary/#category"
class="glossary">category</a>, and sends a
<a href="{{ site.baseurl }}/glossary/#report" class="glossary">report</a>, 
by email or using a web service such as <a href="{{ site.baseurl }}/glossary/#open311"
class="glossary">Open311</a>, to the department or body responsible for fixing
it.

But FixMyStreet doesn't just send problem reports &mdash; it makes the reports
visible to everyone. Anyone can see what's already been reported, leave <a
href="{{ site.baseurl }}/glossary/#update" class="glossary">updates</a>, or
subscribe to <a href="{{ site.baseurl }}/glossary/#alert"
class="glossary">alerts</a>. We help prevent duplicate reports and offer
additional features for <a href="{{ site.baseurl }}/glossary/#staff-user"
class="glossary">staff users</a> working for the authorities who are actually
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
        <a href="{{ site.baseurl }}running">run the site</a> and the project
      </li>
      <li>
        <strong>a developer</strong> who can 
        <a href="{{ site.baseurl }}install">do the tech</a> and 
        <a href="{{ site.baseurl }}customising">customise the code</a>
      </li>
      <li>
        <strong>a translator</strong> (unless you'll be using a 
        <a href="{{ site.baseurl }}customising/language">language</a>
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
    <ul>
      <li><a href="{{ site.baseurl }}install/install-script">on your own server</a></li>
      <li><a href="{{ site.baseurl }}install/ami">on an Amazon Web Services EC2 server</a></li>
      <li>...or ask us to <a href="{{ site.baseurl }}install/#hosting">host it for you</a></li>
    </ul>
  </dd>  
  <dt>
    <h3 id="get_the_data_for_the_areas_you_want_to_cover">3. Get the data for the areas you want to cover</h3>
  </dt>
  <dd>
    <p>
      We know from experience it's a good idea to start small and expand later (for
      example, maybe start with one city and go national later):
    </p>
    <ul>
      <li>
        you'll need to get the 
        <a href="{{ site.baseurl }}customising/boundaries">boundary data</a>
        for the area you're covering (and the borders of any authorities within it)
      </li>
      <li>
        you must find 
        <a href="{{ site.baseurl }}running/bodies_and_contacts">email addresses</a>
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
    <a href="{{ site.baseurl }}customising">customise the site</a>:
    <ul>
      <li>
        <a href="{{ site.baseurl }}customising/config">configure the site</a>
        so it does what you want
      </li>
      <li>
        make simple <a href="{{ site.baseurl }}customising/css">colour scheme</a> changes, 
        logo, and wording changes 
      </li>
      <li>
        optionally make more complex design or 
        <a href="{{ site.baseurl }}customising/cobrand-module">behaviour changes</a>
        &mdash; this will require dev skills (you can do this, or ask us to)
      </li>
      <li>
        <a href="{{ site.baseurl }}customising/language">translate</a>
        it into the language(s) you need. We use a service called
        Transifex so your translators don't need to be programmers.
      </li>
      <li>
        change the about/privacy/FAQ pages by 
        <a href="{{ site.baseurl }}customising/templates">writing your own</a>
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
      <a href="{{ site.baseurl }}running/admin_manual">user support</a>
      to do, marketing and press to handle, liaison with the authorities you're
      sending the reports to, and perhaps even integration (because email is 
      the easiest, but not necessarily the best, way to send those reports).
    </p>
  </dd>
</dl>

Still interested? Read 
[Can We Fix It?]({{ site.baseurl }}The-FixMyStreet-Platform-DIY-Guide-v1.1.pdf),
a document we've written to describe in more detail how and why FixMyStreet
works as well as it does.

And remember... we can help! If you're trying to set this up somewhere outside the UK,
email [international@mysociety.org](mailto://international@mysociety.org) and tell us
all about it.
