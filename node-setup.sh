#!/bin/bash
#
# Designed for: Ubuntu Server 22.04 LTS 64-bit on a Raspberry Pi
# Description:  Handles the initial set up common to all nodes for a
#               microK8s cluster
#
# Note:         This script assumes you have already run the initial
#               'sudo apt update && sudo apt upgrade -y' and restarted your
#               machine at least once. If you want to set a hostname for any
#               given node you should do so and restart before executing this
#               script.
#
#
# Aliases available after running:
#
# Alias     | Mapping
# ----------------------------
# 'helm'    |'microk8s helm3'
# 'kubectl' |'microk8s kubectl'

# Update and upgrade the system
sudo apt update && sudo apt upgrade -y

# Enable cgroups by appending to /boot/firmware/cmdline.txt
sudo sed -i '1s/^/cgroup_enable=memory cgroup_memory=1 /' /boot/firmware/cmdline.txt

# Enable port forwarding and make it persistent
sudo iptables -P FORWARD ACCEPT
sudo apt install iptables-persistent -y

# add additional packages for linux so Calico doesn't break later down the line
sudo apt install linux-modules-extra-raspi -y

# Install Docker
sudo apt-get install ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

# Install MicroK8s
sudo snap install microk8s --classic

# Add current user to microK8s group
sudo usermod -aG microk8s $USER
mkdir ~/.kube
sudo chown -f -R $USER ~/.kube
sudo microk8s config > ~/.kube/config
newgrp microk8s

# Add current user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Create useful aliases
alias kubectl="microk8s kubectl"
echo 'alias kubectl="microk8s kubectl"' >> ~/.profile
alias helm="microk8s helm3"
echo 'alias helm="microk8s helm3"' >> ~/.profile

# start MicroK8s
microk8s status --wait-ready

# enable various services for kubernetes
microk8s enable dashboard dns metallb helm3

# end
