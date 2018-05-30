require 'line/bot'
require 'open-uri'
require 'uri'

class FanhaoController < ApplicationController
  protect_from_forgery with: :null_session

  def line
    @line ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def welcome
    render plain: 'server is up'
  end

  def learn(channel_id, received_text)
    keyword, desired_value = received_text.split(';')
    if get_vid_info(keyword).nil?
      mapping = KeywordReply.where(channel_id: channel_id, keyword: keyword).last
      if mapping.nil?
        mapping = KeywordReply.create(channel_id: channel_id, keyword: keyword, reply: desired_value)
        text = "#{mapping.keyword} => #{mapping.reply} 建立完成"
      else
        mapping.reply = desired_value
        mapping.save
        text = "#{mapping.keyword} => #{mapping.reply} 修改完成"
      end
    else
      text = "請勿亂搞"
    end
    { type: "text", text: text }
  end

  def delete_mapping(channel_id, keyword)
    mapping = KeywordReply.where(channel_id: channel_id, keyword: keyword).last
    mapping.destroy unless mapping.nil?
    text = "「#{keyword}」已經被刪除"
    { type: "text", text: text }
  end

  def pick(channel_id)
    current_setting = CurrentSetting.find_by(channel_id: channel_id)
    get_current_genre(channel_id) if current_setting.nil?
    genre_encoded_name = URI::encode(current_setting.genre.name)
    genre_url = if current_setting.genre.name == "ALL"
                  "https://www.javhoo.com"
                else
                  "https://www.javhoo.com/genre/#{genre_encoded_name}"
                end
    genre_dom = get_dom_from_url genre_url
    maximum = genre_dom.css("ul.pagination > li:nth-last-child(2) a").text.to_i
    page = rand(1..maximum)

    url = if current_setting.genre.name == "ALL"
            "https://www.javhoo.com"
          else
            "https://www.javhoo.com/genre/#{genre_encoded_name}/page/#{page}"
          end
    fanhao_array = []

    fanhaos_dom = get_dom_from_url url
    fanhaos_dom.css("date").each do |fanhao_dom|
      fanhao = fanhao_dom.text.split(" / ")[0]
      fanhao_array.push fanhao
    end
    rand_fanhao = fanhao_array.sample

    vid_info = get_vids_info_from "https://www.javbus.com", rand_fanhao
    [
      {
        type: 'image',
        originalContentUrl: vid_info[:cover],
        previewImageUrl: vid_info[:cover]
      },
      { type: "text", text: "番號：#{vid_info[:fanhao]}" },
      { type: "text", text: "女優名：#{vid_info[:girls]}" },
      { type: "text", text: "發行日：#{vid_info[:date]}" },
      { type: "text", text: "類型：#{vid_info[:genres]}" }
    ]
  end

  def list(channel_id)
    commands = ""
    KeywordReply.where(channel_id: channel_id).each do |keyword_reply|
      commands << "#{keyword_reply.keyword} => #{keyword_reply.reply}\n"
    end
    { type: 'text', text: commands }
  end

  def help()
    commands = "新增關鍵字 => 關鍵字;番號\n"
    commands << "刪除關鍵字 => --關鍵字--\n"
    commands << "查詢目前所有關鍵字 => ;list\n"
    commands << "列出當月前十名女優 => top 10\n"
    commands << "===========================\n"
    commands << "抽番號 => 抽\n"
    commands << "顯示影片類型 => ;page 數字\n"
    commands << "顯示目前類型 => ;nt\n"
    commands << "設定目前類型 => **類型編號**"
    { type: 'text', text: commands }
  end

  def get_top_10_from_dmm
    url = "http://www.dmm.co.jp/digital/videoa/-/ranking/=/type=actress"
    data = []
    begin
      dom = get_dom_from_url url
      top10 = dom.css('.bd-b').each do |element|
        rank = element.css('.rank').text
        avatar_uri = URI.parse(element.css('img').attr('src').text)
        avatar_uri.scheme = 'https'
        avatar = avatar_uri.to_s
        name = element.css('.data > p').text
        works = "https://www.dmm.co.jp" +  element.css('.data > p > a').attr('href').text

        girl = {
          thumbnailImageUrl: avatar,
          title: name,
          text: "Rank ##{rank}",
          actions: [
            {
              type: 'uri',
              label: "【#{name}】所有演出",
              uri: works
            }
          ]
        }
        data.push(girl) if data.size != 10
      end
      {
        type: 'template',
        altText: 'DMM top 10 女演員',
        template: {
          type: 'carousel',
          columns: data
        }
      }
    rescue Exception => e
      puts "Error occured while searching top 10 on DMM"
      puts e
    end
  end

  def judge_text(channel_id, user_input)
    mapping = KeywordReply.where(channel_id: channel_id, keyword: user_input).last
    unless mapping.nil?
      vid_info = get_vid_info(mapping.reply)
      unless vid_info.nil?
        [
          {
            type: 'image',
            originalContentUrl: vid_info[:cover],
            previewImageUrl: vid_info[:cover]
          },
          { type: "text", text: "女優名：#{vid_info[:girls]}" },
          { type: "text", text: "類型：#{vid_info[:genres]}" }
        ]
      else
        { type: 'text', text: mapping.reply }
      end
    else
      return nil
    end
  end

  def get_genres_by(page)
    text = ""
    Genre.paginate(page: page).each do |genre|
      text << "#{genre.id} => #{genre.name}\n"
    end
    { type: 'text', text: text }
  end

  def get_current_genre(channel_id)
    current_setting = CurrentSetting.find_by(channel_id: channel_id)
    if current_setting.nil?
      genre_id = Genre.find_by(name: "ALL").id
      set_current_genre(channel_id, genre_id)
      current_setting = CurrentSetting.find_by(channel_id: channel_id)
    end
    text = "目前頻道的類型為 #{current_setting.genre.id} => #{current_setting.genre.name}"
    { type: 'text', text: text }
  end

  def set_current_genre(channel_id, genre_id)
    current_setting = CurrentSetting.find_or_initialize_by(channel_id: channel_id)
    current_setting.genre_id = genre_id
    current_setting.save
    text = "頻道已設定為 #{current_setting.genre.id} => #{current_setting.genre.name}\n"
    text << "抽起來！抽起來！"
    { type: 'text', text: text }
  end

  def get_vids_info_from(provider, fanhao)
    url = "#{provider}/#{fanhao.parameterize}"
    begin
      dom = get_dom_from_url url
      case provider
      when "https://www.javbus.com"
        cover = dom.css(".bigImage img").attr('src').text
        girls_node = dom.css("ul+ p a")
        genres_node = dom.css(".header+ p a")
        date = dom.css("p:nth-child(2)").text.split(": ")[1]
        fanhao = dom.css("p:nth-child(1) .header+ span").text
      when "https://www.libredmm.com/movies"
        http_cover_url = dom.css(".w-100").attr('src').text
        parsed_cover_url = URI.parse(http_cover_url)
        parsed_cover_url.scheme = "https"
        cover = parsed_cover_url.to_s
        girls_node = dom.css("dd:nth-child(2) a")
        genres_node = dom.css("dd~ dd .list-inline-item a")
        date = dom.css("dd:nth-child(14)").text
      end

      girls = girls_node.to_a.empty? ? "未知演員" : girls_node.to_a.join(", ")
      genres = genres_node.to_a.empty? ? "未知類別" : genres_node.to_a.join(", ")

      vid = {
        cover: cover,
        girls: girls,
        genres: genres,
        date: date,
        fanhao: fanhao
      }
    rescue Exception => e
      puts "errors occured while searching #{fanhao} at #{provider}"
      puts e
    end
  end

  def get_vid_info(fanhao)
    puts "get_vid_info 的 fanhao 參數是 #{fanhao}"
    case fanhao
    when /^[A-Za-z]+[\s\-]?\d+$/ # normal fanhao (including uncensoured)
      get_vids_info_from("https://www.javbus.com", fanhao)
    when /^\d+[A-Za-z]+[\s\-]?\d+$/ # m-stage
      get_vids_info_from("https://www.libredmm.com/movies", fanhao)
    else
      puts "找不到 #{fanhao}"
      nil
    end
  end

  def get_dom_from_url(url)
    resp = open(url)
    html_data = resp.read
    Nokogiri::HTML(html_data)
  end

  def handle_commands(channel_id, command)
    case command
    when /^\;help/ then help()
    when /^\;list/ then list(channel_id)
    when "抽" then pick(channel_id)
    when "top 10" then get_top_10_from_dmm()
    when /^\;nt/ then get_current_genre(channel_id)
    end
  end

  def handle_searching(fanhao)
    vid_info = get_vid_info(fanhao)
    [
      {
        type: 'image',
        originalContentUrl: vid_info[:cover],
        previewImageUrl: vid_info[:cover]
      },
      { type: "text", text: "女優名：#{vid_info[:girls]}" },
      { type: "text", text: "發行日：#{vid_info[:date]}" },
      { type: "text", text: "類型：#{vid_info[:genres]}" }
    ]
  end

  def webhook
    body = request.body.read
    events = line.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          user_input = event.message['text']
          channel_id = params["events"][0][:"source"][:"groupId"]
          message = case user_input
                    when /^\;help/, /^\;list/, "抽", "top 10", /^\;nt/
                      handle_commands(channel_id, user_input)
                    when /^[A-Za-z]+[\s\-]?\d+$/, /^\d+[A-Za-z]+[\s\-]?\d+$/
                      handle_searching(user_input)
                    when /.*\S\;\S.*/
                      learn(channel_id, user_input)
                    when /^\-\-.+\-\-/
                      delete_mapping(channel_id, user_input.split('--')[1])
                    when /^\*{2}\d+\*{2}$/
                      desired_genre_id = user_input.split("**")[1]
                      set_current_genre(channel_id, desired_genre_id)
                    when /^\;page\s?[1-5]\b/ then get_genres_by(user_input.split(";page ")[1])
                    else
                      judge_text(channel_id, user_input)
                    end
          line.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end
end
