# IIS-Junk
Dumping ground for useful (and otherwise) IIS related scripts. YMMV.

What's Here?

_TristanK's IIS Crudware_. Don't assume there are no bugs; assume I tested these to the point of 
"it works on my system" and if you're lucky, maybe a couple of others.

## DodgyLogArchiver

Takes IIS Log files associated with a website, and archives them. Optionally deletes Older-Than-X files too.

Tries to work out what log files live where automatically, from IIS config.

I suggest running _without_ -RemoveOldLogFiles and -RemoveOldArchivedFiles   - at least until you're comfortable
with how it works and handles retention. And have backups of your archives if necessary.

Designed to be run from a scheduled task each day.


## Get-CruftyWebFiles

Scans IIS websites, apps and vdirs for _crufty_ files, and _evil cruft_ like config backups containing passwords.

Produces .\Cruft.csv - full of interesting and cryptic information, like word counts of "password" vs "pass".

Categorizes cruft with _severity_ based on confidence of the word appearing being _evil_. May enhance later.

Also identifies general _sampleware_ based on names.

### The Obligatory Rant

_Cruft_ on a production web server is evil. It should not exist.

Cruft could be _sampleware_, unused libraries, old versions of things, previous apps stored in "v2" folders,
readme files, sample.txt files, demo files which come with the developer package the dev just unzipped into
the web folder and never cleaned up.

**Do you have cruft?** If you do have cruft, you should work out where it is, and how to get rid of it, 
before something becomes crufty *and important* and kills you.

#### Examples of Bad Cruft Which Might Kill You: 
 - A web.config renamed to web.config.txt because there was already a .bak!
 - Or a saved web.config file that was edited in notepad... and maybe also the .bak... and they became .txt too
 - Or .xml files used for configuration information, but aren't .config files... they're .xml files... so...
 
.TXT and .XML file types are 99.9% considered _servable static files_ by IIS. So if one of the above files
- or any sampleware for that matter - contains sensitive information - like a **username and password** - and 
someone manages to guess/infer the URL and request it, you're potentially *done*.
 
Backups shouldn't be stored in a servable content area. Keep 'em outside the site's wwwroot.

