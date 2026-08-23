#!/bin/sh
# Flutter generates FlutterGeneratedPluginSwiftPackage at iOS 13.0 by default;
# bump to match Runner's IPHONEOS_DEPLOYMENT_TARGET (15.0).
set -e
PKG="${SRCROOT}/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if [ ! -f "$PKG" ]; then
  exit 0
fi
for ver in 13.0 14.0; do
  sed -i '' "s/.iOS(\"${ver}\")/.iOS(\"15.0\")/g" "$PKG"
done
