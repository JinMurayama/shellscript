#record.jsonとresister_CNAME.jsonはあらかじめ同じディレクトリに配置しておいてください

#事前に値を格納する
R53_ZONE_NAME=test.co.jp #登録するドメイン名を入れる
R53_ZONE_COMMENT="テストdomain" #登録するコメントを入力 何もいれなくてもよい
PROFILE=#プロファイル名
FILE_PATH=record.json  #jsonファイルのファイルパス
ELB_ARN= #タグを追加するELBのARNを登録
ELB_LISTENER_ARN= #事前にSSL証明書を紐づけるALBのリスナーのARNを登録

#jsonファイルにエラーがないかを確認
NUMBER=`cat ${FILE_PATH} | jq . | wc -l`
expr "$NUMBER" > error.txt
#エラーがあれば中止
if [ $? -ne 1 ] ; then
        echo "OK continue to create hosted-zone and record-sets"
        rm -rf error.txt
else
        echo "error json file. stop creating hosted-zone and record-sets"
        rm -rf error.txt
        exit
fi

#route53に新規ゾーンを作成する
#echo "aws route53 create-hosted-zone --name "${R53_ZONE_NAME}" --caller-reference `date +%Y-%m-%d-%H:%M:%S` --hosted-zone-config Comment="${R53_ZONE_COMMENT}"  --profile ${PROFILE}"
aws route53 create-hosted-zone --name "${R53_ZONE_NAME}" --caller-reference `date +%Y-%m-%d-%H:%M:%S` --hosted-zone-config Comment="${R53_ZONE_COMMENT}"  --profile ${PROFILE}

#Route53に登録されいてるかどうか確認
echo "aws route53 list-hosted-zones --profile ${PROFILE}| grep "${R53_ZONE_NAME}""
aws route53 list-hosted-zones --profile ${PROFILE}| grep "${R53_ZONE_NAME}"

#Route53に登録したゾーンのHosted Zone IDを取得する ここまではOK
echo "aws route53 list-hosted-zones --profile ${PROFILE} | jq --arg zone_name "${R53_ZONE_NAME}." -r '.HostedZones[]|select(.Name == $zone_name)|.Id' | sed 's/\/hostedzone\///'"
R53_ZONE_ID=`aws route53 list-hosted-zones --profile ${PROFILE} | jq --arg zone_name "${R53_ZONE_NAME}." -r '.HostedZones[]|select(.Name == $zone_name)|.Id' | sed 's/\/hostedzone\///'`

#Route 53に作成したゾーンに対して、DNSレコードを追加する
echo "aws route53 change-resource-record-sets --hosted-zone-id ${R53_ZONE_ID} --change-batch file://${FILE_PATH} --profile ${PROFILE}"
aws route53 change-resource-record-sets --hosted-zone-id ${R53_ZONE_ID} --change-batch file://${FILE_PATH} --profile ${PROFILE}

#Route 53に作成したゾーンに対して、DNSレコードが追加されたか確認する。
echo "aws route53 list-resource-record-sets --hosted-zone-id ${R53_ZONE_ID} --profile ${PROFILE}"
aws route53 list-resource-record-sets --hosted-zone-id ${R53_ZONE_ID} --profile ${PROFILE}


#対象のELBにタグを追加する
echo -n "引き続きELBにタグを追加しますか? [y/n]:"
read ANS
case $ANS in
  "" | [Yy]* )
	# ここに「Yes」の時の処理を書く
    echo "Yes"
    echo "タグを追加いたします。"
	#タグを追加
	echo " aws elbv2 add-tags --resource-arns ${ELB_ARN} --tags Key="${R53_ZONE_NAME}",Value="yes" --profile ${PROFILE}"
	aws elbv2 add-tags --resource-arns ${ELB_ARN} --tags Key="${R53_ZONE_NAME}",Value="yes" --profile ${PROFILE}
	#タグが追加されているか確認
	echo "aws elbv2 describe-tags --resource-arns ${ELB_ARN} --profile ${PROFILE}| jq --arg domain_name "${R53_ZONE_NAME}" -r '.TagDescriptions[].Tags[]|select(.Key==$domain_name)|.Key,.Value'"
	aws elbv2 describe-tags --resource-arns ${ELB_ARN} --profile ${PROFILE}| jq --arg domain_name "${R53_ZONE_NAME}" -r '.TagDescriptions[].Tags[]|select(.Key==$domain_name)|.Key,.Value'
	echo "タグを追加しました"
    ;;
  * )
    # ここに「No」の時の処理を書く
    echo "No"
    echo "タグ追加は行いません、別途タグを追加してください。"
    ;;
esac

#SSL証明書をリクエストしますか？
echo -n "引き続きACMでSSL証明書（DNS検証）をリクエストをしますか? [y/n]:"
read ANS

case $ANS in
  "" | [Yy]* )
    # ここに「Yes」の時の処理を書く
    echo "Yes"
    echo "リクエストを実行いたします。"

    #証明書をリクエスト（DNS検証）
    echo "aws acm request-certificate --domain-name "${R53_ZONE_NAME}" --validation-method DNS --tags Key="Name",Value="${R53_ZONE_NAME}" --profile ${PROFILE}"
    aws acm request-certificate --domain-name "${R53_ZONE_NAME}" --validation-method DNS --tags Key="Name",Value="${R53_ZONE_NAME}" --profile ${PROFILE}

    #証明書のarnを取得
    echo "aws acm list-certificates --profile ${PROFILE} | jq --arg domain_name "${R53_ZONE_NAME}" -r '.CertificateSummaryList[]|select(.DomainName==$domain_name)|.CertificateArn'"
    CERTIFICATEARN=`aws acm list-certificates --profile ${PROFILE} | jq --arg domain_name "${R53_ZONE_NAME}" -r '.CertificateSummaryList[]|select(.DomainName==$domain_name)|.CertificateArn'`

    #DNS検証用レコードセットを取得
    echo "aws acm describe-certificate --certificate-arn ${CERTIFICATEARN} --profile ${PROFILE}| jq -r '.Certificate.DomainValidationOptions[].ResourceRecord' > CNAME.json"
    aws acm describe-certificate --certificate-arn ${CERTIFICATEARN} --profile ${PROFILE}| jq -r '.Certificate.DomainValidationOptions[].ResourceRecord' > CNAME.json

    CNAME_NAME=`cat CNAME.json | jq -r '.Name'`
    CNAME_VALUE=`cat CNAME.json | jq -r '.Value'`
    echo ${CNAME_NAME}
    echo ${CNAME_VALUE}

    #resister_CNAMEにvalueを格納する
    echo "cat resister_CNAME.json | jq --arg name ${CNAME_NAME} '.Changes[].ResourceRecordSet.Name|=$name' > resister_CNAME.json"
    cat resister_CNAME.json | jq --arg name ${CNAME_NAME} '.Changes[].ResourceRecordSet.Name|=$name' > resister_CNAME.json
    echo "cat resister_CNAME.json | jq --arg value ${CNAME_VALUE} '.Changes[].ResourceRecordSet.ResourceRecords[].Value|=$value ' > resister_CNAME.json"
    cat resister_CNAME.json | jq --arg value ${CNAME_VALUE} '.Changes[].ResourceRecordSet.ResourceRecords[].Value|=$value ' > resister_CNAME.json

    #CNAMEのレコードを対象のゾーンにセットする
    echo "aws route53 change-resource-record-sets --hosted-zone-id ${R53_ZONE_ID} --change-batch file://resiter_NAME.json --profile ${PROFILE}"
    aws route53 change-resource-record-sets --hosted-zone-id ${R53_ZONE_ID} --change-batch file://resister_CNAME.json --profile ${PROFILE}

    #証明書がIssuedになるまで待つ
    DESIRED_STATUS="ISSUED"
    status=""
    counter=1
    MAX_RETRIES=60
    while [ "${DESIRED_STATUS}" != "${status}" ] ; do 
  	echo "checking certificate status...(${counter}/${MAX_RETRIES})"
  	status=$(aws acm describe-certificate --certificate-arn ${CERTIFICATEARN} --profile ${PROFILE}| jq -r '.Certificate.Status')
  	counter=$((counter + 1))
  	if [ ${counter} -gt ${MAX_RETRIES} ]; then
    		>&2 echo "Failed to validate domain. Program exits in error."
    		exit 1
  	fi
    sleep 30
    done
 
    echo "validate DNS record: DONE."

	
    #証明書の状態を表示する("DomainValidationOptionsがsuccess)
    echo "aws acm describe-certificate --certificate-arn ${CERTIFICATEARN} --profile ${PROFILE}"
    aws acm describe-certificate --certificate-arn ${CERTIFICATEARN} --profile ${PROFILE}

    #対象のELBのリスナーにSSL証明書を割り当てる
    echo "aws elbv2 add-listener-certificates --listener-arn ${ELB_LISTENER_ARN} --certificates CertificateArn=${CERTIFICATEARN} --profile ${PROFILE}"
    aws elbv2 add-listener-certificates --listener-arn ${ELB_LISTENER_ARN} --certificates CertificateArn=${CERTIFICATEARN} --profile ${PROFILE}


    echo "cmplete certificate"
	
    ;;
  * )
    # ここに「No」の時の処理を書く
    echo "No"
    echo "リクエストを中断します、別途SSL証明書を発行してください。"
    ;;
esac

#route 53に追加したDNSレコードの名前解決テスト
echo "dig ${R53_ZONE_NAME} A"
dig ${R53_ZONE_NAME} A

#route 53に追加したDNSレコードの名前解決テスト
echo "dig ${R53_ZONE_NAME} MX"
dig ${R53_ZONE_NAME} MX

#route 53に追加したDNSレコードの名前解決テスト
echo "dig ${R53_ZONE_NAME} TXT"
dig ${R53_ZONE_NAME} TXT

echo "insert into dns.host_zone value(, '${R53_ZONE_NAME}');" | mysql -u root -h 127.0.0.1
echo 'select * from dns.host_zone;' | mysql -u root -h 127.0.0.1


