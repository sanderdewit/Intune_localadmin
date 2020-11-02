# Intune_localadmin
Intune Endpoint Analytics local admin group based solution.


Purpose of this script:
-
Monitoring the local administrators groups for (hybrid/AzureAD joined machines).
It does this based on AzureAD groups. Per device one AzureAD group should be created.

It uses Intune endpoint analytics to schedule the localadmin_check script periodically.
Once a failure is detected it will run the remediate script to fix the issue.

The script expects the following users in the local administrators groups
- Local administrator account (should be disabled)
- Device administrator (MS default with AAD joined)
- Company administrator (MS default with AAD joined) (also known as global administrator)
- Device specific group

This scripts uses an AzureAD app registration to read out groups in AzureAD. it queries for a group specific with the devicename or serial number.
This group is then added to the local administrators groups. Other administrators except the one listed above, will be automatically removed.

Please review the parameters and entered your own information.
For the remediation script a log will be written in c:\programdata\scripts\localadmin.log
