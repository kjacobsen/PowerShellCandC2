PowerShellCandC2
================

New PowerShell Malware Project

Simply drop SystemInformation.ps1 using your prefered persistence method. For ideas, look at the Excel file which has a macro to drop the script onto the system.

Each time SystemInformation.PS:
1. Collect bunch of info
2. Collect WinSCP Passwords
3. LSA Secrets dump
4. Windows Hash dump
5. Connect to C&C to download commands to run

Enjoy
