#!/usr/bin/env bash

# Exit on error:
set -e

# TODO: CAAS-1660: test on Centos 7 and Stream 9

# Setup centos User
bash 1_setup_user.sh

# Update Git Version (only successfully tested for CentOS 7; CentOS 8 had problems with the wandisco repo
bash 2_update-git-centos.sh

# Configure Git credentials
bash 3_configure_git.sh

# Install Docker v18.06.1.ce-3
# --> moved to install install-kubernetes-via-kubadm-on-centos
# source 4_install_docker.sh

# Install JQ and YQ
bash 5_install_jq_and_yq.sh

# Set up aliases (optional for CentOS systems for angular development; not needed in most cases)
#
# source 6_source_set_angular_aliases.sh

# Create iptables rules for a secure connection
bash 7_create_iptables_entries.sh

# Set up cronjobs for updating iptables rules
bash 8_set_cronjobs.sh

# Hardening the machine like no root and password login
bash 9_hardening.sh

# Disable Ipv6 for better connection with git
bash 10_disabling_ipv6.sh

# Increase Watchfile Limit (needed e.g. for angular in watch mode)
bash 11_increasing_watchfile_limit.sh

# Install and enable ntp
bash 12_install_ntp.sh

