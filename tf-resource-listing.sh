#!/bin/bash
# Name: tf-resource-listing.sh
# Owner: Saurav Mitra
# Description: List Terraform resources By Workspace foreach nested directories
# Usage:
# ./tf-resource-listing.sh

# SET VARIABLES
repo="/Users/saurav.mitra/Tech/Terraform/tf-listing"
workspaces=(dev stg pro)

root=`basename ${repo}`
dir=$(pwd)

for d in $(find ${repo} -maxdepth 3 -type d)
do
    dname=`basename ${d}`
    pdname=`basename $(dirname ${d})`
    if [[ ( "${dname}" == "${root}" ) || ( "${pdname}" == "terraform.tfstate.d" ) || ( "${dname}" == "terraform.tfstate.d" ) || ( "${dname}" == ".terraform" ) || ( "${dname}" == "providers" ) ]]
    then
        continue
    else
        echo "Directory- ${d}:"
        cd ${d}
        for ws in "${workspaces[@]}"
        do
            terraform workspace select ${ws}
            if [ $? -ne 0 ]; then
                continue
            fi
            # echo "Workspace- ${ws}:"
            output="${dir}/resources_${ws}.txt"
            echo "ResourcePath: ${d}" >> ${output}
            terraform state list >> ${output}
        done
    fi
done

cd ${dir}
