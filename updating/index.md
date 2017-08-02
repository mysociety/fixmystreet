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

## The code itself

The `master` branch of the main FixMyStreet repository should always be safe,
stable, and deployable. On top of that, we have fixed version numbers that our
install script and AMI use, and you are welcome to as well.

**Install script/ AMI users:** Note that if you have used the install script or
the AMI, then your repository by default will be cloned from the main
FixMyStreet repository. Please see our [AMI specific updating instructions](/updating/ami/).

Let's say you have forked the main FixMyStreet repository on GitHub, and you
have cloned your fork and have been working on that. You have made some commits
that you have not yet submitted upstream to be merged in. GitHub have some
[helpful instructions](https://help.github.com/articles/fork-a-repo) on pulling
in upstream changes, but it basically boils down to:

{% highlight bash %}
# If you haven't set up the remote before
git remote add upstream https://github.com/mysociety/fixmystreet.git
# Fetch new commits from upstream
git fetch upstream
# Merge those commits into your current branch
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

If you are updating to a version lower than 2.1 then you will have to run
multiple scripts to update everything:

{% highlight bash %}
git submodule update
bin/install_perl_modules
bin/update-schema --commit
bin/make_css
commonlib/bin/gettext-makemo
{% endhighlight %}

Of course, if you have made changes to the database schema yourself, this may
not work, please feel free to [contact us](/community/) to discuss it first.

## Restart the server

Lastly, you should restart your application server, this may be restarting
your webserver, or if it is running separately, something like:

{% highlight bash %}
sudo /etc/init.d/fixmystreet restart
{% endhighlight %}
