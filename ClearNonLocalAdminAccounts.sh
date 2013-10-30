#!/bin/bash

# Clear all non local admin accounts script
# Script is based off work at the following webpage:
# http://www.macos.utah.edu/documentation/authentication/dscl.html

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

# Set up needed variables here

macname=$( scutil --get ComputerName | awk '{print substr($0,length($0)-3,4)}' )
OIFS=$IFS
IFS=$'\n'

# Special section to set up globally exempted user accounts

exempt=( uadmin sshadmin Shared Guest .localized libadmin ualkiosk )

# Mount fileshare where local admin file is kept.

mkdir /Volumes/SYSVOL
mount_smbfs -o nobrowse //'DOMAIN;username:password'@domain.local/SYSVOL /Volumes/SYSVOL

# Read localadmin file to LOCADMIN variable. We'll do all our processing from that.

LOCADMIN=$( cat /Volumes/SYSVOL/domain.local/localadmin/localadmins.txt)

# Unmount and clean up fileshare.

diskutil umount force /Volumes/SYSVOL

while read -r LOCADMIN
do

# Because the file contains bash reserved characters, we must remove them before processing.
# This will cause the script to ignore the line totally.

   line=$( echo ${LOCADMIN//[*]/} )

# Grab the name of the computer from the current line of the file

   compname=$( echo "${line}" | cut -d : -f 1 | awk '{print substr($0,length($0)-3,4)}' )
   
# Find out how many users are listed by counting the commas
   
   usercount=$( echo $((`echo ${line} | sed 's/[^,]//g' | wc -m`-1)) )

# Does the current computer name match the one in the file?

   if [ "$macname" = "$compname" ];
   then

      for (( loop=0; loop<=usercount; loop++ ))
      do

         field=$(($loop + 1))
	     username=$( echo "${line}" | cut -d : -f 4 | cut -d "," -f ${field} | cut -c11- | sed "s/$(printf '\r')\$//" )

      done             
   fi

done << EOF
$LOCADMIN
EOF

exempt[$[${#exempt[@]}]]=`echo $username`

# Find exempt array length

tLen=${#exempt[@]}

# Delete accounts apart from those in the exclusion array

# Read the user account from /users in order.

for Account in `ls /Users`
do

# Does the flag file exist? If so, delete it.

   if [ -f /var/tmp/ualadminexempt ];
   then
      rm /var/tmp/ualadminexempt
   fi

# Loop around the exemption array to check current user.

   for (( i=0; i<${tLen}; i++ ));
   do

# Create the exemption flag file if account matches. We do this because of BASH's local variable limitation.

      if [ "${exempt[i]}" == $Account ];
      then
         touch /var/tmp/ualadminexempt
      fi

   done

# If exempt file doesn't exist, delete the account.

   if [ ! -f /var/tmp/ualadminexempt ];
   then
      dscl . delete /Users/$Account > /dev/null 2>&1
	  rm -rf /Users/$Account
   fi

# Read the next username.

done

# Let's set IFS back to the way it was.

export IFS=$OIFS

# Clean up any left over flag files

if [ -f /var/tmp/ualadminexempt ];
then
   rm /var/tmp/ualadminexempt
fi

# Clean up the system audio plist file with previously deployed master plist file

cp -fp /usr/local/scripts/com.apple.audio.SystemSettings.plist /Library/Preferences/Audio/

# All done!
