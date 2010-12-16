#!/usr/bin/env ruby

require 'rubygems'
require 'bench_info.rb'
require 'commit_info.rb'
require 'ogs_author_mapping.rb'

if ARGV.size < 2
  puts 'Usage: process_benchmark_job.rb commit_info_file benchmark_job_output'
  Process.exit 1
end

p ARGV

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

#failed_benchmarks.each {|row| row.inspect2}
#crashed_benchmarks.each {|row| p row}

## Get newly failed benchmarks
# Get last benchmark run

last_commit_info = CommitInfo.filter(:revision < CommitInfo.last.revision).order(:revision).last
p last_commit_info
#last_benchmark_runs = BenchmarkRun.filter(:commit_info_id => CommitInfo.last.previous.revision)

## Get fixed benchmarks

## Send emails for new failed benchmarks ##


#class ProcessBenchmarkJob
  # To change this template use File | Settings | File Templates.
#end
