Rails.application.routes.draw do
  resources :post_views, only: [:create, :show]
  resources :post_searches, only: [:create, :show]
  resource :missed_searches, only: [:create, :show]
end
