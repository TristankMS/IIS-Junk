# CruftyWebFiles
# All care, no responsibility accepted by TristanK
# 1.0 Initial 2016-11-24
# 
# Tries to identify extraneous stuff on an IIS web server in servable content areas
#    i.e. those which are linked from apps attached to a website
# Hopefully doesn't become part of the cruft afterwards
#
# Cruft isn't always fatal, but it's always evil.
#
# doesn't have loop detection yet, so if it runs forever, it's your fault. Ctrl+C.

param(
    [string]
    $OutputCSVFile = ".\Cruft.csv"
)

function StoreCruft
{	
	param
	(
		[string] $Website,        
        $Application,
        $FileName,
		$ServableName,
        $Severity,
        $Issue,
        $Notes
	)
	# build PS object for pipeline
    $Object = New-Object PSObject                                       
           $Object | add-member Noteproperty Website          $Website
           $Object | add-member Noteproperty Application      $Application
           $Object | add-member Noteproperty FileName         $FileName      
           $Object | add-member Noteproperty ServableName     $ServableName
           $Object | add-member Noteproperty Severity         $Severity
           $Object | add-member Noteproperty Notes            $Notes
    
    if([string]::IsNullOrEmpty($OutputCSVFile)){
        $Object
    }
    else{
        $Object | Export-Csv -Append -NoTypeInformation -Path $OutputCSVFile 
        $Object
    }
}

# Apps - list of websites (/ app) or apps to scan. Must reside on local box. If not set, scans all.
function Get-CruftyFiles{
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Alias('Path')]
    [String[]]$FolderPath
    ) 

    process {
    $FolderPath = [System.Environment]::ExpandEnvironmentVariables($FolderPath)
    $servableFileTypes=("txt","xml")  # maybe INF, but not .ini, .config by default
    $Severities = @{"Critical" = 0; "High" = 1; "Medium" = 2; "Low" = 3; "Informational" = 4; "Other" = 5}
    $passwordy = @{"password" = $Severities["High"]; "pwd" = $Severities["High"]; "pass" = $Severities["Medium"] ; "username" = $Severities["High"]; "user" = $Severities["Medium"] }
    # higher confidence it's a bad word = higher severity. Still needs a human to look at it.
    $extracrufty=("readme.*","sample.*","example.*","demo.*") # can replace with TXT etc if too noisy
        
       foreach($path in $FolderPath)
       {
           Write-Host -ForegroundColor Black -BackgroundColor DarkGray $path

           # look for serious problem file types - possible leaks of config / passwords / etc
           foreach ($filetype in $servableFileTypes){
                $coll = gci -Path $path -Filter "*.$filetype" -Recurse
                #write-host $path $coll
                foreach($item in $coll){
                    Write-Host $item.FullName
                    $item | Add-Member -Name "Severity" -MemberType NoteProperty -Value $Severities["Informational"]
                    $item | Add-Member -Name "BadData" -MemberType NoteProperty -Value ""
                    foreach($searchitem in $passwordy.Keys){
                        $badInfo = Select-String -Path $item.FullName -Pattern $searchitem -AllMatches # (remove -Allmatches for speed over accuracy)
                        $item.BadData += "$searchitem=$($badInfo.Matches.Count);"
                        if($badInfo.Matches.Count -gt 0){
                            if($item.Severity -eq ""){
                                $item.Severity = $passwordy[$searchitem]
                            }
                            if($item.Severity -gt $searchitem.Value){
                                $item.Severity = $passwordy[$searchitem]
                            }
                        }
                    }
                }
                $coll
           }# end foreach

           foreach ($filename in $extracrufty){
                $coll = gci -Path $path -Filter "$filename" -Recurse
                #write-host $path $coll
                foreach($item in $coll){
                    Write-Host $item.FullName
                    $item | Add-Member -Name "Severity" -MemberType NoteProperty -Value $Severities["Low"]
                    $item | Add-Member -Name "BadData" -MemberType NoteProperty -Value "LooksCrufty"
                }
                $coll
           }# end foreach
       }
    }
}
$sites = Get-Website # "Default Web Site" # TESTING ONLY
foreach ($site in $sites){
    Write-host -ForegroundColor Black -BackgroundColor Green $site.name
    #get first site binding to hopefully provide a request framework
    $requestablehopefully=$site.bindings.Collection[0].bindingInformation.ToString()
    # todo: Binding interpreter to pick most-likely-servable binding and convert to URL
    $apps = Get-WebApplication -Site $site.name 
    $vdirs = Get-WebVirtualDirectory -Site $site.name
    # do the site itself, root app isn't an app in PS land.
    $basePath =  [System.Environment]::ExpandEnvironmentVariables($site.physicalPath.ToString())
    $cruftyFiles = $site.physicalPath.ToString() | Get-CruftyFiles
        foreach($cruftyFile in $cruftyFiles){
        $relativePath = $cruftyFile.FullName.ToLower().Replace($basePath.ToLower(),"");
        $relativePath = $relativePath.Replace("\","/");
        $srvable = "$($requestablehopefully)$relativePath"
        StoreCruft -Website $site.name -Application "/" -FileName $cruftyFile.FullName -ServableName "$srvable" -Severity $cruftyFile.Severity -Notes $cruftyFile.BadData
    }
    foreach($app in $apps){
        $cruftyFiles = $app.physicalPath.ToString() | Get-CruftyFiles
        foreach($cruftyFile in $cruftyFiles){
            $basePath =  [System.Environment]::ExpandEnvironmentVariables($app.physicalPath.ToString())
            $relativePath = $cruftyFile.FullName.ToLower().Replace($basePath.ToLower(),"");
            $relativePath = $relativePath.Replace("\","/");
            $srvable = "$($requestablehopefully)$($app.path)$($relativePath)"
            StoreCruft -Website $site.name -Application $app.path -FileName $cruftyFile.FullName -ServableName "$srvable" -Severity $cruftyFile.Severity -Notes $cruftyFile.BadData
        }
    }
    foreach($app in $vdirs){ #cheating
        $cruftyFiles = $app.physicalPath.ToString() | Get-CruftyFiles
        foreach($cruftyFile in $cruftyFiles){
            $basePath =  [System.Environment]::ExpandEnvironmentVariables($app.physicalPath.ToString())
            $relativePath = $cruftyFile.FullName.ToLower().Replace($basePath.ToLower(),"");
            $relativePath = $relativePath.Replace("\","/");
            $srvable = "$($requestablehopefully)$($app.path)/$($relativePath)"
            StoreCruft -Website $site.name -Application $app.path -FileName $cruftyFile.FullName -ServableName "$srvable" -Severity $cruftyFile.Severity -Notes $cruftyFile.BadData
        }
    }
}