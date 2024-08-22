# What is 

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


## Create infrastructure and agent: 
The infrastructure agent for each infrastructure will be the part that maintains the MES application installed within it.
Only a single agent is allowed per infrastructure, but it can manage multiple environments.

Fill out the agent section in the values.yml file if you have not already done so.
  
```
ansible-playbook -vvvi inventory.yml playbooks/01-deploy-infrastructure.yml --ask-vault-pass
```

## create SQL servers on Openshift Virt
In order to create the windows VM on Openshift Virt, the following playbook is available.

```
ansible-playbook -vvvi inventory.yml playbooks/02-deploy-environment.yml --ask-vault-pass
```

This will deploy a single windows server vm to Openshift virt.

TODO: configure the database services.

log into windows server and run in powershell
```
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
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
 - incorporate the terminateOtherVersions commands
 - implement "Openshift Manual" target deployment