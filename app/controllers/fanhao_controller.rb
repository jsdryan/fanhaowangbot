require 'line/bot'
require 'open-uri'

class FanhaoController < ApplicationController
  protect_from_forgery with: :null_session

  def welcome
    render plain: 'test'
  end

  def line
    @line ||= Line::Bot::Client.new { |config|
      config.channel_secret = '3896157742f8e82f9f7b3dc3db0a710c'
      config.channel_token = 'jxl0ZhSptQiS8NneU1kxLKzu2MSX0L/9+mzmPFsxABifrL+BBmJQDj82NfqmIt4hQ6RPiPi4FGomcflpXyKAKoy8JDtmHSkkMkdxK5YKhjrvxQ5PTCs6XOWiMEIzYIRujEYcFVZhXmo4j6R1egl1BwdB04t89/1O/w1cDnyilFU=
  '
    }
  end

  def reply_to_line(reply_text)
    return nil if reply_text.nil?

    # 取得 reply token
    reply_token = params['events'][0]['replyToken']

    # 設定回覆訊息

    message = if reply_text.kind_of?(Array)
      {
        type: 'template',
        altText: 'this is an template message',
        template: {
          type: 'carousel',
          columns: [
            {
              thumbnailImageUrl: 'http://pics.dmm.co.jp/mono/actjpgs/medium/sazanami_aya.jpg',
              title: 'example',
              text: 'test',
              actions: [
                {
                  type: 'message',
                  label: 'keep',
                  text: 'keep'
                },
                {
                  type: 'uri',
                  label: 'site',
                  uri: 'https://example.com/page1'
                },
              ],
            },
            {
              thumbnailImageUrl: 'http://pics.dmm.co.jp/mono/actjpgs/medium/sazanami_aya.jpg',
              title: 'example',
              text: 'test',
              actions: [
                {
                  type: 'message',
                  label: 'keep',
                  text: 'keep'
                },
                {
                  type: 'uri',
                  label: 'site',
                  uri: 'https://example.com/page2'
                },
              ],
            },
          ],
        }
      }
    else
      {
        type: 'image',
        originalContentUrl: reply_text,
        previewImageUrl: reply_text
      }
    end

    # 傳送訊息
    line.reply_message(reply_token, message)
  end

  def received_text
    message = params['events'][0]['message']
    message['text'] unless message.nil?
  end

  def keyword_reply(received_text)
    result = case received_text
    when 'top 20'
      []
    else
      url = 'https://www.javbus.com'
      html_data = open("#{url}/#{received_text.parameterize}").read
      cover = Nokogiri::HTML(html_data).css(".bigImage img").attr('src').text
    end
    result
  end

  def webhook
    reply_text = keyword_reply(received_text)
    response = reply_to_line(reply_text)

    puts response
    head :ok
  end
end
