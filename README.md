
#THIS IS IN THE TESTING PHASE#

## Install Command
```
mkdir -p /var/lib/vz/snippets && \
cd /var/lib/vz/snippets && \
REPO_URL="https://github.com/ForDefault/automated-proxmox-virtiofs-hook.git" && \
REPO_NAME=$(basename "$REPO_URL" .git) && \
git clone "$REPO_URL" && \
mv "$REPO_NAME"/* . && \
rmdir "$REPO_NAME" && \
chmod +x /var/lib/vz/snippets/virtiofs_alias.sh && \
echo "qmstart() { /var/lib/vz/snippets/virtiofs_alias.sh \"\$@\"; }" >> ~/.bashrc && \
mv /var/lib/vz/snippets/my_vms.json.example /var/lib/vz/snippets/my_vms.json && \
nano /var/lib/vz/snippets/my_vms.json.example && \
source ~/.bashrc
```
# Automated Virtiofsd Hook for Proxmox

## Overview
This project extends the basic functionality of the standard virtiofsd hook for Proxmox.
 - **do not store your paths in the viofshook.conf; as viofshook.conf is remade each launch. Instead use the my_vms.json** 
 - dynamic management of VM filesystems through JSON file. 
 - Automated simplicity for attaching filesystems to VMs( significantly reducing the manual setup and minimizing errors)
### Usage
> Use the normal WebUI to launch when you have made the changes to **my_vms.json**
> > > **IMPORTANT**: default values left unchanged for **my_vms.json** nullify the directory mount 



## Key Files and Configuration


**my_vms.json** - This file is central to configuring the filesystems for your VMs. Make sure to adjust the following fields:

- **VMID**: Replace the placeholder with the actual ID of your VM, ensuring it is enclosed in double quotes. Default value is **102**

- **HostStorage**: Typically set this to **"local"** unless your configuration differs.

- **FolderPaths**: Change **"mypath"** and **"example2"**  to the paths where you want your VMs to access directories.

**If** you used the **Installation Command**, you will be prompted to edit my_vms.json. 
If you did not:
```
nano /var/lib/vz/snippets/my_vms.json
```

### Removing Alias Easily:
The script automatically configures the bash alias to handle filesystem setup through the Proxmox web GUI. 
> If you need to remove this alias for any reason, you can use the following command:
```
sed -i '/qmstart()/d' ~/.bashrc
```

This setup not only automates the filesystem linkage for each VM but also ensures configurations are applied consistently, leveraging the Proxmox environment to its fullest.

## Here's how it works:
- **Alias Setup:** An alias (`qmstart`) is added to your `.bashrc` file. This alias points to the `virtiofs_alias.sh` script. Whenever a `qmstart` command is invoked (mimicking the native Proxmox command to start VMs), the alias triggers the script instead of the original command.

- **JSON Configuration File:** The `my_vms.json` file holds the configurations for each VM, specifying which host storage and folder paths to mount. The script reads this file to determine how to configure the VM's filesystem.

- **Dynamic Configuration:** Upon executing the `qmstart` command, the script dynamically updates the Proxmox VM configurations based on the `my_vms.json` file. It adjusts the VM's setup to include the necessary filesystem mounts as specified in the configuration.

- **Automation through Web GUI:** With the alias in place, changes to the filesystem setup can be made directly through editing the `my_vms.json` file. These changes are then automatically applied the next time the VM is started via the Proxmox web GUI, without needing to manually enter shell commands for each VM.

This mechanism ensures that filesystem configurations are not only easier to manage but also consistently applied, enhancing the usability and flexibility of Proxmox VM management.



=====================================
# Virtiofsd hook for Proxmox
=====================================
Proxmox does not yet natively support adding filesystems to VM via virtiofsd. Instead you can use a script to configure the virtual machine and execute virtiofsd when the VM starts.
## Preparation
* Download the hook script and the config file to a snippet directory within your configured storage
* Make the hook script executable (chmod +x viofshook)
* Adjust the config file to include the directories you want to attach to your VM. A sample file is provided. Remove the sample extension and adjust according to your needs
## VM setup
Execute

    qm set {VMID} --hookscript {STORAGE}:snippets/viofshook

    viofshook {VMID} install
and replace `{VMID}` with the ID of your virtual machine and `{STORAGE}` with the name of your storage (e.g. local)

This enures that the virtiofs daemon is executed when the VM starts and that required parameters are added to the VM config. The second step cannot happen when the script is called from PVE, as the VM configuration is locked at this stage. You will also have to repeat the second command when changing memory size or shares for the VM.

Once your VM is running, you can mount your shares.
## Config file syntax
    vmid:tag1=directory1,tag2=directory2, ...
## Caveats
* This script will override all `args:` settings. Any manual changes will be overwritten when running the install routine
* Online migrations are not yet supported.
