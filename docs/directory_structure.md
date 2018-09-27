---
layout: page
title: Directory structure
---


# The FixMyStreet platform's directory structure

<p class="lead">This page gives you an overview of where to find things in FixMyStreet's
directories.</p>

You'll probably never need to worry about this if you're just
installing FixMyStreet -- this is really more useful if you're a developer
planning on making more substantive changes to the code (and if you do,
remember to read the page about [feeding your changes back](/feeding-back)).

FixMyStreet uses [Catalyst](http://www.catalystframework.org/), which is a
common Perl "Model-View-Controller" web framework. Again, you don't need to be
familiar with Catalyst to install or even work on the code, especially if all
you're doing is [customising your installation](/customising).

## Key directories and what they're for

<dl class="dir-structure">
  <dt>
    bin
  </dt>
  <dd>
    <p><em>scripts for system tasks</em></p>
    <p>
      For example, scripts used for installation or set-up, such as <code>make_css</code>,
      and cron jobs (that is, those tasks that must be run at regular intervals,
      such as <code>send-reports</code>).
    </p>
  </dd>
  <dt>
    commonlib
  </dt>
  <dd>
    <p><em>mySociety's library of common functions</em></p>
    <p>
      We maintain a <a href="https://github.com/mysociety/commonlib/">common library</a> that
      we use across many of our projects (not just FixMyStreet). This is implemented as a
      <a href="http://git-scm.com/book/en/Git-Tools-Submodules">git submodule</a>,
      so FixMyStreet contains it even though the code is separate. Normally, you
      don't need to think about this (because git handles it automatically)... but if you
      really <em>do</em> need to change anything here, be aware that it is a separate git repository.
    </p>
  </dd>
  <dt>
    conf
  </dt>
  <dd>
    <p><em>configuration files</em></p>
    <p>
      The primary configuration file is <code>general.yml</code>. This file isn't in the git
      repository (since it will contain information specific to your installation, including
      the database password), but example files are.
      See  <a href="{{ "/customising/config/" | relative_url }}">details of all
      configuration settings</a>.
    </p>
  </dd>
  <dt>
    data
  </dt>
  <dd>
    <p><em>data files</em></p>
  </dd>
  <dt>
    db
  </dt>
  <dd>
    <p><em>database SQL</em></p>
    <p>
      The <code>db</code> directory contains SQL for creating the tables and seeding some of the data &mdash;
      for example, <code>schema.sql</code> contains the full database structure, and you use this when
      you first create the database (see <em>2. Create a new PostgreSQL database</em> in the
      <a href="{{ "/install/" | relative_url }}">installation instructions</a> if you're installing manually).
    </p>
    <p>
      By convention, we also put "migration" SQL in here, so if the schema has changed since you installed and
     you need to add new fields, you'll find the individual changes you need to apply here.
    </p>
  </dd>
  <dt>
    local
  </dt>
  <dd>
    <p><em>local (as opposed to system-wide) Perl libraries</em></p>
    <p>
      FixMyStreet installs its local CPAN modules here. These are populated by the script
      <code>bin/install_perl_modules</code>.
    </p>
  </dd>
  <dt>
    locale
  </dt>
  <dd>
    <p><em>translations (internationalisation/i18n)</em></p>
    <p>
      The translation strings are stored in <code>.po</code> files in directories specific to
      the locale and encoding. For example, <code>nn_NO.UTF-8/</code> contains the translations
      for the Norwegian site. See more about
      <a href="{{ "/customising/language/" | relative_url }}">translating FixMyStreet</a>.
    </p>
  </dd>
  <dt>
    notes
  </dt>
  <dd>
    <p><em>documentation notes</em></p>
    <p>
      These are technical notes. This is in addition to the
      <a href="https://fixmystreet.org/">core documentation</a> &mdash; which you are reading now &mdash;
      which is actually stored in the git repository in the <code>docs</code> directory, and published
      as GitHub pages.
    </p>
  </dd>
  <dt>
    perllib
  </dt>
  <dd>
    <p><em>the main application code</em></p>
    <dl>
      <dt>
        Catalyst
      </dt>
      <dd>
        <p><em>the Catalyst framework's own files &mdash; not FixMyStreet-specific</em></p>
      </dd>
      <dt>
        DBIx
      </dt>
      <dd>
        <p><em>database bindings</em></p>
      </dd>
      <dt>
        FixMyStreet
      </dt>
      <dd>
        <p><em>the core FixMyStreet Catalyst application</em></p>
        <dl>
          <dt>
            App
          </dt>
          <dd>
            <p><em>the core FixMyStreet program code</em></p>
            <dl>
              <dt>
                Controller
              </dt>
              <dt>
                Model
              </dt>
              <dt class="last">
                View
              </dt>
            </dl>
          </dd>
          <dt>
            Cobrand
          </dt>
          <dd>
            Contains the <a href="{{ "/customising/cobrand-module/" | relative_url }}">Cobrand modules</a>, which you
            can use if you need to add custom behaviour beyond that provided by config
            and template changes.
            See <a href="{{ "/customising/" | relative_url }}">more abobut customising</a> your site.
          </dd>
          <dt>
            DB
          </dt>
          <dd>
            <p><em>code for handling model data from the database</em></p>
            <dl>
              <dt>
                Result
              </dt>
              <dt class="last">
                ResultSet
              </dt>
            </dl>
          </dd>
          <dt>
            GeoCode
          </dt>
          <dt>
            Map
          </dt>
          <dt>
            Roles
          </dt>
          <dt class="last">
            SendReport
          </dt>
          <dd class="last">
            <p><em>code for handling report sending</em></p>
            <p>
              In addition to email and Open311, this is where the
              custom 
              <a href="{{ "/customising/integration/" | relative_url }}">back-end integrations</a>
              are found.
            </p>
          </dd>
        </dl>
      </dd>
      <dt>
        Geo
      </dt>
      <dt class="last">
        Open311
      </dt>
      <dd class="last">
        <p>
          <em>code for implementing FixMyStreet's <a href="{{ "/glossary/#open311" | relative_url }}" class="glossary__link">Open311</a> functionality</em>
        </p>
      </dd>
    </dl>

  </dd>
  <dt>
    script
  </dt>
  <dd>
    <p><em>Catalyst scripts</em></p>
    <p>
      For example, <code>fixmystreet_app_server.pl</code> for running the Catalyst development server.
    </p>
  </dd>
  <dt>
    t
  </dt>
  <dd>
    <p><em>tests</em></p>
    <p>
      FixMyStreet's test suite runs under <a href="http://perldoc.perl.org/5.8.9/prove.html">prove</a>.
    </p>
  </dd>
  <dt>
    templates
  </dt>
  <dd>
    <p>
      <em>email and web templates</em>
    </p>
    <p>
      These are templates for the email messages that FixMyStreet sends, and the web pages it
      shows, in cobrand-specific directories. If no template can be found for a specific
      email or web page in the required cobrand, FixMyStreet uses the template in
      <code>default/</code>. In this way, cobrands only need to override templates that
      differ from FixMyStreet's default &mdash; it's feasible for your cobrand's template
      directories to be empty.
      See <a href="{{ "/customising/" | relative_url }}">more abobut customising</a> your site.
    </p>
    <dl>
      <dt>
        email
      </dt>
      <dd>
        Template files for the email messages that FixMyStreet sends, as <code>.txt</code>
        text files.
      </dd>
      <dt class="last">
        web
      </dt>
      <dd class="last">
        <p>
          Template files for the web pages.
          The templates, which all have the extension <code>.html</code>, use the popular
          <a href="http://www.template-toolkit.org">Template Toolkit</a> system.
        </p>
        <p>
          FixMyStreet stores compiled templates, created on demand with the extension
          <code>.ttc</code>, alongside the template files. Don't edit these files: edit
          the <code>.html</code> ones, and FixMyStreet will overwrite the <code>.ttc</code>
          files automatically.
        </p>
      </dd>
    </dl>
  </dd>
  <dt class="last">
    web
  </dt>
  <dd class="last">
    <p><em>static resources for the web pages, including stylesheets, javascript, images</em></p>
    <dl>
      <dt>cobrands</dt>
      <dd>
        <p><em>resources specific to cobrands</em></p>
        <p>For example, if your installation has its own logo, put it here.</p>
      </dd>
      <dt>css</dt>
      <dd>
        <p><em>some core SCSS definitions</em></p>
      </dd>
      <dt>i</dt>
      <dd>
        <p><em>images</em></p>
        <p>
          Images, including navigation icons and sprites, used by the default site (and hence
          available to other cobrands too) &mdash; for example <code>pin-green.png</code>
          is the green pin used on most cobrand's maps.
        </p>
      </dd>
      <dt>iphone</dt>
      <dt>js</dt>
      <dd>
        <p><em>JavaScript files</em></p>
      </dd>
      <dt class="last">posters</dt>
    </dl>
  </dd>
</dl>

We've missed out some of the less important subdirectories here just to keep
things clear.
