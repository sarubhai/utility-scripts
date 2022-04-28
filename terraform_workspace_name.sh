#!/bin/bash
# Name: terraform_workspace_name.sh
# Owner: Saurav Mitra
# Description: Apply or Destroy Terraform resources & Configure OpenVPN Client Profile on local machine for terraform cloud Workspace
# Usage:
# ./terraform_workspace_name.sh apply
# ./terraform_workspace_name.sh destroy

dir=$(pwd)

# Connect to Terraform Cloud Remote State to get run Outputs
terraform_api='https://app.terraform.io/api/v2'
helper_tf_apply_destroy='your-terraform-api-token'
organization_name='your-org-name'
workspace_name='your-workspace-name'

# Get Workspace ID
url=${terraform_api}/organizations/${organization_name}/workspaces/${workspace_name}
response=`curl -s -X GET -H "Authorization: Bearer ${helper_tf_apply_destroy}" ${url}`
workspace_id=`echo ${response} | jq -r '.data.id'`
echo "Workspace ID: ${workspace_id}"

# Function to Check & Wait for Terraform Run Status
status_check() {
    while [ true ]
    do
        url=${terraform_api}/runs/$1
        response=`curl -s -X GET -H "Authorization: Bearer ${helper_tf_apply_destroy}" ${url}`
        status=`echo ${response} | jq -r '.data.attributes.status'`
        # planning/planned/applying/applied
        if [ "${status}" == "$2" ]
        then
            break
        else
            sleep 10
            echo "."
        fi
    done
}

###########
## APPLY ##
###########
apply() {
    # Start a New Apply Plan
    dt_id=`date "+%F|%H:%M:%S"`
    echo "{" > ${dir}/payload.json
    echo "    \"data\": {" >> ${dir}/payload.json
    echo "        \"attributes\": {" >> ${dir}/payload.json
    echo "            \"message\": \"AutoMac-${dt_id}\"" >> ${dir}/payload.json
    echo "        }," >> ${dir}/payload.json
    echo "        \"relationships\": {" >> ${dir}/payload.json
    echo "            \"workspace\": {" >> ${dir}/payload.json
    echo "                \"data\": {" >> ${dir}/payload.json
    echo "                    \"id\": \"${workspace_id}\"" >> ${dir}/payload.json
    echo "                }" >> ${dir}/payload.json
    echo "            }" >> ${dir}/payload.json
    echo "        }" >> ${dir}/payload.json
    echo "    }" >> ${dir}/payload.json
    echo "}" >> ${dir}/payload.json

    url=${terraform_api}/runs
    response=`curl -s -X POST -H "Authorization: Bearer ${helper_tf_apply_destroy}" -H "Content-Type: application/vnd.api+json" ${url} --data @${dir}/payload.json`
    # Get Run ID
    run_id=`echo ${response} | jq -r '.data.id'`
    echo ${run_id}

    # Get Run Detail
    status_check ${run_id} "planned"

    # Apply the Run
    url=${terraform_api}/runs/${run_id}/actions/apply
    response=`curl -s -X POST -H "Authorization: Bearer ${helper_tf_apply_destroy}" -H "Content-Type: application/vnd.api+json" ${url} --data '{"comment":"Confirm Apply"}'`
    echo ${response}

    # Get Run Detail
    status_check ${run_id} "applied"


    # Get Outputs from remote workspace
    url=${terraform_api}/organizations/${organization_name}/workspaces/${workspace_name}?include=outputs
    response=`curl -s -X GET -H "Authorization: Bearer ${helper_tf_apply_destroy}" ${url}`
    # Get OpenVPN Access Server IP
    openvpn_access_server_ip=`echo ${response} | jq -r '.included[] | select(.attributes.name=="openvpn_access_server_url") | .attributes.value'`
    echo ${openvpn_access_server_ip}

    vpn_admin_username='your-openvpn-username'
    vpn_admin_password='your-openvpn-password'
    url=${openvpn_access_server_ip}rest/GetUserlogin
    # Download OpenVPN Client Profile
    curl -s -k -X GET -u ${vpn_admin_username}:${vpn_admin_password} ${url} > ${dir}/${workspace_name}.ovpn
    # Import OpenVPN Client Profile
    /Applications/OpenVPN\ Connect.app/Contents/MacOS/OpenVPN\ Connect --hide-tray --import-profile=${dir}/${workspace_name}.ovpn --name=${workspace_name} --username=${vpn_admin_username} --password=${vpn_admin_password}

    # Cleanup
    rm -rf ${dir}/payload.json
}


#############
## DESTROY ##
#############
destroy() {
    # Remove OpenVPN Client Profile
    /Applications/OpenVPN\ Connect.app/Contents/MacOS/OpenVPN\ Connect --hide-tray --remove-profile=${workspace_name}
    rm -rf ${dir}/${workspace_name}.ovpn

    # Start a New Destroy Plan
    dt_id=`date "+%F|%H:%M:%S"`
    echo "{" > ${dir}/payload.json
    echo "    \"data\": {" >> ${dir}/payload.json
    echo "        \"attributes\": {" >> ${dir}/payload.json
    echo "            \"is-destroy\": true," >> ${dir}/payload.json
    echo "            \"message\": \"AutoMac-${dt_id}\"" >> ${dir}/payload.json
    echo "        }," >> ${dir}/payload.json
    echo "        \"relationships\": {" >> ${dir}/payload.json
    echo "            \"workspace\": {" >> ${dir}/payload.json
    echo "                \"data\": {" >> ${dir}/payload.json
    echo "                    \"id\": \"${workspace_id}\"" >> ${dir}/payload.json
    echo "                }" >> ${dir}/payload.json
    echo "            }" >> ${dir}/payload.json
    echo "        }" >> ${dir}/payload.json
    echo "    }" >> ${dir}/payload.json
    echo "}" >> ${dir}/payload.json

    url=${terraform_api}/runs
    response=`curl -s -X POST -H "Authorization: Bearer ${helper_tf_apply_destroy}" -H "Content-Type: application/vnd.api+json" ${url} --data @${dir}/payload.json`
    # Get Run ID
    run_id=`echo ${response} | jq -r '.data.id'`
    echo ${run_id}

    # Get Run Detail
    status_check ${run_id} "planned"

    # Apply the Run
    url=${terraform_api}/runs/${run_id}/actions/apply
    response=`curl -s -X POST -H "Authorization: Bearer ${helper_tf_apply_destroy}" -H "Content-Type: application/vnd.api+json" ${url} --data '{"comment":"Confirm Apply"}'`
    # echo ${response}

    # Check if Resources Destroyed
    # url=${terraform_api}/workspaces/${workspace_id}
    # response=`curl -s -X GET -H "Authorization: Bearer ${helper_tf_apply_destroy}" ${url}`
    # echo ${response} | jq '.data.attributes.actions'

    # Cleanup
    rm -rf ${dir}/payload.json
}


# Commandline Entry
if [ $# -eq 0 ]; then
    echo "No arguments provided. Must be one of apply or destroy"
    exit 1
elif [ "$1" == "apply" ]; then
    apply
elif [ "$1" == "destroy" ]; then
    destroy
else
    exit 1
fi
