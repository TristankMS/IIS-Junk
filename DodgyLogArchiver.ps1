# IIS log archiving sample script (c) 2016
# all care taken, no responsibility accepted by TristanK
# Note: ZERO ERROR HANDLING
#
# Example: 
#    .\dodgylogarchiver.ps1 -archiveFolder D:\Archive\Logs -daysToKeepOnWebServer 30 -daysToKeepInArchive 300 
#
#    ... which should be nondestructive, i.e. it'll copy but not delete. And if it looks like it's OK, "arm" it to delete the files.
#
#    .\dodgylogarchiver.ps1 -archiveFolder D:\Archive\Logs -daysToKeepOnWebServer 30 -daysToKeepInArchive 300 -actuallyRemoveOldLocalFiles -actuallyRemoveOldArchivedFiles
# 
# Tries to do an intelligent job of log archiving
# Designed to run on local IIS server
# Cheats by using XCOPY to un-set the archive bit for files which haven't changed
# so we know which files we've already copied
# (possible future "improvement" to go PS only)
# Also finds HTTPERR logs and does the same thing with them

param (
[Parameter(Mandatory=$true,HelpMessage="Please enter the location you want to use for archived log storage:")]
$archiveFolder="G:\Storage\Logs",
[Parameter(Mandatory=$false)]  
$daysToKeepOnWebServer = 60,         # number of days to retain in current web server log directory
[Parameter(Mandatory=$false)]
$daysToKeepInArchive = 900,          # number of days to retain in archive location, i.e. should typically be a higher number
[Parameter(Mandatory=$false)]
[switch]$skipHTTPERR,                # don't archive HTTPERR logs
[Parameter(Mandatory=$false)]
[switch]$actuallyRemoveOldLocalFiles, # don't just talk about it - actually remove files
[Parameter(Mandatory=$false)]
[switch]$actuallyRemoveOldArchivedFiles # don't just talk about it - actually keep the archive trimmed down to X days
)

function SafeName($unsafename){
    $safename = ""
    $safename = $unsafename.Replace("\","_")
    $safename = $safename.Replace("/","_")
    $safename = $safename.Replace(":","-")
    $safename
}

Import-Module WebAdministration

if([string]::IsNullOrEmpty($archiveFolder)){
    ""
    "Please specify -archiveFolder. This is where you want your local logs to be copied."
    "Valid syntax is G:\Storage\Something or \\server\writableshare\something ."
    ""
    exit
}
#$archiveFolder = "G:\Storage\Logs"
#$daysToKeepOnWebServer = 60
#$daysToKeepInArchive = 900
#$skipHTTPERR = $false
#$actuallyRemoveOldLocalFiles = $true
#$actuallyRemoveOldArchivedFiles = $true

$websites = get-website

if($skipHTTPERR -ne $true){
    #just in case someone's Really Clever and has moved HTTPERR from its default location
    # default location
    Write-Host -ForegroundColor Yellow -BackgroundColor Blue "HTTPERR Start"

    $httpErrFolder = "$env:windir\System32\LogFiles\"
    $httpParams = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\HTTP\Parameters" -ErrorAction SilentlyContinue
    if($null -ne $httpParams.ErrorLoggingDir){
        # if that worked, replace the default.
        $httpErrFolder = $httpParams.ErrorLoggingDir
    }

    $httpErrFolder = join-path $httpErrFolder -ChildPath "HTTPERR"
    
    $targetdir = "" + $env:COMPUTERNAME + "_0_HTTPERR"
    $targetfolder = Join-Path $archiveFolder -ChildPath $targetdir

    "Site:   HTTPERR - global HTTP transport error log" 
    "Source: $httpErrFolder"
    "Dest:   $targetfolder"
    #initially, copy everything because it's safer to do so
    #plus, cheat with XCOPY because it's faster! (unsets Archive attrib)
    "Copying $httpErrFolder\*.log to $targetfolder"
    xcopy "$httpErrFolder\*.log" "$targetfolder" /M /I /Y

    #then, consider whether we need to clean up the local server
    $files=Get-ChildItem "$httpErrFolder\*.log"
    foreach($file in $files){
        if($file.LastWriteTime.AddDays($daysToKeepOnWebServer) -lt [DateTime]::Now){
            "$file is too old to keep locally"
            if($actuallyRemoveOldLocalFiles){
                "   deleting..."
                Remove-Item $file -Force
            }
        }
    }

    $storedlogs=Get-ChildItem "$targetfolder\*.log"
        foreach($oldLogFile in $storedlogs){
        if($oldLogFile.LastWriteTime.AddDays($daysToKeepInArchive) -lt [DateTime]::Now){
            "$oldLogFile is too old to keep stored"
            if($actuallyRemoveOldArchivedFiles){
                "   deleting..."
                Remove-Item $oldLogFile -Force
            }
        }
    }
    write-host -ForegroundColor Yellow -BackgroundColor Red "End of HTTPERR"
    ""
}

foreach ($website in $websites){
    Write-Host -ForegroundColor Yellow -BackgroundColor Blue "$($website.Name) Start"
    $logdir = [System.Environment]::ExpandEnvironmentVariables($website.logFile.directory)
    
    #try to avoid weird characters legal for a site name but not a filename
    $safename = SafeName($website.name)
    $targetdir = "" + $env:COMPUTERNAME + "_" + $website.id + "_" + $safename
    $targetfolder = Join-Path $archiveFolder -ChildPath $targetdir
    $dirToLookAt = "" + $logdir + "\W3SVC" + $website.id

    "Site:   " + $website.name
    "Source: $dirToLookAt"
    "Dest:   $targetfolder"

    #initially, copy everything because it's safer to do so
    #plus, cheat with XCOPY because it's faster!
    "Copying $dirToLookAt\*.log to $targetfolder"
    xcopy "$dirToLookAt\*.log" "$targetfolder" /M /I /Y

    #then, consider whether we need to clean up the local server
    $files=Get-ChildItem "$dirToLookAt\*.log"
    foreach($file in $files){
        if($file.LastWriteTime.AddDays($daysToKeepOnWebServer) -lt [DateTime]::Now){
            "$file is too old to keep locally"
            if($actuallyRemoveOldLocalFiles){
                  "   deleting..."
                Remove-Item $file -Force
            }
        }
    }

    $storedlogs=Get-ChildItem "$targetfolder\*.log"
        foreach($oldLogFile in $storedlogs){
        if($oldLogFile.LastWriteTime.AddDays($daysToKeepInArchive) -lt [DateTime]::Now){
            "$oldLogFile is too old to keep stored"
            if($actuallyRemoveOldArchivedFiles){
                  "   deleting..."
                Remove-Item $oldLogFile -Force
            }
        }
    }
    write-host -ForegroundColor Yellow -BackgroundColor Red "End of $($website.Name)"
    ""
}
