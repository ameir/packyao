
require 'json'

def run_command(command)
  puts "running command '#{command}'..."
  system(command)
  puts "Returned: #{$CHILD_STATUS}"
end

# TODO: checkout specific branch or commit
def git_clone(_url, _branch_or_commit = 'master')
  commands = ['git init', 'git remote add origin ' + url, 'get pull']
  commands.each do |command|
    run_command(command)
  end
end

def http_download(url)
  command = "wget -O source '#{url}'"
  run_command(command)
end

def build_package(params)
  puts "Currently in #{Dir.pwd}"

  # set env vars
  params['env'].each do |key, value|
    puts "exporting #{key}=#{value}"
    ENV[key] = value
  end

  params['commands'].each do |command|
    run_command(command)
  end
end

def create_package_layout(params)
  require 'fileutils'
  workspace = 'packyao-dist'
  Dir.mkdir(workspace, 0777) unless Dir.exist?(workspace)

  puts "Currently in #{Dir.pwd}"
  params['package_files'].each do |source, destination|
    puts "Processing: #{source} -> #{destination}"
    destination_dir = File.dirname(workspace + destination)
    puts "Creating directory '#{destination_dir}'..."
    FileUtils.mkdir_p(destination_dir) unless Dir.exist?(destination_dir)
    puts "Copying: #{source} -> #{workspace + destination}"
    FileUtils.cp(source, workspace + destination)
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
    '-C', 'packyao-dist',
    '-m', params['maintainer'] || 'packyao <ameirh+packyao@gmail.com>',
    '--iteration', 1,
    '--description', params['description'] || 'This package was created by packyao.',
    '--url', params['url'] || 'http://www.packyao.com',
    '--verbose',
    '--force'
  ]

  fail 'problem creating package' unless FPM::Command.new('fpm').run(arguments) == 0
end

filename = 'packyao.json'
params = JSON.parse(File.read(filename))

workspace = 'packyao-workspace'
Dir.mkdir(workspace, 0777) unless Dir.exist?(workspace)
Dir.chdir(workspace)

case params['type']
when 'git'
  git_clone(params['source'])
when 'http'
  http_download(params['source'])
else
  puts 'No supported download method defined.'
end

build_package(params)
create_package_layout(params)
create_package(params)
