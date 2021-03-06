#!/usr/bin/env lsc -cj
author: 'Chia-liang Kao'
name: 'fireauth'
description: 'authorize against apps using firebase auth'
version: '0.0.1'
homepage: 'https://github.com/clkao/fireauth'
bin:
  fireauth: 'bin/cmd.js'
repository:
  type: 'git'
  url: 'https://github.com/clkao/fireauth'
engines:
  node: '0.8.x'
  npm: '1.1.x'
scripts:
  prepublish: """
    env PATH="./node_modules/.bin:$PATH" lsc -cj package.ls &&
    env PATH="./node_modules/.bin:$PATH" lsc -bc bin &&
    env PATH="./node_modules/.bin:$PATH" lsc -bc -o lib src
  """
dependencies:
  express: \3.x.x
  pg: \1.1.x
  optimist: \0.5.x
  firebase: \0.5.x
  qs: \0.6.x
  request: \2.21.x
devDependencies:
  LiveScript: '1.1.x'
