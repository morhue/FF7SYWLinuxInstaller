#! /bin/bash
#Install FF7SYW on a SteamDeck (prepare environment, download packages, install and configuration post install)

#http: https://github.com/morhue/FF7SYWLinuxInstaller
#author: Morhue morhue@gmail.com
#help and support from Joan31/Samba

# shellcheck disable=SC2164

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>FF7SYWinst_"$(date '+%Y-%m-%d-%H_%M_%S')".log 2>&1

#Target version of FF7SYW to install.
FF7SYWFR_target_version="5.63"

#Variables to describe packages/executables to download/intstall. $1 is file name, $2 is GoogleDrive-ID of file, $3 is a fallback url and $4 the md5sum.
FF7SYWFR_PACKAGE_1="FF7SYW.V5.60.zip 1EnBQbvjKKnP2E-7B8o98KHiaJoi9_94a 'http://yatoshicom.free.fr/ff7sywv5.php?id=installeur3' 074f71f4d60f182b4a3c264dcf69c37c"
FF7SYWFR_PACKAGE_2="FF7SYWV5.MAJ.5.63.exe 1i5n1nPrt5_83u9c1pyMIYr7ErbN84yyj 'http://yatoshicom.free.fr/ff7sywv5.php?id=data2' e452937baed9e51f87848424c83f2663"

#Environment variables
PROTON_VERSION="7.0"
STEAMAPPS="$HOME/.local/share/Steam/steamapps"
FF7SYW_COMPATDATA="$STEAMAPPS/compatdata/FF7SYW"
FF7SYW_DIR="$FF7SYW_COMPATDATA/pfx/drive_c/Games/FF7SYWV5"


#Functions

#Display message on stdout terminal with echo -e
display_msg () {
	echo -e "$@" >&3
}

#Execute cmd and display stdout on stdout terminal
display_cmd () {
	"$@" >&3
}

#Quiet pushd on stdout
pushd () {
	command pushd "$@" > /dev/null
}

#Quiet popd on stdout
popd () {
	command popd > /dev/null
}

#Check if FF7 original is installed on Steam
check_FF7_orig_installed () {
        display_msg "\nVérification si FF7 original de Steam est installé:"
	if [[ -f "$STEAMAPPS"/appmanifest_39140.acf ]] \
	&& [[ -d "$STEAMAPPS"/common/FINAL\ FANTASY\ VII/ ]]\
	&& [[ -f "$STEAMAPPS"/common/FINAL\ FANTASY\ VII/FF7_Launcher.exe ]]; then 
		display_msg "FF7 version Steam est installé\n"
	else 
		display_msg "FF7 natif n'est pas installé. Merci de l'installer avec Steam avant de lancer cet installeur.\n"
		exit 1
	fi
}

#Check if Proton (wine fork from Valve) is installed on the system.
#https://github.com/ValveSoftware/Proton
check_proton_installed () {
        display_msg "\nVérification si Proton ${PROTON_VERSION} est installé:"
	if [[ -f "$STEAMAPPS"/appmanifest_1887720.acf ]] \
	&& [[ -f "$STEAMAPPS"/common/Proton\ ${PROTON_VERSION}/proton ]] ; then
		display_msg "Proton ${PROTON_VERSION} est bien installé.\n"
	else
		display_msg "Proton n'est pas installé. Merci d'executer FF7 version Steam au moins une fois avant de lancer cet installeur\n"
		exit 1
	fi
}        

#Create a symbolic link from the Home to FF7 legacy installed by Steam.
#It help the user to target the directory ask by the installer to check if the install is legit.
#It seem FF7SYW is not able to look in hidden directory (.*)
create_simlink_FF7Orig () {
	local symlink
	symlink="$HOME/FF7_orig"
        display_msg "\nCréation d'un lien symbolique vers FF7 original"
	if [[ ! -L "${symlink}" ]]; then
		ln -s "$STEAMAPPS"/common/FINAL\ FANTASY\ VII/ "${symlink}"
	fi
	if [[ -L "${symlink}" ]]; then
		local ls_symlink
		ls_symlink=$(ls -l "$symlink")
		display_msg "Lien symbolique créé:\n" "$ls_symlink"
	else
		display_msg "Lien symbolique vers FF7 original KO\n"
		exit 1
	fi
	display_msg "\n"
}

#Create a symbolic link from Home to the directory where FF7SYW is installed.
#It help the user to target the directory used by Proton to store the PACK and do maintenance or install other mods.
create_dir_simlink_FF7SYW () {
        local symlink
	symlink="$HOME/FF7SYW"
        display_msg "Création du répertoire d'installation"
	if [[ ! -d "$FF7SYW_DIR" ]]; then
		mkdir -p "$FF7SYW_DIR"
	fi
	display_msg "Création d'un lien symbolique vers le répertoire d'installation"
	if [[ ! -L "$symlink" ]]; then
		ln -s "$FF7SYW_DIR" "$symlink"
	fi
	if [[ -d "$FF7SYW_DIR" ]] && [[ -L "$symlink" ]]; then
		ls_symlink=$(ls -l "$symlink")
		display_msg "Répertoire ${FF7SYW_DIR} OK"
		display_msg "Lien symbolique créé:\n" "$ls_symlink"
        else
		display_msg "Problème dans la création du repertoire d'installation et/ou du lien symbolique"
		exit 1
	fi
	echo -e "\n"
}

#Download installer(s) on GoogleDrive.
#$1 is the file name, $2 is the GoogleDrive-ID of the file, $3 is the system directory to store the file.
download_on_gdrive () {
	local file_name
	local file_g_id
	local download_path
	local drive_url

	file_name="$1"
	file_g_id="$2"
	download_path="$3"

	display_msg "Téléchargement de $file_name dans $download_path à partir de GoogleDrive:"
	pushd "$download_path"
	drive_url="https://docs.google.com/uc?export=download&id=${file_g_id}"
	display_cmd wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "$drive_url" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=$file_g_id" -O "$file_name" && rm -rf /tmp/cookies.txt
	popd
}

#Download installer(s) on other server. Used there's a faillure with GoogleDrive.
#$1 is the file name, $2 is the URL of the file, $3 is the system directory to store the file.
download_fallback () {
	local file_name
	local fallback_url
	local download_path

	file_name="$1"
	fallback_url="$2"
	download_path="$3"

	display_msg "Téléchargement de $file_name dans $download_path à partir d'un serveur de substitution:"
	pushd "$download_path"
	display_cmd wget --no-check-certificate "$fallback_url" -O "$file_name"
	popd
}

#Check if the package is complete and not corrupted.
#$1 is the file name, $2 is the checksum, $3 is the directory where the package is stored.
checksum_package_md5 () {
	local file_name
	local checksum_md5
	local package_dir

	file_name="$1"
	checksum_md5="$2"
	package_dir="$3"

	display_msg "Vérification de l'intégrité de $file_name"
	pushd "$package_dir"
	echo -e "$checksum_md5  $file_name" > "$file_name".md5
	if ! md5sum -c "$file_name".md5 ; then
		rm "${file_name}"
                display_msg "Le fichier téléchargé est corrompu ou pas complet\n"
		return 1 
	fi
	rm "$file_name".md5
	popd
}

#Install the package using Proton. If the exe is embedded in a Zip, it unzip it.
#$1 is the MS_Windows executable or zip to install
install_exe_with_proton () {
	local file_name

	file_name="$1"

	pushd "$HOME"/FF7SYWInstaller/
	if [[ "${file_name}" == *.zip ]]; then
		display_msg "Décompression de $file_name"
		display_cmd 7z x "${file_name}"
		file_name=$(unzip -Z1 "${file_name}" | grep .exe)
		rm ./*.zip
	fi
	display_msg "Lancement de l'éxécutable $file_name"
	STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAMAPPS"/../ \
	STEAM_COMPAT_DATA_PATH="$FF7SYW_COMPATDATA"/. \
	"$STEAMAPPS"/common/Proton\ "$PROTON_VERSION"/proton run "$file_name" 1>&2
	popd
}

#Parse FF7SYW_packages variables and launch download/check/install.
download_prepare_install_FF7SYWexes () {
	local total_var_packages
	local var_package_nb
	local package_name
	local file_name
	local file_g_id
	local fallback_url
	local checksum_md5
	local file2install

	display_msg "Préparation de l'environnement, téléchargement (si besoin) et installation des packages"
	mkdir -p "$HOME"/FF7SYWInstaller/
	total_var_packages="$( (set -o posix; set ) | grep -c FF7SYWFR_PACKAGE_)"
	for var_package_nb in $(seq 1 "$total_var_packages"); do
		package_name="FF7SYWFR_PACKAGE_$var_package_nb"
		file_name=$(echo "${!package_name}"| cut -d " " -f 1)
		file_g_id=$(echo "${!package_name}"| cut -d " " -f 2)
		fallback_url=$(echo "${!package_name}"| cut -d " " -f 3)
		checksum_md5=$(echo "${!package_name}"| cut -d " " -f 4)
		if [[ -f "$(xdg-user-dir DOWNLOAD)/${file_name}" ]]; then
			display_msg "$file_name est déjà présent dans le dossier des Téléchargements"
			display_msg "Déplacement dans $HOME/FF7SYWInstaller\n"
			mv "$(xdg-user-dir DOWNLOAD)/${file_name}" "$HOME/FF7SYWInstaller/."
		fi
		if [[ -f "$HOME/FF7SYWInstaller/${file_name}" ]]; then
			display_msg "$file_name est déjà présent dans le dossier FF7SYWInstaller\n"
			checksum_package_md5 "$file_name" "$checksum_md5" "$HOME/FF7SYWInstaller/"
		fi
		if [[ ! -f "$HOME/FF7SYWInstaller/${file_name}" ]]; then
			display_msg "Téléchargement de $file_name"
                        if ! ping -c 1 8.8.8.8 ; then 
				display_msg "Non connecté à Internet\n"
				exit 1
			fi
			download_on_gdrive "${file_name}" "${file_g_id}" "$HOME"/FF7SYWInstaller/
			if ! checksum_package_md5 "$file_name" "$checksum_md5" "$HOME"/FF7SYWInstaller/ ; then
				display_msg "Problème lors du téléchargement à partir de GoogleDrive."
				display_msg "Lancement du téléchargement sur un serveur de substitution"
				download_fallback "${file_name}" "${fallback_url}" "$HOME"/FF7SYWInstaller/
				if ! checksum_package_md5 "$file_name" "$checksum_md5" "$HOME"/FF7SYWInstaller/ ; then
					display_msg "Impossible de télécharger l'installeur ${file_name}. Merci de le télécharger avec Firefox ou Chrome\n"
					exit 1
				fi
			fi
		fi
        file2install+=" ${file_name}"
	sync
	done
	if [[ -d "$FF7SYW_COMPATDATA" ]]; then
		rm -rf "${FF7SYW_COMPATDATA:?}"/*
	else
		mkdir -p "$FF7SYW_COMPATDATA"
	fi
	create_dir_simlink_FF7SYW
	display_msg "Lancement des installeurs FF7SYW.\n\n"
	display_msg "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	display_msg "IMPORTANT: Merci de choisir le repertoire $HOME/FF7SYW/ dans l'installateur graphique!"
	display_msg "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
	sleep 10
	for f in ${file2install}; do 
		install_exe_with_proton "${f}"
	done
}

#Install fonts from FF7SYW launcher in user fonts directory.
install_fonts () {
	local check_fonts_present
	check_fonts_present=$(fc-list | grep -i "Roboto")
	display_msg "Installation des polices du Lanceur de FF7SYW"
	if [[ ! "$check_fonts_present" == *"Roboto-Regular.ttf"* ]] \
	&& [[ ! "$check_fonts_present" == *"Roboto-Black.ttf"* ]]; then
		if [[ ! -d "$HOME"/.local/share/fonts ]]; then
			mkdir -p "$HOME"/.local/share/fonts
		fi
		cp "$FF7SYW_DIR"/FF7_SYW/addfiles/polices/*.ttf "$HOME"/.local/share/fonts/.
		fc-cache -f -v 1>&2 #Force fonts cache regen
	fi
	if [[ ! "$check_fonts_present" == *"Roboto-Regular.ttf"* ]] \
	&& [[ ! "$check_fonts_present" == *"Roboto-Black.ttf"* ]]; then
		display_msg "Les polices sont présentes ou ont été installées\n"
	else
		display_msg "Problème lors de l'install des polices"
	fi
}

#Clean non-needed files to gain space.
clean_install () {
	unlink "$HOME"/FF7_orig
}

#Main
check_FF7_orig_installed
check_proton_installed
create_simlink_FF7Orig
download_prepare_install_FF7SYWexes
install_fonts
clean_install
