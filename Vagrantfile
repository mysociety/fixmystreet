# -*- mode: ruby -*-
# vi: set ft=ruby :

BOX_NAME = ENV['BOX_NAME'] || "precise64"
BOX_URI = ENV['BOX_URI'] || "http://files.vagrantup.com/precise64.box"

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = BOX_NAME

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = BOX_URI

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network :forwarded_port, guest: 3000, host: 3000

  config.vm.synced_folder ".", "/home/vagrant/fixmystreet", :owner => "vagrant", :group => "vagrant"

  config.vm.provision :shell, :inline => <<-EOS
    # To prevent "dpkg-preconfigure: unable to re-open stdin: No such file or directory" warnings
    export DEBIAN_FRONTEND=noninteractive
    # Fetch and run install script
    wget -O install-site.sh --no-verbose https://github.com/mysociety/commonlib/raw/master/bin/install-site.sh
    sh install-site.sh --dev fixmystreet vagrant 127.0.0.1.xip.io
    # We want to be on port 3000 for development
    sed -i -r -e "s,^( *BASE_URL: .*)',\\1:3000'," fixmystreet/conf/general.yml
    # All done
    echo "****************"
    echo "You can now ssh into your vagrant box: vagrant ssh"
    echo "The website code is found in: ~/fixmystreet"
    echo "You can run the dev server with: script/fixmystreet_app_server.pl [-d] [-r] [--fork]"
  EOS

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
