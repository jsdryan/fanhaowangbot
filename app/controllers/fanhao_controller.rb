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

  def value_type(value)
    if value.match(/^\w+.\d+/)
      url = 'https://www.javbus.com'
      html_data = open("#{url}/#{value.parameterize}").read
      cover = Nokogiri::HTML(html_data).css(".bigImage img").attr('src')
      if cover.nil?
        "https://pics.javbus.com/cover/4u93_b.jpg"
      else
        cover.text
      end
    else
      FanhaoAlias.find_by(keyword: value).fanhao
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

          if user_input.match(/.+\;.+/) # 小手;OBD-065 / 小手;變態
            keyword, desired_value = user_input.split(';')
            fanhao_alias = FanhaoAlias.find_by(keyword: keyword)
            value = value_type(desired_value)

            if fanhao_alias.nil?
              FanhaoAlias.create(keyword: keyword, fanhao: value, is_activated: true)
            else
              fanhao_alias.update(fanhao: value)
            end
          elsif user_input.match(/^\-\-.+\-\-/)
            keyword = user_input.split('--')[1]
            fanhao = FanhaoAlias.find_by(keyword: keyword)
            fanhao.destory
          else # OBD-065 / 小手 / top 10
            message = case user_input
            when 'top 10'
              data = []
              top10 = Nokogiri::HTML(open("http://www.dmm.co.jp/digital/videoa/-/ranking/=/type=actress/"))
              top10.css('.bd-b').each do |element|
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
            else # OBD-065 / 小手
              cover = value_type(user_input)

              {
                type: 'image',
                originalContentUrl: cover,
                previewImageUrl: cover
              }
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
