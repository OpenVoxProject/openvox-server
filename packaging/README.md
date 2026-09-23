# openvox-server packaging

This directory holds the [vanagon](https://github.com/openvoxproject/vanagon)
configuration that builds the openvox-server rpm and deb packages. The packages
are noarch and are built once per supported platform so each one carries the
right java dependency, dist tag, and maintainer scripts.

Two vanagon projects make up the build:

1. `openvox-server-uberjar` builds everything that needs the JVM toolchain: the
   `puppet-server-release.jar` uberjar, the vendored gems, and on the FIPS
   variant the BouncyCastle FIPS jars. It runs once per variant, on the
   platforms specified in `UBERJAR_PLATFORMS` in `lib/server_packaging.rb`, and
   its output is a rooted archive, `openvox-server-uberjar-<version>.<platform>.tar.gz`,
   that CI uploads to the artifacts S3 bucket.
2. `openvox-server` builds the package for one platform. The `uberjar-tarball`
   component fetches the matching uberjar archive (from S3 in CI, or from
   `packaging/output` for local builds) and the `openvox-server` component
   installs all authored content from `packaging/resources/`: CLI wrappers and
   configs from `resources/files/`, and the systemd unit, defaults file, and
   tmpfiles config rendered from the templates next to it.

The package build for `SOURCE_TARBALL_PLATFORM` in `lib/server_packaging.rb` 
also writes `openvox-server-<version>.tar.gz` to `packaging/output/`. That is
the tarball downstream packagers such as the FreeBSD port build from: the jar
and the authored content in the layout of the ezbake source tarball, under a
`puppetserver-<version>/` top level directory.

Both run through `rake "vox:build[<project>,<platform>]"` at the repo root,
which is what the shared CI workflow calls.

## Local builds

Requirements: docker and `bundle install` at the repo root. The JDK and
leiningen are installed inside the build container.

```sh
bundle exec rake "vox:build[openvox-server,el-9-x86_64]"
bundle exec rake "vox:build[openvox-server,ubuntu-24.04-amd64]"
bundle exec rake "vox:build[openvox-server,redhatfips-9-x86_64]"
```

A package build first builds the uberjar archive it needs when that is missing
from `packaging/output/`. To build the archive on its own:

```sh
bundle exec rake "vox:build[openvox-server-uberjar,el-9-x86_64]"
```

Set `SERVER_TARBALL_BASE` to a `file://` or `https://` directory URL to fetch
the archive from somewhere else. Packages land in `packaging/output/`.

The Clojure dependencies can be rebuilt from source before the uberjar build
with `DEP_REBUILD` (a comma separated subset), `DEP_REBUILD_BRANCH`,
`DEP_REBUILD_ORG` and `FULL_DEP_REBUILD_BRANCH`, as with the ezbake build.

## Service styles

Two systemd service styles are maintained (see `packaging/resources/systemd/`).
The `direct` style matches the ezbake 4.x packages shipped for OpenVox 9 and is
the default there. It runs java straight from the unit with `Type=notify`, or
`Type=notify-reload` on platforms with systemd 253 or newer. The `wrapper`
style matches the ezbake 2.x packages shipped for OpenVox 8 and is the default
for 8.x versions. It runs the service through the start/stop/reload CLI
wrappers in `resources/files/wrapper/`. Override with `SERVER_SERVICE_STYLE`.
