## Unreleased

## 7.18.2
* Fixed package metadata to require Java 11 or 17 rather than Java 8. Puppetserver removed support for Java 8, but still builds with it for some reason. Openvox-server is built with Java 11.

## 7.18.1
* Fixed package metadata to require openvox-agent >= 7.35.0. Was previously mistakenly set to openvox-agent >= 8.11.0.

## 7.18.0
* Initial openvox-server release. Based on puppetserver 7.17.3. Supported on all platforms that puppetserver currently supports, but for all architectures rather than just x86_64.
