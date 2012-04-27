{exec} = require 'child_process'

REMOTE = 'git@github.com:also/globe'

task 'build', ->
  exec 'coffee -co build src/*.coffee && coffee -c examples/**/*.coffee'

task 'site', ->
  cmd = [
    'rm -rf gh-pages'
    'git clone . gh-pages -b gh-pages'
    'cd gh-pages'
    "git pull #{REMOTE} gh-pages"
    'cd -'
    'cp -r build examples natural-earth.jpg gh-pages/'
  ].join '&&'
  exec cmd
