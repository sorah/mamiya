## Serf Events used in Mamiya

## Master sends

- `mamiya:task`
  - Enqueue `Task` to task queue.
  - Payload is in JSON. `payload['task']` is a task name. Payload will be passed in `Agent:;TaskQueue#enqueue` directly.

## Agents send

- `mamiya:task:start`
- `mamiya:task:finish`
- `mamiya:task:error`

  - `payload['task']` is a started/finished/errored task.
  - `payload['error']` is a class name of exception occured.

----

- `mamiya:pkg:remove`
- `mamiya:prerelease:remove`
- `mamiya:release:remove`
