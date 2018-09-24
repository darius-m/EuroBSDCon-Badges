#!/bin/bash

# Darius Mihai, University Politehnica of Bucharest
#
# Parser to create badges based on the template
# Please change variables below to fit your needs
#
# By default, the script expects the directory it's placed in to be a fitting
# work directory
#
# Relevant variables:
# -> *_REF_* variables values the script will look for in the template file to
# replace with actual values
# -> GUESTS_FILE is the name of a CSV file that contains the names, emails, and
# other information for the guests
# TEMPLATE_DOC is the badge template file

set -eu

SCRIPT_NAME="`readlink -f $0`"
WORK_DIR="${SCRIPT_NAME%/*}"

GUESTS_FILE="${WORK_DIR}/tickets.csv"
TEMPLATE_DOC="${WORK_DIR}/EuroBSDCon-2018-Badge_Template.docx"

PARAM_NAME_IDX=1
PARAM_MAIL_IDX=2
PARAM_ROLE_IDX=3
PARAM_FIRST_EVENT_IDX=4

GUEST_ROLE_REF_COLOUR="ccddee"
GUEST_EVENTS_REF_COLOUR="CFE2F3"
GUEST_TUTORIALS_REF_COLOUR="FFF2CC"

BADGE_NUM=0
BADGES_DIR="${WORK_DIR}/badges"
TMP_DIR="${WORK_DIR}/tmp"

GUEST_EVENTS=""
GUEST_EVENTS_COLOUR="FFFFFF"
GUEST_TUTORIALS=""
GUEST_TUTORIALS_COLOUR="FFFFFF"

declare -A EVENTS
EVENTS=(
    ["Conference"]="CONF"
    ["Social event"]="SOC"
    ["NetBSD devsummit"]="NETBSD"
    ["FreeBSD devsummit (Thursday)"]="FBSD (T)"
    ["FreeBSD devsummit (Friday)"]="FBSD (F)"
    ["Tutorial: Advanced container management with libiocage"]="T1"
    ["Tutorial: Ports and Poudriere"]="T3"
    ["Tutorial: Managing BSD Systems with Ansible"]="T2"
    ["Tutorial: LibTLS Tutorial for TLS beginners"]="T4"
    ["Tutorial: Introduction to BGP for developers and sysadmins"]="T5"
    ["Tutorial: An Introduction to the FreeBSD Open-Source Operating System"]="T6"
)

SORTED_EVENTS=("FBSD (T)" "FBSD (F)" "NETBSD" "CONF" "SOC")
SORTED_TUTORIALS=("T1" "T2" "T3" "T4" "T5" "T6")

get_best_event_map() {
    local EVENT="${1}"

    if [ -z "$(echo -e ${EVENT} | tr -d '[:space:]')" ]; then
        return
    fi

    if [ ! -z "${EVENTS[${EVENT}]+exists}" ]; then
        echo "${EVENTS[${EVENT}]}"
        return
    else
        for EV in "${!EVENTS[@]}"; do
            if [[ "${EVENT}" = "${EV}"* ]]; then
                echo "${EVENTS[${EV}]}"
                return
            fi
        done
    fi

    exit 1
}

sort_events_and_tutorials() {
    local EVTS=""
    local TUTS=""

    for EVT in "${SORTED_EVENTS[@]}"; do
        if [[ "${GUEST_EVENTS}" = *"${EVT}"* ]]; then
            if [ -z "${EVTS}" ]; then
                EVTS="${EVT}"
            else
                EVTS+="    ${EVT}"
            fi
        fi
    done

    # Special clause for a second Social event invitation
    if [[ "${GUEST_EVENTS}" = *"SOC"*"SOC"* ]]; then
        if [ -z "${EVTS}" ]; then
            EVTS="SOC2"
        else
            EVTS+="    SOC2"
        fi
    fi


    for TUT in "${SORTED_TUTORIALS[@]}"; do
        if [[ "${GUEST_TUTORIALS}" = *"${TUT}"* ]]; then
            if [ -z "${TUTS}" ]; then
                TUTS="${TUT}"
            else
                TUTS+="    ${TUT}"
            fi
        fi
    done

    GUEST_EVENTS="${EVTS}"
    GUEST_TUTORIALS="${TUTS}"
}


mkdir -p "${BADGES_DIR}"
rm -rf "${BADGES_DIR}"/*


PROGRESS=0
while IFS='' read -r LINE || [[ -n "${LINE}" ]]; do
    IFS=','; PARAMS=(${LINE}); unset IFS

    printf "Parsing... [%d]: %s\n" $((++PROGRESS)) "${PARAMS[${PARAM_NAME_IDX}]}"

    #MAIL="${PARAMS[$PARAM_MAIL_IDX]%@*}"
    #if [ "${MAIL%+*}" = "${PARAMS[$PARAM_NAME_IDX]}" ]; then
    #    echo "${PARAMS[$PARAM_MAIL_IDX]}"
    #fi

    mkdir -p "${TMP_DIR}"; rm -rf "${TMP_DIR}"/*
    unzip "${TEMPLATE_DOC}" -d "${TMP_DIR}" 2>&1 >/dev/null

    # Set parameters for document depending on the guest type and other parameters
    case "${PARAMS[${PARAM_ROLE_IDX}]^^}" in
        SPEAKER) GUEST_ROLE_COLOUR="ff0000" ;;
        ATTENDEE) GUEST_ROLE_COLOUR="439f4c" ;;
        WHEEL) GUEST_ROLE_COLOUR="4a86e8" ;;
    esac

    GUEST_EVENTS=""
    GUEST_EVENTS_COLOUR="FFFFFF"
    GUEST_TUTORIALS=""
    GUEST_TUTORIALS_COLOUR="FFFFFF"

    for IDX in $(seq ${PARAM_FIRST_EVENT_IDX} $((${#PARAMS[@]}-1))); do
        EVENT="$(get_best_event_map "${PARAMS[${IDX}]}")"
        if [[ "${EVENT}" = "T"[1-6] ]]; then
            GUEST_TUTORIALS+=" | ${EVENT}"
            GUEST_TUTORIALS_COLOUR="${GUEST_TUTORIALS_REF_COLOUR}"
        else
            GUEST_EVENTS+=" | ${EVENT}"
            GUEST_EVENTS_COLOUR="${GUEST_EVENTS_REF_COLOUR}"
        fi
    done


    # Sort the events and tutorials in an expected order
    sort_events_and_tutorials

    # For empty registrations leave the lines coloured, and fill the text later in pen
    if [ -z "${GUEST_EVENTS}" -a -z "${GUEST_TUTORIALS}" ]; then
        GUEST_TUTORIALS_COLOUR="${GUEST_TUTORIALS_REF_COLOUR}"
        GUEST_EVENTS_COLOUR="${GUEST_EVENTS_REF_COLOUR}"
    fi

    # Set the values in the document
    sed -i -e "s|GUEST_MAIL|${PARAMS[${PARAM_MAIL_IDX}]}|g"                  \
           -e "s|GUEST_NAME|${PARAMS[${PARAM_NAME_IDX}]}|g"                  \
           -e "s|GUEST_ROLE|${PARAMS[${PARAM_ROLE_IDX}]^^}|g"                \
           -e "s|${GUEST_ROLE_REF_COLOUR}|${GUEST_ROLE_COLOUR}|g"            \
           -e "s|GUEST_EVENTS|${GUEST_EVENTS}|g"                          \
           -e "s|${GUEST_EVENTS_REF_COLOUR}|${GUEST_EVENTS_COLOUR}|g"        \
           -e "s|GUEST_TUTORIALS|${GUEST_TUTORIALS}|g"                    \
           -e "s|${GUEST_TUTORIALS_REF_COLOUR}|${GUEST_TUTORIALS_COLOUR}|g"  \
       ${TMP_DIR}/word/document.xml

    # Create the new document with the values inserted in it
    cd "${TMP_DIR}"
    DOC_NAME="${BADGES_DIR}/EuroBSDCon_Badge_$((++BADGE_NUM)).docx"
    zip -rq "${DOC_NAME}" *

    rm -rf "${TMP_DIR}"
done < "${GUESTS_FILE}"

sync

# Convert everything to PDFs (cd is required since we might be in tmp which was removed)
cd "${BADGES_DIR}"
lowriter --headless --convert-to pdf $(ls "${BADGES_DIR}"/*.docx | sort -V)

# Merge PDFs for convenience
pdfunite $(ls "${BADGES_DIR}"/*.pdf | sort -V) ${BADGES_DIR}/merged.pdf
