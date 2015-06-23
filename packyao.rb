
require 'json'

def run_command(command)
  puts "running command '#{command}'..."
  system(command)
  puts "Returned: #{$?}"
end

def git_clone(url)
  commands = ['git init', 'git remote add origin ' + $url, 'get pull'];
  commands.each do |command|
    run_command(command);
  end
end

def http_download(url)
  command = "wget -O source '#{url}'";
  run_command(command);
end

def build_package(params)

  puts "Currently in #{Dir.pwd}"

  # set env vars
  params['env'].each do |key,value|
    puts "exporting #{key}=#{value}";
    ENV[key] = value
  end

  params['commands'].each do |command|
    run_command(command);
  end
end

filename = 'packyao-twemproxy.json'
params = JSON.parse(File.read(filename))

workspace = 'packyao-workspace';
Dir.mkdir(workspace, 0777) unless Dir.exists?(workspace)
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
