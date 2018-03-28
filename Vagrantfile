# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
require 'socket'

if File.exist?('vagrant_hosts.yml')
  hosts = YAML.load_file('vagrant_hosts.yml')
else
  hosts = [{'name' => 'default'}]
end

begin
  hostname = Socket.gethostbyname(Socket.gethostname).first
rescue
  hostname = 'ght'
end
dir_basename = File.basename(File.expand_path(File.dirname(__FILE__)))

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "centos/7"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"
  config.vm.network "private_network", type: "dhcp" if hosts.count > 1

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"
  #config.vm.synced_folder ".", "/home/vagrant/sync", type: "virtualbox"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  #config.vm.provision "bootstrap", type: "shell", path: "bootstrap.sh"
  #config.vm.provision "etc_hosts", type: "shell", path: "etc_hosts.sh" if hosts.count > 1

  # Provision hosts detailed in vagrant_hosts.yml
  hosts.each_with_index do |host, index|
    config.vm.define host['name'], autostart: host.fetch('autostart', true), primary: index==0?true:false do |node|
      node.vm.box = "#{host['box']}" if host.has_key?('box')
      node.vm.hostname = "#{host['name']}.#{dir_basename}.#{hostname}"
      if host.has_key?('forwarded_ports')
        host['forwarded_ports'].each do |forwarded_port|
          node.vm.network "forwarded_port", guest: forwarded_port['guest_port'], host_ip: "127.0.0.1", host: forwarded_port['host_port'], protocol: forward_port.fetch('protocol', 'tcp'), auto_correct: true
        end
      end
      if host.has_key?('synced_folders')
        host['synced_folders'].each do |synced_folder|
          node.vm.synced_folder synced_folder['src'], synced_folder['dest'], type: "virtualbox"
        end
      end
      node.vm.provider "virtualbox" do |vb|
         vb.cpus   = host['cpus']   if host.has_key?('cpus')
         vb.gui    = host['gui']    if host.has_key?('gui')
         vb.memory = host['memory'] if host.has_key?('memory')
         # vb.customize ['modifyvm', :id, '--groups', dir_basename]
         if host.has_key?('hdd') && host['hdd'] = 'true'
           vb.customize ['createhd','--filename',"#{host['name']}",'--size',500*1024] unless File.exist?("./#{host['name']}.vdi")
           vb.customize ['storageattach',:id,'--storagectl','IDE','--port',1,'--device',0,'--type','hdd','--medium',"#{host['name']}.vdi"]
           #vb.customize ['storageattach',:id,'--storagectl','IDE Controller','--port',1,'--device',0,'--type','hdd','--medium',"#{host['name']}.vdi"]
         end
      end
      if host.has_key?('provisioners')
        host['provisioners'].each do |provision|
          case provision.fetch('type', 'shell')
          when 'shell'
            node.vm.provision "#{provision['name']}", type: "shell", path: Dir.glob("bin.d/**/#{provision['script']}")[0] if provision.fetch('type', 'shell') == 'shell'
          when 'ansible'
            if File.directory?("ansible") and provision.fetch('enable', true)
              node.vm.provision "ansible_local" do |ansible|
                ansible.install = true
                ansible.inventory_path = 'inventory'
                ansible.limit = 'all'
                ansible.provisioning_path = '/vagrant/ansible'
                ansible.playbook = 'playbook.yml'
                ansible.verbose = true
              end
            end
          when 'puppet'
            if File.directory?("puppet") and provision.fetch('enable', true)
              node.vm.synced_folder "./puppet", "/etc/puppet", type: "virtualbox"
              node.vm.provision "bootstrap", type: "shell", path: "bootstrap.sh"

              node.vm.provision "puppet" do |puppet|
                puppet.manifests_path    = ["vm", "/etc/puppet/manifests"]
                puppet.manifest_file     = "site.pp"
                puppet.module_path       = ["vm", "/etc/puppet/modules"]
                puppet.hiera_config_path = ["vm", "puppet/hiera.yaml"]
                puppet.working_directory = "/tmp/vagrant-puppet"
                puppet.options           = "--verbose"
              end
            end
          end
        end
      end
    end
  end
end
