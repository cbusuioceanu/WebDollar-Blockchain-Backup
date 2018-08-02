#!/bin/bash

# You need a Dropbox account and an API key
# This script should be used with CRON
# Before first time run, make sure you input your values for linuxuser=, mainwebdfolder= and pm2dropboxport= !
# If you have to reset the main webdollar dropbox folder, just remove the .blockchaindbs file located @ /home/$linuxuser/.blockchaindbs
# sudo crontab -e
# Paste: 0 */6 * * * /bin/bash /home/enter_your_user/blockcharch.sh > /home/enter_your_user/blockcharchiver.log
# ^ CRON at every 6 hours ^

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games # if CRON doesn't run this script correctly, please change the PATH to your system env PATH (run echo $PATH to get it)

#### COLOR SETTINGS ####
black=$(tput setaf 0 && tput bold)
red=$(tput setaf 1 && tput bold)
green=$(tput setaf 2 && tput bold)
yellow=$(tput setaf 3 && tput bold)
blue=$(tput setaf 4 && tput bold)
magenta=$(tput setaf 5 && tput bold)
cyan=$(tput setaf 6 && tput bold)
white=$(tput setaf 7 && tput bold)
blackbg=$(tput setab 0 && tput bold)
redbg=$(tput setab 1 && tput bold)
greenbg=$(tput setab 2 && tput bold)
yellowbg=$(tput setab 3 && tput bold)
bluebg=$(tput setab 4 && tput dim)
magentabg=$(tput setab 5 && tput bold)
cyanbg=$(tput setab 6 && tput bold)
whitebg=$(tput setab 7 && tput bold)
stand=$(tput sgr0)
###

### System dialog VARS
showinfo="$green[info]$stand"
showerror="$red[error]$stand"
showexecute="$yellow[running]$stand"
showok="$magenta[OK]$stand"
showdone="$blue[DONE]$stand"
showinput="$cyan[input]$stand"
showwarning="$red[warning]$stand"
showremove="$green[removing]$stand"
shownone="$magenta[none]$stand"
redhashtag="$redbg$white#$stand"
abortfm="$cyan[abort for Menu]$stand"
###

### CHANGE_THESE_VALUES_TO_YOURS
linuxuser="webd1" # change this to your Linux UserName | do not change order!
mainwebdfolder="Webddropbox" # This location should have blockchainDB3 - do not use a location with blockchainDB380 or blockchainDB3PORT etc - backed up blockchain won't be compatible with other instances
pm2dropboxport="8888"		       #^ You should make a separate Dropbox webdollar-node because when using the cron service to start this script, the process of pm2 must be stopped and restarted after backup
                                       #^ Do not use a production WebDollar-Full-Node for this. Uptime is important!
###

### GENERAL_VARS
DEBUG="1" # change this to 1 if debugging is needed
dropbox_config_file="/home/$linuxuser/.dropbox_uploader"
ftp_config_file_server1="/home/$linuxuser/.ftp_uploader1"
ftp_config_file_server2="/home/$linuxuser/.ftp_uploader2"
TMP_DIR="/tmp"
LOCAL_FILE_SRC="/home/$linuxuser/$mainwebdfolder/blockchainDB3.tar.gz"
SHA_FILE_SRC="/home/$linuxuser/$mainwebdfolder/blockchainDB3.sha1"
DROPBOX_DST="/blockchainDB3.tar.gz" # must start with /
fastsearch="/home/$linuxuser/.blockchaindbs"
db3chunksfolder="/home/$linuxuser/db3chunks"
response_code_100="^HTTP/1.1 100 CONTINUE"
response_code_200="^HTTP/1.1 200 OK"
whichpm2=$(which pm2)
whichsplit=$(which split)
###

# CHECKING FOR DROPBOX_AUTH FILE
if [[ -e $dropbox_config_file ]]; then

	# Check if config file has the OAUTH_ACCESS_TOKEN
	if [[ ! $(grep "OAUTH_ACCESS_TOKEN" $dropbox_config_file) == "OAUTH_ACCESS_TOKEN" ]]; then
        	echo "$showok Dropbox OAUTH_ACCESS_TOKEN found @ $dropbox_config_file..."
	fi

else # first time configuration for dropbox uploader

	echo -e "\n$showexecute Dropbox Upload first time configuration...\n"

	read -e -r -p "$showinput Asuming you already have a Dropbox App, enter the Access Token: " OAUTH_ACCESS_TOKEN

	read -e -r -p "$showinfo The access token is $OAUTH_ACCESS_TOKEN. Is this correct? [y/n]: " answer
	if [[ $answer == "y" ]]; then

		touch $dropbox_config_file
		echo "OAUTH_ACCESS_TOKEN=$OAUTH_ACCESS_TOKEN" > $dropbox_config_file
		echo "$showok Dropbox configuration has been saved."
	else
		echo "$showerror Please start the script again and enter correct OAUTH_ACCESS_TOKEN."
		exit 1

	fi # start again if the ACCESS_TOKEN is not correct


fi # CHECKING FOR DROPBOX_AUTH FILE END

# CHECKING FOR FTP CONFIG FILE START
if [[ -e $ftp_config_file_server1 ]]; then

        # Check if ftp config file has the correct data
        if [[ ! $(grep "FTP_HOST" $ftp_config_file_server1) == "FTP_HOST" ]]; then
                echo -e "$showok FTP UPLOADER config found @ $ftp_config_file_server1...\n"
        fi

else # first time configuration for ftp uploader

        echo -e "\\n$showexecute FTP Uploader first time configuration...\\n$showinfo Asuming you already have a FTP Account..."

        read -e -r -p "$showinput enter FTP_HOST (e.g. domain.tld): " FTP_HOST
        read -e -r -p "$showinput enter FTP_USERNAME(e.g. user@subdomain.domain.tld): " FTP_USERNAME
        read -e -r -p "$showinput enter FTP_PASSWORD: " FTP_PASSWORD

        read -e -r -p "$showinfo FTP UPLOADER config: HOST=$FTP_HOST | USER=$FTP_USERNAME | PASS=$FTP_PASSWORD -> Are these correct? [y/n]: " answer
        if [[ $answer == "y" ]]; then

                touch $ftp_config_file_server1
                echo -e "FTP_HOST=$FTP_HOST\\nFTP_USERNAME=$FTP_USERNAME\\nFTP_PASSWORD=$FTP_PASSWORD" > $ftp_config_file_server1
                echo "$showok FTP UPLOADER configuration has been saved."
        else
                echo "$showerror Please start the script to enter FTP config info again."
                exit 1

        fi # start again if the ACCESS_TOKEN is not correct
fi # CHECKING FOR FTP CONFIG FILE END

### check single file response START
function checksingleresponse()
{
	# Check Response from Dropbox
	if grep "^HTTP/1.1 200 OK" "$RESPONSE_FILE"; then

       		echo -e "\n$showok Operation ended successfully!"
	      	echo -e "$showok File uploaded!"
	else
		#Checking response file for generic errors
	    	if grep "HTTP/1.1 400" "$RESPONSE_FILE"; then

	       		ERROR_MSG=$(grep "Error" "$RESPONSE_FILE")
			echo "$showerror $ERROR_MSG"
			echo "$showerror Check API call functions."
			echo "$showerror File upload failed!"
			#rm_tmp_files
		else
		    	if grep "invalid_access_token" "$RESPONSE_FILE"; then

	       			ERROR_MSG=$(grep "invalid_access_token" "$RESPONSE_FILE")
				echo "$showerror $ERROR_MSG"
				echo "$showerror Wrong API key!!!"
				echo "$showerror File upload failed!"
				#rm_tmp_files
			fi
		fi
	fi
}
### check single file response END

### FTP_UPLOADER FUNCTION START
function ftp_uploader(){

sha1sum $LOCAL_FILE_SRC | awk '{print $1}' > $SHA_FILE_SRC

for ftpupload in $ftp_config_file_server1 $ftp_config_file_server2;
do

        get_FTP_HOST=$(grep "FTP_HOST" $ftpupload | cut -d "=" -f2)
        get_FTP_USER=$(grep "FTP_USER" $ftpupload | cut -d "=" -f2)
        get_FTP_PASSWORD=$(grep "FTP_PASSWORD" $ftpupload | cut -d "=" -f2)

lftp -d -u "$get_FTP_USER","$get_FTP_PASSWORD" "$get_FTP_HOST" << EOT
put $LOCAL_FILE_SRC -o "blockchainDB3.tar.gz"
put $SHA_FILE_SRC -o blockchainDB3.sha1
bye
EOT

sleep 2
done

}
### FTP_UPLOADER FUNCTION END

### START BLOCKCHAIN_ARHIVATOR
function blockchainarchivator(){
	### VARS
	webdnode=$(cat $fastsearch)
	getblockchainfolder="$webdnode/blockchainDB3"
	getpm2dropboxport=$($whichpm2 list | grep $pm2dropboxport | awk '{print $2}')
	getpm2dropboxid=$($whichpm2 list | grep $pm2dropboxport | awk '{print $4}')
	getpm2dropboxstatus=$($whichpm2 list | grep $pm2dropboxport | awk '{print $10}')
	#cutport=$(ls -d $getblockchainfolder | cut -d '/' -f5 | cut -d '8' -f1)
	###

	if [[ -s $fastsearch ]]; then

		echo "$showinfo Fast Search available! Proceeding..."
		echo "$showexecute Changing directory to: $webdnode" && if cd "$webdnode"; then echo "$showinfo Current DIR has been changed to $yellow$(pwd)$stand"; else echo "$showerror Couldn't change DIR to $getblockchainfolder!"; fi

		if [[ -d "$getblockchainfolder" ]]; then
			echo "$showok Blockchain Folder $getblockchainfolder found!"
			echo "$showinfo Blockchain Folder has size = $(du -h "$getblockchainfolder")"
			echo "$showinfo We must STOP pm2 process in order to start Blockchain Archivation and Backup!"
			echo "$showexecute Stopping PM2 process for ID=$getpm2dropboxid and PORT=$pm2dropboxport"

			if [[ -n $getpm2dropboxport ]]; then
				$whichpm2 stop $pm2dropboxport
				sleep 2
				echo "$showexecute Proceeding with Blockchain Archivation..."
				if cd "$getblockchainfolder"; then echo "$showinfo Current DIR has been changed to $yellow$(pwd)$stand"; else echo "$showerror Couldn't change DIR to $getblockchainfolder!"; fi
				tar -czvf "$webdnode/blockchainDB3.tar.gz" *
				sleep 2

				if [[ -s "$webdnode/blockchainDB3.tar.gz" ]]; then
					echo "$showok Blockchain Folder Archived successfully! Size = $(du -h "$webdnode"/blockchainDB3.tar.gz)"
					echo "$showexecute Reloading PM2 instance for PORT=$pm2dropboxport..."
					cd .. && $whichpm2 reload $pm2dropboxport
					sleep 1

					if [[ $getpm2dropboxstatus == online ]]; then
						echo "$showok PM2 Instance is ${green}online$stand!"
					elif [[ $getpm2dropboxstatus == errored ]]; then
						echo "$showerror PM2 Instance failed to start!"
						echo "$showinfo Check LOG."
						$whichpm2 log $pm2dropboxport
						exit 1
					fi
				else
					echo "$showerror Blockchain Folder was not archived! Unexpected error! Investigate!"
				fi
			else
				if [[ ! -n $getpm2dropboxport ]]; then
					echo "$showerror Oops...PM2 instance with PORT=$pm2dropboxport does not exist!"
					echo "$showerror We can't proceed. Maybe the instance didn't start after the last Dropbox Backup."
					exit 0
				fi
			fi
		else
			echo "$showerror Oops..Blockchain Folder not found! This wasn't suppose to happen..."
		fi
	else
		echo "$showerror Oops. WebDollar Node Root folder not found! Stopping..."
		exit 1
	fi
}
### END BLOCKCHAIN_ARHIVATOR

### START ARCHIVE_CREATION
if [[ ! -s $fastsearch ]]; then

	echo "$showerror Fast Search (cache): No Fast Search file found!!"
	echo "$showexecute Creating one now..."
	touch $fastsearch && sudo find / -name $mainwebdfolder | tee $fastsearch
	echo "$showinfo Contents of Fast Search = $(cat $fastsearch)"
	blockchainarchivator
else
	echo "$showok Fast Search file found!!"
	echo "$showexecute Proceeding with the archivation process..."

	blockchainarchivator
fi
### END ARCHIVE_CREATION


### DROPBOX UPLOADER FUNCTION
function dropbox_uploader(){

# DO NOT EDIT BELOW #
API_MIGRATE_V2="https://api.dropboxapi.com/1/oauth2/token_from_oauth1"
API_LONGPOLL_FOLDER="https://notify.dropboxapi.com/2/files/list_folder/longpoll"
API_CHUNKED_UPLOAD_START_URL="https://content.dropboxapi.com/2/files/upload_session/start"
API_CHUNKED_UPLOAD_FINISH_URL="https://content.dropboxapi.com/2/files/upload_session/finish"
API_CHUNKED_UPLOAD_APPEND_URL="https://content.dropboxapi.com/2/files/upload_session/append_v2"
API_UPLOAD_URL="https://content.dropboxapi.com/2/files/upload"
API_DOWNLOAD_URL="https://content.dropboxapi.com/2/files/download"
API_DELETE_URL="https://api.dropboxapi.com/2/files/delete_v2"
API_MOVE_URL="https://api.dropboxapi.com/2/files/move"
API_COPY_URL="https://api.dropboxapi.com/2/files/copy_v2"
API_METADATA_URL="https://api.dropboxapi.com/2/files/get_metadata"
API_LIST_FOLDER_URL="https://api.dropboxapi.com/2/files/list_folder"
API_LIST_FOLDER_CONTINUE_URL="https://api.dropboxapi.com/2/files/list_folder/continue"
API_ACCOUNT_INFO_URL="https://api.dropboxapi.com/2/users/get_current_account"
API_ACCOUNT_SPACE_URL="https://api.dropboxapi.com/2/users/get_space_usage"
API_MKDIR_URL="https://api.dropboxapi.com/2/files/create_folder"
API_SHARE_URL="https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings"
API_SHARE_LIST="https://api.dropboxapi.com/2/sharing/list_shared_links"
API_SAVEURL_URL="https://api.dropboxapi.com/2/files/save_url"
API_SAVEURL_JOBSTATUS_URL="https://api.dropboxapi.com/2/files/save_url/check_job_status"
API_SEARCH_URL="https://api.dropboxapi.com/2/files/search"
APP_CREATE_URL="https://www.dropbox.com/developers/"
RESPONSE_FILE="$TMP_DIR/dropbox_resp"
RESPONSE_FILE_GET_SESSION="$TMP_DIR/dropbox_response_session"
RESPONSE_FILE_SINGLE="$TMP_DIR/dropbox_response_single"
RESPONSE_FILE_FINISH="$TMP_DIR/dropbox_response_finish"
CHUNK_FILE="$TMP_DIR/dropbox_chunk"
TEMP_FILE="$TMP_DIR/dropbox_tmp_$RANDOM"
BIN_DEPS="sed basename date grep stat dd mkdir"
VERSION="1.0"
# DO NOT EDIT ABOVE #

# REMOVE TEMP FILES FUNCTION
function rm_tmp_files(){

if [[ $DEBUG == 0 ]]; then
	rm -fr "$RESPONSE_FILE"
	rm -fr "$RESPONSE_FILE_SINGLE"
	rm -fr "$RESPONSE_FILE_FINISH"
        rm -fr "$CHUNK_FILE"
	rm -fr "$TEMP_FILE"
fi
}
### REMOVE TEMP FILES FUNCTION END

# DROPBOX UPLOAD FILE FUNCTION
function upload_file(){
### VARS
get_OAUTH_ACCESS_TOKEN=$(grep "OAUTH_ACCESS_TOKEN" $dropbox_config_file | cut -d "=" -f2)
###

if [[ $(stat --format="%s" $LOCAL_FILE_SRC) -lt 157286000  ]]; then

	echo "$showinfo Using single file upload. Total file size is beyond 150M."

	curl --progress-bar -X POST "$API_UPLOAD_URL" -i --globoff -o "$RESPONSE_FILE_SINGLE" \
	--header "Authorization: Bearer $get_OAUTH_ACCESS_TOKEN" \
	--header "Dropbox-API-Arg: {\"path\": \"$DROPBOX_DST\",\"mode\": \"overwrite\",\"autorename\": true,\"mute\": false}" \
	--header "Content-Type: application/octet-stream" \
	--data-binary @"$LOCAL_FILE_SRC"

	checksingleresponse
else
	if [[ $(stat --format="%s" $LOCAL_FILE_SRC) -gt 157286000  ]]; then

		echo "$showinfo File size is greater than 150M, [$(du -h $LOCAL_FILE_SRC)], creating chunks..."

		if [[ -d $db3chunksfolder ]]; then

			$whichsplit -b 100M $LOCAL_FILE_SRC "$db3chunksfolder/blockchainDB3.part"
			sleep 2;
		else
			if [[ ! -d $db3chunksfolder ]]; then

				echo "$showerror Oops...DB3 Chunks folder not found!"
				echo "$showinfo Creating one @ $db3chunksfolder" && mkdir $db3chunksfolder
				$whichsplit -b 100M $LOCAL_FILE_SRC "$db3chunksfolder/blockchainDB3.part"
				sleep 2;
			fi
		fi

		### START_UPLOAD_CHUNK_A (to get a session id, then append)
		getchunkpartA=$(ls -l $db3chunksfolder | grep ".*part" | awk 'NR==1{print$9}')

		echo "$showinfo Uploading CHUNK_A = $green$getchunkpartA$stand"

		curl --progress-bar -X POST "$API_CHUNKED_UPLOAD_START_URL" -i --globoff -o "${CHUNK_FILE}_$getchunkpartA" \
		 --header "Authorization: Bearer $get_OAUTH_ACCESS_TOKEN" \
		 --header "Dropbox-API-Arg: {\"close\": false}" \
		 --header "Content-Type: application/octet-stream" \
		 --data-binary @"$db3chunksfolder/$getchunkpartA"
		### END_UPLOAD_CHUNK_A (to get a session id, then append)

		### VARS
		getchunkparts=$(ls -l $db3chunksfolder | grep ".*part" | awk 'NR>1{print$9}')
		get_chunk_offsets=$(ls -l $db3chunksfolder | grep ".*part" | awk 'NR>1{print$5}')
		getsessionid=$(sed -n 's/{"session_id": *"*\([^"]*\)"*.*/\1/p' ${CHUNK_FILE}_"$getchunkpartA")
		get_total_chunks=$(ls -l $db3chunksfolder | awk 'NR>2{print$9}' | wc -l) # NR>2 because we don't have grep **part pipe and we`re not counting chunkpartA
		###

		### START_CHUNK_UPLOAD_APPEND # SUPPORT_FOR_1A+12_CHUNKS.
		echo "$showinfo We have $green$get_total_chunks$stand CHUNKS to APPEND..."

		for chunk in $getchunkparts;
		do
			chunkstat=$(stat --format=%s $db3chunksfolder/"$chunk")
			statcmd="stat --format="%s" "

			for CUR_OFFSET in $chunkstat;
			do
				INIT_OFFSET="104857600"
				mathcheck=$(if [[ "$chunk" == **ab ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "$CUR_OFFSET"; fi \
				elif [[ "$chunk" == **ac ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "2*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **ad ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "3*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **ae ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "4*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **af ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "5*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **ag ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "6*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **ah ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "7*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **ai ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "8*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **aj ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)+$($statcmd$db3chunksfolder/**ai)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "9*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **ak ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)+$($statcmd$db3chunksfolder/**ai)+$($statcmd$db3chunksfolder/**aj)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "10*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **al ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)+$($statcmd$db3chunksfolder/**ai)+$($statcmd$db3chunksfolder/**aj)+$($statcmd$db3chunksfolder/**ak)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "11*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi \
				elif [[ "$chunk" == **am ]]; then if [[ "$CUR_OFFSET" -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)+$($statcmd$db3chunksfolder/**ai)+$($statcmd$db3chunksfolder/**aj)+$($statcmd$db3chunksfolder/**ak)+$($statcmd$db3chunksfolder/**al)"; elif [[ "$CUR_OFFSET" == 104857600 ]]; then echo "12*$CUR_OFFSET"; elif [[ "$CUR_OFFSET" == "" ]]; then echo "0"; fi fi)
				SET_OFFSET=$(echo "$mathcheck" | bc)

				echo "$showinfo Uploading CHUNK = $green$chunk$stand"

				curl --progress-bar -X POST "$API_CHUNKED_UPLOAD_APPEND_URL" -i --globoff -o "${CHUNK_FILE}_append_$chunk" \
				 --header "Authorization: Bearer $get_OAUTH_ACCESS_TOKEN" \
    				 --header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"$getsessionid\",\"offset\": $SET_OFFSET},\"close\": false}" \
				 --header "Content-Type: application/octet-stream" \
				 --data-binary @"$db3chunksfolder/$chunk"

				echo "$showinfo Checking if CHUNK = $green$chunk$stand uploaded successfully..."

				if grep -q "$response_code_100" "${CHUNK_FILE}_append_$chunk"; then

					echo "$showinfo $response_code_100 for CHUNK = $green$chunk$stand"

				elif grep -q "$response_code_200" "${CHUNK_FILE}_append_$chunk"; then

					echo -e "$showok $response_code_200 for CHUNK = $green$chunk$stand"
					echo -e "$showok CHUNK = $green$chunk$stand uploaded!"
					echo -e "$showinfo Printing debugging info...\\n" && cat "${CHUNK_FILE}_append_$chunk"
				else
					echo -e "$showerror Something went wrong! Check LOG...\\n" && cat "${CHUNK_FILE}_append_$chunk"
				fi

			break
			done
		continue
		done
		### END_CHUNK_UPLOAD_APPEND

		### START_CHUNK_UPLOAD_FINISH

		### VARS
		get_total_chunksoffset=$(stat --format="%s" $db3chunksfolder/* | awk '{sum+=$1} END {print sum}')
		###

		echo "$showinfo We're now commiting CHUNKs uploaded from SESSION_ID=$green$getsessionid$stand..."

		### CLOSE_SESSION_ID
		curl --progress-bar -X POST "$API_CHUNKED_UPLOAD_FINISH_URL" -i --globoff -o "$RESPONSE_FILE_FINISH" \
		--header "Authorization: Bearer $get_OAUTH_ACCESS_TOKEN" \
		--header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"$getsessionid\",\"offset\": $get_total_chunksoffset},\"commit\": {\"path\": \"$DROPBOX_DST\",\"mode\": \"overwrite\",\"autorename\": false,\"mute\": false}}" \
		--header "Content-Type: application/octet-stream" \
		--data-binary @/dev/null
		### END_CHUNK_UPLOAD_FINISH

		### CHECK_DROPBOX_FINISH_RESPONSE

		echo "$showinfo Checking if process ended successfully..."

		if grep -q "$response_code_200" "$RESPONSE_FILE_FINISH"; then
       			echo -e "$showok Operation ended successfully!"
      			echo -e "$showok File commited!"
			echo -e "$showinfo Printing debugging info..." && cat "$RESPONSE_FILE_FINISH"
		else
			echo -e "$showerror Please investigate...\\n" && cat "$RESPONSE_FILE_FINISH"
		fi
	fi
fi

} # DROPBOX UPLOAD FILE FUNCTION END
upload_file # call upload file to dropbox

} # DROPBOX UPLOADER BIG FUNCTION

dropbox_uploader 	# call dropbox big function
ftp_uploader		# call ftp_uploader function
