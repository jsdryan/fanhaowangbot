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
            {
              type: 'template',
              altText: 'DMM top 20 女演員',
              template: {
                type: 'carousel',
                columns: [
                  {
                    thumbnailImageUrl: 'https://pics.dmm.co.jp/mono/actjpgs/medium/sazanami_aya.jpg',
                    title: '佐々波綾',
                    text: 'Rank #1',
                    actions: [
                      {
                        type: 'uri',
                        label: '【佐々波綾】所有影片',
                        uri: 'http://www.dmm.co.jp/digital/videoa/-/list/=/article=actress/id=1037169/'
                      },
                    ],
                  },
                  {
                    thumbnailImageUrl: 'https://pics.dmm.co.jp/mono/actjpgs/medium/hatano_yui.jpg',
                    title: '波多野結衣',
                    text: 'Rank #2',
                    actions: [
                      {
                        type: 'uri',
                        label: '【波多野結衣】所有影片',
                        uri: 'http://www.dmm.co.jp/digital/videoa/-/list/=/article=actress/id=26225/'
                      },
                    ],
                  },
                ],
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
