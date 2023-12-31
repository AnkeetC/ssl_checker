#!/bin/bash

# @HoangDH - Jun 29 2019
# set -ex

SLACK_WEBHOOK_URL="${{ secrets.SLACK_WEBHOOK_URL }}"

notify() {
  WEBHOOK="$SLACK_WEBHOOK_URL"
  SLACK_CHANNEL="#ssl-monitor"
  SLACK_BOTNAME="SSL Checker"
  
  DOMAIN="$1"
  EXPIRY_DAYS="$2"
  EXPIRY_DATE="$3"
  ISSUER="$4"
  COLOR="$5"

  SLACK_PAYLOAD="payload={\"channel\":\"${SLACK_CHANNEL}\",\"icon_emoji\":\":skull:\",\"username\":\"${SLACK_BOTNAME}\",\"attachments\":[{\"color\":\"${COLOR}\",\"fields\":[{\"title\":\"Domain:\",\"value\":\"${DOMAIN}\",\"short\":true},{\"title\":\"Expiry day(s):\",\"value\":\"${EXPIRY_DAYS}\",\"short\":true},{\"title\":\"Expiry date:\",\"value\":\"$EXPIRY_DATE\",\"short\":true},{\"title\":\"Issued by:\",\"value\":\"$ISSUER\",\"short\":true}]}]}"
  curl -X POST --data-urlencode "$SLACK_PAYLOAD" $WEBHOOK
}

check_certs() {
  if [ $# -eq 0 ]
  then
    echo "No domain names provided."
    exit 1
  fi

  now_epoch=$( date +%s )

  for name in "$@"
  do
    ip_server=$(dig +short a $name)
    dig +noall +answer +short $name | while read -r ip;
    do
      if [ "$ip" == "$ip_server" ]
      then
        data=`echo | openssl s_client -showcerts -servername $name -connect $ip:443 2>/dev/null | openssl x509 -noout -enddate -issuer`
        expiry_date=$(echo $data | grep -Eo "notAfter=(.*)GMT" | cut -d "=" -f 2)
        issuer=$(echo $data | grep -Eo "CN=(.*)"| cut -d "=" -f 2)
        expiry_epoch=$(date -d "$expiry_date" +%s)
        expiry_days="$(( ($expiry_epoch - $now_epoch) / (3600 * 24) ))"
        if [ $expiry_days -lt 100 ]
        then
            color="#ff0000"
            notify "$name" "$expiry_days" "$expiry_date" "$issuer" "$color"
        else
            color="#2eb886"
            notify "$name" "$expiry_days" "$expiry_date" "$issuer" "$color"
        fi
      fi
    done
  done
}

check_certs "$@"
