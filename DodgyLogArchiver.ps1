# log archiving sample script (c) 2016
# all care taken, no responsibility accepted by TristanK
# Note: ZERO ERROR HANDLING
# Tries to do an intelligent job of log archiving
# Designed to run on local IIS server
# Cheats by using XCOPY to un-set the archive bit
# so we know which files we've already copied
# (possible future "improvement" to go PS only)
# Also finds HTTPERR logs and does the same thing with them

function SafeName($unsafename){
    $safename = ""
    $safename = $unsafename.Replace("\","_")
    $safename = $safename.Replace("/","_")
    $safename = $safename.Replace(":","-")
    $safename
}
Import-Module WebAdministration

$archiveFolder = "G:\Storage\Logs"
$daysToKeepOnWebServer = 60
$daysToKeepInArchive = 900
$skipHTTPERR = $false
$actuallyRemoveOldLocalFiles = $true
$actuallyRemoveOldArchivedFiles = $true

$websites = get-website

if($skipHTTPERR -ne $true){
    #just in case someone's Really Clever and has moved HTTPERR from its default location
    # default location
    $httpErrFolder = "$env:windir\System32\LogFiles\"
    $httpParams = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\services\HTTP\Parameters" -ErrorAction SilentlyContinue
    if($null -ne $httpParams.ErrorLoggingDir){
        # if that worked, replace the default.
        $httpErrFolder = $httpParams.ErrorLoggingDir
    }

    $httpErrFolder = join-path $httpErrFolder -ChildPath "HTTPERR"
    
    $targetdir = "" + $env:COMPUTERNAME + "_0_HTTPERR"
    $targetfolder = Join-Path $archiveFolder -ChildPath $targetdir

    #initially, copy everything because it's safer to do so
    #plus, cheat with XCOPY because it's faster! (unsets Archive attrib)
    xcopy "$httpErrFolder\*.log" "$targetfolder" /M /I

    #then, consider whether we need to clean up the local server
    $files=Get-ChildItem "$httpErrFolder\*.log"
    foreach($file in $files){
        if($file.LastWriteTime.AddDays($daysToKeepOnWebServer) -lt [DateTime]::Now){
            "$file is too old to keep locally"
            if($actuallyRemoveOldLocalFiles){
                Remove-Item $file -Force
            }
        }
    }

    $storedlogs=Get-ChildItem "$targetfolder\*.log"
        foreach($oldLogFile in $storedlogs){
        if($oldLogFile.LastWriteTime.AddDays($daysToKeepInArchive) -lt [DateTime]::Now){
            "$oldLogFile is too old to keep stored"
            if($actuallyRemoveOldArchivedFiles){
                Remove-Item $oldLogFile -Force
            }
        }
    }
}

foreach ($website in $websites){
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
    xcopy "$dirToLookAt\*.log" "$targetfolder" /M /I

    #then, consider whether we need to clean up the local server
    $files=Get-ChildItem "$dirToLookAt\*.log"
    foreach($file in $files){
        if($file.LastWriteTime.AddDays($daysToKeepOnWebServer) -lt [DateTime]::Now){
            "$file is too old to keep locally"
            if($actuallyRemoveOldLocalFiles){
                Remove-Item $file -Force
            }
        }
    }

    $storedlogs=Get-ChildItem "$targetfolder\*.log"
        foreach($oldLogFile in $storedlogs){
        if($oldLogFile.LastWriteTime.AddDays($daysToKeepInArchive) -lt [DateTime]::Now){
            "$oldLogFile is too old to keep stored"
            if($actuallyRemoveOldArchivedFiles){
                Remove-Item $oldLogFile -Force
            }
        }
    }
}

