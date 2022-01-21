#!/bin/bash

[[ $EUID = 0 ]] ||
{
	echo "Script must be executed as root." >&2
	exit 1
}

getent group docker &>/dev/null ||
groupadd --system docker

for user in flederwiesel jenkins
do
	getent passwd $user &>/dev/null &&
	echo -e "\033[37mUser '$user' already exists.\033[m" ||
	{
		echo -e "\033[36m# Password for user '$user':\033[m"
		passwd=$(openssl passwd -crypt -in <(head -c 16 /dev/urandom | base64 | tee /proc/$$/fd/1))

		useradd --create-home --shell /bin/bash \
			--no-user-group --groups docker \
			--password $passwd $user
	}

	[[ -f /home/$user/.ssh/$user ]] ||
	su $user <<EOF
		ssh-keygen -N '' -f /home/$user/.ssh/$user
EOF
done
