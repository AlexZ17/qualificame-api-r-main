module Qualificame
	module Params
		module Serializer
			extend ActiveSupport::Concern

			included do
				include ActiveSupport::Callbacks
				define_callbacks :serialize
			end

			class_methods do
				attr_accessor :_extra_attributes, :_conditional_attributes

				def strip_attribute(attr)
					symbolized = attr.is_a?(Symbol)

					attr = attr.to_s.gsub(/\?\Z/, '')
					attr = attr.to_sym if symbolized
					attr
				end

				def extra_attributes(*attrs, **conditions)
					@_extra_attributes ||= []
					@_conditional_attributes ||= {}

					striped_attrs = attrs.map{ |attr|
						striped_attr = strip_attribute attr

						@_extra_attributes << striped_attr

						define_method striped_attr do
							object.read_attribute_for_serialization attr
						end unless method_defined?(attr)

						striped_attr
					}

					set_callback(:serialize, :before, **conditions){ |serializer_obj|
						serializer_obj.filtered_keys += striped_attrs
					} if conditions.present?
				end

				def valid_attribute?(attr)
					_attributes.include?(attr) or 
						_extra_attributes&.include?(attr)
				end

				def valid_extra_attribute?(attr)
					_extra_attributes&.include?(attr)
				end

				def valid_association?(attr)
					_associations.include?(attr)
				end


				# should be used when associating collection serializers:
				#
				# has_many :posts, serializer: PostSerializer.wrap
				#
				def wrap
					@wrap ||= Class.new(ArraySerializer) do
						def initialize(object, options={})
							super
							@each_serializer = self.class.each_serializer
						end
					end.tap{ |klass|
						klass.each_serializer = self
					}
				end
			end

			attr_reader :params_fields
			attr_accessor :filtered_keys

			def initialize(object, options={})
				super

				# Rails.logger.debug("#{self.class.name}: #{object.class.name} (#{object.id})")
				# Rails.logger.debug(Thread.current.backtrace.join("\n") + "\n") if self.is_a?(Api::V1::UserAppSerializer)

				# only root objects should get the params_fields from the scope
				@params_fields = options.fetch(:params_fields,
					scope&.respond_to?(:serializer_opts) && scope.serializer_opts)

				@serializers_cache = {}
			end


			def serializable_object(options={})
				filter_keys!
				# Rails.logger.debug("\n(serialize 1) #{self.class.name} (#{self.object_id.to_s(16)})")
				# Rails.logger.debug(Thread.current.backtrace.join("\n") + "\n") if self.is_a?(Api::V1::SepSchoolSerializer)
				run_callbacks :serialize do
					super.tap{ @serialized = true }
				end
			end

			def embedded_in_root_associations
				if @serialized then super
				else
					filter_keys!
					# Rails.logger.debug("\n(serialize 2) #{self.class.name} (#{self.object_id.to_s(16)})")
					# Rails.logger.debug(Thread.current.backtrace.join("\n") + "\n") if self.is_a?(Api::V1::SepSchoolSerializer)
					run_callbacks :serialize do
						super.tap{ @serialized = true }
					end
				end
			end

			def build_serializer(association)
				# optimization: avoid re-creating serializers each time this method is called 
				# 	(called by: #serialize and #embedded_in_root_associations)
				@serializers_cache[association] ||= super
			end

			
			
			def filter(keys)
				filtered_keys
			end

			# associations should have access to the corresponding 
			# nested fields sent in params_fields
			def association_options_for_serializer(association)
				super.tap{ |opts|
					opts[:params_fields] = RequestStore.store.dig(
						"#{self.class.name}:association_fields", association.name) }
			end

			private

				# validate fields against params and 
				# cache keys in the RequestStore for performance
				def filter_keys!
					self.filtered_keys = RequestStore.store["#{self.class.name}:params_serializer_attributes"] ||= begin

						if params_fields = self.params_fields

							valid_fields = self.class._attributes + (self.class._extra_attributes || [])
							
							if fields = params_fields[params_fields_key = :fields]
								attributes = valid_fields & fields
							elsif fields = params_fields[params_fields_key = :include_fields]
								attributes = self.class._attributes + fields.select{ |field| valid_fields.include?(field) }
							else
								attributes = self.class._attributes.dup
							end

							associations = self.class._associations
							association_fields = {}

							fields.each{ |field| 
								if field.is_a?(Hash)
									# add association with custom attributes
									field.each{ |assoc_key, assoc_fields|
										if associations.has_key?(assoc_key)
											attributes << assoc_key
											association_fields[assoc_key.to_s] = { params_fields_key => assoc_fields }
										end
									}
								else
									# add association WITHOUT custom attributes
									attributes << field if 
										associations.has_key?(field)
								end
							} if fields and associations.present?

							RequestStore.store["#{self.class.name}:association_fields"] = association_fields if 
								association_fields.present?

							attributes.unshift(:id) unless attributes.include?(:id)
							attributes
						else
							self.class._attributes
						end

					end
				end
		end
	end
end