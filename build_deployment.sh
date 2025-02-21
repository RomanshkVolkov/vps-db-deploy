#!/bin/bash

deployment_dir="."

declare -A params=(
  [STACK]=""
  [IMAGE]=""
  [DEPLOY_ROOT_PASSWORD]=""
)

for arg in "$@"; do
  case $arg in
  *=*)
    key="${arg%%=*}"
    value="${arg#*=}"

    if [[ -z "${params[$key]}" ]]; then
      params[$key]="$value"
      if [[ -z "$value" ]]; then
        echo "Missing value for $key"
        exit 1
      fi
    fi
    ;;
  esac
done
# Deploy the stack

yaml_content=$(cat "$deployment_dir/deployment.template.yml")

# exclude envs array strings
declare -A exclude_envs=(
  ["STACK"]=1
)

function replace_env() {
  if [[ -v ${exclude_envs[$1]} ]]; then
    return
  fi

  env_name="${1}_PLACEHOLDER"
  env_value="${2}"

  yaml_content=$(echo "$yaml_content" | sed "s|$env_name|$env_value|g")
}

# raplace all args on the template
for key in "${!params[@]}"; do
  replace_env "$key" "${params[$key]}"
done

stack="${params[STACK]}-${params[DEPLOYMENT_ENVIROMENT]}"
yaml_content=$(echo "$yaml_content" | sed "s|STACK_PLACEHOLDER|$stack|g")

echo "$yaml_content"
