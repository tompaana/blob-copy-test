#!/bin/bash
set -e

positional_args=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--env)
      env="$2"
      shift
      shift
      ;;
    -m|--meronym)
      resource_name_meronym="$2"
      shift
      shift
      ;;
    -f|--filepath)
      filepath="$2"
      shift
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      positional_args+=("$1")
      shift
      ;;
  esac
done

if [ -z "$env" ]; then
    >&2 echo "Environment (dev/test/prod) missing"
    exit 1
fi

if [ -z "$resource_name_meronym" ]; then
    >&2 echo "Resource name meronym missing"
    exit 1
fi

if [ -z "$filepath" ]; then
    >&2 echo "Filepath missing"
    exit 1
fi

resource_group_name="rg-copytest${resource_name_meronym}-${env}"
storage_account_names=("stctb${resource_name_meronym}${env}westeurope" "stctb${resource_name_meronym}${env}swedencentral")
container_name="copytest"
destination_blob_name="test.txt"

for storage_account_name in "${storage_account_names[@]}"; do
    echo "Uploading file ${filepath} to container ${container_name} in storage account ${storage_account_name}..."

    az storage blob upload \
        --account-name "$storage_account_name" \
        --auth-mode login \
        --container-name "$container_name" \
        --file "$filepath" \
        --name "$destination_blob_name" \
        --overwrite
done

echo "Done"
