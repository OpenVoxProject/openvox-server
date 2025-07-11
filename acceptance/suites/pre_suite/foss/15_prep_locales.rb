test_name 'Ensure en_US.UTF-8 locale is present on Debian for openvoxdb migrations' do
  confine :to, :platform => /^debian/
  on(master, puppet_resource('package', 'locales-all', 'ensure=present'))
end
