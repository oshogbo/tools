#!/bin/sh
#
# Copyright (c) 2018 Konrad Witaszczyk <def@FreeBSD.org>
# Copyright (c) 2018 Mariusz Zaborski <oshogbo@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

. $HOME/.pwdbrc

usage()
{
	echo "usage: pwdb command args ..."
	echo
	echo "	add <name> <username>"
	echo "	del <name>"
	echo "	change <name> <username> <password>"
	echo "	gen"
	echo "	list"
	echo "	get <name>"
	echo "	show <name>"
	exit 1
}

die()
{
	echo "${*}" >&2
	exit 1
}

sshcmd()
{
	ssh -q "${PWDB_HOST}" $*
}

pwdb_read()
{
	sshcmd "cat ${PWDB_PATH}" | gpg --decrypt 2>/dev/null
}

pwdb_write()
{
	gpg --encrypt --recipient "${PWDB_ID}" 2>/dev/null | sshcmd "cat > ${PWDB_PATH}.new; "
	[ $? -eq 0 ] || die "GnuPG returned invalid value."
	sshcmd mv "${PWDB_PATH}.new" "${PWDB_PATH}" || die "Unable to store new value."
}

pwdb_new()
{
	local password

	password=`openssl rand -base64 12 2>/dev/null`
	if [ $? -ne 0 ] || [ -z "${password}" ]; then
		die "OpenSSL returned invalid value." >&2
	fi

	echo "${password}"
}

pwdb_change()
{
	name="$1"
	[ -n "${name}" ] || die "Missing name."

	username="$2"
	[ -n "${username}" ] || die "Missing username."

	password="$3"
	[ -n "${password}" ] || die "Missing password."

	(pwdb_read | grep -v "^${name}: " && echo "${name}: ${username} ${password}") | pwdb_write || exit 1
}

pwdb_gen()
{
	pwdb_new
}

pwdb_show()
{
	local name

	name="$1"
	[ -n "${name}" ] || die "Missing name."

	pwdb_read | sed -n "s/^${name}:\(.*\)$/\1/p"
}

pwdb_add()
{
	local name username password

	name="$1"
	[ -n "${name}" ] || die "Missing name."

	username="$2"
	[ -n "${username}" ] || die "Missing username."

	password=`pwdb_show "${name}"`
	[ -z "${password}" ] || die "You must delete old password."

	password=`pwdb_new`

	(pwdb_read && echo "${name}: ${username} ${password}") | pwdb_write || exit 1

	echo "${password}"
}

pwdb_del()
{
	local name

	name="$1"
	[ -n "${name}" ] || die "Missing name."

	pwdb_read | sed "/^${name}:.*$/d" | pwdb_write || exit 1
}

pwdb_list()
{
	pwdb_read | sed -n 's/^\(.*\):.*$/\1/p' | sort
}

[ -n "${PWDB_ID}" ] || die "Missing identity."
[ -n "${PWDB_HOST}" ] || die "Missing remote server."

case "$1" in
"add")
	pwdb_add "$2" "$3"
	;;
"del")
	pwdb_del "$2"
	;;
"change")
	pwdb_change "$2" "$3" "$4"
	;;
"list")
	pwdb_list
	;;
"get")
	pwdb_show "$2"
	;;
"show")
	pwdb_show "$2"
	;;
*)
	usage
	;;
esac
