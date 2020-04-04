#s[[h
PROFILE=
ZONE_FILE=hosted_zone_list.csv

touch `date +%Y%m%d_route53-records.csv`

aws route53 list-hosted-zones --profile ${PROFILE} | jq -r '.HostedZones[]|[.Id, .Name] | @csv' |  sed 's/"//g'>> ${ZONE_FILE}
#aws route53 list-hosted-zones --max-items 10 --profile ${PROFILE} | jq -r '.HostedZones[]|[.Id, .Name]' >> ${ZONE_FILE}

echo "finish read host_zone_list"

file=`date "+%Y%m%d_route53-records.csv"`

echo "Zone,RecordName,RecordType,RecordDate" >> ${file}

count=0

while read line; do
ZONE_ID=`echo ${line} | cut -d ',' -f 1` 
DOMAINE_NAME=`echo ${line} | cut -d ',' -f 2`
echo "domain_name:${DOMAINE_NAME}"
echo -n "${DOMAINE_NAME}," >> ${file}
aws route53 list-resource-record-sets --hosted-zone-id ${ZONE_ID} --profile ${PROFILE} | jq -r --arg domain_name ${DOMAINE_NAME} ' .ResourceRecordSets|.[]|[$domain_name, .Name, .Type, if .Type=="A" then .AliasTarget.DNSName else .ResourceRecords[].Value end] | @csv' >> ${file}
count=`expr ${count} + 1`
echo $count
done < ${ZONE_FILE}

echo 'finish route53 list record'
