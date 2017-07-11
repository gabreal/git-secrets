#!/bin/sh
#
# tested with:
# - openssl (1.1.0f-3, 1.0.1f-1ubuntu2.22)
# - bash 4.4-5
# - dash 0.5.8-2.4
#
# 
# TODO:
# -

# in order to initialize transparent secrets handling do the following
# instructions:


SECRETS_FILE="secrets.file"
ENCRYPTION_KEY_VAR="ENCRYPTION_KEY"

ENCRYPTION_KEY="$(eval echo \${${ENCRYPTION_KEY_VAR}})"



case "${1}" in 
	(''|help|--help)

		cat <<-EOF

		${0} handles transparent secrets file encryption.


		Secrets files are configrued via .gitattributes i.e.

		.gitattributes:
		${SECRETS_FILE} filter=encryptionmagic diff=encryptionmagic

		this file is provided with the repo.


		Running this script with "init" parameter will add the following
		following to .git/config:

		[filter "encryptionmagic"]
			smudge = ./utils/secrets.sh decrypt
			clean = ./utils/secrets.sh encrypt
		
		[diff "encryptionmagic"]
			textconv = cat

		and will search afterwards for files to be decrypted. This can manually
		be performed by invoking 

		    git checkout ${SECRETS_FILE}

		
		The encryption key may either be provided as secondary argument to the
		init command. Then it will be stored in .git/config and needs not
		further be mentioned. Otherwise the encryption key can be provided via
		environment variable ENCRYPTION_KEY.


		
		*** don't use quotes and equal signs in passwords, please ***

		EOF

		exit 0

		;;
	(init)
		git config filter.encryptionmagic.smudge './utils/secrets.sh decrypt'
		git config filter.encryptionmagic.clean './utils/secrets.sh encrypt'
		git config diff.encryptionmagic.textconv cat

		if [ ! -d .git ]
		then
			echo "Please run again from the top-level of the repository for init to be complete."
			exit 1
		fi

		if [ ! -r .gitattributes ] || ! grep -q "${SECRETS_FILE}" .gitattributes
		then
			echo "${SECRETS_FILE} filter=encryptionmagic diff=encryptionmagic" >> .gitattributes
		fi

		if [ "${2}" ]
		then
			# take this as encryption key
			ENCRYPTION_KEY=${2}
			# and store it as configuration value
			git config git-secrets.key "${ENCRYPTION_KEY}"
		fi

		if [ -z "${ENCRYPTION_KEY}" ]
		then
			echo
			echo "> ENCRYPTION_KEY not set!"
			echo
		else
			echo "decrypting ${SECRETS_FILE} s now ..."
			find . -wholename "*${SECRETS_FILE}*" -exec git checkout '{}' \; -print
		fi

		exit 0
		;;
	(encrypt|decrypt)
		;;
	(*)
		echo "${0}: unknown argument ${1}" >&2
		exit 1
		;;
esac



if [ -z "${ENCRYPTION_KEY}" ]
then
	gitkey="$(git config git-secrets.key)"
	if [ "${gitkey}" ]
	then
		ENCRYPTION_KEY="${gitkey}"
	else
		echo "ENCRYPTION_KEY not set" >&2
		return 0
	fi
fi


git config filter.encryptionmagic.clean 2>&1 > /dev/null || \
	( echo "git-secrets not initialized" >&2; return 0 )


while read line
do
	# patterns for lines to ignore
	echo "${line}" | grep -E '^ *#' && continue
	echo "${line}" | grep -v '=' && continue

	key="$(echo ${line} | cut -d '=' -f 1)"
	value="$(echo ${line} | sed -r "s/^[^=]+=[\"'](.*)[\"'][^\"']*$/'\1'/")"

	case "${1}" in 
		(decrypt)
			if [ "${key}" != "${key#GITENC_}" ]
			then
				key="${key#GITENC_}"
				value="$(echo ${value}  | openssl enc -d -base64 -A -aes-256-cbc -md sha256 -nosalt -k ${ENCRYPTION_KEY})"
			else
				echo "# INFO: double-decryption attempt"
			fi
			;;
		(encrypt)
			if [ "${key}" = "${key#GITENC_}" ]
			then
				key="GITENC_${key}"
				value="$(echo ${value}  | openssl enc -e -base64 -A -aes-256-cbc -md sha256 -nosalt -k ${ENCRYPTION_KEY})"
			else
				echo "# INFO: double-encryption attempt"
			fi
			;;
	esac
	echo "${key}=\"${value}\""
done

# vim: set tabstop=4 softtabstop=0 noexpandtab shiftwidth=4:
