# IIS-Junk
Dumping ground for useful (and otherwise) IIS related scripts. YMMV.

What's Here?

TristanK's IIS Crudware. Don't assume there are no bugs; assume I tested these to the point of 
"it works on my system" and if you're lucky, maybe a couple of others.

## DodgyLogArchiver

From a simpler time when I knew even less PowerShell than today.

Takes IIS Log files associated with a website, and archives them. Optionally deletes Older-Than-X files too.

Tries to work out what log files live where automatically, from IIS config.

Initial version is not parameterized, so you need to edit the script so it does what you want. Let's call that
a feature for now.

I suggest running with

  $actuallyRemoveOldLocalFiles = $false
  $actuallyRemoveOldArchivedFiles = $false

at least the first time.

## Get-CruftyWebFiles

Scans websites, apps and vdirs for crufty files, and evil cruft (eg config backups containing passwords).

Produces .\Cruft.csv full of interesting and cryptic information, like word counts of "password" vs "pass"

Categorizes cruft with severity based on confidence of the word appearing. May enhance later.

Also identifies general sampleware based on names.

### The Obligatory Rant

_Cruft_ on a production web server is evil. It should not exist. Do you have cruft? If you have cruft, you
should work out where it is, and how to get rid of it, before something becomes crufty and important and
kills you.

Examples: 
 - I renamed web.config to web.config.txt because there was already a .bak.
 - Or I saved a web.config file I was editing in notepad and also the .bak and they became .txt too
 - Or we use .xml files for configuration, and they're very proper
 
.TXT and .XML file types are 99.9% considered _servable static files_ by IIS. So if one of those files
contains sensitive information - like a username and password - and someone manages to guess/infer the name 
and request it, you're *done*.
 
Backups should not be in your servable content area. Keep 'em outside the site's wwwroot.

