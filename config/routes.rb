Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  post '/webhook', to: 'fanhao#webhook'
  root to: 'fanhao#welcome'
end
