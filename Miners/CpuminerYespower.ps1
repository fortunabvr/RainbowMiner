﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\CPU-Yespower\cpuminer$($f = $Global:GlobalCPUInfo.Features; if ($f.avx2 -and $f.sha -and $f.aes) {'-avx2-sha'} elseif ($f.sse42 -and $f.sha -and $f.aes) {'-sse42-sha'} elseif ($f.avx2 -and $f.aes) {'-avx2'} elseif ($f.avx -and $f.aes) {'-avx'} elseif ($f.sse42) {'-sse42'} elseif ($f.sse2) {'-sse2'} else {''}).exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.8.3-bubasik/cpuminer-opt-cryply-yespower-ver2.zip"
$ManualUri = "https://github.com/bubasik/cpuminer-opt-yespower/releases"
$Port = "530{0:d2}"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #Yespower
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Session.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-b $($Miner_Port) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($DeviceParams) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Ccminer"
                Port = $Miner_Port
                Uri = $Uri
                FaultTolerance = 0.5 #$_.FaultTolerance
                ExtendInterval = $_.ExtendInterval
				DevFee = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}