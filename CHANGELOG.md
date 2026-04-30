# Changelog

All notable changes to this project will be documented in this file.

## [8.13.0](https://github.com/openvoxproject/openvox-server/tree/8.13.0) (2026-04-30)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.12.1...8.13.0)

**Implemented enhancements:**

- openvoxserver-ca: Update 3.1.1-\>3.2.0 [\#256](https://github.com/OpenVoxProject/openvox-server/pull/256) ([bastelfreak](https://github.com/bastelfreak))
- remove unused build dependencies  [\#254](https://github.com/OpenVoxProject/openvox-server/pull/254) ([bastelfreak](https://github.com/bastelfreak))
- Depend on latest openvox-agent packages [\#253](https://github.com/OpenVoxProject/openvox-server/pull/253) ([bastelfreak](https://github.com/bastelfreak))
- ezbake: Update 2.7.3-\>2.7.4 [\#252](https://github.com/OpenVoxProject/openvox-server/pull/252) ([bastelfreak](https://github.com/bastelfreak))
- Add Ubuntu 26.04 to build matrix [\#251](https://github.com/OpenVoxProject/openvox-server/pull/251) ([bastelfreak](https://github.com/bastelfreak))

**Fixed bugs:**

- \[Bug\]: Exception after pruning CRL [\#202](https://github.com/OpenVoxProject/openvox-server/issues/202)
- Change chown during install to check java.security.fips file existence [\#199](https://github.com/OpenVoxProject/openvox-server/pull/199) ([nmburgan](https://github.com/nmburgan))

**Merged pull requests:**

- fix: include tarballs in snapshot artifact upload by matching on version [\#286](https://github.com/OpenVoxProject/openvox-server/pull/286) ([slauger](https://github.com/slauger))
- Remove FIPS BC jars from ezbake-fips dependencies [\#274](https://github.com/OpenVoxProject/openvox-server/pull/274) ([nmburgan](https://github.com/nmburgan))
- version bump for dependencies [\#242](https://github.com/OpenVoxProject/openvox-server/pull/242) ([corporate-gadfly](https://github.com/corporate-gadfly))
- replace Joda-Time with with java.time API [\#233](https://github.com/OpenVoxProject/openvox-server/pull/233) ([corporate-gadfly](https://github.com/corporate-gadfly))
- Remove dujour-version-check from dependencies [\#232](https://github.com/OpenVoxProject/openvox-server/pull/232) ([corporate-gadfly](https://github.com/corporate-gadfly))
- remove unused dujour-version-check [\#231](https://github.com/OpenVoxProject/openvox-server/pull/231) ([corporate-gadfly](https://github.com/corporate-gadfly))
- Add Podman compatibility to vox:build task [\#228](https://github.com/OpenVoxProject/openvox-server/pull/228) ([Sharpie](https://github.com/Sharpie))
- Use new ezbake methods for managing BC FIPS jars [\#196](https://github.com/OpenVoxProject/openvox-server/pull/196) ([nmburgan](https://github.com/nmburgan))

## [8.12.1](https://github.com/openvoxproject/openvox-server/tree/8.12.1) (2026-01-21)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.12.0...8.12.1)

**Fixed bugs:**

- \[Bug\]: openvox-server 8.12.0 seems unable to serve directories \(recurse =\> true\)  for file resources [\#183](https://github.com/OpenVoxProject/openvox-server/issues/183)

**Merged pull requests:**

- Downgrade ring-core to version 1.14.2 [\#184](https://github.com/OpenVoxProject/openvox-server/pull/184) ([nmburgan](https://github.com/nmburgan))
- CI: Update comment with ZIP link [\#179](https://github.com/OpenVoxProject/openvox-server/pull/179) ([bastelfreak](https://github.com/bastelfreak))
- CI: Drop beaker-abs & beaker-vmpooler, allow latest beaker-hostgenerator [\#171](https://github.com/OpenVoxProject/openvox-server/pull/171) ([bastelfreak](https://github.com/bastelfreak))

## [8.12.0](https://github.com/openvoxproject/openvox-server/tree/8.12.0) (2026-01-15)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.11.0...8.12.0)

**Implemented enhancements:**

- Add Ubuntu 25.10 support [\#138](https://github.com/OpenVoxProject/openvox-server/pull/138) ([bastelfreak](https://github.com/bastelfreak))
- lein-parent: Update 0.3.7-\>0.3.9 [\#108](https://github.com/OpenVoxProject/openvox-server/pull/108) ([bastelfreak](https://github.com/bastelfreak))
- Add Ruby 4.0 support [\#107](https://github.com/OpenVoxProject/openvox-server/pull/107) ([bastelfreak](https://github.com/bastelfreak))
- Update dependencies [\#105](https://github.com/OpenVoxProject/openvox-server/pull/105) ([nmburgan](https://github.com/nmburgan))

**Fixed bugs:**

- \[Bug\]: /puppet-ca/v1/sign endpoint has no configuration in auth.conf [\#100](https://github.com/OpenVoxProject/openvox-server/issues/100)
- \[Bug\]: Could not find 'facter' \(\>= 2.0.1, \< 5\) among 110 total gem\(s\) \(Gem::MissingSpecError\) [\#94](https://github.com/OpenVoxProject/openvox-server/issues/94)
- \[Bug\]: openvox-server 8.11.0-1+debian13 Trixie Package Java Dependency [\#91](https://github.com/OpenVoxProject/openvox-server/issues/91)
- \[Bug\]: RHEL9 openvox8 fails to start [\#90](https://github.com/OpenVoxProject/openvox-server/issues/90)
- \[Bug\]: EL10 \(Alma Linux 10\) openvox-server-8.8.1 and openvoxdb-8.9.1 fails to install due to the missing java-17-openjdk-headless [\#36](https://github.com/OpenVoxProject/openvox-server/issues/36)
- remove stale dependencies and imports [\#106](https://github.com/OpenVoxProject/openvox-server/pull/106) ([corporate-gadfly](https://github.com/corporate-gadfly))

**Merged pull requests:**

- client\_may\_use\_external\_cert\_chains test: don't use /tmp [\#170](https://github.com/OpenVoxProject/openvox-server/pull/170) ([nmburgan](https://github.com/nmburgan))
- split\_external\_cas test: don't use /tmp [\#169](https://github.com/OpenVoxProject/openvox-server/pull/169) ([nmburgan](https://github.com/nmburgan))
- More changes for FIPS builds [\#168](https://github.com/OpenVoxProject/openvox-server/pull/168) ([nmburgan](https://github.com/nmburgan))
- Add FIPS-only build [\#167](https://github.com/OpenVoxProject/openvox-server/pull/167) ([nmburgan](https://github.com/nmburgan))
- Change how we define the version [\#166](https://github.com/OpenVoxProject/openvox-server/pull/166) ([nmburgan](https://github.com/nmburgan))
- Update build task to handle building FIPS [\#165](https://github.com/OpenVoxProject/openvox-server/pull/165) ([nmburgan](https://github.com/nmburgan))
- Move versions into managed deps and update openvox components [\#158](https://github.com/OpenVoxProject/openvox-server/pull/158) ([nmburgan](https://github.com/nmburgan))
- Add logback version check [\#139](https://github.com/OpenVoxProject/openvox-server/pull/139) ([nmburgan](https://github.com/nmburgan))
- Remove clj-parent [\#114](https://github.com/OpenVoxProject/openvox-server/pull/114) ([nmburgan](https://github.com/nmburgan))
- Changes for FIPS [\#112](https://github.com/OpenVoxProject/openvox-server/pull/112) ([nmburgan](https://github.com/nmburgan))
- Remove testing Java 11 on el8 [\#104](https://github.com/OpenVoxProject/openvox-server/pull/104) ([nmburgan](https://github.com/nmburgan))
- Change namespace, update versions, update build task [\#101](https://github.com/OpenVoxProject/openvox-server/pull/101) ([nmburgan](https://github.com/nmburgan))
- Update gem lists [\#99](https://github.com/OpenVoxProject/openvox-server/pull/99) ([nmburgan](https://github.com/nmburgan))
- \(maint\) Drop beaker parameters from beaker\_acceptance.yml call [\#93](https://github.com/OpenVoxProject/openvox-server/pull/93) ([jpartlow](https://github.com/jpartlow))

## [8.11.0](https://github.com/openvoxproject/openvox-server/tree/8.11.0) (2025-08-24)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.10.0...8.11.0)

**Implemented enhancements:**

- Improve regen\_certs script [\#82](https://github.com/OpenVoxProject/openvox-server/pull/82) ([jcharaoui](https://github.com/jcharaoui))

**Fixed bugs:**

- Fix CRL test with uncommon timezone [\#81](https://github.com/OpenVoxProject/openvox-server/pull/81) ([jcharaoui](https://github.com/jcharaoui))

**Merged pull requests:**

- Fix tag task [\#89](https://github.com/OpenVoxProject/openvox-server/pull/89) ([nmburgan](https://github.com/nmburgan))
- Allow override of ezbake version and fix ezbake ref passthrough [\#87](https://github.com/OpenVoxProject/openvox-server/pull/87) ([nmburgan](https://github.com/nmburgan))
- Update net-imap [\#86](https://github.com/OpenVoxProject/openvox-server/pull/86) ([binford2k](https://github.com/binford2k))
- feat: do single prs for updates, to better see what breaks atm [\#71](https://github.com/OpenVoxProject/openvox-server/pull/71) ([rwaffen](https://github.com/rwaffen))

## [8.10.0](https://github.com/openvoxproject/openvox-server/tree/8.10.0) (2025-07-31)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.9.0...8.10.0)

**Implemented enhancements:**

- Consider Java 21 "supported" [\#62](https://github.com/OpenVoxProject/openvox-server/pull/62) ([smortex](https://github.com/smortex))
- Introduce EZBAKE\_REPO to select the ezbake repository & optimize git clone [\#59](https://github.com/OpenVoxProject/openvox-server/pull/59) ([ekohl](https://github.com/ekohl))
- depend on openvox-agent 8.21.1 or newer [\#58](https://github.com/OpenVoxProject/openvox-server/pull/58) ([bastelfreak](https://github.com/bastelfreak))
- Run tests on JRE11, 17 & 21 \(21 without FIPS\) [\#57](https://github.com/OpenVoxProject/openvox-server/pull/57) ([bastelfreak](https://github.com/bastelfreak))
- chore: update rexml to 3.4.1 [\#54](https://github.com/OpenVoxProject/openvox-server/pull/54) ([SimonHoenscheid](https://github.com/SimonHoenscheid))

**Security fixes:**

- sec: CVE 2024-49761 update rexml to 3.3.9 [\#42](https://github.com/OpenVoxProject/openvox-server/pull/42) ([SimonHoenscheid](https://github.com/SimonHoenscheid))

## [8.9.0](https://github.com/openvoxproject/openvox-server/tree/8.9.0) (2025-07-19)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.8.1...8.9.0)

**Fixed bugs:**

- \[Bug\]: Server phones to updates.puppet.com on startup [\#22](https://github.com/OpenVoxProject/openvox-server/issues/22)
- \[Bug\]: PuppetServer CA service sets the CRL NextUpdate field to 5 Years into the future [\#14](https://github.com/OpenVoxProject/openvox-server/issues/14)
- Fix git submodules [\#44](https://github.com/OpenVoxProject/openvox-server/pull/44) ([bastelfreak](https://github.com/bastelfreak))

**Merged pull requests:**

- openvox-server: depend on openvox-agent 8.21.0 or newer [\#53](https://github.com/OpenVoxProject/openvox-server/pull/53) ([bastelfreak](https://github.com/bastelfreak))
- \(maint\) Drop debian-10 from testing matrix [\#40](https://github.com/OpenVoxProject/openvox-server/pull/40) ([jpartlow](https://github.com/jpartlow))
- packaging: Switch from Perforce to OpenVoxProject releases [\#38](https://github.com/OpenVoxProject/openvox-server/pull/38) ([bastelfreak](https://github.com/bastelfreak))
- Replace puppetserver-ca gem with openvoxserver-ca [\#34](https://github.com/OpenVoxProject/openvox-server/pull/34) ([bastelfreak](https://github.com/bastelfreak))
- Drop analytics/dropsonde integration in openvox-server [\#9](https://github.com/OpenVoxProject/openvox-server/pull/9) ([ekohl](https://github.com/ekohl))

## [8.8.1](https://github.com/openvoxproject/openvox-server/tree/8.8.1) (2025-03-19)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.8.0...8.8.1)

**Fixed bugs:**

- \[Bug\]: openvox-server 7.18.1 fails to start [\#5](https://github.com/OpenVoxProject/openvox-server/issues/5)

**Merged pull requests:**

- Add replaces/conflicts on puppetserver [\#12](https://github.com/OpenVoxProject/openvox-server/pull/12) ([nmburgan](https://github.com/nmburgan))
- Add CHANGELOG.md [\#6](https://github.com/OpenVoxProject/openvox-server/pull/6) ([nmburgan](https://github.com/nmburgan))
- Fix build task to remove unneeded i386 folders [\#4](https://github.com/OpenVoxProject/openvox-server/pull/4) ([nmburgan](https://github.com/nmburgan))

## [8.8.0](https://github.com/openvoxproject/openvox-server/tree/8.8.0) (2025-01-16)

[Full Changelog](https://github.com/openvoxproject/openvox-server/compare/8.7.0...8.8.0)



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
