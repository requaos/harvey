#!/usr/bin/env bash
# (env-shebang: NixOS hosts carry no /bin/bash — the venue-portability
# fix; this file is exec'd via `su -c ./BUILD` from BUILD_SETUP_NAMESPACE,
# so the interpreter line is load-bearing)
set +x
. buildnamespace
which mk
export FORCERCFORMK=1
mk clean
mk libs
# yes, plan 9 really needs this!
PATH=$PATH:.
mk all

time rc $HARVEY/build/scripts/linux-build

# in case of emergency break glass
bash
