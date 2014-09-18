# Commands

## Global options

- `-C`, `--config`: path to configuration file (default: `./config.rb`)
  - config file won't be required if a command don't need it.
- `-S`, `--script`: path to script file (default: `./deploy.rb`)
  - script file won't be required if a command don't need it.
- `-a`, `--app`: Specify application name to operate
- `-d`, `--debug`: Enable debug mode
- `--color`, `--no-color`: Enable or disable colored output. When the stdout is a terminal, it'll be enabled by default.

## Storage related commands

### `list-applications` - list application in storage

```
$ mamiya list-applications -C ./config.rb
```

### `list-packages` - list packages for specified app in storage

```
$ mamiya list-packages -C ./config.rb -a myapp
```

- __Requires:__ configuration file, application name
  - application name will be retrieved from deploy script when not specified.
- __Options:__
  - `-n`, `--name-only`: Show only names (without heading text)

### `show` - show package information

```
$ mamiya list-packages -C ./config.rb -a myapp PACKAGE_NAME
```

- __Requires:__ configuration file, application name, package name
  - application name will be retrieved from deploy script when not specified.
- __Options:__
  - `-f`, `--format`: Choose output format from `pp`, `json`, or `yaml`. Default: `pp`.

## Build, pushing and fetching packages

### `build` - build package using script

```
$ mamiya build --script ./deploy.rb --source source_dir --destination dest_dir
```

- __Requires:__ application name, source, destination, deploy script
  - source, description, and app name will be taken from deploy script, if omitted
- __Options:__
  - `-f`, `--source`, `--build-from`: directory for package source.
  - `-t`, `--destination`, `--build-to`: directory to save built packages.
  - `-P`, `--skip-prepare-build`: Skip prepare build phase of deploy script.

### `push` - push built package to the storage

### `fetch`

## Package related commands

### `extract`

## `client` - API client for `mamiya master`

### `list-applications`

### `list-packages`

### `show-package`

### `list-agents`

### `show-agent`

### `show-distribution`
