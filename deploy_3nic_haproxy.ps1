# William Lam
# www.virtuallyghetto
# Blog: https://www.virtuallyghetto.com/2020/11/automating-haproxy-vm-deployment-with-3-nic-configuration-using-powercli.html
# Description: Deploy HAProxy VM w/3-NIC Configuration

$HAProxyOVA = "/Volumes/Storage/Software/vmware-haproxy-v0.2.0.ova"

$Cluster = "Tanzu-Cluster"
$VMHost = "Z840.homelab.local"
$Datastore = "Z840-SATA-2TB-Datastore-1"

$HAProxyDisplayName = "haproxy.homelab.local"
$HAProxyHostname = "haproxy.homelab.local"
$HAProxyDNS = "10.0.1.3"
$HAProxyManagementNetwork = "Management"
$HAProxyManagementIPAddress = "10.0.1.111/24" # Format is IP Address/CIDR Prefix
$HAProxyManagementGateway = "10.0.1.254"
$HAProxyFrontendNetwork = "Frontend"
$HAProxyFrontendIPAddress = "10.10.0.2/24" # Format is IP Address/CIDR Prefix
$HAProxyFrontendGateway = "10.0.10.254"
$HAProxyWorkloadNetwork = "Workload"
$HAProxyWorkloadIPAddress = "10.0.20.2/24" # Format is IP Address/CIDR Prefix
$HAProxyWorkloadGateway = "10.0.20.254"
$HAProxyLoadBalanceIPRange = "10.0.10.64/26" # Format is Network CIDR Notation
$HAProxyOSPassword = "VMware1!"
$HAProxyPort = "5556"
$HAProxyUsername = "wcp"
$HAProxyPassword = "VMware1!"

### DO NOT EDIT BEYOND HERE ###

$ovfconfig = Get-OvfConfiguration $HAProxyOVA

$ovfconfig.DeploymentOption.value = "frontend"

$ovfconfig.network.hostname.value = $HAProxyHostname
$ovfconfig.network.nameservers.value = $HAProxyDNS

$ovfconfig.NetworkMapping.Management.value = $HAProxyManagementNetwork
$ovfconfig.NetworkMapping.Frontend.value = $HAProxyFrontendNetwork
$ovfconfig.NetworkMapping.Workload.value = $HAProxyWorkloadNetwork

# Management
$ovfconfig.network.management_ip.value = $HAProxyManagementIPAddress
$ovfconfig.network.management_gateway.value = $HAProxyManagementGateway

# Workload
$ovfconfig.network.workload_ip.value = $HAProxyWorkloadIPAddress
$ovfconfig.network.workload_gateway.value = $HAProxyWorkloadGateway

$ovfconfig.loadbalance.service_ip_range.value = $HAProxyLoadBalanceIPRange
$ovfconfig.appliance.root_pwd.value = $HAProxyOSPassword
$ovfconfig.loadbalance.dataplane_port.value = $HAProxyPort
$ovfconfig.loadbalance.haproxy_user.value = $HAProxyUsername
$ovfconfig.loadbalance.haproxy_pwd.value = $HAProxyPassword

Write-Host "Deploying HAProxy VM $HAProxyDisplayName ..."
$vm = Import-VApp -Source $HAProxyOVA -OvfConfiguration $ovfconfig -Name $HAProxyDisplayName -Location $Cluster -VMHost $VMHost -Datastore $Datastore -DiskStorageFormat thin

$vappProperties = $vm.ExtensionData.Config.VAppConfig.Property
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.vAppConfig = New-Object VMware.Vim.VmConfigSpec

$ovfChanges = @{
    "frontend_ip"=$HAProxyFrontendIPAddress
    "frontend_gateway"=$HAProxyFrontendGateway
}

# Retrieve existing OVF properties from VM
$vappProperties = $VM.ExtensionData.Config.VAppConfig.Property

# Create a new Update spec based on the # of OVF properties to update
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.vAppConfig = New-Object VMware.Vim.VmConfigSpec
$propertySpec = New-Object VMware.Vim.VAppPropertySpec[]($ovfChanges.count)

# Find OVF property Id and update the Update Spec
foreach ($vappProperty in $vappProperties) {
    if($ovfChanges.ContainsKey($vappProperty.Id)) {
        $tmp = New-Object VMware.Vim.VAppPropertySpec
        $tmp.Operation = "edit"
        $tmp.Info = New-Object VMware.Vim.VAppPropertyInfo
        $tmp.Info.Key = $vappProperty.Key
        $tmp.Info.value = $ovfChanges[$vappProperty.Id]
        $propertySpec+=($tmp)
    }
}
$spec.VAppConfig.Property = $propertySpec

Write-Host "Updating HAProxy Frontend Properties"
$task = $vm.ExtensionData.ReconfigVM_Task($spec)
$task1 = Get-Task -Id ("Task-$($task.value)")
$task1 | Wait-Task

Write-Host "Powering On $HAProxyDisplayName ..."
$vm | Start-Vm -RunAsync | Out-Null
