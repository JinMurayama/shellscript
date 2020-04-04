ZONE_LIST='zone_list.txt';
RECORD_TXT_JSON='record_txt.json';
ZONE_ID_LIST=`date +%Y%m%d:%H:%M:%s_zone_id_list.csv`;
PROFILE="";
DAY=`date +%Y%m%d`;
RESULT_JSON="result.json";

mkdir /tmp/${DAY}
mkdir /tmp/${DAY}/record_list

touch /tmp/${DAY}/${ZONE_ID_LIST}


#zone_listの各ドメインからzone-idを抽出し、zone_id_list.txtに格納する
while read domain; do
aws route53 list-hosted-zones --profile ${PROFILE} | jq -r --arg domain_name ${domain} '.HostedZones[]|select(.Name==$domain_name)|[.Id,.Name]| @csv' | sed 's/"//g' >> /tmp/${DAY}/${ZONE_ID_LIST}
done < ${ZONE_LIST}

RESULT_FILE="afeter_changing_record_list.csv"
touch /tmp/${DAY}/${RESULT_FILE}

#zone-idをtxt_record.jsonに埋め込んで、zone_id_listをもとにレコードを変える。
while read zone; do
ZONE_ID=`echo ${zone} | cut -d ',' -f 1` 
DOMAINE_NAME=`echo ${zone} | cut -d ',' -f 2`
DATE=`date +%Y%m%d:%H:%M:%s`;
DOMAINE_NAME_FILE="${DOMAINE_NAME}_${DATE}_${RECORD_TXT_JSON}"
touch /tmp/${DAY}/record_list/${DOMAINE_NAME_FILE}
echo -n "${DOMAINE_NAME}, ${ZONE_ID}, " >> /tmp/${DAY}/${RESULT_FILE}
echo "${DOMAINE_NAME}, ${ZONE_ID}"
#echo `cat ${RECORD_TXT_JSON} | jq -r '.Changes[].ResourceRecordSet.Name'`
cat ${RECORD_TXT_JSON} | jq --arg domain_name "${DOMAINE_NAME}" '.Changes[].ResourceRecordSet.Name|=$domain_name' > /tmp/${DAY}/record_list/${DOMAINE_NAME_FILE}
#echo `cat /tmp/${DAY}/record_list/${DOMAINE_NAME_FILE} | jq -r '.Changes[].ResourceRecordSet.Name'`
aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file:///tmp/${DAY}/record_list/${DOMAINE_NAME_FILE} --profile ${PROFILE} > /tmp/${DAY}/${RESULT_JSON}
echo `cat /tmp/${DAY}/${RESULT_JSON} | jq -r '.ChangeInfo.Status'` >> /tmp/${DAY}/${RESULT_FILE}

done < /tmp/${DAY}/${ZONE_ID_LIST}

TIME_RESULT_FILE=`date +%Y%m%d:%H:%M:%s_${RESULT_FILE}`;

mv /tmp/${DAY}/${RESULT_FILE} /tmp/${DAY}/${TIME_RESULT_FILE};
