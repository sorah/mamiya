## mamiya example configuration

You can start both master and agent(s) using foreman, in local.

- `deploy.rb`: mamiya script file (for package building, preparing)
- `config.rb`: master node configuration
- `config.agent.rb`: agent node configuration


### Building and pushing packages

- specify `$S3_BUCKET`, `$AWS_ACCESS_KEY_ID`, and `$AWS_SECRET_ACCESS_KEY` to use `S3` storage.
  - if not all specified, defaults to `Filesystem` storage uses `./packages` directory.

```
$ bundle exec mamiya build
09/09 09:41:00   INFO | [Build] Initiating package build
09/09 09:41:00   INFO | [Build] Running script.before_build
09/09 09:41:00   INFO | [Build] Running script.prepare_build
09/09 09:41:00   INFO | [Build] Running script.build ...
09/09 09:41:00   INFO | [Build] Copying script files...
09/09 09:41:00   INFO | [Build] - /.../example/deploy.rb -> /.../example/source/.mamiya.script
09/09 09:41:00   INFO | [Build] Package name determined: 2014-09-09_09.41.00-myapp
09/09 09:41:00   INFO | [Build] Packaging to: /.../example/builds/2014-09-09_09.41.00-myapp.tar.gz
09/09 09:41:00   INFO | [Build] Packed.
09/09 09:41:00   INFO | [Build] Running script.after_build
09/09 09:41:00   INFO | [Build] DONE!

$ tree packages
builds
├── 2014-09-09_09.41.00-myapp.json
└── 2014-09-09_09.41.00-myapp.tar.gz

0 directories, 2 files
```

```
$ bundle exec mamiya push builds/2014-09-09_09.41.00-myapp.tar.gz
$ bundle exec mamiya list-packages
$ bundle exec mamiya fetch 2014-09-09_09.41.00-myapp /tmp/
```

### Test steps individually (without agents)

```
$ bundle exec mamiya extract /tmp/2014-09-09_09.41.00-myapp.tar.gz /tmp/test
09/09 09:41:00   INFO | [Extract] Extracting /tmp/2014-09-09_09.41.00-myapp.tar.gz onto /tmp/test/2014-09-09_09.41.00-myapp
```

```
$ bundle exec mamiya prepare /tmp/test/2014-09-09_09.41.00-myapp
09/09 09:41:00   INFO | [Prepare] Preparing /private/tmp/test/2014-09-09_09.41.00-myapp...
```

### master and agents

#### Start cluster in local

You have to install [Serf](https://www.serfdom.io/) to run.

```
$ foreman start

(or)

$ foreman start -m 'master=1,agent=2'
```

#### Test `mamiya client`

```
$ bundle exec mamiya client list-packages -a myapp
2014-09-09_09.41.00-myapp

$ bundle exec mamiya client show-package -a myapp 2014-09-09_09.41.00-myapp
{"application"=>"myapp",
 "name"=>"2014-09-09_09.41.00-myapp",
 "meta"=>
  {"application"=>"myapp",
   "script"=>"deploy.rb",
   "name"=>"2014-09-09_09.41.00-myapp",
   "checksum"=>"..."}}
```
