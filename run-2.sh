#!/bin/bash
bar_size=40
bar_char_done="#"
bar_char_todo="-"
bar_percentage_scale=2

function show_progress {
    current="$1"
    total="$2"
    # calculate the progress in percentage 
    percent=$(bc <<< "scale=$bar_percentage_scale; 100 * $current / $total" )
    # The number of done and todo characters
    done=$(bc <<< "scale=0; $bar_size * $percent / 100" )
    todo=$(bc <<< "scale=0; $bar_size - $done" )
    # build the done and todo sub-bars
    done_sub_bar=$(printf "%${done}s" | tr " " "${bar_char_done}")
    todo_sub_bar=$(printf "%${todo}s" | tr " " "${bar_char_todo}")
    # output the bar
    echo -ne "\rProgress : [${done_sub_bar}${todo_sub_bar}] ${percent}%"
    if [ $total -eq $current ]; then
        echo -e "\nDONE"
    fi
}

echo "" > /home/sqldata/scripts/transfer.md

# global vars
if [ -f .env ]; then
	from_srv=$(awk -F '=' 'function t(s){gsub(/[[:space:]]/,"",s);return s};/^FROM_SRV/{v=t(\$2)};END{printf "%s\n",v}' ./.env)
	chat_id=$(awk -F '=' 'function t(s){gsub(/[[:space:]]/,"",s);return s};/^CHAT_ID/{v=t($2)};END{printf "%s\n",v}' ./.env)
	bot_api=$(awk -F '=' 'function t(s){gsub(/[[:space:]]/,"",s);return s};/^API/{v=t($2)};END{printf "%s\n",v}' ./.env)	
else
    echo "file .env not found."
    exit 1
fi

# run transfer
num_args=$#
transfer_count=0
not_transfer_count=0

for i in $(seq 1 $num_args); do
  db_name=$(echo "$@" | cut -d' ' -f$i)
  pg_dump --dbname $db_name --host=$from_srv --create | psql >&/dev/null
  psql -c "\l" | grep $db_name >&/dev/null > /home/sqldata/scripts/tmp.md
  if ! grep -q "$db_name" /home/sqldata/scripts/tmp.md; then
    echo -e "\n$db_name not_transfered $(date +%d"."%m"."%Y)" >> /home/sqldata/scripts/transfer.md
    ((not_transfer_count++))
  else
    echo -e "\n$db_name transfer date $(date +%d"."%m"."%Y)" >> /home/sqldata/scripts/transfer.md
    ((transfer_count++))
  fi
  show_progress $i $num_args
done

# results
get_fail=$(cat /home/sqldata/scripts/transfer.md | grep "not_.*")
fail=$(if grep -q "not_.*" /home/sqldata/scripts/transfer.md; then echo "LIST: $get_fail"; fi)
dst_srv=$(hostname)
curl --data-urlencode "chat_id=$chat_id" \
     --data-urlencode "text=TRANSFER from $from_srv to $dst_srv COMPLETE with status: SUCCESS $transfer_count . ERRORS $not_transfer_count . DATE $(date "+%Y-%m-%d %H:%M:%S") . $fail" \
     "https://api.telegram.org/bot$bot_api/sendMessage" \
     &>/dev/null
