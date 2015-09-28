function Export-WindowsFeatures {
<#
.SYNOPSIS
Exports installed Windows features as a chocolatey install script

.LINK
http://boxstarter.org
#>

    Write-BoxstarterMessage "Exporting Windows features..."
	    
    $output = Get-WindowsFeatures

    $commands = $output | % { "choco install " + $_ + " -source windowsfeatures -y" }

    [PSCustomObject]@{"Command" = $commands; }
}

function Get-WindowsFeatures() {
	
	$result = @()
    $result = dism /online /Get-Features /Format:Table | Select-String Enabled | % {($_ -split '\|', 2)[0].Trim()}

    $result
}