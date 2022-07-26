class Api::ReportsController < ApiController
	include Qualificame::Params
	before_action only: [:index, :show, :create, :destroy] do
		doorkeeper_authorize! :admin
	end
	
	# GET /api/reports
	#
	def index
		kiosk_ids = current_company.kiosks.pluck(:id)
		@reports = Report.where(kiosk_id: kiosk_ids)
		
		meta = {}
		
		params_pagination(max_limit: 30){ |limit, offset|
			meta[:total] = total = @reports.count
			
			@reports = offset >= total ? 
				@reports.none :
				@reports.limit(limit).offset(offset).order(created_at: :desc)
		}
		
		@reports = @reports.all

		meta = nil unless meta.present?
		
		render json: @reports, each_serializer: ReportSerializer, meta: meta
	end

	# GET /api/reports/:id
	#
	def show
		@report = Report.where(id: params[:id].to_i).take

		return forbidden unless current_company.valid_kiosk?(@report&.kiosk_id)
		return not_found unless @report
		
		render json: @report
	end
	
	# POST /api/reports
	#
	def create
		@report = build_params(Report.new)
		return unless @report

		@report.save
		
		render json: @report
	end

	# DELETE /api/reports/:id
	# 
	def destroy
		@report = Report.where(id: params[:id].to_i).take

		return forbidden unless current_company.valid_kiosk?(@report.kiosk_id)
		return not_found unless @report

		@report.destroy

		head :no_content
	end
	
	private

		def safe_params
			@safe_params ||= params.require(:report).permit(
				:start_datetime,
				:end_datetime,
				:kiosk_id
			)
		end

		def build_params(report)
			report_params = safe_params

			# report.start_datetime = param_to_datetime!(report_params, :start_datetime) if
			# 	report_params.has_key?(:start_datetime)

			# report.end_datetime = param_to_datetime!(report_params, :end_datetime) if
			# 	report_params.has_key?(:end_datetime)

			report.start_datetime = report_params[:start_datetime] if
				report_params.has_key?(:start_datetime)

			report.end_datetime = report_params[:end_datetime] if
				report_params.has_key?(:end_datetime)

			kiosk_id = report_params[:kiosk_id].to_i
			raise ApplicationController::InvalidParameter.new(:kiosk_id) unless 
				kiosk_id > 0 and kiosk = Kiosk.where(id: kiosk_id).take
			
			return forbidden unless current_company.valid_kiosk?(kiosk_id)

			report.kiosk = kiosk

			total_events, result, result_tag = report.kiosk.build_report(report.start_datetime, report.end_datetime)
			if total_events
				report.total_excellent = total_events[Event::VALUE_EXCELLENT]
				report.total_average   = total_events[Event::VALUE_AVERAGE]
				report.total_bad       = total_events[Event::VALUE_BAD]
				report.total_awful     = total_events[Event::VALUE_AWFUL]
			end
			
			report.result = result
			report.result_tag = result_tag

			report.valid?

			report
		end
end

