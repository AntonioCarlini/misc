#!/usr/bin/env sh

#+
#
# This helper script provides support for running another script with output redirected to a log file,
# either for recording or for post-processing.
#
# Options
#
# --refresh
#   NOT CURRENTLY IMPLEMENTED
#   Causes the containing git repository to be pulled and the potentially changed script to be re-invoked.
#
# --always-email
#   NOT CURRENTLY IMPLEMENTED
#   Request that the log always be emailed to the user. By default no automatic email is sent.
#
# --log
#   Specifies the location of the log file. If the path only includes a filename, $HOME/tmp/ will be prepended.
#
# --post-processor
#   NOT CURRENTLY IMPLEMENTED
#   Specifies a script to run that post-processes the log file.
#   The script will be called in this way:
#     script LOGFILE COMMAND ALWAYS-EMAIL
#
# Everything from the first unrecognised option onwards is assumed to be the final COMMAND and its arguments.
#-


# ARGS used after a --refresh will be built up in this variable
ARGS_WITHOUT_REFRESH=

# Look at leading options, stopping on the first unknown
REFRESH=
ALWAYS_EMAIL=
LOGFILE=
POST_PROCESSOR=
for i in "$@"; do
    key=$1
    case $key in
	--refresh)
	    REFRESH=y
	    shift
	    # Here would do git pull, but currently not implemented
	    # reinvoke same script but with --refresh removed from the arguments
	    echo "Will eventually re-invoke with: [$ARGS_WITHOUT_REFRESH] [$@]"
	    ;;

	--always-email)
	    ALWAYS_EMAIL=n
	    ARGS_WITHOUT_REFRESH="$ARGS_WITHOUT_REFRESH $1"
	    shift
	    ;;

	--log)
	    shift
	    LOGFILE=$1
	    ARGS_WITHOUT_REFRESH="$ARGS_WITHOUT_REFRESH --log $LOGFILE"
	    shift
	    ;;

	--post-processor)
	    shift
	    POST_PROCESSOR=$1
	    ARGS_WITHOUT_REFRESH="$ARGS_WITHOUT_REFRESH --processor $POST_PROCESSOR"
	    shift
	    ;;
	*)
	    break
	    ;;
    esac
done

# TODO
# If no LOGFILE then what? Email a failure status?
# Allow the logfile to be anywhere or force it to be in $HOME/tmp? Or default it to be in $HOME/tmp?

echo "After handling all args = [$@] resubmit args =[$ARGS_WITHOUT_REFRESH]"

# Now exec to start running this script after the "exec" line below but with everything logged ...
LOG=/tmp/$(basename ${LOGFILE})
exec > $LOG 2>&1 < /dev/null

# At this point an original invocation like
#
#   run-with-log.sh --log dns-log dns-update-database.rb --arguments
#
# will reach this point with $0 set to the path to the run-with-log.sh script and
# $@ set to "dns-update-database.rb --arguments", which is the command line to be
# invoked.

STATUS=$?
echo "$(date) Noting environment: ["
echo $0
echo STATUS=$STATUS
echo HOME=$HOME
echo ALWAYS_EMAIL=$ALWAYS_EMAIL
echo PROCESSOR=$PROCESSOR
echo LOGFILE=$LOGFILE
echo "]"
echo "$(date) Logging command: [$@] ["
$@
echo "]"
echo "$(date) Command completed."
