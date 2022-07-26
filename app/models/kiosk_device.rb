class KioskDevice < ApplicationRecord
	CLAIMED    = 1
	FORGOTTEN  = 2

	belongs_to :kiosk

	scope :by_uuid, -> (uuid) {
		where(uuid: uuid)
	}

	scope :claimed, -> {
		where(status: KioskDevice::CLAIMED)
	}

	scope :forgotten, -> {
		where(status: KioskDevice::FORGOTTEN)
	}

	def forgotten!
		update_attribute(:status, KioskDevice::FORGOTTEN)
	end

	private

		def self.redis_token(uuid:nil)
			new_uuid   = SecureRandom.urlsafe_base64(24)
			token      = nil
			tryouts    = 4
			leeway     = 8
			expires_in = 3.seconds#aqui se modifica la expiracion del qr

			Sidekiq.redis{ |redis|
				# early return when uuid was given but there's no token
				token = redis.hget("kiosk:#{uuid}", "token")
				return false if !token and uuid

				uuid = new_uuid if !uuid

				# is token still alive?
				ttl = redis.ttl("tokens:#{token}:kiosk")

				if ttl < leeway
					loop do
						token = KioskDevice.safe_token
						tryouts -= 1

						break if tryouts < 0 or redis.setnx("tokens:#{token}:kiosk", uuid)
					end

					# assign new token to uuid, set time
					redis.hset("kiosk:#{uuid}", "token", token)

					redis.expire("tokens:#{token}:kiosk", expires_in + leeway)
				end
			}

			return {
				uuid: uuid,
				token: token
			}
		end##

		def self.is_valid?(token:)
			leeway     = 8
			uuid       = nil

			Sidekiq.redis{ |redis|
				# is token still alive?
				ttl = redis.ttl("tokens:#{token}:kiosk")

				if ttl >= leeway
					uuid = redis.get("tokens:#{token}:kiosk")

				else
					# early return when token expired or doesn't exist
					return false
				end
			}

			return { uuid: uuid }
		end


		def self.safe_token
			return SecureRandom.urlsafe_base64(6)
		end
end
