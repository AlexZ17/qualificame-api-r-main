class ApplicationWorker
	include Sidekiq::Worker

	sidekiq_options retry: false

	def perform(*args)
		method_name, *other_args = args
		
		if self.respond_to?(method_name)
			method_name = method_name.to_sym
			
			if other_args.last.is_a?(Hash)
				*args, kwargs = other_args
				self.send(method_name, *args, **kwargs.symbolize_keys)
			else
				self.send(method_name, *args)
			end
		end
	end

end
