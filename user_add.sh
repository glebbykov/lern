#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

# Assign the arguments to variables
USERNAME=$1
PASSWORD=$2

useradd -m -s /bin/bash $USERNAME

echo "$USERNAME:$PASSWORD" | chpasswd

usermod -aG sudo $USERNAME

sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

systemctl restart ssh

echo "'$USERNAME' created and configured with the specified password."
