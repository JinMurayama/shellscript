while read line; do
domain=${line}
#status=`curl -LI -o /dev/null https://${domain}/ -w '%{http_code}\n' -s`
status=`curl -LI -0 /dev/null https://${domain}/ -w '%{http_code}\n' -s | grep "HTTP/" | tail -1 | awk '{print $2}'
`
echo "${line}"
echo "${line},${status}" >> domain_status.csv
done < domain_list.txt
