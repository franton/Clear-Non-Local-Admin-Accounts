#!/bin/bash

# Clear all non local admin accounts script

# Author: r.purves@arts.ac.uk
# Version 1.0 25-10-2012 : Initial version
# Version 1.1 26-10-2012 : Allow specifying of the local admin account name
# Version 1.2 10-01-2013 : Forced all logging to a file to stop Casper throwing tons of emails
# Version 1.3 11-01-2013 : Disabled the group membership deletion as it was throwing errors

# Version 2.0 17-01-2013 : Vastly simplified script to delete user record THEN user folder

# Version 2.1 19-03-2013 : Now will scan for exempted admin accounts and spare them. Same
#						   process as the add user as admin account script.
# Version 2.2 22-03-2013 : Changed processing of localadmin file to match AddUserAsAdmin script.
#                          This was due to processing bugs that had been copied from that script.
# Version 2.3 26-06-2013 : Added line to replace system audio preference file as this was clogging up with deleted users.
# Version 2.4 10-09-2013 : Added read only user account for mounting sysvol share
# Version 2.5 22-11-2013 : Removed line to replace system audio preference file as this was clogging up with deleted users.
# Version 2.6 20-02-2014 : Modified account deletion to use JAMF binary. Old commands left in but commented out.
# Version 3.0 28-03-2014 : Now uses JSS extension attribute AND current admins for excluded user list.

# This section reads the current local admin users into $currentadmins

# Read admin group membership into variable

localadmins=$( dscl . -read /Groups/admin GroupMembership | cut -c18- )

# Read that variable into an array

read -a currentadmins <<< $localadmins

# End of current local admin section

# This section reads the admin users extension attribute into $extadminusers

# Set up needed variables here

ethernet=$(ifconfig en0|grep ether|awk '{ print $2; }')
apiurl=`/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url`
apiuser="apiuser"
apipass="password"

# Grab user info from extension attribute for target computer and process.

# Retrieve the computer record data from the JSS API

cmd="curl --silent --user ${apiuser}:${apipass} --request GET ${apiurl}JSSResource/computers/macaddress/${ethernet//:/.}"
hostinfo=$( ${cmd} )

# Reprogram IFS to treat commas as a newline

OIFS=$IFS
IFS=$','

# Now parse the data and get the usernames

adminusers=${hostinfo##*Admin Users\<\/name\>\<value\>}
adminusers=${adminusers%%\<\/value\>*}

# If the Ext Attribute is blank, we need to test for that and blank the variable if so.
# We'll get a large amount of xml in place if we don't!

test=$( echo $adminusers | cut -c 3-5 )

if [ $test == "xml" ];
then
   unset adminusers
fi

# End of extension attribute section

# Special section to set up globally exempted user accounts. Read $4 for policy specified accounts.

exempt=( "$adminusers",account1,account2,Shared,Guest,".localized","$4" )

# Read exempt users into array

read -a extadminusers <<< "$exempt"

# About to merge our two array lists together. Set IFS to cope with newlines only.

IFS=$'\n'

# Merge the two arrays into one array to rule them all. $exemptusers

exemptusers=(`for R in "${currentadmins[@]}" "${extadminusers[@]}" ; do echo "$R" ; done | sort -du`)

# Reset IFS back to normal

IFS=$OIFS

# Find exempt array length

tLen=${#exemptusers[@]}

# Delete accounts apart from those in the exclusion array

# Read the user account from /users in order.

for Account in `ls /Users`
do

echo "Processing account name: "$Account

# Does the flag file exist? If so, delete it.

   if [ -f /var/tmp/ualadminexempt ];
   then
      rm /var/tmp/ualadminexempt
   fi

# Loop around the exemption array to check current user.

   for (( i=0; i<${tLen}; i++ ));
   do

# Create the exemption flag file if account matches. We do this because of BASH's local variable limitation.

      if [ "${exemptusers[i]}" == $Account ];
      then
      	 echo "Exempting user account: "$Account
         touch /var/tmp/ualadminexempt
      fi

   done

# If exempt file doesn't exist, delete the account.

   if [ ! -f /var/tmp/ualadminexempt ];
   then
		echo "Deleting user account: "$Account
		jamf deleteAccount -username $Account -deleteHomeDirectory
   fi

# Read the next username.

done

# Clean up any left over flag files

if [ -f /var/tmp/ualadminexempt ];
then
   rm /var/tmp/ualadminexempt
fi

# All done!

exit 0
