# nanogems
A minimalist rubygem loader.  Useful for when ultra-fast startup time is important.

## About

Nanogems is intended to be a higher performance rubygem loader.  It does not provide the rubygems API, it just handles file loading. "No magic. No bloated code. Just Ruby."

## Usage

```sh
ruby --disable-gems -rnanogems some.rb
```

Then use normal requires:

```ruby
require "optimist"
```

You may wish to use the `Kernel#gem` method to specify a version.  If used liberally it may also speed your load time.

```ruby
require "nanogems"
gem "optimist", "3.0.0"
require "optimist"
```

If you do not want to put `require "nanogems"` in all your scripts using stuff from gems, just place `export RUBYOPT=rnanogems` into your profile file (`/etc/profile` or `~/.profile`).

## Operation and Tricks

Using rubygems can be extremely slow for lightweight ruby scripts, especially in the following scenarios:

+ Communal Ruby installation over a shared network with lots of installed gems
+ Slow filer performance, e.g. cloud storage
+ Only a few gems are used and they fit "standard" patterns.

nanogems exploits the fact that:
1. Ultimately we just want to update `$LOAD_PATH` to find our gem code.
2. Most standard rubygems install into: `#{gemname}-#{version}/lib`

It also saves time by not reading gem specification files or doing a lot of other things rubygems does.

## Installation

:construction:

This will install nanogems
```sh
sudo ruby install.rb
```
## Performance

For small numbers of gems loaded or simple gems, performance should be better than rubygems.  If it is not, feel free to use rubygems or submit a fix via a pull-request.

```sh
### with rubygems (default)
$ hyperfine "ruby -e \"require 'optimist'; puts Optimist::VERSION\""
Benchmark 1: ruby -e "require 'optimist'; puts Optimist::VERSION"
  Time (mean ± σ):      77.7 ms ±   2.3 ms    [User: 66.1 ms, System: 10.7 ms]
  Range (min … max):    74.6 ms …  87.2 ms    37 runs

### with nanogems
$ hyperfine "ruby --disable-gems -r./nanogems -e \"require 'optimist'; puts Optimist::VERSION\""
Benchmark 1: ruby --disable-gems -r./nanogems -e "require 'optimist'; puts Optimist::VERSION"
  Time (mean ± σ):      20.0 ms ±   1.8 ms    [User: 14.7 ms, System: 5.0 ms]
  Range (min … max):    18.0 ms …  26.0 ms    139 runs

### with nanogems and gem version specification
$ hyperfine "ruby --disable-gems -r./nanogems -e \"gem 'optimist', '3.1.0'; require 'optimist'; puts Optimist::VERSION\""
Benchmark 1: ruby --disable-gems -r./nanogems -e "gem 'optimist', '3.1.0'; require 'optimist'; puts Optimist::VERSION"
  Time (mean ± σ):      17.7 ms ±   1.7 ms    [User: 12.9 ms, System: 4.5 ms]
  Range (min … max):    15.8 ms …  22.6 ms    170 runs
``` 
 
... your mileage may vary.

## Bugs/Features

Absolute gem version specifiers should work, but relative ones ">=0.a" are not supported.

This may not cleanly load all gems, as it takes a lot of liberties for performance reasons.  Many modern gems rely on rubygems being loaded and all of the rubygems `Gem::*` API present.  These are not in scope for nanogems.

If the required files aren't in `#{gemname}-#{version}/lib`, you may be able to patch around it by explicitly using `gem "<other_name>"`

# Attribution

This work is based on the fine work of some other projects:
+ [microgems](https://github.com/botanicus/microgems) 
+ [minigems](https://github.com/fabien/minigems)

Authors for other projects are attributed in the [LICENSE](LICENSE)
