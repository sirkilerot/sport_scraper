#!/bin/bash

username=$1
priezvisko=$(echo $username | awk '{print $2}')
mkdir -p "$priezvisko"

## Atletika ############################

search_atletika="site:statistika.atletika.sk $username"
atletika_result=$(googler -n 1 --json "$search_atletika")
atletika_html=$(echo "$atletika_result" | grep -oP '(?<="url": ")[^"]*')
echo "$atletika_html"
curl -o "${priezvisko}_atletika" "$atletika_html"
grep -Pzo '(?s)<h3 class="aktHPleft___ fanzonatitlered">Osobné rekordy</h3>.*?</table>' "${priezvisko}_atletika" > atlet_temp && mv atlet_temp "${priezvisko}_atletika"
grep -Pzo '(?s)<tr class.*' "${priezvisko}_atletika" > atlet_temp && mv atlet_temp "${priezvisko}_atletika"
awk 'NR % 9 == 2 || NR % 9==3' "${priezvisko}_atletika" > atlet_temp && mv atlet_temp "${priezvisko}_atletika"
sed -i '$d' "${priezvisko}_atletika"
awk '{gsub(/<[^>]*>/, ""); print}' "${priezvisko}_atletika" > atlet_temp && mv atlet_temp "${priezvisko}_atletika"
mv "${priezvisko}_atletika" "$priezvisko"
[ -f atlet_temp ] && rm atlet_temp

## ITRA ###################################
search_itra="site:itra.run $username"
itra_result=$(googler -n 1 --json $search_itra)
itra_html=$(echo $itra_result | grep -oP '(?<="url": ")[^"]*')
curl -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0 Safari/537.36" -o itra1 -L $itra_html
awk '/<div class="performance-progress">/,/<span class="level">/' itra1 > itra_temp && mv itra_temp itra1
grep -oP '<span class="level-count">\K[0-9]+' itra1 > ${priezvisko}_itra
grep -oP '<span class="level">\K[^<]+' itra1 >> ${priezvisko}_itra
rm itra1
mv ${priezvisko}_itra $priezvisko
[ -f itra_temp] && rm itra_temp

## Strava #################################

while true; do
    read -p "Do you want to provide Strava session cookie? (Yes/no): " answer
    if [[ $answer =~ [Nn](o)?$ ]]; then
        echo "Skipping strava.com"
        break
    fi
    read -p "Enter your session cookie: " session_cookie
    username_url=$(echo "$username" | sed 's/ /+/g')
    echo "https://www.strava.com/athletes/search?text=$username_url"
    curl -o strava_query -H "Cookie: _strava4_session=$session_cookie" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0 Safari/537.36" "https://www.strava.com/athletes/search?text=$username_url"
    grep 'data-athlete-id' strava_query | head -n 1 > athlete
    if [ -f athlete ] && [ ! -s athlete ]; then
        echo "User not found or session cookie invalid"
    else
        id=$(awk -F'href="' '{print $2}' athlete | awk -F'"' '{print $1}')
        curl -o strava_main -X GET -H "X-Requested-With: XMLHttpRequest" -H "Cookie: _strava4_session=$session_cookie" "https://www.strava.com/$id/profile_sidebar_comparison?hl=en-US&ytd_year=2024"
        rm strava_query athlete
        sed -n '/2025/,/<\/tbody>/p' strava_main > ${priezvisko}_strava
        sed -E 's/<[^>]*title=([^ >]+)[^>]*>/\1/g; s/<[^>]*>//g' ${priezvisko}_strava > temp && mv temp ${priezvisko}_strava
        sed -i '/^$/d' ${priezvisko}_strava
	sed -i '/^202[0-5]$\|^201[0-9]$/d' ${priezvisko}_strava
	awk '/Time/{getline; print}' ${priezvisko}_strava > user1
        [ -f strava_temp ] && rm strava_temp
	rm strava_main
	time_file=user1
	total_hours=0
	total_minutes=0
	while IFS= read -r time; do
	    hours=$(echo "$time" | grep -oP '\d+(?=h)')
	    minutes=$(echo "$time" | grep -oP '\d+(?=m)')
	    total_hours=$((total_hours + hours))
	    total_minutes=$((total_minutes + minutes))
	done < "$time_file"
	if (( total_minutes >= 60 )); then
	    additional_hours=$((total_minutes / 60))
	    total_hours=$((total_hours + additional_hours))
	    total_minutes=$((total_minutes % 60))
	fi
	total_minutes_for_weekly_avg=$((total_hours * 60 + total_minutes))
	weekly_minutes=$((total_minutes_for_weekly_avg / 52))
	weekly_hours=$((weekly_minutes / 60))
	weekly_remaining_minutes=$((weekly_minutes % 60))

	{
	    echo "Rocny objem: $total_hours h $total_minutes m"
	    echo "Tyzdenny objem: $weekly_hours h $weekly_remaining_minutes m"
	} > "${priezvisko}_final"
	echo "$total_hours h $total_minutes m"


        break
    fi
done
rm user1
cat ${priezvisko}/${priezvisko}_itra >> ${priezvisko}_final
cat ${priezvisko}/${priezvisko}_atletika >> ${priezvisko}_final
mv ${priezvisko}_final $priezvisko
mv ${priezvisko}_strava $priezvisko
echo 'done'
