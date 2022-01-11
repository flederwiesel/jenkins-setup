#!/bin/bash

{
url=http://ubuntu-devel:8080

jenkins-cli()
{
	java -jar /usr/share/java/jenkins-cli.jar \
		-s "$url/" -auth \
		@$HOME/jenkins-auth "$@"
}

cat <<EOF
# Jenkins CLI commands

version $(jenkins-cli version)

<style>
a {
	font-weight: bold;
}
</style>
EOF

jenkins-cli 2>&1 |
awk '/^  [^ ]/ {
	cmd = $1
}

/^    / {
	desc[cmd] = $0
}

BEGIN {
	commands["build"]         = "build clear-queue delete-builds keep-build list-changes set-build-description set-build-display-name set-external-build-result stop-builds"
	commands["configuration"] = "apply-configuration check-configuration export-configuration reload-configuration reload-jcasc-configuration "
	commands["credentials"]   = "create-credentials-by-xml create-credentials-domain-by-xml delete-credentials delete-credentials-domain get-credentials-as-xml get-credentials-domain-as-xml import-credentials-as-xml list-credentials list-credentials-as-xml list-credentials-context-resolvers list-credentials-providers update-credentials-by-xml update-credentials-domain-by-xml"
	commands["job"]           = "add-job-to-view copy-job create-job delete-job disable-job enable-job get-job list-jobs reload-job update-job"
	commands["misc"]          = "console get-gradle groovy groovysh help mail session-id version who-am-i"
	commands["node"]          = "connect-node create-node delete-node disconnect-node get-node offline-node online-node update-node wait-node-offline wait-node-online"
	commands["pipeline"]      = "declarative-linter replay-pipeline restart-from-stage"
	commands["plugin"]        = "disable-plugin enable-plugin install-plugin list-plugins "
	commands["system"]        = "cancel-quiet-down quiet-down restart safe-restart safe-shutdown shutdown"
	commands["view"]          = "create-view delete-view get-view remove-job-from-view update-view"
}

END {

	# for (.. in ..) does not give us sorted output (sigh)...
	for (c in commands)
		groups[i++] = c

	asort(groups, groups)

	for (i = 1; i <= length(groups); i++)
	{
		print "## " groups[i]

		split(commands[groups[i]], cmdgroup, " ")

		for (c in cmdgroup)
		{
			command = cmdgroup[c]

			print "- [" command "]('"$url"'/cli/command/" command ")"
			print "    " desc[command]

			delete desc[command]
		}
	}

	unknown = length(desc)

	if (unknown)
	{
		print "Found " unknown " unknown command" (unknown < 2 ? "" : "") ":" > "/dev/stderr"

		for (d in desc)
			print "    " d > "/dev/stderr"
	}
}'
} > jenkins-cli-commands.md
