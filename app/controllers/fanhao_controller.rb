require 'line/bot'
require 'open-uri'

class FanhaoController < ApplicationController
  protect_from_forgery with: :null_session

  def line
    @line ||= Line::Bot::Client.new { |config|
      config.channel_secret = '3896157742f8e82f9f7b3dc3db0a710c'
      config.channel_token = 'jxl0ZhSptQiS8NneU1kxLKzu2MSX0L/9+mzmPFsxABifrL+BBmJQDj82NfqmIt4hQ6RPiPi4FGomcflpXyKAKoy8JDtmHSkkMkdxK5YKhjrvxQ5PTCs6XOWiMEIzYIRujEYcFVZhXmo4j6R1egl1BwdB04t89/1O/w1cDnyilFU=
  '
    }
  end

  # def reply_to_line(reply_text)
  #   return nil if reply_text.nil?

  #   # 取得 reply token
  #   reply_token = params['events'][0]['replyToken']

  #   # 設定回覆訊息

  #   message = if reply_text.kind_of?(Array)
  #     {

  #     }
  #   else
  #     {
  #       type: 'image',
  #       originalContentUrl: reply_text,
  #       previewImageUrl: reply_text
  #     }
  #   end

  #   # 傳送訊息
  #   line.reply_message(reply_token, message)
  # end

  # def received_text
  #   message = params['events'][0]['message']
  #   message['text'] unless message.nil?
  # end

  # def keyword_reply(received_text)
  #   result = case received_text
  #   when 'top 20'
  #     []
  #   else
  #     url = 'https://www.javbus.com'
  #     html_data = open("#{url}/#{received_text.parameterize}").read
  #     cover = Nokogiri::HTML(html_data).css(".bigImage img").attr('src').text
  #   end
  #   result
  # end

  def webhook
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
              type: 'text',
              text: 'top 20'
            }
          else
            url = 'https://www.javbus.com'
            html_data = open("#{url}/#{received_text.parameterize}").read
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


    # reply_text = keyword_reply(received_text)
    # response = reply_to_line(reply_text)
    head :ok
  end
end
