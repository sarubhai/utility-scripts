#!/bin/bash
# Name: vault_kv_to_secrets_manager_migration.sh
# Owner: Saurav Mitra
# Description: Migrate Vault KV Secrets to AWS Secrets Manager

START_TIME=`date "+%F | %H:%M:%S"`

#~~~~~~~~~~~~#
# Vault Config
#~~~~~~~~~~~~#
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='hvs.cQNycaoHXRKhNFoShYk.....'

# cURL Headers
export VAULT_API="${VAULT_ADDR}/v1"
declare -a VAULT_HEADER=('-H' "Content-Type:application/json" '-H' "X-Vault-Token:${VAULT_TOKEN}")

# Recursive function to list all secret path values for KV Version 1
function get_kv1 {
    local -r KEY_PATH="$1"
    
    # List Secrets
    KEY_LIST=`curl -s "${VAULT_HEADER[@]}" -X LIST "${VAULT_API}/${KEY_PATH}" | jq ".data.keys"`
    
    if [ "$KEY_LIST" == "null" ]; then return; fi

    for KEY in $(echo "${KEY_LIST}" | jq -r ".[]")
    do
        if [[ "${KEY}" == */ ]]; then
            get_kv1 "${KEY_PATH}${KEY}"
        else
            # Read Secret Value
            echo "Key: ${KEY_PATH}${KEY}"
            KEY_VALUE=`curl -s "${VAULT_HEADER[@]}" -X GET "${VAULT_API}/${KEY_PATH}${KEY}" | jq ".data"`
            echo "${KEY_VALUE}"
        fi
    done
}

# Recursive function to list all secret path values for KV Version 2
function get_kv2 {
    local -r KEY_PATH="$1"
    
    # List Secrets
    KEY_METADATA_PATH=`echo "${KEY_PATH}" | sed -e "s|/|/metadata/|"`
    KEY_LIST=`curl -s "${VAULT_HEADER[@]}" -X LIST "${VAULT_API}/${KEY_METADATA_PATH}" | jq ".data.keys"`
    
    if [ "$KEY_LIST" == "null" ]; then return; fi

    for KEY in $(echo "${KEY_LIST}" | jq -r ".[]")
    do
        if [[ "${KEY}" == */ ]]; then
            get_kv2 "${KEY_PATH}${KEY}"
        else
            # Read Secret Value
            echo "Key: ${KEY_PATH}${KEY}"
            KEY_DATA_PATH=`echo "${KEY_PATH}${KEY}" | sed -e "s|/|/data/|"`
            KEY_VALUE=`curl -s "${VAULT_HEADER[@]}" -X GET "${VAULT_API}/${KEY_DATA_PATH}" | jq ".data.data"`
            echo "${KEY_VALUE}"
        fi
    done
}


# List Mounted Secrets Engines
SECRETS=`curl -s "${VAULT_HEADER[@]}" -X GET "${VAULT_API}/sys/mounts" | jq`
SECRET_COUNT=`echo ${SECRETS} | jq ".data | length"`
echo "Total Number of Secret Engines: ${SECRET_COUNT}"

DATA=`echo ${SECRETS} | jq ".data"`


# Get KV Secrets Engines
KV_SECRETS=`echo ${DATA} | jq '[keys[] as $k | select(.[$k].type | contains("kv")) | "\($k)|\(.[$k].options.version)"]'`
KV_COUNT=`echo ${KV_SECRETS} | jq "length"`
echo "Total Number of KV Secret Engines: ${KV_COUNT}"

for (( i=0; i<${KV_COUNT}; i++ ))
do
    KV_SECRET=`echo ${KV_SECRETS} | jq -r ".[${i}]"`
    IFS='|' read -r -a KV_PROP <<< "${KV_SECRET}"
    SECRET=`echo "${KV_PROP[0]}"`
    TYPE=`echo "${KV_PROP[1]}"`
    echo -e "\nKV Version${TYPE} Secret Engine Mount Path `expr ${i} + 1`: ${SECRET}"

    if [[ "${TYPE}" == 1 ]]; then
        get_kv1 ${SECRET}
    else
        get_kv2 ${SECRET}
    fi
done


END_TIME=`date "+%F | %H:%M:%S"`
echo -e "\nStart: ${START_TIME}"
echo "End  : ${END_TIME}"


: '
# Sample KV Secret Generation
vault secrets enable -path=kv2 -version=2 kv
vault kv put kv2/key1 hello1=world1
vault kv put kv2/p1/p2/p3/key2 hello2=world2
vault kv put kv2/p1/p2/p3/p4/key3 hello3=world3
vault kv put kv2/p5/key4 hello4=world4
vault kv put kv2/p5/p6/key5 hello5=world5


vault secrets enable -path=kv1 -version=1 kv
vault kv put kv1/key1 hello1=world1
vault kv put kv1/p1/p2/p3/key2 hello2=world2
vault kv put kv1/p1/p2/p3/p4/key3 hello3=world3
vault kv put kv1/p5/key4 hello4=world4
vault kv put kv1/p5/p6/key5 hello5=world5
'
