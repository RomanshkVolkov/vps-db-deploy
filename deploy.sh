#!/bin/bash

# colors
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Deploy the stack
file="auto-deploy-db.yml"
selected_image=""
PORT_CONTAINER=""
VOLUME_CONTAINER=""

function validateImages() {
  case $1 in
  "mongo")
    selected_image="mongo:latest"
    PORT_CONTAINER=27017
    VOLUME_CONTAINER="/data/db"
    ;;
  "postgres")
    selected_image="postgres:latest"
    PORT_CONTAINER=5432
    VOLUME_CONTAINER="/var/lib/postgresql/data"
    ;;
  "sqlserver")
    selected_image="mcr.microsoft.com/mssql/server:latest"
    PORT_CONTAINER=1433
    VOLUME_CONTAINER="/var/opt/mssql/data"
    ;;
  "mysql")
    selected_image="mysql:latest"
    PORT_CONTAINER=3306
    VOLUME_CONTAINER="/var/lib/mysql"
    ;;
  "mariadb")
    selected_image="mariadb:latest"
    PORT_CONTAINER=3306
    VOLUME_CONTAINER="/var/lib/mysql"
    ;;
  esac

  if [ -z $selected_image ]; then
    errorMessage "Invalid image"
    helpMenu
    exit 1
  fi

  message "Selected image -> $selected_image"
}

function message() {
  echo -e "${yellowColour}[*]${endColour}${grayColour} $1${endColour}"
}

function errorMessage() {
  echo -e "${redColour}[x] ${endColour} ${grayColour}$1${endColour}"
}

function helpMenu() {
  echo ""
  echo -e "${yellowColour}[*]${endColour}${grayColour} Help Menu${endColour}"
  echo -e "${yellowColour}[*]${endColour}${grayColour} Usage: $0 -i <mysql|sqlserver|mariadb|postgres|mongo> -t <target> -p <port> -s <op_password_reference> -e <enviroment>${endColour}"
  echo -e "${yellowColour}[*]${endColour}${grayColour} Example: $0 -i mysql -t 0.0.0.0 -p 1027 -s op://<1password_reference> -e test${endColour}"
}

function removeFile() {
  message "Removing file $1"
  sleep 2
  rm $1
}

validateExistFile() {
  if [ ! -f $file ]; then
    errorMessage "File not found"
    exit 1
  else
    message "File created successfully"
  fi
}

function runDeploy() {
  clear
  message "Deploying stack $selected_image on $target:$port"

  validateImages $image

  if ! command -v op &>/dev/null; then
    errorMessage "op command not found. Please install and configure 1Password CLI."
    exit 1
  fi

  sleep 1
  message "Getting password from 1Password..."
  message "Reference -> $op_password_reference"

  db_password="$(op read "$op_password_reference")"
  ./build_deployment.sh STACK="$image-vps" \
    IMAGE="$selected_image" \
    DEPLOYMENT_ENVIRONMENT="$enviroment" \
    DEPLOY_ROOT_USERNAME="root" \
    DEPLOY_ROOT_PASSWORD="$db_password" \
    PORT_CONTAINER="$PORT_CONTAINER" \
    PORT="$port" \
    VOLUME_CONTAINER="$VOLUME_CONTAINER" \
    VOLUME="$image-$enviroment" \
    >$file

  message "Validating created file..."
  sleep 2

  validateExistFile $file
  user="deploy"
  vol_dir="/home/deploy/database/$image-$enviroment"

  message "Creating directory on target..."
  ssh -o StrictHostKeyChecking=no -p 22 $user@${target} "mkdir -p $vol_dir"

  if [ "$image" == "sqlserver" ]; then
    message "Adjusting directory permissions..."
    # Desde 2019, se ejecuta como el usuario mssql (UID 10001)
    ssh -o StrictHostKeyChecking=no -p 22 $user@${target} "chown -R 10001:0 $vol_dir"
  fi

  message "Copying build template to target..."
  scp -o StrictHostKeyChecking=no -P 22 $file root@${target}:/tmp/$file

  message "Deploying stack..."
  ssh -o StrictHostKeyChecking=no -p 22 root@${target} "docker stack deploy -c "/tmp/$file" "$image-$enviroment""

 < message "Removing file from target..."
  ssh -o StrictHostKeyChecking=no -p 22 root@${target} "rm /tmp/$file"

  message "Stack deployed successfully"
}

declare -i parameter_counter=0
while getopts "i:t:p:s:e:" arg; do
  case $arg in
  i)
    image=$OPTARG
    let parameter_counter+=1
    ;;
  t)
    target=$OPTARG
    let parameter_counter+=1
    ;;
  p)
    port=$OPTARG
    let parameter_counter+=1
    ;;
  s)
    op_password_reference=$OPTARG
    let parameter_counter+=1
    ;;
  e)
    enviroment="$OPTARG"
    let parameter_counter+=1
    ;;
  esac
done

if [ $parameter_counter -ne 5 ]; then
  errorMessage "Invalid number of parameters"
  sleep 2
  helpMenu
  exit 1
fi

runDeploy
removeFile $file
