terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.11.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.53"
    }
  }
}

provider "azurerm" {
  features {}
  client_id       = ""
  subscription_id = ""
  tenant_id       = ""
  use_msi         = true
}

provider "coder" {
}

data "coder_workspace" "me" {}

resource "coder_agent" "main" {
  count = data.coder_workspace.me.transition == "start" ? 1 : 0
  arch  = "amd64"
  auth  = "azure-instance-identity"
  os    = "windows"

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 5
    timeout      = 5
    script       = "((Get-Counter '\\Processor(_Total)\\% Processor Time').CounterSamples.CookedValue).ToString('#,0.00') + '%'"
  }
  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 5
    timeout      = 5
    script       = "((100 - (104857600 * ((Get-Counter '\\Memory\\Available MBytes').CounterSamples.CookedValue) / ((Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum))).ToString('#,0.00')) + '%'"
  }
  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    interval     = 5
    timeout      = 5
    script       = "get-psdrive c | % { $_.used/($_.used + $_.free) } | % tostring p"
  }
}

#Generate random password for default user
resource "random_password" "admin_password" {
  length  = 16
  special = true
  # https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements#reference
  # we remove characters that require special handling in XML, as this is how we pass it to the VM
  # namely: <>&'"
  override_special = "~!@#$%^*_-+=`|\\(){}[]:;,.?/"
}

#Generate random computer name
resource "random_string" "computer_name" {
  length  = 15
  special = false
}

locals {
  prefix              = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
  resource_group_name = "MC_eric-rg_eric-cluster_eastus2"
  subnet_id           = "/subscriptions/05e8b285-4ce1-46a3-b4c9-f51ba67d6acc/resourceGroups/MC_eric-rg_eric-cluster_eastus2/providers/Microsoft.Network/virtualNetworks/aks-vnet-94756878/subnets/aks-subnet"

  admin_username = "coder"
}

#Create network interface
resource "azurerm_network_interface" "main" {
  name                = "${local.prefix}-nic"
  resource_group_name = local.resource_group_name
  location            = "eastus2"
  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    Coder_Provisioned = "true"
    Environment       = "Production"
    Usecase           = "test"
    UserName          = "${data.coder_workspace.me.owner}"
  }
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "main" {
  name                  = "${local.prefix}-vm"
  admin_username        = local.admin_username
  admin_password        = random_password.admin_password.result
  location              = "eastus2"
  resource_group_name   = local.resource_group_name
  network_interface_ids = [azurerm_network_interface.main.id]
  size                  = "Standard_DS1_v2"
  computer_name         = lower(random_string.computer_name.result)
  custom_data = base64encode(
    templatefile("${path.module}/Initialize.ps1.tftpl", { init_script = try(coder_agent.main[0].init_script, "") }
  ))
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  identity {
    type = "SystemAssigned"
  }
  os_disk {
    name                 = "${local.prefix}-myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  additional_unattend_content {
    content = "<AutoLogon><Password><Value>${random_password.admin_password.result}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${local.admin_username}</Username></AutoLogon>"
    setting = "AutoLogon"
  }
  additional_unattend_content {
    content = file("${path.module}/FirstLogonCommands.xml")
    setting = "FirstLogonCommands"
  }

  provisioner "local-exec" {
    when    = create
    command = "az vm extension set --vm-name ${local.prefix}-vm --name AADLoginForWindows --publisher Microsoft.Azure.ActiveDirectory -g ${local.resource_group_name}"
  }

  provisioner "local-exec" {
    when    = create
    command = "az vm restart --ids ${azurerm_windows_virtual_machine.main.id}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "az vm start --name ${self.name} -g ${self.resource_group_name}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "az vm run-command invoke  --command-id RunPowerShellScript --name ${self.name} -g ${self.resource_group_name} --scripts 'Dsregcmd /leave'"
  }

  tags = {
    Coder_Provisioned = "true"
    Environment       = "Production"
    Usecase           = "test"
    UserName          = "${data.coder_workspace.me.owner}"
  }
}

# Stop the VM
resource "null_resource" "stop_vm" {
  count      = data.coder_workspace.me.transition == "stop" ? 1 : 0
  depends_on = [azurerm_windows_virtual_machine.main]
  provisioner "local-exec" {
    # Use deallocate so the VM is not charged
    command = "az vm deallocate --ids ${azurerm_windows_virtual_machine.main.id}"
  }
}

# Start the VM
resource "null_resource" "start" {
  count      = data.coder_workspace.me.transition == "start" ? 1 : 0
  depends_on = [azurerm_windows_virtual_machine.main]
  provisioner "local-exec" {
    command = "az vm start --ids ${azurerm_windows_virtual_machine.main.id}"
  }
}

#Hide Nerwork Interface from metadata
resource "coder_metadata" "hide_azurerm_network_interface" {
  count       = data.coder_workspace.me.start_count
  resource_id = azurerm_network_interface.main.id
  hide        = true
  item {
    key   = "name"
    value = azurerm_network_interface.main.name
  }
}

#Hide Null Resounce (start VM) from metadata
resource "coder_metadata" "hide_null_resource" {
  count       = data.coder_workspace.me.start_count
  resource_id = null_resource.start[0].id
  hide        = true
}

#Hide Random Password from metadata
resource "coder_metadata" "hide_random_password" {
  count       = data.coder_workspace.me.start_count
  resource_id = random_password.admin_password.id
  hide        = true
}

#Hide Random String from metadata
resource "coder_metadata" "hide_computer_name" {
  count       = data.coder_workspace.me.start_count
  resource_id = random_string.computer_name.id
  hide        = true
}

#Coder metadata
resource "coder_metadata" "ceic" {
  resource_id = azurerm_windows_virtual_machine.main.id
  item {
    key   = "User Name"
    value = "<SHORT ID>@domainname.com"
  }
  item {
    key   = "Password"
    value = "System Password"
  }
  item {
    key   = "IP Address"
    value = azurerm_network_interface.main.private_ip_address
  }
}
