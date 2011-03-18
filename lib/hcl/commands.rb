module HCl
  module Commands
    def tasks(filter=nil)
      tasks = Task.all
      if tasks.empty?
        puts "No cached tasks. Run `hcl show' to populate the cache and try again."
      else
        filter = Regexp.new(filter, 'i') unless filter.nil?
        tasks.each do |task|
          task_as_string = task.to_s
          if filter.nil? || task_as_string =~ filter
            puts '%8d %8d %s' % [task.project.id, task.id, ('# ' + task_as_string).black.bold]
          end
        end
      end
      nil
    end
  
    def set key = nil, *args
      if key.nil?
        @settings.each do |k, v|
          puts "#{k}: #{v}"
        end
      else
        value = args.join(' ')
        @settings ||= {}
        @settings[key] = value
        write_settings
      end
      nil
    end
  
    def unset key
      @settings.delete key
      write_settings
    end
  
    def aliases
      @settings.keys.select { |s| s =~ /^task\./ }.map { |s| s.slice(5..-1) }
    end
  
    def start *args
      starting_time = args.detect {|x| x =~ /^\+\d*(\.|:)?\d+$/ }
      if starting_time
        args.delete(starting_time)
        starting_time = time2float starting_time
      end
      ident = args.shift
      task_ids = if @settings.key? "task.#{ident}"
          @settings["task.#{ident}"].split(/\s+/)
        else
          [ident, args.shift]
        end
      task = Task.find *task_ids
      if task.nil?
        puts "Unknown project/task alias, try one of the following: #{aliases.join(', ')}."
        exit 1
      end
      timer = task.start(:starting_time => starting_time, :note => args.join(' '))
      puts "Started timer for #{timer} (at #{current_time})"
    end
    
    def stop
      entry = DayEntry.with_timer
      if entry
        entry.toggle
        puts "Stopped #{entry} (at #{current_time})"
      else
        puts "No running timers found."
      end
    end
  
    def note *args
      message = args.join ' '
      entry = DayEntry.with_timer
      if entry
        entry.append_note message
        puts "Added note '#{message}' to #{entry}."
      else
        puts "No running timers found."
      end
    end
  
    def show *args
      date = args.empty? ? nil : Chronic.parse(args.join(' '))
      total_hours = 0.0
      DayEntry.all(date).each do |day|
        running = day.running? ? '(running) '.yellow : ''
        message = "\t#{day.formatted_hours}\t#{running}#{day.client} - #{day.project} #{day.notes}"[0..78]
        message.green if running
        total_hours = total_hours + day.hours.to_f
        puts message
      end
      puts "\t" + '-' * 40
      puts "\t#{as_hours total_hours}\ttotal " + "(as of #{current_time})".black.bold
    end
    
    def resume
      entry = DayEntry.last
      if entry
        puts "Resumed #{entry} (at #{current_time})"
        entry.toggle
      else
        puts "No timers found"
      end
    end
    
  private
    def current_time
      Time.now.strftime('%I:%M %p').downcase
    end
  end
end
