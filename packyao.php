<?php
$a = [];

$a['source'] = 'https://drive.google.com/uc?export=download&id=0B-jblWXS1ZxsNmJIUzBscWVKU2M';
$a['type'] = 'http';
$a['commands'] = [
    'pwd',
    'apt-get -y install build-essential autoconf',
    'tar xvfz source',
    'cd nutcracker-0.4.0 && CFLAGS="-ggdb3 -O0" ./configure --enable-debug=full && '
    . 'make && make install'
];
$a['depends'] = [];
$a['cwd'] = '';
$a['env'] = [];
$a['version'] = '';
$a['output'] = 'deb';
$a['package_files'] = [
    'nutcracker-0.4.0/src/nutcracker' => '/usr/local/sbin/nutcracker',
    'nutcracker-0.4.0/man/nutcracker.8' => '/usr/local/share/man/man8/nutcracker.8'
];
$a['build_distro'] = 'ubuntu';
$a['build_distro_version'] = '14.04';


echo json_encode($a, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;

$workspace = 'packyao-workspace';
mkdir($workspace, 0777, true);
chdir($workspace);

switch ($a['type']) {
    case 'git':
        gitClone($a['source']);
        break;
    case 'http':
        httpDownload($a['source']);
        break;

    default:
        break;
}

build();

function gitClone($url)
{
    $commands = ['git init', 'git remote add origin ' . $url, 'get pull'];
    foreach ($commands as $command) {
        runCommand($command);
    }
}

function httpDownload($url)
{
    $command = "wget -O source '$url'";
    runCommand($command);
}

function build()
{
    global $a;
    echo getcwd() . PHP_EOL;
    // set env vars
    foreach ($a['env'] as $key => $value) {
        echo "exporting $value" . PHP_EOL;
        putenv("$value");
    }

    foreach ($a['commands'] as $command) {
        runCommand($command);
    }
}

function runCommand($command)
{
    echo "running command '$command'..." . PHP_EOL;
    exec($command, $output, $return_var);
    print_r($output);
    echo "Returned: $return_var" . PHP_EOL;
}
