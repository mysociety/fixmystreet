---
layout: page
title: Running FixMyStreet
author: dave
---

# Running FixMyStreet

<p class="lead">After you've installed FixMyStreet, you need to manage the
site. The information here will help you with the common tasks needed to keep
everything running smoothly. </p>

<div class="row-fluid">
<div class="span6">
<ul class="nav nav-pills nav-stacked">
<li><a href="admin_manual/">Administrator's manual</a></li>
<li><a href="staff/">Staff user's manual</a></li>
<li><a href="bodies_and_contacts">About managing bodies and contacts</a></li>
<li><a href="users">About users</a></li>
</ul>
</div>
</div>

## Accessing the admin pages

By default the administration pages for FixMyStreet can be found on your
installation at `/admin`.

When you first deploy your installation of FixMyStreet, this is just a public
directory. Obviously, for a
<a href="{{ "/glossary/#production" | relative_url }}" class="glossary__link">production</a>
server you should **restrict access to
authorised users only**. For example, if you're running the Apache webserver,
you can use `htaccess` to do this.

<div class="attention-box warning">
  <p><strong>You <em>must</em> restrict access to admin</strong>
    <br>
    Never put your FixMyStreet site live until you have protected
    your admin pages.
  </p>
</div>

If you can configure your webserver to only allow access to the admin URLs over https, then you should do that, and deny access any other way. It's also a good idea to IP-restrict access to admin URLs if you know where your authorised users will be accessing them from.
