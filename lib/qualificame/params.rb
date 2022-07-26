module Qualificame
	module Params
		extend ActiveSupport::Concern

		private

		# parse request params with the format:
		# ?filters=field_a=1,2;field_b;association(sub_field_a=1)
		#
		# call with block:
		# 	params_filters{ |field, values, association| }
		#
		def params_filters(restrict: nil)
			filters = params[:filters]
			return unless filters.is_a?(String)

			current_string = current_key = ''
			array_stack = []
			current_values = []
			current_hash = {}
			
			filters.each_char{ |c| 
				case c
				when 'a'..'z', '0'..'9', '_', '-', 'T', 'Z', ':', '.'
					current_string << c
				when '='
					current_key = current_string.to_sym if current_string.present?
					current_string = ''
				when ','
					current_values << current_string if current_string.present?
					current_string = ''
				when ';'
					current_values << current_string if current_string.present?
					current_hash[current_key.to_sym] = current_values if current_values.present?
					current_string = current_key = ''
					current_values = []
				when '('
					current_key = current_string.to_sym if current_string.present?
					array_stack << current_hash
					# nested depth bigger than 2 will be ignored
					current_hash = array_stack.length <= 2 ? 
						(current_hash[current_key] = {}) : {}
					current_string = current_key = ''
				when ')'
					current_values << current_string if current_string.present?
					current_hash[current_key.to_sym] = current_values if current_values.present?
					current_hash = array_stack.pop
					current_string = current_key = ''
					current_values = []
				end
			}

			current_values << current_string if current_string.present?
			current_hash[current_key.to_sym] = current_values if current_values.present?
			filters = current_hash

			filters.each{ |key, values| 
				if values.is_a?(Hash)
					values.each{ |sub_key, values|
						if values.is_a?(Hash)
							values.each{ |sub_sub_key, values|
								yield(sub_sub_key, values, sub_key)
							}
						else 
							yield(sub_key, values, key)
						end
					}
				else
					yield(key, values)
				end
			} if block_given?

			filters
		end


		# each item will be parsed to_i, remove 0 (ceros) and duplicates
		#
		def params_array_to_integers(values)
			
			set = Set.new

			values.each{ |value|
				value = Integer(value) rescue next
				set << value if value > 0 
			} if values.is_a?(Array)
			
			set.to_a
		end

		def params_extract_date(value, key)
			date = String(value)
			return unless date.present?
			
			Date.parse(date)
		rescue ArgumentError
			raise ActionController::InvalidParameter.new(key)
		end

		def params_extract_date!(params, key)
			date = String(params[key])
			return unless date.present?
			
			Date.parse(date)
		rescue ArgumentError
			raise ActionController::InvalidParameter.new(key)
		end

		def params_extract_integer!(params, key, range: 1..Float::INFINITY, required: false)
			number = params[key]
			unless number.present?
				raise ActionController::ParameterMissing.new(key) if required
				return
			end
			
			number = Integer(number)
			raise ActionController::InvalidParameter.new(key) if range and not range.cover?(number)
			
			number
		rescue ArgumentError
			raise ActionController::InvalidParameter.new(key)
		end


		def params_extract_string!(params, key, range: 0..255, required: false)
			string = params[key]
			if string == nil
				raise ActionController::ParameterMissing.new(key) if required
				return
			end

			string = String(string)
			raise ActionController::InvalidParameter.new(key) if range and not range.cover?(string.length)
			
			string
		end

		def params_extract_email!(params, key)
			email = params[key].to_s
			return unless email.present?

			raise ActionController::InvalidParameter.new(key) unless User.email_valid?(email)
			
			email
		end


		# parse request params with the format:
		# ?sort_by=field_a;field_b:DESC;field_c:ASC
		#
		# ASC is the default.
		# 
		# call with block:
		# 	params_sort_by{ |field, direction| } # direction can be :asc or :desc
		#
		def params_sort_by
			sort_by = params[:sort_by]
			return unless sort_by.is_a?(String)

			sort_by.split(';').each{ |sort_by|
				next unless sort_by.present?
				
				key, order = $1, $2 if sort_by =~ /(.*):(ASC|DESC)/i
				key ||= sort_by
				order = order ? order.downcase : :asc

				yield(key.to_sym, order.to_sym)
			}
		end


		# parse request params with the format:
		# ?limit=100&offset=300
		#
		# call with block:
		# 	params_pagination(max_limit: 200){ |limit, offset| }
		# 
		# limit is required, or the block won't be called.
		# offset is optional.
		#
		def params_pagination(max_limit: 200, force: true)
			limit, offset = params.values_at(:limit, :offset)
			limit = max_limit if force and !limit.present?
			
			if limit.present?
				limit = limit.to_s.to_i
				limit = [0, limit, max_limit].sort[1]
				offset = offset.to_s.to_i
				offset = [0, offset].sort[1]

				yield(limit, offset)
			end
		end


		def params_cursor_pagination(max_limit: 200)
			limit = params_extract_integer!(params, :limit)
			limit = limit ? [0, limit, max_limit].sort[1] : max_limit

			order = $1 if params_extract_string!(params, :order) =~ /(ASC|DESC)/i
			order = order ? order.downcase.to_sym : :asc

			cursor = params_extract_string!(params, :cursor)

			yield(limit, cursor, order)
		end


		# parse request params with the format:
		# ?fields=name,type,nested_object(name,another_nested_object(name))
		# 
		# can be called with block:
		# 	params_fields{ |field| }
		# 
		# if the block evaluates false the field will be ignored:
		#
		# ... or if you want to control nested associations:
		# 	params_fields(max_depth: 1){ |field, association| }
		# 
		# @param max_depth [Optional]: the level depth allowed for nested associations.
		#
		def params_fields(max_depth: 1)
			fields = params[@params_fields_key = :fields] || params[@params_fields_key = :include_fields]

			fields = if fields.present? and fields.is_a?(String)
				current_key = ''
				array_stack = []
				current_array = []
				hash_stack = Hash.new{ |h, k| 
					current_array << v = {}; h[k] = v }
				hash_depth = 0
				
				fields.each_char{ |c| 
					case c
					when 'a'..'z', '0'..'9', '_', '-'
						current_key << c
					when ','
						current_array << current_key.to_sym if current_key.present?
						current_key = ''
					when '('
						if hash_depth < max_depth
							array_stack << current_array
							current_hash = hash_stack[hash_depth]
							current_hash[current_key.to_sym] = current_array = []
						else current_array = []
						end
						hash_depth += 1
						current_key = ''
					when ')'
						current_array << current_key.to_sym if current_key.present?
						current_array = array_stack.pop if hash_depth <= max_depth
						hash_stack.delete(hash_depth) if hash_stack.has_key?(hash_depth)
						hash_depth -= 1
						current_key = ''
					end
				}

				current_array << current_key.to_sym if current_key.present?
				current_array
			end

			if fields
				params_deep_each_field(fields, nil, &Proc.new) if block_given?
				(current_user.serializer_opts ||= {})[@params_fields_key] = fields 
			end

			fields
		end

		def params_fields_include(*fields)
			if !@params_fields_key or @params_fields_key == :include_fields
				((current_user.serializer_opts ||= {})[@params_fields_key ||= :include_fields] ||= []).concat(
					fields)
			end
		end


		def params_include_fields?
			@params_fields_key == :include_fields
		end


		def params_deep_each_field(fields, association = nil)
			fields.delete_if{ |value|
				if value.is_a?(Hash)
					value.delete_if{ |key, array|
						next true if yield(key, association) == false
						params_deep_each_field(array, key, &Proc.new)
						false
					}

					value.empty? 
				else
					yield(value, association) == false
				end
			}
		end

	end
end
