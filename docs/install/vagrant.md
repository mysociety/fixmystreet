---
layout: page
title: Vagrant
---

# FixMyStreet using Vagrant

<p class="lead">
Vagrant provides an easy method to set up virtual development environments &mdash; for
further information see <a href="http://www.vagrantup.com">the Vagrant website</a>.
We bundle an example Vagrantfile in the repository, which runs the
<a href="{{ "/install/install-script/" | relative_url }}">install script</a> for you.
</p>

Note that this is just one of [many ways to install FixMyStreet]({{ "/install/" | relative_url }}).

<div class="attention-box warning">
  Vagrant is only suitable for use as a
  <a href="{{ "/glossary/#development" | relative_url }}" class="glossary__link">development</a>
  server &mdash; <strong>do not</strong> use it in
  <a href="{{ "/glossary/#production" | relative_url }}" class="glossary__link">production</a>!
</div>

This pages describes how to use Vagrant to create a development environment
where you can run the test suite and the development server, and make changes
to the codebase.

The advantage of using Vagrant is that it lets you run FixMyStreet within a
virtual machine (VM), with its own system software and environment set up
entirely independently of the actual machine it's running on. This means you
don't have to worry about it interfering with your own machine's operating
system. The main disadvantage is that the virtual machine runs somewhat slower,
and makes more demands on the processor, than FixMyStreet running natively.

The basic process is to create a base virtual machine, and then provision it
with the software packages and setup needed. There are several ways to do this,
including Chef, Puppet, or the existing FixMyStreet install script (which is
the method used in the example below). The supplied scripts will create a
Vagrant VM based on the server edition of Ubuntu 12.04 LTS. This contains
everything you need to work on FixMyStreet.

1. Clone the repository, `cd` into it and run vagrant. This will provision the
   system and can take some time.

        git clone --recursive https://github.com/mysociety/fixmystreet.git
        cd fixmystreet
        vagrant up --no-color

## Working with the Vagrant box

You've now got a local FixMyStreet development server to work with. You can
edit the files locally (which means you can use your favourite text editor, for
example) and the changes will be reflected on the virtual machine.

To start the dev server:

    vagrant ssh

    # You are now in a terminal on the virtual machine
    cd fixmystreet

    # run the dev server
    script/server

The server will now be running and you can visit it at the address
`http://fixmystreet.127.0.0.1.xip.io:3000/`

The username and password to access the admin (at address
`http://fixmystreet.127.0.0.1.xip.io:3000/admin/`) will have been shown at the
end of the `vagrant up` output.
