class Api::ChoicesController < ApiController
	include Qualificame::Params
	include Api::ContextRecords
	before_action only: [:create, :update] do
		doorkeeper_authorize! :admin
	end
	before_action only: [:index, :show] do
		doorkeeper_authorize! :admin, :kiosk
	end

	load_context_records_for question: Question
	
	# GET /api/questions/:id/choices
	#
	def index
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)

		end

		@choices = Choice

		if question
			return forbidden unless current_company.valid_question?(question.id)

			@choices = @choices.where(:question_id => question.id)
			
		else return forbidden
		end

		params_filters{ |key, values|
			case key
					
			when :active
				@choices = @choices.where(active: values)

			end
		}

		@choices = @choices.all

		render json: @choices
	end
	
	# GET /api/choices/:id
	#
	def show
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)

		end

		@choice = Choice.where(id: params[:id].to_i).take
		
		return forbidden unless current_company.valid_question?(@choice&.question_id)
		return not_found unless @choice
		
		render json: @choice
	end
	
	# POST /api/questions/:id/choices
	#
	def create
		@choice = build_params(Choice.new)
		return unless @choice
			
		@choice.save
		
		render json: @choice
	end

	# PUT /api/choices/:id
	#
	def update
		@choice = Choice.where(id: params[:id].to_i).take
		
		return forbidden unless current_company.valid_question?(@choice&.question_id)
		return not_found unless @choice
			
		return unless build_params(@choice)

		@choice.save
		
		render json: @choice
	end
	
	private
	
		def safe_params
			@safe_params ||= params.require(:choice).permit(
				:description,
				:active
			)
		end
		
		def build_params(choice)
			choice_params = safe_params

			if choice.new_record?
				question_id = params[:question_id].to_i
				raise ApplicationController::InvalidParameter.new(:question_id) unless 
					question_id > 0 and question = Question.where(id: question_id).take
				
				return forbidden unless current_company.valid_question?(question_id)
				choice.question = question
			
				choice.description = choice_params[:description] if 
					choice_params.has_key?(:description)

			elsif choice.question.nil?
				return not_found

			end

			choice.active = choice_params[:active] if 
				choice_params.has_key?(:active)
				
			choice.valid?
			
			choice
		end
end
