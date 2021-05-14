# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  
    # boxes at https://vagrantcloud.com/search.
    config.vm.box = "ubuntu/focal64"
  
    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    # NOTE: This will enable public access to the opened port
    config.vm.network "forwarded_port", guest: 80, host: 8080
  
    # Provider-specific configuration so you can fine-tune various
    # backing providers for Vagrant. These expose provider-specific options.
    # Example for VirtualBox:
    config.vm.provider "virtualbox" do |vb|
      # Display the VirtualBox GUI when booting the machine
      # vb.gui = true
      vb.memory = "4196"
      vb.cpus = 2
    end
    # config.disksize.size = '15GB'
  
    # Enable provisioning with a shell script. Additional provisioners such as
    # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
    # documentation for more information about their specific syntax and use.
    # config.vm.provision "shell", inline: <<-SHELL
    # echo "hello-world"
    # SHELL
    config.vm.provision "file", source: "namespaces.yml", destination: "namespaces.yml"
    config.vm.provision "shell", path: "deploy.sh" 
  end
  