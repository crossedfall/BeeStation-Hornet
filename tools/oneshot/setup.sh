#!/bin/bash

if [ ! -f "./docker-compose.yml" ]; then
    wget -q "https://raw.githubusercontent.com/Crossedfall/BeeStation-Hornet/master/tools/oneshot/docker-compose.yml"
fi

# If the static files directory doesn't exist, create it
if [ ! -d "./StaticFiles" ]; then
    mkdir ./StaticFiles
fi

# Check if config exists, if it doesn't checkout the config from upstream
if [ -d "./StaticFiles/config" ]; then
    echo -e "\e[42mUsing local config\e[0m"
    config_exists=true
else
    config_exists=false
    write_config=true
    echo -e "\e[41mPulling latest config from upstream\e[0m"
    cd ./StaticFiles
    git init
    git remote add origin https://github.com/beestation/beestation-hornet
    git fetch --depth=5
    git config core.sparseCheckout true
    echo "config/" >> .git/info/sparse-checkout
    git pull origin master
    cd ..
    echo -e "\n\e[42mConfig loaded\e[0m\n"
fi

# Check for a schema file, if one isn't found download from upstream
for f in ./*schema.sql; do
    [ -e "$f" ] && echo "\e[42mSchema found. Using\e[0m '$f'" || \
        ( echo -e "\e[41mSchema not found. Downloading from upstream.\e[0m\n" && \
        wget -q "https://raw.githubusercontent.com/BeeStation/BeeStation-Hornet/master/SQL/beestation_schema.sql" )
    break
done

# Build docker image
if [[ "$(docker images -q beestation:latest 2> /dev/null)" == "" ]]; then
    echo -e "\e[41mBuilding docker image\e[0m\n"
    docker build -q --pull --rm -f "Dockerfile" -t beestation https://raw.githubusercontent.com/Crossedfall/BeeStation-Hornet/master/tools/oneshot/Dockerfile
fi

# If check is true, ask the user if they would like the script to setup the db config file
if $config_exists; then
    read -p "Would you like me to setup the dbconfig.txt file?" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
    else
        write_config=true
    fi
fi

if $write_config; then
    cd ./StaticFiles/config
    echo -e \
    "SQL_ENABLED

ADDRESS 172.16.238.10

PORT 3306

FEEDBACK_DATABASE ss13beedb

FEEDBACK_TABLEPREFIX SS13_

FEEDBACK_LOGIN ss13dbuser

FEEDBACK_PASSWORD password1

ASYNC_QUERY_TIMEOUT 10

BLOCKING_QUERY_TIMEOUT 5

BSQL_THREAD_LIMIT 50" > dbconfig.txt
fi

# Compose it up bb
echo -e "Building...\n"
docker-compose up --quiet-pull --force-recreate --no-start
echo -e "====================================="
echo -e "Ready! Use \e[41mdocker-compose up\e[0m to start the service with logging. Use \e[41mdocker-compose up -d\e[0m if you want it to run in the background."
