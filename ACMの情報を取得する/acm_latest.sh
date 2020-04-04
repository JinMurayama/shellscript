PROFILE=
DOMAIN_NAME="example.net"
FILE="acm_list.txt"

rm ${FILE}

aws acm list-certificates --profile ${PROFILE} | jq -r --arg domain_name ${DOMAIN_NAME} '.CertificateSummaryList[]|select(.DomainName==$domain_name)|.CertificateArn' >> ${FILE}

#num=`cat "${FILE}" | wc -l `

#if [ $num -gt 1 ] ; then
#    echo "証明書が2つ以上存在します"
#else
#    echo "証明書が1つしか存在しないので、終了します"
#    exit 1;
#fi

while read ACM
do
row=`aws acm describe-certificate --certificate-arn ${ACM} --profile ${PROFILE} | jq -r '.Certificate|[.NotAfter,.InUseBy[]] | @csv'`
end_date=`echo $row | cut -d , -f 1`
alb=`echo $row | cut -d , -f 2`

echo ${ACM}
echo -n "有効期限は"
echo `date --date @${end_date}`
echo -n "ALBは"
echo ${alb}

done < ${FILE}
