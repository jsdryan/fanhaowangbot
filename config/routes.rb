Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  post 'fanhao/webhook', to: 'fanhao#webhook'
  get 'fanhao/welcome', to: 'fanhao#welcome'
end
