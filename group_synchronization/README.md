# Group Synchronization

An dungeon queue in Go that runs parties through a limited number of dungeon instances without deadlock or starvation.

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

Limits:

- `1 <= n <= 1024`,
- `0 <= t, h, d <= 1048576`, and
- `0 <= t1 <= t2 <= 15`.

## How To

Make sure [Go](https://go.dev/) (1.23+) is installed.

### Running

From the `group_synchronization` directory:

```bash
go run ./cmd/lfg

# Run with Go race detector
go run -race ./cmd/lfg
```

### Building Binaries

To compile executable binaries into a `bin/` directory:

```bash
go build -o bin/lfg ./cmd/lfg
```

## References

<https://www.cs.yale.edu/homes/aspnes/pinewiki/Deadlock.html>
