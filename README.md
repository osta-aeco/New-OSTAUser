# New-OSTAUser
Creates new AzureAD/Office365 users for OSTA-AECO.

```powershell
New-OSTAUser
	-FirstName <String[]>
	-LastName <String[]>
	-Title <String[]>
	-Department <String[GeneralAssembly|ExecutiveCouncil|BoardDirectors]>
	-LicenseType <String[Base|Enhanced]>
	[-OSTADomain <String[]>]
```

## Description
This PowerShell script is designed to simplify and automate user creation for OSTA-AECO in AzureAD and Office365.

## Installation
This version is designed to be compatible with Install-Module and the new GitHub Package Registry (GPR).

Copy and paste this code into a PowerShell session to install the script.

```powershell
Register-PSRepository -Name "OSTA-AECO" -SourceLocation "https://nuget.pkg.github.com/osta-aeco/index.json" -PublishLocation "https://github.com/osta-aeco" -InstallationPolicy Trusted; Install-Module "New-OSTAUser"
```

## How it works
This script is designed to work with PowerShell and PowerShell Core.

### AzureAD check
> This code section is only valid for PowerShell desktop users. It will *not* run for Cloud Shell users.

Checks to see whether the AzureAD PowerShell module is installed and current. If not, the script attempts to retrieve and install the module before importing it.

### Data integrity
This section ensures that all values passed through the mandatory parameters are free of leading and trailing spaces, and that all text is in title case.

### Password generation
Due to limitations with PowerShell Core, we need to use two different password-generation mechanisms depending on whether the user is running Windows PowerShell or PowerShell Core.

#### Windows PowerShell users
This section calls `[System.Web.Security.Membership]` to securely generate a random password with 8 characters, 2 of which are non-alphanumeric.

#### PowerShell Core users
This section randomly generates a password using `Get-Random`.

### User creation
This section creates the AzureAD account using the inputs specified by the user and assigns it to the correct AzureAD group to provision licenses.

> For **Windows PowerShell** users, the credentials are also copied to the clipboard.
