#!/usr/bin/env ruby

require 'json'
require 'English'

$commands = {
  'type' => 'shell'
}

def run_command(command)
  puts "running command '#{command}'..."
  system(command)
  puts "Return code: #{$CHILD_STATUS}"
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
  scratchspace = "#{workspace}/scratch"
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
    run_command("cd /tmp; tar xvf #{File.expand_path(File.dirname(__FILE__))}/image.tar #{source[1..-1]}")
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
    '-C', 'dist/scratch',
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

puts ARGV[0]

command = ARGV[0]
filename = ARGV[1]
params = JSON.parse(File.read(filename))

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
else
  puts 'invalid argument'
  exit 1
end
