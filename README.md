# CS.80 : Big Data and Microcontrollers

## Requirements
Hardware:
- 1 x Raspberry Pi 4 4GB+ RAM for primary node
- n x Raspberry Pi 3b/4 1GB+ RAM for worker nodes
- n + 1 x 32GB+ microSD cards for primary storage on nodes
- 1 x Router or Switch with n+2 capacity for all nodes and internet access.

note: this project is replicable on any arm64 or x86-64 based systems with sufficient memory (e.g. more than 1 GB).

Software:
- Ubuntu Server 22.04 LTS, or another arm64 compatible OS.
- Canonical's MicroK8s
- JupyterHub
- Apache Spark
- Helm3

User:
- Comfortable using the linux terminal.

## Replication Guide

### Creating an [Apache Spark](https://spark.apache.org/) Cluster with Raspberry Pis

The objective of this document is to provide a detailed walkthrough of installing a kubernetes cluster onto networked Raspberry Pi units to function as a learning environment for Kubernetes.

By the end of this tutorial you will have a Kubernetes cluster via Canonical's MicroK8s. Additionally you should finish this with sufficient base knowledge of the tools involved to troubleshoot issues and continue onto more advanced topics some of which are available at the end of the this document .

### TL;DR
If you have several Raspberry Pi 4 units with 64-bit Ubuntu Server 22.04 LTS running on each and you don't want to read the entire tutorial you can run `node-setup.sh` on each unit, and then connect your leaf nodes to the master nodes via `microk8s add-node`, and skip to setting up JupyterHub and Spark.

### Node Hardware Requirements
* Recommended: `Raspberry Pi 4 w/ 8GB RAM`
* Minimum: `Raspberry Pi 3B`

While inexpensive units like the Raspberry Pi Zero W are appealing to utilize as cheap worker nodes they simply lack sufficient RAM and computing power to be more than a waste of your time. If you choose to utilize non Pi 3B/4 hardware you want to make sure you have a minimum of 1GB of RAM. Additionally, it is not recommended to use a USB drive as your primary storage.

### Operating System
Any Linux based OS with ARM64 support will likely suffice, however, we utilized `64-bit Ubuntu Server 22.04 LTS` and this document assumes you are using it through SSH as a sudoer.

If you want to install a compatible operating system the easiest method is via the [Raspberry Pi Image](https://www.raspberrypi.com/software/) which offers the ability to flash a storage device with a range of Raspberry Pi operating systems including the same version of Ubuntu Server as utilized within this tutorial. Just note that if you pursue this method you will need to create a file named "ssh" on the boot portion of the storage device or SSH will be inaccessible.

To check if a currently installed OS will suffice you can execute the following command:
```
  $ uname -m
  - aarch64
```

Where the `aarch64` reflects OS support for 64-bit ARM systems.

## Kubernetes through MicroK8s
[MicroK8s](https://microk8s.io/) is Canonical's light-weight distribution of Kubernetes, designed to get users up and running quickly and easily. They tout it as having the [lowest-memory footprint](https://ubuntu.com/blog/microk8s-memory-optimisation) implementation of K8s, making it particularly attractive for use on Raspberry Pis.

It is important to note that MicroK8s is designed for a development environment and **not** as a production Kubernetes implementation.

### Setting Up Your nodes

For each Raspberry Pi you wish to use as a node in the cluster proceed with the following steps
#### Update Ubuntu

```
$ sudo apt update && sudo apt upgrade -y
```

#### Adding Node Hostnames
Changing the hostname of your nodes from the default 'ubuntu' is recommened, and likely to save some minor headaches. To change a node's hostname simply do the following:
1. edit /etc/hostname

   As /etc/hostname typically only stores one string which represents the hostname the following command is a quick way to edit without messing around in nano/vim/text editor of your choice
   ```
   $ sudo sed -i 's/ubuntu/{new_hostname}/' /etc/hostname
   ```
    confirm the change with
    ```
    $ cat /etc/hostname
    ```

2. edit /etc/hosts

    If any instance of the old hostname exists replace with the new one

3. Reboot
    ```
    $ sudo reboot now
    ```
#### Install extra linux modules for Raspberry Pis
Some Kubernetes services will run into continuous failures without these modules.

  ```
    $ sudo apt install linux-modules-extra-raspi -y
  ```

#### Enable [cgroups](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/resource_management_guide/ch01)
Check if you need to enable cgroups:  

```
$ grep cgroup /boot/firmware/cmdline.txt
```

If grep returns nothing try the following:
```
$ sudo sed -i '1s/^/cgroup_enable=memory cgroup_memory=1 /' /boot/firmware/cmdline.txt
```
Then try grep again, which should result in something similar to the following:
```
$ grep cgroup /boot/firmware/cmdline.txt`
- cgroup_enable=memory cgroup_memory=1 elevator=deadline net.ifnames=0 console=serial0,115200 dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fixrtc quiet splash
```
If that does not work open `/boot/firmware/cmdline.txt` in your preferred text editor and add `cgroup_enable=memory cgroup_memory=1` manually.

#### Install MicroK8s and Docker
Installing MicroK8s:
```
$ sudo snap install microk8s --classic
```
Enable forwarding with IPTables and make it persistent:
```
$ sudo iptables -P FORWARD ACCEPT
$ sudo apt install iptables-persistent -y
```
Installing Docker:
```
$ sudo apt-get install ca-certificates curl gnupg lsb-release
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
$ echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
$ sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
```
#### Add user to MicroK8s group
You can skip this step if you're fine with prefacing everything with `sudo`
```
$ sudo usermod -a -G microk8s $USER
$ sudo chown -f -R $USER ~/.kube
$ mkdir ~/.kube
$ sudo microk8s config > ~/.kube/config
$ newgrp microk8s
```
`$USER` is typically an automatically defined environment variable, but if it's not defined on your system you can substitute in your user name or set the variable yourself with `export USER=<username>`.
#### Start MicroK8s
```
$ microk8s status --wait-ready
```

### Composing the Cluster
Choose one node to be the master node, preferably your most powerful node. For each leaf node you wish to add to the cluster do the following:

On the Master node run:
```
$ microk8s add-node
```
This generates the a unique connection string for a leaf node of the following form `{master_ip}:{port}/{token}`
Additionally, microk8s will return a fully formed command to use on your leaf node like:
`microk8s join 1.2.3.4:25000/5794860a071f6eda231162bba2574f28/68a5897a0373 --worker`

To complete adding the leaf node to the cluster simply run the provided command on the leaf node.

If you run into an error similar to the following:
```
- Connection failed. The hostname (pi3) of the joining node does not resolve to the IP "192.168.0.102". Refusing join (400).
```

Add the ip and hostname of the target worker node to the main node's `/etc/hosts`. For example if you have a primary node `primary` and a worker node `worker1` that returns the dns error when attempting to join the microk8s cluster you would edit the `/etc/hosts` file on `primary` and add the following line:

```
<ip to worker1> worker1
```

Once a node has been added to the cluster you can run the following command on the master node to view the current state of the cluster:
```
$ microk8s kubectl get node
```

Now that we've got our leaf nodes added to the cluster we can configure services we may need. It's safe to assume that all following commands will be executed on the master node unless otherwise stated.

## Running JupyterHub and Apache Spark on Kubernetes

From here on out we'll be working exclusively with the primary node, so you don't need to worry about messing about with any more leaf nodes.

#### MicroK8s Addons
For this we're going to need several addons that you may not have enable earlier:
```
$ microk8s enable dns metallb helm3
```

Why do we need these addons?

- Helm3: we're going to install JupyterHub and Spark via a Helm chart.
- metallb: To assign IPs to make Jupyter accessible outside the cluster
- dns: pretty much everything you want to do with kubernetes is going to rely on having this.

for metallb you will need to specify a range of ip addresses that you want it to assign services to. I used the range `192.168.0.110:192.168.0.120` for testing this.

#### Create Aliases for `helm` and `kubectl`
```
$ alias helm="microk8s helm3"
$ alias kubectl="microk8s kubectl"
```
Save your alias beyond a single bash instance
```
$ echo 'alias helm="microk8s helm3"' >> ~/.bash_aliases
$ echo 'alias kubectl="microk8s kubectl"' >> ~/.bash_aliases
```
If you don't want to use `.bash_aliases` you can also save the aliases in `.bashrc` or `.profile`.

### Install Jupyter Hub and Spark
#### Add the JupyterHub Repo to Helm
```
$ microk8s helm3 repo add jupyterhub https://jupyterhub.github.io/helm-chart/
$ microk8s helm3 repo update
```

#### Create a config.yaml for JupyterHub

The simplest configuration for JupyterHub for our purposes is as follows:
```
# JupyterHub with PySpark Config
#
# Chart config reference:   https://zero-to-jupyterhub.readthedocs.io/en/stable/resources/reference.html
# Chart default values:     https://github.com/jupyterhub/zero-to-jupyterhub-k8s/blob/HEAD/jupyterhub/values.yaml
# Available chart versions: https://jupyterhub.github.io/helm-chart/
#
singleuser:
  image:
    # You may want to replace the "latest" tag with a fixed version from:
    # https://hub.docker.com/r/jupyter/pyspark-notebook
    name: jupyter/pyspark-notebook
    tag: latest
```

Then all that's left is to have helm get it installed for us. Here is an example that creates a helm release named `jupyter-pyspark` running in the `default` namespace on Kubernetes.
```
microk8s helm3 upgrade --cleanup-on-fail \
  --install jupyter-pyspark jupyterhub/jupyterhub \
  --namespace default \
  --version=1.2.0 \
  --values config.yaml
```

Once the installation is complete you can check on the status of the hub and proxy pods in kubernetes:
```
$ microk8s kubectl get pods --namespace=default
```

And after a few minutes or so we can check on the publicly accessible IP assigned to JupyterHub by metallb:
```
$ microk8s kubectl -n default get svc proxy-public -o jsonpath='{.status.loadBalancer.ingress[].ip}'
```

Note: that without additional configuration you'll need to access JupyterHub via http not https.

## You're good to go!
Barring any hiccups in the process described above you should now have a connectable instance of JupyterHub running along with access to client mode spark. To test that everything is functioning well navigate to JupyterHub, in my case it is located at `192.168.0.110`

You should arrive at a dummy JupyterHub log in screen, simply log in with any username/password.

Once logged in and your JupyterLab instance has started open a notebook and input the following:
```
import random
from pyspark.sql import SparkSession

# Spark session & context
spark = SparkSession.builder.master("local").getOrCreate()
sc = spark.sparkContext

# Sum of the first 100 whole numbers
rdd = sc.parallelize(range(100 + 1))
rdd.sum()
```

and then run the cell(s).

If you encounter a module error where IPyKernel doesn't acknowledge the PySpark module, wait a couple minutes and then try to run the cell(s) again. If impatient you can put
```
help('modules')
```
into a new cell, run it and examine the resulting list for pyspark, if it's not there even after waiting for awhile examine the `config.yaml` you used to set up JupyterHub with and make sure it is pulling the `jupyter/pyspark-notebook` image.

### Other Useful Information

#### Inspect your MicroK8s Setup
If you encounter any issues with the k8s system you can run:
```
$ microk8s inspect
```
which will generate a report of issues and warnings which will give you a good jump off point for getting everything running.

#### Resetting MicroK8s
In the event you reach a point where you want a fresh start with the K8s cluster on each node run
```
$ microk8s leave
```
which will remove the node from the cluster, and then finally on your master node:
```
$ microk8s reset
```
which will reset microk8s back to a fresh install state. However this may not change your kube config, so remember to run:
```
$ microk8s config > ~/.kube/config
```
Or you can run into issues with microk8s starting up again.

## Unrealized Features and possible new projects
- Simplified Spark container build and deploy system to leverage entire cluster instead of just client-mode Spark.
- User Authentication to access cluster services.
- Custom OS images to simplify set up further
