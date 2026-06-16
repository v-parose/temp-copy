#!/bin/bash

DOTNET_USER=dotnet-bot
HELIX_USER=helix-runner

printf "Enter password for both new accounts: "
read -s USER_PASS
printf "\n"

printf "Enter DDFUN password (for Secure Token grant): "
read -s DDFUN_PASS
printf "\n"

for USER in $DOTNET_USER $HELIX_USER
do
    id "$USER" >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        echo "$USER already exists"
    else
        echo "Creating $USER"
        sudo sysadminctl -addUser "$USER" -password "$USER_PASS" -admin
    fi

    echo "Granting Secure Token to $USER"
    sudo sysadminctl -secureTokenOn "$USER" -password "$USER_PASS" -adminUser DDFUN -adminPassword "$DDFUN_PASS"

    echo "Verifying Secure Token for $USER"
    sysadminctl -secureTokenStatus "$USER"
done

echo "Users created and Secure Token enabled"
echo "Log into helix-runner and run Script 2"