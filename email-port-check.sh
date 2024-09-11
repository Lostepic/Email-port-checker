#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

function install_package_if_needed() {
    local package=$1
    if ! command -v $package &> /dev/null; then
        if command -v apt &> /dev/null; then
            echo "$package not found, installing using apt..."
            apt update
            apt install -y $package
        elif command -v dnf &> /dev/null; then
            echo "$package not found, installing using dnf..."
            dnf install -y $package
        else
            echo "Neither apt nor dnf found. Unsupported package manager."
            exit 1
        fi
    else
        echo "$package is already installed."
    fi
}

install_package_if_needed "telnet"

if ! command -v nc &> /dev/null; then
    if command -v apt &> /dev/null; then
        echo "nc not found, installing netcat-openbsd..."
        apt install -y netcat-openbsd
    else
        echo "nc not found, attempting to install..."
        install_package_if_needed "netcat"
    fi
fi

install_package_if_needed "timeout"

declare -A email_servers=(
    ["Gmail_SMTP"]="smtp.gmail.com"
    ["Gmail_IMAP"]="imap.gmail.com"
    ["Gmail_POP3"]="pop.gmail.com"
    ["Outlook_SMTP"]="smtp.office365.com"
    ["Outlook_IMAP"]="outlook.office365.com"
    ["Outlook_POP3"]="outlook.office365.com"
    ["Yahoo_SMTP"]="smtp.mail.yahoo.com"
    ["Yahoo_IMAP"]="imap.mail.yahoo.com"
    ["Yahoo_POP3"]="pop.mail.yahoo.com"
)

declare -A email_ports=(
    ["SMTP_incoming"]=25
    ["SMTP_SSL"]=465
    ["SMTP_submission"]=587
    ["IMAP"]=143
    ["IMAP_SSL"]=993
    ["POP3"]=110
    ["POP3_SSL"]=995
)

declare -A port_status
for service in "${!email_ports[@]}"; do
    port_status[$service]="closed"
done

function check_port() {
    local server=$1
    local service=$2
    local port=$3
    local timeout_duration=5

    if command -v telnet &> /dev/null; then
        echo "Checking $service on $server (Port $port) using telnet with a $timeout_duration-second timeout..."
        if timeout $timeout_duration bash -c "echo quit | telnet $server $port" 2>/dev/null | grep -q "Connected"; then
            echo "$service on $server: Port $port is open"
            port_status[$service]="open"
        else
            echo "$service on $server: Port $port is closed or timed out"
        fi
    elif command -v nc &> /dev/null; then
        echo "Checking $service on $server (Port $port) using nc with a $timeout_duration-second timeout..."
        if timeout $timeout_duration nc -zv $server $port 2>&1 | grep -q succeeded; then
            echo "$service on $server: Port $port is open"
            port_status[$service]="open"
        else
            echo "$service on $server: Port $port is closed or timed out"
        fi
    else
        echo "Neither telnet nor netcat available for port checking."
        exit 1
    fi
}

echo "Checking email ports for public email servers..."
for service in "${!email_ports[@]}"; do
    port=${email_ports[$service]}
    for server in "${!email_servers[@]}"; do
        check_port "${email_servers[$server]}" "$service" "$port"
    done
done

echo ""
echo "======================================"
echo "Summary of Email Port Connectivity Check:"
echo "======================================"

for service in "${!email_ports[@]}"; do
    if [ "${port_status[$service]}" == "open" ]; then
        echo "$service (Port ${email_ports[$service]}): Open - Port is not blocked"
    else
        echo "$service (Port ${email_ports[$service]}): Closed - Port may be blocked by upstream provider"
    fi
done

echo "======================================"
echo "Email port check completed."
