require 'rubygems'
require 'sequel'
require 'time'

class BenchmarkRunInfo

  attr_reader :time
  attr_reader :crashed
  attr_reader :type
  attr_reader :name
  attr_reader :author
  attr_reader :passed

  def passed=(passed)
    if not crashed
      @passed = passed
    end
  end

  def initialize(time, crashed, name, author)
    @passed = false
    @time = time
    @crashed = crashed
    @name = name
    @author = author
  end

  def inspect2
    if @crashed
      passed = 'crashed'
    elsif @passed
      passed = 'passed'
    else
      passed = 'failed'
    end
    @passed ? passed = 'passed' : passed = 'failed'
    if not @passed
      puts "Benchmark #{@name} by #{@author} #{passed} in #{time} s."
    end
  end
end

class BenchmarkConfigRunInfo

  attr_reader :config

  def num_tested
    return @runs.length
  end

  def num_passed
    return @runs.length - failed.length
  end

  def num_failed
    return failed.length
  end

  def num_crashed
    return crashed.length
  end

  # Returns a list of failed benchmarks
  def failed
    failed = []
    @runs.each do |run|
      failed.push run if not run.passed
    end
    return failed
  end

  # Returns a list of crashed benchmarks
  def crashed
    crashed = []
    @runs.each do |run|
      crashed.push run if run.crashed
    end
    return crashed
  end

  # Get benchmark by name
  def benchmark(name)
    @runs.each do |run|
      return run if run.name =~ /#{Regexp.escape(name)}$/
    end
    puts "Benchmark #{name} not found."
    return nil
  end

  def inspect2
    puts '=== BenchmarkConfigRunInfo ==='
    puts "Tested  :  #{num_tested}"
    puts "Passed  :  #{num_passed}"
    puts "Crashed :  #{num_crashed}"
    puts "Failed  :  #{num_failed}"
    puts '---------------------'
    @runs.each { |run| run.inspect2}
    puts ''
  end

  def initialize(config)
    @config = config
    @runs = []
  end

  def add_benchmark_run(time, crashed, name, author)
    @runs.push BenchmarkRunInfo.new(time, crashed, name, author)
  end

end

class BenchmarkJobOutputReader

  attr_reader :bench_test_infos

  def num_tested
    num = 0
    @bench_test_infos.each do |info|
      num = num + info.num_tested
    end
    return num
  end

  def num_passed
    num = 0
    @bench_test_infos.each do |info|
      num = num + info.num_passed
    end
    return num
  end

  def num_crashed
    num = 0
    @bench_test_infos.each do |info|
      num = num + info.num_failed
    end
    return num
  end

  def num_failed
    num = 0
    @bench_test_infos.each do |info|
      num = num + info.num_failed
    end
    return num
  end

  def initialize(filename)
    @bench_test_infos = []

    File.open(filename, 'r') do |file|
      num_test_project_lines = 0
      while line = file.gets
        if line =~ /Test project/
          # Check config
          config = line.scan(/build_([\w]+$)/)[0].to_s

          # Even test runs are benchmarks, otherwise file compares
          if num_test_project_lines % 2 == 0
            bench_test_infos.push BenchmarkConfigRunInfo.new(config)
          end

          num_test_project_lines += 1

        elsif line =~ /^\s*[0-9]+\/[0-9]+\sTest/
          # Check for passed or failed
          crashed = false
          crashed = false if line =~ /\s+Passed\s+/
          crashed = true if line =~ /\*+Failed\s+/

          # Check author
          author = line.scan(/:\s([A-Z]{2,4})_/)[0].to_s

          # Check benchmark name
          name = line.scan(/(FILECOMPARE_|BENCHMARK_)(.+)\s\.+/)[0].to_s
          name = name.gsub('FILECOMPARE_', '').gsub('BENCHMARK_', '')

          # Even test runs are benchmarks, otherwise file compares
          if (num_test_project_lines-1) % 2 == 0

            # Check benchmark time
            time = line.scan(/\s+([0-9]+\.[0-9]+)\s+sec/)[0].to_s.to_f
         
            bench_test_infos.last.add_benchmark_run(
                time, crashed, name, author)

            #puts "Add Benchmark: #{name}, crashed #{crashed}"
          else
            bench = bench_test_infos.last.benchmark(name)
            if bench
              bench.passed = !crashed
            else
              puts line
            end
          end

        end
      end
    end

  end

  def inspect2
    puts '=== BenchmarkJobOutputReader ==='
    puts "Tested  :  #{num_tested}"
    puts "Passed  :  #{num_passed}"
    puts "Crashed :  #{num_crashed}"
    puts "Failed  :  #{num_failed}"
    puts '---------------------'
    @bench_test_infos.each { |info| info.inspect2}
    puts ''
  end

end

info = BenchmarkJobOutputReader.new('benchOut.txt')
puts info.inspect2