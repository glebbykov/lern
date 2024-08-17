#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

FILE=$1
if [ ! -f $FILE ]; then
    echo "File not found!"
    exit 1
fi

USERNAME=$(sed -n '1p' $FILE)
PASSWORD=$(sed -n '2p' $FILE)

useradd -m -s /bin/bash $USERNAME

echo "$USERNAME:$PASSWORD" | chpasswd

usermod -aG sudo $USERNAME

sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

systemctl restart ssh

echo "'$USERNAME' created and configured with the specified password."
