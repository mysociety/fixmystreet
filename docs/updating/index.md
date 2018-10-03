---
layout: page
title: Updating your installation
---

# Updating your installation

<p class="lead">Keeping your installation up to date means you get new features
and bug fixes implemented by other users of the platform.</p>

Please read the guidelines for [feeding back changes](/feeding-back/) -- if
you follow those when working on your site it should be much easier for you to
keep your code up to date with upstream. In the best case scenario, if you
submit frequent pull requests and keep up to date, you shouldn't run into many
conflicts at all.

If your cobrand is not present upstream, then you may want to check changes in
core templates against your cobrand before updating – [we have a script to help
with that](/updating/templates/).

## Updating the code itself

The `master` branch of the main FixMyStreet repository should always be safe,
stable, and deployable. On top of that, we have fixed version numbers that our
install script and packaged options use, and you are welcome to as well.

<div class="attention-box info">
<strong>Install script/ package users:</strong> Note that if you have used the install script or
a packaged image, then your repository by default will be cloned from the main
FixMyStreet repository. Please see our <a href="ami/">package-specific updating instructions</a>.
</div>

Let's say you have forked the main FixMyStreet repository on GitHub, and you
have cloned your fork and have been working on that. You have made some commits
that you have not yet submitted upstream to be merged in. GitHub have some
[helpful instructions](https://help.github.com/articles/fork-a-repo) on pulling
in upstream changes, and it basically boils down to:

{% highlight bash %}
# If you haven't set up the remote before
git remote add upstream https://github.com/mysociety/fixmystreet.git
# Fetch new commits from upstream
git fetch upstream
# Merge those commits into your current branch
# Or whichever version tag e.g. v2.5
git merge upstream/master
{% endhighlight %}

If you're proficient with git, of course feel free to rebase your changes on
top of the upstream master, or however else you wish to best go about the
issue :-) Doing this frequently will help prevent you get in a situation where
you are too worried to merge in case it breaks something.

## Subsequent dependency updates

After updating the code, you should run the following command to update any
needed dependencies and any schema changes to your database. It's a good idea
to take a backup of your database first.

{% highlight bash %}
script/update
{% endhighlight %}

Of course, if you have made changes to the database schema yourself, this may
not work, please feel free to [contact us](/community/) to discuss it first.

## Restart the server

Lastly, you should restart your application server, this may be restarting
your webserver, or if it is running separately, something like:

{% highlight bash %}
sudo service fixmystreet restart
{% endhighlight %}
