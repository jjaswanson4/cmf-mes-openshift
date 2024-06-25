The purpose of this repository is to provide a base for automated installation of the Critical Manufacturing MES on Openshift using Ansible and their shell SDK.

References:
- https://github.com/criticalmanufacturing/portal-sdk

Prerequisits:
- a RHEL helper host with ansible installed
- An openshift cluster accessible from the helper
- Login credentials for https://portal.criticalmanufacturing.com

Start off by copying the examples/values.yml and examples/secrets.yml files to the root of this repository and filling in the values as per the comments in these files.

# Create a login token for the CMF portal:
Log into  https://portal.criticalmanufacturing.com, and navigate to the User Profile page.
In the Access Tokens section, generate a new access token by clicking the "Create" button at the top of this section.
Name it accordingly and set the desired expiration date. 
Ensure that the Scope of the token includes "Applications"

Insert the value of the token into the cmf.auth-token field of the secrets file.


# Setup an MES using the automated agent.
Steps:
## Prepare the host
First steps are to prepare the ansible helper
```
ansible-playbook -vvvi inventory.yml --extra-vars='@extra-vars.yml' playbooks/00-prepare-host.yml
```  


### set CM_PORTAL_TOKEN env 
### Log into Openshift Portal
### Create infrastructure: 
  -- cmf-portal createinfrastructure --name {{ cmf.infrastructure.name }} --customer {{ cmf.customer }} --ignore-if-exists
### deploy agent: 
Only one agent per infrastructure is allowed. If there is already one, ensure that the name matches
  cmf-portal deployagent --name "{{ cmf.agent.name }}" --target {{ cmf.agent.target }} --output {{ workingDir +'/agent' }} --deploymentTimeoutMinutes {{ cmf.agent.deploymentTimeout}} --description {{ cmf.agent.description }} -ci {{ cmf.infrastructure.name }}

//Home install: (cmf-portal deployagent --name 'cmf-infra-agent' --output /home/ansible/MES-install/agent --deploymentTimeoutMinutes 360 -trg OpenShiftOnPremisesTarget --type Development --parameters /home/ansible/ocp_appliance/appliance_assets/MES/Templates/agent.json -ci 'Home SNO')

Rename the deployStackToKubernetes.ps1 to deployStackToKubernetes.sh and add execution permissions

Read the traefik version from workingDir/agent/traefik-deployment.yaml

kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/{{ traefikVersion }}/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml


### pre-check 
cmf-portal checkagentconnection --name {{ cmf.agent.name }}

### Deploy each environment
cmf-portal deploy --name "{{ cmf.environment.name }}" --target {{ cmf.environment.target }} --site {{ cmf.environment.site }} --package {{ cmf.environment.package }} --license {{ cmf.environment.license }} --output {{ workingDir+ '/environments/' + cmf.environment.name }} --deploymentTimeoutMinutes {{ cmf.environment.deploymentTimeout}}