#!/bin/bash

# Check if the user is root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root or with sudo."
    exit 1
fi

# Function to check if a package is installed
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
        elif command -v yum &> /dev/null; then
            echo "$package not found, installing using yum..."
            yum install -y $package
        else
            echo "Unsupported package manager."
            exit 1
        fi
    else
        echo "$package is already installed."
    fi
}

# Install necessary tools (telnet, netcat for port checking, and timeout)
install_package_if_needed "telnet"
install_package_if_needed "curl"

# Check for netcat availability and install the correct version
if ! command -v nc &> /dev/null; then
    if command -v apt &> /dev/null; then
        echo "nc not found, installing netcat-openbsd..."
        apt install -y netcat-openbsd
    elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
        install_package_if_needed "nc"
    fi
fi

install_package_if_needed "timeout"

# Get the public IP addresses of the machine
ipv4_address=$(curl -4 -s ifconfig.me)
ipv6_address=$(curl -6 -s ifconfig.me)

# Detect if the machine has IPv4 and/or IPv6 connectivity
has_ipv4_connectivity=false
has_ipv6_connectivity=false

if ping -c 1 -4 google.com &> /dev/null; then
    has_ipv4_connectivity=true
fi

if ping -c 1 -6 google.com &> /dev/null; then
    has_ipv6_connectivity=true
fi

# Define common public email servers and their ports
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

# Declare dictionaries to store results for both IPv4 and IPv6
declare -A port_status_ipv4
declare -A port_status_ipv6
declare -A failed_ports_ipv4
declare -A failed_ports_ipv6

# Initialize port status to "closed" by default
for service in "${!email_ports[@]}"; do
    port_status_ipv4[$service]="closed"
    port_status_ipv6[$service]="closed"
done

# Function to check if a port is open on a public server with a timeout
function check_port() {
    local server=$1
    local service=$2
    local port=$3
    local protocol=$4  # "IPv4" or "IPv6"
    local timeout_duration=5  # Timeout duration in seconds
    local flags=""  # netcat flags for ipv4 or ipv6

    if [ "$protocol" == "IPv6" ]; then
        flags="-6"
    fi

    echo "Checking $server on port $port over $protocol..."

    # Check for open ports using telnet or netcat with a timeout
    if command -v telnet &> /dev/null; then
        if timeout $timeout_duration bash -c "echo quit | telnet $server $port" 2>/dev/null | grep -q "Connected"; then
            if [ "$protocol" == "IPv4" ]; then
                port_status_ipv4[$service]="open"
            else
                port_status_ipv6[$service]="open"
            fi
        else
            if [ "$protocol" == "IPv4" ]; then
                failed_ports_ipv4["$service"]="${failed_ports_ipv4[$service]} $server:$port"
            else
                failed_ports_ipv6["$service"]="${failed_ports_ipv6[$service]} $server:$port"
            fi
        fi
    elif command -v nc &> /dev/null; then
        if timeout $timeout_duration nc $flags -zv $server $port 2>&1 | grep -q succeeded; then
            if [ "$protocol" == "IPv4" ]; then
                port_status_ipv4[$service]="open"
            else
                port_status_ipv6[$service]="open"
            fi
        else
            if [ "$protocol" == "IPv4" ]; then
                failed_ports_ipv4["$service"]="${failed_ports_ipv4[$service]} $server:$port"
            else
                failed_ports_ipv6["$service"]="${failed_ports_ipv6[$service]} $server:$port"
            fi
        fi
    fi
}

# Output minimal information during the check
echo "Running checks... Please wait, this may take a few minutes."

# Check all email-related ports for public email servers for both IPv4 and IPv6
if [ "$has_ipv4_connectivity" == true ]; then
    echo "IPv4 connectivity detected. Testing ports over IPv4."
    for service in "${!email_ports[@]}"; do
        port=${email_ports[$service]}
        for server in "${!email_servers[@]}"; do
            check_port "${email_servers[$server]}" "$service" "$port" "IPv4"
        done
    done
else
    echo "No IPv4 connectivity detected."
fi

if [ "$has_ipv6_connectivity" == true ]; then
    echo "IPv6 connectivity detected. Testing ports over IPv6."
    for service in "${!email_ports[@]}"; do
        port=${email_ports[$service]}
        for server in "${!email_servers[@]}"; do
            check_port "${email_servers[$server]}" "$service" "$port" "IPv6"
        done
    done
else
    echo "No IPv6 connectivity detected."
fi

# Output detailed summary
echo ""
echo "======================================"
echo "Summary of Email Port Connectivity Check:"
echo "======================================"
echo "Local machine public IP addresses used for testing:"
if [ -n "$ipv4_address" ]; then
    echo "IPv4: $ipv4_address"
else
    echo "IPv4: No public address detected"
fi
if [ -n "$ipv6_address" ]; then
    echo "IPv6: $ipv6_address"
else
    echo "IPv6: No public address detected"
fi

echo ""
echo "IPv4 Results:"
if [ "$has_ipv4_connectivity" == true ]; then
    for service in "${!email_ports[@]}"; do
        if [ "${port_status_ipv4[$service]}" == "open" ]; then
            echo "$service (Port ${email_ports[$service]}): Open - IPv4"
        else
            echo "$service (Port ${email_ports[$service]}): Closed - IPv4"
            if [ "${failed_ports_ipv4[$service]}" ]; then
                echo "  -> Failed on: ${failed_ports_ipv4[$service]}"
            fi
        fi
    done
else
    echo "IPv4 tests skipped due to lack of connectivity."
fi

echo "--------------------------------------"
echo "IPv6 Results:"
if [ "$has_ipv6_connectivity" == true ]; then
    for service in "${!email_ports[@]}"; do
        if [ "${port_status_ipv6[$service]}" == "open" ]; then
            echo "$service (Port ${email_ports[$service]}): Open - IPv6"
        else
            echo "$service (Port ${email_ports[$service]}): Closed - IPv6"
            if [ "${failed_ports_ipv6[$service]}" ]; then
                echo "  -> Failed on: ${failed_ports_ipv6[$service]}"
            fi
        fi
    done
else
    echo "IPv6 tests skipped due to lack of connectivity."
fi
echo "======================================"
echo "Email port check completed."

# Display failed ports summary if any failures
if [ ${#failed_ports_ipv4[@]} -ne 0 ] || [ ${#failed_ports_ipv6[@]} -ne 0 ]; then
    echo ""
    echo "======================================"
    echo "Failed Port Checks Summary:"
    echo "======================================"

    if [ ${#failed_ports_ipv4[@]} -ne 0 ]; then
        echo "Failed IPv4 Ports:"
        for service in "${!failed_ports_ipv4[@]}"; do
            echo "$service: ${failed_ports_ipv4[$service]}"
        done
    else
        echo "All IPv4 ports passed."
    fi

    if [ ${#failed_ports_ipv6[@]} -ne 0 ]; then
        echo "Failed IPv6 Ports:"
        for service in "${!failed_ports_ipv6[@]}"; do
            echo "$service: ${failed_ports_ipv6[$service]}"
        done
    else
        echo "All IPv6 ports passed."
    fi

    echo "======================================"
fi

echo "All checks completed."
