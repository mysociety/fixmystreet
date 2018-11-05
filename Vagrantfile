# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# Provide for a `--base-box` option to permit overriding the box used
require 'getoptlong'
opts = GetoptLong.new(
  [ '--base-box', GetoptLong::OPTIONAL_ARGUMENT ]
)

baseBox='mysociety/fixmystreet'
opts.each do |opt, arg|
  case opt
    when '--base-box'
      baseBox=arg
  end
end

# This ensures pre-built modules are available in the correct place.
$mount_modules = <<-EOS
  [ ! -e /home/vagrant/fixmystreet/local ] && mkdir /home/vagrant/fixmystreet/local
  if ! mount | grep -q /home/vagrant/fixmystreet/local 2>/dev/null ; then
    echo "Mounting pre-built perl modules from /usr/share/fixmystreet/local"
    mount -o bind /usr/share/fixmystreet/local /home/vagrant/fixmystreet/local
    chown -R vagrant:vagrant /home/vagrant/fixmystreet/local
  fi
EOS

# This installs FMS from scratch, for use with non-mySociety boxes.
$full_setup = <<-EOS
    BASEBOX=$1
    # To prevent "dpkg-preconfigure: unable to re-open stdin: No such file or directory" warnings
    export DEBIAN_FRONTEND=noninteractive
    # Make sure git submodules are checked out!
    echo "Checking submodules exist/up to date"
    apt-get -qq install -y git >/dev/null
    cd fixmystreet
    git submodule --quiet update --init --recursive --rebase
    cd commonlib
    git config core.worktree "../../../commonlib"
    echo "gitdir: ../.git/modules/commonlib" > .git
    cd ../..
    # Fetch and run install script
    wget -O install-site.sh --no-verbose https://github.com/mysociety/commonlib/raw/master/bin/install-site.sh
    sh install-site.sh --dev fixmystreet vagrant 127.0.0.1.xip.io
    if [ $? -eq 0 ]; then
      touch /tmp/success
    else
      rm -f /tmp/success 2>/dev/null
    fi
    # Even if it failed somehow, we might as well update the port if possible
    if [ -e fixmystreet/conf/general.yml ] && ! grep -q "^ *BASE_URL.*:3000'$" conf/general.yml; then
      # We want to be on port 3000 for development
      sed -i -r -e "s,^( *BASE_URL: .*)',\\1:3000'," fixmystreet/conf/general.yml
    fi
EOS

# This just runs our update script, used on our offical box.
$update = <<-EOS
    chown -R vagrant:vagrant /home/vagrant/.cpanm
    su vagrant -c '/home/vagrant/fixmystreet/script/setup ; exit $?'
    if [ $? -eq 0 ]; then
      touch /tmp/success
    else
      rm -f /tmp/success 2>/dev/null
    fi
EOS

# This will ensure that bits of config are set right.
$configure = <<-EOS
    # Create a superuser for the admin
    su vagrant -c 'fixmystreet/bin/createsuperuser superuser@example.org password'
    if [ -e /tmp/success ]; then
        # All done
        echo "****************"
        echo "You can now ssh into your vagrant box: vagrant ssh"
        echo "The website code is found in: ~/fixmystreet"
        echo "You can run the dev server with: script/server"
        echo "Access the admin with username: superuser@example.org and password: password"
    else
        echo "Unfortunately, something appears to have gone wrong with the installation."
        echo "Please see above for any errors, and do ask on our mailing list for help."
        exit 1
    fi
EOS

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "#{baseBox}"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network :forwarded_port, guest: 3000, host: 3000
  # And 3001 for the Cypress test server
  config.vm.network :forwarded_port, guest: 3001, host: 3001

  config.vm.synced_folder ".", "/home/vagrant/fixmystreet", :owner => "vagrant", :group => "vagrant"

  # When using the mySociety box, just mount the local perl modules and run `script/update`
  # For any other box, just run the full setup process.
  if "#{baseBox}" == "mysociety/fixmystreet"
    config.vm.provision "shell", run: "always", inline: $mount_modules
    config.vm.provision "shell", run: "always", inline: $update
  else
    config.vm.provision "shell", inline: $full_setup
  end

  # Run the configuration steps on all boxes.
  config.vm.provision "shell", inline: $configure

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network :private_network, ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network :public_network

  # If true, then any SSH connections made will enable agent forwarding.
  # Default value: false
  # config.ssh.forward_agent = true

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider :virtualbox do |vb|
  #   # Don't boot with headless mode
  #   vb.gui = true
  #
  #   # Use VBoxManage to customize the VM. For example to change memory:
  #   vb.customize ["modifyvm", :id, "--memory", "1024"]
  # end
  #
  # View the documentation for the provider you're using for more
  # information on available options.

end
