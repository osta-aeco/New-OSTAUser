<# Create-OSTAUser.ps1 | Arjun Dhanjal (Arjun.Dhanjal@osta-aeco.org) #> 

function New-OSTAUser {
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
	Param (
	    [string] $OSTADomain = "@osta-aeco.org",
		[Parameter(Mandatory=$True)]
		[string] $FirstName,
		[Parameter(Mandatory=$True)]
		[string] $LastName,
		[Parameter(Mandatory=$True)]
		[ValidateSet('Executive Council','Board of Directors','General Assembly')]
		[string] $Department,
		[Parameter(Mandatory=$True)]
		[string] $Title,
		[Parameter(Mandatory=$True)]
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

		if ($ModuleLoadCheck -eq $Null) {
		Write-Information -MessageData "INFO: Importing AzureAD PowerShell module."
		Import-Module AzureAD
		}
	}

	<# Check to see if AzureAD is connected. If not, prompt for credentials #>
	$AzureConnection = [Microsoft.Open.Azure.AD.CommonLibrary.AzureSession]::AccessTokens
	if ($AzureConnection -eq $null) {
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

	$Title = $TextInfo.ToTitleCase($Title)
	$Title = $Title.Trim()

	<# Set AzureAD Attributes #>
	$OSTAUser = $FirstName + "." + $LastName + $OSTADomain
	$DisplayName = $LastName + ", " + $FirstName
	$MailNickName = $FirstName + "." + $LastName

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

	Write-Information -MessageData "WAIT! Confirm that the following information is correct before proceeding."
	$InformationOrder = "FirstName", "LastName", "Title", "OSTADomain", "Department", "LicenseType"
	$Information = @(	@{ 'FirstName' = $FirstName }
						@{ 'LastName' = $LastName }
						@{ 'Title' = $Title }
						@{ 'OSTADomain' = $OSTADomain }
						@{ 'Department' = $Department }
						@{ 'LicenseType' = $LicenseType }
						) | Sort-Object { $InformationOrder.IndexOf($_.Result) }
	Write-Information -MessageData $Information

	<# Critical code #>
	if ($PSCmdlet.ShouldProcess("ShouldProcess?")) {

		<# Create user account and get its ObjectId #>
		$Information = "INFO: Creating AzureAD account for " + $OSTAUser
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