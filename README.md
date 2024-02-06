# Sharepoint inventory

Collecting customer data is part of the job of a data scientist. Much of this data can be gathered through traditional means, but others involve creating specific tools for this work.

Today's script came from a client's need to inventory all of their Microsoft sites on their tenant to work on a file and obsolete version cleanup process. Since Microsoft's native monitoring tool only provides a general summary of sites, there was a need to create a PowerShell script to do this job for us.

It's necessary for the system administrator to grant access to the sites so that the script can perform the scan, and the scanning time depends on the quantity of files.