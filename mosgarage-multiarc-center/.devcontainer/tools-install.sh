#!/bin/bash
# shellcheck source-path=SCRIPTDIR/../scripts
#
# executable
#
# install tools in the development environment

set -e


function installAzureCli() {
    # Installing az-cli via "pip" install Python dependencies in conflicts with development around security & login
    # So instead, we will use the deb package to do so (not from Universe repo, as outdated). The script below adds a repo
    # and install the latest version of the cli
    # Note: the deb package does not support arm64 architecture, hence the test first

    pushd /tmp > /dev/null
    envArchitecture=$(arch)

    if [ "${envArchitecture}" = "x86_64" ]; then
        sudo curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi

    popd > /dev/null
}

installAzureCli
