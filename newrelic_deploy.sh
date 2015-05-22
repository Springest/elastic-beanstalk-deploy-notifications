#!/bin/bash

version="1.0"

function usage {
    echo "AWS Elastic Beanstalk Deployment Notifications for New Relic (v${version})"
    echo
    echo "Usage: newrelic_deploy.sh -a <APP NAME> -k <API KEY> [options]"
    echo
    echo "Options:"
    echo
    echo "  -a  The name your the application in Elastic Beanstalk."
    echo "  -d  The name of the deployer (default: AWS Elastic Beanstalk)."
    echo "  -e  Error if the HTTP request fails. Note that this will abort the deployment."
    echo "  -h  Displays this help message."
    echo "  -k  Your New Relic API key."
    echo "  -q  Quiet mode."
    echo "  -v  Display version information."
    echo
}

function info {
    echo "[INFO] ${@}"
}

function warn {
    echo "[WARN] ${@}"
}

function error {
    echo "[ERROR] ${@}" >&2
    exit 1
}

api_key=""
app_name=""
deployer=""
verbose=1
error_on_fail=0

if [[ ${#} == 0 ]]; then
    usage
    exit 1
fi

while getopts "a:d:ehk:qv" option; do
    case "${option}" in
        a) app_name="${OPTARG}";;
        d) deployer="${OPTARG}";;
        e) error_on_fail=1;;
        h) usage; exit;;
        k) api_key="${OPTARG}";;
        q) verbose=0;;
        v) echo "Version ${version}"; exit;;
        *) echo; usage; exit 1;;
    esac
done

if [[ -z "${app_name}" ]]; then
    error "The application name must be provided"
fi

if [[ -z "${api_key}" ]]; then
    error "The API key must be provided"
fi

if [[ -z "${deployer}" ]]; then
    deployer="AWS Elastic Beanstalk"
fi

if [[ -f REVISION ]]; then
    app_version=$(cat REVISION)
else
    app_version="unknown"
    error "Unable to extract application version from source REVISION file"
fi

if [[ ${verbose} == 1 ]]; then
    info "Application name: ${app_name}"
    info "Application version: ${app_version}"
    info "Sending deployment notification..."
fi

http_response=$(curl -s -D - -H "x-api-key:${api_key}" -d "deployment[app_name]=${app_name}&deployment[revision]=${app_version}&deployment[user]=${deployer}" "https://rpm.newrelic.com/deployments.xml" -o /dev/null)
http_status=$(echo "${http_response}" | head -n 1)
echo "${http_status}" | grep -q "201"

if [[ ${?} == 0 ]]; then
    if [[ ${verbose} == 1 ]]; then
        info "Deployment notification successfully sent (${app_name} v${app_version})"
    fi
else
    msg="Failed to send deployment notification: ${http_status}"
    if [[ ${error_on_fail} == 1 ]]; then
        error "${msg}"
    else
        warn "${msg}"
    fi
fi
