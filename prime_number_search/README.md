# Prime Number Search

A multithreaded prime number search in Go exploring different concurrency schemes and output styles.

## Configuration

Edit the `config` file in the project root:

```text
15 500
```

- First value (`x`): number of threads
- Second value (`y`): search upper bound

## How To

Make sure [Go](https://go.dev/) (1.23+) is installed.

### Running

From the `prime_number_search` directory:

```bash
# Scheme 1: Range Partitioning
go run ./cmd/scheme1_now
go run ./cmd/scheme1_later

# Scheme 2: Divisor Splitting
go run ./cmd/scheme2_now
go run ./cmd/scheme2_later
```

### Building Binaries

To compile executable binaries into a `bin/` directory:

```bash
go build -o bin/scheme1_now ./cmd/scheme1_now
go build -o bin/scheme1_later ./cmd/scheme1_later
go build -o bin/scheme2_now ./cmd/scheme2_now
go build -o bin/scheme2_later ./cmd/scheme2_later
```

### Benchmarking

A benchmarking tool is included in `cmd/perf/` to measure runtimes across multiple thread counts and ranges:

```bash
go run ./cmd/perf -x 1,4,15,64 -y 1000,100000,1000000 -timeout 3s
```

Flags:

- `-x`: comma-separated thread counts (default: `1,4,15,64`)
- `-y`: comma-separated upper bounds (default: `1000,100000,1000000,10000000`)
- `-timeout`: duration before killing long-running runs (default: `2s`)
