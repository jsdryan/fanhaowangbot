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
          when 'top 20'
            data = []
            top20 = Nokogiri::HTML(open("http://www.dmm.co.jp/digital/videoa/-/ranking/=/type=actress/"))
            top20.css('.bd-b').each do |element|
              rank = element.css('.rank').text
              avatar_uri = URI.parse(element.css('img').attr('src').text)
              avatar_uri.scheme = 'https'
              avatar = avatar_uri.to_s
              name = element.css('.data > p').text
              works = "https:/" + element.css('.data > p > a').attr('href').text

              girl = {
                thumbnailImageUrl: avatar,
                title: name,
                text: rank,
                works: works,
                actions: [
                  {
                    type: 'uri',
                    label: "【#{name}】所有影片",
                    uri: works
                  },
                ],
              }
              data.push(girl)
            end
            puts data
            {
              type: 'template',
              altText: 'DMM top 20 女演員',
              template: {
                type: 'carousel',
                columns: data
              }
            }
          else
            url = 'https://www.javbus.com'
            html_data = open("#{url}/#{user_input.parameterize}").read
            cover = Nokogiri::HTML(html_data).css(".bigImage img").attr('src').text

            {
              type: 'image',
              originalContentUrl: cover,
              previewImageUrl: cover
            }
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
