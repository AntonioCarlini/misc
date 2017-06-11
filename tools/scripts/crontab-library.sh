
# add_to_crontab
#
# Adds a crontab entry, avoiding duplicates.
#
# $1 - the crontab frequency specification
# $2 - the command to supply to crontab

function add_to_crontab() {
    local frequency=$1
    local command=$2
    cat <(grep -i -v "$command" <(crontab -l) ) <(echo "$frequency $command") | crontab -
}

# remove_from_crontab
#
# Removes and entry from the crontab
#
# $1 - the command in the crontab entry
#
function remove_from_crontab() {
    local command=$1
    cat <(grep -i -v "$command" <(crontab -l) ) | crontab -
}
