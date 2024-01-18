#!/bin/bash
set -eu

# Step 0: Install required pkgs
sudo apt-get -y install libtool m4 automake bison flex

# Step 1: Generating autotool scripts
libtoolize
aclocal
autoheader
automake --add-missing
autoconf

# Step 2: Compilation and installation
./configure
make
sudo make install
