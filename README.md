# Intune_localadmin
Intune Endpoint Analytics local admin group based solution. It adds an AzureAD group to the local administrator group and monitors the local administrator so no other entries are added.


Purpose of this script:
-
create_app.ps1 will create the AzureAD app registration with the group.read.all permissions.
This requires the following roles:
- Application administrator/developer: To create the app.
- Global administrator/privileged role administrator: to consent the api permissions

It is required to grant consent for all users.

This solution monitors the local administrators groups for (hybrid/AzureAD joined machines).
It does this based on AzureAD groups. Per device one AzureAD group should be created. The azautomation.ps1 script will help to automate this process.

It uses Intune Endpoint Analytics Proactive Remediations to schedule the localadmin_check script periodically. https://endpoint.microsoft.com/#blade/Microsoft_Intune_Enrollment/UXAnalyticsMenu/proactiveRemediations
Once a failure is detected it will run the remediate script to fix the issue.
Autopilot does leverage a default account during installation, so exception have been build in the prevent this script from executing during this phase.
During the AutoPilot/PreDeployment phase, the security group will be added, but no users will be removed. It will not report an error in this case to keep the logging clean.


The script expects the following users in the local administrators groups
- Local administrator account (should be disabled). It is always the sid ending with 500.
- Device administrator (MS default with AAD joined). 
- Company administrator (MS default with AAD joined) (also known as global administrator)
- Device specific group. This is based on the serialnumber of the device (similar to AutoPilot)

This scripts uses an AzureAD app registration to read out groups in AzureAD. it queries for a group specific with the devicename or serial number.
This group is then added to the local administrators groups. Other administrators except the one listed above, will be automatically removed.

Please review the parameters and entered your own information.
For the remediation script a log will be written in c:\programdata\scripts\localadmin.log

Setup:
-
Go to the Intune portal (endpoint.microsoft.com).
Go to Reports, Endpoint Analytics, Proactive Remedations and choose create script package.
- Upload here the check script and the remediation script
- make sure the following settings are correct
- Run this script using the logged-on credentials: No
- Enforce script signature check: No (unless you signed the script with your own certificate, which is generally a good practice)
- Run script in 64-bit PowerShell: Yes
![image](https://user-images.githubusercontent.com/30201578/141688331-db7fee26-9f42-4e98-a4e4-7127fe1fc70e.png)


FAQ:
-
How do I use this information in my security monitoring?
- Via the Graph API you can query the devicehealth script. https://docs.microsoft.com/en-us/graph/api/intune-devices-devicehealthscript-get?view=graph-rest-beta
This will allow you to read out the status and link it the other events.

How do I find the SIDs for my global/device administrator?
- The script get-info.ps1 will provide all the information necessary to fill in the parameters.

The script doesn't work, what should I do?
- Make sure the Run script in 64-bit PowerShell is enabled.

When uploading the script, I notice some strange characters.
- Make sure the file is saved and uploaded in the UTF8 format.


