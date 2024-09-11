# Email Port Connectivity Checker

This script checks the connectivity of common email ports (SMTP, IMAP, POP3) to popular public email servers (Gmail, Outlook, Yahoo). It verifies whether the email ports are open or blocked by an upstream provider, providing a final summary.

## Features
- Tests email-related ports (SMTP, IMAP, POP3) with SSL and non-SSL versions.
- Checks against popular email servers (Gmail, Outlook, Yahoo).
- Provides a final summary, indicating whether each port is blocked or open.

## Tested Email Ports:
- **SMTP**: 25 (non-SSL), 465 (SSL), 587 (submission)
- **IMAP**: 143 (non-SSL), 993 (SSL)
- **POP3**: 110 (non-SSL), 995 (SSL)

## Prerequisites
The script works on Linux systems with either APT or DNF package managers. It requires root privileges for installing required tools.

### Tools Installed by the Script:
- **telnet**: Used to check connectivity over ports.
- **netcat**: Used as an alternative to telnet for port checking.
- **timeout**: Limits how long port checking commands run to prevent hanging.

## Installation

1. **Clone the Repository**:
    ```bash
    git clone https://github.com/yourusername/email-port-checker.git
    ```
   
2. **Navigate to the Directory**:
    ```bash
    cd email-port-checker
    ```

3. **Make the Script Executable**:
    ```bash
    chmod +x email-check.sh
    ```

## Usage

1. **Run the Script**:
    You need to run the script with `sudo` or as root to allow it to install any missing dependencies and check the ports.
    ```bash
    sudo ./email-check.sh
    ```

    The script will:
    - Install `telnet`, `netcat-openbsd`, or `netcat-traditional` (based on the system) and `timeout`.
    - Check email ports (SMTP, IMAP, POP3) on public servers like Gmail, Yahoo, and Outlook.
    - Output a final summary indicating whether each port is open or blocked.

2. **View the Summary**:
    After the script completes, it will provide a summary indicating whether each email port is open or blocked by the upstream provider.

## Example Output

Checking Gmail_SMTP on smtp.gmail.com (Port 25) using telnet with a 5-second timeout...
Gmail_SMTP on smtp.gmail.com: Port 25 is closed or timed out
Checking Gmail_IMAP on imap.gmail.com (Port 993) using nc with a 5-second timeout...
Gmail_IMAP on imap.gmail.com: Port 993 is open

======================================
Summary of Email Port Connectivity Check:
======================================
SMTP_incoming (Port 25): Closed - Port may be blocked by upstream provider
SMTP_SSL (Port 465): Open - Port is not blocked
SMTP_submission (Port 587): Open - Port is not blocked
IMAP (Port 143): Closed - Port may be blocked by upstream provider
IMAP_SSL (Port 993): Open - Port is not blocked
POP3 (Port 110): Closed - Port may be blocked by upstream provider
POP3_SSL (Port 995): Open - Port is not blocked
======================================
Email port check completed.
