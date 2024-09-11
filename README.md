The purpose of this repository is to provide a base for automated installation of the Critical Manufacturing MES on Openshift using Ansible and their shell SDK.

References:
- https://github.com/criticalmanufacturing/portal-sdk

# Prerequisits:
- An active Red Hat Enterprise Linux subscription
- Login credentials and an active license for Critical Manufacturing MES - https://portal.criticalmanufacturing.com
- A linux helper with ansible installed
- SHH root access setup to helper, either by means of sshpass, or [passwordless sudo access](https://developers.redhat.com/blog/2018/08/15/how-to-enable-sudo-on-rhel) (remember to copy your ssh id to the helper)
- An openshift cluster accessible from the helper, and a login token for server.
- have ansible-playbook and ansible-galaxy commands available locally, if not, see https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
- CIFS/SMB CSI driver installed- https://docs.openshift.com/container-platform/4.16/storage/container_storage_interface/persistent-storage-csi-smb-cifs.html#:~:text=The%20CIFS%2FSMB%20CSI%20Driver,administrators%20to%20pre%2Dprovision%20storage.
 

# Repository structure
This repo contains several key elements:
## Examples
The example section contains suggestions for the inventory, secrets and values files.
Copy each of these to the cmf-mes-openshift parent directory and complete the correct values according to the comments in each.

For best practices and to prevent accidentally checking in the secrets file, use [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/vault_encrypting_content.html)

```
ansible-vault encrypt secrets.yml
```

Provide a new password and it will be encrypted.
To run any playbooks that make use of these secrets, add the "--ask-vault-pass" tag to use every playbook command

In order to change values, use
```
ansible-vault edit secrets.yml
```

## Playbooks
These are the core playbooks that will be deploying various components needed.
The host, infrastructure, and environment files have been split in order to make it easier to redeploy and update the correct components.

## Tempates
These templates contain the export values from portal.criticalmanufacturing.com and are a suggestion for getting started quickly.
Some templating has been applied, but there are many more configurations that can be applied by changing values within these.

The exact working of each value is beyond the scope of this repo, so please refer to CMF documentations for in-depth details on what each of these do.

# Where to get the PATs (personal access tokens)
## Create a login token for the CMF portal:
Log into  https://portal.criticalmanufacturing.com, and navigate to the User Profile page.
In the Access Tokens section, generate a new access token by clicking the "Create" button at the top of this section.
Name it accordingly and set the desired expiration date. 
Ensure that the Scope of the token includes "Applications"

Insert the value of the token into the cmf_secrets.auth_token field of the secrets file.

##  Openshift login token
In order to get an openshift token, use the web console to retrieve the login command.
Once logged in, click on the username at the top-right corner and select "copy log-in command"
The correct token can then bes een when you click on "Display Token"
It will start with "sha256~xxxxxx"
Copy this value into openshift_login_token in the secrets.yml file,


# Setup an MES using the automated agent
## Prepare the host
First steps are to prepare the ansible environment.
To install all the requirements for the various playbooks used, run the following:
```
ansible-galaxy collection install -r requirements/requirements.yml 
```

Next, we install the Portal SDK packages along with NPM, in order to be able to run the rest of the commands.

```
ansible-playbook -vvi inventory.yml playbooks/00-prepare-host.yml 
```  
TODO - there is an error in the newest NPMs published by CMF. Need to use the direct pull from their git

## create SQL servers on Openshift Virt
In order to create the windows VM on Openshift Virt, the following playbook is available.

```
ansible-playbook -vvvi inventory.yml playbooks/97-deploy-windows-database.yml --ask-vault-pass
```

This will deploy a single windows server vm to Openshift virt.
Currently this server sill requires some manual intervention for further automation to be able to run.
On the windows server, Copy the followying to powershell and run.

```
# ------ scripts to run on windows to enable Ansible. Build into golden image -----
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private; 
Enable-PSRemoting -Force; 
winrm quickconfig -q; 
winrm quickconfig -transport:http; 
winrm set winrm/config '@{MaxTimeoutms="1800000"}'; 
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="800"}'; 
winrm set winrm/config/service '@{AllowUnencrypted="true"}'; 
winrm set winrm/config/service/auth '@{Basic="true"}'; 
winrm set winrm/config/client/auth '@{Basic="true"}'; 
winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port="5985"}'; 
netsh advfirewall firewall set rule group="Windows Remote Administration" new enable=yes; 
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new enable=yes action=allow remoteip=any; 
Set-Service winrm -startuptype "auto"; 
Restart-Service winrm
```


TODO!!!!
Configure the correct storage.
Based on the cluster type and storage operators used, there are various options to be considered at this stage.
The easiest option would be if Openshift Data Foundations are installed with the RWX storage class cephfs available.
Make sure that is setup in the values.yml file.

For Single Node Openshift where only the LVM storage is available, manually create the storage volumes in order to be able to support RWX modes that are required by several of the Critical Manufacturing containers.

## Setting up the SQL database server
The MES running in analysis db mode requires a SQL server database.
Once a connection is available to a Windows host via winrm, the database services and configurations can be applied by running
```
ansible-playbook -vvvi inventory.yml playbooks/98-configure-windows.yml --ask-vault-pass
```
Make sure you can log into the db user spcified. If the SQL install fails, it might be because of Windows magic upon first login

## Create infrastructure and agent: 
The infrastructure agent for each infrastructure will be the part that maintains the MES application installed within it.
Only a single agent is allowed per infrastructure, but it can manage multiple environments.

Fill out the agent section in the values.yml file if you have not already done so.
  
```
ansible-playbook -vvvi inventory.yml playbooks/01-deploy-infrastructure.yml --ask-vault-pass
```


## Deploy each environment

Currently this section will deploy a single environment to the infrastructure defined in the previous steps.
It makes use of the SQL Server hosted within containers so no extended database services like SQL Server Reporting Services, or SQL Server Analysis services will be available when deploying. 

Once the infrastructure agent is up and running on the target Openshift cluster, the environment can be deployed using the "Openshift Remote" target.
What this means is that the yaml manifests are generated by the CMF DevOps portal, and passed to the infrastructure agent, which then does the work of deploying each of these in the correct namespace.

Each subsequent run with the same environment name will generate a new version, and apply the changes.

```
ansible-playbook -vvvi inventory.yml playbooks/02-deploy-environment.yml --ask-vault-pass
```

TODO:
 - update to allow multiple environment deployments simultaneously