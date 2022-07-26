class EventAggregationSerializer < ActiveModel::Serializer
	include Qualificame::Params::Serializer

	attributes :id, :description, :total, :active
end
