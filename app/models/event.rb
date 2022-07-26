class Event < ApplicationRecord
	VALUE_EXCELLENT = 1
	VALUE_AVERAGE   = 2
	VALUE_BAD       = 3
	VALUE_AWFUL     = 4

	TYPE_POSITIVE   = 1
	TYPE_NEGATIVE   = 2

	belongs_to :kiosk
	belongs_to :choice

	def select_type
		case value
		when Event::VALUE_EXCELLENT, Event::VALUE_AVERAGE
			return Event::TYPE_POSITIVE
		when Event::VALUE_BAD, Event::VALUE_AWFUL
			return Event::TYPE_NEGATIVE
		else
			return Event::TYPE_NEGATIVE
		end
	end

	def self.human_value(value)
		case value
		when Event::VALUE_EXCELLENT 
			return 'excellent'
		when Event::VALUE_AVERAGE 
			return 'average'
		when Event::VALUE_BAD 
			return 'bad'
		when Event::VALUE_AWFUL 
			return 'awful'
		else
			return ''
		end
	end

	def self.get_totals(first_event:, last_event:)
		indexed_events = {
			Event::VALUE_EXCELLENT => 0,
			Event::VALUE_AVERAGE => 0, 
			Event::VALUE_BAD => 0, 
			Event::VALUE_AWFUL => 0
		}
		result = total_events = total_positives = total_negatives = 0
		result_tag = ""

		if first_event.is_a?(Event) and last_event.is_a?(Event)

			indexed_events[Event::VALUE_EXCELLENT] = first_event.id === last_event.id ? last_event.cumulative_total_excellent : last_event.cumulative_total_excellent - first_event.cumulative_total_excellent
			indexed_events[Event::VALUE_AVERAGE]   = first_event.id === last_event.id ? last_event.cumulative_total_average : last_event.cumulative_total_average - first_event.cumulative_total_average
			indexed_events[Event::VALUE_BAD]       = first_event.id === last_event.id ? last_event.cumulative_total_bad : last_event.cumulative_total_bad - first_event.cumulative_total_bad
			indexed_events[Event::VALUE_AWFUL]     = first_event.id === last_event.id ? last_event.cumulative_total_awful : last_event.cumulative_total_awful - first_event.cumulative_total_awful

			total_events    = indexed_events.values.inject(0){|sum, count| sum + count }
			total_positives = indexed_events[Event::VALUE_EXCELLENT] + indexed_events[Event::VALUE_AVERAGE]
			total_negatives = indexed_events[Event::VALUE_BAD] + indexed_events[Event::VALUE_AWFUL]

			# [key, value]
			max = indexed_events.max_by{|k,v| v}

			result = total_events > 0 ? ( total_positives * 100 ) / total_events : 0
			result_tag = max[1] >= 0 ? Event.human_value( max[0] ) : ''

		end
		
		return [ indexed_events, result, result_tag, total_events, total_positives, total_negatives ]
	end
end
