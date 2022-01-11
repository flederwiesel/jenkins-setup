# Jenkins CLI commands

version 2.319.1

<style>
a {
	font-weight: bold;
}
</style>
## build
- [build](http://ubuntu-devel:8080/cli/command/build)
        Builds a job, and optionally waits until its completion.
- [clear-queue](http://ubuntu-devel:8080/cli/command/clear-queue)
        Clears the build queue.
- [delete-builds](http://ubuntu-devel:8080/cli/command/delete-builds)
        Deletes build record(s).
- [keep-build](http://ubuntu-devel:8080/cli/command/keep-build)
        Mark the build to keep the build forever.
- [list-changes](http://ubuntu-devel:8080/cli/command/list-changes)
        Dumps the changelog for the specified build(s).
- [set-build-description](http://ubuntu-devel:8080/cli/command/set-build-description)
        Sets the description of a build.
- [set-build-display-name](http://ubuntu-devel:8080/cli/command/set-build-display-name)
        Sets the displayName of a build.
- [set-external-build-result](http://ubuntu-devel:8080/cli/command/set-external-build-result)
        Set external monitor job result.
- [stop-builds](http://ubuntu-devel:8080/cli/command/stop-builds)
        Stop all running builds for job(s)
## configuration
- [apply-configuration](http://ubuntu-devel:8080/cli/command/apply-configuration)
        Apply YAML configuration to instance
- [check-configuration](http://ubuntu-devel:8080/cli/command/check-configuration)
        Check YAML configuration to instance
- [export-configuration](http://ubuntu-devel:8080/cli/command/export-configuration)
        Export jenkins configuration as YAML
- [reload-configuration](http://ubuntu-devel:8080/cli/command/reload-configuration)
        Discard all the loaded data in memory and reload everything from file system. Useful when you modified config files directly on disk.
- [reload-jcasc-configuration](http://ubuntu-devel:8080/cli/command/reload-jcasc-configuration)
        Reload JCasC YAML configuration
## credentials
- [create-credentials-by-xml](http://ubuntu-devel:8080/cli/command/create-credentials-by-xml)
        Create Credential by XML
- [create-credentials-domain-by-xml](http://ubuntu-devel:8080/cli/command/create-credentials-domain-by-xml)
        Create Credentials Domain by XML
- [delete-credentials](http://ubuntu-devel:8080/cli/command/delete-credentials)
        Delete a Credential
- [delete-credentials-domain](http://ubuntu-devel:8080/cli/command/delete-credentials-domain)
        Delete a Credentials Domain
- [get-credentials-as-xml](http://ubuntu-devel:8080/cli/command/get-credentials-as-xml)
        Get a Credentials as XML (secrets redacted)
- [get-credentials-domain-as-xml](http://ubuntu-devel:8080/cli/command/get-credentials-domain-as-xml)
        Get a Credentials Domain as XML
- [import-credentials-as-xml](http://ubuntu-devel:8080/cli/command/import-credentials-as-xml)
        Import credentials as XML. The output of "list-credentials-as-xml" can be used as input here as is, the only needed change is to set the actual Secrets which are redacted in the output.
- [list-credentials](http://ubuntu-devel:8080/cli/command/list-credentials)
        Lists the Credentials in a specific Store
- [list-credentials-as-xml](http://ubuntu-devel:8080/cli/command/list-credentials-as-xml)
        Export credentials as XML. The output of this command can be used as input for "import-credentials-as-xml" as is, the only needed change is to set the actual Secrets which are redacted in the output.
- [list-credentials-context-resolvers](http://ubuntu-devel:8080/cli/command/list-credentials-context-resolvers)
        List Credentials Context Resolvers
- [list-credentials-providers](http://ubuntu-devel:8080/cli/command/list-credentials-providers)
        List Credentials Providers
- [update-credentials-by-xml](http://ubuntu-devel:8080/cli/command/update-credentials-by-xml)
        Update Credentials by XML
- [update-credentials-domain-by-xml](http://ubuntu-devel:8080/cli/command/update-credentials-domain-by-xml)
        Update Credentials Domain by XML
## job
- [add-job-to-view](http://ubuntu-devel:8080/cli/command/add-job-to-view)
        Adds jobs to view.
- [copy-job](http://ubuntu-devel:8080/cli/command/copy-job)
        Copies a job.
- [create-job](http://ubuntu-devel:8080/cli/command/create-job)
        Creates a new job by reading stdin as a configuration XML file.
- [delete-job](http://ubuntu-devel:8080/cli/command/delete-job)
        Deletes job(s).
- [disable-job](http://ubuntu-devel:8080/cli/command/disable-job)
        Disables a job.
- [enable-job](http://ubuntu-devel:8080/cli/command/enable-job)
        Enables a job.
- [get-job](http://ubuntu-devel:8080/cli/command/get-job)
        Dumps the job definition XML to stdout.
- [list-jobs](http://ubuntu-devel:8080/cli/command/list-jobs)
        Lists all jobs in a specific view or item group.
- [reload-job](http://ubuntu-devel:8080/cli/command/reload-job)
        Reload job(s)
- [update-job](http://ubuntu-devel:8080/cli/command/update-job)
        Updates the job definition XML from stdin. The opposite of the get-job command.
## misc
- [console](http://ubuntu-devel:8080/cli/command/console)
        Retrieves console output of a build.
- [get-gradle](http://ubuntu-devel:8080/cli/command/get-gradle)
        List available gradle installations
- [groovy](http://ubuntu-devel:8080/cli/command/groovy)
        Executes the specified Groovy script. 
- [groovysh](http://ubuntu-devel:8080/cli/command/groovysh)
        Runs an interactive groovy shell.
- [help](http://ubuntu-devel:8080/cli/command/help)
        Lists all the available commands or a detailed description of single command.
- [mail](http://ubuntu-devel:8080/cli/command/mail)
        Reads stdin and sends that out as an e-mail.
- [session-id](http://ubuntu-devel:8080/cli/command/session-id)
        Outputs the session ID, which changes every time Jenkins restarts.
- [version](http://ubuntu-devel:8080/cli/command/version)
        Outputs the current version.
- [who-am-i](http://ubuntu-devel:8080/cli/command/who-am-i)
        Reports your credential and permissions.
## node
- [connect-node](http://ubuntu-devel:8080/cli/command/connect-node)
        Reconnect to a node(s)
- [create-node](http://ubuntu-devel:8080/cli/command/create-node)
        Creates a new node by reading stdin as a XML configuration.
- [delete-node](http://ubuntu-devel:8080/cli/command/delete-node)
        Deletes node(s)
- [disconnect-node](http://ubuntu-devel:8080/cli/command/disconnect-node)
        Disconnects from a node.
- [get-node](http://ubuntu-devel:8080/cli/command/get-node)
        Dumps the node definition XML to stdout.
- [offline-node](http://ubuntu-devel:8080/cli/command/offline-node)
        Stop using a node for performing builds temporarily, until the next "online-node" command.
- [online-node](http://ubuntu-devel:8080/cli/command/online-node)
        Resume using a node for performing builds, to cancel out the earlier "offline-node" command.
- [update-node](http://ubuntu-devel:8080/cli/command/update-node)
        Updates the node definition XML from stdin. The opposite of the get-node command.
- [wait-node-offline](http://ubuntu-devel:8080/cli/command/wait-node-offline)
        Wait for a node to become offline.
- [wait-node-online](http://ubuntu-devel:8080/cli/command/wait-node-online)
        Wait for a node to become online.
## pipeline
- [declarative-linter](http://ubuntu-devel:8080/cli/command/declarative-linter)
        Validate a Jenkinsfile containing a Declarative Pipeline
- [replay-pipeline](http://ubuntu-devel:8080/cli/command/replay-pipeline)
        Replay a Pipeline build with edited script taken from standard input
- [restart-from-stage](http://ubuntu-devel:8080/cli/command/restart-from-stage)
        Restart a completed Declarative Pipeline build from a given stage.
## plugin
- [disable-plugin](http://ubuntu-devel:8080/cli/command/disable-plugin)
        Disable one or more installed plugins.
- [enable-plugin](http://ubuntu-devel:8080/cli/command/enable-plugin)
        Enables one or more installed plugins transitively.
- [install-plugin](http://ubuntu-devel:8080/cli/command/install-plugin)
        Installs a plugin either from a file, an URL, or from update center. 
- [list-plugins](http://ubuntu-devel:8080/cli/command/list-plugins)
        Outputs a list of installed plugins.
## system
- [cancel-quiet-down](http://ubuntu-devel:8080/cli/command/cancel-quiet-down)
        Cancel the effect of the "quiet-down" command.
- [quiet-down](http://ubuntu-devel:8080/cli/command/quiet-down)
        Quiet down Jenkins, in preparation for a restart. Don’t start any builds.
- [restart](http://ubuntu-devel:8080/cli/command/restart)
        Restart Jenkins.
- [safe-restart](http://ubuntu-devel:8080/cli/command/safe-restart)
        Safely restart Jenkins.
- [safe-shutdown](http://ubuntu-devel:8080/cli/command/safe-shutdown)
        Puts Jenkins into the quiet mode, wait for existing builds to be completed, and then shut down Jenkins.
- [shutdown](http://ubuntu-devel:8080/cli/command/shutdown)
        Immediately shuts down Jenkins server.
## view
- [create-view](http://ubuntu-devel:8080/cli/command/create-view)
        Creates a new view by reading stdin as a XML configuration.
- [delete-view](http://ubuntu-devel:8080/cli/command/delete-view)
        Deletes view(s).
- [get-view](http://ubuntu-devel:8080/cli/command/get-view)
        Dumps the view definition XML to stdout.
- [remove-job-from-view](http://ubuntu-devel:8080/cli/command/remove-job-from-view)
        Removes jobs from view.
- [update-view](http://ubuntu-devel:8080/cli/command/update-view)
        Updates the view definition XML from stdin. The opposite of the get-view command.
