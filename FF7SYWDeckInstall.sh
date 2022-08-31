#! /bin/bash

#Install FF7SYW on a SteamDeck

# shellcheck disable=SC2164

FF7SYWFR_target_version="5.63"
#FF7SYWFR_PACKAGE_1=("FF7SYW.V5.60.zip" "1EnBQbvjKKnP2E-7B8o98KHiaJoi9_94a" "'http://yatoshicom.free.fr/ff7sywv5.php?id=installeur3'" "074f71f4d60f182b4a3c264dcf69c37c")
#FF7SYWFR_PACKAGE_2=("FF7SYWV5.MAJ.5.63.exe" "1i5n1nPrt5_83u9c1pyMIYr7ErbN84yyj" "'http://yatoshicom.free.fr/ff7sywv5.php?id=data2'" "e452937baed9e51f87848424c83f2663")
FF7SYWFR_PACKAGE_1="FF7SYW.V5.60.zip 1EnBQbvjKKnP2E-7B8o98KHiaJoi9_94a 'http://yatoshicom.free.fr/ff7sywv5.php?id=installeur3' 074f71f4d60f182b4a3c264dcf69c37c"
FF7SYWFR_PACKAGE_2="FF7SYWV5.MAJ.5.63.exe 1i5n1nPrt5_83u9c1pyMIYr7ErbN84yyj 'http://yatoshicom.free.fr/ff7sywv5.php?id=data2' e452937baed9e51f87848424c83f2663"

PROTON_VERSION="7.0"
FF7SYW_DIR="$HOME/FF7SYW/FF7SYWV5/"
STEAMAPPS="$HOME/.local/share/Steam/steamapps/"

check_FF7_orig_installed () {
	if [[ -f "$STEAMAPPS"/appmanifest_39140.acf ]] \
	&& [[ -d "$STEAMAPPS"/common/FINAL\ FANTASY\ VII/ ]]\
	&& [[ -f "$STEAMAPPS"/common/FINAL\ FANTASY\ VII/FF7_Launcher.exe ]]; then 
		echo -e "FF7 natif est installé\n"
	else 
		echo -e "FF7 natif n'est pas installé. Merci de l'installer avec Steam avant de lancer cet installeur\n"
		exit 1
	fi
}

check_proton_installed () {
	if [[ -f "$STEAMAPPS"/appmanifest_1887720.acf ]] \
	&& [[ -f "$STEAMAPPS"/common/Proton\ "$PROTON_VERSION"/proton ]] ; then
		echo -e "Proton OK\n"
	else
		echo -e "Proton n'est pas installé, merci d'executé FF7 Steam au moins une fois avant de lancer cet installeur\n"
		exit 1
	fi
}        
			
create_simlink_FF7Orig () {
	if [[ ! -L "$HOME"/FF7_orig ]]; then
        	ln -s "$STEAMAPPS"/common/FINAL\ FANTASY\ VII/ "$HOME"/FF7_orig
	fi
	echo "simlink OK"
}

create_dir_simlink_FF7SYW () {
	if [[ ! -d "$FF7SYW_DIR" ]]; then
		mkdir -p "$FF7SYW_DIR"
	fi
	if [[ ! -L "$HOME"/FF7SYW/ ]]; then
		ln -s "$FF7SYW_DIR" "$HOME"/FF7SYW
	fi
}

download_on_gdrive () {
	local file_name
	local file_g_id
	local download_path
	local drive_url

	file_name="$1"
	file_g_id="$2"
	download_path="$3"

	pushd "$download_path"
	drive_url="https://docs.google.com/uc?export=download&id=${file_g_id}"
	wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "$drive_url" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$file_g_id" -O "$file_name" && rm -rf /tmp/cookies.txt
	popd
}

download_fallback () {
	local file_name
	local fallback_url
	local download_path

	file_name="$1"
	fallback_url="$2"
	download_path="$3"

	pushd "$download_path"
	wget --no-check-certificate "$fallback_url" -O "$file_name"
	popd
}

checksum_package_md5 () {
	local file_name
	local checksum_md5
	local package_dir

	file_name="$1"
	checksum_md5="$2"
	package_dir="$3"

	pushd "$package_dir"
	echo -e "$checksum_md5  $file_name" > "$file_name".md5
	if ! md5sum -c "$file_name".md5 ; then
		rm "${file_name}"
                echo -e "Le fichier téléchargé est corrompu ou pas complet\n"
		return 1 
	fi
	rm "$file_name".md5
	popd
}

install_exe_with_proton () {
# $1 is the MS_Windows executable or zip to install, $2 is the compatdata dir for the app previously created
	local file_name
	local compatdata_FF7SYW_inst

	file_name="$1"
	compatdata_FF7SYW_inst="$2"
	pushd "$HOME"/FF7SYWInstaller/
	if [[ "${file_name}" == *.zip ]]; then
		unzip "${file_name}"
		file_name=$(unzip -Z1 "${file_name}" | grep .exe)
		rm ./*.zip
	fi
	STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAMAPPS"/../ \
	STEAM_COMPAT_DATA_PATH="$STEAMAPPS"/compatdata/"$compatdata_FF7SYW_inst"/. \
	"$STEAMAPPS"/common/Proton\ "$PROTON_VERSION"/proton run "$file_name"
	popd
}

download_prepare_install_FF7SYWexes () {
	local total_var_packages
	local var_package_nb
	local package_name
	local file_name
	local file_g_id
	local fallback_url
	local checksum_md5
	local file2install

	mkdir -p "$HOME"/FF7SYWInstaller/
	total_var_packages="$( (set -o posix; set ) | grep -c FF7SYWFR_PACKAGE_)"
	for var_package_nb in $(seq 1 "$total_var_packages"); do
		package_name="FF7SYWFR_PACKAGE_$var_package_nb"
#		array_package_name=("${!package_name}")
#		file_name="${array_package_name[0]}"
#		file_g_id="${array_package_name[1]}"
#		fallback_url="${array_package_name[2]}"
#		checksum_md5="${array_package_name[3]}"
		file_name=$(echo "${!package_name}"| cut -d " " -f 1)
		file_g_id=$(echo "${!package_name}"| cut -d " " -f 2)
		fallback_url=$(echo "${!package_name}"| cut -d " " -f 3)
		checksum_md5=$(echo "${!package_name}"| cut -d " " -f 4)
		if [[ -f "$(xdg-user-dir DOWNLOAD)/${file_name}" ]]; then
			mv "$(xdg-user-dir DOWNLOAD)/${file_name}" "$HOME/FF7SYWInstaller/."
		fi
		if [[ -f "$HOME/FF7SYWInstaller/${file_name}" ]]; then
			checksum_package_md5 "$file_name" "$checksum_md5" "$HOME/FF7SYWInstaller/"
		fi
		if [[ ! -f "$HOME/FF7SYWInstaller/${file_name}" ]]; then
                        if ! ping -c 1 8.8.8.8 ; then 
				echo -e "Non connecté à Internet\n"
				exit 1
			fi
			download_on_gdrive "${file_name}" "${file_g_id}" "$HOME"/FF7SYWInstaller/
			if ! checksum_package_md5 "$file_name" "$checksum_md5" "$HOME"/FF7SYWInstaller/ ; then
				download_fallback "${file_name}" "${fallback_url}" "$HOME"/FF7SYWInstaller/
				if ! checksum_package_md5 "$file_name" "$checksum_md5" "$HOME"/FF7SYWInstaller/ ; then
					echo -e "Impossible de télécharger l'installeur ${file_name}. Merci de le télécharger avec Firefox ou Chrome"
					exit 1
				fi
			fi
		fi
        file2install+=" ${file_name}"
	sync
	done
	if [[ -d "$STEAMAPPS"/compatdata/install_SYW ]]; then
		rm -rf "$STEAMAPPS"/compatdata/install_SYW/*
	else
		mkdir -p "$STEAMAPPS"/compatdata/install_SYW/
	fi
	for f in ${file2install}; do 
		install_exe_with_proton "${f}" "$STEAMAPPS"/compatdata/install_SYW/.
	done
}

install_fonts () {
	local check_fonts_present
	check_fonts_present=$(fc-list | grep -i "Roboto")
	if [[ ! "$check_fonts_present" == *"Roboto-Regular.ttf"* ]] \
	&& [[ ! "$check_fonts_present" == *"Roboto-Black.ttf"* ]]; then
		if [[ ! -d "$HOME"/.local/share/fonts ]]; then
			mkdir -p "$HOME"/.local/share/fonts
		fi
		cp "$FF7SYW_DIR"/FF7_SYW/addfiles/polices/*.ttf "$HOME"/.local/share/fonts/.
		fc-cache -f -v #Force fonts cache regen
	fi
	echo -e "Les polices sont présentes ou ont été installées\n"
}

#STEAM_COMPAT_CLIENT_INSTALL_PATH=/home/deck/.local/share/Steam STEAM_COMPAT_DATA_PATH=/home/deck/.local/share/Steam/steamapps/compatdata/install_SYW/. /home/deck/.steam/steam/steamapps/common/Proton\ 7.0/proton run /home/deck/Downloads/FF7SYW.V5.60.exe

#STEAM_COMPAT_CLIENT_INSTALL_PATH=/home/deck/.local/share/Steam STEAM_COMPAT_DATA_PATH=/home/deck/.local/share/Steam/steamapps/compatdata/install_SYW/. /home/deck/.steam/steam/steamapps/common/Proton\ 7.0/proton run /home/deck/Downloads/FF7SYWV5.MAJ.5.63.exe


#Main
check_FF7_orig_installed
check_proton_installed
create_simlink_FF7Orig
create_dir_simlink_FF7SYW
download_prepare_install_FF7SYWexes
install_fonts
