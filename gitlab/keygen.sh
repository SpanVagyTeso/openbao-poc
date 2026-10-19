#!/bin/sh
# Generates the GitLab root password and the root API token used by OpenTofu, if they don't exist yet.
set -eu

umask 077
cd /secrets

random() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$1"
}

if [ -s root-password ]; then
  echo "GitLab root password already exists"
else
  random 32 > root-password
  echo "GitLab root password written to secrets/gitlab/root-password"
fi

if [ -s root-token ]; then
  echo "GitLab root token already exists"
else
  printf 'glpat-%s' "$(random 32)" > root-token
  echo "GitLab root token written to secrets/gitlab/root-token"
fi

# GitLab reads both files as the unprivileged git user
chmod 644 root-password root-token
