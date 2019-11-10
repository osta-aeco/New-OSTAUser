<# New-OSTAUser.ps1 | Arjun Dhanjal (Arjun.Dhanjal@osta-aeco.org) #>

<#
.SYNOPSIS
Creates a new AzureAD/Office 365 user for OSTA-AECO.

.DESCRIPTION
Creates a new AzureAD/Office 365 user for OSTA-AECO.
Compatible with both Windows PowerShell and PowerShell Core.

.PARAMETER FirstName
Specifies the first name of the user object in AzureAD. Will comprise the user's display name.

.PARAMETER LastName
Specifies the last name of the user object in AzureAD. Will comprise the user's display name.

.PARAMETER JobTitle
Specifies the user's job title in AzureAD.

.PARAMETER Department
Specifies the user's department in AzureAD.

.PARAMETER LicenseType
Specifies the user's license type.

.EXAMPLE
PS> New-OSTAUser -FirstName John -LastName Doe -JobTitle "Public Affairs Coordinator" -Department ExecutiveCouncil -LicenseType Enhanced

.EXAMPLE
PS> New-OSTAUser -fn John -ln Doe -t "Public Affairs Coordinator" -dt "ExecutiveCouncil" -lt Enhanced

.LINK
https://github.com/osta-aeco/New-OSTAUser
#>

function New-OSTAUser {
	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='High')]
	Param (
		[Alias('domain')]
		[string] $OSTADomain = "@osta-aeco.org",
		[Parameter(Mandatory=$True)]
		[Alias('fn','first')]
		[string] $FirstName,
		[Parameter(Mandatory=$True)]
		[Alias('ln','last')]
		[string] $LastName,
		[Parameter(Mandatory=$True)]
		[Alias('Title','ti','t')]
		[string] $JobTitle,
		[Parameter(Mandatory=$True)]
		[Alias('dept','dt')]
		[ValidateSet('ExecutiveCouncil','BoardDirectors','GeneralAssembly')]
		[string] $Department,
		[Parameter(Mandatory=$True)]
		[Alias('lic','lt','license')]
		[ValidateSet('Base','Enhanced')]
		[string] $LicenseType
		)

	<# Change user's $InformationPreference for this session #>
	$UserInfoPref = $InformationPreference
	$InformationPreference = "Continue"

	<# Check for Azure Cloud Shell and PS Core #>
	if ($PSVersionTable.OS -Like '*Linux*') {
		$CloudShell = [bool] $True
	}
	else {
		$CloudShell = [bool] $False
	}

	if ($PSVersionTable.PSEdition -Like 'Core') {
		$PSCore = [bool] $True
	}
	else {
		$PSCore = [bool] $False
	}

	<# AzureAD PS Module. This section checks to see whether the AzureAD module is installed and current. If the module doesn't exist or isn't current, the module will be installed. #>
	if ($CloudShell -eq $False) {
		Write-Information -MessageData "INFO: Checking whether AzureAD module is installed."
		$AzureADVersionCheck = [int](Get-Module -Name AzureAD).Version.Major

		if ($AzureADVersionCheck -lt "2") {
			Write-Warning -Message "AzureAD PowerShell module is not installed. Installing now." -WarningAction Continue
			Install-Module AzureAD
		}

		$ModuleLoadCheck = (Get-Module "AzureAD").Name

		if ($Null -eq $ModuleLoadCheck) {
			Write-Information -MessageData "INFO: Importing AzureAD PowerShell module."
			Import-Module AzureAD
		}
	}

	<# Check to see if AzureAD is connected. If not, prompt for credentials #>
	$AzureConnection = [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens
	if ($Null -eq $AzureConnection) {
		Write-Information -MessageData "INFO: Authenticating to AzureAD."
		Connect-AzureAD
		$AzureConnection = [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens
	}

	<# Ensure inputs are in Title Case and don't have any leading or trailing spaces #>
	$TextInfo = (Get-Culture).TextInfo

	$FirstName = $TextInfo.ToTitleCase($FirstName)
	$FirstName = $FirstName.Trim()

	$LastName = $TextInfo.ToTitleCase($LastName)
	$LastName = $LastName.Trim()

	$JobTitle = $TextInfo.ToTitleCase($JobTitle)
	$JobTitle = $JobTitle.Trim()

	<# Set AzureAD Attributes #>
	$MailNickName = $FirstName.Replace(' ','') + "." + $LastName.Replace(' ','')
	$OSTAUser = $MailNickname + $OSTADomain
	$DisplayName = $LastName + ", " + $FirstName

	if ($Department -eq "ExecutiveCouncil") { $Department = "Executive Council" }
	elseif ( $Department -eq "BoardDirectors") { $Department = "Board of Directors"}
	elseif ( $Department -eq "GeneralAssembly" ) { $Department = "General Assembly" }
	else { $Department = $Department }

	<# Generate a random password. Uses System.Web AssemblyType if PSVersion != Core, otherwise uses alternate password generation #>
	Write-Information -MessageData "INFO: Randomly generating a password."

	$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile

	if ($CloudShell -eq $False) {
		Add-Type -AssemblyName System.Web
		$PasswordProfile.Password = [System.Web.Security.Membership]::GeneratePassword(8,2)
		} else {
			$Length = 8
			$Types = @{
				uppers = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
				lowers = 'abcdefghijkmnopqrstuvwxyz'
				digits = '23456789'
				symbols = '_-+=@$%'
			}

			$four = foreach($thisType in $Types.Keys) {
				Get-Random -Count 1 -InputObject ([char[]]$types[$thisType])
			}

			[char[]]$allSupportedChars = $Types.Values -join ''

			$theRest = Get-Random -count ($length - ($Types.Keys.Count)) -InputObject $allSupportedChars

			$PasswordProfile.Password = ($four + $theRest -join '') | Sort-Object {Get-Random}
		}

		<# Confirm user inputs #>
		Write-Information -MessageData "WAIT! Confirm that the following information is correct before proceeding."
		$InformationOrder = "FirstName", "LastName", "Title", "OSTADomain", "Department", "LicenseType"
		$Information = @(	@{ 'FirstName' = $FirstName }
			@{ 'LastName' = $LastName }
			@{ 'JobTitle' = $JobTitle }
			@{ 'OSTADomain' = $OSTADomain }
			@{ 'Department' = $Department }
			@{ 'LicenseType' = $LicenseType }
			) | Sort-Object { $InformationOrder.IndexOf($_.Result) }
		Write-Information -MessageData $Information

		<# Critical code #>
		if ($PSCmdlet.ShouldProcess("$OSTAUser in AzureAD")) {

			<# Create user account and get its ObjectId #>
			$Information = "INFO: Creating AzureAD account " + $OSTAUser
			Write-Information -MessageData $Information
			New-AzureADUser -AccountEnabled $True -UserPrincipalName $OSTAUser -MailNickName $MailNickname -DisplayName $DisplayName -UsageLocation CA -GivenName $FirstName -Surname $LastName -Department $Department -PasswordProfile $PasswordProfile -Verbose

			$UserObjectId = (Get-AzureADUser -ObjectId $OSTAUser).ObjectId

			<# Add user account to correct Office365 licensing group #>
			$BaseLicense = (Get-AzureADGroup -SearchString "Licensing_Office365_Base").ObjectId
			$EnhancedLicense = (Get-AzureADGroup -SearchString "Licensing_Office365_Enhanced").ObjectId

			if ($LicenseType -eq "Base") {
				$Information = "Assigning user " + $DisplayName + " to AzureAD group Licensing_Office365_Base."
				Write-Information -MessageData $Information
				Add-AzureADGroupMember -ObjectId $BaseLicense -RefObjectId $UserObjectId -Verbose
				} elseif ($LicenseType -eq "Enhanced") {
					$Information = "Assigning user " + $DisplayName + " to AzureAD group Licensing_Office365_Enhanced."
					Write-Information -MessageData $Information
					Add-AzureADGroupMember -ObjectId $EnhancedLicense -RefObjectId $UserObjectId -Verbose
				}

				<# Copy credentials to clipboard #>
				if ($PSCore -eq $False) {
					$Clipboard = "Your myOSTA account has been created. Log in at https://myosta.osta-aeco.org. `r`nUsername: " + $OSTAUser + " `r`nPassword: " + $PasswordProfile.Password
					Set-Clipboard $Clipboard
				}

				<# Output user information #>
				$Information = "An account has been created for " + $DisplayName + ". Please provide these credentials to the user for sign-in at https://myosta.osta-aeco.org. " + $FirstName + " will be required to change their password when they sign in for the first time."
				Write-Information -MessageData $Information
				$Information = "Email address: " + $OSTAUser
				Write-Information -MessageData $Information
				$Information = "Temporary password: " + $PasswordProfile.Password

				if ($PSCore -eq $False) {
					$Information = $DisplayName + "'s credentials have been copied to your system clipboard."
					Write-Information -MessageData $Information
				}
			}
			<# Revert user's $InformationPreference #>
			$InformationPreference = $UserInfoPref
		}
