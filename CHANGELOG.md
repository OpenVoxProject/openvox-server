# Changelog

All notable changes to this project will be documented in this file.

## [9.0.0-beta1](https://github.com/openvoxproject/openvox-server/tree/9.0.0-beta1) (2026-07-14)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.13.0...9.0.0-beta1)

**Breaking changes:**

- JRUBY 10, YO [\#468](https://github.com/OpenVoxProject/openvox-server/pull/468) ([Sharpie](https://github.com/Sharpie))
- CI: Stop building on amazon-2  [\#349](https://github.com/OpenVoxProject/openvox-server/pull/349) ([bastelfreak](https://github.com/bastelfreak))
- CI: Stop building packages for Debian 11 & 12 [\#343](https://github.com/OpenVoxProject/openvox-server/pull/343) ([bastelfreak](https://github.com/bastelfreak))
- Mark java 25 as supported & Drop support for Java 17 [\#336](https://github.com/OpenVoxProject/openvox-server/pull/336) ([bastelfreak](https://github.com/bastelfreak))
- remove pe\_serverversion fact [\#247](https://github.com/OpenVoxProject/openvox-server/pull/247) ([corporate-gadfly](https://github.com/corporate-gadfly))
- Update to jetty12 [\#217](https://github.com/OpenVoxProject/openvox-server/pull/217) ([austb](https://github.com/austb))

**Implemented enhancements:**

- Inform trapperkeeper about service readiness [\#465](https://github.com/OpenVoxProject/openvox-server/pull/465) ([bastelfreak](https://github.com/bastelfreak))
- exclude jruby windows binaries and rdoc artifacts from uberjar [\#321](https://github.com/OpenVoxProject/openvox-server/pull/321) ([corporate-gadfly](https://github.com/corporate-gadfly))
- Support podman in tasks/build.rake [\#227](https://github.com/OpenVoxProject/openvox-server/pull/227) ([gregorynisbet-google](https://github.com/gregorynisbet-google))

**Fixed bugs:**

- \[Bug\]: Race condition in JRuby startup leads to flakyness in OpenVox Server tests [\#414](https://github.com/OpenVoxProject/openvox-server/issues/414)
- \[Bug\]: Don't include jruby-openssl as a vendored gem as JRuby 10.0.6.0+ / 9.4.15.0 include it as a dependency [\#366](https://github.com/OpenVoxProject/openvox-server/issues/366)
- \[Bug\]: Update to 8.13.0 breaks ruby function openssl EC use [\#322](https://github.com/OpenVoxProject/openvox-server/issues/322)
- \[Bug\]: Uninstalling openvox-server on SLES 15.7 not possible [\#245](https://github.com/OpenVoxProject/openvox-server/issues/245)
- \[Bug\]: Installation of openvox-server using package resource fails \(partly\) on SLES 15.7 [\#244](https://github.com/OpenVoxProject/openvox-server/issues/244)
- \[Maintenance\]: Performance issues with ring-core 1.15.x need investigation [\#197](https://github.com/OpenVoxProject/openvox-server/issues/197)
- Fix Jolokia 2.x configuration [\#377](https://github.com/OpenVoxProject/openvox-server/pull/377) ([Sharpie](https://github.com/Sharpie))
- isolate SLES RPM macros in /opt/suse-rpm-macros [\#346](https://github.com/OpenVoxProject/openvox-server/pull/346) ([corporate-gadfly](https://github.com/corporate-gadfly))
- Download SLES RPM macros to aid in expansion of macros [\#344](https://github.com/OpenVoxProject/openvox-server/pull/344) ([corporate-gadfly](https://github.com/corporate-gadfly))
- add jruby-openssl 0.16.0 to vendored gems [\#324](https://github.com/OpenVoxProject/openvox-server/pull/324) ([corporate-gadfly](https://github.com/corporate-gadfly))

**Security fixes:**

- Upgrade concurrent-ruby 1.3.5-\>1.3.7 [\#435](https://github.com/OpenVoxProject/openvox-server/pull/435) ([Sharpie](https://github.com/Sharpie))
- Upgrade JRuby 9.4.12.1-\>9.4.15.0 [\#434](https://github.com/OpenVoxProject/openvox-server/pull/434) ([Sharpie](https://github.com/Sharpie))
- Consolidate Jackson usage on 2.21.4 [\#395](https://github.com/OpenVoxProject/openvox-server/pull/395) ([Sharpie](https://github.com/Sharpie))

**Closed issues:**

- \[Doc\] Issues link is dead following Perforce doc change [\#17](https://github.com/OpenVoxProject/openvox-server/issues/17)

**Merged pull requests:**

- Build JARs with Java version based on branch [\#483](https://github.com/OpenVoxProject/openvox-server/pull/483) ([Sharpie](https://github.com/Sharpie))
- acceptance: Run tests against Postgres 17 [\#479](https://github.com/OpenVoxProject/openvox-server/pull/479) ([Sharpie](https://github.com/Sharpie))
- Update acceptance tests for compatibility with latest OpenVox 9 [\#470](https://github.com/OpenVoxProject/openvox-server/pull/470) ([Sharpie](https://github.com/Sharpie))
- fix regex to accept 3 multi-digit version string [\#469](https://github.com/OpenVoxProject/openvox-server/pull/469) ([corporate-gadfly](https://github.com/corporate-gadfly))
- ci: enable auto-merge for renovate [\#440](https://github.com/OpenVoxProject/openvox-server/pull/440) ([rwaffen](https://github.com/rwaffen))
- CI: Drop redundant MRI matrix from RSpec tests [\#427](https://github.com/OpenVoxProject/openvox-server/pull/427) ([silug](https://github.com/silug))
- renovate: set automergeStrategy [\#425](https://github.com/OpenVoxProject/openvox-server/pull/425) ([bastelfreak](https://github.com/bastelfreak))
- Explicitly check out main branch during backports [\#379](https://github.com/OpenVoxProject/openvox-server/pull/379) ([Sharpie](https://github.com/Sharpie))
- Add arm64 support to acceptance [\#374](https://github.com/OpenVoxProject/openvox-server/pull/374) ([jpartlow](https://github.com/jpartlow))
- CI: test building on Fedora 44 [\#348](https://github.com/OpenVoxProject/openvox-server/pull/348) ([bastelfreak](https://github.com/bastelfreak))
- Readd workflow to backport PRs [\#347](https://github.com/OpenVoxProject/openvox-server/pull/347) ([bastelfreak](https://github.com/bastelfreak))
- Dockerfile: Dont install vim & Replace java-21-openjdk-devel-\>java-21-openjdk-headless [\#345](https://github.com/OpenVoxProject/openvox-server/pull/345) ([bastelfreak](https://github.com/bastelfreak))
- feat: simplify container build by using ADD, list packages more readable [\#342](https://github.com/OpenVoxProject/openvox-server/pull/342) ([rwaffen](https://github.com/rwaffen))
- CI: Add Java 25 [\#335](https://github.com/OpenVoxProject/openvox-server/pull/335) ([bastelfreak](https://github.com/bastelfreak))
- Provide --format='{{json .ID}}' when listing docker images. [\#332](https://github.com/OpenVoxProject/openvox-server/pull/332) ([gregorynisbet-google](https://github.com/gregorynisbet-google))
- build: Switch to alma 10 / Java 21 / system Ruby [\#330](https://github.com/OpenVoxProject/openvox-server/pull/330) ([bastelfreak](https://github.com/bastelfreak))
- Use Ruby 4 for builder image and cache it [\#311](https://github.com/OpenVoxProject/openvox-server/pull/311) ([nmburgan](https://github.com/nmburgan))
- Migrate config to use trapperkeeper-webserver [\#299](https://github.com/OpenVoxProject/openvox-server/pull/299) ([nmburgan](https://github.com/nmburgan))
- Update acceptance descriptions and defaults for OpenVox 9 [\#297](https://github.com/OpenVoxProject/openvox-server/pull/297) ([nmburgan](https://github.com/nmburgan))
- Target openvox9 platform for main branch [\#296](https://github.com/OpenVoxProject/openvox-server/pull/296) ([nmburgan](https://github.com/nmburgan))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
