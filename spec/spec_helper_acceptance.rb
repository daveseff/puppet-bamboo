require 'beaker-pe'
require 'beaker-puppet'
require 'beaker-rspec/spec_helper'
require 'beaker-rspec/helpers/serverspec'
require 'beaker/puppet_install_helper'
require 'beaker/module_install_helper'
require 'spec_vars' if File.file?(File.join(File.dirname(__FILE__), 'spec_vars.rb'))

run_puppet_install_helper
configure_type_defaults_on(hosts)
install_ca_certs unless %r{pe}i.match?(ENV['PUPPET_INSTALL_TYPE'])
install_module_on(hosts)
install_module_dependencies_on(hosts)

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module and dependencies
    puppet_module_install(source: proj_root, module_name: 'bamboo')
    # net-tools required for netstat utility being used by be_listening
    if fact('osfamily') == 'RedHat' && fact('operatingsystemmajrelease') == '7'
      pp = <<-EOS
        package { 'net-tools': ensure => installed }
      EOS

      apply_manifest_on(agents, pp, catch_failures: false)
    end

    hosts.each do |host|
      on host, '/bin/touch /etc/puppetlabs/code/hiera.yaml'
      on host, 'chmod 755 /root'
      if fact_on(host, 'osfamily') == 'Debian'
        # Install sources for OpenJDK 8 on older distributions
        if fact_on(host, 'operatingsystem') == 'Ubuntu'
          on host, 'apt-get install -y software-properties-common'
          on host, 'add-apt-repository ppa:openjdk-r/ppa'
        end

        on host, 'apt-get update'

      end

      on host, puppet('module', 'install', 'puppetlabs-stdlib'), acceptable_exit_codes: [0, 1]
      on host, puppet('module', 'install', 'puppet-staging'), acceptable_exit_codes: [0, 1]
      on host, puppet('module', 'install', 'puppetlabs-java'), acceptable_exit_codes: [0, 1]
    end
  end
end
