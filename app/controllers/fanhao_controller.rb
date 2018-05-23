class FanhaoController < ApplicationController
  protect_from_forgery with: :null_session

  def welcome
    render plain: 'test'
  end

  def webhook
    head :ok
  end
end
