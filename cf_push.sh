#!/bin/bash

# 传入参数
push_mod=$1
config_file=$2
pushmessage=$3
hostnames=$4
v4_num=$5
v6_num=$6
ip_type=$7
csvfile=$8

# 检查配置文件是否存在
if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
    echo "错误：配置文件不存在或未指定"
    exit 1
fi

# 从配置文件读取推送设置
read_push_settings() {
    local push_id=$1
    yq e ".push[] | select(.push_name == \"$push_mod\")" "$config_file"
}

# 检查 informlog 文件并读取内容
if [ ! -f "./informlog" ]; then
    echo "informlog 文件不存在"
    message_text="错误: informlog 文件不存在，无法获取更新信息"
elif [ ! -s "./informlog" ]; then
    echo "informlog 文件为空"
    message_text="错误: 没有更新信息"
else
    message_text=$(cat ./informlog)
fi

# 读取 $csvfile 文件的部分
if [ -f "$csvfile" ]; then
    ip_count=$(($ip_type == "IPv4" ? $v4_num : $v6_num))
    ip_info=$(awk -F',' -v domains="$hostnames" -v ip_count="$ip_count" -v ip_type="$ip_type" 'BEGIN {
        split(domains, domain_arr, " ")
        print ip_type " 地址："
    }
    NR>1 {
        if (NR-2 < ip_count) {  # 只处理实际解析的IP数量
            ips[NR-1] = $1
            latency[NR-1] = $5
            speed[NR-1] = $6
            count++
        }
    }
    END {
        for (i=1; i<=count; i++) print ips[i]
        print "━━━━━━━━━━━━━━━━━━━"
        print "域名："
        for (i=1; i<=length(domain_arr); i++) print domain_arr[i]
        print "━━━━━━━━━━━━━━━━━━━"
        print "平均延迟："
        for (i=1; i<=count; i++) print latency[i] " ms"
        print "━━━━━━━━━━━━━━━━━━━"
        print "下载速度："
        for (i=1; i<=count; i++) print speed[i] " MB/s"
    }' "$csvfile")
    message_text="${ip_info}"
else
    message_text="错误: 没有测速结果 ($csvfile 文件不存在)"
fi

# 设置 Telegram 和微信 API 的基础 URL
tgapi=${Proxy_TG:-"https://api.telegram.org"}
wxapi=${Proxy_WX:-"https://qyapi.weixin.qq.com"}

# 处理多个推送模式
IFS=' ' read -ra push_modes <<< "$push_mod"
for mode in "${push_modes[@]}"; do
    case $mode in
        "不设置")
            echo "未设置推送模式"
            ;;
        "Telegram")  # Telegram 推送
            telegram_bot_token=$(yq e ".push[] | select(.push_name == \"Telegram\") | .telegram_bot_token" "$config_file")
            telegram_user_id=$(yq e ".push[] | select(.push_name == \"Telegram\") | .telegram_user_id" "$config_file")
            TGURL="https://api.telegram.org/bot${telegram_bot_token}/sendMessage"
            res=$(curl -s -X POST $TGURL -H "Content-type:application/json" -d "{\"chat_id\":\"$telegram_user_id\", \"parse_mode\":\"HTML\", \"text\":\"$message_text\"}")
            if [[ $(echo "$res" | jq -r ".ok") == "true" ]]; then
                echo "TG推送成功"
            else
                echo "TG推送失败，请检查网络或TG机器人token和ID"
            fi
            ;;
        "PushPlus")  # PushPlus 推送
            pushplus_token=$(yq e ".push[] | select(.push_name == \"PushPlus\") | .pushplus_token" "$config_file")
            echo "正在进行 PushPlus 推送..."
            res=$(curl -s -X POST "http://www.pushplus.plus/send" \
                 -H "Content-Type: application/json" \
                 -d "{\"token\":\"${pushplus_token}\",\"title\":\"Cloudflare优选IP推送\",\"content\":\"${message_text}\",\"template\":\"html\"}")
            if [[ $(echo "$res" | jq -r ".code") == 200 ]]; then
                echo "PushPlus推送成功"
            else
                echo "PushPlus推送失败，错误信息：$(echo "$res" | jq -r ".msg")"
                echo "请检查pushplus_token是否填写正确"
            fi
            ;;
        "Server酱")  # Server酱 推送
            server_sendkey=$(yq e ".push[] | select(.push_name == \"Server酱\") | .server_sendkey" "$config_file")
            res=$(curl -s -X POST "https://sctapi.ftqq.com/${server_sendkey}.send" -d "title=Cloudflare优选IP推送" -d "desp=${message_text}")
            if [[ $(echo "$res" | jq -r ".code") == 0 ]]; then
                echo "Server 酱推送成功"
            else
                echo "Server 酱推送失败，请检查Server 酱server_sendkey是否配置正确"
            fi
            ;;
        "PushDeer")  # PushDeer 推送
            pushdeer_pushkey=$(yq e ".push[] | select(.push_name == \"PushDeer\") | .pushdeer_pushkey" "$config_file")
            res=$(curl -s -X POST "https://api2.pushdeer.com/message/push" -d "pushkey=${pushdeer_pushkey}" -d "text=Cloudflare优选IP推送" -d "desp=${message_text}")
            if [[ $(echo "$res" | jq -r ".code") == 0 ]]; then
                echo "PushDeer推送成功"
            else
                echo "PushDeer推送失败，请检查pushdeer_pushkey是否填写正确"
            fi
            ;;
        "企业微信")  # 企业微信 推送
            wechat_corpid=$(yq e ".push[] | select(.push_name == \"企业微信\") | .wechat_corpid" "$config_file")
            wechat_secret=$(yq e ".push[] | select(.push_name == \"企业微信\") | .wechat_secret" "$config_file")
            wechat_agentid=$(yq e ".push[] | select(.push_name == \"企业微信\") | .wechat_agentid" "$config_file")
            wechat_userid=$(yq e ".push[] | select(.push_name == \"企业微信\") | .wechat_userid" "$config_file")
            access_token=$(curl -s -G "https://qyapi.weixin.qq.com/cgi-bin/gettoken" -d "corpid=$wechat_corpid" -d "corpsecret=$wechat_secret" | jq -r .access_token)
            res=$(curl -s -X POST "https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=$access_token" -H "Content-Type: application/json" -d "{\"touser\":\"$wechat_userid\",\"msgtype\":\"text\",\"agentid\":$wechat_agentid,\"text\":{\"content\":\"$message_text\"}}")
            if [[ $(echo "$res" | jq -r ".errcode") == "0" ]]; then
                echo "企业微信推送成功"
            else
                echo "企业微信推送失败，请检查企业微信参数是否填写正确"
            fi
            ;;
        "Synology-Chat")  # Synology-Chat 推送
            synology_chat_url=$(yq e ".push[] | select(.push_name == \"Synology-Chat\") | .synology_chat_url" "$config_file")
            res=$(curl -X POST "$synology_chat_url" -H "Content-Type: application/json" -d "{\"text\":\"$message_text\"}")
            if [[ $(echo "$res" | jq -r ".success") == "true" ]]; then
                echo "Synology-Chat推送成功"
            else
                echo "Synology-Chat推送失败，请检查synology_chat_url是否填写正确"
            fi
            ;;
        *)
            echo "未知的推送模式: $mode"
            ;;
    esac
done

exit 0
