# Pester 3 compatible tests
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:ScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Otimizar-PC.ps1"
. $script:ScriptPath -LoadOnly

Describe "Otimizador-PC" {
    Context "Function existence" {
        It "Defines Clean-Temp" { (Get-Command Clean-Temp -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Clean-BrowserCaches" { (Get-Command Clean-BrowserCaches -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Clean-PackageCaches" { (Get-Command Clean-PackageCaches -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Does not define Clean-ProjectJunk (projects preserved)" { (Get-Command Clean-ProjectJunk -ErrorAction SilentlyContinue) -eq $null | Should Be $true }
        It "Defines Optimize-Startup" { (Get-Command Optimize-Startup -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines System-Tweaks" { (Get-Command System-Tweaks -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Optimize-Disk" { (Get-Command Optimize-Disk -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Clear-EventLogs" { (Get-Command Clear-EventLogs -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Disable-BackgroundApps" { (Get-Command Disable-BackgroundApps -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Flush-DNS" { (Get-Command Flush-DNS -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Enable-StorageSense" { (Get-Command Enable-StorageSense -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Run-CleanMgr" { (Get-Command Run-CleanMgr -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Show-DiskSpace" { (Get-Command Show-DiskSpace -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Is-Protected" { (Get-Command Is-Protected -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
        It "Defines Get-FolderSize" { (Get-Command Get-FolderSize -ErrorAction SilentlyContinue) -ne $null | Should Be $true }
    }

    Context "Is-Protected" {
        It "Protects Epic Games path" { Is-Protected "C:\Program Files\Epic Games\Fortnite" | Should Be $true }
        It "Protects Fortnite path" { Is-Protected "C:\Users\Leo\AppData\Local\FortniteGame" | Should Be $true }
        It "Does not protect normal paths" { Is-Protected "C:\Users\Leo\Documents\projeto" | Should Be $false }
        It "Protects EpicGames" { Is-Protected "C:\EpicGames\Launcher" | Should Be $true }
    }

    Context "Get-FolderSize" {
        It "Returns 0 for non-existent path" { Get-FolderSize "C:\This\Does\Not\Exist" | Should Be 0 }
        It "Returns positive size for existing folder" {
            $size = Get-FolderSize $env:TEMP
            $size | Should BeGreaterThan 0
        }
    }

    Context "Version" {
        It "Has a version defined" { $Version | Should Not BeNullOrEmpty }
    }
}
