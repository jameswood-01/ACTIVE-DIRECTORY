# 🏢 Enterprise Active Directory Lab

[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Windows Server](https://img.shields.io/badge/Windows%20Server-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://learn.microsoft.com/en-us/windows-server/)
[![VMware](https://img.shields.io/badge/VMware-607078?style=for-the-badge&logo=vmware&logoColor=white)](https://www.vmware.com/)
[![Active Directory](https://img.shields.io/badge/Active%20Directory-00188F?style=for-the-badge&logo=microsoft&logoColor=white)](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview)
![Status](https://img.shields.io/badge/status-complete-brightgreen?style=for-the-badge)

A fully functional enterprise-style Active Directory environment built from scratch in a virtualized home lab — replicating the core identity, network, and automation infrastructure found in a real corporate IT environment.

> This is what your corporate IT environment looks like under the hood.

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Repo Structure](#-repo-structure)
- [Core Components](#-core-components)
  - [Domain Controller](#1-domain-controller)
  - [DHCP Server](#2-dhcp-server)
  - [DNS Server](#3-dns-server)
  - [NAT Routing (Dual-NIC)](#4-nat-routing-dual-nic)
  - [Automated User Provisioning](#5-automated-user-provisioning)
- [Script Usage](#-script-usage)
- [Technologies Used](#-technologies-used)
- [Screenshots](#-screenshots)
- [Skills Demonstrated](#-skills-demonstrated)
- [Future Improvements](#-future-improvements)
- [License](#-license)
- [Author](#-author)

---

## 🏗️ Overview

This project simulates a small-to-mid-size enterprise network end-to-end — not just a single isolated service, but the full stack an IT/security admin would actually manage: identity, network services, routing, and automated provisioning at scale.

**Highlights:**
- Enterprise-grade Active Directory domain built from the ground up
- Dual-NIC domain controller handling both internal services and edge routing
- Fully automated bulk provisioning of 1,000 AD user accounts via PowerShell
- Designed to mirror real-world corporate IT topology

---

## ⚙️ Architecture

```
                     Internet
                        │
                 [ NAT / RRAS ]
                        │
          ┌─────────────┴─────────────┐
          │     Domain Controller     │
          │  (Dual-NIC: LAN + WAN)    │
          │                           │
          │   ├── AD DS               │
          │   ├── DNS                 │
          │   └── DHCP                │
          └─────────────┬─────────────┘
                        │
                 [ Internal LAN ]
                        │
          ┌─────────────┴─────────────┐
          │   Domain-joined clients   │
          │   (addresses via DHCP)    │
          └───────────────────────────┘

   AD DS: 1,000 user accounts provisioned by PowerShell
```

---

## 📁 Repo Structure

```
├── scripts/
│   └── Create-BulkADUsers.ps1      # Bulk AD user provisioning script
├── docs/
│   └── ADUserCreation_Log.csv      # Sample output log from a provisioning run
└── README.md
```

> 📂 [`/scripts`](./scripts) · 📂 [`/docs`](./docs)

---

## 🧩 Core Components

### 1. Domain Controller
Windows Server configured as the forest/domain root with Active Directory Domain Services (AD DS). Hosts organizational units (OUs), group policy structure, and the primary identity store for the environment.

### 2. DHCP Server
Configured with scoped IP ranges for automatic address assignment to all domain-joined clients, removing the need for manual IP configuration as the environment scales.

### 3. DNS Server
Internal DNS zone resolving AD domain resources, enabling clients and services to locate the domain controller and each other by name rather than static IP.

### 4. NAT Routing (Dual-NIC)
The domain controller is configured with two network interfaces — one bound to the internal LAN, the other handling NAT via Routing and Remote Access (RRAS) — giving the internal network outbound internet access while keeping it segmented from the external interface.

### 5. Automated User Provisioning
A custom PowerShell script ([`Create-BulkADUsers.ps1`](./scripts/Create-BulkADUsers.ps1)) that bulk-creates AD user accounts — generating unique usernames, assigning OU placement and group membership, setting initial passwords, enforcing password-change-at-first-logon, and logging every account created for auditing.

---

## 🖥️ Script Usage

```powershell
# Create 1,000 users in the Employees OU
.\scripts\Create-BulkADUsers.ps1 -UserCount 1000 -OU "OU=Employees,DC=lab,DC=local"

# Create 500 users, add them to a group, and pull names from a CSV
.\scripts\Create-BulkADUsers.ps1 -UserCount 500 -OU "OU=Staff,DC=corp,DC=local" -Group "AllStaff" -NameListPath ".\names.csv"

# Dry run (no changes made)
.\scripts\Create-BulkADUsers.ps1 -UserCount 1000 -OU "OU=Employees,DC=lab,DC=local" -WhatIf
```

**Requirements:** the ActiveDirectory PowerShell module (RSAT or run on the DC) and rights to create users in the target OU. The script prompts securely for the initial password, so it is never stored in the script or your shell history. Usernames are capped at AD's 20-character limit and made unique automatically.

Full parameter documentation is in the script's comment-based help — run:

```powershell
Get-Help .\scripts\Create-BulkADUsers.ps1 -Full
```

➡️ [View the script](./scripts/Create-BulkADUsers.ps1)

---

## 🧰 Technologies Used

| Category | Tools / Tech |
|---|---|
| OS / Platform | Windows Server, Windows 10/11 clients |
| Virtualization | VMware Workstation / ESXi |
| Directory Services | Active Directory Domain Services (AD DS) |
| Networking | DHCP, DNS, RRAS (NAT routing), dual-NIC configuration |
| Automation | PowerShell, Active Directory PowerShell module |

---

## 📸 Screenshots

> 🚧 Screenshots coming soon. Once uploaded to a `screenshots/` folder, they'll appear here:
>
> ```markdown
> | Active Directory Users & Computers | DHCP Scope |
> |---|---|
> | ![AD Users](./screenshots/ad-users-and-computers.png) | ![DHCP Scope](./screenshots/dhcp-scope.png) |
>
> | DNS Zones | Script Output |
> |---|---|
> | ![DNS Zones](./screenshots/dns-zones.png) | ![Script Output](./screenshots/script-output.png) |
> ```

---

## 🎯 Skills Demonstrated

- Enterprise directory services design and deployment
- Network segmentation and routing (NAT, dual-NIC)
- DHCP/DNS administration
- Infrastructure automation and scripting at scale
- Systems administration and troubleshooting in a Windows Server environment
- Documentation and auditability practices (CSV logging, comment-based help)

---

## 🔭 Future Improvements

- [ ] Add Group Policy Object (GPO) configuration and screenshots
- [ ] Integrate a SIEM (Wazuh/Splunk) to monitor AD authentication events
- [ ] Add a second DC for redundancy/replication testing
- [ ] Script-based OU and GPO deployment (infrastructure-as-code style)

---

## 📄 License

This project is for educational and portfolio purposes.

## 👤 Author

**Woody**
Cybersecurity & IT — [GitHub Profile](https://github.com/jameswood-01) · [LinkedIn](https://www.linkedin.com/in/jamesmwood22/)
