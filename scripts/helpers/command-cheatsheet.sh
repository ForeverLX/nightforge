#!/bin/bash
# Command Cheatsheet - Offensive Security Tools
# Quick reference for common commands

while true; do
    SELECTION=$(cat << 'EOF' | fuzzel --dmenu --prompt "Command Cheatsheet:" --width 100
📡 RECON - Subdomain Enumeration
🔍 RECON - Port Scanning  
🌐 RECON - HTTP Probing
📂 RECON - Content Discovery
🔧 RECON - Technology Detection
💉 WEB - SQL Injection
⚡ WEB - XSS Testing
📁 WEB - Directory Fuzzing
🎫 AD - Kerberoasting
🩸 AD - BloodHound
🐳 TOOLS - Container Commands
📝 TOOLS - Git Commands
📋 SYSTEM - File Operations
🌍 SYSTEM - Network Analysis
❌ Exit Cheatsheet
EOF
    )

    [ -z "$SELECTION" ] && exit 0
    [[ "$SELECTION" =~ "Exit" ]] && exit 0

    case "$SELECTION" in
        *"Subdomain Enumeration"*)
            CONTENT='=== SUBDOMAIN ENUMERATION ===

Amass (Passive):
  amass enum -d target.com -passive -o subs.txt

Amass (Active):
  amass enum -d target.com -active -o subs.txt

Amass (Deep):
  amass enum -d target.com -active -brute -o subs.txt

DNS Resolution:
  cat subs.txt | dnsx -a -resp -o resolved.txt

Extract IPs:
  cat resolved.txt | cut -d " " -f2 | sort -u'
            ;;
        
        *"Port Scanning"*)
            CONTENT='=== PORT SCANNING ===

Naabu (Fast):
  naabu -host target.com -top-ports 1000

Naabu (All Ports):
  naabu -host target.com -p -

Naabu (Custom Ports):
  naabu -host target.com -p "80,443,8080,8443"

RustScan + Nmap:
  rustscan -a target.com -- -sV -sC

Nmap (Service Detection):
  nmap -sV -sC -p 80,443 target.com

Nmap (All Ports):
  nmap -p- target.com'
            ;;
        
        *"HTTP Probing"*)
            CONTENT='=== HTTP PROBING ===

httpx (Basic):
  cat hosts.txt | httpx

httpx (Tech Detection):
  cat hosts.txt | httpx -tech-detect

httpx (Full Info):
  cat hosts.txt | httpx -status-code -title -tech-detect -json -o results.json

Extract URLs:
  jq -r ".url" results.json'
            ;;
        
        *"Content Discovery"*)
            CONTENT='=== CONTENT DISCOVERY ===

ffuf (Directory Fuzzing):
  ffuf -w wordlist.txt -u http://target.com/FUZZ

ffuf (Extensions):
  ffuf -w wordlist.txt -u http://target.com/FUZZ -e .php,.html,.txt

ffuf (POST Data):
  ffuf -w wordlist.txt -u http://target.com/login -X POST -d "user=FUZZ&pass=test"

ffuf (Filter Size):
  ffuf -w wordlist.txt -u http://target.com/FUZZ -fs 4242

ffuf (Match Status):
  ffuf -w wordlist.txt -u http://target.com/FUZZ -mc 200,301,302'
            ;;
        
        *"Technology Detection"*)
            CONTENT='=== TECHNOLOGY DETECTION ===

webanalyze (Single):
  webanalyze -host https://target.com

webanalyze (Multiple):
  webanalyze -hosts urls.txt -output json > tech.json

webanalyze (Update DB):
  webanalyze -update

Extract Technologies:
  jq -r ".matches[].app_name" tech.json | sort -u'
            ;;
        
        *"SQL Injection"*)
            CONTENT='=== SQL INJECTION ===

SQLMap (Basic):
  sqlmap -u "http://target.com/page?id=1"

SQLMap (POST):
  sqlmap -u "http://target.com/login" --data "user=test&pass=test"

SQLMap (Dump Database):
  sqlmap -u "http://target.com/page?id=1" --dbs

SQLMap (Dump Table):
  sqlmap -u "http://target.com/page?id=1" -D dbname -T users --dump

SQLMap (Batch Mode):
  sqlmap -u "http://target.com/page?id=1" --batch --risk 3 --level 5'
            ;;
        
        *"XSS Testing"*)
            CONTENT='=== XSS TESTING ===

Manual Payloads:
  <script>alert(1)</script>
  <img src=x onerror=alert(1)>
  <svg onload=alert(1)>

ffuf (XSS Fuzzing):
  ffuf -w xss-payloads.txt -u "http://target.com/search?q=FUZZ" -mr "alert\(1\)"

Burp Suite:
  1. Capture request
  2. Send to Intruder
  3. Load XSS payloads
  4. Analyze responses'
            ;;
        
        *"Directory Fuzzing"*)
            CONTENT='=== DIRECTORY FUZZING ===

ffuf (Basic):
  ffuf -w /usr/share/wordlists/dirb/common.txt -u http://target.com/FUZZ

ffuf (Recursive):
  ffuf -w wordlist.txt -u http://target.com/FUZZ -recursion -recursion-depth 2

ffuf (With Extensions):
  ffuf -w wordlist.txt -u http://target.com/FUZZ -e .php,.html,.asp,.aspx,.jsp

ffuf (Filter by Size):
  ffuf -w wordlist.txt -u http://target.com/FUZZ -fs 1234

ffuf (Match Status Codes):
  ffuf -w wordlist.txt -u http://target.com/FUZZ -mc 200,301,302,403

dirsearch:
  dirsearch -u http://target.com -e php,html,js

gobuster:
  gobuster dir -u http://target.com -w wordlist.txt'
            ;;
        
        *"Kerberoasting"*)
            CONTENT='=== KERBEROASTING ===

Request Service Tickets:
  impacket-GetUserSPNs domain.local/user:password -dc-ip 10.10.10.10 -request

Crack Tickets:
  hashcat -m 13100 tickets.txt wordlist.txt

Rubeus (Windows):
  Rubeus.exe kerberoast /outfile:hashes.txt

PowerView:
  Get-NetUser -SPN | Select samaccountname,serviceprincipalname

Mimikatz:
  kerberos::list /export'
            ;;
        
        *"BloodHound"*)
            CONTENT='=== BLOODHOUND ===

Collect Data (SharpHound):
  SharpHound.exe -c All -d domain.local

Collect Data (BloodHound.py):
  bloodhound-python -u user -p password -d domain.local -dc dc01.domain.local -c All

Import to Neo4j:
  1. Start Neo4j
  2. Open BloodHound GUI
  3. Upload ZIP file
  4. Run queries

Useful Queries:
  - Find all Domain Admins
  - Shortest path to Domain Admins
  - Kerberoastable Users
  - AS-REP Roastable Users
  - Computers with Unconstrained Delegation'
            ;;
        
        *"Container Commands"*)
            CONTENT='=== CONTAINER COMMANDS ===

Run Container:
  container.sh run web

Build Container:
  container.sh build web

List Containers:
  podman ps -a

Stop Container:
  podman stop <container_id>

Remove Container:
  podman rm <container_id>

Recon Pipeline:
  recon-pipeline -m fast target.com
  recon-pipeline -p "80,443" target.com
  recon-pipeline --no-subdomain target.com
  recon-pipeline --scope inscope.txt target.com'
            ;;
        
        *"Git Commands"*)
            CONTENT='=== GIT COMMANDS ===

Status:
  git status

Add Files:
  git add .
  git add <file>

Commit:
  git commit -m "message"

Push:
  git push origin main

Pull:
  git pull

Branch:
  git branch <name>
  git checkout <name>

Diff:
  git diff
  git diff <file>

Log:
  git log --oneline
  git log --graph --oneline --all'
            ;;
        
        *"File Operations"*)
            CONTENT='=== FILE OPERATIONS ===

Find Files:
  find . -name "*.txt"
  find . -type f -mtime -7

Search Content:
  grep -r "pattern" .
  rg "pattern"

Disk Usage:
  du -sh *
  ncdu

File Info:
  file <filename>
  stat <filename>

Permissions:
  chmod 755 file.sh
  chmod +x file.sh

Copy/Move:
  cp source dest
  mv source dest'
            ;;
        
        *"Network Analysis"*)
            CONTENT='=== NETWORK ANALYSIS ===

Interface Info:
  ip addr
  ifconfig

Open Ports:
  ss -tulpn
  netstat -tulpn

Active Connections:
  ss -tuna

Packet Capture:
  tcpdump -i eth0 -w capture.pcap
  tcpdump -i eth0 port 80

DNS Lookup:
  dig target.com
  nslookup target.com

Trace Route:
  traceroute target.com
  mtr target.com'
            ;;
        *)
            continue
            ;;
    esac
    
    # Show content and wait for user to dismiss
    echo "$CONTENT" | fuzzel --dmenu --prompt "Commands (ESC to go back):" --width 100
done
