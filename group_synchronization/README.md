# Group Synchronization

An LFG (Looking for Group) dungeon queue in Go that runs parties through a limited number of dungeon instances without deadlock or starvation. See [specs.md](specs.md) for the full problem statement.

## Configuration

Edit the `config` file in the project root:

```text
3 5 5 15 1 5
```

| Position | Value | Description                                  |
| -------- | ----- | -------------------------------------------- |
| 1        | `n`   | maximum number of concurrent instances       |
| 2        | `t`   | number of tank players in the queue          |
| 3        | `h`   | number of healer players in the queue        |
| 4        | `d`   | number of DPS players in the queue           |
| 5        | `t1`  | minimum clear time of an instance, seconds   |
| 6        | `t2`  | maximum clear time of an instance, seconds   |

Limits: `1 <= n <= 1024`, `0 <= t, h, d <= 1048576`, and `0 <= t1 <= t2 <= 15`.

## How To

Make sure [Go](https://go.dev/) (1.23+) is installed.

### Running

From the `group_synchronization` directory:

```bash
go run ./cmd/lfg
```

Add `-race` to run with the race detector:

```bash
go run -race ./cmd/lfg
```

### Building Binaries

```bash
go build -o bin/lfg ./cmd/lfg
```

### Slides

```bash
typst compile docs/deck.typ
```

## Output

Each time a party enters or clears an instance, the program prints the event, followed by the status of every instance (`active` or `empty`):

```text
[  2.00s] Party 4 entered instance 3 (clear time 5s)
          Instance 1: active (party 1)
          Instance 2: active (party 2)
          Instance 3: active (party 4)
```

At the end it prints a summary of how many parties each instance served and the total time it served.
