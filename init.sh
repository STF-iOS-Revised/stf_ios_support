#!/bin/bash

mkdir -p repos

GR="\033[32m"
RED="\033[91m"
RST="\033[0m"

function install_brew_if_needed() {
  if ! command -v brew > /dev/null; then
    echo "Brew not installed; installing"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

function assert_has_xcodebuild() {
  XCODE_VERSION="none"
  XCODE_MAJOR_VERSION="0"
  XCODE_MINOR_VERSION="0"
  if command -v xcodebuild > /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | grep Xcode | tr -d "\n" | perl -pe 's/Xcode //')
    XCODE_MAJOR_VERSION=$(echo $XCODE_VERSION | perl -pe 's/([0-9]+)\.[0-9]+/$1/')
    XCODE_MINOR_VERSION=$(echo $XCODE_VERSION | perl -pe 's/[0-9]+\.([0-9]+)/$1/')
  fi

  if ((XCODE_MAJOR_VERSION > 10)) || ( ((XCODE_MAJOR_VERSION == 10)) && ((XCODE_MINOR_VERSION >= 3))); then
    echo -e "${GR}Xcode $XCODE_VERSION installed$RST"
  else
    echo -e "${RED}Xcode 10.3+ not installed$RST"
    echo -e "${RED}You need to install it and then rerun init.sh script$RST"
    exit 1
  fi
}

install_brew_if_needed
assert_has_xcodebuild

./util/brewser.pl installdeps stf_ios_support.rb


# TODO Bellow code pending review

./util/brewser.pl ensurehead libplist 2.2.1
./util/brewser.pl fixpc libplist 2.0

./util/brewser.pl ensurehead libusbmuxd 2.0.3
./util/brewser.pl fixpc libusbmuxd 2.0

./util/brewser.pl ensurehead libimobiledevice 1.3.1
./util/brewser.pl fixpc libimobiledevice 1.0

#make libimd
