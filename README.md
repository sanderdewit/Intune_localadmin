# Intune_localadmin
Intune Endpoint Analytics local admin group based solution.


Purpose of this script:
-
create_app.ps1 will create the AzureAD app registration with the group.read.all permissions.
This requires the following roles:
- Application administrator/developer: To create the app.
- Global administrator/privileged role administrator: to consent the api permissions

It is required to grant consent for all users.

This solution monitors the local administrators groups for (hybrid/AzureAD joined machines).
It does this based on AzureAD groups. Per device one AzureAD group should be created. The azautomation.ps1 script will help to automate this process.

It uses Intune Endpoint Analytics Proactive Remediations to schedule the localadmin_check script periodically.
Once a failure is detected it will run the remediate script to fix the issue.
Autopilot does leverage a default account during installation, so exception have been build in the prevent this script from executing during this phase.


The script expects the following users in the local administrators groups
- Local administrator account (should be disabled). It is always the sid ending with 500.
- Device administrator (MS default with AAD joined). 
- Company administrator (MS default with AAD joined) (also known as global administrator)
- Device specific group. This is based on the serialnumber of the device (similar to AutoPilot)

This scripts uses an AzureAD app registration to read out groups in AzureAD. it queries for a group specific with the devicename or serial number.
This group is then added to the local administrators groups. Other administrators except the one listed above, will be automatically removed.

Please review the parameters and entered your own information.
For the remediation script a log will be written in c:\programdata\scripts\localadmin.log
