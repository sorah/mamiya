## Task

Task is a some procedures that ordered remotely.
It'll be executed via `mamiya:task` serf event, and `TaskQueue`.

Task implementations are placed in `lib/mamiya/agent/tasks`.

Each task run has a job specification, such as target application and package.

### Base classes

- `abstract` - base
- `notifyable`

### Tasks

- `fetch` - Fetch specified package from storage
- `prepare` - Unpack fetched package then prepare it
  - if specified package hasn't fetched, enqueues `fetch` task with chain
- `switch`

- `clean`
- `ping`

### Chaining

- task can have chain in `_chain` key
- `_chain` should be an Array (if specified,) like `['prepare', 'switch']`.
- When task run with `_chain` finished, Task named the first element of `_chain` will be enqueued into `TaskQueue`.

#### Example

1. User enqueue `{"_chain": ["bar"], "task": "foo", "test": 42}`
2. Task `{"_chain": ["bar"], "task": "foo", "test": 42}` run
3. Task `{"_chain": ["bar"], "task": "foo", "test": 42}` enqueues `{"task": "bar", "test": 42}`
4. Task `{"task": "bar", "test": 42}` run
