#!/bin/sh -e
#
# tested with:
# - openssl (1.1.0g, 1.1.0f-3, 1.0.1f-1ubuntu2.22)
# - bash (4.4-5)
# - dash (0.5.8-2.4, 0.5.8-2.10)
# - zsh  (5.4.2-3)
#
# git-secrets
# 
# initialization of transparent secrets handling:
# - either set up ENCRYPTION_KEY environment variable and run
#   ./utils/secrets.sh init
# - or run ./utils/secrets.sh init ${ENCRYPTION_KEY}
# the latter one will store the key in .git/config for further usage
 


SECRETS_FILE="secrets.file"
ENCRYPTION_KEY_VAR="ENCRYPTION_KEY"

ENCRYPTION_KEY="$(eval echo \${${ENCRYPTION_KEY_VAR}})"

EQ="="

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
		environment variable ${ENCRYPTION_KEY_VAR}.


		
		*** don't use quotes and equal signs in passwords, please ***

		EOF

		exit 0

		;;
	(init)

		if [ ! -d .git ]
		then
			echo "Please run again from the top-level of the repository for init to be complete."
			exit 1
		fi

		git config filter.encryptionmagic.smudge './utils/secrets.sh decrypt'
		git config filter.encryptionmagic.clean './utils/secrets.sh encrypt'
		git config diff.encryptionmagic.textconv cat

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
			echo "> ${ENCRYPTION_KEY_VAR} not set!"
			echo
		else
			echo "decrypting ${SECRETS_FILE} s now ..."
			find . -wholename "*${SECRETS_FILE}*" -print | while read file
				do
					grep -q '^GITENC_' "${file}" && rm -vf "${file}"
					git checkout "${file}"
				done
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
		echo "${ENCRYPTION_KEY_VAR} not set" >&2
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

	key="$(echo -n "${line}" | sed -r 's/^([^ =]+)[ =]+.*$/\1/')"
	value="$(echo -n "${line}" | sed -r 's/^[^ =]+[ =]+["\x27](.*)["\x27] *$/\1/')"

	test "${DEBUG}" && echo "${1}: ${key}=${EQ}=\"${value}\"" >&2

	if [ -z "${value}" ]
	then
		echo "# ERROR: malformed ${SECRETS_FILE} at key ${key}" >&2
		exit 1
	fi

	case "${1}" in 
		(decrypt)
			if [ "${key}" != "${key#GITENC_}" ]
			then
				key="${key#GITENC_}"
				value="$(echo -n "${value}" | openssl enc -d -base64 -A -aes-256-cbc -md sha256 -nosalt -k ${ENCRYPTION_KEY})"
			else
				echo "# INFO: double-decryption attempt" >&2
			fi
			;;
		(encrypt)
			if [ "${key}" = "${key#GITENC_}" ]
			then
				key="GITENC_${key}"
				value="$(echo -n "${value}" | openssl enc -e -base64 -A -aes-256-cbc -md sha256 -nosalt -k ${ENCRYPTION_KEY})"
			else
				echo "# INFO: double-encryption attempt" >&2
			fi
			;;
	esac

	if [ -z "${value}" ]
	then
		echo "# ERROR: empty value at key ${key}" >&2
		exit 1
	fi
	test "${DEBUG}" && echo "${1}: ${key}=${EQ}=\"${value}\"" >&2
	echo "${key}${EQ}\"${value}\""
done

# vim: set tabstop=4 softtabstop=0 noexpandtab shiftwidth=4:
