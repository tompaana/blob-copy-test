#!/bin/bash
set -e

wait=false
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
    -a|--ip-address)
      ip_address="$2"
      shift
      shift
      ;;
    --wait)
      wait=true
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

if [ -z "$ip_address" ]; then
    ip_address=$(curl ifconfig.me)
fi

if [ -z "$ip_address" ]; then
    >&2 echo "Could not resolve your IP address, please provide it as a parameter"
    exit 1
fi

resource_group_name="rg-copytest${resource_name_meronym}-${env}"
storage_account_names=("stctb${resource_name_meronym}${env}westeurope" "stctb${resource_name_meronym}${env}swedencentral")

for storage_account_name in "${storage_account_names[@]}"; do
    echo "Whitelisting IP address ${ip_address} for ${storage_account_name}..."

    az storage account network-rule add \
        --account-name "$storage_account_name" \
        --action Allow \
        --ip-address "$ip_address" \
        --resource-group "$resource_group_name"
done

if [ "$wait" = true ]; then
    echo "Taking a nap for 30 seconds..."
    sleep 30
fi

echo "Done"
