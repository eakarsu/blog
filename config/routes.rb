Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  root 'pages#home'
  get 'about', to: 'pages#about'
  resources :articles do
    member do
      post :submit_for_review
      post :request_changes
      post :approve
      post :publish
      post :archive
    end
    resources :media_assets, only: [:show, :create, :destroy]
    resources :article_revisions, only: [:index, :show]
    resources :comments, only: [:create, :destroy] do
      member do
        post :approve
        post :reject
      end
    end
  end
  get "feed", to: "feeds#show", defaults: { format: :atom }
  get "sitemap", to: "feeds#sitemap", defaults: { format: :xml }
  get "export", to: "publishing_exports#show"
  post "import", to: "publishing_imports#create"
  resources :audit_events, only: :index
  get 'signup', to: 'users#new'
  resources :users, except: [:new]
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  get 'api/auth/me', to: 'sessions#show'
  delete 'logout', to: 'sessions#destroy'
  resources :categories, except: [:destroy]

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
