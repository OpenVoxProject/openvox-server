# Building RPM packaging

This layout is compatible with [fedpkg](https://pagure.io/fedpkg/).

## Creating an SRPM

First you need the source files

```sh
spectool -g openvox-server.spec
```

Then you can use fedpkg to create the SRPM:

```sh
fedpkg srpm
```

## Building locally

Using mock it's easy to build locally.

```sh
fedpkg mockbuild --enable-network
```

Now you can find your files in `results_openvox-server`.

By default the above builds using Fedora Rawhide, but the release can be specified:

```sh
fedpkg --release epel10 mockbuild --enable-network
```

## Building in COPR

This again relies on having the source present.
It is needed to enable network access during the build.

```sh
fedpkg copr-build ekohl/openvox8 -- --enable-net on
```
