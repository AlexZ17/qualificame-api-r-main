module SerializerOptions
	extend ActiveSupport::Concern

	included do
		attr_accessor :serializer_opts
	end
end
