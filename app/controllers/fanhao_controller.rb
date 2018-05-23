require 'line/bot'

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
    message = {
      type: 'image',
      originalContentUrl: reply_text,
      previewImageUrl: reply_text
    }

    # 傳送訊息
    line.reply_message(reply_token, message)
  end

  def received_text
    message = params['events'][0]['message']
    message['text'] unless message.nil?
  end

  def keyword_reply(received_text)
    # 學習紀錄表
    keyword_mapping = {
      'QQ' => 'https://res.cloudinary.com/demo/image/upload/w_250,h_250,c_fill,f_auto/seagull.jpg',
      '我難過' => '神曲支援：https://www.youtube.com/watch?v=T0LfHEwEXXw&feature=youtu.be&t=1m13s'
    }

    # 查表
    keyword_mapping[received_text]
  end

  def webhook
    reply_text = keyword_reply(received_text)
    response = reply_to_line(reply_text)

    head :ok
  end
end
