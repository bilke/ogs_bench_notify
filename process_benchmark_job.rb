#!/usr/bin/env ruby

require 'rubygems'
require 'bench_info.rb'
require 'commit_info.rb'
require 'ogs_author_mapping.rb'
require 'net/smtp'

if ARGV.size < 2
  puts 'Usage: process_benchmark_job.rb commit_info_file benchmark_job_output'
  Process.exit 1
end

p ARGV

def send_email(from, from_alias, to, to_alias, subject, message)
	msg = <<END_OF_MESSAGE
From: #{from_alias} <#{from}>
To: #{to_alias} <#{to}>
MIME-Version: 1.0
Content-type: text/html
Subject: #{subject}

#{message}
END_OF_MESSAGE

	Net::SMTP.start('mail.your-domain.com',
                  25,
                  'localhost',
                  'username', 'password') do |smtp|
		smtp.send_message(msg, from, to)
	end
end

### Read files ###
#if File.exists?(ARGV[0])
#  # read commit info
#  CommitInfoLoader.new(ARGV[0])
#
#  if File.exists?(ARGV[1])
#    # read benchmark job output
#    BenchmarkRunsLoader.new(ARGV[1])
#  else
#    puts "File #{ARGV[1]} does not exist!"
#    Process.exit 1
#  end
#else
#  puts "File #{ARGV[0]} does not exist!"
#  Process.exit 1
#end

### Process info ###

## Get failed benchmarks
actual_benchmark_runs = BenchmarkRun.filter(:commit_info_id => CommitInfo.last.revision)
failed_benchmarks = actual_benchmark_runs.filter(:passed => false)
crashed_benchmarks = failed_benchmarks.filter(:crashed => true)

#CommitInfo.each {|row| p row}
#actual_benchmark_runs.each {|row| p row}
#failed_benchmarks.each {|row| row.inspect2}
#crashed_benchmarks.each {|row| p row}

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

#puts "Newly failed benchmarks:"
#new_failed_benchmarks.each {|row| p row}

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

  if new_failed_benchmarks.count
    msg << "ah, something went wrong because there are new benchmarks failing:\n"
    new_failed_benchmarks.each do |benchmark|
      msg << benchmark.benchmark_info << "\n"
    end
    msg << "\nPlease fix them again as soon as possible."
  end

  puts msg
end
