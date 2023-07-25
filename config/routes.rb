Rails.application.routes.draw do
  root 'home#index'

  # Devise (login/logout)
  devise_for :users, defaults: { format: :html },
                         path: '',
                   path_names: { sign_up: 'register' },
                  controllers: {
                    sessions: 'sessions',
                    registrations: 'registrations',
                    confirmations: 'confirmations'
                  }
  devise_scope :user do
    get 'sign_in', to: 'devise/sessions#new'
    get 'register', to: 'devise/registrations#new'
    post 'register', to: 'devise/registrations#create'
    delete 'sign_out', to: 'devise/sessions#destroy'
    get 'confirmation/sent', to: 'confirmations#sent'
    get 'confirmation/:confirmation_token', to: 'confirmations#show'
    patch 'confirmation', to: 'confirmations#create'
  end

  # Redirect old urls
  get '/users/sign_in', to: redirect('/sign_in')
  get '/users/sign_out', to: redirect('/sign_out')
  get '/users/confirmation', to: redirect('/confirmation')
  get '/users/register', to: redirect('/register')
  get '/password', to: redirect('/edit')
  patch 'users/confirmation', to: 'confirmations#create'
  patch 'confirmation.user', to: 'confirmations#create'
  get '/welcome', to: redirect('/home')
  get '/apple-touch-icon-precomposed.png', to: redirect('/icons/apple-touch-icon-precomposed.png')
  get '/apple-touch-icon.png', to: redirect('/icons/apple-touch-icon.png')
  get '/.well-known/assetlinks.json', to: 'errors#not_found'

  # Post-login home page
  get 'home' => 'home#index'
  post 'home/toggle_sidebar' => 'home#toggle_sidebar'

  # Events, schedules, memberships and reports
  get 'events/my_events' => 'events#my_events', as: :my_events
  get 'events/org_events' => 'events#org_events', as: :org_events
  get 'events/past(/location/:location)' => 'events#past', as: :events_past
  get 'events/future(/location/:location)' => 'events#future', as: :events_future
  get 'events/year/:year(/location/:location)' => 'events#year', as: :events_year
  get 'events/location/:location(/year/:year)' => 'events#location', as: :events_location
  get 'events/kind/:kind(/year/:year)' => 'events#kind', as: :events_kind
  get '/events/reports' => 'reports#select_events_form', as: :events_report
  post '/events/reports' => 'reports#export_events', as: :events_generate_report

  resources :events do
    get 'schedule/new/:day' => 'schedule#new', as: :schedule_day
    get 'schedule/new/:day/item' => 'schedule#new_item', as: :schedule_item
    get 'schedule/:id' => 'schedule#edit', as: :schedule_edit
    post 'schedule/create' => 'schedule#create'
    post 'schedule/publish_schedule' => 'schedule#publish_schedule'
    post 'schedule/:id/recording/:record_action' => 'schedule#recording', as: :recording
    get 'report' => 'reports#event_form', as: :report
    get 'summary' => 'reports#summary', as: :summary
    post 'report' => 'reports#export', as: :generate_report
    resources :schedule
    resources :memberships do
      match 'email_change' => 'memberships#email_change', as: :email_change, via: [:get, :post]
      get 'cancel_email_change' =>  'memberships#cancel_email_change', as: :email_cancel
      collection do
        match 'add', via: [:get, :post]
        post 'process_new'
        match 'invite', via: [:get, :post]
      end
    end
    get 'lectures' => 'lectures#index'
  end

  get 'email_notifications' => 'email_notifications#index'
  scope path: 'email_notifications/:location/:attendance', as: :email_notification do
    get '/' => 'email_notifications#show'
    get 'new' => 'email_notifications#new'
    match '/' => 'email_notifications#upsert', via: %i[put post]
    delete '/destroy' => 'email_notifications#destroy'
  end

  resources :settings
  post 'settings/delete' => 'settings#delete'

  # Invitations & RSVP
  get '/invitations' => 'invitations#index'
  get '/invitations/new/(:id)' => 'invitations#new', as: :invitations_new
  post '/invitations/create' => 'invitations#create'
  get '/invitations/send/:membership_id' => 'invitations#send_invite',
      as: :invitations_send
  get '/invitations/send_all/:event_id' => 'invitations#send_all_invites',
      as: :all_invitations_send

  get '/rsvp' => 'rsvp#index'
  get '/rsvp/:otp' => 'rsvp#index', as: :rsvp_otp, constraints: { otp: /[^\/]+/ }
  match '/rsvp/email/:otp' => 'rsvp#email', as: :rsvp_email, via: [:get, :post]
  match '/rsvp/confirm_email/:otp' => 'rsvp#confirm_email', as: :rsvp_confirm_email, via: [:get, :post]
  match '/rsvp/cancel/:otp' => 'rsvp#cancel', as: :rsvp_cancel, via: [:get, :post]
  match '/rsvp/yes/:otp' => 'rsvp#yes', as: :rsvp_yes, via: [:get, :post]
  match '/rsvp/yes-online/:otp' => 'rsvp#yes_online', as: :rsvp_yes_online, via: [:get, :post]
  match '/rsvp/no/:otp' => 'rsvp#no', as: :rsvp_no, via: [:get, :post]
  match '/rsvp/maybe/:otp' => 'rsvp#maybe', as: :rsvp_maybe, via: [:get, :post]
  match '/rsvp/feedback/:membership_id' => 'rsvp#feedback',
        as: :rsvp_feedback, via: [:get, :post]

  # API
  namespace :api do
    devise_for :users, defaults: { format: :json }, class_name: 'ApiUser',
                           skip: [:registrations, :invitations, :passwords, :confirmations, :unlocks],
                           path: '', path_names: { sign_in: 'login', sign_out: 'logout' }

    devise_scope :user do
      get 'login', to: 'devise/sessions#new'
      delete 'logout', to: 'devise/sessions#destroy'
    end

    namespace :v1 do
      patch 'lectures' => 'lectures#update'
      put 'lectures' => 'lectures#update'
      get 'lecture_data/:id' => 'lectures#lecture_data', as: :lecture_data
      get 'lectures_on/:date/:location' => 'lectures#lectures_on', as: :lectures_on
      get 'lectures_at/:date/:location' => 'lectures#lectures_at', as: :lectures_at
      get 'lectures_current/:room' => 'lectures#current', as: :lectures_current
      get 'lectures_next/:room' => 'lectures#next', as: :lectures_next
      get 'lectures_last/:room' => 'lectures#last', as: :lectures_last
      post 'events' => 'events#create'
      post 'events/sync' => 'events#sync'
    end
  end

  # Admin dashboard
  namespace :admin do
    resources :events
    resources :people
    resources :lectures
    resources :schedules
    resources :users
    root to: "people#index"
  end

  # Maillists
  post "/maillist" => 'griddler/authentication#incoming'
  post "/bounces" => 'griddler/authentication#bounces'

  # Lectures RSS
  get '/lectures/today/:room' => 'lectures#today', as: :todays_lectures
  get '/lectures/current/:room' => 'lectures#current', as: :current_lecture
  get '/lectures/next/:room' => 'lectures#next', as: :next_lecture

  # Errors
  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
  get '/not_found' => 'errors#not_found'
  get '/wp-login.php' => 'errors#not_found'
  get '*unmatched_route', to: 'errors#not_found'
  match '*path' => redirect('/'), via: :get
end
