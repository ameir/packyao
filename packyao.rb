#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'

$commands = {
  'type' => 'shell'
}

def run_command(command)
  puts "running command '#{command}'..."
  output, status = Open3.capture2e(command)

  puts "Output: \n" + output
  puts "Return code: #{status.exitstatus}"

  raise "Command failed: '#{command}'" unless status.success?
  output
end

def set_env(params)
  $commands['environment_vars'] = []
  params['env'].each do |key, value|
    command = "#{key}=#{value}"
    $commands['environment_vars'].push(command)
  end
end

def generate_packer_config(params)
  packer = {}
  packer['builders'] = [{
    'type' => 'docker',
    'image' => params['build_distro'],
    'export_path' => 'image.tar'
  }]

  packer['provisioners'] = [$commands]
  puts packer
  puts JSON.pretty_generate(packer)
  File.write('packer.json', JSON.pretty_generate(packer))
end

def run_user_commands(params)
  $commands['inline'] = params['commands']
end

def create_package_layout(params)
  require 'fileutils'
  workspace = 'dist'
  scratchspace = "#{workspace}/scratch/#{params['output']}"
  FileUtils.mkdir_p("#{workspace}/builds")

  puts "Currently in #{Dir.pwd}"

  # use hash based on artifact type
  files_hash = params['package_files']
  if files_hash.key?(params['output'])
    puts "Creating #{params['output']}-specific package"
    files_hash = params['package_files'][params['output']]
  end

  files_hash.each do |source, destination|
    puts "Processing: #{source} -> #{destination}"
    destination_dir = File.dirname(scratchspace + destination)
    puts "Creating directory '#{destination_dir}'..."
    FileUtils.mkdir_p(destination_dir) unless Dir.exist?(destination_dir)
    puts "Copying: #{source} -> #{scratchspace + destination}"
    run_command("cd /tmp; tar xvf #{__dir__}/image.tar #{source[1..-1]}")
    FileUtils.cp_r("/tmp#{source}", scratchspace + destination)
  end
end

def create_package(params)
  require 'fpm'
  require 'fpm/command'

  # https://github.com/tim-group/deployapp/blob/master/Rakefile
  arguments = [
    '-n', params['name'],
    '-v', params['version'],
    '-t', params['output'] || 'tar',
    '-s', 'dir',
    '-C', "dist/scratch/#{params['output']}",
    '-p', 'dist/builds',
    '-m', params['maintainer'] || 'packyao <ameirh+packyao@gmail.com>',
    '--iteration', params['iteration'] || 1,
    '--description', params['description'] || 'This package was created by packyao.',
    '--url', params['url'] || 'http://www.packyao.com',
    '--verbose',
    '--force'
  ]

  puts "Creating #{params['output']} build..."
  raise 'problem creating package' unless FPM::Command.new('fpm').run(arguments) == 0
end

def generate_metadata(filename)
  extension = File.extname(filename)
  output = {}
  case extension
  when '.deb'
    files = file_list_deb(filename).lines.drop(1).map { |a| a[1..-1] }
  when '.rpm'
    files = file_list_rpm(filename).lines
  else
    puts 'invalid extension!'
    exit 1
  end

  output['files'] = files.map(&:strip)
  File.write("#{filename}.json", JSON.pretty_generate(output))
end

def file_list_deb(filename)
  run_command("dpkg -c #{filename} | awk '{print $NF}'")
end

def file_list_rpm(filename)
  run_command("rpm -qlp #{filename} 2>/dev/null")
end

puts ARGV[0]

command = ARGV[0]
filename = ARGV[1]
params = JSON.parse(File.read(filename)) if File.extname(filename) == '.json'

case command
when 'generate'
  set_env(params)
  run_user_commands(params)
  generate_packer_config(params)
when 'build'
  run_command('packer build packer.json')
when 'package'
  params['outputs'].each do |output|
    params['output'] = output
    puts params
    create_package_layout(params)
    create_package(params)
  end
when 'metadata'
  generate_metadata(filename)
else
  puts 'invalid argument'
  exit 1
end
