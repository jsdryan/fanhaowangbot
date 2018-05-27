require 'line/bot'
require 'open-uri'

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

  def get_vids_info_from(provider, fanhao)
    begin
      resp = open("#{provider}/#{fanhao.parameterize}")
      html_data = resp.read
      dom = Nokogiri::HTML(html_data)

      case provider
      when "https://www.javbus.com"
        cover = dom.css(".bigImage img").attr('src').text
        girls_node = dom.css("ul+ p a")
        genres_node = dom.css(".header+ p a")
      when "https://www.libredmm.com/movies"
        http_cover_url = dom.css(".w-100").attr('src').text
        parsed_cover_url = URI.parse(http_cover_url)
        parsed_cover_url.scheme = "https"
        cover = parsed_cover_url.to_s
        girls_node = dom.css("dd:nth-child(2) a")
        genres_node = dom.css("dd~ dd .list-inline-item a")
      end

      girls = girls_node.to_a.empty? ? "未知演員" : girls_node.to_a.join(", ")
      genres = genres_node.to_a.empty? ? "未知類別" : genres_node.to_a.join(", ")

      vid = {
        cover: cover,
        girls: girls,
        genres: genres
      }
    rescue Exception => e
      puts "errors occured while searching #{fanhao} at #{provider}"
      puts e
    end
  end

  def get_vid_info(fanhao)
    puts "get_vid_info 的 fanhao 參數是 #{fanhao}"
    case fanhao
    when /^[A-Za-z]+[\s\-]{1}\d+$/ # normal fanhao (including uncensoured)
      get_vids_info_from("https://www.javbus.com", fanhao)
    when /^\d+[A-Za-z]+[\s\-]{1}\d+$/ # m-stage
      get_vids_info_from("https://www.libredmm.com/movies", fanhao)
    else
      puts "找不到 #{fanhao}"
      nil
    end
  end

  def webhook
    body = request.body.read
    events = line.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          user_input = event.message['text']

          message = case user_input
                      # searching vids image on external sites
                    when "top 10"
                      puts "---------------------- top 10 ----------------------"
                      begin
                        data = []
                        url = "http://www.dmm.co.jp/digital/videoa/-/ranking/=/type=actress"
                        resp = open(url)
                        html_data = resp.read
                        dom = Nokogiri::HTML(html_data)
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
                    when /^[A-Za-z]+[\s\-]{1}\d+$/, /^\d+[A-Za-z]+[\s\-]{1}\d+$/
                      puts "---------------------- searching vid image ----------------------"
                      vid_info = get_vid_info(user_input)
                      puts vid_info
                      [
                        {
                          type: 'image',
                          originalContentUrl: vid_info[:cover],
                          previewImageUrl: vid_info[:cover]
                        },
                        { type: "text", text: "女優名：#{vid_info[:girls]}" },
                        { type: "text", text: "類型：#{vid_info[:genres]}" }
                      ]
                    when /.+\S\;\S.+/ # create keyword
                      puts "---------------------- create keyword ----------------------"
                      keyword, desired_value = user_input.split(';')
                      keyword_info = get_vid_info(keyword)
                      # if keyword cannot be found by searching from sites
                      # then create or update it
                      if keyword_info.nil?
                        mapping = FanhaoAlias.find_or_initialize_by(keyword: keyword)
                        mapping.fanhao = desired_value
                        mapping.save
                        text = "#{mapping.keyword} => #{mapping.fanhao} 建立完成"
                      else
                        text = "#{keyword} 不是 #{desired_value}，禁止混淆！"
                      end
                      { type: "text", text: text }
                    when /^\-\-.+\-\-/ # delete keyword
                      puts "---------------------- delete keyword ----------------------"
                      keyword = user_input.split('--')[1]
                      fanhao = FanhaoAlias.find_by(keyword: keyword)
                      fanhao.destroy
                      text = "「#{keyword}」已經被刪除"
                      { type: "text", text: text }
                    when ";help"
                      puts "---------------------- help ----------------------"
                      commands = "新增關鍵字 => 關鍵字;番號\n刪除關鍵字 => --關鍵字--\n查詢目前所有關鍵字 => ;list\n列出當月前十名女優 => top 10"
                      { type: 'text', text: commands }
                    when ";list"
                      puts "---------------------- list ----------------------"
                      commands = ""
                      FanhaoAlias.all.each do |fanhao|
                        commands << "\n#{fanhao.keyword} => #{fanhao.fanhao}"
                      end
                      { type: 'text', text: commands }
                    else
                      puts "---------------------- normal texting ----------------------"
                      begin
                        mapping = FanhaoAlias.find_by(keyword: user_input)

                        unless mapping.nil?
                          puts "#{user_input} 不是 nil"
                          fanhao_info = get_vid_info(mapping.fanhao)
                          unless fanhao_info.nil?
                          puts "#{fanhao_info} 不是 nil"
                            [
                              {
                                type: 'image',
                                originalContentUrl: fanhao_info[:cover],
                                previewImageUrl: fanhao_info[:cover]
                              },
                              { type: "text", text: "女優名：#{fanhao_info[:girls]}" },
                              { type: "text", text: "類型：#{fanhao_info[:genres]}" }
                            ]
                          else
                            { type: 'text', text: mapping.fanhao }
                          end
                        else
                          raise "no #{user_input} keyword in database."
                        end
                      rescue Exception => e
                        puts "Error occured while searching #{user_input} in database."
                        puts e
                      end
                    end

          line.reply_message(event['replyToken'], message)
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = line.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    }

    head :ok
  end
end
