#!/usr/bin/env ruby
# frozen_string_literal: true
require 'bigdecimal'
require 'bigdecimal/util'

if ARGV[0].nil?
  usage
  exit(false)
end
FILE = ARGV[0].freeze

# Header Row Variables
MAGIC_STRING = 'MPS7'
HEADER_SIZE = 9
HEADER_FORMAT = 'a4CN'

# Data Row Variables
ENUM_FORMAT = 'C'
BASE_DATA_LINE_FORMAT = 'NQ>'
ADDTIONAL_DATA_LINE_FORMAT = 'G'
RECORD_TYPE_ENUM = {
  0 => 'Debit',
  1 => 'Credit',
  2 => 'StartAutopay',
  3 => 'StopAutopay'
}.freeze

# Check to make sure file exists and is readable by user
file_check(FILE)

File.open(FILE, 'rb') do |f|
  results = {
    records: 0,
    total_debits: 0,
    total_credits: 0,
    autopays_started: 0,
    autopays_ended: 0,
    header_record_count: 0,
    balance_for_2456938384156277127: 0
  }
  # Header Row
  process_header(f, results)
  # Data Rows
  process_data_rows(f, results)
  # Output Results
  print_results(results)
end

BEGIN {
  def usage
    puts 'usage: record_processor.rb data_file'
  end

  def file_check(file)
    # Check to make sure file exists and is readable by user
    # raise exception if not.
    unless File.readable?(file) && File.exist?(file)
      raise 'Either file does not exist or this user ' \
            'does not have read permissions'
    end
  end

  def process_header(file_handle, results)
    # Extract header row
    header_arr = file_handle.read(HEADER_SIZE).unpack(HEADER_FORMAT)

    # Error out if we do not see Magic String (MPS7)
    raise 'Invalid header format!' if header_arr.first != MAGIC_STRING

    results[:header_record_count] = header_arr[2]
  end

  def process_data_rows(file_handle, results)
    until file_handle.eof?
      # Extract record type
      type_enum = file_handle.read(1).unpack(ENUM_FORMAT).first
      record_type = RECORD_TYPE_ENUM[type_enum]

      # Raise exception if row contains unknown record type
      raise 'Unknown Record Type!' if record_type.nil?

      # Get format and bytes based on record type
      bytes, unpack_format =
        case [RECORD_TYPE_ENUM[0], RECORD_TYPE_ENUM[1]].include? record_type
        when true
          [20, BASE_DATA_LINE_FORMAT + ADDTIONAL_DATA_LINE_FORMAT]
        when false
          [12, BASE_DATA_LINE_FORMAT]
        end

      # Read row
      data_row = [record_type, file_handle.read(bytes).unpack(unpack_format)]
                 .flatten

      validate_row_data(data_row)

      # Floats are not the best way to store currency, lets convert to BigDecimal
      data_row[3] = data_row[3].to_d if data_row[3]

      add_data_row_to_results(data_row, results)
    end
  end

  def validate_row_data(data_row)
    # !!Crude!! validation of data
    raise 'Invalid epoch time' unless /^\d+$/ =~ data_row[1].to_s

    raise 'Invalid user ID' unless data_row[2] >= 0 &&
                                   # Max unsigned 8byte Int
                                   data_row[2] <= 18_446_744_073_709_551_615
    begin
      Float(data_row[3] || 0)
    rescue
      raise 'Invalid float'
    end
  end

  # Tally row results
  def add_data_row_to_results(data_row, results)
    results[:records] += 1
    case data_row[0] # Record Type
    when 'Debit'
      results[:total_debits] += data_row[3]
      if data_row[2] == 2_456_938_384_156_277_127
        results[:balance_for_2456938384156277127] += data_row[3]
      end
    when 'Credit'
      results[:total_credits] += data_row[3]
      if data_row[2] == 2_456_938_384_156_277_127
        results[:balance_for_2456938384156277127] -= data_row[3]
      end
    when 'StartAutopay'
      results[:autopays_started] += 1
    when 'StopAutopay'
      results[:autopays_ended] += 1
    end
  end

  def print_results(results)
    if results[:records] != results[:header_record_count]
      warn 'WARNING: Records count does not match header value: ' \
        "Records: #{results[:records]} Header: #{results[:header_record_count]}"
    end
    puts
    puts "Header Row Record Count: #{results[:header_record_count]}"
    puts "Total Records: #{results[:records]}"
    puts "Total Credits: $#{results[:total_credits].to_s("F")}"
    puts "Total Debits: $#{results[:total_debits].to_s("F")}"
    puts "Total Autopays Started: #{results[:autopays_started]}"
    puts "Total Autopays Ended: #{results[:autopays_ended]}"
    puts 'Balance for user ID 2456938384156277127: $'\
      "#{results[:balance_for_2456938384156277127].to_s("F")}"
  end
}
