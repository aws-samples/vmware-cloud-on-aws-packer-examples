#!/usr/bin/env bash

set -e

/usr/bin/printf "Installing AWS CLI...\n"
PATH="$HOME/.local/bin:$PATH" /usr/bin/pip3 install --quiet awscli

