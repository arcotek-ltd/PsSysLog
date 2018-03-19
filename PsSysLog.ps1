$hereString = $hereString -replace '[ \t]','|'
#$hereString
$template = @"
{Date*:03-18-2018}|{[datetime]Time:12:54:39}|{LogLevel:Local7.Info}|10.100.40.1|101748:|.Mar|18|12:54:38.102:|%SEC-6-IPACCESSLOGP:|list|{Rule:INTERNET_INBOUND}|{Result:denied}|{protocol:udp}|{SrcIp:72.246.184.23}({SrcPort:3478})|({SrcInterface:Dialer0}|)|->|{Destination:84.92.212.165}({DstPort:54292}),|{PacketCount:1}|packet||
{Date*:03-18-2018}|{[datetime]Time:12:54:36}|{LogLevel:Local7.Info}|10.100.40.1|101747:|.Mar|18|12:54:34.990:|%SEC-6-IPACCESSLOGP:|list|{Rule:INTERNET_INBOUND}|{Result:denied}|{protocol:udp}|{SrcIp:104.47.152.166}({SrcPort:500})|({SrcInterface:Dialer0}|)|->|{Destination:84.92.212.165}({DstPort:500}),|{PacketCount:1}|packet||
"@

$Results = $hereString | ConvertFrom-String  -TemplateContent $template
$oData=@()

Function Get-ServiceNamesFromPortNumber($Port,$Protocol,$XmlObject)
{
    $oPort = $oXml.registry.record | Where-Object {($_.Number -eq $Port) -and ($_.Protocol -eq $Protocol)}
    $oPortCount = ($oPort | Measure-Object).Count
    If($oPortCount -gt 1)
    {
        Write-Host "Found '$oPortCount' records. Returning first 1."
        $oPort | select -First 1
    }
    elseif($oPortCount -eq 0)
    {
        Write-Host "No ports matching '$Port' on '$Protocol' found."
    }
    else
    {
        $oPort
    }
}


$url = "https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xml"
Write-Host "Loading XML from '$url'..."
$oXml = New-Object System.Xml.XmlDocument
$oXml.Load($url)


Function Get-WhoIs($ipAddress,$ApiKey)
{
    $uri = "https://api.jsonwhois.io/whois/ip?key=$ApiKey&ip_address=$ipAddress"
       
    Try
    {
        Invoke-RestMethod -Method Get -Uri $uri  -ErrorAction Stop
    }
    catch
    {
        Write-Error "Invoke-RestMethod error: $($_.Exception.Message)"
    }
        
    #-ContentType 'application/json' 
}

Function Get-IpGeoLocation($ipAddress,$ApiKey)
{
    $uri = "https://api.jsonwhois.io/geo?key=$ApiKey&ip_address=$ipAddress"
       
    Try
    {
        Invoke-RestMethod -Method Get -Uri $uri  -ErrorAction Stop
    }
    catch
    {
        Write-Error "Invoke-RestMethod error: $($_.Exception.Message)"
    }
        
    #-ContentType 'application/json' 
}

$ApiKey = "yourJsonwhois.comAPIkeyHere"



$Results | ForEach-Object {
    $Date = [datetime]::parseexact($_.Date, 'MM-dd-yyyy', $null)
    $oWhoIs = Get-WhoIs -ApiKey $ApiKey -ipAddress $_.SrcIp
    $oGeoLocation = Get-IpGeoLocation -ApiKey $ApiKey -ipAddress $_.SrcIp
    
    $srcPort = ($_.SrcPort).ToInt32($null)
    
    if($SrcPort -lt 49152)
    {
        Write-Host "Port '$($_.SrcPort)', is in the static range."
        $ServicePort = Get-ServiceNamesFromPortNumber -Port $_.SrcPort -Protocol $_.Protocol -XmlObject $oXml
    }
    else
    {
        Write-Host "Port '$($_.SrcPort)', is in the dynamic range."
        $ServicePort = [pscustomobject]@{
            Name = "Dynamic"
            description = "dynamic range"
        }
    }
    
    $oData += [pscustomobject]@{
        Date = $date.ToString('yyyy/MM/dd')
        Time = ($_.Time).toString('HH:mm:ss')
        LogLevel = $_.LogLevel
        Rule = $_.Rule
        Result = $_.Result
        Protocol = $_.Protocol
        SrcIp = $_.SrcIp
        SrcPort = $_.SrcPort
        PortName = $ServicePort.Name
        PortDescription = $ServicePort.description
        SrcInterface = $_.SrcInterface
        Destination = $_.Destination
        PacketCount = $_.PacketCount
        FQDN = (Resolve-DnsName $_.srcIp -QuickTimeout).NameHost | Out-String
        OwnerOrganisation = $oWhoIs.result.contacts.owner.organization
        OwnerName = $oWhoIs.result.contacts.owner.name
        Country = $oGeoLocation.country_name
        Location = "$($oGeoLocation.location_latitude),$($oGeoLocation.location_long)"
    }
}
$file = "C:\Temp\SysLog.html"
#$oData | Out-GridView






$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse; font-family: Tahoma, Geneva, sans-serif;font-size:0.9em;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED; color: white;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black; font-size:0.9em;}
TD a{width:100%;display:block;}
</style>
"@

#$oData | ConvertTo-Html -Head $Header -Property *,@{Label="Location";Expression={"<a href='$($_.location)'>$($_.location)</a>"}} | Out-File $file

$oHTML = $oData | ConvertTo-Html -Head $Header -Property Date,Time,LogLevel,Rule,Result,Protocol,@{L="Source IP";E={"<a href='http://www.findip-address.com/$($_.SrcIp)' target=_blank title='Further info...'>$($_.SrcIp)</a>"}},SrcPort,PortName,PortDescription,SrcInterface,Destination,PacketCount,FQDN,OwnerOrganisation,OwnerName,Country,Location,@{Label="Location";Expression={"<a href='http://maps.google.com/maps?q=$($_.location)' target=_blank>$($_.location)</a>"}} 

Add-Type -AssemblyName System.Web
[System.Web.HttpUtility]::HtmlDecode($oHTML) | Out-File $file

Invoke-Item -Path $file
