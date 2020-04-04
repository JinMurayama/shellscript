#postgresを再起動する
/etc/init.d/postgres restart
sleep 5
#dbのリスト一覧を出力し、テキストファイルに埋め込む
#postgresユーザーでDBに接続し、DB一覧を出力
DATE=`date '+%Y-%m-%d'`
mkdir /usr/local/pgsql/data/list_log
mkdir /usr/local/pgsql/data/list_log/${DATE}
/usr/local/pgsql/bin/psql -U postgres -c "\l" > /usr/local/pgsql/data/list_log/${DATE}/db-list.txt
#db-list.txtのname欄だけを取り出して、delete-db-list.txtに出力
cat /usr/local/pgsql/data/list_log/${DATE}/db-list.txt | awk -F" " '{print $1}' > /usr/local/pgsql/data/list_log/${DATE}/delete-db-list.txt
#db-list.txtをtmpに格納
cp /usr/local/pgsql/data/list_log/${DATE}/delete-db-list.txt /tmp
#下記コマンドを実行し、データベースを削除
cat /tmp/delete-db-list.txt | while read line ; do /usr/local/pgsql/bin/psql -U postgres -c "DROP DATABASE IF EXISTS \"${line}\""; done
#postgres再起動
/etc/init.d/postgres restart
