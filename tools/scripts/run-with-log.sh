#!/usr/bin/env sh

#+
#
# This helper script provides support for running another script with output redirected to a log file,
# either for recording or for post-processing.
#
# Options
#
# --refresh
#   Only recognised as the first option.
#   Causes the containing git repository to be pulled and the potentially changed script to be re-invoked.
#
# --always-email
#   Request that the log always be emailed to the user. By default no automatic email is sent.
#
# --log
#   Specifies the location of the log file. If the path only includes a filename, $HOME/tmp/ will be prepended.
#
# --processor
#   Specifies a script to run that post-processes the log file.
#   The script will be called in this way:
#     script LOGFILE COMMAND ALWAYS-EMAIL
#
# Everything from the first unrecognised option onwards is assumed to be the final COMMAND and its arguments.
#-

# If --refresh is present as the first argument, then pull the git repo to update the script and exec the (potentially) new script.
if [ "$1" = "--refresh" ]; then
    shift
    echo "Here would do git pull, but currently not implemented."
    exec $0 $@
fi

# Look at leading options, stopping on the first unknown
REFRESH=
ALWAYS_EMAIL=
LOGFILE=
PROCESSOR=
for i in "$@"; do
    key=$1
    case $key in
	--refresh)
	    REFRESH=y
	    shift
	    ;;

	--always-email)
	    ALWAYS_EMAIL=n
	    shift
	    ;;

	--log)
	    shift
	    LOGFILE=$1
	    shift
	    ;;

	--processor)
	    shift
	    PROCESSOR=$1
	    shift
	    ;;
	*)
	    break
	    ;;
    esac
done

# If no LOGFILE then what? Email a failure status?
# Allow the logfile to be anywhere or force it to be in $HOME/tmp? Or default it to be in $HOME/tmp?

echo After processing all args = [$@]
# Now exec to get a log
LOG=/tmp/`basename $LOGFILE`.log
shift
echo Using $LOG
exec > $LOG 2>&1 < /dev/null

# The remaining arguments specify what to do
$@

# So something like
#
#   run-with-log.sh --refresh dns-log dns-update-database.rb
#
# will run the script an write to the log, but what is going to post-process the script and email it?

STATUS=$?
echo STATUS=$STATUS
echo HOME=$HOME
echo ALWAYS_EMAIL=$ALWAYS_EMAIL
echo PROCESSOR=$PROCESSOR
echo LOGFILE=$LOGFILE

# What would be useful?
# email a status?
# email on error?
