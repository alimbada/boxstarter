function cinst {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param($RebootCodes=@(3010))
    chocolatey Install @PSBoundParameters
}

function cup {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param($RebootCodes=@(3010))
    chocolatey Update @PSBoundParameters
}

function cinstm {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>    
    param($RebootCodes=@(3010))
    chocolatey InstallMissing @PSBoundParameters
}

function chocolatey {
<#
.SYNOPSIS
Intercepts Chocolatey call to check for reboots

#>  
    param($RebootCodes=@(3010))
    if((Test-PendingReboot) -and $Boxstarter.RebootOk) {return Invoke-Reboot}
    $global:error.Clear()
    Call-Chocolatey @PSBoundParameters
    if($Boxstarter.rebootOk -and $global:error.count -gt 0) {
        if ($global:error[$global:error.count-1] -match "code was '(\d+)'") {
            $errorCode=$matches[1]
            if($RebootCodes -contains $errorCode) {
                Write-BoxstarterMessage "Chocolatey Install returned a rebootable exit code"
                $pkgDir = (dir $env:ChocolateyInstall\lib\$packageName.*)
                if($pkgDir.length -gt 0) {$pkgDir = $pkgDir[-1]}
                remove-item $pkgDir -Recurse -Force
                Invoke-Reboot
            }
        }
    }
}

function Call-Chocolatey {
    $session=Start-TimedSection "Calling Chocolatey to install $packageName"
    ."$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1" @PSBoundParameters
    Stop-Timedsection $session
}

function Intercept-Command ($commandName, $omitCommandParam) {
    $metadata=New-Object System.Management.Automation.CommandMetaData (Get-Command "$env:ChocolateyInstall\chocolateyinstall\chocolatey.ps1")
    $srcMetadata=New-Object System.Management.Automation.CommandMetaData (Get-Command $commandName)
    $metadata.Parameters.Remove("Verbose") | out-null
    $metadata.Parameters.Remove("Debug") | out-null
    $metadata.Parameters.Remove("ErrorAction") | out-null
    $metadata.Parameters.Remove("WarningAction") | out-null
    $metadata.Parameters.Remove("ErrorVariable") | out-null
    $metadata.Parameters.Remove("WarningVariable") | out-null
    $metadata.Parameters.Remove("OutVariable") | out-null
    $metadata.Parameters.Remove("OutBuffer") | out-null
    if($omitCommandParam) {
        $metadata.Parameters.Remove("command") | out-null
    }
    $params = [Management.Automation.ProxyCommand]::GetParamBlock($metadata)    
    if($srcMetadata.Parameters.count -gt 0) {
        $srcParams = [Management.Automation.ProxyCommand]::GetParamBlock($srcMetadata)    
        $params += ",`r`n" + $srcParams
    }
    $cmdLetBinding = [Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
    $strContent = (Get-Content function:\$commandName).ToString()
    if($strContent -match "param\(.+\)") {
        $strContent = $strContent.Replace($matches[0],"")
    }
    Set-Item Function:\$commandName -value "$cmdLetBinding `r`n param ( $params )Process{ `r`n$strContent}" -force
}

function Intercept-Chocolatey {
    if($Script:BoxstarterIntrercepting){return}
    Intercept-Command cinst $true
    Intercept-Command cup $true
    Intercept-Command cinstm $true
    Intercept-Command chocolatey
    Intercept-Command call-chocolatey
    $Script:BoxstarterIntrercepting=$true
}