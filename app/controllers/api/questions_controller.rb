class Api::QuestionsController < ApiController
	include Qualificame::Params
	before_action only: [:create, :update, :destroy] do
		doorkeeper_authorize! :admin
	end
	before_action only: [:index, :show] do
		doorkeeper_authorize! :admin, :kiosk
	end

	# GET /api/questions
	#
	def index
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)
		
			kiosk_ids = kiosk_device.kiosk_id

		elsif scope == User::ADMIN
			kiosk_ids = current_company.kiosks.pluck(:id)

		else
			return forbidden

		end

		@questions = Question

		params_filters{ |key, values|
			case key
					
			when :kiosk_id
				kiosk_id = params_array_to_integers(values)[0]

				return forbidden unless current_company.valid_kiosk?(kiosk_id)
				kiosk_ids = kiosk_id if kiosk_id

			when :question_type
				@questions = @questions.where(question_type: values)

			end
		}
		
		@questions = @questions.where(kiosk_id: kiosk_ids)

		params_sort_by{ |key, order|
			case key
			when :created_at
				@questions = @questions.order("questions.created_at #{order}")

			end
		}

		@questions = @questions.all
		
		render json: @questions
	end
	
	# GET /api/questions/:id
	#
	def show
		if scope == User::KIOSK
			uuid = params[:uuid]

			raise ApplicationController::InvalidParameter.new(:uuid) unless uuid

			kiosk_device = KioskDevice.where(uuid: uuid, status: KioskDevice::CLAIMED).take

			return unauthorized unless kiosk_device and current_company.valid_kiosk?(kiosk_device.kiosk_id)

		end

		@question = Question.where(id: params[:id].to_i).take

		return forbidden unless current_company.valid_kiosk?(@question&.kiosk_id)
		return not_found unless @question
		
		render json: @question
	end
	
	# POST /api/questions
	#
	def create
		begin
			@question = build_params(Question.new)
			return unless @question
				
			@question.save
			
			render json: @question
		rescue ActiveRecord::RecordNotUnique
			return bad_request('Solamente puede existir una pregunta de este tipo por Kiosko')
		end
	end
	
	# PUT /api/questions/:id
	#
	def update
		@question = Question.where(id: params[:id].to_i).take

		return forbidden unless current_company.valid_kiosk?(@question&.kiosk_id)
		return not_found unless @question
			
		return unless build_params(@question)
			
		@question.save
		
		render json: @question
	end

	# DELETE /api/questions/:id
	# 
	def destroy
		@question = Question.where(id: params[:id].to_i).take

		@question.destroy

		head :no_content
	end
	
	private
	
		def safe_params
			@safe_params ||= params.require(:question).permit(
				:question_type,
				:description,
				:kiosk_id
			)
		end
		
		def build_params(question)
			question_params = safe_params

			if question.new_record?
				kiosk_id = question_params[:kiosk_id].to_i
				raise ApplicationController::InvalidParameter.new(:kiosk_id) unless 
					kiosk_id > 0 and kiosk = Kiosk.where(id: kiosk_id).take
				
				return forbidden unless current_company.valid_kiosk?(kiosk_id)

				question.kiosk = kiosk
			end
			
			question.question_type = question_params[:question_type].to_i if 
				question_params.has_key?(:question_type)
			
			question.description = question_params[:description] if 
				question_params.has_key?(:description)
				
			question.valid?
			
			question
		end
end
