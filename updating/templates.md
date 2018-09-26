---
layout: page
title: Updating your installation
---

# Checking core template changes against your cobrand

<p class="lead">You may have your own cobrand, overriding templates in core,
and wish to check what changes there have been in core since your current
version, to see whether you need to make similar/related changes to your
cobrand templates. We provide a script to help with this.</p>

First, let's assume your cobrand is called `fixmypark` and you are in a git
repository with your current code checked out, but with access to the new
version you wish to compare against (ie. your repository is up to date with
upstream via `git fetch`, see below).

Then you can run the following to list templates that have changed between the
most recent version accessible from the current checkout and the newest
available version:

{% highlight bash %}
$ bin/cobrand-checks fixmypark
templates/web/base/report/update-form.html
{% endhighlight %}

If you prefer to be more explicit, you can specify old and new revisions:

{% highlight bash %}
$ bin/cobrand-checks fixmypark v2.3 v2.4
templates/web/base/report/new/after_photo.html
{% endhighlight %}

## --diff

If you specify `--diff`, you get a diff of the changes in core templates
between the specified versions, but only in templates that your cobrand
has overridden:

{% highlight diff %}
$ bin/cobrand-checks fixmypark v2.3 v2.4 --diff
diff --git a/templates/web/base/report/new/after_photo.html b/templates/web/base/report/new/after_photo.html
index b337977e4..4b28bf7f7 100644
--- a/templates/web/base/report/new/after_photo.html
+++ b/templates/web/base/report/new/after_photo.html
@@ -1,3 +1,4 @@
+[% IF c.cobrand.allow_photo_upload %]
 <div class="description_tips" aria-label="[% loc('Tips for perfect photos') %]">
     <ul class="do">
         <li>[% loc('For best results include a close-up and a wide shot') %]</li>
@@ -6,3 +7,4 @@
         <li>[% loc('Avoid personal information and vehicle number plates') %]</li>
     </ul>
 </div>
+[% END %]
{% endhighlight %}

## --interactive

For more advanced usage, `--interactive` will step through those files one by
one, letting you pick various different diffs (e.g. core change version to
version, or the change between old/new version and your cobrand), and edit your
cobrand template using vimdiff.
