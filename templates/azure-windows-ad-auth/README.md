---
name: Windows Development Template
description: This template supports `CEIC`.
tags: [cloud, azure, windows]
icon: /icon/azure.png
---

# Windows Development Template

## Tools installed as part of this Template

1. Matlab - R2022b Update3
1. Target Link - 22.1p2
1. TPT - 19.0
1. MXAM- 9.0.1, 9.1.0 and 9.1.1
1. MSVC - 2015 sp3
1. PVCS web client
1. PREEvision V10.80 Starvision PROD
1. Citrix Receiver
1. Apache open office
1. WinMerge

### Note

* Workspace name must be less than 32 characters.

* Workspace will be stopped automatically after 8 hrs. If you want to extend, modify the schedule accordingly after launching your workspace.

### Login Instructions

1. Setup Coder CLI (one Time Activity)

* For Windows: go to [https://github.com/coder/coder/releases/latest](https://github.com/coder/coder/releases/latest), download the `.exe` file

* For Linux or MAC

``` console
curl -fsSL https://coder.com/install.sh | sh
```

1. Open terminal and execute the command to authenticate:

* `coder login <url>`
* It will redirect to browser and display the token, use the same token to authenticate

1. Execute the following command to configure coder ssh

* `coder config-ssh`

1. Open secure tunnel to connect with your workspaces.

* `coder tunnel <workspace name> --tcp <local Port>:3389`
* `Ex: coder tunnel my-workspcae --tcp 8080:3389`

1. Now open your local Remote Desktop Connection (RDC) client and provide details as below to connect with your workspace.

* `localhost:<local port>`  -->  Ex: `localhost:8080`
* `User Name: <SHORT ID>@corp.net`
* `Password: Laptop/System Password`
