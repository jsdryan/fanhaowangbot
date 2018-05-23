require 'line/bot'

class FanhaoController < ApplicationController
  protect_from_forgery with: :null_session

  def welcome
    render plain: 'test'
  end

  def webhook
    client = Line::Bot::Client.new { |config|
      config.channel_secret = '3896157742f8e82f9f7b3dc3db0a710c'
      config.channel_token = 'jxl0ZhSptQiS8NneU1kxLKzu2MSX0L/9+mzmPFsxABifrL+BBmJQDj82NfqmIt4hQ6RPiPi4FGomcflpXyKAKoy8JDtmHSkkMkdxK5YKhjrvxQ5PTCs6XOWiMEIzYIRujEYcFVZhXmo4j6R1egl1BwdB04t89/1O/w1cDnyilFU=
'
    }

    reply_token = params['events'][0]['replyToken']
    message = {
      type: 'text',
      text: '好哦～好哦～'
    }

    response = client.reply_message(reply_token, message)

    head :ok
  end
end
