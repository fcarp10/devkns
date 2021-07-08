# -*- mode: ruby -*-
# vi: set ft=ruby :

# ports to forward
ports=[8080, 5672, 15672, 9200, 5601] # [openfaas, rabbitmq, rabbitmq, elasticsearch, kibana]

$script = <<-'SCRIPT'
apt-get update && apt-get install curl jq -y
./deploy.sh -c 'rabbitmq' -d 'true' -p 'false' -g 'true' -x 'true'
SCRIPT

Vagrant.configure("2") do |config|
  
    # boxes at https://vagrantcloud.com/search.
    config.vm.box = "ubuntu/focal64"
  
    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    # NOTE: This will enable public access to the opened port
    ports.each do |port|
      config.vm.network :forwarded_port, guest: port, host: port
    end
  
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

    files = ["namespaces.yml", "logstash_values.yml", "utils.sh", "deploy.sh"]
    files.each do |f|
      config.vm.provision "file", source: f, destination: f
    end

    config.vm.provision "shell", inline: $script

  end
  