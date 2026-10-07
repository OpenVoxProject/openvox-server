platform "fedora-43-x86_64" do |plat|
  plat.inherit_from_default
  # Only so the package file name matches the one the ezbake build produced.
  # Vanagon's default would be fc43, which works just as well.
  plat.dist 'fedora43'
end
