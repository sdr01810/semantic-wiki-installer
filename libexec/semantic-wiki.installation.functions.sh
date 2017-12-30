##/bin/bash source'd
## Installation functions for a semantic wiki.
##
## Installation is performed in unattended mode. Supports Windows and Debian-based Linux.
##
## Installs the Bitnami Tomcat stack, Jena Fuseki, MediaWiki, and various MediaWiki extensions.
##

set -e

##

function install_semantic_wiki() {

	install_technology_stack

	restart_technology_stack

	install_module_fuseki
	install_module_mediawiki

	restart_technology_stack

	report "Done."
}

##

function install_technology_stack() {

	report "Starting Bitnami Tomcat installation to: ${technology_stack_installation_root_dpn:?} ..."

	install_technology_stack_base

	install_technology_stack_configuration
}

function install_technology_stack_base() {

	! [ -e "${technology_stack_installation_root_dpn:?}" ] || return 0

	local installation_mode="$(inferred_bitnami_installation_mode)"
	local installer_program_pn="$(inferred_technology_stack_installer_program_pn)"

	local -a command=(
		"${installer_program_pn:?}"
		--mode "${installation_mode:?}"
		--prefix "${technology_stack_installation_root_dpn:?}"
		--mysql_password "${password:?}"
		--phpmyadmin_password "${password:?}"
		--mysql_database_name "${product_database_name}"
		--mysql_database_username "${product_name_id:?}"
		--mysql_database_password "${password:?}"
		--tomcat_manager_username "${product_name_id:?}"
		--tomcat_manager_password "${password:?}"
		--launch_cloud 0
	)

	mkdir -p "${technology_stack_installation_root_dpn:?}"

	case "${installation_mode:?}" in
	unattended.DISABLED)
		xx "${command[@]}" &
		wait_for_unattended_technology_stack_installation_to_finish
		;;
	*)
		xx "${command[@]}"
		;;
	esac
}

function install_technology_stack_configuration() {

	install_technology_stack_git_configuration

	install_technology_stack_php_configuration

	install_technology_stack_httpd_configuration

	install_technology_stack_tomcat_configuration
}

function install_technology_stack_git_configuration() {

	xxq git config --global --get user.name ||
	xxv git config --global --add user.name "${product_name_tc:?} Administrator"

	xxq git config --global --get user.email ||
	xxv git config --global --add user.email "${product_admin_mail_address:?}"
}

function install_technology_stack_php_configuration() {

	local f1

	case "$(inferred_os_type)" in
	msys|windows)
		for f1 in "${technology_stack_installation_root_dpn:?}/php/php.ini" ; do

			perl -i~ -pe '

				s{^(\s*;\s*)(extension\s*=\s*php_fileinfo.dll)}{$2}i;

			' "$f1"
		done
		;;
	esac
}

function install_technology_stack_httpd_configuration() {

	set_ownership_of_web_content "${technology_stack_installation_root_dpn:?}/apache2/htdocs"
}

function install_technology_stack_tomcat_configuration() {

	local f1

	for f1 in "$(inferred_tomcat_service_setenv_script_fpn)" ; do

		! [ -e "$f1" ] ||
		case "$(inferred_os_type)" in
		msys|windows)
			perl -i~ -pe '

				s{^\s*((?:set\s+)?JAVA_OPTS\s*=.*)(--JvmMs\s+\d+)}{${1}--JvmMs '"${tomcat_service_jvm_heap_min:?}"'};

				s{^\s*((?:set\s+)?JAVA_OPTS\s*=.*)(--JvmMx\s+\d+)}{${1}--JvmMx '"${tomcat_service_jvm_heap_max:?}"'};

			' "$f1"
			;;
		esac

		! [ -e "${f1%.*}.sh" ] ||
		case "$(inferred_os_type)" in
		*)
			perl -i~ -pe '

				s{^\s*((?:export\s+)?JAVA_OPTS\s*=.*)(-Xms\d+[mM])}{${1}-Xms'"${tomcat_service_jvm_heap_min:?}"'M};

				s{^\s*((?:export\s+)?JAVA_OPTS\s*=.*)(-Xmx\d+[mM])}{${1}-Xms'"${tomcat_service_jvm_heap_max:?}"'M};

			' "${f1%.*}.sh"
			;;
		esac
	done

	for f1 in "${tomcat_service_installation_root_dpn:?}/conf/catalina.properties" ; do

		perl -i~ -pe '

			s{\b(tomcat.util.scan.StandardJarScanFilter.jarsToSkip\s*=\s*)}{${1}*,} unless m{=\s*\*,};

		' "$f1"
	done
}

##

function wait_for_unattended_technology_stack_installation_to_finish() {

	wait_for_technology_stack_to_start

	wait_for_technology_stack_installer_to_create_uninstaller

	wait_for_technology_stack_installer_to_stop
}

function wait_for_technology_stack_installer_to_create_uninstaller() {

	report "Ensuring that the technology stack uninstaller has been created..."

	wait_for_nonempty_file "${technology_stack_uninstaller_fpn}"
	wait_for_nonempty_file "${technology_stack_uninstaller_data_fpn}"
}

function wait_for_technology_stack_installer_to_stop() {

	report "Ensuring that the technology stack installer has stopped..."

	wait %% || report_exit_code $? || :
}

##

function start_technology_stack() {

	report "Ensuring that all ${product_name_tc:?} services have started..."

	case "$(inferred_os_type)" in
	msys|windows)
		local s1

		for s1 in MySQL Tomcat Apache ; do

			xx net start "tomcatstack${s1}" ||
			report_exit_code $?
		done
		;;
	*)
		"${technology_stack_cli_fpn:?}" start ||
		report_exit_code $?
		;;
	esac

	wait_for_technology_stack_to_start
}

function wait_for_technology_stack_to_start() {

	wait_for_nonempty_file "${mysql_service_pid_fpn}"

	wait_for_nonempty_file "${tomcat_service_pid_fpn}"

	wait_for_nonempty_file "${http_service_pid_fpn}"
}

function stop_technology_stack() {

	report "Ensuring that all ${product_name_tc:?} services have stopped..."

	case "$(inferred_os_type)" in
	msys|windows)
		local s1

		for s1 in Apache Tomcat MySQL ; do

			xx net stop "tomcatstack${s1}" ||
			report_exit_code $?
		done
		;;
	*)
		"${technology_stack_cli_fpn:?}" stop ||
		"${technology_stack_cli_fpn:?}" stop ||
		report_exit_code $?
		;;
	esac
}

function restart_technology_stack() {

	report "Restarting all ${product_name_tc:?} services..."

	case "$(inferred_os_type)" in
	msys|windows)
		local s1

		for s1 in Apache Tomcat MySQL ; do

			xxq net stop "tomcatstack${s1}" || :
		done
		for s1 in MySQL Tomcat Apache ; do

			xxv net start "tomcatstack${s1}"
		done
		;;
	*)
		"${technology_stack_cli_fpn:?}" restart ||
		report_exit_code $?
		;;
	esac

	wait_for_technology_stack_to_start

	report_technology_stack_status
}

function report_technology_stack_status() {

	report "Resulting status of ${product_name_tc:?} services:"

	case "$(inferred_os_type)" in
	msys|windows)
		local s1

		for s1 in Apache Tomcat MySQL ; do

			xx sc query "tomcatstack${s1}" ||
			report_exit_code $?
		done
		;;
	*)
		"${technology_stack_cli_fpn:?}" status ||
		report_exit_code $?
		;;
	esac
}

##

function install_module_fuseki() {

	if [ ! -e "${technology_stack_installation_root_dpn:?}" ] ; then
		report "Not yet installed: ${technology_stack_installation_root_dpn:?}; aborting..."
		return 2
	fi

	report "Starting Fuseki installation to: ${module_fuseki_installation_root_dpn:?} ..."

	install_module_fuseki_base

	install_module_fuseki_configuration
}

function install_module_fuseki_base() {

	! [ -e "${module_fuseki_installation_root_dpn:?}" ] || return 0

	local tarball_pn="$(inferred_module_fuseki_tarball_pn)"

	mkdir -p "${module_fuseki_installation_root_dpn:?}"

	xx tar xf "${tarball_pn:?}" --strip-components 1 \
		-C "${module_fuseki_installation_root_dpn:?}"
}

function install_module_fuseki_configuration() {

	install_module_fuseki_local_configuration

	install_module_fuseki_tomcat_configuration
}

function install_module_fuseki_local_configuration() {

	local d1

	for d1 in "${module_fuseki_installation_root_dpn:?}/etc" ; do

		mkdir -p "$d1" ; set_ownership_of_webapp_content "$d1"
	done
}

function install_module_fuseki_tomcat_configuration() {

	local d1 f1

	install_technology_stack_tomcat_configuration #! FIXME: HACK

	for d1 in "${module_fuseki_installation_root_dpn:?}/etc" ; do
	for f1 in "$(inferred_tomcat_service_setenv_script_fpn)" ; do

		case "$(inferred_os_type)" in
		msys|windows)
			perl -i~ -pe '

				s{[ \t]*$}{}; # trim trailing space

				if (m#^\s*(?:set\s+)FUSEKI_BASE\s*=#) {

					$_ = "" . "set FUSEKI_BASE='"${d1}"'$/";

					$found_FUSEKI_BASE = 1;
				}

				if (eof && ! defined($found_FUSEKI_BASE)) {

					$_ = $_ . "set FUSEKI_BASE='"${d1}"'$/";

					$found_FUSEKI_BASE = 1;
				}

				#^-- no spaces allowed in FUSEKI_BASE

			' "$f1"
			;;
		*)
			perl -i~ -pe '

				s{[ \t]*$}{}; # trim trailing space

				if (m#^\s*(?:export\s+)FUSEKI_BASE\s*=#) {

					$_ = "" . "export FUSEKI_BASE='"${d1}"'$/";

					$found_FUSEKI_BASE = 1;
				}

				if (eof && ! defined($found_FUSEKI_BASE)) {

					$_ = $_ . "export FUSEKI_BASE='"${d1}"'$/";

					$found_FUSEKI_BASE = 1;
				}

				#^-- no spaces allowed in FUSEKI_BASE

			' "$f1"
			;;
		esac

		set_ownership_of_webapp_content "$f1"
	done;done

	for f1 in "${module_fuseki_installation_root_dpn:?}/fuseki.war" ; do
	for f2 in "${tomcat_service_installation_root_dpn:?}/webapps/${f1##*/}" ; do

		cp "$f1" "$f2" ; set_ownership_of_webapp_content "$f2"
	done;done
}

##

function install_module_mediawiki() {

	if [ ! -e "${technology_stack_installation_root_dpn:?}" ] ; then
		report "Not yet installed: ${technology_stack_installation_root_dpn:?}; aborting..."
		return 2
	fi

	report "Starting MediaWiki installation to: ${module_mediawiki_installation_root_dpn:?} ..."

	install_module_mediawiki_base

	install_module_mediawiki_configuration

	install_module_mediawiki_extensions_needed
}

function install_module_mediawiki_base() {

	! [ -e "${module_mediawiki_installation_root_dpn:?}/htdocs" ] || return 0

	local tarball_pn="$(inferred_module_mediawiki_tarball_pn)"

	mkdir -p "${module_mediawiki_installation_root_dpn:?}/htdocs"

	xx tar xf "${tarball_pn:?}" --strip-components 1 \
		-C "${module_mediawiki_installation_root_dpn:?}/htdocs"
}

function install_module_mediawiki_configuration() {

	install_module_mediawiki_php_configuration

	install_module_mediawiki_local_configuration

	install_module_mediawiki_httpd_configuration
}

function install_module_mediawiki_php_configuration() {

	true # TODO: srogers: performance: customize PHP for MediaWiki (use APC, perhaps?)
}

function install_module_mediawiki_local_configuration() {(

	local wiki_admin_user_name="${product_name_id:?}"
	local wiki_name="${product_name_tc% Wiki} Wiki"
	local wiki_script_path="/wiki"

	local php_path_fragment=
	case "$(inferred_os_type)" in
	msys|windows)
		php_path_fragment="${technology_stack_installation_root_dpn:?}/php"
		php_path_fragment="$(as_unix_pathname "${php_path_fragment:?}")"
		PATH="${php_path_fragment:?}:${PATH}"
		#^-- FIXME: srogers: test against Windows 10 bash
		;;
	*)
		php_path_fragment="${technology_stack_installation_root_dpn:?}/php/bin"
		PATH="${php_path_fragment:?}:${PATH}"
		;;
	esac

	cd "${module_mediawiki_installation_root_dpn:?}/htdocs"

	rm -f LocalSettings.php

	xx php maintenance/install.php \
		--dbtype "mysql" \
		--dbserver "localhost" \
		--installdbuser "root" \
		--installdbpass "${password:?}" \
		--dbname "${product_database_name?}" \
		--dbuser "${product_name_id:?}" \
		--dbpass "${password:?}" \
		--server "${product_site_root_url:?}" \
		--pass "${password:?}" \
		"${wiki_name:?}" \
		"${wiki_admin_user_name:?}"

	perl -i~ -pe "

		s'\".*\"'\"$(printf %q "${product_admin_mail_address:?}")\"'  if m{\\\$wgEmergencyContact\\s*=};

		s'\".*\"'\"$(printf %q "${product_admin_mail_address:?}")\"'  if m{\\\$wgPasswordSender\\s*=};

		s'\".*\"'\"$(printf %q "${wiki_script_path:?}")\"'            if m{\\\$wgScriptPath\\s*=};

	" LocalSettings.php

	set_ownership_of_web_content .
)}

function install_module_mediawiki_httpd_configuration() {

	local this_package_root_dpn="$(dirname "$(dirname "$0")")"
	local f1

	for f1 in {htaccess,httpd-app,httpd-prefix}.conf ; do

		create_file_from_template \
			"${this_package_root_dpn:?}/share/mediawiki/conf/${f1}.in" \
			"${module_mediawiki_installation_root_dpn:?}/conf/${f1}"
	done

	##

	local include_directive="Include \"${module_mediawiki_installation_root_dpn:?}/conf/httpd-prefix.conf\""

	for f1 in "${http_service_installation_root_dpn:?}/conf/bitnami/bitnami-apps-prefix.conf" ; do

		fgrep -q "${include_directive}" "$f1" || echo "${include_directive}" >> "$f1"
	done

	##

	for f1 in "${tomcat_service_installation_root_dpn:?}/conf/tomcat.conf" ; do

		perl -i~ -pe 'next if m{(\bserver-status\b)\|wiki\b} ; s{(\bserver-status\b)}{$1|wiki}' "$f1"
	done
}

function install_module_mediawiki_extensions_needed() {

	local extensions_root_dpn="${module_mediawiki_installation_root_dpn:?}/htdocs/extensions"
	local f1

	mkdir -p "${extensions_root_dpn:?}"

	for f1 in "$(dirname "$(dirname "$0")")/share/mediawiki-extensions.needed.txt" ; do

		xx cat "$f1" | omit_wsac |

		while read name release git_commit_id git_repo_url ; do

			install_module_mediawiki_extension_under "${extensions_root_dpn:?}" \
				"${name:?}" "${release:?}" "${git_commit_id:?}" "${git_repo_url:?}"
		done
	done

	set_ownership_of_web_content "${extensions_root_dpn:?}"
}

function install_module_mediawiki_extension_under() { # extensions_root_dpn name release git_commit_id git_repo_url

	local extensions_root_dpn="${1:?}" ; shift 1

	local name="${1:?}" release="${2:?}" ; shift 2

	local git_commit_id="${1:?}" git_repo_url="${2:?}" ; shift 2

	local extension_patches_root_dpn="$(realpath "$(dirname "$(dirname "$0")")/share/mediawiki-extension-patches")"
	local d1 p1

	for d1 in "${extensions_root_dpn:?}" ; do
	(
		xx cd "$d1"

		if [ -d "${name:?}" -a ! -e "${name:?}/.git" ] ; then

			xx rm -rf "${name:?}" # prepare to replace a standard extension
		fi

		! [ -e "${name:?}" ] || return 0

		xx git clone "${git_repo_url:?}" "${name:?}"

		xx cd "${name:?}"

		xx git checkout -b "${release:?}" "${git_commit_id:?}"

		xx git checkout -b "${release:?}-local"

		capture_git_submodule_updates

		for p1 in "${extension_patches_root_dpn:?}/${name:?}/${release:?}"/*.patch ; do

			[ -e "$p1" ] || continue

			xx patch -p1 -i "$p1"

			xx git add -A :/
			xx git commit -m "Apply patch: ${p1##*/}."
		done

		capture_git_submodule_updates

		! false ||
		xx git log --reverse "${release:?}..${release:?}-local"
	)
	done
}

function capture_git_submodule_updates() {

	if [ -e ".gitmodules" ] ; then

		xx git submodule update --init --recursive
			
		xx git add -A :/
		xx git commit -m "Capture submodule updates (if any)." --allow-empty
	fi
}


##

function inferred_technology_stack_installer_program_pn() {

	local version="${technology_stack_version:?}"

	local sha1= # depends on platform
	local local_fpn="./Bitnami-Tomcat-${version:?}.installer$(inferred_installer_program_suffix)"
	local remote_url="https://downloads.bitnami.com/files/stacks/tomcatstack/${version:?}/bitnami-tomcatstack-${version:?}-"

	case "$(inferred_os_type)" in
	msys|windows)
		case "$(inferred_cpu_type)" in
		x86_32|x86_64)
			sha1="${technology_stack_installer_x86_32_windows_sha1:?}"
			remote_url="${remote_url:?}windows-installer.exe"
			;;
		*)
			report "CPU type not supported: $(inferred_cpu_type)"
			return 2
			;;
		esac
		;;
	linux-gnu)
		case "$(inferred_cpu_type)" in
		x86_64)
			sha1="${technology_stack_installer_x86_64_linux_sha1:?}"
			remote_url="${remote_url:?}linux-x64-installer.run"
			;;
		*)
			report "CPU type not supported: $(inferred_cpu_type)"
			return 2
			;;
		esac
		;;
	*)
		assert_cannot_happen
		;;
	esac

	ensure_file_downloaded_to "${local_fpn:?}" "${sha1:?}" "${remote_url:?}"

	chmod +x "${local_fpn:?}"

	echo "${local_fpn:?}"
}

function inferred_module_fuseki_tarball_pn() {

	local version="${module_fuseki_version:?}"

	local sha1="${module_fuseki_tarball_sha1:?}"
	local local_fpn="./fuseki-${version:?}.tar.gz"
	local remote_url="http://archive.apache.org/dist/jena/binaries/apache-jena-fuseki-${version:?}.tar.gz"

	ensure_file_downloaded_to "${local_fpn:?}" "${sha1:?}" "${remote_url:?}"

	echo "${local_fpn:?}"
}

function inferred_module_mediawiki_tarball_pn() {

	local version="${module_mediawiki_version:?}"
	local version_major_minor="$(echo "${version:?}" | perl -lpe 's{^(\d+\.\d+)\D.*$}{$1}')"

	local sha1="${module_mediawiki_tarball_sha1:?}"
	local local_fpn="./mediawiki-${version:?}.tar.gz"
	local remote_url="https://releases.wikimedia.org/mediawiki/${version_major_minor:?}/mediawiki-${version:?}.tar.gz"

	ensure_file_downloaded_to "${local_fpn:?}" "${sha1:?}" "${remote_url:?}"

	echo "${local_fpn:?}"
}

##

function inferred_product_site_root_url() {

	echo "${product_site_root_url:-http://$(hostname --fqdn)}"
}

function inferred_product_name_tc() {

	echo "${product_name_tc:-Semantic Wiki}" # title case
}

function inferred_product_name_lc() {

	inferred_product_name_tc |

	perl -lpe '$_ = lc' # lower case
}

function inferred_product_name_id() {

	inferred_product_name_lc |

	perl -lpe 's{\W}{_}g' # identifier syntax
}

function inferred_product_name_pn() {

	case "$(inferred_os_type)" in
	msys|windows)
		inferred_product_name_tc
		;;
	*)
		inferred_product_name_lc
		;;
	esac |

	perl -lpe 's{\s}{-}g' # pathname without spaces
}

function inferred_installer_program_suffix() {

	local rc=0 result=".$(inferred_cpu_type)"

	case "$(inferred_os_type)" in
	msys|windows)
		result="${result}.exe"
		;;
	linux-gnu)
		result="${result}.linux.run"
		;;
	*)
		report "OS type not supported: $(inferred_os_type)"
		rc=2
		;;
	esac

	echo "${result:?}"
	return ${rc}
}

function inferred_XAMP_name() {

	case "$(inferred_os_type)" in
	msys|windows)
		echo "WAMP"
		;;
	*)
		echo "LAMP"
		;;
	esac
}

function inferred_os_type() {

	local rc=0 result="${OSTYPE:-unspecified}"

	case "${result:?}" in
	linux-gnu)
		case "${OS}"xx in
		Windows*)
			result="windows"
			#^-- Windows 10 provides its own bash
			;;
		esac
		;;
	msys)
		true
		;;
	unspecified)
		report "OS type not specified"
		rc=2
		;;
	esac

	echo "${result:?}"
	return ${rc}
}

function inferred_cpu_type() {

	local rc=0 result="${HOSTTYPE:-unspecified}"

	case "$(inferred_os_type)" in
	msys|windows)
		case "${PROCESSOR_ARCHITECTURE:-unspecified}" in
		unspecified)
			report "Windows processor architecture not specified"
			rc=2
			;;
		*)
			result="${PROCESSOR_ARCHITECTURE:?}"
			;;
		esac
		;;
	esac

	case "${result:?}" in
	x86_32|x86|i[0-9]86)
		result="x86_32"
		;;
	x86_64|amd64)
		result="x86_64"
		;;
	unspecified)
		report "CPU type not specified"
		rc=2
		;;
	esac

	echo "${result:?}"
	return ${rc}
}

function inferred_configuration_file_pn() {

	local this_script_fbn="$(basename "$0")"
	local this_script_fpn="$0"

	local result="${this_script_fbn%.*sh}".conf

	[ -e "${result:?}" ] || result="${this_script_fpn%.*sh}".conf

	echo "${result}"
}

function inferred_technology_stack_installation_root_dpn() {

	case "$(inferred_os_type)" in
	msys|windows)
		echo "c:/Stacks/$(inferred_product_name_pn)"
		;;
	*)
		echo "/opt/$(inferred_product_name_pn)"
		;;
	esac
}

function inferred_module_mediawiki_installation_root_dpn() {

	echo "$(inferred_technology_stack_installation_root_dpn)/apps/mediawiki"
}

function inferred_module_fuseki_installation_root_dpn() {

	echo "$(inferred_technology_stack_installation_root_dpn)/apps/fuseki"
}

function inferred_tomcat_service_setenv_script_fpn() {

	local result="${tomcat_service_installation_root_dpn:?}/bin/setenv"

	case "$(inferred_os_type)" in
	msys|windows)
		result="${result}.bat"
		;;
	*)
		result="${result}.sh"
		;;
	esac

	echo "${result:?}"
}

function inferred_bitnami_installation_mode() {

	case "$(inferred_os_type)" in
	msys|windows)
		echo "qt" # interactive GUI-based installation
		;;
	*)
		echo "unattended" # non-interactive installation
		;;
	esac
}

##

function ensure_file_downloaded_to() { # file_pn file_sha1 file_remote_url

	local file_pn="${1:?}"
	local file_sha1="${2:?}"
	local file_remote_url="${3:?}"

	[ -e "${file_pn:?}" ] ||
	xx curl --output "${file_pn:?}" "${file_remote_url:?}"

	check_sha1sum_of "${file_pn:?}" "${file_sha1:?}"
}

function check_sha1sum_of() { # file_pn file_sha1

	xx echo "${2:?}  ${1:?}" | xx sha1sum --check --status -
}

##

function create_file_from_template() { # template_file_pn file_pn

	local template_file_pn="${1:?}"
	local file_pn="${2:?}"

	mkdir -p "$(dirname "${file_pn:?}")" ; > "${file_pn:?}"

	xx cat "${template_file_pn:?}" | perl -lpe "

		s'\\\$\\{technology_stack_installation_root_dpn}'$(printf %q "${technology_stack_installation_root_dpn:?}")';

		s'\\\$\\{module_mediawiki_installation_root_dpn}'$(printf %q "${module_mediawiki_installation_root_dpn:?}")';

	" > "${file_pn:?}"
}

##

function set_ownership_of_web_content() { # file_or_directory_pn ...

	set_ownership daemon www-data "$@"
}

function set_ownership_of_webapp_content() { # file_or_directory_pn ...

	set_ownership tomcat tomcat "$@"
}

function set_ownership() { # user_name group_name file_or_directory_pn ...

		local u1="${1:?}" ; shift
		local g1="${1:?}" ; shift
		local x1

		(is_user "$u1" && is_group "$g1") || return 0

		for x1 in "$@" ; do

			if [ -d "$x1" ] ; then
				xx chmod -R a+rX,ug+w,o-w "$x1"/.
				xx chown -R "$u1"."$g1"   "$x1"/.
			else
				xx chmod a+rX,ug+w,o-w "$x1"
				xx chown "$u1"."$g1"   "$x1"
			fi
		done
}

function is_user() { # user_name

	hash getent >/dev/null 2>&1 || return $?

	getent passwd "${1:?}" >/dev/null 2>&1
}

function is_group() { # group_name

	hash getent >/dev/null 2>&1 || return $?

	getent group "${1:?}" >/dev/null 2>&1
}

##

function wait_for_nonempty_file() { # file_pn

	! [ -z "${1}" ] || return 0

	while ! xxq [ -s "${1:?}" ] ; do sleep_awhile ; done
}

function sleep_awhile() {

	sleep 10
}

##

function as_unix_pathname() { # msys_or_windows_pathname

	if hash cygpath >/dev/null 2>&- ; then

		cygpath -u "${1}"
	else
		echo "$1" | perl -pe 's{^([a-zA-Z]):} {/$1}'
	fi
}

function omit_wsac() {

	perl -ne 'next if m{^\s*#|^\s*$} ; print' "$@"

	#^-- filter: omit whitespace and comments
}

##

function assert_cannot_happen() {

	report "Internal logic error at line ${BASH_LINENO[1]} in file ${BASH_SOURCE[1]}."

	exit 2
}

function assert() { # expression

	! (eval "$@") || return 0

	report "Assertion failed at line ${BASH_LINENO[1]} in file ${BASH_SOURCE[1]}:" "$@"

	exit 2
}

##

function xx() { # ...

	xxv "$@"
}

function xxq() { # ...

	echo 1>&2 "+" "$@"

	"$@" # quietly: no exit code report
}

function xxv() { # ...

	echo 1>&2 "+" "$@"

	"$@" || report_exit_code $?
}

function report() { # ...

	echo 1>&2
	echo 1>&2 "+" "$@"
}

function report_exit_code() { # xc

	local xc="${1:-$?}"

	echo 1>&2 "^-- EXIT CODE: ${xc}"

	return ${xc}
}

##

product_name_tc= # inferred unless set by .conf file

product_site_root_url= # inferred unless set by .conf file

##

password="not_secure"

product_admin_mail_address="devops@example.com"

##

tomcat_service_jvm_heap_min=512

tomcat_service_jvm_heap_max=1024

##

module_fuseki_version="2.6.0"

module_mediawiki_version="1.29.1"

technology_stack_version="8.5.24-2"

##
##^-- default configuration parameters above
##^

source "$(inferred_configuration_file_pn)" ||
report_exit_code $?

umask 0022
#^-- required by the Bitnami installer

set -e
#^-- required by these scripts

##v
##v-- derived configuration parameters below
##

product_name_tc="$(inferred_product_name_tc)"

product_site_root_url="$(inferred_product_site_root_url)"

##

product_name_id="$(inferred_product_name_id)"
product_name_lc="$(inferred_product_name_lc)"
product_name_pn="$(inferred_product_name_pn)"

module_fuseki_installation_root_dpn="$(inferred_module_fuseki_installation_root_dpn)"

module_mediawiki_installation_root_dpn="$(inferred_module_mediawiki_installation_root_dpn)"

technology_stack_installation_root_dpn="$(inferred_technology_stack_installation_root_dpn)"

##

product_database_name="${product_name_id%_db}_db"

##

http_service_installation_root_dpn="${technology_stack_installation_root_dpn:?}/apache2"

mysql_service_installation_root_dpn="${technology_stack_installation_root_dpn:?}/mysql"

tomcat_service_installation_root_dpn="${technology_stack_installation_root_dpn:?}/apache-tomcat"

##

technology_stack_cli_fpn="${technology_stack_installation_root_dpn}/ctlscript.sh"
technology_stack_uninstaller_fpn="${technology_stack_installation_root_dpn}/uninstall"
technology_stack_uninstaller_data_fpn="${technology_stack_installation_root_dpn}/uninstall.dat"

case "$(inferred_os_type)" in
msys|windows)
	http_service_pid_fpn="${http_service_installation_root_dpn}/logs/httpd.pid"
	mysql_service_pid_fpn="${mysql_service_installation_root_dpn}/data/$(hostname).pid"
	tomcat_service_pid_fpn= # no .pid file provided
	;;
*)
	http_service_pid_fpn="${http_service_installation_root_dpn}/logs/httpd.pid"
	mysql_service_pid_fpn="${mysql_service_installation_root_dpn}/data/mysqld.pid"
	tomcat_service_pid_fpn="${tomcat_service_installation_root_dpn}/temp/catalina.pid"
	;;
esac

##

case "${module_fuseki_version:?}" in
2.6.0)
	module_fuseki_tarball_sha1="92f27e01268ad47737bafd164474e36238351c86"
	;;
3.4.0)
	module_fuseki_tarball_sha1="514913b50d27798f3688a45a59f9bf5130b0dff2"
	;;
3.5.0)
	module_fuseki_tarball_sha1="ee89efb913cbab1840ad15ed426635c8f0529d1f"
	;;
*)
	report "Fuseki version not supported: ${module_fuseki_version:?}"
	return 2
esac

case "${module_mediawiki_version:?}" in
1.29.1)
	module_mediawiki_tarball_sha1="4ceacc2b5f883f37ed696fbe5413d547652acdc4"
	;;
1.30.0)
	module_mediawiki_tarball_sha1="16f4831904dbb7a67de2b78ebb968999d2fb996c"
	;;
*)
	report "MediaWiki version not supported: ${module_mediawiki_version:?}"
	return 2
esac

case "${technology_stack_version:?}" in
8.5.24-2)
	technology_stack_installer_x86_64_linux_sha1="4c0177a8d8e489c40594d414953d5ab42c4345e7"
	technology_stack_installer_x86_32_windows_sha1="52650ac59499da74feb63e944be18c5d235ac8fa"
	;;
*)
	report "Bitnami Tomcat stack version not supported: ${technology_stack_version:?}"
	return 2
esac

##

