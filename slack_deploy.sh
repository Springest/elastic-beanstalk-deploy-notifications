#!/bin/bash

version="1.2"

function usage {
    echo "AWS Elastic Beanstalk Deployment Notifications for Slack (v${version})"
    echo
    echo "Usage: appsignal_deploy.sh -a <APP NAME> -c <SLACK CHANNEL> -w <WEBHOOK URL> [options]"
    echo
    echo "Options:"
    echo
    echo "  -a  The name your the application in Elastic Beanstalk."
    echo "  -c  The channel to post to (without the hash)."
    echo "  -w  The webhook url to post to."
    echo "  -d  The name of the deployer (default: AWS Elastic Beanstalk)."
    echo "  -c  The icon to use (without the colons, default: package)."
    echo "  -e  Error if the HTTP request fails. Note that this will abort the deployment."
    echo "  -h  Displays this help message."
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

app_name=""
channel=""
webhook_url=""
icon=""
environment=$DEPLOY_STACK_NAME
deployer=""
verbose=1
error_on_fail=0

if [[ ${#} == 0 ]]; then
    usage
    exit 1
fi

while getopts "a:c:w:d:i:ehk:qv" option; do
    case "${option}" in
        a) app_name="${OPTARG}";;
        c) channel="${OPTARG}";;
        w) webhook_url="${OPTARG}";;
        d) deployer="${OPTARG}";;
        i) icon="${OPTARG}";;
        e) error_on_fail=1;;
        h) usage; exit;;
        q) verbose=0;;
        v) echo "Version ${version}"; exit;;
        *) echo; usage; exit 1;;
    esac
done

if [[ -z "${app_name}" ]]; then
    error "The application name must be provided"
fi

if [[ -z "${channel}" ]]; then
    error "The channel must be provided"
fi

if [[ -z "${webhook_url}" ]]; then
    error "The webhook_url must be provided"
fi

if [[ -z "${deployer}" ]]; then
    deployer="AWS Elastic Beanstalk"
fi

if [[ -z "${icon}" ]]; then
    icon="package"
fi

if [[ -f REVISION ]]; then
    app_version=$(cat REVISION)
else
    EB_CONFIG_SOURCE_BUNDLE=$(/opt/elasticbeanstalk/bin/get-config container -k source_bundle)
    app_version=$(unzip -z "${EB_CONFIG_SOURCE_BUNDLE}" | tail -n1)

    if [[ -z "${app_version}" ]]; then
        app_version="unknown"
        error "Unable to extract application version from source REVISION file, or load version information from within the container"
    fi
fi

if [[ -z "${environment}" ]]; then
  environment=$(/var/app/current/docker/get_eb_environment_name)
fi

if [[ ${verbose} == 1 ]]; then
    info "Application name: ${app_name}"
    info "Application version: ${app_version}"
    info "Application environment: ${environment}"
    info "Webhook URL: ${webhook_url}"
    info "Channel: ${channel}"
    info "Icon: ${icon}"
    info "Sending deployment notification..."
fi

http_response=$(curl -X POST -s -d "{\"channel\":\"#${channel}\",\"icon_emoji\":\":${icon}:\",\"text\":\"${app_name} was successfully deployed to ${environment} by ${deployer}\",\"username\":\"${deployer}\",\"attachments\":[{\"fallback\":\"${app_name} was successfully deployed to ${environment} by ${deployer}\",\"color\":\"#8eb573\",\"fields\":[{\"title\":\"Environment:\",\"value\":\"${environment}\",\"short\":false},{\"title\":\"Version:\",\"value\":\"${app_version}\"}]}]}" "${webhook_url}")
http_status=$(echo "${http_response}" | head -n 1)
echo "${http_status}" | grep -q "ok"

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
