#!/usr/bin/env ruby

require 'rubygems'
require 'sequel'

if ARGV.size > 4
  $DB = Sequel.connect('sqlite://' + ARGV[4])
else
  $DB = Sequel.connect('sqlite://ogsbench.db')
end

require 'bench_info.rb'
require 'commit_info.rb'
require 'ogs_author_mapping.rb'
require 'net/smtp'
require 'csv'

if ARGV.size < 2
  puts 'Usage: process_benchmark_job.rb commit_info_file benchmark_job_output'
  Process.exit 1
end

$password = nil
$job_url = nil

if ARGV.size > 2
  $password = ARGV[2]
end

if ARGV.size > 3
  $job_url = ARGV[3]
end



# if using text/html as Content-type then newlines must be encoded as <br> ...
def send_email(from, from_alias, to, to_alias, subject, message)
	msg = <<END_OF_MESSAGE
From: #{from_alias} <#{from}>
To: #{to_alias} <#{to}>
MIME-Version: 1.0
Content-type: text/plain
Subject: #{subject}

#{message}
END_OF_MESSAGE

	Net::SMTP.start('mr1.ufz.de',
                  25,
                  'localhost.localdomain',
                  'bilke', $password) do |smtp|
		puts "Sending email to #{to_alias} <#{to}>..."
    smtp.send_message(msg, from, to)
	end
end

### Read files ###
if File.exists?(ARGV[0])
  # read commit info
  CommitInfoLoader.new(ARGV[0])

  if File.exists?(ARGV[1])
    # read benchmark job output
    BenchmarkRunsLoader.new(ARGV[1])
  else
    puts "File #{ARGV[1]} does not exist!"
    Process.exit 1
  end
else
  puts "File #{ARGV[0]} does not exist!"
  Process.exit 1
end

### Process info ###

## Get failed benchmarks
actual_benchmark_runs = BenchmarkRun.filter(:commit_info_id => CommitInfo.last.revision)
failed_benchmarks = actual_benchmark_runs.filter(:passed => false)
crashed_benchmarks = failed_benchmarks.filter(:crashed => true)

## Get newly failed benchmarks
# Get last benchmark run
last_commit_info = CommitInfo.filter(:revision < CommitInfo.last.revision).order(:revision).last
last_benchmark_runs = BenchmarkRun.filter(:commit_info_id => last_commit_info.revision)

new_failed_benchmarks = []
failed_benchmarks.each do |actual_failed_benchmark|
  new_failed_benchmark = last_benchmark_runs.filter(:passed => true,
                                                    :name => actual_failed_benchmark.name).all
  if new_failed_benchmark.length > 0
    new_failed_benchmarks.push new_failed_benchmark[0]
  end
end

## Get fixed benchmarks
fixed_benchmarks = []
last_benchmark_runs.filter(:passed => false).each do |last_benchmark|
  #puts "last failed: #{last_benchmark.name}"
  fixed_benchmark = actual_benchmark_runs.filter(:passed => true,
                                                 :name => last_benchmark.name).all
  if fixed_benchmark.length > 0
    fixed_benchmarks.push fixed_benchmark[0]
  end
end

#puts "Fixed benchmarks:"
#fixed_benchmarks.each {|row| p row}

# Write email to commiter if something has changed
if new_failed_benchmarks.count or fixed_benchmarks.count
  author = Author[:id => CommitInfo.last.author.id]
  msg = "Hello #{author.name},\n\n"

  nice_verbs = ['awesome', 'brilliant', 'great', 'gorgeous']

  if fixed_benchmarks.count
    msg << "you are absolutely #{nice_verbs[rand(nice_verbs.length)]}! You have fixed the following benchmarks:\n"
    fixed_benchmarks.each do |benchmark|
      msg << benchmark.benchmark_info << "\n"
    end
    msg << "\n"
  end

  bla = ['Ah', 'Eh', 'Ouch']

  if new_failed_benchmarks.count
    msg << "#{bla[rand(bla.length)]}, something went wrong because there are new benchmarks failing:\n"
    new_failed_benchmarks.each do |benchmark|
      msg << benchmark.benchmark_info << "\n"
      msg << "Have a look at #{$job_url.to_s + benchmark.author.short_name + "_" + benchmark.name.gsub(/\//, "_") + ".html"} for more infos\n\n"
    end
    msg << "\nPlease fix them again as soon as possible.\n"

  end

  if failed_benchmarks.count
    msg << "Unfortunately the following benchmarks failed as before:\n"
    failed_benchmarks.each do |benchmark|
      if not new_failed_benchmarks.find{ |failed_benchmark| failed_benchmark.name == benchmark.name}
        msg << benchmark.benchmark_info << "\n"
        msg << "Have a look at #{$job_url.to_s + "artifact/benchmarks/results/" + benchmark.author.short_name + "_" + benchmark.name.gsub(/\//, "_") + ".html"} for more infos\n\n"
      end
    end
  end

  #puts msg
  send_email('Hudson Build Server', 'lars.bilke@ufz.de',
             'larsbilke83@googlemail.com', author.name,
             'Benchmark report', msg) if $password
end

## Generate statistics
num_tested = actual_benchmark_runs.count
num_failed = failed_benchmarks.count
num_new_failed = new_failed_benchmarks.count
num_crashed = crashed_benchmarks.count
num_fixed = fixed_benchmarks.count

# Write to csv file
CSV.open("#{File.dirname(ARGV[0])}/benchSummary.csv", "w") do |csv|
  csv << ['tested', 'failed', 'crashed', 'new_failed', 'fixed']
  csv << [num_tested.to_s, num_failed.to_s, num_crashed.to_s,
          num_new_failed.to_s, num_fixed.to_s]
end
