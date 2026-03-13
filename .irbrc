puts "Loading #{__FILE__}"
# put overrides/additions in '_irbrc'

IRB.conf[:HISTORY_FILE] = "#{ENV["PROJECT_ROOT"]}/tmp/.irb_history"
