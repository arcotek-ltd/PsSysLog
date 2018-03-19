# PsSysLog
Finishes the job the Kiwi Syslog server starts

Quick PS script to resolve IP addresses into Whois data a IP GeoLocation.

You need to create an account and get an API key from https://jsonwhois.io/. If it asks for credit card details, just cancel the page by clicking another option. 250 request / month are free. I'm guessing they want you to go over and they can then charge you.

From Kiwi SysLog, select the rows you want, right-click and copy to clipboard.
Open up PsSysLog.ps1 and paste in the contents into the here string between `@' and '@`

```
$hereString=@'
#Paste Kiwi Rows on clipboard here.
'@
```

I'll tidy it up... one day.
