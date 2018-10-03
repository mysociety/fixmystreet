---
layout: page
title: Testing
---

# Testing

<p class="lead">
  This page describes how to run FixMyStreet’s test suite.
</p>

## Server testing

You can run the test suite for the backend codebase by running the following
command in the `fixmystreet` directory:

{% highlight bash %}
$ script/test
{% endhighlight %}

The `master` branch of the repository should always be passing all tests for
our developers and on mySociety's servers.

## Client testing

To run the front-end tests, you will need to install
[Cypress](https://cypress.io) using `npm` (not direct download), and the
`cypress` command needs to be on your `PATH`. Then you can run the front-end
tests headlessly using:

{% highlight bash %}
$ bin/browser-tests run
{% endhighlight %}

This uses its own test server and database, not affecting your development
database. If you wish to run the tests interactively for debugging, use:

{% highlight bash %}
$ bin/browser-tests open
{% endhighlight %}

If you're running FixMyStreet in a Vagrant box, you can use this script to run
the test server in the VM and Cypress outside of it:

{% highlight bash %}
$ bin/browser-tests --vagrant run
{% endhighlight %}
