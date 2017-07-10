
utils/secrets.sh handles transparent secrets file encryption.


Secrets files are configrued via .gitattributes i.e.

.gitattributes:
secrets.file filter=encryptionmagic diff=encryptionmagic

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

    git checkout secrets.file


The encryption key may either be provided as secondary argument to the
init command. Then it will be stored in .git/config and needs not
further be mentioned. Otherwise the encryption key can be provided via
environment variable ENCRYPTION_KEY.



*** don't use quotes and equal signs in passwords, please ***


sample password for this repo: XenonIrisWellsIdiot1995Grog
