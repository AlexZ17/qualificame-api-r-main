class KioskDeviceSerializer < ActiveModel::Serializer
	include Qualificame::Params::Serializer

	attributes :id, :uuid, :status, :kiosk_id, :created_at, :name
end