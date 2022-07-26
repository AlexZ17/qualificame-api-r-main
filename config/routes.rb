Rails.application.routes.draw do
	use_doorkeeper do
		skip_controllers :authorizations, :applications, :authorized_applications
	end
	
	root 'api#index'

	devise_for :users,
				path: 'auth',
				path_names: {
					sign_in: 'login',
					sign_out: 'logout',
					registration: 'signup'
				},
				controllers: {
					sessions: 'auth/sessions',
					registrations: 'auth/registrations'
				}

	get "kiosk" => "kiosk_devices#show"

	namespace :api do
		resources :companies, only: [:show]
		# resources :users, only: [:index, :show, :create, :update, :destroy]
		get "me" => "users#show"

		resource :user, only: [:show, :update]

		resources :mobile_devices, only: [:create]

		resources :kiosks, only: [:index, :show, :create, :update, :destroy] do
			resources :kiosk_devices, only: [:index]
			resources :events_aggregations, only: [:index]
		end

		put "register_kiosk" => "kiosk_devices#update"
		put "logout_device" => "kiosk_devices#logout_kiosk_device"

		resources :questions, only: [:index, :show, :create, :update, :destroy] do 
			resources :choices, only: [:index, :create]
		end

		resources :choices, only: [:show, :update]
		
		resources :reports, only: [:index, :show, :create, :destroy]

		resources :alerts, only: [:index, :update]
		
		resources :events, only: [:index, :show, :create, :update]

	end
end