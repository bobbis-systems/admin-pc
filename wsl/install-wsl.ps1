# ============================================
# 🐧 Bobbis WSL Bootstrap Installer (Final Smart Menu)
# ============================================

# Author: Bobbis Systems
# Version: 1.8-smart-menu
# Description: Adaptive, intelligent WSL installer with dynamic menu
# ============================================

# ─────────────── SYSTEM CONFIGURATION ───────────────

$EnableTestMode     = $false
$EnableLogging      = $true
$EnablePause        = $true
$EnableLoopMode     = $true

# ─────────────── WSL DISTRO SETTINGS ───────────────

$WSLVersion         = 2
$DesiredDistros     = @("Ubuntu", "Kali-Linux", "Alpine")
$WSLListArgs        = "--list --quiet"
$WSLRootPath        = "$env:LOCALAPPDATA\Packages"

# ─────────────── LOGGING SETTINGS ───────────────

$LogRootPath        = "$env:ProgramData\Bobbis-Systems\logs"
$LogDateFormat      = "yyyy-MM-dd"
$LogDateTag         = (Get-Date).ToString($LogDateFormat)
$LogFile            = "$LogRootPath\${LogDateTag}_wsl_installer.log"
if ($EnableLogging -and -not $EnableTestMode) {
    New-Item -ItemType Directory -Path $LogRootPath -Force | Out-Null
}
function Log-Action($msg) {
    if ($EnableLogging -and -not $EnableTestMode) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp | $msg" | Out-File -Append -FilePath $LogFile
    }
}

# ─────────────── SANITY CHECKS ───────────────

$WSLAvailable = Get-Command wsl -ErrorAction SilentlyContinue

# ─────────────── HELPERS ───────────────

function Get-WSLVersion {
    try {
        $statusOutput = & wsl --status 2>$null
        if ($statusOutput -match "Default Version:\s+(\d+)") {
            return $matches[1]
        }
    } catch {}
    return "Unknown"
}

function Show-Menu {
    Clear-Host
    $installedClean = @()
    $MissingDistros = @()
    $wslVer = "Unknown"

    if ($WSLAvailable) {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
        $vmFeature  = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
        $wslVer     = Get-WSLVersion
        $installedRaw = @(wsl $WSLListArgs 2>$null)
        $installedClean = $installedRaw | ForEach-Object { $_.Trim().ToLower() }
        $MissingDistros = $DesiredDistros | Where-Object { $installedClean -notcontains $_.ToLower() }
    }

    Write-Host "`n💾 WSL System Status" -ForegroundColor Cyan
    Write-Host " WSL Available:   " + ($WSLAvailable ? "✅ Yes" : "❌ No")
    Write-Host " Default Version: $wslVer"
    if ($WSLAvailable) {
        Write-Host " VM Platform:     $($vmFeature.State)"
        Write-Host ""
        Write-Host "📦 Distro Status:" -ForegroundColor Yellow
        foreach ($distro in $DesiredDistros) {
            $match = $installedClean | Where-Object { $_ -eq $distro.ToLower() }
            if ($match) {
                Write-Host " ✅ $distro installed" -ForegroundColor Green
            } else {
                Write-Host " ❌ $distro not installed" -ForegroundColor Red
            }
        }
    }

    Write-Host ""
    $option = 1
    $menuMap = @{}

    if (-not $WSLAvailable) {
        Write-Host "[$option] Install WSL prerequisites"
        $menuMap[$option.ToString()] = "prereqs"
    } elseif ($MissingDistros.Count -eq $DesiredDistros.Count) {
        Write-Host "[$option] Install distros (Ubuntu, Kali, Alpine)"
        $menuMap[$option.ToString()] = "install"
        $option++
        Write-Host "[$option] Exit"
        $menuMap[$option.ToString()] = "exit"
    } else {
        if ($MissingDistros.Count -gt 0) {
            Write-Host "[$option] Install missing distros: $($MissingDistros -join ", ")"
            $menuMap[$option.ToString()] = "install"
            $option++
        }
        Write-Host "[$option] View installed distros"
        $menuMap[$option.ToString()] = "view"
        $option++
        Write-Host "[$option] Uninstall a distro"
        $menuMap[$option.ToString()] = "uninstall"
        $option++
        Write-Host "[$option] Exit"
        $menuMap[$option.ToString()] = "exit"
    }
    Write-Host ""
    return $menuMap
}

function Install-Prerequisites {
    Write-Host "`n🔧 Enabling WSL prerequisites..." -ForegroundColor Cyan
    if ($EnableTestMode) {
        Write-Host "[TEST] Would enable WSL and VM features, and set default to $WSLVersion"
    } else {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
        wsl --set-default-version $WSLVersion
        Log-Action "Enabled WSL + VM features, set version $WSLVersion"
    }

    Write-Host "
⚡ WSL prerequisites installed successfully." -ForegroundColor Green
    Write-Host "🔁 Please reboot your system now."
    Write-Host "🧭 After reboot, re-run this script to continue the setup." -ForegroundColor Yellow

    if ($EnablePause) { Pause }
    exit
} else {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
        wsl --set-default-version $WSLVersion
        Log-Action "Enabled WSL + VM features, set version $WSLVersion"
        Write-Host "⚡ Please reboot your machine before continuing!" -ForegroundColor Yellow
    }
    if ($EnablePause) { Pause }
}

function Install-Distros {
    if (-not $WSLAvailable) {
        Write-Host "❌ WSL is not available. Please install prerequisites first." -ForegroundColor Red
        return
    }
    $installed = @(wsl $WSLListArgs 2>$null) | ForEach-Object { $_.ToLower().Trim() }
    $MissingDistros = $DesiredDistros | Where-Object { $installed -notcontains $_.ToLower() }

    if ($MissingDistros.Count -eq 0) {
        Write-Host "✅ All desired distros are already installed." -ForegroundColor Green
        return
    }

    Write-Host "`n📦 Installing missing distros..." -ForegroundColor Green
    foreach ($distro in $MissingDistros) {
        Write-Host "➞ Installing $distro..."
        if ($EnableTestMode) {
            Write-Host "[TEST] Would run: wsl --install -d $distro"
        } else {
            try {
                wsl --install -d $distro
                Log-Action "Installed $distro"
            } catch {
                Write-Host "⚠ Failed to install $distro." -ForegroundColor Red
            }
        }
    }
    if ($EnablePause) { Pause }
}

function View-Distros {
    if (-not $WSLAvailable) {
        Write-Host "❌ WSL is not available. Please install prerequisites first." -ForegroundColor Red
        return
    }
    Write-Host "`n📃 Installed WSL distros:" -ForegroundColor Cyan
    wsl --list --verbose
    if ($EnablePause) { Pause }
}

function Uninstall-Distro {
    if (-not $WSLAvailable) {
        Write-Host "❌ WSL is not available. Please install prerequisites first." -ForegroundColor Red
        return
    }
    Write-Host "`n🔞 Uninstall WSL Distro" -ForegroundColor Red
    $installed = @(wsl $WSLListArgs 2>$null) | ForEach-Object { $_.ToLower().Trim() }
    $distro = Read-Host "Enter exact distro name"
    $distro = $distro.Trim()
    if (-not $installed -contains $distro.ToLower()) {
        Write-Host "❌ '$distro' not found in installed list." -ForegroundColor Red
        return
    }
    if ($EnableTestMode) {
        Write-Host "[TEST] Would run: wsl --unregister $distro"
    } else {
        try {
            wsl --unregister $distro
            Log-Action "Uninstalled $distro"
            Write-Host "✅ $distro uninstalled."
        } catch {
            Write-Host "⚠ Failed to uninstall $distro." -ForegroundColor Red
        }
    }
    if ($EnablePause) { Pause }
}

function Run-MainMenuLoop {
    do {
        $menuMap = Show-Menu
        $choice = Read-Host "Select an option"
        if ($menuMap.ContainsKey($choice)) {
            switch ($menuMap[$choice]) {
                "prereqs"   { Install-Prerequisites }
                "install"   { Install-Distros }
                "view"      { View-Distros }
                "uninstall" { Uninstall-Distro }
                "exit"      { Write-Host "`n👋 Exiting..."; break }
            }
        } else {
            Write-Host "❌ Invalid option. Try again." -ForegroundColor Red
            if ($EnablePause) { Pause }
        }
    } while ($true)
}

if ($EnableLoopMode) {
    Run-MainMenuLoop
} else {
    Show-Menu
    Write-Host "🧭 Tip: Run Install-Prerequisites or Install-Distros manually in ISE."
}
