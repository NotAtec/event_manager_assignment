require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone_number(number)
  phone_number = number.delete('^0-9')
  return phone_number if phone_number.length == 10

  return phone_number[1..-1] if phone_number.length == 11 && phone_number[0].to_i == 1

  'badnum'
end

def log_time(registration, count)
  to_register = DateTime.strptime(registration, '%m/%d/%y %H:%M')
  count[to_register.hour] += 1
  count
end

def log_date(registration, count)
  to_register = DateTime.strptime(registration, '%m/%d/%y %H:%M')
  count[to_register.wday] += 1
  count
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
time_count = Array.new(23, 0)
date_count = Array.new(7, 0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  phone_number = clean_phone_number(row[:homephone])
  File.open('output/phone_numbers.txt', 'a') { |file| file.puts("#{name} | #{phone_number}") }

  time_count = log_time(row[:regdate], time_count)

  date_count = log_date(row[:regdate], date_count)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

days = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]
active_day = days[date_count.index(date_count.max)]

puts "The most active time for signing up was between #{time_count.index(time_count.max)}:00 and #{time_count.index(time_count.max) + 1}:00"
puts "The most active day for signing up was: #{active_day}"
