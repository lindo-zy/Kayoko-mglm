# Kayoko

Feature-rich clipboard manager for iOS.

A Kayoko fork maintained by **mlgm**, based on the [OwnGoal Studio edition](https://github.com/OwnGoalStudio/Kayoko).

## Credits

- Original project: [AlexandraAurora/Kayoko](https://github.com/AlexandraAurora/Kayoko)
- Based on: [OwnGoalStudio/Kayoko](https://github.com/OwnGoalStudio/Kayoko)

## License

GPLv3. See [`COPYING`](COPYING).

## RootHide local builds

The local RootHide toolchain is expected at `/Users/xiao/dev/theos-roothide` with
`iPhoneOS16.5.sdk` and `iPhoneOS17.0.sdk` installed in its `sdks` directory.

Build both packages:

```sh
./build-roothide-ios.sh all
```

The iOS 16 and iOS 17 debs are written to `packages/ios16` and
`packages/ios17`, respectively. Pass `ios16` or `ios17` instead of `all` to
build only one target. Their package metadata requires the matching minimum
firmware version. Every successful invocation increments the patch component of
`PACKAGE_VERSION` once and writes the new version back to `Makefile`. Output
filenames include `_ios16_` or `_ios17_`. Set `THEOS` to override the toolchain
path.
