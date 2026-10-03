# ACTIVE DIRECTORY
# Enterprise Active Directory Lab

A fully functional enterprise-style Active Directory environment built from scratch in a virtualized home lab — designed to replicate the core infrastructure of a real corporate IT network.

## 🏗️ Overview

This project simulates a small-to-mid-size enterprise network, covering identity management, network services, and automated provisioning at scale. It was built to demonstrate hands-on, end-to-end infrastructure skills rather than isolated, single-purpose labs.

## ⚙️ Architecture

- **Domain Controller** — Windows Server running Active Directory Domain Services (AD DS)
- **Dual-NIC Configuration** — one interface bound to the internal LAN, the other handling NAT routing out to the internet
- **DHCP Server** — automatic IP assignment and scope management for all domain-joined clients
- **DNS Server** — internal name resolution supporting the AD domain
- **NAT Routing** — Routing and Remote Access (RRAS) configured for internet access from the internal network
- **Automated User Provisioning** — custom PowerShell script to bulk-create 1,000 Active Directory user accounts

- # Enterprise Active Directory Lab

A fully functional enterprise-style Active Directory environment built from scratch in a virtualized home lab — designed to replicate the core infrastructure of a real corporate IT network.

## 🏗️ Overview

This project simulates a small-to-mid-size enterprise network, covering identity management, network services, and automated provisioning at scale. It was built to demonstrate hands-on, end-to-end infrastructure skills rather than isolated, single-purpose labs.

## ⚙️ Architecture

- **Domain Controller** — Windows Server running Active Directory Domain Services (AD DS)
- **Dual-NIC Configuration** — one interface bound to the internal LAN, the other handling NAT routing out to the internet
- **DHCP Server** — automatic IP assignment and scope management for all domain-joined clients
- **DNS Server** — internal name resolution supporting the AD domain
- **NAT Routing** — Routing and Remote Access (RRAS) configured for internet access from the internal network
- **Automated User Provisioning** — custom PowerShell script to bulk-create 1,000 Active Directory user accounts

- 
## 🚀 Features

- Full AD DS deployment with organizational units (OUs) and group policy structure
- Dual-homed DC handling both internal services and edge routing/NAT
- DHCP scope configured for automatic client onboarding
- Internal DNS resolving domain resources
- PowerShell automation script that generates 1,000 unique AD user accounts (names, usernames, OU placement, and group assignment) in a single run

## 🖥️ PowerShell User Provisioning Script

Located in [`/scripts`](./scripts), this script:
- Reads from a generated or provided list of user data (or generates it programmatically)
- Creates AD user objects via `New-ADUser`
- Assigns users to appropriate OUs and security groups
- Sets initial passwords and enforces password-change-at-first-logon policy
- Logs successes/failures for auditing

```powershell
# Example usage
.\Create-BulkADUsers.ps1 -UserCount 1000 -OU "OU=Employees,DC=lab,DC=local"
```

## 🧰 Technologies Used

- Windows Server (Active Directory Domain Services, DNS, DHCP, RRAS)
- PowerShell (Active Directory module)
- VMware Workstation/ESXi for virtualization
- (Add: Windows client OS version, hypervisor version, etc. as applicable)

## 📸 Screenshots

_Add screenshots of AD Users and Computers, DHCP scope, DNS zones, and the PowerShell script output here._

## 🎯 Skills Demonstrated

- Enterprise directory services design and deployment
- Network segmentation and routing (NAT, dual-NIC)
- DHCP/DNS administration
- Infrastructure automation and scripting at scale
- Troubleshooting and systems administration in a Windows Server environment

## 📄 License

This project is for educational and portfolio purposes.

## 👤 Author

**jameswood01**
Cybersecurity & IT — [[GitHub Profile Link](https://github.com/jameswood-01/)]
