FUNCTION Get-Shares {
    <#
    .Synopsis 
        Gets the shares configured on a given system.

    .Description 
        Gets the shares configured on a given system.

    .Parameter Computer  
        Computer can be a single hostname, FQDN, or IP address.

    .Parameter Fails  
        Provide a path to save failed systems to.

    .Example 
        Get-Shares 
        Get-Shares SomeHostName.domain.com
        Get-Content C:\hosts.csv | Get-Shares
        Get-Shares $env:computername
        Get-ADComputer -filter * | Select -ExpandProperty Name | Get-Shares

    .Notes 
        Updated: 2017-09-01
        LEGAL: Copyright (C) 2017  Anthony Phipps
        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.
    
        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <http://www.gnu.org/licenses/>.
    #>

    PARAM(
    	[Parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        $Computer = $env:COMPUTERNAME,
        [Parameter()]
        $Fails
    );

	BEGIN{

        $datetime = Get-Date -Format "yyyy-MM-dd_hh.mm.ss.ff";
        Write-Information -MessageData "Started at $datetime" -InformationAction Continue;

        $stopwatch = New-Object System.Diagnostics.Stopwatch;
        $stopwatch.Start();

        $total = 0;

        $PermissionFlags = @{
            0x1     =     "Read-List";
            0x2     =     "Write-Create";
            0x4     =     "Append-Create Subdirectory";                  	
            0x20    =     "Execute file-Traverse directory";
            0x40    =     "Delete child"
            0x10000 =     "Delete";                     
            0x40000 =     "Write access to DACL";
            0x80000 =     "Write Owner"
        };

        class EnumeratedShare
        {
            [String] $Computer
            [Datetime] $DateScanned
            [String] $ComputerName
            [String] $Name
            [String] $Path
            [String] $Description
            [String] $TrusteeName
            [String] $TrusteeDomain
            [String] $TrusteeSID
            [String] $AccessType
            [String] $AccessMask
            [String] $Permissions
        };
	};

    PROCESS{

        $Computer = $Computer.Replace('"', '');  # get rid of quotes, if present

        $Shares = $null;
        $Shares = Get-WmiObject -class Win32_LogicalShareSecuritySetting -ComputerName $Computer -ErrorAction SilentlyContinue;

        if ($Shares) {
            $OutputArray = $null;
            $OutputArray = @();

            foreach ($Share in $Shares) {

                $ShareName = $Share.Name;

                $DACLs = $Share.GetSecurityDescriptor().Descriptor.DACL;

                foreach ($DACL in $DACLs) {

                    $TrusteeName = $DACL.Trustee.Name;
                    $TrusteeDomain = $DACL.Trustee.Domain;
                    $TrusteeSID = $DACL.Trustee.SIDString;

                    # 1 Deny; 0 Allow
                    if ($DACL.AceType) 
                        { $Type = "Deny" }
                    else 
                        { $Type = "Allow" };
        
                    $SharePermission = $null;

                    # Convert AccessMask to human-readable format
                    foreach ($Key in $PermissionFlags.Keys) {

                        if ($Key -band $DACL.AccessMask) {
                                          
                            $SharePermission += $PermissionFlags[$Key];       
                            $SharePermission += "; ";
                        };
                    };

                    $output = $null;
                    $output = [EnumeratedShare]::new();

                    $output.Computer = $Computer;
                    $output.DateScanned = Get-Date -Format u;
                    $output.ComputerName = $ShareSecurity.PSComputerName;
                    $output.Name = $Share.Name;
                    $output.Path = $Share.Path;
                    $output.Description = $Share.Description;
                    $output.TrusteeName = $TrusteeName;
                    $output.TrusteeDomain = $TrusteeDomain;
                    $output.TrusteeSID = $TrusteeSID;
                    $output.AccessType = $Type;
                    $output.AccessMask = $DACL.AccessMask;
                    $output.Permissions = $SharePermission;

                    $OutputArray += $output;
                };
            };

            Return $OutputArray;
        }

        else { # System was not reachable

            if ($Fails) { # -Fails switch was used
                Add-Content -Path $Fails -Value ("$Computer");
            }
            else{ # -Fails switch not used
                            
                $output = $null;
                $output = [EnumeratedShare]::new();
                $output.Computer = $Computer;
                $output.DateScanned = Get-Date -Format u;

                return $output;
            };
        };
         
        $elapsed = $stopwatch.Elapsed;
        $total = $total+1;
            
        Write-Information -MessageData "System $total `t $ThisComputer `t Time Elapsed: $elapsed" -InformationAction Continue;

    };
};
