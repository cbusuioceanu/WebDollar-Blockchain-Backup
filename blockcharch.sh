#!/bin/bash

# You need a Dropbox account and an API key
# This script should be used with CRON
# sudo crontab -e
# Paste: 0 */12 * * * bash blkcharch.sh
# ^ CRON at every 12 hours ^

#### COLOR SETTINGS ####
BLACK=$(tput setaf 0 && tput bold)
RED=$(tput setaf 1 && tput bold)
GREEN=$(tput setaf 2 && tput bold)
YELLOW=$(tput setaf 3 && tput bold)
BLUE=$(tput setaf 4 && tput bold)
MAGENTA=$(tput setaf 5 && tput bold)
CYAN=$(tput setaf 6 && tput bold)
WHITE=$(tput setaf 7 && tput bold)
BLACKbg=$(tput setab 0 && tput bold)
REDbg=$(tput setab 1 && tput bold)
GREENbg=$(tput setab 2 && tput bold)
YELLOWbg=$(tput setab 3 && tput bold)
BLUEbg=$(tput setab 4 && tput dim)
MAGENTAbg=$(tput setab 5 && tput bold)
CYANbg=$(tput setab 6 && tput bold)
WHITEbg=$(tput setab 7 && tput bold)
STAND=$(tput sgr0)
###

### System dialog VARS
showinfo="$GREEN[info]$STAND"
showerror="$RED[error]$STAND"
showexecute="$YELLOW[running]$STAND"
showok="$MAGENTA[OK]$STAND"
showdone="$BLUE[DONE]$STAND"
showinput="$CYAN[input]$STAND"
showwarning="$RED[warning]$STAND"
showremove="$GREEN[removing]$STAND"
shownone="$MAGENTA[none]$STAND"
redhashtag="$REDbg$WHITE#$STAND"
abortfm="$CYAN[abort for Menu]$STAND"
###

### VARS
linuxuser="webd1" # change this to your Linux UserName | do not change order!
fastsearch="/home/$linuxuser/.blockchaindbs"
db3chunksfolder="/home/$linuxuser/db3chunks"
response_code_100="^HTTP/1.1 100 CONTINUE"
response_code_200="^HTTP/1.1 200 OK"
###

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

### START BLOCKCHAIN_ARHIVATOR
function blockchainarchivator(){
	### VARS
	webdnode=$(cat $fastsearch)
	getblockchainfolder="$webdnode/blockchainDB380"
	cutport=$(ls -d $getblockchainfolder | cut -d '/' -f5 | cut -d '8' -f1)
	###

	if [[ -s $fastsearch ]]; then

		echo "$showinfo Fast Search available! Proceeding..."
		echo "$showexecute Changing directory to: $webdnode" && cd $webdnode && echo "$showinfo Directory changed to $(pwd)"

		if [[ -d $getblockchainfolder ]]; then

			echo "$showok Blockchain Folder $getflockchanfolder found!"
			echo "$showinfo Blockchain Folder has size = $(du -h $getblockchainfolder)"
			echo "$showexecute Proceeding with Blockchain Archivation..."
			cd $getblockchainfolder && tar -czvf "$webdnode/$cutport.tar.gz" *

			if [[ -s "$webdnode/$cutport.tar.gz" ]]; then

				echo "$showok Blockchain Folder Archived successfully! Size = $(du -h $webdnode/$cutport.tar.gz)"
			else
				echo "$showerror Blockchain Folder was not archived! Unexpected error! Investigate!"
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
	touch $fastsearch && echo "$(find / -type d -name "Node-WebDollar")" > $fastsearch
	echo "$showinfo Contents of Fast Search = $(cat $fastsearch)"
	blockchainarchivator
else
	echo "$showok Fast Search file found!!"
	echo "$showexecute Proceeding with the archivation process..."

	blockchainarchivator
fi
### END ARCHIVE_CREATION


### DROPBOX UPLOADER FUNCTION
function dropboxbkupupload(){
### VARS
dropbox_config_file="/.dropbox_uploader"
TMP_DIR="/tmp"
DEBUG="1" # change this to 1 if debugging is needed
LOCAL_FILE_SRC="/home/$linuxuser/Node-WebDollar/blockchainDB3.tar.gz"
DROPBOX_DST="/blockchainDB3.tar.gz" # must start with /
###

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

#CHECKING FOR AUTH FILE
if [[ -e $dropbox_config_file ]]; then

	# Check if config file has the OAUTH_ACCESS_TOKEN
	if [[ ! $(grep OAUTH_ACCESS_TOKEN $dropbox_config_file) == "OAUTH_ACCESS_TOKEN" ]]; then
        	echo -e "$showok Dropbox OAUTH_ACCESS_TOKEN found @ $dropbox_config_file...\n"
	fi

else #first time configuration

	echo -e "\n$showexecute Dropbox Upload first time configuration...\n"

	read -e -r -p "$showinput Asuming you already have a Dropbox App, enter the Access Token: " OAUTH_ACCESS_TOKEN

	read -e -r -p "$showinfo The access token is $OAUTH_ACCESS_TOKEN. Is this correct? [y/n]: " answer
	if [[ $answer != "y" ]]; then dropboxbkupupload; fi # start again if the ACCESS_TOKEN is not correct

	touch .$dropbox_config_file
	echo "OAUTH_ACCESS_TOKEN=$OAUTH_ACCESS_TOKEN" > .$dropbox_config_file
	echo "$showok Dropbox configuration has been saved."

fi # CHECKING FOR AUTH FILE END

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

		echo "$showinfo File size is greater than 150M, creating chunks..."

		if [[ -d $db3chunksfolder ]]; then

			split -b 100M $LOCAL_FILE_SRC "$db3chunksfolder/blockchainDB3.part"
			sleep 2;
		else
			if [[ ! -d $db3chunksfolder ]]; then

				echo "$showerror Oops...DB3 Chunks folder not found!"
				echo "$showinfo Creating one @ $db3chunksfolder" && mkdir $db3chunksfolder
				split -b 100M $LOCAL_FILE_SRC "$db3chunksfolder/blockchainDB3.part"
				sleep 2;
			fi
		fi

		### START_UPLOAD_CHUNK_A (to get a session id, then append)
		getchunkpartA=$(ls -l $db3chunksfolder | grep **part | awk 'NR==1{print$9}')

		echo "$showinfo Uploading CHUNK_A = $GREEN$getchunkpartA$STAND"

		curl --progress-bar -X POST "$API_CHUNKED_UPLOAD_START_URL" -i --globoff -o "${CHUNK_FILE}_$getchunkpartA" \
		 --header "Authorization: Bearer $get_OAUTH_ACCESS_TOKEN" \
		 --header "Dropbox-API-Arg: {\"close\": false}" \
		 --header "Content-Type: application/octet-stream" \
		 --data-binary @"$db3chunksfolder/$getchunkpartA"
		### END_UPLOAD_CHUNK_A (to get a session id, then append)

		### VARS
		getchunkparts=$(ls -l $db3chunksfolder | grep **part | awk 'NR>1{print$9}')
		get_chunk_offsets=$(ls -l $db3chunksfolder | grep **part | awk 'NR>1{print$5}')
		getsessionid=$(sed -n 's/{"session_id": *"*\([^"]*\)"*.*/\1/p' ${CHUNK_FILE}_$getchunkpartA)
		get_total_chunks=$(ls -l $db3chunksfolder | awk 'NR>2{print$9}' | wc -l) # NR>2 because we don't have grep **part pipe and we`re not counting chunkpartA
		###

		### START_CHUNK_UPLOAD_APPEND # SUPPORT_FOR_1+12_CHUNKS.
		echo "$showinfo We have $GREEN$get_total_chunks$STAND CHUNKS to APPEND..."

		for chunk in $getchunkparts;
		do
			chunkstat=$(stat --format="%s" $db3chunksfolder/$chunk)
			statcmd="stat --format="%s" "

			for CUR_OFFSET in $chunkstat;
			do
				INIT_OFFSET="104857600"
				mathcheck=$(if [[ $chunk == **ab ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$CUR_OFFSET"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "$CUR_OFFSET"; fi fi \
				elif [[ $chunk == **ac ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "2*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **ad ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "3*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **ae ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "4*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **af ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "5*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **ag ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "6*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **ah ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "7*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **ai ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "8*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **aj ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)+$($statcmd$db3chunksfolder/**ai)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "9*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **ak ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)+$($statcmd$db3chunksfolder/**ai)+$($statcmd$db3chunksfolder/**aj)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "10*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **al ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)+$($statcmd$db3chunksfolder/**ai)+$($statcmd$db3chunksfolder/**aj)+$($statcmd$db3chunksfolder/**ak)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "11*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi \
				elif [[ $chunk == **am ]]; then if [[ $CUR_OFFSET -lt 104857600 ]]; then echo "$($statcmd$db3chunksfolder/**aa)+$($statcmd$db3chunksfolder/**ab)+$($statcmd$db3chunksfolder/**ac)+$($statcmd$db3chunksfolder/**ad)+$($statcmd$db3chunksfolder/**ae)+$($statcmd$db3chunksfolder/**af)+$($statcmd$db3chunksfolder/**ag)+$($statcmd$db3chunksfolder/**ah)+$($statcmd$db3chunksfolder/**ai)+$($statcmd$db3chunksfolder/**aj)+$($statcmd$db3chunksfolder/**ak)+$($statcmd$db3chunksfolder/**al)"; else if [[ $CUR_OFFSET == 104857600 ]]; then echo "12*$CUR_OFFSET"; else if [[ $CUR_OFFSET == "" ]]; then echo "0"; fi fi fi fi)
				SET_OFFSET=$(echo "$mathcheck" | bc)

				echo "$showinfo Uploading CHUNK = $GREEN$chunk$STAND"

				curl --progress-bar -X POST "$API_CHUNKED_UPLOAD_APPEND_URL" -i --globoff -o "${CHUNK_FILE}_append_$chunk" \
				 --header "Authorization: Bearer $get_OAUTH_ACCESS_TOKEN" \
    				 --header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"$getsessionid\",\"offset\": $SET_OFFSET},\"close\": false}" \
				 --header "Content-Type: application/octet-stream" \
				 --data-binary @"$db3chunksfolder/$chunk"

				echo "$showinfo Checking if CHUNK = $GREEN$chunk$STAND uploaded successfully..."

				if [[ $(grep "$response_code_100" "${CHUNK_FILE}_append_$chunk") ]]; then

					echo "$showinfo $response_code_100 for CHUNK = $GREEN$chunk$STAND"

				elif [[ $(grep "$response_code_200" "${CHUNK_FILE}_append_$chunk") ]]; then

					echo -e "$showok $response_code_200 for CHUNK = $GREEN$chunk$STAND"
					echo -e "$showok CHUNK = $GREEN$chunk$STAND uploaded!"
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

		echo "$showinfo We're now commiting CHUNKs uploaded from SESSION_ID=$RED$getsessionid$STAND..."

		### CLOSE_SESSION_ID
		curl --progress-bar -X POST "$API_CHUNKED_UPLOAD_FINISH_URL" -i --globoff -o "$RESPONSE_FILE_FINISH" \
		--header "Authorization: Bearer $get_OAUTH_ACCESS_TOKEN" \
		--header "Dropbox-API-Arg: {\"cursor\": {\"session_id\": \"$getsessionid\",\"offset\": $get_total_chunksoffset},\"commit\": {\"path\": \"$DROPBOX_DST\",\"mode\": \"overwrite\",\"autorename\": false,\"mute\": false}}" \
		--header "Content-Type: application/octet-stream" \
		--data-binary @/dev/null
		### END_CHUNK_UPLOAD_FINISH

		### CHECK_DROPBOX_FINISH_RESPONSE

		echo "$showinfo Checking if process ended successfully..."

		if [[ $(grep "$response_code_200" "$RESPONSE_FILE_FINISH") ]]; then
       			echo -e "$showok Operation ended successfully!"
      			echo -e "$showok File commited!"
			echo -e "$showinfo Printing debugging info..." && cat "$RESPONSE_FILE_FINISH"
		else
			echo -e "$showerror Please investigate...\\n" && cat "$RESPONSE_FILE_FINISH"
		fi
	fi
fi

} # DROPBOX UPLOAD FILE FUNCTION END
upload_file

}
### DROPBOX UPLOADER FUNCTION

dropboxbkupupload

